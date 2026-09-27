------------------------------------------------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2026 VINCENT MORIN, UBO
-- SPDX-License-Identifier: GPL-3.0-or-later
------------------------------------------------------------------------------------------------------------------------
--	1	2	3	4	5	6	7	8	9	0	1	2

separate ( EXPANDER )
				----------
	package body		STRUCTURES
				----------
is

  THE_COMPILATION_UNIT	: TREE;

  package CODI	renames EXPANDER.UTILS;
  use CODI;

  procedure CODE_TRANS_WITH_INCLUDES ( COMPILATION_UNIT :TREE );

			--^^^^^^^^^^^^^^^^^^^^^--
  procedure		  CODE_COMPILATION_UNIT	( COMPILATION_UNIT :TREE )
  is			-------------------------

    UNIT_ALL_DECL		: TREE	:= D( AS_ALL_DECL, COMPILATION_UNIT );
  begin
    CODI.CUR_LEVEL	    := 0;
    CODI.ENCLOSING_BODY := TREE_VOID;
    THE_COMPILATION_UNIT := COMPILATION_UNIT;

    CODE_WITH_CONTEXT( D( AS_CONTEXT_ELEM_S, COMPILATION_UNIT ),
			EMIT_INCLUDES => UNIT_ALL_DECL.TY /= DN_SUBUNIT );
    if  UNIT_ALL_DECL.TY /= DN_SUBUNIT  then
      CODE_TRANS_WITH_INCLUDES( COMPILATION_UNIT );
    end if;

    case  UNIT_ALL_DECL.TY  is

    when  DN_SUBPROG_ENTRY_DECL	=>
      CODI.IN_SPEC_UNIT := TRUE;
      DECLARATIONS.CODE_SUBPROG_ENTRY_DECL( UNIT_ALL_DECL );						-- les instanciations génériques sont comprises  (unit_kind instantiation)

    when  DN_PACKAGE_DECL		=>
      CODI.IN_SPEC_UNIT := TRUE;
      DECLARATIONS.CODE_PACKAGE_DECL( UNIT_ALL_DECL );							-- les instanciations génériques sont comprises  (unit_kind instantiation)

    when  DN_GENERIC_DECL		=>
      CODI.IN_SPEC_UNIT := TRUE;
      DECLARATIONS.CODE_GENERIC_DECL( UNIT_ALL_DECL );

    when  DN_SUBPROGRAM_BODY		=>
      CODI.IN_SPEC_UNIT := FALSE;
      CODE_SUBPROGRAM_BODY( UNIT_ALL_DECL );

    when  DN_PACKAGE_BODY		=>
      CODI.IN_SPEC_UNIT := FALSE;
      CODE_PACKAGE_BODY( UNIT_ALL_DECL );

    when  DN_SUBUNIT		=>
			--| Niveau de depart du subunit : reprendre le niveau enregistre par
			--| l'unite PARENTE sur la premiere declaration (stub ou spec), meme
			--| canal bibliotheque que CD_LABEL.  Invariant : CD_LEVEL d'un id de
			--| sous-programme = niveau d'EXECUTION de son corps (pose apres
			--| INC_LEVEL).  Un package separe n'a PAS de cd_level (schema DIANA :
			--| dn_package_id n'en porte aucun) ; sans frame, son niveau = celui du
			--| sous-programme englobant le plus proche (remontee XD_REGION, les
			--| packages sont transparents ; TREE_VOID = bibliotheque).  Demarrer a 0
			--| n'etait juste que pour les subunits de bibliotheque (parent sans
			--| frame) : un subunit de SOUS-PROGRAMME (idl-sem_phase-*.adb) se
			--| compilait un cran trop haut et son LINK ecrasait le display du
			--| parent -- segfault ENUM_IMAGE de FIX_PRE (La 1, use__info -> 0).
      declare
        SUB_BODY		: TREE	:= D( AS_SUBUNIT_BODY, UNIT_ALL_DECL );
        FIRST_DECL_ID	: TREE	:= D( SM_FIRST, D( AS_SOURCE_NAME, SUB_BODY ) );
      begin
        if  SUB_BODY.TY = DN_SUBPROGRAM_BODY  then
	CODI.CUR_LEVEL := DI( CD_LEVEL, FIRST_DECL_ID ) - 1;					-- l'INC_LEVEL du corps retablira CD_LEVEL ; -1 sur une valeur non posee (0) => CONSTRAINT_ERROR : bruyant

        elsif  SUB_BODY.TY = DN_PACKAGE_BODY  then
	declare
	  REGION : TREE := D( XD_REGION, FIRST_DECL_ID );
	begin
	  while  REGION /= TREE_VOID  and then  REGION.TY = DN_PACKAGE_ID  loop		-- packages transparents (y compris STANDARD -> TREE_VOID ensuite)
	    REGION := D( XD_REGION, REGION );
	  end loop;
	  if  REGION = TREE_VOID  then
	    CODI.CUR_LEVEL := 0;								-- chaine de packages jusqu'a la bibliotheque : cas test_subunit, inchange
	  elsif  REGION.TY = DN_PROCEDURE_ID  or  REGION.TY = DN_FUNCTION_ID
	     or  REGION.TY = DN_OPERATOR_ID  then
	    CODI.CUR_LEVEL := DI( CD_LEVEL, REGION );						-- niveau d'execution du frame du sous-programme = niveau de ses declarations
	  else
	    CODI.TROU( "CODE_COMPILATION_UNIT region de subunit package", REGION );		-- generique / task : hors corpus, refus bruyant
	  end if;
	end;

       else
	CODI.TROU( "CODE_COMPILATION_UNIT subunit non couvert", SUB_BODY );			-- task body separe : hors corpus, refus bruyant
        end if;
        CODE_SUBUNIT_BODY( SUB_BODY );
      end;

    when others			=> CODI.TROU( "CODE_COMPILATION_UNIT", UNIT_ALL_DECL );			--| vague 4 : levait deja, enrichi du message TROU

    end case;

  end	CODE_COMPILATION_UNIT;
	---------------------



			-----------------
  procedure		CODE_WITH_CONTEXT		( CONTEXT_ELEM_S :TREE; EMIT_INCLUDES :BOOLEAN := TRUE )
  is			-----------------

    CONTEXT_ELEM_SEQ	: SEQ_TYPE	:= LIST( CONTEXT_ELEM_S );
    CONTEXT_ELEM		: TREE;
		------------------
    procedure	INSERT_WITHED_UNIT  ( DEFN :TREE )
    is
    begin
      if  EMIT_INCLUDES  then
        declare
	UNIT_NAME :constant STRING	:= PRINT_NAME( D( LX_SYMREP, DEFN ) );
        begin
	PUT_LINE( "if ~ definite " & PRINT_NAME( D( LX_SYMREP, DEFN ) ) );
	PUT_LINE( "include '" & UNIT_NAME & ".FINC'" );
	if  CODI.GENERATE_BINARY_MAP  then
	  PUT_LINE( "display 'including withed unit " & UNIT_NAME & ".FINC'" & ", 10"  );
	end if;
	PUT_LINE( "end if" );
        end;
      end if;

    end	INSERT_WITHED_UNIT;
	------------------
  begin

    while  not IS_EMPTY( CONTEXT_ELEM_SEQ )  loop
      POP( CONTEXT_ELEM_SEQ, CONTEXT_ELEM );

      if  CONTEXT_ELEM.TY = DN_WITH  then
        declare
	NAME_S		:constant TREE	:= D( AS_NAME_S, CONTEXT_ELEM );
	NAME_SEQ		: SEQ_TYPE	:= LIST( NAME_S );
	NAME		: TREE;
        begin
	while  not IS_EMPTY( NAME_SEQ )  loop
	  POP( NAME_SEQ, NAME );

	  declare
	    DEFN  : TREE	:= D( SM_DEFN, NAME );
	  begin
	    if  DEFN.TY = DN_PACKAGE_ID  then
	      INSERT_WITHED_UNIT( DEFN );
	      DB( CD_COMPILED, DEFN, TRUE );

	    elsif  DEFN.TY = DN_GENERIC_ID  then
	      INSERT_WITHED_UNIT( DEFN );

	    elsif  DEFN.TY = DN_PROCEDURE_ID  or  DEFN.TY = DN_FUNCTION_ID  then
	      INSERT_WITHED_UNIT( DEFN );

	      if  not DB( CD_COMPILED, DEFN )  then
	        DI( CD_LEVEL,      DEFN,  1 );
	        DI( CD_PARAM_SIZE, DEFN,  0 );
	        DB( CD_COMPILED,   DEFN,  TRUE );
	      end if;
	    end if;
	  end;

	end loop;
        end;
      end if;
    end loop;

  end	CODE_WITH_CONTEXT;
	-----------------


			------------------------
  procedure		CODE_TRANS_WITH_INCLUDES	( COMPILATION_UNIT :TREE )
  is			------------------------
		-- Le FINC d'un CORPS re-elabore son spec inline (elab_spec:) mais
		-- son texte ne porte pas les with du spec : les includes
		-- correspondants manquaient (constate sur text_io : IO_EXCEPTIONS
		-- absent, symboles __exc indefinis a l'assemblage).  XD_WITH_LIST
		-- est la fermeture transitive (dump du 7/7) : une garde d'include
		-- par unite package/generique, en sautant :
		--   . _STANDRD -- inclus par le wrapper ;
		--   . le spec de l'unite compilee -- son FINC n'existe pas quand on
		--     compile le corps, et son contenu est re-elabore inline.
		--     Identification par NOEUD (TW_COMP_UNIT = XD_PARENT), doublee
		--     d'un test de nom (cas spec-seule : XD_PARENT est vierge).
		-- Pas d'effet de bord CD_* ici : c'est le role de la passe
		-- textuelle CODE_WITH_CONTEXT, inchangee.
    TW_SEQ	: SEQ_TYPE	:= LIST( COMPILATION_UNIT );
    TW		: TREE;
    OWN_SPEC	:constant TREE	:= D( XD_PARENT, COMPILATION_UNIT );
    OWN_NAME	:constant STRING
		:= PRINT_NAME( D( LX_SYMREP, D( AS_SOURCE_NAME, D( AS_ALL_DECL, COMPILATION_UNIT ) ) ) );

  begin
    while  not IS_EMPTY( TW_SEQ )  loop
      POP( TW_SEQ, TW );

      declare
        TW_UNIT		: TREE	:= D( TW_COMP_UNIT, TW );
        DEFN		: TREE	:= D( AS_SOURCE_NAME, D( AS_ALL_DECL, TW_UNIT ) );
        UNIT_NAME	:constant STRING	:= PRINT_NAME( D( LX_SYMREP, DEFN ) );
      begin
        if  ( DEFN.TY = DN_PACKAGE_ID  or  DEFN.TY = DN_GENERIC_ID
	or  DEFN.TY = DN_PROCEDURE_ID  or  DEFN.TY = DN_FUNCTION_ID)
	  and then  UNIT_NAME /= "_STANDRD"  and then  UNIT_NAME /= "STANDARD"
	  and then  UNIT_NAME /= OWN_NAME
	  and then  TW_UNIT /= OWN_SPEC
        then
	  PUT_LINE( "if ~ definite " & UNIT_NAME );
	  PUT_LINE( "include '" & UNIT_NAME & ".FINC'" );
	  if  CODI.GENERATE_BINARY_MAP  then
	    PUT_LINE( "display 'including trans withed unit " & UNIT_NAME & ".FINC'" & ", 10" );
	  end if;
	  PUT_LINE( "end if" );
        end if;
      end;
    end loop;

  end	CODE_TRANS_WITH_INCLUDES;
	------------------------


		--------------------------
  procedure	CODE_GENERIC_FRAME_OFFSETS ( GENERIC_ID : TREE )
  is		--------------------------
    GPRM_SEQ : SEQ_TYPE := LIST( D( SM_GENERIC_PARAM_S, GENERIC_ID ) );
		---------------
    procedure	INVERSE_RECURSE
    is		---------------
      GPRM	: TREE;

    begin
      POP( GPRM_SEQ, GPRM );
      if  not IS_EMPTY( GPRM_SEQ )  then INVERSE_RECURSE; end if;

      if  GPRM.TY = DN_TYPE_DECL  then
        declare
	GTYPE_ID	 : TREE := D( AS_SOURCE_NAME, GPRM );
	GPRM_NAME  : constant STRING := PRINT_NAME( D( LX_SYMREP, GTYPE_ID ) );
        begin
	PUT_LINE( tab & GPRM_NAME & "__u_ofs = $" );
	PUT_LINE( tab & "rq 1" );

	PUT_LINE( tab & GPRM_NAME & "__ld_ofs = $" );
	PUT_LINE( tab & "rq 1" );

	PUT_LINE( tab & GPRM_NAME & "__st_ofs = $" );
	PUT_LINE( tab & "rq 1" );

	PUT_LINE( tab & GPRM_NAME & "__inadr_ofs = $" );
	PUT_LINE( tab & "rq 1" );

	PUT_LINE( tab & GPRM_NAME & "__outadr_ofs = $" );
	PUT_LINE( tab & "rq 1" );
        end;

      elsif  GPRM.TY = DN_SUBPROG_ENTRY_DECL  then
        declare
	SUBP_ID	: TREE		:= D( AS_SOURCE_NAME, GPRM );
	SUBP_STR  : constant STRING	:= LETTERED_SUBNAME( PRINT_NAME( D( LX_SYMREP, SUBP_ID ) ) );

        begin
	PUT_LINE( tab & SUBP_STR & "__call_ofs = $" );
	PUT_LINE( tab & "rq 1" );
        end;

      elsif  GPRM.TY = DN_IN  or else  GPRM.TY = DN_IN_OUT  or else  GPRM.TY = DN_OUT  then
        declare
	GOBJ_SEQ  : SEQ_TYPE	:= LIST( D( AS_SOURCE_NAME_S, GPRM ) );
	GOBJ_ID	: TREE;

        begin
	while  not IS_EMPTY( GOBJ_SEQ )  loop
	  POP( GOBJ_SEQ, GOBJ_ID );

	  declare
	    GOBJ_NAME	: constant STRING	:= PRINT_NAME( D( LX_SYMREP, GOBJ_ID ) );
	    GOBJ_TYPE	: TREE		:= D( SM_OBJ_TYPE, GOBJ_ID );
	  begin
	    while  GOBJ_TYPE.TY = DN_PRIVATE  or else  GOBJ_TYPE.TY = DN_L_PRIVATE  loop
	      GOBJ_TYPE := D( SM_TYPE_SPEC, GOBJ_TYPE );
	    end loop;

	    if  GOBJ_TYPE.TY in CLASS_SCALAR  or else  GOBJ_TYPE.TY = DN_ACCESS  then
	         -- Objet formel scalaire :
	         -- slot unique X_ofs, utilisé par LVA , -X_ofs
	         --
	         -- Physique attendu côté instance :
	         --     VAR X_disp, q
	         --
	         -- Donc :
	         --     X_ofs = 8  =>  GFP - 8 = X_disp

	      PUT_LINE( tab & GOBJ_NAME & "_ofs = $" );
	      PUT_LINE( tab & "rq 1" );

	    else
	         -- Objet formel composite :
	         -- doublet X_disp / X__u.
	         --
	         -- Physique attendu côté instance :
	         --     VAR X_disp, q
	         --     VAR X__u,   q
	         --     VAR GFP_disp, q
	         --
	         -- Donc :
	         --     X__u_ofs = 8	 => GFP - 8  = X__u
	         --     X_ofs    = 16  => GFP - 16 = X_disp
	         --
	         -- LVA , -X_ofs donne bien l'adresse du doublet.

	      PUT_LINE( tab & GOBJ_NAME & "__u_ofs = $" );
	      PUT_LINE( tab & "rq 1" );

	      PUT_LINE( tab & GOBJ_NAME & "_ofs = $" );
	      PUT_LINE( tab & "rq 1" );
	    end if;
	  end;
	end loop;
        end;

      else
        CODI.TROU( "CODE_GENERIC_FRAME_OFFSETS parametre generique", GPRM );					--| vague 4, HORS LISTE : un formel non couvert
      end if;

    end	INVERSE_RECURSE;
	---------------
  begin
    if  not IS_EMPTY( GPRM_SEQ )  then
      PUT_LINE( "virtual at 8" );
      INVERSE_RECURSE;
      PUT_LINE( "end virtual" );
    end if;

  end	CODE_GENERIC_FRAME_OFFSETS;
	--------------------------


			--------------------
  procedure		CODE_SUBPROGRAM_BODY	( SUBPROGRAM_BODY :TREE )
  is			--------------------

    LBL			: LABEL_TYPE;
    SOURCE_NAME		: TREE		:= D( AS_SOURCE_NAME, SUBPROGRAM_BODY );
    SUB_NAME		:constant STRING	:= LETTERED_SUBNAME( PRINT_NAME( D( LX_SYMREP, SOURCE_NAME ) ) );
    DECL_ID		: TREE		:= D( SM_FIRST, SOURCE_NAME );
    SAVE_ENCLOSING		: TREE		:= ENCLOSING_BODY;
    SAVE_NO_SUB_PARAM	: BOOLEAN		:= CODI.NO_SUBP_PARAMS;
    SUB_BODY		: TREE		:= D( AS_BODY, SUBPROGRAM_BODY );

    SAVE_IN_GENERIC_BODY	: BOOLEAN		:= CODI.IN_GENERIC_BODY;
    SAVE_ENCLOSING_GENERIC	: TREE		:= CODI.ENCLOSING_GENERIC;
    SAVE_GENERIC_BASE_LEVEL	: LEVEL_NUM	:= CODI.GENERIC_BASE_LEVEL;
    SAVE_GFP_LEVEL		: LEVEL_NUM	:= CODI.GFP_LEVEL;
    SAVE_GOTO_BASE		: GOTO_LBL_IDX	:= CODI.GOTO_BODY_BASE;
    SAVE_GOTO_TOP		: GOTO_LBL_IDX	:= CODI.GOTO_LBL_TOP;
    SAVE_GOTO_PEND_BASE	: GOTO_LBL_IDX	:= CODI.GOTO_PEND_BASE;
    SAVE_GOTO_PEND_TOP	: GOTO_LBL_IDX	:= CODI.GOTO_PEND_TOP;

  begin
    INC_LEVEL;
    CODI.GFP_LEVEL := CODI.CUR_LEVEL;									-- ce PRO porte le PRM GFP_ofs vu par ses blocs
    CODI.GOTO_BODY_BASE := CODI.GOTO_LBL_TOP;								-- ouvrir le perimetre goto de CE corps
    CODI.GOTO_PEND_BASE := CODI.GOTO_PEND_TOP;
    if  DECL_ID.TY /= DN_GENERIC_ID  then
      if  DECL_ID = SOURCE_NAME  then									-- PREMIERE DEFINITION PAS DE SPEC DEJA ETIQUETEE
        LBL := NEW_LABEL;
        DI( CD_LEVEL, SOURCE_NAME, INTEGER( CODI.CUR_LEVEL ) );
        DI( CD_LABEL, SOURCE_NAME, INTEGER( LBL ) );

      else
        LBL := LABEL_TYPE( DI( CD_LABEL, DECL_ID ) );
        DI( CD_LEVEL, SOURCE_NAME, DI( CD_LEVEL, DECL_ID ) );
        DI( CD_LABEL, SOURCE_NAME, INTEGER( LBL ) );

      end if;

    else
      LBL := NEW_LABEL;
      DI( CD_LEVEL, SOURCE_NAME, INTEGER( CODI.CUR_LEVEL ) );
      DI( CD_LABEL, SOURCE_NAME, INTEGER( LBL ) );
      DB( CD_COMPILED, SOURCE_NAME, TRUE );
      CODI.IN_GENERIC_BODY := TRUE;
      CODI.ENCLOSING_GENERIC := DECL_ID;
      CODI.GENERIC_BASE_LEVEL := CODI.CUR_LEVEL - 1;

    end if;

    if  ENCLOSING_BODY /= TREE_VOID  then
      NEW_LINE;
      PUT_LINE( "if defined " & SUB_NAME & '_' & LABEL_STR( LBL ) & '_' );
    end if;

    if  SUB_BODY.TY = DN_STUB  then
      declare
        UNIT_FILE_NAME	:constant STRING	:= PRINT_NAME( D( XD_LIB_NAME, THE_COMPILATION_UNIT ) );
        FULL_NAME		:constant STRING	:= UNIT_FILE_NAME( UNIT_FILE_NAME'FIRST .. UNIT_FILE_NAME'LAST-4 )
						& '-' & SUB_NAME & ".FINC";
      begin
        PUT_LINE( "include '" & FULL_NAME & ''' );
        if  CODI.GENERATE_BINARY_MAP  then
	PUT_LINE( "display 'including sub body " & FULL_NAME & ''' & ", 10" );
        end if;
      end;

    else
      if  ENCLOSING_BODY = TREE_VOID  then								-- unite de bibliotheque : garde n 97
        PUT_LINE( SUB_NAME & " = '" & SUB_NAME & "'" );
      end if;

      PUT( "PRO" & tab & SUB_NAME & '_' & LABEL_STR( LBL ) );

      if  CODI.DEBUG  then PUT( tab50 & ";---------- PRO " & SUB_NAME ); end if;
      NEW_LINE;
      if  CODI.GENERATE_BINARY_MAP  then
        PUT_LINE( " hexa_show '" & SUB_NAME & '_' & LABEL_STR( LBL ) & " ', $" );
      end if;


      if DECL_ID.TY = DN_GENERIC_ID then
        CODE_GENERIC_FRAME_OFFSETS( DECL_ID );
      end if;

      DECLARATIONS.CODE_HEADER( D( SM_SPEC, SOURCE_NAME ) );

      ENCLOSING_BODY := SUBPROGRAM_BODY;

      CODE_BLOCK_BODY( SUB_BODY );

      PUT_LINE( "ret_lbl:" );
      PUT_LINE( tab & CODI.EXIT_UNLINK_MNEMONIC( D( AS_HEADER, SUBPROGRAM_BODY ) )		-- chantier co-pile (n 163) : UNLINKR rend la
		& LEVEL_NUM'IMAGE( CODI.CUR_LEVEL ) );					-- co-pile, sauf resultat TABLEAU (n 147)

      PUT( tab & "RTD" );
      if  CODI.NO_SUBP_PARAMS = FALSE  then  PUT( tab & "prm_siz" );
--        if  SOURCE_NAME.TY = DN_FUNCTION_ID  then
        if  SOURCE_NAME.TY = DN_FUNCTION_ID  or  SOURCE_NAME.TY = DN_OPERATOR_ID  then
	PUT( INTEGER'IMAGE( - STACK_ELEMENT_SIZE ) );							-- POUR UNE FONCTION NE PAS LIBERER LE RESULTAT
        end if;
      end if;
      CODI.NO_SUBP_PARAMS := SAVE_NO_SUB_PARAM;
      NEW_LINE;
      PUT_LINE( "excep:" );

      PUT( "endPRO" );
      if  CODI.DEBUG  then PUT( tab50 & ";---------- end PRO " & SUB_NAME); end if;
      NEW_LINE;
    end if;

    DEC_LEVEL;
    ENCLOSING_BODY := SAVE_ENCLOSING;
    if  ENCLOSING_BODY /= TREE_VOID  then
      PUT_LINE( "end if" );
    end if;

    CODI.GOTO_CHECK_BODY_END;										-- ceinture : raccord jamais resolu
    CODI.GOTO_LBL_TOP    := SAVE_GOTO_TOP;								-- refermer le perimetre goto de ce corps
    CODI.GOTO_BODY_BASE  := SAVE_GOTO_BASE;
    CODI.GOTO_PEND_TOP   := SAVE_GOTO_PEND_TOP;
    CODI.GOTO_PEND_BASE  := SAVE_GOTO_PEND_BASE;
    CODI.IN_GENERIC_BODY    := SAVE_IN_GENERIC_BODY;
    CODI.ENCLOSING_GENERIC  := SAVE_ENCLOSING_GENERIC;
    CODI.GENERIC_BASE_LEVEL := SAVE_GENERIC_BASE_LEVEL;
    CODI.GFP_LEVEL          := SAVE_GFP_LEVEL;

  end	CODE_SUBPROGRAM_BODY;
	--------------------



			-----------------
  procedure		CODE_PACKAGE_BODY		( PACKAGE_BODY :TREE )
  is			-----------------

    PACK_ID	: TREE		:= D( AS_SOURCE_NAME, PACKAGE_BODY );
    PACK_NAME	:constant STRING	:= PRINT_NAME( D( LX_SYMREP, PACK_ID ) );
    PACK_DEF	: TREE		:= D( SM_FIRST, PACK_ID );
    PACK_BODY	: TREE		:= D( AS_BODY, PACKAGE_BODY );
    CAS_NORMAL	: BOOLEAN		:= PACK_NAME /= "STANDARD" and PACK_NAME /= "_STANDRD";
  begin
    if  PACK_DEF.TY = DN_GENERIC_ID  then
      declare
        SAVE_GENERIC_LEVEL	:LEVEL_NUM	:= CODI.GENERIC_BASE_LEVEL;
        SAVE_GFP_LEVEL	:LEVEL_NUM	:= CODI.GFP_LEVEL;
      begin
      CODI.GENERIC_BASE_LEVEL := CUR_LEVEL;
      CODI.GFP_LEVEL := CUR_LEVEL;									-- code d'elaboration du corps : meme niveau qu'avant (CUR_LEVEL)

      CODI.IN_GENERIC_BODY := TRUE;
      CODI.ENCLOSING_GENERIC := PACK_DEF;
      PUT_LINE( PACK_NAME & " = " & "'" & PACK_NAME & "'" );
      PUT( "namespace " & PACK_NAME );
      if  CODI.DEBUG  then NEW_LINE; PUT( tab50 & ";---------- GENERIC PACKAGE ----------" ); NEW_LINE; end if;
      NEW_LINE;
      if  CODI.GENERATE_BINARY_MAP  then
        PUT_LINE( " hexa_show '" & PACK_NAME & " body ', $" );
      end if;

      PUT_LINE( "PRMS" );

      declare
        GPRM_SEQ	: SEQ_TYPE	:= LIST( D( SM_GENERIC_PARAM_S, PACK_DEF ) );
        GPRM	: TREE;
      begin
        while  not IS_EMPTY( GPRM_SEQ )  loop
	POP( GPRM_SEQ, GPRM );

	if  GPRM.TY = DN_TYPE_DECL  then
	  declare
	    GTYPE_ID	: TREE		:= D( AS_SOURCE_NAME, GPRM );
	    GPRM_NAME	:constant STRING	:= PRINT_NAME( D( LX_SYMREP, GTYPE_ID ) );
	    GTYPE_DEF	: TREE		:= D( AS_TYPE_DEF, GPRM );
	  begin
	    PUT_LINE( tab & "PRM " & GPRM_NAME & "__u_ofs" );
	    PUT_LINE( tab & "PRM " & GPRM_NAME & "__ld_ofs" );
	    PUT_LINE( tab & "PRM " & GPRM_NAME & "__st_ofs" );
	    PUT_LINE( tab & "PRM " & GPRM_NAME & "__inadr_ofs" );
	    PUT_LINE( tab & "PRM " & GPRM_NAME & "__outadr_ofs" );
	  end;

	elsif  GPRM.TY = DN_SUBPROG_ENTRY_DECL  then
	declare
	  SUBP_ID		: TREE		:= D( AS_SOURCE_NAME, GPRM );
	  SUBP_STR	: constant STRING	:= LETTERED_SUBNAME( PRINT_NAME( D( LX_SYMREP, SUBP_ID ) ) );

	begin
	  PUT_LINE( tab & "PRM " & SUBP_STR & "__call_ofs" );
	end;

	end if;
        end loop;
      end;

      PUT_LINE( "endPRMS" );

      if  CODI.DEBUG  then NEW_LINE; PUT( tab50 & ";---------- GENERIC PACKAGE SPEC OF BODY ----------" );
        NEW_LINE; end if;
      NEW_LINE;
      DECLARATIONS.CODE_PACKAGE_SPEC( D( SM_SPEC, PACK_ID ) );						-- POUR LES EMPLACEMENTS DES VARS DE SPEC DE GENERIQUE

      ENCLOSING_BODY := PACKAGE_BODY;
      if  CODI.DEBUG  then NEW_LINE; PUT( tab50 & ";---------- GENERIC PACKAGE BODY ----------" ); NEW_LINE; end if;
      NEW_LINE;
      CODE_BLOCK_BODY( PACK_BODY, IS_PACK_BODY=> TRUE );							-- POUR LES VARS ET LES SUBS DU CORPS DE GENERIQUE

      PUT( "end namespace " );
      if  CODI.DEBUG  then
        PUT( tab50 & ";---------- end generic package BDY " & PACK_NAME );
      end if;
      NEW_LINE;
      CODI.IN_GENERIC_BODY := FALSE;
      CODI.GENERIC_BASE_LEVEL := SAVE_GENERIC_LEVEL;
      CODI.GFP_LEVEL := SAVE_GFP_LEVEL;
      end;
    else

      if  PACK_BODY.TY = DN_STUB  then
        declare
	UNIT_FILE_NAME	:constant STRING	:= PRINT_NAME( D( XD_LIB_NAME, THE_COMPILATION_UNIT ) );
	FULL_UNIT_NAME	:constant STRING	:= UNIT_FILE_NAME( UNIT_FILE_NAME'FIRST .. UNIT_FILE_NAME'LAST-4 )
						& '-' & PACK_NAME & ".FINC";
        begin
	PUT_LINE( "include '" & FULL_UNIT_NAME & ''' );
	if  CODI.GENERATE_BINARY_MAP  then
	  PUT_LINE( "display 'including sub unit " & FULL_UNIT_NAME & ''' & ", 10" );
	end if;
        end;

      else
        if  CAS_NORMAL  then
	PUT_LINE( PACK_NAME & " = " & "'" & PACK_NAME & "'" );
	PUT( "namespace " & PACK_NAME );
	if  CODI.DEBUG  then PUT( tab50 & ";---------- PACKAGE (BDY)" ); end if;
	NEW_LINE;
        end if;

--  Si la spec du package a déjà été émise par CODE_PACKAGE_DECL
--  dans la même unité / le même bloc, ne pas la réémettre dans le body.
--  Le body ne doit coder ici que ses déclarations propres.
        if  not DB( CD_COMPILED, D( SM_FIRST, PACK_ID ) )
	or else D( XD_REGION, PACK_ID ) = TREE_VOID							-- STANDARD
	or else  PRINT_NAME( D( LX_SYMREP, D( XD_REGION, PACK_ID ) ) ) = "STANDARD"				-- Package librairie
        then
	PUT( "elab_spec:" );
	if  CODI.DEBUG  then PUT_LINE( tab50 & ";    SPEC ELAB" ); end if;
	NEW_LINE;

	DECLARATIONS.CODE_PACKAGE_SPEC( D( SM_SPEC, PACK_ID ) );
	DB( CD_COMPILED, PACK_ID, TRUE );
        end if;
        ENCLOSING_BODY := PACKAGE_BODY;
        CODE_BLOCK_BODY( PACK_BODY, IS_PACK_BODY=> TRUE );

        if  CAS_NORMAL  then
	PUT( "end namespace " );
	if  CODI.DEBUG
	then  PUT_LINE( tab50 & ";---------- end package BDY " & PACK_NAME );
	end if;
        end if;
        NEW_LINE;
      end if;

    end if;

  end	CODE_PACKAGE_BODY;
	-----------------



			--===============--
  procedure		  CODE_BLOCK_BODY	( BLOCK_BODY :TREE; IS_PACK_BODY :BOOLEAN := FALSE )
  is			--===============--


			-----------
  procedure		CODE_ITEM_S		( ITEM_S :TREE )
  is
    ITEM_SEQ	: SEQ_TYPE	:= LIST ( ITEM_S );
    ITEM		: TREE;
  begin
    while  not IS_EMPTY( ITEM_SEQ )  loop
      POP( ITEM_SEQ, ITEM );

      if  ITEM.TY in CLASS_DECL
      then  DECLARATIONS.CODE_DECL( ITEM );

      elsif  ITEM.TY in CLASS_SUBUNIT_BODY
      then  CODE_SUBUNIT_BODY( ITEM );

      else
        CODI.TROU( "CODE_ITEM_S", ITEM );							--| vague 4 : dispatch muet (fossile n 115)
      end if;

    end loop;

  end	CODE_ITEM_S;
	-----------

  begin
    DI( CD_LEVEL, BLOCK_BODY, INTEGER( CODI.CUR_LEVEL ) );

    if  CODI.CUR_LEVEL /= 0  and then  not IS_PACK_BODY
    then  PUT( "ELB" & LEVEL_NUM'IMAGE( CODI.CUR_LEVEL ) );
    end if;

    if  CODI.DEBUG  then PUT( tab50 & ";    BODY ELAB" ); end if;
    NEW_LINE;

    declare
      SAVE_ENCLOSING	: TREE	:= ENCLOSING_BODY;
    begin
      CODE_ITEM_S( D( AS_ITEM_S, BLOCK_BODY ) );
      ENCLOSING_BODY := SAVE_ENCLOSING;
    end;

    if  ENCLOSING_BODY.TY = DN_SUBPROGRAM_BODY  then

      if  CODI.DEBUG  then PUT( tab50 & ";    end elab" ); end if;
      NEW_LINE;

    end if;

    PUT( "begin:" );
    if  CODI.DEBUG  then
      PUT( tab50 & ";---------- " );
      if  ENCLOSING_BODY.TY = DN_SUBPROGRAM_BODY  then PUT( "BDY INSTRUCTIONS" );
      elsif  ENCLOSING_BODY.TY = DN_PACKAGE_BODY  then PUT( "package BDY INSTRUCTIONS" );
      end if;
    end if;
    NEW_LINE;

    declare
      HAS_HANDLERS		:constant BOOLEAN	:= not IS_EMPTY( LIST( D( AS_ALTERNATIVE_S, BLOCK_BODY ) ) );
      LVL_STR		:constant STRING	:= INTEGER'IMAGE( CODI.CUR_LEVEL );
      DSP_NUM		:constant LABEL_TYPE	:= NEW_LABEL;					-- la surcharge NUMERIQUE
      DSP_LBL		:constant STRING	:= LABEL_STR( DSP_NUM );
      POST_LBL		:constant STRING	:= NEW_LABEL;
      CTX_NAME		:constant STRING	:= "exc_ctx_" & LABEL_STR( DSP_NUM );

    begin
      if  HAS_HANDLERS  then
        if  IS_PACK_BODY  then
	PUT_LINE( ";ANOMALIE : handlers sur corps de package non modelises" );				--| DEFAUT DOCUMENTE (vague 5) : bruyant volontairement
												--| non fatal -- exceptions d'elaboration, differe
												--| (croiser pilier 11)

        else
			-- PILIER 11 : frame porteur -> contexte de reprise (push a begin:, apres
			-- l'elaboration : LRM 11.4.2 gratuit).  Publication d'EXC_TOP en DERNIER.
	PUT_LINE( "VAR" & tab & CTX_NAME & ", q," & INTEGER'IMAGE( 8 + CODI.CUR_LEVEL ) );			-- 7 en-tete + (lvl+1) display
	PUT_LINE( tab & "LA" & tab & "0, STANDARD.EXCEPTIONS_TOP_CTX_disp" );
	PUT_LINE( tab & "SA " & LVL_STR & ',' & tab & CTX_NAME );						-- PREV_CTX
	PUT_LINE( tab & "LCA" & tab & DSP_LBL );
	PUT_LINE( tab & "SA " & LVL_STR & ',' & tab & CTX_NAME & " + STANDARD._EXCEPTION_CONTEXT.DISPATCH" );	-- offset symbolique : suit le record Ada
	PUT_LINE( tab & "EXC_MACH " & LVL_STR & ',' & tab & CTX_NAME );					-- RBP RSP R13 R14 NXT_LVL FP(0..lvl)
	PUT_LINE( tab & "LVA " & LVL_STR & ',' & tab & CTX_NAME );
	PUT_LINE( tab & "SA" & tab & "0, STANDARD.EXCEPTIONS_TOP_CTX_disp" );
	CODI.HANDLER_CTX_AT( CODI.CUR_LEVEL ) := TRUE;							-- pour les pops de CODE_RETURN / CODE_EXIT
        end if;
      end if;

      INSTRUCTIONS.CODE_STM_S( D( AS_STM_S, BLOCK_BODY ) );

      if  HAS_HANDLERS  and then  not IS_PACK_BODY  then
        CODI.HANDLER_CTX_AT( CODI.CUR_LEVEL ) := FALSE;							-- AVANT les handlers : leur contexte est
												-- deja depile a l'entree du dispatch
        CODI.EXC_POP;										-- sortie normale du corps protege
        PUT_LINE( tab & "BRA" & tab & POST_LBL );								-- sauter la section dispatch+handlers

        PUT_LINE( DSP_LBL & ':' );									-- LRM 11.3 : memoriser l'exception qui a cause le transfert, par ACTIVATION -- dans PREV_CTX (+0), mort depuis le pop.
        PUT_LINE( tab & "LA" & tab & "0, STANDARD.EXCEPTIONS_CURRENT_disp" );
        PUT_LINE( tab & "SA " & LVL_STR & ',' & tab & CTX_NAME );

        declare
	OLD_LVL	:constant INTEGER		:= CODI.HANDLER_LVL;
	OLD_SUF	:constant LABEL_TYPE	:= CODI.HANDLER_CTX_SUF;
        begin
	CODI.HANDLER_LVL := CODI.CUR_LEVEL;
	CODI.HANDLER_CTX_SUF := DSP_NUM;
	CODE_EXCEPTIONS_ALTERNATIVE_S( D( AS_ALTERNATIVE_S, BLOCK_BODY ) );
	CODI.HANDLER_LVL := OLD_LVL;
	CODI.HANDLER_CTX_SUF := OLD_SUF;
        end;
        PUT_LINE( POST_LBL & ':' );									-- chute des handlers et du flux normal :
												-- epilogue de l'appelant (ret_lbl / UNLINK)
      end if;
    end;

  end	CODE_BLOCK_BODY;
	---------------



			-----------------
  procedure		CODE_SUBUNIT_BODY		( SUBUNIT_BODY :TREE )
  is			-----------------
  begin

    if  SUBUNIT_BODY.TY = DN_SUBPROGRAM_BODY
    then  CODE_SUBPROGRAM_BODY( SUBUNIT_BODY );

    elsif  SUBUNIT_BODY.TY = DN_PACKAGE_BODY
    then  CODE_PACKAGE_BODY( SUBUNIT_BODY );

    elsif  SUBUNIT_BODY.TY = DN_TASK_BODY
    then  CODE_TASK_BODY( SUBUNIT_BODY );

    end if;

  end	CODE_SUBUNIT_BODY;
	-----------------



			--------------
  procedure		CODE_TASK_BODY ( TASK_BODY :TREE )
  is
  begin
    CODI.TROU( "CODE_TASK_BODY (tasking hors perimetre)", TASK_BODY );					--| vague 4 : corps vide, le corps de tache etait avale

  end	CODE_TASK_BODY;
	--------------



		----------------------------------------------------
		--	E X C E P T I O N S	  H A N D L E R S	--


			-----------------------------
  procedure		CODE_EXCEPTIONS_ALTERNATIVE_S		( ALTERNATIVE_S :TREE )
  is			-----------------------------
		-- PILIER 11 : dispatch des handlers.  On arrive sur le label pose par
		-- CODE_BLOCK_BODY avec le contexte DEJA depile par exc_raise_ et l'etat
		-- machine restaure a l'etat begin: du frame porteur ;
		-- EXCEPTIONS_CURRENT porte l'identite (@doublet STR).
		-- Chute en fond de section sans appariement : re-raise (LRM 11.4.1).

    ALTERNATIVE_SEQ		: SEQ_TYPE		:= LIST ( ALTERNATIVE_S );
    ALTERNATIVE_ELEM	: TREE;
    END_LBL		:constant STRING		:= NEW_LABEL;
    SEEN_OTHERS		: BOOLEAN			:= FALSE;

		----------------
    procedure	CODE_ALTERNATIVE	( ALTERNATIVE :TREE )
    is		----------------
      HANDLER_LBL		:constant STRING		:= NEW_LABEL;
      SKIP_LBL		:constant STRING		:= NEW_LABEL;
      CHOICE_SEQ		: SEQ_TYPE		:= LIST( D( AS_CHOICE_S, ALTERNATIVE ) );
      CHOICE		: TREE;
      IS_OTHERS		: BOOLEAN			:= FALSE;

    begin
      while  not IS_EMPTY( CHOICE_SEQ )  loop
        POP( CHOICE_SEQ, CHOICE );

        if  CHOICE.TY = DN_CHOICE_EXP  then
	declare
	  EXCEPTION_ID	: TREE	:= CODI.EXCEPTION_ID_OF( D( AS_EXP, CHOICE ) );				-- resout selected + renames (LRM 8.5);
	begin											-- when X =>  (choix multiple : une paire par choix)
	  PUT_LINE( tab & "LA" & tab & "0, STANDARD.EXCEPTIONS_CURRENT_disp" );
	  PUT( tab & "LCA" & tab );
	  CODI.REGIONS_PATH( EXCEPTION_ID );
	  PUT_LINE( PRINT_NAME( D( LX_SYMREP, EXCEPTION_ID ) ) & "__exc.data_ptr" );
	  PUT_LINE( tab & "CEQ" );
	  PUT_LINE( tab & "BT" & tab & HANDLER_LBL );
	end;

        elsif  CHOICE.TY = DN_CHOICE_OTHERS  then
	IS_OTHERS := TRUE;  SEEN_OTHERS := TRUE;							-- sem : others seul dans son choix, et dernier

        elsif  CHOICE.TY = DN_CHOICE_RANGE  then
	PUT_LINE( "CODE_ALTERNATIVE ANOMALIE : CHOICE_RANGE in EXCEPTIONS" );					--| DEFAUT DOCUMENTE (vague 5) : ceinture
												--| d'impossible (sem : choix = noms ou others)
        end if;
      end loop;

      if  not IS_OTHERS  then
        PUT_LINE( tab & "BRA" & tab & SKIP_LBL );								-- aucun choix apparie : alternative suivante
        PUT_LINE( HANDLER_LBL & ':' );
      end if;
      INSTRUCTIONS.CODE_STM_S( D( AS_STM_S, ALTERNATIVE ) );
      PUT_LINE( tab & "BRA" & tab & END_LBL );								-- fin de handler : reprendre apres le corps protege
      if  not IS_OTHERS  then
        PUT_LINE( SKIP_LBL & ':' );
      end if;
    end	CODE_ALTERNATIVE;
	----------------

  begin
    while  not IS_EMPTY( ALTERNATIVE_SEQ )  loop
      POP( ALTERNATIVE_SEQ, ALTERNATIVE_ELEM );

      if  ALTERNATIVE_ELEM.TY = DN_ALTERNATIVE  then
        CODE_ALTERNATIVE( ALTERNATIVE_ELEM );

      elsif  ALTERNATIVE_ELEM.TY = DN_ALTERNATIVE_PRAGMA  then
        PUT_LINE( "CODE_EXCEPTIONS_ALTERNATIVE_S ANOMALIE : DN_ALTERNATIVE_PRAGMA in EXCEPTIONS" );			--| DEFAUT DOCUMENTE (vague 5) : ceinture bruyante
      end if;
    end loop;

    if  not SEEN_OTHERS  then
      PUT_LINE( tab & "BRA" & tab & "STANDARD.exc_raise_" );						-- non-appariement : propager (contexte deja depile)
    end if;
    PUT_LINE( END_LBL & ':' );

  end	CODE_EXCEPTIONS_ALTERNATIVE_S;
	-----------------------------


	----------
end	STRUCTURES;
	----------

--	1	2	3	4	5	6	7	8	9	0	1	2
------------------------------------------------------------------------------------------------------------------------
