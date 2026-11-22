------------------------------------------------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2026 VINCENT MORIN, UBO
-- SPDX-License-Identifier: GPL-3.0-or-later
------------------------------------------------------------------------------------------------------------------------
--	1	2	3	4	5	6	7	8	9	0	1	2

separate ( EXPANDER )

					-----
	package body			UTILS
is					-----

  INT_LABEL	: LABEL_TYPE	:= 1;
  FS		: FILE_TYPE;


			-- GENERIC ACTUALS MANAGEMENT

  MAX_FORMAL_NAME_LEN	: constant	:= 32;

  GA_NAME		: array( 1 .. MAX_GENERIC_FORMALS ) of STRING( 1 .. MAX_FORMAL_NAME_LEN );
  GA_LEN		: array( 1 .. MAX_GENERIC_FORMALS ) of NATURAL;
  GA_ACTUAL	: array( 1 .. MAX_GENERIC_FORMALS ) of TREE;
  GA_COUNT	: NATURAL := 0;


			--^^^^--
  procedure		  TROU			( SITE :STRING; NOEUD :TREE := TREE_VOID )
  is			--------

	-- Signal maison des manques de capacite. Ecrit "; !! TROU ..."
	-- dans le FINC (traçabilite : grep TROU = inventaire vivant)
	-- ET le meme message sur la console (lecon n 96 : un
	-- commentaire FINC n'est vu par personne), puis leve
	-- PROGRAM_ERROR -- mode STRICT, defaut. En RECENSEMENT :
	-- compte, logue, continue.
	-- HYPOTHESE : la sortie courante est le FINC (vrai de tous les
	-- sites CODE_*). Si FS est ferme (hors expansion d'unite), on
	-- ecrit seulement sur la console.

    function	MSG		return STRING
    is
    begin
      if  NOEUD = TREE_VOID  then
        return  "!! TROU " & SITE;
      else
        return  "!! TROU " & SITE & " : " & NODE_NAME'IMAGE( NOEUD.TY );
      end if;
    end MSG;

  begin
    TROU_COUNT := TROU_COUNT + 1;

    if  IS_OPEN( FS )  then
      PUT_LINE( "; " & MSG );									-- dans le FINC (sortie courante)
      SET_OUTPUT( STANDARD_OUTPUT );
      NEW_LINE;
      PUT_LINE( MSG );									-- sur la console
      SET_OUTPUT( FS );									-- retour au FINC
    else
      NEW_LINE;
      PUT_LINE( MSG );									-- deja sur la console
    end if;

    if  not TROU_RECENSEMENT  then
      raise PROGRAM_ERROR;
    end if;

  end	TROU;
	----


			--^^^^^^^^^^^^^^^^--
  procedure		  OPEN_OUTPUT_FILE		( FILE_NAME :STRING )
  is			--------------------

  begin
    CREATE ( FS, OUT_FILE, FILE_NAME( FILE_NAME'FIRST .. FILE_NAME'LAST-4 ) & ".FINC" );				-- FASM INCLUDE
    SET_OUTPUT ( FS );										-- CODAGE SUR SORTIE STANDARD
    INT_LABEL := 1;

    TROU_COUNT := 0;										-- RAZ COMPTAGE DES TROUS D'IMPLEMENTATION PAR UNITE

  end	OPEN_OUTPUT_FILE;
	----------------


			--^^^^^^^^^^^^^^^^^--
  procedure		  CLOSE_OUTPUT_FILE
  is			---------------------

  begin
    SET_OUTPUT ( STANDARD_OUTPUT );

    if  TROU_COUNT > 0  then
      PUT_LINE( "!!" & NATURAL'IMAGE( TROU_COUNT ) & " TROU(s) traverses -- FINC SUSPECT" );
    end if;

    CLOSE ( FS );

  end	CLOSE_OUTPUT_FILE;
	-----------------


  package INT_IO	is new INTEGER_IO ( INTEGER ); use INT_IO;
  package LBL_IO	is new INTEGER_IO ( LABEL_TYPE ); use LBL_IO;


			--^^^^^^^^^--
  function		  NEW_LABEL						return LABEL_TYPE
  is			-------------

    LBL	: LABEL_TYPE	:= INT_LABEL;

  begin
    INT_LABEL := INT_LABEL + 1;
    return LBL;

  end	NEW_LABEL;
	---------


			--^^^^^^^^^--
  function		  NEW_LABEL						return STRING
  is			-------------

    LSTR  :constant STRING	:= LABEL_TYPE'IMAGE( INT_LABEL );

  begin
    INT_LABEL := INT_LABEL + 1;
    return 'L' & LSTR( LSTR'FIRST+1 .. LSTR'LAST );

  end	NEW_LABEL;
	---------


			--^^^^^^^^^--
  function		  LABEL_STR			( LBL : LABEL_TYPE )	return STRING
  is			-------------

    LSTR  :constant STRING	:= LABEL_TYPE'IMAGE( LBL );

  begin
    return 'L' & LSTR( LSTR'FIRST+1 .. LSTR'LAST );

  end	LABEL_STR;
	---------


			--^^^^^^^^^--
  procedure		  INC_LEVEL
  is			-------------
  begin
    CUR_LEVEL := CUR_LEVEL + 1;

  end	INC_LEVEL;
	---------


			--^^^^^^^^^--
  procedure		  DEC_LEVEL
  is			-------------

  begin
    CUR_LEVEL := CUR_LEVEL - 1;

  end	DEC_LEVEL;
	---------


			--^^^^^^^^^--
  function		  TYPE_SIZE		( TYPE_SPEC :TREE )		return NATURAL
  is			-------------

  begin
    case TYPE_SPEC.TY is
    when DN_ACCESS			=> return ADDR_SIZE;
    when DN_RECORD
	=> return ( DI( CD_IMPL_SIZE, TYPE_SPEC ) + STORAGE_UNIT - 1 ) / STORAGE_UNIT;
    when DN_CONSTRAINED_RECORD
	=> return TYPE_SIZE( D( SM_BASE_TYPE, TYPE_SPEC ) );
    when DN_ARRAY			=> return 2 * ADDR_SIZE;
    when DN_ENUMERATION | DN_INTEGER	=> return INTG_SIZE;
    when DN_FLOAT			=> return ADDR_SIZE;			-- 8 octets = 64 bits IEEE 754 double
    when DN_L_PRIVATE		=> return TYPE_SIZE( D( SM_TYPE_SPEC, TYPE_SPEC ) );
    when others =>
      TROU( "TYPE_SIZE type illicite", TYPE_SPEC );
    end case;
    return 0;

  end	TYPE_SIZE;
	---------


		--^^^^^^^^^^^^^--
  function	  TYPE_INFO_STR	( TYPE_SPEC :TREE ) return STRING
  is		-----------------
	-- Nom du namespace d'info d'un type dans le FINC. Convention
	-- UNIQUE (piege n 99) : type nomme -> '_' & nom_du_type ;
	-- type ANONYME (XD_SOURCE_NAME = l'OBJET, espece CLASS_VC_NAME,
	-- cf n 80/95c) -> '_' & nom_de_l_objet & "__type", comme au site
	-- de declaration. Toute fabrication manuelle de ce nom est un
	-- bug en attente.
    SRC		: TREE		:= D( XD_SOURCE_NAME, TYPE_SPEC );
    NAME_STR	:constant STRING	:= '_' & PRINT_NAME( D( LX_SYMREP, SRC ) );
  begin
    if  SRC.TY in CLASS_VC_NAME  then
      return  NAME_STR & "__type";
    else
      return  NAME_STR;
    end if;

  end	TYPE_INFO_STR;
	-------------

			--^^^^^^^^^^^^^^--
  function		  FULL_TYPE_VIEW		( T : TREE )	return TREE
  is			------------------
    R : TREE := T;
  begin
    loop
      if R.TY = DN_PRIVATE or else R.TY = DN_L_PRIVATE then
        if  D( SM_TYPE_SPEC, R ) /= TREE_VOID  then
          R := D( SM_TYPE_SPEC, R );

        elsif  D( SM_DERIVED, R ) /= TREE_VOID  then
			--| Seconde saveur DIANA de `private`/`l_private` (grammaire
			--| diana_NODES : SM_DERIVED en tete d'attributs) : type DERIVE
			--| d'un type prive, declare HORS du paquetage -- SM_TYPE_SPEC
			--| est VOID et aucune completion ne viendra.  La vue pleine est
			--| celle du PARENT : representation identique (LRM 3.4, meme
			--| doctrine que C1).  Precedent maison : ROOT_RECORD suit deja
			--| SM_DERIVED (n 120b).  Decouverte temoin CONV_DER1 30/07
			--| (ERREUR CODE_VC_NAME TYPE_SPEC.TY = DN_VOID sur DS : DSET).
          R := D( SM_DERIVED, R );

        else
          return R;								-- ni completion ni parent : anomalie, bruyante en aval
        end if;

      elsif R.TY = DN_INCOMPLETE then
        R := D( XD_FULL_TYPE_SPEC, R );

      else
        return R;
      end if;
    end loop;

  end	FULL_TYPE_VIEW;
	--------------


			--^^^^^^^^^^^^^^^^^--
  function		  CODE_DATA_TYPE_OF		( EXP_OR_TYPE_SPEC :TREE )	return CHARACTER
  is			---------------------

  begin
    if  EXP_OR_TYPE_SPEC.TY in CLASS_EXP  then
      declare
        EXP	: TREE	renames EXP_OR_TYPE_SPEC;

      begin
        case EXP.TY is
        when DN_FUNCTION_CALL | DN_PARENTHESIZED | DN_USED_OBJECT_ID =>
	return CODE_DATA_TYPE_OF( D( SM_EXP_TYPE, EXP ) );

        when others =>
	PUT_LINE( "ERREUR CODE_DATA_TYPE_OF : EXP.TY ILLICITE " & NODE_NAME'IMAGE( EXP.TY ) );
	raise PROGRAM_ERROR;
        end case;

      end;

    elsif  EXP_OR_TYPE_SPEC.TY in CLASS_TYPE_SPEC  then
      declare
        TYPE_SPEC	: TREE	renames EXP_OR_TYPE_SPEC;

      begin
        case TYPE_SPEC.TY is
        when DN_ACCESS =>
	return 'A';

        when DN_ENUMERATION =>
	declare
	  TYPE_SOURCE_NAME  : TREE		:= D( XD_SOURCE_NAME, TYPE_SPEC );
	  TYPE_SYMREP	: TREE		:= D( LX_SYMREP, TYPE_SOURCE_NAME );
	  NAME		: constant STRING	:= PRINT_NAME( TYPE_SYMREP );

	begin
	  if NAME = "BOOLEAN" then
	    return 'B';
	  elsif NAME = "CHARACTER" then
	    return 'B';
	  else
	    return 'I';
	  end if;
	end;

        when DN_INTEGER | DN_NUMERIC_LITERAL =>
	return 'I';

        when others =>
	PUT_LINE( "ERREUR CODE_DATA_TYPE_OF : TYPE_SPEC.TY ILLICITE " & NODE_NAME'IMAGE( TYPE_SPEC.TY ) );
	raise PROGRAM_ERROR;
        end case;
      end;

    else
      PUT_LINE ( "!!! CODE_DATA_TYPE_OF : EXP_OR_TYPE_SPEC.TY ILLICITE " & NODE_NAME'IMAGE ( EXP_OR_TYPE_SPEC.TY ) );
      raise PROGRAM_ERROR;
    end if;

  end	CODE_DATA_TYPE_OF;
	-----------------


			--====================--
  function		  NUMBER_OF_DIMENSIONS	( EXP :TREE )	return NATURAL
  is			--====================--

  begin
    if  EXP.TY in CLASS_CONSTRAINED  then
      return NUMBER_OF_DIMENSIONS( D( SM_BASE_TYPE, EXP ) );

    elsif  EXP.TY = DN_FUNCTION_CALL or EXP.TY = DN_USED_OBJECT_ID  then
      return NUMBER_OF_DIMENSIONS( D( SM_EXP_TYPE, EXP ) );

    elsif  EXP.TY = DN_ARRAY  then
      return DI( CD_DIMENSIONS, EXP );

    else
      PUT_LINE( "ERREUR NUMBER_OF_DIMENSIONS : TYPE EXPRESSION ILLICITE" & NODE_NAME'IMAGE( EXP.TY ) );
      raise PROGRAM_ERROR;
    end if;

  end	  NUMBER_OF_DIMENSIONS;
	--====================--


			--===========--
  function		  CONSTRAINED		( TYPE_SPEC :TREE )		return BOOLEAN
  is			--===========--

  begin
    return not ( TYPE_SPEC.TY in CLASS_UNCONSTRAINED );

  end	  CONSTRAINED;
	--===========--



			--==============--
  procedure		  LOAD_TYPE_SIZE		( TYPE_SPEC :TREE )
  is			--==============--

  begin
    if  CONSTRAINED( TYPE_SPEC )  then
      PUT_LINE( ASCII.HT & "LI" & ASCII.HT &  INTEGER'IMAGE( TYPE_SIZE( TYPE_SPEC ) ) );

    else
      TROU( "LOAD_TYPE_SIZE type non contraint", TYPE_SPEC );
    end if;

  end	  LOAD_TYPE_SIZE;
	--==============--


			--=============--
  function		  OPER_SIZ_CHAR		( DEFN :TREE )		return CHARACTER
  is			--=============--
  begin
    if  DEFN.TY = DN_FLOAT  or  DEFN.TY = DN_ACCESS  then return 'Q'; end if;

    declare
      TS		: TREE		:= DEFN;
      SIZ		: NATURAL;
    begin
      if  TS.TY = DN_INTEGER  or else  TS.TY = DN_ENUMERATION  then						-- la representation vit sur la BASE (RM83) ;
        declare											-- un sous-type suit sa base, toujours
	BASE	: TREE	:= D( SM_BASE_TYPE, TS );
        begin
	if  BASE /= TREE_VOID  and then  BASE /= TREE_NIL  then
	  TS := BASE;
	end if;
        end;
      end if;
      SIZ := DI( CD_IMPL_SIZE, TS );

      if  SIZ <= 0  then PUT_LINE( "'; EXPANDER.UTILS.OPER_SIZ_CHAR SIZ = 0 ! "
	& NODE_NAME'IMAGE( DEFN.TY )
	& ' ' & PRINT_NAME( D( LX_SYMREP, D( XD_SOURCE_NAME, DEFN ) ) )
	);
      raise  PROGRAM_ERROR;
      end if;
      if	 SIZ <= 8		then return 'B';
      elsif SIZ <= 16	then return 'W';
      elsif SIZ <= 32	then return 'D';
      elsif SIZ <= 64	then return 'Q';
      else
        PUT_LINE( "'; EXPANDER.UTILS.OPER_SIZ_CHAR : taille > 64 bits -- operande non scalaire ? "
	  & NODE_NAME'IMAGE( DEFN.TY ) );
        raise  PROGRAM_ERROR;										-- n 96 : un S'v'/L'v' est TOUJOURS un bug amont
      end if;
    end;

  end	  OPER_SIZ_CHAR;
	--=============--


			--^^^^^^^^^^^^^--
  function		  EXP_TYPE_CHAR		( EXP :TREE )	return CHARACTER
  is			-----------------

    EXP_TYPE	: TREE		:= FULL_TYPE_VIEW( D( SM_EXP_TYPE, EXP ) );

  begin
    -- Les flottants sont toujours en double IEEE 754 = 64 bits = qword
    if  EXP_TYPE.TY = DN_FLOAT  or  EXP_TYPE.TY = DN_ACCESS then return 'Q'; end if;
    declare
      SIZ		: NATURAL		:= DI( CD_IMPL_SIZE, EXP_TYPE );
    begin
    if	 SIZ <= 8		then return 'B';
    elsif  SIZ <= 16	then return 'W';
    elsif  SIZ <= 32	then return 'D';
    elsif  SIZ <= 64	then return 'Q';
    else return 'V';
    end if;
    end;

  end	EXP_TYPE_CHAR;
	-------------


			--^^^^^^^^^^^^^^^^--
  function		  IS_UNSIGNED_TYPE		( DEFN :TREE )		return BOOLEAN
  is			--------------------
  -- Non signe ssi la borne basse STATIQUE du type de BASE est >= 0 : c'est le
  -- type de base qui porte la representation du conteneur (CD_IMPL_SIZE).
  -- CONSERVATEUR : tout cas non prouvable statiquement rend FALSE (load signe,
  -- toujours correct aujourd'hui). Enumere : 'POS >= 0, donc TRUE, SAUF clause
  -- de representation (codes internes negatifs possibles, RM83 13.3) -> FALSE.

    TS	: TREE	:= FULL_TYPE_VIEW( DEFN );

  begin
    if  TS = TREE_VOID  or else  TS = TREE_NIL  then
      PUT_LINE( "; UTILS.IS_UNSIGNED_TYPE TS VOID" );
      raise PROGRAM_ERROR;
    end if;

    if  TS.TY = DN_ENUMERATION  then
	-- Le conteneur porte les CODES internes (SM_REP), pas les positions.
	-- Sans clause de representation : code = position >= 0.  Avec clause
	-- (RM83 13.3), les codes sont strictement CROISSANTS : le SM_REP du
	-- PREMIER litteral du type de BASE est donc le minimum representable
	-- dans le conteneur.  Pas de sm_representation sur dn_enumeration
	-- dans diana.idl (D stricte, piege 95a) : on lit SM_LITERAL_S,
	-- qui couvre les deux cas.
      declare
	BASE	: TREE		:= FULL_TYPE_VIEW( D( SM_BASE_TYPE, TS ) );
	LITS	: SEQ_TYPE;
	FIRST_LIT : TREE;
      begin
	if  BASE = TREE_VOID  or else  BASE = TREE_NIL  then
	  BASE := TS;
	end if;

	LITS := LIST( D( SM_LITERAL_S, BASE ) );
	if  IS_EMPTY( LITS )  then
	  return FALSE;							-- conservateur : load signe
	end if;
	POP( LITS, FIRST_LIT );
	return  DI( SM_REP, FIRST_LIT ) >= 0;
      end;
    end if;

    if  TS.TY /= DN_INTEGER  then									-- FLOAT/ACCESS : chemin qword, hors sujet
      return FALSE;
    end if;

    declare
      BASE	: TREE	:= FULL_TYPE_VIEW( D( SM_BASE_TYPE, TS ) );
      NAMED	: TREE;
      RNG		: TREE;
      FST		: TREE;
    begin
      if  BASE = TREE_VOID  or else  BASE = TREE_NIL  then
        BASE := TS;
      end if;

      -- Gamme decisive : celle du PREMIER SOUS-TYPE NOMME, pas celle de la
      -- base anonyme (RM83 3.5.4 : la base herite de la gamme du predéfini
      -- parent — temoin DIANA du 18/07, SM_RANGE de la base en region STANDRD).
      -- Aucun objet n'est du type de base, et tout sous-type nommable est
      -- contraint dans la gamme du premier nomme : le conteneur ne recoit
      -- jamais d'autre valeur.
      NAMED := BASE;
      if	     D( XD_SOURCE_NAME, BASE ) /= TREE_VOID
      and then D( XD_SOURCE_NAME, BASE ) /= TREE_NIL  then
        declare
	SPEC	: TREE	:= FULL_TYPE_VIEW( D( SM_TYPE_SPEC, D( XD_SOURCE_NAME, BASE ) ) );
        begin
	if  SPEC /= TREE_VOID  and then  SPEC /= TREE_NIL  then
	  NAMED := SPEC;
	end if;
        end;
      end if;

      RNG := D( SM_RANGE, NAMED );
      if  RNG = TREE_VOID  or else  RNG = TREE_NIL  then
        RNG := D( SM_RANGE, TS );									-- repli : gamme du spec recu
      end if;

      if  RNG = TREE_VOID  or else  RNG = TREE_NIL  then
        return FALSE;
      end if;

      FST := D( AS_EXP1, RNG );

      while  FST.TY = DN_PARENTHESIZED  or else  FST.TY = DN_CONVERSION  loop					-- meme deshabillage que STATIC_BOUND_VALUE
        FST := D( AS_EXP, FST );
      end loop;

      if  FST.TY = DN_NUMERIC_LITERAL  then
        return  DI( SM_VALUE, FST ) >= 0;								-- -32768 arrive en NEG( literal ), donc PAS
      end if;											-- DN_NUMERIC_LITERAL ici : tombe en FALSE

      return FALSE;

    end;

  end	IS_UNSIGNED_TYPE;
	----------------


			--^^^^^^^^^^^^^--
  function		  OPER_LOAD_STR	( DEFN :TREE )		return STRING
  is			-----------------
    C	: CHARACTER	:= OPER_SIZ_CHAR( DEFN );
  begin
    if  C /= 'Q'  and then  IS_UNSIGNED_TYPE( DEFN )  then
      return "UL" & C;
    else
      return "L" & C;
    end if;

  end	OPER_LOAD_STR;
	-------------


			--^^^^^^^^^^^^^^--
  function		  OPER_LOADI_STR	( DEFN :TREE )		return STRING
  is			------------------
    C	: CHARACTER	:= OPER_SIZ_CHAR( DEFN );
  begin
    if  C /= 'Q'  and then  IS_UNSIGNED_TYPE( DEFN )  then
      return "ULI" & C;
    else
      return "LI" & C;
    end if;

  end	OPER_LOADI_STR;
	--------------


			--^^^^^^^^--
  procedure		  LOAD_MEM			( DEFN :TREE )
  is			------------

  begin
    if  CODI.IN_GENERIC_BODY
        and then  DEFN.TY in CLASS_PARAM_NAME
        and then  EXPRESSIONS.IS_GENERIC_FORMAL_OBJECT( DEFN )  then
      declare
        DEFN_STR		:constant STRING	:= PRINT_NAME( D( LX_SYMREP, DEFN ) );
        OBJ_TYPE		: TREE		:= D( SM_OBJ_TYPE, DEFN );
        HAS_GENERIC_TYPE	: BOOLEAN
			:= EXPRESSIONS.IS_GENERIC_FORMAL_TYPE( D( XD_SOURCE_NAME, OBJ_TYPE ) );
      begin

        if  HAS_GENERIC_TYPE  then
	PUT_LINE( tab & "LA " & IMAGE( CODI.GENERIC_BASE_LEVEL + 1 ) & "," & tab & "-GFP_ofs" );
	PUT_LINE( tab & "LVA ," & tab & "-" & DEFN_STR & "_ofs" );

	PUT_LINE( tab & "LA" & LEVEL_NUM'IMAGE( CODI.GENERIC_BASE_LEVEL+1 ) & ',' & tab & "-GFP_ofs" );
	PUT_LINE( tab & "LA ," & tab & '-'
			& PRINT_NAME( D( LX_SYMREP, D( XD_SOURCE_NAME, D( SM_OBJ_TYPE, DEFN ) ) ) )
			& "__ld_ofs" );
	PUT_LINE( tab & "CALLI" );

        else
	while  OBJ_TYPE.TY = DN_PRIVATE  or else  OBJ_TYPE.TY = DN_L_PRIVATE  loop
	  OBJ_TYPE := D( SM_TYPE_SPEC, OBJ_TYPE );
	end loop;

	PUT_LINE( tab & "LA " & IMAGE( CODI.GENERIC_BASE_LEVEL + 1 ) & "," & tab & "-GFP_ofs" );

	if  OBJ_TYPE.TY in CLASS_SCALAR  or else  OBJ_TYPE.TY = DN_ACCESS  then
	  PUT_LINE( tab & OPER_LOAD_STR( OBJ_TYPE ) & " ," & tab & "-" & DEFN_STR & "_ofs" );

	else
	  PUT_LINE( tab & "LVA ," & tab & "-" & DEFN_STR & "_ofs" );
	end if;
        end if;
        return;
      end;
    end if;

    if  DEFN.TY in CLASS_PARAM_NAME  then								-- in_id in_out_id out_id
      if  (DEFN.TY = DN_IN_ID) and (D( SM_OBJ_TYPE, DEFN ).TY in CLASS_SCALAR
			or else D( SM_OBJ_TYPE, DEFN ).TY = DN_ACCESS)	then

				-------------------
				SCALAR_IN_PARAMETER:
        begin
	PUT( tab & OPER_LOAD_STR( D( SM_OBJ_TYPE, DEFN ) ) & ' ' & INTEGER'IMAGE( DI( CD_LEVEL, DEFN ) ) & ',' );
	PUT( tab & '-' & PRINT_NAME( D( LX_SYMREP, DEFN ) ) );						-- ATTENTION signe offset de params opposé aux vars
	PUT_LINE( "_ofs" );										-- offset de parametre scalaire

        end		SCALAR_IN_PARAMETER;
			-------------------

      elsif  D( SM_OBJ_TYPE, DEFN ).TY in CLASS_SCALAR
	or else  D( SM_OBJ_TYPE, DEFN ).TY = DN_ACCESS  then						-- out/in_out SCALAIRE lu en expression :

				--------------------							-- le slot contient l'ADRESSE, dereferencer
				SCALAR_REF_PARAMETER:							-- (meme geste que la re-passe out->in de
        begin
	PUT( tab & OPER_LOADI_STR( D( SM_OBJ_TYPE, DEFN ) ) & ' ' & INTEGER'IMAGE( DI( CD_LEVEL, DEFN ) ) & ',' );
	PUT( tab & '-' & PRINT_NAME( D( LX_SYMREP, DEFN ) ) );
	PUT_LINE( "_ofs" );

        end		SCALAR_REF_PARAMETER;
			--------------------

      else											-- pas scalaire ou out in/out
        PUT( tab & "LA " & INTEGER'IMAGE( DI( CD_LEVEL, DEFN ) ) & ',' & tab );
        PUT( '-' & PRINT_NAME( D( LX_SYMREP, DEFN ) ) );							-- ATTENTION signe offset de params opposé aux vars
        PUT_LINE( "_ofs" );										-- offset de parametre adresse

      end if;

    else												-- NON PARAM
      declare
        OBJ_TYPE	:TREE	:= D( SM_OBJ_TYPE, DEFN );
      begin
        while  OBJ_TYPE.TY = DN_PRIVATE  or  OBJ_TYPE.TY = DN_L_PRIVATE  loop
	OBJ_TYPE := D( SM_TYPE_SPEC, OBJ_TYPE );
        end loop;

        if DEFN.TY in CLASS_VC_NAME  and then  DB( SM_RENAMES_OBJ, DEFN )  then
				---------------
				MANAGE_RENAMING:
	declare
	  OBJ_LEVEL	: LEVEL_NUM	:= DI( CD_LEVEL, DEFN );
	  OBJ_STR		: constant STRING	:= PRINT_NAME( D( LX_SYMREP, DEFN ) );
	begin

	  if  OBJ_TYPE.TY in CLASS_SCALAR  or else OBJ_TYPE.TY = DN_ACCESS  then
	    PUT( tab & OPER_LOADI_STR( OBJ_TYPE ) & tab & IMAGE( OBJ_LEVEL ) & ", " );
	    REGIONS_PATH( DEFN );
	    PUT_LINE( OBJ_STR & "_disp, 0" );
	  else
	    PUT_LINE( tab & "LVA" & tab & IMAGE( OBJ_LEVEL ) & ", " & OBJ_STR & "_disp" );
	  end if;

	  return;

	end		MANAGE_RENAMING;
			---------------
        end if;

        if  OBJ_TYPE.TY in CLASS_SCALAR  or else OBJ_TYPE.TY = DN_ACCESS  then
	declare
	  DEFN_LVL	: INTEGER		:= DI( CD_LEVEL, DEFN );

	begin
	  PUT( tab & OPER_LOAD_STR( OBJ_TYPE ) & ' ' & IMAGE( DEFN_LVL ) & ',' & tab );
	  if  DEFN_LVL /= INTEGER( CUR_LEVEL )  or else  D( XD_REGION, DEFN ).TY = DN_PACKAGE_ID  then
	    REGIONS_PATH( DEFN );
	  end if;
	  PUT_LINE( PRINT_NAME( D( LX_SYMREP, DEFN ) ) & "_disp" );
	end;

        else											-- variable non scalaire
	declare
	  DEFN_LVL	: INTEGER		:= DI( CD_LEVEL, DEFN );
	begin
	  PUT( tab & "LVA " & IMAGE( DEFN_LVL ) & ',' & tab );
	  if  DEFN_LVL /= INTEGER( CUR_LEVEL )  or else  D( XD_REGION, DEFN ).TY = DN_PACKAGE_ID  then
	    REGIONS_PATH( DEFN );
	  end if;
	  PUT_LINE( PRINT_NAME( D( LX_SYMREP, DEFN ) ) & "_disp" );
	end;

        end if;
      end;
    end if;

  end	LOAD_MEM;
	--------


			--^^^^^--
  procedure		  STORE			( DEST_DEFN	:TREE )
  is			---------
    TYPE_SPEC	: TREE		:= D( SM_OBJ_TYPE, DEST_DEFN );
    SIZ_CHAR	: CHARACTER;
    STORE_LEVEL	: INTEGER;
    DEST_DEFN_STR	:constant STRING	:= PRINT_NAME( D( LX_SYMREP, DEST_DEFN ) );

  begin

    while  TYPE_SPEC.TY = DN_L_PRIVATE  or  TYPE_SPEC.TY = DN_PRIVATE  loop
      TYPE_SPEC := D( SM_TYPE_SPEC, TYPE_SPEC );
    end loop;

    SIZ_CHAR := OPER_SIZ_CHAR( TYPE_SPEC );

    if  DEST_DEFN.TY = DN_COMPONENT_ID  then
      declare
        PARENT_TYPE : TREE	:= D( SM_TYPE_SPEC, D( XD_REGION, DEST_DEFN ) );
      begin
        STORE_LEVEL := DI( CD_LEVEL, PARENT_TYPE );
      end;
    else
      STORE_LEVEL := DI( CD_LEVEL, DEST_DEFN );
    end if;

    if  DEST_DEFN.TY = DN_OUT_ID  or  DEST_DEFN.TY = DN_IN_OUT_ID  then
      PUT_LINE( tab & "SI" & SIZ_CHAR & ' ' & INTEGER'IMAGE( STORE_LEVEL )
	& ',' & tab & '-' & DEST_DEFN_STR & "_ofs" );

    else
      PUT( tab & "S" & SIZ_CHAR & ' ' & INTEGER'IMAGE( STORE_LEVEL ) & ',' & tab );
      if  STORE_LEVEL /= INTEGER( CUR_LEVEL )  or else  D( XD_REGION, DEST_DEFN ).TY = DN_PACKAGE_ID  then
        REGIONS_PATH( DEST_DEFN );
      end if;
      PUT_LINE( DEST_DEFN_STR & "_disp" );

    end if;

  end	STORE;
	-----


		--^^^^^^^^^^^^^^^^^--
  function	  SUBPROGRAM_ORIGIN		( DEFN :TREE )	return TREE
  is		---------------------
		-- LRM 8.5 : un renames de sous-programme ne declare pas un
		-- nouveau corps -- l'appel vise l'ORIGINE.  On suit la chaine
		-- SM_UNIT_DESC = DN_RENAMES_UNIT jusqu'au premier id porteur
		-- d'un vrai corps.  Meme prudence que EXCEPTION_ID_OF : la
		-- representation reelle est a confirmer au dump.
    RESULT	: TREE	:= DEFN;

  begin
    loop
      declare
        UD	: TREE	:= D( SM_UNIT_DESC, RESULT );
      begin
        exit when  UD = TREE_VOID  or else  UD = TREE_NIL
	or else  UD.TY /= DN_RENAMES_UNIT;

        declare
	NAME	: TREE	:= D( AS_NAME, UD );
        begin
	while  NAME.TY = DN_SELECTED  loop
	  NAME := D( AS_DESIGNATOR, NAME );
	end loop;
	RESULT := D( SM_DEFN, NAME );
        end;
      end;
    end loop;
    return  RESULT;

end	SUBPROGRAM_ORIGIN;
	-----------------


			--^^^^^^^^^^^^^^^^^^^^^^^--
  procedure		  SET_GENERIC_ACTUAL_TYPE	( FORMAL_NAME : STRING; ACTUAL_SPEC :TREE )
  is			---------------------------
  begin
    if  CODI.DEBUG  then
      PUT_LINE( "; F4A SET  cle=" & FORMAL_NAME & "  actuel=" & NODE_NAME'IMAGE( ACTUAL_SPEC.TY ) );
    end if;

    if  GA_COUNT = MAX_GENERIC_FORMALS  or else  FORMAL_NAME'LENGTH > MAX_FORMAL_NAME_LEN  then
      PUT_LINE( "; ANOMALIE SET_GENERIC_ACTUAL_TYPE : table pleine ou nom trop long" );
      raise PROGRAM_ERROR;
    end if;
    GA_COUNT := GA_COUNT + 1;
    GA_NAME( GA_COUNT )( 1 .. FORMAL_NAME'LENGTH ) := FORMAL_NAME;
    GA_LEN(  GA_COUNT ) := FORMAL_NAME'LENGTH;
    GA_ACTUAL( GA_COUNT ) := ACTUAL_SPEC;

  end	SET_GENERIC_ACTUAL_TYPE;
	-----------------------


			--^^^^^^^^^^^^^^^^^^^^^^--
  function		  GENERIC_ACTUAL_TYPE_OF	( FORMAL_NAME : STRING ) return TREE
  is			--------------------------
  begin

   for  I  in  1 .. GA_COUNT  loop
      if  GA_LEN( I ) = FORMAL_NAME'LENGTH
      and then  GA_NAME( I )( 1 .. GA_LEN( I ) ) = FORMAL_NAME
      then
        return GA_ACTUAL( I );
      end if;
    end loop;    return TREE_VOID;

  end	GENERIC_ACTUAL_TYPE_OF;
	----------------------


			--^^^^^^^^^^^^^^^^^^^^^^^^^^--
  procedure		  CLEAR_GENERIC_ACTUAL_TYPES
  is			------------------------------
  begin
    GA_COUNT := 0;

  end	CLEAR_GENERIC_ACTUAL_TYPES;
	--------------------------


			--^^^--
  procedure		EXC_POP
  is			-------									-- PILIER 11 : EXC_TOP := EXC_TOP.PREV_CTX
  begin
    PUT_LINE( tab & "LA 0," & tab & "STANDARD.EXCEPTIONS_TOP_CTX_disp" );
    PUT_LINE( tab & "LA , 0" );									-- PREV_CTX (offset 0)
    PUT_LINE( tab & "SA 0," & tab & "STANDARD.EXCEPTIONS_TOP_CTX_disp" );

  end	EXC_POP;
	-------


			--^^^^^^^^^^^^^^^--
  function		  EXCEPTION_ID_OF	( NAME :TREE )	return TREE
  is			-------------------
		-- Descend un nom eventuellement qualifie (DN_SELECTED) jusqu'au
		-- USED_NAME_ID, prend son SM_DEFN, puis suit la chaine des
		-- renommages.  LRM 8.5 : un renames ne declare pas une nouvelle
		-- exception -- l'identite est celle de l'ORIGINE.
		-- REPRESENTATION REELLE (dump exc_ren0, 7/7, contra diana_NODES) :
		-- SM_RENAMES_EXC porte DIRECTEMENT l'EXCEPTION_ID cible, pas le
		-- nom.  On accepte les deux formes -- foi au dump, pas a la
		-- grammaire.
    N		: TREE	:= NAME;
    RESULT	: TREE	:= NAME;
  begin
    loop
      while  N.TY = DN_SELECTED  loop
        N := D( AS_DESIGNATOR, N );
      end loop;

      if	 N.TY = DN_USED_NAME_ID  then  RESULT := D( SM_DEFN, N );
      elsif  N.TY = DN_EXCEPTION_ID  then  RESULT := N;							-- forme constatee : l'ID directement
      else	 exit;										-- nom non modelise : rendre le dernier resolu
      end if;

      N := D( SM_RENAMES_EXC, RESULT );
      exit when  N.TY /= DN_USED_NAME_ID
        and then  N.TY /= DN_SELECTED
        and then  N.TY /= DN_EXCEPTION_ID;								-- vierge/void : pas (plus) un renommage
    end loop;
    return  RESULT;

  end	EXCEPTION_ID_OF;
	---------------


			--^^^^^^^^^^^^^^^^--
  function		  GOTO_LABEL_ENTRY		( LABEL_ID :TREE )  return GOTO_LBL_IDX
  is			--------------------
  begin
    for  I in GOTO_BODY_BASE + 1 .. GOTO_LBL_TOP  loop
      if  GOTO_LABELS( I ).ID = LABEL_ID  then
        return I;
      end if;
    end loop;

    if  GOTO_LBL_TOP = MAX_GOTO_LABELS  then						-- refus bruyant (piege n 53)
      PUT_LINE( "; !!! GOTO_LABEL_ENTRY : table pleine (MAX_GOTO_LABELS)" );
      raise PROGRAM_ERROR;
    end if;

    GOTO_LBL_TOP := GOTO_LBL_TOP + 1;
    GOTO_LABELS( GOTO_LBL_TOP ) := ( ID => LABEL_ID,
			         LBL	=> NEW_LABEL,
			         DEFINED	=> FALSE,
			         LEVEL	=> 0 );
    return GOTO_LBL_TOP;

  end	GOTO_LABEL_ENTRY;
	----------------


			--^^^^^^^^^^^^^^^^^^^--
  procedure		  GOTO_CHECK_BODY_END
  is			-----------------------
  begin
    for  I in GOTO_PEND_BASE + 1 .. GOTO_PEND_TOP  loop
      if  GOTO_PENDING( I ).TARGET /= TREE_VOID  then					-- un goto en avant a ete emis, son raccord
        PUT_LINE( "; !!! GOTO : etiquette jamais emise dans ce corps" );			-- jamais pose : sem le garantit,
        raise PROGRAM_ERROR;							-- ceinture bruyante (piege n 53)
      end if;
    end loop;

  end	GOTO_CHECK_BODY_END;
	-------------------


			--^^^^^--
  function		  TAB50			return STRING
  is			---------

    NTABS		: INTEGER		:= (50 - NATURAL(TEXT_IO.COL) ) / 10;

  begin
    if  NTABS < 0  then  NTABS := 1;  else  NTABS := NTABS + 1;  end if;
    declare
      ESPACEMENT	: STRING( 1.. NATURAL(NTABS) )	:= (others => tab );

    begin
      return ESPACEMENT;
    end;

  end	TAB50;
	-----


			--^--
  function		IMAGE			( I : NATURAL )	return STRING
  is			-----

    STR	:constant STRING	:= NATURAL'IMAGE( I );

  begin
    return STR( STR'FIRST+1 .. STR'LAST );

  end	  IMAGE;
	--=====--


			--^^^^^^^^^^^^--
  procedure		  REGIONS_PATH		( ID : TREE; WITH_DOT :BOOLEAN := TRUE )
  is			----------------

    REGION	: TREE		:= D( XD_REGION, ID );
    RGN_NAME	:constant STRING	:= LETTERED_SUBNAME( PRINT_NAME( D( LX_SYMREP, REGION ) ) );

  begin
    if  RGN_NAME = "STANDARD"  or  RGN_NAME = "_STANDRD" then
      PUT( "STANDARD." );

    else
      REGIONS_PATH( REGION );

      if  REGION.TY = DN_TYPE_ID
      or else REGION.TY = DN_SUBTYPE_ID
      or else REGION.TY = DN_PRIVATE_TYPE_ID
      or else REGION.TY = DN_L_PRIVATE_TYPE_ID
      then
        PUT( '_' );
      end if;

      PUT( RGN_NAME );

      if  REGION.TY = DN_PROCEDURE_ID  or  REGION.TY = DN_FUNCTION_ID  or  REGION.TY = DN_OPERATOR_ID  then
        PUT( '_' & LABEL_STR( LABEL_TYPE( DI( CD_LABEL, REGION ) ) ) );

      elsif  REGION.TY = DN_GENERIC_ID  and then
		( D( SM_SPEC, REGION ).TY = DN_PROCEDURE_SPEC  or  D( SM_SPEC, REGION ).TY = DN_FUNCTION_SPEC )
      then
		-- Region = generique de SOUS-PROGRAMME : le namespace physique
		-- est le PRO du corps, au nom etiquete, mais generic_id ne porte
		-- pas CD_LABEL (schema DIANA).  Le label est sur l'AS_SOURCE_NAME
		-- du corps -- pose par CODE_SUBPROGRAM_BODY.  Lien verifie au
		-- dump (MINIG) : XD_BODY, et non SM_BODY (absent du dump).
		-- Les generiques de PACKAGE gardent leur namespace NON etiquete.
        PUT( '_' & LABEL_STR( LABEL_TYPE( DI( CD_LABEL, D( AS_SOURCE_NAME, D( XD_BODY, REGION ) ) ) ) ) );

      end if;
      if  WITH_DOT  then PUT( '.' ); end if;

    end if;

  end	  REGIONS_PATH;
	--============--


			--^^^^^^^^^^^^^^^^--
  function		  LETTERED_SUBNAME			( SUB_NAME : STRING )	return STRING
  is			--------------------
  begin
    if  SUB_NAME( SUB_NAME'FIRST ) = '"'  then
      if SUB_NAME = """>="""  then return "_GE_";
      elsif SUB_NAME = """>"""  then return "_GT_";
      elsif SUB_NAME = """<="""  then return "_LE_";
      elsif SUB_NAME = """<"""  then return "_LT_";
      elsif SUB_NAME = """+"""  then return "_PLUS_";
      elsif SUB_NAME = """-"""  then return "_MINUS_";
      elsif SUB_NAME = """&"""  then return "_CONC_";
      elsif SUB_NAME = """="""   then return "_EQ_";
      elsif SUB_NAME = """AND"""  then return "_AND_";
      elsif SUB_NAME = """OR"""   then return "_OR_";
      elsif SUB_NAME = """XOR"""  then return "_XOR_";
      elsif SUB_NAME = """NOT"""  then return "_NOT_";
      elsif SUB_NAME = """*"""    then return "_MUL_";
      elsif SUB_NAME = """/"""    then return "_DIV_";
      elsif SUB_NAME = """**"""   then return "_POW_";
      elsif SUB_NAME = """MOD"""  then return "_MOD_";
      elsif SUB_NAME = """REM"""  then return "_REM_";
      elsif SUB_NAME = """ABS"""  then return "_ABS_";
      end if;
      PUT_LINE( "'; LETTERED_SUBNAME : operateur non mappe " & SUB_NAME );
      raise  PROGRAM_ERROR;					-- n 96 : plus JAMAIS de guillemets en sortie	 end if;
      return  SUB_NAME;
    else
      return  SUB_NAME;
    end if;

  end	  LETTERED_SUBNAME;
	--================--


		--^^^^^^^^^^^^--
  function	LAST_OF_SELECTED	( NAME_ID :TREE )	return TREE
  is		----------------
    TEMP_NAME	: TREE	:= NAME_ID;

  begin
    while  TEMP_NAME.TY = DN_SELECTED  loop
      TEMP_NAME := D( AS_DESIGNATOR, TEMP_NAME );
    end loop;
    return  TEMP_NAME;

  end	LAST_OF_SELECTED;
	----------------


			--^^^^^^^^^^^^^^^^^^^^--
  function		  EXIT_UNLINK_MNEMONIC	( HEADER :TREE )	return STRING
  is			------------------------
		-- Chantier co-pile (n 109/147/163) : mnemonique de l'epilogue d'un
		-- frame de sous-programme (ret_lbl des corps, wrappers d'instanciation).
		-- UNLINKR rend la co-pile (r14 := r13) : procedures, fonctions a
		-- resultat scalaire / access / record -- le resultat est COPIE chez
		-- l'appelant avant l'epilogue.  UNLINK garde : fonctions a resultat
		-- TABLEAU (CODE_RETURN copie le data_ptr, PAS les donnees : contrat
		-- d'evasion, gardien STRRET_TEST) et toute sorte non prouvee sure
		-- (formel generique en corps partage, vue privee non percee) :
		-- le comportement historique est toujours le repli.
    RESULT_TS	: TREE;
  begin
    if  HEADER = TREE_VOID  or else  HEADER.TY /= DN_FUNCTION_SPEC  then
      return "UNLINKR";										-- procedure : rien n'evade
    end if;

    RESULT_TS := D( SM_TYPE_SPEC, D( SM_DEFN, LAST_OF_SELECTED( D( AS_NAME, HEADER ) ) ) );
    if  RESULT_TS = TREE_VOID  or else  RESULT_TS = TREE_NIL  then
      return "UNLINK";										-- non prouvable : garder
    end if;
    RESULT_TS := FULL_TYPE_VIEW( RESULT_TS );

    if  RESULT_TS.TY in CLASS_SCALAR
    or else  RESULT_TS.TY = DN_ACCESS
    or else  RESULT_TS.TY = DN_RECORD
    or else  RESULT_TS.TY = DN_CONSTRAINED_RECORD
    then
      return "UNLINKR";
    else
      return "UNLINK";										-- DN_ARRAY / DN_CONSTRAINED_ARRAY / autre : contrat d'evasion
    end if;

  end	EXIT_UNLINK_MNEMONIC;
	--------------------


		--^^^^^^^^^^^^^^^^^^^^^--
  function	  CONTIENT_DISCRIMINANT	( EXP :TREE )	return BOOLEAN
  is		-------------------------
	-- Parcours des formes d'expression d'une borne de contrainte de composant.
	-- Forme non prevue : FALSE (le composant reste statique ; le chemin
	-- historique levera bruyamment au site de lecture si c'etait faux).
    SEQ		: SEQ_TYPE;
    E		: TREE;
  begin
    if  EXP = TREE_VOID  then
      return  FALSE;
    end if;

    case  EXP.TY  is
    when DN_USED_OBJECT_ID		=> return  D( SM_DEFN, EXP ).TY = DN_DISCRIMINANT_ID;
    when DN_PARENTHESIZED
       | DN_QUALIFIED
       | DN_CONVERSION		=> return  CONTIENT_DISCRIMINANT( D( AS_EXP, EXP ) );
    when DN_RANGE			=> return  CONTIENT_DISCRIMINANT( D( AS_EXP1, EXP ) )
					   or else  CONTIENT_DISCRIMINANT( D( AS_EXP2, EXP ) );
    when DN_FUNCTION_CALL		=>
      SEQ := LIST( D( SM_NORMALIZED_PARAM_S, EXP ) );
      while  not IS_EMPTY( SEQ )  loop
        POP( SEQ, E );
        if  CONTIENT_DISCRIMINANT( E )  then
	return  TRUE;
        end if;
      end loop;
      return  FALSE;
    when others			=> return  FALSE;
    end case;

  end	CONTIENT_DISCRIMINANT;
	---------------------


		--^^^^^^^^^^^^^^^^^^^^^^^--
  function	  EST_COMPOSANT_DYNAMIQUE	( COMP_ID :TREE )	return BOOLEAN
  is		---------------------------
	-- Composant de sous-type tableau dont une borne d'indice (SM_RANGE des
	-- sous-types d'indice, la ou CODE_EXP butait) reference un discriminant.
    T		: TREE;
    IDX_S	: SEQ_TYPE;
    IDX		: TREE;
  begin
    if  COMP_ID.TY /= DN_COMPONENT_ID  then
      return  FALSE;
    end if;

    T := D( SM_OBJ_TYPE, COMP_ID );
    if  T.TY /= DN_CONSTRAINED_ARRAY  then
      return  FALSE;
    end if;

    IDX_S := LIST( D( SM_INDEX_SUBTYPE_S, T ) );
    while  not IS_EMPTY( IDX_S )  loop
      POP( IDX_S, IDX );
      if  ( IDX.TY = DN_INTEGER  or else  IDX.TY = DN_ENUMERATION )
      and then  CONTIENT_DISCRIMINANT( D( SM_RANGE, IDX ) )
      then
        return  TRUE;
      end if;
    end loop;
    return  FALSE;

  end	EST_COMPOSANT_DYNAMIQUE;
	-----------------------


		--^^^^^^^^^^^^^^^^^^^^--
  function	  EST_RECORD_DYNAMIQUE	( REC_TYPE :TREE )	return BOOLEAN
  is		------------------------
    R		: TREE		:= REC_TYPE;

		------------------
    function	COMP_LIST_DYNAMIQUE	( CL :TREE )	return BOOLEAN
    is		------------------
      DECL_S	: SEQ_TYPE;
      DECL	: TREE;
      ID_S	: SEQ_TYPE;
      ID		: TREE;
      VP		: TREE;
      VAR_S	: SEQ_TYPE;
      VAR_E	: TREE;
    begin
      if  CL = TREE_VOID  or else  CL = TREE_NIL  then
        return  FALSE;
      end if;

      DECL_S := LIST( D( AS_DECL_S, CL ) );
      while  not IS_EMPTY( DECL_S )  loop
        POP( DECL_S, DECL );
        if  DECL.TY /= DN_NULL_COMP_DECL  then
	ID_S := LIST( D( AS_SOURCE_NAME_S, DECL ) );
	while  not IS_EMPTY( ID_S )  loop
	  POP( ID_S, ID );
	  if  EST_COMPOSANT_DYNAMIQUE( ID )  then
	    return  TRUE;
	  end if;
	end loop;
        end if;
      end loop;

      VP := D( AS_VARIANT_PART, CL );
      if  VP /= TREE_VOID  and then  VP /= TREE_NIL  then
        VAR_S := LIST( D( AS_VARIANT_S, VP ) );
        while  not IS_EMPTY( VAR_S )  loop
	POP( VAR_S, VAR_E );
	if  VAR_E.TY = DN_VARIANT  and then  COMP_LIST_DYNAMIQUE( D( AS_COMP_LIST, VAR_E ) )  then
	  return  TRUE;
	end if;
        end loop;
      end if;
      return  FALSE;

    end	COMP_LIST_DYNAMIQUE;
	------------------

  begin
    R := FULL_TYPE_VIEW( R );
    if  R.TY = DN_CONSTRAINED_RECORD  then
      R := FULL_TYPE_VIEW( D( SM_BASE_TYPE, R ) );
    end if;
    if  R.TY /= DN_RECORD  then
      return  FALSE;
    end if;
    return  COMP_LIST_DYNAMIQUE( D( SM_COMP_LIST, R ) );

  end	EST_RECORD_DYNAMIQUE;
	--------------------


		--^^^^^^^^^^^^^^^^^--
  procedure	  DESC_VERS_DONNEES	( COMP_ID :TREE )
  is		---------------------
	-- @desc = objet + COMP ; donnees = objet + [@desc + OFS]
	--	  = @desc + [@desc + OFS] - COMP		(aucune reevaluation du prefixe)
  begin
    PUT_LINE( tab & "DUP" );
    PUT_LINE( tab & "LD" & tab & "," & INTEGER'IMAGE( DESC_OFS ) );
    PUT_LINE( tab & "ADD" );
    PUT( tab & "LI" & tab );
    REGIONS_PATH( COMP_ID );
    PUT_LINE( PRINT_NAME( D( LX_SYMREP, COMP_ID ) ) );
    PUT_LINE( tab & "SUB" );

  end	DESC_VERS_DONNEES;
	-----------------


		--^^^^^^^^^^^^^^^^^^^^^^^--
  function	  EST_SELECTION_DYNAMIQUE	( NAME :TREE )	return BOOLEAN
  is		---------------------------
  begin
    return  NAME /= TREE_VOID
	and then  NAME.TY = DN_SELECTED
	and then  EST_COMPOSANT_DYNAMIQUE( D( SM_DEFN, D( AS_DESIGNATOR, NAME ) ) );

  end	EST_SELECTION_DYNAMIQUE;
	-----------------------


		--^^^^^^^^^^^^^^^^^^^^^^^^^--
  function	  A_DISCRIMINANTS_PAR_DEFAUT	( REC_TYPE :TREE )	return BOOLEAN
  is		-----------------------------
	-- RM83 3.7.1 : tous les discriminants ont un defaut, ou aucun ; on regarde
	-- le premier.
    R		: TREE		:= FULL_TYPE_VIEW( REC_TYPE );
    DECL_S	: SEQ_TYPE;
    DECL	: TREE;
    ID_S	: SEQ_TYPE;
    ID		: TREE;
  begin
    if  R.TY = DN_CONSTRAINED_RECORD  then
      R := FULL_TYPE_VIEW( D( SM_BASE_TYPE, R ) );
    end if;
    if  R.TY /= DN_RECORD  then
      return  FALSE;
    end if;
    DECL_S := LIST( D( SM_DISCRIMINANT_S, R ) );
    if  IS_EMPTY( DECL_S )  then
      return  FALSE;
    end if;
    POP( DECL_S, DECL );
    ID_S := LIST( D( AS_SOURCE_NAME_S, DECL ) );
    POP( ID_S, ID );
    return  D( SM_INIT_EXP, ID ) /= TREE_VOID  and then  D( SM_INIT_EXP, ID ) /= TREE_NIL;

  end	A_DISCRIMINANTS_PAR_DEFAUT;
	--------------------------


		--^^^^^^^^^^^^^^^^^--
  procedure	  POSER_REC_COURANT	( LVL :LEVEL_NUM; NOM :STRING )
  is		---------------------
  begin
    REC_COURANT_NOM( 1 .. NOM'LENGTH ) := NOM;
    REC_COURANT_LEN := NOM'LENGTH;
    REC_COURANT_LVL := LVL;

  end	POSER_REC_COURANT;
	-----------------


		--^^^^^^^^^^^^^^^--
  procedure	  OTER_REC_COURANT
  is		-------------------
  begin
    REC_COURANT_LEN := 0;

  end	OTER_REC_COURANT;
	----------------


	-----
end	UTILS;
	-----

------------------------------------------------------------------------------------------------------------------------
--	1	2	3	4	5	6	7	8	9	0	1	2
