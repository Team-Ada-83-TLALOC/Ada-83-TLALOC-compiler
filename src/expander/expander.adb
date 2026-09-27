------------------------------------------------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2026 VINCENT MORIN, UBO
-- SPDX-License-Identifier: GPL-3.0-or-later
------------------------------------------------------------------------------------------------------------------------
--	1	2	3	4	5	6	7	8	9	0	1	2

with DIANA_NODE_ATTR_CLASS_NAMES, IDL, TEXT_IO;
use  DIANA_NODE_ATTR_CLASS_NAMES, IDL, TEXT_IO;
					--------
			procedure		EXPANDER		( NOM_TEXTE :STRING := "";
							  CPU_NAME :STRING := "X86_64";
							  OS_NAME :STRING := "LINUX"
 							)
					--------
is

  procedure DBGSTOP;


			-----
	package		UTILS
			-----
  is

			-- FLAGS DE DEBOGAGE ET AVERTISSEMENTS DE NON IMPLEMENTATION

    DEBUG				: BOOLEAN		:= FALSE;
    GENERATE_BINARY_MAP		: BOOLEAN		:= TRUE;

			--| DISCIPLINE TROU() (briefing expander bruyant, fossile n 115) :
			--| tout manque de capacite se signale AU SITE, dans le FINC ET
			--| sur la console (lecon n 96), puis leve PROGRAM_ERROR.
    TROU_RECENSEMENT		: BOOLEAN		:= FALSE;						--| TRUE : loguer SANS lever -- un run complet donne
												--| l'inventaire des trous vivants du corpus ; le FINC
												--| produit est alors FAUX (pile potentiellement
												--| desequilibree), il ne sert qu'a l'inventaire.
    TROU_COUNT			: NATURAL		:= 0;						--| trous traverses dans l'unite courante

    procedure TROU ( SITE :STRING; NOEUD :TREE := TREE_VOID );

    tab				: CHARACTER	renames ASCII.HT;

    MAX_INSTR			: constant		:= 10_000;				--| NB MAX D'INSTRUCTIONS
    MAX_LABEL			: constant		:= 10_000;				--| NB MAX D'ETIQUETTES DE SAUT
    MAX_UNIT			: constant		:= 2**11-1;				--| NB MAX D'UNITES PROGRAMME
    MAX_LEVEL			: constant		:= 2**5-1;				--| NB MAX DE NIVEAUX D'IMBRICATION
    MAX_OFFSET			: constant		:= 2**15-1;				--| 32K

    type LABEL_TYPE			is new NATURAL		range 0 .. MAX_LABEL;			--| TYPE ETIQUETTE
    subtype UNIT_NUM		is INTEGER		range 0 .. MAX_UNIT;
    subtype LEVEL_NUM		is NATURAL		range 0 .. MAX_LEVEL;
    subtype OFFSET_VAL		is INTEGER		range -MAX_OFFSET .. MAX_OFFSET;

    STORAGE_UNIT			: constant		:= 8;					--| OCTET DE 8 bits
    STACK_ELEMENT_SIZE		: constant		:= 8;					--| LA PILE EST GEREE PAR QUAD WORDS SUR X86-64
    ADDR_SIZE			: constant		:= 8;					--| ADRESSES SUR 64 BITS
    BOOL_SIZE			: constant		:= 1;					--| BOOLEEN SUR 1 OCTET
    CHAR_SIZE			: constant		:= 1;					--| CARACTERE SUR 8 BITS
    INTG_SIZE			: constant		:= 8;					--| ENTIER SUR 64 BITS

    type LOOP_CODE			is (DEC, GT, INC, LT);

    OUTPUT_CODE			: BOOLEAN			:= TRUE;					-- Dans le traitement de spécif on désactive le codage


			-- GENERICS MANAGEMENT

    IN_GENERIC_INSTANTIATION		: BOOLEAN			:= FALSE;					-- Traitement special pour les spec d instantiation
    INSTANTIATION_MODEL_NAME		: TREE;
    GENERIC_MODEL_DECL_SEQ		: SEQ_TYPE;
    IN_GENERIC_BODY			: BOOLEAN			:= FALSE;					-- Traitement special pour les corps de generique
    ENCLOSING_GENERIC		: TREE;
    GENERIC_BASE_LEVEL		: LEVEL_NUM		:= 0;
    MAX_GENERIC_FORMALS		: constant		:= 8;

    IN_SPEC_UNIT			: BOOLEAN			:= FALSE;

    CUR_LEVEL			: LEVEL_NUM;							--| NIVEAU D'IMBRICATION COURANT
    GFP_LEVEL			: LEVEL_NUM		:= 0;					--| NIVEAU DU PRO (ou corps de package generique) ENGLOBANT :
												--| frame porteur du PRM GFP_ofs (piege n 144). Pose par
												--| CODE_SUBPROGRAM_BODY / CODE_PACKAGE_BODY, JAMAIS par
												--| CODE_BLOCK : un bloc declare a son frame mais pas de PRM.
    CUR_OFFSET			: OFFSET_VAL		:= 0;


			-- EXCEPTIONS SERVICE

