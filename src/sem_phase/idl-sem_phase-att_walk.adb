------------------------------------------------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2026 VINCENT MORIN, UBO
-- SPDX-License-Identifier: GPL-3.0-or-later
------------------------------------------------------------------------------------------------------------------------
--	1	2	3	4	5	6	7	8	9	0	1	2

separate (IDL.SEM_PHASE)
    --|----------------------------------------------------------------------------------------------
    --| ATT_WALK
    --|----------------------------------------------------------------------------------------------
package body ATT_WALK is
  use REQ_UTIL;
  use VIS_UTIL;
  use DEF_UTIL;
  use SET_UTIL;
  use UARITH;
  use PRENAME;
  use EXP_TYPE, EXPRESO;
  use MAKE_NOD;
  use SEM_GLOB;
  use RED_SUBP;
  use CHK_STAT;

  procedure WALK_ATTRIBUTE_PREFIX (PREFIX : in out TREE; PREFIX_ID : out TREE; PREFIX_TYPE : out TREE; ATTRIBUTE_ID : TREE);

  procedure CHECK_PREFIX_AND_ATTRIBUTE (ATTRIBUTE_NODE, PREFIX_ID, PREFIX_TYPE : TREE; ATTRIBUTE_SUBTYPE, ATTRIBUTE_VALUE : out TREE; PARAMETER : in out TREE; PARAM_TYPESET : in out TYPESET_TYPE; IS_FUNCTION : Boolean);

        -- $$$$ FOR DEBUG
  procedure PRINT_TREE (T : TREE) is
  begin
    if T.TY = DN_REAL_VAL then
      PRINT_NOD.PRINT_TREE (D (XD_NUMER, T));
      Put ('/');
      PRINT_NOD.PRINT_TREE (D (XD_DENOM, T));
    else
      PRINT_NOD.PRINT_TREE (T);
    end if;
  end PRINT_TREE;

        -- $$$$ EXTENSIONS TO UARITH
  function U_REAL (NUMER : Integer; DENOM : Integer := 1) return TREE is
    REAL : TREE := MAKE (DN_REAL_VAL);
  begin
    D (XD_NUMER, REAL, U_VAL (NUMER));
    D (XD_DENOM, REAL, U_VAL (1));
    REAL := REAL / U_VAL (DENOM);
    return REAL;
  end U_REAL;

        -- $$$$ EXTENSIONS TO UARITH
  function "<" (L, R : TREE) return Boolean is
  begin
    return not (L >= R);
  end "<";

  function ">" (L, R : TREE) return Boolean is
  begin
    return not (L <= R);
  end ">";

        -- $$$$ SHOULD NOT BE HERE
  function GET_SUBSTRUCT (TYPE_SPEC : TREE) return TREE is
  begin
    if TYPE_SPEC.TY in CLASS_PRIVATE_SPEC and then GET_BASE_STRUCT (TYPE_SPEC).TY in CLASS_FULL_TYPE_SPEC then
      return D (SM_TYPE_SPEC, TYPE_SPEC);
    elsif TYPE_SPEC.TY = DN_INCOMPLETE and then GET_BASE_STRUCT (TYPE_SPEC).TY in CLASS_FULL_TYPE_SPEC then
      return D (XD_FULL_TYPE_SPEC, TYPE_SPEC);
    else
      return TYPE_SPEC;
    end if;
  end GET_SUBSTRUCT;

        -- $$$$ SHOULD NOT BE HERE
  function GET_APPROPRIATE_BASE (TYPE_SPEC : TREE) return TREE is
    BASE_TYPE : TREE := GET_BASE_TYPE (TYPE_SPEC);
  begin
    if BASE_TYPE.TY = DN_ACCESS then
      return GET_BASE_TYPE (D (SM_DESIG_TYPE, BASE_TYPE));
    else
      return BASE_TYPE;
    end if;
  end GET_APPROPRIATE_BASE;

  function BITS_IN_INTEGER_PART (REAL : TREE) return Natural is
    TEMP	 : TREE	 := REAL;
    RESULT : Integer := 0;
  begin
    while TEMP > U_REAL (2**14) loop
      TEMP   := TEMP / U_VAL (2**14);
      RESULT := RESULT + 14;
    end loop;
    while TEMP > U_REAL (1) loop
      TEMP   := TEMP / U_VAL (2);
      RESULT := RESULT + 1;
    end loop;
    return RESULT;
  end BITS_IN_INTEGER_PART;

  function DIGITS_IN_INTEGER_PART (REAL : TREE) return Natural is
    TEMP	 : TREE	 := REAL;
    RESULT : Integer := 0;
  begin
    while TEMP > U_REAL (10**4) loop
      TEMP   := TEMP / U_VAL (10**4);
      RESULT := RESULT + 4;
    end loop;
    while TEMP > U_REAL (1) loop
      TEMP   := TEMP / U_VAL (10);
      RESULT := RESULT + 1;
    end loop;
    return RESULT;
  end DIGITS_IN_INTEGER_PART;

  function GET_FLOAT_MANTISSA (CONSTRAINT : TREE) return TREE is
    RESULT : TREE;
  begin
    RESULT := U_VAL (BITS_IN_INTEGER_PART (U_REAL (10)**D (SM_ACCURACY, CONSTRAINT)) + 1);
    return RESULT;
  end GET_FLOAT_MANTISSA;

  function IS_SHORT_FLOAT_BASE (TYPE_SPEC : TREE) return Boolean is
				-- BASE FLOAT (IEEE SIMPLE) OU LONG_FLOAT (IEEE DOUBLE), CHOISIE PAR DEF_WALK
  begin
    return D (SM_ACCURACY, GET_BASE_STRUCT (TYPE_SPEC)) <= PREDEFINED_FLOAT_ACCURACY;
  end IS_SHORT_FLOAT_BASE;

  function GET_FLOAT_SAFE_EMAX (TYPE_SPEC : TREE) return TREE is
				-- LRM 3.5.8 : CELUI DE LA BASE ; SAFE_SMALL = 2**(-SAFE_EMAX-1) RESTE UN NORMAL IEEE
  begin
    if IS_SHORT_FLOAT_BASE (TYPE_SPEC) then
      return U_VAL (125);
    else
      return U_VAL (1_021);
    end if;
  end GET_FLOAT_SAFE_EMAX;

  function GET_FIXED_SMALL (CONSTRAINT : TREE) return TREE is
    SMALL : TREE := D (CD_IMPL_SMALL, CONSTRAINT);
  begin
    if SMALL = TREE_VOID then
      SMALL := D (SM_ACCURACY, CONSTRAINT);
    end if;
    return SMALL;
  end GET_FIXED_SMALL;

  function GET_FIXED_BOUND (CONSTRAINT : TREE) return TREE is
    SMALL	    : constant TREE := GET_FIXED_SMALL (CONSTRAINT);
    BOUND	    : TREE	:= GET_STATIC_VALUE (D (AS_EXP2, D (SM_RANGE, CONSTRAINT)));
    LOW_BOUND : TREE	:= GET_STATIC_VALUE (D (AS_EXP1, D (SM_RANGE, CONSTRAINT)));
    REAL_ZERO : constant TREE := U_REAL (0);
  begin
    if BOUND < U_REAL (0) then
      BOUND := -BOUND;
    end if;
    if LOW_BOUND < U_REAL (0) then
      LOW_BOUND := -LOW_BOUND;
    end if;
    if LOW_BOUND > BOUND then
      BOUND := LOW_BOUND;
    end if;
    if BOUND > SMALL then
      BOUND := BOUND - SMALL;
    end if;
    return BOUND;
  end GET_FIXED_BOUND;

  function GET_FIXED_MANTISSA (CONSTRAINT : TREE) return TREE is
    RESULT : TREE;
  begin
    RESULT := U_VAL (BITS_IN_INTEGER_PART (GET_FIXED_BOUND (CONSTRAINT) / GET_FIXED_SMALL (CONSTRAINT)));
    return RESULT;
  end GET_FIXED_MANTISSA;

  function GET_WIDTH (TYPE_SPEC : TREE) return Integer is
    RANGE_NODE : TREE    := D (SM_RANGE, TYPE_SPEC);
    L_BOUND    : TREE    := D (AS_EXP1, RANGE_NODE);
    U_BOUND    : TREE    := D (AS_EXP2, RANGE_NODE);
    L_VALUE    : TREE;
    U_VALUE    : TREE;
    COUNT	     : Integer := 0;
    ESIZE	     : Integer;
    ENUM_LIST  : SEQ_TYPE;
    ENUM	     : TREE;
    function SLENGTH (A : String) return Integer is
		    -- A IS TEXT OF ENUMERATION LITERAL; RETURNS WIDTH
    begin
      if A (A'FIRST) = '_' then
        return A'LENGTH - 1;
      else
        return A'LENGTH;
      end if;
    end SLENGTH;
  begin
    L_VALUE := GET_STATIC_VALUE (L_BOUND);
    U_VALUE := GET_STATIC_VALUE (U_BOUND);
    if TYPE_SPEC.TY = DN_ENUMERATION then
      ENUM_LIST := LIST (D (SM_LITERAL_S, TYPE_SPEC));
      while not IS_EMPTY (ENUM_LIST) loop
        exit when D (SM_POS, HEAD (ENUM_LIST)) = L_VALUE;
        ENUM_LIST := TAIL (ENUM_LIST);
      end loop;
      while not IS_EMPTY (ENUM_LIST) loop
        POP (ENUM_LIST, ENUM);
        ESIZE := SLENGTH (PRINT_NAME (D (LX_SYMREP, ENUM)));
        if ESIZE > COUNT then
	COUNT := ESIZE;
        end if;
        exit when D (SM_POS, ENUM) = U_VALUE;
      end loop;
      return COUNT;
    else -- INTEGER
      if L_VALUE < U_VAL (0) then
        L_VALUE := -L_VALUE;
      end if;
      if U_VALUE < U_VAL (0) then
        U_VALUE := -U_VALUE;
      end if;
      if L_VALUE > U_VALUE then
        U_VALUE := L_VALUE;
      end if;
      while U_VALUE >= U_VAL (10) loop
        COUNT   := COUNT + 1;
        U_VALUE := U_VALUE / U_VAL (10);
      end loop;
      return COUNT + 2;
    end if;
  end GET_WIDTH;
   --|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
   --|  PROCEDURE EVAL_ATTRIBUTE
  procedure EVAL_ATTRIBUTE (EXP : TREE; TYPESET : out TYPESET_TYPE; IS_SUBTYPE : out Boolean; IS_FUNCTION : Boolean := False) is
    ATTRIBUTE_NODE : TREE := EXP;
    PARAMETER      : TREE := TREE_VOID;
    PARAM_TYPESET  : TYPESET_TYPE;
    ATTRIBUTE_ID   : TREE;

    PREFIX      : TREE;
    PREFIX_ID   : TREE;
    PREFIX_TYPE : TREE;

    NEW_TYPESET	  : TYPESET_TYPE := EMPTY_TYPESET;
    ATTRIBUTE_SUBTYPE : TREE	       := TREE_VOID;
    ATTRIBUTE_VALUE	  : TREE	       := TREE_VOID;
  begin
    IS_SUBTYPE := False;			 --| HYPOTHÈSE : CE N'EST PAS UN 'RANGE

	      -- SPLIT OFF PARAMETER, IF ONE IS GIVEN
    if EXP.TY = DN_FUNCTION_CALL then
      declare
        PARAM_LIST : SEQ_TYPE := LIST (D (AS_GENERAL_ASSOC_S, EXP));
      begin
        ATTRIBUTE_NODE := D (AS_NAME, EXP);		   --| UN NAME QUI EST UN ATTRIBUTE
        POP (PARAM_LIST, PARAMETER);
        if not IS_EMPTY (PARAM_LIST) then
	ERROR (D (LX_SRCPOS, HEAD (PARAM_LIST)), "ONLY SINGLE PARAMETER ALLOWED FOR ATTRIBUTE");
        end if;
        if PARAMETER.TY = DN_ASSOC then
	ERROR (D (LX_SRCPOS, PARAMETER), "NAMED NOTATION NOT ALLOWED FOR ATTRIBUTE");
	PARAMETER := D (AS_EXP, PARAMETER);
        end if;
        EVAL_EXP_TYPES (PARAMETER, PARAM_TYPESET);
      end;
    end if;

	      -- LOOKUP ATTRIBUTE ID
    ATTRIBUTE_ID := EVAL_ATTRIBUTE_IDENTIFIER (ATTRIBUTE_NODE);
    if ATTRIBUTE_ID = TREE_VOID then
      ERROR (D (LX_SRCPOS, D (AS_USED_NAME_ID, ATTRIBUTE_NODE)), "ATTRIBUTE NOT KNOWN TO IMPLEMENTATION - " & PRINT_NAME (D (LX_SYMREP, D (AS_USED_NAME_ID, ATTRIBUTE_NODE))));
    elsif DEFINED_ATTRIBUTES'VAL (DI (XD_POS, ATTRIBUTE_ID)) = RANGE_X then
      IS_SUBTYPE := True;
    end if;

	      -- WALK PREFIX
    PREFIX := D (AS_NAME, ATTRIBUTE_NODE);
    WALK_ATTRIBUTE_PREFIX (PREFIX, PREFIX_ID, PREFIX_TYPE, ATTRIBUTE_ID);
    D (AS_NAME, ATTRIBUTE_NODE, PREFIX);

    if False then
      CHECK_PREFIX_AND_ATTRIBUTE (ATTRIBUTE_NODE, PREFIX_ID, PREFIX_TYPE, ATTRIBUTE_SUBTYPE, ATTRIBUTE_VALUE, PARAMETER, PARAM_TYPESET, IS_FUNCTION => True);
    else
      CHECK_PREFIX_AND_ATTRIBUTE (ATTRIBUTE_NODE, PREFIX_ID, PREFIX_TYPE, ATTRIBUTE_SUBTYPE, ATTRIBUTE_VALUE, PARAMETER, PARAM_TYPESET, IS_FUNCTION);
    end if;

    D (SM_EXP_TYPE, ATTRIBUTE_NODE, ATTRIBUTE_SUBTYPE);
    D (SM_VALUE, ATTRIBUTE_NODE, ATTRIBUTE_VALUE);
    if ATTRIBUTE_SUBTYPE /= TREE_VOID then
      ADD_TO_TYPESET (NEW_TYPESET, GET_BASE_TYPE (ATTRIBUTE_SUBTYPE));
    end if;
    TYPESET := NEW_TYPESET;

    if PARAMETER /= TREE_VOID then
      LIST (D (AS_GENERAL_ASSOC_S, EXP), SINGLETON (PARAMETER));
    end if;
  end EVAL_ATTRIBUTE;

  function RESOLVE_ATTRIBUTE (EXP : TREE) return TREE is
    ATTRIBUTE_NODE : TREE := EXP;
    ATTRIBUTE_ID   : TREE;
  begin

	      -- SPLIT OFF PARAMETER, IF ONE IS GIVEN
    if EXP.TY = DN_FUNCTION_CALL then
      ATTRIBUTE_NODE := D (AS_NAME, EXP);
      D (AS_EXP, ATTRIBUTE_NODE, HEAD (LIST (D (AS_GENERAL_ASSOC_S, EXP))));
    end if;

	      -- GET THE ATTRIBUTE ID
    ATTRIBUTE_ID := D (SM_DEFN, D (AS_USED_NAME_ID, ATTRIBUTE_NODE));

	      -- IF THE ATTRIBUTE NAME WAS UNDEFINED
    if ATTRIBUTE_ID = TREE_VOID then

		    -- JUST RETURN THE ATTRIBUTE NODE
      return ATTRIBUTE_NODE;

		    -- ELSE
    else

      case DEFINED_ATTRIBUTES'VAL (DI (XD_POS, ATTRIBUTE_ID)) is

			  -- FOR A RANGE ATTRIBUTE
        when RANGE_X =>

				-- CONSTRUCT AND RETURN RANGE_ATTRIBUTE NODE
	return
	 MAKE_RANGE_ATTRIBUTE
	  (LX_SRCPOS => D (LX_SRCPOS, ATTRIBUTE_NODE), AS_NAME => D (AS_NAME, ATTRIBUTE_NODE), AS_USED_NAME_ID => D (AS_USED_NAME_ID, ATTRIBUTE_NODE), AS_EXP => D (AS_EXP, ATTRIBUTE_NODE), SM_TYPE_SPEC => D (SM_EXP_TYPE, ATTRIBUTE_NODE));

			  -- FOR AN ATTRIBUTE WHICH IS A FUNCTION
        when PRED | SUCC | POS | VAL | VALUE | IMAGE =>

				-- IF A PARAMETER WAS GIVEN
	if EXP.TY = DN_FUNCTION_CALL then

				        -- RETURN A FUNCTION CALL
	  D (SM_NORMALIZED_PARAM_S, EXP, MAKE_EXP_S (LIST => SINGLETON (D (AS_EXP, ATTRIBUTE_NODE))));
	  D (AS_EXP, ATTRIBUTE_NODE, TREE_VOID);
	  D (SM_EXP_TYPE, EXP, D (SM_EXP_TYPE, ATTRIBUTE_NODE));
	  D (SM_EXP_TYPE, ATTRIBUTE_NODE, TREE_VOID);
	  D (SM_VALUE, EXP, D (SM_VALUE, ATTRIBUTE_NODE));
	  D (SM_VALUE, ATTRIBUTE_NODE, TREE_VOID);
	  return EXP;

				        -- ELSE
	else

				        -- RETURN THE ATTRIBUTE NODE
	  return ATTRIBUTE_NODE;
	end if;

			  -- FOR ALL OTHER ATTRIBUTES
        when others =>

				-- RETURN THE ATTRIBUTE NODE
	return ATTRIBUTE_NODE;
      end case;
    end if;

  end RESOLVE_ATTRIBUTE;
   --|----------------------------------------------------------------------------------------------
   --|  FUNCTION EVAL_ATTRIBUTE_IDENTIFIER
  function EVAL_ATTRIBUTE_IDENTIFIER (ATTRIBUTE_NODE : TREE) return TREE is
    USED_OBJECT_ID	  : constant TREE := D (AS_USED_NAME_ID, ATTRIBUTE_NODE);
    USED_NAME_ID_COPY : constant TREE := MAKE_USED_NAME_ID_FROM_OBJECT (USED_OBJECT_ID);
    SYMREP	  : constant TREE := D (LX_SYMREP, USED_NAME_ID_COPY);
    DEFLIST	  : SEQ_TYPE      := LIST (SYMREP);
    DEF		  : TREE;
    ID		  : TREE;
  begin

    D (AS_USED_NAME_ID, ATTRIBUTE_NODE, USED_NAME_ID_COPY);
    while not IS_EMPTY (DEFLIST) loop
      POP (DEFLIST, DEF);
      ID := D (XD_SOURCE_NAME, DEF);
      if ID.TY = DN_ATTRIBUTE_ID then
        D (SM_DEFN, USED_NAME_ID_COPY, ID);
        return ID;
      end if;
    end loop;

    D (SM_DEFN, USED_NAME_ID_COPY, TREE_VOID);
    ERROR (D (LX_SRCPOS, USED_NAME_ID_COPY), "ATTRIBUTE NOT KNOWN - '" & PRINT_NAME (D (LX_SYMREP, USED_NAME_ID_COPY)));
    return TREE_VOID;
  end EVAL_ATTRIBUTE_IDENTIFIER;

  procedure WALK_ATTRIBUTE_PREFIX (PREFIX : in out TREE; PREFIX_ID : out TREE; PREFIX_TYPE : out TREE; ATTRIBUTE_ID : TREE) is
	      -- NOTE. PREFIX_ID NULL FOR OBJECT OR EXPRESSION
	      -- ... AND THE ID FOR ANY OTHER NAMED ENTITY (E.G. TYPE_ID)
	      -- PREFIX_TYPE SET FOR OBJECT OR EXPRESSION OR [SUB]TYPE NAME
    DEFSET	: DEFSET_TYPE  := EMPTY_DEFSET;
    ID		: TREE	     := TREE_VOID;
    TYPESET	: TYPESET_TYPE := EMPTY_TYPESET;
    PREFIX_TYPE_OUT : TREE	     := TREE_VOID;
  begin

	      -- ASSUME DEFAULT VALUES FOR OUT PARAMETERS
    PREFIX_ID   := TREE_VOID;
    PREFIX_TYPE := TREE_VOID;

	      -- IF PREFIX IS A STRING LITERAL
    if PREFIX.TY = DN_STRING_LITERAL then

		    -- MAKE IT A USED_OP
      PREFIX := MAKE_USED_OP_FROM_STRING (PREFIX);
    end if;

	      -- IF PREFIX IS A [SELECTED] NAME
    if PREFIX.TY = DN_SELECTED or else PREFIX.TY in CLASS_USED_OBJECT then

		    -- EVALUATE THE NAME
      FIND_VISIBILITY (PREFIX, DEFSET);
      ID := GET_THE_ID (DEFSET);

      case ID.TY is
        when DN_VOID =>
	PREFIX := RESOLVE_EXP (PREFIX, TREE_VOID);
        when CLASS_OBJECT_NAME =>
	REQUIRE_UNIQUE_DEF (PREFIX, DEFSET);
	STASH_DEFSET (PREFIX, DEFSET);
	ID	      := GET_THE_ID (DEFSET);
	PREFIX_TYPE_OUT := GET_BASE_TYPE (ID);
	PREFIX_TYPE     := PREFIX_TYPE_OUT;
	PREFIX	      := RESOLVE_EXP (PREFIX, PREFIX_TYPE_OUT);
        when CLASS_TYPE_NAME =>
	REQUIRE_UNIQUE_DEF (PREFIX, DEFSET);
	ID	      := GET_THE_ID (DEFSET);
	PREFIX_TYPE_OUT := GET_BASE_TYPE (ID);
	if PREFIX_TYPE_OUT.TY = DN_TASK_SPEC and then DI (XD_LEX_LEVEL, GET_DEF_FOR_ID (D (XD_SOURCE_NAME, PREFIX_TYPE_OUT))) > 0 then
	  PREFIX_TYPE := PREFIX_TYPE_OUT;
	  STASH_DEFSET (PREFIX, DEFSET);
	  PREFIX := RESOLVE_EXP (PREFIX, PREFIX_TYPE_OUT);
	else
	  PREFIX_ID   := ID;
	  PREFIX	    := RESOLVE_NAME (PREFIX, GET_THE_ID (DEFSET));
	  PREFIX_TYPE := D (SM_TYPE_SPEC, ID);
	end if;
	return;
        when DN_OPERATOR_ID | DN_LABEL_ID | DN_PACKAGE_ID | DN_TASK_BODY_ID =>
	REQUIRE_UNIQUE_DEF (PREFIX, DEFSET);
	PREFIX_ID := GET_THE_ID (DEFSET);
	PREFIX	:= RESOLVE_NAME (PREFIX, GET_THE_ID (DEFSET));
	return;
        when DN_PROCEDURE_ID | DN_FUNCTION_ID | DN_ENTRY_ID | DN_GENERIC_ID =>
				-- (PREFIX MAY BE OVERLOADABLE OR MAY BE EXPRESSION)
	if ATTRIBUTE_ID = TREE_VOID then
	  return;
	end if;

	case DEFINED_ATTRIBUTES'VAL (DI (XD_POS, ATTRIBUTE_ID)) is
	  when CALLABLE | FIRST | LAST | LENGTH | RANGE_X | TERMINATED =>
					      -- EXPRESSION ALLOWED
	    declare
	      GENERAL_ASSOC_S : TREE := MAKE_GENERAL_ASSOC_S (LIST => (TREE_NIL, TREE_NIL), LX_SRCPOS => D (LX_SRCPOS, PREFIX));
	    begin
	      REQUIRE_FUNCTION_OR_ARRAY_DEF (PREFIX, DEFSET);
	      REDUCE_APPLY_NAMES (PREFIX, DEFSET, GENERAL_ASSOC_S);
	      REQUIRE_UNIQUE_DEF (PREFIX, DEFSET);
	      STASH_DEFSET (PREFIX, DEFSET);
	      PREFIX	  := MAKE_FUNCTION_CALL (AS_NAME => PREFIX, AS_GENERAL_ASSOC_S => GENERAL_ASSOC_S, LX_SRCPOS => D (LX_SRCPOS, PREFIX));
	      PREFIX_TYPE_OUT := GET_BASE_TYPE (ID);
	      PREFIX_TYPE	  := PREFIX_TYPE_OUT;
	      PREFIX	  := RESOLVE_EXP (PREFIX, PREFIX_TYPE_OUT);
	    end;
	  when others =>
	    REQUIRE_UNIQUE_DEF (PREFIX, DEFSET);
	    PREFIX_ID := GET_THE_ID (DEFSET);
	    PREFIX    := RESOLVE_NAME (PREFIX, GET_THE_ID (DEFSET));
	    return;
	end case;
        when DN_BLOCK_LOOP_ID =>
	ERROR (D (LX_SRCPOS, PREFIX), "CANNOT BE ATTRIBUTE PREFIX");
	return;
        when others =>
	Put_Line ("!! INVALID ID NODE FOR ATTRIBUTE PREFIX");
	raise Program_Error;
      end case;

    else

      if PREFIX.TY = DN_FUNCTION_CALL then
        declare
	NAME	         : TREE	:= D (AS_NAME, PREFIX);
	HOLD_PREFIX        : TREE;
				-- SAVE PREFIX TO RESTORE IT
	HOLD_DESIGNATOR    : TREE;
				-- SAVE DESIG TO RESTORE IT
	SAVE_NAME	         : TREE	:= NAME;
	GENERAL_ASSOC_S    : TREE	:= D (AS_GENERAL_ASSOC_S, PREFIX);
	GENERAL_ASSOC_LIST : SEQ_TYPE := LIST (GENERAL_ASSOC_S);
	INDEX	         : TREE;
        begin
	if (NAME.TY = DN_SELECTED or else NAME.TY = DN_USED_OBJECT_ID) and then not IS_EMPTY (GENERAL_ASSOC_LIST) and then IS_EMPTY (TAIL (GENERAL_ASSOC_LIST)) and then HEAD (GENERAL_ASSOC_LIST).TY /= DN_ASSOC then
	  if NAME.TY = DN_SELECTED then
	    HOLD_DESIGNATOR := D (AS_DESIGNATOR, NAME);
	    HOLD_PREFIX	:= D (AS_NAME, NAME);
	  end if;
	  FIND_VISIBILITY (NAME, DEFSET);
	  ID := GET_THE_ID (DEFSET);
	  if ID.TY = DN_VOID then
					      -- FINISH HERE BECAUSE ERROR ALREADY REPORTED
	    NAME := RESOLVE_EXP (NAME, TREE_VOID);
	    D (AS_NAME, PREFIX, NAME);
	    INDEX := HEAD (GENERAL_ASSOC_LIST);
	    EVAL_EXP_TYPES (INDEX, TYPESET);
	    INDEX := RESOLVE_EXP (INDEX, TREE_VOID);
	    LIST (GENERAL_ASSOC_S, SINGLETON (INDEX));
	    return;
	  elsif ID.TY = DN_ENTRY_ID and then D (SM_SPEC, ID).TY = DN_ENTRY and then D (AS_DISCRETE_RANGE, D (SM_SPEC, ID)) /= TREE_VOID then
	    NAME := RESOLVE_NAME (NAME, ID);
	    D (AS_NAME, PREFIX, NAME);
	    PREFIX_ID := ID;
	    INDEX	    := HEAD (GENERAL_ASSOC_LIST);
	    EVAL_EXP_TYPES (INDEX, TYPESET);
	    REQUIRE_TYPE (GET_TYPE_OF_DISCRETE_RANGE (D (AS_DISCRETE_RANGE, D (SM_SPEC, ID))), INDEX, TYPESET);
	    INDEX := RESOLVE_EXP (INDEX, GET_THE_TYPE (TYPESET));
	    LIST (GENERAL_ASSOC_S, SINGLETON (INDEX));
	    return;
	  elsif NAME.TY = DN_SELECTED then
					      -- PUT IT BACK TO USED OBJECT ID
					      -- SINCE VISIBILITY WILL BE CHECKED AGAIN
	    D (AS_DESIGNATOR, NAME, HOLD_DESIGNATOR);
	    D (AS_NAME, NAME, HOLD_PREFIX);
	  end if;
	end if;
        end;

			  -- ELSE IF PREFIX IS AN ATTRIBUTE
      elsif PREFIX.TY = DN_ATTRIBUTE and then EVAL_ATTRIBUTE_IDENTIFIER (PREFIX) /= TREE_VOID then

        case DEFINED_ATTRIBUTES'VAL (DI (XD_POS, EVAL_ATTRIBUTE_IDENTIFIER (PREFIX))) is
	when BASE =>
				        -- EVALUATE THE 'BASE PREFIX
	  declare
	    BASE_PREFIX	 : TREE := D (AS_NAME, PREFIX);
	    BASE_PREFIX_ID	 : TREE;
	    BASE_PREFIX_TYPE : TREE;
	  begin
	    WALK_ATTRIBUTE_PREFIX (BASE_PREFIX, BASE_PREFIX_ID, BASE_PREFIX_TYPE, EVAL_ATTRIBUTE_IDENTIFIER (PREFIX));
	    if BASE_PREFIX_ID.TY in CLASS_TYPE_NAME then
	      PREFIX_ID	  := BASE_PREFIX_ID;
	      PREFIX_TYPE_OUT := GET_BASE_TYPE (BASE_PREFIX_TYPE);
	      PREFIX_TYPE	  := PREFIX_TYPE_OUT;
	      PREFIX	  := RESOLVE_ATTRIBUTE (PREFIX);
	      D (AS_NAME, PREFIX, BASE_PREFIX);
	      D (SM_EXP_TYPE, PREFIX, TREE_VOID);
	    else
	      ERROR (D (LX_SRCPOS, BASE_PREFIX), "PREFIX OF 'BASE MUST BE A [SUB]TYPE");
	    end if;
	  end;

				        -- AND RETURN
	  return;

	when PRED | SUCC | VAL | IMAGE | POS | VALUE =>
				        -- NOTE. THESE CAN BE PREFIX OF 'ADDRESS
				        -- (ACVC TEST AD7201E.ADA)
				        -- SEEMS STRANGE FOR 'VAL AND 'POS (NOT REDEFINABLE)
	  declare
	    BASE_PREFIX	 : TREE := D (AS_NAME, PREFIX);
	    BASE_PREFIX_ID	 : TREE;
	    BASE_PREFIX_TYPE : TREE;
	  begin
	    WALK_ATTRIBUTE_PREFIX (BASE_PREFIX, BASE_PREFIX_ID, BASE_PREFIX_TYPE, EVAL_ATTRIBUTE_IDENTIFIER (PREFIX));
	    if BASE_PREFIX_ID.TY in CLASS_TYPE_NAME then
	      PREFIX_ID	  := TREE_VOID;
	      PREFIX_TYPE_OUT := TREE_VOID;
	      PREFIX_TYPE	  := PREFIX_TYPE_OUT;
	      PREFIX	  := RESOLVE_ATTRIBUTE (PREFIX);
	      D (AS_NAME, PREFIX, BASE_PREFIX);
	      D (SM_EXP_TYPE, PREFIX, TREE_VOID);
	    else
	      ERROR (D (LX_SRCPOS, BASE_PREFIX), "PREFIX OF ATTRIBUTE MUST BE A [SUB]TYPE");
	    end if;

	    return;
	  end;

	when others =>
	  null;
        end case;
      end if;

		    -- WHEN WE GET HERE, PREFIX MUST BE AN EXPRESSION
		    -- $$$$ NO, IT COULD ALSO BE MEMBER OF ENTRY FAMILY
      EVAL_EXP_TYPES (PREFIX, TYPESET);

		    -- $$$$ LIMIT TO NAME OR PREFIX

      REQUIRE_UNIQUE_TYPE (PREFIX, TYPESET);
      PREFIX_TYPE_OUT := GET_THE_TYPE (TYPESET);
      PREFIX_TYPE	  := PREFIX_TYPE_OUT;
      PREFIX	  := RESOLVE_EXP (PREFIX, PREFIX_TYPE_OUT);
    end if;

  end WALK_ATTRIBUTE_PREFIX;

  procedure CHECK_PREFIX_AND_ATTRIBUTE (ATTRIBUTE_NODE, PREFIX_ID, PREFIX_TYPE : TREE; ATTRIBUTE_SUBTYPE, ATTRIBUTE_VALUE : out TREE; PARAMETER : in out TREE; PARAM_TYPESET : in out TYPESET_TYPE; IS_FUNCTION : Boolean) is
    USED_NAME_ID	 : TREE	       := D (AS_USED_NAME_ID, ATTRIBUTE_NODE);
    ATTRIBUTE_ID	 : TREE	       := D (SM_DEFN, USED_NAME_ID);
    PREFIX_ERROR	 : Boolean       := False;
    WHICH_ATTRIBUTE  : DEFINED_ATTRIBUTES;
    WHICH_SUBSCRIPT  : Integer       := 1;
    PREFIX_BASE	 : constant TREE := GET_BASE_TYPE (PREFIX_TYPE);
    PREFIX_SUBSTRUCT : TREE;
  begin

	      -- RETURN IF ATTRIBUTE_ID IS VOID
    if ATTRIBUTE_ID = TREE_VOID then
      if PARAMETER /= TREE_VOID then
        PARAMETER := RESOLVE_EXP (PARAMETER, TREE_VOID);
      end if;
      return;
    end if;

	      -- SET DEFAULT RESULTS
    ATTRIBUTE_SUBTYPE := MAKE (DN_ANY_INTEGER);
    ATTRIBUTE_VALUE	  := TREE_VOID;

	      -- CHECK POSSIBLE PREFIXES
    WHICH_ATTRIBUTE := DEFINED_ATTRIBUTES'VAL (DI (XD_POS, ATTRIBUTE_ID));
    case WHICH_ATTRIBUTE is
      when ADDRESS =>
        ATTRIBUTE_SUBTYPE := PREDEFINED_ADDRESS;
        if PREDEFINED_ADDRESS = TREE_VOID then
	ERROR (D (LX_SRCPOS, ATTRIBUTE_NODE), "PREDEFINED SYSTEM NOT WITHED");
        end if;
        if PREFIX_ID.TY not in CLASS_UNIT_NAME'FIRST .. DN_ENTRY_ID and then (PREFIX_ID.TY /= DN_TYPE_ID or else D (SM_TYPE_SPEC, PREFIX_ID).TY /= DN_TASK_SPEC or else DI (XD_LEX_LEVEL, D (XD_REGION_DEF, GET_DEF_FOR_ID (PREFIX_ID))) = 0)
         and then PREFIX_ID /= TREE_VOID
        then
	PREFIX_ERROR := True;
        end if;
      when AFT | FORE =>
        if PREFIX_ID.TY in CLASS_TYPE_NAME and then GET_BASE_STRUCT (PREFIX_TYPE).TY = DN_FIXED then
	PREFIX_SUBSTRUCT := GET_SUBSTRUCT (D (SM_TYPE_SPEC, PREFIX_ID));
	if IS_STATIC_SUBTYPE (PREFIX_SUBSTRUCT) then
	  if WHICH_ATTRIBUTE = AFT then
	    if GET_FIXED_SMALL (PREFIX_SUBSTRUCT) >= U_REAL (1, 10) then
	      ATTRIBUTE_VALUE := U_VAL (2);
	    else
	      ATTRIBUTE_VALUE := U_VAL (1 + DIGITS_IN_INTEGER_PART (U_REAL (1) / GET_FIXED_SMALL (PREFIX_SUBSTRUCT)));
	    end if;
	  else -- FORE
	    ATTRIBUTE_VALUE := U_VAL (1 + DIGITS_IN_INTEGER_PART (GET_FIXED_BOUND (PREFIX_SUBSTRUCT)));
	  end if;
	end if;
        else
	PREFIX_ERROR := True;
        end if;
      when BASE =>
        ERROR (D (LX_SRCPOS, D (AS_USED_NAME_ID, ATTRIBUTE_NODE)), "ATTRIBUTE 'BASE NOT ALLOWED");
      when CALLABLE | TERMINATED =>
        ATTRIBUTE_SUBTYPE := PREDEFINED_BOOLEAN;
        if PREFIX_ID = TREE_VOID and then GET_APPROPRIATE_BASE (PREFIX_TYPE).TY = DN_TASK_SPEC then
	null;
        else
	PREFIX_ERROR := True;
        end if;
      when CONSTRAINED =>
        ATTRIBUTE_SUBTYPE := PREDEFINED_BOOLEAN;
        if (PREFIX_ID = TREE_VOID and then (GET_APPROPRIATE_BASE (PREFIX_TYPE).TY = DN_RECORD or else GET_APPROPRIATE_BASE (PREFIX_TYPE).TY in CLASS_PRIVATE_SPEC) and then not IS_EMPTY (LIST (D (SM_DISCRIMINANT_S, GET_APPROPRIATE_BASE (PREFIX_TYPE)))))
         or else (PREFIX_ID.TY in CLASS_TYPE_NAME
				        --AND THEN IS_NONLIMITED_TYPE(D ( SM_TYPE_SPEC,PREFIX_ID))
	and then IS_PRIVATE_TYPE (D (SM_TYPE_SPEC, PREFIX_ID)))
        then
	null;
        else
	PREFIX_ERROR := True;
        end if;
      when PRENAME.COUNT =>
        if PREFIX_ID.TY /= DN_ENTRY_ID then
	PREFIX_ERROR := True;
        end if;
      when DELTA_X =>
        ATTRIBUTE_SUBTYPE := MAKE (DN_ANY_REAL);
        if PREFIX_ID.TY in CLASS_TYPE_NAME and then GET_BASE_STRUCT (PREFIX_TYPE).TY = DN_FIXED then
	PREFIX_SUBSTRUCT := GET_SUBSTRUCT (D (SM_TYPE_SPEC, PREFIX_ID));
	if IS_STATIC_SUBTYPE (PREFIX_SUBSTRUCT) then
	  ATTRIBUTE_VALUE := D (SM_ACCURACY, PREFIX_SUBSTRUCT);
	end if;
        else
	PREFIX_ERROR := True;
        end if;
      when DIGITS_X | EMAX | MACHINE_EMAX | MACHINE_EMIN | MACHINE_MANTISSA | MACHINE_RADIX | SAFE_EMAX =>
        if PREFIX_ID.TY in CLASS_TYPE_NAME and then GET_BASE_STRUCT (PREFIX_TYPE).TY = DN_FLOAT then
	PREFIX_SUBSTRUCT := GET_SUBSTRUCT (D (SM_TYPE_SPEC, PREFIX_ID));
	if IS_STATIC_SUBTYPE (PREFIX_SUBSTRUCT) then
	  case WHICH_ATTRIBUTE is
	    when DIGITS_X =>
	      ATTRIBUTE_VALUE := D (SM_ACCURACY, PREFIX_SUBSTRUCT);
	    when EMAX =>				-- LRM 3.5.7 : 4 * B
	      ATTRIBUTE_VALUE := U_VAL (4) * GET_FLOAT_MANTISSA (PREFIX_SUBSTRUCT);
	    when SAFE_EMAX =>
	      ATTRIBUTE_VALUE := GET_FLOAT_SAFE_EMAX (PREFIX_TYPE);
	    when MACHINE_EMAX =>			-- IEEE, MANTISSE DANS [0.5, 1) : VALEURS DE L'EXPANSEUR
	      if IS_SHORT_FLOAT_BASE (PREFIX_TYPE) then
	        ATTRIBUTE_VALUE := U_VAL (128);
	      else
	        ATTRIBUTE_VALUE := U_VAL (1_024);
	      end if;
	    when MACHINE_EMIN =>
	      if IS_SHORT_FLOAT_BASE (PREFIX_TYPE) then
	        ATTRIBUTE_VALUE := U_VAL (-125);
	      else
	        ATTRIBUTE_VALUE := U_VAL (-1_021);
	      end if;
	    when MACHINE_MANTISSA =>			-- BIT CACHE COMPRIS
	      if IS_SHORT_FLOAT_BASE (PREFIX_TYPE) then
	        ATTRIBUTE_VALUE := U_VAL (24);
	      else
	        ATTRIBUTE_VALUE := U_VAL (53);
	      end if;
	    when MACHINE_RADIX =>
	      ATTRIBUTE_VALUE := U_VAL (2);
	    when others =>
	      Put_Line ("IMPOSSIBLE CASE");
	      raise Program_Error;
	  end case;
	end if;
	null;
        else
	PREFIX_ERROR := True;
        end if;
      when MANTISSA =>
        if PREFIX_ID.TY in CLASS_TYPE_NAME and then GET_BASE_STRUCT (PREFIX_TYPE).TY in CLASS_REAL then
	PREFIX_SUBSTRUCT := GET_SUBSTRUCT (D (SM_TYPE_SPEC, PREFIX_ID));
	if IS_STATIC_SUBTYPE (PREFIX_SUBSTRUCT) then
	  if PREFIX_SUBSTRUCT.TY = DN_FLOAT then
	    ATTRIBUTE_VALUE := GET_FLOAT_MANTISSA (PREFIX_SUBSTRUCT);
	  else
	    ATTRIBUTE_VALUE := GET_FIXED_MANTISSA (PREFIX_SUBSTRUCT);
	  end if;
	end if;
        else
	PREFIX_ERROR := True;
        end if;
      when EPSILON =>
        ATTRIBUTE_SUBTYPE := MAKE (DN_ANY_REAL);
        if PREFIX_ID.TY in CLASS_TYPE_NAME and then GET_BASE_STRUCT (PREFIX_TYPE).TY = DN_FLOAT then
	PREFIX_SUBSTRUCT := GET_SUBSTRUCT (D (SM_TYPE_SPEC, PREFIX_ID));
	if IS_STATIC_SUBTYPE (PREFIX_SUBSTRUCT) then
	  ATTRIBUTE_VALUE := U_REAL (2) / (U_VAL (2)**GET_FLOAT_MANTISSA (PREFIX_SUBSTRUCT));	-- LRM 3.5.7 : 2**(1-B)
	end if;
        else
	PREFIX_ERROR := True;
        end if;
      when LARGE | SAFE_LARGE | SAFE_SMALL | SMALL =>
        ATTRIBUTE_SUBTYPE := MAKE (DN_ANY_REAL);
        if PREFIX_ID.TY in CLASS_TYPE_NAME and then GET_BASE_STRUCT (PREFIX_TYPE).TY in CLASS_REAL then
	PREFIX_SUBSTRUCT := GET_SUBSTRUCT (D (SM_TYPE_SPEC, PREFIX_ID));
	if not IS_STATIC_SUBTYPE (PREFIX_SUBSTRUCT) then
	  null;
	elsif PREFIX_SUBSTRUCT.TY = DN_FLOAT then
	  case WHICH_ATTRIBUTE is
	    when LARGE =>
	      ATTRIBUTE_VALUE := (U_REAL (1) - U_REAL (1) / U_VAL (2)**GET_FLOAT_MANTISSA (PREFIX_SUBSTRUCT)) * U_VAL (16)**GET_FLOAT_MANTISSA (PREFIX_SUBSTRUCT);
	    when SAFE_LARGE =>			-- LRM 3.5.8 : 2**SAFE_EMAX * (1 - 2**(-B DE LA BASE))
	      ATTRIBUTE_VALUE := (U_REAL (1) - U_REAL (1) / U_VAL (2)**GET_FLOAT_MANTISSA (GET_BASE_STRUCT (PREFIX_TYPE)))
				 * U_VAL (2)**GET_FLOAT_SAFE_EMAX (PREFIX_TYPE);
	    when SAFE_SMALL =>			-- LRM 3.5.8 : 2**(-SAFE_EMAX-1)
	      ATTRIBUTE_VALUE := (U_REAL (1, 2)) / U_VAL (2)**GET_FLOAT_SAFE_EMAX (PREFIX_TYPE);
	    when SMALL =>
	      ATTRIBUTE_VALUE := (U_REAL (1, 2)) / U_VAL (16)**GET_FLOAT_MANTISSA (PREFIX_SUBSTRUCT);
	    when others =>
	      Put_Line ("!! IMPOSSIBLE CASE");
	      raise Program_Error;
	  end case;
	else -- FIXED
	  case WHICH_ATTRIBUTE is
	    when LARGE =>
	      ATTRIBUTE_VALUE := (U_VAL (2)**GET_FIXED_MANTISSA (PREFIX_SUBSTRUCT) - U_VAL (1)) * GET_FIXED_SMALL (PREFIX_SUBSTRUCT);
	    when SAFE_LARGE =>
	      ATTRIBUTE_VALUE := GET_STATIC_VALUE (D (AS_EXP2, D (SM_RANGE, GET_BASE_TYPE (PREFIX_TYPE))));
	    when SAFE_SMALL =>
	      ATTRIBUTE_VALUE := GET_FIXED_SMALL (GET_BASE_TYPE (PREFIX_TYPE));
	    when SMALL =>
	      ATTRIBUTE_VALUE := GET_FIXED_SMALL (PREFIX_SUBSTRUCT);
	    when others =>
	      Put_Line ("!! IMPOSSIBLE CASE");
	      raise Program_Error;
	  end case;
	end if;
        else
	PREFIX_ERROR := True;
        end if;
      when FIRST | LAST | LENGTH =>
			  -- (STATIC VALUE CHECKED LATER WHEN ARGUMENT FOUND)
        null;
      when FIRST_BIT | LAST_BIT | POSITION =>
        if D (AS_NAME, ATTRIBUTE_NODE).TY = DN_SELECTED and then D (SM_DEFN, D (AS_DESIGNATOR, D (AS_NAME, ATTRIBUTE_NODE))).TY in CLASS_COMP_NAME then
	null;
        else
	PREFIX_ERROR := True;
        end if;
      when IMAGE =>
        if not IS_DISCRETE_TYPE (GET_BASE_TYPE (PREFIX_TYPE)) then
	PREFIX_ERROR := True;
        end if;
        ATTRIBUTE_SUBTYPE := PREDEFINED_STRING;
      when MACHINE_OVERFLOWS | MACHINE_ROUNDS =>
        ATTRIBUTE_SUBTYPE := PREDEFINED_BOOLEAN;
        ATTRIBUTE_VALUE   := U_VAL (1);
        if PREFIX_ID.TY in CLASS_TYPE_NAME and then GET_BASE_STRUCT (PREFIX_TYPE).TY in CLASS_REAL then
	null;
        else
	PREFIX_ERROR := True;
        end if;
      when POS =>
        if PREFIX_ID.TY in CLASS_TYPE_NAME and then GET_BASE_STRUCT (PREFIX_TYPE).TY in DN_ENUMERATION .. DN_INTEGER then
	null;
        else
	PREFIX_ERROR := True;
        end if;
      when PRED | SUCC =>
        if PREFIX_ID.TY in CLASS_TYPE_NAME and then GET_BASE_STRUCT (PREFIX_TYPE).TY in DN_ENUMERATION .. DN_INTEGER then
	ATTRIBUTE_SUBTYPE := D (SM_TYPE_SPEC, PREFIX_ID);
        else
	PREFIX_ERROR := True;
        end if;
      when RANGE_X =>

        if (PREFIX_ID.TY in CLASS_TYPE_NAME and then GET_SUBSTRUCT (D (SM_TYPE_SPEC, PREFIX_ID)).TY in CLASS_CONSTRAINED and then GET_APPROPRIATE_BASE (PREFIX_ID).TY = DN_ARRAY)
         or else (PREFIX_ID = TREE_VOID and then GET_APPROPRIATE_BASE (PREFIX_TYPE).TY = DN_ARRAY)
        then
	null;
        else
	PREFIX_ERROR := True;
        end if;
      when SIZE =>
        if PREFIX_ID.TY in CLASS_TYPE_NAME then
	PREFIX_SUBSTRUCT := GET_SUBSTRUCT (D (SM_TYPE_SPEC, PREFIX_ID));
	if IS_STATIC_SUBTYPE (PREFIX_SUBSTRUCT) then
	  ATTRIBUTE_VALUE := D (CD_IMPL_SIZE, PREFIX_SUBSTRUCT);
	end if;
        elsif PREFIX_ID = TREE_VOID then
				-- $$$$ CHECK THAT IT IS AN OBJECT
	null;
        else
	PREFIX_ERROR := True;
        end if;
      when STORAGE_SIZE =>
        if GET_BASE_STRUCT (PREFIX_TYPE).TY = DN_TASK_SPEC or else (GET_BASE_STRUCT (PREFIX_TYPE).TY = DN_ACCESS and then PREFIX_ID.TY in CLASS_TYPE_NAME) then
	null;
        else
	PREFIX_ERROR := True;
        end if;
      when VAL | VALUE =>
        if IS_DISCRETE_TYPE (GET_BASE_TYPE (PREFIX_ID)) then
	ATTRIBUTE_SUBTYPE := D (SM_TYPE_SPEC, PREFIX_ID);
        else
	PREFIX_ERROR := True;
        end if;
      when WIDTH =>
        if IS_DISCRETE_TYPE (GET_BASE_TYPE (PREFIX_ID)) then
	PREFIX_SUBSTRUCT := GET_SUBSTRUCT (D (SM_TYPE_SPEC, PREFIX_ID));
	if IS_STATIC_SUBTYPE (PREFIX_SUBSTRUCT) then
	  ATTRIBUTE_VALUE := U_VAL (GET_WIDTH (PREFIX_SUBSTRUCT));
	end if;
        else
	PREFIX_ERROR := True;
        end if;
    end case;

	      -- PUT OUT PREFIX ERROR, IF ANY
    if PREFIX_ERROR then
      ERROR (D (LX_SRCPOS, ATTRIBUTE_NODE), "INVALID PREFIX FOR ATTRIBUTE");
    end if;

	      -- IF THERE WAS A PARAMETER
    if PARAMETER /= TREE_VOID then

      if PREFIX_ID.TY in CLASS_TYPE_NAME then
        PREFIX_SUBSTRUCT := GET_SUBSTRUCT (D (SM_TYPE_SPEC, PREFIX_ID));
      else
        PREFIX_SUBSTRUCT := TREE_VOID;
      end if;

      case WHICH_ATTRIBUTE is
        when IMAGE =>
	REQUIRE_TYPE (PREFIX_BASE, PARAMETER, PARAM_TYPESET);
	PARAMETER := RESOLVE_EXP (PARAMETER, PARAM_TYPESET);
        when POS =>
	REQUIRE_TYPE (PREFIX_BASE, PARAMETER, PARAM_TYPESET);
	PARAMETER := RESOLVE_EXP (PARAMETER, PARAM_TYPESET);
	if IS_STATIC_SUBTYPE (PREFIX_SUBSTRUCT) then
	  ATTRIBUTE_VALUE := GET_STATIC_VALUE (PARAMETER);
	end if;
        when PRED =>
	REQUIRE_TYPE (PREFIX_BASE, PARAMETER, PARAM_TYPESET);
	PARAMETER := RESOLVE_EXP (PARAMETER, PARAM_TYPESET);
				-- $$$$ ONLY FOR STATIC SUBTYPE; CHECK CONSTRAINT
	if IS_STATIC_SUBTYPE (PREFIX_SUBSTRUCT) then
	  ATTRIBUTE_VALUE := GET_STATIC_VALUE (PARAMETER) - U_VAL (1);
	end if;
        when SUCC =>
	REQUIRE_TYPE (PREFIX_BASE, PARAMETER, PARAM_TYPESET);
	PARAMETER := RESOLVE_EXP (PARAMETER, PARAM_TYPESET);
	if IS_STATIC_SUBTYPE (PREFIX_SUBSTRUCT) then
	  ATTRIBUTE_VALUE := GET_STATIC_VALUE (PARAMETER) + U_VAL (1);
	end if;
        when VAL =>
	REQUIRE_INTEGER_TYPE (PARAMETER, PARAM_TYPESET);
	PARAMETER := RESOLVE_EXP (PARAMETER, PARAM_TYPESET);
	if IS_STATIC_SUBTYPE (PREFIX_SUBSTRUCT) then
	  ATTRIBUTE_VALUE := GET_STATIC_VALUE (PARAMETER);
	end if;
        when VALUE =>
	REQUIRE_TYPE (PREDEFINED_STRING, PARAMETER, PARAM_TYPESET);
	PARAMETER := RESOLVE_EXP (PARAMETER, PARAM_TYPESET);
        when FIRST | LAST | RANGE_X | LENGTH =>
	if GET_BASE_STRUCT (PREFIX_BASE).TY in CLASS_SCALAR then
	  ERROR (D (LX_SRCPOS, PARAMETER), "PARAMETER NOT ALLOWED");
	  PARAMETER := RESOLVE_EXP (PARAMETER, TREE_VOID);
	else
	  REQUIRE_TYPE (MAKE (DN_UNIVERSAL_INTEGER), PARAMETER, PARAM_TYPESET);
	  PARAMETER := RESOLVE_EXP (PARAMETER, PARAM_TYPESET);
	  if GET_STATIC_VALUE (PARAMETER) = TREE_VOID then
	    ERROR (D (LX_SRCPOS, PARAMETER), "PARAMETER MUST BE STATIC");
	  else
	    WHICH_SUBSCRIPT := U_POS (GET_STATIC_VALUE (PARAMETER));
	  end if;
	end if;
        when others =>
	ERROR (D (LX_SRCPOS, PARAMETER), "PARAMETER NOT ALLOWED FOR ATTRIBUTE");
	PARAMETER := RESOLVE_EXP (PARAMETER, TREE_VOID);
      end case;

		    -- ELSE -- SINCE THERE WAS NO PARAMETER
    else

      case WHICH_ATTRIBUTE is
        when IMAGE | PRED | SUCC | VALUE =>
	if not IS_FUNCTION then
	  ERROR (D (LX_SRCPOS, D (AS_USED_NAME_ID, ATTRIBUTE_NODE)), "PARAMETER REQUIRED FOR ATTRIBUTE");
	end if;
        when POS | VAL =>
	if IS_FUNCTION then
	  ERROR (D (LX_SRCPOS, D (AS_USED_NAME_ID, ATTRIBUTE_NODE)), "ATTRIBUTE IS NOT A FUNCTION");
	else
	  ERROR (D (LX_SRCPOS, D (AS_USED_NAME_ID, ATTRIBUTE_NODE)), "PARAMETER REQUIRED FOR ATTRIBUTE");
	end if;
        when others =>
	if IS_FUNCTION then
	  ERROR (D (LX_SRCPOS, D (AS_USED_NAME_ID, ATTRIBUTE_NODE)), "ATTRIBUTE IS NOT A FUNCTION");
	end if;
      end case;
    end if;

    case WHICH_ATTRIBUTE is
      when FIRST | LAST | RANGE_X | LENGTH =>
        declare
	INDEX	       : TREE := TREE_VOID;
	INDEX_LIST       : SEQ_TYPE;
	PREFIX_SUBSTRUCT : TREE := PREFIX_TYPE;
        begin
	if PREFIX_SUBSTRUCT.TY in DN_PRIVATE .. DN_L_PRIVATE then
	  PREFIX_SUBSTRUCT := D (SM_TYPE_SPEC, PREFIX_SUBSTRUCT);
	elsif PREFIX_SUBSTRUCT.TY = DN_INCOMPLETE then
	  PREFIX_SUBSTRUCT := D (XD_FULL_TYPE_SPEC, PREFIX_SUBSTRUCT);
	end if;
	if PREFIX_SUBSTRUCT.TY = DN_ACCESS or else PREFIX_SUBSTRUCT.TY = DN_CONSTRAINED_ACCESS then
	  PREFIX_SUBSTRUCT := D (SM_DESIG_TYPE, PREFIX_SUBSTRUCT);
	end if;
	if PREFIX_SUBSTRUCT.TY in DN_PRIVATE .. DN_L_PRIVATE then
	  PREFIX_SUBSTRUCT := D (SM_TYPE_SPEC, PREFIX_SUBSTRUCT);
	elsif PREFIX_SUBSTRUCT.TY = DN_INCOMPLETE then
	  PREFIX_SUBSTRUCT := D (XD_FULL_TYPE_SPEC, PREFIX_SUBSTRUCT);
	end if;

	if PREFIX_SUBSTRUCT.TY in CLASS_SCALAR then
				        -- $$$$ MAKE SURE WE GET SUBTYPE
	  INDEX		:= PREFIX_SUBSTRUCT;
	  ATTRIBUTE_SUBTYPE := GET_BASE_TYPE (INDEX);
				        -- $$$$ VALUE ONLY FOR STATIC SUBTYPE
	  if WHICH_ATTRIBUTE = FIRST then
	    if D (SM_RANGE, INDEX).TY = DN_RANGE then
	      ATTRIBUTE_VALUE := GET_STATIC_VALUE (D (AS_EXP1, D (SM_RANGE, INDEX)));
	    end if;
	  elsif WHICH_ATTRIBUTE = LAST then
	    if D (SM_RANGE, INDEX).TY = DN_RANGE then
	      ATTRIBUTE_VALUE := GET_STATIC_VALUE (D (AS_EXP2, D (SM_RANGE, INDEX)));
	    end if;
	  else
	    ERROR (D (LX_SRCPOS, ATTRIBUTE_NODE), "ARRAY TYPE REQUIRED");
	  end if;
	else
	  PREFIX_SUBSTRUCT := GET_BASE_STRUCT (PREFIX_SUBSTRUCT);
	  if PREFIX_SUBSTRUCT.TY = DN_ARRAY then
	    INDEX_LIST := LIST (D (SM_INDEX_S, PREFIX_SUBSTRUCT));
	    loop
	      if IS_EMPTY (INDEX_LIST) then
	        ERROR (D (LX_SRCPOS, PARAMETER), "PARAMETER NOT WITHIN ARRAY DIMENSION");
	        ATTRIBUTE_SUBTYPE := TREE_VOID;
	        exit;
	      else
	        POP (INDEX_LIST, INDEX);
	        WHICH_SUBSCRIPT := WHICH_SUBSCRIPT - 1;
	        if WHICH_SUBSCRIPT = 0 then
		if WHICH_ATTRIBUTE /= LENGTH then
		  ATTRIBUTE_SUBTYPE := GET_BASE_TYPE (D (SM_TYPE_SPEC, INDEX));
		end if;
		exit;
	        end if;
	      end if;
	    end loop;
	  elsif PREFIX_SUBSTRUCT /= TREE_VOID then
	    ERROR (D (LX_SRCPOS, ATTRIBUTE_NODE), "ARRAY TYPE REQUIRED");
	  end if;
	end if;
        end;

      when others =>
        null;
    end case;

  end CHECK_PREFIX_AND_ATTRIBUTE;

        --PROCEDURE WALK_ATTRIBUTE_FUNCTION(EXP: TREE) IS
        --  PREFIX:	        TREE := D ( AS_NAME, EXP);
        --  ATTRIBUTE_ID:   TREE := EVAL_ATTRIBUTE_IDENTIFIER(EXP);
        --  ATTRIBUTE_KIND: DEFINED_ATTRIBUTES;
        --
        --  PREFIX_ID:      TREE;
        --  PREFIX_TYPE:    TREE;
        --BEGIN
        --
        --  -- CHECK ATTRIBUTE IDENTIFIER
        --  IF ATTRIBUTE_ID /= CONST_VOID THEN
        --        ATTRIBUTE_KIND := DEFINED_ATTRIBUTES'VAL(DI(XD_POS,ATTRIBUTE_ID));
        --      CASE ATTRIBUTE_KIND IS
        --      WHEN PRED | SUCC | IMAGE | VALUE =>
        --	NULL;
        --      WHEN OTHERS =>
        --	ERROR(D ( LX_SRCPOS,D ( AS_USED_NAME_ID,EXP))
        --		, "ATTRIBUTE NOT VALID AS FUNCTION" );
        --	ATTRIBUTE_ID := CONST_VOID;
        --      END CASE;
        --  END IF;
        --
        --  -- RESOLVE THE PREFIX
        --  WALK_ATTRIBUTE_PREFIX
        --	( PREFIX
        --	, PREFIX_ID
        --	, PREFIX_TYPE
        --	, ATTRIBUTE_ID );
        --
        --  -- STORE THE RESOLVED PREFIX
        --  D ( AS_NAME, EXP, PREFIX);
        --END WALK_ATTRIBUTE_FUNCTION;

end ATT_WALK;
