------------------------------------------------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2026 VINCENT MORIN, UBO
-- SPDX-License-Identifier: GPL-3.0-or-later
------------------------------------------------------------------------------------------------------------------------
--	1	2	3	4	5	6	7	8	9	0	1	2

separate ( EXPANDER.DECLARATIONS )
				-----------
package body			TYPES_DECLS
				-----------
is

    procedure CODE_ENUMERATION_DECL		( TYPE_DECL :TREE );
    procedure CODE_INTEGER_DECL		( TYPE_DECL :TREE );
    procedure CODE_FIXED_DECL			( TYPE_DECL :TREE );
    procedure CODE_FLOAT_DECL			( TYPE_DECL :TREE );

    procedure CODE_RECORD_DECL		( TYPE_DECL :TREE );
    procedure CODE_CONSTRAINED_RECORD_DECL	( TYPE_NAME : TREE; TYPE_SPEC : TREE );
    procedure CODE_UNCONSTRAINED_ARRAY_DECL	( TYPE_DECL :TREE;  MARQUER :BOOLEAN := TRUE );
    procedure CODE_CONSTRAINED_ARRAY_DECL	( TYPE_DECL :TREE );
    procedure CODE_ACCESS_DECL		( TYPE_DECL :TREE );



			--^^^^^^^^^^^^^^--
  procedure		  CODE_TYPE_DECL		( TYPE_DECL :TREE )
  is			------------------

    TYPE_NAME	: TREE	:= D( AS_SOURCE_NAME, TYPE_DECL );
    TYPE_SPEC	: TREE	:= D( SM_TYPE_SPEC, TYPE_NAME );
  begin
				-- SCALAR TYPES

    if	 TYPE_SPEC.TY = DN_ENUMERATION	then  CODE_ENUMERATION_DECL	     ( TYPE_DECL );
    elsif  TYPE_SPEC.TY = DN_INTEGER		then  CODE_INTEGER_DECL	     ( TYPE_DECL );
    elsif  TYPE_SPEC.TY = DN_FIXED		then  CODE_FIXED_DECL	     ( TYPE_DECL );
    elsif  TYPE_SPEC.TY = DN_FLOAT		then  CODE_FLOAT_DECL	     ( TYPE_DECL );

				-- COMPOSITE TYPES

    elsif  TYPE_SPEC.TY = DN_RECORD		then  CODE_RECORD_DECL	     ( TYPE_DECL );
    elsif  TYPE_SPEC.TY = DN_CONSTRAINED_RECORD	then  CODE_CONSTRAINED_RECORD_DECL ( TYPE_NAME, TYPE_SPEC );
    elsif  TYPE_SPEC.TY = DN_ARRAY		then  CODE_UNCONSTRAINED_ARRAY_DECL( TYPE_DECL );
    elsif  TYPE_SPEC.TY = DN_CONSTRAINED_ARRAY	then  CODE_CONSTRAINED_ARRAY_DECL  ( TYPE_DECL );

				-- ACCESS TYPES

    elsif  TYPE_SPEC.TY = DN_ACCESS		then  CODE_ACCESS_DECL	     ( TYPE_DECL );

    elsif  TYPE_SPEC.TY = DN_CONSTRAINED_ACCESS  then
			--| type T is access R (e) : l'analyse donne un sous-type d'acces
			--| contraint d'une base anonyme.  Contrainte du designe evaluee
			--| UNE fois, controlee, rangee (<type>.__D_x) -- LRM 3.3.2, 3.7.2
      declare
        TYPE_STR	:constant STRING	:= '_' & PRINT_NAME( D( LX_SYMREP, TYPE_NAME ) );
        DES	: TREE		:= D( SM_DESIG_TYPE, TYPE_SPEC );
      begin
        DI( CD_LEVEL,    TYPE_SPEC, INTEGER( CODI.CUR_LEVEL ) );
        DB( CD_COMPILED, TYPE_SPEC, TRUE );
        PUT_LINE( TYPE_STR & " = '" & TYPE_STR & "'" );
        PUT_LINE( "namespace " & TYPE_STR );
        PUT_LINE( "VAR use__info, Q" );								-- patron d'acces (comme
        PUT_LINE( "VAR SIZ__, D" );									-- CODE_ACCESS_DECL) : lu par
        PUT_LINE( tab & "LVA" & tab & IMAGE( CODI.CUR_LEVEL ) & ", SIZ__" );				-- les actuels generiques
        PUT_LINE( tab & "SA"  & tab & IMAGE( CODI.CUR_LEVEL ) & ", use__info" );
        PUT_LINE( tab & "LI"  & tab & IMAGE( CODI.ADDR_SIZE * CODI.STORAGE_UNIT ) );
        PUT_LINE( tab & "SD"  & tab & IMAGE( CODI.CUR_LEVEL ) & ", SIZ__" );
        PUT_LINE( "VAR DESIG__u, Q" );
        PUT_LINE( tab & "LI" & tab & "0" );								-- designe anonyme : pas de patron
        PUT_LINE( tab & "SA" & tab & IMAGE( CODI.CUR_LEVEL ) & ", DESIG__u" );
        if  DES.TY = DN_CONSTRAINED_RECORD
	and then  not ( D( XD_SOURCE_NAME, DES ).TY = DN_SUBTYPE_ID
		    and then  D( SM_TYPE_SPEC, D( XD_SOURCE_NAME, DES ) ) = DES )
        then
	EXPRESSIONS.ELABORER_DISCRIMINANTS( DES );
        end if;
        PUT_LINE( "end namespace" );
      end;

			-- PRIVATE / LIMITED PRIVATE / INCOMPLETE TYPES

    elsif  TYPE_SPEC.TY = DN_PRIVATE  or  TYPE_SPEC.TY = DN_L_PRIVATE  then
				------------------------
				ANTICIPATE_PRIVATE_LEVEL:
      declare
        FULL_TYPE_SPEC	: TREE	:= D( SM_TYPE_SPEC, TYPE_SPEC );

      begin
        if  not (FULL_TYPE_SPEC.TY = DN_VOID)
	and then  not ( (FULL_TYPE_SPEC.TY = DN_PRIVATE)  or  (FULL_TYPE_SPEC.TY = DN_L_PRIVATE ))
	and then  not DB( CD_COMPILED, FULL_TYPE_SPEC )  then
	DI( CD_LEVEL, FULL_TYPE_SPEC, CODI.CUR_LEVEL );
        end if;
      end			ANTICIPATE_PRIVATE_LEVEL;
			------------------------

      if  CODI.DEBUG  then
        if  D( SM_TYPE_SPEC, TYPE_SPEC ) = TREE_VOID
        and then  D( SM_DERIVED, TYPE_SPEC ) /= TREE_VOID  then
			--| Seconde saveur : type DERIVE d'un prive (SM_TYPE_SPEC VOID,
			--| aucune completion a attendre).  Aucun descripteur propre a
			--| elaborer : representation du PARENT, le percage aval suit
			--| SM_DERIVED (regle unique).  L'ancien commentaire FINC
			--| << deferred to full type >> MENTAIT pour cette saveur.
	PUT_LINE( "; EXPANDER.DECLARATIONS.CODE_TYPE_DECL : skip DERIVE-de-PRIVE "
		& PRINT_NAME( D( LX_SYMREP, TYPE_NAME ) ) & " (representation du parent, percage via SM_DERIVED)" );

        else
	PUT_LINE( "; EXPANDER.DECLARATIONS.CODE_TYPE_DECL : skip PRIVATE "
		& PRINT_NAME( D( LX_SYMREP, TYPE_NAME ) ) & " (deferred to full type)" );
        end if;
      end if;

    elsif  TYPE_SPEC.TY = DN_INCOMPLETE  then
				---------------------------
				ANTICIPATE_INCOMPLETE_LEVEL:
      declare
        FULL_TYPE_SPEC	: TREE	:= D( XD_FULL_TYPE_SPEC, TYPE_SPEC );
      begin
        if  not (FULL_TYPE_SPEC.TY = DN_VOID)  and then  not DB( CD_COMPILED, FULL_TYPE_SPEC )  then
	DI( CD_LEVEL, FULL_TYPE_SPEC, CODI.CUR_LEVEL );
        end if;
      end			ANTICIPATE_INCOMPLETE_LEVEL;
			---------------------------
      if  CODI.DEBUG  then
        PUT_LINE(	"; EXPANDER.DECLARATIONS.CODE_TYPE_DECL : skip INCOMPLETE "
		& PRINT_NAME( D( LX_SYMREP, TYPE_NAME ) ) & " (deferred to full type)" );
      end if;

    else
      PUT_LINE( "; EXPANDER.DECLARATIONS.CODE_TYPE_DECL : TYPE_SPEC.TY ("
		& NODE_NAME'IMAGE( TYPE_SPEC.TY ) & " NON FAIT POUR ) "
		& PRINT_NAME( D( LX_SYMREP, TYPE_NAME ) )
	        );
    end if;

  end	  CODE_TYPE_DECL;
	--==============--


			---------------------
  procedure		CODE_ENUMERATION_DECL	( TYPE_DECL :TREE )
  is			---------------------

    TYPE_ID	: TREE		:= D( AS_SOURCE_NAME, TYPE_DECL );
    TYPE_SPEC	: TREE		:= D( SM_TYPE_SPEC, TYPE_ID );
    TYPE_STR	:constant STRING	:= '_' & PRINT_NAME( D( LX_SYMREP, TYPE_ID ) );
    BASE		: TREE		:= D( SM_BASE_TYPE, TYPE_SPEC );
    MAX_REP	: INTEGER		:= INTEGER'FIRST;
    MIN_REP	: INTEGER		:= INTEGER'LAST;

		-------------------
    procedure	CODE_ENUM_LITERAL_S		( ENUM_LITERAL_S :TREE )
    is
      ENUM_LITERAL_SEQ	: SEQ_TYPE	:= LIST ( ENUM_LITERAL_S );
      ENUM_LITERAL_ID	: TREE;
      LAST_LITERAL		: TREE;
    begin
      while  not IS_EMPTY( ENUM_LITERAL_SEQ )  loop
        POP( ENUM_LITERAL_SEQ, ENUM_LITERAL_ID );
        declare
	ENUM_ID_STR	:constant STRING	:= PRINT_NAME( D( LX_SYMREP, ENUM_LITERAL_ID ) );
	REP		: INTEGER		:= DI( SM_REP, ENUM_LITERAL_ID );
        begin
	if  MIN_REP > REP  then MIN_REP := REP; end if;
	if  MAX_REP < REP  then MAX_REP := REP; end if;
	if  ENUM_ID_STR /= "'""'"
	then  PUT_LINE( "db" & INTEGER'IMAGE( REP ) & "," & INTEGER'IMAGE( ENUM_ID_STR'LENGTH ) & ", """ & ENUM_ID_STR & """" );
	else  PUT_LINE( "db" & INTEGER'IMAGE( REP ) & "," & INTEGER'IMAGE( ENUM_ID_STR'LENGTH ) & ", ""'""""'""" );
	end if;
        end;
        LAST_LITERAL := ENUM_LITERAL_ID;
      end loop;
      DI( CD_LAST, ENUM_LITERAL_S, DI ( SM_REP, LAST_LITERAL ) );

  end	CODE_ENUM_LITERAL_S;
	-------------------

  begin
    DI( CD_LEVEL,	  TYPE_SPEC, INTEGER( CODI.CUR_LEVEL ) );
    DB( CD_COMPILED,  TYPE_SPEC, TRUE );

    if  BASE /= TREE_VOID  and then  BASE /= TYPE_SPEC  and then  BASE.TY = DN_ENUMERATION  then
			--| Enumeration DERIVEE CONTRAINTE (TYPE T IS NEW P RANGE A .. B, ou NEW S,
			--| S sous-type contraint) : SM_TYPE_SPEC (T) est un SOUS-TYPE de la base
			--| derivee anonyme, qui porte aussi le nom T.  La table des litteraux va
			--| dans _T__base (TYPE_INFO_STR de la base) ; _T est un patron de sous-type
			--| (FST, LST elaborees, PARENT__u) -- note conception_derives_contraints.
      DI( CD_LEVEL,    BASE, INTEGER( CODI.CUR_LEVEL ) );
      DB( CD_COMPILED, BASE, TRUE );
      declare
        BASE_STR	:constant STRING	:= TYPE_INFO_STR( BASE );				-- _T__base
        LVL_STR	:constant STRING	:= IMAGE( CODI.CUR_LEVEL );
        SIZE_CHAR	: CHARACTER	:= OPER_SIZ_CHAR( TYPE_SPEC );
        RNG		: TREE		:= D( SM_RANGE, TYPE_SPEC );
      begin
        PUT_LINE( BASE_STR & " = '" & BASE_STR & "'" );
        PUT_LINE( "namespace " & BASE_STR );
        PUT_LINE( "VAR use__info, Q" );
        PUT_LINE( "BEGIN_BLOC_DEF" );
        CODE_ENUM_LITERAL_S( D( SM_LITERAL_S, BASE ) );
        PUT_LINE( "END_BLOC_DEF " & IMAGE( DI( CD_IMPL_SIZE, BASE ) )
			& ',' & INTEGER'IMAGE( MIN_REP ) & ',' & INTEGER'IMAGE( MAX_REP ) );
        PUT_LINE( tab & "LCA" & tab & "SIZ" );
        PUT_LINE( tab & "SA" & tab & LVL_STR & ", use__info" );
        PUT_LINE( "end namespace");

        PUT_LINE( TYPE_STR & " = '" & TYPE_STR & "'" );					-- _T : patron de sous-type
        PUT_LINE( "namespace " & TYPE_STR );						-- (meme forme qu'ENUMERATION_SUBTYPE)
        PUT_LINE( "VAR use__info, Q" );
        PUT_LINE( "VAR SIZ__, D" );
        PUT_LINE( tab & "LVA" & tab & LVL_STR & ", SIZ__" );
        PUT_LINE( tab & "SA" & tab & LVL_STR & ", use__info" );
        PUT_LINE( "VAR FST, " & SIZE_CHAR );
        PUT_LINE( "VAR LST, " & SIZE_CHAR );
        PUT_LINE( tab & "LI" & tab & IMAGE( DI( CD_IMPL_SIZE, BASE ) ) );
        PUT_LINE( tab & "SD" & tab & LVL_STR & ", SIZ__" );
        EXPRESSIONS.CODE_EXP( D( AS_EXP1, RNG ) );
        PUT_LINE( tab & 'S' & SIZE_CHAR & tab & LVL_STR & ", FST" );
        EXPRESSIONS.CODE_EXP( D( AS_EXP2, RNG ) );
        PUT_LINE( tab & 'S' & SIZE_CHAR & tab & LVL_STR & ", LST" );
        PUT_LINE( "VAR PARENT__u, Q" );
        PUT_LINE( tab & "LA" & tab & LVL_STR & ", " & BASE_STR & ".use__info" );
        PUT_LINE( tab & "SA" & tab & LVL_STR & ", PARENT__u" );
        PUT_LINE( "end namespace" );
      end;
      return;
    end if;

    if  CODI.DEBUG  then NEW_LINE; PUT_LINE( tab50 & "; " & TYPE_STR & " ENUMERATION TYPE INFO" ); end if;

    PUT_LINE( TYPE_STR & " = '" & TYPE_STR & "'" );
    PUT_LINE( "namespace " & TYPE_STR );
    PUT_LINE( "VAR use__info, Q" );

    PUT_LINE( "BEGIN_BLOC_DEF" );
    CODE_ENUM_LITERAL_S( D( SM_LITERAL_S, TYPE_SPEC ) );
    PUT_LINE( "END_BLOC_DEF " & IMAGE( DI( CD_IMPL_SIZE, TYPE_SPEC ) )
			& ',' & INTEGER'IMAGE( MIN_REP ) & ',' & INTEGER'IMAGE( MAX_REP ) );

    if  CODI.DEBUG  then PUT( ASCII.HT & "; SIZ en bits !" ); end if;
    NEW_LINE;

    PUT_LINE( tab & "LCA" & tab & "SIZ" );								-- SIZ defini par END_BLOC_DEF
    PUT_LINE( tab & "SA" & tab & IMAGE( CODI.CUR_LEVEL ) & ", use__info" );

    PUT_LINE( "end namespace");

  end	CODE_ENUMERATION_DECL;
	---------------------


			-----------------
  procedure		CODE_INTEGER_DECL		( TYPE_DECL :TREE )
  is			-----------------

    TYPE_ID		: TREE		:= D( AS_SOURCE_NAME, TYPE_DECL );
    TYPE_STR		:constant STRING	:= '_' & PRINT_NAME( D( LX_SYMREP, TYPE_ID ) );
    INTEGER_SPEC		: TREE		:= D( SM_TYPE_SPEC, TYPE_ID );
    INT_RANGE		: TREE		:= D( SM_RANGE, INTEGER_SPEC );
    EXP_FST		: TREE		:= D( AS_EXP1, INT_RANGE );
    EXP_LST		: TREE		:= D( AS_EXP2, INT_RANGE );
    LVL_STR		:constant STRING	:= IMAGE( CODI.CUR_LEVEL );
    SIZE_CHAR		: CHARACTER	:= OPER_SIZ_CHAR( INTEGER_SPEC );

  begin
    DI( CD_LEVEL,	  INTEGER_SPEC, INTEGER( CODI.CUR_LEVEL ) );
    DI( CD_LEVEL,	  D( SM_BASE_TYPE, INTEGER_SPEC ), INTEGER( CODI.CUR_LEVEL  ) );
    DB( CD_COMPILED,  INTEGER_SPEC, TRUE );

    if  CODI.DEBUG  then  NEW_LINE; PUT_LINE( tab50 & "; " & TYPE_STR & " TYPE RANGE INFO" ); end if;

    PUT_LINE( TYPE_STR & " = '" & TYPE_STR & "'" );
    PUT_LINE( "namespace " & TYPE_STR );

    PUT_LINE( "VAR use__info, Q" );
    PUT_LINE( "VAR SIZ__, D" );									-- VAR taille de patron SIZ__
    PUT_LINE( tab & "LVA" & tab & LVL_STR & ", SIZ__" );							-- Adresse debut patron sur SIZ__
    PUT_LINE( tab & "SA" & tab & LVL_STR & ", use__info" );

    PUT_LINE( "VAR FST, " & SIZE_CHAR );
    PUT_LINE( "VAR LST, " & SIZE_CHAR );

    PUT_LINE( tab & "LI" & tab & IMAGE( DI( CD_IMPL_SIZE, INTEGER_SPEC ) ) );
    PUT_LINE( tab & "SD" & tab & LVL_STR & ", SIZ__" );							-- Taille du patron

    EXPRESSIONS.CODE_EXP( EXP_FST );
    PUT_LINE( tab & 'S' & SIZE_CHAR & tab & LVL_STR & ", FST" );

    EXPRESSIONS.CODE_EXP( EXP_LST );
    PUT_LINE( tab & 'S' & SIZE_CHAR & tab & LVL_STR & ", LST" );

    PUT_LINE( "end namespace" );

  end	CODE_INTEGER_DECL;
	-----------------


		--------------------
  procedure	EMIT_FIXED_TYPE_INFO	( SUBTYPE_STR, LVL_STR :STRING; TYPE_SPEC :TREE )
  is
    SIZE_CHAR	: CHARACTER	:= OPER_SIZ_CHAR( TYPE_SPEC );
    SMALL_VAL	: TREE		:= D( CD_IMPL_SMALL, TYPE_SPEC );	-- herite du parent tel quel (dump F-1)
    FIXED_RANGE	: TREE		:= D( SM_RANGE, TYPE_SPEC );		-- contrainte pliee du subtype_indication
    EXP_FST	: TREE		:= D( AS_EXP1, FIXED_RANGE );
    EXP_LST	: TREE		:= D( AS_EXP2, FIXED_RANGE );
  begin
	-- Bornes = SM_VALUE rationnels en unites du type (piege 71),
	-- scalees par la formule unique. Pas de PARENT__u : layout
	-- strictement identique a CODE_FIXED_DECL (SIZ, FST, LST, NUMER, DENOM).
    if  CODI.DEBUG  then NEW_LINE; PUT_LINE( tab50 & "; " & SUBTYPE_STR & " FIXED SUBTYPE INFO" ); end if;

    PUT_LINE( SUBTYPE_STR & " = '" & SUBTYPE_STR & "'" );
    PUT_LINE( "namespace " & SUBTYPE_STR );

    PUT_LINE( "VAR use__info, Q" );
    PUT_LINE( "VAR SIZ__, D" );
    PUT_LINE( tab & "LVA" & tab & LVL_STR & ", SIZ__" );
    PUT_LINE( tab & "SA" & tab & LVL_STR & ", use__info" );
    PUT_LINE( tab & "LI" & tab & IMAGE( DI( CD_IMPL_SIZE, TYPE_SPEC ) ) );
    PUT_LINE( tab & "SD" & tab & LVL_STR & ", SIZ__" );

    PUT_LINE( "VAR FST, " & SIZE_CHAR );
    PUT_LINE( "VAR LST, " & SIZE_CHAR );
    EXPRESSIONS.CODE_STATIC_FIXED_VALUE( D( SM_VALUE, EXP_FST ), TYPE_SPEC );
    PUT_LINE( tab & 'S' & SIZE_CHAR & tab & LVL_STR & ", FST" );
    EXPRESSIONS.CODE_STATIC_FIXED_VALUE( D( SM_VALUE, EXP_LST ), TYPE_SPEC );
    PUT_LINE( tab & 'S' & SIZE_CHAR & tab & LVL_STR & ", LST" );

    PUT_LINE( "VAR NUMER, Q" );
    PUT_LINE( "VAR DENOM, Q" );
    PUT_LINE( tab & "LI" & tab & PRINT_NUM( D( XD_NUMER, SMALL_VAL ) ) );
    PUT_LINE( tab & "SQ" & tab & LVL_STR & ", NUMER" );
    PUT_LINE( tab & "LI" & tab & PRINT_NUM( D( XD_DENOM, SMALL_VAL ) ) );
    PUT_LINE( tab & "SQ" & tab & LVL_STR & ", DENOM" );

    PUT_LINE( "end namespace" );

  end	EMIT_FIXED_TYPE_INFO;
	--------------------


			---------------
  procedure		CODE_FIXED_DECL		( TYPE_DECL :TREE )
  is			---------------

    TYPE_ID		: TREE		:= D( AS_SOURCE_NAME, TYPE_DECL );
    TYPE_STR		:constant STRING	:= '_' & PRINT_NAME( D( LX_SYMREP, TYPE_ID ) );
    FIXED_SPEC		: TREE		:= D( SM_TYPE_SPEC, TYPE_ID );
    LVL_STR		:constant STRING	:= IMAGE( CODI.CUR_LEVEL );

  begin
    DI( CD_LEVEL,	  FIXED_SPEC, INTEGER( CODI.CUR_LEVEL ) );
    DB( CD_COMPILED,  FIXED_SPEC, TRUE );

    EMIT_FIXED_TYPE_INFO( TYPE_STR, LVL_STR, FIXED_SPEC );

  end	CODE_FIXED_DECL;
	---------------


			---------------------
  procedure		EMIT_FLOAT_MODEL_INFO	( LVL_STR :STRING; TYPE_SPEC :TREE )
  is			---------------------
	--| Suite du bloc d'info flottant, apres LST : les grandeurs entieres du MODELE (LRM 3.5.7, 3.5.8),
	--| calculees a la compilation (UTILS.MODELE_FLOTTANT) ; NB_DIGITS car DIGITS est reserve.  Un corps generique PARTAGE en deduit les
	--| attributs d'un formel DIGITS <> par T__u (CODE_ATTRIBUTE, STANDARD._FLOAT_USE_INFO).
	--| Disposition identique a FLOAT_USE_INFO de _standrd.adb : SIZ, FST, LST, puis ces cinq entiers.

			----
    procedure		CHMP		( NOM :STRING; QUOI :CHARACTER )
    is			----
    begin
      PUT_LINE( "VAR " & NOM & ", D" );
      PUT_LINE( tab & "LI" & tab & IMAGE( MODELE_FLOTTANT( TYPE_SPEC, QUOI ) ) );
      PUT_LINE( tab & "SD" & tab & LVL_STR & ", " & NOM );
    end	CHMP;
	----

  begin
    CHMP( "NB_DIGITS",	   'D' );
    CHMP( "MANTISSA",	   'B' );
    CHMP( "SAFE_EMAX",	   'S' );
    CHMP( "BASE_DIGITS",   'd' );
    CHMP( "BASE_MANTISSA", 'b' );
  end	EMIT_FLOAT_MODEL_INFO;
	---------------------


			---------------
  procedure		CODE_FLOAT_DECL		( TYPE_DECL :TREE )
  is			---------------

    TYPE_ID		: TREE		:= D( AS_SOURCE_NAME, TYPE_DECL );
    TYPE_STR		:constant STRING	:= '_' & PRINT_NAME( D( LX_SYMREP, TYPE_ID ) );
    FLOAT_SPEC		: TREE		:= D( SM_TYPE_SPEC, TYPE_ID );
    SIZE_CHAR		: CHARACTER	:= OPER_SIZ_CHAR( FLOAT_SPEC );

  begin
    DI( CD_LEVEL,	  FLOAT_SPEC, INTEGER( CODI.CUR_LEVEL ) );
    DB( CD_COMPILED,  FLOAT_SPEC, TRUE );

    if  CODI.DEBUG  then  NEW_LINE; PUT_LINE( tab50 & "; " & TYPE_STR & " FLOAT TYPE INFO" ); end if;

    PUT_LINE( TYPE_STR & " = '" & TYPE_STR & "'" );
    PUT_LINE( "namespace " & TYPE_STR );

    PUT_LINE( "VAR use__info, Q" );

    PUT_LINE( "VAR SIZ__, D" );									-- VAR taille du patron
    PUT_LINE( "VAR FST, Q" );
    PUT_LINE( "VAR LST, Q" );

    declare
      FLOAT_RANGE	: TREE		:= D( SM_RANGE, FLOAT_SPEC );
      EXP_FST	: TREE		:= D( AS_EXP1, FLOAT_RANGE );
      EXP_LST	: TREE		:= D( AS_EXP2, FLOAT_RANGE );
      LVL_STR	:constant STRING	:= IMAGE( CODI.CUR_LEVEL );
    begin
      PUT_LINE( tab & "LVA" & tab & LVL_STR & ", SIZ__" );							-- Adresse debut de ptron
      PUT_LINE( tab & "SA"  & tab & LVL_STR & ", use__info" );

      PUT_LINE( tab & "LI" & tab & INTEGER'IMAGE( DI( CD_IMPL_SIZE, FLOAT_SPEC ) ) );
      PUT_LINE( tab & "SD" & tab & LVL_STR & ", SIZ__" );							-- Taille de patron

      EXPRESSIONS.CODE_EXP( EXP_FST );
      PUT_LINE( tab & "SQ" & tab & LVL_STR & ", FST" );

      EXPRESSIONS.CODE_EXP( EXP_LST );
      PUT_LINE( tab & "SQ" & tab & LVL_STR & ", LST" );

      EMIT_FLOAT_MODEL_INFO( LVL_STR, FLOAT_SPEC );						-- DIGITS .. BASE_MANTISSA
    end;

    PUT_LINE( "end namespace" );

  end	CODE_FLOAT_DECL;
	---------------


			-----------------------------
  procedure		CODE_UNCONSTRAINED_ARRAY_DECL		( TYPE_DECL :TREE;  MARQUER :BOOLEAN := TRUE )
  is			-----------------------------

    TYPE_ID		: TREE		:= D( AS_SOURCE_NAME, TYPE_DECL );
    TYPE_ID_STR		:constant STRING	:= '_' & PRINT_NAME( D( LX_SYMREP, TYPE_ID ) );
    TYPE_SPEC		: TREE		:= D( SM_TYPE_SPEC, TYPE_ID );
    INDEX_SUBTYPE_S		: SEQ_TYPE	:= LIST( D( SM_INDEX_S, TYPE_SPEC ) );
    DIM_NBR		: NATURAL		:= 1;
    TOTAL_DIMS		: NATURAL		:= 0;
    LVL			: LEVEL_NUM	renames CODI.CUR_LEVEL;
    LVL_STR		:constant STRING	:= IMAGE( LVL );

		---------------
    procedure	USEINFO_OFFSETS	( IDX_TYPE_LIST :in out SEQ_TYPE )
    is		---------------
      IDX_TYPE		: TREE;
      DIM_NBR_STR		:constant STRING	:= IMAGE( DIM_NBR );
    begin
      POP( IDX_TYPE_LIST, IDX_TYPE );

      declare
        IDX_TYPE_SPEC	: TREE		:= D( SM_TYPE_SPEC, IDX_TYPE );
        IDX_TYPE_NAME	: TREE		:= D( AS_NAME, IDX_TYPE );
        IDX_TYPE_DEFN	: TREE		:= D( SM_DEFN, IDX_TYPE_NAME );

      begin
        TOTAL_DIMS := TOTAL_DIMS + 1;

        if  not IS_EMPTY( IDX_TYPE_LIST )  then								-- Encore des dimensions
	DIM_NBR := DIM_NBR + 1;
	USEINFO_OFFSETS( IDX_TYPE_LIST );

	PUT_LINE( "SIZ_" & DIM_NBR_STR & " = $" );
	PUT_LINE( tab & "rd 1 " );
	PUT_LINE( "FST_" & DIM_NBR_STR & " = $" );
	PUT_LINE( tab & "rd 1 " );
	PUT_LINE( "LST_" & DIM_NBR_STR & " = $" );
	PUT_LINE( tab & "rd 1 " );

        else											-- Fini de parcourir les dimensions
	PUT_LINE( "COMP_SIZ = $" );
	PUT_LINE( tab & "rd 1 " );
	PUT_LINE( "FST_" & DIM_NBR_STR & " = $" );
	PUT_LINE( tab & "rd 1 " );
	PUT_LINE( "LST_" & DIM_NBR_STR & " = $" );
	PUT_LINE( tab & "rd 1 " );

        end if;

      end;
    end	USEINFO_OFFSETS;
	---------------

  begin
    if  MARQUER  then										--| FALSE : sous-type sans contrainte, noeud
      DI( CD_LEVEL,	  TYPE_SPEC, INTEGER( CODI.CUR_LEVEL ) );				--| PARTAGE avec le type de base
      DB( CD_COMPILED,  TYPE_SPEC, TRUE );
    end if;

    if  CODI.DEBUG  then NEW_LINE; PUT_LINE( tab50 & "; " & TYPE_ID_STR & " UNCONSTRAINED ARRAY SUBTYPE INFO" ); end if;
    PUT_LINE( TYPE_ID_STR & " = '" & TYPE_ID_STR & "'" );
    PUT_LINE( "namespace " & TYPE_ID_STR );

    PUT_LINE( "VAR use__info, Q" );
    PUT_LINE( "VAR SIZ__, D" );									-- VAR taille de patron
    PUT_LINE( tab & "LVA" & tab & LVL_STR & ", SIZ__" );							-- Adresse debut de patron
    PUT_LINE( tab & "SA" & tab & LVL_STR & ", use__info" );
    PUT_LINE( tab & "LI" & tab & '1' );
    PUT_LINE( tab & "NEG" );
    PUT_LINE( tab & "SD" & tab & LVL_STR & ", SIZ__" );							-- SIZ=-1 UNCONSTRAINED

    PUT( "  virtual at 4" );										-- Commence apres SIZ
    if  CODI.DEBUG  then  PUT_LINE( tab50 & "; use info offsets pour acces sur array contraint" ); end if;
    NEW_LINE;

    USEINFO_OFFSETS( INDEX_SUBTYPE_S );

    PUT_LINE( "  end virtual" );									-- Commence apres SIZ

    PUT_LINE( "end namespace" );

  end	CODE_UNCONSTRAINED_ARRAY_DECL;
	-----------------------------


		------------------
    procedure	STATIC_BOUND_VALUE  ( BOUND :TREE;  VAL :out INTEGER;  OK :out BOOLEAN )
    is		------------------
	-- Valeur statique d'une borne discrete. Piege n 95a AMENDE : le
	-- test de propriete (valeur statique presente) ne vaut que la ou
	-- la LECTURE est licite -- l'espece fixe son jeu d'attributs
	-- (diana.idl) et D est stricte. D'ou : case sur l'espece, chaque
	-- D(...) couvert. En particulier used_name_id / used_op ne portent
	-- PAS sm_value : on passe par sm_defn.

      DEFN	: TREE;

		-------------
      procedure	LIRE_SM_VALUE	( N :TREE;  V :out INTEGER;  FOUND :out BOOLEAN )
      is 		-------------
	-- Prerequis : l'espece de N porte sm_value.
	SV : TREE := D( SM_VALUE, N );
      begin
	if  SV.PT = HI  and then  SV.NOTY = DN_NUM_VAL  then
	  V := DI( SM_VALUE, N );			FOUND := TRUE;
	elsif  SV.TY = DN_NUM_VAL  then
	  V := INTEGER'VALUE( PRINT_NUM( SV ) );	FOUND := TRUE;
	else
	  V := 0;				FOUND := FALSE;
	end if;

      end LIRE_SM_VALUE;
	-------------


		--------------
      procedure	FOLD_BLTN_CALL	( FC :TREE;  V :out INTEGER;  FOUND :out BOOLEAN )
      is  	--------------
	-- Pliage minimal des operateurs PREDEFINIS entiers +, -, *
	-- (binaires et unaires) a operandes statiques : couvre les
	-- idiomes N-1, N+1, 2*N des bornes. La place DURABLE de ce
	-- pliage est SEM (LRM 4.9 : sm_value sur toute expression
	-- statique) ; ceci est le filet expander -- dette sem a solder.
	NAME	: TREE	:= D( AS_NAME, FC );
	DEFN	: TREE;
	PRM_S	: SEQ_TYPE;
	P1, P2	: TREE;
	V1, V2	: INTEGER;
	OK1, OK2  : BOOLEAN;
      begin
	V := 0;  FOUND := FALSE;

	if  NAME.TY /= DN_USED_OP  and then  NAME.TY /= DN_USED_NAME_ID  then
	  return;
	end if;
	DEFN := D( SM_DEFN, NAME );
	if  DEFN.TY /= DN_BLTN_OPERATOR_ID  then							-- jamais un "-" UTILISATEUR (meme garde que F-D)
	  return;
	end if;

	declare
	  OP : constant STRING := PRINT_NAME( D( LX_SYMREP, DEFN ) );
	begin
	  PRM_S := LIST( D( SM_NORMALIZED_PARAM_S, FC ) );
	  POP( PRM_S, P1 );
	  STATIC_BOUND_VALUE( P1, V1, OK1 );
	  if  not OK1  then  return;  end if;

	  if  IS_EMPTY( PRM_S )  then									-- unaire
	    if	OP = """-"""  then  V := -V1;  FOUND := TRUE;
	    elsif OP = """+"""  then  V :=  V1;  FOUND := TRUE;
	    end if;
	    return;
	  end if;

	  POP( PRM_S, P2 );
	  STATIC_BOUND_VALUE( P2, V2, OK2 );
	  if  not OK2  then  return;  end if;

	  if    OP = """+"""  then  V := V1 + V2;  FOUND := TRUE;
	  elsif OP = """-"""  then  V := V1 - V2;  FOUND := TRUE;
	  elsif OP = """*"""  then  V := V1 * V2;  FOUND := TRUE;
	  end if;						-- "/" exclu : troncature a valider avant
	end;

      end	FOLD_BLTN_CALL;
	--------------

    begin
      VAL := 0;
      OK  := FALSE;

      case  BOUND.TY  is

      when  DN_NUMERIC_LITERAL  |  DN_CONVERSION  |  DN_PARENTHESIZED  |  DN_FUNCTION_CALL =>			-- especes portant sm_value
	LIRE_SM_VALUE( BOUND, VAL, OK );
	if  OK  then  return;  end if;

	if  BOUND.TY = DN_CONVERSION  or else  BOUND.TY = DN_PARENTHESIZED  then
	  STATIC_BOUND_VALUE( D( AS_EXP, BOUND ), VAL, OK );						-- conversion entiere statique :
												-- valeur inchangee (LRM 4.6)
	elsif  BOUND.TY = DN_FUNCTION_CALL  then
	  FOLD_BLTN_CALL( BOUND, VAL, OK );
	end if;

      when  DN_USED_NAME_ID | DN_USED_OP								-- PAS de sm_value ici : via sm_defn
	| DN_USED_OBJECT_ID | DN_USED_CHAR  =>								-- USED_OBJECT : sm_defn ET sm_value

	if  BOUND.TY in CLASS_USED_OBJECT  then								-- eux seuls portent sm_value
	  LIRE_SM_VALUE( BOUND, VAL, OK );
	  if  OK  then  return;  end if;
	end if;

	DEFN := D( SM_DEFN, BOUND );
	if  DEFN.TY = DN_ENUMERATION_ID  or else  DEFN.TY = DN_CHARACTER_ID  then
	  VAL := DI( SM_REP, DEFN );  OK := TRUE;
	elsif  DEFN.TY = DN_NUMBER_ID  then
	  STATIC_BOUND_VALUE( D( SM_INIT_EXP, DEFN ), VAL, OK );						-- nombre nomme (LRM 3.2.2)
	end if;

      when  DN_ENUMERATION_ID  |  DN_CHARACTER_ID  =>							-- borne = litteral DEFINISSANT
	VAL := DI( SM_REP, BOUND );
	OK := TRUE;

      when  others  =>
	null;											-- INTENTIONNEL : borne reellement dynamique : OK = FALSE
      end case;

    end	STATIC_BOUND_VALUE;
	------------------


			--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^--
  procedure		  PROCESS_CONSTRAINED_ARRAY_TYPE_SPEC	( TYPE_SPEC :TREE; CONSTRAINT :TREE := TREE_VOID )
  is			---------------------------------------

    DIM_NBR		: NATURAL			:= 0;
    LVL			: LEVEL_NUM		renames CODI.CUR_LEVEL;
    LVL_STR		:constant STRING		:= IMAGE( CODI.CUR_LEVEL );
    TOTAL_ELEMENTS		: NATURAL;

    BASE_TYPE		: TREE			:= D( SM_BASE_TYPE, TYPE_SPEC );
    COMP_TYPE		: TREE			:= D( SM_COMP_TYPE, BASE_TYPE );
  begin
    if  COMP_TYPE.TY = DN_PRIVATE  or  COMP_TYPE.TY = DN_L_PRIVATE  then
      COMP_TYPE := D( SM_TYPE_SPEC, COMP_TYPE );
    end if;

    if  CODI.EST_RECORD_DYNAMIQUE( COMP_TYPE )  then						--| option B : pas de taille d'ELEMENT statique
      CODI.TROU( "PROCESS_CONSTRAINED_ARRAY_TYPE_SPEC tableau de records dynamiques (taille max : etape 3)", COMP_TYPE );
    end if;

    declare
      COMP_SIZE_TREE	: TREE			:= TREE_VOID;
      IS_STATIC		: BOOLEAN			:= COMP_SIZE_TREE /= TREE_VOID;
      ARRAY_STATIC_SIZE	: NATURAL			:= 0;

      function  TYPE_SIZE_BITS	( T :TREE )	return NATURAL;

		---------------------------
      function	CONSTRAINED_ARRAY_SIZE_BITS		( ARR :TREE )	return NATURAL
      is		---------------------------
        ARR_SPEC		: TREE		:= CODI.FULL_TYPE_VIEW( ARR );
        BASE_TYPE		: TREE;
        ELEM_TYPE		: TREE;
        IDX_S		: SEQ_TYPE;
        IDX_TYPE		: TREE;
        IDX_SPEC		: TREE;
        IDX_RANGE		: TREE;
        LO, HI		: INTEGER;
        LO_OK, HI_OK	: BOOLEAN;
        TOTAL		: NATURAL;

      begin
        if  ARR_SPEC = TREE_VOID  or else  ARR_SPEC = TREE_NIL
          or else  ARR_SPEC.TY /= DN_CONSTRAINED_ARRAY
        then
	TROU( "CONSTRAINED_ARRAY_SIZE_BITS erreur spec", ARR_SPEC );
          return  0;
        end if;

        if  D( CD_IMPL_SIZE, ARR_SPEC ) /= TREE_VOID
          and then D( CD_IMPL_SIZE, ARR_SPEC ) /= TREE_NIL
          and then DI( CD_IMPL_SIZE, ARR_SPEC ) > 0

        then
          return NATURAL( DI( CD_IMPL_SIZE, ARR_SPEC ) );
        end if;

        BASE_TYPE := D( SM_BASE_TYPE, ARR_SPEC );
        ELEM_TYPE := D( SM_COMP_TYPE, BASE_TYPE );

        TOTAL := TYPE_SIZE_BITS( ELEM_TYPE );

        if  TOTAL = 0  then
          return  0;
        end if;

        IDX_S := LIST( D( SM_INDEX_SUBTYPE_S, ARR_SPEC ) );
        while  not IS_EMPTY( IDX_S )  loop
          POP( IDX_S, IDX_TYPE );
          IDX_SPEC := CODI.FULL_TYPE_VIEW( IDX_TYPE );
          IDX_RANGE := D( SM_RANGE, IDX_SPEC );

          if  IDX_RANGE = TREE_VOID  or else  IDX_RANGE = TREE_NIL  or else  IDX_RANGE.TY /= DN_RANGE
          then return  0;
          end if;

          STATIC_BOUND_VALUE( D( AS_EXP1, IDX_RANGE ), LO, LO_OK );
          STATIC_BOUND_VALUE( D( AS_EXP2, IDX_RANGE ), HI, HI_OK );

          if  not ( LO_OK and HI_OK )  or else  HI < LO  then
            return  0;
          end if;

          TOTAL := TOTAL * NATURAL( HI - LO + 1 );
        end loop;

        DI( CD_IMPL_SIZE, ARR_SPEC, INTEGER( TOTAL ) );
        return  TOTAL;

      end	CONSTRAINED_ARRAY_SIZE_BITS;
	---------------------------


		--------------
      function	TYPE_SIZE_BITS ( T :TREE )	return NATURAL
      is		--------------

        TS	: TREE		:= CODI.FULL_TYPE_VIEW( T );
        RAW	: INTEGER;

      begin
        if  CODI.EST_ACCES( TS )  or else  TS.TY = DN_FLOAT  then
          return  CODI.ADDR_SIZE * CODI.STORAGE_UNIT;

        elsif  TS.TY = DN_CONSTRAINED_ARRAY  then
          return  CONSTRAINED_ARRAY_SIZE_BITS( TS );

        elsif  TS.TY = DN_RECORD  or else  TS.TY = DN_CONSTRAINED_RECORD  then
          if  TS.TY = DN_CONSTRAINED_RECORD  then
            TS := D( SM_BASE_TYPE, TS );
          end if;

          RAW := DI( CD_IMPL_SIZE, TS );
          if  RAW = 0  then
            return  0;
          end if;

          return  NATURAL( ( ( RAW + CODI.STORAGE_UNIT - 1 )
                            / CODI.STORAGE_UNIT ) * CODI.STORAGE_UNIT );

        else
          RAW := DI( CD_IMPL_SIZE, TS );
          return  NATURAL( ( ( RAW + CODI.STORAGE_UNIT - 1 )
                            / CODI.STORAGE_UNIT ) * CODI.STORAGE_UNIT );
        end if;

      end	TYPE_SIZE_BITS;
	--------------


		--------------
      function	COMP_SIZE_BITS	return NATURAL
      is		--------------
      begin
        return TYPE_SIZE_BITS( COMP_TYPE );

      end COMP_SIZE_BITS;
	--------------


      -- Staticite d'une borne discrete pour le calcul de CD_IMPL_SIZE.
      -- Deliberement conservateur : on ne reconnait d'abord que les bornes
      -- que le code existant savait deja exploiter dans le chemin sans
      -- CONSTRAINT, c'est-a-dire les DN_NUMERIC_LITERAL avec SM_VALUE.
      -- Le code d'initialisation du descripteur reste dynamique et continue
      -- d'utiliser CODE_DISCRETE_RANGE_BOUND ; seule la decision de poser
      -- CD_IMPL_SIZE est modifiee.

		-----------------------
      function	IS_STATIC_INTEGER_BOUND	( EXP :TREE )	return BOOLEAN
      is		-----------------------
      begin
        return  EXP /= TREE_VOID  and then  EXP.TY = DN_NUMERIC_LITERAL;

      end	IS_STATIC_INTEGER_BOUND;
	-----------------------


		-------------------
      procedure	STATIC_RANGE_BOUNDS	( RNG :in  TREE; IS_STATIC :out BOOLEAN; LO, HI :out INTEGER )
      is		-------------------

        EXP1	: TREE	:= TREE_VOID;
        EXP2	: TREE	:= TREE_VOID;

      begin
        IS_STATIC := FALSE;
        LO := 0;
        HI := -1;

        if RNG /= TREE_VOID and then RNG.TY = DN_RANGE then
	EXP1 := D( AS_EXP1, RNG );
	EXP2 := D( AS_EXP2, RNG );

	if IS_STATIC_INTEGER_BOUND( EXP1 )
	  and then IS_STATIC_INTEGER_BOUND( EXP2 )
	then
	  LO := DI( SM_VALUE, EXP1 );
	  HI := DI( SM_VALUE, EXP2 );
	  IS_STATIC := TRUE;
	end if;
        end if;

      end	STATIC_RANGE_BOUNDS;
	-------------------


		-------------------------
      procedure	MULTIPLY_STATIC_DIMENSION	( LO, HI :in INTEGER )
      is		-------------------------
        LEN : NATURAL;
      begin
        if HI < LO then
	LEN := 0;
        else
	LEN := NATURAL( HI - LO + 1 );
        end if;

        ARRAY_STATIC_SIZE := LEN * ARRAY_STATIC_SIZE;

      end	MULTIPLY_STATIC_DIMENSION;
	-------------------------


		----------------------------
    procedure	COMPILE_ARRAY_TYPE_DIMENSION		( IDX_TYPE_LIST, RANGE_LIST :in out SEQ_TYPE;
						  HAS_RANGES :BOOLEAN )
    is		----------------------------

      IDX_TYPE		: TREE;
      SRC_RANGE		: TREE		:= TREE_VOID;
      DIM_NBR_STR		:constant STRING	:= IMAGE( DIM_NBR+1 );

    begin
      POP( IDX_TYPE_LIST, IDX_TYPE );
      if  HAS_RANGES  then
        POP( RANGE_LIST, SRC_RANGE );
      end if;
      DIM_NBR := DIM_NBR + 1;

      if  IS_EMPTY( IDX_TYPE_LIST )  then
        declare
	ELEMENT_SIZ		: NATURAL		:= COMP_SIZE_BITS;					-- TAILLE EN BITS
	ELEMENT_SIZ_STR		:constant STRING	:= IMAGE( ELEMENT_SIZ );				-- IMAGE DE TAILLE EN BITS
        begin
	ARRAY_STATIC_SIZE := ELEMENT_SIZ;
	PUT_LINE( "VAR _COMP_SIZ, D" );
	PUT_LINE( "VAR _FST_" & DIM_NBR_STR & ", D" );
	PUT_LINE( "VAR _LST_" & DIM_NBR_STR & ", D" );

	if  ELEMENT_SIZ = 0
	  and then ( COMP_TYPE.TY = DN_RECORD  or else  COMP_TYPE.TY = DN_CONSTRAINED_RECORD )
	then
		-- Pilier 3.7 / ACVC A7 : composant record dont la vue complete
		-- (type prive) n'est pas encore compilee.  Taille inconnue de
		-- l'EXPANDER mais pas de l'ASSEMBLEUR : emettre le symbole
		-- <rec>.size*8, defini plus loin dans le meme FINC (fasm est
		-- multi-passes).  Le tableau suit le chemin dynamique.
	  IS_STATIC := FALSE;

	  declare
	    REC	: TREE	:= COMP_TYPE;
	  begin
	    if  REC.TY = DN_CONSTRAINED_RECORD  then
	      REC := D( SM_BASE_TYPE, REC );
	    end if;

	    declare
	      REC_NAME	: TREE		:= D( XD_SOURCE_NAME, REC );
	      REC_STR	:constant STRING	:= '_' & PRINT_NAME( D( LX_SYMREP, REC_NAME ) );
	    begin
	      PUT( tab & "LI" & tab );
	      CODI.REGIONS_PATH( REC_NAME );
	      PUT_LINE( REC_STR & ".size*8" );							-- TAILLE SYMBOLIQUE (bits)
	    end;
	  end;

	else
	  PUT_LINE(	tab & "LI" & tab & ELEMENT_SIZ_STR );						-- TAILLE D'UN ELEMENT DU TABLEAU
	end if;

	PUT_LINE( tab & "SD" & tab & LVL_STR & ", _COMP_SIZ" );						-- DWORD COMP_SIZ
	PUT_LINE( tab & "LD" & tab & LVL_STR & ", _COMP_SIZ" );						-- recharge pour MUL suivant
        end;

      else
        COMPILE_ARRAY_TYPE_DIMENSION( IDX_TYPE_LIST, RANGE_LIST, HAS_RANGES );

        PUT_LINE( "VAR _SIZ_" & DIM_NBR_STR & ", D" );
        PUT_LINE( "VAR _FST_" & DIM_NBR_STR & ", D" );
        PUT_LINE( "VAR _LST_" & DIM_NBR_STR & ", D" );

        PUT_LINE( tab & "MUL" );
        PUT_LINE( tab & "SD" & tab & LVL_STR & ", _SIZ_" & DIM_NBR_STR );					-- METTRE LA TAILLE TRANCHE A CELLE LAISSEE PAR LE CALCUL SUR LA DIM PRECEDENTE
        PUT_LINE( tab & "LD" & tab & LVL_STR & ", _SIZ_" & DIM_NBR_STR );					-- recharge pour MUL suivant
      end if;

      if  HAS_RANGES  and then  SRC_RANGE /= TREE_VOID  then

        declare
	RNG_STATIC : BOOLEAN;
	RNG_LO	 : INTEGER;
	RNG_HI	 : INTEGER;
        begin
	STATIC_RANGE_BOUNDS( SRC_RANGE, RNG_STATIC, RNG_LO, RNG_HI );

	if RNG_STATIC and then IS_STATIC then
	  MULTIPLY_STATIC_DIMENSION( RNG_LO, RNG_HI );
	else
	  IS_STATIC := FALSE;
	end if;
        end;

        EXPRESSIONS.CODE_DISCRETE_RANGE_BOUND( SRC_RANGE, IS_LAST => FALSE );
        PUT_LINE( tab & "SD" & tab & LVL_STR & ", _FST_" & DIM_NBR_STR );

        EXPRESSIONS.CODE_DISCRETE_RANGE_BOUND( SRC_RANGE, IS_LAST => TRUE );
        PUT_LINE( tab & "SD" & tab & LVL_STR & ", _LST_" & DIM_NBR_STR );

      elsif  IDX_TYPE.TY = DN_INTEGER  then
        declare
	IDX_RANGE		: TREE		:= D( SM_RANGE, IDX_TYPE );
	RANGE_FIRST	: TREE		:= D( AS_EXP1, IDX_RANGE );
	RANGE_LAST	: TREE		:= D( AS_EXP2, IDX_RANGE );
        begin
	if  RANGE_FIRST.TY /= DN_NUMERIC_LITERAL
	or  RANGE_LAST.TY /= DN_NUMERIC_LITERAL
	then
	  IS_STATIC := FALSE;
	end if;

	EXPRESSIONS.CODE_EXP( RANGE_FIRST );
	PUT_LINE( tab & "SD" & tab & LVL_STR & ", _FST_" & DIM_NBR_STR );
	EXPRESSIONS.CODE_EXP( RANGE_LAST );
	PUT_LINE( tab & "SD" & tab & LVL_STR & ", _LST_" & DIM_NBR_STR );

	if  IS_STATIC  then
	  ARRAY_STATIC_SIZE := ( DI( SM_VALUE, RANGE_LAST ) + 1 - DI( SM_VALUE, RANGE_FIRST ) ) * ARRAY_STATIC_SIZE;
	end if;
        end;

      elsif  IDX_TYPE.TY = DN_ENUMERATION  then
	-- Index par MARQUE DE TYPE enumere : array (NODE_NAME) of ...
	-- (chemin sans INDEX_CONSTRAINT ; les plages explicites passent,
	-- elles, par HAS_RANGES / CODE_DISCRETE_RANGE_BOUND).
	-- Les bornes vivent dans SM_RANGE du type_spec ; ce sont des
	-- litteraux (definissants ou used names) : STATIC_BOUND_VALUE
	-- rend leur SM_REP, coherent avec le LI SM_REP emis au runtime
	-- pour les litteraux d'enumeration.
        declare
	IDX_RANGE		: TREE		:= D( SM_RANGE, IDX_TYPE );
	RANGE_FIRST	: TREE		:= D( AS_EXP1, IDX_RANGE );
	RANGE_LAST	: TREE		:= D( AS_EXP2, IDX_RANGE );
	V_FST		: INTEGER;
	V_LST		: INTEGER;
	OK_FST		: BOOLEAN;
	OK_LST		: BOOLEAN;
        begin
	STATIC_BOUND_VALUE( RANGE_FIRST, V_FST, OK_FST );
	STATIC_BOUND_VALUE( RANGE_LAST,  V_LST, OK_LST );

	if  OK_FST  then
	  PUT_LINE( tab & "LI" & tab & IMAGE( V_FST ) );
	else
	  IS_STATIC := FALSE;
	  EXPRESSIONS.CODE_EXP( RANGE_FIRST );
	end if;
	PUT_LINE( tab & "SD" & tab & LVL_STR & ", _FST_" & DIM_NBR_STR );

	if  OK_LST  then
	  PUT_LINE( tab & "LI" & tab & IMAGE( V_LST ) );
	else
	  IS_STATIC := FALSE;
	  EXPRESSIONS.CODE_EXP( RANGE_LAST );
	end if;
	PUT_LINE( tab & "SD" & tab & LVL_STR & ", _LST_" & DIM_NBR_STR );

	if  IS_STATIC  then
	  ARRAY_STATIC_SIZE := ( V_LST + 1 - V_FST ) * ARRAY_STATIC_SIZE;
	end if;
        end;

      else
        IS_STATIC := FALSE;
        CODI.TROU( "PROCESS_CONSTRAINED_ARRAY_TYPE_SPEC index non entier", IDX_TYPE );				--| vague 5 : bornes symboliques douteuses en aval
      end if;

      PUT_LINE( tab & "LD" & tab & LVL_STR & ", _LST_" & DIM_NBR_STR );
      PUT_LINE( tab & "LD" & tab & LVL_STR & ", _FST_" & DIM_NBR_STR );
      PUT_LINE( tab & "SUB" );
      PUT_LINE( tab & "INC" );
      PUT_LINE( tab & "CLAMP0" );

    end	COMPILE_ARRAY_TYPE_DIMENSION;
	----------------------------


		--------------------
    procedure	COMPUTE_INFO_OFFSETS	( IDX_TYPE_LIST :in out SEQ_TYPE )
    is
      IDX_TYPE		: TREE;
      DIM_NBR_STR		:constant STRING	:= IMAGE( DIM_NBR+1 );
    begin
      POP( IDX_TYPE_LIST, IDX_TYPE );
      DIM_NBR := DIM_NBR + 1;

      if  IS_EMPTY( IDX_TYPE_LIST )  then
	PUT_LINE( "COMP_SIZ = $" );
	PUT_LINE( tab & "rd 1 " );
	PUT_LINE( "FST_" & DIM_NBR_STR & " = $" );
	PUT_LINE( tab & "rd 1 " );
	PUT_LINE( "LST_" & DIM_NBR_STR & " = $" );
	PUT_LINE( tab & "rd 1 " );
      else
        COMPUTE_INFO_OFFSETS( IDX_TYPE_LIST );

        PUT_LINE( "SIZ_" & DIM_NBR_STR & " = $" );
        PUT_LINE( tab & "rd 1 " );
        PUT_LINE( "FST_" & DIM_NBR_STR & " = $" );
        PUT_LINE( tab & "rd 1 " );
        PUT_LINE( "LST_" & DIM_NBR_STR & " = $" );
        PUT_LINE( tab & "rd 1 " );
      end if;

    end	COMPUTE_INFO_OFFSETS;
	--------------------

  begin
    if  CODI.EST_ACCES( COMP_TYPE )  or else  COMP_TYPE.TY in CLASS_SCALAR  then
      IS_STATIC := TRUE;
    else
      COMP_SIZE_TREE := D( CD_IMPL_SIZE, COMP_TYPE );
      IS_STATIC := COMP_SIZE_TREE /= TREE_VOID;
    end if;

    DI( CD_LEVEL, TYPE_SPEC, INTEGER( LVL ) );

    PUT_LINE( "VAR use__info, Q" );
    PUT_LINE( "VAR SIZ__, D" );									-- VAR taille de patron
    PUT_LINE( tab & "LVA" & tab & LVL_STR & ", SIZ__" );							-- Adresse debut de patron
    PUT_LINE( tab & "SA" & tab & LVL_STR & ", use__info" );

			-------------------
			DESCRIPTOR_ON_STACK:
    begin
      if  CONSTRAINT /= TREE_VOID  and then  CONSTRAINT.TY = DN_INDEX_CONSTRAINT  then
        declare
	IDX_TYPE_LIST	: SEQ_TYPE	:= LIST( D( SM_INDEX_SUBTYPE_S, TYPE_SPEC ) );
	RANGE_LIST	: SEQ_TYPE	:= LIST( D( AS_DISCRETE_RANGE_S, CONSTRAINT ) );
        begin
	COMPILE_ARRAY_TYPE_DIMENSION( IDX_TYPE_LIST, RANGE_LIST, TRUE );
        end;
      else
        declare
	IDX_TYPE_LIST	: SEQ_TYPE	:= LIST( D( SM_INDEX_SUBTYPE_S, TYPE_SPEC ) );
	DUMMY_LIST	: SEQ_TYPE	:= LIST( D( SM_INDEX_SUBTYPE_S, TYPE_SPEC ) );
        begin
	COMPILE_ARRAY_TYPE_DIMENSION( IDX_TYPE_LIST, DUMMY_LIST, FALSE );
        end;
      end if;

      PUT_LINE( tab & "MUL" );
      PUT_LINE( tab & "SD" & tab & LVL_STR & ", SIZ__" );							-- Taille de patron

      if  IS_STATIC  then
        DI( CD_IMPL_SIZE,	TYPE_SPEC,  ARRAY_STATIC_SIZE );
      end if;

      PUT_LINE( "  virtual at 4" );									-- Commence apres SIZ
      declare
        IDX_TYPE_LIST	: SEQ_TYPE	:= LIST( D( SM_INDEX_SUBTYPE_S, TYPE_SPEC ) );
      begin
        DIM_NBR := 0;
        COMPUTE_INFO_OFFSETS( IDX_TYPE_LIST );
      end;
      PUT_LINE( "  end virtual" );

      PUT_LINE( "end namespace" );

    end	DESCRIPTOR_ON_STACK;
	-------------------

    DB( CD_COMPILED, TYPE_SPEC, TRUE );
    end;

  end	PROCESS_CONSTRAINED_ARRAY_TYPE_SPEC;
	-----------------------------------


			---------------------------
  procedure		CODE_CONSTRAINED_ARRAY_DECL		( TYPE_DECL :TREE )
  is			---------------------------

    TYPE_NAME		: TREE			:= D( AS_SOURCE_NAME, TYPE_DECL );
    TYPE_NAME_STR		:constant STRING		:= '_' & PRINT_NAME( D( LX_SYMREP, TYPE_NAME ) );
    TYPE_SPEC		: TREE			:= D( SM_TYPE_SPEC, TYPE_NAME );

  begin
    if  CODI.DEBUG  then NEW_LINE; PUT_LINE( tab50 & "; array decl constrained array type info" ); end if;

    PUT_LINE( TYPE_NAME_STR & " = '" & TYPE_NAME_STR & "'" );
    PUT_LINE( "namespace " & TYPE_NAME_STR );

    if  TYPE_DECL.TY = DN_CONSTRAINED_ARRAY_DEF  then
      PROCESS_CONSTRAINED_ARRAY_TYPE_SPEC( TYPE_SPEC, D( AS_CONSTRAINT, TYPE_DECL ) );
    else
      PROCESS_CONSTRAINED_ARRAY_TYPE_SPEC( TYPE_SPEC );
    end if;

  end	CODE_CONSTRAINED_ARRAY_DECL;
	---------------------------


			----------------
  procedure		CODE_RECORD_DECL		( TYPE_DECL :TREE )
  is			----------------

    TYPE_ID		: TREE			:= D( AS_SOURCE_NAME, TYPE_DECL );
    TYPE_SPEC		: TREE			:= D( SM_TYPE_SPEC, TYPE_ID );
    TYPE_ID_STR		:constant STRING		:= '_' & PRINT_NAME( D( LX_SYMREP, TYPE_ID ) );
    LVL			: LEVEL_NUM		renames CODI.CUR_LEVEL;
    LVL_STR		:constant STRING		:= IMAGE( LVL );
    IS_STATIC		: BOOLEAN			:= TRUE;
    STATIC_SIZE		: NATURAL			:= 0;
    EST_DYNAMIQUE		: BOOLEAN			:= FALSE;				--| composant(s) dependant d'un discriminant (option B)


    function  STATIC_TYPE_SIZE_BITS	( T :TREE )	return NATURAL;
    function  STATIC_TYPE_ALIGN_BYTES	( T :TREE )	return NATURAL;					--| alignement du composant elementaire : 1/2/4/8
    function  STATIC_RECORD_SIZE_BITS	( REC :TREE )	return NATURAL;

			-----------------
    procedure		ALIGN_STATIC_BITS		( CUMUL : in out NATURAL;  COMP_TYPE : TREE )
    is			-----------------
    -- Arrondit le cumul de bits a l'alignement du champ qui va etre pose,
    -- MIROIR EXACT des align_* que STATOFS emet avec le meme
    -- STATIC_TYPE_ALIGN_BYTES.  Toute divergence entre ce calcul et le
    -- layout fasmg est un bug d'ecrasement memoire (cf. RPG_DATA).
      A_BITS	: NATURAL := STATIC_TYPE_ALIGN_BYTES( COMP_TYPE ) * CODI.STORAGE_UNIT;
    begin
      if  A_BITS > 0  then
        CUMUL := ( ( CUMUL + A_BITS - 1 ) / A_BITS ) * A_BITS;
      end if;

    end	ALIGN_STATIC_BITS;
	-----------------

			------------------
    function		ROUND_STORAGE_BITS		( SIZE_BITS :NATURAL )	return NATURAL
    is			------------------
      RESULT	: NATURAL		:= SIZE_BITS;
    begin
      if  RESULT < CODI.STORAGE_UNIT  then
	RESULT := CODI.STORAGE_UNIT;
      end if;

      return  CODI.STORAGE_UNIT * ( ( RESULT + CODI.STORAGE_UNIT - 1 ) / CODI.STORAGE_UNIT );

    end	ROUND_STORAGE_BITS;
	------------------


			-----------------------
    function		STATIC_RECORD_SIZE_BITS	( REC :TREE ) return NATURAL
    is			-----------------------
      REC_SPEC	: TREE		:= FULL_TYPE_VIEW( REC );
      SIZE	: NATURAL		:= 0;
      UNKNOWN	: BOOLEAN		:= FALSE;
		-----------------
      procedure	ADD_DISCRIMINANTS	( DS : TREE )
      is		-----------------
        DSCRMT_DECL_S	: SEQ_TYPE;
        DSCRMT_DECL		: TREE;

      begin
        if  DS = TREE_VOID  or else  DS = TREE_NIL  then
	  return;
        end if;

        DSCRMT_DECL_S := LIST( DS );

        while  not IS_EMPTY( DSCRMT_DECL_S )  loop
	POP( DSCRMT_DECL_S, DSCRMT_DECL );

	declare
	  DISCR_ID_S	: SEQ_TYPE	:= LIST( D( AS_SOURCE_NAME_S, DSCRMT_DECL ) );
	  DISCR_ID	: TREE;
	begin
	  while  not IS_EMPTY( DISCR_ID_S )  loop
	    POP( DISCR_ID_S, DISCR_ID );

	    declare
	      DISCR_TYPE	: TREE	:= FULL_TYPE_VIEW( D( SM_OBJ_TYPE, DISCR_ID ) );
	      DISCR_SIZE	: NATURAL := STATIC_TYPE_SIZE_BITS( DISCR_TYPE );
	    begin
	      if  DISCR_SIZE = 0  then
	        UNKNOWN := TRUE;
	        return;
	      end if;

	      ALIGN_STATIC_BITS( SIZE, DISCR_TYPE );
	      SIZE := SIZE + ROUND_STORAGE_BITS( DISCR_SIZE );
	    end;
	  end loop;
	end;
        end loop;

      end ADD_DISCRIMINANTS;
	-----------------

		-------------
      procedure	ADD_COMP_LIST	( CL : TREE )
      is		-------------
        V_DECL_S	: SEQ_TYPE;
        V_DECL	: TREE;
      begin
        if  CL = TREE_VOID  or else  CL = TREE_NIL  then
	return;
        end if;

        V_DECL_S := LIST( D( AS_DECL_S, CL ) );

        while  not IS_EMPTY( V_DECL_S )  loop
	POP( V_DECL_S, V_DECL );

	if  V_DECL.TY /= DN_NULL_COMP_DECL  then
	  declare
	    COMP_ID_S	: SEQ_TYPE	:= LIST( D( AS_SOURCE_NAME_S, V_DECL ) );
	    COMP_ID	: TREE;
	  begin
	    while  not IS_EMPTY( COMP_ID_S )  loop
	      POP( COMP_ID_S, COMP_ID );

	      declare
	        COMP_TYPE	: TREE	:= FULL_TYPE_VIEW( D( SM_OBJ_TYPE, COMP_ID ) );
	        COMP_SIZE	: NATURAL := STATIC_TYPE_SIZE_BITS( COMP_TYPE );
	      begin
	        if  COMP_SIZE = 0  then
		UNKNOWN := TRUE;
		return;
	        end if;

	        ALIGN_STATIC_BITS( SIZE, COMP_TYPE );
	        SIZE := SIZE + ROUND_STORAGE_BITS( COMP_SIZE );
	      end;
	    end loop;
	  end;
	end if;
        end loop;

	--  Pilier 3.7, layout ADDITIF : les champs de TOUTES les variantes
	--  sont poses bout a bout par CODE_RECORD_DECL ; la taille statique
	--  est donc la somme (coherence avec TRAITER_LES_CHAMPS).
        declare
	VP	: TREE	:= D( AS_VARIANT_PART, CL );
        begin
	if  VP /= TREE_VOID  and then  VP /= TREE_NIL  then
	  declare
	    VAR_S : SEQ_TYPE	:= LIST( D( AS_VARIANT_S, VP ) );
	    VAR_E : TREE;
	  begin
	    while  not IS_EMPTY( VAR_S )  loop
	      POP( VAR_S, VAR_E );

	      if  VAR_E.TY = DN_VARIANT  then
	        ADD_COMP_LIST( D( AS_COMP_LIST, VAR_E ) );

	        if  UNKNOWN  then
		return;
	        end if;
	      end if;
	    end loop;
	  end;
	end if;
        end;

      end ADD_COMP_LIST;
	-------------

    begin
      if  REC_SPEC.TY /= DN_RECORD  then
	return 0;
      end if;

      if  REPRESENTED_ITEMS.HAS_RECORD_REP( REC_SPEC )  then
	return NATURAL( REPRESENTED_ITEMS.REPRESENTED_RECORD_SIZE_BITS( REC_SPEC ) );
      end if;

      if  D( SM_SIZE, REC_SPEC ) /= TREE_VOID  then
	return NATURAL( DI( SM_SIZE, REC_SPEC ) );
      end if;

      ADD_DISCRIMINANTS( D( SM_DISCRIMINANT_S, REC_SPEC ) );
      if  UNKNOWN  then
	return 0;
      end if;

      ADD_COMP_LIST( D( SM_COMP_LIST, REC_SPEC ) );

      if  UNKNOWN  then
	return 0;
      end if;

      if  SIZE /= 0  then
	DI( CD_IMPL_SIZE, REC_SPEC, INTEGER( SIZE ) );
      end if;

      return SIZE;

    end	STATIC_RECORD_SIZE_BITS;
	-----------------------


			-------------------
    function		STATIC_INDEX_LENGTH		( IDX_TYPE : TREE ) return NATURAL
    is			-------------------

      IDX_SPEC	: TREE	:= FULL_TYPE_VIEW( IDX_TYPE );
      IDX_RANGE	: TREE;
      FST		: TREE;
      LST		: TREE;
    begin
      if  IDX_SPEC = TREE_VOID  or else  IDX_SPEC = TREE_NIL  then
        return 0;
      end if;

      if  IDX_SPEC.TY = DN_INTEGER  or else  IDX_SPEC.TY = DN_ENUMERATION  then
        IDX_RANGE := D( SM_RANGE, IDX_SPEC );

        if  IDX_RANGE = TREE_VOID  or else  IDX_RANGE = TREE_NIL  then
	TROU( "STATIC_INDEX_LENGTH range vide", IDX_RANGE );
	return 0;
        end if;

        FST := D( AS_EXP1, IDX_RANGE );
        LST := D( AS_EXP2, IDX_RANGE );

	--  Perimetre : toute borne STATIQUE -- litteral, nombre nomme,
	--  litteral d'enumeration (index par marque de type), expression
	--  statique annotee SM_VALUE par sem.  Les bornes dynamiques
	--  continuent de rendre le record non statique (OK = FALSE -> 0).
        declare
	LO, HI		: INTEGER;
	LO_OK, HI_OK	: BOOLEAN;
        begin
	STATIC_BOUND_VALUE( FST, LO, LO_OK );
	STATIC_BOUND_VALUE( LST, HI, HI_OK );

	if  not( LO_OK and HI_OK )  then
	  return  0;										-- INTENTIONNEL : borne dynamique -> record non
												-- statique (perimetre ci-dessus). Le refus
												-- bruyant reste en aval : CHAMPS_REGULIERS
												-- "offset non statique" (piege n 121d).

	elsif  HI < LO  then
	  TROU( "STATIC_INDEX_LENGTH HI < LO", IDX_SPEC );
	  return  0;										-- tableau vide (garde existante)
	else
	  return NATURAL( HI + 1 - LO );
	end if;
        end;

      else
        TROU( "STATIC_INDEX_LENGTH idx_spec inattendu", IDX_SPEC );
        return  0;
      end if;

    end	STATIC_INDEX_LENGTH;
	-------------------


			----------------------------------
    function		STATIC_CONSTRAINED_ARRAY_SIZE_BITS	( ARR : TREE ) return NATURAL
    is			----------------------------------
      ARR_SPEC  : TREE := FULL_TYPE_VIEW( ARR );
      BASE_TYPE : TREE;
      COMP_TYPE : TREE;
      COMP_SIZE : NATURAL;
      IDX_S     : SEQ_TYPE;
      IDX_TYPE  : TREE;
      LEN	      : NATURAL;
      TOTAL     : NATURAL;
    begin
      if  ARR_SPEC = TREE_VOID  or else  ARR_SPEC = TREE_NIL
      or else  ARR_SPEC.TY /= DN_CONSTRAINED_ARRAY
      then
        return 0;
      end if;

-- Cache : une taille N'EST en cache que si elle est CONNUE et
	-- POSITIVE. Piege n 95a : l'absence se lit VOID *ou* NIL selon
	-- le noeud, et un 0 signifie "inconnu", pas "tableau vide" --
	-- un tableau vide se recalcule pour rien, c'est sans danger.
      declare
        CIS	: TREE	:= D( CD_IMPL_SIZE, ARR_SPEC );

      begin
        if  CIS /= TREE_VOID  and then  CIS /= TREE_NIL
		and then  DI( CD_IMPL_SIZE, ARR_SPEC ) > 0
        then
	return  NATURAL( DI( CD_IMPL_SIZE, ARR_SPEC ) );
        end if;
      end;

      BASE_TYPE := D( SM_BASE_TYPE, ARR_SPEC );
      COMP_TYPE := FULL_TYPE_VIEW( D( SM_COMP_TYPE, BASE_TYPE ) );
      COMP_SIZE := STATIC_TYPE_SIZE_BITS( COMP_TYPE );

      if  COMP_SIZE = 0  then
        return 0;
      end if;

      TOTAL := COMP_SIZE;
      IDX_S := LIST( D( SM_INDEX_SUBTYPE_S, ARR_SPEC ) );

      while  not IS_EMPTY( IDX_S )  loop
	POP( IDX_S, IDX_TYPE );
	LEN := STATIC_INDEX_LENGTH( IDX_TYPE );

	if  LEN = 0  then
	  return 0;
	end if;

	TOTAL := TOTAL * LEN;
      end loop;

      DI( CD_IMPL_SIZE, ARR_SPEC, INTEGER( TOTAL ) );
      return TOTAL;

    end	STATIC_CONSTRAINED_ARRAY_SIZE_BITS;
	----------------------------------


			---------------------
    function		STATIC_TYPE_SIZE_BITS	( T : TREE )	return NATURAL
    is			---------------------
      TS : TREE := FULL_TYPE_VIEW( T );
    begin
	--| CONTRAT DU 0 (vague 2, triage 28/07) : 0 = "taille non calculable
	--| STATIQUEMENT", sentinelle contractuelle.  Appelants verifies le
	--| 28/07 : ADD_DISCRIMINANTS et ADD_COMP_LIST (UNKNOWN := TRUE),
	--| STATIC_CONSTRAINED_ARRAY_SIZE_BITS (propagation), IS_STATIC :=
	--| FALSE (insert use__info), et le garde COMP_SIZE = 0 -> raise du
	--| layout represente.  Les 0 LEGITIMES : type vide (garde d'entree),
	--| DN_ARRAY non contraint.  Les 0 d'IGNORANCE (scalaire sans
	--| CD_IMPL_SIZE, noeud hors classes) passent par TROU : en STRICT ils
	--| levent, en RECENSEMENT ils rendent 0 (= chemin dynamique) apres
	--| comptage.
      if  TS = TREE_VOID  or else  TS = TREE_NIL  then
        return  0;											-- INTENTIONNEL : vue vide -> non statique
      end if;

      if  CODI.EST_ACCES( TS )  then
        return  CODI.ADDR_SIZE * CODI.STORAGE_UNIT;

      elsif  TS.TY = DN_RECORD  then
        return  STATIC_RECORD_SIZE_BITS( TS );

      elsif  TS.TY = DN_CONSTRAINED_RECORD  then
	-- Pilier 3.7 : vue contrainte (nommee ou anonyme) -> taille du record
	-- de base (layout additif : la contrainte ne change pas la taille).
        return  STATIC_RECORD_SIZE_BITS( D( SM_BASE_TYPE, TS ) );

      elsif  TS.TY = DN_CONSTRAINED_ARRAY  then
        return  STATIC_CONSTRAINED_ARRAY_SIZE_BITS( TS );

      elsif  TS.TY = DN_ARRAY  then
        return  0;											-- INTENTIONNEL : non contraint -> non statique

      elsif  TS.TY in CLASS_SCALAR  or else  TS.TY in CLASS_CONSTRAINED  then
        if  D( CD_IMPL_SIZE, TS ) /= TREE_VOID  then
	return  NATURAL( DI( CD_IMPL_SIZE, TS ) );
        else
	CODI.TROU( "STATIC_TYPE_SIZE_BITS scalaire sans CD_IMPL_SIZE", TS );					-- vague 2 : le front-end aurait du le poser
	return  0;
        end if;

      else
        CODI.TROU( "STATIC_TYPE_SIZE_BITS", TS );								-- vague 2 : noeud hors classes, 0 mentait
        return 0;
      end if;

    end	STATIC_TYPE_SIZE_BITS;
	-----------------------

			------------------------
    function		STATIC_TYPE_ALIGN_BYTES	( T : TREE )	return NATURAL
    is			-----------------------
    -- Alignement naturel du composant ELEMENTAIRE d'un type, en octets.
    -- Scalaire : la taille de son conteneur. Tableau : l'alignement de son
    -- composant (recursif : tableau de tableaux d'octets -> 1). Record,
    -- access, inconnu : 8, conservateur (= comportement STATOFS historique).
    --| DEFAUT DOCUMENTE (vague 2, triage 28/07 cat. D) : le 8 par defaut
    --| n'est PAS un trou, c'est le miroir du STATOFS fasmg (piege n 110) --
    --| mais il est a CROISER OBLIGATOIREMENT avec le chantier n 117
    --| (alignement 8 impose aux records representes) le jour ou l'un des
    --| deux cotes bouge.  Ne pas resserrer ici sans son test-miroir.

      TS  : TREE	:= FULL_TYPE_VIEW( T );
    begin
      if  TS = TREE_VOID  or else  TS = TREE_NIL  then
        return 8;
      end if;

      if  TS.TY = DN_INTEGER  or else  TS.TY = DN_ENUMERATION  or else  TS.TY = DN_FIXED  then
        case  OPER_SIZ_CHAR( TS )  is
	when 'B'		=>  return 1;
	when 'W'		=>  return 2;
	when 'D'		=>  return 4;
	when others	=>  return 8;
        end case;
      end if;

       if  TS.TY = DN_CONSTRAINED_ARRAY  or else  TS.TY = DN_ARRAY  then
        declare
	BASE	: TREE	:= D( SM_BASE_TYPE, TS );				-- SM_COMP_TYPE vit sur la BASE
        begin									-- (idiome l.555)
	if  BASE = TREE_VOID  or else  BASE = TREE_NIL  then
	  BASE := TS;
	end if;
    -- Un tableau PACKED ne doit pas introduire l'alignement naturel
    -- de son type composant entre ses composants ni lorsqu'il est
    -- lui-même composant d'un record.
	if  BASE.TY = DN_ARRAY  and then  DB( SM_IS_PACKED, BASE )  then
	  return 1;
	end if;

	return  STATIC_TYPE_ALIGN_BYTES( D( SM_COMP_TYPE, BASE ) );
        end;
      end if;

      return 8;								-- DN_FLOAT, DN_ACCESS, DN_RECORD, autres

    end	STATIC_TYPE_ALIGN_BYTES;
	-----------------------

  begin
				-- Resolve private/incomplete to full type
    if  TYPE_SPEC.TY = DN_L_PRIVATE
    or  TYPE_SPEC.TY = DN_PRIVATE
    then
      TYPE_SPEC := D( SM_TYPE_SPEC, TYPE_SPEC );
    elsif  TYPE_SPEC.TY = DN_INCOMPLETE  then
      TYPE_SPEC := D( XD_FULL_TYPE_SPEC, TYPE_SPEC );
    end if;

    if  REPRESENTED_ITEMS.HAS_RECORD_REP( TYPE_SPEC )  then
      REPRESENTED_ITEMS.CODE_REPRESENTED_RECORD_DECL( TYPE_ID, TYPE_SPEC );
      return;
    end if;

			-------------------------
			MARQUER_LES_REGULIERS:
    declare
	-- Composant tableau a bornes NON statiques, hors discriminant (A : S
	-- avec S IS ARR (1 .. F (X)), ou A : ARR (1 .. F (X))) : ses bornes
	-- sont elaborees UNE fois au type (patron du sous-type nomme, ou bloc
	-- local _<comp>__type ci-dessous) ; l'objet le porte comme un composant
	-- DYNAMIQUE de l'option B.  Marque CD_ALIGNMENT( sous-type ) = 2.
		-------------
      procedure	MARQUER_LISTE	( CL :TREE )
      is		-------------
        DECL_S	: SEQ_TYPE;
        DECL	: TREE;
        ID_S	: SEQ_TYPE;
        ID	: TREE;
        T	: TREE;
      begin
        if  CL = TREE_VOID  or else  CL = TREE_NIL  then
	return;
        end if;
        DECL_S := LIST( D( AS_DECL_S, CL ) );
        while  not IS_EMPTY( DECL_S )  loop
	POP( DECL_S, DECL );
	if  DECL.TY /= DN_NULL_COMP_DECL  then
	  ID_S := LIST( D( AS_SOURCE_NAME_S, DECL ) );
	  while  not IS_EMPTY( ID_S )  loop
	    POP( ID_S, ID );
	    T := D( SM_OBJ_TYPE, ID );
	    if  T.TY = DN_CONSTRAINED_ARRAY
	      and then  not CODI.EST_COMPOSANT_DISCR( ID )
	      and then  STATIC_TYPE_SIZE_BITS( T ) = 0
	    then
	      declare
	        IDX_S	: SEQ_TYPE	:= LIST( D( SM_INDEX_SUBTYPE_S, T ) );
	        IDX	: TREE;
	        ELEM	: TREE		:= FULL_TYPE_VIEW( D( SM_COMP_TYPE, D( SM_BASE_TYPE, T ) ) );
	      begin
	        POP( IDX_S, IDX );
	        if  IS_EMPTY( IDX_S )								-- 1 dimension (descripteur 1-dim)
		and then  ( CODI.EST_ACCES( ELEM )  or else  ELEM.TY = DN_FLOAT
			  or else  ( D( CD_IMPL_SIZE, ELEM ) /= TREE_VOID
				   and then  DI( CD_IMPL_SIZE, ELEM ) > 0 ) )		-- element de taille statique
	        then
		DI( CD_ALIGNMENT, T, 2 );
	        end if;
	      end;
	    end if;
	  end loop;
	end if;
        end loop;
        declare
	VP	: TREE	:= D( AS_VARIANT_PART, CL );
	VAR_S	: SEQ_TYPE;
	VAR_E	: TREE;
        begin
	if  VP /= TREE_VOID  and then  VP /= TREE_NIL  then
	  VAR_S := LIST( D( AS_VARIANT_S, VP ) );
	  while  not IS_EMPTY( VAR_S )  loop
	    POP( VAR_S, VAR_E );
	    if  VAR_E.TY = DN_VARIANT  then
	      MARQUER_LISTE( D( AS_COMP_LIST, VAR_E ) );
	    end if;
	  end loop;
	end if;
        end;
      end	MARQUER_LISTE;
	-------------
    begin
      MARQUER_LISTE( D( SM_COMP_LIST, TYPE_SPEC ) );
    end	MARQUER_LES_REGULIERS;
	---------------------

    EST_DYNAMIQUE := CODI.EST_RECORD_DYNAMIQUE( TYPE_SPEC );

    DI( CD_LEVEL,	  TYPE_SPEC, INTEGER( CODI.CUR_LEVEL ) );
    DB( CD_COMPILED,  TYPE_SPEC, TRUE );

    if  CODI.DEBUG  then NEW_LINE; PUT_LINE( tab50 & "; " & TYPE_ID_STR & " RECORD TYPE INFO" ); end if;

    PUT_LINE( TYPE_ID_STR & " = '" & TYPE_ID_STR & "'" );
    PUT_LINE( "namespace " & TYPE_ID_STR );

    PUT_LINE( "VAR use__info, Q" );
    PUT_LINE( "VAR SIZ__, D" );									-- Var taille de patron
    PUT_LINE( tab & "LVA" & tab & LVL_STR & ", SIZ__" );							-- Adresse de debut de patron
    PUT_LINE( tab & "SA" & tab & LVL_STR & ", use__info" );

			------------------------
			INSERE_LES_DISCRIMINANTS:
    declare
      DSCRMT_DECL_S		: SEQ_TYPE	:= LIST( D( AS_DSCRMT_DECL_S, TYPE_DECL ) );
      DSCRMT_DECL		: TREE;
    begin
      while  not IS_EMPTY( DSCRMT_DECL_S )  loop
        POP( DSCRMT_DECL_S, DSCRMT_DECL );
        declare
	DISCRIMINANT_ID_S	: SEQ_TYPE	:= LIST( D( AS_SOURCE_NAME_S, DSCRMT_DECL ) );
	DISCRIMINANT_ID	: TREE;
        begin
	while  not IS_EMPTY( DISCRIMINANT_ID_S )  loop
	  POP( DISCRIMINANT_ID_S, DISCRIMINANT_ID );
	  declare
	    DISCRIMINANT_TYPE_SPEC	: TREE		:= D( SM_OBJ_TYPE, DISCRIMINANT_ID );
	    DISCRIMINANT_TYPE_NAME	: TREE		:= D( XD_SOURCE_NAME, DISCRIMINANT_TYPE_SPEC );
	    DISCRIMINANT_STR	:constant STRING	:= PRINT_NAME( D( LX_SYMREP, DISCRIMINANT_ID ) );
	    DISCRIMINANT_TYPE_STR	:constant STRING	:= '_' & PRINT_NAME( D( LX_SYMREP, DISCRIMINANT_TYPE_NAME ) );
	  begin
	    PUT( "USEINFO " & LVL_STR & ", " & DISCRIMINANT_STR & ", " );
	    PUT( tab & "LA " & IMAGE( DI( CD_LEVEL, DISCRIMINANT_TYPE_SPEC ) ) & ", " );
	    REGIONS_PATH( D( XD_SOURCE_NAME, DISCRIMINANT_TYPE_SPEC ) );
	    PUT_LINE( DISCRIMINANT_TYPE_STR & ".use__info" );
	  end;
	end loop;
        end;
      end loop;
    end	INSERE_LES_DISCRIMINANTS;
	------------------------

			-----------------
			INSERE_LES_CHAMPS:
    declare
		-----------------
      procedure	INSERER_COMP_LIST		( CL : TREE )
      is		-----------------
        V_DECL_S		: SEQ_TYPE;
        V_DECL		: TREE;
      begin
        if  CL = TREE_VOID  then
	return;
        end if;

        V_DECL_S := LIST( D( AS_DECL_S, CL ) );

      -- 1. Champs ordinaires de CE comp_list
        while  not IS_EMPTY( V_DECL_S )  loop
	POP( V_DECL_S, V_DECL );

	if  V_DECL.TY /= DN_NULL_COMP_DECL  then

	  declare
	    COMP_ID_S	: SEQ_TYPE := LIST( D( AS_SOURCE_NAME_S, V_DECL ) );
	    COMP_ID	: TREE;
	    COMP_TYPE	: TREE;
	  begin
	    while  not IS_EMPTY( COMP_ID_S )  loop
	      POP( COMP_ID_S, COMP_ID );

	      COMP_TYPE := D( SM_OBJ_TYPE, COMP_ID );

	      if  COMP_TYPE.TY = DN_PRIVATE  or else  COMP_TYPE.TY = DN_L_PRIVATE  then
	        COMP_TYPE := D( SM_TYPE_SPEC, COMP_TYPE );
	      end if;
			----------------------------
			PROCESS_INSERT_ONE_COMPONENT:
	      declare
	        COMP_TYPE_NAME	: TREE		:= D( XD_SOURCE_NAME, COMP_TYPE );
	        COMP_TYPE_STR	:constant STRING	:= '_' & PRINT_NAME( D( LX_SYMREP, COMP_TYPE_NAME ) );
	        COMP_ID_STR		:constant STRING	:= PRINT_NAME( D( LX_SYMREP, COMP_ID ) );
	        COMP_TYPE_DEF	: TREE		:= D( AS_TYPE_DEF, V_DECL );
	        LOCAL_INFO_STR	:constant STRING	:= '_' & COMP_ID_STR & "__type";

	      begin
	        if  CODI.EST_COMPOSANT_DISCR( COMP_ID )  then					--| (un composant REGULIER garde son bloc info :
		--| Option B : bornes propres a chaque OBJET -- elles vivent dans le
		--| descripteur de l'objet (CODE_INIT_DESCRIPTEURS), pas dans un bloc
		--| info de niveau type. CD_LEVEL pose pour les lecteurs (TYPE_LVL de
		--| CODE_INDEXED), sans bloc derriere.
		DI( CD_LEVEL, COMP_TYPE, INTEGER( CODI.CUR_LEVEL ) );

	        elsif  COMP_TYPE.TY = DN_CONSTRAINED_ARRAY  then
		--| Piege n 46 generalise aux COMPOSANTS (session 5 aout) : le noeud
		--| DN_CONSTRAINED_ARRAY anonyme revient CD_COMPILED=TRUE au compile du
		--| CORPS (rechargement DCL apres la spec) -> le bloc info imbrique
		--| sautait ; et le USEINFO retombait dans les DEUX unites sur
		--| STANDARD._<base> (patron NON contraint, SIZ=-1) via XD_SOURCE_NAME.
		--| Remede aligne sur COMPILE_ARRAY_VAR (journal A21001A) : descripteur
		--| LOCAL _<comp>__type des qu'il y a contrainte anonyme, INDEPENDANT de
		--| CD_COMPILED ; le USEINFO pointe le bloc local au niveau courant.
		--| Type/sous-type NOMME : chemin REGIONS_PATH inchange.
		declare
		  COMP_CONSTRAINT	: TREE	:= TREE_VOID;
		  USE_LOCAL_INFO	: BOOLEAN	:= FALSE;
		begin
		  if  COMP_TYPE_DEF /= TREE_VOID  and then  COMP_TYPE_DEF.TY = DN_SUBTYPE_INDICATION  then
		    COMP_CONSTRAINT := D( AS_CONSTRAINT, COMP_TYPE_DEF );
		  end if;

--		  if  COMP_CONSTRAINT /= TREE_VOID  or else  not DB( CD_COMPILED, COMP_TYPE )  then
--		    USE_LOCAL_INFO := TRUE;
		  if  COMP_CONSTRAINT /= TREE_VOID
		  or else  D( SM_TYPE_SPEC, COMP_TYPE_NAME ) /= COMP_TYPE				-- ANONYME : le nom remonte au type de base (piege n 99)
		  then
		    USE_LOCAL_INFO := TRUE;
		    DI( CD_LEVEL, COMP_TYPE, INTEGER( CODI.CUR_LEVEL ) );				-- niveau du bloc local, lu par CODE_INDEXED (TYPE_LVL)

		    PUT_LINE( LOCAL_INFO_STR & " = '" & LOCAL_INFO_STR & "'" );
		    PUT_LINE( " namespace " & LOCAL_INFO_STR );
		    PROCESS_CONSTRAINED_ARRAY_TYPE_SPEC( COMP_TYPE );
		  end if;

		  PUT( "USEINFO " & LVL_STR & ", " & COMP_ID_STR & ", " );
		  if  USE_LOCAL_INFO  then
		    PUT_LINE( tab & "LA " & LVL_STR & ", " & LOCAL_INFO_STR & ".use__info" );
		  else
		    PUT( tab & "LA " & IMAGE( DI( CD_LEVEL, COMP_TYPE ) ) & ", " );
		    REGIONS_PATH( D( XD_SOURCE_NAME, D( SM_TYPE_SPEC, COMP_TYPE_NAME ) ) );
		    PUT_LINE( COMP_TYPE_STR & ".use__info" );
		  end if;
		end;

	        else
		PUT( "USEINFO " & LVL_STR & ", " & COMP_ID_STR & ", " );
		PUT( tab & "LA " & IMAGE( DI( CD_LEVEL, FULL_TYPE_VIEW( COMP_TYPE ) ) ) & ", " );	--| ACR (F) : niveau de la base
		REGIONS_PATH( COMP_TYPE_NAME );
		PUT_LINE( COMP_TYPE_STR & ".use__info" );
	        end if;

	        if  STATIC_TYPE_SIZE_BITS( COMP_TYPE ) = 0  and then  not CODI.EST_COMPOSANT_DYNAMIQUE( COMP_ID )  then
		IS_STATIC := FALSE;
	        end if;


	      end		PROCESS_INSERT_ONE_COMPONENT;
			----------------------------
	    end loop;
	  end;
	end if;
        end loop;

      -- 2. Champs contenus dans les variantes de CE comp_list
        declare
	VP	: TREE	:= D( AS_VARIANT_PART, CL );
        begin
	if  VP /= TREE_VOID  and then  VP /= TREE_NIL  then
	  declare
	    VAR_S		: SEQ_TYPE	:= LIST( D( AS_VARIANT_S, VP ) );
	    VAR_E		: TREE;
	  begin
	    while  not IS_EMPTY( VAR_S )  loop
	      POP( VAR_S, VAR_E );

	      if  VAR_E.TY = DN_VARIANT  then
	        INSERER_COMP_LIST( D( AS_COMP_LIST, VAR_E ) );
	      end if;
	    end loop;
	  end;
	end if;
        end;

      end INSERER_COMP_LIST;
	-----------------
    begin
      INSERER_COMP_LIST( D( SM_COMP_LIST, TYPE_SPEC ) );

    end	INSERE_LES_CHAMPS;
	-----------------

    if  IS_STATIC  then
      PUT( "virtual at 0" );
      if  CODI.DEBUG  then  PUT( tab50 & "; calcul des offsets statiques" ); end if;
      NEW_LINE;
    end	if;

			-------------------------
			TRAITER_LES_DISCRIMINANTS:
    declare
      DSCRMT_DECL_S		: SEQ_TYPE	:= LIST( D( AS_DSCRMT_DECL_S, TYPE_DECL ) );
      DSCRMT_DECL		: TREE;
    begin
      while  not IS_EMPTY( DSCRMT_DECL_S )  loop
        POP( DSCRMT_DECL_S, DSCRMT_DECL );
        declare
	DISCRIMINANT_ID_S	: SEQ_TYPE	:= LIST( D( AS_SOURCE_NAME_S, DSCRMT_DECL ) );
	DISCR_TYPE_DEFN	: TREE		:= D( SM_DEFN, D( AS_NAME, DSCRMT_DECL ) );
	DISCR_TYPE_SPEC	: TREE		:= D( SM_TYPE_SPEC, DISCR_TYPE_DEFN );
	DISCRIMINANT_ID	: TREE;
	SIZE_CHAR		: CHARACTER	:= 'x';
        begin
	if  TYPE_SPEC.TY = DN_INTEGER  then
	  SIZE_CHAR := OPER_SIZ_CHAR( TYPE_SPEC );
	end if;
	while  not IS_EMPTY( DISCRIMINANT_ID_S )  loop
	  POP( DISCRIMINANT_ID_S, DISCRIMINANT_ID );

	  declare
	    DISCR_TYPE	: TREE		:= D( SM_OBJ_TYPE, DISCRIMINANT_ID );
	    DISCR_SIZE	: NATURAL;
	  begin
	    if  DISCR_TYPE.TY = DN_PRIVATE  or else  DISCR_TYPE.TY = DN_L_PRIVATE  then
	      DISCR_TYPE := D( SM_TYPE_SPEC, DISCR_TYPE );
	    end if;

	    DISCR_SIZE := DI( CD_IMPL_SIZE, DISCR_TYPE );

	    if DISCR_SIZE < CODI.STORAGE_UNIT then
	      DISCR_SIZE := CODI.STORAGE_UNIT;
	    end if;

	    PUT_LINE( "STATOFS " & PRINT_NAME( D( LX_SYMREP, DISCRIMINANT_ID ) ) & ','
			& INTEGER'IMAGE( ( DISCR_SIZE + CODI.STORAGE_UNIT - 1 ) / CODI.STORAGE_UNIT ) & ','
			& INTEGER'IMAGE( STATIC_TYPE_ALIGN_BYTES( DISCR_TYPE ) ) );

	    ALIGN_STATIC_BITS( STATIC_SIZE, DISCR_TYPE );
	    STATIC_SIZE := STATIC_SIZE
		+ CODI.STORAGE_UNIT * ( ( DISCR_SIZE + CODI.STORAGE_UNIT - 1 ) / CODI.STORAGE_UNIT );
	  end;

	end loop;
        end;
      end loop;

    end		TRAITER_LES_DISCRIMINANTS;
		-------------------------

			------------------
			TRAITER_LES_CHAMPS:
    declare
		-----------------
      procedure	TRAITER_COMP_LIST	( CL : TREE )
      is		-----------------
        V_DECL_S		: SEQ_TYPE	:= LIST( D( AS_DECL_S, CL ) );
        V_DECL		: TREE;
      begin

        while  not IS_EMPTY( V_DECL_S )  loop
	POP( V_DECL_S, V_DECL	);

	if  V_DECL.TY /= DN_NULL_COMP_DECL  then

			----------------
			CHAMPS_REGULIERS:
	  declare
	    COMP_ID_S	: SEQ_TYPE	:= LIST( D( AS_SOURCE_NAME_S, V_DECL ) );
	    COMP_ID	: TREE;
	    COMP_TYPE	: TREE;

	  begin
	    while  not IS_EMPTY( COMP_ID_S )  loop
	      POP( COMP_ID_S, COMP_ID );
	      COMP_TYPE := D( SM_OBJ_TYPE, COMP_ID );
	      if  COMP_TYPE.TY = DN_PRIVATE  or  COMP_TYPE.TY = DN_L_PRIVATE  then
	        COMP_TYPE := D( SM_TYPE_SPEC, COMP_TYPE );
	      end if;

	      declare
	        COMP_TYPE_NAME	: TREE		:= D( XD_SOURCE_NAME, COMP_TYPE );
	        COMP_TYPE_STR	:constant STRING	:= '_'  & PRINT_NAME( D( LX_SYMREP, COMP_TYPE_NAME ) );
	        COMP_ID_STR		:constant STRING	:= PRINT_NAME( D( LX_SYMREP, COMP_ID ) );
	        COMP_SIZE		: NATURAL;

	      begin
	        if  IS_STATIC  and then  CODI.EST_COMPOSANT_DYNAMIQUE( COMP_ID )  then
		--| Option B : DESCRIPTEUR dans la partie statique (aligne sur 4).
		declare
		  IDX_S	: SEQ_TYPE	:= LIST( D( SM_INDEX_SUBTYPE_S, COMP_TYPE ) );
		  IDX	: TREE;
		begin
		  POP( IDX_S, IDX );
		  if  not IS_EMPTY( IDX_S )  then
		    CODI.TROU( "CODE_RECORD_DECL composant dynamique multi-dimensions (descripteur 1-dim)", COMP_TYPE );
		  end if;
		end;
		PUT_LINE( "STATOFS " & COMP_ID_STR & ',' & INTEGER'IMAGE( CODI.DESC_TAILLE ) & ", 4" );
		STATIC_SIZE := ( ( STATIC_SIZE + 31 ) / 32 ) * 32
			   + CODI.DESC_TAILLE * CODI.STORAGE_UNIT;

	        elsif  IS_STATIC  then
		COMP_SIZE := STATIC_TYPE_SIZE_BITS( COMP_TYPE );
		if  COMP_SIZE = 0  then
		  PUT_LINE( "; OFFSET NON STATIQUE A FAIRE ; taille inconnue pour " & COMP_ID_STR );
		  raise  PROGRAM_ERROR;
		end if;


		if  COMP_SIZE < CODI.STORAGE_UNIT  then
		  COMP_SIZE := CODI.STORAGE_UNIT;
		end if;

		PUT_LINE( "STATOFS " & COMP_ID_STR & ','
			& INTEGER'IMAGE( ( COMP_SIZE + CODI.STORAGE_UNIT - 1 ) / CODI.STORAGE_UNIT ) & ','
			& INTEGER'IMAGE( STATIC_TYPE_ALIGN_BYTES( COMP_TYPE ) ) );

		ALIGN_STATIC_BITS( STATIC_SIZE, COMP_TYPE );
		STATIC_SIZE := STATIC_SIZE
			   + CODI.STORAGE_UNIT * ( ( COMP_SIZE + CODI.STORAGE_UNIT - 1 ) / CODI.STORAGE_UNIT );

	        else
		CODI.TROU( "CHAMPS_REGULIERS : offset non statique (les offsets SUIVANTS seraient faux)" );	--| vague 5, cat. D
	        end if;
	      end;
	    end loop;
	  end		CHAMPS_REGULIERS;
			----------------
	end if;
        end loop;
			----------------
			CHAMPS_VARIANTES:
        declare
	VP	: TREE := D( AS_VARIANT_PART, CL );
        begin
	if  VP /= TREE_VOID  and then  VP /= TREE_NIL  then
	  declare
	    VAR_S		: SEQ_TYPE	:= LIST( D( AS_VARIANT_S, VP ) );
	    VAR_E		: TREE;
	  begin
	    while  not IS_EMPTY( VAR_S )  loop
	      POP( VAR_S, VAR_E );

	      if  VAR_E.TY = DN_VARIANT  then
	        TRAITER_COMP_LIST( D( AS_COMP_LIST, VAR_E ) );
	      end if;
	    end loop;
	  end;
	end if;
        end		CHAMPS_VARIANTES;
			----------------

      end TRAITER_COMP_LIST;
	-----------------

    begin
      TRAITER_COMP_LIST( D( SM_COMP_LIST, TYPE_SPEC ) );

      if  IS_STATIC  and then  EST_DYNAMIQUE  then
        PUT_LINE( "STATOFS __TAILLE, 4, 4" );								--| taille totale de l'OBJET (octets)
        PUT_LINE( "STATOFS __MUTABLE, 4, 4" );								--| /= 0 : objet NON CONTRAINT (taille max,
        STATIC_SIZE := ( ( STATIC_SIZE + 31 ) / 32 ) * 32 + 64;						--| discriminants modifiables, LRM 3.7.1)
      end if;

      if  IS_STATIC  then
        PUT_LINE( "size = $" );									--| record dynamique : partie STATIQUE seule
        PUT_LINE( "end virtual" );
        PUT_LINE( tab & "LI" & tab & " size*" & IMAGE( CODI.STORAGE_UNIT ) );
        PUT_LINE( tab & "SD" & tab & LVL_STR & ", SIZ__" );							-- Taille du patron
        if  not EST_DYNAMIQUE  then									--| pas de taille statique d'OBJET : un
	DI( CD_IMPL_SIZE, TYPE_SPEC, STATIC_SIZE );							--| lecteur non adapte leve bruyamment
        end if;
      end if;

      if  D( SM_SIZE, TYPE_SPEC ) /= TREE_VOID  then
        DI( CD_IMPL_SIZE, TYPE_SPEC, DI( SM_SIZE, TYPE_SPEC ) );
      end if;

    end		TRAITER_LES_CHAMPS;
		------------------

    PUT_LINE( "end namespace" );

  end	CODE_RECORD_DECL;
	----------------


  function ROOT_RECORD ( T : TREE ) return TREE is
    R : TREE := FULL_TYPE_VIEW( T );
  begin
    while R.TY = DN_CONSTRAINED_RECORD loop
      R := FULL_TYPE_VIEW( D( SM_BASE_TYPE, R ) );
    end loop;

    return R;
  end ROOT_RECORD;

		----------------------------
  procedure	CODE_CONSTRAINED_RECORD_DECL  ( TYPE_NAME : TREE; TYPE_SPEC : TREE )
  is
    TYPE_STR	:constant STRING	:= '_' & PRINT_NAME( D( LX_SYMREP, TYPE_NAME ) );
    LVL_STR	:constant STRING	:= IMAGE( CODI.CUR_LEVEL );


    BASE_REC	: TREE		:= ROOT_RECORD( TYPE_SPEC );
    BASE_NAME	: TREE		:= D( XD_SOURCE_NAME, BASE_REC );
    BASE_STR	: constant STRING	:= '_' & PRINT_NAME( D( LX_SYMREP, BASE_NAME ) );

  procedure EMIT_BASE_PREFIX is
  begin
    REGIONS_PATH( BASE_NAME );
    PUT( BASE_STR );
  end EMIT_BASE_PREFIX;

  procedure EMIT_ALIAS ( NAME : STRING ) is
  begin
    PUT( NAME & " = " );
    EMIT_BASE_PREFIX;
    PUT_LINE( "." & NAME );
  end EMIT_ALIAS;

  procedure EMIT_COMP_LIST_ALIASES ( CL : TREE ) is
    V_DECL_S : SEQ_TYPE;
    V_DECL   : TREE;
  begin
    if CL = TREE_VOID or else CL = TREE_NIL then
      return;
    end if;

    V_DECL_S := LIST( D( AS_DECL_S, CL ) );

    while not IS_EMPTY( V_DECL_S ) loop
      POP( V_DECL_S, V_DECL );

      if V_DECL.TY /= DN_NULL_COMP_DECL then
        declare
	COMP_ID_S : SEQ_TYPE := LIST( D( AS_SOURCE_NAME_S, V_DECL ) );
	COMP_ID	: TREE;
        begin
	while not IS_EMPTY( COMP_ID_S ) loop
	  POP( COMP_ID_S, COMP_ID );
	  EMIT_ALIAS( PRINT_NAME( D( LX_SYMREP, COMP_ID ) ) );
	end loop;
        end;
      end if;
    end loop;

    declare
      VP : TREE := D( AS_VARIANT_PART, CL );
    begin
      if VP /= TREE_VOID and then VP /= TREE_NIL then
        declare
	VAR_S : SEQ_TYPE := LIST( D( AS_VARIANT_S, VP ) );
	VAR_E : TREE;
        begin
	while not IS_EMPTY( VAR_S ) loop
	  POP( VAR_S, VAR_E );

	  if VAR_E.TY = DN_VARIANT then
	    EMIT_COMP_LIST_ALIASES( D( AS_COMP_LIST, VAR_E ) );
	  end if;
	end loop;
        end;
      end if;
    end;
  end EMIT_COMP_LIST_ALIASES;

begin
  if BASE_REC.TY /= DN_RECORD then
    PUT_LINE( "; CODE_CONSTRAINED_RECORD_DECL : base non record "
	  & NODE_NAME'IMAGE( BASE_REC.TY ) );
    raise PROGRAM_ERROR;
  end if;

  DI( CD_LEVEL, TYPE_SPEC, INTEGER( CODI.CUR_LEVEL ) );
  DB( CD_COMPILED, TYPE_SPEC, TRUE );

  if D( CD_IMPL_SIZE, BASE_REC ) /= TREE_VOID then
    DI( CD_IMPL_SIZE, TYPE_SPEC, DI( CD_IMPL_SIZE, BASE_REC ) );
  end if;

  if CODI.DEBUG then
    NEW_LINE;
    PUT_LINE( tab50 & "; " & TYPE_STR & " CONSTRAINED RECORD VIEW" );
  end if;

  PUT_LINE( TYPE_STR & " = '" & TYPE_STR & "'" );
  PUT_LINE( "namespace " & TYPE_STR );

  PUT( "use__info = " );
  EMIT_BASE_PREFIX;
  PUT_LINE( ".use__info" );

  PUT( "SIZ = " );
  EMIT_BASE_PREFIX;
  PUT_LINE( ".SIZ__" );

  PUT( "SIZ__ = " );								-- objet d'un sous-type NOMME :
  EMIT_BASE_PREFIX;								-- COMPILE_RECORD_VAR lit <sous-type>.SIZ__
  PUT_LINE( ".SIZ__" );

  PUT( "size = " );
  EMIT_BASE_PREFIX;
  PUT_LINE( ".size" );

  -- Discriminants du record racine.
  declare
    DSCRMT_DECL_S : SEQ_TYPE := LIST( D( SM_DISCRIMINANT_S, BASE_REC ) );
    DSCRMT_DECL   : TREE;
  begin
    while not IS_EMPTY( DSCRMT_DECL_S ) loop
      POP( DSCRMT_DECL_S, DSCRMT_DECL );

      declare
        DISCR_ID_S : SEQ_TYPE := LIST( D( AS_SOURCE_NAME_S, DSCRMT_DECL ) );
        DISCR_ID   : TREE;
      begin
        while not IS_EMPTY( DISCR_ID_S ) loop
	POP( DISCR_ID_S, DISCR_ID );
	EMIT_ALIAS( PRINT_NAME( D( LX_SYMREP, DISCR_ID ) ) );
        end loop;
      end;
    end loop;
  end;

  -- Composants ordinaires et variants du record racine.
  EMIT_COMP_LIST_ALIASES( D( SM_COMP_LIST, BASE_REC ) );

  -- LRM 3.7.2 : contrainte evaluee UNE fois, controlee, rangee (<vue>.__D_x)
  if  TYPE_SPEC.TY = DN_CONSTRAINED_RECORD  and then  D( XD_SOURCE_NAME, TYPE_SPEC ) = TYPE_NAME  then
    EXPRESSIONS.ELABORER_DISCRIMINANTS( TYPE_SPEC );
  end if;

  PUT_LINE( "end namespace" );

  end	CODE_CONSTRAINED_RECORD_DECL;
	----------------------------


				----------------
  procedure			CODE_ACCESS_DECL		( TYPE_DECL :TREE )
  is				----------------
    TYPE_ID		: TREE		:= D( AS_SOURCE_NAME, TYPE_DECL );
    TYPE_SPEC		: TREE		:= D( SM_TYPE_SPEC, TYPE_ID );
    TYPE_STR		: constant STRING	:= '_' & PRINT_NAME( D( LX_SYMREP, TYPE_ID ) );
    RAW_DESIG_TYPE		: TREE		:= D( SM_DESIG_TYPE, TYPE_SPEC );
    DESIG_TYPE		: TREE		:= RAW_DESIG_TYPE;
    DESIG_IS_FORWARD	: BOOLEAN		:= FALSE;
    LVL_STR		:constant STRING	:= IMAGE( CODI.CUR_LEVEL );

  begin
    DI( CD_LEVEL,	   TYPE_SPEC, INTEGER( CODI.CUR_LEVEL ) );
    DB( CD_COMPILED,   TYPE_SPEC, TRUE );

  --  Le type access lui-même est complet immédiatement :
  --  sa représentation est toujours un pointeur machine.
  --  En revanche, le type désigné peut encore être une vue privée
  --  ou un incomplete.

    while  DESIG_TYPE.TY = DN_PRIVATE  or else  DESIG_TYPE.TY = DN_L_PRIVATE  loop
      if  D( SM_TYPE_SPEC, DESIG_TYPE ) = TREE_VOID  then
        exit;
      end if;

      DESIG_TYPE := D( SM_TYPE_SPEC, DESIG_TYPE );
    end loop;

    --  Si le type désigné est incomplet, l'access type est légalement
    --  déclaré avant le full type. On utilise alors le full type comme
    --  source du use_info, mais sans le marquer compilé.
    if  DESIG_TYPE.TY = DN_INCOMPLETE  then
			--------------------
			ACCESS_TO_INCOMPLETE:
      declare
        FULL_DESIG_TYPE : TREE := D( XD_FULL_TYPE_SPEC, DESIG_TYPE );
      begin
        if  FULL_DESIG_TYPE /= TREE_VOID  then
	DESIG_TYPE := FULL_DESIG_TYPE;

	--  Le full type sera codé plus tard dans la même partie déclarative.
	--  On initialise seulement son niveau pour permettre la référence
	--  forward à CELL.use__info.
	DI( CD_LEVEL, DESIG_TYPE, INTEGER( CODI.CUR_LEVEL ) );
        end if;
      end		ACCESS_TO_INCOMPLETE;
		--------------------
    end if;

    if  DESIG_TYPE /= TREE_VOID
	and then DESIG_TYPE.TY /= DN_PRIVATE
	and then DESIG_TYPE.TY /= DN_L_PRIVATE
	and then DESIG_TYPE.TY /= DN_INCOMPLETE
    then
      if  D( CD_LEVEL, DESIG_TYPE ).PT = P  and then  D( CD_LEVEL, DESIG_TYPE ).TY = DN_VIRGIN  then
      --  Cas : access vers un full type connu sémantiquement,
      --  mais déclaré/codé plus loin dans la même région.
        DI( CD_LEVEL, DESIG_TYPE, INTEGER( CODI.CUR_LEVEL ) );
        DESIG_IS_FORWARD := TRUE;
      end if;
    end if;

    if  CODI.DEBUG  then
      NEW_LINE;
      PUT_LINE( tab50 & "; " & TYPE_STR & " ACCESS TYPE INFO" );
    end if;

    PUT_LINE( TYPE_STR & " = '" & TYPE_STR & "'" );
    PUT_LINE( "namespace " & TYPE_STR );

    PUT_LINE( "VAR use__info, Q" );
    PUT_LINE( "VAR SIZ__, D" );									-- VAR taille de patron
    PUT_LINE( tab & "LVA" & tab & LVL_STR & ", SIZ__" );							-- Adresse debut de patron
    PUT_LINE( tab & "SA"  & tab & LVL_STR & ", use__info" );
    PUT_LINE( tab & "LI"  & tab & IMAGE( CODI.ADDR_SIZE * CODI.STORAGE_UNIT ) );
    PUT_LINE( tab & "SD"  & tab & LVL_STR & ", SIZ__" );							-- Taille de patron

    PUT_LINE( "VAR DESIG__u, Q" );

    if  DESIG_TYPE.TY = DN_PRIVATE  or else  DESIG_TYPE.TY = DN_L_PRIVATE
	or else  DESIG_TYPE.TY = DN_INCOMPLETE  or else  DESIG_TYPE = TREE_VOID
    then
    --  Patron désigné encore indisponible.
    --  Suffisant pour les déclarations pures de A33003A.
      PUT_LINE( tab & "LI" & tab & "0" );

    else
      declare
        DESIG_NAME  : TREE		:= D( XD_SOURCE_NAME, DESIG_TYPE );
        DESIG_STR	:constant STRING	:= '_' & PRINT_NAME( D( LX_SYMREP, DESIG_NAME ) );
        DESIG_LVL	:constant INTEGER	:= DI( CD_LEVEL, DESIG_TYPE );

      begin
        if  DESIG_IS_FORWARD  then
         --  Important : ne pas faire La ..., use__info ici.
         --  Le code de TA est exécuté avant l'initialisation de TD.use__info.
         --  On stocke donc directement le pointeur vers le bloc use_info.
	if  DESIG_TYPE.TY = DN_ENUMERATION  then
	  PUT( tab & "LCA" & tab );									-- CONSTANTE
	  REGIONS_PATH( DESIG_NAME );
	  PUT_LINE( DESIG_STR & ".SIZ" );								-- Defini par STR
	else
	  PUT( tab & "LVA" & tab & IMAGE( DESIG_LVL ) & ", " );
	  REGIONS_PATH( DESIG_NAME );
	  PUT_LINE( DESIG_STR & ".SIZ__" );								-- SIZ__ en patron
	end if;

        else
	PUT( tab & "LA " & IMAGE( DI( CD_LEVEL, DESIG_TYPE ) ) & ", " );
	REGIONS_PATH( DESIG_NAME );
	PUT_LINE( DESIG_STR & ".use__info" );
        end if;
      end;
    end if;

    PUT_LINE( tab & "SA" & tab & LVL_STR & ", DESIG__u" );

    -- access R (e) : contrainte ANONYME du designe, elaboree ici (<type>.__D_x)
    if  RAW_DESIG_TYPE.TY = DN_CONSTRAINED_RECORD
      and then  not ( D( XD_SOURCE_NAME, RAW_DESIG_TYPE ).TY = DN_SUBTYPE_ID
		  and then  D( SM_TYPE_SPEC, D( XD_SOURCE_NAME, RAW_DESIG_TYPE ) ) = RAW_DESIG_TYPE )
    then
      EXPRESSIONS.ELABORER_DISCRIMINANTS( RAW_DESIG_TYPE );
    end if;
    PUT_LINE( "end namespace" );

  end	CODE_ACCESS_DECL;
	----------------


				--^^^^^^^^^^^^^^^^^--
  procedure			  CODE_SUBTYPE_DECL		( SUBTYPE_DECL :TREE )
  is				---------------------

    SUBTYPE_ID		: TREE		:= D( AS_SOURCE_NAME, SUBTYPE_DECL) ;
    TYPE_SPEC		: TREE		:= D( SM_TYPE_SPEC, SUBTYPE_ID );
    SUBTYPE_STR		:constant STRING	:= '_' & PRINT_NAME( D( LX_SYMREP, SUBTYPE_ID	) );
    LVL_STR		:constant STRING	:= IMAGE( CODI.CUR_LEVEL );
  begin
    if  TYPE_SPEC.TY = DN_PRIVATE  or else  TYPE_SPEC.TY = DN_L_PRIVATE  then
      if  CODI.DEBUG  then
        PUT_LINE( "; CODE_SUBTYPE_DECL : skip PRIVATE subtype " & SUBTYPE_STR & " (deferred to full type)" );
      end if;
      return;

    elsif  TYPE_SPEC.TY = DN_INCOMPLETE  then
      if  CODI.DEBUG  then
        PUT_LINE( "; CODE_SUBTYPE_DECL : skip INCOMPLETE subtype " & SUBTYPE_STR & " (deferred to full type)" );
      end if;
      return;
    end if;

    if  TYPE_SPEC.TY = DN_RECORD  then
			--| subtype SS is S, S record : TYPE_SPEC EST le noeud de S (aucun
			--| noeud neuf).  Ne pas ecraser son CD_LEVEL ; exporter les alias
			--| de la vue (<SS>.size, .SIZ__, .use__info, champs) que lisent
			--| les sites qui nomment le sous-type (COMPILE_RECORD_VAR...).
      declare
        BASE	: TREE	:= D( SM_BASE_TYPE, TYPE_SPEC );
        MARQUE	: TREE	:= D( AS_NAME, D( AS_SUBTYPE_INDICATION, SUBTYPE_DECL ) );
        TYPE_ID	: TREE	:= TREE_VOID;
      begin
        if  MARQUE.TY = DN_USED_NAME_ID  or else  MARQUE.TY = DN_SELECTED  then
	if  MARQUE.TY = DN_SELECTED  then
	  MARQUE := D( AS_DESIGNATOR, MARQUE );
	end if;
	TYPE_ID := D( SM_DEFN, MARQUE );
        end if;
        if  D( XD_SOURCE_NAME, TYPE_SPEC ) = SUBTYPE_ID
	and then  TYPE_ID /= TREE_VOID  and then  TYPE_ID.TY = DN_TYPE_ID
	and then  D( SM_TYPE_SPEC, TYPE_ID ) = TYPE_SPEC
        then											--| noeud du TYPE renomme au nom du sous-type
	D( XD_SOURCE_NAME, TYPE_SPEC, TYPE_ID );						--| par l'analyse : rendre son nom au type
        end if;

        if  D( XD_SOURCE_NAME, TYPE_SPEC ) /= SUBTYPE_ID  then				--| noeud PARTAGE avec le type
	declare
	  NIVEAU	: INTEGER	:= DI( CD_LEVEL, TYPE_SPEC );
	begin
	  CODE_CONSTRAINED_RECORD_DECL( SUBTYPE_ID, TYPE_SPEC );
	  DI( CD_LEVEL, TYPE_SPEC, NIVEAU );
	end;
	return;

        elsif  BASE /= TREE_VOID  and then  BASE /= TYPE_SPEC  and then  BASE.TY = DN_RECORD  then	--| COPIE nommee du sous-type :
	declare										--| alias vers la base
	  NIVEAU	: INTEGER	:= DI( CD_LEVEL, BASE );
	begin
	  CODE_CONSTRAINED_RECORD_DECL( SUBTYPE_ID, BASE );
	  DI( CD_LEVEL, BASE, NIVEAU );
	  DI( CD_LEVEL, TYPE_SPEC, INTEGER( CODI.CUR_LEVEL ) );
	  DB( CD_COMPILED, TYPE_SPEC, TRUE );
	  if  D( CD_IMPL_SIZE, BASE ) /= TREE_VOID  then
	    DI( CD_IMPL_SIZE, TYPE_SPEC, DI( CD_IMPL_SIZE, BASE ) );
	  end if;
	end;
	return;
        end if;
      end;
    end if;

    DI( CD_LEVEL,	  TYPE_SPEC, INTEGER( CODI.CUR_LEVEL ) );
    DB( CD_COMPILED,  TYPE_SPEC, TRUE );

    if  TYPE_SPEC.TY = DN_INTEGER  or else  TYPE_SPEC.TY = DN_ENUMERATION  then
      declare									-- representation = celle de la base :
        BASE	: TREE	:= D( SM_BASE_TYPE, TYPE_SPEC );				-- recopier pour les lecteurs directs
      begin									-- de CD_IMPL_SIZE (COMP_SIZE_BITS...)
        if  BASE /= TREE_VOID  and then  BASE /= TREE_NIL  then
	DI( CD_IMPL_SIZE, TYPE_SPEC, DI( CD_IMPL_SIZE, BASE ) );
        end if;
      end;
    end if;

    if  TYPE_SPEC.TY = DN_INTEGER  then
				---------------
				INTEGER_SUBTYPE:
      declare
        SIZE_CHAR		: CHARACTER	:= OPER_SIZ_CHAR( TYPE_SPEC );
        INT_RANGE		: TREE		:= D( SM_RANGE, TYPE_SPEC );
        EXP_FST		: TREE		:= D( AS_EXP1, INT_RANGE );
        EXP_LST		: TREE		:= D( AS_EXP2, INT_RANGE );
        LVL_STR		:constant STRING	:= IMAGE( CODI.CUR_LEVEL );
        BASE_TYPE		: TREE		:= D( SM_BASE_TYPE, TYPE_SPEC );
        BASETYPE_STR	:constant STRING	:= '_' & PRINT_NAME( D( LX_SYMREP,
					   D( XD_SOURCE_NAME, BASE_TYPE ) ) );
      begin
        if  CODI.DEBUG  then NEW_LINE; PUT_LINE( tab50 & "; " & SUBTYPE_STR & " INTEGER SUBTYPE INFO" ); end if;

        PUT_LINE( SUBTYPE_STR & " = '" & SUBTYPE_STR & "'" );
        PUT_LINE( "namespace " & SUBTYPE_STR );

        PUT_LINE( "VAR use__info, Q" );
        PUT_LINE( "VAR SIZ__, D" );									-- VAR taille de patron
        PUT_LINE( tab & "LVA" & tab & LVL_STR & ", SIZ__" );						-- Adresse debut de patron
        PUT_LINE( tab & "SA" & tab & LVL_STR & ", use__info" );
        PUT_LINE( "VAR FST, " & SIZE_CHAR );
        PUT_LINE( "VAR LST, " & SIZE_CHAR );
        PUT_LINE( tab & "LI" & tab & IMAGE( DI( CD_IMPL_SIZE, TYPE_SPEC ) ) );
        PUT_LINE( tab & "SD" & tab & LVL_STR & ", SIZ__" );

        EXPRESSIONS.CODE_EXP( EXP_FST );
        PUT_LINE( tab & 'S' & SIZE_CHAR & tab & LVL_STR & ", FST" );

        EXPRESSIONS.CODE_EXP( EXP_LST );
        PUT_LINE( tab & 'S' & SIZE_CHAR & tab & LVL_STR & ", LST" );

        PUT_LINE( "VAR PARENT__u, Q" );
        PUT( tab & "LA" & tab & IMAGE( DI( CD_LEVEL, BASE_TYPE ) ) & ", " );
        REGIONS_PATH( D( XD_SOURCE_NAME, D( SM_BASE_TYPE, TYPE_SPEC ) ) );
        PUT_LINE(  BASETYPE_STR & ".use__info"	);
        PUT_LINE( tab & "SA" & tab & LVL_STR & ", PARENT__u" );

        PUT_LINE( "end namespace" );

      end		INTEGER_SUBTYPE;
		---------------

    elsif  TYPE_SPEC.TY = DN_ENUMERATION  then
				-------------------
				ENUMERATION_SUBTYPE:
      declare
        SIZE_CHAR		: CHARACTER	:= OPER_SIZ_CHAR( TYPE_SPEC );
        ENUM_RANGE		: TREE		:= D( SM_RANGE, TYPE_SPEC );
        EXP_FST		: TREE		:= D( AS_EXP1, ENUM_RANGE );
        EXP_LST		: TREE		:= D( AS_EXP2, ENUM_RANGE );
        LVL_STR		:constant STRING	:= IMAGE( CODI.CUR_LEVEL );
        BASE_TYPE		: TREE		:= D( SM_BASE_TYPE, TYPE_SPEC );
        BASETYPE_STR	:constant STRING	:= '_' & PRINT_NAME( D( LX_SYMREP,
					   D( XD_SOURCE_NAME, BASE_TYPE ) ) );
      begin

        if  CODI.DEBUG  then NEW_LINE; PUT_LINE( tab50 & "; " & SUBTYPE_STR & " ENUMERATION SUBTYPE INFO" ); end if;

        PUT_LINE( SUBTYPE_STR & " = '" & SUBTYPE_STR & "'" );
        PUT_LINE( "namespace " & SUBTYPE_STR );

        PUT_LINE( "VAR use__info, Q" );
        PUT_LINE( "VAR SIZ__, D" );									-- VAR taille de patron
        PUT_LINE( tab & "LVA" & tab & LVL_STR & ", SIZ__" );						-- Adresse debut patron
        PUT_LINE( tab & "SA" & tab & LVL_STR & ", use__info" );

        PUT_LINE( "VAR FST, " & SIZE_CHAR );
        PUT_LINE( "VAR LST, " & SIZE_CHAR );
        PUT_LINE( tab & "LI" & tab & IMAGE( DI( CD_IMPL_SIZE, TYPE_SPEC ) ) );
        PUT_LINE( tab & "SD" & tab & LVL_STR & ", SIZ__" );							-- Taille patron

        EXPRESSIONS.CODE_EXP( EXP_FST );
        PUT_LINE( tab & 'S' & SIZE_CHAR & tab & LVL_STR & ", FST" );

        EXPRESSIONS.CODE_EXP( EXP_LST );
        PUT_LINE( tab & 'S' & SIZE_CHAR & tab & LVL_STR & ", LST" );

        PUT_LINE( "VAR PARENT__u, Q" );
        PUT( tab & "LA " & IMAGE( DI( CD_LEVEL, BASE_TYPE ) ) & tab & ", " );
        REGIONS_PATH( D( XD_SOURCE_NAME, BASE_TYPE ) );
        PUT_LINE(  BASETYPE_STR & ".use__info"	);
        PUT_LINE( tab & "SA" & tab & LVL_STR & ", PARENT__u" );

        PUT_LINE( "end namespace" );

      end		ENUMERATION_SUBTYPE;
		-------------------

    elsif  TYPE_SPEC.TY = DN_FLOAT  then
			------------
			GARDE_FORMEL:
  declare
    FLOAT_RANGE : TREE := D( SM_RANGE, TYPE_SPEC );
    BASE_TYPE   : TREE := D( SM_BASE_TYPE, TYPE_SPEC );
  begin
    if FLOAT_RANGE = TREE_VOID then
      -- Cas typique : SUBTYPE SF IS F; où F est un type formel flottant.
      -- Ne surtout pas chercher AS_EXP1/AS_EXP2.
      if CODI.DEBUG then
        PUT_LINE( "; CODE_SUBTYPE_DECL : FLOAT subtype without range "
	      & SUBTYPE_STR & " treated as alias" );
      end if;

      -- Minimalement : le type est connu/compilé, mais aucun patron FST/LST
      -- propre n'est généré.
      DB( CD_COMPILED, TYPE_SPEC, TRUE );

      return;
    end if;

  end	GARDE_FORMEL;
	------------

				-------------
				FLOAT_SUBTYPE:
      declare
        FLOAT_RANGE		: TREE		:= D( SM_RANGE, TYPE_SPEC );
        EXP_FST		: TREE		:= D( AS_EXP1, FLOAT_RANGE );
        EXP_LST		: TREE		:= D( AS_EXP2, FLOAT_RANGE );
        BASE_TYPE		: TREE		:= D( SM_BASE_TYPE, TYPE_SPEC );
        BASETYPE_STR	:constant STRING	:= '_' & PRINT_NAME( D( LX_SYMREP, D( XD_SOURCE_NAME, BASE_TYPE ) ) );
      begin
        if  CODI.DEBUG  then
	NEW_LINE;
	PUT_LINE( tab50 & "; " & SUBTYPE_STR & " FLOAT SUBTYPE INFO" );
        end if;

        PUT_LINE( SUBTYPE_STR & " = '" & SUBTYPE_STR & "'" );
        PUT_LINE( "namespace " & SUBTYPE_STR );

        PUT_LINE( "VAR use__info, Q" );
        PUT_LINE( "VAR SIZ__, D" );									-- VAR taille patron
        PUT_LINE( "VAR FST, Q" );
        PUT_LINE( "VAR LST, Q" );

        PUT_LINE( tab & "LVA" & tab & LVL_STR & ", SIZ__" );						-- Adresse debut patron
        PUT_LINE( tab & "SA"  & tab & LVL_STR & ", use__info" );

        PUT_LINE( tab & "LI" & tab & IMAGE( DI( CD_IMPL_SIZE, TYPE_SPEC ) ) );
        PUT_LINE( tab & "SD" & tab & LVL_STR & ", SIZ__" );							-- Taille patron

        EXPRESSIONS.CODE_EXP( EXP_FST );
        PUT_LINE( tab & "SQ" & tab & LVL_STR & ", FST" );

        EXPRESSIONS.CODE_EXP( EXP_LST );
        PUT_LINE( tab & "SQ" & tab & LVL_STR & ", LST" );

        EMIT_FLOAT_MODEL_INFO( LVL_STR, TYPE_SPEC );						-- DIGITS .. BASE_MANTISSA, avant PARENT__u

        PUT_LINE( "VAR PARENT__u, Q" );
        PUT( tab & "LA " & IMAGE( DI( CD_LEVEL, BASE_TYPE ) ) & tab & ", " );
        REGIONS_PATH( D( XD_SOURCE_NAME, BASE_TYPE ) );
        PUT_LINE( BASETYPE_STR & ".use__info" );
        PUT_LINE( tab & "SA" & tab & LVL_STR & ", PARENT__u" );

        PUT_LINE( "end namespace" );

      end		FLOAT_SUBTYPE;
		-------------

    elsif  TYPE_SPEC.TY = DN_CONSTRAINED_ARRAY
    then
      PUT_LINE( SUBTYPE_STR & " = '" & SUBTYPE_STR & "'" );
      PUT( "namespace " & SUBTYPE_STR );
      if  CODI.DEBUG  then PUT( tab50 & "; " & SUBTYPE_STR & " CONSTRAINED ARRAY SUBTYPE INFO" ); end if;
      NEW_LINE;

      PROCESS_CONSTRAINED_ARRAY_TYPE_SPEC( TYPE_SPEC, D( AS_CONSTRAINT, D( AS_SUBTYPE_INDICATION, SUBTYPE_DECL ) ) );

    elsif  TYPE_SPEC.TY = DN_CONSTRAINED_RECORD  then
      CODE_CONSTRAINED_RECORD_DECL( SUBTYPE_ID, TYPE_SPEC );

    elsif  TYPE_SPEC.TY = DN_FIXED  then
      EMIT_FIXED_TYPE_INFO( SUBTYPE_STR, LVL_STR, TYPE_SPEC );

    elsif  TYPE_SPEC.TY = DN_CONSTRAINED_ACCESS  then
			--| subtype A3 is ACC (e) : contrainte du designe evaluee UNE
			--| fois, controlee, rangee (<sous-type>.__D_x) -- LRM 3.3.2
      PUT_LINE( SUBTYPE_STR & " = '" & SUBTYPE_STR & "'" );
      PUT_LINE( "namespace " & SUBTYPE_STR );
      declare
        DES	: TREE	:= D( SM_DESIG_TYPE, TYPE_SPEC );
        BASE	: TREE	:= D( SM_BASE_TYPE, TYPE_SPEC );
      begin
        PUT_LINE( "VAR use__info, Q" );								--| patron d'acces, comme le type (CODE_ACCESS_DECL) :
        PUT_LINE( "VAR SIZ__, D" );								--| lu par un allocateur dont le designe est ce
        PUT_LINE( tab & "LVA" & tab & LVL_STR & ", SIZ__" );					--| sous-type (NEW CA_UR'(...), c48009c)
        PUT_LINE( tab & "SA"  & tab & LVL_STR & ", use__info" );
        PUT_LINE( tab & "LI"  & tab & IMAGE( CODI.ADDR_SIZE * CODI.STORAGE_UNIT ) );
        PUT_LINE( tab & "SD"  & tab & LVL_STR & ", SIZ__" );
        PUT_LINE( "VAR DESIG__u, Q" );
        if  BASE.TY = DN_ACCESS  and then  D( XD_SOURCE_NAME, BASE ).TY = DN_TYPE_ID  then		--| patron du designe : celui de la base nommee
	  PUT( tab & "LA" & tab & IMAGE( DI( CD_LEVEL, BASE ) ) & ", " );
	  REGIONS_PATH( D( XD_SOURCE_NAME, BASE ) );
	  PUT_LINE( TYPE_INFO_STR( BASE ) & ".DESIG__u" );
        else
	  PUT_LINE( tab & "LI" & tab & "0" );
        end if;
        PUT_LINE( tab & "SA" & tab & LVL_STR & ", DESIG__u" );
        if  DES.TY = DN_CONSTRAINED_RECORD
	and then  not ( D( XD_SOURCE_NAME, DES ).TY = DN_SUBTYPE_ID
		    and then  D( SM_TYPE_SPEC, D( XD_SOURCE_NAME, DES ) ) = DES )
        then
	EXPRESSIONS.ELABORER_DISCRIMINANTS( DES );					-- designe ANONYME seulement
        end if;
      end;
      PUT_LINE( "end namespace" );

    elsif  TYPE_SPEC.TY = DN_ARRAY  then							--| SUBTYPE STR IS STRING : le noeud est celui de la
      CODE_UNCONSTRAINED_ARRAY_DECL( SUBTYPE_DECL, MARQUER => FALSE );				--| base ; patron _STR propre au nom (STR (5 .. 9)
											--| y lit _STR.FST_1 ; c36205)
    else
      PUT_LINE( ";  CODE_SUBTYPE_DECL : TYPE_SPEC.TY PAS FAIT " & NODE_NAME'IMAGE( TYPE_SPEC.TY ) );
    end if;

  end	  CODE_SUBTYPE_DECL;
	--=================--


	-----------
end	TYPES_DECLS;
	-----------

------------------------------------------------------------------------------------------------------------------------
--	1	2	3	4	5	6	7	8	9	0	1	2
