--
--	T A R G E T _ C O D E . L E X
--
--	P0 complet : flot de lignes du .fas et de ses includes, classification,
--	effets STRUCTURELS immediats (namespaces, labels, gardes, PRO/endPRO,
--	STR/CST), alimentation de l'IR pour tout le reste. Les operandes restent
--	du TEXTE NON RESOLU jusqu'a P2 (calque du timing fasmg : les references
--	avant sont gratuites).
--
--	GARDES A DEUX REGIMES (arbitrage session du 17 aout) :
--	  - "if ~ definite NOM"  : evalue AU PARSING — inclusion unique (n 97) ;
--	    si NOM est defini, tout le bloc est SAUTE (comptage des if imbriques).
--	  - "if defined NOM_"    : JAMAIS evalue a P0 — le contenu est parse
--	    inconditionnellement et NOM_ est enregistre dans l'IR comme
--	    CONDITION D'ATTEIGNABILITE, filtree en P2/P3.
--
--	HYPOTHESE TLALOC (a confirmer par le temoin) : FLOAT_IO.GET( FROM :
--	STRING ; ... ) disponible pour les litteraux de LIF. Sinon, parseur
--	manuel a substituer.
--
-----------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2026 VINCENT MORIN, UBO
-- SPDX-License-Identifier: GPL-3.0-or-later
------------------------------------------------------------------------------------------------------------------------
--	1	2	3	4	5	6	7	8	9	0	1	2

with IDL;

separate ( TARGET_CODE )

					---
