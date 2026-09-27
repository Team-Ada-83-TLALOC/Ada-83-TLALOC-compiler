------------------------------------------------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2026 VINCENT MORIN, UBO
-- SPDX-License-Identifier: GPL-3.0-or-later
------------------------------------------------------------------------------------------------------------------------
--	1	2	3	4	5	6	7	8	9	0	1	2

		--			|
		--		       \\ | //
		--		     \\ u ^ u //		/-------_______------\
		--		   \ )Y|Y|Y|Y|Y( /		|  T  h e		 |
		--		     / /o o o\ \		|  L  o n e s o m e  |
		--		    \|H|H|H|H|H|/		|  A  d a		 |
		--		   G))  Q	  Q  ((G		|  L  o v i n g	 |
		--		    / \	"   / \ 	   	|  O  l't i m e r's  |
		--		   /_/  \V¨V/  \_\		|  C  o m p i l e r  |
		--		       \vvvvv/		\-------______-------/
		--		     \ooooooooo/
		--
		--	Command language (see CLI) :
		--
		-- TLALOC HELP [verb]
		-- TLALOC COMPILE [/PROJECT=dir] [/STOP_PHASE[=WRITELIB|SYNTAX|LIB|SEMANTICS|EXPAND]] source
		-- TLALOC BIND    [/PROJECT=dir] unit			-- writes the fasmg main .fas
		-- TLALOC DUMP    [/PROJECT=dir] [/FORMAT[=U|P|A]]	-- DIANA tree of $$$.TMP
		-- TLALOC CODE    [/PROJECT=dir] [/TARGET_CPU=X86_64|ARM64|RISCV64] [/MAP] unit
		--
		-- /PROJECT : directory holding ADA__LIB, relative to the executable or
		-- absolute, default "./". SOURCE is relative to the project or absolute.
		-- COMPILE without /STOP_PHASE is the full compilation (old option W) ;
		-- /STOP_PHASE alone stops after the library write without coding (old w).

with TEXT_IO, CALENDAR;
use  TEXT_IO, CALENDAR;
with IDL, EXPANDER, TARGET_CODE, CLI;

					--==--
		procedure			TLALOC
					--==--

is

  use CLI.COMMAND_ACCESS;

  type STOP_PHASE_KIND	is ( SYNTAX, LIB, SEMANTICS, EXPAND, WRITELIB );

  CMD			: STRING( 1..512 );
  CMD_LENGTH		: NATURAL;


			---------------
  procedure		DEFINE_LANGUAGE
  is			---------------
    use CLI;
    use COMMAND_DEFINE;
  begin
    COMMAND_DEFINE.START( TOOL_NAME=> "TLALOC" );
    ADD_FREE_VALUE_QUALIFIER( "PROJECT", DEFAULT=> "./" );

    ADD_VERB( "HELP" );
    ADD_PARAMETER( "VERB", REQUIRED=> FALSE );

    ADD_VERB( "COMPILE" );
    ADD_QUALIFIER( "STOP_PHASE", "SYNTAX,LIB,SEMANTICS,EXPAND,WRITELIB",
		IMPLICIT_FIRST_VALUE=> FALSE,
		NEGATABLE=> FALSE, DEFAULT=>"WRITELIB" );
    ADD_PARAMETER( "SOURCE" );

    ADD_VERB( "BIND" );
    ADD_PARAMETER( "UNIT" );
    ADD_QUALIFIER( "TARGET_CPU", "X86_64,ARM64,RISCV64", DEFAULT=> "X86_64" );
    ADD_QUALIFIER( "TARGET_OS", "LINUX,WINDOWS,UEFI", DEFAULT=> "LINUX" );

    ADD_VERB( "DUMP" );
    ADD_QUALIFIER( "FORMAT", "PRETTY,UGLY,ALLTREE", IMPLICIT_FIRST_VALUE=> TRUE );

    ADD_VERB( "CODE" );
    ADD_QUALIFIER( "TARGET_CPU", "X86_64,ARM64,RISCV64", DEFAULT=> "X86_64" );
    ADD_QUALIFIER( "TARGET_OS", "LINUX,WINDOWS", DEFAULT=> "LINUX" );
    ADD_QUALIFIER( "MAP" );
    ADD_PARAMETER( "UNIT" );

    COMMAND_DEFINE.STOP;

  end	DEFINE_LANGUAGE;
	---------------


			-----------
  procedure		SET_PROJECT
  is			-----------
    -- /PROJECT (or its default) into IDL.PROJECT_PATH, with a trailing '/',
    -- then IDL.LIB_PATH.
    P	: constant STRING := GET_VALUE( "PROJECT" );
  begin
    IDL.PROJECT_PATH_LENGTH := P'LENGTH;
    IDL.PROJECT_PATH( 1 .. P'LENGTH ) := P;
    if P( P'LAST ) /= '/' then
      IDL.PROJECT_PATH_LENGTH := IDL.PROJECT_PATH_LENGTH + 1;
      IDL.PROJECT_PATH( IDL.PROJECT_PATH_LENGTH ) := '/';
    end if;

    IDL.LIB_PATH_LENGTH	:= IDL.PROJECT_PATH_LENGTH + IDL.DEFAULT_LIB_PATH'LENGTH;
    IDL.LIB_PATH( 1..IDL.LIB_PATH_LENGTH )
			:= IDL.PROJECT_PATH( 1 .. IDL.PROJECT_PATH_LENGTH )
			   & IDL.DEFAULT_LIB_PATH;

  end	SET_PROJECT;
	-----------


			-------
  function		PROJECT				return STRING
  is			-------
  begin
    return IDL.PROJECT_PATH( 1 .. IDL.PROJECT_PATH_LENGTH );

  end	PROJECT;
	-------


			----------
  procedure		DO_COMPILE
  is			----------

    SOURCE	:constant STRING := GET_VALUE( "SOURCE" );
    PHASE		: STOP_PHASE_KIND := WRITELIB;
    SEPARATOR	: NATURAL := SOURCE'FIRST - 1;		-- last '/' of SOURCE, or before it

    START_TIME, END_TIME	: CALENDAR.TIME;

  begin
    if  STATUS_OF( "STOP_PHASE" ) = PRESENT  then

--      PHASE := STOP_PHASE_KIND'VALUE( GET_VALUE( "STOP_PHASE" ) );		-- A VOIR EXPANDER NE PREND PAS CECI
  if  GET_VALUE( "STOP_PHASE" ) = "SYNTAX"  then PHASE := SYNTAX;
  elsif GET_VALUE( "STOP_PHASE" ) = "LIB"  then PHASE := LIB;
  elsif GET_VALUE( "STOP_PHASE" ) = "SEMANTICS"  then PHASE := SEMANTICS;
  elsif GET_VALUE( "STOP_PHASE" ) = "EXPAND"  then PHASE := EXPAND;
  elsif GET_VALUE( "STOP_PHASE" ) = "WRITELIB"  then PHASE := WRITELIB;
  end if;


    end if;

    for  I in SOURCE'RANGE  loop
      if  SOURCE( I ) = '/'  then
	SEPARATOR := I;
      end if;
    end loop;

			-----------------------
			SEPARE_PATH_NOM_EXECUTE:
    declare
      NOM_TEXTE		: constant STRING := SOURCE( SEPARATOR + 1 .. SOURCE'LAST );
      CHEMIN_RELATIF	: constant STRING := SOURCE( SOURCE'FIRST .. SEPARATOR );

      function CHEMIN_TEXTE return STRING is
      begin
	if SOURCE( SOURCE'FIRST ) = '/' then								--| absolute source path
	  return CHEMIN_RELATIF;
	else
	  return PROJECT & CHEMIN_RELATIF;
	end if;
      end CHEMIN_TEXTE;

    begin
      START_TIME := CLOCK;

      IDL.PAR_PHASE( CHEMIN_TEXTE, NOM_TEXTE, IDL.LIB_PATH );
      if  PHASE /= SYNTAX  then
	IDL.LIB_PHASE;
	if  PHASE /= LIB  then
	  IDL.SEM_PHASE;
	  if  PHASE = WRITELIB  or  PHASE = EXPAND  then							--| EXPAND : code but do not write, $$$.TMP kept for DUMP
	    EXPANDER;
	  end if;
	end if;
      end if;

      IDL.ERR_PHASE( CHEMIN_TEXTE & NOM_TEXTE );

      if  PHASE = WRITELIB  then									--| kills $$$.TMP
	IDL.WRITE_LIB;
      end if;

      END_TIME := CLOCK;
      PUT_LINE( " ..... Ok" & INTEGER'IMAGE( INTEGER( 1000 * (END_TIME - START_TIME) ) ) & " msec" );

    exception
      when NAME_ERROR =>
	PUT_LINE( "TLALOC: cannot open " & CHEMIN_TEXTE & NOM_TEXTE );

    end	SEPARE_PATH_NOM_EXECUTE;
	-----------------------

  end	DO_COMPILE;
	----------


			-------
  procedure		DO_BIND
  is			-------
  begin
    EXPANDER( GET_VALUE( "UNIT" ), GET_VALUE( "TARGET_CPU" ), GET_VALUE( "TARGET_OS" ) );				--| writes the fasmg main .fas

  end	DO_BIND;
	-------


			-------
  procedure		DO_DUMP
  is			-------
    -- $$$.TMP DIANA tree print. Do not use after a full COMPILE, which
    -- kills $$$.TMP ; use /STOP_PHASE=EXPAND before.
  begin
    IDL.PRETTY_DIANA( GET_VALUE( "FORMAT" )( GET_VALUE( "FORMAT" )'FIRST ) );

  end	DO_DUMP;
	-------


			-------
  procedure		DO_CODE
  is			-------
  begin
    TARGET_CODE( CPU_NAME=> GET_VALUE( "TARGET_CPU" ), OS_NAME=> GET_VALUE( "TARGET_OS" ),
		 UNIT_NAME=> GET_VALUE( "UNIT" ),
		 MAP=> IS_PRESENT( "MAP" ) );

  end	DO_CODE;
	-------


			-------
  procedure		DO_HELP
  is			-------
  begin
    if  IS_PRESENT( "VERB" )  then
      CLI.COMMAND_DEFINE.SHOW_SYNTAX( GET_VALUE( "VERB" ) );
    else
      CLI.COMMAND_DEFINE.SHOW_SYNTAX;
    end if;
  exception
    when  NO_SUCH_NAME =>
      PUT_LINE( "TLALOC: no such verb " & GET_VALUE( "VERB" ) );
      CLI.COMMAND_DEFINE.SHOW_SYNTAX;

  end	DO_HELP;
	-------


begin
  DEFINE_LANGUAGE;

  GET_LINE( CMD, CMD_LENGTH );
  CLI.PARSE_COMMAND_FROM_VERB( CMD( 1 .. CMD_LENGTH ) );
  SET_PROJECT;

  declare
    VERB	: constant STRING := GET_VERB;
  begin
    if    VERB = "HELP"    then DO_HELP;
    elsif VERB = "COMPILE" then DO_COMPILE;
    elsif VERB = "BIND"    then DO_BIND;
    elsif VERB = "DUMP"    then DO_DUMP;
    elsif VERB = "CODE"    then DO_CODE;
    end if;
  end;

exception
  when CLI.COMMAND_ERROR =>
    PUT_LINE( "TLALOC: " & CLI.ERROR_MESSAGE );
    CLI.COMMAND_DEFINE.SHOW_SYNTAX;
  when CLI.COMMAND_DEFINE.DEFINITION_ERROR =>
    PUT_LINE( "TLALOC: internal error in command definition : " & CLI.ERROR_MESSAGE );

end	TLALOC;
	--==--
