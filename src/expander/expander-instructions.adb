------------------------------------------------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2026 VINCENT MORIN, UBO
-- SPDX-License-Identifier: GPL-3.0-or-later
------------------------------------------------------------------------------------------------------------------------
--	1	2	3	4	5	6	7	8	9	0	1	2

separate ( EXPANDER )
				------------
	package body		INSTRUCTIONS
				------------
  is


  package CODI	renames EXPANDER.UTILS;
  use CODI;


  procedure			CODE_STM_S		( STM_S :TREE )
  is
  begin
    declare
      STM_SEQ : SEQ_TYPE := LIST ( STM_S );
      STM_ELEM : TREE;
    begin
      while not IS_EMPTY ( STM_SEQ ) loop
        POP( STM_SEQ, STM_ELEM );
        CODE_STM_ELEM( STM_ELEM );
      end loop;
    end;
  end	CODE_STM_S;

			-------------
  procedure		CODE_STM_ELEM		( STM_ELEM :TREE )
  is			-------------
  begin

    if STM_ELEM.TY in CLASS_STM then
      CODE_STM( STM_ELEM );

    elsif STM_ELEM.TY = DN_STM_PRAGMA then
      CODE_STM_PRAGMA( STM_ELEM );

    else
      CODI.TROU( "CODE_STM_ELEM", STM_ELEM );								--| vague 3 : dispatch muet (fossile n 115)
    end if;

  end	CODE_STM_ELEM;
	-------------

			---------------
  procedure		CODE_STM_PRAGMA		( STM_PRAGMA :TREE )
  is			---------------
  begin
    null;												--| INTENTIONNEL (partiel) : aucun pragma d'instruction
												--| n'a d'effet de code dans le perimetre actuel ; si un
												--| pragma devient signifiant (SUPPRESS, INLINE...), le
												--| trier ICI au lieu d'elargir ce null (triage 28/07)
  end;



				--^^^^^^^^--
  procedure			  CODE_STM		( STM :TREE )
  is				------------
  begin
    if STM.TY = DN_LABELED  then
      CODE_LABELED( STM );

    elsif STM.TY = DN_NULL_STM  then
      CODE_NULL_STM( STM );

    elsif STM.TY = DN_ACCEPT  then
      CODE_ACCEPT( STM );

    elsif STM.TY = DN_TERMINATE  then
      CODE_TERMINATE( STM );

    elsif STM.TY = DN_ABORT  then
      CODE_ABORT( STM );

    elsif STM.TY in CLASS_CLAUSES_STM  then
      CODE_CLAUSES_STM( STM );

    elsif STM.TY in CLASS_BLOCK_LOOP  then
      CODE_BLOCK_LOOP( STM );

    elsif STM.TY in CLASS_ENTRY_STM  then
      CODE_ENTRY_STM( STM );

    elsif STM.TY in CLASS_STM_WITH_NAME  then
      CODE_STM_WITH_NAME( STM );

    elsif STM.TY in CLASS_STM_WITH_EXP  then
      CODE_STM_WITH_EXP( STM );

    else
      CODI.TROU( "CODE_STM", STM );									--| vague 3 : dispatch muet (fossile n 115)

    end if;

  end	CODE_STM;
	--====--


			------------
  procedure		CODE_LABELED		( LABELED :TREE )
  is			------------

    LBL_SEQ	: SEQ_TYPE	:= LIST( D( AS_SOURCE_NAME_S, LABELED ) );
    LBL_ID	: TREE;

  begin
    while  not IS_EMPTY( LBL_SEQ )  loop
      POP( LBL_SEQ, LBL_ID );
      declare
        E		: CODI.GOTO_LBL_IDX := CODI.GOTO_LABEL_ENTRY( LBL_ID );
        LX_STR	:constant STRING	:= LABEL_STR( CODI.GOTO_LABELS( E ).LBL );
        HAS_STUB	: BOOLEAN		:= FALSE;
      begin
        if  CODI.GOTO_LABELS( E ).DEFINED  then						-- sem garantit l'unicite (LRM 5.1) ;
	PUT_LINE( "; !!! CODE_LABELED : etiquette emise deux fois" );			-- ceinture bruyante (piege n 53)
	raise PROGRAM_ERROR;
        end if;

			-- 1. y a-t-il des raccords a poser (gotos en avant inter-niveaux) ?
        for  I in CODI.GOTO_PEND_BASE + 1 .. CODI.GOTO_PEND_TOP  loop
	if  CODI.GOTO_PENDING( I ).TARGET = LBL_ID
	  and then  CODI.GOTO_PENDING( I ).LEVEL /= CODI.CUR_LEVEL
	then
	  HAS_STUB := TRUE;
	end if;
        end loop;

        if  HAS_STUB  then								-- la chute normale saute les raccords
	PUT_LINE( tab & "BRA" & tab & LX_STR );
        end if;

			-- 2. raccords inter-niveaux : EXC_POP d'apres la PHOTO prise au
			--    site du goto (les blocs traverses sont refermes ici), puis
			--    UNLINK par niveau (piege n 69), puis BRA vers l'etiquette.
        for  I in CODI.GOTO_PEND_BASE + 1 .. CODI.GOTO_PEND_TOP  loop
	if  CODI.GOTO_PENDING( I ).TARGET = LBL_ID
	  and then  CODI.GOTO_PENDING( I ).LEVEL /= CODI.CUR_LEVEL
	then
	  if  CODI.GOTO_PENDING( I ).LEVEL < CODI.CUR_LEVEL  then				-- goto ENTRANT dans un bloc :
	    PUT_LINE( "; !!! CODE_LABELED : goto en avant vers un niveau plus profond" );	-- illegal (LRM 5.9), sem le refuse ;
	    raise PROGRAM_ERROR;							-- ceinture bruyante (piege n 53)
	  end if;
	  PUT_LINE( LABEL_STR( CODI.GOTO_PENDING( I ).LBL_G ) & ':' );
	  for  L in reverse CODI.CUR_LEVEL + 1 .. CODI.GOTO_PENDING( I ).LEVEL  loop
	    if  CODI.GOTO_PENDING( I ).CTX( L )  then  CODI.EXC_POP;  end if;
	    PUT_LINE( tab & "UNLINKR" & LEVEL_NUM'IMAGE( L ) );
	  end loop;
	  PUT_LINE( tab & "BRA" & tab & LX_STR );
	  CODI.GOTO_PENDING( I ).TARGET := TREE_VOID;					-- raccord resolu
	end if;
        end loop;

			-- 3. gotos en avant de MEME niveau : etiquette vide, chute vers Lx
        for  I in CODI.GOTO_PEND_BASE + 1 .. CODI.GOTO_PEND_TOP  loop
	if  CODI.GOTO_PENDING( I ).TARGET = LBL_ID  then
	  PUT_LINE( LABEL_STR( CODI.GOTO_PENDING( I ).LBL_G ) & ':' );
	  CODI.GOTO_PENDING( I ).TARGET := TREE_VOID;					-- raccord resolu
	end if;
        end loop;

        CODI.GOTO_LABELS( E ).DEFINED := TRUE;
        CODI.GOTO_LABELS( E ).LEVEL   := CODI.CUR_LEVEL;
        PUT_LINE( LX_STR & ':' );
      end;
    end loop;

    CODE_STM( D( AS_STM, LABELED ) );									-- l'instruction etiquetee elle-meme

  end	CODE_LABELED;
	------------

			-------------
  procedure		CODE_NULL_STM		( NULL_STM :TREE )
  is			-------------
  begin
    null;												--| INTENTIONNEL : le null Ada, aucun code a emettre
  end	CODE_NULL_STM;
	-------------

			-----------
  procedure		CODE_ACCEPT		( ADA_ACCEPT :TREE )
  is			-----------
  begin
    CODI.TROU( "CODE_ACCEPT (tasking hors perimetre)", ADA_ACCEPT );						--| vague 3 : corps vide, l'instruction etait avalee

  end	CODE_ACCEPT;
	-----------

			--------------
  procedure		CODE_TERMINATE		( ADA_TERMINATE :TREE )
  is			--------------
  begin
    CODI.TROU( "CODE_TERMINATE (tasking hors perimetre)", ADA_TERMINATE );					--| vague 3 : corps vide, l'instruction etait avalee

  end	CODE_TERMINATE;
	--------------

			----------
  procedure		CODE_ABORT		( ADA_ABORT :TREE )
  is			----------
  begin
    CODI.TROU( "CODE_ABORT (tasking hors perimetre)", ADA_ABORT );					--| vague 3 : corps vide, l'instruction etait avalee

  end	CODE_ABORT;
	----------

			----------------
  procedure		CODE_CLAUSES_STM		( CLAUSES_STM :TREE )
  is			----------------
  begin
    if CLAUSES_STM.TY = DN_IF
    then
      CODE_IF( CLAUSES_STM );

    elsif CLAUSES_STM.TY = DN_SELECTIVE_WAIT
    then
      CODE_SELECTIVE_WAIT( CLAUSES_STM );

    else
      CODI.TROU( "CODE_CLAUSES_STM", CLAUSES_STM );						--| vague 3, HORS LISTE triage : dispatch muet
    end if;

  end	CODE_CLAUSES_STM;
	----------------

			-------
  procedure		CODE_IF			( ADA_IF :TREE )
  is
    POST_IF_LBL	:constant STRING	:= NEW_LABEL;
  begin
    if  CODI.DEBUG  then PUT( tab50 & "; debut if" ); end if;
    NEW_LINE;
    CODE_TEST_CLAUSE_ELEM_S( D( AS_TEST_CLAUSE_ELEM_S, ADA_IF ), POST_IF_LBL );
    CODE_STM_S( D( AS_STM_S, ADA_IF ) );								-- partie else
    PUT( POST_IF_LBL & ':' );
    if  CODI.DEBUG  then PUT( tab50 & "; post if" ); end if;
    NEW_LINE;

  end	CODE_IF;
	-------


			-----------------------
  procedure		CODE_SELECT_ALTERNATIVE	( SELECT_ALTERNATIVE :TREE )
  is			-----------------------
  begin
    CODI.TROU( "CODE_SELECT_ALTERNATIVE (tasking hors perimetre)", SELECT_ALTERNATIVE );			--| vague 3 : corps vide, l'instruction etait avalee

  end	CODE_SELECT_ALTERNATIVE;
	-----------------------

		-----------------------
  procedure	CODE_TEST_CLAUSE_ELEM_S	( TEST_CLAUSE_ELEM_S :TREE; STM_END_LBL :STRING )
  is		-----------------------
    TEST_CLAUSE_ELEM_SEQ	: SEQ_TYPE	:= LIST( TEST_CLAUSE_ELEM_S );
    TEST_CLAUSE_ELEM	: TREE;
  begin
    while  not IS_EMPTY( TEST_CLAUSE_ELEM_SEQ )  loop
      POP( TEST_CLAUSE_ELEM_SEQ, TEST_CLAUSE_ELEM );

      if  TEST_CLAUSE_ELEM.TY = DN_COND_CLAUSE  then
        CODE_COND_CLAUSE( TEST_CLAUSE_ELEM, STM_END_LBL );

      elsif  TEST_CLAUSE_ELEM.TY = DN_SELECT_ALTERNATIVE  then
        CODE_SELECT_ALTERNATIVE ( TEST_CLAUSE_ELEM );

      elsif  TEST_CLAUSE_ELEM.TY = DN_SELECT_ALT_PRAGMA  then
        CODE_SELECT_ALT_PRAGMA( TEST_CLAUSE_ELEM );

      else
        CODI.TROU( "CODE_TEST_CLAUSE_ELEM_S", TEST_CLAUSE_ELEM );						--| vague 3, HORS LISTE triage : dispatch muet
      end if;
    end loop;

  end	CODE_TEST_CLAUSE_ELEM_S;
	-----------------------


			----------------
  procedure		CODE_COND_CLAUSE		( COND_CLAUSE :TREE; STM_END_LBL :STRING )
  is
  begin
    declare
      EXP			: TREE		:= D( AS_EXP, COND_CLAUSE );
      NEXT_CLAUSE_LBL	:constant STRING	:= NEW_LABEL;
    begin
      EXPRESSIONS.CODE_EXP( EXP );									-- Expression booleenne de decision
      PUT_LINE( tab & "BF" & tab & NEXT_CLAUSE_LBL );
      INSTRUCTIONS.CODE_STM_S( D( AS_STM_S, COND_CLAUSE ) );
      PUT_LINE( tab & "BRA" & tab & STM_END_LBL );
      PUT_LINE( NEXT_CLAUSE_LBL & ':' );
    end;

  end	CODE_COND_CLAUSE;
	----------------


			-------------------
  procedure		CODE_SELECTIVE_WAIT		( SELECTIVE_WAIT :TREE )
  is			-------------------
  begin
    CODI.TROU( "CODE_SELECTIVE_WAIT (tasking hors perimetre)", SELECTIVE_WAIT );				--| vague 3 : corps vide, l'instruction etait avalee

  end	CODE_SELECTIVE_WAIT;
	-------------------


			---------------
  procedure		CODE_BLOCK_LOOP		( BLOCK_LOOP :TREE )
  is			---------------
  begin

    if BLOCK_LOOP.TY = DN_LOOP
    then
      CODE_LOOP( BLOCK_LOOP );

    elsif BLOCK_LOOP.TY = DN_BLOCK
    then
      CODE_BLOCK( BLOCK_LOOP );

    else
      CODI.TROU( "CODE_BLOCK_LOOP", BLOCK_LOOP );								--| vague 3, HORS LISTE triage : dispatch muet
    end if;
  end	CODE_BLOCK_LOOP;
	---------------


				---------
  procedure			CODE_LOOP			( ADA_LOOP :TREE )
  is
    LOOP_STM_S		: TREE		:= D( AS_STM_S,	  ADA_LOOP );
    LOOP_NAME_ID		: TREE		:= D( AS_SOURCE_NAME, ADA_LOOP );
    ITERATION		: TREE		:= D( AS_ITERATION,	  ADA_LOOP );
    LOOP_LBL_STR		:constant STRING	:= PRINT_NAME( D( LX_SYMREP, LOOP_NAME_ID ) );
    AFTER_LOOP_LBL		: LABEL_TYPE	:= NEW_LABEL;
    AFTER_LOOP_LBL_STR	:constant STRING	:= LABEL_STR( AFTER_LOOP_LBL );
  begin
    DI( CD_AFTER_LOOP, ADA_LOOP, INTEGER( AFTER_LOOP_LBL ) );
    DI( CD_LEVEL,	   ADA_LOOP, INTEGER( CODI.CUR_LEVEL ) );

--
--				SIMPLE BOUCLE
--
    if  ITERATION = TREE_VOID  then
      PUT_LINE( LOOP_LBL_STR & ':' );
      CODE_STM_S( LOOP_STM_S );
      PUT_LINE( tab & "BRA" & tab & LOOP_LBL_STR );

--
--				BOUCLE WHILE
--
    elsif  ITERATION.TY = DN_WHILE  then
      PUT_LINE( LOOP_LBL_STR & ':' );
      EXPRESSIONS.CODE_EXP( D( AS_EXP, ITERATION ) );
      PUT_LINE( tab & "BF" & tab & LABEL_STR( AFTER_LOOP_LBL ) );
      CODE_STM_S( LOOP_STM_S );
      PUT_LINE( tab & "BRA" & tab & LOOP_LBL_STR );

    elsif  ITERATION.TY in CLASS_FOR_REV  then

				FOR_OR_REVERSE_LOOP:

      declare
        ITERATION_ID	: TREE		:= D( AS_SOURCE_NAME, ITERATION );
        ITERATION_RANGE	: TREE		:= D( AS_DISCRETE_RANGE, ITERATION );
        ITERATION_TYPE	: TREE		:= D( SM_OBJ_TYPE, ITERATION_ID );
        TYPE_CHAR		: CHARACTER	:= OPER_SIZ_CHAR( ITERATION_TYPE );
        ITERATION_ID_STR	:constant STRING	:= PRINT_NAME( D( LX_SYMREP, ITERATION_ID ) );
        ITERATION_ID_TAG	: LABEL_TYPE	:= NEW_LABEL;
        ITERATION_ID_VARSTR	:constant STRING	:= ITERATION_ID_STR & LABEL_STR( ITERATION_ID_TAG ) & "_disp";
        LVL		: LEVEL_NUM	renames CODI.CUR_LEVEL;
        LVL_STR		:constant STRING	:= INTEGER'IMAGE( LVL );
      begin
        DI( CD_LEVEL,  ITERATION_ID, LVL );
        DI( CD_OFFSET, ITERATION_ID, INTEGER( ITERATION_ID_TAG ) );

        PUT( "VAR" & tab & ITERATION_ID_VARSTR & ", " & TYPE_CHAR );
        if  CODI.DEBUG  then PUT( tab50 & "; compteur boucle " & LOOP_LBL_STR); end if;
        NEW_LINE;

        if  ITERATION_RANGE = TREE_VOID  then
	ITERATION_RANGE := D( SM_RANGE, D( SM_OBJ_TYPE, ITERATION_ID ) );
        end if;

        EXPRESSIONS.CODE_DISCRETE_RANGE_BOUND( ITERATION_RANGE, IS_LAST => FALSE );
        PUT_LINE( tab & "S" & TYPE_CHAR & ' ' & LVL_STR & ',' & tab & ITERATION_ID_VARSTR );

        PUT( "VAR" & tab & "LMT_" & ITERATION_ID_VARSTR & ", " & TYPE_CHAR );
        if  CODI.DEBUG  then PUT( tab50 & "; limite boucle " & LOOP_LBL_STR); end if;
        NEW_LINE;

        EXPRESSIONS.CODE_DISCRETE_RANGE_BOUND( ITERATION_RANGE, IS_LAST => TRUE );
        PUT_LINE( tab & "S" & TYPE_CHAR & ' ' & LVL_STR & ',' & tab & "LMT_" & ITERATION_ID_VARSTR );

--			VERIFIER POUR NULL RANGE

        PUT( tab & OPER_LOAD_STR( ITERATION_TYPE ) & ' ' & LVL_STR & ',' & tab & ITERATION_ID_VARSTR );
        if  CODI.DEBUG  then
	PUT( tab50 & "; test null range " & LOOP_LBL_STR );
        end if;
        NEW_LINE;
        PUT_LINE( tab & OPER_LOAD_STR( ITERATION_TYPE ) & ' ' & LVL_STR
		& ',' & tab & "LMT_" & ITERATION_ID_VARSTR );
        PUT_LINE( tab & "CGT" );
        PUT_LINE( tab & "BT" & tab & AFTER_LOOP_LBL_STR );

--			INVERSER CNT LMT POUR REVERSE

        if  ITERATION.TY = DN_REVERSE  then
	PUT( tab & OPER_LOAD_STR( ITERATION_TYPE ) & ' ' & LVL_STR & ',' & tab & ITERATION_ID_VARSTR );
	if  CODI.DEBUG  then
	  PUT( tab50 & "; inversion range " & LOOP_LBL_STR );
	end if;
	NEW_LINE;
	PUT_LINE( tab & OPER_LOAD_STR( ITERATION_TYPE ) & ' ' & LVL_STR & ',' & tab & "LMT_" & ITERATION_ID_VARSTR );
	PUT_LINE( tab & "S" & TYPE_CHAR & ' ' & LVL_STR & ',' & tab & ITERATION_ID_VARSTR );
	PUT_LINE( tab & "S" & TYPE_CHAR & ' ' & LVL_STR & ',' & tab & "LMT_" & ITERATION_ID_VARSTR );
        end if;

--			DEBUT ET CORPS DE BOUCLE

        PUT( LOOP_LBL_STR & ':' );
        if  CODI.DEBUG  then
	PUT( tab50 & "; corps boucle " & LOOP_LBL_STR );
        end if;
        NEW_LINE;
        CODE_STM_S ( LOOP_STM_S );

--			TEST DE SORTIE

        PUT( tab & OPER_LOAD_STR( ITERATION_TYPE ) & ' ' & LVL_STR & ',' & tab & ITERATION_ID_VARSTR );
        if  CODI.DEBUG  then
	PUT( tab50 & "; test de sortie " & LOOP_LBL_STR );
        end if;
        NEW_LINE;
        PUT_LINE( tab & OPER_LOAD_STR( ITERATION_TYPE ) & ' ' & LVL_STR
		& ',' & tab & "LMT_" & ITERATION_ID_VARSTR );
        PUT_LINE( tab & "CEQ" );
        PUT_LINE( tab & "BT" & tab & AFTER_LOOP_LBL_STR );

--			MISE A JOUR DU COMPTEUR

        PUT( tab & OPER_LOAD_STR( ITERATION_TYPE ) & ' ' & LVL_STR & ',' & tab & ITERATION_ID_VARSTR );
        if  CODI.DEBUG  then
	PUT( tab50 & "; mise a jour compteur " & LOOP_LBL_STR );
        end if;
        NEW_LINE;

        if  ITERATION.TY = DN_FOR  then
	PUT_LINE( tab & "INC" );

        elsif  ITERATION.TY = DN_REVERSE  then
	PUT_LINE( tab & "DEC" );

        else
	CODI.TROU( "FOR_OR_REVERSE_LOOP iteration", ITERATION );						--| vague 3, HORS LISTE : sans INC/DEC la boucle
												--| generee serait INFINIE en silence
        end if;
        PUT_LINE( tab & "S" & TYPE_CHAR & ' ' & LVL_STR & ',' & tab & ITERATION_ID_VARSTR );

        PUT( tab & "BRA" & tab & LOOP_LBL_STR );
        if  CODI.DEBUG  then
	PUT( tab50 & "; iteration suivante " & LOOP_LBL_STR );
        end if;
        NEW_LINE;

      end			FOR_OR_REVERSE_LOOP;
			-------------------
    end if;

    PUT( AFTER_LOOP_LBL_STR & ':' );
    if  CODI.DEBUG  then
      PUT( tab50 & "; post loop " & LOOP_LBL_STR );
    end if;
    NEW_LINE;

  end	CODE_LOOP;
	---------


			----------
  procedure		CODE_BLOCK		( BLOCK :TREE )
  is
    LOOP_NAME_ID	: TREE		:= D( AS_SOURCE_NAME, BLOCK );
    PROC_LBL	:constant STRING	:= PRINT_NAME( D( LX_SYMREP, LOOP_NAME_ID ) );
  begin
    PUT_LINE( "namespace" & tab &  PROC_LBL );
    INC_LEVEL;
    STRUCTURES.CODE_BLOCK_BODY( D( AS_BLOCK_BODY, BLOCK ) );
    PUT_LINE( tab & "UNLINKR" & LEVEL_NUM'IMAGE( CODI.CUR_LEVEL ) );						-- RESTAURER LE DISPLAY, LA PILE ET LA CO-PILE APRES LE BLOC (n 163)
    DEC_LEVEL;
    PUT_LINE( "endPRO" );										-- POUR CALCUL DU LOC_SIZ AVANT FERMETURE DU NAMESPACE

  end	CODE_BLOCK;
	----------


			--------------
  procedure		CODE_ENTRY_STM		( ENTRY_STM :TREE )
  is			--------------
  begin

    if  ENTRY_STM.TY = DN_COND_ENTRY  then
      CODE_COND_ENTRY ( ENTRY_STM );

    elsif  ENTRY_STM.TY = DN_TIMED_ENTRY  then
      CODE_TIMED_ENTRY ( ENTRY_STM );

    else
      CODI.TROU( "CODE_ENTRY_STM", ENTRY_STM );								--| vague 3, HORS LISTE triage : dispatch muet
    end if;
  end	CODE_ENTRY_STM;
	--------------


			---------------
  procedure		CODE_COND_ENTRY		( COND_ENTRY :TREE )
  is			---------------
  begin
    CODI.TROU( "CODE_COND_ENTRY (tasking hors perimetre)", COND_ENTRY );					--| vague 3 : corps vide, l'instruction etait avalee
  end	CODE_COND_ENTRY;
	---------------


			----------------
  procedure		CODE_TIMED_ENTRY		( TIMED_ENTRY :TREE )
  is			----------------
  begin
    CODI.TROU( "CODE_TIMED_ENTRY (tasking hors perimetre)", TIMED_ENTRY );					--| vague 3 : corps vide, l'instruction etait avalee
  end	CODE_TIMED_ENTRY;
	----------------

			------------------
  procedure		CODE_STM_WITH_NAME		( STM_WITH_NAME :TREE )
  is			------------------
  begin
    if  STM_WITH_NAME.TY = DN_GOTO  then
      CODE_GOTO( STM_WITH_NAME );

    elsif  STM_WITH_NAME.TY = DN_RAISE  then
      CODE_RAISE( STM_WITH_NAME );

    elsif  STM_WITH_NAME.TY in CLASS_CALL_STM  then
      CODE_CALL_STM( STM_WITH_NAME );

    else
      CODI.TROU( "CODE_STM_WITH_NAME", STM_WITH_NAME );						--| vague 3 : dispatch muet (fossile n 115)
    end if;
  end	CODE_STM_WITH_NAME;
	------------------


			---------
  procedure		CODE_GOTO			( ADA_GOTO :TREE )
  is			---------

    TARGET	: TREE	:= D( AS_NAME, ADA_GOTO );

  begin
    if  TARGET.TY /= DN_LABEL_ID  then
      TARGET := D( SM_DEFN, TARGET );							-- forme du dump GOTO_DUMP :
    end if;										-- DN_USED_NAME_ID -> SM_DEFN -> DN_LABEL_ID
    if  TARGET.TY /= DN_LABEL_ID  then
      PUT_LINE( "; !!! CODE_GOTO : cible non resolue " & NODE_NAME'IMAGE( TARGET.TY ) );		-- refus bruyant (piege n 53)
      raise PROGRAM_ERROR;
    end if;

    declare
      E	: CODI.GOTO_LBL_IDX := CODI.GOTO_LABEL_ENTRY( TARGET );
    begin
      if  CODI.GOTO_LABELS( E ).DEFINED  then						-- GOTO ARRIERE : deniveler ICI, forme de
        for  L in reverse CODI.GOTO_LABELS( E ).LEVEL + 1 .. CODI.CUR_LEVEL  loop			-- CODE_EXIT (pieges n 69 et 34)
	if  CODI.HANDLER_CTX_AT( L )  then  CODI.EXC_POP;  end if;				-- pop des blocs proteges traverses
	PUT_LINE( tab & "UNLINK" & LEVEL_NUM'IMAGE( L ) );
        end loop;
        PUT_LINE( tab & "BRA" & tab & LABEL_STR( CODI.GOTO_LABELS( E ).LBL ) );

      else										-- GOTO AVANT : BRA vers le RACCORD propre a
        if  CODI.GOTO_PEND_TOP = MAX_GOTO_LABELS  then					-- ce goto ; le denivele sera emis par
	PUT_LINE( "; !!! CODE_GOTO : table des raccords pleine" );				-- CODE_LABELED qui connaitra les 2 niveaux
	raise PROGRAM_ERROR;
        end if;
        CODI.GOTO_PEND_TOP := CODI.GOTO_PEND_TOP + 1;
        CODI.GOTO_PENDING( CODI.GOTO_PEND_TOP ).TARGET := TARGET;
        CODI.GOTO_PENDING( CODI.GOTO_PEND_TOP ).LBL_G  := NEW_LABEL;
        CODI.GOTO_PENDING( CODI.GOTO_PEND_TOP ).LEVEL  := CODI.CUR_LEVEL;
        for  L in LEVEL_NUM  loop								-- PHOTO des contextes au site du goto
	CODI.GOTO_PENDING( CODI.GOTO_PEND_TOP ).CTX( L ) := CODI.HANDLER_CTX_AT( L );		-- (miroir du principe d'EXC_MACH : les
        end loop;										-- blocs seront refermes a l'etiquette)
        PUT_LINE( tab & "BRA" & tab & LABEL_STR( CODI.GOTO_PENDING( CODI.GOTO_PEND_TOP ).LBL_G ) );
      end if;

    end;

  end	CODE_GOTO;
	---------


			----------
  procedure		CODE_RAISE		( ADA_RAISE :TREE )
  is
    NAME  : TREE	:= D( AS_NAME, ADA_RAISE );
  begin
    if  NAME = TREE_VOID  then									-- raise; nu (LRM 11.3) -- forme confirmee au dump E-C
      if  CODI.HANDLER_LVL < 0  then
        PUT_LINE( "ANOMALIE : raise nu hors handler" );							--| DEFAUT DOCUMENTE (vague 5) : ceinture d'impossible
												--| (sem le garantit), bruyante non fatale
      else
        PUT_LINE( tab & "LA " & IMAGE( CODI.HANDLER_LVL ) & ',' & tab
			& "exc_ctx_" & LABEL_STR( CODI.HANDLER_CTX_SUF ) );				-- l'exception DU handler, pas la globale
        PUT_LINE( tab & "SA" & tab & "0, STANDARD.EXCEPTIONS_CURRENT_disp" );
        PUT_LINE( tab & "BRA" & tab & "STANDARD.exc_raise_" );
      end if;

    else
      declare
        EXCEPTION_ID    : TREE  := CODI.EXCEPTION_ID_OF( NAME );						-- resout selected + renames (LRM 8.5);
      begin
        PUT( tab & "LCA" & tab );
        CODI.REGIONS_PATH( EXCEPTION_ID );
        PUT_LINE( PRINT_NAME( D( LX_SYMREP, EXCEPTION_ID ) ) & "__exc.data_ptr" );				-- l'ADRESSE fait identite
        PUT_LINE( tab & "SA" & tab & "0, STANDARD.EXCEPTIONS_CURRENT_disp" );
        PUT_LINE( tab & "BRA" & tab & "STANDARD.exc_raise_" );						-- derouler
      end;
    end if;

  end	CODE_RAISE;
	----------


			---------------
  procedure		CODE_ENTRY_CALL	( ENTRY_CALL :TREE )
  is			---------------
  begin
    CODI.TROU( "CODE_ENTRY_CALL (tasking hors perimetre)", ENTRY_CALL );					--| vague 3 : corps vide, l'appel etait avale
  end	CODE_ENTRY_CALL;
	---------------


			-------------
  procedure		CODE_CALL_STM		( CALL_STM :TREE )
  is			-------------

    NAME_ID		: TREE	:= D( AS_NAME, CALL_STM );

  begin
    while  NAME_ID.TY = DN_SELECTED  loop
      NAME_ID := D( AS_DESIGNATOR, NAME_ID );
    end loop;

    if  CALL_STM.TY = DN_PROCEDURE_CALL  then
        CODE_PROCEDURE_CALL ( CALL_STM, NAME_ID );

    elsif  CALL_STM.TY = DN_ENTRY_CALL  then
      CODE_ENTRY_CALL ( CALL_STM );

    else
      CODI.TROU( "CODE_CALL_STM", CALL_STM );							--| vague 3 : dispatch muet (fossile n 115)
    end if;

  end	CODE_CALL_STM;
	-------------

				-------------------
  procedure			CODE_PROCEDURE_CALL		( PROCEDURE_CALL :TREE; USED_NAME_ID : TREE )
  is
    NORM_ACT_PRM_S  : SEQ_TYPE	:= LIST( D( SM_NORMALIZED_PARAM_S, PROCEDURE_CALL ) );

    ORIGINE	: TREE		:= SUBPROGRAM_ORIGIN( D( SM_DEFN, USED_NAME_ID ) );
    NEGATION	:constant BOOLEAN	:= D( SM_UNIT_DESC, ORIGINE ).TY = DN_IMPLICIT_NOT_EQ;		--| "/=" implicite : appel du "=", puis NOT
    PROC_ID	: TREE		:= ORIGINE_EGALITE( ORIGINE );
    SUB_NAME	:constant STRING	:= LETTERED_SUBNAME( PRINT_NAME( D( LX_SYMREP, PROC_ID ) ) );
    LBL		: LABEL_TYPE	:= LABEL_TYPE( DI( CD_LABEL, PROC_ID ) );

    SPEC_PRM_GRP_S  : SEQ_TYPE	:= LIST( D( AS_PARAM_S, D( SM_SPEC, PROC_ID) ) );
    FRM_PRM_GRP	: TREE;
    SPEC_PRM_ID_S	: SEQ_TYPE;

    MAX_COPIES	:constant	:= 64;									--| LRM 6.2 : scalaires et acces out / in out PAR
    type T_COPIE	is record									--| COPIE, cote appelant (note conception_copie_
		  FRM, ACT	: TREE;								--| parametres) : l'appele recoit l'adresse d'une
		  LBL		: LABEL_TYPE;							--| cellule __CP<n> ; __CA<n> garde l'adresse de
		end record;									--| l'actuel pour la recopie au retour normal
    COPIES	: array( 1 .. MAX_COPIES ) of T_COPIE;
    NB_COPIES	: NATURAL	:= 0;


		---------------------
    function	IS_IN_CURRENT_GENERIC	( ID : TREE ) return BOOLEAN
    is		---------------------
      REGION : TREE := ID;
    begin
      if  not CODI.IN_GENERIC_BODY  then
        return FALSE;
      end if;

      while  REGION /= TREE_VOID  loop
        if  REGION = CODI.ENCLOSING_GENERIC  then
	return TRUE;
        end if;

        exit when REGION = TREE_VOID;

        REGION := D( XD_REGION, REGION );
      end loop;
      return FALSE;

    end	IS_IN_CURRENT_GENERIC;
	---------------------

		----------------
    function	COPIE_PAR_VALEUR	( FRM, ACT :TREE ) return BOOLEAN
    is		----------------
	-- Formel out / in out scalaire ou d'acces, actuel NOMME dont l'adresse est empilee
	-- par INVERSE_RECURSE_ON_PARAMETERS.  Hors corps generiques (lot ulterieur) ; hors
	-- conversion en actuel (sauf T (V) d'acces, deja ramene a V) ; hors renommage.
      F_TYPE	: TREE;
      DEFN	: TREE;
    begin
      if  CODI.IN_GENERIC_BODY
        or else  ( FRM.TY /= DN_OUT_ID  and then  FRM.TY /= DN_IN_OUT_ID )
      then
        return FALSE;
      end if;
      F_TYPE := CODI.FULL_TYPE_VIEW( D( SM_OBJ_TYPE, FRM ) );
      if  not ( F_TYPE.TY in CLASS_SCALAR  or else  CODI.EST_ACCES( F_TYPE ) )
        or else  EXPRESSIONS.IS_GENERIC_FORMAL_TYPE( D( XD_SOURCE_NAME, D( SM_OBJ_TYPE, FRM ) ) )
        or else  CODI.EST_SELECTION_DYNAMIQUE( ACT )
      then
        return FALSE;
      end if;
      if  ACT.TY = DN_USED_OBJECT_ID  then
        DEFN := D( SM_DEFN, ACT );
        if  DEFN.TY = DN_VARIABLE_ID  then
	return  not DB( SM_RENAMES_OBJ, DEFN );
        end if;
        return  DEFN.TY = DN_OUT_ID  or else  DEFN.TY = DN_IN_OUT_ID;
      end if;
      return  ACT.TY = DN_INDEXED  or else  ACT.TY = DN_SELECTED  or else  ACT.TY = DN_ALL;

    end	COPIE_PAR_VALEUR;
	----------------

		--------------
    function	VUE_CONTROLE	( T :TREE ) return TREE
    is		--------------
	-- Vue a CONTROLER : la vue privee est percee, mais un sous-type d'acces contraint
	-- reste tel quel (FULL_TYPE_VIEW le ramenerait a sa base, sans contrainte).
    begin
      if  T.TY = DN_PRIVATE  or else  T.TY = DN_L_PRIVATE  then
        return  CODI.FULL_TYPE_VIEW( T );
      end if;
      return  T;

    end	VUE_CONTROLE;
	--------------

		----------------
    function	SOUS_TYPE_ACTUEL	( ACT :TREE ) return TREE
    is		----------------
	-- Sous-type de l'actuel, contre lequel la valeur rendue est controlee (LRM 6.4.1).
    begin
      if  ACT.TY = DN_USED_OBJECT_ID  then
        return  VUE_CONTROLE( D( SM_OBJ_TYPE, D( SM_DEFN, ACT ) ) );
      end if;
      return  VUE_CONTROLE( D( SM_EXP_TYPE, ACT ) );

    end	SOUS_TYPE_ACTUEL;
	----------------

			-----------------------------
    procedure		INVERSE_RECURSE_ON_PARAMETERS
    is			-----------------------------
      ACT_PRM	: TREE;
      FRM_PRM_ID	: TREE;
      COPIE	: BOOLEAN	:= FALSE;							--| actuel passe par COPIE (cellule __CP<n>)

		------------------------------
      procedure	WRAP_COMPOSITE_ACTUAL_DOUBLET		( FRM_PRM_ID, ACT_PRM :TREE )
      is		------------------------------
      -- A appeler juste APRES CODE_EXP( ACT_PRM ) quand celui-ci laisse
      -- une @data nue.  Ne fait rien si le formel n'est pas composite.
        FRM_TYPE	: TREE	:= CODI.FULL_TYPE_VIEW( D( SM_OBJ_TYPE, FRM_PRM_ID ) );
      begin
        if  FRM_TYPE.TY = DN_CONSTRAINED_RECORD  then
	FRM_TYPE := D( SM_BASE_TYPE, FRM_TYPE );				-- pilier 3.7 : use__info de la base
        end if;

        if  FRM_TYPE.TY /= DN_RECORD
	and then  FRM_TYPE.TY /= DN_CONSTRAINED_ARRAY
	and then  FRM_TYPE.TY /= DN_ARRAY
        then
	return;								-- scalaire / access : rvalue deja correcte
        end if;

        declare
	ANON	:constant STRING	:= ANONYMOUS_NAME_AT( ACT_PRM ) & "_dbl_" & NEW_LABEL;
	TYPE_NAME : TREE		:= D( XD_SOURCE_NAME, FRM_TYPE );
	TN_STR	:constant STRING	:= TYPE_INFO_STR( FRM_TYPE );
	LVL_STR	:constant STRING	:= IMAGE( CODI.CUR_LEVEL );
        begin
	-- doublet = 2 qwords ADJACENTS (meme motif que TTR_disp/TTR__u)
	PUT_LINE( "VAR" & tab & ANON & "_disp, q" );
	PUT_LINE( "VAR" & tab & ANON & "__u,   q" );

	PUT_LINE( tab & "SA  " & LVL_STR & ", " & ANON & "_disp" );		-- consomme l'@element de CODE_EXP
	PUT( tab & "LA  " & IMAGE( DI( CD_LEVEL, FRM_TYPE ) ) & ", " );
	CODI.REGIONS_PATH( TYPE_NAME );
	PUT_LINE( TN_STR & ".use__info" );
	PUT_LINE( tab & "SA  " & LVL_STR & ", " & ANON & "__u" );

	PUT_LINE( tab & "LVA " & LVL_STR & ", " & ANON & "_disp" );		-- @doublet, a la place de l'@data
        end;
      end WRAP_COMPOSITE_ACTUAL_DOUBLET;
	------------------------------

   begin

      while  not IS_EMPTY( NORM_ACT_PRM_S )  loop

        if  IS_EMPTY( SPEC_PRM_ID_S )  then
	POP( SPEC_PRM_GRP_S, FRM_PRM_GRP );
	SPEC_PRM_ID_S := LIST( D( AS_SOURCE_NAME_S, FRM_PRM_GRP ) );
        end if;
        POP( SPEC_PRM_ID_S, FRM_PRM_ID );
        POP( NORM_ACT_PRM_S, ACT_PRM );

        INVERSE_RECURSE_ON_PARAMETERS;

        if  FRM_PRM_ID.TY /= DN_IN_ID
	and then  ACT_PRM.TY = DN_CONVERSION
	and then  D( AS_EXP, ACT_PRM ).TY = DN_USED_OBJECT_ID
	and then  CODI.EST_ACCES( CODI.FULL_TYPE_VIEW( D( SM_OBJ_TYPE, FRM_PRM_ID ) ) )
        then											--| out / in out : T (V), T et V d'acces (meme
	ACT_PRM := D( AS_EXP, ACT_PRM );							--| representation) : passer V PAR REFERENCE ;
        end if;											--| contraintes : avant / au retour (6.4.1)

        if  CODI.EST_SELECTION_DYNAMIQUE( ACT_PRM )  then						--| option B : doublet {donnees, descripteur}
	EXPRESSIONS.CODE_DOUBLET_DYNAMIQUE( ACT_PRM, "SELARG_" & NEW_LABEL );			--| (par reference, tout mode)

        elsif  ACT_PRM.TY = DN_ALL
	and then  CODI.EST_ACCES_TABLEAU_NC( D( SM_EXP_TYPE, D( AS_NAME, ACT_PRM ) ) )
        then											--| Q1b : doublet ( @donnees, en-tete ),
	EXPRESSIONS.CODE_ARRAY_OPERAND( ACT_PRM, "ALLARG_" & NEW_LABEL,				--| par reference, tout mode
				  CODI.TABLEAU_DESIGNE( D( SM_EXP_TYPE, D( AS_NAME, ACT_PRM ) ) ) );

        elsif  ACT_PRM.TY = DN_SELECTED  or else ACT_PRM.TY = DN_ALL  then

	declare
	  ACT_TYPE	: TREE	:= D( SM_EXP_TYPE, ACT_PRM );
	begin
	  while  ACT_TYPE.TY = DN_PRIVATE  or else  ACT_TYPE.TY = DN_L_PRIVATE  loop
	    ACT_TYPE := D( SM_TYPE_SPEC, ACT_TYPE );
	  end loop;

	  while  ACT_TYPE.TY = DN_CONSTRAINED_RECORD							--| lot 31 : remede annonce ci-dessous --
	    and then  CODI.EST_RECORD_DYNAMIQUE( ACT_TYPE )						--| use__info de la BASE dans le doublet
	  loop											--| (composant record dynamique contraint)
	    ACT_TYPE := CODI.FULL_TYPE_VIEW( D( SM_BASE_TYPE, ACT_TYPE ) );
	  end loop;

	  if  ACT_TYPE.TY = DN_CONSTRAINED_RECORD  then
			--| Vague 2 (n 112, dette commune SELARG/INDARG) : vue contrainte
			--| absente du test composite -- l'actuel serait retombe dans la
			--| branche scalaire (adresse seule, pas de doublet).  Refus
			--| bruyant ; remede le jour du temoin : use__info de la BASE
			--| (pilier 3.7) dans le doublet SELARG.
	    CODI.TROU( "SELARG actuel selecte de vue record contrainte", ACT_TYPE );

	  elsif  ACT_TYPE.TY = DN_ARRAY  or else  ACT_TYPE.TY = DN_CONSTRAINED_ARRAY  or  else ACT_TYPE.TY = DN_RECORD
	  then
	    declare
	      ANON	:constant STRING	:= "SELARG_" & NEW_LABEL;
	      LVL_STR	:constant STRING	:= IMAGE( CODI.CUR_LEVEL );
	      TYPE_NAME	: TREE		:= D( XD_SOURCE_NAME, ACT_TYPE );
	      TYPE_NAME_STR :constant STRING	:= '_' & PRINT_NAME( D( LX_SYMREP, TYPE_NAME ) );
	    begin
	      PUT_LINE( tab & "VAR " & ANON & "_disp, q" );
	      PUT_LINE( tab & "VAR " & ANON & "__u, q" );

		      if  ACT_PRM.TY = DN_SELECTED  then
		        EXPRESSIONS.CODE_SELECTED( ACT_PRM, IS_SOURCE => FALSE );
		      else
		        EXPRESSIONS.CODE_OBJECT_ADDRESS( ACT_PRM );
		      end if;
	      PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & ANON & "_disp" );

	      declare
	        SEL_DEFN	: TREE	:= TREE_VOID;
	        IS_ANON_COMP	: BOOLEAN	:= FALSE;
	      begin
	        if  ACT_PRM.TY = DN_SELECTED  then
		SEL_DEFN := D( SM_DEFN, D( AS_DESIGNATOR, ACT_PRM ) );
		IS_ANON_COMP := SEL_DEFN.TY = DN_COMPONENT_ID
			and then  ACT_TYPE.TY = DN_CONSTRAINED_ARRAY
			and then  D( SM_TYPE_SPEC, TYPE_NAME ) /= ACT_TYPE;
	        end if;

	        if  IS_ANON_COMP  then
		-- Segfault OPEN/GET_LINE du bootstrap (aout 2026) : composant de
		-- sous-type tableau ANONYME en actual -- XD_SOURCE_NAME remonte au
		-- patron NON contraint (SIZ=-1, pas de _FST/_LST), historiquement
		-- amorti par la greffe " namespace _STRING" supprimee au correctif
		-- record.  Viser le bloc _<comp>__type ELABORE du record (meme
		-- famille que CODE_INDEXED/CODE_SLICE) ; niveau = CD_LEVEL pose
		-- par le producteur.  Type NOMME / record / .all : chemin
		-- historique inchange ci-dessous.
		PUT( tab & "LA " & IMAGE( DI( CD_LEVEL, ACT_TYPE ) ) & ", " );
		CODI.REGIONS_PATH( SEL_DEFN );
		PUT_LINE( '_' & PRINT_NAME( D( LX_SYMREP, SEL_DEFN ) ) & "__type.use__info" );
	        elsif  SEL_DEFN /= TREE_VOID
	        and then  ( SEL_DEFN.TY = DN_VARIABLE_ID  or else  SEL_DEFN.TY = DN_CONSTANT_ID )
	        then
		-- Nom ETENDU d'objet (IDL.LIB_PATH, classif 6 aout) : reprendre le
		-- __u de l'OBJET (son info elaboree), jamais le patron du type.
		PUT( tab & "LA " & IMAGE( DI( CD_LEVEL, SEL_DEFN ) ) & ", " );
		CODI.REGIONS_PATH( SEL_DEFN );
		PUT_LINE( PRINT_NAME( D( LX_SYMREP, SEL_DEFN ) ) & "__u" );

	        else
		PUT( tab & "LA " & IMAGE( DI( CD_LEVEL, ACT_TYPE ) ) & ", " );
		CODI.REGIONS_PATH( TYPE_NAME );
		PUT_LINE( TYPE_NAME_STR & ".use__info" );
	        end if;
	      end;
	      PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & ANON & "__u" );

	      PUT_LINE( tab & "LVA " & LVL_STR & ", " & ANON & "_disp" );
	    end;

	  else
	    if  FRM_PRM_ID.TY = DN_IN_ID  and then  ACT_PRM.TY = DN_ALL  then				--| in : X.ALL scalaire ou d'acces, rvalue par
	      EXPRESSIONS.CODE_EXP( ACT_PRM );								--| CODE_EXP (CODE_SELECTED lit AS_DESIGNATOR, absent
												--| de DN_ALL : c41303o)
	    elsif  FRM_PRM_ID.TY = DN_IN_ID  then
	      EXPRESSIONS.CODE_SELECTED( ACT_PRM );							-- in : rvalue (historique)
	    else
	      EXPRESSIONS.CODE_OBJECT_ADDRESS( ACT_PRM );							-- out / in out : adresse seule
	    end if;
	  end if;
	end;

        elsif  ACT_PRM.TY = DN_USED_OBJECT_ID  then
	declare
	  DEFN		: TREE	:= D( SM_DEFN, ACT_PRM );
	  EXP_TYPE	: TREE	:= D( SM_EXP_TYPE, ACT_PRM );
	  DEFN_STR	:constant STRING	:= PRINT_NAME( D( LX_SYMREP, DEFN ) );
	begin
	  if  DEFN.TY = DN_CONSTANT_ID  then

	    while  EXP_TYPE.TY = DN_PRIVATE  or else  EXP_TYPE.TY = DN_L_PRIVATE  loop				-- n 81 ter : vue privee -> vue complete
	      EXP_TYPE := D( SM_TYPE_SPEC, EXP_TYPE );							-- (TREE_VOID et autres constantes differees
	    end loop;										-- en actuel), reflexe maison avant dispatch.

	    if EXP_TYPE.TY = DN_ENUMERATION then
	      PUT_LINE( tab & "LI" & tab & INTEGER'IMAGE( DI( SM_VALUE, ACT_PRM ) ) );

	    elsif EXP_TYPE.TY = DN_ARRAY  or else  EXP_TYPE.TY = DN_CONSTRAINED_ARRAY
	        or else  EXP_TYPE.TY = DN_RECORD  or else  EXP_TYPE.TY = DN_CONSTRAINED_RECORD  then
	      PUT( tab & "LVA" & ' ' & INTEGER'IMAGE( DI( CD_LEVEL, DEFN ) ) & ',' & tab );
	      REGIONS_PATH( DEFN );
	      PUT( DEFN_STR & "_disp" );
	      if  CODI.DEBUG  then PUT( tab50 & "; array actual" ); end if;
	      NEW_LINE;

	    elsif  EXP_TYPE.TY = DN_INTEGER  then							-- PIEGE n 81 : INTEGER/FIXED/FLOAT.
	      LOAD_MEM( DEFN );									-- Constante ELABOREE (slot _disp, cf.

	    else											-- style BRUYANT (piege n 53) : la retombee
	      PUT_LINE( "; !!! CODE_PROCEDURE_CALL : actuel constant non gere "				-- silencieuse de cette branche a coute le
		      & NODE_NAME'IMAGE( EXP_TYPE.TY ) );						-- fossile n 81 (IDENT_INT inerte).
	      raise PROGRAM_ERROR;

	    end if;

	  elsif  DEFN.TY = DN_VARIABLE_ID  then
	    if FRM_PRM_ID.TY = DN_IN_ID then
	      LOAD_MEM( DEFN );
	    else
	      if  D( SM_OBJ_TYPE, DEFN ).TY in CLASS_SCALAR  then
	        PUT( tab & "LVA" & ' ' & INTEGER'IMAGE( DI( CD_LEVEL, DEFN ) ) & ',' & tab );
	        REGIONS_PATH( DEFN );
	        PUT_LINE( DEFN_STR & "_disp" );

	      else
	        PUT( tab & "LVA" & ' ' & INTEGER'IMAGE( DI( CD_LEVEL, DEFN ) ) & ',' & tab );
	        REGIONS_PATH( DEFN );
	        PUT_LINE(  DEFN_STR & "_disp" );
	      end if;
	    end if;

	  elsif  DEFN.TY = DN_IN_ID  then								-- Appel avec un parametre entrant de la procedure englobante

	    if  not CODI.IN_GENERIC_BODY  then
	      LOAD_MEM( DEFN );									-- Parametre entree "normal" hors generique

	    else											-- On fait un appel au sein d'un generique
				-----------------------------
				PARAMETRE_ENTREE_EN_GENERIQUE:
	      declare
	        HAS_GENERIC_TYPE	: BOOLEAN
			:= EXPRESSIONS.IS_GENERIC_FORMAL_TYPE( D( XD_SOURCE_NAME, D( SM_OBJ_TYPE, DEFN ) ) );

	      begin
	        if  D( XD_REGION, DEFN ).TY /= DN_GENERIC_ID  then						-- Un parametre entree "normal"
		if  HAS_GENERIC_TYPE  then								-- Mais a type generique
		  PUT_LINE( tab & "LVA " & IMAGE( DI( CD_LEVEL, DEFN ) ) & ','
		    & tab & '-' & PRINT_NAME( D( LX_SYMREP, DEFN ) ) & "_ofs" );
		  PUT_LINE( tab & "LA" & LEVEL_NUM'IMAGE( CODI.GENERIC_BASE_LEVEL+1 ) & ',' & tab & "-GFP_ofs" );
		  PUT_LINE( tab & "LA ," & tab & '-'
			& PRINT_NAME( D( LX_SYMREP, D( XD_SOURCE_NAME, D( SM_OBJ_TYPE, DEFN ) ) ) )
			& "__ld_ofs" );
		  PUT_LINE( tab & "CALLI" );

		else										-- Mais a type non generique
		  LOAD_MEM( DEFN );
		end if;

	        else										-- Un objet formel generique en entree
		LOAD_MEM( DEFN );
	        end if;
	      end		PARAMETRE_ENTREE_EN_GENERIQUE;
			-----------------------------
	    end if;

	  elsif  DEFN.TY = DN_OUT_ID  or  DEFN.TY = DN_IN_OUT_ID  then					-- Param out/in_out de la procedure englobante
	    if  FRM_PRM_ID.TY = DN_IN_ID  then
	      declare
	        OBJ_TYPE	: TREE	:= D( SM_OBJ_TYPE, DEFN );
	      begin
	        if  OBJ_TYPE.TY = DN_PRIVATE  or  OBJ_TYPE.TY = DN_L_PRIVATE  then
		OBJ_TYPE := D( SM_TYPE_SPEC, OBJ_TYPE );
	        end if;

	        if  OBJ_TYPE.TY in CLASS_SCALAR  or else  CODI.EST_ACCES( OBJ_TYPE )  then
	      -- out/inout -> in scalaire : dereferencement, charger la valeur pointee
		  PUT_LINE( tab & OPER_LOADI_STR( OBJ_TYPE ) & ' ' & INTEGER'IMAGE( DI( CD_LEVEL, DEFN ) ) & ',' & tab
			& '-' & DEFN_STR & "_ofs" );
	        else
	      -- out/inout -> in composite : le slot contient deja l'adresse, la propager
		PUT_LINE( tab & "LA " & INTEGER'IMAGE( DI( CD_LEVEL, DEFN ) ) & ',' & tab
			& '-' & DEFN_STR & "_ofs" );
	        end if;
	      end;
	    else
	      -- out/inout -> out/inout : propager l'adresse
	      PUT_LINE( tab & "LA " & INTEGER'IMAGE( DI( CD_LEVEL, DEFN ) ) & ',' & tab
		      & '-' & DEFN_STR & "_ofs" );
	    end if;

	  elsif  DEFN.TY = DN_ITERATION_ID  then		     -- Variable de boucle for
	    declare
	      ITERATION_ID_STR	: constant STRING	:= PRINT_NAME( D( LX_SYMREP, DEFN ) );
	      ITERATION_ID_TAG	: LABEL_TYPE	:= LABEL_TYPE( DI( CD_OFFSET, DEFN ) );
	      ITERATION_ID_VARSTR	: constant STRING	:= ITERATION_ID_STR
						& LABEL_STR( ITERATION_ID_TAG ) & "_disp";

	    begin
	      PUT_LINE( tab & OPER_LOAD_STR( D( SM_OBJ_TYPE, DEFN ) ) & ' '
			& INTEGER'IMAGE( DI( CD_LEVEL, DEFN ) ) & ','
			& tab & ITERATION_ID_VARSTR );
	    end;

	  elsif  DEFN.TY = DN_ENUMERATION_ID  then							-- Appel avec un énuméré
	    PUT_LINE( tab & "LI" & ' ' & INTEGER'IMAGE( DI( SM_REP, DEFN ) ) );				--| Reclassement n 3 : SM_POS -> SM_REP, alignement sur
												--| la convention valeur (expressions:368, pliage bornes).
												--| Divergence relevee par l'audit n 117 de seance ;
												--| rep = pos sur tout le corpus actuel -> diff FINC vide.

	  elsif  DEFN.TY = DN_COMPONENT_ID  then							-- Appel avec une composante
			--| Vague 3, DECOUVERTE : ce site emettait un "LI " SANS
			--| OPERANDE -- ligne FINC cassee, erreur d'assemblage
			--| differee au lieu d'un signal au site.
	    CODI.TROU( "INVERSE_RECURSE_ON_PARAMETERS actuel DN_COMPONENT_ID (LI sans operande)", DEFN );

	  elsif  DEFN.TY = DN_NUMBER_ID  then								-- Appel avec un nombre nomme
	    EXPRESSIONS.CODE_EXP( D( SM_INIT_EXP, DEFN ) );						--| plie A L'USAGE — idiome expressions:450
												--| (CODE_USED_OBJECT_ID) ; mode in seul,
												--| rvalue empilee = protocole attendu.
												--| Temoins : numarg_test +
												--| TARGET_CODE.EMITS ( Q64( ENTRY_PT ) ).
	  else
			--| Vague 3, DECOUVERTE (etait liste vague 5, mais c'est une
			--| frontiere d'appel) : demi-bruyant, l'actuel n'etait PAS
			--| empile -- desequilibre du protocole d'appel garanti.
	    CODI.TROU( "INVERSE_RECURSE_ON_PARAMETERS DEFN non fait", DEFN );
	  end if;
	end;

        elsif  ACT_PRM.TY = DN_STRING_LITERAL  then
	declare
	  NOM_ANONYME	:constant STRING	:= "STR_" & NEW_LABEL;
	begin
	  EXPRESSIONS.CODE_STRING_LITERAL( ACT_PRM, NOM_ANONYME );
	  PUT_LINE( tab & "LCA" & tab & NOM_ANONYME & ".data_ptr" );					-- LOAD CONSTANT ADDRESS
	end;

        elsif  ACT_PRM.TY = DN_SLICE  then								-- SLICE PARAMETER
	EXPRESSIONS.CODE_SLICE( ACT_PRM, IS_DESTINATION=> FALSE );

        elsif  ACT_PRM.TY = DN_AGGREGATE
	 or  ( ACT_PRM.TY = DN_QUALIFIED  and then D( AS_EXP, ACT_PRM).TY = DN_AGGREGATE ) then

	if  ACT_PRM.TY = DN_QUALIFIED  then ACT_PRM := D( AS_EXP, ACT_PRM); end if;
	declare
	  ANONYMOUS_STR	:constant STRING	:= ANONYMOUS_NAME_AT( ACT_PRM );
	  TYPE_SPEC	: TREE		:= D( SM_EXP_TYPE, ACT_PRM );
	  TYPE_NAME	: TREE		:= D( XD_SOURCE_NAME, TYPE_SPEC );
	  TYPE_NAME_STR	:constant STRING	:= '_' & PRINT_NAME( D( LX_SYMREP, TYPE_NAME ) );
	begin
	  if  CODI.FULL_TYPE_VIEW( D( SM_OBJ_TYPE, FRM_PRM_ID ) ).TY = DN_ARRAY  then			--| formel tableau NON contraint : bornes
	    EXPRESSIONS.CODE_ARRAY_OPERAND( ACT_PRM, ANONYMOUS_STR,					--| de l'agregat (choix, ou S'FIRST en
				      CODI.FULL_TYPE_VIEW( D( SM_OBJ_TYPE, FRM_PRM_ID ) ) );	--| positionnel, LRM 4.3.2) -- le patron
												--| du type de base n'en a pas (SIZ = -1)
	  elsif  CODI.EST_RECORD_DYNAMIQUE( TYPE_SPEC )  then						--| option B : objet neuf sur la co-pile
	    declare										--| (discriminants de l'agregat), doublet
	      B_TYPE	: TREE	:= CODI.FULL_TYPE_VIEW( TYPE_SPEC );				--| use__info de la BASE (pilier 3.7)
	    begin
	      if  B_TYPE.TY = DN_CONSTRAINED_RECORD  then
	        B_TYPE := CODI.FULL_TYPE_VIEW( D( SM_BASE_TYPE, B_TYPE ) );
	      end if;
	      PUT_LINE( tab & "VAR " & ANONYMOUS_STR & "_disp, q" );
	      PUT_LINE( tab & "VAR " & ANONYMOUS_STR & "__u, q" );
	      DECLARATIONS.CODE_OBJET_DYNAMIQUE( TYPE_SPEC, LIST( D( SM_NORMALIZED_COMP_S, ACT_PRM ) ), SUR_LE_TAS => FALSE );
	      PUT_LINE( tab & "DUP" );
	      PUT_LINE( tab & "SA " & IMAGE( CODI.CUR_LEVEL ) & ", " & ANONYMOUS_STR & "_disp" );
	      EXPRESSIONS.CODE_AGGREGATE( ACT_PRM, TYPE_SPEC );
	      PUT( tab & "LA " & IMAGE( DI( CD_LEVEL, B_TYPE ) ) & ", " );
	      CODI.REGIONS_PATH( D( XD_SOURCE_NAME, B_TYPE ) );
	      PUT_LINE( TYPE_INFO_STR( B_TYPE ) & ".use__info" );
	      PUT_LINE( tab & "SA " & IMAGE( CODI.CUR_LEVEL ) & ", " & ANONYMOUS_STR & "__u" );
	      PUT_LINE( tab & "LVA " & IMAGE( CODI.CUR_LEVEL ) & ", " & ANONYMOUS_STR & "_disp" );
	    end;

	  else
	  PUT_LINE( tab & "VAR " & ANONYMOUS_STR & "_disp, q" );
	  PUT_LINE( tab & "VAR " & ANONYMOUS_STR & "__u, q" );
	  PUT( tab & "VAR " & ANONYMOUS_STR & "__dat, " );
	  CODI.REGIONS_PATH( TYPE_NAME );
	  PUT_LINE( TYPE_NAME_STR & ".SIZ__" );

	  PUT_LINE( tab & "LVA " & IMAGE( CODI.CUR_LEVEL ) & ", " & ANONYMOUS_STR & "__dat" );
	  PUT_LINE( tab & "SA " & IMAGE( CODI.CUR_LEVEL ) & ", " & ANONYMOUS_STR & "_disp" );

	  PUT( tab & "LA " & IMAGE( DI( CD_LEVEL, TYPE_SPEC ) ) & ", " );
	  CODI.REGIONS_PATH( TYPE_NAME );
	  PUT_LINE( TYPE_NAME_STR & ".use__info" );
	  PUT_LINE( tab & "SA " & IMAGE( CODI.CUR_LEVEL ) & ", " & ANONYMOUS_STR & "__u" );

	  PUT_LINE( tab & "LVA " & IMAGE( CODI.CUR_LEVEL ) & ", " & ANONYMOUS_STR & "__dat" );
	  EXPRESSIONS.CODE_AGGREGATE( ACT_PRM, TYPE_SPEC );
	  PUT_LINE( tab & "LVA " & IMAGE( CODI.CUR_LEVEL ) & ", " & ANONYMOUS_STR & "_disp" );
	  end if;
	end;

        elsif  ACT_PRM.TY = DN_INDEXED  then								-- COMPOSANT INDEXE EN ACTUAL

	if  FRM_PRM_ID.TY = DN_IN_ID  then
	  EXPRESSIONS.CODE_EXP( ACT_PRM );								-- in : rvalue (scalaire charge, composite laisse @)
	  WRAP_COMPOSITE_ACTUAL_DOUBLET( FRM_PRM_ID, ACT_PRM );						-- composite : @data -> @doublet

	else
	  EXPRESSIONS.CODE_OBJECT_ADDRESS( ACT_PRM );							-- out / in out : @element (par reference)
	  WRAP_COMPOSITE_ACTUAL_DOUBLET( FRM_PRM_ID, ACT_PRM );						--| n 112 INDARG paye (aout 2026) : composite
												--| indexe out/in-out normalise en doublet,
												--| use__info de la base (pilier 3.7).  No-op
												--| scalaire (historique).  Temoins :
												--| indarg_test + TARGET_CODE.LEX
												--| ( OPEN( FILES( FTOP ), ... ) ).
	end if;

        else
	EXPRESSIONS.CODE_EXP( ACT_PRM );
        end if;

	-- LRM 6.2 / 6.4.1 : out / in out scalaire ou d'acces PAR COPIE.  Pile = @actuel ;
	-- on la range dans __CA<n>, on copie la valeur dans __CP<n> (in out : controlee
	-- contre le sous-type du formel ; out : copiee sans controle, l'appele peut la
	-- relire -- tolerance C3) et on passe @__CP<n>.  Recopie apres le CALL.
        if  COPIE_PAR_VALEUR( FRM_PRM_ID, ACT_PRM )  and then  NB_COPIES < MAX_COPIES  then
	declare
	  LBL		: LABEL_TYPE	:= NEW_LABEL;
	  LVL_STR	:constant STRING	:= IMAGE( CODI.CUR_LEVEL );
	  CA		:constant STRING	:= "__CA" & LABEL_STR( LBL );
	  CP		:constant STRING	:= "__CP" & LABEL_STR( LBL );
	  F_TYPE	: TREE		:= D( SM_OBJ_TYPE, FRM_PRM_ID );
	begin
	  COPIE := TRUE;
	  NB_COPIES := NB_COPIES + 1;
	  COPIES( NB_COPIES ) := ( FRM_PRM_ID, ACT_PRM, LBL );
	  PUT_LINE( "VAR " & CA & ", Q" );
	  PUT_LINE( "VAR " & CP & ", " & OPER_SIZ_CHAR( F_TYPE ) );
	  PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & CA );					-- @actuel
	  PUT_LINE( tab & OPER_LOADI_STR( F_TYPE ) & tab & LVL_STR & ", " & CA & ", 0" );		-- valeur de l'actuel
	  if  FRM_PRM_ID.TY = DN_IN_OUT_ID  then
	    EXPRESSIONS.CODE_RANGE_CHECK( VUE_CONTROLE( F_TYPE ) );			-- avant l'appel : sous-type du formel
	  end if;
	  PUT_LINE( tab & 'S' & OPER_SIZ_CHAR( F_TYPE ) & tab & LVL_STR & ", " & CP );
	  PUT_LINE( tab & "LVA" & tab & LVL_STR & ", " & CP );					-- @copie, passee a l'appele
	end;
        end if;

	-- LRM 6.4.1 : formel de sous-type record CONTRAINT -> discriminants de
	-- l'actuel egaux a ceux de la contrainte, tout mode.  Pile = @doublet
	-- (rendu tel quel) ; [@doublet] = @donnees.
        if  CODI.CHECKS_ENABLED
	and then  CODI.FULL_TYPE_VIEW( D( SM_OBJ_TYPE, FRM_PRM_ID ) ).TY = DN_CONSTRAINED_RECORD
        then
	declare
	  F_TYPE	: TREE		:= CODI.FULL_TYPE_VIEW( D( SM_OBJ_TYPE, FRM_PRM_ID ) );
	  F_BASE	: TREE		:= CODI.FULL_TYPE_VIEW( D( SM_BASE_TYPE, F_TYPE ) );
	  ADR		:constant STRING	:= "__PRM" & NEW_LABEL;
	  LVL_STR	:constant STRING	:= IMAGE( CODI.CUR_LEVEL );
	  EXP_S		: SEQ_TYPE	:= LIST( D( SM_NORMALIZED_DSCRMT_S, F_TYPE ) );
	  EXP		: TREE;
	  DECL_S	: SEQ_TYPE;
	  DECL		: TREE;
	begin
	  if  F_BASE.TY = DN_RECORD  and then  not REPRESENTED_ITEMS.HAS_RECORD_REP( F_BASE )  then
	    PUT_LINE( "VAR " & ADR & ", Q" );
	    PUT_LINE( tab & "DUP" );
	    PUT_LINE( tab & "LA" & tab & "-1, 0" );						-- @donnees de l'actuel
	    PUT_LINE( tab & "SA" & tab & LVL_STR & ", " & ADR );
	    DECL_S := LIST( D( SM_DISCRIMINANT_S, F_BASE ) );
	    while  not IS_EMPTY( DECL_S )  loop
	      POP( DECL_S, DECL );
	      declare
	        ID_S	: SEQ_TYPE	:= LIST( D( AS_SOURCE_NAME_S, DECL ) );
	        ID	: TREE;
	      begin
	        while  not IS_EMPTY( ID_S )  and then  not IS_EMPTY( EXP_S )  loop
		POP( ID_S, ID );
		POP( EXP_S, EXP );
		PUT( tab & OPER_LOADI_STR( D( SM_OBJ_TYPE, ID ) ) & tab & LVL_STR & ", " & ADR & ", " );
		REGIONS_PATH( ID );  PUT_LINE( PRINT_NAME( D( LX_SYMREP, ID ) ) );
		EXPRESSIONS.CODE_VALEUR_DISCRIMINANT( F_TYPE, TREE_VOID, ID, EXP );
		PUT_LINE( tab & "CNE" );
		PUT_LINE( tab & "BT" & tab & "STANDARD.ce_raise_" );
	        end loop;
	      end;
	    end loop;
	  end if;
	end;
        end if;

	-- E-D2 : gamme du SOUS-TYPE DU FORMEL (LRM 6.4.1), mode in.  Les in out copies
	-- (COPIE) sont controles ci-dessus ; reste ici l'acces contraint non copie.
        if  FRM_PRM_ID.TY = DN_IN_ID  then
	EXPRESSIONS.CODE_RANGE_CHECK( D( SM_OBJ_TYPE, FRM_PRM_ID ) );
        elsif  FRM_PRM_ID.TY = DN_IN_OUT_ID  and then  not COPIE
	and then  D( SM_OBJ_TYPE, FRM_PRM_ID ).TY = DN_CONSTRAINED_ACCESS
	and then  ( ACT_PRM.TY = DN_USED_OBJECT_ID  or else  ACT_PRM.TY = DN_CONVERSION )	--| conversion : son propre controle (4.6)
        then											--| in out d'acces contraint (6.4.1) : la VALEUR
	EXPRESSIONS.CODE_EXP( ACT_PRM );							--| de l'actuel, controlee avant l'appel
	EXPRESSIONS.CODE_RANGE_CHECK( D( SM_OBJ_TYPE, FRM_PRM_ID ) );
	PUT_LINE( tab & "DROP" );
        end if;

      end loop;
    end	INVERSE_RECURSE_ON_PARAMETERS;
	-----------------------------

  begin
    if  IS_IN_CURRENT_GENERIC( PROC_ID )  and then  not EXPRESSIONS.IS_GENERIC_FORMAL_SUBPROGRAM( PROC_ID )
    then
      PUT( tab & "LA " & INTEGER'IMAGE( CODI.GFP_LEVEL ) & ',' & tab & "-GFP_ofs" );
      if  CODI.DEBUG  then PUT( tab50 & "; propagation GFP generique" ); end if;
      NEW_LINE;
    end if;

    if not IS_EMPTY( SPEC_PRM_GRP_S ) then
      POP( SPEC_PRM_GRP_S, FRM_PRM_GRP );
      SPEC_PRM_ID_S := LIST( D( AS_SOURCE_NAME_S, FRM_PRM_GRP ) );

      INVERSE_RECURSE_ON_PARAMETERS;

    end if;

    if  EXPRESSIONS.IS_GENERIC_FORMAL_SUBPROGRAM( PROC_ID )  then
      PUT_LINE( tab & "LA " & IMAGE( CODI.GFP_LEVEL ) & "," & tab & "-GFP_ofs" );
      PUT_LINE( tab & "LA ," & tab & "-" & SUB_NAME & "__call_ofs" );
      PUT_LINE( tab & "CALLI" );

    else
      PUT( tab & "CALL" & tab );
      CODI.REGIONS_PATH( PROC_ID );
      PUT_LINE( " ," & SUB_NAME & '_' & LABEL_STR( LBL ) );
    end if;

    if  NEGATION  then										--| "/=" implicite : NOT du resultat booleen
      PUT_LINE( tab & "LI" & tab & "1" );								--| du "=" (LRM 6.7)
      PUT_LINE( tab & "OUX" );
    end if;

			--| LRM 6.2 / 6.4.1 : retour NORMAL seulement (une exception de l'appele
			--| saute ce code : l'actuel reste intact).  Valeur controlee contre le
			--| sous-type de l'ACTUEL, puis rangee a l'adresse gardee dans __CA<n>.
    for  K in 1 .. NB_COPIES  loop
      declare
        LVL_STR	:constant STRING	:= IMAGE( CODI.CUR_LEVEL );
        F_TYPE	: TREE		:= D( SM_OBJ_TYPE, COPIES( K ).FRM );
      begin
        PUT_LINE( tab & OPER_LOAD_STR( F_TYPE ) & tab & LVL_STR & ", __CP" & LABEL_STR( COPIES( K ).LBL ) );
        EXPRESSIONS.CODE_RANGE_CHECK( SOUS_TYPE_ACTUEL( COPIES( K ).ACT ) );
        PUT_LINE( tab & "SI" & OPER_SIZ_CHAR( F_TYPE ) & tab & LVL_STR & ", __CA" & LABEL_STR( COPIES( K ).LBL ) & ", 0" );
      end;
    end loop;

			--| LRM 6.4.1 : au RETOUR, un actuel out / in out de sous-type
			--| d'acces CONTRAINT doit encore satisfaire sa contrainte.
    if  CODI.CHECKS_ENABLED  then
      declare
        ACT_S	: SEQ_TYPE	:= LIST( D( SM_NORMALIZED_PARAM_S, PROCEDURE_CALL ) );
        GRP_S	: SEQ_TYPE	:= LIST( D( AS_PARAM_S, D( SM_SPEC, PROC_ID ) ) );
        GRP	: TREE;
        ID_S	: SEQ_TYPE;
        ID	: TREE;
        ACT	: TREE;
      begin
        while  not IS_EMPTY( GRP_S )  loop
	POP( GRP_S, GRP );
	ID_S := LIST( D( AS_SOURCE_NAME_S, GRP ) );
	while  not IS_EMPTY( ID_S )  and then  not IS_EMPTY( ACT_S )  loop
	  POP( ID_S, ID );
	  POP( ACT_S, ACT );
	  if  ACT.TY = DN_CONVERSION  then							--| T (V) en actuel : c'est V qui recoit
	    ACT := D( AS_EXP, ACT );								--| la valeur au retour (6.4.1)
	  end if;
	  if  ( ID.TY = DN_OUT_ID  or else  ID.TY = DN_IN_OUT_ID )
	    and then  not COPIE_PAR_VALEUR( ID, ACT )						--| deja controle par la recopie
	    and then  ACT.TY = DN_USED_OBJECT_ID
	    and then  ( D( SM_DEFN, ACT ).TY in CLASS_VC_NAME  or else  D( SM_DEFN, ACT ).TY in CLASS_PARAM_NAME )
	    and then  D( SM_OBJ_TYPE, D( SM_DEFN, ACT ) ).TY = DN_CONSTRAINED_ACCESS
	  then
	    EXPRESSIONS.CODE_EXP( ACT );
	    EXPRESSIONS.CODE_RANGE_CHECK( D( SM_OBJ_TYPE, D( SM_DEFN, ACT ) ) );
	    PUT_LINE( tab & "DROP" );
	  end if;
	end loop;
        end loop;
      end;
    end if;

  end	CODE_PROCEDURE_CALL;
	-------------------


			-----------------
  procedure		CODE_STM_WITH_EXP		( STM_WITH_EXP :TREE )
  is			-----------------
  begin

    if  STM_WITH_EXP.TY = DN_RETURN
    then
      CODE_RETURN( STM_WITH_EXP );

    elsif  STM_WITH_EXP.TY = DN_DELAY
    then
      CODE_DELAY( STM_WITH_EXP );

    elsif  STM_WITH_EXP.TY = DN_CASE
    then
      CODE_CASE( STM_WITH_EXP );

    elsif  STM_WITH_EXP.TY in CLASS_STM_WITH_EXP_NAME
    then
      CODE_STM_WITH_EXP_NAME( STM_WITH_EXP );

    else
      CODI.TROU( "CODE_STM_WITH_EXP", STM_WITH_EXP );							--| vague 3 : dispatch muet (fossile n 115)
    end if;

  end	CODE_STM_WITH_EXP;
	-----------------

				-----------
  procedure			CODE_RETURN		( ADA_RETURN :TREE )
  is				-----------
  begin
    declare
      EXP			: TREE		:= D( AS_EXP, ADA_RETURN );
      BLOCK_BODY		: TREE		:= D( AS_BODY, CODI.ENCLOSING_BODY );
      ENCLOSING_LEVEL	: INTEGER		:= DI( CD_LEVEL, BLOCK_BODY );
    begin
      if  EXP /= TREE_VOID  then
			---------------------
			STORE_FUNCTION_RESULT:
        declare
	EXPR_TYPE		: TREE	:= D ( SM_EXP_TYPE, EXP );
	FULL_TYPE		: TREE	:= CODI.FULL_TYPE_VIEW( EXPR_TYPE );
	ENCLOSING_NAME	: TREE	:= D( AS_NAME, D( AS_HEADER, CODI.ENCLOSING_BODY ) );
	DEFN		: TREE	:= D( SM_DEFN, CODI.LAST_OF_SELECTED( ENCLOSING_NAME ) );
	RETURN_SUBTYPE	: TREE	:= D( SM_TYPE_SPEC, DEFN );

        begin
	if  CODI.DEBUG  then
	  PUT_LINE( "; CODE_RETURN : EXPR TYPE = " & NODE_NAME'IMAGE( EXPR_TYPE.TY )
		& "  VUE COMPLETE = " & NODE_NAME'IMAGE( FULL_TYPE.TY ));
	end if;

	if  FULL_TYPE.TY = DN_UNIVERSAL_INTEGER  or  FULL_TYPE.TY = DN_UNIVERSAL_REAL  then
	  FULL_TYPE := CODI.FULL_TYPE_VIEW( RETURN_SUBTYPE );						-- LRM 83 : conversion implicite
	end if;

	if  FULL_TYPE.TY in CLASS_SCALAR  or else  CODI.EST_ACCES( FULL_TYPE )  then
	  EXPRESSIONS.CODE_EXP( EXP );
	  EXPRESSIONS.CODE_RANGE_CHECK( RETURN_SUBTYPE );						-- E-D3 : gamme / contrainte d'acces du
												-- SOUS-TYPE DE RETOUR

--	  PUT_LINE( tab & "S" & CODI.OPER_SIZ_CHAR( FULL_TYPE ) & ' ' & INTEGER'IMAGE( ENCLOSING_LEVEL )
--			& ',' & tab & "-result__ofs" );
			--| FIX 30/07 (paye par POW1 v2, B**3 = -27) : le slot resultat est
			--| une cellule de 8 octets relue BRUTE par l'appelant apres RTD
			--| (aucune re-extension de signe) ; l'ecrire a la taille memoire du
			--| type (Sd/Sw/Sb selon OPER_SIZ_CHAR) laisse les bits hauts a
			--| zero -- tout resultat de fonction scalaire NEGATIF etait faux.
			--| Latent depuis toujours : le corpus ne retourne jamais de
			--| negatif (tailles, comptes, positions).  La valeur en pile est
			--| deja un 64 bits SIGNE complet (Ld etend, LI est quadval, MUL
			--| est imul 64) : ecrire le slot PLEIN, Sq, toujours -- l'acces
			--| (Sa = Sq) ne change pas.  Les VARIABLES d/w/b ne sont pas
			--| concernees : leurs relectures re-etendent (FETCH_DWORD signe).
	  PUT_LINE( tab & "SQ " & INTEGER'IMAGE( ENCLOSING_LEVEL ) & ',' & tab & "-result__ofs" );

	elsif  FULL_TYPE.TY = DN_ARRAY  or  FULL_TYPE.TY = DN_CONSTRAINED_ARRAY
	or     EXP.TY = DN_STRING_LITERAL								-- return "..." : SM_EXP_TYPE est DN_VOID
	then
	  declare
	    SRC_LVL_STR : constant STRING := INTEGER'IMAGE( CODI.CUR_LEVEL );
	    RES_LVL_STR : constant STRING := INTEGER'IMAGE( ENCLOSING_LEVEL );
	  begin
	    if  EXP.TY = DN_STRING_LITERAL  then
		-- La macro STR pose une constante dont le champ data_ptr ouvre un
		-- doublet complet : LCA nom.data_ptr = @doublet (idiome de
		-- CODE_ARRAY_OPERAND).  La mecanique de copie ci-dessous s'applique.
	      declare
	        STR_NAME	:constant STRING	:= "RET_STR_" & NEW_LABEL;
	      begin
	        EXPRESSIONS.CODE_STRING_LITERAL( EXP, STR_NAME );
	        PUT_LINE( tab & "LCA" & tab & STR_NAME & ".data_ptr" );
	      end;

	    elsif  EXP.TY = DN_SLICE  then
		-- return S( A .. B ) : le chemin par defaut (CODE_EXP -> CODE_NAME ->
		-- CODE_SLICE en mode destination) laisserait @data, len ; la mecanique
		-- ci-dessous attend un @doublet.  Le mode source de CODE_SLICE construit
		-- le doublet anonyme (info aux offsets standard, bornes REELLES de la
		-- tranche conservees -- semantique Ada d'une tranche).
	      EXPRESSIONS.CODE_SLICE( EXP, IS_DESTINATION => FALSE );

	    elsif  EXP.TY = DN_INDEXED  or else  EXP.TY = DN_SELECTED  or else  EXP.TY = DN_ALL  then
			--| Vague 2 (n 112, dette AUDITS) : la mecanique ci-dessous
			--| suppose @doublet_src ; une reference de composant (return
			--| TAB2D(I)) laisse @data nue -- trou jamais exerce, refus
			--| bruyant pose.  Remede le jour du temoin : doublet anonyme
			--| a la WRAP_COMPOSITE_ACTUAL_DOUBLET (use__info du type).
	      CODI.TROU( "CODE_RETURN tableau : source reference de composant (@data)", EXP );

	    elsif  EXP.TY = DN_AGGREGATE  then
		-- return ( ... ) : CODE_EXP n'a pas de type de contexte pour l'agregat
		-- (CODE_AGGREGATE : « type contexte absent »).  Doublet anonyme de
		-- l'operande d'agregat, le SOUS-TYPE DE RETOUR fournissant la contrainte
		-- d'indice applicable (LRM 4.3.2) : others et positionnel en tirent
		-- leurs bornes s'il est contraint.
	      EXPRESSIONS.CODE_ARRAY_OPERAND( EXP, "RET_AGG_" & NEW_LABEL, CODI.FULL_TYPE_VIEW( RETURN_SUBTYPE ),
					CONTRAINTE_APPLICABLE => TRUE );

	    else
	      EXPRESSIONS.CODE_EXP( EXP );
	    end if;										-- Pile : @doublet_src

    -- doublet_src = [data_ptr_src : q, info_ptr_src : q]
    -- result__ofs contient @doublet_dest, initialisé par l'appelant.
    -- Convention BLKMOV : pile = ... @DST, LEN, @SRC.

	    declare
	      INFO_SRC : constant STRING := "RET_INFO_" & NEW_LABEL;
	    begin
	      PUT_LINE( "VAR" & tab & INFO_SRC & ", Q" );

		-- Copier data_ptr : data_ptr_dest <- data_ptr_src
		-- EXP laisse @doublet_src sur pile ; on en garde une copie.
	      PUT_LINE( tab & "DUP" );
	      PUT_LINE( tab & "LA  ,  0" );
	      PUT_LINE( tab & "SIQ  " & RES_LVL_STR & ", -result__ofs,  0" );

      -- Sauver info_ptr_src = [@doublet_src + 8].
	      PUT_LINE( tab & "DUP" );
	      PUT_LINE( tab & "LA  ,  8" );
	      PUT_LINE( tab & "SA  " & SRC_LVL_STR & ", " & INFO_SRC );
	      PUT_LINE( tab & "DROP" );

      -- Copier l'info vers info_ptr_dest = [@doublet_dest + 8] : 16 octets pour une
      -- dimension, + 12 par dimension de plus (lot 35 : SIZ_K, FST_K, LST_K).
	      PUT_LINE( tab & "LA  " & RES_LVL_STR & ", -result__ofs" );
	      PUT_LINE( tab & "LA  ,  8" );
	      declare
	        IDX_S	: SEQ_TYPE	:= LIST( D( SM_INDEX_S, CODI.FULL_TYPE_VIEW( D( SM_BASE_TYPE, CODI.FULL_TYPE_VIEW( RETURN_SUBTYPE ) ) ) ) );
	        IDX	: TREE;
	        LONG	: NATURAL		:= 4;
	      begin
	        while  not IS_EMPTY( IDX_S )  loop
		POP( IDX_S, IDX );
		LONG := LONG + 12;
	        end loop;
	        PUT_LINE( tab & "LI" & tab & IMAGE( LONG ) );
	      end;
	      PUT_LINE( tab & "LA  " & SRC_LVL_STR & ", " & INFO_SRC );
	      PUT_LINE( tab & "BLKMOV" );
	    end;
	  end;

	elsif  FULL_TYPE.TY = DN_ENUM_LITERAL_S  then
	  EXPRESSIONS.CODE_EXP( EXP );
	  raise PROGRAM_ERROR;

	elsif  FULL_TYPE.TY = DN_RECORD
	or     FULL_TYPE.TY = DN_CONSTRAINED_RECORD
	or     FULL_TYPE.TY = DN_L_PRIVATE
	or     FULL_TYPE.TY = DN_PRIVATE
	then
				-- Copier les donnees dans le doublet alloue par l appelant (adresse dans result__ofs)
	  declare
	    TYPE_SPEC	: TREE	:= FULL_TYPE;

	  begin
	    if  TYPE_SPEC.TY = DN_CONSTRAINED_RECORD  then						-- pilier 3.7 : vue contrainte -> base
	      TYPE_SPEC := D( SM_BASE_TYPE, TYPE_SPEC );							-- (symbole .size de la vue anonyme inexistant)
	    end if;

	    declare
	      TYPE_NAME	: TREE		:= D( XD_SOURCE_NAME, TYPE_SPEC );
	      TN_STR	: constant STRING	:= '_' & PRINT_NAME( D( LX_SYMREP, TYPE_NAME ) );
	      LVL_STR	: constant STRING	:= INTEGER'IMAGE( ENCLOSING_LEVEL );
	    begin
	      if  CODI.EST_RECORD_DYNAMIQUE( TYPE_SPEC )  then
			--| Option B, etape 3 : objet resultat alloue sur la co-pile de
			--| l'APPELE (gardee : EXIT_UNLINK_MNEMONIC -> UNLINK) ; son adresse
			--| va dans data_ptr du doublet de l'appelant.  Resultat = valeur
			--| CONTRAINTE : __MUTABLE := 0.
	        declare
		RES	:constant STRING	:= "__RES" & NEW_LABEL;
		CUR	:constant STRING	:= IMAGE( CODI.CUR_LEVEL );
	        begin
		PUT_LINE( "VAR " & RES & ", Q" );
		if  EXP.TY = DN_AGGREGATE  then
		  DECLARATIONS.CODE_OBJET_DYNAMIQUE( TYPE_SPEC, LIST( D( SM_NORMALIZED_COMP_S, EXP ) ), SUR_LE_TAS => FALSE );
		  PUT_LINE( tab & "DUP" );
		  PUT_LINE( tab & "SA" & tab & CUR & ", " & RES );
		  EXPRESSIONS.CODE_AGGREGATE( EXP, TYPE_SPEC );
		else
		  declare
		    SRC	:constant STRING	:= "__SRC" & NEW_LABEL;
		  begin
		    PUT_LINE( "VAR " & SRC & ", Q" );
		    EXPRESSIONS.CODE_COMPOSITE_DATA_ADDRESS( EXP );
		    PUT_LINE( tab & "SA" & tab & CUR & ", " & SRC );
		    PUT( tab & "LID" & tab & CUR & ", " & SRC & ", " );
		    CODI.REGIONS_PATH( TYPE_NAME );
		    PUT_LINE( TN_STR & ".__TAILLE" );
		    PUT_LINE( tab & "CO_VAR" );
		    PUT_LINE( tab & "DUP" );
		    PUT_LINE( tab & "SA" & tab & CUR & ", " & RES );					-- @DST
		    PUT( tab & "LID" & tab & CUR & ", " & SRC & ", " );
		    CODI.REGIONS_PATH( TYPE_NAME );
		    PUT_LINE( TN_STR & ".__TAILLE" );						-- LEN
		    PUT_LINE( tab & "LA" & tab & CUR & ", " & SRC );					-- @SRC
		    PUT_LINE( tab & "BLKMOV" );
		  end;
		end if;
		PUT_LINE( tab & "LI" & tab & "0" );
		PUT( tab & "SID" & tab & CUR & ", " & RES & ", " );
		CODI.REGIONS_PATH( TYPE_NAME );
		PUT_LINE( TN_STR & ".__MUTABLE" );
		PUT_LINE( tab & "LA" & tab & CUR & ", " & RES );						-- data_ptr := @objet
		PUT_LINE( tab & "SIQ  " & LVL_STR & ", -result__ofs,  0" );
	        end;

	      elsif  EXP.TY = DN_AGGREGATE  then
	      -- result__ofs contient l'adresse du doublet alloue par l'appelant
	      -- Extraire data_ptr (offset 0 du doublet) pour CODE_AGGREGATE
	        PUT_LINE( tab & "LA  " & LVL_STR & ',' & tab & "-result__ofs" );
	        PUT_LINE( tab & "LA  ,  0" );			    -- data_ptr = [doublet + 0]
	        EXPRESSIONS.CODE_AGGREGATE( EXP, TYPE_SPEC );

	      else
	      -- EXP est une variable ou expression composite : BLKMOV vers la destination
	      -- Destination : data_ptr du doublet result__ofs
	        PUT_LINE( tab & "LA  " & LVL_STR & ',' & tab & "-result__ofs" );
	        PUT_LINE( tab & "LA  ,  0" );			    -- @DST = data_ptr du doublet appelant

	        PUT( tab & "LI" & tab );
	        CODI.REGIONS_PATH( TYPE_NAME );
	        PUT_LINE( TN_STR & ".size" );			    -- LEN

	        EXPRESSIONS.CODE_COMPOSITE_DATA_ADDRESS( EXP );
	        PUT_LINE( tab & "BLKMOV" );
	      end if;
	    end;
	  end;

	else
	-- Trou auparavant SILENCIEUX (cause du segfault R6 : result__ofs jamais
	-- rempli, BLKMOV appelant depuis un pointeur non initialise).
	-- Refus bruyant (piege n 53).
	  PUT_LINE( "; CODE_RETURN : type de retour non gere "
		& NODE_NAME'IMAGE( EXPR_TYPE.TY ) );
	  raise PROGRAM_ERROR;
	end if;

        end	STORE_FUNCTION_RESULT;
		---------------------
      end if;

		-- Chantier co-pile (n 163) : les blocs traverses par un return gardent
		-- UNLINK (pas UNLINKR) -- la valeur rendue peut vivre dans leur region
		-- (declare T : STRING := ... begin return T & T; end).  C'est l'epilogue
		-- ret_lbl du frame (EXIT_UNLINK_MNEMONIC) qui tranche pour tout le frame.
		-- PILIER 11 : depiler le contexte de chaque bloc protege traverse
		-- (note v2 par. 5bis).  Dans un HANDLER le drapeau du niveau est faux
		-- (contexte deja depile) : rien n'est emis pour ce bloc-la.
      for  L in reverse LEVEL_NUM( ENCLOSING_LEVEL + 1 ) .. CODI.CUR_LEVEL  loop
        if  CODI.HANDLER_CTX_AT( L )  then  CODI.EXC_POP;  end if;
        PUT_LINE( tab & "UNLINK" & LEVEL_NUM'IMAGE( L ) );
      end loop;
      if  CODI.HANDLER_CTX_AT( LEVEL_NUM( ENCLOSING_LEVEL ) )  then						-- return depuis le corps protege de la
        CODI.EXC_POP;										-- procedure elle-meme (son UNLINK est a ret_lbl)
      end if;

      PUT_LINE( tab & "BRA ret_lbl" );
    end;

  end	CODE_RETURN;
	-----------


			----------
  procedure		CODE_DELAY		( ADA_DELAY :TREE )
  is			----------
  begin
    CODI.TROU( "CODE_DELAY", ADA_DELAY );								--| vague 3 : corps vide, l'instruction etait avalee

  end	CODE_DELAY;
	----------


			---------
  procedure		CODE_CASE			( ADA_CASE :TREE )
  is			---------

    CASE_EXP		: TREE		:= D( AS_EXP, ADA_CASE );
    ALTERNATIVE_S		: TREE		:= D( AS_ALTERNATIVE_S, ADA_CASE );
    POST_CASE_LBL		: constant STRING	:= NEW_LABEL;

    HAS_OTHERS		: BOOLEAN		:= FALSE;
    OTHERS_LBL		: LABEL_TYPE	:= 0;

		----------------------
    function	ALTERNATIVE_HAS_OTHERS	( ALTERNATIVE :TREE ) return BOOLEAN
    is		----------------------
      CHOICE_SEQ	: SEQ_TYPE	:= LIST( D( AS_CHOICE_S, ALTERNATIVE ) );
      CHOICE		: TREE;
    begin
      while not IS_EMPTY( CHOICE_SEQ ) loop
        POP( CHOICE_SEQ, CHOICE );

        if CHOICE.TY = DN_CHOICE_OTHERS then
	return TRUE;
        end if;
      end loop;

      return FALSE;

    end	ALTERNATIVE_HAS_OTHERS;
	----------------------

			---------------------------
    procedure		ALLOCATE_ALTERNATIVE_LABELS
    is			---------------------------
      ALT_SEQ		: SEQ_TYPE	:= LIST( ALTERNATIVE_S );
      ALT_ELEM		: TREE;
      CHOICE_S		: TREE;
      ALT_LBL		: LABEL_TYPE;
    begin
      while not IS_EMPTY( ALT_SEQ ) loop
        POP( ALT_SEQ, ALT_ELEM );

        if ALT_ELEM.TY = DN_ALTERNATIVE then
	CHOICE_S := D( AS_CHOICE_S, ALT_ELEM );
	ALT_LBL  := NEW_LABEL;

	DI( CD_LABEL, CHOICE_S, INTEGER( ALT_LBL ) );

	if ALTERNATIVE_HAS_OTHERS( ALT_ELEM ) then
	  HAS_OTHERS := TRUE;
	  OTHERS_LBL := ALT_LBL;
	end if;

        elsif ALT_ELEM.TY = DN_ALTERNATIVE_PRAGMA then
	null;											--| INTENTIONNEL : pragma d'alternative, aucun code

        else
	CODI.TROU( "CODE_CASE.ALLOCATE_ALTERNATIVE_LABELS", ALT_ELEM );					--| vague 3 : boucle d'alternatives muette
        end if;
      end loop;

    end	ALLOCATE_ALTERNATIVE_LABELS;
	---------------------------

			--------------------
    procedure		CODE_CHOICE_EXP_TEST	( CHOICE :TREE; ALT_LBL :LABEL_TYPE )
    is			--------------------
      CHOICE_EXP	: TREE		:= D( AS_EXP, CHOICE );
    begin
      PUT_LINE( tab & "DUP" );					-- garde le selecteur case
      EXPRESSIONS.CODE_EXP( CHOICE_EXP );			-- valeur du choix
      PUT_LINE( tab & "CEQ" );
      PUT_LINE( tab & "BT" & tab & LABEL_STR( ALT_LBL ) );

    end	CODE_CHOICE_EXP_TEST;
	--------------------

			----------------------
    procedure		CODE_CHOICE_RANGE_TEST	( CHOICE :TREE; ALT_LBL :LABEL_TYPE )
    is			----------------------

      DISCRETE_RANGE	: TREE		:= D( AS_DISCRETE_RANGE, CHOICE );
      NEXT_CHOICE_LBL	: constant STRING	:= NEW_LABEL;

    begin
      if  DISCRETE_RANGE.TY = DN_RANGE  or else  DISCRETE_RANGE.TY = DN_DISCRETE_SUBTYPE  then
			--| Chantier C2 (recensement 28/07, 82 traversees ; temoin
			--| CASE_ST1) : choix = MARQUE DE SOUS-TYPE, LRM 5.4 -- la marque
			--| denote son intervalle.  MEME fenetre CGE/CGT/BF que DN_RANGE,
			--| bornes par la regle exportee CODE_DISCRETE_RANGE_BOUND, qui
			--| rend CODE_EXP(AS_EXP1/2) sur un DN_RANGE : emission de la
			--| forme historique INCHANGEE par construction (oracle : diff
			--| FINC corpus = fenetres AJOUTEES aux 82 sites, rien d'autre).
			--| Les choix de case sont STATIQUES (LRM 5.4(4)) : re-evaluer
			--| les bornes du SM_RANGE de la marque est sur.  Reste au TROU :
			--| DN_RANGE_ATTRIBUTE en choix (aucune traversee au recensement).

        -- Test borne basse : selector >= first
        PUT_LINE( tab & "DUP" );
        EXPRESSIONS.CODE_DISCRETE_RANGE_BOUND( DISCRETE_RANGE, IS_LAST => FALSE );
        PUT_LINE( tab & "CGE" );
        PUT_LINE( tab & "BF" & tab & NEXT_CHOICE_LBL );

        -- Test borne haute : not (selector > last)
        PUT_LINE( tab & "DUP" );
        EXPRESSIONS.CODE_DISCRETE_RANGE_BOUND( DISCRETE_RANGE, IS_LAST => TRUE );
        PUT_LINE( tab & "CGT" );
        PUT_LINE( tab & "BF" & tab & LABEL_STR( ALT_LBL ) );

        PUT_LINE( NEXT_CHOICE_LBL & ':' );

      else
        CODI.TROU( "CODE_CASE forme de choix-intervalle", DISCRETE_RANGE );					--| vague 5 : aucun test emis, l'alternative
												--| ne serait JAMAIS appariee
      end if;

    end	CODE_CHOICE_RANGE_TEST;
	----------------------

			----------------------
    procedure		CODE_ALTERNATIVE_TESTS	( ALTERNATIVE :TREE )
    is			----------------------

      CHOICE_S		: TREE		:= D( AS_CHOICE_S, ALTERNATIVE );
      CHOICE_SEQ	: SEQ_TYPE	:= LIST( CHOICE_S );
      CHOICE		: TREE;
      ALT_LBL		: LABEL_TYPE	:= LABEL_TYPE( DI( CD_LABEL, CHOICE_S ) );

    begin
      while not IS_EMPTY( CHOICE_SEQ ) loop
        POP( CHOICE_SEQ, CHOICE );

        if CHOICE.TY = DN_CHOICE_EXP then
	CODE_CHOICE_EXP_TEST( CHOICE, ALT_LBL );

        elsif CHOICE.TY = DN_CHOICE_RANGE then
	CODE_CHOICE_RANGE_TEST( CHOICE, ALT_LBL );

        elsif CHOICE.TY = DN_CHOICE_OTHERS then
	null;											-- INTENTIONNEL : traite apres tous les tests

        else
	CODI.TROU( "CODE_ALTERNATIVE_TESTS forme de choix", CHOICE );					--| vague 5 : demi-bruyant hors lexique de grep,
												--| pris par la verification de fini
        end if;
      end loop;

    end	CODE_ALTERNATIVE_TESTS;
	----------------------

			--------------
    procedure		CODE_ALL_TESTS
    is			--------------

      ALT_SEQ		: SEQ_TYPE	:= LIST( ALTERNATIVE_S );
      ALT_ELEM		: TREE;

    begin
      while not IS_EMPTY( ALT_SEQ ) loop
        POP( ALT_SEQ, ALT_ELEM );

        if ALT_ELEM.TY = DN_ALTERNATIVE then
	CODE_ALTERNATIVE_TESTS( ALT_ELEM );

        elsif ALT_ELEM.TY = DN_ALTERNATIVE_PRAGMA then
	null;											--| INTENTIONNEL : pragma d'alternative, aucun code

        else
	CODI.TROU( "CODE_CASE.CODE_ALL_TESTS", ALT_ELEM );						--| vague 3 : boucle d'alternatives muette
        end if;
      end loop;

    end	CODE_ALL_TESTS;
	--------------

			---------------------
    procedure		CODE_ALTERNATIVE_BODY	( ALTERNATIVE :TREE )
    is			---------------------

      CHOICE_S		: TREE		:= D( AS_CHOICE_S, ALTERNATIVE );
      ALT_LBL		: LABEL_TYPE	:= LABEL_TYPE( DI( CD_LABEL, CHOICE_S ) );
      IS_OTHERS_ALT : BOOLEAN := ALTERNATIVE_HAS_OTHERS( ALTERNATIVE );

    begin
      PUT_LINE( LABEL_STR( ALT_LBL ) & ':' );

      -- Les alternatives ordinaires sont atteintes par BT avec le selecteur
      -- encore sur la pile. L'alternative others est atteinte apres DROP.
      if not IS_OTHERS_ALT then
        PUT_LINE( tab & "DROP" );
      end if;

      CODE_STM_S( D( AS_STM_S, ALTERNATIVE ) );
      PUT_LINE( tab & "BRA" & tab & POST_CASE_LBL );

    end	CODE_ALTERNATIVE_BODY;
	---------------------

			---------------
    procedure		CODE_ALL_BODIES
    is			---------------

      ALT_SEQ		: SEQ_TYPE	:= LIST( ALTERNATIVE_S );
      ALT_ELEM		: TREE;

    begin
      while not IS_EMPTY( ALT_SEQ ) loop
        POP( ALT_SEQ, ALT_ELEM );

        if ALT_ELEM.TY = DN_ALTERNATIVE then
	CODE_ALTERNATIVE_BODY( ALT_ELEM );

        elsif ALT_ELEM.TY = DN_ALTERNATIVE_PRAGMA then
	null;											--| INTENTIONNEL : pragma d'alternative, aucun code

        else
	CODI.TROU( "CODE_CASE.CODE_ALL_BODIES", ALT_ELEM );						--| vague 3 : boucle d'alternatives muette
        end if;
      end loop;

    end	CODE_ALL_BODIES;
	---------------

  begin
    if CODI.DEBUG then
      PUT( tab50 & "; debut case" );
      NEW_LINE;
    end if;

    ALLOCATE_ALTERNATIVE_LABELS;

    -- Le selecteur reste vivant sur la pile pendant tous les tests.
    EXPRESSIONS.CODE_EXP( CASE_EXP );

    CODE_ALL_TESTS;

    -- Aucun choix ordinaire n'a reussi : on consomme le selecteur.
    PUT_LINE( tab & "DROP" );

    if HAS_OTHERS then
      PUT_LINE( tab & "BRA" & tab & LABEL_STR( OTHERS_LBL ) );
    else
      -- Normalement impossible si la semantique Ada a verifie l'exhaustivite.
      PUT_LINE( tab & "BRA" & tab & POST_CASE_LBL );
    end if;

    CODE_ALL_BODIES;

    PUT_LINE( POST_CASE_LBL & ':' );

    if CODI.DEBUG then
      PUT( tab50 & "; fin case" );
      NEW_LINE;
    end if;

  end	CODE_CASE;
	---------

			----------------------
  procedure		CODE_STM_WITH_EXP_NAME	( STM_WITH_EXP_NAME :TREE )
  is			----------------------
  begin
    if  STM_WITH_EXP_NAME.TY = DN_CODE  then
      CODE_CODE( STM_WITH_EXP_NAME );

    elsif  STM_WITH_EXP_NAME.TY = DN_ASSIGN  then
      CODE_ASSIGN( STM_WITH_EXP_NAME );

    elsif  STM_WITH_EXP_NAME.TY = DN_EXIT  then
      CODE_EXIT( STM_WITH_EXP_NAME );

    else
      CODI.TROU( "CODE_STM_WITH_EXP_NAME", STM_WITH_EXP_NAME );					--| vague 3 : dispatch muet (fossile n 115)
    end if;
  end	CODE_STM_WITH_EXP_NAME;
	----------------------

				---------
  procedure			CODE_CODE			( CODE :TREE )
  is
    OP_TYPE_STR		:constant STRING	:= PRINT_NAME( D( LX_SYMREP, D( AS_NAME, CODE ) ) );
    AGGREG		: TREE		:= D( AS_EXP, CODE );
    NAMED_ASSOC_LIST	: SEQ_TYPE	:= LIST( D( AS_GENERAL_ASSOC_S, AGGREG ) );
    NAMED_ASSOC		: TREE;
  begin

    while  not IS_EMPTY( NAMED_ASSOC_LIST )  loop
      POP( NAMED_ASSOC_LIST, NAMED_ASSOC );
      declare
        CHOICE_LIST		: SEQ_TYPE	:= LIST( D( AS_CHOICE_S, NAMED_ASSOC ) );
        CHOICE_EXP		: TREE;
        USED_OBJECT_ID	: TREE		:= D( AS_EXP, NAMED_ASSOC );
      begin

				-- OPERATION ASM 0 PARAMETRE

        if  OP_TYPE_STR = "ASM_OP_0"  then
	POP( CHOICE_LIST, CHOICE_EXP );
	if  PRINT_NAME( D( LX_SYMREP, D( AS_EXP, CHOICE_EXP ) ) ) = "OPCODE"  then
	  PUT_LINE( tab & PRINT_NAME( D( LX_SYMREP, USED_OBJECT_ID ) ) );
	end if;

				-- OPERATION ASM 1 PARAMETRE

        elsif  OP_TYPE_STR = "ASM_OP_1"  then
	POP( CHOICE_LIST, CHOICE_EXP );
	if  PRINT_NAME( D( LX_SYMREP, D( AS_EXP, CHOICE_EXP ) ) ) = "OPCODE"  then
	  PUT( tab & PRINT_NAME( D( LX_SYMREP, USED_OBJECT_ID ) ) );
	end if;

	if  PRINT_NAME( D( LX_SYMREP, D( AS_EXP, CHOICE_EXP ) ) ) = "VAL"  then
	  declare
	    NUM_REP	:constant STRING	:=   PRINT_NAME( D( LX_NUMREP, USED_OBJECT_ID ) );
	  begin
	    if  NUM_REP'LENGTH >= 4 and then NUM_REP( NUM_REP'FIRST .. NUM_REP'FIRST+2) = "16#"  then
	      PUT_LINE( tab & "0x" & NUM_REP( NUM_REP'FIRST+3 .. NUM_REP'LAST-1 ) );
	    else
	      PUT_LINE( tab & NUM_REP );
	    end if;
	  end;
	end if;

				-- OPERATION ASM 2 PARAMETRES

        elsif  OP_TYPE_STR = "ASM_OP_2"  then
	POP( CHOICE_LIST, CHOICE_EXP );
	if  PRINT_NAME( D( LX_SYMREP, D( AS_EXP, CHOICE_EXP ) ) ) = "OPCODE"  then
	  PUT( tab & PRINT_NAME( D( LX_SYMREP, USED_OBJECT_ID ) ) );
	end if;

	if  PRINT_NAME( D( LX_SYMREP, D( AS_EXP, CHOICE_EXP ) ) ) = "LVL"  then
	  PUT( ' ' & PRINT_NAME( D( LX_NUMREP, USED_OBJECT_ID ) ) );
	end if;

	if  PRINT_NAME( D( LX_SYMREP, D( AS_EXP, CHOICE_EXP ) ) ) = "OFS"  then
	  if  USED_OBJECT_ID.TY = DN_NUMERIC_LITERAL  then
	    PUT_LINE( " ," & tab & PRINT_NAME( D( LX_NUMREP, USED_OBJECT_ID ) ) );
	  elsif  USED_OBJECT_ID.TY = DN_FUNCTION_CALL
	     and then PRINT_NAME( D( LX_SYMREP, D(AS_NAME, USED_OBJECT_ID ) ) ) = """-"""
	  then
	    declare
	      NAMED_ASSOC_LIST	: SEQ_TYPE	:= LIST( D( AS_GENERAL_ASSOC_S, USED_OBJECT_ID ) );
	      NAMED_ASSOC		: TREE;
	      FUNCTION_NAME_STRING	:constant STRING	:= PRINT_NAME( D( LX_SYMREP, D(AS_NAME, USED_OBJECT_ID ) ) );
	    begin
	      POP( NAMED_ASSOC_LIST, NAMED_ASSOC );
	      PUT_LINE( " ," & tab & '-' & PRINT_NAME( D( LX_NUMREP, NAMED_ASSOC ) ) );
	    end;
	  end if;
	end if;

				-- OPERATION ASM 3 PARAMETRES

        elsif  OP_TYPE_STR = "ASM_OP_3"  then
	POP( CHOICE_LIST, CHOICE_EXP );
	if  PRINT_NAME( D( LX_SYMREP, D( AS_EXP, CHOICE_EXP ) ) ) = "OPCODE"  then
	  PUT( tab & PRINT_NAME( D( LX_SYMREP, USED_OBJECT_ID ) ) );
	end if;

	if  PRINT_NAME( D( LX_SYMREP, D( AS_EXP, CHOICE_EXP ) ) ) = "LVL"  then
	  PUT( ' ' & PRINT_NAME( D( LX_NUMREP, USED_OBJECT_ID ) ) );
	end if;

	if  PRINT_NAME( D( LX_SYMREP, D( AS_EXP, CHOICE_EXP ) ) ) = "DISP"  then
	  if  USED_OBJECT_ID.TY = DN_NUMERIC_LITERAL  then
	    PUT( " ," & tab & PRINT_NAME( D( LX_NUMREP, USED_OBJECT_ID ) ) );
	  elsif  USED_OBJECT_ID.TY = DN_FUNCTION_CALL
	     and then PRINT_NAME( D( LX_SYMREP, D(AS_NAME, USED_OBJECT_ID ) ) ) = """-"""
	  then
	    declare
	      NAMED_ASSOC_LIST	: SEQ_TYPE	:= LIST( D( AS_GENERAL_ASSOC_S, USED_OBJECT_ID ) );
	      NAMED_ASSOC		: TREE;
	      FUNCTION_NAME_STRING	:constant STRING	:= PRINT_NAME( D( LX_SYMREP, D(AS_NAME, USED_OBJECT_ID ) ) );
	    begin
	      POP( NAMED_ASSOC_LIST, NAMED_ASSOC );
	      PUT( " ," & tab & '-' & PRINT_NAME( D( LX_NUMREP, NAMED_ASSOC ) ) );
	    end;
	  end if;
	end if;

	if  PRINT_NAME( D( LX_SYMREP, D( AS_EXP, CHOICE_EXP ) ) ) = "OFS"  then
	  if  USED_OBJECT_ID.TY = DN_NUMERIC_LITERAL  then
	    PUT_LINE( ',' & tab & PRINT_NAME( D( LX_NUMREP, USED_OBJECT_ID ) ) );
	  elsif  USED_OBJECT_ID.TY = DN_FUNCTION_CALL
	     and then PRINT_NAME( D( LX_SYMREP, D(AS_NAME, USED_OBJECT_ID ) ) ) = """-"""
	  then
	    declare
	      NAMED_ASSOC_LIST	: SEQ_TYPE	:= LIST( D( AS_GENERAL_ASSOC_S, USED_OBJECT_ID ) );
	      NAMED_ASSOC		: TREE;
	      FUNCTION_NAME_STRING	:constant STRING	:= PRINT_NAME( D( LX_SYMREP, D(AS_NAME, USED_OBJECT_ID ) ) );
	    begin
	      POP( NAMED_ASSOC_LIST, NAMED_ASSOC );
	      PUT_LINE( " ," & tab & '-' & PRINT_NAME( D( LX_NUMREP, NAMED_ASSOC ) ) );
	    end;
	  end if;
	end if;

        end if;

      end;
    end loop;

  end	CODE_CODE;
	---------


			---------------
  function		RECORD_CONTROLE	( REC_TYPE :TREE;  SOUS_TYPE_CONTRAINT :BOOLEAN )	return BOOLEAN
  is			---------------
	--| Lot 34 (LRM 5.2) : affectation a un record STATIQUE a discriminants dont la
	--| destination est CONTRAINTE (sous-type contraint, objet designe, ou type sans
	--| defauts) : les discriminants de la valeur doivent etre ceux de la destination.
    BASE	: TREE	:= CODI.FULL_TYPE_VIEW( REC_TYPE );
  begin
    return  CODI.CHECKS_ENABLED
      and then  BASE.TY = DN_RECORD
      and then  not CODI.EST_RECORD_DYNAMIQUE( BASE )
      and then  not IS_EMPTY( LIST( D( SM_DISCRIMINANT_S, BASE ) ) )
      and then  not REPRESENTED_ITEMS.HAS_RECORD_REP( BASE )
      and then  ( SOUS_TYPE_CONTRAINT  or else  not CODI.A_DISCRIMINANTS_PAR_DEFAUT( BASE ) );
  end	RECORD_CONTROLE;
	---------------


			----------------------
  procedure		COPIE_RECORD_CONTROLEE	( SRC_EXP, REC_TYPE :TREE )
  is			----------------------
	--| Lot 34 : pile = @DST.  Source (agregat : temporaire de cadre) ; discriminants
	--| egaux, sinon CONSTRAINT_ERROR avant toute ecriture ; copie de .size octets.
    N	:constant STRING	:= NEW_LABEL;
    LVL	:constant STRING	:= IMAGE( CODI.CUR_LEVEL );
    DST	:constant STRING	:= "__RDD" & N;
    SRC	:constant STRING	:= "__RDS" & N;
    TMP	:constant STRING	:= "__RDT" & N;
    BASE	: TREE		:= CODI.FULL_TYPE_VIEW( REC_TYPE );
    DECL_S	: SEQ_TYPE;
    DECL	: TREE;
    ID_S	: SEQ_TYPE;
    ID	: TREE;

    procedure	CHAMP	( V :STRING;  DISCR :TREE )
    is
    begin
      PUT( tab & CODI.OPER_LOADI_STR( D( SM_OBJ_TYPE, DISCR ) ) & tab & LVL & ", " & V & ", " );
      CODI.REGIONS_PATH( D( XD_SOURCE_NAME, BASE ) );
      PUT_LINE( '_' & PRINT_NAME( D( LX_SYMREP, D( XD_SOURCE_NAME, BASE ) ) ) & "."
    	    & PRINT_NAME( D( LX_SYMREP, DISCR ) ) );
    end	CHAMP;
  begin
    PUT_LINE( "VAR " & DST & ", Q" );
    PUT_LINE( "VAR " & SRC & ", Q" );
    PUT_LINE( tab & "SA" & tab & LVL & ", " & DST );
    if  SRC_EXP.TY = DN_AGGREGATE  then							--| agregat : temporaire de cadre
      PUT( "VAR " & TMP & "__dat, " );
      CODI.REGIONS_PATH( D( XD_SOURCE_NAME, BASE ) );
      PUT_LINE( '_' & PRINT_NAME( D( LX_SYMREP, D( XD_SOURCE_NAME, BASE ) ) ) & ".size" );
      PUT_LINE( tab & "LVA" & tab & LVL & ", " & TMP & "__dat" );
      EXPRESSIONS.CODE_AGGREGATE( SRC_EXP, REC_TYPE );
      PUT_LINE( tab & "LVA" & tab & LVL & ", " & TMP & "__dat" );
    else
      EXPRESSIONS.CODE_COMPOSITE_DATA_ADDRESS( SRC_EXP );
    end if;
    PUT_LINE( tab & "SA" & tab & LVL & ", " & SRC );
    DECL_S := LIST( D( SM_DISCRIMINANT_S, BASE ) );
    while  not IS_EMPTY( DECL_S )  loop
      POP( DECL_S, DECL );
      ID_S := LIST( D( AS_SOURCE_NAME_S, DECL ) );
      while  not IS_EMPTY( ID_S )  loop
        POP( ID_S, ID );
        CHAMP( DST, ID );
        CHAMP( SRC, ID );
        PUT_LINE( tab & "CNE" );
        PUT_LINE( tab & "BT" & tab & "STANDARD.ce_raise_" );
      end loop;
    end loop;
    PUT_LINE( tab & "LA" & tab & LVL & ", " & DST );
    PUT( tab & "LI" & tab );
    CODI.REGIONS_PATH( D( XD_SOURCE_NAME, BASE ) );
    PUT_LINE( '_' & PRINT_NAME( D( LX_SYMREP, D( XD_SOURCE_NAME, BASE ) ) ) & ".size" );
    PUT_LINE( tab & "LA" & tab & LVL & ", " & SRC );
    PUT_LINE( tab & "BLKMOV" );
  end	COPIE_RECORD_CONTROLEE;
	----------------------


				-----------
  procedure			CODE_ASSIGN		( ASSIGN :TREE )
  is				-----------

    DST_NAME	: TREE	:= D( AS_NAME, ASSIGN );							-- DESTINATION DONT ON VEUT L ADRESSE POUR Y METTRE LA SOURCE
    SRC_EXP	: TREE	:= D( AS_EXP, ASSIGN );							-- EXPRESSION SOURCE A AFFECTER
    BASE_DST_NAME	: TREE	:= DST_NAME;								-- Pour le cas DN_SELECTED eventuel

  begin
    declare

		---------
      procedure	STORE_VAL		( VAL_TYPE_SPEC :TREE )
      is		---------
        TYPE_SPEC	: TREE	:= VAL_TYPE_SPEC;
      begin
        if  TYPE_SPEC.TY = DN_L_PRIVATE  or  TYPE_SPEC.TY = DN_PRIVATE  then
	TYPE_SPEC := D( SM_TYPE_SPEC, TYPE_SPEC );
        end if;

        case  TYPE_SPEC.TY  is
        when  DN_ACCESS | DN_CONSTRAINED_ACCESS =>
	PUT_LINE( tab & "SA" );

        when  DN_ENUMERATION | DN_INTEGER | DN_FIXED | DN_FLOAT =>
	PUT_LINE( tab & "S" & CODI.OPER_SIZ_CHAR( TYPE_SPEC ) );						-- Juste stocker la valeur sur pile

        when others =>
	PUT_LINE ( "!!! STORE_VAL TYPE_SPEC.TY ILLICITE " & NODE_NAME'IMAGE ( TYPE_SPEC.TY ) );
	raise  PROGRAM_ERROR;
        end case;

      end STORE_VAL;
	---------

    begin

      if  D( SM_EXP_TYPE, DST_NAME ).TY = DN_VOID  then
        PUT_LINE( "!!! CODE_ASSIGN: destination selected non typee ou composante inexistante probleme frontend probable" );
        raise PROGRAM_ERROR;
      end if;

      if  DST_NAME.TY = DN_ALL
        and then  CODI.EST_ACCES_TABLEAU_NC( D( SM_EXP_TYPE, D( AS_NAME, DST_NAME ) ) )
      then												--| Q1b : bornes dans l'en-tete
        EXPRESSIONS.CODE_AFFECTATION_EN_TETE( DST_NAME, SRC_EXP );

      elsif  DST_NAME.TY = DN_ALL  then									-- AFFECTATION A UN ELEMENT POINTE
        declare
	DST_TYPE : TREE := D( SM_EXP_TYPE, DST_NAME );
        begin
	while  DST_TYPE.TY = DN_PRIVATE  or else DST_TYPE.TY = DN_L_PRIVATE  loop
	  DST_TYPE := D( SM_TYPE_SPEC, DST_TYPE );
	end loop;

	if  DST_TYPE.TY = DN_CONSTRAINED_RECORD  then							-- pilier 3.7 : vue contrainte -> base
	  DST_TYPE := D( SM_BASE_TYPE, DST_TYPE );
	end if;

	EXPRESSIONS.CODE_OBJECT_ADDRESS( DST_NAME );							-- @objet designe

	if  DST_TYPE.TY = DN_RECORD  and then  RECORD_CONTROLE( DST_TYPE, TRUE )  then		--| lot 34 : objet designe, contraint
	  COPIE_RECORD_CONTROLEE( SRC_EXP, DST_TYPE );
	elsif  DST_TYPE.TY = DN_RECORD  then
	  if  SRC_EXP.TY = DN_AGGREGATE  then								--| LEN n'est empile que pour BLKMOV : avant,
	    EXPRESSIONS.CODE_AGGREGATE( SRC_EXP, DST_TYPE );						--| CODE_AGGREGATE le prenait pour @DST

	  elsif  CODI.EST_RECORD_DYNAMIQUE( DST_TYPE )  then						--| option B : LEN = __TAILLE de la source
	    EXPRESSIONS.CODE_COPIE_RECORD_DYNAMIQUE( SRC_EXP, DST_TYPE );

	  else
	    PUT( tab & "LI" & tab );
	    CODI.REGIONS_PATH( D( XD_SOURCE_NAME, DST_TYPE ) );
	    PUT_LINE( '_' & PRINT_NAME( D( LX_SYMREP, D( XD_SOURCE_NAME, DST_TYPE ) ) ) & ".size" );
			--| Vague 2 (n 112) : le "A VERIFIER" est verifie -- le La
			--| inconditionnel etait un trou (source reference de composant
			--| = @data nue, le La lisait un data comme un data_ptr).
			--| Regle unique.  Diff FINC : identique sur les sources
			--| @doublet, La retire sur les sources @data (bug latent paye).
	    EXPRESSIONS.CODE_COMPOSITE_DATA_ADDRESS( SRC_EXP );

	    PUT_LINE( tab & "BLKMOV" );
	  end if;

	elsif  DST_TYPE.TY = DN_ARRAY or else DST_TYPE.TY = DN_CONSTRAINED_ARRAY  then
	  if  SRC_EXP.TY = DN_AGGREGATE  then
	    EXPRESSIONS.CODE_AGGREGATE( SRC_EXP, DST_TYPE );
	  elsif  DST_TYPE.TY = DN_CONSTRAINED_ARRAY						--| designe tableau contraint NOMME : BLKMOV,
	    and then  ( D( XD_SOURCE_NAME, DST_TYPE ).TY = DN_TYPE_ID				--| LEN = SIZ du patron du type (comme la voie
		      or else  D( XD_SOURCE_NAME, DST_TYPE ).TY = DN_SUBTYPE_ID )			--| variable) ; c41303b/j
	  then
	    PUT( tab & "LD" & tab & IMAGE( DI( CD_LEVEL, DST_TYPE ) ) & ", " );
	    CODI.REGIONS_PATH( D( XD_SOURCE_NAME, DST_TYPE ) );
	    PUT_LINE( CODI.TYPE_INFO_STR( DST_TYPE ) & ".SIZ__" );					-- SIZ (bits)
	    PUT_LINE( tab & "LI" & tab & IMAGE( CODI.STORAGE_UNIT ) );
	    PUT_LINE( tab & "DIV" );									-- LEN en octets
	    if  SRC_EXP.TY = DN_STRING_LITERAL  then
	      EXPRESSIONS.CODE_STRING_LITERAL( SRC_EXP, IDL.ANONYMOUS_NAME_AT( SRC_EXP ) );
	      PUT_LINE( tab & "LCA" & tab & IDL.ANONYMOUS_NAME_AT( SRC_EXP ) & ".data_ptr" );
	      PUT_LINE( tab & "LA" );									-- @SRC = data_ptr
	    elsif  SRC_EXP.TY = DN_SLICE  then
	      EXPRESSIONS.CODE_SLICE( SRC_EXP, IS_DESTINATION => TRUE );				-- @src, len_src
	      PUT_LINE( tab & "DROP" );								-- longueur = celle de la destination
	    else
	      EXPRESSIONS.CODE_COMPOSITE_DATA_ADDRESS( SRC_EXP );
	    end if;
	    PUT_LINE( tab & "BLKMOV" );

	  else
	    PUT_LINE( "; CODE_ASSIGN DN_ALL array source non aggregate a completer" );
	    raise PROGRAM_ERROR;
	  end if;

	else
	  EXPRESSIONS.CODE_EXP( SRC_EXP );
	  STORE_VAL( DST_TYPE );
	end if;
        end;

      elsif  DST_NAME.TY = DN_SELECTED  then								-- AFFECTATION A UN SELECTED (COMPOSANTE DE RECORD PAR EX.)
			------------------------------
			SEE_IF_REPRESENTED_DESTINATION:
        declare
	DESIGNATOR      : TREE := D( AS_DESIGNATOR, DST_NAME );
	DESIGNATOR_DEFN : TREE := D( SM_DEFN, DESIGNATOR );
        begin
	if  REPRESENTED_ITEMS.HAS_COMPONENT_REP( DESIGNATOR_DEFN )  then
	  EXPRESSIONS.CODE_OBJECT_ADDRESS( D( AS_NAME, DST_NAME ) );
	  REPRESENTED_ITEMS.CODE_STORE_REP_COMPONENT( DESIGNATOR_DEFN, SRC_EXP );
	  return;
	end if;
        end	SEE_IF_REPRESENTED_DESTINATION;
		------------------------------

			--------------------
			DESTINATION_SELECTED:
        declare
	DST_TYPE : TREE := CODI.FULL_TYPE_VIEW( D( SM_EXP_TYPE, DST_NAME ) );				--| lot 31 : vue complete (composant de type
												--| prive, c61010a : retombait au scalaire)
        begin
	if  DST_TYPE.TY = DN_CONSTRAINED_RECORD  then						-- pilier 3.7 : vue contrainte -> base
	  DST_TYPE := CODI.FULL_TYPE_VIEW( D( SM_BASE_TYPE, DST_TYPE ) );
	end if;

	if  CODI.EST_SELECTION_DYNAMIQUE( DST_NAME )  then
			--| Option B : destination = donnees du composant, LEN = SIZ du
			--| descripteur (bits -> octets), source = @data (regle n 112).
	  declare
	    DESC	:constant STRING	:= "__DESC" & NEW_LABEL;
	    LVL	:constant STRING	:= IMAGE( CODI.CUR_LEVEL );
	  begin
	    PUT_LINE( "VAR " & DESC & ", Q" );
	    EXPRESSIONS.CODE_SELECTED( DST_NAME, IS_SOURCE => FALSE );				-- @descripteur
	    PUT_LINE( tab & "DUP" );
	    PUT_LINE( tab & "SA" & tab & LVL & ", " & DESC );
	    CODI.DESC_VERS_DONNEES( D( SM_DEFN, D( AS_DESIGNATOR, DST_NAME ) ) );		-- @DST
	    PUT_LINE( tab & "LID" & tab & LVL & ", " & DESC & "," & INTEGER'IMAGE( CODI.DESC_SIZ ) );
	    PUT_LINE( tab & "LI" & tab & "3" );
	    PUT_LINE( tab & "SAR" );									-- LEN
	    if  SRC_EXP.TY = DN_AGGREGATE  then							--| agregat : doublet a bornes propres
	      declare										--| (choix, ou S'FIRST) ; longueur
	        SRCI	:constant STRING	:= "__AFI" & NEW_LABEL;					--| controlee (SIZ egales, 5.2.1)
	      begin
	        PUT_LINE( "VAR " & SRCI & ", Q" );
	        EXPRESSIONS.CODE_ARRAY_OPERAND( SRC_EXP, "AFDYN_" & NEW_LABEL,
					  CODI.FULL_TYPE_VIEW( D( SM_BASE_TYPE, D( SM_EXP_TYPE, DST_NAME ) ) ) );
	        PUT_LINE( tab & "DUP" );
	        PUT_LINE( tab & "LA" & tab & "-1, 8" );
	        PUT_LINE( tab & "SA" & tab & LVL & ", " & SRCI );
	        PUT_LINE( tab & "LA" & tab & "-1, 0" );						-- @SRC
	        if  CODI.CHECKS_ENABLED  then
		PUT_LINE( tab & "LID" & tab & LVL & ", " & SRCI & ", 0" );
		PUT_LINE( tab & "LID" & tab & LVL & ", " & DESC & "," & INTEGER'IMAGE( CODI.DESC_SIZ ) );
		PUT_LINE( tab & "CNE" );
		PUT_LINE( tab & "BT" & tab & "STANDARD.ce_raise_" );
	        end if;
	      end;
	    else
	      EXPRESSIONS.CODE_COMPOSITE_DATA_ADDRESS( SRC_EXP );					-- @SRC
	    end if;
	    PUT_LINE( tab & "BLKMOV" );
	  end;
	  return;
	end if;

      -- Calculer l'adresse destination : @R.C, @A(I).C, etc.
	EXPRESSIONS.CODE_SELECTED( DST_NAME, IS_SOURCE => FALSE );

	if  DST_TYPE.TY = DN_RECORD  then

	  if  SRC_EXP.TY = DN_AGGREGATE  then
	    EXPRESSIONS.CODE_AGGREGATE( SRC_EXP, DST_TYPE );

	  elsif  CODI.EST_RECORD_DYNAMIQUE( DST_TYPE )  then					--| lot 31 : composant record dynamique --
	    EXPRESSIONS.CODE_COPIE_RECORD_DYNAMIQUE( SRC_EXP, DST_TYPE );			--| __TAILLE de la source, discriminants

	  else
	    PUT( tab & "LI" & tab );
	    CODI.REGIONS_PATH( D( XD_SOURCE_NAME, DST_TYPE ) );
	    PUT_LINE( '_' & PRINT_NAME( D( LX_SYMREP, D( XD_SOURCE_NAME, DST_TYPE ) ) ) & ".size" );

	    EXPRESSIONS.CODE_COMPOSITE_DATA_ADDRESS( SRC_EXP );				--| vague 2 (n 112) : discrimination locale -> regle unique
										--| (QUALIFIED desormais dans la regle) ; diff FINC = orthographe seule

	    PUT_LINE( tab & "BLKMOV" );
	  end if;

	elsif  DST_TYPE.TY = DN_ARRAY  or else  DST_TYPE.TY = DN_CONSTRAINED_ARRAY  then

	  if  SRC_EXP.TY = DN_AGGREGATE  then
	    EXPRESSIONS.CODE_AGGREGATE( SRC_EXP, DST_TYPE );
	  else
	    PUT( tab & "LI" & tab );
	    CODI.REGIONS_PATH( D( XD_SOURCE_NAME, DST_TYPE ) );
	    PUT_LINE( '_' & PRINT_NAME( D( LX_SYMREP, D( XD_SOURCE_NAME, DST_TYPE ) ) ) & ".size" );
	    EXPRESSIONS.CODE_EXP( SRC_EXP );						-- A VERIFIER POUR EXPRESSIONS.CODE_COMPOSITE_DATA_ADDRESS( SRC_EXP );
	    PUT_LINE( tab & "BLKMOV" );
	  end if;

	else
         -- Scalaire : pile = @destination, valeur
	  EXPRESSIONS.CODE_EXP( SRC_EXP );
	  STORE_VAL( DST_TYPE );
	end if;
        end	DESTINATION_SELECTED;
		--------------------


      elsif  DST_NAME.TY = DN_INDEXED  then								-- AFFECTATION A UN ELEMENT DE TABLEAU
				-------------------
				DESTINATION_INDEXED:
        declare
	INDEXED_TYPE	: TREE	:= D( SM_EXP_TYPE, DST_NAME );

        begin
	while  INDEXED_TYPE.TY = DN_PRIVATE  or else  INDEXED_TYPE.TY = DN_L_PRIVATE  loop
	  INDEXED_TYPE := D( SM_TYPE_SPEC, INDEXED_TYPE );
	end loop;

	if  INDEXED_TYPE.TY = DN_CONSTRAINED_RECORD  then							-- pilier 3.7 : vue contrainte -> base
	  INDEXED_TYPE := D( SM_BASE_TYPE, INDEXED_TYPE );
	end if;

	EXPRESSIONS.CODE_INDEXED( DST_NAME );								-- @DST

	if  SRC_EXP.TY = DN_AGGREGATE  then
	  EXPRESSIONS.CODE_AGGREGATE( SRC_EXP, INDEXED_TYPE );

	elsif  CODI.EST_RECORD_DYNAMIQUE( INDEXED_TYPE )  then						--| lot 27 : composant record dynamique,
	  EXPRESSIONS.CODE_COPIE_RECORD_DYNAMIQUE( SRC_EXP, INDEXED_TYPE );				--| LEN = __TAILLE de la source, controle

	elsif  INDEXED_TYPE.TY in CLASS_UNCONSTRAINED_COMPOSITE						-- DN_RECORD .. DN_ARRAY
		or else  INDEXED_TYPE.TY = DN_CONSTRAINED_RECORD
		or else  INDEXED_TYPE.TY = DN_CONSTRAINED_ARRAY
	then
	  if  SRC_EXP.TY = DN_STRING_LITERAL  then
			--| FIX v3 30/07 (SLICE1 : le v2 emettait LI 0 -- CD_IMPL_SIZE
			--| n'est PAS pose sur les sous-types composants, et DI rend 0
			--| sans aboyer, contrairement a CD_LEVEL : incoherence des
			--| defauts d'attributs, notee).  Pour un LITTERAL, la longueur
			--| juste et DISPONIBLE est celle du litteral : LX_SYMREP contient
			--| les guillemets (cf. CODE_STRING_LITERAL, 'FIRST+1..'LAST-1),
			--| donc 'LENGTH - 2.  Source : STR + LCA data_ptr + La (idiome
			--| de la branche destination-objet).
	    declare
	      LIT_LEN	:constant INTEGER	:= PRINT_NAME( D( LX_SYMREP, SRC_EXP ) )'LENGTH - 2;
	    begin
	      PUT_LINE( tab & "LI" & tab & IMAGE( LIT_LEN ) );					-- LEN = longueur du litteral (octets)
	      EXPRESSIONS.CODE_STRING_LITERAL( SRC_EXP, IDL.ANONYMOUS_NAME_AT( SRC_EXP ) );
	      PUT_LINE( tab & "LCA" & tab & IDL.ANONYMOUS_NAME_AT( SRC_EXP ) & ".data_ptr" );
	      PUT_LINE( tab & "LA" );							-- @SRC = data_ptr
	      PUT_LINE( tab & "BLKMOV" );
	    end;

	  elsif  INDEXED_TYPE.TY = DN_CONSTRAINED_ARRAY  then
	    CODI.TROU( "CODE_ASSIGN composant TABLEAU indexe, source non litterale (LEN indisponible : CD_IMPL_SIZE absent des sous-types composants)", DST_NAME );

	  else
	    PUT( tab & "LI" & tab );								-- record : .size existe (nomme par construction)
	    CODI.REGIONS_PATH( D( XD_SOURCE_NAME, INDEXED_TYPE ) );
	    PUT_LINE( '_' & PRINT_NAME( D( LX_SYMREP, D( XD_SOURCE_NAME, INDEXED_TYPE ) ) ) & ".size" );
	    EXPRESSIONS.CODE_COMPOSITE_DATA_ADDRESS( SRC_EXP );					--| vague 2 (n 112) : regle unique
	    PUT_LINE( tab & "BLKMOV" );
	  end if;

	else
	  EXPRESSIONS.CODE_EXP( SRC_EXP );
	  STORE_VAL( INDEXED_TYPE );
	end if;

        end	DESTINATION_INDEXED;
		-------------------

      elsif  DST_NAME.TY = DN_USED_OBJECT_ID  then							-- AFFECTATION A UN OBJET
				--------------------------
				DESTINATION_USED_OBJECT_ID:
        declare
	NAME_TYPE : TREE		:= D( SM_EXP_TYPE, DST_NAME );
	DEFN	: TREE		:= D( SM_DEFN, DST_NAME );

			------------
	function		ST_VIA_CALLI	return BOOLEAN
	is		------------
	    -- Invariant (lot n° 84) : l'adresse destination n'est empilee AVANT
	    -- l'expression source que si STORE_OR_CALLI la consommera par le
	    -- thunk ST -- MEME PREDICAT des deux cotes, sinon adresse orpheline
	    -- sur la pile d'evaluation.
	begin
	  return  CODI.IN_GENERIC_BODY
	    and then  EXPRESSIONS.IS_GENERIC_FORMAL_TYPE( D( XD_SOURCE_NAME, NAME_TYPE ) )
	    and then  ( DEFN.TY = DN_OUT_ID  or  DEFN.TY = DN_IN_OUT_ID );

	end	ST_VIA_CALLI;
		------------

			--------------
	procedure		STORE_OR_CALLI
	is		--------------
	    -- Si dans un body generique et parametre out/in_out, utiliser CALLI vers ST
	    -- pour respecter la taille du type actuel. Sinon, store classique.
	    -- Convention: pile = [..., @param_out, valeur]  (valeur en sommet, empilee par l'appelant)
	    -- ST fait SIb -1,0 : POP_RBX (valeur), INDIRECT_BASE_IN_RAX (deref @param → @dest), STORE
	begin
	  if  ST_VIA_CALLI  then
	    declare
	      FORMAL_TYPE_NAME :constant STRING := PRINT_NAME( D( LX_SYMREP, D( XD_SOURCE_NAME, NAME_TYPE ) ) );
	    begin
	        -- Charger l'adresse de ST via le GFP
	        -- Utiliser le niveau du parametre (= niveau de la procedure, pas du bloc declare)
	      PUT_LINE( tab & "LA " & INTEGER'IMAGE( CODI.GENERIC_BASE_LEVEL+1 ) & ',' & tab & "-GFP_ofs" );
	      PUT_LINE( tab & "LA ," & tab & '-' & FORMAL_TYPE_NAME & "__st_ofs" );
	      PUT_LINE( tab & "CALLI" );
	    end;
	  else
	    CODI.STORE( DEFN );
	  end if;
	end	STORE_OR_CALLI;
		--------------

        begin
				-- Resolve private to full type -- regle unique de percage (suit
				-- SM_DERIVED : temoin CONV_DER1 30/07, DS := DSET(S), derive d'un prive)
	NAME_TYPE := CODI.FULL_TYPE_VIEW( NAME_TYPE );

	if  DEFN.TY in CLASS_VC_NAME  and then  DB( SM_RENAMES_OBJ, DEFN )  then
				--------------
				MANAGE_RENAMES:
	  declare
	    DEFN_STR	: constant STRING	:= PRINT_NAME( D( LX_SYMREP, DEFN ) );
	    DEFN_LVL	: INTEGER		:= DI( CD_LEVEL, DEFN );
	  begin
	    if  NAME_TYPE.TY in CLASS_SCALAR  then
	      EXPRESSIONS.CODE_EXP( SRC_EXP );
	      PUT( tab & "SI" & CODI.OPER_SIZ_CHAR( NAME_TYPE ) & tab & IMAGE( DEFN_LVL ) & ", " & tab );
	      REGIONS_PATH( DEFN );
	      PUT_LINE( DEFN_STR & "_disp, 0" );
	      return;
	    end if;
	  end	MANAGE_RENAMES;
		--------------
	end if;

	if  CODI.EST_ACCES( NAME_TYPE )  then								-- OBJET ASSIGNE DE TYPE ACCES
	  EXPRESSIONS.CODE_EXP( SRC_EXP );
	  if  DEFN.TY in CLASS_VC_NAME  or else  DEFN.TY in CLASS_PARAM_NAME  then
	    EXPRESSIONS.CODE_RANGE_CHECK( D( SM_OBJ_TYPE, DEFN ) );					-- sous-type d'acces contraint (3.8)
	  end if;
	  CODI.STORE( DEFN );

	elsif  NAME_TYPE.TY = DN_ARRAY  or  NAME_TYPE.TY = DN_CONSTRAINED_ARRAY  then				-- OBJET ASSIGNE TABLEAU

	  if  SRC_EXP.TY = DN_AGGREGATE  then
	    if  DEFN.TY in CLASS_PARAM_NAME  then							--| formel tableau : @donnees lues dans le
	      CODI.LOAD_MEM( DEFN );									--| doublet, comme la voie BLKMOV ci-dessous
	      PUT_LINE( tab & "LA" );									--| (CODE_OBJECT emettait LVA niv, ARR :
	    else											--| symbole introuvable, c64109)
	      CODE_OBJECT( DEFN );									-- @DST (data) — chemin valide, inchange
	    end if;
	    EXPRESSIONS.CODE_AGGREGATE( SRC_EXP, NAME_TYPE );

	  elsif  ( ( SRC_EXP.TY = DN_INDEXED  or else  SRC_EXP.TY = DN_SELECTED )		--| composant tableau inline (bornes non
		    and then  not CODI.EST_SELECTION_DYNAMIQUE( SRC_EXP ) )			--| re-emissibles en general), agregat
	    or else  ( SRC_EXP.TY = DN_QUALIFIED							--| qualifie (bornes d'un agregat vide
		       and then  D( AS_EXP, SRC_EXP ).TY = DN_AGGREGATE )			--| multidimensionnel non fiables, c52103s) :
	  then										--| copie non controlee, comme avant le lot 30
			-- Convention BLKMOV : pile = @DST, LEN, @SRC.
	    CODI.LOAD_MEM( DEFN );									-- @doublet destination (variable ou parametre)
	    PUT_LINE( tab & "LA" );									-- @DST = data_ptr (offset 0 du doublet)

        -- LEN (octets) lu dynamiquement dans le descripteur de la DESTINATION :
        -- SIZ (bits, dword a l'offset 0 du bloc info) / STORAGE_UNIT.
        -- Robuste pour les sous-types anonymes (STRING(1..6)) et les parametres,
        -- la ou un `_TYPE.size` statique remonterait au type de base non contraint
        -- via XD_SOURCE_NAME (meme famille que le piege n° 46).
        -- ; CHK: egalite des longueurs source/destination (pilier exceptions)
	    if  DEFN.TY in CLASS_PARAM_NAME  then							-- idiome CODE_LENGTH, chemin parametre
	      PUT_LINE( tab & "LVA" & tab & IMAGE( DI( CD_LEVEL, DEFN ) )
			& ", -" & PRINT_NAME( D( LX_SYMREP, DEFN ) ) & "_ofs" );
	      PUT_LINE( tab & "LIA" & tab & ", ," & INTEGER'IMAGE( CODI.ADDR_SIZE ) );				-- @info
	      PUT_LINE( tab & "LD" & tab & ", 0" );							-- SIZ (bits)

	    else											-- idiome CODE_LENGTH, chemin variable
	      PUT( tab & "LID" & tab & IMAGE( DI( CD_LEVEL, DEFN ) ) & ", " );
	      if  DI( CD_LEVEL, DEFN ) /= INTEGER( CODI.CUR_LEVEL )  then					-- uplevel : chemin absolu
	        CODI.REGIONS_PATH( DEFN );								-- (! traverse mal une region generique, cf. PIEGES)
	      end if;										-- local : nom relatif, comme l'elaboration
	      PUT_LINE( PRINT_NAME( D( LX_SYMREP, DEFN ) ) & "__u, 0" );					-- SIZ (bits)

	    end if;

	    PUT_LINE( tab & "LI" & tab & IMAGE( CODI.STORAGE_UNIT ) );
	    PUT_LINE( tab & "DIV" );									-- LEN en octets

	    if  SRC_EXP.TY = DN_STRING_LITERAL  then
	      EXPRESSIONS.CODE_STRING_LITERAL( SRC_EXP, IDL.ANONYMOUS_NAME_AT( SRC_EXP ) );
	      PUT_LINE( tab & "LCA" & tab & IDL.ANONYMOUS_NAME_AT( SRC_EXP ) & ".data_ptr" );			-- @SRC (idiome concat, l. 2550)
	      PUT_LINE( tab & "LA" );									-- @SRC = data_ptr  <<< LIGNE AJOUTEE

	    elsif  SRC_EXP.TY = DN_SLICE  then
	      EXPRESSIONS.CODE_SLICE( SRC_EXP, IS_DESTINATION => TRUE );					-- @src, len_src
	      PUT_LINE( tab & "DROP" );								-- longueur = celle de la destination

	    else
	      EXPRESSIONS.CODE_COMPOSITE_DATA_ADDRESS( SRC_EXP );
	    end if;

	    PUT_LINE( tab & "BLKMOV" );

	  else										--| lot 30 (LRM 5.2.1) : conversion implicite
	    declare									--| au sous-type de la variable -- longueurs
	      N	:constant STRING	:= NEW_LABEL;					--| controlees, bornes de la variable
	      LVL	:constant STRING	:= IMAGE( CODI.CUR_LEVEL );
	      DD	:constant STRING	:= "__AFV" & N;
	      DIC	:constant STRING	:= "__AFW" & N;
	    begin
	      PUT_LINE( "VAR " & DD & ", Q" );
	      PUT_LINE( "VAR " & DIC & ", Q" );
	      CODI.LOAD_MEM( DEFN );							-- @doublet destination (variable ou parametre)
	      PUT_LINE( tab & "DUP" );
	      PUT_LINE( tab & "LA" );							-- @donnees
	      PUT_LINE( tab & "SA" & tab & LVL & ", " & DD );
	      PUT_LINE( tab & "LA" & tab & "," & INTEGER'IMAGE( CODI.ADDR_SIZE ) );		-- @info
	      PUT_LINE( tab & "SA" & tab & LVL & ", " & DIC );
	      EXPRESSIONS.CODE_COPIE_TABLEAU( SRC_EXP, NAME_TYPE, DD, DIC );
	    end;
	  end if;


	elsif  NAME_TYPE.TY = DN_ENUMERATION  then							-- OBJET ASSIGNE ENUMERATION (DONT BOOLEAN, CHARACTER)
	  if  ST_VIA_CALLI  then
	    PUT_LINE( tab & "LVA " & INTEGER'IMAGE( DI( CD_LEVEL, DEFN ) ) & ','
		    & tab & '-' & PRINT_NAME( D( LX_SYMREP, DEFN ) ) & "_ofs" );
	    PUT_LINE( tab & "LA" );
	  end if;
	  EXPRESSIONS.CODE_EXP( SRC_EXP );
	  EXPRESSIONS.CODE_RANGE_CHECK( NAME_TYPE );							-- PILIER CHECKS : gamme du sous-type de la vue
	  STORE_OR_CALLI;

	elsif  NAME_TYPE.TY = DN_INTEGER  or  NAME_TYPE.TY = DN_FIXED  or  NAME_TYPE.TY = DN_FLOAT  then		-- OBJET ASSIGNE SCALAIRE

	  if  ST_VIA_CALLI  then

	      PUT_LINE( tab & "LVA " & INTEGER'IMAGE( DI( CD_LEVEL, DEFN ) ) & ','
		    & tab & '-' & PRINT_NAME( D( LX_SYMREP, DEFN ) ) & "_ofs" );
	      PUT_LINE( tab & "LA" );

	  end if;

	  EXPRESSIONS.CODE_EXP( SRC_EXP );
	  EXPRESSIONS.CODE_RANGE_CHECK( NAME_TYPE );							-- PILIER CHECKS : gamme du sous-type de la vue
	  STORE_OR_CALLI;

	elsif  NAME_TYPE.TY = DN_RECORD  or else NAME_TYPE.TY = DN_CONSTRAINED_RECORD  then
	  declare
	    REC_TYPE : TREE := NAME_TYPE;
	  begin
	    if  REC_TYPE.TY = DN_CONSTRAINED_RECORD  then
	      REC_TYPE := D( SM_BASE_TYPE, REC_TYPE );
	    end if;

	    if  DEFN.TY = DN_COMPONENT_ID  then
	      CODI.TROU( "DESTINATION_USED_OBJECT_ID affectation : destination composant record", DEFN );		--| vague 5 : rien charge, le La ,0 d'apres
												--| dereferencait n'importe quoi
	    else
	      CODI.LOAD_MEM( DEFN );									-- @variable (adresse du doublet @data @use__info)
	    end if;
	    PUT_LINE( tab & "LA" );									-- @DST (adresse des data)

	    if  RECORD_CONTROLE( REC_TYPE, NAME_TYPE.TY = DN_CONSTRAINED_RECORD )  then		--| lot 34 (LRM 5.2)
	      COPIE_RECORD_CONTROLEE( SRC_EXP, REC_TYPE );

	    elsif  SRC_EXP.TY = DN_AGGREGATE  then
	      EXPRESSIONS.CODE_AGGREGATE( SRC_EXP, REC_TYPE );

	    elsif  CODI.EST_RECORD_DYNAMIQUE( REC_TYPE )  then						--| option B : LEN = __TAILLE de la source
	      EXPRESSIONS.CODE_COPIE_RECORD_DYNAMIQUE( SRC_EXP, REC_TYPE );

	    else
	      PUT( tab & "LI" & tab );
	      CODI.REGIONS_PATH( D( XD_SOURCE_NAME, NAME_TYPE ) );
	      PUT_LINE( '_' & PRINT_NAME( D( LX_SYMREP, D( XD_SOURCE_NAME, NAME_TYPE ) ) ) & ".size" );		-- LEN (taille en octets, calculee par FASM)

	      EXPRESSIONS.CODE_COMPOSITE_DATA_ADDRESS( SRC_EXP );
	      PUT_LINE( tab & "BLKMOV" );								-- COPY_BLOCK  @DST LEN @SRC
	    end if;
	  end;

	else											-- AUTRE TYPE SCALAIRE (type formel generique, etc.)
	  if  ST_VIA_CALLI  then
	    PUT_LINE( tab & "LVA " & INTEGER'IMAGE( DI( CD_LEVEL, DEFN ) ) & ',' & tab & '-' & PRINT_NAME( D( LX_SYMREP, DEFN ) ) & "_ofs" );
	    PUT_LINE( tab & "LA" );
	  end if;
	  EXPRESSIONS.CODE_EXP( SRC_EXP );

	  -- E-D6 : gamme du FORMEL en corps partage -- bornes via le dictionnaire
	  -- d'instance (GFP), idiome GENERIC_FIRST_LAST verbatim (expressions ~1830).
	  -- Seul site hors CODE_RANGE_CHECK ; AUCUNE elision (note, Q6).
	  if  CODI.CHECKS_ENABLED
	  and then  CODI.IN_GENERIC_BODY
	  and then  EXPRESSIONS.IS_GENERIC_FORMAL_TYPE( D( XD_SOURCE_NAME, NAME_TYPE ) )
	  then
	    declare
	      LA_GFP	:constant STRING
			 := tab & "LVA" & INTEGER'IMAGE( INTEGER( CODI.GENERIC_BASE_LEVEL ) + 1 )
			  & ',' & tab & "-GFP_ofs";
	      CHN_LID	:constant STRING
			 := tab & "LID , -"
			  & PRINT_NAME( D( LX_SYMREP, D( XD_SOURCE_NAME, NAME_TYPE ) ) )
			  & "__u_ofs, STANDARD._ENUM_USE_INFO";
	    begin
	      PUT_LINE( tab & "DUP" );
	      PUT_LINE( LA_GFP );
	      PUT_LINE( CHN_LID & ".FST" );
	      PUT_LINE( tab & "CLT" );
	      PUT_LINE( tab & "BT" & tab & "STANDARD.ce_raise_" );
	      PUT_LINE( tab & "DUP" );
	      PUT_LINE( LA_GFP );
	      PUT_LINE( CHN_LID & ".LST" );
	      PUT_LINE( tab & "CGT" );
	      PUT_LINE( tab & "BT" & tab & "STANDARD.ce_raise_" );
	    end;
	  end if;
	  STORE_OR_CALLI;
	end if;

        end	DESTINATION_USED_OBJECT_ID;
		--------------------------

      elsif  DST_NAME.TY = DN_SLICE  then								-- AFFECTATION A UNE TRANCHE
        EXPRESSIONS.CODE_SLICE( DST_NAME );

        if  SRC_EXP.TY = DN_AGGREGATE  then
	PUT_LINE( tab & "DROP" );
	EXPRESSIONS.CODE_AGGREGATE( SRC_EXP, D( SM_EXP_TYPE, DST_NAME ), D( AS_DISCRETE_RANGE, DST_NAME ) );

        elsif SRC_EXP.TY = DN_SLICE then
      -- Source slice : laisse @src, len_src
	EXPRESSIONS.CODE_SLICE( SRC_EXP, IS_DESTINATION => TRUE );

      -- On copie avec la longueur destination.
      -- Pile avant DROP : @dst, len_dst, @src, len_src
      -- Pile après DROP : @dst, len_dst, @src
	PUT_LINE( tab & "DROP" );
	PUT_LINE( tab & "BLKMOV" );									-- COPY_BLOCK;	- @DST @SRC LEN

        else
	EXPRESSIONS.CODE_COMPOSITE_DATA_ADDRESS( SRC_EXP );
	PUT_LINE( tab & "BLKMOV" );									-- COPY_BLOCK;	- @DST @SRC LEN
        end if;

      end if;
    end;
  end	CODE_ASSIGN;
	-----------


			---------
  procedure		CODE_EXIT			( ADA_EXIT :TREE )
  is			---------
  begin
    declare
      LVB_LBL		:constant STRING	:= NEW_LABEL;
      EXP			: TREE		:= D ( AS_EXP, ADA_EXIT );
      LOOP_STM		: TREE		:= D ( SM_STM, ADA_EXIT );
      EXITED_LOOP_LEVEL	: LEVEL_NUM	:= LEVEL_NUM( DI( CD_LEVEL, LOOP_STM ) );
      AFTER_LOOP_LABEL	: LABEL_TYPE	:= LABEL_TYPE( DI( CD_AFTER_LOOP, LOOP_STM ) );
    begin
      if  EXP = TREE_VOID  then
        for  L in reverse EXITED_LOOP_LEVEL + 1 .. CODI.CUR_LEVEL  loop					-- UNLINK par NIVEAU (bug compte-comme-niveau
	if  CODI.HANDLER_CTX_AT( L )  then  CODI.EXC_POP;  end if;						-- corrige) + pop des blocs proteges traverses
	PUT_LINE( tab & "UNLINKR" & LEVEL_NUM'IMAGE( L ) );						-- n 163 : les blocs quittes rendent leur co-pile
        end loop;
        PUT_LINE( tab & "BRA" & tab & LABEL_STR( AFTER_LOOP_LABEL ) );

      else
        EXPRESSIONS.CODE_EXP( EXP );
        if EXITED_LOOP_LEVEL /= CODI.CUR_LEVEL then
	declare
	  SKIP_LBL	:constant STRING	:= NEW_LABEL;
	begin
	  PUT_LINE( tab & "BF" & tab & SKIP_LBL );

	  for  L in reverse EXITED_LOOP_LEVEL + 1 .. CODI.CUR_LEVEL  loop
	    if  CODI.HANDLER_CTX_AT( L )  then  CODI.EXC_POP;  end if;
	    PUT_LINE( tab & "UNLINKR" & LEVEL_NUM'IMAGE( L ) );
	  end loop;

	  PUT_LINE( tab & "BRA" & tab & LABEL_STR( AFTER_LOOP_LABEL ) );
	  PUT_LINE( SKIP_LBL & ':' );
	end;
        else
	PUT_LINE( tab & "BT" & tab & LABEL_STR( AFTER_LOOP_LABEL ) );

        end if;
      end if;
    end;

  end	CODE_EXIT;
	---------


	------------
end	INSTRUCTIONS;
	------------

------------------------------------------------------------------------------------------------------------------------
--	1	2	3	4	5	6	7	8	9	0	1	2