--| PILIER 11 : contexte de reprise empile au niveau L.  VRAI pendant la generation des stms proteges SEULEMENT (jamais pendant les handlers : deja depile, LRM 11.4.1).
    HANDLER_CTX_AT			: array( LEVEL_NUM ) of BOOLEAN	:= ( others => FALSE );
    HANDLER_LVL			: INTEGER			:= -1;					--| PILIER 11 : handler INNERMOST en cours de
    HANDLER_CTX_SUF			: LABEL_TYPE		:= 0;					--| generation -- niveau et suffixe (numero du label de dispatch) du contexte associe.
    CHECKS_ENABLED			: BOOLEAN			:= TRUE;					--| PILIER CHECKS : commutateur global d'emission.

			-- GOTO SERVICE (etiquettes <<L>> et instruction goto, LRM 5.9)
			--| Tables par CORPS (les etiquettes ne franchissent pas les corps,
			--| LRM 5.9), discipline de pile pour l'imbrication des corps.
			--| Indexees par le NOEUD DN_LABEL_ID (le CD_LABEL des label_id est
			--| vierge -- constat au dump GOTO_DUMP -- on ne le touche pas).
			--| goto ARRIERE : denivele immediat (forme CODE_EXIT).
			--| goto AVANT : BRA vers un RACCORD propre au goto + photo des
			--| contextes ; le raccord (EXC_POP + UNLINK) est emis par
			--| CODE_LABELED, qui connait les deux niveaux.

    MAX_GOTO_LABELS		: constant		:= 64;						--| NB MAX D'ETIQUETTES GOTO PAR IMBRICATION DE CORPS
    subtype GOTO_LBL_IDX	is NATURAL		range 0 .. MAX_GOTO_LABELS;

    type LVL_SET		is array( LEVEL_NUM ) of BOOLEAN;						--| photo de HANDLER_CTX_AT au site d'un goto

    type GOTO_LBL_REC	is record
			  ID		: TREE;							--| le DN_LABEL_ID (cle, egalite TREE)
			  LBL		: LABEL_TYPE;						--| etiquette FASM de l'instruction etiquetee
			  DEFINED		: BOOLEAN;						--| l'etiquette a ete EMISE
			  LEVEL		: LEVEL_NUM;						--| niveau d'emission (valide si DEFINED)
			end record;

    GOTO_LABELS		: array( 1 .. MAX_GOTO_LABELS ) of GOTO_LBL_REC;
    GOTO_LBL_TOP		: GOTO_LBL_IDX	:= 0;
    GOTO_BODY_BASE		: GOTO_LBL_IDX	:= 0;							--| base du corps courant dans la table

    type GOTO_PEND_REC	is record									--| un goto EN AVANT en attente de raccord
			  TARGET		: TREE;							--| le DN_LABEL_ID vise (TREE_VOID : resolu)
			  LBL_G		: LABEL_TYPE;						--| etiquette du raccord propre a ce goto
			  LEVEL		: LEVEL_NUM;						--| niveau du SITE du goto
			  CTX		: LVL_SET;						--| photo de HANDLER_CTX_AT au site du goto
			end record;

    GOTO_PENDING			: array( 1 .. MAX_GOTO_LABELS ) of GOTO_PEND_REC;
    GOTO_PEND_TOP			: GOTO_LBL_IDX	:= 0;
    GOTO_PEND_BASE			: GOTO_LBL_IDX	:= 0;						--| base du corps courant

    function  GOTO_LABEL_ENTRY	( LABEL_ID :TREE )		return GOTO_LBL_IDX;			--| trouve ou cree l'entree du corps courant
    procedure GOTO_CHECK_BODY_END;									--| ceinture bruyante : raccord jamais resolu

												--| -1 : hors handler (raise nu = ANOMALIE).
    NO_SUBP_PARAMS			: BOOLEAN			:= TRUE;					--| pour prms et prm_siz
    ENCLOSING_BODY			: TREE;
    CHOICE_OTHERS_FLAG		: BOOLEAN			:= FALSE;

    LOOP_STM_S			: TREE;
    LOOP_OP_INC_DEC			: LOOP_CODE;							--| POUR LE TRAITEMENT DES BOUCLES FOR REVERSE
    LOOP_OP_GT_LT			: LOOP_CODE;							--| DE MEME

    TYPE_SYMREP			: TREE;								--| UTILISE POUR LES OBJECT_DECL VAR CONST

    procedure OPEN_OUTPUT_FILE	( FILE_NAME :STRING );
    procedure CLOSE_OUTPUT_FILE;


    function  OPER_SIZ_CHAR		( DEFN :TREE )			return CHARACTER;
    function  EXP_TYPE_CHAR		( EXP :TREE )			return CHARACTER;
    function  IS_UNSIGNED_TYPE	( DEFN :TREE )			return BOOLEAN;			--| borne basse statique du type de BASE >= 0
    function  OPER_LOAD_STR		( DEFN :TREE )			return STRING;			--| "LB".."LQ" ou "ULB".."ULD" selon le signe
    function  OPER_LOADI_STR		( DEFN :TREE )			return STRING;			--| "LIB".."LIQ" ou "ULIB".."ULID" idem

    function  NEW_LABEL						return LABEL_TYPE;
    function  NEW_LABEL						return STRING;
    function  LABEL_STR		( LBL : LABEL_TYPE )		return STRING;

    procedure INC_LEVEL;
    procedure DEC_LEVEL;

    function  TYPE_SIZE		( TYPE_SPEC :TREE )			return NATURAL;
    function  TYPE_INFO_STR		( TYPE_SPEC :TREE )			return STRING;
    function  FULL_TYPE_VIEW		( T : TREE )			return TREE;
    function  CODE_DATA_TYPE_OF	( EXP_OR_TYPE_SPEC :TREE )		return CHARACTER;

    procedure LOAD_MEM		( DEFN :TREE );
    procedure STORE			( DEST_DEFN :TREE );

    function  SUBPROGRAM_ORIGIN	( DEFN :TREE )			return TREE;

    procedure SET_GENERIC_ACTUAL_TYPE	( FORMAL_NAME : STRING; ACTUAL_SPEC : TREE );
    function  GENERIC_ACTUAL_TYPE_OF	( FORMAL_NAME : STRING )		return TREE;			-- TREE_VOID si absent
    procedure CLEAR_GENERIC_ACTUAL_TYPES;

    procedure EXC_POP;
    function  EXCEPTION_ID_OF		( NAME :TREE )			return TREE;			--| PILIER 11 : SM_DEFN a travers DN_SELECTED, puis chaine des renommages (LRM 8.5)

    function  TAB50							return STRING;
    function  IMAGE			( I : NATURAL )			return STRING;

    procedure REGIONS_PATH		( ID : TREE; WITH_DOT :BOOLEAN := TRUE );

    function  LETTERED_SUBNAME	( SUB_NAME : STRING )		return STRING;

    function  LAST_OF_SELECTED	( NAME_ID :TREE )			return TREE;

    function  EXIT_UNLINK_MNEMONIC	( HEADER :TREE )			return STRING;			--| chantier co-pile (n 163) : "UNLINKR" (rend la co-pile) ou "UNLINK" (garde : resultat tableau)

    OPERAND_OVERFLOW		: exception;


  end	UTILS;
	-----

  package CODI	renames UTILS;
  use CODI;


  procedure CODE_ROOT ( ROOT :TREE );
  procedure CODE_OBJECT ( OBJECT :TREE );
  procedure CODE_SELECT_ALT_PRAGMA ( SELECT_ALT_PRAGMA :TREE );
  procedure CODE_EXCEPTION_ID ( EXCEPTION_ID :TREE );


				-----------
	package			EXPRESSIONS
				-----------
  is

    procedure CODE_EXP		( EXP		:TREE );
    procedure CODE_INDEXED		( INDEXED		:TREE );
    procedure CODE_STRING_LITERAL	( STRING_LITERAL	:TREE; STR_NAME :STRING );
    procedure CODE_SELECTED		( SELECTED	:TREE; IS_SOURCE :BOOLEAN := TRUE; CONTEXT :TREE := TREE_VOID );
    procedure CODE_SLICE		( SLICE		:TREE; IS_DESTINATION :BOOLEAN := TRUE );
    procedure CODE_STATIC_FIXED_VALUE	( VALUE, FIXED_TYPE :TREE );
    procedure CODE_AGGREGATE		( AGGREGATE, TYPE_SPEC	:TREE; DST_SLICE_RANGE :TREE := TREE_VOID );
    procedure CODE_OBJECT_ADDRESS	( NAME : TREE );
    procedure CODE_COMPOSITE_DATA_ADDRESS( EXP : TREE );
    procedure CODE_ARRAY_OPERAND	( E :TREE; ANON :STRING; CONTEXT_TYPE :TREE );
    function  IS_GENERIC_FORMAL_TYPE	( TYPE_DEFN	:TREE )		return BOOLEAN;
    function  IS_GENERIC_FORMAL_OBJECT  ( DEFN		:TREE )		return BOOLEAN;
    function  IS_GENERIC_FORMAL_SUBPROGRAM( ID		:TREE )		return BOOLEAN;
    procedure CODE_DISCRETE_RANGE_BOUND ( DISCRETE_RANGE :TREE; IS_LAST :BOOLEAN );
    procedure CODE_RANGE_CHECK	( TYPE_SPEC	:TREE );						--| PILIER CHECKS : gamme scalaire, valeur au
    procedure CODE_ZERO_DIVIDE_CHECK;									--| PILIER CHECKS E-E : diviseur au sommet,


  private

    procedure CODE_NAME		( NAME : TREE );
    procedure CODE_EXP_EXP		( EXP_EXP :TREE; TYPE_SPEC_HINT :TREE := TREE_VOID );
    procedure CODE_USED_OP		( USED_OP		:TREE );
    procedure CODE_USED_NAME_ID	( USED_NAME_ID	:TREE );
    procedure CODE_USED_CHAR		( USED_CHAR :TREE );
    procedure CODE_USED_OBJECT_ID	( USED_OBJECT_ID	:TREE );
    procedure CODE_ALL		( ADA_ALL		:TREE );

    procedure CODE_ATTRIBUTE		( ATTRIBUTE	:TREE );
    procedure CODE_FUNCTION_CALL	( FUNCTION_CALL	:TREE );
    procedure CODE_QUALIFIED_ALLOCATOR  ( QUALIFIED_ALLOCATOR:TREE );
    procedure CODE_SUBTYPE_ALLOCATOR	( SUBTYPE_ALLOCATOR :TREE );

    procedure CODE_NUMERIC_LITERAL	( NUMERIC_LITERAL	:TREE );
    procedure CODE_NULL_ACCESS	( NULL_ACCESS	:TREE );
    procedure CODE_SHORT_CIRCUIT	( SHORT_CIRCUIT	:TREE );
    procedure CODE_PARENTHESIZED	( PARENTHESIZED :TREE );
    procedure CODE_CONVERSION		( CONVERSION	:TREE );
    procedure CODE_QUALIFIED		( QUALIFIED	:TREE );
    procedure CODE_RANGE_MEMBERSHIP	( RANGE_MEMBERSHIP  :TREE );
    procedure CODE_TYPE_MEMBERSHIP	( TYPE_MEMBERSHIP	:TREE );

    procedure CODE_VC_ID		( VC_ID		:TREE );

	-----------
  end	EXPRESSIONS;
	-----------

  package body UTILS is separate;


			-----------------
  package			REPRESENTED_ITEMS
			-----------------
  is

    function  REP_RECORD_USED_BITS		( TYPE_SPEC :TREE )		return INTEGER;

    function  REPRESENTED_RECORD_SIZE_BITS	( TYPE_SPEC :TREE )		return INTEGER;
    function  HAS_RECORD_REP			( TYPE_SPEC :TREE )		return BOOLEAN;
    procedure CODE_REPRESENTED_RECORD_DECL	( TYPE_ID :TREE; TYPE_SPEC :TREE );
    function  HAS_COMPONENT_REP		( COMP_ID :TREE )		return BOOLEAN;
    procedure GET_COMPONENT_REP		( COMP_ID :TREE; BYTE_OFFSET :out INTEGER;
					  FIRST_BIT, LAST_BIT, WIDTH : out INTEGER );
    function  IS_SMALL_REP_RECORD		( TYPE_SPEC :TREE )		return BOOLEAN;
    procedure CODE_REPRESENTED_RECORD_AGGREGATE	( AGGREGATE :TREE; TYPE_SPEC :TREE );
    procedure CODE_LOAD_REP_COMPONENT		( COMP_ID :TREE );
    procedure CODE_STORE_REP_COMPONENT		( COMP_ID :TREE; VALUE_EXP  :TREE );

  end	REPRESENTED_ITEMS;
	-----------------

  package body REPRESENTED_ITEMS is separate;




				------------
	package			DECLARATIONS
				------------
  is

    procedure CODE_DECL		( DECL :TREE );
    procedure CODE_DECL_S		( DECL_S :TREE );
    procedure CODE_SUBPROG_ENTRY_DECL	( SUBPROG_ENTRY_DECL :TREE );
    procedure CODE_PACKAGE_DECL	( PACKAGE_DECL :TREE );
    procedure CODE_HEADER		( HEADER :TREE );
    procedure CODE_PACKAGE_SPEC	( PACKAGE_SPEC :TREE );
    procedure CODE_GENERIC_DECL	( GENERIC_DECL :TREE );


  private
    procedure CODE_NULL_COMP_DECL	( NULL_COMP_DECL :TREE );

			-- TYPE DECLARATION

    procedure CODE_TASK_DECL		( TASK_DECL :TREE );
    procedure CODE_UNIT_DECL		( UNIT_DECL :TREE );
    procedure CODE_SIMPLE_RENAME_DECL	( SIMPLE_RENAME_DECL :TREE );

			-- SUBPROGRAM DECLARATION

    procedure CODE_SUBP_ENTRY_HEADER	( SUBP_ENTRY_HEADER :TREE );
    procedure CODE_PARAM_S		( PARAM_S :TREE; FOR_FUNCTION :BOOLEAN := FALSE );
    procedure CODE_PARAM		( PARAM :TREE );
    procedure CODE_IN		( ADA_IN :TREE );
    procedure CODE_IN_OUT		( ADA_IN_OUT :TREE );
    procedure CODE_OUT		( ADA_OUT :TREE );

			-- VAR/CONST DECLARATION

    procedure CODE_VC_NAME		( VC_NAME :TREE; OBJECT_DECL :TREE := TREE_VOID );
    procedure CODE_ID_S_DECL		( ID_S_DECL :TREE );
    procedure CODE_EXCEPTION_DECL	( EXCEPTION_DECL :TREE );
    procedure CODE_DEFERRED_CONSTANT_DECL ( DEFERRED_CONSTANT_DECL :TREE );
    procedure CODE_EXP_DECL		( EXP_DECL :TREE );
    procedure CODE_NUMBER_DECL	( NUMBER_DECL :TREE );
    procedure CODE_OBJECT_DECL	( OBJECT_DECL :TREE );

    procedure CODE_ID_DECL		( ID_DECL :TREE );

	------------
  end	DECLARATIONS;
	------------

  package body DECLARATIONS is separate;



				------------
	package			INSTRUCTIONS
				------------
  is

    procedure CODE_STM_S		( STM_S :TREE );
    procedure CODE_STM		( STM :TREE );
    procedure CODE_PROCEDURE_CALL	( PROCEDURE_CALL :TREE; USED_NAME_ID : TREE );


  private

    procedure CODE_TEST_CLAUSE_ELEM_S	( TEST_CLAUSE_ELEM_S :TREE; STM_END_LBL :STRING );
    procedure CODE_COND_CLAUSE	( COND_CLAUSE :TREE; STM_END_LBL :STRING );
    procedure CODE_STM_ELEM		( STM_ELEM :TREE );
    procedure CODE_STM_PRAGMA		( STM_PRAGMA :TREE );
    procedure CODE_LABELED		( LABELED :TREE );
    procedure CODE_NULL_STM		( NULL_STM :TREE );
    procedure CODE_STM_WITH_EXP	( STM_WITH_EXP :TREE );
    procedure CODE_STM_WITH_EXP_NAME	( STM_WITH_EXP_NAME :TREE );
    procedure CODE_STM_WITH_NAME	( STM_WITH_NAME :TREE );
    procedure CODE_CALL_STM		( CALL_STM :TREE );
    procedure CODE_BLOCK_LOOP		( BLOCK_LOOP :TREE );
    procedure CODE_LOOP		( ADA_LOOP :TREE );
    procedure CODE_ASSIGN		( ASSIGN :TREE );
    procedure CODE_IF		( ADA_IF :TREE );
    procedure CODE_CASE		( ADA_CASE :TREE );
    procedure CODE_BLOCK		( BLOCK :TREE );
    procedure CODE_EXIT		( ADA_EXIT :TREE );
    procedure CODE_RETURN		( ADA_RETURN :TREE );
    procedure CODE_GOTO		( ADA_GOTO :TREE );
    procedure CODE_ACCEPT		( ADA_ACCEPT :TREE );
    procedure CODE_DELAY		( ADA_DELAY :TREE );
    procedure CODE_SELECTIVE_WAIT	( SELECTIVE_WAIT :TREE );
    procedure CODE_TERMINATE		( ADA_TERMINATE :TREE );
    procedure CODE_ENTRY_STM		( ENTRY_STM :TREE );
    procedure CODE_COND_ENTRY		( COND_ENTRY :TREE );
    procedure CODE_TIMED_ENTRY	( TIMED_ENTRY :TREE );
    procedure CODE_ABORT		( ADA_ABORT :TREE );
    procedure CODE_CLAUSES_STM	( CLAUSES_STM :TREE );
    procedure CODE_RAISE		( ADA_RAISE :TREE );
    procedure CODE_CODE		( CODE :TREE );

	------------
  end	INSTRUCTIONS;
	------------

  package body EXPRESSIONS  is separate;




				----------
	package			STRUCTURES
				----------
  is

    procedure CODE_COMPILATION_UNIT	( COMPILATION_UNIT :TREE );
    procedure CODE_BLOCK_BODY		( BLOCK_BODY :TREE; IS_PACK_BODY :BOOLEAN := FALSE );


  private

    procedure CODE_WITH_CONTEXT	( CONTEXT_ELEM_S  :TREE; EMIT_INCLUDES :BOOLEAN := TRUE );
    procedure CODE_SUBPROGRAM_BODY	( SUBPROGRAM_BODY :TREE );
    procedure CODE_PACKAGE_BODY	( PACKAGE_BODY :TREE );
    procedure CODE_SUBUNIT_BODY	( SUBUNIT_BODY :TREE );
    procedure CODE_TASK_BODY		( TASK_BODY :TREE );
    procedure CODE_EXCEPTIONS_ALTERNATIVE_S ( ALTERNATIVE_S :TREE );

	----------
  end	STRUCTURES;
	----------

  package body STRUCTURES    is separate;
  package body INSTRUCTIONS  is separate;



				---------
  procedure			CODE_ROOT			( ROOT :TREE )
  is
    USER_ROOT	:constant TREE	:= D( XD_USER_ROOT, ROOT );
    COMPILATION	:constant TREE	:= D( XD_STRUCTURE, USER_ROOT );
    COMPLTN_UNIT_S  :constant TREE	:= D( AS_COMPLTN_UNIT_S, COMPILATION );
  begin
    declare
      COMPLTN_UNIT_SEQ	: SEQ_TYPE	:= LIST ( COMPLTN_UNIT_S );
      COMPLTN_UNIT		: TREE;
    begin
      while not IS_EMPTY( COMPLTN_UNIT_SEQ ) loop
        POP( COMPLTN_UNIT_SEQ, COMPLTN_UNIT );
        CODI.OPEN_OUTPUT_FILE( GET_LIB_PREFIX & PRINT_NAME( D( XD_LIB_NAME, COMPLTN_UNIT ) ) );

        STRUCTURES.CODE_COMPILATION_UNIT ( COMPLTN_UNIT );

        CODI.CLOSE_OUTPUT_FILE;
      end loop;
    end;

  end	CODE_ROOT;
	---------


			-------------------
  procedure		CODE_CONTEXT_PRAGMA		( CONTEXT_PRAGMA :TREE )
  is			-------------------
  begin
    null;												--| INTENTIONNEL (partiel) : pragma de contexte sans
												--| effet de code ; trier ICI si l'un devient signifiant
  end	CODE_CONTEXT_PRAGMA;
	-------------------


			-----------------
  procedure		CODE_BLOCK_MASTER		( BLOCK_MASTER :TREE )
  is			-----------------
  begin
    TROU( "CODE_BLOCK_MASTER (tasking/masters hors perimetre)", BLOCK_MASTER );					--| vague 4 : corps vide

  end	CODE_BLOCK_MASTER;
	-----------------


			--------------------
  procedure		CODE_DERIVED_SUBPROG	( DERIVED_SUBPROG :TREE )
  is			--------------------
  begin
			--| Vague 4 : semantique REELLE non couverte -- SUBPROGRAM_ORIGIN
			--| ne suit que les chaines de RENAMES, pas la derivation : un
			--| appel au sous-programme derive viserait un label jamais emis.
    TROU( "CODE_DERIVED_SUBPROG", DERIVED_SUBPROG );

  end	CODE_DERIVED_SUBPROG;
	--------------------


			--------------------
  procedure		CODE_IMPLICIT_NOT_EQ	( IMPLICIT_NOT_EQ :TREE )
  is			--------------------
  begin
    null;												--| INTENTIONNEL (elucide vague 4) : le "/=" implicite est
												--| resolu AU SITE D'USAGE par symbole d'operateur
												--| (expressions : egalites scalaires, BLKCMP, records) --
												--| rien a declarer ici

  end	CODE_IMPLICIT_NOT_EQ;
	--------------------


			-----------------------
  procedure		CODE_SUBTYPE_INDICATION	( SUBTYPE_INDICATION, TYPE_DECL :TREE )
  is			-----------------------
    TYPE_ID		: TREE		:= D( AS_SOURCE_NAME, TYPE_DECL );
    INTEGER_SPEC		: TREE		:= D( SM_TYPE_SPEC, TYPE_ID );
  begin
    DI( CD_LEVEL,	  INTEGER_SPEC, INTEGER( CODI.CUR_LEVEL ) );
    DB( CD_COMPILED,  INTEGER_SPEC, TRUE );

  end	CODE_SUBTYPE_INDICATION;
	-----------------------



  procedure CODE_OBJECT ( OBJECT :TREE ) is
  begin
    case OBJECT.TY is
    when DN_VARIABLE_ID =>
      PUT_LINE( tab & "LA " & INTEGER'IMAGE( DI( CD_LEVEL, OBJECT ) ) & ',' & tab & PRINT_NAME( D( LX_SYMREP, OBJECT ) ) & "_disp" );

    when DN_IN_ID =>
      PUT_LINE( tab & "LVA " & INTEGER'IMAGE( DI( CD_LEVEL, OBJECT ) ) & ',' & tab & PRINT_NAME( D( LX_SYMREP, OBJECT ) ) );

    when DN_IN_OUT_ID | DN_OUT_ID =>
      PUT_LINE( tab & "LVA " & INTEGER'IMAGE( DI( CD_LEVEL, OBJECT ) ) & ',' & tab & PRINT_NAME( D( LX_SYMREP, OBJECT ) ) );

    when DN_INDEXED =>
      EXPRESSIONS.CODE_INDEXED( OBJECT );

    when DN_USED_OBJECT_ID =>
      CODE_OBJECT( D( SM_DEFN, OBJECT ) );

    when DN_CONSTANT_ID =>
      PUT_LINE( tab & "LIA " & INTEGER'IMAGE( DI( CD_LEVEL, OBJECT ) ) & ','
	      & tab & PRINT_NAME( D( LX_SYMREP, OBJECT ) ) & "_disp" );					-- LOAD CONSTANT ADDRESS

    when others =>
      PUT_LINE( "!!! LOAD_OBJECT_ADDRESS : OBJECT.TY ILLICITE " & NODE_NAME'IMAGE ( OBJECT.TY ) );
      raise PROGRAM_ERROR;
    end case;
  end;


			----------------------
  procedure		CODE_SELECT_ALT_PRAGMA	( SELECT_ALT_PRAGMA :TREE )
  is			----------------------
  begin
    null;												--| INTENTIONNEL : pragma d'alternative select, aucun code

  end	CODE_SELECT_ALT_PRAGMA;
	----------------------


  procedure CODE_EXCEPTION_ID ( EXCEPTION_ID :TREE ) is
  begin
    declare
      LBL :constant STRING := NEW_LABEL;
    begin
      PUT_LINE( "; EXL" & tab & LBL );
    end;
  end;



  procedure DBGSTOP is begin null; end;									--| INTENTIONNEL : crochet de point d'arret debogueur


begin
  if  NOM_TEXTE = ""  then										-- Pas de fabrication du .fas (tête d'assemblage fasmg)
    OPEN_IDL_TREE_FILE( LIB_PATH(1..LIB_PATH_LENGTH) & "$$$.TMP" );
    if DI( XD_ERR_COUNT, TREE_ROOT ) = 0
    then
      CODE_ROOT( TREE_ROOT );
    end if;
    CLOSE_IDL_TREE_FILE;

  else												-- Fabriquer le .fas
			--------------------
			CREATE_FAS_MAIN_FILE:
    declare
      LAST_NAME_CHAR	: POSITIVE	:= NOM_TEXTE'FIRST;
      UPPER_NAME		: STRING( NOM_TEXTE'RANGE );
    begin
FIND_DOT_IF_ANY_AND_UPCASE:
      for  I in NOM_TEXTE'RANGE  loop
        if  NOM_TEXTE( I ) in 'a' .. 'z'  then
	UPPER_NAME( I ) := CHARACTER'VAL( CHARACTER'POS( 'A' )
				+ CHARACTER'POS( NOM_TEXTE( I ) ) - CHARACTER'POS( 'a' ) );
        else UPPER_NAME( I ) := NOM_TEXTE( I );
        end if;
        exit when  NOM_TEXTE( I ) = '.';
        LAST_NAME_CHAR := I;
      end loop	FIND_DOT_IF_ANY_AND_UPCASE;

      declare
        F		: FILE_TYPE;
        NOM_FAS	: STRING renames UPPER_NAME( UPPER_NAME'FIRST .. LAST_NAME_CHAR );
        PATH_NAME	:constant STRING	:= IDL.LIB_PATH( 1 .. IDL.LIB_PATH_LENGTH )
					& NOM_FAS & '.' & CPU_NAME & OS_NAME( OS_NAME'FIRST ) & "FAS";
      begin
        OPEN( F, IN_FILE, PATH_NAME );
        CLOSE( F );
        PUT_LINE( "TLALOC/Ada 83 - " & PATH_NAME & " already exists" );

      exception
        when NAME_ERROR =>										-- Le FAS n'existe pas
	CREATE( F, OUT_FILE, PATH_NAME );
	SET_OUTPUT( F );

	PUT( tab & "include '../../src/expander/fasmg/codi_" );
	if  CPU_NAME = "X86_64"  then
	  PUT( "x86_64" & OS_NAME( OS_NAME'FIRST ) );

	elsif  CPU_NAME = "ARM64"  then
	  PUT( "arm64" );

	elsif  CPU_NAME = "RISCV64"  then
	  PUT( "riscv64" );
	end if;
	PUT_LINE( ".finc'" );

	PUT_LINE( "STANDARD = 'STANDARD'" );
	PUT_LINE( "namespace STANDARD" );
	PUT_LINE( "  virtual at 8" );
	PUT_LINE( "    VARzone::" );
	PUT_LINE( "  end virtual" );

	PUT_LINE( tab & "LINK" & tab & "0, loc_siz" );

	PUT_LINE( "include '_STANDRD.FINC'" );

   -- PILIER 11 EXCEPTIONS : contexte-sentinelle en fond de la pile des contextes de reprise
	PUT_LINE( tab & "EXC_MACH" & tab & "0, EXC_CTX0__dat" );						-- photo niveau 0 (NXT_LVL=1 : FP(0))
	PUT_LINE( tab & "LCA" & tab & "exc_uncaught_" );
	PUT_LINE( tab & "SA" & tab & "0, EXC_CTX0__dat + _EXCEPTION_CONTEXT.DISPATCH" );
	PUT_LINE( tab & "LVA" & tab & "0, EXC_CTX0__dat" );
	PUT_LINE( tab & "SA" & tab & "0, EXCEPTIONS_TOP_CTX_disp" );					-- (PREV_CTX de la sentinelle : jamais lu)

	PUT_LINE( "include '" & NOM_FAS & ".FINC'" );
	PUT_LINE( tab & "CALL" & tab & "STANDARD., " & NOM_FAS & "_L1" );
	PUT_LINE( tab & "SYS_EXIT" );

    -- PILIER 11 EXCEPTIONS : region inatteignable (apres SYS_EXIT)						-- deroulage + sentinelle
	PUT_LINE( "exc_raise_:" );									-- instance unique ; les raise viennent par BRA
	PUT_LINE( tab & "EXC_RAISE" & tab & "EXCEPTIONS_TOP_CTX_disp" );
	PUT_LINE( "exc_uncaught_:" );									-- dispatch du contexte-sentinelle
	PUT_LINE( tab & "STR" & tab & "EXC_MSG__, 'EXCEPTION NON RATTRAPEE : '" );
	PUT_LINE( tab & "STR" & tab & "EXC_NL__, 10" );
	PUT_LINE( tab & "LCA" & tab & "EXC_MSG__.data_ptr" );
	PUT_LINE( tab & "SYS_PUT_STR" );
	PUT_LINE( tab & "LA" & tab & "0, EXCEPTIONS_CURRENT_disp" );					-- le symbole EST son diagnostic
	PUT_LINE( tab & "SYS_PUT_STR" );
	PUT_LINE( tab & "LCA" & tab & "EXC_NL__.data_ptr" );
	PUT_LINE( tab & "SYS_PUT_STR" );
	PUT_LINE( tab & "SYS_EXIT" & tab & "1" );

    -- PILIER CHECKS : trampolines de levee des predefinies. Instance unique par executable,
    -- atteinte par BT/BF depuis les sites de check ; ne font que POSER l'identite et sauter
    -- au deroulage (pilier 11). Pas de photographie : l'invariant de frontiere d'instruction
    -- couvre le saut depuis toute profondeur d'expression, comme pour raise.
	PUT_LINE( "ce_raise_:" );									-- CONSTRAINT_ERROR
	PUT_LINE( tab & "LCA" & tab & "CONSTRAINT_ERROR__exc.data_ptr" );
	PUT_LINE( tab & "SA" & tab & "0, EXCEPTIONS_CURRENT_disp" );
	PUT_LINE( tab & "BRA" & tab & "exc_raise_" );
	PUT_LINE( "ne_raise_:" );									-- NUMERIC_ERROR (utilise a partir de E-E)
	PUT_LINE( tab & "LCA" & tab & "NUMERIC_ERROR__exc.data_ptr" );
	PUT_LINE( tab & "SA" & tab & "0, EXCEPTIONS_CURRENT_disp" );
	PUT_LINE( tab & "BRA" & tab & "exc_raise_" );


	PUT_LINE( " virtual VARzone" );
	PUT_LINE( "   loc_siz = $" );
	PUT_LINE( "  end virtual" );
	PUT_LINE( "end namespace" );
	CLOSE( F );
	SET_OUTPUT( STANDARD_OUTPUT );
	PUT_LINE( "TLALOC/Ada 83 - " & PATH_NAME & " created" );
      end;
    end		CREATE_FAS_MAIN_FILE;
		--------------------

  end if;

	--------
end	EXPANDER;
	--------

------------------------------------------------------------------------------------------------------------------------
--	1	2	3	4	5	6	7	8	9	0	1	2