package body				LEX
is					---
  use IR;

  package FIO		is new FLOAT_IO( LONG_FLOAT );

  LEX_ABORT		: exception renames LEX_FAULT;

		--  reserve de texte (lexemes, operandes, gardes)

  TEXT			: STRING( 1 .. TEXT_MAX );
  TEXT_TOP		: NATURAL	:= 0;

		--  pile d'includes

  DEPTH_MAX		: constant	:= 64;
  FILES			: array ( 1 .. DEPTH_MAX ) of FILE_TYPE;
  FTOP			: NATURAL	:= 0;

		--  ligne courante

  LINE_MAX		: constant	:= 2000;
  LINE			: STRING( 1 .. LINE_MAX );
  LEN			: NATURAL	:= 0;
  POS			: NATURAL	:= 1;

		--  pile des gardes

  type GUARD_REGIME		is ( TAKEN,								--| ~definite faux : bloc pris, end if popera
			     SKIPPING,								--| ~definite vrai : bloc saute (inclusion unique)
			     LAZY );								--| defined : condition d'atteignabilite (IR)

  GSTACK_MAX		: constant	:= 32;
  GSTACK			: array ( 1 .. GSTACK_MAX ) of GUARD_REGIME;
  GNAMES			: array ( 1 .. GSTACK_MAX ) of SLICE;						--| nom de garde (regime LAZY)
  GTOP			: NATURAL	:= 0;
  SKIP_DEPTH		: NATURAL	:= 0;								--| if imbriques pendant un saut

		--  tampon d'operandes de la ligne

  OP_LINE_MAX		: constant	:= 8;
  TAGS			: array ( 1 .. OP_LINE_MAX ) of IR.OPERAND_TAG;
  TXTS			: array ( 1 .. OP_LINE_MAX ) of SLICE;
  IVALS			: array ( 1 .. OP_LINE_MAX ) of LONG_INTEGER;
  FVALS			: array ( 1 .. OP_LINE_MAX ) of LONG_FLOAT;
  NOPS			: NATURAL	:= 0;


			-----
  procedure		FAULT	( MSG :STRING )
  is			-----
  begin
    PUT_LINE( "TARGET_CODE.LEX : " & MSG );
    if  LEN > 0  then
      PUT_LINE( "  ligne : " & LINE( 1 .. LEN ) );
    end if;
    raise  LEX_ABORT;

  end	FAULT;
	-----

  -------------------------------------------------------------------------------------------------------------------
  --			reserve de texte
  -------------------------------------------------------------------------------------------------------------------
			-----
  function		STORE	( S :STRING )	return SLICE
  is			-----
    R			: SLICE;

  begin
    if  TEXT_TOP + S'LENGTH > TEXT_MAX  then
      FAULT( "reserve de texte pleine (TEXT_MAX)" );
    end if;

    TEXT( TEXT_TOP + 1 .. TEXT_TOP + S'LENGTH ) := S;
    R.F := TEXT_TOP + 1;
    R.L := TEXT_TOP + S'LENGTH;
    TEXT_TOP := TEXT_TOP + S'LENGTH;
    return  R;

  end	STORE;
	-----


			-----
  function		IMAGE		( S :SLICE )	return STRING
  is			-----
  begin
    if  S.F = 0  or  S.L < S.F  then
      return  "";
    end if;
    return  TEXT( S.F .. S.L );

  end	IMAGE;
	-----


			-----------
  function		POOL_STRING	( S :STRING )	return SLICE
  is			-----------
  begin
    return  STORE( S );
  end	POOL_STRING;
	-----------

  -------------------------------------------------------------------------------------------------------------------
  --			micro-lexique de la ligne
  -------------------------------------------------------------------------------------------------------------------

			------------
  function		IS_WORD_CHAR	( C :CHARACTER )	return BOOLEAN
  is			------------
  begin
    return  ( C in 'A' .. 'Z' )  or  ( C in 'a' .. 'z' )
	or ( C in '0' .. '9' )  or  ( C = '_' );

  end	IS_WORD_CHAR;
	------------


			------------
  function		IS_NAME_CHAR	( C :CHARACTER )	return BOOLEAN
  is			------------
  begin
    return  IS_WORD_CHAR( C )  or  ( C = '.' );				--| noms pointes

  end	IS_NAME_CHAR;
	------------


			-----------
  procedure		SKIP_BLANKS
  is			-----------
  begin
    while  POS <= LEN  and then  ( LINE( POS ) = ' '  or  LINE( POS ) = ASCII.HT )  loop
      POS := POS + 1;
    end loop;

  end	SKIP_BLANKS;
	-----------


			---------
  procedure		NEXT_WORD		( F, L :out NATURAL )					--| [A-Za-z0-9_]
  is			---------
  begin
    SKIP_BLANKS;
    F := POS;
    while  POS <= LEN  and then  IS_WORD_CHAR( LINE( POS ) )  loop
      POS := POS + 1;
    end loop;
    L := POS - 1;

  end	NEXT_WORD;
	---------


			---------
  procedure		NEXT_NAME		( F, L :out NATURAL )						--| [A-Za-z0-9_.]
  is			---------
  begin
    SKIP_BLANKS;
    F := POS;
    while  POS <= LEN  and then  IS_NAME_CHAR( LINE( POS ) )  loop
      POS := POS + 1;
    end loop;
    L := POS - 1;

  end	NEXT_NAME;
	---------


			---
  function		EQL	( F, L :NATURAL; S :STRING )	return BOOLEAN
  is
  begin
    if  L - F + 1 /= S'LENGTH  then
      return  FALSE;
    end if;
    return  LINE( F .. L ) = S;

  end	EQL;
	---

  -------------------------------------------------------------------------------------------------------------------
  --			operandes : decoupage et classification
  -------------------------------------------------------------------------------------------------------------------

			--------
  procedure		CLASSIFY		( A, B :NATURAL )
  is			--------

    HAS_DOT		: BOOLEAN		:= FALSE;
    PURE_NAME		: BOOLEAN		:= TRUE;
    V			: LONG_INTEGER;
    FV			: LONG_FLOAT;
    LST			: POSITIVE;
    NEG			: BOOLEAN		:= FALSE;
    I			: NATURAL;

  begin
    NOPS := NOPS + 1;
    if  NOPS > OP_LINE_MAX  then
      FAULT( "trop d'operandes sur la ligne" );
    end if;
    TAGS( NOPS )	:= IR.EMPTY_OP;
    TXTS( NOPS ).F	:= 0;
    TXTS( NOPS ).L	:= 0;
    IVALS( NOPS )	:= 0;
    FVALS( NOPS )	:= 0.0;

    if  A > B  then
      return;											--| operande VIDE (virgules conservees)
    end if;

    if  LINE( A ) = '''  or else  LINE( A ) = '"'  then							--| chaine quotee (' ou ") : le DOUBLAGE du
      declare											--| delimiteur actif est RESOLU ici - le STRB
        QC	:constant CHARACTER		:= LINE( A );						--| stocke les octets EFFECTIFS (TC-12) ;
        BUF	: STRING( 1 .. LINE_MAX );								--| l'autre delimiteur est un octet ordinaire
        N		: NATURAL			:= 0;
        I		: NATURAL;

      begin
        if  B <= A  or else  LINE( B ) /= QC  then
	FAULT( "chaine non close" );
        end if;

        I := A + 1;
        while  I <= B - 1  loop
	if  LINE( I ) = QC  then									--| forcement double (l'operande aurait clos sinon)
	    I := I + 1;
	  end if;
	  N := N + 1;
	  BUF( N ) := LINE( I );
	  I := I + 1;
	end loop;
	TAGS( NOPS ) := IR.STRB_OP;
	TXTS( NOPS ) := STORE( BUF( 1 .. N ) );
      end;
      return;
    end if;

    if  ( LINE( A ) in '0' .. '9' )
        or else ( LINE( A ) = '-'  and then  B > A  and then  LINE( A + 1 ) in '0' .. '9' )
    then
      for  I in A .. B  loop
        if  LINE( I ) = '.'  then
	HAS_DOT := TRUE;
        end if;
      end loop;

      if  HAS_DOT  then										--| flottant : IEEE 754 double a la charge d'EMITS
        FIO.GET( LINE( A .. B ), FV, LST );
	TAGS( NOPS )  := IR.FLT_OP;
	FVALS( NOPS ) := FV;
      else											--| entier 64 bits, parse manuel
        V := 0;
        I := A;
        if  LINE( I ) = '-'  then
	NEG := TRUE;
	I := I + 1;
        end if;

        while  I <= B  loop
	if  LINE( I ) not in '0' .. '9'  then
	  FAULT( "litteral entier mal forme" );
	end if;
	V := V * 10 - LONG_INTEGER( CHARACTER'POS( LINE( I ) ) - CHARACTER'POS( '0' ) );		--| cumul NEGATIF : -2**63 representable,
	I := I + 1;											--| +2**63 non (LONG_INTEGER'FIRST emis
        end loop;											--| en -09223372036854775808)

        if  not NEG  then
	V := -V;
        end if;

        TAGS( NOPS ) := IR.INT_OP;
        IVALS( NOPS ) := V;
      end if;
      return;
    end if;

    for  I in A .. B  loop
      if  not IS_NAME_CHAR( LINE( I ) )  then
        PURE_NAME := FALSE;
      end if;
    end loop;

    if  PURE_NAME  then
      TAGS( NOPS ) := IR.NAME_OP;
    else
      TAGS( NOPS ) := IR.EXPR_OP;									--| evalue en P2 par EVAL
    end if;
    TXTS( NOPS ) := STORE( LINE( A .. B ) );

  end	CLASSIFY;
	--------


			--------------
  procedure		PARSE_OPERANDS
  --| decoupe le reste de la ligne sur les virgules de profondeur zero, hors
  --| chaines ; un ';' hors chaine termine la ligne (commentaire)
  is			--------------

    A, B		: NATURAL;
    DEPTH		: NATURAL;
    INQ		: BOOLEAN;
    QC		: CHARACTER	:= ''';								--| delimiteur ACTIF de la chaine en cours
    C		: CHARACTER;
    DONE		: BOOLEAN		:= FALSE;

  begin
    NOPS := 0;
    SKIP_BLANKS;

    if  POS > LEN  or else  LINE( POS ) = ';'  then
      return;											--| aucun operande
    end if;

    loop
      SKIP_BLANKS;
      A := POS;
      DEPTH := 0;
      INQ := FALSE;
      while  POS <= LEN  loop
        C := LINE( POS );
        if  INQ  then
	if  C = QC  then
	  if  POS < LEN  and then  LINE( POS + 1 ) = QC  then
	    POS := POS + 1;										--| doublage : reste en chaine
	  else
	    INQ := FALSE;
	  end if;
	end if;

        elsif  C = '''  or else  C = '"'  then
	INQ := TRUE;
	QC  := C;

        elsif  C = '('  then
	DEPTH := DEPTH + 1;

        elsif  C = ')'  then
	if  DEPTH = 0  then
	  FAULT( "parenthese fermante en trop" );
	end if;
	DEPTH := DEPTH - 1;

        elsif  DEPTH = 0  and then  C = ','  then
	exit;
        elsif  DEPTH = 0  and then  C = ';'  then
	DONE := TRUE;
	exit;
        end if;
        POS := POS + 1;
      end loop;

      B := POS - 1;
      while  B >= A  and then  ( LINE( B ) = ' '  or  LINE( B ) = ASCII.HT )  loop
        B := B - 1;
      end loop;
      CLASSIFY( A, B );
      exit when  (DONE  or  POS > LEN)  or else  LINE( POS ) /= ',';
      POS := POS + 1;
    end loop;

  end	PARSE_OPERANDS;
	--------------


			-------------
  procedure		EMIT_OPERANDS
  is			-------------
  begin
    for  I in 1 .. NOPS  loop
      IR.ADD_OP( TAGS( I ), TXTS( I ), IVALS( I ), FVALS( I ) );
    end loop;

  end	EMIT_OPERANDS;
	-------------

  -------------------------------------------------------------------------------------------------------------------
  --			gardes
  -------------------------------------------------------------------------------------------------------------------
			---------
  procedure		SYNC_LAZY
  is			---------
  begin
  --| apres un pop : la garde lazy courante de l'IR est la plus haute LAZY
    for  I in reverse 1 .. GTOP  loop
      if  GSTACK( I ) = LAZY  then
        IR.SET_LAZY( GNAMES( I ) );
        return;
      end if;
    end loop;
    IR.CLEAR_LAZY;

  end	SYNC_LAZY;
	---------


			-----
  procedure		DO_IF
  is			-----

    F, L		: NATURAL;
    TILDE		: BOOLEAN	:= FALSE;

  begin
    if  GTOP = GSTACK_MAX  then
      FAULT( "gardes trop imbriquees (GSTACK_MAX)" );
    end if;

    SKIP_BLANKS;
    if  POS <= LEN  and then  LINE( POS ) = '~'  then
      TILDE := TRUE;
      POS := POS + 1;
    end if;

    NEXT_WORD( F, L );
    if  TILDE  then
      if  not EQL( F, L, "definite" )  then
	FAULT( "forme de garde inconnue apres ~" );
      end if;

      NEXT_NAME( F, L );
      GTOP := GTOP + 1;

      if  SYMBOLS.IS_DEFINED( LINE( F .. L ) )  then							--| inclusion unique : bloc SAUTE
	GSTACK( GTOP ) := SKIPPING;
	SKIP_DEPTH     := 1;
      else
	GSTACK( GTOP ) := TAKEN;
      end if;

    elsif  EQL( F, L, "defined" )  then									--| lazy : JAMAIS evalue a P0
      NEXT_NAME( F, L );
      GTOP := GTOP + 1;
      GSTACK( GTOP ) := LAZY;
      GNAMES( GTOP ) := STORE( LINE( F .. L ) );
      IR.SET_LAZY( GNAMES( GTOP ) );

    else
      FAULT( "forme de if non reconnue" );
    end if;

  end	DO_IF;
	-----


			---------
  procedure		DO_END_IF
  is			---------
  begin
    if  GTOP = 0  then
      FAULT( "end if sans if" );
    end if;

    GTOP := GTOP - 1;
    SYNC_LAZY;

  end	DO_END_IF;
	---------

  -------------------------------------------------------------------------------------------------------------------
  --			classification et traitement d'une ligne
  -------------------------------------------------------------------------------------------------------------------

			------------
  procedure		PROCESS_LINE
  is			------------

    WF, WL		: NATURAL;
    F2, L2		: NATURAL;

  begin
    POS := 1;
    for  I in 1 .. LEN  loop
      if  LINE( I ) = ASCII.CR  or  LINE( I ) = ASCII.FF  then
        LINE( I ) := ' ';
      end if;
    end loop;

    --  mode saut (inclusion unique) : seul le squelette if / end if compte
    if  GTOP > 0  and then  GSTACK( GTOP ) = SKIPPING  then
      NEXT_WORD( WF, WL );

      if  EQL( WF, WL, "if" )  then
        SKIP_DEPTH := SKIP_DEPTH + 1;

      elsif EQL( WF, WL, "end" )  then
        NEXT_WORD( F2, L2 );
        if  EQL( F2, L2, "if" )  then
	SKIP_DEPTH := SKIP_DEPTH - 1;
	if SKIP_DEPTH = 0  then
	  GTOP := GTOP - 1;
	  SYNC_LAZY;
	end if;
        end if;
      end if;

      return;
    end if;

    SKIP_BLANKS;
    if  POS > LEN  or else  LINE( POS ) = ';'  then
      return;											--| vide ou commentaire
    end if;

--    NEXT_WORD( WF, WL );
    NEXT_NAME( WF, WL );										-- Cas label compose : LD_ENUM.elab
    if  WL < WF  then
      FAULT( "ligne non reconnue" );
    end if;

    --  label ?  ("nom:" = label de code ; "nom::" = zone d'adressage)
    if  POS <= LEN  and then  LINE( POS ) = ':'  then

      POS := POS + 1;
      if  POS <= LEN  and then  LINE( POS ) = ':'  then							--| "nom::" (VARzone de la tete canonique) :
        POS := POS + 1;										--| genre dedie, traite en P2 (frame de niveau 0)
        IR.NEW_ELT( IR.AREA_DEF, STORE( LINE( WF .. WL ) ) );

      else
        declare
	DOT	: NATURAL	:= 0;
        begin
	for  I in WF .. WL  loop
	  if  LINE( I ) = '.'  then
	    DOT := I;
	    exit;
	  end if;
	end loop;

	if  DOT = 0  then
	  SYMBOLS.DECLARE_SYM( LINE( WF .. WL ), SYMBOLS.CODE_LABEL );

	else
	  SYMBOLS.ENTER_SCOPE( LINE( WF .. DOT - 1 ) );
	  SYMBOLS.DECLARE_SYM( LINE( DOT + 1 .. WL ), SYMBOLS.CODE_LABEL );
	  SYMBOLS.LEAVE_SCOPE;
	end if;

	IR.NEW_ELT( IR.LABEL_DEF, STORE( LINE( WF .. WL ) ) );
        end;

      end if;
      return;

    end if;

    --  affectation ?
    SKIP_BLANKS;
    if  POS <= LEN  and then  LINE( POS ) = '='  then
      POS := POS + 1;
      SKIP_BLANKS;

      if  POS <= LEN  and then  LINE( POS ) = '''  then							--| garde n 97 : seul "defini" compte
        SYMBOLS.DECLARE_SYM( LINE( WF .. WL ), SYMBOLS.GUARD );

      else											--| affectation generale : IR, evaluee en P2
        IR.NEW_ELT( IR.ASSIGNMENT, STORE( LINE( WF .. WL ) ) );
        IR.ADD_OP( IR.EXPR_OP, STORE( LINE( POS .. LEN ) ), 0, 0.0 );
      end if;

      return;
    end if;

    --  directives fasmg-natives
    if  EQL( WF, WL, "namespace" )  then
      NEXT_NAME( F2, L2 );
      SYMBOLS.ENTER_SCOPE( LINE( F2 .. L2 ) );
      return;
    end if;

    if  EQL( WF, WL, "end" )  then
      NEXT_WORD( F2, L2 );

      if  EQL( F2, L2, "namespace" )  then
        SYMBOLS.LEAVE_SCOPE;

      elsif  EQL( F2, L2, "if" )  then
        DO_END_IF;

      elsif EQL( F2, L2, "virtual" )  then
        IR.NEW_ELT( IR.VIRT_CLOSE, STORE( "end virtual" ) );

      else
	FAULT( "end inconnu" );
      end if;

      return;
    end if;

    if  EQL( WF, WL, "include" )  then
      SKIP_BLANKS;
      if  POS > LEN  or else  LINE( POS ) /= '''  then
        FAULT( "include sans nom quote" );
      end if;

      F2 := POS + 1;
      L2 := F2;

      while  L2 <= LEN  and then  LINE( L2 ) /= '''  loop
        L2 := L2 + 1;
      end loop;

      if  L2 > LEN  then
        FAULT( "nom d'include non clos" );
      end if;

      if  L2 - F2 >= 30  and then  LINE( F2 .. F2 + 29 ) = "../../src/expander/fasmg/codi_"  then			--| le codi est l'IMPLEMENTATION de TARGET_CODE,
        if  LINE( F2 + 30 .. L2 - 1 ) /= CODI_NAME  then							--| ... de la cible CHOISIE : un .fas qui declare
          FAULT( "include codi_" & LINE( F2 + 30 .. L2 - 1 )						--| un autre codi est refuse (jamais un binaire
		 & " : cible choisie " & CPU_KIND'IMAGE( TARGET_CPU ) );					--| arm pour un .fas x86, ni l'inverse)
        end if;
        return;											--| internalisee : ne jamais le parser (TC-04) ;
      end if;											--| fasmg, lui, lit cet include — meme .fas, deux
												--| assembleurs, oracle cmp.
      if  FTOP = DEPTH_MAX  then
        FAULT( "includes trop imbriques (DEPTH_MAX)" );
      end if;

      FTOP := FTOP + 1;

      begin
        OPEN( FILES( FTOP ), IN_FILE, IDL.LIB_PATH( 1 .. IDL.LIB_PATH_LENGTH ) & LINE( F2 .. L2 - 1 ) );		--| repertoire LIB_PATH
      exception
        when NAME_ERROR =>
	FTOP := FTOP - 1;
	FAULT( "include introuvable : " & IDL.LIB_PATH( 1 .. IDL.LIB_PATH_LENGTH ) & LINE( F2 .. L2 - 1 ) );
      end;
      return;
    end if;

    if  EQL( WF, WL, "if" )  then
      DO_IF;
      return;
    end if;

    if  EQL( WF, WL, "virtual" )  then
      NEXT_WORD( F2, L2 );										--| "at" ou nom de zone
      if  EQL( F2, L2, "at" )  then
        IR.NEW_ELT( IR.VIRT_OPEN, STORE( "virtual" ) );
        PARSE_OPERANDS;										--| la base (0 ou 8)
        EMIT_OPERANDS;

      else											--| "virtual NOM" : reouverture de zone (queue du
        if  L2 < F2	 then										--| .fas reel : virtual VARzone / loc_siz = $)
	FAULT( "virtual sans at ni nom de zone" );
        end if;
        IR.NEW_ELT( IR.VIRT_REOPEN, STORE( "virtual" ) );
        IR.ADD_OP( IR.NAME_OP, STORE( LINE( F2 .. L2 ) ) );

      end if;

      return;
    end if;

    if  EQL( WF, WL, "display" )  or else  EQL( WF, WL, "hexa_show" )  then					--| carto : conserve brut, emis sous option
      IR.NEW_ELT( IR.MAP_NOTE, STORE( LINE( WF .. LEN ) ) );
      return;
    end if;

    --  macro LLIR (vocabulaire clos ; l'inconnu se paiera bruyamment en P2/P3)
    PARSE_OPERANDS;
    if  EQL( WF, WL, "PRO" )  then									--| ouvre le namespace du sous-programme
      if  NOPS < 1  or else  TAGS( 1 ) /= IR.NAME_OP  then
        FAULT( "PRO sans nom" );
      end if;
      SYMBOLS.ENTER_SCOPE( IMAGE( TXTS( 1 ) ) );
      IR.NEW_ELT( IR.MACRO_CALL, STORE( LINE( WF .. WL ) ) );
      EMIT_OPERANDS;

    elsif EQL( WF, WL, "endPRO" )  then
      IR.NEW_ELT( IR.MACRO_CALL, STORE( LINE( WF .. WL ) ) );
      EMIT_OPERANDS;
      SYMBOLS.LEAVE_SCOPE;

    elsif  EQL( WF, WL, "STR" )  or else  EQL( WF, WL, "CST" )  then						--| constante differee : LIFO (releve DIS_BONJOUR)
      if  NOPS < 1  or else  TAGS( 1 ) /= IR.NAME_OP  then
        FAULT( "STR/CST sans nom" );
      end if;

      if  EQL( WF, WL, "STR" )  then									--| STR = NAMESPACE : data_ptr/info_ptr/info/data
	SYMBOLS.ENTER_SCOPE( IMAGE( TXTS( 1 ) ) );							--| + statiques SIZ/COMP_SIZ/FST_1/LST_1 (0/4/8/12)
	SYMBOLS.DECLARE_SYM( "data_ptr", SYMBOLS.CODE_LABEL );
	SYMBOLS.DECLARE_SYM( "info_ptr", SYMBOLS.CODE_LABEL );
	SYMBOLS.DECLARE_SYM( "info",     SYMBOLS.CODE_LABEL );
	SYMBOLS.DECLARE_SYM( "data",     SYMBOLS.CODE_LABEL );
	SYMBOLS.DECLARE_SYM( "SIZ",      SYMBOLS.STATIC_OFFSET,  0 );
	SYMBOLS.DECLARE_SYM( "COMP_SIZ", SYMBOLS.STATIC_OFFSET,  4 );
	SYMBOLS.DECLARE_SYM( "FST_1",    SYMBOLS.STATIC_OFFSET,  8 );
	SYMBOLS.DECLARE_SYM( "LST_1",    SYMBOLS.STATIC_OFFSET, 12 );
	SYMBOLS.LEAVE_SCOPE;

      else
        SYMBOLS.DECLARE_SYM( IMAGE( TXTS( 1 ) ), SYMBOLS.CONSTANT_ADDR );
      end if;
      IR.NEW_ELT( IR.MACRO_CALL, STORE( LINE( WF .. WL ) ) );
      EMIT_OPERANDS;
      IR.DEFER_LAST;

    elsif  EQL( WF, WL, "USEINFO" )  then								--| EXPANSION a la fasmg : (1) element USEINFO
      if  NOPS < 3											--| reduit a lvl, nom - le layout de P2 ; (2) la
	 or else  TAGS( 1 ) /= IR.INT_OP								--| charge (ops 3.., rejoints par ", ") re-parsee
	 or else  TAGS( 2 ) /= IR.NAME_OP								--| en element ordinaire ; (3) "Sa lvl, nom__u"
      then											--| synthetise. EMITS n'a rien a apprendre.
        FAULT( "forme USEINFO inattendue (lvl entier, nom, charge)" );
      end if;

      declare
        L1TXT	:constant SLICE	  	:= TXTS( 1 );
        L1INT	:constant LONG_INTEGER	:= IVALS( 1 );
        NAME2	:constant SLICE		:= TXTS( 2 );
        N		: NATURAL			:= 0;

      begin
        IR.NEW_ELT( IR.MACRO_CALL, STORE( LINE( WF .. WL ) ) );
        IR.ADD_OP( TAGS( 1 ), TXTS( 1 ), IVALS( 1 ), FVALS( 1 ) );
        IR.ADD_OP( TAGS( 2 ), TXTS( 2 ), IVALS( 2 ), FVALS( 2 ) );

        for  I in 3 .. NOPS  loop								--| reconstruire la ligne de charge dans LINE
	if  TAGS( I ) /= IR.EXPR_OP  and  TAGS( I ) /= IR.NAME_OP  then
	  FAULT( "charge USEINFO hors corpus (texte attendu)" );
	end if;

	declare
	  P		: constant STRING := IMAGE( TXTS( I ) );
	begin
	  if I > 3  then
	    LINE( N + 1 .. N + 2 ) := ", ";
	    N := N + 2;
	  end if;
	  LINE( N + 1 .. N + P'LENGTH ) := P;
	  N := N + P'LENGTH;
	end;
        end loop;
        LEN := N;											--| la ligne d'origine est consommee : reutilisable
        POS := 1;
        NEXT_WORD( WF, WL );
        PARSE_OPERANDS;
        IR.NEW_ELT( IR.MACRO_CALL, STORE( LINE( WF .. WL ) ) );
        EMIT_OPERANDS;
        IR.NEW_ELT( IR.MACRO_CALL, STORE( "SA" ) );							--| le rangement de la macro codi
        IR.ADD_OP( IR.INT_OP, L1TXT, L1INT, 0.0 );							--| litteral INT_OP : contournement TLALOC
												--| (constante d'enumere dynamique en actuel =
												--| raise idl.adb:432, SM_VALUE non entier ;
												--| temoin de bissection : enumcst_test.adb) ;
												--| le corpus garantit lvl entier (garde ci-dessus)
        IR.ADD_OP( IR.NAME_OP, STORE( IMAGE( NAME2 ) & "__u" ) );
      end;

    else
      IR.NEW_ELT( IR.MACRO_CALL, STORE( LINE( WF .. WL ) ) );
      EMIT_OPERANDS;
    end if;

  end	PROCESS_LINE;
	------------

  -------------------------------------------------------------------------------------------------------------------
  --			pilote P0
  -------------------------------------------------------------------------------------------------------------------

			------
  procedure		RUN_P0		( FAS_NAME :STRING )
  is			------
  begin
    FTOP := 1;

    begin
      OPEN( FILES( 1 ), IN_FILE, IDL.LIB_PATH( 1 .. IDL.LIB_PATH_LENGTH ) & FAS_NAME );
    exception
      when  NAME_ERROR =>
        FTOP := 0;
        FAULT( "source introuvable : " & IDL.LIB_PATH( 1 .. IDL.LIB_PATH_LENGTH ) & FAS_NAME );
    end;

    while  FTOP > 0  loop
      if   END_OF_FILE( FILES( FTOP ) )  then
        CLOSE( FILES( FTOP ) );
        FTOP := FTOP - 1;
      else
        GET_LINE( FILES( FTOP ), LINE, LEN );
        PROCESS_LINE;
      end if;
    end loop;

    if  GTOP /= 0  then
      FAULT( "if sans end if a la fin des sources" );
    end if;

  end	RUN_P0;
	------

  -------------------------------------------------------------------------------------------------------------------
  --			evaluateur d'expressions (P2) : + - * / mod, parentheses
  -------------------------------------------------------------------------------------------------------------------

			----
  function		EVAL		( S :SLICE )	return LONG_INTEGER
  is			----

    P			: NATURAL		:= S.F;
    R			: LONG_INTEGER;

		-----
    procedure	ESKIP
    is		----
    begin
      while  P <= S.L  and then  ( TEXT( P ) = ' '  or  TEXT( P ) = ASCII.HT )  loop
        P := P + 1;
      end loop;

    end	ESKIP;
	-----

    function	EXPR return LONG_INTEGER;

		----
    function	FACT		return LONG_INTEGER
    is		----

      V		: LONG_INTEGER	:= 0;
      F		: NATURAL;

    begin
      ESKIP;
      if  P > S.L  then
        FAULT( "expression tronquee : " & IMAGE( S ) );
      end if;

      if  TEXT( P ) = '-'  then
        P := P + 1;
        return  -FACT;
      end if;

      if  TEXT( P ) = '('  then
        P := P + 1;
        V := EXPR;
        ESKIP;
        if  P > S.L  or else  TEXT( P ) /= ')'  then
	FAULT( "parenthese non fermee : " & IMAGE( S ) );
        end if;
        P := P + 1;
        return  V;
      end if;

      if  TEXT( P ) in '0' .. '9'  then
        while  P <= S.L  and then  TEXT( P ) in '0' .. '9'  loop
	V := V * 10 + LONG_INTEGER( CHARACTER'POS( TEXT( P ) ) - CHARACTER'POS( '0' ) );
	P := P + 1;
        end loop;
        return  V;
      end if;

      if  IS_NAME_CHAR( TEXT( P ) )  then								--| nom (pointe) : resolution BRUYANTE en P2
        F := P;
        while  P <= S.L  and then  IS_NAME_CHAR( TEXT( P ) )  loop
	P := P + 1;
        end loop;

        if  TEXT( F .. P - 1 ) = "mod"  then
	FAULT( "mod sans operande gauche : " & IMAGE( S ) );
        end if;

        return SYMBOLS.VALUE_OF( SYMBOLS.RESOLVE( TEXT( F .. P - 1 ) ) );
      end if;

      FAULT( "caractere inattendu dans l'expression : " & IMAGE( S ) );
      return  0;								--| jamais atteint

    end	FACT;
	----

			----
    function		TERM		return LONG_INTEGER
    is			----

      V			: LONG_INTEGER	:= FACT;
      F			: NATURAL;

    begin
      loop
        ESKIP;
        exit when  P > S.L;
        if  TEXT( P ) = '*'  then
	P := P + 1;
	V := V * FACT;

        elsif TEXT( P ) = '/'  then
	P := P + 1;
	V := V / FACT;

        elsif TEXT( P ) = 'm'  and then  P + 2 <= S.L  and then  TEXT( P .. P + 2 ) = "mod"
	     and then  ( P + 3 > S.L  or else  not IS_NAME_CHAR( TEXT( P + 3 ) ) )
        then
	F := P;
	P := P + 3;
	V := V mod FACT;
        else
	exit;
        end if;
      end loop;

      return  V;

    end	TERM;
	----

			----
    function		EXPR	return LONG_INTEGER
    is			----

      V			: LONG_INTEGER	:= TERM;

    begin
      loop
        ESKIP;
        exit when  P > S.L;
        if  TEXT( P ) = '+'  then
	P := P + 1;
	V := V + TERM;
        elsif  TEXT( P ) = '-'  then
	P := P + 1;
	V := V - TERM;
        else
	exit;
        end if;
      end loop;
      return  V;

    end	EXPR;
	----

  begin
    R := EXPR;
    ESKIP;
    if  P <= S.L  then
      FAULT( "residu en fin d'expression : " & IMAGE( S ) );
    end if;
    return  R;

  end	EVAL;
	----


			---------
  function		TEXT_USED				return NATURAL
  is			---------
  begin
    return TEXT_TOP;
  end	TEXT_USED;
	---------


	---
end	LEX;
	---

------------------------------------------------------------------------------------------------------------------------
--	1	2	3	4	5	6	7	8	9	0	1	2
