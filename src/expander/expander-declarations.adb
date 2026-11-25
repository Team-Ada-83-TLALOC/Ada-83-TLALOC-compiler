------------------------------------------------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2026 VINCENT MORIN, UBO
-- SPDX-License-Identifier: GPL-3.0-or-later
------------------------------------------------------------------------------------------------------------------------
--	1	2	3	4	5	6	7	8	9	0	1	2

separate ( EXPANDER )
				------------
	package body		DECLARATIONS
				------------
is


  package CODI	renames EXPANDER.UTILS;
  use CODI;


  -------			-----------
  package			TYPES_DECLS
  -------			-----------
  is

    procedure CODE_TYPE_DECL			( TYPE_DECL :TREE );
    procedure CODE_SUBTYPE_DECL		( SUBTYPE_DECL :TREE );
    procedure PROCESS_CONSTRAINED_ARRAY_TYPE_SPEC ( TYPE_SPEC :TREE; CONSTRAINT :TREE := TREE_VOID );
    procedure STATIC_BOUND_VALUE		( BOUND :TREE;  VAL :out INTEGER;  OK :out BOOLEAN );

  ---	-----------
  end	TYPES_DECLS;
  ---	-----------
  package body TYPES_DECLS is separate;


  procedure CODE_REP	( REP :TREE );
  procedure CODE_USE_PRAGMA	( USE_PRAGMA :TREE );



			--^^^^^^^^^--
  procedure		  CODE_DECL		( DECL :TREE )
  is			-------------
  begin
    if	 DECL.TY = DN_NULL_COMP_DECL  then  CODE_NULL_COMP_DECL( DECL );
    elsif  DECL.TY in CLASS_ID_DECL	then  CODE_ID_DECL	     ( DECL );
    elsif  DECL.TY in CLASS_ID_S_DECL	then  CODE_ID_S_DECL     ( DECL );
    elsif  DECL.TY in CLASS_REP	then  CODE_REP	     ( DECL );
    elsif  DECL.TY in CLASS_USE_PRAGMA  then  CODE_USE_PRAGMA    ( DECL );
    elsif  DECL.TY = DN_PRAGMA_ID									--| INTENTIONNEL (recensement _standrd, 28/07) :
    	or else  DECL.TY = DN_ATTRIBUTE_ID								--| entites PREDEFINIES de STANDARD (noms de pragmas,
    	or else  DECL.TY = DN_BLTN_OPERATOR_ID								--| d'attributs, operateurs intrinseques -- classe DIANA
    then  null;											--| INTENTIONNEL -- PREDEF_NAME) : AUCUNE elaboration a emettre.
												--| Tout autre PREDEF (argument_id...) continue de sonner.
    else  CODI.TROU( "CODE_DECL", DECL );								--| vague 4 : dispatch muet (fossile n 115)
    end if;

  end	CODE_DECL;
	---------



			--===========--
  procedure		  CODE_DECL_S		( DECL_S :TREE )
  is			--===========--

    DECL_SEQ	: SEQ_TYPE	:= LIST( DECL_S );
    DECL		: TREE;
  begin
    while  not IS_EMPTY( DECL_SEQ )  loop
      POP( DECL_SEQ, DECL );
      CODE_DECL( DECL );
    end loop;

  end	  CODE_DECL_S;
	--===========--


			-------------------
  procedure		CODE_NULL_COMP_DECL		( NULL_COMP_DECL :TREE )
  is			-------------------
  begin
    null;											--| INTENTIONNEL : composant null, aucun code

  end	CODE_NULL_COMP_DECL;
	-------------------


			------------
  procedure		CODE_ID_DECL		( ID_DECL :TREE )
  is			------------
  begin
    if	 ID_DECL.TY = DN_TYPE_DECL		then  TYPES_DECLS.CODE_TYPE_DECL   ( ID_DECL );
    elsif  ID_DECL.TY = DN_SUBTYPE_DECL		then  TYPES_DECLS.CODE_SUBTYPE_DECL( ID_DECL );
    elsif  ID_DECL.TY = DN_TASK_DECL		then  CODE_TASK_DECL         ( ID_DECL );
    elsif  ID_DECL.TY in CLASS_UNIT_DECL	then  CODE_UNIT_DECL         ( ID_DECL );
    elsif  ID_DECL.TY in CLASS_SIMPLE_RENAME_DECL then  CODE_SIMPLE_RENAME_DECL( ID_DECL );
    else   CODI.TROU( "CODE_ID_DECL", ID_DECL );						--| vague 4 : dispatch muet (fossile n 115)
    end if;

  end	CODE_ID_DECL;
	------------



			--------------
  procedure		CODE_ID_S_DECL		( ID_S_DECL :TREE )
  is			--------------
  begin
    if	 ID_S_DECL.TY in CLASS_EXP_DECL		then  CODE_EXP_DECL		   ( ID_S_DECL );
    elsif  ID_S_DECL.TY = DN_EXCEPTION_DECL		then  CODE_EXCEPTION_DECL	   ( ID_S_DECL );
    elsif  ID_S_DECL.TY = DN_DEFERRED_CONSTANT_DECL	then  CODE_DEFERRED_CONSTANT_DECL( ID_S_DECL );
    else   CODI.TROU( "CODE_ID_S_DECL", ID_S_DECL );						--| vague 4 : dispatch muet (fossile n 115)
    end if;

  end	CODE_ID_S_DECL;
	--------------



			--^^^^^^^^^^^--
  procedure		  CODE_HEADER		( HEADER :TREE )
  is			---------------
  begin

    if  HEADER.TY in CLASS_SUBP_ENTRY_HEADER
    then
      CODE_PARAM_S( D( AS_PARAM_S, HEADER ), (HEADER.TY = DN_FUNCTION_SPEC) );
      CODE_SUBP_ENTRY_HEADER( HEADER );

    elsif  HEADER.TY = DN_PACKAGE_SPEC
    then  CODE_PACKAGE_SPEC( HEADER );

    else
      CODI.TROU( "CODE_HEADER", HEADER );							--| vague 4 : dispatch muet (fossile n 115)

    end if;

  end	CODE_HEADER;
	-----------


			------------
  procedure		CODE_PARAM_S	( PARAM_S :TREE; FOR_FUNCTION :BOOLEAN := FALSE )
  is			------------
  begin
    declare
      PARAM_SEQ		: SEQ_TYPE	:= LIST( PARAM_S );
      PARAM		: TREE;
    begin
      CODI.NO_SUBP_PARAMS := IS_EMPTY( PARAM_SEQ );
      if  CODI.NO_SUBP_PARAMS  and  not FOR_FUNCTION  and  not CODI.IN_GENERIC_BODY  then
        return;
      end if;

      if  CODI.OUTPUT_CODE  then
        PUT( "PRMS" );
        if  CODI.DEBUG  then  PUT( tab50 & ";    debut parametrage" ); end if;
        NEW_LINE;
      end if;

      while  not IS_EMPTY( PARAM_SEQ )  loop
        POP( PARAM_SEQ, PARAM );
        CODE_PARAM( PARAM );
      end loop;

      if  CODI.OUTPUT_CODE  then
        if  CODI.IN_GENERIC_BODY  then
	PUT_LINE( tab & "PRM GFP_ofs" );
        end if;
        if  FOR_FUNCTION  then
	PUT( tab & "PRM result__ofs" );
	if  CODI.DEBUG  then  PUT( tab50 & "; resultat de fonction" ); end if;
	NEW_LINE;
        end if;
        PUT( "endPRMS" );
        if CODI.DEBUG then PUT( tab50 & ";    fin parametrage" ); end if;
        NEW_LINE;
      end if;
    end;

  end	CODE_PARAM_S;
	------------


			----------
  procedure		CODE_PARAM	( PARAM :TREE )
  is			----------

    ID_LIST	: SEQ_TYPE	:= LIST( D( AS_SOURCE_NAME_S, PARAM ) );
    ID		: TREE;

  begin
    while  not IS_EMPTY( ID_LIST )  loop
      POP( ID_LIST, ID );

      DI( CD_LEVEL, ID, INTEGER( CODI.CUR_LEVEL ) );

      if  CODI.OUTPUT_CODE  then
        if  D( SM_OBJ_TYPE, ID ).TY in CLASS_SCALAR and PARAM.TY = DN_IN  then
	PUT( tab & "PRM " & PRINT_NAME( D( LX_SYMREP, ID ) ) & "_ofs" );
        else
	PUT( tab & "PRM " & PRINT_NAME( D( LX_SYMREP, ID ) ) & "_ofs" );
        end if;
      end if;

      if  PARAM.TY = DN_IN
      then  CODE_IN ( PARAM );

      elsif  PARAM.TY = DN_OUT
      then  CODE_OUT ( PARAM );

      elsif  PARAM.TY = DN_IN_OUT
      then  CODE_IN_OUT ( PARAM );

      else
        CODI.TROU( "CODE_PARAM mode", PARAM );							--| vague 4, HORS LISTE : chaine muette

      end if;
      if  CODI.OUTPUT_CODE  then NEW_LINE; end if;
    end loop;

  end	CODE_PARAM;
	----------


  --|-------------------------------------------------------------------------------------------
  procedure CODE_IN ( ADA_IN :TREE ) is
  begin
    if  CODI.OUTPUT_CODE  then
      if  CODI.DEBUG  then PUT( tab50 & "; in" ); end if;
    end if;
  end;

  --|-------------------------------------------------------------------------------------------
  procedure CODE_IN_OUT ( ADA_IN_OUT :TREE ) is
  begin
    if  CODI.OUTPUT_CODE  then
      if  CODI.DEBUG  then PUT( tab50 & "; in out" ); end if;
    end if;
  end;

  --|-------------------------------------------------------------------------------------------
  procedure CODE_OUT ( ADA_OUT :TREE ) is
  begin
    if  CODI.OUTPUT_CODE  then
      if  CODI.DEBUG  then PUT( tab50 & "; out" ); end if;
    end if;
  end;

			----------------------
  procedure		CODE_SUBP_ENTRY_HEADER	( SUBP_ENTRY_HEADER :TREE )
  is			----------------------
  begin
    if SUBP_ENTRY_HEADER.TY = DN_PROCEDURE_SPEC  then
      null;
    elsif SUBP_ENTRY_HEADER.TY = DN_FUNCTION_SPEC  then
      null;
    else
      CODI.TROU( "CODE_SUBP_ENTRY_HEADER", SUBP_ENTRY_HEADER );						--| vague 4 : dispatch muet
    end if;
  end	CODE_SUBP_ENTRY_HEADER;
	----------------------


			-----------------
  procedure		CODE_PACKAGE_SPEC		( PACKAGE_SPEC :TREE )
  is			-----------------
  begin
    if  CODI.DEBUG  then PUT( tab50 & "; CODE_PACKAGE_SPEC" ); end if;
    NEW_LINE;
    if  CODI.GENERATE_BINARY_MAP  then
      PUT_LINE( " hexa_show '" & " spec ', $" );
    end if;

    CODE_DECL_S( D( AS_DECL_S1, PACKAGE_SPEC ) );
    CODE_DECL_S( D( AS_DECL_S2, PACKAGE_SPEC ) );

  end	CODE_PACKAGE_SPEC;
	-----------------


			-------------------
  procedure		CODE_EXCEPTION_DECL		( EXCEPTION_DECL :TREE )
  is			-------------------

		------------------
    procedure	CODE_SOURCE_NAME_S		( SOURCE_NAME_S :TREE )
    is		------------------

      SOURCE_NAME_SEQ	: SEQ_TYPE	:= LIST( SOURCE_NAME_S );
      SOURCE_NAME		: TREE;

    begin
      while  not IS_EMPTY( SOURCE_NAME_SEQ )  loop
        POP( SOURCE_NAME_SEQ, SOURCE_NAME );
        declare
	EXC_STR	:constant STRING	:= PRINT_NAME( D( LX_SYMREP, SOURCE_NAME ) );
        begin
	PUT_LINE( "STR " & EXC_STR & "__exc, " & """" & EXC_STR & """" );
        end;
      end loop;

    end	CODE_SOURCE_NAME_S;
	------------------

  begin
    CODE_SOURCE_NAME_S( D( AS_SOURCE_NAME_S, EXCEPTION_DECL ) );

  end	CODE_EXCEPTION_DECL;
	-------------------



		----------------------------------------------------

		--	DECL . ID_S_DECL .  E X P _ D E C L	--

		----------------------------------------------------


			-------------
  procedure		CODE_EXP_DECL		( EXP_DECL :TREE )
  is			-------------

  begin
    if  EXP_DECL.TY in CLASS_OBJECT_DECL
    then  CODE_OBJECT_DECL ( EXP_DECL );

    elsif  EXP_DECL.TY = DN_NUMBER_DECL
    then  CODE_NUMBER_DECL ( EXP_DECL );

    else
      CODI.TROU( "CODE_EXP_DECL", EXP_DECL );								--| vague 4, HORS LISTE : dispatch muet
    end if;

  end	CODE_EXP_DECL;
	-------------


			----------------
  procedure		CODE_OBJECT_DECL		( OBJECT_DECL :TREE )
  is			----------------

    SRC_NAME_SEQ	: SEQ_TYPE	:= LIST( D( AS_SOURCE_NAME_S, OBJECT_DECL ) );
    SRC_NAME	: TREE;

  begin
    while  not IS_EMPTY( SRC_NAME_SEQ )  loop
      POP( SRC_NAME_SEQ, SRC_NAME );
      if  not CODI.IN_GENERIC_BODY  or else  ( CODI.CUR_LEVEL /= CODI.GENERIC_BASE_LEVEL )  then
        CODE_VC_NAME( SRC_NAME, OBJECT_DECL );
      end if;
    end loop;

  end	CODE_OBJECT_DECL;
	----------------


			----------------
  procedure		CODE_NUMBER_DECL		( NUMBER_DECL :TREE ) is
  begin
    null;												--| INTENTIONNEL : DN_NUMBER_ID est plie A L'USAGE via
												--| SM_INIT_EXP (expressions, CODE_USED_OBJECT_ID) --
												--| rien a elaborer ici (triage 28/07)
  end	CODE_NUMBER_DECL;
	----------------


			---------------------------
  procedure		CODE_DEFERRED_CONSTANT_DECL	( DEFERRED_CONSTANT_DECL :TREE )
  is			---------------------------
  begin
			--| INTENTIONNEL (reclassement n 6, recensement idl-sem_phase
			--| 28/07 -- la porte de sortie pre-ecrite en vague 4 est prise) :
			--| constante DIFFEREE, LRM 7.4.  L'elaboration a lieu a la
			--| COMPLETION : la declaration complete de la partie PRIVEE est
			--| un object_decl ordinaire, et CODE_PACKAGE_SPEC elabore bien
			--| AS_DECL_S1 PUIS AS_DECL_S2 (verifie).  Meme modele que les
			--| types prives << deferred to full type >>.  Caveat : les
			--| usages doivent resoudre vers l'objet COMPLETE (liaison
			--| front-end) -- atteste par l'historique du bootstrap.
    null;												--| INTENTIONNEL (cf. ci-dessus)

  end	CODE_DEFERRED_CONSTANT_DECL;
	---------------------------



			------------
  procedure		CODE_VC_NAME		( VC_NAME :TREE; OBJECT_DECL :TREE := TREE_VOID )
  is			------------

    VC_ADDRESS		: TREE			:= D( SM_ADDRESS, VC_NAME );				-- adresse eventuelle

			--------------
    function		OVERLAY_TARGET		return TREE
    is			--------------
			--| C8 (oracle ADDR_OV1) : cible d'un overlay STATIQUE PAR NOM --
			--| << for X use at Y'ADDRESS >>, Y objet autonome (ni renames)
			--| ou PARAMETRE in.  La contrainte de NIVEAU appartient aux
			--| USAGERS : equation/LVA exigent le meme frame ; la voie
			--| parametre adresse FP(niveau cible) explicitement (univ_ops :
			--| VDP declare dans un BLOC, INC_LEVEL au-dessus de V).
			--| La resolution est alors DELEGUEE A
			--| FASMG par equation de symbole ( X_disp = Y_disp ) : meme
			--| cellule de frame, zero code -- et le seul schema qui couvre
			--| aussi les SCALAIRES (acces par VALEUR directe dans le slot,
			--| aucune indirection a detourner).  TREE_VOID sinon.
	  PREFIX	: TREE;
	  TARGET	: TREE;
    begin
      if  VC_ADDRESS = TREE_VOID  or else  VC_ADDRESS.TY /= DN_ATTRIBUTE  then
        return  TREE_VOID;
      end if;
      if  PRINT_NAME( D( LX_SYMREP, D( AS_USED_NAME_ID, VC_ADDRESS ) ) ) /= "ADDRESS"  then
        return  TREE_VOID;
      end if;
      PREFIX := D( AS_NAME, VC_ADDRESS );
      if  PREFIX.TY /= DN_USED_OBJECT_ID  then
        return  TREE_VOID;
      end if;

      TARGET := D( SM_DEFN, PREFIX );
      if  TARGET.TY in CLASS_VC_NAME  then
        if  DB( SM_RENAMES_OBJ, TARGET )  then								-- le _disp d'un renames porte une ADRESSE
	return TREE_VOID;
        end if;
      elsif  TARGET.TY = DN_IN_ID  or else  TARGET.TY = DN_IN_OUT_ID  then					-- C8 (univ_ops) : cible = PARAMETRE in --
        null;											--| slot = VALEUR (scalaire) ou @doublet (composite, n 91/94)
      else
        return TREE_VOID;
      end if;

      return  TARGET;

    end	OVERLAY_TARGET;
	--------------


  begin
    declare
      TYPE_SPEC	: TREE	:= D( SM_OBJ_TYPE, VC_NAME );

		-----------------------
      procedure	COMPILE_VC_NAME_INTEGER	( VC_NAME :TREE )
      is		-----------------------

        OPER_TYPE		: CHARACTER	:= OPER_SIZ_CHAR( TYPE_SPEC );
        INIT_EXP		: TREE		:= D( SM_INIT_EXP, VC_NAME );

      begin
        if  VC_ADDRESS /= TREE_VOID  then								-- C8 : clause d'adresse = OVERLAY (LRM 13.5)
	declare
	  TGT	: TREE	:= OVERLAY_TARGET;
	begin
	  if  TGT = TREE_VOID  or else  INIT_EXP /= TREE_VOID
		or else  TGT.TY  not in  CLASS_VC_NAME							-- parametre : pas de symbole _disp, pas d'equation
		or else  DI( CD_LEVEL, TGT ) /= INTEGER( CODI.CUR_LEVEL )					-- equation : meme frame requis (ex-garde du helper)
		or else  CODI.FULL_TYPE_VIEW( D( SM_OBJ_TYPE, TGT ) ).TY  not in  CLASS_SCALAR			-- slot cible = VALEUR : l'equation exige la meme sorte des deux cotes
	  then
	    CODI.TROU( "COMPILE_VC_NAME_INTEGER overlay 'ADDRESS non statique-par-nom (ou avec init)", VC_NAME );	--| discrimine (n 122) : absolue/dynamique, renames, autre niveau ; retombee : objet DISTINCT, FINC SUSPECT
	  else
	    PUT( PRINT_NAME( D( LX_SYMREP, VC_NAME ) ) & "_disp = " & PRINT_NAME( D( LX_SYMREP, TGT ) ) & "_disp" );
	    if  CODI.DEBUG  then PUT( tab50 & "; variable entiere OVERLAY : equation fasmg, meme slot" ); end if;
	    NEW_LINE;
	    DI( CD_LEVEL, VC_NAME, INTEGER( CODI.CUR_LEVEL ) );
	    return;
	  end if;
	end;
        end if;

        PUT( "VAR " & PRINT_NAME( D( LX_SYMREP, VC_NAME ) ) & "_disp, " & OPER_TYPE );
        if  CODI.DEBUG  then PUT( tab50 & "; variable entiere" ); end if;
        NEW_LINE;
        DI( CD_LEVEL,     VC_NAME, INTEGER( CODI.CUR_LEVEL ) );

	if  INIT_EXP /= TREE_VOID  then
	  EXPRESSIONS.CODE_EXP( INIT_EXP );
	  EXPRESSIONS.CODE_RANGE_CHECK( TYPE_SPEC );							-- E-D1 : gamme du sous-type de l'objet
	  CODI.STORE( VC_NAME );
	end if;

      end COMPILE_VC_NAME_INTEGER;
	-----------------------


		---------------------
      procedure	COMPILE_VC_NAME_FIXED	( VC_NAME :TREE )
      is		---------------------

        OPER_TYPE		: CHARACTER;
        INIT_EXP		: TREE		:= D( SM_INIT_EXP, VC_NAME );
        IS_GENERIC_FORMAL	: BOOLEAN		:= FALSE;
        VAR_NAME		:constant STRING	:= PRINT_NAME( D( LX_SYMREP, VC_NAME ) );
      begin
        if  VC_ADDRESS /= TREE_VOID  then								-- Clause adressage presente
	PUT_LINE( "; COMPILE_VC_NAME_FIXED ADDRESS CLAUSE non geree" );
	raise  PROGRAM_ERROR;
        end if;

        if  not CODI.IN_GENERIC_BODY  then
	OPER_TYPE := OPER_SIZ_CHAR( TYPE_SPEC );

        elsif  EXPRESSIONS.IS_GENERIC_FORMAL_TYPE( D( XD_SOURCE_NAME, TYPE_SPEC ) ) then
	IS_GENERIC_FORMAL := TRUE;
	OPER_TYPE := 'Q';										-- Place maximale, on ne sait pas quelle taille actuelle sera prise

        else
	OPER_TYPE := OPER_SIZ_CHAR( TYPE_SPEC );
        end if;

