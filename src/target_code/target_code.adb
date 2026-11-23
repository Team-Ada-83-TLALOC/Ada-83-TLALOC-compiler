------------------------------------------------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2026 VINCENT MORIN, UBO
-- SPDX-License-Identifier: GPL-3.0-or-later
------------------------------------------------------------------------------------------------------------------------
--	1	2	3	4	5	6	7	8	9	0	1	2
--
--				T A R G E T _ C O D E   --   assembleur natif LLIR / FINC  ->  ELF executable
--
--	Outil autonome au meme titre que l'EXPANDER : etant donne le nom d'un .fas
--	initial et des FINC corrects, tout s'enchaine sans le frontend.
--	Reference : NOTE_SUBSET_FASMG v1. Implementations de reference : fasmg +
--	codi_x86_64.finc / codi_arm64.finc / codi_riscv64.finc (les db/dd commentes
--	des codi SONT les specs d'encodage).
--
--	DOCTRINE (v1 par 2.5) :
--	  - UNE lecture du texte, puis des phases sur l'IR en memoire. Pas de
--	    convergence d'adresses : INVARIANT DE TAILLE DETERMINISTE — la taille
--	    de chaque invocation est calculable avant de connaitre les adresses,
--	    grace aux formes canoniques (rel32/AUIPC+JALR fixes ; toute constante
--	    de classe ADRESSE en forme fixe : movabs / movz+movk / lui+addi).
--	  - Le lazy fasmg (postpone + ~definite) est remplace par le calcul
--	    d'ATTEIGNABILITE : point fixe sur un ensemble fini croissant de
--	    marques — borne par le nombre de sous-programmes, aucune oscillation.
--	  - Refus BRUYANTS (doctrine R6) : les err/assert des codi deviennent des
--	    levees explicites avec message ; jamais de repli muet.
--
--	PHASES :
--	  P0  LEX + PARSE   : .fas + includes (gardes de with = inclusion unique) ;
--	                      IR complete, y compris corps sous garde "if defined".
--	  P1  REACHABILITY  : marquage depuis l'entree via CALL/LSPA ; fermeture.
--	  P2  LAYOUT        : PRMzone/VARzone/STATOFS (unites atteignables) ;
--	                      tailles puis adresses de chaque invocation ;
--	                      constantes differees placees APRES le code en ordre
--	                      LIFO d'enregistrement (releve DIS_BONJOUR) ;
--	                      ASM_SIZE en dernier. assert image < 2**32.
--	  P3  EMIT          : en-tete ELF + amorcage + code + constantes, via la
--	                      table d'encodage de la cible ; MAP sous option.
--
-----------------------------------------------------------------------------------------------------------------------

with TEXT_IO, SEQUENTIAL_IO, IDL;
use  TEXT_IO;

					-----------
procedure					TARGET_CODE	( CPU_NAME, OS_NAME, UNIT_NAME :STRING;
							  MAP :BOOLEAN := FALSE )
is					-----------
  --| CPU_NAME : X86_64, ARM64 ou RISCV64 (forme canonique rendue par CLI).
  --| UNIT_NAME : nom du .fas sans extension. MAP : carto (display/hexa_show).


  --				C I B L E S   E T   T R A I T S

  type CPU_KIND		is ( X86_64, ARM64, RISCV64 );

  TARGET_CPU		: CPU_KIND	:= X86_64;						--| choisi par option de commande ("a la DCL", a venir)

  GENERATE_BINARY_MAP	: BOOLEAN		:= FALSE;							--| pendant du flag homonyme de l'expander : reproduit
												--| les display/hexa_show (carto) sous option

  type TARGET_TRAITS	is record
			  E_MACHINE	: INTEGER;						--| 62 / 183 / 243
			  ORIG		: INTEGER;						--| 16#400000#
			  ENTRY_POINT	: INTEGER;						--| 16#400078#
			  PAD_BYTE	: INTEGER;						--| remplissage align_* : 16#90# x86, 0 sinon (byte-diff !)
			  CALL_FRAME	: INTEGER;						--| micro-pile par CALL : 8 x86, 16 arm/riscv (alignement SP)
			  MEMSZ_RESERVE	: LONG_INTEGER;						--| reserve co-pile au dessus du code (p_memsz)
			  PROLOGUE_SIZE	: INTEGER;						--| amorcage (codi queue) : 82 x86, 92 arm
			  BRA_SIZE	: INTEGER;						--| taille du BRA de BEGIN_BLOC_DEF : 5 x86, 4 arm
      --  numeros de syscalls (openat/unlinkat cote arm et riscv), constantes ioctl, etc.
			end record;

  --| Une constante TRAITS par cible, initialisee dans EMIT (corps separate).


			---
  package			LEX
  is			---

    --| P0 : flot de lignes du .fas et de ses includes (repertoire courant =
    --| ADA__LIB), LF seul, CR/FF neutralises, tabulations libres. Une
    --| invocation par ligne ; vocabulaire CLOS (NOTE v1 par 1).
    --|
    --| Effets STRUCTURELS executes AU PARSING : namespaces (litteraux et
    --| ouverts par PRO/endPRO), labels, gardes n 97 (NAME = '...'),
    --| STR/CST (declaration CONSTANT_ADDR + enregistrement differe LIFO),
    --| gardes "~ definite" (inclusion unique : bloc saute si defini).
    --| Les gardes "defined" ne sont JAMAIS evaluees a P0 : condition
    --| d'atteignabilite enregistree dans l'IR, filtree en P2/P3.
    --| Les OPERANDES restent du texte non resolu jusqu'a P2.

    LEX_FAULT		: exception;								--| refus bruyant (doctrine R6)

    TEXT_MAX		: constant	:= 50_000_000;

    type SLICE		is record
			  F	: NATURAL	:= 0;							--| tranche dans la reserve de texte
			  L	: NATURAL	:= 0;							--| F = 0 ou L < F : tranche vide
			end record;

    function  IMAGE		( S :SLICE )			return STRING;
    function  POOL_STRING	( S :STRING )			return SLICE;				--| pour les temoins et outils

    procedure RUN_P0	( FAS_NAME :STRING );							--| parse tout, alimente SYMBOLS et IR

    function  EVAL		( S :SLICE )			return LONG_INTEGER;			--| + - * / mod, parentheses ; noms resolus

    function  TEXT_USED					return NATURAL;				--| jauge : occupation de la reserve de texte
												--| BRUYAMMENT via SYMBOLS (usage : P2)
	---
  end	LEX;
	---


			-------
  package			SYMBOLS
  is			-------
    --| Arbre de portees calque sur fasmg : "namespace X" ouvre — ou ROUVRE,
    --| cumulativement (STANDARD en tete de chaque FINC) — le fils X du scope
    --| courant. RESOLUTION D'UN NOM NON POINTE = portee courante puis
    --| REMONTEE DES PARENTS UNIQUEMENT — JAMAIS les freres (piege n 105 ;
    --| l'expander emet REGIONS_PATH en s'y fiant : tout ecart casse des FINC
    --| valides). Nom pointe = premier composant par remontee, puis descente.
    --|
    --| Layout (P2) — MIROIR DE LAYOUT, piege n 110 : TARGET_CODE est la
    --| TROISIEME implementation du calcul d'alignement (fasmg,
    --| ALIGN_STATIC_BITS, ici) ; test-miroir obligatoire. Zones EMPILABLES
    --| (la VARzone ouverte par ELB peut contenir des virtual at 0).
    --|
    --| Atteignabilite (P1) : remplace le lazy fasmg (postpone + ~definite,
    --| qui exigeait structurellement le multi-passes). MARK pose
    --| PREFIX.SUBNAME_ (classe LAZY_MARK) ; les gardes "if defined X_" de
    --| l'IR s'evaluent via IS_DEFINED ; point fixe pilote par P1 sur la
    --| croissance de REACH_COUNT (ensemble fini croissant : terminaison
    --| garantie, sans rapport avec les adresses).

    SYMBOL_FAULT		: exception;								--| refus bruyant (doctrine R6)

    subtype VALUE_TYPE	is LONG_INTEGER;								--| INTEGER TLALOC = 64 bits

    type SYM_CLASS		is ( SCOPE_NAME,								--| namespace (ouvre un scope)
			     CODE_LABEL,								--| label:, elab, post, ret_lbl (adresse posee en P2)
			     FRAME_OFFSET,								--| VAR _disp, USEINFO __u  (VARzone, base 8)
			     PARAM_OFFSET,								--| PRM _ofs  (PRMzone, base 8)
			     STATIC_OFFSET,								--| STATOFS   (virtual at 0)
			     CONSTANT_ADDR,								--| STR / CST (adresse posee en P2, zone differee)
			     GUARD,								--| NAME = 'NAME' (n 97) — redefinissable
			     LAZY_MARK,								--| PREFIX.SUBNAME_ (atteignabilite)
			     PLAIN_VALUE );								--| affectation quelconque — redefinissable

    SYM_MAX		:constant			:= 1_048_576;
    type SYM_ID		is range 0 .. SYM_MAX;
    NO_SYM		:constant SYM_ID		:= 0;

    SCOPE_MAX		:constant			:= 65_536;
    type SCOPE_ID		is range 0 .. SCOPE_MAX;
    ROOT_SCOPE		:constant SCOPE_ID		:= 1;


  --				P O R T E E S

    procedure ENTER_SCOPE	( NAME :STRING );								--| ouvre ou ROUVRE le fils NAME du scope courant
    procedure LEAVE_SCOPE;
    function  CURRENT_SCOPE					return SCOPE_ID;				--| memorise par l'IR sur chaque element
    procedure USE_SCOPE	( S :SCOPE_ID );								--| repositionnement en P1/P2/P3


  --				D E C L A R A T I O N S   R E S O L U T I O N S

    procedure DECLARE_SYM	( NAME :STRING; CLASS :SYM_CLASS; VALUE :VALUE_TYPE := 0 );
    function  DECLARE_SYM	( NAME :STRING; CLASS :SYM_CLASS; VALUE :VALUE_TYPE := 0 ) return SYM_ID;
    procedure SET_VALUE	( S :SYM_ID; VALUE :VALUE_TYPE );						--| adresses et tailles posees en P2
    function  RESOLVE	( DOTTED :STRING ) 			return SYM_ID;				--| leve SYMBOL_FAULT si introuvable
    function  TRY_RESOLVE	( DOTTED :STRING )			return SYM_ID;				--| NO_SYM si introuvable (defined / ~definite)
    function  IS_DEFINED	( DOTTED :STRING )			return BOOLEAN;
    function  CLASS_OF	( S :SYM_ID )			return SYM_CLASS;
    function  VALUE_OF	( S :SYM_ID )			return VALUE_TYPE;				--| leve si valeur non posee (garde anti bug de phase)
    function  SCOPE_UNDER	( S :SYM_ID )			return SCOPE_ID;				--| scope OUVERT par S (classe SCOPE_NAME)
    procedure SET_EPOCH	( N :NATURAL );								--| epoque des boucles d'elements (TC-24)


  --				Z O N E S   D E   L A Y O U T

    procedure OPEN_ZONE	( BASE :VALUE_TYPE );
    procedure ZONE_ALIGN	( ALGN :VALUE_TYPE );							--| padding VIRTUEL (les octets 90/00 : affaire d'EMIT)
    procedure ZONE_RESERVE	( SIZE :VALUE_TYPE );
    function  ZONE_POS					return VALUE_TYPE;				--| le "$" fasmg de la zone courante
    function  CLOSE_ZONE					return VALUE_TYPE;				--| position finale (prm_siz/loc_siz ajustes par l'appelant)


  --				A T T E I G N A B I L I T E

    procedure MARK		( PREFIX, SUBNAME :STRING );							--| declare PREFIX.SUBNAME_ si absente
    function  REACH_COUNT					return NATURAL;				--| croissance => continuer le point fixe


  --				C A R T O

    procedure DUMP_MAP;										--| sous GENERATE_BINARY_MAP

  --				J A U G E S

    function  POOL_USED					return NATURAL;				--| jauges capacites (TC-22)
    function  POOL_CAPACITY					return NATURAL;				--| borne du pool (declaree au corps)
    function  SYM_COUNT					return NATURAL;
    function  SCOPE_COUNT					return NATURAL;

	-------
  end	SYMBOLS;
	-------


			--
  package			IR
  is			--

    --| Liste sequentielle des elements entre P0 et P3. Chaque element est
    --| estampille a sa creation : scope courant et garde lazy courante
    --| (condition d'atteignabilite ; tranche vide = inconditionnel). Les
    --| corps sous "if defined" sont PRESENTS, filtres en P2/P3.
    --| Differes (STR/CST) en ordre d'enregistrement ; emission en ordre
    --| INVERSE (LIFO fasmg, releve DIS_BONJOUR) juste apres le code ;
    --| ASM_SIZE en tout dernier. TAILLE et ADRESSE par element : champs
    --| poses en P2 (livraison TC-03).

    IR_FAULT		: exception;								--| refus bruyant (doctrine R6)

    ELT_MAX		:constant			:= 5_000_000;					--| 1_000_000 atteint par l'autocompilation (expandeur, nov. 2026)
    type ELT_ID		is range 0 .. ELT_MAX;

    OPS_MAX		:constant			:= 7_500_000;					--| suit ELT_MAX
    DEFER_MAX		:constant			:= 200_000;

    type ELT_KIND		is ( MACRO_CALL,								--| toute macro LLIR (y compris STATOFS, db...)
			     LABEL_DEF,								--| "nom:"
			     ASSIGNMENT,								--| "X = expr" hors garde n 97 (evaluee en P2)
			     VIRT_OPEN,								--| "virtual at N"
			     VIRT_CLOSE,								--| "end virtual"
			     MAP_NOTE,								--| display / hexa_show (emis sous option)
			     AREA_DEF,								--| "nom::" : zone d'adressage (VARzone, tete .fas)
			     VIRT_REOPEN );								--| "virtual NOM" : reouverture de zone (queue .fas)

    type OPERAND_TAG	is ( EMPTY_OP, INT_OP, FLT_OP, NAME_OP, EXPR_OP, STRB_OP );

    --  construction (LEX, dans l'ordre du texte) ------------------------------------------------------------------
    procedure NEW_ELT	( KIND :ELT_KIND; MNEMO :LEX.SLICE );						--| estampille scope + garde lazy
    procedure ADD_OP	( TAG :OPERAND_TAG; TXT :LEX.SLICE;
			  IVAL :LONG_INTEGER := 0; FVAL :LONG_FLOAT := 0.0 );
    procedure SET_LAZY	( GUARD :LEX.SLICE );
    procedure CLEAR_LAZY;
    procedure DEFER_LAST;										--| STR/CST : enregistrement LIFO

    --  acces (P1, P2, P3, temoins) --------------------------------------------------------------------------------
    function  ELT_COUNT					return NATURAL;
    function  DEFER_COUNT					return NATURAL;
    function  DEFER_AT	( I :NATURAL )			return ELT_ID;
    function  KIND_OF	( E :ELT_ID )			return ELT_KIND;
    function  MNEMO_OF	( E :ELT_ID )			return LEX.SLICE;
    function  SCOPE_OF	( E :ELT_ID )			return SYMBOLS.SCOPE_ID;
    function  LAZY_OF	( E :ELT_ID )			return LEX.SLICE;
    function  N_OPS		( E :ELT_ID )			return NATURAL;
    function  OP_TAG	( E :ELT_ID; I :NATURAL )		return OPERAND_TAG;
    function  OP_TXT	( E :ELT_ID; I :NATURAL )		return LEX.SLICE;
    function  OP_INT	( E :ELT_ID; I :NATURAL )		return LONG_INTEGER;
    function  OP_FLT	( E :ELT_ID; I :NATURAL )		return LONG_FLOAT;

	--
  end	IR;
	--

			------
  package			PASSES
  is			------

    --| P1 : remplace le lazy fasmg (postpone + ~definite, qui exigeait le
    --| multi-passes). Point fixe sur les marques : les CALL/LSPA des
    --| elements ACTIFS posent PREFIX.SUBNAME_ ; un element est actif si sa
    --| garde lazy, evaluee DANS SON SCOPE estampille (lecon TC-02f), est
    --| definie. Ensemble fini croissant : terminaison garantie.
    --| P2 : layout, miroir n 110 (troisieme implementation). Regles :
    --| PRMzone base 8 (dq par PRM, prm_siz = $-8) ; VARzone base 8 a l'ELB
    --| (align par caractere b/w/d/q, taille litterale = octets + align_q,
    --| USEINFO reserve nom__u, loc_siz aligne q a endPRO) ; virtual at N +
    --| STATOFS (algn OCTETS 1/2/4/8, repli par taille si 0, reservation
    --| rb = octets), zones empilables. ELB declare elab, endPRO declare
    --| post (labels internes aux macros codi). Q7 : VARzone en modele PILE
    --| par frame — oracle DEBUG_LLIR (show loc_siz) pour trancher.
    --| Adresses et tailles d'instructions : TC-04 (EMITS.SIZE_OF).

    PASS_FAULT		: exception;								--| refus bruyant (doctrine R6)

    function  ACTIVE	( E :IR.ELT_ID )		return BOOLEAN;					--| garde lazy evaluee dans le scope de E
    procedure P1_REACH;
    procedure P2_LAYOUT	( FROM, TO :IR.ELT_ID );							--| par plage : rejouable (les labels de macro
												--| elab/post ne sont pas redefinissables)

	------
  end	PASSES;
	------


			-----
  package			EMITS
  is			-----

    --| Deux services par macro LLIR : SIZE_OF (P2B) et ENCODE (P3).
    --| CONTRAT : SIZE_OF ne depend JAMAIS d'une adresse non encore posee
    --| (formes canoniques — NOTE v1 par 2.5) ; P3 verifie octets emis =
    --| SIZE_OF a chaque element (refus bruyant sinon).
    --| Tranche TC-04, x86-64 seul : DROP DUP LI ADD SUB MUL BRA SYS_EXIT,
    --| en-tete ELF64 + Phdr, amorcage 82 octets, ASM_SIZE, ecriture du
    --| binaire (SEQUENTIAL_IO(CHARACTER)). Hors tranche : refus bruyant.
    --| Differes STR/CST (LIFO) : TC-05. Retarget (TRAITS par cible,
    --| ENCODE_ARM64 / ENCODE_RISCV64 a specification identique) :
    --| reintroduit une fois la table x86 complete.

    EMIT_FAULT		: exception;								--| refus bruyant (doctrine R6)

    procedure P2B_ADDRESSES	( FROM, TO :IR.ELT_ID );							--| adresses des elements ACTIFS de la plage ;
												--| labels poses ; ASM_SIZE ; assert < 2**32
    procedure P3_EMIT	( FROM, TO :IR.ELT_ID; BIN_NAME :STRING );					--| ELF + amorcage + code ; ecrit le binaire
    function  ASM_SIZE						return SYMBOLS.VALUE_TYPE;

    function  BIN_CAPACITY				return NATURAL;				--| jauge : borne du tampon binaire

	-----
  end	EMITS;
	-----


  --|  Conventions de nommage par cible. CODI_NAME : suffixe de l'include
  --|  codi que le .fas DOIT porter (controle croise dans LEX : la cible
  --|  choisie au lancement et celle declaree par le .fas ne divergent
  --|  jamais en silence). FAS_EXT / EXE_EXT : extensions du source et du
  --|  binaire (.fas x86 historique, .arm64fas, .riscv64fas).

			---------
  function		CODI_NAME				return STRING
  is			---------
  begin
    case  TARGET_CPU  is
      when X86_64  =>
        if  OS_NAME = "LINUX"  then
	return "x86_64L.finc";

        elsif  OS_NAME = "WINDOWS"  then
	return "x86_64W.finc";

        else return "x86_64.finc";
        end if;

      when ARM64   => return "arm64.finc";

      when RISCV64 => return "riscv64.finc";
    end case;
  end	CODI_NAME;
	---------

			-------
  function		FAS_EXT					return STRING
  is			-------
  begin
    case  TARGET_CPU  is
      when X86_64  =>
        if  OS_NAME = "LINUX"  then
	return ".X86_64LFAS";
        elsif  OS_NAME = "WINDOWS"  then
	return ".X86_64WFAS";
        else
	return ".X86_64FAS";
        end if;
      when ARM64   => return ".ARM64FAS";
      when RISCV64 => return ".RISCV64FAS";
    end case;

  end	FAS_EXT;
	-------

			-------
  function		EXE_EXT					return STRING
  is			-------
  begin
    case  TARGET_CPU  is
      when X86_64  => return ".x86exe";
      when ARM64   => return ".arm64exe";
      when RISCV64 => return ".riscv64exe";
    end case;

  end	EXE_EXT;
	-------


  package body		LEX		is separate;						--| target_code-lex.adb
  package body		SYMBOLS		is separate;						--| target_code-symbols.adb
  package body		IR		is separate;						--| target_code-ir.adb
  package body		PASSES		is separate;						--| target_code-passes.adb
  package body		EMITS		is separate;						--| target_code-emits.adb (+ encode_* en sous-unites)


  --			P I L O T E

begin
--  TARGET_CPU		:= CPU_KIND'VALUE( CPU_NAME );		-- L'expander ne prend pas ceci à voir
  if  CPU_NAME = "X86_64"  then TARGET_CPU := X86_64;
  elsif CPU_NAME = "ARM64"  then TARGET_CPU := ARM64;
  elsif CPU_NAME = "RISCV64"  then TARGET_CPU := RISCV64;
  end if;

  GENERATE_BINARY_MAP	:= MAP;

  if  UNIT_NAME'LENGTH > 0  then
    PUT( "Assembling [" & UNIT_NAME & ']' );
    LEX.RUN_P0( UNIT_NAME & FAS_EXT );
    PUT( '.' );

    PASSES.P1_REACH;
    PUT( '.' );

    PASSES.P2_LAYOUT( 1, IR.ELT_ID( IR.ELT_COUNT ) );
    PUT( '.' );

    EMITS.P2B_ADDRESSES( 1, IR.ELT_ID( IR.ELT_COUNT ) );
    PUT( '.' );

    EMITS.P3_EMIT( 1, IR.ELT_ID( IR.ELT_COUNT ), IDL.LIB_PATH( 1 .. IDL.LIB_PATH_LENGTH ) & UNIT_NAME & EXE_EXT );
    NEW_LINE;

    PUT_LINE( "CARTO capacites :" );
    PUT_LINE( "  elements " & NATURAL'IMAGE( IR.ELT_COUNT )
		& " /" & INTEGER'IMAGE( IR.ELT_MAX )
		& "   differes" & NATURAL'IMAGE( IR.DEFER_COUNT )
		& " /" & INTEGER'IMAGE( IR.DEFER_MAX ) );
    PUT_LINE( "  texte    " & NATURAL'IMAGE( LEX.TEXT_USED )
		& " /" & INTEGER'IMAGE( LEX.TEXT_MAX ) );
    PUT_LINE( "  symboles " & NATURAL'IMAGE( SYMBOLS.SYM_COUNT )
		& " /" & INTEGER'IMAGE( SYMBOLS.SYM_MAX )
		& "   scopes" & NATURAL'IMAGE( SYMBOLS.SCOPE_COUNT )
		& " /" & INTEGER'IMAGE( SYMBOLS.SCOPE_MAX ) );
    PUT_LINE( "  pool     " & NATURAL'IMAGE( SYMBOLS.POOL_USED )
		& " /" & NATURAL'IMAGE( SYMBOLS.POOL_CAPACITY ) );
    PUT_LINE( "  octets   " & SYMBOLS.VALUE_TYPE'IMAGE( EMITS.ASM_SIZE )
		& " /" & NATURAL'IMAGE( EMITS.BIN_CAPACITY ) );

  else
    PUT_LINE( "NOM VIDE" );
  end if;

end	TARGET_CODE;
	-----------
