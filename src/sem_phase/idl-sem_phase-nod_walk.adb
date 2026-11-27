------------------------------------------------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2026 VINCENT MORIN, UBO
-- SPDX-License-Identifier: GPL-3.0-or-later
------------------------------------------------------------------------------------------------------------------------
--	1	2	3	4	5	6	7	8	9	0	1	2

separate (IDL.SEM_PHASE)

					--------
package body				NOD_WALK
is					--------

  use DEF_UTIL;
  use VIS_UTIL;
  use MAKE_NOD;
  use EXP_TYPE, EXPRESO;
  use REQ_UTIL;
  use RED_SUBP;
  use DEF_WALK;
  use SET_UTIL;
  use STM_WALK;
  use PRA_WALK;
  use ATT_WALK;
  use HOM_UNIT;
  use DERIVED; -- REMEMBER_DERIVED_DECL

  EQUAL_SYM     : TREE := TREE_VOID; -- STORESYM("=");
  NOT_EQUAL_SYM : TREE := TREE_VOID; -- STORESYM("/=");

      --|-------------------------------------------------------------------------------------------
      --|	      PROCEDURE FORCE_UPPER_CASE
  procedure FORCE_UPPER_CASE (OPERATOR_ID : TREE) is
    function MAKE_UPPER_CASE (A_IN : String) return String is
      MAGIC : constant	    := Character'POS ('A') - Character'POS ('A');
      A	  : String (A_IN'RANGE) := A_IN;
    begin
      for II in A'RANGE loop
        if A (II) in 'A' .. 'Z' then
	A (II) := Character'VAL (Character'POS (A (II)) - MAGIC);
        end if;
      end loop;
      return A;
    end MAKE_UPPER_CASE;

  begin
    D (LX_SYMREP, OPERATOR_ID, STORE_SYM (MAKE_UPPER_CASE (PRINT_NAME (D (LX_SYMREP, OPERATOR_ID)))));
  end FORCE_UPPER_CASE;
      --|-------------------------------------------------------------------------------------------
      --|	      PROCEDURE INSERT_OBJ_TYPE_AND_INIT_EXP_IN_S
  procedure INSERT_OBJ_TYPE_AND_INIT_EXP_IN_S (SOURCE_NAME_S : TREE; OBJ_TYPE : TREE; INIT_EXP : TREE := TREE_VOID) is
    SOURCE_NAME_LIST : SEQ_TYPE := LIST (SOURCE_NAME_S);
    SOURCE_NAME	 : TREE;
    SOURCE_DEF	 : TREE;
    PRIOR_NAME	 : TREE;
    PRIOR_DEF	 : TREE;

    TEMP_OBJ_TYPE : TREE := OBJ_TYPE;
    TEMP_INIT_EXP : TREE := INIT_EXP;
  begin
    while not IS_EMPTY (SOURCE_NAME_LIST) loop

      POP (SOURCE_NAME_LIST, SOURCE_NAME);
      SOURCE_DEF := GET_DEF_FOR_ID (SOURCE_NAME);
      MAKE_DEF_VISIBLE (SOURCE_DEF);
      PRIOR_DEF := GET_PRIOR_DEF (SOURCE_DEF);
      D (SM_OBJ_TYPE, SOURCE_NAME, TEMP_OBJ_TYPE);
      if TEMP_INIT_EXP /= TREE_VOID then
        D (SM_INIT_EXP, SOURCE_NAME, TEMP_INIT_EXP);
      end if;

      if OBJ_TYPE = TREE_VOID then
        MAKE_DEF_IN_ERROR (SOURCE_DEF);
      elsif PRIOR_DEF /= TREE_VOID then
        if SOURCE_NAME.TY = DN_CONSTANT_ID then
	PRIOR_NAME := D (XD_SOURCE_NAME, PRIOR_DEF);
	if PRIOR_NAME.TY = DN_CONSTANT_ID and then D (SM_INIT_EXP, PRIOR_NAME) = TREE_VOID and then GET_BASE_TYPE (D (SM_OBJ_TYPE, PRIOR_NAME)) = GET_BASE_TYPE (TEMP_OBJ_TYPE) then
	  REMOVE_DEF_FROM_ENVIRONMENT (SOURCE_DEF);
	  D (SM_FIRST, SOURCE_NAME, PRIOR_NAME);
	  D (SM_INIT_EXP, PRIOR_NAME, TEMP_INIT_EXP);
	else
	  ERROR (D (LX_SRCPOS, SOURCE_NAME), "DUPLICATE DECLARATION OF CONSTANT - " & PRINT_NAME (D (LX_SYMREP, SOURCE_NAME)));
	  MAKE_DEF_IN_ERROR (SOURCE_DEF);
	end if;
        else
	ERROR (D (LX_SRCPOS, SOURCE_NAME), "DUPLICATE DECLARATION - " & PRINT_NAME (D (LX_SYMREP, SOURCE_NAME)));
	MAKE_DEF_IN_ERROR (SOURCE_DEF);
        end if;
      else
        MAKE_DEF_VISIBLE (SOURCE_DEF);
      end if;

    end loop;
  end INSERT_OBJ_TYPE_AND_INIT_EXP_IN_S;
      --|-------------------------------------------------------------------------------------------
      --|	      PROCEDURE FIXUP_CONSTRAINED_ARRAY_OBJECTS
  procedure FIXUP_CONSTRAINED_ARRAY_OBJECTS (SOURCE_NAME_S : TREE; H : H_TYPE) is
    SOURCE_NAME_LIST   : SEQ_TYPE := LIST (SOURCE_NAME_S);
    SOURCE_NAME	   : TREE;
    OBJ_TYPE	   : TREE;
    EXP		   : TREE;
    CONSTRAINED_SPEC   : TREE;
    UNCONSTRAINED_SPEC : TREE;
  begin
    POP (SOURCE_NAME_LIST, SOURCE_NAME);
    OBJ_TYPE := D (SM_OBJ_TYPE, SOURCE_NAME);
    EXP	   := D (SM_INIT_EXP, SOURCE_NAME);
	      -- MAKE PREDEFINED OPERATORS FOR FIRST OBJECT TYPE
    PRE_FCNS.GEN_PREDEFINED_OPERATORS (GET_BASE_TYPE (OBJ_TYPE), H);
	      -- FOR EACH SOURCE NAME EXCEPT THE FIRST
    while not IS_EMPTY (SOURCE_NAME_LIST) loop
      POP (SOURCE_NAME_LIST, SOURCE_NAME);
		    -- MAKE COPIES OF TYPE AND SUBTYPE SPEC
      CONSTRAINED_SPEC   := COPY_NODE (OBJ_TYPE);
      UNCONSTRAINED_SPEC := COPY_NODE (D (SM_BASE_TYPE, CONSTRAINED_SPEC));
      D (XD_SOURCE_NAME, CONSTRAINED_SPEC, SOURCE_NAME);
      D (XD_SOURCE_NAME, UNCONSTRAINED_SPEC, SOURCE_NAME);
      D (SM_BASE_TYPE, UNCONSTRAINED_SPEC, UNCONSTRAINED_SPEC);
      D (SM_BASE_TYPE, CONSTRAINED_SPEC, UNCONSTRAINED_SPEC);
		    -- GENERATE PREDEFINED OPERATORS FOR CREATED TYPE
      PRE_FCNS.GEN_PREDEFINED_OPERATORS (GET_BASE_TYPE (UNCONSTRAINED_SPEC), H);
		    -- IF AN INITIALIZATION EXPRESSION WAS GIVEN
      if EXP /= TREE_VOID then
			  -- MAKE A COPY OF IT WITH THE NEW TYPE
        EXP := COPY_NODE (EXP);
        D (SM_EXP_TYPE, EXP, CONSTRAINED_SPEC);
        D (SM_INIT_EXP, SOURCE_NAME, EXP);
      end if;
    end loop;
  end FIXUP_CONSTRAINED_ARRAY_OBJECTS;
      --|-------------------------------------------------------------------------------------------
      --|	      PROCEDURE FINISH_PARAM_DECL
  procedure FINISH_PARAM_DECL (NODE : TREE; H : H_TYPE) is
    SOURCE_NAME_S : TREE := D (AS_SOURCE_NAME_S, NODE);
    EXP	        : TREE := D (AS_EXP, NODE);
    NAME	        : TREE := D (AS_NAME, NODE);

    TYPE_SPEC : TREE;
    TYPESET   : TYPESET_TYPE;
  begin
    TYPE_SPEC := EVAL_TYPE_MARK (NAME);
    NAME	    := RESOLVE_TYPE_MARK (NAME);
    D (AS_NAME, NODE, NAME);

    if EXP /= TREE_VOID then
      EVAL_EXP_TYPES (EXP, TYPESET);
      REQUIRE_TYPE (GET_BASE_TYPE (TYPE_SPEC), EXP, TYPESET);
      EXP := RESOLVE_EXP (EXP, TYPESET);
    end if;
	      -- GET SUBTYPE FOR OBJECT
    if TYPE_SPEC /= TREE_VOID then
      TYPE_SPEC := D (SM_TYPE_SPEC, GET_NAME_DEFN (NAME));
    end if;

    INSERT_OBJ_TYPE_AND_INIT_EXP_IN_S (SOURCE_NAME_S, OBJ_TYPE => TYPE_SPEC, INIT_EXP => EXP);
  end FINISH_PARAM_DECL;
      --|-------------------------------------------------------------------------------------------
      --|	      PROCEDURE FINISH_PARAM_S
  procedure FINISH_PARAM_S (DECL_S : TREE; H : H_TYPE) is
    DECL_LIST : SEQ_TYPE := LIST (DECL_S);
    DECL	    : TREE;
  begin
    while not IS_EMPTY (DECL_LIST) loop
      POP (DECL_LIST, DECL);
      WALK (DECL, H);
      FINISH_PARAM_DECL (DECL, H);
    end loop;
  end FINISH_PARAM_S;
      --|-------------------------------------------------------------------------------------------
      --|	      PROCEDURE WALK_HEADER
  procedure WALK_HEADER (NODE : TREE; H : H_TYPE) is
  begin

    case CLASS_HEADER'(NODE.TY) is

      when DN_PROCEDURE_SPEC =>
        declare
	PARAM_S : TREE := D (AS_PARAM_S, NODE);
        begin
	FINISH_PARAM_S (PARAM_S, H);
        end;

      when DN_FUNCTION_SPEC =>
        declare
	PARAM_S : TREE := D (AS_PARAM_S, NODE);
	NAME    : TREE := D (AS_NAME, NODE);
	DUMMY   : TREE;
        begin
	if NAME /= TREE_VOID then
	  DUMMY := EVAL_TYPE_MARK (NAME);
	  NAME  := RESOLVE_TYPE_MARK (NAME);
	  D (AS_NAME, NODE, NAME);
	end if;
	FINISH_PARAM_S (PARAM_S, H);
        end;

      when DN_ENTRY =>
        declare
	PARAM_S	     : TREE := D (AS_PARAM_S, NODE);
	DISCRETE_RANGE : TREE := D (AS_DISCRETE_RANGE, NODE);
	TYPESET	     : TYPESET_TYPE;
	TYPE_SPEC	     : TREE;
        begin
	if DISCRETE_RANGE /= TREE_VOID then
	  EVAL_NON_UNIVERSAL_DISCRETE_RANGE (DISCRETE_RANGE, TYPESET);
	  REQUIRE_UNIQUE_TYPE (DISCRETE_RANGE, TYPESET);
	  TYPE_SPEC := GET_THE_TYPE (TYPESET);
	  if TYPE_SPEC.TY = DN_UNIVERSAL_INTEGER then
					      --$$$$ CHECK FOR VALID BOUND EXPRESSIONS
					      --$$$$ ARE WE CHECKING THAT IT IS DISCRETE ?
	    TYPE_SPEC := PREDEFINED_INTEGER;
	  end if;
	  DISCRETE_RANGE := RESOLVE_DISCRETE_RANGE (DISCRETE_RANGE, TYPE_SPEC);
	  D (AS_DISCRETE_RANGE, NODE, DISCRETE_RANGE);
	else
	  TYPE_SPEC := TREE_VOID;
	end if;
	FINISH_PARAM_S (PARAM_S, H);
        end;

      when DN_PACKAGE_SPEC =>
        declare
	DECL_S1 : constant TREE := D (AS_DECL_S1, NODE);
	DECL_S2 : constant TREE := D (AS_DECL_S2, NODE);
	H       : H_TYPE	    := WALK_HEADER.H;
        begin
	DB (XD_BODY_IS_REQUIRED, NODE, False);
	WALK_ITEM_S (DECL_S1, H);
	H.IS_IN_SPEC := False;
	WALK_ITEM_S (DECL_S2, H);
	DB (XD_BODY_IS_REQUIRED, NODE, True);
        end;
    end case;
  end WALK_HEADER;
      --|-------------------------------------------------------------------------------------------
      --|	      PROCEDURE WALK_UNIT_DESC
  procedure WALK_UNIT_DESC (SOURCE_NAME : TREE; NODE : TREE; H : H_TYPE; HEADER : TREE := TREE_VOID) is
  begin
    if NODE = TREE_VOID then
      return;
    end if;

    case CLASS_UNIT_DESC'(NODE.TY) is

      when DN_RENAMES_UNIT | DN_NAME_DEFAULT =>
        declare
	NAME : TREE := D (AS_NAME, NODE);
        begin
	if SOURCE_NAME.TY = DN_PACKAGE_ID then
	  NAME := WALK_NAME (DN_PACKAGE_ID, NAME);
	else
	  NAME := WALK_HOMOGRAPH_UNIT (NAME, HEADER);
	end if;
	D (AS_NAME, NODE, NAME);
        end;

      when DN_INSTANTIATION =>
        INSTANT.WALK_INSTANTIATION (SOURCE_NAME, NODE, H);

      when DN_BOX_DEFAULT | DN_NO_DEFAULT =>
        null;

      when DN_BLOCK_BODY =>
        declare
	ITEM_S	       : TREE := D (AS_ITEM_S, NODE);
	STM_S	       : TREE := D (AS_STM_S, NODE);
	ALTERNATIVE_S    : TREE := D (AS_ALTERNATIVE_S, NODE);
	ALTERNATIVE_LIST : SEQ_TYPE;
	ALTERNATIVE      : TREE;
        begin
	WALK_ITEM_S (ITEM_S, H);
	if STM_S /= TREE_VOID then
	  DECLARE_LABEL_BLOCK_LOOP_IDS (STM_S, H);
	end if;
	if ALTERNATIVE_S /= TREE_VOID then
	  ALTERNATIVE_LIST := LIST (ALTERNATIVE_S);
	  while not IS_EMPTY (ALTERNATIVE_LIST) loop
	    POP (ALTERNATIVE_LIST, ALTERNATIVE);
	    if ALTERNATIVE.TY = DN_ALTERNATIVE then
	      DECLARE_LABEL_BLOCK_LOOP_IDS (D (AS_STM_S, ALTERNATIVE), H);
	    end if;
	  end loop;
	end if;
	if STM_S /= TREE_VOID then
	  WALK_STM_S (STM_S, H);
	end if;
	WALK_ALTERNATIVE_S (ALTERNATIVE_S, H);
        end;

      when DN_STUB =>
        declare
        begin
	null;
        end;

      when DN_IMPLICIT_NOT_EQ | DN_DERIVED_SUBPROG =>
        Put_Line ("!! WALK_UNIT_DESC: INVALID NODE");
        raise Program_Error;

    end case;
  end WALK_UNIT_DESC;
      --|-------------------------------------------------------------------------------------------
      --|	      PROCEDURE CHECK_EQUALITY_OPERATOR
  procedure CHECK_EQUALITY_OPERATOR (OPERATOR_ID : TREE; H : H_TYPE) is
    SYMREP : TREE;
    NEW_ID : TREE;
  begin
    if OPERATOR_ID.TY /= DN_OPERATOR_ID then
      return;
    end if;

    if EQUAL_SYM = TREE_VOID then
      EQUAL_SYM	:= STORE_SYM ("""=""");
      NOT_EQUAL_SYM := STORE_SYM ("""/=""");
    end if;

    SYMREP := D (LX_SYMREP, OPERATOR_ID);
    if SYMREP = NOT_EQUAL_SYM then
      ERROR (D (LX_SRCPOS, OPERATOR_ID), "DEFINITION OF ""/="" OPERATOR");
    end if;

    if SYMREP = EQUAL_SYM then
      NEW_ID := COPY_NODE (OPERATOR_ID);
		    -- SET SM_FIRST TO THE CREATED ID
      D (SM_FIRST, NEW_ID, NEW_ID);
      D (LX_SYMREP, NEW_ID, NOT_EQUAL_SYM);
      D (SM_UNIT_DESC, NEW_ID, MAKE_IMPLICIT_NOT_EQ (SM_EQUAL => OPERATOR_ID));
      MAKE_DEF_VISIBLE (MAKE_DEF_FOR_ID (NEW_ID, H), D (XD_HEADER, GET_DEF_FOR_ID (OPERATOR_ID)));
      D (XD_NOT_EQUAL, OPERATOR_ID, NEW_ID);
		    -- CONSTRUCT NEW FORMAL PARAMETER ID'S
      declare
        SPEC	   : TREE	    := COPY_NODE (D (SM_SPEC, NEW_ID));
        PARAM_S	   : TREE	    := COPY_NODE (D (AS_PARAM_S, SPEC));
        PARAM_LIST	   : SEQ_TYPE := LIST (PARAM_S);
        PARAM	   : TREE;
        ID_S	   : TREE;
        ID_LIST	   : SEQ_TYPE;
        ID	   : TREE;
        NEW_ID_LIST	   : SEQ_TYPE;
        NEW_PARAM_LIST : SEQ_TYPE := (TREE_NIL, TREE_NIL);
      begin
        while not IS_EMPTY (PARAM_LIST) loop
	POP (PARAM_LIST, PARAM);
	PARAM	  := COPY_NODE (PARAM);
	ID_S	  := COPY_NODE (D (AS_SOURCE_NAME_S, PARAM));
	ID_LIST	  := LIST (ID_S);
	NEW_ID_LIST := (TREE_NIL, TREE_NIL);
	while not IS_EMPTY (ID_LIST) loop
	  POP (ID_LIST, ID);
	  ID := COPY_NODE (ID);
	  D (SM_FIRST, ID, ID);
	  NEW_ID_LIST := APPEND (NEW_ID_LIST, ID);
	end loop;
	LIST (ID_S, NEW_ID_LIST);
	D (AS_SOURCE_NAME_S, PARAM, ID_S);
	NEW_PARAM_LIST := APPEND (NEW_PARAM_LIST, PARAM);
        end loop;
        LIST (PARAM_S, NEW_PARAM_LIST);
        D (AS_PARAM_S, SPEC, PARAM_S);
        D (SM_SPEC, NEW_ID, SPEC);
      end;
    end if;
  end CHECK_EQUALITY_OPERATOR;
      --|-------------------------------------------------------------------------------------------
      --|	      FUNCTION IS_CONSTANT_EXP
  function IS_CONSTANT_EXP (EXP : TREE) return Boolean is
  begin
    if EXP.TY = DN_SELECTED then
      return IS_CONSTANT_EXP (D (AS_DESIGNATOR, EXP));
    elsif EXP.TY = DN_USED_OBJECT_ID then
      return D (SM_DEFN, EXP).TY = DN_CONSTANT_ID;
    else
      return False;
    end if;
  end IS_CONSTANT_EXP;
      --|-------------------------------------------------------------------------------------------
      --|	      FUNCTION SWITCH_REGION
  procedure SWITCH_REGION (GENERIC_ID, REGION_DEF : TREE) is
    ITEM_LIST : SEQ_TYPE := LIST (D (SM_GENERIC_PARAM_S, GENERIC_ID));
    ITEM	    : TREE;
    NAME_LIST : SEQ_TYPE;
    NAME	    : TREE;
  begin
    while not IS_EMPTY (ITEM_LIST) loop
      POP (ITEM_LIST, ITEM);
      case CLASS_ITEM'(ITEM.TY) is
        when CLASS_DSCRMT_PARAM_DECL | CLASS_ID_S_DECL =>
	NAME_LIST := LIST (D (AS_SOURCE_NAME_S, ITEM));
	while not IS_EMPTY (NAME_LIST) loop
	  POP (NAME_LIST, NAME);
	  if D (LX_SYMREP, NAME).TY = DN_SYMBOL_REP then
	    D (XD_REGION_DEF, GET_DEF_FOR_ID (NAME), REGION_DEF);
	  end if;
	end loop;
        when CLASS_ID_DECL =>
	if D (LX_SYMREP, D (AS_SOURCE_NAME, ITEM)).TY = DN_SYMBOL_REP then
	  D (XD_REGION_DEF, GET_DEF_FOR_ID (D (AS_SOURCE_NAME, ITEM)), REGION_DEF);
	end if;
        when others =>
	null;
      end case;
    end loop;
  end SWITCH_REGION;
      --|-------------------------------------------------------------------------------------------
      --|	      PROCEDURE REPROCESS_USE_CLAUSES
  procedure REPROCESS_USE_CLAUSES (DECL_S : TREE; H : H_TYPE) is	     --| POUR LA VISIBILITÉ DANS LE CORPS DES CLAUSES DE LA DECL DE PACKAGE
    DECL_LIST : SEQ_TYPE;
    DECL	    : TREE;
    ITEM_LIST : SEQ_TYPE;
    ITEM	    : TREE;
    ITEM_DEFN : TREE;
    ITEM_DEF  : TREE;
  begin
    if DECL_S = TREE_VOID then
      return;
    end if;

    DECL_LIST := LIST (DECL_S);
    while not IS_EMPTY (DECL_LIST) loop
      POP (DECL_LIST, DECL);
      if DECL.TY = DN_USE then
        ITEM_LIST := LIST (D (AS_NAME_S, DECL));
        while not IS_EMPTY (ITEM_LIST) loop
	POP (ITEM_LIST, ITEM);
	if ITEM.TY = DN_SELECTED then
	  ITEM := D (AS_DESIGNATOR, ITEM);
	end if;
	if ITEM.TY = DN_USED_NAME_ID then
	  ITEM_DEFN := D (SM_DEFN, ITEM);
	else
	  ITEM_DEFN := TREE_VOID;
	end if;
	if ITEM_DEFN.TY = DN_PACKAGE_ID then
	  ITEM_DEF := GET_DEF_FOR_ID (ITEM_DEFN);
	  if DI (XD_LEX_LEVEL, ITEM_DEF) <= 0 and then not DB (XD_IS_USED, ITEM_DEF) then
	    DB (XD_IS_USED, ITEM_DEF, True);
	    SU.USED_PACKAGE_LIST := INSERT (SU.USED_PACKAGE_LIST, ITEM_DEF);
	  end if;
	end if;
        end loop;
      elsif DECL.TY = DN_TYPE_DECL and then (D (AS_TYPE_DEF, DECL).TY = DN_RECORD_DEF or else D (AS_TYPE_DEF, DECL).TY in DN_CONSTRAINED_ARRAY_DEF .. DN_UNCONSTRAINED_ARRAY_DEF) then
        PRE_FCNS.GEN_PREDEFINED_OPERATORS (D (SM_TYPE_SPEC, D (AS_SOURCE_NAME, DECL)), H);
      elsif DECL.TY in CLASS_OBJECT_DECL and then D (AS_TYPE_DEF, DECL).TY = DN_CONSTRAINED_ARRAY_DEF then
        declare
	ID_LIST : SEQ_TYPE := LIST (D (AS_SOURCE_NAME_S, DECL));
	ID      : TREE;
        begin
	while not IS_EMPTY (ID_LIST) loop
	  POP (ID_LIST, ID);
	  PRE_FCNS.GEN_PREDEFINED_OPERATORS (D (SM_OBJ_TYPE, ID), H);
	end loop;
        end;
      end if;
    end loop;
  end REPROCESS_USE_CLAUSES;


				----
  procedure			WALK		( NODE :TREE; H :H_TYPE )
  is				----

  begin
    if NODE = TREE_VOID then
      return;
    end if;

    case CLASS_ITEM'(NODE.TY) is

      when DN_DSCRMT_DECL | DN_IN | DN_IN_OUT | DN_OUT =>	      --| DISCRIMINANT OU DIRECTION
        declare
	SOURCE_NAME_S : TREE := D (AS_SOURCE_NAME_S, NODE);
        begin
	WALK_SOURCE_NAME_S (SOURCE_NAME_S, H);
        end;

		     --| DECLARATION DE CONSTANTE
      when DN_CONSTANT_DECL =>
        declare
	SOURCE_NAME_S : TREE := D (AS_SOURCE_NAME_S, NODE);
	EXP	    : TREE := D (AS_EXP, NODE);
	TYPE_DEF	    : TREE := D (AS_TYPE_DEF, NODE);

	TYPE_SPEC : TREE;
	TYPESET	: TYPESET_TYPE;
        begin
	WALK_SOURCE_NAME_S (SOURCE_NAME_S, H);								--| INSÉRER LES NOMS DANS L'ENVIRONNEMENT

	if TYPE_DEF.TY = DN_CONSTRAINED_ARRAY_DEF then							--| DÉCLARATION DE TABLEAU CONTRAINT
	  TYPE_SPEC := EVAL_TYPE_DEF (TYPE_DEF, HEAD (LIST (SOURCE_NAME_S)), H);				--| EVALUER LA DÉFINITION DE TYPE

	else											--| LA DÉCLARATION CONTIENT UNE SUBTYPE INDICATION
	  TYPE_SPEC := EVAL_SUBTYPE_INDICATION (TYPE_DEF);
	  RESOLVE_SUBTYPE_INDICATION (TYPE_DEF, TYPE_SPEC);
	  D (AS_TYPE_DEF, NODE, TYPE_DEF);
	end if;

	EVAL_EXP_TYPES (EXP, TYPESET);		  --| EVALUER L'EXPRESSION QUI DOIT ÊTRE DONNÉE
	REQUIRE_TYPE (GET_BASE_TYPE (TYPE_SPEC), EXP, TYPESET);
	REQUIRE_NONLIMITED_TYPE (EXP, TYPESET);
	EXP := RESOLVE_EXP (EXP, TYPESET);
	D (AS_EXP, NODE, EXP);
				-- COMPLETE SOURCE_NAME DEFINITIONS AND MAKE VISIBLE
	INSERT_OBJ_TYPE_AND_INIT_EXP_IN_S (SOURCE_NAME_S, OBJ_TYPE => TYPE_SPEC, INIT_EXP => EXP);
				-- IF TYPE DEFINITION IS A CONSTRAINED ARRAY DEFINITION
	if TYPE_DEF.TY = DN_CONSTRAINED_ARRAY_DEF then
	  FIXUP_CONSTRAINED_ARRAY_OBJECTS (SOURCE_NAME_S, H);	       --| COPIER LES ARRAY TYPE SPECS ET GÉNÉRER LES OPÉRATEURS PRÉDÉFINIS
	end if;
        end;

         --| DECLARATION DE VARIABLE
      when DN_VARIABLE_DECL =>
        declare
	SOURCE_NAME_S : TREE := D (AS_SOURCE_NAME_S, NODE);
	EXP	    : TREE := D (AS_EXP, NODE);
	TYPE_DEF	    : TREE := D (AS_TYPE_DEF, NODE);

	TYPE_SPEC : TREE;
	TYPESET	: TYPESET_TYPE;
        begin
	WALK_SOURCE_NAME_S (SOURCE_NAME_S, H);								--| INSÉRER LES NOMS DANS L'ENVIRONNEMENT

	if TYPE_DEF.TY = DN_CONSTRAINED_ARRAY_DEF then							--| CONTIENT UNE DÉFINITION DE TABLEAU CONTRAINT
	  TYPE_SPEC := EVAL_TYPE_DEF (TYPE_DEF, HEAD (LIST (SOURCE_NAME_S)), H);				--| EVALUER LA DÉFINITION DE TYPE

	else											--| INDICATION DE SOUS TYPE
	  TYPE_SPEC := EVAL_SUBTYPE_INDICATION( TYPE_DEF );						--| EVALUER LA SUBTYPE INDICATION
	  RESOLVE_SUBTYPE_INDICATION( TYPE_DEF, TYPE_SPEC );						--| LA RÉSOUDRE
	  D (AS_TYPE_DEF, NODE, TYPE_DEF);

	end if;

	if EXP /= TREE_VOID then		      --| UNE EXPRESSION EST DONNÉE
	  EVAL_EXP_TYPES (EXP, TYPESET);
	  REQUIRE_TYPE (GET_BASE_TYPE (TYPE_SPEC), EXP, TYPESET);
	  REQUIRE_NONLIMITED_TYPE (EXP, TYPESET);
	  EXP := RESOLVE_EXP (EXP, TYPESET);
	  D (AS_EXP, NODE, EXP);
	end if;

	INSERT_OBJ_TYPE_AND_INIT_EXP_IN_S
	 (SOURCE_NAME_S,	--| TERMINER LES DÉFINITIONS ET RENDRE VISIBLE
	  OBJ_TYPE => TYPE_SPEC, INIT_EXP => EXP);

	if TYPE_DEF.TY = DN_CONSTRAINED_ARRAY_DEF then
	  FIXUP_CONSTRAINED_ARRAY_OBJECTS (SOURCE_NAME_S, H);
	end if;
        end;
		      --| DECLARATION DE NOMBRE
      when DN_NUMBER_DECL =>
        declare
	SOURCE_NAME_S : TREE := D (AS_SOURCE_NAME_S, NODE);
	EXP	    : TREE := D (AS_EXP, NODE);
	TYPE_SPEC	    : TREE;
	TYPESET	    : TYPESET_TYPE;
        begin
	WALK_SOURCE_NAME_S (SOURCE_NAME_S, H);
	EVAL_EXP_TYPES (EXP, TYPESET);
	REQUIRE_UNIVERSAL_TYPE (EXP, TYPESET);
	REQUIRE_UNIQUE_TYPE (EXP, TYPESET);
	TYPE_SPEC := GET_THE_TYPE (TYPESET);
	EXP	:= RESOLVE_EXP (EXP, TYPE_SPEC);
	INSERT_OBJ_TYPE_AND_INIT_EXP_IN_S (SOURCE_NAME_S, OBJ_TYPE => TYPE_SPEC, INIT_EXP => EXP);
        end;
		      --| DECLARATION D'EXCEPTION
      when DN_EXCEPTION_DECL =>
        declare
	SOURCE_NAME_S : TREE := D (AS_SOURCE_NAME_S, NODE);
        begin
	WALK_SOURCE_NAME_S (SOURCE_NAME_S, H);
	CHECK_UNIQUE_SOURCE_NAME_S (SOURCE_NAME_S);
        end;
		      --| DECLARATION DE CONSTANTE DIFFEREE
      when DN_DEFERRED_CONSTANT_DECL =>
        declare
	SOURCE_NAME_S : TREE := D (AS_SOURCE_NAME_S, NODE);
	NAME	    : TREE := D (AS_NAME, NODE);
	TYPE_SPEC	    : TREE;
        begin
	WALK_SOURCE_NAME_S (SOURCE_NAME_S, H);
	TYPE_SPEC := EVAL_TYPE_MARK (NAME);
	if TYPE_SPEC /= TREE_VOID then
	  TYPE_SPEC := D (SM_TYPE_SPEC, GET_NAME_DEFN (NAME));
	end if;
	NAME := RESOLVE_TYPE_MARK (NAME);
	D (AS_NAME, NODE, NAME);
				-- CHECK THAT CURRENT DECLARATION IS IN VISIBLE PART
				-- ... AND THAT TYPE IS PRIVATE TYPE IS DEFINED IN THIS REGION
				-- ... (OUTSIDE THE PACKAGE, SM_TYPE_SPEC IS NOT VOID)
	if not H.IS_IN_SPEC or else GET_BASE_TYPE (TYPE_SPEC).TY not in CLASS_PRIVATE_SPEC then
	  ERROR (D (LX_SRCPOS, NODE), "DEFERRED CONSTANT NOT ALLOWED");
	end if;

	INSERT_OBJ_TYPE_AND_INIT_EXP_IN_S (SOURCE_NAME_S, OBJ_TYPE => TYPE_SPEC, INIT_EXP => TREE_VOID);
        end;
		      --| DECLARATION DE TYPE
      when DN_TYPE_DECL =>
        declare
	SOURCE_NAME   : TREE := D (AS_SOURCE_NAME, NODE);
	DSCRMT_DECL_S : TREE := D (AS_DSCRMT_DECL_S, NODE);
	TYPE_DEF	    : TREE := D (AS_TYPE_DEF, NODE);

	SOURCE_DEF : TREE := MAKE_DEF_FOR_ID (SOURCE_NAME, H);
	TYPE_SPEC  : TREE;

	PRIOR_DEF	        : TREE;
	PRIOR_NAME        : TREE;
	PRIOR_SPEC        : TREE   := TREE_VOID;
	NEW_DSCRMT_DECL_S : TREE   := DSCRMT_DECL_S;
	H	        : H_TYPE := WALK.H;
	S	        : S_TYPE;
        begin
	PRIOR_DEF := GET_PRIOR_DEF (SOURCE_DEF);

	if PRIOR_DEF /= TREE_VOID then		    --| IL Y A UNE DÉFINITION ANTÉRIEURE
	  PRIOR_NAME := D (XD_SOURCE_NAME, PRIOR_DEF);

	  if PRIOR_NAME.TY in DN_PRIVATE_TYPE_ID .. DN_L_PRIVATE_TYPE_ID then	       --| TYPE PRIVÉ (LIMITÉ)
	    PRIOR_SPEC := D (SM_TYPE_SPEC, PRIOR_NAME);

	    if D (SM_TYPE_SPEC, PRIOR_SPEC) /= TREE_VOID or else H.IS_IN_SPEC then	  --| TYPE COMPLET ANTÉRIEUR ! OU ON EST DANS LA PARTIE VISIBLE
	      PRIOR_SPEC := TREE_VOID;		 --| INDIQUER UNE ERREUR
	    end if;

	  elsif PRIOR_NAME.TY = DN_TYPE_ID then			 --| UN ID DE TYPE
	    PRIOR_SPEC := D (SM_TYPE_SPEC, PRIOR_NAME);	        --| SPÉCIF DE TYPE CORRESPONDANTE
	    if PRIOR_SPEC.TY /= DN_INCOMPLETE			--| CE N'EST PAS UN INCOMPLET
	     or else D (XD_FULL_TYPE_SPEC, PRIOR_SPEC) /= TREE_VOID then --| LE TYPE COMPLET EST DÉJÀ DÉCLARÉ
	      PRIOR_SPEC := TREE_VOID;		 --| INDIQUER UNE ERREUR
	    end if;
	  end if;

	  if TYPE_DEF.TY not in DN_ENUMERATION_DEF .. DN_RECORD_DEF then     --| CE N'EST PAS UNE DÉFINITION COMPLÈTE POSSIBLE
	    PRIOR_SPEC := TREE_VOID;			  --| INDIQUER UNE ERREUR
	  end if;

	  if PRIOR_SPEC = TREE_VOID then		   --| REDÉCLARATION INTERDITE
	    ERROR (D (LX_SRCPOS, NODE), "REDECLARATION OF TYPE NAME");
	    MAKE_DEF_IN_ERROR (PRIOR_DEF);		        --| DÉFINITION ANTÉRIEURE INDIQUÉE EN ERREUR
	    PRIOR_DEF := TREE_VOID;		    --| FAIRE COMME S'IL N'Y AVAIT PAS D'ENTÉRIEURE
	  end if;
	end if;
				-- IF DISCRIMINANTS WERE GIVEN
	if DSCRMT_DECL_S /= TREE_VOID and then not IS_EMPTY (LIST (DSCRMT_DECL_S)) then

				        -- WALK THE DISCRIMINANTS
				        -- ... (IN THE RECORD'S DECLARATIVE REGION)
	  ENTER_REGION (SOURCE_DEF, H, S);
				        --WALK_ITEM_S(DSCRMT_DECL_S, H);
	  FINISH_PARAM_S (DSCRMT_DECL_S, H);
	  LEAVE_REGION (SOURCE_DEF, S);
	  H := WALK.H;

	  if TYPE_DEF.TY not in DN_ACCESS_DEF .. DN_L_PRIVATE_DEF and then TYPE_DEF /= TREE_VOID then
	    ERROR (D (LX_SRCPOS, DSCRMT_DECL_S), "DISCRIMINANTS NOT ALLOWED");
	  elsif PRIOR_DEF /= TREE_VOID then
	    if D (SM_DISCRIMINANT_S, PRIOR_SPEC) = TREE_VOID or else IS_EMPTY (LIST (D (SM_DISCRIMINANT_S, PRIOR_SPEC))) then
	      ERROR (D (LX_SRCPOS, DSCRMT_DECL_S), "FIRST DECLARATION HAD NO DISCRIMINANTS");
	    else
	      NEW_DSCRMT_DECL_S := D (SM_DISCRIMINANT_S, PRIOR_SPEC);
	      CONFORM_PARAMETER_LISTS (NEW_DSCRMT_DECL_S, DSCRMT_DECL_S);
	      NEW_DSCRMT_DECL_S := D (SM_DISCRIMINANT_S, PRIOR_SPEC);
	      if TYPE_DEF.TY /= DN_RECORD_DEF then
	        ERROR (D (LX_SRCPOS, DSCRMT_DECL_S), "FULL TYPE MUST BE RECORD");
	      end if;
	    end if;
	  end if;
	end if;

	if PRIOR_DEF /= TREE_VOID then
	  D (SM_FIRST, SOURCE_NAME, PRIOR_NAME);
	else
	  PRIOR_DEF  := SOURCE_DEF;
	  PRIOR_NAME := SOURCE_NAME;
	end if;

	if TYPE_DEF = TREE_VOID then
	  ENTER_REGION (PRIOR_DEF, H, S);
	  TYPE_SPEC := MAKE_INCOMPLETE (SM_DISCRIMINANT_S => NEW_DSCRMT_DECL_S, XD_SOURCE_NAME => SOURCE_NAME);
	  LEAVE_REGION (PRIOR_DEF, S);
	else
	  TYPE_SPEC := EVAL_TYPE_DEF (TYPE_DEF, PRIOR_NAME, H, NEW_DSCRMT_DECL_S);
	  if TYPE_DEF.TY = DN_DERIVED_DEF then
	    REMEMBER_DERIVED_DECL (NODE);
	  end if;
	end if;

	D (SM_TYPE_SPEC, SOURCE_NAME, TYPE_SPEC);
	if TYPE_SPEC /= TREE_VOID then
	  if PRIOR_DEF /= SOURCE_DEF then
	    REMOVE_DEF_FROM_ENVIRONMENT (SOURCE_DEF);
	    if PRIOR_SPEC /= TREE_VOID then
	      if PRIOR_SPEC.TY = DN_INCOMPLETE then
	        D (XD_FULL_TYPE_SPEC, PRIOR_SPEC, TYPE_SPEC);
	      else
	        D (SM_TYPE_SPEC, PRIOR_SPEC, TYPE_SPEC);
	      end if;
	    end if;
	  else
	    MAKE_DEF_VISIBLE (SOURCE_DEF);
	  end if;
	  PRE_FCNS.GEN_PREDEFINED_OPERATORS (GET_BASE_TYPE (TYPE_SPEC), H);
	else
	  MAKE_DEF_IN_ERROR (SOURCE_DEF);
	end if;
        end;

      when DN_SUBTYPE_DECL =>
        declare
	SOURCE_NAME        : TREE	:= D (AS_SOURCE_NAME, NODE);
	SUBTYPE_INDICATION : TREE	:= D (AS_SUBTYPE_INDICATION, NODE);
	SOURCE_DEF         : TREE	:= MAKE_DEF_FOR_ID( SOURCE_NAME, H );
	TYPE_SPEC	         : TREE;
        begin
	TYPE_SPEC := EVAL_TYPE_DEF( SUBTYPE_INDICATION, SOURCE_NAME, H );
	D( SM_TYPE_SPEC, SOURCE_NAME, TYPE_SPEC );

-- MODIF V.MORIN 18/6/2025 le xd_source_name d'un type_spec de subtype_decl pointait sur le type_id de base
-- semble incorrect pour cet attribut non Diana
--
-- Lot 33 : SANS contrainte (SUBTYPE S IS R), TYPE_SPEC est le noeud MEME du type (ou
-- sous-type) nomme, partage : le renommer cassait la visibilite par selection des
-- composants (XD_REGION des composants /= XD_SOURCE_NAME du type : NOT VISIBLE BY
-- SELECTION, c37206a, c37404a/b...) et le nom du patron dans l'expanseur (c37213d).
-- On ne renomme que le noeud NOUVEAU d'une contrainte -- pour un RECORD seulement
-- (tableaux, scalaires : l'expanseur nomme le patron du sous-type d'apres ce nom,
-- notamment dans une instance, cc3224a).
	if  TYPE_SPEC /= TREE_VOID
	  and then  ( TYPE_SPEC.TY /= DN_RECORD
		      or else  D( XD_SOURCE_NAME, TYPE_SPEC ) = TREE_VOID
		      or else  D( XD_SOURCE_NAME, TYPE_SPEC ).TY not in CLASS_TYPE_NAME
		      or else  D( SM_TYPE_SPEC, D( XD_SOURCE_NAME, TYPE_SPEC ) ) /= TYPE_SPEC )
	then
	  D( XD_SOURCE_NAME, TYPE_SPEC, SOURCE_NAME );
	end if;
--put_line( "; NOD_WALK 722 subtype_decl source_name : " & PRINT_NAME( D( LX_SYMREP, SOURCE_NAME ) ) );
--
	if  TYPE_SPEC /= TREE_VOID  then
	  MAKE_DEF_VISIBLE( SOURCE_DEF );
	else
	  MAKE_DEF_IN_ERROR( SOURCE_DEF );
	end if;
        end;

      when DN_TASK_DECL =>
        declare
	SOURCE_NAME : TREE := D (AS_SOURCE_NAME, NODE);
	DECL_S	  : TREE := D (AS_DECL_S, NODE);

	H	 : H_TYPE := WALK.H;
	S	 : S_TYPE;
	SOURCE_DEF : TREE	:= MAKE_DEF_FOR_ID (SOURCE_NAME, H);
	PRIOR_DEF  : TREE;

	TASK_SPEC : TREE := MAKE_TASK_SPEC (SM_DECL_S => DECL_S, XD_SOURCE_NAME => SOURCE_NAME);
        begin
	if SOURCE_NAME.TY = DN_TYPE_ID then
	  D (SM_FIRST, SOURCE_NAME, SOURCE_NAME);
	  D (SM_TYPE_SPEC, SOURCE_NAME, TASK_SPEC);
	  PRIOR_DEF := GET_PRIOR_DEF (SOURCE_DEF);
	  if PRIOR_DEF /= TREE_VOID then
	    if D (XD_SOURCE_NAME, PRIOR_DEF).TY = DN_L_PRIVATE_TYPE_ID then
	      REMOVE_DEF_FROM_ENVIRONMENT (SOURCE_DEF);
	      D (SM_FIRST, SOURCE_NAME, D (XD_SOURCE_NAME, PRIOR_DEF));
	      D (SM_TYPE_SPEC, D (SM_TYPE_SPEC, D (XD_SOURCE_NAME, PRIOR_DEF)), TASK_SPEC);
	      SOURCE_DEF := PRIOR_DEF;
	    elsif (D (XD_SOURCE_NAME, PRIOR_DEF).TY = DN_TYPE_ID and then D (SM_TYPE_SPEC, D (XD_SOURCE_NAME, PRIOR_DEF)).TY = DN_INCOMPLETE) then
	      REMOVE_DEF_FROM_ENVIRONMENT (SOURCE_DEF);
	      D (SM_FIRST, SOURCE_NAME, D (XD_SOURCE_NAME, PRIOR_DEF));
	      D (XD_FULL_TYPE_SPEC, D (SM_TYPE_SPEC, D (XD_SOURCE_NAME, PRIOR_DEF)), TASK_SPEC);
	      SOURCE_DEF := PRIOR_DEF;
	    else
	      ERROR (D (LX_SRCPOS, SOURCE_NAME), "DUPLICATE NAME FOR TASK - " & PRINT_NAME (D (LX_SYMREP, SOURCE_NAME)));
	      MAKE_DEF_IN_ERROR (SOURCE_DEF);
	    end if;
	    D (XD_SOURCE_NAME, TASK_SPEC, D (XD_SOURCE_NAME, SOURCE_DEF));
	  else
	    MAKE_DEF_VISIBLE (SOURCE_DEF);
	  end if;
	else
	  D (SM_OBJ_TYPE, SOURCE_NAME, TASK_SPEC);
	  CHECK_UNIQUE_DEF (SOURCE_DEF);
	end if;

	ENTER_REGION (SOURCE_DEF, H, S);
	WALK_ITEM_S (DECL_S, H);
	LEAVE_REGION (SOURCE_DEF, S);
        end;

      when DN_GENERIC_DECL =>
        declare
	SOURCE_NAME : TREE	   := D (AS_SOURCE_NAME, NODE);
	HEADER	  : TREE	   := D (AS_HEADER, NODE);
	ITEM_S	  : TREE	   := D (AS_ITEM_S, NODE);
	ITEM_LIST	  : SEQ_TYPE := LIST (ITEM_S);
	ITEM	  : TREE;

	H	 : H_TYPE := WALK.H;
	S	 : S_TYPE;
	SOURCE_DEF : TREE	:= MAKE_DEF_FOR_ID (SOURCE_NAME, H);
        begin
	D (SM_FIRST, SOURCE_NAME, SOURCE_NAME);
	D (SM_SPEC, SOURCE_NAME, HEADER);
	D (SM_GENERIC_PARAM_S, SOURCE_NAME, ITEM_S);

	CHECK_UNIQUE_DEF (SOURCE_DEF);

	ENTER_REGION (SOURCE_DEF, H, S);
	while not IS_EMPTY (ITEM_LIST) loop
	  POP (ITEM_LIST, ITEM);
	  WALK (ITEM, H);
	  if ITEM.TY in CLASS_PARAM then
	    FINISH_PARAM_DECL (ITEM, H);
	  end if;
	end loop;
	H.SUBP_SYMREP := D (LX_SYMREP, SOURCE_NAME);
				--IF KIND ( HEADER) IN CLASS_SUBP_ENTRY_HEADER THEN
				--    WALK_ITEM_S(D ( AS_PARAM_S,HEADER), H);
				--END IF;
	WALK_HEADER (HEADER, H);
	LEAVE_REGION (SOURCE_DEF, S);
	MAKE_DEF_VISIBLE (SOURCE_DEF, HEADER);
        end;

      when DN_SUBPROG_ENTRY_DECL =>
        declare
	SOURCE_NAME : TREE := D (AS_SOURCE_NAME, NODE);
	HEADER	  : TREE := D (AS_HEADER, NODE);
	UNIT_KIND	  : TREE := D (AS_UNIT_KIND, NODE);

	H	 : H_TYPE := WALK.H;
	S	 : S_TYPE;
	SOURCE_DEF : TREE;
	PRIOR_DEF  : TREE;
        begin
	if SOURCE_NAME.TY = DN_OPERATOR_ID then
	  FORCE_UPPER_CASE (SOURCE_NAME);
	end if;
	SOURCE_DEF := MAKE_DEF_FOR_ID (SOURCE_NAME, H);
	D (SM_SPEC, SOURCE_NAME, HEADER);
	if SOURCE_NAME.TY /= DN_ENTRY_ID then
	  D (SM_FIRST, SOURCE_NAME, SOURCE_NAME);
	  D (SM_UNIT_DESC, SOURCE_NAME, UNIT_KIND);
	end if;

	if HEADER /= TREE_VOID then
	  ENTER_REGION (SOURCE_DEF, H, S);
	  H.SUBP_SYMREP := D (LX_SYMREP, SOURCE_NAME);
				        --WALK_ITEM_S(D ( AS_PARAM_S,HEADER), H);
	  WALK_HEADER (HEADER, H);
	  LEAVE_REGION (SOURCE_DEF, S);
	  H := WALK.H;
	end if;
	WALK_UNIT_DESC (SOURCE_NAME, UNIT_KIND, H, HEADER);
	HEADER := D (SM_SPEC, SOURCE_NAME);
				-- IN CASE INSTANTIATION
	if HEADER.TY = DN_ENTRY and then D (AS_DISCRETE_RANGE, HEADER) /= TREE_VOID then
				        -- IT IS AN ENTRY FAMILY
	  MAKE_DEF_VISIBLE (SOURCE_DEF);
	  PRIOR_DEF := GET_PRIOR_DEF (SOURCE_DEF);
	else
	  MAKE_DEF_VISIBLE (SOURCE_DEF, HEADER);
	  PRIOR_DEF := GET_PRIOR_HOMOGRAPH_DEF (SOURCE_DEF);
	end if;
	if PRIOR_DEF /= TREE_VOID then
	  if D (XD_HEADER, PRIOR_DEF) /= TREE_FALSE then
	    ERROR (D (LX_SRCPOS, SOURCE_NAME), "DUPLICATE DEF FOR SUBPROGRAM NAME - " & PRINT_NAME (D (LX_SYMREP, SOURCE_NAME)));
	  end if;
	  MAKE_DEF_IN_ERROR (SOURCE_DEF);
	else
	  CHECK_EQUALITY_OPERATOR (SOURCE_NAME, H);
	end if;
        end;

      when DN_PACKAGE_DECL =>
        declare
	SOURCE_NAME : TREE := D (AS_SOURCE_NAME, NODE);
	HEADER	  : TREE := D (AS_HEADER, NODE);
	UNIT_KIND	  : TREE := D (AS_UNIT_KIND, NODE);

	H	 : H_TYPE := WALK.H;
	S	 : S_TYPE;
	SOURCE_DEF : TREE	:= MAKE_DEF_FOR_ID (SOURCE_NAME, H);
        begin
	D (SM_FIRST, SOURCE_NAME, SOURCE_NAME);
	D (SM_SPEC, SOURCE_NAME, HEADER);
	D (SM_UNIT_DESC, SOURCE_NAME, UNIT_KIND);

	CHECK_UNIQUE_DEF (SOURCE_DEF);
	WALK_UNIT_DESC (SOURCE_NAME, UNIT_KIND, H);
	MAKE_DEF_VISIBLE (SOURCE_DEF);
	if HEADER /= TREE_VOID then
	  ENTER_REGION (SOURCE_DEF, H, S);
	  WALK_HEADER (HEADER, H);
	  LEAVE_REGION (SOURCE_DEF, S);
	end if;
        end;
		    -- FOR A RENAMING DECLARATION FOR AN OBJECT
      when DN_RENAMES_OBJ_DECL =>
        declare
	SOURCE_NAME    : TREE := D (AS_SOURCE_NAME, NODE);
	NAME	     : TREE := D (AS_NAME, NODE);
	TYPE_MARK_NAME : TREE := D (AS_TYPE_MARK_NAME, NODE);

	SOURCE_DEF : TREE := MAKE_DEF_FOR_ID (SOURCE_NAME, H);
	BASE_TYPE  : TREE;
	TYPESET	 : TYPESET_TYPE;
        begin
				-- EVALUATE AND RESOLVE THE TYPE MARK
	BASE_TYPE	     := GET_BASE_TYPE (EVAL_TYPE_MARK (TYPE_MARK_NAME));
	TYPE_MARK_NAME := RESOLVE_TYPE_MARK (TYPE_MARK_NAME);
	D (AS_TYPE_MARK_NAME, NODE, TYPE_MARK_NAME);
				-- EVALUATE THE NAME BEING REDEFINED; REQUIRE SAME BASE TYPE
	EVAL_EXP_TYPES (NAME, TYPESET);
	REQUIRE_TYPE (BASE_TYPE, NAME, TYPESET);
	NAME := RESOLVE_EXP (NAME, TYPESET);
				-- IF A CONSTANT (OR IN PARAMETER) IS BEING RENAMED
	if IS_CONSTANT_EXP (NAME) then
				        -- REPLACE VARIABLE_ID WITH CONSTANT_ID
				        -- SM_FIRST ADDED 8-17-91 WBE
	  SOURCE_NAME := MAKE_CONSTANT_ID (LX_SRCPOS => D (LX_SRCPOS, SOURCE_NAME), LX_SYMREP => D (LX_SYMREP, SOURCE_NAME), XD_REGION => D (XD_REGION, SOURCE_NAME));
	  D (SM_FIRST, SOURCE_NAME, SOURCE_NAME);
	  D (AS_SOURCE_NAME, NODE, SOURCE_NAME);
				        -- FIX UP DEF TO POINT TO NEWLY-CREATED CONSTANT_ID
	  D (XD_SOURCE_NAME, SOURCE_DEF, SOURCE_NAME);
	end if;
				-- STORE REMAINING ATTRIBUTES OF SOURCE NAME
	D (SM_INIT_EXP, SOURCE_NAME, NAME);
	DB (SM_RENAMES_OBJ, SOURCE_NAME, True);
	D (SM_OBJ_TYPE, SOURCE_NAME, D (SM_EXP_TYPE, NAME));
				-- CHECK THAT SOURCE NAME IS UNIQUE AND MAKE IT VISIBLE
	CHECK_UNIQUE_DEF (SOURCE_DEF);
        end;

      when DN_RENAMES_EXC_DECL =>
        declare
	SOURCE_NAME : TREE := D (AS_SOURCE_NAME, NODE);
	NAME	  : TREE := D (AS_NAME, NODE);

	SOURCE_DEF : TREE := MAKE_DEF_FOR_ID (SOURCE_NAME, H);
        begin

				-- WALK THE REDEFINED EXCEPTION NAME
	NAME := WALK_NAME (DN_EXCEPTION_ID, NAME);
	D (AS_NAME, NODE, NAME);

				-- $$$$ WHAT ABOUT WHEN NAME IS A RENAMED EXCEPTION ?

				-- INSERT REDEFINED NAME IN SOURCE NAME
	if NAME.TY = DN_SELECTED then
	  NAME := D (AS_DESIGNATOR, NAME);
	end if;
	D (SM_RENAMES_EXC, SOURCE_NAME, D (SM_DEFN, NAME));

				-- ADDED 6/29/90 (OMITTED.  WHY WASN'T IT FOUND BY ACVC?)
				-- CHECK FOR UNIQUE NAMES AND MAKE VISIBLE
	CHECK_UNIQUE_DEF (SOURCE_DEF);
        end;

      when DN_NULL_COMP_DECL =>
        declare
        begin
	null;
        end;

      when  DN_LENGTH_ENUM_REP =>
        declare
	NAME : TREE := D (AS_NAME, NODE);
	EXP  : TREE := D (AS_EXP, NODE);

        begin
	if  NAME.TY = DN_ATTRIBUTE  then								-- IF IT IS A LENGTH CLAUSE
	  REP_CLAU.RESOLVE_LENGTH_REP( NAME, EXP, H );
	  D( AS_EXP, NODE, EXP );

	else											-- IT IS AN ENUMERATION REPRESENTATION CLAUSE
	  REP_CLAU.RESOLVE_ENUM_REP (NAME, EXP, H);
	  D (AS_NAME, NODE, NAME);
	end if;
        end;

      when DN_ADDRESS =>
        declare
	NAME : TREE := D (AS_NAME, NODE);
	EXP  : TREE := D (AS_EXP, NODE);
        begin
	REP_CLAU.RESOLVE_ADDRESS_REP (NAME, EXP, H);
	D (AS_NAME, NODE, NAME);
	D (AS_EXP, NODE, EXP);
        end;

      when DN_RECORD_REP =>
        declare
	NAME	       : TREE := D (AS_NAME, NODE);
	ALIGNMENT_CLAUSE : TREE := D (AS_ALIGNMENT_CLAUSE, NODE);
	COMP_REP_S       : TREE := D (AS_COMP_REP_S, NODE);
        begin
	REP_CLAU.RESOLVE_RECORD_REP (NAME, ALIGNMENT_CLAUSE, COMP_REP_S, H);
	D (AS_NAME, NODE, NAME);
	D (AS_ALIGNMENT_CLAUSE, NODE, ALIGNMENT_CLAUSE);
	D (AS_COMP_REP_S, NODE, COMP_REP_S);
	if D (SM_DEFN, NAME).TY in CLASS_TYPE_NAME and GET_BASE_TYPE (NAME).TY = DN_RECORD then
	  D (SM_REPRESENTATION, GET_BASE_TYPE (NAME), NODE);
	end if;
        end;
		    -- FOR A USE CLAUSE (NOT PART OF A CONTEXT CLAUSE)
      when DN_USE =>
        declare
	NAME_S : TREE := D (AS_NAME_S, NODE);

	NAME_LIST	    : SEQ_TYPE := LIST (NAME_S);
	NAME	    : TREE;
	NAME_DEFN	    : TREE;
	NEW_NAME_LIST : SEQ_TYPE := (TREE_NIL, TREE_NIL);
	PACKAGE_DEF   : TREE;
        begin

				-- FOR EACH USED NAME
	while not IS_EMPTY (NAME_LIST) loop
	  POP (NAME_LIST, NAME);
				        -- EVALUATE AND RESOLVE PACKAGE NAME
	  NAME	      := WALK_NAME (DN_PACKAGE_ID, NAME);
	  NEW_NAME_LIST := APPEND (NEW_NAME_LIST, NAME);
				        -- GET THE PACKAGE ID OF THE ORIGINAL (UNRENAMED) PACKAGE
	  loop
	    if NAME.TY = DN_SELECTED then
	      NAME := D (AS_DESIGNATOR, NAME);
	    end if;
	    NAME_DEFN := D (SM_DEFN, NAME);
	    exit when NAME_DEFN.TY /= DN_PACKAGE_ID or else D (SM_UNIT_DESC, NAME_DEFN).TY /= DN_RENAMES_UNIT;
	    NAME := D (AS_NAME, D (SM_UNIT_DESC, NAME_DEFN));
	  end loop;
				        -- IF IT IS INDEED A PACKAGE ID
	  if NAME_DEFN.TY = DN_PACKAGE_ID then
					      -- GET THE DEF CORRESPONDING TO THE PACKAGE
	    PACKAGE_DEF := GET_DEF_FOR_ID (NAME_DEFN);

					      -- IF IT IS NOT AN ENCLOSING REGION AND NOT USED
	    if DI (XD_LEX_LEVEL, PACKAGE_DEF) <= 0 and then not DB (XD_IS_USED, PACKAGE_DEF) then

						    -- MARK IT USED
	      DB (XD_IS_USED, PACKAGE_DEF, True);

						    -- ADD IT TO LIST OF USED REGIONS
	      SU.USED_PACKAGE_LIST := INSERT (SU.USED_PACKAGE_LIST, PACKAGE_DEF);
	    end if;
	  end if;
	end loop;

				-- REPLACE NAME LIST WITH LIST OF RESOLVED NAMES
	LIST (NAME_S, NEW_NAME_LIST);
        end;

      when DN_PRAGMA =>
        declare
	USED_NAME_ID    : TREE := D (AS_USED_NAME_ID, NODE);
	GENERAL_ASSOC_S : TREE := D (AS_GENERAL_ASSOC_S, NODE);
        begin
	WALK_PRAGMA (USED_NAME_ID, GENERAL_ASSOC_S, H);
        end;

      when DN_SUBPROGRAM_BODY =>
        declare
	SOURCE_NAME  : TREE := D( AS_SOURCE_NAME, NODE );
	FIRST_NAME   : TREE := D( SM_FIRST, SOURCE_NAME );
	BODY_NODE	   : TREE := D( AS_BODY, NODE );
	FIRST_HEADER : TREE := TREE_VOID;
	HEADER	   : TREE := D( AS_HEADER, NODE );

	H	 : H_TYPE := WALK.H;
	S	 : S_TYPE;
	SOURCE_DEF : TREE;
	PRIOR_DEF  : TREE;
        begin
	if SOURCE_NAME.TY = DN_OPERATOR_ID then
	  FORCE_UPPER_CASE (SOURCE_NAME);
	end if;
	SOURCE_DEF := MAKE_DEF_FOR_ID (SOURCE_NAME, H);
	D( SM_SPEC, SOURCE_NAME, HEADER);
	D( SM_UNIT_DESC, SOURCE_NAME, TREE_VOID);
	D( XD_BODY, FIRST_NAME, NODE );

	if FIRST_NAME = SOURCE_NAME then
	  PRIOR_DEF := GET_PRIOR_DEF (SOURCE_DEF);
	  if PRIOR_DEF /= TREE_VOID and then D (XD_SOURCE_NAME, PRIOR_DEF).TY = DN_GENERIC_ID then
	    FIRST_NAME := D (XD_SOURCE_NAME, PRIOR_DEF);
	    PRIOR_DEF  := GET_DEF_FOR_ID (FIRST_NAME);
	    D( XD_BODY, FIRST_NAME, NODE );
	  else
	    PRIOR_DEF := SOURCE_DEF;
	  end if;
	else
	  PRIOR_DEF := GET_DEF_FOR_ID (FIRST_NAME);
				        -- LIBRARY UNIT WITH EXISTING SUBPROGRAM SPEC
				        -- $$$$ WORRY ABOUT KILLING PRIOR BODY IN THIS COMPILATION
	  D (XD_REGION_DEF, PRIOR_DEF, H.REGION_DEF);
	end if;

	if SOURCE_DEF /= PRIOR_DEF and then D (SM_SPEC, D (XD_SOURCE_NAME, SOURCE_DEF)) = D (SM_SPEC, D (XD_SOURCE_NAME, PRIOR_DEF)) then
				        -- (SPEC WAS GENERATED IN LIBPHASE; DO NOT REDO IT)
	  null;
	else
	  ENTER_REGION (SOURCE_DEF, H, S);
				        --WALK_ITEM_S(D ( AS_PARAM_S,HEADER), H);
	  H.SUBP_SYMREP := D (LX_SYMREP, SOURCE_NAME);
	  if SOURCE_DEF /= PRIOR_DEF and then FIRST_NAME.TY = DN_GENERIC_ID then
					      -- (SPEC IS GENERIC) - $$$$
	    SWITCH_REGION (FIRST_NAME, SOURCE_DEF);
	    WALK_HEADER (HEADER, H);
	    SWITCH_REGION (FIRST_NAME, PRIOR_DEF);
	  else
	    WALK_HEADER (HEADER, H);
	  end if;
	  LEAVE_REGION (SOURCE_DEF, S);
	  H := WALK.H;
	end if;

	if FIRST_NAME = SOURCE_NAME then
				        -- (LOOK FOR A SUBPROGRAM DECLARATION)
	  MAKE_DEF_VISIBLE (SOURCE_DEF, HEADER);
	  PRIOR_DEF := GET_PRIOR_HOMOGRAPH_DEF (SOURCE_DEF);
	  if PRIOR_DEF /= TREE_VOID then
	    REMOVE_DEF_FROM_ENVIRONMENT (SOURCE_DEF);
	    FIRST_NAME := D (XD_SOURCE_NAME, PRIOR_DEF);
	  end if;
	end if;
	if PRIOR_DEF = TREE_VOID then
	  MAKE_DEF_VISIBLE (SOURCE_DEF, HEADER);
	  CHECK_EQUALITY_OPERATOR (SOURCE_NAME, H);
	else
	  if FIRST_NAME.TY in CLASS_SUBPROG_NAME or FIRST_NAME.TY = DN_GENERIC_ID then
	    FIRST_HEADER := D (SM_SPEC, FIRST_NAME);
	  end if;
	  if FIRST_HEADER.TY /= HEADER.TY then
	    if D (XD_HEADER, PRIOR_DEF) /= TREE_FALSE then
	      ERROR (D (LX_SRCPOS, SOURCE_NAME), "DUPLICATE DEF FOR SUBPROGRAM NAME - " & PRINT_NAME (D (LX_SYMREP, SOURCE_NAME)));
	    end if;
	    MAKE_DEF_IN_ERROR (SOURCE_DEF);
	    FIRST_NAME := SOURCE_NAME;
	  else
	    D (SM_FIRST, SOURCE_NAME, FIRST_NAME);
	  end if;
	end if;

	if FIRST_NAME /= SOURCE_NAME then
				        --D ( XD_BODY, FIRST_NAME, BODY_NODE);
	  D (SM_SPEC, SOURCE_NAME, D (SM_SPEC, FIRST_NAME));
	  CONFORM_PARAMETER_LISTS (D (AS_PARAM_S, D (SM_SPEC, FIRST_NAME)), D (AS_PARAM_S, HEADER));
	  REMOVE_DEF_FROM_ENVIRONMENT (SOURCE_DEF);
	  SOURCE_DEF := PRIOR_DEF;
	end if;

	ENTER_BODY (SOURCE_DEF, H, S);
	if FIRST_NAME.TY = DN_GENERIC_ID then
	  MAKE_DEF_VISIBLE (SOURCE_DEF, D (SM_SPEC, FIRST_NAME));
	end if;
	if D (XD_HEADER, SOURCE_DEF).TY = DN_FUNCTION_SPEC then
	  H.RETURN_TYPE := GET_BASE_TYPE (D (AS_NAME, D (XD_HEADER, SOURCE_DEF)));
	end if;
	WALK_UNIT_DESC (SOURCE_NAME, BODY_NODE, H);
	if FIRST_NAME.TY = DN_GENERIC_ID then
	  MAKE_DEF_VISIBLE (SOURCE_DEF);
	end if;
	LEAVE_BODY (SOURCE_DEF, S);
        end;

      when DN_PACKAGE_BODY =>
        declare
	SOURCE_NAME : TREE := D (AS_SOURCE_NAME, NODE);
	BODY_NODE	  : TREE := D (AS_BODY, NODE);

	FIRST_NAME : TREE;
	H	 : H_TYPE := WALK.H;
	S	 : S_TYPE;
	SOURCE_DEF : TREE;
        begin
				-- CHECK FOR LIBRARY UNIT WITH EXISTING PACKAGE SPEC
				-- $$$$ WORRY ABOUT KILLING PRIOR BODY IN THIS COMPILATION
	FIRST_NAME := D (SM_FIRST, SOURCE_NAME);
	if FIRST_NAME /= SOURCE_NAME then
	  SOURCE_DEF := GET_DEF_FOR_ID (D (SM_FIRST, SOURCE_NAME));
	  D (XD_REGION_DEF, SOURCE_DEF, H.REGION_DEF);
	end if;

	SOURCE_DEF := GET_DEF_IN_REGION (SOURCE_NAME, H);
	if SOURCE_DEF = TREE_VOID then
	  ERROR (D (LX_SRCPOS, NODE), "NO SPECIFICATION FOUND FOR PACKAGE - " & PRINT_NAME (D (LX_SYMREP, SOURCE_NAME)));
	  SOURCE_DEF := MAKE_DEF_FOR_ID (SOURCE_NAME, H);
	  D (SM_SPEC, SOURCE_NAME, TREE_VOID);
				        -- AVOID CRASH
	  MAKE_DEF_IN_ERROR (SOURCE_DEF);
	else
	  FIRST_NAME := D (XD_SOURCE_NAME, SOURCE_DEF);
	  if FIRST_NAME.TY /= DN_PACKAGE_ID and then (FIRST_NAME.TY /= DN_GENERIC_ID or else D (SM_SPEC, FIRST_NAME).TY /= DN_PACKAGE_SPEC) then
	    ERROR (D (LX_SRCPOS, NODE), "DUPLICATE NAME FOR PACKAGE - " & PRINT_NAME (D (LX_SYMREP, SOURCE_NAME)));
	    SOURCE_DEF := MAKE_DEF_FOR_ID (SOURCE_NAME, H);
	    MAKE_DEF_IN_ERROR (SOURCE_DEF);
	    FIRST_NAME := SOURCE_NAME;
	  elsif D (XD_BODY, FIRST_NAME) /= TREE_VOID then
	    ERROR (D (LX_SRCPOS, NODE), "DUPLICATE BODY FOR PACKAGE - " & PRINT_NAME (D (LX_SYMREP, SOURCE_NAME)));
	  end if;
	end if;

	D (SM_FIRST, SOURCE_NAME, FIRST_NAME);
	D (SM_SPEC, SOURCE_NAME, D (SM_SPEC, FIRST_NAME));
	D (SM_UNIT_DESC, SOURCE_NAME, TREE_VOID);
	D (XD_REGION, SOURCE_NAME, D (XD_REGION, FIRST_NAME));
	if BODY_NODE.TY = DN_STUB then
	  null;
				        -- D ( XD_STUB, SOURCE_NAME, SOURCE_NAME);
				        -- D ( XD_STUB, FIRST_NAME, SOURCE_NAME);
	else
				        -- D ( XD_BODY, FIRST_NAME, NODE);
				        -- D ( XD_BODY, SOURCE_NAME, NODE);
				        -- D ( XD_STUB, SOURCE_NAME, D ( XD_STUB, FIRST_NAME));
	  ENTER_BODY (SOURCE_DEF, H, S);
				        -- SCAN SPEC FOR USE CLAUSES
	  declare
	    SPEC : TREE := D (SM_SPEC, SOURCE_NAME);
	  begin
	    if SPEC /= TREE_VOID then
	      REPROCESS_USE_CLAUSES (D (AS_DECL_S1, SPEC), H);
	      REPROCESS_USE_CLAUSES (D (AS_DECL_S2, SPEC), H);
	    end if;
	  end;
	  WALK_UNIT_DESC (SOURCE_NAME, BODY_NODE, H);
	  LEAVE_BODY (SOURCE_DEF, S);
	end if;
        end;

      when DN_TASK_BODY =>
        declare
	SOURCE_NAME : TREE := D (AS_SOURCE_NAME, NODE);
	BODY_NODE	  : TREE := D (AS_BODY, NODE);

	H : H_TYPE := WALK.H;
	S : S_TYPE;

	SOURCE_DEF : TREE := MAKE_DEF_FOR_ID (SOURCE_NAME, H);
	PRIOR_DEF  : TREE;
	PRIOR_NAME : TREE;
	TASK_TYPE  : TREE := TREE_VOID;
        begin

	PRIOR_DEF := GET_PRIOR_DEF (SOURCE_DEF);
	if PRIOR_DEF /= TREE_VOID then
	  TASK_TYPE := GET_BASE_TYPE (D (XD_SOURCE_NAME, PRIOR_DEF));
	end if;

	D (SM_TYPE_SPEC, SOURCE_NAME, TASK_TYPE);
	D (SM_BODY, SOURCE_NAME, BODY_NODE);
	if TASK_TYPE.TY /= DN_TASK_SPEC then
	  ERROR (D (LX_SRCPOS, NODE), "NO TASK [TYPE] DECLARATION");
	  MAKE_DEF_IN_ERROR (SOURCE_DEF);
	  PRIOR_NAME := SOURCE_NAME;
	  TASK_TYPE  := TREE_VOID;
	else
	  REMOVE_DEF_FROM_ENVIRONMENT (SOURCE_DEF);
	  PRIOR_NAME := D (XD_SOURCE_NAME, PRIOR_DEF);
	  D (SM_FIRST, SOURCE_NAME, PRIOR_NAME);
	  if D (XD_BODY, TASK_TYPE) /= TREE_VOID or else (D (XD_STUB, TASK_TYPE) /= TREE_VOID and then BODY_NODE.TY = DN_STUB) then
	    ERROR (D (LX_SRCPOS, SOURCE_NAME), "DUPLICATE BODY OR STUB DECLARATION");
	    TASK_TYPE := TREE_VOID;
	  else
	    SOURCE_DEF := PRIOR_DEF;
					      --D ( SM_BODY, TASK_TYPE, BODY_NODE);
	  end if;
	end if;

	if BODY_NODE.TY /= DN_STUB then
	  if TASK_TYPE /= TREE_VOID then
	    null;
					      -- D ( XD_BODY, TASK_TYPE, BODY_NODE);
	  end if;
	else
	  if TASK_TYPE /= TREE_VOID then
	    null;
					      -- D ( XD_STUB, TASK_TYPE, SOURCE_NAME);
	  end if;
	end if;

	ENTER_BODY (SOURCE_DEF, H, S);
	WALK_UNIT_DESC (SOURCE_NAME, BODY_NODE, H);
	LEAVE_BODY (SOURCE_DEF, S);
        end;

    end case;

  end WALK;
      --||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
      --|	      PROCEDURE WALK_SOURCE_NAME_S
  procedure WALK_SOURCE_NAME_S (SOURCE_NAME_S : TREE; H : H_TYPE) is
    SOURCE_NAME_LIST : SEQ_TYPE := LIST (SOURCE_NAME_S);
    SOURCE_NAME	 : TREE;
    DUMMY_DEF	 : TREE;
  begin
    while not IS_EMPTY (SOURCE_NAME_LIST) loop
      POP (SOURCE_NAME_LIST, SOURCE_NAME);
      DUMMY_DEF := MAKE_DEF_FOR_ID (SOURCE_NAME, H);
    end loop;
  end WALK_SOURCE_NAME_S;

      --||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
      --|	      PROCEDURE ENTER_REGION
  procedure ENTER_REGION (DEF : TREE; H : in out H_TYPE; S : out S_TYPE) is
  begin
--    S.SB	       := SB;
    S.SU	       := SU;
    H.REGION_DEF := DEF;
    H.LEX_LEVEL  := H.LEX_LEVEL + 1;
    DI (XD_LEX_LEVEL, DEF, H.LEX_LEVEL);
    H.IS_IN_SPEC	     := True;
    H.IS_IN_BODY	     := False;
    H.RETURN_TYPE	     := TREE_VOID;
    SU.USED_PACKAGE_LIST := (TREE_NIL, TREE_NIL);
  end ENTER_REGION;
      --||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
      --|	      PROCEDURE LEAVE_REGION
  procedure LEAVE_REGION (DEF : TREE; S : S_TYPE) is
    PACKAGE_DEF : TREE;
  begin
    DI (XD_LEX_LEVEL, DEF, 0);
    while not IS_EMPTY (SU.USED_PACKAGE_LIST) loop
      POP (SU.USED_PACKAGE_LIST, PACKAGE_DEF);
      DB (XD_IS_USED, PACKAGE_DEF, False);
    end loop;
--    SB :=	S.SB;
    SU := S.SU;
  end LEAVE_REGION;
      --||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
      --|	      PROCEDURE ENTER_BODY
  procedure ENTER_BODY (DEF : TREE; H : in out H_TYPE; S : out S_TYPE) is
  begin
    ENTER_REGION (DEF, H, S);
    H.IS_IN_SPEC := False;
    H.IS_IN_BODY := True;
    if D (XD_SOURCE_NAME, DEF).TY = DN_GENERIC_ID and then D (XD_HEADER, DEF) /= TREE_FALSE then
      MAKE_DEF_VISIBLE (DEF, D (SM_SPEC, D (XD_SOURCE_NAME, DEF)));
    end if;
  end ENTER_BODY;
      --||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
      --|	      PROCEDURE LEAVE_BODY
  procedure LEAVE_BODY (DEF : TREE; S : S_TYPE) is
  begin
    LEAVE_REGION (DEF, S);
    if D (XD_SOURCE_NAME, DEF).TY = DN_GENERIC_ID and then D (XD_HEADER, DEF) /= TREE_FALSE then
      MAKE_DEF_VISIBLE (DEF);
    end if;
  end LEAVE_BODY;

  procedure FINISH_VARIABLE_DECL (NODE : TREE; H : H_TYPE) is
    SOURCE_NAME_S : TREE := D (AS_SOURCE_NAME_S, NODE);
    EXP	        : TREE := D (AS_EXP, NODE);
    TYPE_DEF      : TREE := D (AS_TYPE_DEF, NODE);

    TYPE_SPEC : TREE;
    TYPESET   : TYPESET_TYPE;
  begin
    TYPE_SPEC := EVAL_SUBTYPE_INDICATION (TYPE_DEF);
    RESOLVE_SUBTYPE_INDICATION (TYPE_DEF, TYPE_SPEC);
    D (AS_TYPE_DEF, NODE, TYPE_DEF);

    if EXP /= TREE_VOID then
      if not IS_NONLIMITED_TYPE (TYPE_SPEC) then
        ERROR (D (LX_SRCPOS, TYPE_DEF), "INITIAL VALUE FOR LIMITED TYPE");
        TYPE_SPEC := TREE_VOID;
      end if;

      EVAL_EXP_TYPES (EXP, TYPESET);
      REQUIRE_TYPE (GET_BASE_TYPE (TYPE_SPEC), EXP, TYPESET);
      EXP := RESOLVE_EXP (EXP, TYPESET);
    end if;

    INSERT_OBJ_TYPE_AND_INIT_EXP_IN_S (SOURCE_NAME_S, OBJ_TYPE => TYPE_SPEC, INIT_EXP => EXP);
  end FINISH_VARIABLE_DECL;

  function WALK_EXP_MUST_BE_NAME (NAME : TREE) return TREE is
    NAME_KIND : NODE_NAME := NAME.TY;
    DEFSET    : DEFSET_TYPE;
  begin
    if NAME_KIND = DN_USED_OBJECT_ID or NAME_KIND = DN_SELECTED then
      FIND_VISIBILITY (NAME, DEFSET);
      REQUIRE_UNIQUE_DEF (NAME, DEFSET);
      return RESOLVE_NAME (NAME, GET_THE_ID (DEFSET));
    else
      ERROR (D (LX_SRCPOS, NAME), "NAME REQUIRED");
      return WALK_ERRONEOUS_EXP (NAME);
    end if;
  end WALK_EXP_MUST_BE_NAME;

  function WALK_NAME (ID_KIND : NODE_NAME; NAME : TREE) return TREE is
    NEW_NAME  : constant TREE := WALK_EXP_MUST_BE_NAME (NAME);
    NAME_DEFN : TREE	:= GET_NAME_DEFN (NEW_NAME);
  begin

    if NAME_DEFN = TREE_VOID or else NAME_DEFN.TY = ID_KIND then
      null;
    elsif ID_KIND = DN_PACKAGE_ID and then NAME_DEFN.TY = DN_GENERIC_ID and then D (SM_SPEC, NAME_DEFN).TY = DN_PACKAGE_SPEC and then DI (XD_LEX_LEVEL, GET_DEF_FOR_ID (NAME_DEFN)) > 0 then
      null;
    else
      ERROR (D (LX_SRCPOS, NAME), "NAME MUST BE " & NODE_IMAGE (ID_KIND));
		    -- ADDED WBE 9/21/90
		    -- CLEAR DEFN IF WRONG KIND
      if NEW_NAME.TY = DN_SELECTED then
        D (SM_DEFN, D (AS_DESIGNATOR, NEW_NAME), TREE_VOID);
      else
        D (SM_DEFN, NEW_NAME, TREE_VOID);
      end if;
    end if;

    return NEW_NAME;
  end WALK_NAME;

  function WALK_TYPE_MARK (NAME : TREE) return TREE is
    NEW_NAME  : constant TREE := WALK_EXP_MUST_BE_NAME (NAME);
    NAME_DEFN : TREE	:= GET_NAME_DEFN (NEW_NAME);
  begin

    if NAME_DEFN.TY not in CLASS_TYPE_NAME and then NAME_DEFN /= TREE_VOID then
      ERROR (D (LX_SRCPOS, NAME), "TYPE MARK REQUIRED");
    end if;

    return NEW_NAME;
  end WALK_TYPE_MARK;

  procedure WALK_DISCRETE_CHOICE_S (CHOICE_S : TREE; TYPE_SPEC : TREE) is
    CHOICE_LIST : SEQ_TYPE := LIST (CHOICE_S);
    CHOICE      : TREE;

    NEW_CHOICE_LIST : SEQ_TYPE := (TREE_NIL, TREE_NIL);
    EXP		: TREE;
    TYPESET	: TYPESET_TYPE;
    IS_SUBTYPE	: Boolean;
  begin
    while not IS_EMPTY (CHOICE_LIST) loop
      POP (CHOICE_LIST, CHOICE);

      case CLASS_CHOICE'(CHOICE.TY) is
        when DN_CHOICE_EXP =>
	EXP := D (AS_EXP, CHOICE);
	EVAL_EXP_SUBTYPE_TYPES (EXP, TYPESET, IS_SUBTYPE);
	REQUIRE_TYPE (TYPE_SPEC, EXP, TYPESET);
	if not IS_SUBTYPE then
	  EXP := RESOLVE_EXP (EXP, GET_THE_TYPE (TYPESET));
	  D (AS_EXP, CHOICE, EXP);
	else
	  EXP    := RESOLVE_DISCRETE_RANGE (EXP, GET_THE_TYPE (TYPESET));
	  CHOICE := MAKE_CHOICE_RANGE (LX_SRCPOS => D (LX_SRCPOS, CHOICE), AS_DISCRETE_RANGE => EXP);

	end if;
        when DN_CHOICE_RANGE =>
	EXP := D (AS_DISCRETE_RANGE, CHOICE);
	EVAL_DISCRETE_RANGE (EXP, TYPESET);
	REQUIRE_TYPE (TYPE_SPEC, EXP, TYPESET);
	EXP := RESOLVE_DISCRETE_RANGE (EXP, GET_THE_TYPE (TYPESET));
	D (AS_DISCRETE_RANGE, CHOICE, EXP);

        when DN_CHOICE_OTHERS =>
	null;
      end case;

      NEW_CHOICE_LIST := APPEND (NEW_CHOICE_LIST, CHOICE);
    end loop;
    LIST (CHOICE_S, NEW_CHOICE_LIST);
  end WALK_DISCRETE_CHOICE_S;


			-----------
  procedure		WALK_ITEM_S		( ITEM_S :TREE; H :H_TYPE )
  is			-----------

    ITEM_LIST	: SEQ_TYPE	:= LIST (ITEM_S);
    ITEM		: TREE;

  begin
    while  not IS_EMPTY( ITEM_LIST )  loop
      POP( ITEM_LIST, ITEM );
      WALK( ITEM, H );
    end loop;

  end	WALK_ITEM_S;
	-----------


end	NOD_WALK;
	--------