<<NORMALE>>
       PUT( "VAR "  & VAR_NAME & "_disp, " & OPER_TYPE );
       if  CODI.DEBUG  then PUT( tab50  & "; variable fixed" ); end	if;
	NEW_LINE;
	DI( CD_LEVEL,     VC_NAME, INTEGER( CODI.CUR_LEVEL ) );

        if  INIT_EXP /= TREE_VOID  then
	if  IS_GENERIC_FORMAL  then
	  PUT_LINE( tab & "LVA " & IMAGE( CUR_LEVEL ) & ", " & VAR_NAME & "_disp" );
	end if;

	EXPRESSIONS.CODE_EXP( INIT_EXP );

	if  not IS_GENERIC_FORMAL  then
	  CODI.STORE( VC_NAME );

	else											-- Acceder a variable de type instancie
	  PUT_LINE( tab & "LA " & IMAGE( GENERIC_BASE_LEVEL+1 ) & ',' & tab & "-GFP_ofs" );
	  PUT_LINE( tab & "LA , -" & PRINT_NAME( D( LX_SYMREP, D( XD_SOURCE_NAME, TYPE_SPEC ) ) )  & "__st_ofs" );
	  PUT_LINE( tab & "CALLI" );
	end if;
        end if;

      end COMPILE_VC_NAME_FIXED;
	---------------------


		---------------------
      procedure	COMPILE_VC_NAME_FLOAT	( VC_NAME :TREE )
      is		---------------------

        OPER_TYPE		: CHARACTER	:= OPER_SIZ_CHAR( TYPE_SPEC );
        INIT_EXP		: TREE		:= D( SM_INIT_EXP, VC_NAME );

      begin
        if  VC_ADDRESS /= TREE_VOID  then								-- Clause adressage présente
	PUT_LINE( "; COMPILE_VC_NAME_FLOAT ADDRESS CLAUSE non geree" );
	raise  PROGRAM_ERROR;
        end if;

        PUT( "VAR " & PRINT_NAME( D( LX_SYMREP, VC_NAME ) ) & "_disp, " & OPER_TYPE );
        if  CODI.DEBUG  then PUT( tab50 & "; variable flottante" ); end if;
        NEW_LINE;
        DI( CD_LEVEL, VC_NAME, INTEGER( CODI.CUR_LEVEL ) );

        if  INIT_EXP /= TREE_VOID  then
	EXPRESSIONS.CODE_EXP( INIT_EXP );
	CODI.STORE( VC_NAME );
        end if;

      end COMPILE_VC_NAME_FLOAT;
	---------------------


			---------------------------
      procedure		COMPILE_VC_NAME_ENUMERATION	( VC_NAME, TYPE_SPEC :TREE )
      is			---------------------------

        NAME	:constant STRING	:= PRINT_NAME( D(LX_SYMREP, CODI.TYPE_SYMREP ) );

		-------------------------
        procedure	COMPILE_VC_NAME_BOOL_CHAR	( VC_NAME :TREE )
        is	-------------------------

	OPER_TYPE		: CHARACTER	:= OPER_SIZ_CHAR( TYPE_SPEC );
	INIT_EXP		: TREE		:= D( SM_INIT_EXP, VC_NAME );

        begin
	PUT( "VAR " & PRINT_NAME( D( LX_SYMREP, VC_NAME ) ) & "_disp, " & OPER_TYPE );
	if  CODI.DEBUG  then PUT( tab50 & "; variable bool char enum" ); end if;
	NEW_LINE;

	DI( CD_LEVEL,     VC_NAME, INTEGER( CODI.CUR_LEVEL ) );
	DB( CD_COMPILED,  VC_NAME, TRUE );

	if  INIT_EXP /= TREE_VOID  then
	  EXPRESSIONS.CODE_EXP( INIT_EXP );
	  EXPRESSIONS.CODE_RANGE_CHECK( TYPE_SPEC );						-- E-D1 : gamme du sous-type de l'objet
	  CODI.STORE( VC_NAME );
	end if;

        end	COMPILE_VC_NAME_BOOL_CHAR;
		-------------------------

      begin
        if  VC_ADDRESS /= TREE_VOID  then								-- Clause adressage présente
	PUT_LINE( "; COMPILE_VC_NAME_ENUMERATION ADDRESS CLAUSE non geree" );
	raise  PROGRAM_ERROR;
        end if;

        if  NAME = "BOOLEAN"
        then  COMPILE_VC_NAME_BOOL_CHAR( VC_NAME );

        elsif  NAME = "CHARACTER"
        then  COMPILE_VC_NAME_BOOL_CHAR( VC_NAME );

        else  COMPILE_VC_NAME_INTEGER( VC_NAME );
        end if;

      end COMPILE_VC_NAME_ENUMERATION;
	---------------------------


		------------------
      procedure	COMPILE_ACCESS_VAR  ( VAR_ID, TYPE_SPEC :TREE )
      is		------------------

        LVL		: LEVEL_NUM	renames CODI.CUR_LEVEL;
        LVL_STR		: constant STRING := IMAGE( CODI.CUR_LEVEL );
        VAR_STR		: constant STRING := PRINT_NAME( D( LX_SYMREP, VAR_ID ) );

      begin
        if  VC_ADDRESS /= TREE_VOID  then								-- Clause adressage présente
	PUT_LINE( "; COMPILE_ACCESS_VAR ADDRESS CLAUSE non geree" );
	raise  PROGRAM_ERROR;
        end if;

        DI( CD_LEVEL,     VAR_ID, INTEGER( LVL ) );
        DB( CD_COMPILED,  VAR_ID, TRUE );

        PUT_LINE( "VAR " & VAR_STR & "_disp, Q" );

        declare
		INIT_EXP		: TREE	:= D( SM_INIT_EXP, VAR_ID );
        begin
		if  INIT_EXP = TREE_VOID  then
		  PUT_LINE( tab & "LI" & tab & "0" );							-- null access
		else
		  EXPRESSIONS.CODE_EXP( INIT_EXP );
		  EXPRESSIONS.CODE_RANGE_CHECK( D( SM_OBJ_TYPE, VAR_ID ) );				-- sous-type d'acces contraint (3.8)
		end if;

		PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & VAR_STR & "_disp" );
        end;

      end COMPILE_ACCESS_VAR;
	------------------


		-----------------
      procedure	COMPILE_ARRAY_VAR	( VC_NAME, TYPE_SPEC :TREE )
      is		-----------------
        VC_STR		:constant STRING		:= PRINT_NAME( D( LX_SYMREP, VC_NAME ) );
        TYPE_NAME		: TREE			:= D( XD_SOURCE_NAME, TYPE_SPEC );
        TYPE_LEVEL		: INTEGER;
        TYPE_NAME_STR	:constant STRING		:= '_' & PRINT_NAME( D( LX_SYMREP, TYPE_NAME ) );
        LOCAL_TYPE_INFO_STR	:constant STRING		:= '_' & VC_STR & "__type";
        DIM_NBR		: NATURAL			:= 1;
        LVL		: LEVEL_NUM		renames CODI.CUR_LEVEL;
        LVL_STR		:constant STRING		:= IMAGE( CODI.CUR_LEVEL );
        ANONYMOUS_SUBTYPE	: BOOLEAN			:= FALSE;
        USE_LOCAL_TYPE_INFO	: BOOLEAN			:= FALSE;
        OVERLAY_TGT		: TREE			:= OVERLAY_TARGET;					-- C8 : overlay statique-par-nom (equation fasmg / LVA)
        OVERLAY_TGT_TYPE	: TREE			:= TREE_VOID;					-- vue complete du type de la cible (posee en tete de corps)
        OVERLAY_EQUATE	: BOOLEAN			:= FALSE;						-- cible COMPOSITE : equation, cellule data_ptr PARTAGEE
        OVERLAY_LVA		: BOOLEAN			:= FALSE;						-- cible SCALAIRE  : data_ptr := @slot de la cible (print_nod)
        DO_OVERLAY		: BOOLEAN			:= FALSE;

			--------------------
        procedure		PUT_TYPE_INFO_PREFIX
        is		--------------------
        begin
	if  USE_LOCAL_TYPE_INFO  then
	  PUT( LOCAL_TYPE_INFO_STR );
	else
	  REGIONS_PATH( TYPE_NAME );
	  PUT( TYPE_NAME_STR );
	end if;
        end	PUT_TYPE_INFO_PREFIX;
		--------------------

			--------------
        procedure		COVAR_ALLOCATE
        is		--------------
        begin
	PUT( tab & "LD" & tab & IMAGE( TYPE_LEVEL ) & ", " );						-- LOAD SIZ FOR ALLOCATION
	PUT_TYPE_INFO_PREFIX;
	PUT_LINE( ".SIZ__" );
	PUT_LINE( tab & "LI" & tab & '8' );
	PUT_LINE( tab & "DIV" );

	PUT_LINE( tab & "CO_VAR" );
	PUT( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "_disp" );
	if  CODI.DEBUG  then PUT( tab50 & "; array data ptr at _disp" ); end if;
	NEW_LINE;

        end	COVAR_ALLOCATE;
		--------------


		------------------------------
      procedure	UNCONSTRAINED_AGGREGATE_OBJECT	( AGG :TREE )
      is		------------------------------
	-- Objet non contraint initialise par agregat (RM83 4.3.2) :
	-- bornes deduites, bloc info ANONYME, __u re-pointe dessus.
	-- Idiome du doublet anonyme (cf. CODE_ARRAY_AGGREGATE_OPERAND).
	-- Deliberement conservateur : positionnel a cardinal statique,
	-- ou nomme a choix DN_NUMERIC_LITERAL (precedent
	-- IS_STATIC_INTEGER_BOUND). Tout le reste : refus BRUYANT.

        BASE_TYPE		: TREE		:= D( SM_BASE_TYPE, TYPE_SPEC );
        COMP_TYPE		: TREE		:= D( SM_COMP_TYPE, BASE_TYPE );
        COMP_BITS		: INTEGER := DI( CD_IMPL_SIZE, COMP_TYPE );
        COMP_BYTES		: INTEGER := COMP_BITS / CODI.STORAGE_UNIT;
        INFO_STR		:constant STRING	:= '_' & VC_STR & "__agg_info";

        SEEN_POSITIONAL	: BOOLEAN := FALSE;
        SEEN_NAMED		: BOOLEAN := FALSE;
        ALL_CHOICES_STATIC	: BOOLEAN := TRUE;
        NB_ELEMENTS		: NATURAL := 0;
        MIN_CHOICE		: INTEGER := INTEGER'LAST;
        MAX_CHOICE		: INTEGER := INTEGER'FIRST;

			-------
        procedure	EMIT_LI		( VALUE :INTEGER )
        is		-------
        begin
	if  VALUE < 0  then						-- convention LI 1 / NEG
	  PUT_LINE( tab & "LI" & tab & IMAGE( -VALUE ) );
	  PUT_LINE( tab & "NEG" );
	else
	  PUT_LINE( tab & "LI" & tab & IMAGE( VALUE ) );
	end if;
        end	EMIT_LI;
	-------

		----------------------
        function	IS_STATIC_CHOICE_EXP	( EXP :TREE ) return BOOLEAN
        is	----------------------
        begin
	return  EXP /= TREE_VOID  and then  EXP.TY = DN_NUMERIC_LITERAL;
        end	IS_STATIC_CHOICE_EXP;
		----------------------

		-----------------
        procedure	NOTE_CHOICE_VALUE	( VALUE :INTEGER )
        is	-----------------
        begin
	if  VALUE < MIN_CHOICE  then  MIN_CHOICE := VALUE;  end if;
	if  VALUE > MAX_CHOICE  then  MAX_CHOICE := VALUE;  end if;
        end	NOTE_CHOICE_VALUE;
		-----------------

		-----------------
        procedure	ANALYSE_AGGREGATE
        is	-----------------
	NORM_SEQ  : SEQ_TYPE	:= LIST( D( SM_NORMALIZED_COMP_S, AGG ) );
	ASSOC	: TREE;
        begin
	while not  IS_EMPTY( NORM_SEQ )  loop
	  POP( NORM_SEQ, ASSOC );

	  if  ASSOC.TY = DN_NAMED  then
	    SEEN_NAMED := TRUE;
				-------------------
				ANALYSE_CHOICE_LIST:
	    declare
	      CHOICES	: SEQ_TYPE	:= LIST( D( AS_CHOICE_S, ASSOC ) );
	      CH		: TREE;
	      EXP1	: TREE;
	      EXP2	: TREE;
	    begin
	      while not  IS_EMPTY( CHOICES )  loop
	        POP( CHOICES, CH );

	        if  CH.TY = DN_CHOICE_EXP  then
		EXP1 := D( AS_EXP, CH );
		if  IS_STATIC_CHOICE_EXP( EXP1 )  then
		  NOTE_CHOICE_VALUE( DI( SM_VALUE, EXP1 ) );
		else
		  ALL_CHOICES_STATIC := FALSE;
		end if;

	        elsif  CH.TY = DN_CHOICE_RANGE  then
		EXP1 := D( AS_EXP1, D( AS_DISCRETE_RANGE, CH ) );
		EXP2 := D( AS_EXP2, D( AS_DISCRETE_RANGE, CH ) );
		if  IS_STATIC_CHOICE_EXP( EXP1 )
		  and then  IS_STATIC_CHOICE_EXP( EXP2 )
		then
		  NOTE_CHOICE_VALUE( DI( SM_VALUE, EXP1 ) );
		  NOTE_CHOICE_VALUE( DI( SM_VALUE, EXP2 ) );
		else
		  ALL_CHOICES_STATIC := FALSE;
		end if;

	        else							-- DN_CHOICE_OTHERS...
				-- others : bornes indeterminables sur objet
				-- non contraint (RM83 4.3.2), sem aurait du
				-- refuser -- refus bruyant par prudence.
		ALL_CHOICES_STATIC := FALSE;
	        end if;
	      end loop;
	    end	ANALYSE_CHOICE_LIST;
		-------------------
	  else								-- expression nue
	    SEEN_POSITIONAL := TRUE;
	    NB_ELEMENTS := NB_ELEMENTS + 1;
	  end if;
	end loop;
        end	ANALYSE_AGGREGATE;
		-----------------

		-----------------
        function	FIRST_INDEX_RANGE	return TREE
        is	-----------------
	-- Range du sous-type d'index (idiome ADD_INDEX_DIMENSION) ;
	-- verifie au passage que le type est MONO-dimensionnel.
	IDX_S	: SEQ_TYPE	:= LIST( D( SM_INDEX_S, BASE_TYPE ) );
	IDX	: TREE;
        begin
	POP( IDX_S, IDX );

	if not  IS_EMPTY( IDX_S )  then
	  PUT_LINE( "; COMPILE_ARRAY_VAR : agregat non contraint MULTIDIM non fait" );
	  raise PROGRAM_ERROR;
	end if;

	if  IDX.TY = DN_INDEX  then
	  return D( SM_RANGE, D( SM_TYPE_SPEC, IDX ) );
	else
	  return D( SM_RANGE, IDX );
	end if;
        end	FIRST_INDEX_RANGE;
		-----------------

      begin									-- UNCONSTRAINED_AGGREGATE_OBJECT

        ANALYSE_AGGREGATE;

        if  SEEN_POSITIONAL  and  SEEN_NAMED  then				-- melange : illegal RM83 4.3
	PUT_LINE( "; COMPILE_ARRAY_VAR : agregat mixte positionnel/nomme" );
	raise PROGRAM_ERROR;
        end if;

        if  SEEN_NAMED  and then  not ALL_CHOICES_STATIC  then
	PUT_LINE( "; COMPILE_ARRAY_VAR : agregat non contraint a choix non statiques" );
	raise PROGRAM_ERROR;
        end if;

        if  SEEN_POSITIONAL  and then  NB_ELEMENTS = 0  then
	PUT_LINE( "; COMPILE_ARRAY_VAR : agregat vide" );
	raise PROGRAM_ERROR;
        end if;

        -- ---- Bloc info anonyme (layout aligne sur virtual at 4) ----
        PUT_LINE( "namespace " & INFO_STR );
        PUT_LINE( "  VAR SIZ__, D" );
        PUT_LINE( "  VAR _COMP_SIZ, D" );
        PUT_LINE( "  VAR _FST_1, D" );
        PUT_LINE( "  VAR _LST_1, D" );
        PUT_LINE( "end namespace" );

        -- ---- Bornes deduites ; laisse COUNT en sommet de pile ----
        if  SEEN_POSITIONAL  then
				-- RM83 4.3.2 : FST = INDEX'FIRST,
				-- LST = FST + n - 1 (n statique).
				-----------------
				POSITIONAL_BOUNDS:
	declare
	  RNG	: TREE	:= FIRST_INDEX_RANGE;
	begin
	  EXPRESSIONS.CODE_EXP( D( AS_EXP1, RNG ) );			-- INDEX'FIRST
	  PUT_LINE( tab & "DUP" );
	  PUT_LINE( tab & "SD  " & LVL_STR & ", " & INFO_STR & "._FST_1" );
	  EMIT_LI( INTEGER( NB_ELEMENTS ) - 1 );
	  PUT_LINE( tab & "ADD" );
	  PUT_LINE( tab & "SD  " & LVL_STR & ", " & INFO_STR & "._LST_1" );
	  EMIT_LI( INTEGER( NB_ELEMENTS ) );				-- COUNT
	end	POSITIONAL_BOUNDS;
		-----------------
        else								-- nomme statique
				-- RM83 4.3.2 : bornes = min/max des choix
				-- (couverture contigue garantie par sem).
	EMIT_LI( MIN_CHOICE );
	PUT_LINE( tab & "SD  " & LVL_STR & ", " & INFO_STR & "._FST_1" );
	EMIT_LI( MAX_CHOICE );
	PUT_LINE( tab & "SD  " & LVL_STR & ", " & INFO_STR & "._LST_1" );
	EMIT_LI( MAX_CHOICE - MIN_CHOICE + 1 );				-- COUNT
        end if;

        -- ---- COMP_SIZ ; SIZ := COUNT * COMP_BITS ----
        PUT_LINE( tab & "LI"  & tab & IMAGE( COMP_BITS ) );
        PUT_LINE( tab & "SD  " & LVL_STR & ", " & INFO_STR & "._COMP_SIZ" );
        PUT_LINE( tab & "DUP" );						-- COUNT preserve pour l'allocation
        if  COMP_BITS /= 1  then
	PUT_LINE( tab & "LI" & tab & IMAGE( COMP_BITS ) );
	PUT_LINE( tab & "MUL" );
        end if;
        PUT_LINE( tab & "SD  " & LVL_STR & ", " & INFO_STR & ".SIZ__" );

        -- ---- Allocation co-pile : COUNT * COMP_BYTES octets ----
        if  COMP_BYTES /= 1  then
	PUT_LINE( tab & "LI" & tab & IMAGE( COMP_BYTES ) );
	PUT_LINE( tab & "MUL" );
        end if;
        PUT_LINE( tab & "CO_VAR" );
        PUT( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "_disp" );
        if  CODI.DEBUG  then PUT( tab50 & "; array data ptr at _disp" ); end if;
        NEW_LINE;

        -- ---- Re-pointer __u sur le bloc anonyme (ecrase use__info du type) ----
        PUT_LINE( tab & "LVA " & LVL_STR & ", " & INFO_STR & ".SIZ__" );
        PUT( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "__u" );
        if  CODI.DEBUG  then PUT( tab50 & "; array info ptr at __u (agregat, bornes deduites)" ); end if;
        NEW_LINE;

        -- ---- Donnees : chemin existant inchange ----
        PUT_LINE( tab & "LA" & tab & LVL_STR & ", " & VC_STR & "_disp" );
        EXPRESSIONS.CODE_AGGREGATE( AGG, TYPE_SPEC );

      end UNCONSTRAINED_AGGREGATE_OBJECT;
	------------------------------

      begin
        if  OVERLAY_TGT /= TREE_VOID  then								-- C8 : la SORTE de la cible choisit le mecanisme
	OVERLAY_TGT_TYPE := CODI.FULL_TYPE_VIEW( D( SM_OBJ_TYPE, OVERLAY_TGT ) );
	OVERLAY_EQUATE   := OVERLAY_TGT.TY in CLASS_VC_NAME						-- parametre : pas de symbole _disp (TROU, cf. grille v2.2)
		     and then  DI( CD_LEVEL, OVERLAY_TGT ) = INTEGER( CODI.CUR_LEVEL )			-- equation/LVA : meme frame requis (ex-garde du helper)
		     and then  ( OVERLAY_TGT_TYPE.TY = DN_ARRAY   or else  OVERLAY_TGT_TYPE.TY = DN_CONSTRAINED_ARRAY
		     or else  OVERLAY_TGT_TYPE.TY = DN_RECORD  or else  OVERLAY_TGT_TYPE.TY = DN_CONSTRAINED_RECORD );
	OVERLAY_LVA      := OVERLAY_TGT.TY in CLASS_VC_NAME
		     and then  DI( CD_LEVEL, OVERLAY_TGT ) = INTEGER( CODI.CUR_LEVEL )
		     and then  OVERLAY_TGT_TYPE.TY in CLASS_SCALAR;
	DO_OVERLAY       := OVERLAY_EQUATE  or else  OVERLAY_LVA;
        end if;

        declare
	SOURCE_CONSTRAINT		: TREE		:= TREE_VOID;
        begin
	if  OBJECT_DECL /= TREE_VOID  and then  D( AS_TYPE_DEF, OBJECT_DECL ) /= TREE_VOID  then
	  declare
	    TYPE_DEF	: TREE	:= D( AS_TYPE_DEF, OBJECT_DECL );
	  begin
	    if  TYPE_DEF.TY = DN_SUBTYPE_INDICATION  then
	      SOURCE_CONSTRAINT := D( AS_CONSTRAINT, TYPE_DEF );
	    elsif  TYPE_DEF.TY = DN_CONSTRAINED_ARRAY_DEF  then
	      SOURCE_CONSTRAINT := D( AS_CONSTRAINT, TYPE_DEF );
	    end if;
	  end;
	end if;

	if  SOURCE_CONSTRAINT /= TREE_VOID  or else  DB( CD_COMPILED, TYPE_SPEC ) = FALSE  then
	  ANONYMOUS_SUBTYPE := TRUE;
	  USE_LOCAL_TYPE_INFO := TRUE;
	  PUT_LINE( LOCAL_TYPE_INFO_STR & " = '" & LOCAL_TYPE_INFO_STR & "'" );
	  PUT( "namespace " & LOCAL_TYPE_INFO_STR );
	  if  CODI.DEBUG  then PUT( tab50 & "; array var constrained array type info" ); end if;
	  NEW_LINE;
	  TYPES_DECLS.PROCESS_CONSTRAINED_ARRAY_TYPE_SPEC( TYPE_SPEC, SOURCE_CONSTRAINT );
	end if;
        end;

        TYPE_LEVEL := DI( CD_LEVEL, TYPE_SPEC );

        if  OVERLAY_EQUATE  then
	PUT( VC_STR & "_disp = " & PRINT_NAME( D( LX_SYMREP, OVERLAY_TGT ) ) & "_disp" );		-- C8 : OVERLAY, equation fasmg -- meme cellule data_ptr
	if  CODI.DEBUG  then PUT( tab50 & "; variable array OVERLAY : data_ptr partage (pas d'allocation)" ); end if;
	NEW_LINE;
        elsif  OVERLAY_LVA  then									-- C8 : cible SCALAIRE (print_nod, endianite) --
	PUT( "VAR " & VC_STR & "_disp, Q" );								--| le slot scalaire contient sa VALEUR : pas d'equation --
	if  CODI.DEBUG  then PUT( tab50 & "; variable array OVERLAY sur scalaire" ); end if;		--| le data_ptr de l'overlay = ADRESSE du slot cible
	NEW_LINE;
	PUT_LINE( tab & "LVA" & tab & LVL_STR & ", " & PRINT_NAME( D( LX_SYMREP, OVERLAY_TGT ) ) & "_disp" );
	PUT( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "_disp" );
	if  CODI.DEBUG  then PUT( tab50 & "; array data ptr at _disp (OVERLAY, pas d'allocation)" ); end if;
	NEW_LINE;
        else
	if  VC_ADDRESS /= TREE_VOID  then
	  CODI.TROU( "COMPILE_ARRAY_VAR overlay 'ADDRESS hors motif (non statique-par-nom, ou cible ni composite ni scalaire)", VC_NAME );	--| discrimine (n 122) ; retombee : objet DISTINCT, FINC SUSPECT
	end if;
	PUT( "VAR " & VC_STR & "_disp, Q" );
	if  CODI.DEBUG  then PUT( tab50 & "; variable array : pointeur aux data" ); end if;
	NEW_LINE;
        end if;

        PUT( "VAR " & VC_STR & "__u, Q" );
        if  CODI.DEBUG  then PUT( tab50 & "; variable array : useinfo pointeur au rec info" ); end if;
        NEW_LINE;

        DI( CD_LEVEL, VC_NAME, INTEGER( LVL ) );

        PUT( tab & "LA" & INTEGER'IMAGE( TYPE_LEVEL ) & ", " );						-- LOAD ADDRESS FOR INFO
        PUT_TYPE_INFO_PREFIX;
        PUT_LINE( ".use__info" );

        PUT( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "__u" );
        if  CODI.DEBUG  then PUT( tab50 & "; array info ptr at __u" ); end if;
        NEW_LINE;
				----------
				INITIALIZE:
        declare
	INIT_EXP		: TREE		:= D( SM_INIT_EXP, VC_NAME );
        begin
	if  DO_OVERLAY  then									-- C8 : OVERLAY -- les data sont celles de la cible
	  if  INIT_EXP = TREE_VOID  then
	    null;										--| ni allocation ni init ; __u (vue cible) pose ci-dessus
	  elsif  INIT_EXP.TY = DN_AGGREGATE  and then  TYPE_SPEC.TY /= DN_ARRAY  then
			--| print_nod (detection d'endianite) : init A TRAVERS l'overlay --
			--| PAS d'allocation ; l'agregat s'ecrit dans la memoire de la
			--| CIBLE via [_disp].  LRM 13.5 : l'elaboration de l'objet ECRIT
			--| l'emplacement vise -- c'est le but meme de l'idiome.
	    PUT_LINE( tab &  "LA" & tab & LVL_STR & ", " & VC_STR & "_disp" );
	    EXPRESSIONS.CODE_AGGREGATE( INIT_EXP, TYPE_SPEC );
	  else
	    CODI.TROU( "COMPILE_ARRAY_VAR overlay : forme d'initialisation non observee", INIT_EXP );	--| n 122 ; un litteral chaine RE-POINTERAIT _disp sur la CONSTANTE -- jamais ici
	  end if;
	elsif  INIT_EXP /= TREE_VOID  then

	  if  INIT_EXP.TY = DN_STRING_LITERAL								-- vraie constante chaine
	  then
	    EXPRESSIONS.CODE_STRING_LITERAL( INIT_EXP, VC_STR );

	    PUT_LINE( tab & "LCA" & tab & VC_STR & ".data_ptr" );
	    PUT_LINE( tab & "LA" );
	    PUT( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "_disp" );
	    if  CODI.DEBUG  then PUT( tab50 & "; array data ptr at _disp" ); end if;
	    NEW_LINE;

	    PUT_LINE( tab & "LCA" & tab & VC_STR & ".info_ptr" );						-- LOAD CONSTANT ADDRESS FOR INFO
	    PUT_LINE( tab & "LA" );
	    PUT( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "__u" );
	    if  CODI.DEBUG  then PUT( tab50 & "; array info ptr at __u" ); end if;
	    NEW_LINE;

	  elsif  INIT_EXP.TY = DN_FUNCTION_CALL								-- retour de STRING par fonction par exemple
	  then
	    EXPRESSIONS.CODE_EXP( INIT_EXP );								-- appel fonction, resultat = adresse du descripteur

	    PUT_LINE( tab & "DUP" );									-- dupliquer l'adresse du descripteur
	    PUT_LINE( tab & "LA" );									-- charger data_ptr (qword a offset 0)
	    PUT( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "_disp" );
	    if  CODI.DEBUG  then PUT( tab50 & "; array data ptr from function result" ); end if;
	    NEW_LINE;

	    PUT_LINE( tab & "LA , 8" );								-- offset +8 pour info_ptr
	    PUT( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "__u" );
	    if  CODI.DEBUG  then PUT( tab50 & "; array info ptr from function result" ); end if;
	    NEW_LINE;


	  elsif  INIT_EXP.TY = DN_AGGREGATE  then
	    if  TYPE_SPEC.TY = DN_ARRAY  then								-- objet NON contraint : bornes déduites
	      UNCONSTRAINED_AGGREGATE_OBJECT( INIT_EXP );							-- nouveau, ci-dessous

	    else
	      COVAR_ALLOCATE;
	      if  CODI.DEBUG  then PUT( tab50 & "; array data aggregate" ); end if;
	      NEW_LINE;

	      PUT_LINE( tab &  "LA" & tab & LVL_STR & ", " & VC_STR & "_disp" );
	      EXPRESSIONS.CODE_AGGREGATE( INIT_EXP, TYPE_SPEC );
	    end if;


	  elsif  INIT_EXP.TY = DN_QUALIFIED  then
  -- Initialiseur tableau qualifie : P.E2'(4 => 8, 5 => 3, OTHERS => 1).
  -- Il faut allouer l'objet destination ici, puis coder l'agregat
  -- dans les donnees de cet objet. CODE_QUALIFIED seul construit
  -- une valeur d'expression et ne remplace pas l'initialisation.
	    declare
	      QUAL_EXP : TREE := D( AS_EXP, INIT_EXP );
	    begin
	      if  QUAL_EXP.TY = DN_AGGREGATE  then
	        COVAR_ALLOCATE;
	        if  CODI.DEBUG  then
		PUT( tab50 & "; array data qualified aggregate" );
	        end if;
	        NEW_LINE;

	        PUT_LINE( tab & "LA" & tab & LVL_STR & ", " & VC_STR & "_disp" );
	        EXPRESSIONS.CODE_AGGREGATE( QUAL_EXP, TYPE_SPEC );

	      else
      -- Repli defensif : expression qualifiee non-agregat retournant
      -- un doublet tableau ; on copie les donnees vers la destination.
	        if  TYPE_SPEC.TY = DN_ARRAY  then
	          CODI.TROU( "COMPILE_ARRAY_VAR init NON CONTRAINTE par qualifie non-agregat (remede : modele tranche, commit 6)", INIT_EXP );
	        end if;
	        COVAR_ALLOCATE;
	        PUT_LINE( tab & "LA" & tab & LVL_STR & ", " & VC_STR & "_disp" );
	        PUT( tab & "LD" & tab & IMAGE( TYPE_LEVEL ) & ", " );
	        PUT_TYPE_INFO_PREFIX;
	        PUT_LINE( ".SIZ__" );
	        PUT_LINE( tab & "LI" & tab & '8' );
	        PUT_LINE( tab & "DIV" );
	        EXPRESSIONS.CODE_EXP( INIT_EXP );
	        PUT_LINE( tab & "LA" );
	        PUT_LINE( tab & "BLKMOV" );
	      end if;
	    end;

	  elsif  INIT_EXP.TY = DN_FUNCTION_CALL  then
	    EXPRESSIONS.CODE_EXP( INIT_EXP );

	  elsif  ( INIT_EXP.TY = DN_SELECTED
		  and then  D( SM_DEFN, D( AS_DESIGNATOR, INIT_EXP ) ).TY /= DN_FUNCTION_ID
		  and then  D( SM_DEFN, D( AS_DESIGNATOR, INIT_EXP ) ).TY /= DN_OPERATOR_ID )
	    or else  INIT_EXP.TY = DN_INDEXED
	  then
	  -- Initialiseur composant tableau INLINE (TXT := HTABLE(I).HN) : le
	  -- composant n'a pas de doublet {_disp,__u} propre, et la retombee
	  -- "non gere" ci-dessous laissait VC_disp NON ALLOUE -- deuxieme
	  -- segfault du bootstrap (GRMR_OPS.GRMR_OP_IMAGE), frere de celui de
	  -- HASH_SEARCH corrige dans CODE_ARRAY_OPERAND.  Allouer la destination
	  -- puis BLKMOV depuis l'@data du composant, obtenue directement par
	  -- CODE_OBJECT_ADDRESS (pas de doublet a dereferencer : PAS de "LA ,0",
	  -- contrairement au repli defensif de la branche DN_QUALIFIED).
	  -- Le designator fonction (P.F sans parametre) reste hors perimetre :
	  -- il retombe comme avant dans la branche bruyante.
	    if  TYPE_SPEC.TY = DN_ARRAY  then
	    -- OBJET NON CONTRAINT init par COMPOSANT inline (ITEM_NAME :=
	    -- BLTN_TEXT_ARRAY(OP_NAME), TROU leve par FIX_PRE, 6 aout) : bornes
	    -- DEDUITES du sous-type du composant.  CODE_ARRAY_OPERAND (promu au
	    -- spec, commit 8) normalise le composant en DOUBLET -- bornes
	    -- re-emises au perimetre du commit 3, bruyant au-dela -- puis meme
	    -- modele que la tranche non contrainte (commit 6).
	      PUT_LINE( "VAR " & VC_STR & "__isrc, Q" );
	      PUT_LINE( "VAR " & VC_STR & "__ilen, Q" );
	      EXPRESSIONS.CODE_ARRAY_OPERAND( INIT_EXP, VC_STR & "__init", TYPE_SPEC );		-- @doublet source
	      PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "__isrc" );
	      PUT_LINE( tab & "LA" & tab & LVL_STR & ", " & VC_STR & "__isrc" );
	      PUT_LINE( tab & "LA , 8" );
	      PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "__u" );			-- __u := info du composant normalise
	      PUT_LINE( tab & "LID " & LVL_STR & ", " & VC_STR & "__u, " & TYPE_NAME_STR & ".LST_1" );
	      PUT_LINE( tab & "LID " & LVL_STR & ", " & VC_STR & "__u, " & TYPE_NAME_STR & ".FST_1" );
	      PUT_LINE( tab & "SUB" );
	      PUT_LINE( tab & "INC" );
	      PUT_LINE( tab & "CLAMP0" );
	      PUT_LINE( tab & "LID " & LVL_STR & ", " & VC_STR & "__u, " & TYPE_NAME_STR & ".COMP_SIZ" );
	      PUT_LINE( tab & "LI" & tab & '8' );
	      PUT_LINE( tab & "DIV" );
	      PUT_LINE( tab & "MUL" );
	      PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "__ilen" );
	      PUT_LINE( tab & "LA" & tab & LVL_STR & ", " & VC_STR & "__ilen" );
	      PUT_LINE( tab & "CO_VAR" );
	      PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "_disp" );
	      PUT_LINE( tab & "LA" & tab & LVL_STR & ", " & VC_STR & "_disp" );			-- @DST
	      PUT_LINE( tab & "LA" & tab & LVL_STR & ", " & VC_STR & "__ilen" );			-- LEN
	      PUT_LINE( tab & "LA" & tab & LVL_STR & ", " & VC_STR & "__isrc" );
	      PUT_LINE( tab & "LA" );								-- @SRC = data_ptr du doublet
	      PUT_LINE( tab & "BLKMOV" );
	    else
	      COVAR_ALLOCATE;
	      PUT_LINE( tab & "LA" & tab & LVL_STR & ", " & VC_STR & "_disp" );					-- @DST
	      PUT( tab & "LD" & tab & IMAGE( TYPE_LEVEL ) & ", " );						-- LEN en octets : SIZ destination / 8
	      PUT_TYPE_INFO_PREFIX;
	      PUT_LINE( ".SIZ__" );
	      PUT_LINE( tab & "LI" & tab & '8' );
	      PUT_LINE( tab & "DIV" );
	      EXPRESSIONS.CODE_OBJECT_ADDRESS( INIT_EXP );							-- @SRC = @data du composant
	      PUT_LINE( tab & "BLKMOV" );
	    end if;

	  elsif  INIT_EXP.TY = DN_SLICE  then
	  -- Initialiseur TRANCHE (TEMP_STRING := OP_TEXT(II..II+1), TRONQ :=
	  -- IMAGE(4..IMAGE'LENGTH) dans LEX.LEX_IMAGE) : troisieme membre de la
	  -- famille "operande sans doublet propre" -- la retombee "non gere"
	  -- laissait la aussi VC_disp NON ALLOUE (defaillance differee au premier
	  -- usage : CE ou segfault chez l'appelant, cf. HASH_POS).  CODE_SLICE en
	  -- mode SOURCE fabrique le doublet anonyme de la tranche (bornes de la
	  -- slice) ; ensuite meme copie que le repli defensif DN_QUALIFIED :
	  -- extraction du data_ptr par "LA ,0" puis BLKMOV vers la destination.

	    if  TYPE_SPEC.TY = DN_ARRAY  then
	    -- OBJET NON CONTRAINT init par tranche (NOM_TEXTE := CMD(1..N), classif
	    -- 6 aout, segfault OPEN) : bornes DEDUITES de la tranche (RM83 3.6.1).
	    -- L'ancien chemin lisait SIZ=-1 du PATRON pour l'allocation et laissait
	    -- __u sur le patron.  Le doublet source de CODE_SLICE porte l'info
	    -- NORMALISEE 1..len dans le frame courant : __u la partage, la longueur
	    -- s'y lit par l'idiome LId du "&".
	      PUT_LINE( "VAR " & VC_STR & "__isrc, Q" );						-- @doublet source (scratch)
	      PUT_LINE( "VAR " & VC_STR & "__ilen, Q" );						-- longueur en octets (scratch)
	      EXPRESSIONS.CODE_SLICE( INIT_EXP, IS_DESTINATION => FALSE );
	      PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "__isrc" );
	      PUT_LINE( tab & "LA" & tab & LVL_STR & ", " & VC_STR & "__isrc" );
	      PUT_LINE( tab & "LA , 8" );
	      PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "__u" );			-- __u := info normalisee 1..len
	      PUT_LINE( tab & "LID " & LVL_STR & ", " & VC_STR & "__u, " & TYPE_NAME_STR & ".LST_1" );
	      PUT_LINE( tab & "LID " & LVL_STR & ", " & VC_STR & "__u, " & TYPE_NAME_STR & ".FST_1" );
	      PUT_LINE( tab & "SUB" );
	      PUT_LINE( tab & "INC" );
	      PUT_LINE( tab & "CLAMP0" );
	      PUT_LINE( tab & "LID " & LVL_STR & ", " & VC_STR & "__u, " & TYPE_NAME_STR & ".COMP_SIZ" );
	      PUT_LINE( tab & "LI" & tab & '8' );
	      PUT_LINE( tab & "DIV" );
	      PUT_LINE( tab & "MUL" );
	      PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "__ilen" );
	      PUT_LINE( tab & "LA" & tab & LVL_STR & ", " & VC_STR & "__ilen" );
	      PUT_LINE( tab & "CO_VAR" );
	      PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "_disp" );
	      PUT_LINE( tab & "LA" & tab & LVL_STR & ", " & VC_STR & "_disp" );			-- @DST
	      PUT_LINE( tab & "LA" & tab & LVL_STR & ", " & VC_STR & "__ilen" );			-- LEN
	      PUT_LINE( tab & "LA" & tab & LVL_STR & ", " & VC_STR & "__isrc" );
	      PUT_LINE( tab & "LA" );								-- @SRC = data_ptr du doublet
	      PUT_LINE( tab & "BLKMOV" );
	    else
	      COVAR_ALLOCATE;
	      PUT_LINE( tab & "LA" & tab & LVL_STR & ", " & VC_STR & "_disp" );					-- @DST
	      PUT( tab & "LD" & tab & IMAGE( TYPE_LEVEL ) & ", " );						-- LEN en octets : SIZ destination / 8
	      PUT_TYPE_INFO_PREFIX;
	      PUT_LINE( ".SIZ__" );
	      PUT_LINE( tab & "LI" & tab & '8' );
	      PUT_LINE( tab & "DIV" );
	      EXPRESSIONS.CODE_SLICE( INIT_EXP, IS_DESTINATION => FALSE );					-- @doublet de la tranche
	      PUT_LINE( tab & "LA" );									-- @SRC = data_ptr du doublet
	      PUT_LINE( tab & "BLKMOV" );
	    end if;

	  elsif  INIT_EXP.TY = DN_USED_OBJECT_ID
	  or else  INIT_EXP.TY = DN_CONVERSION  then
	  -- Chantier C4 (recensement 28/07, 3 traversees : nod_walk, vis_util,
	  -- expander-expressions ; temoin ARRINI1) : X : ARR := Y, init par
	  -- OBJET ENTIER -- allocation puis copie, modele exact de la branche
	  -- tranche ci-dessus.  @SRC par la regle unique CCDA (@doublet -> La) ;
	  -- la regle etant TRANSPARENTE aux conversions depuis C1-ter, la forme
	  -- X : ARR := ARR(Z) (Z derive) passe par le meme chemin.  L'init par
	  -- APPEL DE FONCTION reste au TROU ci-dessous : protocole << lieu
	  -- resultat >> des fonctions a resultat composite SUSPENDU (carnet,
	  -- preuve CONV_DER1 v1 du 30/07) -- le bilan prescrivait cette forme
	  -- au temoin, il precedait la preuve.
	    if  TYPE_SPEC.TY = DN_ARRAY  then
	      CODI.TROU( "COMPILE_ARRAY_VAR init NON CONTRAINTE par objet entier (remede : modele tranche, commit 6)", INIT_EXP );
	    end if;
	    COVAR_ALLOCATE;
	    PUT_LINE( tab & "LA" & tab & LVL_STR & ", " & VC_STR & "_disp" );					-- @DST
	    PUT( tab & "LD" & tab & IMAGE( TYPE_LEVEL ) & ", " );						-- LEN en octets : SIZ destination / 8
	    PUT_TYPE_INFO_PREFIX;
	    PUT_LINE( ".SIZ__" );
	    PUT_LINE( tab & "LI" & tab & '8' );
	    PUT_LINE( tab & "DIV" );
	    EXPRESSIONS.CODE_COMPOSITE_DATA_ADDRESS( INIT_EXP );						-- @SRC (@doublet -> La par la regle)
	    PUT_LINE( tab & "BLKMOV" );

	  else
	    CODI.TROU( "COMPILE_ARRAY_VAR forme d'initialisation", INIT_EXP );				--| vague 5 : ni allocation ni init emises ;
												--| reste : DN_FUNCTION_CALL (chantier suspendu)
	  end if;

	else											-- PAS D'INITIALISATION, ALLOUER
	  COVAR_ALLOCATE;
	  if  EST_TABLEAU_DYNAMIQUE( TYPE_SPEC )  then							--| lot 27 : composants records dynamiques
	    declare
	      LEN	:constant STRING	:= VC_STR & "__ilg";
	      PAS	:constant STRING	:= VC_STR & "__ips";
	      GAB	:constant STRING	:= VC_STR & "__igb";
	    begin
	      PUT_LINE( "VAR " & LEN & ", Q" );
	      PUT_LINE( "VAR " & PAS & ", Q" );
	      PUT_LINE( "VAR " & GAB & ", Q" );
	      PUT( tab & "LD" & tab & IMAGE( TYPE_LEVEL ) & ", " );					--| longueur en octets : SIZ / 8
	      PUT_TYPE_INFO_PREFIX;
	      PUT_LINE( ".SIZ__" );
	      PUT_LINE( tab & "LI" & tab & '8' );
	      PUT_LINE( tab & "DIV" );
	      PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & LEN );
	      PUT( tab & "LD" & tab & IMAGE( TYPE_LEVEL ) & ", " );					--| pas en octets : COMP_SIZ / 8
	      PUT_TYPE_INFO_PREFIX;
	      PUT_LINE( "._COMP_SIZ" );
	      PUT_LINE( tab & "LI" & tab & '8' );
	      PUT_LINE( tab & "DIV" );
	      PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & PAS );
	      if  ELEMENT_TABLEAU( TYPE_SPEC ).TY = DN_CONSTRAINED_RECORD  then			--| composant contraint : gabarit du type
	        PUT( tab & "LA" & tab & IMAGE( TYPE_LEVEL ) & ", " );
	        PUT_TYPE_INFO_PREFIX;
	        PUT_LINE( "._GABARIT" );
	      else										--| non contraint : gabarit aux defauts,
	        CODE_OBJET_DYNAMIQUE( ELEMENT_TABLEAU( TYPE_SPEC ), ( TREE_NIL, TREE_NIL ),		--| controle maintenant (LRM 3.7.2)
				SUR_LE_TAS => FALSE, MUTABLE => TRUE );
	      end if;
	      PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & GAB );
	      CODE_INIT_IMPLICITE_TABLEAU( TYPE_SPEC, VC_STR & "_disp", LEN, PAS, GAB );
	    end;
	  elsif  A_INIT_IMPLICITE_TYPE( TYPE_SPEC )  then							--| lot 26 : composants records (LRM 3.2.1)
	    declare
	      LEN	:constant STRING	:= VC_STR & "__ilg";
	    begin
	      PUT_LINE( "VAR " & LEN & ", Q" );								--| longueur en octets : SIZ / 8
	      PUT( tab & "LD" & tab & IMAGE( TYPE_LEVEL ) & ", " );
	      PUT_TYPE_INFO_PREFIX;
	      PUT_LINE( ".SIZ__" );
	      PUT_LINE( tab & "LI" & tab & '8' );
	      PUT_LINE( tab & "DIV" );
	      PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & LEN );
	      CODE_INIT_IMPLICITE_TABLEAU( TYPE_SPEC, VC_STR & "_disp", LEN );
	    end;
	  end if;

	end if;
        end			INITIALIZE;
				----------

        DI( CD_LEVEL,	VC_NAME, INTEGER( LVL ) );
        DB( CD_COMPILED,	VC_NAME, TRUE );

      end COMPILE_ARRAY_VAR;
	-----------------


		------------------
      procedure	COMPILE_RECORD_VAR		( VC_NAME, TYPE_SPEC :TREE )
      is		------------------

        VC_STR		:constant STRING	:= PRINT_NAME( D( LX_SYMREP, VC_NAME ) );
        INIT_EXP		: TREE		:= D( SM_INIT_EXP, VC_NAME );
        LVL		: LEVEL_NUM	renames CODI.CUR_LEVEL;
        LVL_STR		:constant STRING	:= IMAGE( LVL );
        TYPE_NAME		: TREE		:= D( XD_SOURCE_NAME, TYPE_SPEC );
        TYPE_NAME_STR	:constant STRING	:= '_' & PRINT_NAME( D( LX_SYMREP, TYPE_NAME ) );
        OBJET_MUTABLE	: BOOLEAN;

      begin
        OBJET_MUTABLE := CODI.EST_RECORD_DYNAMIQUE( TYPE_SPEC )					--| option B : objet NON CONTRAINT = variable d'un
		   and then  TYPE_SPEC.TY /= DN_CONSTRAINED_RECORD					--| type a defauts : taille MAXIMALE, discriminants
		   and then  VC_NAME.TY /= DN_CONSTANT_ID						--| modifiables (etape 3).  Une constante, ou une
		   and then  CODI.A_DISCRIMINANTS_PAR_DEFAUT( TYPE_SPEC );				--| variable initialisee d'un type sans defauts, est
											--| contrainte par sa valeur (LRM 3.7.2).

        declare
	OVERLAY_TGT	: TREE		:= OVERLAY_TARGET;						-- C8 : overlay statique-par-nom (equation fasmg)
	DO_OVERLAY	: BOOLEAN		:= OVERLAY_TGT /= TREE_VOID
		and then  INIT_EXP = TREE_VOID
		and then  TYPE_SPEC.TY = DN_RECORD
		and then  IS_EMPTY( LIST( D( SM_DISCRIMINANT_S, TYPE_SPEC ) ) )
		and then  CODI.FULL_TYPE_VIEW( D( SM_OBJ_TYPE, OVERLAY_TGT ) ).TY  not in  CLASS_SCALAR		-- slot cible = data_ptr requis :
		and then  not CODI.EST_ACCES( CODI.FULL_TYPE_VIEW( D( SM_OBJ_TYPE, OVERLAY_TGT ) ) );			-- l'equation exige la meme sorte
        begin
	if  VC_ADDRESS /= TREE_VOID  and then  not DO_OVERLAY  then
	  CODI.TROU( "COMPILE_RECORD_VAR overlay 'ADDRESS non statique-par-nom (ou init/discriminants)", VC_NAME );	--| discrimine (n 122) : l'elaboration ecraserait la cible ; retombee : objet DISTINCT, FINC SUSPECT
	end if;

	if  DO_OVERLAY  then
	  if  OVERLAY_TGT.TY = DN_IN_ID  or else  OVERLAY_TGT.TY = DN_IN_OUT_ID  then				-- C8 : cible = PARAMETRE composite (univ_ops) --
	    PUT( "VAR " & VC_STR & "_disp, Q" );							--| son slot porte l'@doublet de l'ACTUEL (n 91/94) :
	    if  CODI.DEBUG  then  PUT( tab50 & "; variable record OVERLAY sur parametre" ); end if;		--| data_ptr := [[-ofs]+0] -- pas d'equation possible
	    NEW_LINE;
	    PUT_LINE( tab & "LA  " & IMAGE( DI( CD_LEVEL, OVERLAY_TGT ) ) & ", -"
			& PRINT_NAME( D( LX_SYMREP, OVERLAY_TGT ) ) & "_ofs" );				-- niveau de la CIBLE (VDP peut etre dans un bloc)
	    PUT_LINE( tab & "LA  ,  0" );
	    PUT( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "_disp" );
	    if  CODI.DEBUG  then  PUT( tab50 & "; record data ptr at _disp (OVERLAY, data de l'actuel)" ); end if;
	    NEW_LINE;
	  else
	    PUT( VC_STR & "_disp = " & PRINT_NAME( D( LX_SYMREP, OVERLAY_TGT ) ) & "_disp" );			-- C8 : OVERLAY, equation fasmg -- meme cellule data_ptr, pas de __dat
	    if  CODI.DEBUG  then  PUT( tab50 & "; variable record OVERLAY : data_ptr partage" ); end if;
	    NEW_LINE;
	  end if;
	  PUT( "VAR " & VC_STR & "__u, Q" );								-- Ptr to rec
	  if  CODI.DEBUG  then  PUT( tab50 & "; variable record : pointeur aux useinfo" ); end if;
	  NEW_LINE;

	else
	  PUT( "VAR " & VC_STR & "_disp, Q" );								-- Ptr to rec
	  if  CODI.DEBUG  then  PUT( tab50 & "; variable record : pointeur aux data record" ); end if;
	  NEW_LINE;
	  PUT( "VAR " & VC_STR & "__u, Q" );								-- Ptr to rec
	  if  CODI.DEBUG  then  PUT( tab50 & "; variable record : pointeur aux useinfo" ); end if;
	  NEW_LINE;

	  PUT( "VAR " & VC_STR & "__dat, " );								-- Espace data
	  REGIONS_PATH( TYPE_NAME );
	  PUT_LINE( TYPE_NAME_STR & ".size" );

	  PUT_LINE( tab & "LVA" & tab & LVL_STR & ", " & VC_STR & "__dat" );
	  PUT( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "_disp" );					-- Stocker l'adresse du rec dans le ptr
	  if  CODI.DEBUG   then  PUT( tab50 & "; record fin" ); end if;
	  NEW_LINE;
	end if;
        end;

        PUT( tab & "LVA" & tab & LVL_STR & ", " );
        REGIONS_PATH( TYPE_NAME );
        PUT_LINE( TYPE_NAME_STR & ".SIZ__" );
        PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "__u" );

        DI( CD_LEVEL, VC_NAME, INTEGER( LVL ) );									--| constante differee : recopie sur SM_FIRST
        DB( CD_COMPILED,  VC_NAME, TRUE );										--| a la fin de CODE_VC_NAME (toutes sortes)

        if  INIT_EXP /= TREE_VOID  and then  CODI.EST_RECORD_DYNAMIQUE( TYPE_SPEC )  then
			--| Option B : objet dynamique INITIALISE.
			--| Agregat : objet neuf dont les discriminants sont ceux de l'agregat
			--| (tete de SM_NORMALIZED_COMP_S), puis remplissage complet.
			--| Expression : copie integrale (__TAILLE de la SOURCE) -- les OFS
			--| des descripteurs sont relatifs, la copie est donc coherente.
			--| (Controle de discriminants, LRM 4.6/5.2 : a faire.)
	if  OBJET_MUTABLE  then
			--| Etape 3 : variable NON CONTRAINTE initialisee -- objet de taille
			--| maximale aux discriminants par defaut, puis AFFECTATION de la
			--| valeur (discriminants libres : ni controle, ni taille figee).
	  CODE_OBJET_DYNAMIQUE( TYPE_SPEC, ( TREE_NIL, TREE_NIL ), SUR_LE_TAS => FALSE, MUTABLE => TRUE );
	  PUT_LINE( tab & "DUP" );
	  PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "_disp" );
	  if  INIT_EXP.TY = DN_AGGREGATE  then
	    EXPRESSIONS.CODE_AGGREGATE( INIT_EXP, TYPE_SPEC );
	  else
	    EXPRESSIONS.CODE_COPIE_RECORD_DYNAMIQUE( INIT_EXP, TYPE_SPEC );
	  end if;

	elsif  INIT_EXP.TY = DN_AGGREGATE  then
	  CODE_OBJET_DYNAMIQUE( TYPE_SPEC, LIST( D( SM_NORMALIZED_COMP_S, INIT_EXP ) ), SUR_LE_TAS => FALSE );
	  PUT_LINE( tab & "DUP" );
	  PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "_disp" );
	  EXPRESSIONS.CODE_AGGREGATE( INIT_EXP, TYPE_SPEC );						-- consomme @objet
	else
	  declare
	    SRC		:constant STRING	:= "__SRC" & NEW_LABEL;
	    BASE_REC	: TREE		:= CODI.FULL_TYPE_VIEW( TYPE_SPEC );
	  begin
	    if  BASE_REC.TY = DN_CONSTRAINED_RECORD  then
	      BASE_REC := CODI.FULL_TYPE_VIEW( D( SM_BASE_TYPE, BASE_REC ) );
	    end if;
	    PUT_LINE( "VAR " & SRC & ", Q" );
	    EXPRESSIONS.CODE_COMPOSITE_DATA_ADDRESS( INIT_EXP );					-- @data source (regle n 112)
	    PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & SRC );
	    PUT( tab & "LID" & tab & LVL_STR & ", " & SRC & ", " );
	    REGIONS_PATH( D( XD_SOURCE_NAME, BASE_REC ) );
	    PUT_LINE( TYPE_INFO_STR( BASE_REC ) & ".__TAILLE" );
	    PUT_LINE( tab & "CO_VAR" );
	    PUT_LINE( tab & "DUP" );
	    PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "_disp" );			-- @DST
	    PUT( tab & "LID" & tab & LVL_STR & ", " & SRC & ", " );
	    REGIONS_PATH( D( XD_SOURCE_NAME, BASE_REC ) );
	    PUT_LINE( TYPE_INFO_STR( BASE_REC ) & ".__TAILLE" );					-- LEN
	    PUT_LINE( tab & "LA" & tab & LVL_STR & ", " & SRC );					-- @SRC
	    PUT_LINE( tab & "BLKMOV" );
	    PUT_LINE( tab & "LI" & tab & "0" );								-- objet CONTRAINT, meme si la
	    PUT( tab & "SID" & tab & LVL_STR & ", " & VC_STR & "_disp, " );				-- source etait mutable
	    REGIONS_PATH( D( XD_SOURCE_NAME, BASE_REC ) );
	    PUT_LINE( TYPE_INFO_STR( BASE_REC ) & ".__MUTABLE" );
	  end;
	end if;

        elsif  INIT_EXP.TY = DN_AGGREGATE  then
	PUT_LINE( tab & "LA " & LVL_STR & ", " & VC_STR & "_disp" );					-- Adresse de debut data
	EXPRESSIONS.CODE_AGGREGATE( INIT_EXP, TYPE_SPEC );


        elsif  INIT_EXP /= TREE_VOID  then
	-- Initialisation par expression quelconque (function_call, variable, ...) retournant un record
	-- @DST = data_ptr de la variable destination
	PUT_LINE( tab & "LA  " & LVL_STR & ", " & VC_STR & "_disp" );   -- @DST

	declare
	  TYPE_NAME2  : TREE	  := D( XD_SOURCE_NAME, TYPE_SPEC );
	  TN_STR2	    : constant STRING := '_' & PRINT_NAME( D( LX_SYMREP, TYPE_NAME2 ) );
	begin
	  PUT( tab & "LI" & tab );
	  CODI.REGIONS_PATH( TYPE_NAME2 );
	  PUT_LINE( TN_STR2 & ".size" );			     -- LEN
	end;
			--| TTAIL1 (7/08) : miroir du n 112 au site de DECLARATION -- le
			--| "LA ,0" inconditionnel supposait un @doublet, mais une reference
			--| de composante (T_TAIL := S.NEXT, IDL_MAN.APPEND) produit l @data
			--| nue : le La lisait un data comme un data_ptr, la VALEUR 32 bits
			--| du TREE devenait l adresse source du BLKMOV (T_TAIL =
			--| [DN_ROOT,P0,L0], puis CONSTRAINT_ERROR au check de gamme
			--| CUR_VP := T.PG dans DABS). Regle unique n 112 :
			--| CODE_COMPOSITE_DATA_ADDRESS discrimine le La par producteur.
	EXPRESSIONS.CODE_COMPOSITE_DATA_ADDRESS( INIT_EXP );	     -- @SRC = @data source

	PUT_LINE( tab & "BLKMOV" );

        else
				-- Pilier 3.7 : elaboration des VALEURS de discriminants.
				-- Vue contrainte : SM_NORMALIZED_DSCRMT_S (expressions dans
				-- l'ordre des discriminants du record de base).
				-- Type a defauts (3.7.1) : SM_INIT_EXP des DISCRIMINANT_ID.
				-- Les offsets sont adresses via le namespace du record de BASE
				-- (les vues contraintes, nommees ou anonymes, n'ont que des alias).
	declare
	  BASE_REC	: TREE	:= TYPE_SPEC;
	  DSCRMT_EXP_S	: SEQ_TYPE;
	  USE_NORM	: BOOLEAN := FALSE;
	begin
	  if  TYPE_SPEC.TY = DN_CONSTRAINED_RECORD  then
	    BASE_REC     := CODI.FULL_TYPE_VIEW( D( SM_BASE_TYPE, TYPE_SPEC ) );			-- base PRIVEE possible : sans percage,
	    DSCRMT_EXP_S := LIST( D( SM_NORMALIZED_DSCRMT_S, TYPE_SPEC ) );			-- les discriminants n'etaient pas ecrits
	    USE_NORM     := TRUE;
	  end if;

	  if  BASE_REC.TY = DN_RECORD  then
	    declare
	      BASE_NAME	: TREE		:= D( XD_SOURCE_NAME, BASE_REC );
	      BASE_STR	:constant STRING	:= '_' & PRINT_NAME( D( LX_SYMREP, BASE_NAME ) );
	      DSCRMT_DECL_S : SEQ_TYPE	:= LIST( D( SM_DISCRIMINANT_S, BASE_REC ) );
	      DSCRMT_DECL	: TREE;
	      DSCRMT_EXP	: TREE;
	    begin
	      while  not IS_EMPTY( DSCRMT_DECL_S )  loop
	        POP( DSCRMT_DECL_S, DSCRMT_DECL );
	        declare
		DISCR_ID_S	: SEQ_TYPE	:= LIST( D( AS_SOURCE_NAME_S, DSCRMT_DECL ) );
		DISCR_ID  : TREE;
	        begin
		while  not IS_EMPTY( DISCR_ID_S )  loop
		  POP( DISCR_ID_S, DISCR_ID );

		  if  USE_NORM  then
		    if  IS_EMPTY( DSCRMT_EXP_S )  then
		      PUT_LINE( "; COMPILE_RECORD_VAR : contrainte normalisee incomplete" );
		      raise PROGRAM_ERROR;
		    end if;
		    POP( DSCRMT_EXP_S, DSCRMT_EXP );
		  else
		    DSCRMT_EXP := D( SM_INIT_EXP, DISCR_ID );		-- defaut eventuel (3.7.1)
		  end if;

		  if  DSCRMT_EXP /= TREE_VOID  and then  DSCRMT_EXP /= TREE_NIL  then

		    if  REPRESENTED_ITEMS.HAS_COMPONENT_REP( DISCR_ID )  then
		      PUT_LINE( tab & "LA  " & LVL_STR & ", " & VC_STR & "_disp" );				-- @data du record (meme idiome que BLKMOV)
		      REPRESENTED_ITEMS.CODE_STORE_REP_COMPONENT( DISCR_ID, DSCRMT_EXP );

		    elsif  REPRESENTED_ITEMS.HAS_RECORD_REP( BASE_REC )  then
		      PUT_LINE( "; COMPILE_RECORD_VAR : composant sans comp_rep dans un record represente" );
		      raise PROGRAM_ERROR;

		    else
		      PUT( tab & "LIVA " & LVL_STR & ", " );
		      CODI.REGIONS_PATH( VC_NAME );
		      PUT( VC_STR & "_disp, " );

		      CODI.REGIONS_PATH( BASE_NAME );
		      PUT_LINE( BASE_STR & "." & PRINT_NAME( D( LX_SYMREP, DISCR_ID ) ) );
		      EXPRESSIONS.CODE_VALEUR_DISCRIMINANT( TYPE_SPEC, TREE_VOID, DISCR_ID, DSCRMT_EXP );	-- valeur ELABOREE d'un sous-type nomme
		      EXPRESSIONS.CODE_RANGE_CHECK( CODI.FULL_TYPE_VIEW( D( SM_OBJ_TYPE, DISCR_ID ) ) );	-- LRM 3.7.2 : valeur dans le sous-type
		      PUT_LINE( tab & "S" & CODI.OPER_SIZ_CHAR( D( SM_OBJ_TYPE, DISCR_ID ) ) );
		    end if;
		  end if;
		end loop;
	        end;
	      end loop;
	    end;
	  end if;
	end;

				-- Option B : record a composants dynamiques.  La partie
				-- statique (discriminants poses) est dans __dat ; on calcule
				-- descripteurs et __TAILLE, puis on reloge l'objet dans un
				-- bloc co-pile de __TAILLE octets (copie de la partie statique).
	if  OBJET_MUTABLE  then
			--| Etape 3 : variable NON CONTRAINTE -- bloc de taille maximale,
			--| discriminants par defaut, __MUTABLE = 1.
	  CODE_OBJET_DYNAMIQUE( TYPE_SPEC, ( TREE_NIL, TREE_NIL ), SUR_LE_TAS => FALSE, MUTABLE => TRUE );
	  PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "_disp" );

	elsif  CODI.EST_RECORD_DYNAMIQUE( TYPE_SPEC )  then
	  declare
	    BASE_REC	: TREE		:= CODI.FULL_TYPE_VIEW( D( SM_BASE_TYPE, TYPE_SPEC ) );
	    BASE_NAME	: TREE		:= D( XD_SOURCE_NAME, BASE_REC );
	    BASE_STR	:constant STRING	:= TYPE_INFO_STR( BASE_REC );
	  begin
	    CODE_INIT_DESCRIPTEURS( TYPE_SPEC, LVL, VC_STR & "_disp" );
	    PUT_LINE( tab & "LI" & tab & "0" );								-- objet CONTRAINT
	    PUT( tab & "SID" & tab & LVL_STR & ", " & VC_STR & "_disp, " );
	    REGIONS_PATH( BASE_NAME );
	    PUT_LINE( BASE_STR & ".__MUTABLE" );

	    PUT( tab & "LID" & tab & LVL_STR & ", " & VC_STR & "_disp, " );			-- __TAILLE
	    REGIONS_PATH( BASE_NAME );
	    PUT_LINE( BASE_STR & ".__TAILLE" );
	    PUT_LINE( tab & "CO_VAR" );								-- @bloc
	    PUT_LINE( tab & "DUP" );								-- @DST
	    PUT( tab & "LI" & tab );								-- LEN = partie statique
	    REGIONS_PATH( BASE_NAME );
	    PUT_LINE( BASE_STR & ".size" );
	    PUT_LINE( tab & "LVA" & tab & LVL_STR & ", " & VC_STR & "__dat" );			-- @SRC
	    PUT_LINE( tab & "BLKMOV" );
	    PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & VC_STR & "_disp" );			-- l'objet est desormais le bloc
	  end;
	end if;

				-- No explicit aggregate : initialize
				-- fields that have default values
				-- (objet record courant : un defaut peut lire un
				-- discriminant, LRM 3.7.1)
	CODE_INIT_IMPLICITE( TYPE_SPEC, VC_STR & "_disp" );						--| lot 25 : variantes, composants records
        end if;
      end COMPILE_RECORD_VAR;
	------------------


    begin
      TYPE_SPEC := CODI.FULL_TYPE_VIEW( TYPE_SPEC );

      if  CODI.GENERATE_BINARY_MAP  then
        PUT_LINE( " hexa_show 'var elab " & PRINT_NAME( D( LX_SYMREP, VC_NAME ) ) & " ', $" );
      end if;

      case TYPE_SPEC.TY is
      when DN_ENUMERATION		=> TYPE_SYMREP := D( XD_SOURCE_NAME, TYPE_SPEC );
				   COMPILE_VC_NAME_ENUMERATION(	VC_NAME, TYPE_SPEC );
      when DN_INTEGER		=> COMPILE_VC_NAME_INTEGER(		VC_NAME );
      when DN_FIXED			=> COMPILE_VC_NAME_FIXED(		VC_NAME );
      when DN_FLOAT			=> COMPILE_VC_NAME_FLOAT(		VC_NAME );
      when DN_ACCESS | DN_CONSTRAINED_ACCESS		=> COMPILE_ACCESS_VAR(		VC_NAME, TYPE_SPEC );
      when DN_CONSTRAINED_RECORD
	| DN_RECORD		=> COMPILE_RECORD_VAR(		VC_NAME, TYPE_SPEC );
      when DN_CONSTRAINED_ARRAY
	| DN_ARRAY		=> COMPILE_ARRAY_VAR(		VC_NAME, TYPE_SPEC );
      when others =>
        PUT_LINE( "; ERREUR CODE_VC_NAME, TYPE_SPEC.TY = " & NODE_NAME'IMAGE( TYPE_SPEC.TY ) );
        raise PROGRAM_ERROR;
      end case;

      if  VC_NAME.TY = DN_CONSTANT_ID  and then  D( SM_FIRST, VC_NAME ) /= VC_NAME  then				--| constante DIFFEREE (LRM 7.4.3) : les usages
        DI( CD_LEVEL, D( SM_FIRST, VC_NAME ), DI( CD_LEVEL, VC_NAME ) );						--| designent la declaration de la partie
        DB( CD_COMPILED, D( SM_FIRST, VC_NAME ), TRUE );							--| visible (SM_FIRST de la declaration
      end if;													--| complete) : meme niveau, meme nom
    end;
    NEW_LINE;

      if  CODI.GENERATE_BINARY_MAP  then
        PUT_LINE( " hexa_show ' disp ', " & PRINT_NAME( D( LX_SYMREP, VC_NAME ) ) & "_disp" );
      end if;

  end	CODE_VC_NAME;
	------------


			--------------
  procedure		CODE_TASK_DECL	( TASK_DECL :TREE )
  is			--------------
  begin
    CODI.TROU( "CODE_TASK_DECL (tasking hors perimetre)", TASK_DECL );					--| vague 4 : corps vide, la declaration etait avalee

  end	CODE_TASK_DECL;
	--------------


			---------------------
  procedure		CODE_RENAMES_OBJ_DECL	( RENAMES_OBJ_DECL :TREE )
  is			---------------------

    SOURCE_NAME	: TREE	:= D( AS_SOURCE_NAME, RENAMES_OBJ_DECL );

  begin
    if  SOURCE_NAME.TY in CLASS_VC_NAME  then
      declare
        NAME	: TREE		:= D( SM_INIT_EXP, SOURCE_NAME );
        SRC_STR	: constant STRING	:= PRINT_NAME( D( LX_SYMREP, SOURCE_NAME ) );
        SRC_TYPE	: TREE		:= D( SM_OBJ_TYPE, SOURCE_NAME );
        LVL	: LEVEL_NUM	renames CODI.CUR_LEVEL;
        LVL_STR	: constant STRING	:= IMAGE( LVL );
      begin
        if NAME = TREE_VOID then
	NAME := D( AS_NAME, RENAMES_OBJ_DECL );
        end if;

        while  SRC_TYPE.TY = DN_PRIVATE  or else  SRC_TYPE.TY = DN_L_PRIVATE  loop
	SRC_TYPE := D( SM_TYPE_SPEC, SRC_TYPE );
        end loop;

      -- Le renommage est représenté par un pointeur vers les données réelles.

      -- Cas particulier important : une tranche est un objet composite dont
      -- les bornes peuvent etre dynamiques. Il faut donc reprendre le doublet
      -- anonyme construit par CODE_SLICE, et non pointer vers le use_info du
      -- type source complet.
        declare
	IS_COMPOSITE : constant BOOLEAN :=
	    SRC_TYPE.TY = DN_RECORD
	    or else SRC_TYPE.TY = DN_CONSTRAINED_RECORD
	    or else SRC_TYPE.TY = DN_ARRAY
	    or else SRC_TYPE.TY = DN_CONSTRAINED_ARRAY;
        begin
	  if  IS_COMPOSITE  and then  NAME.TY = DN_SLICE  then
	    PUT_LINE( "VAR " & SRC_STR & "_disp, Q" );
	    PUT_LINE( "VAR " & SRC_STR & "__u, Q" );

	    EXPRESSIONS.CODE_SLICE( NAME, IS_DESTINATION => FALSE );
	    PUT_LINE( tab & "DUP" );
	    PUT_LINE( tab & "LA" );
	    PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & SRC_STR & "_disp" );
	    PUT_LINE( tab & "LA" & tab & ", 8" );
	    PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & SRC_STR & "__u" );

	  else
	    PUT_LINE( "VAR " & SRC_STR & "_disp, Q" );

	    EXPRESSIONS.CODE_OBJECT_ADDRESS( NAME );
	    PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & SRC_STR & "_disp" );

	  -- Pour les composites non-tranches, on garde le doublet TLALOC habituel.
	    if  IS_COMPOSITE  then
	      declare
	        TYPE_NAME		: TREE		:= D( XD_SOURCE_NAME, SRC_TYPE );
	        TYPE_NAME_STR	:constant STRING	:= '_' & PRINT_NAME( D( LX_SYMREP, TYPE_NAME ) );
	        TYPE_LVL_STR	:constant STRING	:= IMAGE( DI( CD_LEVEL, SRC_TYPE ) );			-- niveau du TYPE (frame de sa def)
	      begin
	        PUT_LINE( "VAR " & SRC_STR & "__u, Q" );

	        PUT( tab & "LVA" & tab & TYPE_LVL_STR & ", " );
	        CODI.REGIONS_PATH( TYPE_NAME );
	        PUT_LINE( TYPE_NAME_STR & ".SIZ__" );

	        PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & SRC_STR & "__u" );
	      end;
	    end if;
	  end if;
        end;

        DI( CD_LEVEL, SOURCE_NAME, INTEGER( LVL ) );
        DB( CD_COMPILED, SOURCE_NAME, TRUE );
      end;
    end if;

  end	CODE_RENAMES_OBJ_DECL;
	---------------------


		---------------------
  procedure	CODE_RENAMES_EXC_DECL	( RENAMES_EXC_DECL :TREE )
  is		--------------------
  begin
    null;		-- INTENTIONNEL -- PILIER 11, LRM 8.5 : un renames d'exception ne declare RIEN.
		-- L'identite est celle de l'exception d'ORIGINE, resolue au site
		-- d'usage par CODI.EXCEPTION_ID_OF.  PIEGE : emettre une STR ici
		-- creerait une identite DISTINCTE -- handlers inoperants a travers
		-- le renommage.
  end	CODE_RENAMES_EXC_DECL;
	---------------------


			-----------------------
  procedure		CODE_SIMPLE_RENAME_DECL	( SIMPLE_RENAME_DECL :TREE )
  is			-----------------------
  begin

    if SIMPLE_RENAME_DECL.TY = DN_RENAMES_OBJ_DECL then
      CODE_RENAMES_OBJ_DECL ( SIMPLE_RENAME_DECL );

    elsif SIMPLE_RENAME_DECL.TY = DN_RENAMES_EXC_DECL then
      CODE_RENAMES_EXC_DECL ( SIMPLE_RENAME_DECL );

    else
      CODI.TROU( "CODE_SIMPLE_RENAME_DECL", SIMPLE_RENAME_DECL );				--| vague 4, HORS LISTE : dispatch muet
    end if;

  end	CODE_SIMPLE_RENAME_DECL;
	-----------------------


 procedure CODE_NAMED_REP	( NAMED_REP :TREE );
 procedure CODE_RECORD_REP	( RECORD_REP :TREE );

			--------
 procedure		CODE_REP		( REP :TREE )
 is			--------
  begin

    if REP.TY in CLASS_NAMED_REP  then  CODE_NAMED_REP( REP );

    elsif REP.TY = DN_RECORD_REP  then  CODE_RECORD_REP( REP );

    else  CODI.TROU( "CODE_REP", REP );								--| vague 4 : dispatch muet (fossile n 115)

    end if;

  end	CODE_REP;
	--------


			--------------
  procedure		CODE_NAMED_REP	( NAMED_REP :TREE )
  is			--------------
  begin

    if  NAMED_REP.TY = DN_ADDRESS  then
      declare
        OBJ_DEFN	: TREE	:= D( SM_DEFN, D( AS_NAME, NAMED_REP ) );
      begin
        if  OBJ_DEFN.TY in CLASS_VC_NAME  and then  D( SM_ADDRESS, OBJ_DEFN ) /= TREE_VOID  then
			--| INTENTIONNEL (C8, oracle ADDR_OV1, 01/08) : clause d'adresse
			--| d'OBJET entierement traitee a la DECLARATION via SM_ADDRESS --
			--| equation de symbole fasmg ( X_disp = Y_disp ), scalaires ET
			--| composites ; hors statique-par-nom le TROU est leve LA-BAS.
			--| Rien a emettre au site de la clause.
          null;
        else
          CODI.TROU( "rep-clause 'ADDRESS hors objet (sous-programme/entree systeme ?)", NAMED_REP );	--| carnet : clause de SOUS-PROGRAMME (16#...#) = chantier separe
        end if;
      end;

    elsif  NAMED_REP.TY = DN_LENGTH_ENUM_REP
    then
			--| Reclassement n 3 (recensement auto-compilation, 28/07) :
			--| le noeud couvre DEUX clauses, sorts distincts.
      if  D( AS_EXP, NAMED_REP ).TY = DN_AGGREGATE  then
			--| for T use (...) : representation d'ENUMERATION.  Les
			--| VALEURS sont pliees (SM_REP partout) mais la machinerie
			--| ORDINALE ne l'est pas ('POS/'VAL identite, 'SUCC/'PRED
			--| par INC/DEC, indexation par la valeur) : rep /= pos
			--| donnerait du code faux.  Reste TROU -- dossier n 117-bis.
        CODI.TROU( "rep-clause d'ENUMERATION (machinerie ordinale non auditee, n 117-bis)", NAMED_REP );
      else
			--| INTENTIONNEL : clause de LONGUEUR (for T'SIZE/'SMALL/... use N),
			--| pliee par le FRONT-END -- CD_IMPL_SIZE porte la taille (les
			--| acces passent par OPER_SIZ_CHAR sur la BASE), le small du
			--| fixed est porte par ses attributs (pilier F).  Rien a emettre
			--| au site.  Au premier temoin 'SIZE : verifier que CD_IMPL_SIZE
			--| reflete bien la clause, sinon rouvrir.  Restes n 117 :
			--| TYPE_SIZE scalaire ignore CD_IMPL_SIZE (arbitrage vague 2).
        null;											--| INTENTIONNEL (cf. ci-dessus)
      end if;
    else
      CODI.TROU( "CODE_NAMED_REP", NAMED_REP );								--| vague 4 : dispatch muet
    end if;

  end	CODE_NAMED_REP;
	--------------


			---------------
  procedure		CODE_RECORD_REP	( RECORD_REP :TREE )
  is			---------------
  begin
			--| Les clauses de COMPOSANTS sont traitees par represented_items
			--| via les ATTRIBUTS du type (n 117) : le noeud REP en position
			--| de declaration n'a rien a emettre.  Seule la clause
			--| d'ALIGNEMENT (at mod) reste non couverte : TROU si presente.
    if  D( AS_ALIGNMENT_CLAUSE, RECORD_REP ) /= TREE_VOID
    and then  D( AS_ALIGNMENT_CLAUSE, RECORD_REP ) /= TREE_NIL
    then
			--| Reclassement n 5 (recensement idl.ads/adb, 28/07) : l'at mod
			--| est DISCRIMINABLE.  L'alignement effectif du stockage est 8
			--| PARTOUT dans le modele x86_64 maison (pile en q, VAR q,
			--| STATOFS 8 -- defaut documente n 117) : une adresse multiple
			--| de 8 est multiple de tout diviseur de 8, donc at mod 1/2/4/8
			--| est SATISFAIT PAR CONSTRUCTION.  Seuls at mod > 8 ou une
			--| expression non statique restent des manques reels.
      declare
        ALIGN_VAL	: INTEGER;
        ALIGN_OK	: BOOLEAN;
      begin
        TYPES_DECLS.STATIC_BOUND_VALUE( D( AS_EXP, D( AS_ALIGNMENT_CLAUSE, RECORD_REP ) ),
					ALIGN_VAL, ALIGN_OK );
        if  ALIGN_OK  and then  ALIGN_VAL > 0  and then  8 mod ALIGN_VAL = 0  then
	null;											--| INTENTIONNEL : garanti par l'alignement 8
        else
	CODI.TROU( "clause at mod > 8 ou non statique (croiser n 117)", RECORD_REP );
        end if;
      end;

    else
      null;											--| INTENTIONNEL : composants via represented_items
    end if;

  end	CODE_RECORD_REP;
	---------------


			----------------------------------------------------

			--	DECL . ID_DECL .  U N I T _ D E C L	--

			----------------------------------------------------


  procedure CODE_NON_GENERIC_DECL	( NON_GENERIC_DECL :TREE );

		--------------
  procedure	CODE_UNIT_DECL		( UNIT_DECL :TREE )
  is		--------------
  begin

    if UNIT_DECL.TY = DN_GENERIC_DECL
    then  CODE_GENERIC_DECL ( UNIT_DECL );

    elsif UNIT_DECL.TY in CLASS_NON_GENERIC_DECL
    then  CODE_NON_GENERIC_DECL ( UNIT_DECL );

    else
      CODI.TROU( "CODE_UNIT_DECL", UNIT_DECL );								--| vague 4 : dispatch muet (fossile n 115)
    end if;

  end	CODE_UNIT_DECL;
	--------------



			--^^^^^^^^^^^^^^^^^--
  procedure		  CODE_GENERIC_DECL		( GENERIC_DECL :TREE )
  is			---------------------

    GENERIC_ID	: TREE		:= D( AS_SOURCE_NAME, GENERIC_DECL );
    GEN_NAME	:constant STRING	:= PRINT_NAME( D( LX_SYMREP, GENERIC_ID ) );
    G_PARAMS	: SEQ_TYPE	:= LIST( D( SM_GENERIC_PARAM_S, GENERIC_ID ) );
    G_PARAM	: TREE;
    G_SPEC	: TREE		:= D( SM_SPEC, GENERIC_ID);

  begin
	-- Garde d'inclusion (piege n 97) : toute unite incluse via
		-- "if ~ definite X" doit definir X en tete de son FINC --
		-- convention deja suivie par CODE_PACKAGE_DECL. Sans elle,
		-- le FINC du modele est re-inclus a chaque with (et meme
		-- DEUX fois dans la meme unite : CODE_WITH_CONTEXT puis
		-- CODE_TRANS_WITH_INCLUDES). NB : "=" fasmg est une
		-- affectation redefinissable -- inoffensive par construction
		-- meme en cas de double emission.
    PUT_LINE( GEN_NAME & " = '" & GEN_NAME & "'" );
				------------------------
				TRAITE_FORMAL_PARAMETERS:
    while  not IS_EMPTY( G_PARAMS )  loop
      POP( G_PARAMS, G_PARAM );
      if  G_PARAM.TY = DN_TYPE_DECL  then
        if  D( AS_TYPE_DEF, G_PARAM ).TY = DN_FORMAL_INTEGER_DEF  then
	DI( CD_IMPL_SIZE, D( SM_TYPE_SPEC, D( AS_SOURCE_NAME, G_PARAM ) ), INTG_SIZE * 8 );

        elsif  D( AS_TYPE_DEF, G_PARAM ).TY = DN_FORMAL_DSCRT_DEF  then
	DI( CD_IMPL_SIZE, D( SM_TYPE_SPEC, D( AS_SOURCE_NAME, G_PARAM ) ), INTG_SIZE * 8 );
        end if;
      end if;
    end loop	TRAITE_FORMAL_PARAMETERS;
		------------------------

    if  G_SPEC.TY = DN_PROCEDURE_SPEC  or  G_SPEC.TY = DN_FUNCTION_SPEC  then
      PUT_LINE( "; GENERIC_SUBPROGRAM_SPEC" );

    else
      declare
        DECL_S	: SEQ_TYPE	:= LIST( D( AS_DECL_S1, D( AS_HEADER, GENERIC_DECL ) ) );
        DECL	: TREE;

      begin
        while  not IS_EMPTY( DECL_S )  loop
	POP( DECL_S, DECL );
	if  DECL.TY = DN_SUBPROG_ENTRY_DECL  and then  IN_SPEC_UNIT  then
	  declare
	    LBL	: LABEL_TYPE	:= NEW_LABEL;
	    NAME  : TREE		:= D( AS_SOURCE_NAME, DECL );
	  begin
	    DI( CD_LABEL, NAME, INTEGER( LBL ) );
	    DI( CD_LEVEL, NAME, INTEGER( CODI.CUR_LEVEL ) + 1 );
	    DB( CD_COMPILED, D( AS_SOURCE_NAME, DECL ), TRUE );
	  end;
	end if;
        end loop;
      end;
    end if;

  end	CODE_GENERIC_DECL;
	--=============--



			---------------------
  procedure		CODE_NON_GENERIC_DECL	( NON_GENERIC_DECL :TREE )
  is			---------------------
  begin

    if  NON_GENERIC_DECL.TY = DN_SUBPROG_ENTRY_DECL
    then  CODE_SUBPROG_ENTRY_DECL( NON_GENERIC_DECL );

    elsif NON_GENERIC_DECL.TY = DN_PACKAGE_DECL
    then  CODE_PACKAGE_DECL( NON_GENERIC_DECL );

    else
      CODI.TROU( "CODE_NON_GENERIC_DECL", NON_GENERIC_DECL );					--| vague 4, HORS LISTE : dispatch muet
    end if;

  end	CODE_NON_GENERIC_DECL;
	---------------------


			--------------------
  procedure		CODE_GENERIC_ACTUALS	( UNIT_KIND :TREE; ACTUALS_PREFIX :STRING := "";
						  ACTUALS_LEVEL :LEVEL_NUM := CODI.CUR_LEVEL )
  is			--------------------

    GNAME_SEQ	: SEQ_TYPE	:= LIST( D( AS_GENERAL_ASSOC_S, UNIT_KIND ) );
    FORMAL_SEQ	: SEQ_TYPE;
    ACTUAL	: TREE;
    FORMAL	: TREE;

		-----------
    function	GENERIC_DEF	return TREE
    is		-----------
      GEN_NAME	: TREE	:= D( AS_NAME, UNIT_KIND );
    begin
      while  GEN_NAME.TY = DN_SELECTED  loop
        GEN_NAME := D( AS_DESIGNATOR, GEN_NAME );
      end loop;
      return  D( SM_DEFN, GEN_NAME );

    end	GENERIC_DEF;
	-----------

		----------------
    function	ACTUAL_NAME_DEFN	( A :TREE )	return TREE
    is		----------------
      N	: TREE	:= A;
    begin
      while  N.TY = DN_SELECTED  loop
        N := D( AS_DESIGNATOR, N );
      end loop;

      return  D( SM_DEFN, N );

    end	ACTUAL_NAME_DEFN;
	----------------

  begin
    FORMAL_SEQ := LIST( D( SM_GENERIC_PARAM_S, GENERIC_DEF ) );

    while  not IS_EMPTY( GNAME_SEQ )  loop
      POP( GNAME_SEQ, ACTUAL );
      POP( FORMAL_SEQ, FORMAL );

      if  ACTUAL.TY = DN_ASSOC  then
        ACTUAL := D( AS_EXP, ACTUAL );
      end if;

      declare
        DEFN		: TREE;
        LVL_STR		:constant STRING	:= LEVEL_NUM'IMAGE( ACTUALS_LEVEL );

      begin
        if  FORMAL.TY = DN_IN  or else  FORMAL.TY = DN_IN_OUT  or else  FORMAL.TY = DN_OUT  then

				---------------------
				ACTUAL_GENERIC_OBJECT:
	declare
	  NAME_SEQ	: SEQ_TYPE	:= LIST( D( AS_SOURCE_NAME_S, FORMAL ) );
	  ACTUAL_TYPE	: TREE		:= D( SM_EXP_TYPE, ACTUAL );
	  FORMAL_NAME	: TREE;
		------------------------
	procedure CODE_ACTUAL_OBJECT_VALUE	( ACTUAL :TREE; FORMAL_TYPE :TREE )
	is	------------------------
	   ANON	:constant STRING	:= "STR_" & NEW_LABEL;
	begin
	  if  FORMAL_TYPE.TY in CLASS_SCALAR  or else  CODI.EST_ACCES( FORMAL_TYPE )  then
	      -- '&' caractère, entier, enum, variable scalaire, etc.
	    EXPRESSIONS.CODE_EXP( ACTUAL );

	  else
	      -- composite : il faut laisser @doublet sur pile
	    if ACTUAL.TY = DN_STRING_LITERAL then
	      EXPRESSIONS.CODE_STRING_LITERAL( ACTUAL, ANON );
	      PUT_LINE( tab & "LCA" & tab & ANON & ".data_ptr" );

	    elsif  ACTUAL.TY = DN_INDEXED  or else  ACTUAL.TY = DN_SELECTED
	    or else  ACTUAL.TY = DN_ALL   or else  ACTUAL.TY = DN_SLICE
	    then
			--| Vague 2 (n 112, dette AUDITS "contrat de
			--| CODE_ACTUAL_OBJECT_VALUE") : l'appelant enchaine DUP /
			--| La ,0 / La ,8 -- contrat @doublet strict.  Une reference
			--| de composant laisse @data nue (la tranche : @data, LEN),
			--| les deux La liraient des donnees comme des pointeurs.
			--| Refus bruyant ; remede le jour du temoin : doublet anonyme.
	      CODI.TROU( "actuel generique composite reference de composant (contrat @doublet)", ACTUAL );

	    else
	      EXPRESSIONS.CODE_EXP( ACTUAL );
	    end if;
	  end if;
	end	CODE_ACTUAL_OBJECT_VALUE;
		------------------------

	begin
	  while  ACTUAL_TYPE.TY = DN_PRIVATE  or else  ACTUAL_TYPE.TY = DN_L_PRIVATE  loop
	    ACTUAL_TYPE := D( SM_TYPE_SPEC, ACTUAL_TYPE );
	  end loop;

	  while  not IS_EMPTY( NAME_SEQ )  loop
	    POP( NAME_SEQ, FORMAL_NAME );

	    declare
	      FORMAL_STR	:constant STRING	:= ACTUALS_PREFIX & PRINT_NAME( D( LX_SYMREP, FORMAL_NAME ) );

	    begin
	      if  ACTUAL_TYPE.TY in CLASS_SCALAR  or else  CODI.EST_ACCES( ACTUAL_TYPE )  then
	        PUT_LINE( "VAR " & FORMAL_STR & "_disp, Q" );

	        CODE_ACTUAL_OBJECT_VALUE( ACTUAL, ACTUAL_TYPE );

	        PUT_LINE( tab & "S" & OPER_SIZ_CHAR( ACTUAL_TYPE ) & " " & LVL_STR & ", " & FORMAL_STR & "_disp" );

	      else
	        PUT_LINE( "VAR " & FORMAL_STR & "_disp, Q" );
	        PUT_LINE( "VAR " & FORMAL_STR & "__u, Q" );

	        CODE_ACTUAL_OBJECT_VALUE( ACTUAL, ACTUAL_TYPE );
	        PUT_LINE( tab & "DUP" );
	        PUT_LINE( tab & "LA  ,  0" );
	        PUT_LINE( tab & "SA " & LVL_STR & ", " & FORMAL_STR & "_disp" );
	        PUT_LINE( tab & "LA  ,  8" );
	        PUT_LINE( tab & "SA " & LVL_STR & ", " & FORMAL_STR & "__u" );
	      end if;
	    end;
	  end loop;
	end		ACTUAL_GENERIC_OBJECT;
			---------------------


        elsif  FORMAL.TY = DN_TYPE_DECL  or  FORMAL.TY = DN_SUBTYPE_DECL  then
	DEFN := D( SM_DEFN, ACTUAL );

				-------------------
				ACTUAL_GENERIC_TYPE:
	declare
	  DEFN_TYPE_SPEC	: TREE		:= D( SM_TYPE_SPEC, DEFN );
	  DEFN_STR	:constant STRING	:= PRINT_NAME( D( LX_SYMREP, DEFN ) );
	  FORMAL_ID	: TREE		:= D( AS_SOURCE_NAME, FORMAL );
	  FORMAL_STR	:constant STRING	:= ACTUALS_PREFIX & PRINT_NAME( D( LX_SYMREP, FORMAL_ID ) );
	begin
	  CODI.SET_GENERIC_ACTUAL_TYPE( PRINT_NAME( D( LX_SYMREP, FORMAL_ID ) ), DEFN_TYPE_SPEC );		-- F-4a

	  if  DEFN_TYPE_SPEC.TY  in  CLASS_SCALAR  then
	        -- Micro-procedures LD et ST pour le type actuel (contournees par BRA)
	    declare
	      SIZ_CHAR	: CHARACTER	:= OPER_SIZ_CHAR( DEFN_TYPE_SPEC );
	    begin
		-- LD : pile = [adresse] → pile = [valeur]
	      PUT_LINE(	"BRA post_LD_" & FORMAL_STR );
	      PUT_LINE(	"LD_" & FORMAL_STR & ".elab:" );
	      PUT_LINE(	tab & OPER_LOAD_STR( DEFN_TYPE_SPEC ) & " -1, 0" );
	      PUT_LINE(	tab & "RTD 0" );
	      PUT_LINE(	"post_LD_" & FORMAL_STR & ":" );

		-- ST : pile = [@param_out, valeur] → pile = []
	      PUT_LINE(	"BRA post_ST_" & FORMAL_STR );
	      PUT_LINE(	"ST_" & FORMAL_STR & ".elab:" );
	      PUT_LINE(	tab & "S" & SIZ_CHAR & " -1, 0" );
	      PUT_LINE(	tab & "RTD 0" );
	      PUT_LINE(	"post_ST_" & FORMAL_STR & ":" );
		-- ADR : pile = [@param_out, valeur] → pile = []

	      PUT_LINE(	"BRA post_INADR_" & FORMAL_STR );
	      PUT_LINE(	"INADR_" & FORMAL_STR & ".elab:" );
	      PUT_LINE(	tab & "RTD 0" );								-- Rien a faire pour un scalaire
	      PUT_LINE(	"post_INADR_" & FORMAL_STR & ":" );

	      PUT_LINE(	"BRA post_OUTADR_" & FORMAL_STR );
	      PUT_LINE(	"OUTADR_" & FORMAL_STR & ".elab:" );
	      PUT_LINE(	tab & "LA" );								-- Pointer Data
	      PUT_LINE(	tab & "RTD 0" );								-- Rien a faire pour un scalaire
	      PUT_LINE(	"post_OUTADR_" & FORMAL_STR & ":" );
	    end;

	        -- VAR en ordre INVERSE des PRM du modele :
	        -- PRM: __u(8) __ld(16) __st(24)  → VAR: __st(-24) __ld(-16) __u(-8)

	    PUT_LINE( "VAR " & FORMAL_STR & "__outadr_ofs, Q" );
	    PUT_LINE( tab & "LCA OUTADR_" &	FORMAL_STR & ".elab" );
	    PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & FORMAL_STR & "__outadr_ofs" );

	    PUT_LINE( "VAR " & FORMAL_STR & "__inadr_ofs, Q" );
	    PUT_LINE( tab & "LCA INADR_" & FORMAL_STR &	".elab" );
	    PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & FORMAL_STR & "__inadr_ofs"	);

	    PUT_LINE( "VAR " & FORMAL_STR & "__st_ofs, Q" );
	    PUT_LINE( tab & "LCA ST_" & FORMAL_STR & ".elab" );
	    PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & FORMAL_STR & "__st_ofs" );

	    PUT_LINE( "VAR " & FORMAL_STR & "__ld_ofs, Q" );
	    PUT_LINE( tab & "LCA LD_" & FORMAL_STR & ".elab" );
	    PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & FORMAL_STR & "__ld_ofs" );

	  elsif  DEFN_TYPE_SPEC.TY  in  CLASS_UNCONSTRAINED						-- COMPOSITE ARRAY OU RECORD GENERIQUES
	     or  DEFN_TYPE_SPEC.TY  in  CLASS_CONSTRAINED  then
					-- A REVOIR

	    begin
		-- LD : pile = [adresse] → pile = [valeur]
	      PUT_LINE(	"BRA post_LD_" & FORMAL_STR );
	      PUT_LINE(	"LD_" & FORMAL_STR & ".elab:" );
	      PUT_LINE(	tab & "LI 0" );				-- A REVOIR
	      PUT_LINE(	tab & "RTD 0" );
	      PUT_LINE(	"post_LD_" & FORMAL_STR & ":" );

		-- ST : pile = [@param_out, valeur] → pile = []
	      PUT_LINE(	"BRA post_ST_" & FORMAL_STR );
	      PUT_LINE(	"ST_" & FORMAL_STR & ".elab:" );
	      PUT_LINE(	tab & "DROP" );				-- A REVOIR
	      PUT_LINE(	tab & "RTD 0" );
	      PUT_LINE(	"post_ST_" & FORMAL_STR & ":" );

	      PUT_LINE(	"BRA post_INADR_" & FORMAL_STR );
	      PUT_LINE(	"INADR_" & FORMAL_STR	& ".elab:" );
	      PUT_LINE(	tab & "LIA" );								-- Indirection
	      PUT_LINE(	tab & "RTD 0" );
	      PUT_LINE(	"post_INADR_" & FORMAL_STR & ":" );

	      PUT_LINE(	"BRA post_OUTADR_" & FORMAL_STR	);
	      PUT_LINE(	"OUTADR_" & FORMAL_STR & ".elab:" );
	      PUT_LINE(	tab & "LIA" );								-- Indirection
	      PUT_LINE(	tab & "RTD 0" );
	      PUT_LINE(	"post_OUTADR_" & FORMAL_STR & ":" );
	    end;

	    PUT_LINE( "VAR " & FORMAL_STR & "__outadr_ofs, Q" );
	    PUT_LINE( tab & "LCA OUTADR_" &	FORMAL_STR & ".elab" );
	    PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & FORMAL_STR & "__outadr_ofs" );

	    PUT_LINE( "VAR " & FORMAL_STR & "__inadr_ofs, Q" );
	    PUT_LINE( tab & "LCA INADR_" & FORMAL_STR &	".elab" );
	    PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & FORMAL_STR & "__inadr_ofs"	);

	    PUT_LINE( "VAR " & FORMAL_STR & "__st_ofs, Q" );
	    PUT_LINE( tab & "LCA ST_" & FORMAL_STR & ".elab" );
	    PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & FORMAL_STR & "__st_ofs" );

	    PUT_LINE( "VAR " & FORMAL_STR & "__ld_ofs, Q" );
	    PUT_LINE( tab & "LCA LD_" & FORMAL_STR & ".elab" );
	    PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & FORMAL_STR & "__ld_ofs" );

	  else
	    CODI.TROU( "ACTUAL_GENERIC_TYPE actuel generique de type : sorte non geree", DEFN_TYPE_SPEC );		--| vague 5 : __ld_ofs absent, appels indirects faux
	  end if;

	  PUT_LINE( "VAR " & FORMAL_STR & "__u_ofs, Q"	);
	  PUT( tab & "LA" & tab & INTEGER'IMAGE( DI( CD_LEVEL, D( SM_TYPE_SPEC, DEFN ) ) ) & ", " );
	  CODI.REGIONS_PATH( DEFN	);
	  PUT_LINE( '_' & DEFN_STR & ".use__info"	);
	  PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & FORMAL_STR & "__u_ofs" );

	end	ACTUAL_GENERIC_TYPE;
		-------------------

        elsif  FORMAL.TY = DN_SUBPROG_ENTRY_DECL  then


				-----------------
				ACTUAL_SUBPROGRAM:
	declare
	  FORMAL_ID	: TREE		:= D( AS_SOURCE_NAME, FORMAL );
	  FORMAL_STR	: constant STRING	:= PRINT_NAME( D( LX_SYMREP, FORMAL_ID ) );
	  FORMAL_SPEC	: TREE		:= D( AS_HEADER, FORMAL );
	  BRIDGE_STR	:constant STRING	:= FORMAL_STR & "__bridge_" & NEW_LABEL;
	  ACTUAL_SUBP	: TREE		:= ACTUAL;
	  ACTUAL_DEFN	: TREE		:= ACTUAL_NAME_DEFN( ACTUAL );

	begin
	  if  ACTUAL_SUBP.TY = DN_ASSOC  then
	    ACTUAL_SUBP := D( AS_EXP, ACTUAL_SUBP );
	  end if;

	  if  ACTUAL_DEFN.TY = DN_ENTRY_ID  then
	    PUT_LINE( "VAR " & LETTERED_SUBNAME( FORMAL_STR )  & "__call_ofs, Q" );

	  elsif  ACTUAL_DEFN.TY = DN_BLTN_OPERATOR_ID  then
	    PUT_LINE( "VAR " & LETTERED_SUBNAME( FORMAL_STR )  & "__call_ofs, Q" );

	  elsif  ACTUAL_DEFN.TY = DN_ENUMERATION_ID  or  ACTUAL_DEFN.TY = DN_CHARACTER_ID  then
	    PUT_LINE( "VAR " & FORMAL_STR & "_disp, Q" );
	    PUT_LINE( tab & "LI" & tab & IMAGE( DI( SM_POS, ACTUAL_DEFN ) ) );
	    PUT_LINE( tab & "SB " & LVL_STR & ", " & FORMAL_STR & "_disp" );

	  else

	    declare
	      ACTUAL_STR	:constant STRING	:= LETTERED_SUBNAME( PRINT_NAME( D( LX_SYMREP, ACTUAL_DEFN ) ) )
					   & "_L" & IMAGE( DI( CD_LABEL, ACTUAL_DEFN ) );
	      SUBNAME_STR	:constant string	:= LETTERED_SUBNAME( FORMAL_STR );
	    begin
	      PUT_LINE( "VAR " & SUBNAME_STR & "__call_ofs, Q" );
	      PUT( tab & "LSPA" & tab );
	      CODI.REGIONS_PATH( ACTUAL_DEFN );
	      PUT_LINE( " ," & ACTUAL_STR );
	      PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & SUBNAME_STR & "__call_ofs" );

	    end;
	  end if;
	end	ACTUAL_SUBPROGRAM;
		-----------------

        else
	CODI.TROU( "actuel generique : sorte de formel non couverte", FORMAL );				--| vague 4, HORS LISTE : dispatch muet
        end if;
      end;
    end loop;

    PUT( "VAR GFP_disp, Q" );
    if  CODI.DEBUG  then
      PUT( tab50 & "; Lieu du Generic Frame Pointer " );
    end if;
    NEW_LINE;

  end	CODE_GENERIC_ACTUALS;
	--------------------


			--=======================--
  procedure		  CODE_SUBPROG_ENTRY_DECL	( SUBPROG_ENTRY_DECL :TREE )
  is			---------------------------

    SOURCE_NAME			: TREE	:= D( AS_SOURCE_NAME, SUBPROG_ENTRY_DECL );

    SAVE_NO_SUB_PARAM		: BOOLEAN := CODI.NO_SUBP_PARAMS;
    SAVE_IN_GENERIC_INSTANTIATION	: BOOLEAN := CODI.IN_GENERIC_INSTANTIATION;
    SAVE_INSTANTIATION_MODEL_NAME	: TREE	:= CODI.INSTANTIATION_MODEL_NAME;
    SAVE_OUTPUT_CODE		: BOOLEAN := CODI.OUTPUT_CODE;
    IS_AN_INSTANTIATION		: BOOLEAN := D( AS_UNIT_KIND, SUBPROG_ENTRY_DECL ).TY = DN_INSTANTIATION;

  begin
    if  CODI.DEBUG  then PUT( tab50 & "; sub program entry decl (in instantiation "
	& BOOLEAN'IMAGE( CODI.IN_GENERIC_INSTANTIATION ) & " )" ); end if;
    NEW_LINE;

    if  not (SOURCE_NAME.TY in CLASS_SUBPROG_NAME)  then
      PUT_LINE( "ANOMALIE : EXPANDER.DECLARATIONS.CODE_SUBPROG_ENTRY_DECL ; SOURCE_NAME.TY pas dans CLASS_SUBPROG_NAME" );
      raise PROGRAM_ERROR;
    else
      if  CODI.IN_SPEC_UNIT
      then DB( CD_COMPILED, SOURCE_NAME, TRUE );
      else
        if  not IN_GENERIC_INSTANTIATION  and then  DB( CD_COMPILED, SOURCE_NAME )  then
	return;
        end if;
      end if;
    end if;

    if  IS_AN_INSTANTIATION  then	         -- ce decl EST une instanciation (a8)
      CODI.IN_GENERIC_INSTANTIATION := TRUE;
      CODI.CLEAR_GENERIC_ACTUAL_TYPES;									-- F-4a : table de l'instanciation courante

      CODI.INSTANTIATION_MODEL_NAME := D( AS_NAME, D( AS_UNIT_KIND, SUBPROG_ENTRY_DECL ) );
      while  CODI.INSTANTIATION_MODEL_NAME.TY = DN_SELECTED  loop	-- cas TEXT_IO.xxx
        CODI.INSTANTIATION_MODEL_NAME := D( AS_DESIGNATOR, CODI.INSTANTIATION_MODEL_NAME );
      end loop;
    end if;
    -- sinon : sous-programme d'une instance de package →
    -- INSTANTIATION_MODEL_NAME reste celui posé par CODE_PACKAGE_DECL (le modèle du package)

    INC_LEVEL;
    declare
      HEADER	: TREE;
      LBL		: LABEL_TYPE	:= NEW_LABEL;
    begin

      if  CODI.IN_SPEC_UNIT  or else  not DB( CD_COMPILED, SOURCE_NAME )
      then  DI( CD_LABEL, SOURCE_NAME, INTEGER( LBL ) );
      end if;

      DI( CD_LEVEL, SOURCE_NAME, INTEGER( CODI.CUR_LEVEL ) );
      DB( CD_COMPILED, SOURCE_NAME, TRUE );

      if  not CODI.IN_GENERIC_INSTANTIATION  then CODI.OUTPUT_CODE := FALSE; end if;				-- ne pas coder les parametres (le body fera ca)

      if  CODI.IN_GENERIC_INSTANTIATION  then
        HEADER := D( SM_SPEC, SOURCE_NAME );
				-------------------------------
				INSTANTIATION_SUBPROG_GENERIQUE:
        declare
	SOURCE_NAME	: TREE		:= D( AS_SOURCE_NAME, SUBPROG_ENTRY_DECL );
	SUB_NAME		:constant STRING	:= LETTERED_SUBNAME( PRINT_NAME( D( LX_SYMREP, SOURCE_NAME ) ) );
	LBL		: LABEL_TYPE	:= LABEL_TYPE( DI( CD_LABEL, SOURCE_NAME ) );
	LABELED_SUB_STR	:constant STRING	:= SUB_NAME & '_' & LABEL_STR( LBL );

        begin
	PUT_LINE( "if defined " & LABELED_SUB_STR & '_' );

	if  IS_AN_INSTANTIATION  then
	  CODE_GENERIC_ACTUALS( D( AS_UNIT_KIND, SUBPROG_ENTRY_DECL ), LABELED_SUB_STR, CODI.CUR_LEVEL-1 );
	end if;

	PUT( "PRO" & tab & LABELED_SUB_STR );
	if  CODI.DEBUG  then PUT( tab50 & ";---------- PRO " & SUB_NAME ); end if;
	NEW_LINE;
	if  CODI.GENERATE_BINARY_MAP  then
	  PUT_LINE( " hexa_show '" & SUB_NAME & '_' & LABEL_STR( LBL ) & " ', $" );
	end if;

	CODE_HEADER( HEADER );

	PUT_LINE( "ELB" & LEVEL_NUM'IMAGE( CODI.CUR_LEVEL ) );
	PUT_LINE( "begin:" );

	declare
	  MODEL_DEFN		: TREE		:= D( SM_DEFN, CODI.INSTANTIATION_MODEL_NAME );
	  MODEL_SPEC		: TREE		:= D( SM_SPEC, MODEL_DEFN );
	  IS_UNCHECKED_CONVERSION	: constant BOOLEAN
					:= MODEL_DEFN.TY = DN_GENERIC_ID
			   and then  PRINT_NAME( D( LX_SYMREP, MODEL_DEFN ) ) = "UNCHECKED_CONVERSION";
	begin

	  if  not IS_UNCHECKED_CONVERSION  then								-- protocole d'appel du modele : slot resultat + GFP + arguments
	    if  SOURCE_NAME.TY = DN_FUNCTION_ID  or  SOURCE_NAME.TY = DN_OPERATOR_ID  then
	      declare
	        WRAP_RESULT_TYPE	: TREE		:= D( SM_TYPE_SPEC, D( SM_DEFN, D( AS_NAME, HEADER ) ) );
	      begin
	        if  WRAP_RESULT_TYPE.TY = DN_ARRAY  then							--| C7 (oracle INSTF1) : resultat NON CONTRAINT --
	          PUT( tab & "LA " & tab & LEVEL_NUM'IMAGE( CODI.CUR_LEVEL ) & ", -result__ofs" );		--| RELAYER le slot recu au modele : son CODE_RETURN
	          if  CODI.DEBUG  then PUT( tab50 & "; lieu result = relais du slot recu (doublet)" ); end if;	--| ecrit data_ptr+descripteur CHEZ l'appelant
	          NEW_LINE;
	        else
	          PUT( tab & "LI" & tab & '0' );							-- lieu result
	          if  CODI.DEBUG  then PUT( tab50 & "; lieu result" ); end if;
	          NEW_LINE;
	        end if;
	      end;
	    end if;

	    PUT_LINE(	tab & "LVA" & tab & LEVEL_NUM'IMAGE( CODI.CUR_LEVEL - 1 ) & ", GFP_disp" );
	  end if;

	declare
	  PRM_SECTIONS_S	: SEQ_TYPE	:= LIST( D( AS_PARAM_S, D( SM_SPEC, SOURCE_NAME ) ) );

			----------------------------
	  procedure	INVERSE_RECURSE_PRM_SECTIONS  ( REMAIN_SECTIONS :in out SEQ_TYPE )
	  is		----------------------------

	    PRM_SECTION		: TREE;
	  begin
	    if  IS_EMPTY( REMAIN_SECTIONS )  then return; end if;
	    POP( REMAIN_SECTIONS, PRM_SECTION );
	    INVERSE_RECURSE_PRM_SECTIONS( REMAIN_SECTIONS );

	    declare
	      NAME_S	: SEQ_TYPE	:= LIST( D( AS_SOURCE_NAME_S, PRM_SECTION ) );

			---------------------
	      procedure	INVERSE_RECURSE_NAMES	( NAMES :in out SEQ_TYPE )
	      is		---------------------
	        NAME	: TREE;

	      begin
	        if  IS_EMPTY( NAMES )  then return; end if;
	        POP( NAMES, NAME );
	        INVERSE_RECURSE_NAMES( NAMES );

	        if  (NAME.TY = DN_IN_ID) and (D( SM_OBJ_TYPE, NAME ).TY in CLASS_SCALAR)  then
		-- in scalaire : passer par copie (valeur)
		PUT_LINE( tab & 'L' & OPER_SIZ_CHAR( D( SM_OBJ_TYPE, NAME ) ) & tab & LEVEL_NUM'IMAGE( CODI.CUR_LEVEL )
			& ", -" & PRINT_NAME( D( LX_SYMREP, NAME ) ) & "_ofs" );

	        else
		-- in composite (record, array) ou out / in_out : propager l'adresse
		PUT_LINE( tab & "LA " & tab & LEVEL_NUM'IMAGE( CODI.CUR_LEVEL )
			& ", -" & PRINT_NAME( D( LX_SYMREP, NAME ) ) & "_ofs" );
	        end if;
	      end INVERSE_RECURSE_NAMES;
		---------------------

	    begin
	      INVERSE_RECURSE_NAMES( NAME_S );
	    end;

	  end	INVERSE_RECURSE_PRM_SECTIONS;
		----------------------------

	begin
	  if  not IS_UNCHECKED_CONVERSION  then
	    INVERSE_RECURSE_PRM_SECTIONS( PRM_SECTIONS_S );
	  end if;
	end;

	  if  MODEL_DEFN.TY = DN_GENERIC_ID
	      and then  PRINT_NAME( D( LX_SYMREP, MODEL_DEFN ) ) = "UNCHECKED_CONVERSION"
	  then

	    declare
			----------------------------------
	      procedure	CODE_UNCHECKED_CONVERSION_INSTANCE	( SUBPROG_ENTRY_DECL :TREE; SOURCE_NAME :TREE )
	      is
	  UNIT_KIND : TREE := D( AS_UNIT_KIND, SUBPROG_ENTRY_DECL );

	  ACTUALS	  : SEQ_TYPE := LIST( D( AS_GENERAL_ASSOC_S, UNIT_KIND ) );
	  SRC_ACT	  : TREE;
	  DST_ACT	  : TREE;

	  SRC_DEFN  : TREE;
	  DST_DEFN  : TREE;

	  SRC_TYPE  : TREE;
	  DST_TYPE  : TREE;

	  function ACTUAL_EXP ( A : TREE ) return TREE is
	  begin
	    if A.TY = DN_ASSOC then
	      return D( AS_EXP, A );
	    else
	      return A;
	    end if;
	  end ACTUAL_EXP;

			--------------------
	  procedure	EMIT_TYPE_SIZE_BYTES	( T : TREE )
	  is		--------------------
	    TT : TREE := CODI.FULL_TYPE_VIEW( T );
	  begin
	    if TT.TY = DN_RECORD then
	      declare
	        TN : TREE := D( XD_SOURCE_NAME, TT );
	        TS : constant STRING := '_' & PRINT_NAME( D( LX_SYMREP, TN ) );
	      begin
	        PUT( tab & "LI" & tab );
	        REGIONS_PATH( TN );
	        PUT_LINE( TS & ".size" );
	      end;

	    elsif TT.TY = DN_CONSTRAINED_ARRAY or else TT.TY = DN_ARRAY then
	      declare
	        TN : TREE := D( XD_SOURCE_NAME, TT );
	        TS : constant STRING := '_' & PRINT_NAME( D( LX_SYMREP, TN ) );
	      begin
	        PUT( tab & "LD" & tab & IMAGE( DI( CD_LEVEL, TT ) ) & ", " );
	        REGIONS_PATH( TN );
	        PUT_LINE( TS & ".SIZ__" );

	        PUT_LINE( tab & "LI" & tab & IMAGE( CODI.STORAGE_UNIT ) );
	        PUT_LINE( tab & "DIV" );
	      end;

	    elsif TT.TY in CLASS_SCALAR or else CODI.EST_ACCES( TT ) then
	      PUT_LINE( tab & "LI" & tab & IMAGE( CODI.TYPE_SIZE( TT ) ) );

	    else
	      PUT_LINE( "; UNCHECKED_CONVERSION : taille cible non geree "
		    & NODE_NAME'IMAGE( TT.TY ) );
	      raise PROGRAM_ERROR;
	    end if;

	  end	EMIT_TYPE_SIZE_BYTES;
		--------------------


	function IS_COMPOSITE ( T : TREE ) return BOOLEAN is
	  TT : TREE := CODI.FULL_TYPE_VIEW( T );
	begin
	  return TT.TY = DN_RECORD
	      or else TT.TY = DN_CONSTRAINED_RECORD
	      or else TT.TY = DN_ARRAY
	      or else TT.TY = DN_CONSTRAINED_ARRAY;
	end IS_COMPOSITE;

	begin
	  POP( ACTUALS, SRC_ACT );
	  POP( ACTUALS, DST_ACT );

	  SRC_ACT := ACTUAL_EXP( SRC_ACT );
	  DST_ACT := ACTUAL_EXP( DST_ACT );

	  SRC_DEFN := D( SM_DEFN, SRC_ACT );
	  DST_DEFN := D( SM_DEFN, DST_ACT );

	  SRC_TYPE := CODI.FULL_TYPE_VIEW( D( SM_TYPE_SPEC, SRC_DEFN ) );
	  DST_TYPE := CODI.FULL_TYPE_VIEW( D( SM_TYPE_SPEC, DST_DEFN ) );

  -- Version minimale robuste pour composite -> composite.
	  if  (SRC_TYPE.TY = DN_ARRAY or else SRC_TYPE.TY = DN_CONSTRAINED_ARRAY
	       or else SRC_TYPE.TY = DN_RECORD)
	  and (DST_TYPE.TY = DN_ARRAY or else DST_TYPE.TY = DN_CONSTRAINED_ARRAY
	       or else DST_TYPE.TY = DN_RECORD)
	  then
	    -- @DST = result__ofs.data_ptr
	    PUT_LINE( tab & "LA" & tab & IMAGE( CODI.CUR_LEVEL ) & ", -result__ofs" );
	    PUT_LINE( tab & "LA" );

    -- LEN = taille du type cible en octets
	    EMIT_TYPE_SIZE_BYTES( DST_TYPE );

    -- @SRC = S.data_ptr
	    PUT_LINE( tab & "LA" & tab & IMAGE( CODI.CUR_LEVEL ) & ", -S_ofs" );
	    PUT_LINE( tab & "LA" );

	    PUT_LINE( tab & "BLKMOV" );

	elsif  IS_COMPOSITE( SRC_TYPE )
	and then (DST_TYPE.TY in CLASS_SCALAR or else CODI.EST_ACCES( DST_TYPE ))
	then
  -- Source composite passée par adresse de doublet.
  -- result__ofs est un résultat scalaire.
	  PUT_LINE( tab & "LA" & tab & IMAGE( CODI.CUR_LEVEL ) & ", -S_ofs" );
	  PUT_LINE( tab & "LA" );
  -- Lire les octets bruts avec la taille du type cible.
	  PUT_LINE( tab & OPER_LOAD_STR( DST_TYPE ) );
  -- Stocker dans le slot résultat.
	  PUT_LINE( tab & "S" & OPER_SIZ_CHAR( DST_TYPE ) & tab & IMAGE( CODI.CUR_LEVEL ) & ", -result__ofs" );

	  else
	    PUT_LINE( "; UNCHECKED_CONVERSION : cas non encore gere "
		  & NODE_NAME'IMAGE( SRC_TYPE.TY ) & " -> " & NODE_NAME'IMAGE( DST_TYPE.TY ) );
	    raise PROGRAM_ERROR;
	  end if;
	      end CODE_UNCHECKED_CONVERSION_INSTANCE;
		----------------------------------

	    begin
	      CODE_UNCHECKED_CONVERSION_INSTANCE( SUBPROG_ENTRY_DECL => SUBPROG_ENTRY_DECL,
					SOURCE_NAME        => SOURCE_NAME
				);
	    end;

	  elsif  MODEL_DEFN.TY = DN_GENERIC_ID  and then  MODEL_SPEC.TY in CLASS_SUBP_ENTRY_HEADER  then
				-----------------------
				DIRECT_SUBPROG_INSTANCE:						-- procedure NP is new P (...);
	    declare
	      MODEL_BDY	: TREE		:= D( XD_BODY, MODEL_DEFN );
	      MODEL_NAME	:constant STRING	:= LETTERED_SUBNAME( PRINT_NAME( D( LX_SYMREP, MODEL_DEFN ) ) );
	      MODEL_LBL	: LABEL_TYPE	:= LABEL_TYPE( DI( CD_LABEL, D( AS_SOURCE_NAME, MODEL_BDY ) ) );

	    begin
	      PUT( tab & "CALL" & tab );
	      REGIONS_PATH( MODEL_DEFN );
	      PUT_LINE( " ," & MODEL_NAME & '_' & LABEL_STR( MODEL_LBL ) );

	    end	DIRECT_SUBPROG_INSTANCE;
		-----------------------
	  else
	    PUT( tab & "CALL" & tab );
	    REGIONS_PATH( D( SM_DEFN, CODI.INSTANTIATION_MODEL_NAME ) );
	    PUT( PRINT_NAME( D( LX_SYMREP, CODI.INSTANTIATION_MODEL_NAME ) ) & ". ," );
			----------------------------------------
			SUBPROG_IN_GENERIC_PACKAGE_INSTANTIATION:
	    declare
	      MODEL_DECL	: TREE;

	    begin
	      while  not( IS_EMPTY( CODI.GENERIC_MODEL_DECL_SEQ ) )  loop
	        POP( CODI.GENERIC_MODEL_DECL_SEQ, MODEL_DECL );
	        if  MODEL_DECL.TY = DN_SUBPROG_ENTRY_DECL  then
		declare
		  NAME	: TREE	:= D( AS_SOURCE_NAME, MODEL_DECL );
		  LBL	: INTEGER := DI( CD_LABEL, NAME );
		begin
		  PUT_LINE( PRINT_NAME( D( LX_SYMREP, NAME ) ) & "_L" & IMAGE( LBL ) );
		  exit;
		end;
	        end if;
	      end loop;
	    end	SUBPROG_IN_GENERIC_PACKAGE_INSTANTIATION;
		----------------------------------------
	  end if;
	end;

	if  SOURCE_NAME.TY = DN_FUNCTION_ID  or  SOURCE_NAME.TY = DN_OPERATOR_ID  then

	  if  D( SM_UNIT_DESC, SOURCE_NAME ).TY /= DN_INSTANTIATION  then
	    declare
	      USED_OBJECT_ID	: TREE		:= D( AS_NAME, HEADER );
	      RESULT_TYPE_ID	: TREE		:= D( SM_DEFN, USED_OBJECT_ID );
	      RESULT_TYPE_SPEC	: TREE		:= D( SM_TYPE_SPEC, RESULT_TYPE_ID );
	      RESULT_SIZE_CHAR	: CHARACTER;
	    begin
	      if  RESULT_TYPE_SPEC.TY = DN_ARRAY  then
			--| INTENTIONNEL (C7, oracle INSTF1, 01/08) : resultat NON CONTRAINT.
			--| Le prologue du wrapper RELAIE le slot recu ( La lvl,-result__ofs
			--| au lieu de LI 0 ) ; le CODE_RETURN du modele ecrit data_ptr et
			--| descripteur A TRAVERS ce slot, directement chez l'appelant, et
			--| RTD prm_siz-8 le lui laisse. Rien a rapatrier ici -- symetrique
			--| du rameau DN_INSTANTIATION ci-dessous (reclassement n 4).
	        null;

	      elsif  RESULT_TYPE_SPEC.TY  in  CLASS_UNCONSTRAINED  then
	        CODI.TROU( "INSTANTIATION_SUBPROG_GENERIQUE : resultat non contraint NON tableau", RESULT_TYPE_SPEC );	--| discrimine C7 : record/access jamais observes (doctrine n 122)

	      else
	        RESULT_SIZE_CHAR := OPER_SIZ_CHAR( RESULT_TYPE_SPEC );
	        if	RESULT_SIZE_CHAR /= 'v'  then
		PUT( tab & 'S' & RESULT_SIZE_CHAR
		& tab & LEVEL_NUM'IMAGE( CODI.CUR_LEVEL ) & ", -result__ofs"  );
		if  CODI.DEBUG  then PUT( tab50	& "; retour resultat" ); end if;
		NEW_LINE;

	        else
		CODI.TROU( "INSTANTIATION_SUBPROG_GENERIQUE : resultat par ref a faire", RESULT_TYPE_SPEC );	--| vague 5
	        end if;
	      end if;
	    end;
	  else
			--| INTENTIONNEL (reclassement n 4, recensement idl.adb 28/07,
			--| FINC TO_CHN_L187 a l'appui) : fonction d'INSTANCIATION.
			--| Son corps est SYNTHETISE par l'expander (unchecked_conversion:
			--| BLKMOV a travers le slot resultat -- La lvl,-result__ofs ; La ;
			--| BLKMOV) ou PARTAGE (modele generique) : le resultat est
			--| materialise PAR le corps via le protocole du slot, et
			--| RTD prm_siz-8 le laisse a l'appelant.  L'epilogue-magasin ne
			--| concerne que les corps compiles depuis l'Ada (CODE_RETURN).
			--| Rien a rapatrier ici -- l'ex-"A VOIR" est elucide.
			--| AMENDEMENT C7 (01/08, oracle INSTF1) : la moitie PARTAGE de ce
			--| fossile ne tenait que si le prologue RELAIE le slot -- le LI 0
			--| d'origine donnait un slot nul au modele (segfault a son
			--| CODE_RETURN). Relais pose au prologue pour DN_ARRAY.
			--| AMENDEMENT (lot 15, temoin GEN1) : pour un resultat SCALAIRE
			--| ou d'ACCES d'un modele PARTAGE, le prologue pose LI 0 : le
			--| modele ecrit dans CE slot, laisse au sommet par son RTD
			--| prm_siz-8 -- il faut le rapatrier dans le result__ofs du
			--| wrapper, sinon la fonction instanciee rend 0.  Modele SANS
			--| parametre declare : son RTD est nu (NO_SUBP_PARAMS) et laisse
			--| aussi GFP au sommet -- DROP d'abord.  On ne touche pas a cet
			--| epilogue : CODE_RETURN d'un resultat TABLEAU ecrit a -8, soit
			--| dans le slot GFP, et compte sur ce RTD nu (ENUMERATION_IO).
	    declare
	      MODELE		: TREE		:= D( SM_DEFN, CODI.INSTANTIATION_MODEL_NAME );
	      RES_TYPE		: TREE		:= CODI.FULL_TYPE_VIEW( D( SM_TYPE_SPEC, D( SM_DEFN, D( AS_NAME, HEADER ) ) ) );
	    begin
	      if  not ( MODELE.TY = DN_GENERIC_ID
		    and then  PRINT_NAME( D( LX_SYMREP, MODELE ) ) = "UNCHECKED_CONVERSION" )
	        and then  ( RES_TYPE.TY in CLASS_SCALAR  or else  CODI.EST_ACCES( RES_TYPE ) )
	      then
	        if  IS_EMPTY( LIST( D( AS_PARAM_S, D( SM_SPEC, SOURCE_NAME ) ) ) )  then		--| modele SANS parametre declare : son
		PUT_LINE( tab & "DROP" );							--| RTD nu laisse GFP au-dessus du resultat
	        end if;
	        PUT( tab & 'S' & OPER_SIZ_CHAR( RES_TYPE ) & tab & LEVEL_NUM'IMAGE( CODI.CUR_LEVEL ) & ", -result__ofs" );
	        if  CODI.DEBUG  then PUT( tab50 & "; retour resultat du modele partage" ); end if;
	        NEW_LINE;
	      end if;
	    end;
	  end if;
	end if;

	PUT_LINE( tab & CODI.EXIT_UNLINK_MNEMONIC( HEADER ) & tab & LEVEL_NUM'IMAGE( CODI.CUR_LEVEL ) );		--| chantier co-pile (n 163) : meme regle que ret_lbl

	if  CODI.NO_SUBP_PARAMS  then
	  PUT_LINE( tab & "RTD" );
	else
	  if  SOURCE_NAME.TY = DN_FUNCTION_ID  or  SOURCE_NAME.TY = DN_OPERATOR_ID  then			--| symetrie avec l'epilogue des corps reels (un operateur est une fonction)
	    PUT_LINE( tab & "RTD" & tab & "prm_siz-8" );
	  else
	    PUT_LINE( tab & "RTD" & tab & "prm_siz" );
	  end if;
	end if;
	PUT( "endPRO" );
	if  CODI.DEBUG  then PUT( tab50 & ";---------- end PRO " & SUB_NAME); end if;
	NEW_LINE;
	PUT_LINE( "end if" );

        end		INSTANTIATION_SUBPROG_GENERIQUE;
			-------------------------------

      else
        HEADER := D( AS_HEADER, SUBPROG_ENTRY_DECL );

				---------------------
				SOUS_PROGRAMME_NORMAL:
        begin
        if  CODI.IN_GENERIC_INSTANTIATION  then
	if  CODI.DEBUG  then PUT( tab50 & "; subprog in generic");  end if;
	NEW_LINE;

        else
	declare
	  SAVE_NO_SUB_PARAM : BOOLEAN		:= CODI.NO_SUBP_PARAMS;
	begin
	  CODI.OUTPUT_CODE := FALSE;						-- ne pas coder les parametres (le body fera ca)
	  CODE_HEADER( HEADER );
	  CODI.OUTPUT_CODE := TRUE;
	  CODI.NO_SUBP_PARAMS := SAVE_NO_SUB_PARAM;
	end;
        end if;
        end		SOUS_PROGRAMME_NORMAL;
			---------------------
      end if;

    end;
    DEC_LEVEL;

    CODI.NO_SUBP_PARAMS := SAVE_NO_SUB_PARAM;
    CODI.IN_GENERIC_INSTANTIATION := SAVE_IN_GENERIC_INSTANTIATION;
    CODI.INSTANTIATION_MODEL_NAME := SAVE_INSTANTIATION_MODEL_NAME;
    CODI.OUTPUT_CODE := SAVE_OUTPUT_CODE;

   end	  CODE_SUBPROG_ENTRY_DECL;
	--=======================--



			--^^^^^^^^^^^^^^^^^--
  procedure		  CODE_PACKAGE_DECL		( PACKAGE_DECL :TREE )
  is			---------------------

    PACK_ID		: TREE			:= D( AS_SOURCE_NAME, PACKAGE_DECL );
    PACK_NAME		:constant STRING		:= PRINT_NAME( D( LX_SYMREP, PACK_ID ) );
    UNIT_KIND		: TREE			:= D( AS_UNIT_KIND, PACKAGE_DECL );
    SAVE_NO_SUB_PARAM	: BOOLEAN			:= CODI.NO_SUBP_PARAMS;
    SAVE_MODEL_SEQ		: SEQ_TYPE		:= CODI.GENERIC_MODEL_DECL_SEQ;
    CAS_NORMAL		: BOOLEAN			:= PACK_NAME /= "STANDARD" and PACK_NAME /= "_STANDRD";
    SAVE_IN_GENERIC_INSTANTIATION	: BOOLEAN := CODI.IN_GENERIC_INSTANTIATION;
    SAVE_INSTANTIATION_MODEL_NAME	: TREE	:= CODI.INSTANTIATION_MODEL_NAME;
    SAVE_OUTPUT_CODE		: BOOLEAN := CODI.OUTPUT_CODE;

  begin
    if  UNIT_KIND.TY = DN_RENAMES_UNIT  then
			--| INTENTIONNEL (recensement system.ads, 28/07) : renommage de
			--| paquetage (package X renames Y) -- ne declare RIEN : ni
			--| namespace, ni en-tete (AS_HEADER est d'ailleurs VOID).
			--| L'identite est celle de l'ORIGINE, resolue au site d'usage
			--| -- meme modele que les renames de sous-programmes
			--| (SUBPROGRAM_ORIGIN) et d'exceptions (pilier 11).  Avant
			--| cette garde : namespace _SYSTEM VIDE emis + TROU CODE_HEADER.
      return;
    end if;


    if  CAS_NORMAL  then
      PUT_LINE( PACK_NAME & " = '" & PACK_NAME & "'" );
      PUT( "namespace " & PACK_NAME );
    end if;
    if  UNIT_KIND.TY = DN_INSTANTIATION
    then
      if  CODI.DEBUG  then PUT( tab50 & ";---------- GENERIC PACKAGE INSTANTIATION" ); end if;
      NEW_LINE;

      CODI.IN_GENERIC_INSTANTIATION := TRUE;
      CODI.CLEAR_GENERIC_ACTUAL_TYPES;									-- F-4a : table de l'instanciation courante

      CODI.INSTANTIATION_MODEL_NAME := D( AS_NAME, UNIT_KIND );
      while  CODI.INSTANTIATION_MODEL_NAME.TY = DN_SELECTED  loop
        CODI.INSTANTIATION_MODEL_NAME := D( AS_DESIGNATOR, CODI.INSTANTIATION_MODEL_NAME );
      end loop;

      CODI.GENERIC_MODEL_DECL_SEQ := LIST( D( AS_DECL_S1, D( SM_SPEC, D( SM_DEFN, CODI.INSTANTIATION_MODEL_NAME ) ) ) );

      PUT( "elab_spec:" );
      if  CODI.DEBUG  then PUT_LINE( tab50 & ";    SPEC ELAB" ); end if;
      NEW_LINE;

      CODE_GENERIC_ACTUALS( UNIT_KIND );

      CODE_PACKAGE_SPEC( D( SM_SPEC, D( AS_SOURCE_NAME, PACKAGE_DECL ) ) );

      if  CODI.DEBUG  then
        PUT( tab50 & ";---------- end generic package instantiation " & PACK_NAME );
      end if;

      NEW_LINE;
      CODI.GENERIC_MODEL_DECL_SEQ := SAVE_MODEL_SEQ;
      CODI.IN_GENERIC_INSTANTIATION := FALSE;

    else
      if  CAS_NORMAL and CODI.DEBUG  then PUT( tab50 & ";---------- PACKAGE DECLARATION" ); end if;
      NEW_LINE;

      CODE_HEADER( D( AS_HEADER, PACKAGE_DECL ) );

      declare
        EXC_LBL		:constant STRING	:= NEW_LABEL;
      begin
        PUT_LINE( "; EXC_LBL" & tab & EXC_LBL );
      end;
    end if;

    if  CAS_NORMAL  then
      PUT_LINE( "end namespace" );
    end if;
    DB( CD_COMPILED, PACK_ID, TRUE );
    if  CODI.DEBUG  then  NEW_LINE; end if;

    CODI.NO_SUBP_PARAMS := SAVE_NO_SUB_PARAM;
    CODI.IN_GENERIC_INSTANTIATION := SAVE_IN_GENERIC_INSTANTIATION;
    CODI.INSTANTIATION_MODEL_NAME := SAVE_INSTANTIATION_MODEL_NAME;
    CODI.OUTPUT_CODE := SAVE_OUTPUT_CODE;

  end	  CODE_PACKAGE_DECL;
	--=================--


			---------------
  procedure		CODE_USE_PRAGMA	( USE_PRAGMA :TREE )
  is			---------------
  begin
    if  USE_PRAGMA.TY = DN_USE  then
      null;											--| INTENTIONNEL : use = visibilite, aucun code
    elsif  USE_PRAGMA.TY = DN_PRAGMA  then
      null;											--| INTENTIONNEL (partiel) : cf. CODE_STM_PRAGMA --
												--| trier ICI si un pragma declaratif devient signifiant
    else
      CODI.TROU( "CODE_USE_PRAGMA", USE_PRAGMA );								--| vague 4 : dispatch muet
    end if;

  end	CODE_USE_PRAGMA;
	---------------


			--------------------
  procedure		CODE_BORNE_SOUS_TYPE	( T :TREE; IS_LAST :BOOLEAN )
  is			--------------------
	-- Option B : empile FIRST ou LAST d'un sous-type discret (litteral
	-- d'enumeration DEFINISSANT : SM_REP, regle de STATIC_BOUND_VALUE).
    FT		: TREE	:= CODI.FULL_TYPE_VIEW( T );
    RNG		: TREE;
    E		: TREE;
  begin
    if  FT.TY = DN_INDEX  then
      FT := CODI.FULL_TYPE_VIEW( D( SM_TYPE_SPEC, FT ) );
    end if;
    RNG := D( SM_RANGE, FT );
    if  RNG.TY = DN_RANGE  then
      if  IS_LAST  then  E := D( AS_EXP2, RNG );  else  E := D( AS_EXP1, RNG );  end if;
      if  E.TY = DN_ENUMERATION_ID  or else  E.TY = DN_CHARACTER_ID  then
        PUT_LINE( tab & "LI" & tab & IMAGE( DI( SM_REP, E ) ) );
      else
        EXPRESSIONS.CODE_EXP( E );
      end if;
    else
      EXPRESSIONS.CODE_DISCRETE_RANGE_BOUND( RNG, IS_LAST );
    end if;

  end	CODE_BORNE_SOUS_TYPE;
	--------------------


			----------------------
  procedure		CODE_INIT_DESCRIPTEURS	( REC_TYPE :TREE; OBJ_LVL :LEVEL_NUM; OBJ_VAR :STRING;
						  BORNER :BOOLEAN := FALSE )
  is			----------------------
	-- Option B (claude/conception_records_discriminants.md).  L'objet a ses
	-- DISCRIMINANTS poses ; l'adresse de ses donnees (au moins la partie
	-- statique) est dans la variable de cadre OBJ_VAR du niveau OBJ_LVL.
	-- Pour chaque composant dynamique, dans l'ordre de la disposition (variantes
	-- comprises, disposition additive) : bornes evaluees avec l'objet comme
	-- OBJET RECORD COURANT, COMP_SIZ, SIZ, OFS ; puis __TAILLE.  Les donnees
	-- suivent la partie statique, chacune alignee sur 8 octets.
	-- BORNER (lot 27, calcul de la taille MAXIMALE) : un intervalle non vide est
	-- ramene dans le sous-type d'indice au lieu de lever CONSTRAINT_ERROR -- le
	-- maximum porte sur les valeurs LEGALES ; le controle reel se fait sur les
	-- discriminants effectifs de l'objet.

    BASE_REC		: TREE		:= CODI.FULL_TYPE_VIEW( REC_TYPE );
    LVL_STR		:constant STRING	:= IMAGE( CODI.CUR_LEVEL );
    OBJ_LVL_STR		:constant STRING	:= IMAGE( OBJ_LVL );
    OFS_VAR		:constant STRING	:= "__OFS" & NEW_LABEL;				-- deplacement courant (octets)
    BASE_NAME		: TREE;

		----------
    procedure	DANS_OBJET	( COMP_ID :TREE; CHAMP :NATURAL )
    is		----------
	-- sommet de pile -> champ CHAMP du descripteur de COMP_ID dans l'objet
    begin
      PUT( tab & "SID" & tab & OBJ_LVL_STR & ", " & OBJ_VAR & ", " );
      REGIONS_PATH( COMP_ID );
      PUT_LINE( PRINT_NAME( D( LX_SYMREP, COMP_ID ) ) & '+' & IMAGE( CHAMP ) );
    end	DANS_OBJET;
	----------

		-------------
    procedure	DEPUIS_OBJET	( COMP_ID :TREE; CHAMP :NATURAL )
    is		-------------
	-- champ CHAMP du descripteur de COMP_ID dans l'objet -> sommet de pile
    begin
      PUT( tab & "LID" & tab & OBJ_LVL_STR & ", " & OBJ_VAR & ", " );
      REGIONS_PATH( COMP_ID );
      PUT_LINE( PRINT_NAME( D( LX_SYMREP, COMP_ID ) ) & '+' & IMAGE( CHAMP ) );
    end	DEPUIS_OBJET;
	------------

		------------
    procedure	UN_COMPOSANT	( COMP_ID :TREE )
    is		------------
      COMP_TYPE		: TREE		:= D( SM_OBJ_TYPE, COMP_ID );
      IDX_S		: SEQ_TYPE	:= LIST( D( SM_INDEX_SUBTYPE_S, COMP_TYPE ) );
      IDX			: TREE;
      ELEM		: TREE		:= CODI.FULL_TYPE_VIEW( D( SM_COMP_TYPE, D( SM_BASE_TYPE, COMP_TYPE ) ) );
      ELEM_BITS		: INTEGER		:= CODI.STORAGE_UNIT;
    begin
      POP( IDX_S, IDX );									-- 1-dim (multi : TROU a la declaration)

      if  CODI.EST_ACCES( ELEM )  or else  ELEM.TY = DN_FLOAT  then				-- convention octet (COMP_SIZE_BITS)
        ELEM_BITS := CODI.ADDR_SIZE * CODI.STORAGE_UNIT;
      elsif  D( CD_IMPL_SIZE, ELEM ) /= TREE_VOID  then
        ELEM_BITS := ( ( DI( CD_IMPL_SIZE, ELEM ) + CODI.STORAGE_UNIT - 1 ) / CODI.STORAGE_UNIT ) * CODI.STORAGE_UNIT;
      else
        CODI.TROU( "CODE_INIT_DESCRIPTEURS element de taille non statique", ELEM );
      end if;

      if  CODI.EST_COMPOSANT_REGULIER( COMP_ID )  then
	-- Composant REGULIER : bornes elaborees UNE fois au type -- patron du
	-- sous-type nomme, ou bloc local _<comp>__type du type record.
        declare
	NOM	: TREE		:= D( XD_SOURCE_NAME, COMP_TYPE );
	NIVEAU	:constant STRING	:= IMAGE( DI( CD_LEVEL, COMP_TYPE ) );

	procedure	BORNE	( CHAMP :STRING )
	is
	begin
	  PUT( tab & "LD" & tab & NIVEAU & ", " );
	  if  NOM /= TREE_VOID  and then  ( NOM.TY = DN_SUBTYPE_ID  or else  NOM.TY = DN_TYPE_ID )
	    and then  D( SM_TYPE_SPEC, NOM ) = COMP_TYPE
	  then
	    REGIONS_PATH( NOM );
	    PUT_LINE( '_' & PRINT_NAME( D( LX_SYMREP, NOM ) ) & "." & CHAMP );
	  else
	    declare
	      R	: TREE	:= BASE_REC;
	    begin
	      while  R.TY = DN_CONSTRAINED_RECORD  loop
	        R := CODI.FULL_TYPE_VIEW( D( SM_BASE_TYPE, R ) );
	      end loop;
	      REGIONS_PATH( D( XD_SOURCE_NAME, R ) );
	      PUT_LINE( '_' & PRINT_NAME( D( LX_SYMREP, D( XD_SOURCE_NAME, R ) ) ) & "._"
		        & PRINT_NAME( D( LX_SYMREP, COMP_ID ) ) & "__type." & CHAMP );
	    end;
	  end if;
	end	BORNE;

        begin
	BORNE( "_FST_1" );
	DANS_OBJET( COMP_ID, CODI.DESC_FST_1 );
	BORNE( "_LST_1" );
	DANS_OBJET( COMP_ID, CODI.DESC_LST_1 );
        end;
      else
      -- FST_1, LST_1 : bornes evaluees dans l'objet courant
      EXPRESSIONS.CODE_DISCRETE_RANGE_BOUND( D( SM_RANGE, IDX ), IS_LAST => FALSE );
      DANS_OBJET( COMP_ID, CODI.DESC_FST_1 );
      EXPRESSIONS.CODE_DISCRETE_RANGE_BOUND( D( SM_RANGE, IDX ), IS_LAST => TRUE );
      DANS_OBJET( COMP_ID, CODI.DESC_LST_1 );
      end if;

      -- LRM 3.6.1 : intervalle NON VIDE -> bornes dans le sous-type d'indice
      -- du type tableau de base, sinon CONSTRAINT_ERROR
      if  BORNER  then
        declare
	VIDE	:constant STRING	:= LABEL_STR( NEW_LABEL );
	OK_F	:constant STRING	:= LABEL_STR( NEW_LABEL );
	OK_L	:constant STRING	:= LABEL_STR( NEW_LABEL );
	IDX_B_S	: SEQ_TYPE	:= LIST( D( SM_INDEX_S, CODI.FULL_TYPE_VIEW( D( SM_BASE_TYPE, COMP_TYPE ) ) ) );
	IDX_B	: TREE;
        begin
	POP( IDX_B_S, IDX_B );
	DEPUIS_OBJET( COMP_ID, CODI.DESC_LST_1 );
	DEPUIS_OBJET( COMP_ID, CODI.DESC_FST_1 );
	PUT_LINE( tab & "CLT" );							-- LST < FST : vide
	PUT_LINE( tab & "BT" & tab & VIDE );
	DEPUIS_OBJET( COMP_ID, CODI.DESC_FST_1 );
	CODE_BORNE_SOUS_TYPE( IDX_B, IS_LAST => FALSE );
	PUT_LINE( tab & "CLT" );
	PUT_LINE( tab & "BF" & tab & OK_F );
	CODE_BORNE_SOUS_TYPE( IDX_B, IS_LAST => FALSE );				-- FST := INDEX'FIRST
	DANS_OBJET( COMP_ID, CODI.DESC_FST_1 );
	PUT_LINE( OK_F & ':' );
	DEPUIS_OBJET( COMP_ID, CODI.DESC_LST_1 );
	CODE_BORNE_SOUS_TYPE( IDX_B, IS_LAST => TRUE );
	PUT_LINE( tab & "CGT" );
	PUT_LINE( tab & "BF" & tab & OK_L );
	CODE_BORNE_SOUS_TYPE( IDX_B, IS_LAST => TRUE );				-- LST := INDEX'LAST
	DANS_OBJET( COMP_ID, CODI.DESC_LST_1 );
	PUT_LINE( OK_L & ':' );
	PUT_LINE( VIDE & ':' );
        end;

      elsif  CODI.CHECKS_ENABLED  then
        declare
	VIDE	:constant STRING	:= LABEL_STR( NEW_LABEL );
	IDX_B_S	: SEQ_TYPE	:= LIST( D( SM_INDEX_S, CODI.FULL_TYPE_VIEW( D( SM_BASE_TYPE, COMP_TYPE ) ) ) );
	IDX_B	: TREE;
        begin
	POP( IDX_B_S, IDX_B );
	DEPUIS_OBJET( COMP_ID, CODI.DESC_LST_1 );
	DEPUIS_OBJET( COMP_ID, CODI.DESC_FST_1 );
	PUT_LINE( tab & "CLT" );							-- LST < FST : vide
	PUT_LINE( tab & "BT" & tab & VIDE );
	DEPUIS_OBJET( COMP_ID, CODI.DESC_FST_1 );
	CODE_BORNE_SOUS_TYPE( IDX_B, IS_LAST => FALSE );
	PUT_LINE( tab & "CLT" );
	PUT_LINE( tab & "BT" & tab & "STANDARD.ce_raise_" );
	DEPUIS_OBJET( COMP_ID, CODI.DESC_LST_1 );
	CODE_BORNE_SOUS_TYPE( IDX_B, IS_LAST => TRUE );
	PUT_LINE( tab & "CGT" );
	PUT_LINE( tab & "BT" & tab & "STANDARD.ce_raise_" );
	PUT_LINE( VIDE & ':' );
        end;
      end if;

      -- COMP_SIZ (bits)
      PUT_LINE( tab & "LI" & tab & IMAGE( ELEM_BITS ) );
      DANS_OBJET( COMP_ID, CODI.DESC_COMP_SIZ );

      -- COUNT = LST - FST + 1 (>= 0) ; SIZ = COUNT * COMP_SIZ (bits)
      DEPUIS_OBJET( COMP_ID, CODI.DESC_LST_1 );
      DEPUIS_OBJET( COMP_ID, CODI.DESC_FST_1 );
      PUT_LINE( tab & "SUB" );
      PUT_LINE( tab & "INC" );
      PUT_LINE( tab & "CLAMP0" );
      PUT_LINE( tab & "DUP" );
      PUT_LINE( tab & "LI" & tab & IMAGE( ELEM_BITS ) );
      PUT_LINE( tab & "MUL" );
      DANS_OBJET( COMP_ID, CODI.DESC_SIZ );

      -- OFS = deplacement courant
      PUT_LINE( tab & "LD" & tab & LVL_STR & ", " & OFS_VAR );
      DANS_OBJET( COMP_ID, CODI.DESC_OFS );

      -- deplacement courant += aligne8( COUNT * octets par element )
      -- (au-dela de LIMITE_COMPOSANT : STORAGE_ERROR, LRM 11.1 -- calcul en
      -- 64 bits, avant toute troncature des champs D)
      PUT_LINE( tab & "LI" & tab & IMAGE( ELEM_BITS / CODI.STORAGE_UNIT ) );
      PUT_LINE( tab & "MUL" );
      declare
        OK_LBL	:constant STRING	:= LABEL_STR( NEW_LABEL );
      begin
        PUT_LINE( tab & "DUP" );
        PUT_LINE( tab & "LI" & tab & IMAGE( CODI.LIMITE_COMPOSANT ) );
        PUT_LINE( tab & "CGT" );
        PUT_LINE( tab & "BF" & tab & OK_LBL );
        PUT_LINE( tab & "LCA" & tab & "STANDARD.STORAGE_ERROR__exc.data_ptr" );
        PUT_LINE( tab & "SA" & tab & "0, STANDARD.EXCEPTIONS_CURRENT_disp" );
        PUT_LINE( tab & "BRA" & tab & "STANDARD.exc_raise_" );
        PUT_LINE( OK_LBL & ':' );
      end;
      PUT_LINE( tab & "LI" & tab & "7" );
      PUT_LINE( tab & "ADD" );
      PUT_LINE( tab & "LI" & tab & "-8" );
      PUT_LINE( tab & "ET" );
      PUT_LINE( tab & "LD" & tab & LVL_STR & ", " & OFS_VAR );
      PUT_LINE( tab & "ADD" );
      PUT_LINE( tab & "SD" & tab & LVL_STR & ", " & OFS_VAR );
    end	UN_COMPOSANT;
	------------

		-----------
    procedure	PARCOURIR	( CL :TREE )
    is		-----------
      DECL_S	: SEQ_TYPE;
      DECL	: TREE;
      ID_S	: SEQ_TYPE;
      ID		: TREE;
      VP		: TREE;
      VAR_S	: SEQ_TYPE;
      VAR_E	: TREE;
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
	  if  CODI.EST_COMPOSANT_DYNAMIQUE( ID )  then
	    UN_COMPOSANT( ID );
	  end if;
	end loop;
        end if;
      end loop;

      VP := D( AS_VARIANT_PART, CL );
      if  VP /= TREE_VOID  and then  VP /= TREE_NIL  then
        VAR_S := LIST( D( AS_VARIANT_S, VP ) );
        while  not IS_EMPTY( VAR_S )  loop
	POP( VAR_S, VAR_E );
	if  VAR_E.TY = DN_VARIANT  then
	  PARCOURIR( D( AS_COMP_LIST, VAR_E ) );
	end if;
        end loop;
      end if;
    end	PARCOURIR;
	---------

  begin
    if  BASE_REC.TY = DN_CONSTRAINED_RECORD  then
      BASE_REC := CODI.FULL_TYPE_VIEW( D( SM_BASE_TYPE, BASE_REC ) );
    end if;
    BASE_NAME := D( XD_SOURCE_NAME, BASE_REC );

    -- donnees : apres la partie statique, alignees sur 8
    PUT_LINE( "VAR " & OFS_VAR & ", D" );
    PUT( tab & "LI" & tab & "((" );
    REGIONS_PATH( BASE_NAME );
    PUT_LINE( TYPE_INFO_STR( BASE_REC ) & ".size+7)/8*8)" );
    PUT_LINE( tab & "SD" & tab & LVL_STR & ", " & OFS_VAR );

    CODI.POSER_REC_COURANT( OBJ_LVL, OBJ_VAR );
    PARCOURIR( D( SM_COMP_LIST, BASE_REC ) );
    CODI.OTER_REC_COURANT;

    -- __TAILLE = fin du dernier composant dynamique
    PUT_LINE( tab & "LD" & tab & LVL_STR & ", " & OFS_VAR );
    PUT( tab & "SID" & tab & OBJ_LVL_STR & ", " & OBJ_VAR & ", " );
    REGIONS_PATH( BASE_NAME );
    PUT_LINE( TYPE_INFO_STR( BASE_REC ) & ".__TAILLE" );

  end	CODE_INIT_DESCRIPTEURS;
	----------------------


			---------------
  procedure		CODE_TAILLE_MAX	( REC_TYPE :TREE;  MAX_VAR :STRING )
  is			---------------
	-- Option B, taille MAXIMALE d'un objet NON CONTRAINT d'un type a discriminants
	-- par defaut : MAX_VAR (cellule D du cadre courant, declaree ici) := max du
	-- __TAILLE sur les combinaisons des bornes FIRST/LAST des sous-types de
	-- discriminants, posees dans une partie statique temporaire.  Les bornes
	-- des composants sont ramenees dans leur sous-type d'indice (BORNER) : aucun
	-- controle ici (lot 27) -- il revient aux discriminants effectifs de l'objet.
	-- Sortie de CODE_OBJET_DYNAMIQUE (etape 3) pour servir aussi au pas d'un
	-- tableau de records mutables, elabore avec le TYPE tableau.
    BASE_REC	: TREE		:= CODI.FULL_TYPE_VIEW( REC_TYPE );
    BASE_NAME	: TREE;
    LVL_STR	:constant STRING	:= IMAGE( CODI.CUR_LEVEL );
    TMP		:constant STRING	:= "__TMX" & NEW_LABEL;
    DISCRS	: array ( 1 .. 4 ) of TREE;
    NB		: NATURAL		:= 0;
    DECL_S2	: SEQ_TYPE;
    DECL2	: TREE;
    ID_S2	: SEQ_TYPE;
    ID2		: TREE;
    COMBI	: NATURAL;
    NB_COMB	: NATURAL		:= 1;							-- 2 ** NB (sans "**" : TLALOC refuse 0 .. 2 ** NB - 1)

		-----------
    procedure	BORNE_DISCR	( DISCR :TREE; IS_LAST :BOOLEAN )
    is		-----------
	-- empile FIRST ou LAST du sous-type du discriminant
    begin
      CODE_BORNE_SOUS_TYPE( D( SM_OBJ_TYPE, DISCR ), IS_LAST );
    end	BORNE_DISCR;
	-----------

  begin
    if  BASE_REC.TY = DN_CONSTRAINED_RECORD  then
      BASE_REC := CODI.FULL_TYPE_VIEW( D( SM_BASE_TYPE, BASE_REC ) );
    end if;
    BASE_NAME := D( XD_SOURCE_NAME, BASE_REC );
    PUT( "VAR " & TMP & "__dat, " );								-- partie statique temporaire
    REGIONS_PATH( BASE_NAME );
    PUT_LINE( TYPE_INFO_STR( BASE_REC ) & ".size" );
    PUT_LINE( "VAR " & TMP & "_disp, Q" );
    PUT_LINE( tab & "LVA" & tab & LVL_STR & ", " & TMP & "__dat" );
    PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & TMP & "_disp" );
    DECL_S2 := LIST( D( SM_DISCRIMINANT_S, BASE_REC ) );
    while  not IS_EMPTY( DECL_S2 )  loop
      POP( DECL_S2, DECL2 );
      ID_S2 := LIST( D( AS_SOURCE_NAME_S, DECL2 ) );
      while  not IS_EMPTY( ID_S2 )  loop
	POP( ID_S2, ID2 );
	if  NB = DISCRS'LAST  then
	  CODI.TROU( "CODE_OBJET_DYNAMIQUE taille max : plus de 4 discriminants", ID2 );
	else
	  NB := NB + 1;
	  DISCRS( NB ) := ID2;
	end if;
      end loop;
    end loop;

    PUT_LINE( "VAR " & MAX_VAR & ", D" );
    PUT_LINE( tab & "LI" & tab & "0" );
    PUT_LINE( tab & "SD" & tab & LVL_STR & ", " & MAX_VAR );
    for  I in 1 .. NB  loop
      NB_COMB := NB_COMB * 2;
    end loop;
    for  C in NATURAL range 0 .. NB_COMB - 1  loop
      COMBI := C;
      for  I in 1 .. NB  loop
	BORNE_DISCR( DISCRS( I ), IS_LAST => COMBI mod 2 = 1 );
	COMBI := COMBI / 2;
	PUT( tab & "SI" & CODI.OPER_SIZ_CHAR( D( SM_OBJ_TYPE, DISCRS( I ) ) ) & tab & LVL_STR & ", " & TMP & "_disp, " );
	REGIONS_PATH( DISCRS( I ) );
	PUT_LINE( PRINT_NAME( D( LX_SYMREP, DISCRS( I ) ) ) );
      end loop;
      CODE_INIT_DESCRIPTEURS( BASE_REC, CODI.CUR_LEVEL, TMP & "_disp", BORNER => TRUE );
      declare
	SKIP	:constant STRING	:= LABEL_STR( NEW_LABEL );
      begin
	PUT( tab & "LID" & tab & LVL_STR & ", " & TMP & "_disp, " );
	REGIONS_PATH( BASE_NAME );
	PUT_LINE( TYPE_INFO_STR( BASE_REC ) & ".__TAILLE" );
	PUT_LINE( tab & "LD" & tab & LVL_STR & ", " & MAX_VAR );
	PUT_LINE( tab & "CGT" );
	PUT_LINE( tab & "BF" & tab & SKIP );
	PUT( tab & "LID" & tab & LVL_STR & ", " & TMP & "_disp, " );
	REGIONS_PATH( BASE_NAME );
	PUT_LINE( TYPE_INFO_STR( BASE_REC ) & ".__TAILLE" );
	PUT_LINE( tab & "SD" & tab & LVL_STR & ", " & MAX_VAR );
	PUT_LINE( SKIP & ':' );
      end;
    end loop;
  end	CODE_TAILLE_MAX;
	---------------


			--------------------
  procedure		CODE_OBJET_DYNAMIQUE	( REC_TYPE :TREE; DSCRMT_EXP_S :SEQ_TYPE; SUR_LE_TAS :BOOLEAN;
						  MUTABLE :BOOLEAN := FALSE )
  is			--------------------
	-- Option B.  Fabrique un objet record dynamique NEUF et laisse son adresse :
	--   1. partie statique temporaire dans le cadre ;
	--   2. discriminants : les premieres expressions de DSCRMT_EXP_S, dans
	--      l'ordre des discriminants (SM_NORMALIZED_DSCRMT_S d'une vue
	--      contrainte, ou SM_NORMALIZED_COMP_S d'un agregat : discriminants en tete) ;
	--      liste VIDE : valeurs par defaut des discriminants ;
	--   3. CODE_INIT_DESCRIPTEURS ;
	--   4. bloc de __TAILLE octets (co-pile, ou tas pour un allocateur) et copie
	--      de la partie statique.
	-- MUTABLE (objet NON CONTRAINT, etape 3) : avant tout, taille MAXIMALE --
	-- descripteurs evalues pour chaque combinaison des bornes FIRST/LAST des
	-- sous-types de discriminants (bornes de composants supposees monotones),
	-- plus grand __TAILLE garde ; le bloc a cette taille ; __MUTABLE = 1.
	-- Les autres composants restent a remplir (agregat, valeurs par defaut).

    BASE_REC		: TREE		:= CODI.FULL_TYPE_VIEW( REC_TYPE );
    LVL_STR		:constant STRING	:= IMAGE( CODI.CUR_LEVEL );
    TMP			:constant STRING	:= "__DYN" & NEW_LABEL;
    BASE_NAME		: TREE;
    EXPS		: SEQ_TYPE	:= DSCRMT_EXP_S;
    DSCRMT_DECL_S		: SEQ_TYPE;
    DSCRMT_DECL		: TREE;
    ID_S		: SEQ_TYPE;
    DISCR_ID		: TREE;
    EXP			: TREE;
    MAX_VAR		:constant STRING	:= "__MAX" & NEW_LABEL;


  begin
    if  BASE_REC.TY = DN_CONSTRAINED_RECORD  then
      BASE_REC := CODI.FULL_TYPE_VIEW( D( SM_BASE_TYPE, BASE_REC ) );
    end if;
    BASE_NAME := D( XD_SOURCE_NAME, BASE_REC );

    -- 1. partie statique temporaire
    PUT( "VAR " & TMP & "__dat, " );
    REGIONS_PATH( BASE_NAME );
    PUT_LINE( TYPE_INFO_STR( BASE_REC ) & ".size" );
    PUT_LINE( "VAR " & TMP & "_disp, Q" );
    PUT_LINE( tab & "LVA" & tab & LVL_STR & ", " & TMP & "__dat" );
    PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & TMP & "_disp" );

    if  MUTABLE  then
      CODE_TAILLE_MAX( BASE_REC, MAX_VAR );							--| lot 27 : procedure partagee
    end if;

    -- 2. discriminants
    DSCRMT_DECL_S := LIST( D( SM_DISCRIMINANT_S, BASE_REC ) );
    while  not IS_EMPTY( DSCRMT_DECL_S )  loop
      POP( DSCRMT_DECL_S, DSCRMT_DECL );
      ID_S := LIST( D( AS_SOURCE_NAME_S, DSCRMT_DECL ) );
      while  not IS_EMPTY( ID_S )  loop
        POP( ID_S, DISCR_ID );
        if  IS_EMPTY( EXPS )  then									-- liste vide : valeurs par DEFAUT
	EXP := D( SM_INIT_EXP, DISCR_ID );								-- (new R : objet alloue contraint
	if  EXP = TREE_VOID  or else  EXP = TREE_NIL  then						--  par ses defauts, LRM 4.8)
	  CODI.TROU( "CODE_OBJET_DYNAMIQUE discriminant sans valeur", DISCR_ID );
	end if;
        else
	POP( EXPS, EXP );
        end if;
        EXPRESSIONS.CODE_VALEUR_DISCRIMINANT( REC_TYPE, TREE_VOID, DISCR_ID, EXP );			-- valeur elaboree, ou l'expression
        PUT( tab & "SI" & CODI.OPER_SIZ_CHAR( D( SM_OBJ_TYPE, DISCR_ID ) ) & tab & LVL_STR & ", " & TMP & "_disp, " );
        REGIONS_PATH( DISCR_ID );
        PUT_LINE( PRINT_NAME( D( LX_SYMREP, DISCR_ID ) ) );
      end loop;
    end loop;

    -- 3. descripteurs, __TAILLE, __MUTABLE
    CODE_INIT_DESCRIPTEURS( BASE_REC, CODI.CUR_LEVEL, TMP & "_disp" );
    if  MUTABLE  then
      PUT_LINE( tab & "LI" & tab & "1" );
    else
      PUT_LINE( tab & "LI" & tab & "0" );
    end if;
    PUT( tab & "SID" & tab & LVL_STR & ", " & TMP & "_disp, " );
    REGIONS_PATH( BASE_NAME );
    PUT_LINE( TYPE_INFO_STR( BASE_REC ) & ".__MUTABLE" );

    -- 4. bloc (__TAILLE, ou maximum si MUTABLE) et copie de la partie statique
    if  MUTABLE  then
      PUT_LINE( tab & "LD" & tab & LVL_STR & ", " & MAX_VAR );
    else
      PUT( tab & "LID" & tab & LVL_STR & ", " & TMP & "_disp, " );
      REGIONS_PATH( BASE_NAME );
      PUT_LINE( TYPE_INFO_STR( BASE_REC ) & ".__TAILLE" );
    end if;
    if  SUR_LE_TAS  then
      PUT_LINE( tab & "HEAP_ALLOC" );
    else
      PUT_LINE( tab & "CO_VAR" );
    end if;
    PUT_LINE( tab & "DUP" );									-- @DST (reste : @objet)
    PUT( tab & "LI" & tab );
    REGIONS_PATH( BASE_NAME );
    PUT_LINE( TYPE_INFO_STR( BASE_REC ) & ".size" );						-- LEN
    PUT_LINE( tab & "LVA" & tab & LVL_STR & ", " & TMP & "__dat" );				-- @SRC
    PUT_LINE( tab & "BLKMOV" );

  end	CODE_OBJET_DYNAMIQUE;
	--------------------


			---------------
  function		ELEMENT_TABLEAU	( T :TREE )		return TREE
  is			---------------
	-- Lot 27 : vue complete du type des composants d'un type tableau.
    TS		: TREE		:= FULL_TYPE_VIEW( T );
  begin
    if  TS.TY = DN_CONSTRAINED_ARRAY  then
      TS := FULL_TYPE_VIEW( D( SM_BASE_TYPE, TS ) );
    end if;
    if  TS.TY /= DN_ARRAY  then
      return TREE_VOID;
    end if;
    return  FULL_TYPE_VIEW( D( SM_COMP_TYPE, TS ) );
  end	ELEMENT_TABLEAU;
	---------------


			---------------------
  function		EST_TABLEAU_DYNAMIQUE	( T :TREE )		return BOOLEAN
  is			---------------------
	-- Lot 27 : tableau dont les composants sont des records dynamiques (option B).
    E		: TREE		:= ELEMENT_TABLEAU( T );
  begin
    return  E /= TREE_VOID
	and then  ( E.TY = DN_RECORD  or else  E.TY = DN_CONSTRAINED_RECORD )
	and then  EST_RECORD_DYNAMIQUE( E );
  end	EST_TABLEAU_DYNAMIQUE;
	---------------------


			--------------
  function		TAILLE_STATIQUE	( T :TREE )		return NATURAL
  is			--------------
	-- Lot 26 : taille statique en octets d'un tableau contraint ou d'un record
	-- (CD_IMPL_SIZE arrondi a l'octet, comme le pas des tableaux de
	-- DECLARATIONS.TYPES_DECLS), 0 si elle n'est pas connue.
    TS		: TREE		:= FULL_TYPE_VIEW( T );
  begin
    if  TS.TY = DN_CONSTRAINED_RECORD  then
      TS := FULL_TYPE_VIEW( D( SM_BASE_TYPE, TS ) );
    end if;
    if  D( CD_IMPL_SIZE, TS ) = TREE_VOID  or else  D( CD_IMPL_SIZE, TS ) = TREE_NIL
      or else  DI( CD_IMPL_SIZE, TS ) <= 0
    then
      return 0;
    end if;
    return  NATURAL( ( DI( CD_IMPL_SIZE, TS ) + STORAGE_UNIT - 1 ) / STORAGE_UNIT );
  end	TAILLE_STATIQUE;
	--------------


			---------------------
  function		A_INIT_IMPLICITE_TYPE	( T :TREE )		return BOOLEAN
  is			---------------------
	-- Lot 26 : vrai si un objet du type T (record ou tableau contraint) recoit des
	-- valeurs implicites (LRM 3.2.1) : record contraint (discriminants a poser),
	-- record a discriminants par defaut ou a composants par defaut, tableau
	-- contraint dont les composants en recoivent.  Records dynamiques : seulement
	-- les discriminants d'un record contraint, et pas comme composants de tableau.
    TS		: TREE		:= FULL_TYPE_VIEW( T );
    BASE		: TREE;
    ELEM		: TREE;
  begin
    if  TS.TY = DN_RECORD  or else  TS.TY = DN_CONSTRAINED_RECORD  then
      BASE := TS;
      if  TS.TY = DN_CONSTRAINED_RECORD  then
        BASE := FULL_TYPE_VIEW( D( SM_BASE_TYPE, TS ) );
      end if;
      if  BASE.TY /= DN_RECORD  or else  REPRESENTED_ITEMS.HAS_RECORD_REP( BASE )  then
        return FALSE;
      end if;
      if  TS.TY = DN_CONSTRAINED_RECORD  then
        return TRUE;
      end if;
      return  not EST_RECORD_DYNAMIQUE( BASE )
	and then  ( not IS_EMPTY( LIST( D( SM_DISCRIMINANT_S, BASE ) ) )  or else  A_INIT_IMPLICITE( BASE ) );

    elsif  TS.TY = DN_CONSTRAINED_ARRAY  then
      BASE := FULL_TYPE_VIEW( D( SM_BASE_TYPE, TS ) );
      ELEM := FULL_TYPE_VIEW( D( SM_COMP_TYPE, BASE ) );
      if  ELEM.TY = DN_RECORD  or else  ELEM.TY = DN_CONSTRAINED_RECORD  then
        if  ELEM.TY = DN_CONSTRAINED_RECORD
          and then  FULL_TYPE_VIEW( D( SM_BASE_TYPE, ELEM ) ).TY = DN_RECORD
        then
	if  EST_RECORD_DYNAMIQUE( FULL_TYPE_VIEW( D( SM_BASE_TYPE, ELEM ) ) )  then
	  return FALSE;
	end if;
        elsif  ELEM.TY = DN_RECORD  and then  EST_RECORD_DYNAMIQUE( ELEM )  then
	return FALSE;
        end if;
        return  A_INIT_IMPLICITE_TYPE( ELEM );
      elsif  ELEM.TY = DN_CONSTRAINED_ARRAY  then
        return  TAILLE_STATIQUE( ELEM ) > 0  and then  A_INIT_IMPLICITE_TYPE( ELEM );
      end if;
    end if;
    return FALSE;
  end	A_INIT_IMPLICITE_TYPE;
	---------------------


			-------------
  procedure		INIT_RECORD_A	( REC_TYPE :TREE;  OBJ_VAR :STRING )
  is			-------------
	-- Lot 26 : record (composant d'un record ou d'un tableau) dont l'adresse est dans
	-- OBJ_VAR : ses discriminants -- ceux de la contrainte (LRM 3.7.2), evalues avec
	-- l'objet courant de l'appelant, ou ses defauts (LRM 3.7.1) -- controles contre
	-- leur sous-type, puis ses propres valeurs implicites (CODE_INIT_IMPLICITE).
    LVL_STR	:constant STRING	:= IMAGE( CODI.CUR_LEVEL );
    C_TYPE	: TREE		:= FULL_TYPE_VIEW( REC_TYPE );
    C_BASE	: TREE		:= C_TYPE;
    C_EXP_S	: SEQ_TYPE	:= ( TREE_NIL, TREE_NIL );
    CONTRAINT	: BOOLEAN		:= C_TYPE.TY = DN_CONSTRAINED_RECORD;
    C_EXP		: TREE;
    C_DECL_S	: SEQ_TYPE;
    C_DECL	: TREE;
  begin
    if  CONTRAINT  then
      C_BASE  := FULL_TYPE_VIEW( D( SM_BASE_TYPE, C_TYPE ) );
      C_EXP_S := LIST( D( SM_NORMALIZED_DSCRMT_S, C_TYPE ) );
    end if;
    if  C_BASE.TY /= DN_RECORD  or else  REPRESENTED_ITEMS.HAS_RECORD_REP( C_BASE )
      or else  not ( CONTRAINT  or else  not EST_RECORD_DYNAMIQUE( C_BASE ) )
    then
      return;
    end if;
    C_DECL_S := LIST( D( SM_DISCRIMINANT_S, C_BASE ) );
    while  not IS_EMPTY( C_DECL_S )  loop
      POP( C_DECL_S, C_DECL );
      declare
        C_ID_S	: SEQ_TYPE	:= LIST( D( AS_SOURCE_NAME_S, C_DECL ) );
        C_ID	: TREE;
      begin
        while  not IS_EMPTY( C_ID_S )  loop
	POP( C_ID_S, C_ID );
	C_EXP := TREE_VOID;
	if  CONTRAINT  then
	  if  not IS_EMPTY( C_EXP_S )  then  POP( C_EXP_S, C_EXP );  end if;
	else
	  C_EXP := D( SM_INIT_EXP, C_ID );							-- defaut (3.7.1)
	end if;
	if  C_EXP /= TREE_VOID  and then  C_EXP /= TREE_NIL  then
	  PUT_LINE( tab & "LA  " & LVL_STR & ", " & OBJ_VAR );					-- @record
	  PUT( tab & "LI" & tab );								-- + deplacement du discriminant
	  REGIONS_PATH( D( XD_SOURCE_NAME, C_BASE ) );
	  PUT_LINE( '_' & PRINT_NAME( D( LX_SYMREP, D( XD_SOURCE_NAME, C_BASE ) ) )
		& "." & PRINT_NAME( D( LX_SYMREP, C_ID ) ) );
	  PUT_LINE( tab & "ADD" );
	  EXPRESSIONS.CODE_VALEUR_DISCRIMINANT( C_TYPE, TREE_VOID, C_ID, C_EXP );		-- valeur elaboree d'un sous-type nomme
	  EXPRESSIONS.CODE_RANGE_CHECK( FULL_TYPE_VIEW( D( SM_OBJ_TYPE, C_ID ) ) );
	  PUT_LINE( tab & "S" & OPER_SIZ_CHAR( D( SM_OBJ_TYPE, C_ID ) ) );
	end if;
        end loop;
      end;
    end loop;

    if  not EST_RECORD_DYNAMIQUE( C_BASE )  and then  A_INIT_IMPLICITE( C_BASE )  then
      CODE_INIT_IMPLICITE( C_TYPE, OBJ_VAR );
    end if;
  end	INIT_RECORD_A;
	-------------


			---------------------------
  procedure		CODE_INIT_IMPLICITE_TABLEAU	( ARR_TYPE :TREE;  DATA_VAR, LEN_VAR :STRING;
							  PAS_VAR, GAB_VAR :STRING := "" )
  is			---------------------------
	-- Lot 26 (LRM 3.2.1) : valeurs implicites des composants d'un tableau contraint
	-- dont l'adresse des donnees est dans DATA_VAR et la longueur en octets dans
	-- LEN_VAR (variables de cadre du niveau courant).  Boucle a l'execution sur
	-- les composants, au pas de leur taille (celui de TYPES_DECLS : CD_IMPL_SIZE
	-- arrondi a l'octet, ou <record>.size) : record -> INIT_RECORD_A ; tableau
	-- contraint de taille statique -> recursion.
	-- Lot 27, composants records DYNAMIQUES : GAB_VAR contient l'adresse d'un
	-- gabarit (objet auto-relatif, discriminants et descripteurs poses) et
	-- PAS_VAR le pas en octets ; chaque composant en recoit une copie (BLKMOV
	-- du pas entier), puis ses valeurs implicites.
    LVL_STR	:constant STRING	:= IMAGE( CODI.CUR_LEVEL );
    TS		: TREE		:= FULL_TYPE_VIEW( ARR_TYPE );
    ELEM		: TREE		:= FULL_TYPE_VIEW( D( SM_COMP_TYPE, FULL_TYPE_VIEW( D( SM_BASE_TYPE, TS ) ) ) );
    CUR		:constant STRING	:= "__INT" & NEW_LABEL;
    FIN		:constant STRING	:= CUR & "_F";
    BOUCLE	:constant STRING	:= NEW_LABEL;
    SORTIE	:constant STRING	:= NEW_LABEL;
  begin
    if  GAB_VAR = ""  and then  not A_INIT_IMPLICITE_TYPE( TS )  then
      return;
    end if;
    PUT_LINE( "VAR " & CUR & ", Q" );								-- @composant courant
    PUT_LINE( "VAR " & FIN & ", Q" );								-- @fin des donnees
    PUT_LINE( tab & "LA  " & LVL_STR & ", " & DATA_VAR );
    PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & CUR );
    PUT_LINE( tab & "LA  " & LVL_STR & ", " & DATA_VAR );
    PUT_LINE( tab & "LA  " & LVL_STR & ", " & LEN_VAR );
    PUT_LINE( tab & "ADD" );
    PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & FIN );
    PUT_LINE( BOUCLE & ':' );
    PUT_LINE( tab & "LA  " & LVL_STR & ", " & CUR );
    PUT_LINE( tab & "LA  " & LVL_STR & ", " & FIN );
    PUT_LINE( tab & "CLT" );
    PUT_LINE( tab & "BF" & tab & SORTIE );

    if  GAB_VAR /= ""  then
      PUT_LINE( tab & "LA  " & LVL_STR & ", " & CUR );						-- @DST
      PUT_LINE( tab & "LA  " & LVL_STR & ", " & PAS_VAR );					-- LEN
      PUT_LINE( tab & "LA  " & LVL_STR & ", " & GAB_VAR );					-- @SRC
      PUT_LINE( tab & "BLKMOV" );
      if  A_INIT_IMPLICITE( ELEM )  then
        CODE_INIT_IMPLICITE( ELEM, CUR );
      end if;
    elsif  ELEM.TY = DN_CONSTRAINED_ARRAY  then
      declare
        E_LEN	:constant STRING	:= CUR & "_L";
      begin
        PUT_LINE( "VAR " & E_LEN & ", Q" );
        PUT_LINE( tab & "LI" & tab & IMAGE( TAILLE_STATIQUE( ELEM ) ) );
        PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & E_LEN );
        CODE_INIT_IMPLICITE_TABLEAU( ELEM, CUR, E_LEN );
      end;
    else
      INIT_RECORD_A( ELEM, CUR );
    end if;

    PUT_LINE( tab & "LA  " & LVL_STR & ", " & CUR );						-- composant suivant
    if  PAS_VAR /= ""  then
      PUT_LINE( tab & "LA  " & LVL_STR & ", " & PAS_VAR );
    elsif  TAILLE_STATIQUE( ELEM ) > 0  then
      PUT_LINE( tab & "LI" & tab & IMAGE( TAILLE_STATIQUE( ELEM ) ) );
    else
      declare
        E_BASE	: TREE		:= ELEM;
      begin
        if  E_BASE.TY = DN_CONSTRAINED_RECORD  then
	E_BASE := FULL_TYPE_VIEW( D( SM_BASE_TYPE, E_BASE ) );
        end if;
        PUT( tab & "LI" & tab );								-- taille symbolique (TYPES_DECLS)
        REGIONS_PATH( D( XD_SOURCE_NAME, E_BASE ) );
        PUT_LINE( '_' & PRINT_NAME( D( LX_SYMREP, D( XD_SOURCE_NAME, E_BASE ) ) ) & ".size" );
      end;
    end if;
    PUT_LINE( tab & "ADD" );
    PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & CUR );
    PUT_LINE( tab & "BRA" & tab & BOUCLE );
    PUT_LINE( SORTIE & ':' );
  end	CODE_INIT_IMPLICITE_TABLEAU;
	---------------------------

			----------------
  function		A_INIT_IMPLICITE	( REC_TYPE :TREE )		return BOOLEAN
  is			----------------
	-- Lot 25 : vrai si un objet du type record REC_TYPE recoit une valeur implicite
	-- (LRM 3.2.1) dans un composant, variantes comprises : valeur par defaut, ou
	-- composant record dont les discriminants sont a poser ou qui en recoit lui-meme.
    BASE		: TREE		:= FULL_TYPE_VIEW( REC_TYPE );

		-----------
    function	LISTE_A_INIT	( CL :TREE )		return BOOLEAN
    is		-----------
      L_S	: SEQ_TYPE;
      L_D	: TREE;
      VP	: TREE;
      V_S	: SEQ_TYPE;
      V_E	: TREE;
    begin
      if  CL = TREE_VOID  or else  CL = TREE_NIL  then
        return FALSE;
      end if;
      L_S := LIST( D( AS_DECL_S, CL ) );
      while  not IS_EMPTY( L_S )  loop
        POP( L_S, L_D );
        if  L_D.TY /= DN_NULL_COMP_DECL  then
	declare
	  I_S	: SEQ_TYPE	:= LIST( D( AS_SOURCE_NAME_S, L_D ) );
	  I	: TREE;
	  CT	: TREE;
	begin
	  while  not IS_EMPTY( I_S )  loop
	    POP( I_S, I );
	    if  D( SM_INIT_EXP, I ) /= TREE_VOID  then
	      return TRUE;
	    end if;
	    CT := FULL_TYPE_VIEW( D( SM_OBJ_TYPE, I ) );
	    if  ( CT.TY = DN_CONSTRAINED_RECORD  or else  CT.TY = DN_RECORD			-- lot 26 : meme critere qu'INIT_UN
	          or else  CT.TY = DN_CONSTRAINED_ARRAY )						-- (record represente ou dynamique :
	      and then  A_INIT_IMPLICITE_TYPE( CT )							-- rien a produire)
	    then
	      return TRUE;
	    end if;
	  end loop;
	end;
        end if;
      end loop;

      VP := D( AS_VARIANT_PART, CL );
      if  VP = TREE_VOID  or else  VP = TREE_NIL  then
        return FALSE;
      end if;
      V_S := LIST( D( AS_VARIANT_S, VP ) );
      while  not IS_EMPTY( V_S )  loop
        POP( V_S, V_E );
        if  V_E.TY = DN_VARIANT  and then  LISTE_A_INIT( D( AS_COMP_LIST, V_E ) )  then
	return TRUE;
        end if;
      end loop;
      return FALSE;
    end	LISTE_A_INIT;
	-----------

  begin
    if  BASE.TY = DN_CONSTRAINED_RECORD  then
      BASE := FULL_TYPE_VIEW( D( SM_BASE_TYPE, BASE ) );
    end if;
    if  BASE.TY /= DN_RECORD  then
      return FALSE;
    end if;
    return  LISTE_A_INIT( D( SM_COMP_LIST, BASE ) );
  end	A_INIT_IMPLICITE;
	----------------


			------------------
  procedure		CODE_INIT_IMPLICITE	( REC_TYPE :TREE;  OBJ_VAR :STRING )
  is			------------------
	-- Lot 25 (LRM 3.2.1, 3.7.2) : valeurs implicites des composants d'un objet record
	-- dont l'adresse des donnees est dans la variable de cadre OBJ_VAR (niveau courant)
	-- et dont les discriminants sont deja poses.  Commun a l'objet declare, a l'objet
	-- alloue (new R) et au composant record d'un record (recursion).
	--   - composants de la liste, puis ceux de la variante CHOISIE d'apres le
	--     discriminant gouvernant lu DANS L'OBJET (cascade a l'execution, choix
	--     statiques par EXPRESSIONS.BORNES_CHOIX ; variantes imbriquees : recursion) ;
	--     les autres variantes ne sont pas evaluees ;
	--   - composant avec defaut : sa valeur ; composant record sans defaut : ses
	--     discriminants (contrainte, ou defauts), puis ses propres valeurs implicites.
	-- L'objet record courant (lecture d'un discriminant dans un defaut) est OBJ_VAR
	-- pendant le parcours ; celui de l'appelant est restaure en sortie.
    LVL		: LEVEL_NUM	renames CODI.CUR_LEVEL;
    LVL_STR	:constant STRING	:= IMAGE( LVL );
    REC_BASE	: TREE		:= FULL_TYPE_VIEW( REC_TYPE );
    SAUVE_NOM	:constant STRING	:= CODI.REC_COURANT_NOM( 1 .. CODI.REC_COURANT_LEN );
    SAUVE_LVL	:constant LEVEL_NUM	:= CODI.REC_COURANT_LVL;

		-------------
    procedure	ADR_COMPOSANT	( COMP_STR :STRING )						--| empile @objet.composant
    is		-------------
    begin
      PUT( tab & "LIVA " & LVL_STR & ", " & OBJ_VAR & ", " );
      REGIONS_PATH( D( XD_SOURCE_NAME, REC_BASE ) );
      PUT_LINE( TYPE_INFO_STR( REC_BASE ) & "." & COMP_STR );
    end	ADR_COMPOSANT;
	-------------

		-------
    procedure	INIT_UN		( COMP_ID :TREE )						--| valeur implicite d'UN composant
    is		-------
      FIELD_INIT	: TREE		:= D( SM_INIT_EXP, COMP_ID );
      COMP_TYPE	: TREE		:= D( SM_OBJ_TYPE, COMP_ID );
      COMP_STR	:constant STRING	:= PRINT_NAME( D( LX_SYMREP, COMP_ID ) );
      C_TYPE	: TREE		:= FULL_TYPE_VIEW( COMP_TYPE );
    begin
      if  FIELD_INIT /= TREE_VOID  and then  EST_COMPOSANT_DYNAMIQUE( COMP_ID )  then
        ADR_COMPOSANT( COMP_STR );								--| @descripteur dans l'objet
        EXPRESSIONS.CODE_VALEUR_COMPOSANT_DYNAMIQUE( COMP_ID, FIELD_INIT );

      elsif  FIELD_INIT /= TREE_VOID  then

        if  FIELD_INIT.TY = DN_AGGREGATE  then							-- composant composite : descente recursive
	if  REPRESENTED_ITEMS.HAS_COMPONENT_REP( COMP_ID )  then
	  PUT_LINE( "; CODE_INIT_IMPLICITE : composant composite d'un record represente non gere" );
	  raise PROGRAM_ERROR;
	end if;
	ADR_COMPOSANT( COMP_STR );
	EXPRESSIONS.CODE_AGGREGATE( FIELD_INIT, COMP_TYPE );					-- l'adresse du champ est sur la pile, CODE_AGGREGATE la consomme

        else										-- composant scalaire : store direct
	if  REPRESENTED_ITEMS.HAS_COMPONENT_REP( COMP_ID )  then
	  PUT_LINE( tab & "LA  " & LVL_STR & ", " & OBJ_VAR );				-- @data du record
	  REPRESENTED_ITEMS.CODE_STORE_REP_COMPONENT( COMP_ID, FIELD_INIT );
	else
	  ADR_COMPOSANT( COMP_STR );
	  EXPRESSIONS.CODE_EXP( FIELD_INIT );
	  EXPRESSIONS.CODE_RANGE_CHECK( C_TYPE );						-- LRM 3.2.1 : defaut dans le sous-type du composant
	  PUT_LINE( tab & "S" & OPER_SIZ_CHAR( COMP_TYPE ) );
	end if;
        end if;

      elsif  ( C_TYPE.TY = DN_CONSTRAINED_RECORD  or else  C_TYPE.TY = DN_RECORD )
        and then  not REPRESENTED_ITEMS.HAS_COMPONENT_REP( COMP_ID )
        and then  A_INIT_IMPLICITE_TYPE( C_TYPE )
      then
			-- Composant record sans defaut : discriminants (contrainte, evaluee avec
			-- l'objet englobant comme objet courant, ou defauts) et valeurs implicites,
			-- par INIT_RECORD_A sur une variable qui recoit l'adresse du composant.
        declare
	C_OBJ	:constant STRING	:= "__INI" & NEW_LABEL;
        begin
	PUT_LINE( "VAR " & C_OBJ & ", Q" );							-- @donnees du composant
	ADR_COMPOSANT( COMP_STR );
	PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & C_OBJ );
	INIT_RECORD_A( C_TYPE, C_OBJ );
        end;

      elsif  C_TYPE.TY = DN_CONSTRAINED_ARRAY
        and then  not REPRESENTED_ITEMS.HAS_COMPONENT_REP( COMP_ID )
        and then  not EST_COMPOSANT_DYNAMIQUE( COMP_ID )
        and then  TAILLE_STATIQUE( C_TYPE ) > 0
        and then  A_INIT_IMPLICITE_TYPE( C_TYPE )
      then
			-- Lot 26 : composant tableau (de taille statique) de records.
        declare
	C_OBJ	:constant STRING	:= "__INI" & NEW_LABEL;
	C_LEN	:constant STRING	:= C_OBJ & "_L";
        begin
	PUT_LINE( "VAR " & C_OBJ & ", Q" );
	PUT_LINE( "VAR " & C_LEN & ", Q" );
	ADR_COMPOSANT( COMP_STR );
	PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & C_OBJ );
	PUT_LINE( tab & "LI" & tab & IMAGE( TAILLE_STATIQUE( C_TYPE ) ) );
	PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & C_LEN );
	CODE_INIT_IMPLICITE_TABLEAU( C_TYPE, C_OBJ, C_LEN );
        end;
      end if;
    end	INIT_UN;
	-------

		----------
    procedure	INIT_LISTE	( CL :TREE )
    is		----------
      L_S	: SEQ_TYPE;
      L_D	: TREE;
      VP	: TREE;
    begin
      if  CL = TREE_VOID  or else  CL = TREE_NIL  then
        return;
      end if;
      L_S := LIST( D( AS_DECL_S, CL ) );
      while  not IS_EMPTY( L_S )  loop
        POP( L_S, L_D );
        if  L_D.TY /= DN_NULL_COMP_DECL  then
	declare
	  I_S	: SEQ_TYPE	:= LIST( D( AS_SOURCE_NAME_S, L_D ) );
	  I	: TREE;
	begin
	  while  not IS_EMPTY( I_S )  loop
	    POP( I_S, I );
	    INIT_UN( I );
	  end loop;
	end;
        end if;
      end loop;

      VP := D( AS_VARIANT_PART, CL );
      if  VP = TREE_VOID  or else  VP = TREE_NIL  then
        return;
      end if;
      declare
        GOV_ID	: TREE		:= D( SM_DEFN, D( AS_NAME, VP ) );
        GOV_STR	:constant STRING	:= PRINT_NAME( D( LX_SYMREP, GOV_ID ) );
        LBL_DONE	:constant STRING	:= NEW_LABEL;
        VAR_S	: SEQ_TYPE	:= LIST( D( AS_VARIANT_S, VP ) );
        VAR_E	: TREE;

		-----
        procedure	DISCR								--| discriminant gouvernant de l'objet
        is		-----
        begin
	PUT( tab & OPER_LOADI_STR( D( SM_OBJ_TYPE, GOV_ID ) ) & tab & LVL_STR & ", " & OBJ_VAR & ", " );
	REGIONS_PATH( D( XD_SOURCE_NAME, REC_BASE ) );
	PUT_LINE( TYPE_INFO_STR( REC_BASE ) & "." & GOV_STR );
        end	DISCR;
	-----

      begin
        while  not IS_EMPTY( VAR_S )  loop
	POP( VAR_S, VAR_E );
	if  VAR_E.TY = DN_VARIANT  then
	  declare
	    LBL_NEXT	:constant STRING	:= NEW_LABEL;
	    CHOICES	: SEQ_TYPE	:= LIST( D( AS_CHOICE_S, VAR_E ) );
	    CH		: TREE;
	    IS_OTHERS	: BOOLEAN		:= FALSE;
	    N_TESTS	: NATURAL		:= 0;
	    LO, HI_B	: INTEGER;
	    OK		: BOOLEAN;
	  begin
	    while  not IS_EMPTY( CHOICES )  loop
	      POP( CHOICES, CH );
	      if  CH.TY = DN_CHOICE_OTHERS  then
	        IS_OTHERS := TRUE;
	      else
	        EXPRESSIONS.BORNES_CHOIX( CH, LO, HI_B, OK );
	        if  not OK  then
		TROU( "CODE_INIT_IMPLICITE choix de variante non statique", CH );
	        end if;
	        if  LO = HI_B  then
		DISCR;
		PUT_LINE( tab & "LI" & tab & INTEGER'IMAGE( LO ) );
		PUT_LINE( tab & "CEQ" );
	        else
		DISCR;
		PUT_LINE( tab & "LI" & tab & INTEGER'IMAGE( LO ) );
		PUT_LINE( tab & "CLT" );							-- d < lo
		DISCR;
		PUT_LINE( tab & "LI" & tab & INTEGER'IMAGE( HI_B ) );
		PUT_LINE( tab & "CGT" );							-- d > hi
		PUT_LINE( tab & "OU" );
		PUT_LINE( tab & "LI" & tab & "1" );
		PUT_LINE( tab & "OUX" );							-- dans l'intervalle
	        end if;
	        N_TESTS := N_TESTS + 1;
	        if  N_TESTS >= 2  then
		PUT_LINE( tab & "OU" );							-- choix multiples : A | B
	        end if;
	      end if;
	    end loop;
	    if  not IS_OTHERS  then
	      PUT_LINE( tab & "BF" & tab & LBL_NEXT );
	    end if;
	    INIT_LISTE( D( AS_COMP_LIST, VAR_E ) );
	    PUT_LINE( tab & "BRA" & tab & LBL_DONE );
	    if  not IS_OTHERS  then
	      PUT_LINE( LBL_NEXT & ':' );
	    end if;
	  end;
	end if;
        end loop;
        PUT_LINE( LBL_DONE & ':' );
      end;
    end	INIT_LISTE;
	----------

  begin
    if  REC_BASE.TY = DN_CONSTRAINED_RECORD  then						-- base PRIVEE possible (derive d'un prive)
      REC_BASE := FULL_TYPE_VIEW( D( SM_BASE_TYPE, REC_BASE ) );
    end if;
    if  REC_BASE.TY /= DN_RECORD  or else  not A_INIT_IMPLICITE( REC_BASE )  then
      return;
    end if;
    POSER_REC_COURANT( LVL, OBJ_VAR );
    INIT_LISTE( D( SM_COMP_LIST, REC_BASE ) );
    if  SAUVE_NOM'LENGTH > 0  then
      POSER_REC_COURANT( SAUVE_LVL, SAUVE_NOM );
    else
      OTER_REC_COURANT;
    end if;
  end	CODE_INIT_IMPLICITE;
	------------------

	------------
end	DECLARATIONS;
	------------

------------------------------------------------------------------------------------------------------------------------
--	1	2	3	4	5	6	7	8	9	0	1	2
