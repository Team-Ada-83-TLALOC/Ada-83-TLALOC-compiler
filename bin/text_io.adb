with MACHINE_CODE;
use  MACHINE_CODE;
					-------
	package body			TEXT_IO
is					-------

  STDOUT_PAGE_LENGTH	: COUNT		:= 0;
  STDOUT_LINE_LENGTH	: COUNT		:= 0;						-- LRM 14.3.3 : non borne par defaut
  STDOUT_PAGE		: POSITIVE_COUNT	:= 1;
  STDOUT_LINE		: POSITIVE_COUNT	:= 1;
  STDOUT_COL		: POSITIVE_COUNT	:= 1;

  DEFAULT_INPUT		: FILE_TYPE;
  DEFAULT_OUTPUT		: FILE_TYPE;
  STD_INPUT		: FILE_TYPE;
  STD_OUTPUT		: FILE_TYPE;


			-- Tampons d'entree-sortie par descripteur Linux (hors LRM).
			-- Indexes par FILE.ID et non loges dans FILE_TYPE, dont les
			-- valeurs sont copiees (DEFAULT_OUTPUT := FILE). Un ID hors
			-- table prend l'ancien chemin : un syscall par PUT_RAW/GET_RAW.

  BUF_SIZE		:constant		:= 16_384;
  MAX_BUF_ID		:constant		:= 15;
  subtype BUF_LEN		is INTEGER range 0 .. BUF_SIZE;

  type IO_BUFFER		is record
			  DATA		: STRING( 1 .. BUF_SIZE );
			  OUT_LEN		: BUF_LEN;						-- DATA( 1 .. OUT_LEN ) en attente d'ecriture
			  IN_POS		: BUF_LEN;						-- octets deja consommes en lecture
			  IN_LEN		: BUF_LEN;						-- DATA( IN_POS+1 .. IN_LEN ) restent a lire
			end record;

  BUFS			: array( 0 .. MAX_BUF_ID ) of IO_BUFFER;


			---------
  procedure		WRITE_RAW		( ID :INTEGER; ITEM :STRING )				-- write( ID, ITEM ) direct, sans tampon
  is			---------

    ERR_CODE	: INTEGER;

		-----------------
    function	WRITE_SYSTEM_CALL		( FILE_ID :INTEGER; LENGTH :POSITIVE )		return INTEGER
    is		-----------------
    begin
      ASM_OP_2'( OPCODE => Ld, LVL => 2, OFS => -16 );							-- LENGTH en -16
      ASM_OP_2'( OPCODE => LIa, LVL => 1, OFS => -16 );							-- @CHARS sur parametre ITEM de WRITE_RAW
      ASM_OP_2'( OPCODE => Ld, LVL => 2, OFS => -8 );							-- ID
      ASM_OP_0'( OPCODE => SYS_FILE_WRITE );
      ASM_OP_2'( OPCODE => SD, LVL => 2, OFS => -24 );							-- Retour du resultat syscall

    end	WRITE_SYSTEM_CALL;
	-----------------
  begin
    if  ITEM'LENGTH = 0  then return; end if;
    ERR_CODE := WRITE_SYSTEM_CALL( ID, ITEM'LENGTH );

  end	WRITE_RAW;
	---------


			--------
  function		READ_RAW		( ID :INTEGER; ITEM :STRING )	return INTEGER		-- read( ID, ITEM ) direct, rend le nombre d'octets lus
  is			--------

		----------------
    function	READ_SYSTEM_CALL		( FILE_ID :INTEGER; LENGTH :POSITIVE )		return INTEGER
    is		----------------
    begin
      ASM_OP_2'( OPCODE => Ld, LVL => 2, OFS => -16 );							-- LENGTH en -16
      ASM_OP_2'( OPCODE => LIa, LVL => 1, OFS => -16 );							-- @CHARS sur parametre ITEM de READ_RAW
      ASM_OP_2'( OPCODE => Ld, LVL => 2, OFS => -8 );							-- ID
      ASM_OP_0'( OPCODE => SYS_FILE_READ );
      ASM_OP_2'( OPCODE => SD, LVL => 2, OFS => -24 );							-- Retour du nombre d'octets lus

    end	READ_SYSTEM_CALL;
	----------------
  begin
    return READ_SYSTEM_CALL( ID, ITEM'LENGTH );

  end	READ_RAW;
	--------


			---------
  procedure		FLUSH_OUT		( ID :INTEGER )						-- vide le tampon de sortie de l'ID
  is			---------
  begin
    if  ID < 0  or else  ID > MAX_BUF_ID  then return; end if;
    if  BUFS( ID ).OUT_LEN > 0  then
      WRITE_RAW( ID, BUFS( ID ).DATA( 1 .. BUFS( ID ).OUT_LEN ) );
      BUFS( ID ).OUT_LEN := 0;
    end if;

  end	FLUSH_OUT;
	---------


			------------
  procedure		RESET_BUFFER	( ID :INTEGER )						-- oublie tout (ouverture, fermeture, reset, delete)
  is			------------
  begin
    if  ID < 0  or else  ID > MAX_BUF_ID  then return; end if;
    BUFS( ID ).OUT_LEN := 0;
    BUFS( ID ).IN_POS  := 0;
    BUFS( ID ).IN_LEN  := 0;

  end	RESET_BUFFER;
	------------


			--   F I L E   M A N A G E M E N T


			------
  procedure		CREATE		( FILE :in out FILE_TYPE;
					  MODE :in FILE_MODE := OUT_FILE;
					  NAME :in STRING := "";
					  FORM :in STRING := ""
					)
  is			------

    ERR_OR_ID	: INTEGER;

		------------------
    function	CREATE_SYSTEM_CALL  ( NAME :in STRING ) return INTEGER
    is		-----------------
    begin
      ASM_OP_2'( OPCODE => LA, LVL => 2, OFS => -8 );
      ASM_OP_0'( OPCODE => SYS_FILE_CREATE );
      ASM_OP_2'( OPCODE => SD, LVL => 2, OFS => -16 );

    end	CREATE_SYSTEM_CALL;
	------------------

  begin
    if  FILE.IS_OPENED  then raise STATUS_ERROR; end if;					-- LRM 14.2.1(4)
    ERR_OR_ID := CREATE_SYSTEM_CALL( NAME );
    if  ERR_OR_ID >= 0  then
      RESET_BUFFER( ERR_OR_ID );
      FILE.ID := ERR_OR_ID;
      FILE.NAME( 1 .. NAME'LENGTH ) := NAME;
      FILE.NAME_LEN := NAME'LENGTH;
      FILE.IS_OPENED := TRUE;
      FILE.MODE := MODE;
      FILE.PAGE_LENGTH := STDOUT_PAGE_LENGTH;
      FILE.LINE_LENGTH := STDOUT_LINE_LENGTH;
      FILE.PAGE := 1;
      FILE.LINE := 1;
      FILE.COL  := 1;
      FILE.IS_DEFAULT_IO	:= FALSE;
      FILE.LOOK_AHEAD	:= ASCII.NUL;
      FILE.HAS_LOOK_AHEAD	:= FALSE;
      FILE.AT_END_OF_FILE	:= FALSE;
    else
      raise USE_ERROR;									-- LRM 14.2.1(6) creation impossible
    end if;

  end	CREATE;
	------


			----
  procedure		OPEN		( FILE :in out FILE_TYPE;
					  MODE :in FILE_MODE;
					  NAME :in STRING;
					  FORM :in STRING := ""
					)
  is			----

    ERR_OR_ID	: INTEGER;

		----------------
    function	OPEN_SYSTEM_CALL	( NAME :in STRING ) return INTEGER
    is		----------------
    begin
      ASM_OP_2'( OPCODE => LA, LVL => 2, OFS => -8 );
      ASM_OP_0'( OPCODE => SYS_FILE_OPEN );
      ASM_OP_2'( OPCODE => SD, LVL => 2, OFS => -16 );							-- Retour du File ID

    end	OPEN_SYSTEM_CALL;
	----------------

  begin
    if  FILE.IS_OPENED  then raise STATUS_ERROR; end if;					-- LRM 14.2.1(4)
    ERR_OR_ID := OPEN_SYSTEM_CALL( NAME );
    if  ERR_OR_ID >= 0  then
      RESET_BUFFER( ERR_OR_ID );
      FILE.ID := ERR_OR_ID;
      FILE.NAME( 1 .. NAME'LENGTH ) := NAME;
      FILE.NAME_LEN := NAME'LENGTH;
      FILE.IS_OPENED := TRUE;
      FILE.MODE := MODE;
      FILE.PAGE_LENGTH := STDOUT_PAGE_LENGTH;
      FILE.LINE_LENGTH := STDOUT_LINE_LENGTH;
      FILE.PAGE := 1;
      FILE.LINE := 1;
      FILE.COL  := 1;
      FILE.IS_DEFAULT_IO	:= FALSE;
      FILE.LOOK_AHEAD	:= ASCII.NUL;
      FILE.HAS_LOOK_AHEAD	:= FALSE;
      FILE.AT_END_OF_FILE	:= FALSE;
    else
      raise NAME_ERROR;									-- LRM 14.2.1(7), piege n 45 desamorce
    end if;

  end	OPEN;
	----


			-----
  procedure		CLOSE		( FILE :in out FILE_TYPE )
  is			-----

    ERR_CODE	: INTEGER;

		-----------------
    function	CLOSE_SYSTEM_CALL	( FILE_ID :in INTEGER )	return INTEGER
    is		-----------------
    begin
      ASM_OP_2'( OPCODE => Ld, LVL => 2, OFS => -8 );
      ASM_OP_0'( OPCODE => SYS_FILE_CLOSE );
      ASM_OP_2'( OPCODE => SD, LVL => 2, OFS => -16 );			-- Retour du resultat syscall

    end	CLOSE_SYSTEM_CALL;
    -----------------

  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    FLUSH_OUT( FILE.ID );									-- ce qui attend dans le tampon part avant la fermeture
    ERR_CODE := CLOSE_SYSTEM_CALL( FILE.ID );
    RESET_BUFFER( FILE.ID );
    FILE.ID := -1;
    FILE.IS_OPENED := FALSE;

  end	CLOSE;
	-----


			------
  procedure		DELETE		( FILE :in out FILE_TYPE )
  is			------

    ERR_CODE	: INTEGER;

		------------------
    function	DELETE_SYSTEM_CALL  ( NAME : STRING )	return INTEGER
    is		------------------

    begin
      ASM_OP_2'( OPCODE => La, LVL => 2, OFS => -8 );
      ASM_OP_0'( OPCODE => SYS_FILE_DELETE );
      ASM_OP_2'( OPCODE => SD, LVL => 2, OFS => -16 );			-- Retour du resultat syscall

    end	DELETE_SYSTEM_CALL;
	------------------

  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    CLOSE( FILE );
    ERR_CODE := DELETE_SYSTEM_CALL( FILE.NAME( 1 .. FILE.NAME_LEN ) );
    RESET_BUFFER( FILE.ID );								-- rien a ecrire : le fichier n'existe plus
    FILE.IS_OPENED := FALSE;

  end	DELETE;
	------


			-----
  procedure		RESET		( FILE :in out FILE_TYPE; MODE :in FILE_MODE )
  is			-----

    ERR_CODE	: INTEGER;

		--------------
    function	SEEK_SYSTEM_CALL	( FILE_ID :in INTEGER )		return INTEGER
    is		--------------
    begin
      ASM_OP_1'( OPCODE => LI, VAL => 0 );				-- OFFSET = 0 (debut du fichier)
      ASM_OP_2'( OPCODE => Ld, LVL => 2, OFS => -8 );			-- FILE_ID
      ASM_OP_0'( OPCODE => SYS_FILE_SET_POS );
      ASM_OP_2'( OPCODE => SD, LVL => 2, OFS => -16 );			-- Retour du resultat syscall

    end	SEEK_SYSTEM_CALL;
	--------------

  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    FLUSH_OUT( FILE.ID );									-- ecrire a l'ancienne position avant de revenir au debut
    ERR_CODE := SEEK_SYSTEM_CALL( FILE.ID );
    RESET_BUFFER( FILE.ID );								-- la lecture anticipee ne vaut plus
    FILE.MODE := MODE;
    FILE.PAGE := 1;
    FILE.LINE := 1;
    FILE.COL  := 1;
    FILE.AT_END_OF_FILE := FALSE;
    FILE.HAS_LOOK_AHEAD := FALSE;

  end	RESET;
	-----


			-----
  procedure		RESET		( FILE :in out FILE_TYPE )
  is			-----
  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    RESET( FILE, FILE.MODE );

  end	RESET;
	-----


			----
  function		MODE		( FILE :in FILE_TYPE )		return FILE_MODE
  is			----
  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    return FILE.MODE;

  end	MODE;
	----


			----
  function		NAME		( FILE :in FILE_TYPE )		return STRING
  is			----
  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    return FILE.NAME( 1 .. FILE.NAME_LEN );

  end	NAME;
	----


			----
  function		FORM		( FILE :in FILE_TYPE )		return STRING
  is			----
  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    return "";

  end	FORM;
	----


			-------
  function		IS_OPEN		( FILE :in FILE_TYPE )		return BOOLEAN
  is			-------
  begin
    return FILE.IS_OPENED;

  end	IS_OPEN;
	-------


			-- Control of default input and output files


			---------
  procedure		SET_INPUT		( FILE :in FILE_TYPE )
  is			---------
  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  FILE.MODE /= IN_FILE  then raise MODE_ERROR; end if;
    DEFAULT_INPUT := FILE;

  end	SET_INPUT;
	---------


			----------
  procedure		SET_OUTPUT	( FILE :in FILE_TYPE )
  is			----------
  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  FILE.MODE /= OUT_FILE  then raise MODE_ERROR; end if;
    DEFAULT_OUTPUT := FILE;

  end	SET_OUTPUT;
	----------


			--------------
  function		STANDARD_INPUT					return FILE_TYPE
  is			--------------
  begin
    return STD_INPUT;

  end	STANDARD_INPUT;
	--------------


			---------------
  function		STANDARD_OUTPUT					return FILE_TYPE
  is			---------------
  begin
    return STD_OUTPUT;

  end	STANDARD_OUTPUT;
	---------------


			-------------
  function		CURRENT_INPUT					return FILE_TYPE
  is			-------------
  begin
    return DEFAULT_INPUT;

  end	CURRENT_INPUT;
	-------------


			--------------
  function		CURRENT_OUTPUT					return FILE_TYPE
  is			--------------
  begin
    return DEFAULT_OUTPUT;

  end	CURRENT_OUTPUT;
	--------------


		-- Primitives brutes (hors LRM)
		--
		-- Niveau RAW : flux d'octets pur. Aucune mise en page (COL/LINE/
		-- PAGE), aucune exception TEXT_IO ; a EOF, GET_RAW arme
		-- AT_END_OF_FILE et rend NUL. Consommateurs legitimes : les
		-- scanners tokenisants (INTEGER_IO, FLOAT_IO, FIXED_IO,
		-- ENUMERATION_IO), les lecteurs de structure (SKIP_LINE,
		-- SKIP_PAGE, END_OF_LINE/PAGE/FILE, GET_LINE) et les emetteurs
		-- de terminateurs (NEW_LINE, NEW_PAGE, SET_COL/SET_LINE).
		-- L'interface publique conforme LRM (GET/PUT) est construite
		-- au-dessus et ne touche jamais le flux directement ; le niveau
		-- RAW, lui, n'appelle jamais le niveau public.


			-------
  procedure		GET_RAW		( FILE :in FILE_TYPE; ITEM :out CHARACTER )
  is			-------

    BYTES_READ	: INTEGER;

		----------------
    function	READ_SYSTEM_CALL		( FILE_ID :in INTEGER )		return INTEGER
    is		----------------
    begin
      ASM_OP_1'( OPCODE => LI, VAL => 1 );								-- push LENGTH = 1 octet (immediat)
      ASM_OP_2'( OPCODE => La, LVL => 1, OFS => -16 );							-- push @ITEM : charge l'adresse destination (out param GET level 1 offset -16)
      ASM_OP_2'( OPCODE => Ld, LVL => 2, OFS => -8 );							-- push FILE_ID (in param READ_SYSTEM_CALL level 2 offset -8)
      ASM_OP_0'( OPCODE => SYS_FILE_READ );								-- (-8) FILE_ID ; (-16) @ITEM ; (-24) LENGTH
      ASM_OP_2'( OPCODE => SD, LVL => 2, OFS => -16 );							-- Retour du BYTES_READ

    end	READ_SYSTEM_CALL;
	-----------------

  begin
    if  FILE.HAS_LOOK_AHEAD  then
      ITEM := FILE.LOOK_AHEAD;
      FILE.HAS_LOOK_AHEAD := FALSE;

    elsif  FILE.ID = -1  then										-- standard console input
      ASM_OP_2'( OPCODE => La, LVL => 1, OFS => -16 );							-- push @ITEM : charge l'adresse destination (out param GET level 1 offset -16)
      ASM_OP_0'( OPCODE => SYS_GET_CHAR );								-- get console char

    elsif  FILE.ID > MAX_BUF_ID  then									-- descripteur hors table : ancien chemin
      BYTES_READ := READ_SYSTEM_CALL( FILE.ID );								-- general file
      if  BYTES_READ = 0  then
        FILE.AT_END_OF_FILE := TRUE;
        ITEM := ASCII.NUL;
      end if;

    else												-- fichier tamponne : blocs de BUF_SIZE
      if  BUFS( FILE.ID ).IN_POS >= BUFS( FILE.ID ).IN_LEN  then
        BYTES_READ := READ_RAW( FILE.ID, BUFS( FILE.ID ).DATA );
        if  BYTES_READ < 0  then BYTES_READ := 0; end if;						-- erreur assimilee a la fin de fichier
        BUFS( FILE.ID ).IN_LEN := BYTES_READ;
        BUFS( FILE.ID ).IN_POS := 0;
      end if;
      if  BUFS( FILE.ID ).IN_LEN = 0  then
        FILE.AT_END_OF_FILE := TRUE;
        ITEM := ASCII.NUL;
      else
        BUFS( FILE.ID ).IN_POS := BUFS( FILE.ID ).IN_POS + 1;
        ITEM := BUFS( FILE.ID ).DATA( BUFS( FILE.ID ).IN_POS );
      end if;
    end if;

  end	GET_RAW;
	-------


			-------
  procedure		PUT_RAW		( FILE :in FILE_TYPE; ITEM :in CHARACTER )
  is			-------

    ERR_CODE	: INTEGER;

		-----------------
    function	WRITE_SYSTEM_CALL		( ID : INTEGER )		return INTEGER
    is		-----------------
    begin
      ASM_OP_1'( OPCODE => LI,  VAL => 1 );								-- push LENGTH en -24
      ASM_OP_2'( OPCODE => LVa, LVL => 1, OFS => -16 );							-- push @CHAR (in param PUT level 1 offset -16)
      ASM_OP_2'( OPCODE => Ld,  LVL => 2, OFS => -8 );							-- ID  (in param WRITE_SYSTEM_CALL level 2 offset -8)
      ASM_OP_0'( OPCODE => SYS_FILE_WRITE );								-- (-8) FILE_ID ; (-16) @ITEM ; (-24) LENGTH
      ASM_OP_2'( OPCODE => SD,  LVL => 2, OFS => -16 );							-- Retour du resultat syscall

    end	WRITE_SYSTEM_CALL;
	-----------------
  begin
    if  FILE.ID = -1  then										-- standard console output
      ASM_OP_2'( OPCODE => LB, LVL => 1, OFS => -16 );
      ASM_OP_0'( OPCODE => SYS_PUT_CHAR );

    elsif  FILE.ID > MAX_BUF_ID  then									-- descripteur hors table : ancien chemin
      ERR_CODE := WRITE_SYSTEM_CALL( FILE.ID );								-- general file

    else												-- fichier tamponne
      if  BUFS( FILE.ID ).OUT_LEN = BUF_SIZE  then
        FLUSH_OUT( FILE.ID );
      end if;
      BUFS( FILE.ID ).OUT_LEN := BUFS( FILE.ID ).OUT_LEN + 1;
      BUFS( FILE.ID ).DATA( BUFS( FILE.ID ).OUT_LEN ) := ITEM;
    end if;

  end	PUT_RAW;
	-------


			-------
  procedure		PUT_RAW		( FILE :in FILE_TYPE; ITEM :in STRING )
  is			-------

    ERR_CODE	: INTEGER;

		-----------------
    function	WRITE_SYSTEM_CALL		( FILE_ID :INTEGER; LENGTH :POSITIVE )		return INTEGER
    is		-----------------
    begin
      ASM_OP_2'( OPCODE => Ld, LVL => 2, OFS => -16 );							-- LENGTH en -16
      ASM_OP_2'( OPCODE => LIa, LVL => 1, OFS => -16 );							-- @CHARS sur parametre ITEM de PUT
      ASM_OP_2'( OPCODE => Ld, LVL => 2, OFS => -8 );							-- ID
      ASM_OP_0'( OPCODE => SYS_FILE_WRITE );
      ASM_OP_2'( OPCODE => SD, LVL => 2, OFS => -24 );							-- Retour du resultat syscall

    end	WRITE_SYSTEM_CALL;
	-----------------
  begin
    if  ITEM'LENGTH = 0  then return; end if;
    if  FILE.ID = -1  then
      ASM_OP_2'( OPCODE => LA, LVL => 1, OFS => -16 );
      ASM_OP_0'( OPCODE => SYS_PUT_STR );

    elsif  FILE.ID > MAX_BUF_ID  then									-- descripteur hors table : ancien chemin
      ERR_CODE := WRITE_SYSTEM_CALL( FILE.ID, ITEM'LENGTH );

    else												-- fichier tamponne
      if  ITEM'LENGTH > BUF_SIZE - BUFS( FILE.ID ).OUT_LEN  then					-- ne tient pas derriere ce qui attend
        FLUSH_OUT( FILE.ID );
      end if;
      if  ITEM'LENGTH > BUF_SIZE  then									-- ne tiendra jamais : ecriture directe
        WRITE_RAW( FILE.ID, ITEM );
      else
        BUFS( FILE.ID ).DATA( BUFS( FILE.ID ).OUT_LEN + 1 .. BUFS( FILE.ID ).OUT_LEN + ITEM'LENGTH ) := ITEM;
        BUFS( FILE.ID ).OUT_LEN := BUFS( FILE.ID ).OUT_LEN + ITEM'LENGTH;
      end if;
    end if;

  end	PUT_RAW;
	-------



			-- Specification of line and page lengths


			---------------
  procedure		SET_LINE_LENGTH	( FILE :in FILE_TYPE; TO :in COUNT )
  is			---------------
  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  FILE.MODE /= OUT_FILE  then raise MODE_ERROR; end if;
    FILE.LINE_LENGTH := TO;

  end	SET_LINE_LENGTH;
	---------------


			---------------
  procedure		SET_LINE_LENGTH	( TO :in COUNT)
  is			---------------
  begin
    SET_LINE_LENGTH( DEFAULT_OUTPUT, TO );

  end	SET_LINE_LENGTH;
	---------------


			---------------
  procedure		SET_PAGE_LENGTH	( FILE :in FILE_TYPE; TO :in COUNT )
  is			---------------
  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  FILE.MODE /= OUT_FILE  then raise MODE_ERROR; end if;
    FILE.PAGE_LENGTH := TO;
  end	SET_PAGE_LENGTH;
	---------------


			---------------
  procedure		SET_PAGE_LENGTH	( TO :in COUNT)
  is			---------------
  begin
    SET_PAGE_LENGTH( DEFAULT_OUTPUT, TO );

  end	SET_PAGE_LENGTH;
	---------------


			-----------
  function		LINE_LENGTH	( FILE :in FILE_TYPE )		return COUNT
  is			-----------
  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  FILE.MODE /= OUT_FILE  then raise MODE_ERROR; end if;
    return FILE.LINE_LENGTH;

  end	LINE_LENGTH;
	-----------


			-----------
  function		LINE_LENGTH					return COUNT
  is			-----------
  begin
    return LINE_LENGTH( DEFAULT_OUTPUT );

  end	LINE_LENGTH;
	-----------


			-----------
  function		PAGE_LENGTH	( FILE :in FILE_TYPE )		return COUNT
  is			-----------
  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  FILE.MODE /= OUT_FILE  then raise MODE_ERROR; end if;
    return FILE.PAGE_LENGTH;

  end	PAGE_LENGTH;
	-----------


			-----------
  function		PAGE_LENGTH					return COUNT
  is			-----------
  begin
    return PAGE_LENGTH( DEFAULT_OUTPUT );

  end	PAGE_LENGTH;
	-----------


			-- Column, Line, and Page Control


			--------
  procedure		NEW_LINE		( FILE	:in FILE_TYPE;
					  SPACING :in POSITIVE_COUNT := 1 )
  is			--------
  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  FILE.MODE /= OUT_FILE  then raise MODE_ERROR; end if;

    PUT_RAW( FILE, ASCII.CR );
    FILE.COL := 1;											-- LRM 14.3.4(3) col := 1
    for  N in 1 .. SPACING  loop
      PUT_RAW( FILE, ASCII.LF );
    end loop;
    FILE.LINE := FILE.LINE + SPACING;
    if  FILE.PAGE_LENGTH /= 0  and then  FILE.LINE > FILE.PAGE_LENGTH  then
      PUT_RAW( FILE,ASCII.FF );
      FILE.PAGE := FILE.PAGE + 1;
      FILE.LINE := 1;
    end if;

  end	NEW_LINE;
	--------


			--------
  procedure		NEW_LINE		( SPACING :in POSITIVE_COUNT := 1 )
  is			--------
  begin
    NEW_LINE( DEFAULT_OUTPUT, SPACING );

  end	NEW_LINE;
	--------


			---------
  procedure		SKIP_LINE		( FILE	:in FILE_TYPE;
					  SPACING :in POSITIVE_COUNT := 1 )
  is			---------

    CH		: CHARACTER;
    LINES_SKIPPED	: COUNT		:= 0;

  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  FILE.MODE /= IN_FILE  then raise MODE_ERROR; end if;
    if  FILE.AT_END_OF_FILE  then raise END_ERROR; end if;					-- LRM 14.3.4(9)

    loop
      exit when  FILE.AT_END_OF_FILE;
      GET_RAW( FILE, CH );
      exit when  FILE.AT_END_OF_FILE;
      if  CH = ASCII.FF  then								-- terminateur de page rencontre
        FILE.PAGE := FILE.PAGE + 1;
        FILE.LINE := 1;
        FILE.COL  := 1;
      end if;
      if  CH = ASCII.LF  then
        LINES_SKIPPED := LINES_SKIPPED + 1;
        FILE.LINE := FILE.LINE + 1;
        FILE.COL := 1;
        exit when  LINES_SKIPPED >= SPACING;
      end if;
    end loop;

  end	SKIP_LINE;
	---------


			---------
  procedure		SKIP_LINE		( SPACING :in POSITIVE_COUNT := 1 )
  is			---------
  begin
    SKIP_LINE( DEFAULT_INPUT, SPACING );

  end	SKIP_LINE;
	---------


			-----------
  function		END_OF_LINE	( FILE :in FILE_TYPE)		return BOOLEAN
  is			-----------

    CH	: CHARACTER;

  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  FILE.MODE /= IN_FILE  then raise MODE_ERROR; end if;
    if  FILE.AT_END_OF_FILE  then return TRUE; end if;
    if  FILE.HAS_LOOK_AHEAD  then
      return FILE.LOOK_AHEAD = ASCII.LF  or else  FILE.LOOK_AHEAD = ASCII.CR
					or else  FILE.LOOK_AHEAD = ASCII.FF;
    end if;
    -- Tenter de lire un caractere
    GET_RAW( FILE, CH );
    if  FILE.AT_END_OF_FILE  then
      return TRUE;
    else
      FILE.LOOK_AHEAD := CH;
      FILE.HAS_LOOK_AHEAD := TRUE;
      return CH = ASCII.LF  or else  CH = ASCII.CR  or else  CH = ASCII.FF;
    end if;

  end	END_OF_LINE;
	-----------


			-----------
  function		END_OF_LINE					return BOOLEAN
  is			-----------
  begin null;
    return END_OF_LINE( DEFAULT_INPUT );

  end	END_OF_LINE;
	-----------


			--------
  procedure		NEW_PAGE		( FILE :in FILE_TYPE )
  is			--------
  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  FILE.MODE /= OUT_FILE  then raise MODE_ERROR; end if;
    if  FILE.COL /= 1  then
      NEW_LINE( FILE );
    end if;
    PUT_RAW( FILE, ASCII.FF );
    FILE.PAGE := FILE.PAGE + 1;
    FILE.LINE := 1;

  end	NEW_PAGE;
	--------


			--------
  procedure		NEW_PAGE
  is			--------
  begin
    NEW_PAGE( DEFAULT_OUTPUT );

  end	NEW_PAGE;
	----


			---------
  procedure		SKIP_PAGE		( FILE :in FILE_TYPE )
  is			---------

    CH	: CHARACTER;

  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  FILE.MODE /= IN_FILE  then raise MODE_ERROR; end if;
    if  FILE.AT_END_OF_FILE  then raise END_ERROR; end if;					-- LRM 14.3.4(21)
    loop
      exit when  FILE.AT_END_OF_FILE;
      GET_RAW( FILE, CH );
      exit when  FILE.AT_END_OF_FILE;
      if  CH = ASCII.LF  then
        FILE.LINE := FILE.LINE + 1;
        FILE.COL := 1;
      end if;
      exit when  CH = ASCII.FF;
    end loop;
    FILE.PAGE := FILE.PAGE + 1;
    FILE.LINE := 1;
    FILE.COL := 1;

  end	SKIP_PAGE;
	---------


			---------
  procedure		SKIP_PAGE
  is			---------
  begin
    SKIP_PAGE( DEFAULT_INPUT );

  end	SKIP_PAGE;
	---------


			-----------
  function		END_OF_PAGE	( FILE :in FILE_TYPE )		return BOOLEAN
  is			-----------

    CH	: CHARACTER;

  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  FILE.MODE /= IN_FILE  then raise MODE_ERROR; end if;
    if  FILE.AT_END_OF_FILE  then return TRUE; end if;
    if  FILE.HAS_LOOK_AHEAD  then
      return FILE.LOOK_AHEAD = ASCII.FF;
    end if;
    -- Tenter de lire un caractere
    GET_RAW( FILE, CH );
    if  FILE.AT_END_OF_FILE  then
      return TRUE;
    else
      FILE.LOOK_AHEAD := CH;
      FILE.HAS_LOOK_AHEAD := TRUE;
      return CH = ASCII.FF;
    end if;

  end	END_OF_PAGE;
	-----------


			-----------
  function		END_OF_PAGE					return BOOLEAN
  is			-----------
  begin
    return END_OF_PAGE( DEFAULT_INPUT );

  end	END_OF_PAGE;
	-----------


			-----------
  function		END_OF_FILE	( FILE :in FILE_TYPE )		return BOOLEAN
  is			-----------

    CH	: CHARACTER;

  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  FILE.MODE /= IN_FILE  then raise MODE_ERROR; end if;
    if  FILE.AT_END_OF_FILE  then return TRUE; end if;
    if  FILE.HAS_LOOK_AHEAD  then return FALSE; end if;
    -- Tenter de lire un caractere
    GET_RAW( FILE, CH );
    if  FILE.AT_END_OF_FILE  then
      return TRUE;
    else
      FILE.LOOK_AHEAD := CH;
      FILE.HAS_LOOK_AHEAD := TRUE;
      return FALSE;
    end if;

  end	END_OF_FILE;
	-----------


			-----------
  function		END_OF_FILE					return BOOLEAN
  is			-----------
  begin
    return END_OF_FILE( DEFAULT_INPUT );

  end	END_OF_FILE;
	-----------


			-------
  procedure		SET_COL		( FILE :in FILE_TYPE; TO :in POSITIVE_COUNT )
  is			-------
  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;

    if  FILE.MODE /= IN_FILE  then
      -- Sortie, LRM 14.3.4(29-31) : espaces jusqu'a la colonne TO ;
      -- si TO est en arriere, terminateur de ligne d'abord.
      if  FILE.LINE_LENGTH /= 0  and then  TO > FILE.LINE_LENGTH  then
        raise LAYOUT_ERROR;								-- LRM 14.3.4(31)
      end if;
      if  TO < FILE.COL  then
        NEW_LINE( FILE );
      end if;
      while  FILE.COL < TO  loop
        PUT_RAW( FILE, ' ' );
        FILE.COL := FILE.COL + 1;
      end loop;
    else
      -- Entree, LRM 14.3.4(32-33) : DIFFERE (restriction consignee).
      -- Le positionnement par lecture (saut de caracteres et de
      -- terminateurs jusqu'a la colonne TO, END_ERROR au terminateur
      -- de fichier) n'est pas implante ; on conserve l'affectation
      -- directe historique du compteur.
      FILE.COL := TO;
    end if;

  end	SET_COL;
	-------


			-------
  procedure		SET_COL		( TO :in POSITIVE_COUNT )
  is			-------
  begin
    SET_COL( DEFAULT_OUTPUT, TO );

  end	SET_COL;
	-------


			--------
  procedure		SET_LINE		( FILE :in FILE_TYPE; TO :in POSITIVE_COUNT )
  is			--------
  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;

    if  FILE.MODE /= IN_FILE  then
      -- Sortie, LRM 14.3.4(36-38) : NEW_LINE jusqu'a la ligne TO ;
      -- si TO est en arriere, terminateur de page d'abord.
      if  FILE.PAGE_LENGTH /= 0  and then  TO > FILE.PAGE_LENGTH  then
        raise LAYOUT_ERROR;								-- LRM 14.3.4(38)
      end if;
      if  TO < FILE.LINE  then
        NEW_PAGE( FILE );
      end if;
      while  FILE.LINE < TO  loop
        NEW_LINE( FILE );
      end loop;
    else
      -- Entree, LRM 14.3.4(39-40) : DIFFERE (restriction consignee),
      -- meme regime que SET_COL en entree.
      FILE.LINE := TO;
    end if;

  end	SET_LINE;
	--------


			--------
  procedure		SET_LINE		( TO :in POSITIVE_COUNT )
  is			--------
  begin
    SET_LINE( DEFAULT_OUTPUT, TO );

  end	SET_LINE;
	--------


			---
  function		COL		( FILE :in FILE_TYPE )		return POSITIVE_COUNT
  is			---
  begin
    if  FILE.COL > COUNT'LAST  then raise LAYOUT_ERROR; end if;
    return FILE.COL;

  end	COL;
	---


			---
  function		COL						return POSITIVE_COUNT
  is			---
  begin
    return COL( DEFAULT_OUTPUT );

  end	COL;
	---


			----
  function		LINE		( FILE :in FILE_TYPE )		return POSITIVE_COUNT
  is			----
  begin
    if  FILE.LINE > COUNT'LAST  then raise LAYOUT_ERROR; end if;
    return FILE.LINE;

  end	LINE;
	----


			----
  function		LINE						return POSITIVE_COUNT
  is			----
  begin
    return LINE( DEFAULT_OUTPUT );

  end	LINE;
	----


			----
  function		PAGE		( FILE :in FILE_TYPE )		return POSITIVE_COUNT
  is			----
  begin
    if  FILE.PAGE > COUNT'LAST  then raise LAYOUT_ERROR; end if;
    return FILE.PAGE;

  end	PAGE;
	----


			----
  function		PAGE						return POSITIVE_COUNT
  is			----
  begin
    return PAGE( DEFAULT_OUTPUT );

  end	PAGE;
	----


			-- Character Input-Output


			---
  procedure		GET		( FILE :in FILE_TYPE; ITEM :out CHARACTER )
  is			---

    CH	: CHARACTER;

  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  FILE.MODE /= IN_FILE  then raise MODE_ERROR; end if;

    -- LRM 14.3.6(4-5) : saute les terminateurs de ligne et de page en
    -- tenant LINE/COL/PAGE a jour ; leve END_ERROR sur le terminateur
    -- de fichier. La lecture physique est deleguee a GET_RAW.
    loop
      if  FILE.AT_END_OF_FILE  then raise END_ERROR; end if;
      GET_RAW( FILE, CH );
      if  FILE.AT_END_OF_FILE  then raise END_ERROR; end if;

      if  CH = ASCII.LF  then
        FILE.LINE := FILE.LINE + 1;
        FILE.COL  := 1;
      elsif  CH = ASCII.FF  then
        FILE.PAGE := FILE.PAGE + 1;
        FILE.LINE := 1;
        FILE.COL  := 1;
      elsif  CH /= ASCII.CR  then							-- CR : moitie muette du terminateur CR LF
        ITEM := CH;
        FILE.COL := FILE.COL + 1;
        return;
      end if;
    end loop;

  end	GET;
	----


			---
  procedure		GET		( ITEM :out CHARACTER )
  is			---
  begin
    GET( DEFAULT_INPUT, ITEM );

  end	GET;
	----


			---
  procedure		PUT		( FILE :in FILE_TYPE; ITEM :in CHARACTER )
  is			---
  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  FILE.MODE /= OUT_FILE  then raise MODE_ERROR; end if;

    -- LRM 14.3.6(4) : coupure implicite si la longueur de ligne est
    -- bornee et que la colonne courante la depasse.
    if  FILE.LINE_LENGTH /= 0  and then  FILE.COL > FILE.LINE_LENGTH  then
      NEW_LINE( FILE );
    end if;
    PUT_RAW( FILE, ITEM );
    FILE.COL := FILE.COL + 1;

  end	PUT;
	----


			---
  procedure		PUT		( ITEM :in CHARACTER )
  is			---
  begin
    PUT( DEFAULT_OUTPUT, ITEM );

  end	PUT;
	----


			-- String Input-Output


			---
  procedure		GET		( FILE :in FILE_TYPE; ITEM :out STRING )
  is			---
  begin
    -- LRM 14.3.6(6) : succession de GET caractere ; passe par le GET
    -- public (saut des terminateurs, END_ERROR, look-ahead respecte).
    -- L'ancien chemin de lecture en bloc contournait le look-ahead.
    for  I  in  ITEM'FIRST .. ITEM'LAST  loop
      GET( FILE, ITEM( I ) );
    end loop;

  end	GET;
	----


			---
  procedure		GET		( ITEM :out STRING )
  is			---
  begin
    GET( DEFAULT_INPUT, ITEM );

  end	GET;
	----


			---
  procedure		PUT		( FILE :in FILE_TYPE; ITEM :in STRING )
  is			---
  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  FILE.MODE /= OUT_FILE  then raise MODE_ERROR; end if;

    if  FILE.LINE_LENGTH /= 0  then
      -- Ligne bornee : caractere par caractere pour beneficier des
      -- coupures implicites du PUT public (LRM 14.3.6(4)).
      for  I  in  ITEM'FIRST .. ITEM'LAST  loop
        PUT( FILE, ITEM( I ) );
      end loop;
    else
      -- Ligne non bornee : ecriture en bloc, comptabilite de colonne.
      PUT_RAW( FILE, ITEM );
      FILE.COL := FILE.COL + COUNT( ITEM'LENGTH );
    end if;

  end	PUT;
	---


			---
  procedure		PUT		( ITEM :in STRING )
  is			---
  begin
    PUT( DEFAULT_OUTPUT, ITEM );

  end	PUT;
	----


			--------
  procedure		GET_LINE		( FILE :in FILE_TYPE;
					  ITEM :out STRING;
					  LAST :out NATURAL
					)
  is			--------

    CH	: CHARACTER;
    POS	: NATURAL		:= ITEM'FIRST;

  begin
    if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  FILE.MODE /= IN_FILE  then raise MODE_ERROR; end if;
    if  FILE.ID = -1  then										-- standard console input : utiliser SYS_GET_STR (mode canonique avec echo)
      ASM_OP_2'( OPCODE => La, LVL => 1, OFS => -24 );							-- push @LAST  (adresse du parametre out LAST)
      ASM_OP_2'( OPCODE => La, LVL => 1, OFS => -16 );							-- push @ITEM descripteur (adresse du parametre out ITEM = descripteur string)
      ASM_OP_0'( OPCODE => SYS_GET_STR );								-- lit une ligne stdin avec echo, stocke longueur dans LAST
    else
      if  FILE.AT_END_OF_FILE  then raise END_ERROR; end if;						-- LRM 14.3.6(12)
      LAST := ITEM'FIRST - 1;
      loop
        exit when  POS > ITEM'LAST;
        exit when  FILE.AT_END_OF_FILE;
        GET_RAW( FILE, CH );
        exit when  FILE.AT_END_OF_FILE;									-- fin de fichier = fin de ligne implicite
        if  CH = ASCII.LF  then									-- terminateur de ligne consomme
	FILE.LINE := FILE.LINE + 1;
	FILE.COL  := 1;
	exit;
        end if;
        if  CH = ASCII.FF  then									-- terminateur de page consomme
	FILE.PAGE := FILE.PAGE + 1;
	FILE.LINE := 1;
	FILE.COL  := 1;
	exit;
        end if;
        if  CH /= ASCII.CR  then
	ITEM( POS ) := CH;
	LAST := POS;
	POS := POS + 1;
	FILE.COL := FILE.COL + 1;
        end if;
      end loop;
    end if;

  end	GET_LINE;
	--------


			--------
  procedure		GET_LINE		( ITEM :out STRING; LAST :out NATURAL )
  is			--------
  begin
    GET_LINE( DEFAULT_INPUT, ITEM, LAST );

  end	GET_LINE;
	--------


			--------
  procedure		PUT_LINE		( FILE :in FILE_TYPE; ITEM :in STRING )
  is			--------
  begin
    PUT( FILE, ITEM );
    NEW_LINE( FILE );

  end	PUT_LINE;
	--------


			--------
  procedure		PUT_LINE		( ITEM :in STRING )
  is			--------
  begin
    PUT( DEFAULT_OUTPUT, ITEM );
    NEW_LINE( DEFAULT_OUTPUT );

  end	PUT_LINE;
	--------


			-- Generic package for Input-Output of Integer Types


				----------
  package body			INTEGER_IO
  is				----------

			---
    procedure		GET		( FILE  :in FILE_TYPE;
					  ITEM  :out NUM;
					  WIDTH :in FIELD := 0
					)
    is

      CH			: CHARACTER;
      VAL			: LONG_INTEGER	:= 0;	-- accumulation en 64 bits
      NEG			: BOOLEAN		:= FALSE;
      CHARS_READ		: NATURAL		:= 0;
      DONE		: BOOLEAN		:= FALSE;
      BASE		: LONG_INTEGER	:= 10;	-- base courante
      IN_BASED		: BOOLEAN		:= FALSE;
      HAVE_DIGIT	: BOOLEAN		:= FALSE;
      DIG		: LONG_INTEGER;

    begin
      if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
      if  FILE.MODE /= IN_FILE  then raise MODE_ERROR; end if;

      if  WIDTH = 0  then
        loop
	exit when  FILE.AT_END_OF_FILE;
	GET_RAW( FILE, CH );
	exit when  FILE.AT_END_OF_FILE;
	exit when  CH /= ' '  and then  CH /= ASCII.HT
			and then  CH /= ASCII.LF
			and then  CH /= ASCII.CR
			and then  CH /= ASCII.FF;
        end loop;
      else
        GET_RAW( FILE, CH );
        CHARS_READ := 0;
      end if;
      if  FILE.AT_END_OF_FILE  then raise END_ERROR; end if;				-- LRM 14.3.7(?) fin de fichier avant l'item

      -- Signe optionnel
      if  not FILE.AT_END_OF_FILE  and then  CH = '-'  then
        NEG := TRUE;
        if  WIDTH > 0  then
	CHARS_READ := CHARS_READ + 1;
	if  CHARS_READ >= WIDTH  then  DONE := TRUE;
	else  GET_RAW( FILE, CH );
	end if;
        else
	GET_RAW( FILE, CH );
        end if;
      elsif  not FILE.AT_END_OF_FILE  and then  CH = '+'  then
        if  WIDTH > 0  then
	CHARS_READ := CHARS_READ + 1;
	if  CHARS_READ >= WIDTH  then  DONE := TRUE;
	else  GET_RAW( FILE, CH );
	end if;
        else
	GET_RAW( FILE, CH );
        end if;
      end if;

      loop
        exit when  DONE  or else  FILE.AT_END_OF_FILE;
        if  WIDTH > 0  and then  CHARS_READ >= WIDTH  then  exit;  end if;

        if  CH >= '0'  and then  CH <= '9'  then
	DIG := LONG_INTEGER( CHARACTER'POS( CH ) - CHARACTER'POS( '0' ) );
	if  IN_BASED  and then  DIG >= BASE  then
	  raise DATA_ERROR;								-- chiffre incompatible avec la base
	end if;
	VAL := BASE * VAL + DIG;		        -- base courante (10 ou base#)
	HAVE_DIGIT := TRUE;
	if  WIDTH > 0  then
	  CHARS_READ := CHARS_READ + 1;
	  if  CHARS_READ >= WIDTH  then  DONE := TRUE;
	  else  GET_RAW( FILE, CH );
	  end if;
	else
	  GET_RAW( FILE, CH );
	end if;

        elsif  ( CH = 'A'  or else  CH = 'B'  or else  CH = 'C'
	    or else  CH = 'D'  or else  CH = 'E'  or else  CH = 'F'
	    or else  CH = 'a'  or else  CH = 'b'  or else  CH = 'c'
	    or else  CH = 'd'  or else  CH = 'e'  or else  CH = 'f' )
	    and then  IN_BASED  then
	if  CH >= 'a'  then
	  DIG := LONG_INTEGER( CHARACTER'POS( CH ) - CHARACTER'POS( 'a' ) + 10 );
	else
	  DIG := LONG_INTEGER( CHARACTER'POS( CH ) - CHARACTER'POS( 'A' ) + 10 );
	end if;
	if  DIG >= BASE  then
	  raise DATA_ERROR;								-- chiffre incompatible avec la base
	end if;
	VAL := BASE * VAL + DIG;
	HAVE_DIGIT := TRUE;
	if  WIDTH > 0  then
	  CHARS_READ := CHARS_READ + 1;
	  if  CHARS_READ >= WIDTH  then  DONE := TRUE;
	  else  GET_RAW( FILE, CH );
	  end if;
	else
	  GET_RAW( FILE, CH );
	end if;

        elsif  CH = '#'  and then  not IN_BASED  then
	BASE     := VAL;			        -- VAL contient la base
	VAL      := 0;
	IN_BASED := TRUE;
	if  WIDTH > 0  then
	  CHARS_READ := CHARS_READ + 1;
	  if  CHARS_READ >= WIDTH  then  DONE := TRUE;
	  else  GET_RAW( FILE, CH );
	  end if;
	else
	  GET_RAW( FILE, CH );
	end if;

        elsif  CH = '#'  and then  IN_BASED  then
	if  WIDTH > 0  then  CHARS_READ := CHARS_READ + 1;  end if;
	DONE := TRUE;

        else
	if  WIDTH = 0  then
	  FILE.LOOK_AHEAD	  := CH;
	  FILE.HAS_LOOK_AHEAD := TRUE;
	end if;
	DONE := TRUE;
        end if;
      end loop;

      if  not HAVE_DIGIT  then raise DATA_ERROR; end if;					-- LRM 14.3.7 image invalide

      if  NEG  then  ITEM := -NUM( VAL );
      else	 ITEM := NUM(  VAL );
      end if;

    end	GET;
	---


			---
    procedure		GET		( ITEM  :out NUM; WIDTH : in FIELD := 0)
    is			---
    begin
      GET( DEFAULT_INPUT, ITEM, WIDTH );

    end	GET;
	----


			---
    procedure		PUT		( FILE  :in FILE_TYPE;
					  ITEM  :in NUM;
					  WIDTH :in FIELD		:= DEFAULT_WIDTH;
					  BASE  :in NUMBER_BASE	:= DEFAULT_BASE
					)
    is			---

      LBASE		: LONG_INTEGER		:= LONG_INTEGER( BASE );
      AVAL		: LONG_INTEGER;		-- valeur absolue, toujours >= 0
      STR			: STRING( 1 .. 68 );
      POS			: POSITIVE		:= STR'LAST;
      IS_NEGATIVE		: BOOLEAN			:= ITEM < 0;
      DIGIT		: INTEGER;
      DLEN		: NATURAL;
      TLEN		: NATURAL;

    begin
      -- Conversion en valeur absolue dans LONG_INTEGER :
      -- meme NUM'FIRST (ex: -2147483648) ne deborde pas en LONG_INTEGER.
      if  IS_NEGATIVE  then
        AVAL := -LONG_INTEGER( ITEM );
      else
        AVAL :=  LONG_INTEGER( ITEM );
      end if;

      loop
        DIGIT := INTEGER( AVAL mod LBASE );     -- AVAL >= 0, resultat toujours >= 0
        if  DIGIT < 10  then
	STR( POS ) := CHARACTER'VAL( CHARACTER'POS( '0' ) + DIGIT );
        else
	STR( POS ) := CHARACTER'VAL( CHARACTER'POS( 'A' ) + DIGIT - 10 );
        end if;
        AVAL := AVAL / LBASE;
        exit when  AVAL = 0;
        POS  := POS - 1;
      end loop;

      DLEN := STR'LAST - POS + 1;
      TLEN := DLEN;
      if  IS_NEGATIVE  then  TLEN := TLEN + 1;  end if;
      if  BASE /= 10  then
        if  BASE >= 10  then  TLEN := TLEN + 4;
        else		TLEN := TLEN + 3;
        end if;
      end if;

      if  WIDTH > TLEN  then
        for  I in 1 .. WIDTH - TLEN  loop
	PUT( FILE, ' ' );
        end loop;
      end if;

      if  IS_NEGATIVE  then  PUT( FILE, '-' );  end if;

      if  BASE /= 10  then
        if  BASE >= 10  then
	PUT( FILE, '1' );
	PUT( FILE, CHARACTER'VAL( CHARACTER'POS( '0' ) + BASE - 10 ) );
        else
	PUT( FILE, CHARACTER'VAL( CHARACTER'POS( '0' ) + BASE ) );
        end if;
        PUT( FILE, '#' );
      end if;

      PUT( FILE, STR( POS .. STR'LAST ) );

      if  BASE /= 10  then  PUT( FILE, '#' );  end if;

    end	PUT;
	---


			---
    procedure		PUT		( ITEM  :in NUM;
					  WIDTH :in FIELD		:= DEFAULT_WIDTH;
					  BASE  :in NUMBER_BASE	:= DEFAULT_BASE
					)
    is			---
    begin
      PUT( DEFAULT_OUTPUT, ITEM, WIDTH, BASE );

    end	PUT;
	----


			---
    procedure		GET		( FROM :in STRING;						-- LRM 14.3.7(14)
					  ITEM :out NUM;
					  LAST :out POSITIVE
					)
    is			---

      POS			: POSITIVE	:= FROM'FIRST;
      VAL			: INTEGER		:= 0;
      NEG			: BOOLEAN		:= FALSE;
      DONE		: BOOLEAN		:= FALSE;
      BASE		: INTEGER		:= 10;
      IN_BASED		: BOOLEAN		:= FALSE;
      CH			: CHARACTER;
      HAVE_DIGIT	: BOOLEAN		:= FALSE;
      DIG		: INTEGER;

    begin

      -- Saut des separateurs initiaux (blancs et horizontaux)
      -- LRM 14.3.7 : meme regle que GET fichier WIDTH=0,
      -- mais seuls les blancs sont sautes (pas les LF --
      -- un STRING ne contient pas de line terminators au sens TEXT_IO).
      while  POS <= FROM'LAST  and then
	   ( FROM( POS ) = ' '  or else  FROM( POS ) = ASCII.HT )  loop
        POS := POS + 1;
      end loop;

      -- Signe optionnel
      if  POS <= FROM'LAST  then
        CH := FROM( POS );
        if  CH = '-'  then
	NEG := TRUE;
	POS := POS + 1;
        elsif  CH = '+'  then
	POS := POS + 1;
        end if;
      end if;

      -- Chiffres, based literals
      loop
        exit when  DONE  or else  POS > FROM'LAST;
        CH := FROM( POS );

        if  CH >= '0'  and then  CH <= '9'  then
	DIG := INTEGER( CHARACTER'POS( CH ) - CHARACTER'POS( '0' ) );
	if  IN_BASED  and then  DIG >= BASE  then
	  raise DATA_ERROR;								-- chiffre incompatible avec la base
	end if;
	VAL := BASE * VAL + DIG;
	HAVE_DIGIT := TRUE;
	LAST := POS;
	POS  := POS + 1;

        elsif  ( CH = 'A'  or else  CH = 'B'  or else  CH = 'C'
	    or else  CH = 'D'  or else  CH = 'E'  or else  CH = 'F'
	    or else  CH = 'a'  or else  CH = 'b'  or else  CH = 'c'
	    or else  CH = 'd'  or else  CH = 'e'  or else  CH = 'f' )
	    and then  IN_BASED  then
	if  CH >= 'a'  then
	  DIG := INTEGER( CHARACTER'POS( CH ) - CHARACTER'POS( 'a' ) + 10 );
	else
	  DIG := INTEGER( CHARACTER'POS( CH ) - CHARACTER'POS( 'A' ) + 10 );
	end if;
	if  DIG >= BASE  then
	  raise DATA_ERROR;								-- chiffre incompatible avec la base
	end if;
	VAL := BASE * VAL + DIG;
	HAVE_DIGIT := TRUE;
	LAST := POS;
	POS  := POS + 1;

        elsif  CH = '#'  and then  not IN_BASED  then
	-- Premier '#' : VAL contient la base
	BASE     := VAL;
	VAL      := 0;
	IN_BASED := TRUE;
	LAST     := POS;
	POS      := POS + 1;

        elsif  CH = '#'  and then  IN_BASED  then
	-- Second '#' : fin du based literal
	LAST := POS;
	DONE := TRUE;

        else
	-- Caractere hors-token : on s'arrete, LAST reste sur le precedent
	DONE := TRUE;
        end if;
      end loop;

      if  not HAVE_DIGIT  then raise DATA_ERROR; end if;					-- LRM 14.3.7(16) image invalide

      if  NEG  then  ITEM := -NUM( VAL );
      else	 ITEM :=  NUM( VAL );
      end if;

    end	GET;
	----


			---
    procedure		PUT		( TO   :out STRING;						-- LRM 14.3.7(17)
					  ITEM :in NUM;
					  BASE :in NUMBER_BASE	:= DEFAULT_BASE
					)
    is			---

      LBASE		: LONG_INTEGER		:= LONG_INTEGER( BASE );
      AVAL		: LONG_INTEGER;
      STR			: STRING( 1 .. 68 );
      POS			: POSITIVE		:= STR'LAST;
      IS_NEGATIVE		: BOOLEAN			:= ITEM < 0;
      DIGIT		: INTEGER;
      DLEN		: NATURAL;
      TLEN		: NATURAL;
      DST			: POSITIVE;

    begin

      if  IS_NEGATIVE  then
        AVAL := -LONG_INTEGER( ITEM );
      else
        AVAL :=  LONG_INTEGER( ITEM );
      end if;

      -- Meme extraction droite-a-gauche que PUT(FILE,...)
      loop
        DIGIT := INTEGER( AVAL mod LBASE );
        if  DIGIT < 10  then
	STR( POS ) := CHARACTER'VAL( CHARACTER'POS( '0' ) + DIGIT );
        else
	STR( POS ) := CHARACTER'VAL( CHARACTER'POS( 'A' ) + DIGIT - 10 );
        end if;
        AVAL := AVAL / LBASE;
        exit when  AVAL = 0;
        POS  := POS - 1;
      end loop;

      -- Calcul de la longueur totale formate (meme logique que PUT FILE)
      DLEN := STR'LAST - POS + 1;
      TLEN := DLEN;
      if  IS_NEGATIVE  then  TLEN := TLEN + 1;  end if;
      if  BASE /= 10  then
        if  BASE >= 10  then  TLEN := TLEN + 4;
        else		TLEN := TLEN + 3;
        end if;
      end if;

      -- LRM 14.3.7 : si TLEN > TO'LENGTH -> LAYOUT_ERROR (non implemente).
      -- Ecriture dans TO, justifie a droite avec espaces a gauche,
      -- comme PUT(FILE, WIDTH => TO'LENGTH).
       if  TLEN > TO'LENGTH  then
        raise LAYOUT_ERROR;								-- LRM 14.3.7(18)
      end if;
      DST := TO'FIRST;

      -- Espaces de remplissage
      if  TO'LENGTH > TLEN  then
        for  I in 1 .. TO'LENGTH - TLEN  loop
	TO( DST ) := ' ';
	DST := DST + 1;
        end loop;
      end if;

      -- Signe
      if  IS_NEGATIVE  then
        TO( DST ) := '-';
        DST := DST + 1;
      end if;

      -- Prefixe base
      if  BASE /= 10  then
        if  BASE >= 10  then
	TO( DST ) := '1';
	DST := DST + 1;
	TO( DST ) := CHARACTER'VAL( CHARACTER'POS( '0' ) + BASE - 10 );
	DST := DST + 1;
        else
	TO( DST ) := CHARACTER'VAL( CHARACTER'POS( '0' ) + BASE );
	DST := DST + 1;
        end if;
        TO( DST ) := '#';
        DST := DST + 1;
      end if;

      -- Digits
      for  I in POS .. STR'LAST  loop
        TO( DST ) := STR( I );
        DST := DST + 1;
      end loop;

      -- Suffixe base
      if  BASE /= 10  then
        TO( DST ) := '#';
      end if;

    end	PUT;
	----


  end	INTEGER_IO;
	----------


			-- Generic package for Input-Output of Real Types


				--------
  package body			FLOAT_IO
  is				--------

			---
    procedure		GET		( FILE  :in FILE_TYPE;
					  ITEM  :out NUM;
					  WIDTH :in FIELD		:= 0
					)
    is			---

      CH		: CHARACTER;
      VAL		: NUM		:= 0.0;
      FRAC	: NUM		:= 0.1;
      NEG		: BOOLEAN		:= FALSE;
      IN_FRAC	: BOOLEAN		:= FALSE;
      EXP_VAL	: INTEGER		:= 0;
      EXP_NEG	: BOOLEAN		:= FALSE;
      CHARS_READ	: NATURAL		:= 0;
      DONE	: BOOLEAN		:= FALSE;
      HAVE_DIGIT	: BOOLEAN		:= FALSE;

    begin
      if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
      if  FILE.MODE /= IN_FILE  then raise MODE_ERROR; end if;

      if  WIDTH = 0  then
        loop
	exit when  FILE.AT_END_OF_FILE;
	GET_RAW( FILE, CH );
	exit when  FILE.AT_END_OF_FILE;
	exit when  CH /= ' '  and then  CH /= ASCII.HT
			and then  CH /= ASCII.LF
			and then  CH /= ASCII.CR
			and then  CH /= ASCII.FF;
        end loop;
      else
        GET_RAW( FILE, CH );
        CHARS_READ := 0;
      end if;
      if  FILE.AT_END_OF_FILE  then raise END_ERROR; end if;				-- LRM 14.3.7(?) fin de fichier avant l'item

      -- Signe optionnel
      if  not FILE.AT_END_OF_FILE  and then  CH = '-'  then
        NEG := TRUE;
        if  WIDTH > 0  then
	CHARS_READ := CHARS_READ + 1;
	if  CHARS_READ >= WIDTH  then  DONE := TRUE;
	else  GET_RAW( FILE, CH );
	end if;
        else
	GET_RAW( FILE, CH );
        end if;
      elsif  not FILE.AT_END_OF_FILE  and then  CH = '+'  then
        if  WIDTH > 0  then
	CHARS_READ := CHARS_READ + 1;
	if  CHARS_READ >= WIDTH  then  DONE := TRUE;
	else  GET_RAW( FILE, CH );
	end if;
        else
	GET_RAW( FILE, CH );
        end if;
      end if;

      -- Mantisse et exposant
      loop
        exit when  DONE  or else  FILE.AT_END_OF_FILE;
        if  WIDTH > 0  and then  CHARS_READ >= WIDTH  then  exit;  end if;

        if  CH = '.'  then
	IN_FRAC := TRUE;
	if  WIDTH > 0  then
	  CHARS_READ := CHARS_READ + 1;
	  if  CHARS_READ >= WIDTH  then  DONE := TRUE;
	  else  GET_RAW( FILE, CH );
	  end if;
	else
	  GET_RAW( FILE, CH );
	end if;

        elsif  CH = 'E'  or else  CH = 'e'  then
	if  WIDTH > 0  then
	  CHARS_READ := CHARS_READ + 1;
	  if  CHARS_READ >= WIDTH  then  DONE := TRUE;
	  else  GET_RAW( FILE, CH );
	  end if;
	else
	  GET_RAW( FILE, CH );
	end if;
	if  not DONE  and then  not FILE.AT_END_OF_FILE  then
	  if  CH = '-'  then
	    EXP_NEG := TRUE;
	    if  WIDTH > 0  then
	      CHARS_READ := CHARS_READ + 1;
	      if  CHARS_READ >= WIDTH  then  DONE := TRUE;
	      else  GET_RAW( FILE, CH );
	      end if;
	    else
	      GET_RAW( FILE, CH );
	    end if;
	  elsif  CH = '+'  then
	    if  WIDTH > 0  then
	      CHARS_READ := CHARS_READ + 1;
	      if  CHARS_READ >= WIDTH  then  DONE := TRUE;
	      else  GET_RAW( FILE, CH );
	      end if;
	    else
	      GET_RAW( FILE, CH );
	    end if;
	  end if;
	end if;
	-- Chiffres de l'exposant
	loop
	  exit when  DONE  or else  FILE.AT_END_OF_FILE;
	  exit when  CH < '0'  or else  CH > '9';
	  EXP_VAL := 10 * EXP_VAL
		       + CHARACTER'POS( CH ) - CHARACTER'POS( '0' );
	  if  WIDTH > 0  then
	    CHARS_READ := CHARS_READ + 1;
	    if  CHARS_READ >= WIDTH  then  DONE := TRUE;
	    else  GET_RAW( FILE, CH );
	    end if;
	  else
	    GET_RAW( FILE, CH );
	  end if;
	end loop;
	if  WIDTH = 0  and then  not FILE.AT_END_OF_FILE
		     and then  ( CH < '0'  or else  CH > '9' )  then
	  FILE.LOOK_AHEAD	  := CH;
	  FILE.HAS_LOOK_AHEAD := TRUE;
	end if;
	DONE := TRUE;

        elsif  CH >= '0'  and then  CH <= '9'  then
	if  IN_FRAC  then
	  VAL  := VAL + FRAC
		    * NUM( CHARACTER'POS( CH ) - CHARACTER'POS( '0' ) );
	  FRAC := FRAC / 10.0;
	else
	  VAL  := 10.0 * VAL
		    + NUM( CHARACTER'POS( CH ) - CHARACTER'POS( '0' ) );
	end if;
	HAVE_DIGIT := TRUE;
	if  WIDTH > 0  then
	  CHARS_READ := CHARS_READ + 1;
	  if  CHARS_READ >= WIDTH  then  DONE := TRUE;
	  else  GET_RAW( FILE, CH );
	  end if;
	else
	  GET_RAW( FILE, CH );
	end if;

        else
	if  WIDTH = 0  then
	  FILE.LOOK_AHEAD	  := CH;
	  FILE.HAS_LOOK_AHEAD := TRUE;
	end if;
	DONE := TRUE;
        end if;
      end loop;

      if  not HAVE_DIGIT  then raise DATA_ERROR; end if;					-- LRM 14.3.8 image invalide

      if  EXP_NEG  then
        for  J in 1 .. EXP_VAL  loop  VAL := VAL / 10.0;  end loop;
      else
        for  J in 1 .. EXP_VAL  loop  VAL := VAL * 10.0;  end loop;
      end if;

      if  NEG  then  ITEM := -VAL;
      else	 ITEM :=  VAL;
      end if;

    end	GET;
	----


			---
    procedure		GET		( ITEM  :out NUM; WIDTH :in FIELD := 0)
    is			---
    begin
      GET( DEFAULT_INPUT, ITEM, WIDTH );

    end	GET;
	----


			---
    procedure		PUT		( FILE :in FILE_TYPE;
					  ITEM :in NUM;
					  FORE :in FIELD		:= DEFAULT_FORE;
					  AFT  :in FIELD		:= DEFAULT_AFT;
					  EXP  :in FIELD		:= DEFAULT_EXP
					)
    is			---

      VAL		: NUM		:= ITEM;
      IS_NEGATIVE	: BOOLEAN		:= ITEM < 0.0;
      E		: INTEGER		:= 0;
      DIGIT	: INTEGER;
      FORE_LEN	: NATURAL;

    begin
      -- Traiter le signe
      if  IS_NEGATIVE  then
        VAL := -ITEM;
      end if;

      -- Calculer l'exposant : normaliser 1.0 <= VAL < 10.0
      if  VAL /= 0.0  then
        while  VAL >= 10.0  loop
	VAL := VAL / 10.0;
	E := E + 1;
        end loop;

        while  VAL < 1.0  loop
	VAL := VAL * 10.0;
	E := E - 1;
        end loop;
      end if;

      -- Arrondir la mantisse au nombre de chiffres demandes.
      -- L'extraction ulterieure des chiffres est volontairement tronquee : floor(VAL), VAL >= 0.0,
      -- car la conversion Ada INTEGER(VAL) arrondit au plus proche (LRM 4.6(7)).
      declare
        ROUNDING	: NUM	:= 0.5;
      begin
        for  I in  1 .. AFT  loop
	ROUNDING := ROUNDING / 10.0;
        end loop;

        VAL := VAL + ROUNDING;
      end;

      -- Propager une retenue issue de l'arrondi :
      -- 9.9999996E+n devient 1.000000E+(n+1).
      if  VAL >= 10.0  then
        VAL := VAL / 10.0;
        E := E + 1;
      end if;

      -- Padding FORE : le champ FORE inclut le signe et le chiffre avant le point
      -- Format : [-]d.dddE[+|-]dd
      -- Nombre de caracteres avant le point : 1 chiffre (+ signe eventuel)
      FORE_LEN := 1;
      if  IS_NEGATIVE  then
        FORE_LEN := 2;
      end if;
      if  FORE > FORE_LEN  then
        for  I in 1 .. FORE - FORE_LEN  loop
	PUT( FILE, ' ' );
        end loop;
      end if;

      -- Signe
      if  IS_NEGATIVE  then
        PUT( FILE, '-' );
      end if;

      -- Chiffre avant le point decimal
      DIGIT := INTEGER( VAL );
      if  NUM( DIGIT ) > VAL  then DIGIT := DIGIT - 1; end if;			-- floor
      if  DIGIT > 9  then DIGIT := 9; end if;				-- securite arrondi
      if  DIGIT < 0  then DIGIT := 0; end if;
      PUT( FILE, CHARACTER'VAL( CHARACTER'POS( '0' ) + DIGIT ) );
      VAL := ( VAL - NUM( DIGIT ) ) * 10.0;

      -- Point decimal
      PUT( FILE, '.' );

      -- Chiffres apres le point
      for  I in 1 .. AFT  loop
        DIGIT := INTEGER( VAL );
        if  NUM( DIGIT ) > VAL  then DIGIT := DIGIT - 1; end if;		-- floor
        if  DIGIT > 9  then DIGIT := 9; end if;
        if  DIGIT < 0  then DIGIT := 0; end if;
        PUT( FILE, CHARACTER'VAL( CHARACTER'POS( '0' ) + DIGIT ) );
        VAL := ( VAL - NUM( DIGIT ) ) * 10.0;
      end loop;

      -- Partie exposant
      if  EXP > 0  then
        PUT( FILE, 'E' );
        if  E < 0  then
	PUT( FILE, '-' );
	E := -E;
        else
	PUT( FILE, '+' );
        end if;
        -- Ecrire l'exposant avec EXP chiffres (padding zero a gauche)
        declare
	EXP_STR	: STRING( 1 .. EXP );
	POS	: NATURAL := EXP;
	EVAL	: INTEGER := E;
        begin
	for  I in reverse 1 .. EXP  loop
	  EXP_STR( I ) := CHARACTER'VAL( CHARACTER'POS( '0' ) + EVAL mod 10 );
	  EVAL := EVAL / 10;
	end loop;
	PUT( FILE, EXP_STR );
        end;
      end if;

    end	PUT;
    ----


			---
    procedure		PUT		( ITEM :in NUM;
					  FORE :in FIELD		:= DEFAULT_FORE;
					  AFT  :in FIELD		:= DEFAULT_AFT;
					  EXP  :in FIELD		:= DEFAULT_EXP
					)
    is			---
    begin
      PUT( DEFAULT_OUTPUT, ITEM, FORE, AFT, EXP );

    end	PUT;
	----


			---
    procedure		GET		( FROM :in STRING; ITEM :out NUM; LAST :out POSITIVE )
    is			---
      ------------------------------------------------------------------
      -- Conversion decimale correctement arrondie.
      --
      -- Aucun calcul flottant n'est effectue avant que la significande
      -- IEEE definitive ait ete determinee.
      --
      -- Le nombre decimal est represente exactement par :
      --
      --              A
      --             ---
      --              B
      --
      -- puis on calcule la significande binaire par division entiere
      -- multiprecision, avec arrondi au plus proche, ties-to-even.
      --
      -- Syntaxe acceptee (LRM 2.4, 14.3.8) : litteral decimal ou base
      -- (BASE#CHIFFRES[.CHIFFRES]#[EXPOSANT], BASE de 2 a 16, '#' ou
      -- son remplacant ':' -- LRM 2.10), chiffres etendus A..F ou
      -- a..f, soulignes isoles entre deux chiffres, E ou e. Dans un
      -- litteral base, l'exposant est une puissance de la BASE.
      -- Le traitement exact ci-dessous est ecrit pour une base RADIX
      -- quelconque : 10 pour un litteral decimal.
      ------------------------------------------------------------------

      BASE : constant INTEGER := 32768;       -- 2**15

      -- STATIQUE (nombre nomme) : le composant D du record BIG est
      -- ainsi contraint statiquement -- offsets record statiques.
      --
      -- Dimensionnement, au pire cas passant les gardes DEC_TOP
      -- (R = RADIX, L = LOG2_R = partie entiere de log2 R) :
      --   SIG <= R**SIG_DIGITS_MAX                     <= 3200 bits
      --   A   <= max( SIG, R**(1 + 1024/L) )           <= 3200 bits
      --   B   <= R**(SIG_DIGITS_MAX + 1075/L)          <= 4530 bits
      --   decalages 2**K de la localisation de E       <= 4600 bits
      -- soit au plus ~310 limbs de 15 bits ; 600 laisse une marge.
      MAX_LIMBS : constant := 600;

      -- Nombre maximal de chiffres significatifs absorbes dans SIG.
      -- 768 chiffres suffisent pour arrondir correctement binary64
      -- (borne de Gay) ; les chiffres excedentaires ne comptent que
      -- via DROPPED et STICKY ci-dessous. 800 donne une marge.
      SIG_DIGITS_MAX : constant := 800;

      subtype LIMB is INTEGER range 0 .. BASE - 1;

      type LIMB_VECTOR is array ( POSITIVE range <> ) of LIMB;

      type BIG is
        record
          N : NATURAL;
          D : LIMB_VECTOR( 1 .. MAX_LIMBS );
        end record;

      ------------------------------------------------------------------
      -- Caracteristiques du format NUM.
      --
      -- Pour IEEE binary64 :
      --
      --   P              = 53
      --   MACHINE_EMIN   = -1021
      --   MACHINE_EMAX   =  1024
      --
      -- donc :
      --
      --   MIN_NORMAL_E   = -1022
      --   MAX_NORMAL_E   =  1023
      --   MIN_SUB_E      = -1074
      ------------------------------------------------------------------

      P             : constant INTEGER := NUM'MACHINE_MANTISSA;
      MIN_NORMAL_E  : constant INTEGER := NUM'MACHINE_EMIN - 1;
      MAX_NORMAL_E  : constant INTEGER := NUM'MACHINE_EMAX - 1;
      MIN_SUB_E     : constant INTEGER := NUM'MACHINE_EMIN - P;

      BIG_OVERFLOW : exception;

      ------------------------------------------------------------------
      -- Analyse de la chaine
      ------------------------------------------------------------------

      POS             : INTEGER := FROM'FIRST;
      CH              : CHARACTER;

      NEG             : BOOLEAN := FALSE;
      POINT_SEEN      : BOOLEAN := FALSE;
      HAVE_DIGIT      : BOOLEAN := FALSE;
      NONZERO_SEEN    : BOOLEAN := FALSE;

      FRAC_COUNT      : INTEGER := 0;
      SIG_COUNT       : INTEGER := 0;

      -- Chiffres significatifs au-dela de SIG_DIGITS_MAX, non absorbes
      -- dans SIG :
      -- DROPPED : ceux situes avant le point (facteur 10 chacun) ;
      -- STICKY  : vrai si l'un au moins etait non nul -- la valeur
      --           exacte est alors STRICTEMENT superieure a la valeur
      --           tronquee representee par SIG.
      DROPPED         : INTEGER := 0;
      STICKY          : BOOLEAN := FALSE;

      EXP_NEG         : BOOLEAN := FALSE;
      EXP_ABS         : INTEGER := 0;
      EXP_DIGIT       : BOOLEAN := FALSE;
      EXP_HUGE        : BOOLEAN := FALSE;

      -- Si l'exposant depasse largement la longueur de la chaine,
      -- aucun nombre de chiffres de la mantisse ne peut le compenser.
      EXP_LIMIT       : constant INTEGER := FROM'LENGTH + 4096;

      DIG             : INTEGER;

      -- Base du litteral : 10, ou BASE d'un litteral base. LOG2_R est
      -- la partie entiere de log2 RADIX (gardes DEC_TOP).
      RADIX           : INTEGER := 10;
      LOG2_R          : INTEGER := 3;
      BASED           : BOOLEAN := FALSE;
      DELIM           : CHARACTER := '#';
      SCAN            : INTEGER;
      BASE_VAL        : INTEGER := 0;

      SIG             : BIG := ( N => 0, D => ( others => 0 ) );
      A               : BIG := ( N => 0, D => ( others => 0 ) );
      B               : BIG := ( N => 0, D => ( others => 0 ) );

      DEC_EXP         : INTEGER;
      DEC_TOP         : INTEGER;

      E               : INTEGER;
      K               : INTEGER;

      Q               : LONG_INTEGER;

      TWO_P           : LONG_INTEGER;

      V               : NUM;

      ------------------------------------------------------------------
      -- Valeur d'un chiffre etendu (LRM 2.4.2) ; 16 si C n'en est pas
      -- un. Un chiffre est valide dans la base RADIX si sa valeur est
      -- inferieure a RADIX.
      ------------------------------------------------------------------

      function DIGIT_VALUE ( C : CHARACTER ) return INTEGER
      is
      begin
        if C >= '0' and then C <= '9' then
          return CHARACTER'POS(C) - CHARACTER'POS('0');
        elsif C >= 'A' and then C <= 'F' then
          return CHARACTER'POS(C) - CHARACTER'POS('A') + 10;
        elsif C >= 'a' and then C <= 'f' then
          return CHARACTER'POS(C) - CHARACTER'POS('a') + 10;
        else
          return 16;
        end if;
      end DIGIT_VALUE;


      ------------------------------------------------------------------
      -- Outils BIG
      ------------------------------------------------------------------

      procedure NORMALIZE ( X : in out BIG )
      is
      begin
        while X.N > 0 loop
          exit when X.D( X.N ) /= 0;
          X.N := X.N - 1;
        end loop;
      end NORMALIZE;


      procedure SET_ZERO ( X : out BIG )
      is
      begin
        X.N := 0;
        for I in X.D'RANGE loop
          X.D( I ) := 0;
        end loop;
      end SET_ZERO;


      procedure SET_ONE ( X : out BIG )
      is
      begin
        SET_ZERO( X );
        X.N    := 1;
        X.D(1) := 1;
      end SET_ONE;


      procedure MUL_SMALL
        ( X : in out BIG;
          M : in     INTEGER )
      is
        CARRY : INTEGER := 0;
        T     : INTEGER;
      begin
        if X.N = 0 then
          return;
        end if;

        for I in 1 .. X.N loop
          T := X.D(I) * M + CARRY;

          X.D(I) := T mod BASE;
          CARRY  := T / BASE;
        end loop;

        while CARRY /= 0 loop
          if X.N = MAX_LIMBS then
            raise BIG_OVERFLOW;
          end if;

          X.N := X.N + 1;

          X.D( X.N ) := CARRY mod BASE;
          CARRY      := CARRY / BASE;
        end loop;
      end MUL_SMALL;


      procedure ADD_SMALL
        ( X : in out BIG;
          A : in     INTEGER )
      is
        CARRY : INTEGER := A;
        I     : INTEGER := 1;
        T     : INTEGER;
      begin
        if CARRY = 0 then
          return;
        end if;

        if X.N = 0 then
          X.N    := 1;
          X.D(1) := 0;
        end if;

        while CARRY /= 0 loop

          if I > X.N then
            if X.N = MAX_LIMBS then
              raise BIG_OVERFLOW;
            end if;

            X.N := X.N + 1;
            X.D( X.N ) := 0;
          end if;

          T := X.D(I) + CARRY;

          X.D(I) := T mod BASE;
          CARRY  := T / BASE;

          I := I + 1;
        end loop;
      end ADD_SMALL;


      procedure MUL_2 ( X : in out BIG )
      is
      begin
        MUL_SMALL( X, 2 );
      end MUL_2;


      procedure DIV_2 ( X : in out BIG )
      is
        CARRY : INTEGER := 0;
        T     : INTEGER;
      begin
        if X.N = 0 then
          return;
        end if;

        for I in reverse 1 .. X.N loop
          T := CARRY * BASE + X.D(I);

          X.D(I) := T / 2;
          CARRY  := T mod 2;
        end loop;

        NORMALIZE( X );
      end DIV_2;


      procedure SHIFT_LEFT
        ( X : in out BIG;
          N : in     NATURAL )
      is
      begin
        for I in 1 .. N loop
          MUL_2( X );
        end loop;
      end SHIFT_LEFT;


      function COMPARE
        ( A : BIG;
          B : BIG ) return INTEGER
      is
      begin
        if A.N < B.N then
          return -1;
        elsif A.N > B.N then
          return 1;
        end if;

        for I in reverse 1 .. A.N loop
          if A.D(I) < B.D(I) then
            return -1;
          elsif A.D(I) > B.D(I) then
            return 1;
          end if;
        end loop;

        return 0;
      end COMPARE;


      procedure SUBTRACT
        ( A : in out BIG;
          B : in     BIG )
      is
        T      : INTEGER;
        BORROW : INTEGER := 0;
      begin
        -- Precondition : A >= B

        for I in 1 .. A.N loop

          T := A.D(I) - BORROW;

          if I <= B.N then
            T := T - B.D(I);
          end if;

          if T < 0 then
            T      := T + BASE;
            BORROW := 1;
          else
            BORROW := 0;
          end if;

          A.D(I) := T;
        end loop;

        NORMALIZE( A );
      end SUBTRACT;


      function BIT_LENGTH ( X : BIG ) return INTEGER
      is
        V : INTEGER;
        B : INTEGER := 0;
      begin
        if X.N = 0 then
          return 0;
        end if;

        V := X.D( X.N );

        while V /= 0 loop
          V := V / 2;
          B := B + 1;
        end loop;

        return 15 * ( X.N - 1 ) + B;
      end BIT_LENGTH;


      ------------------------------------------------------------------
      -- Division entiere multiprecision.
      --
      -- Q est volontairement LONG_INTEGER : dans notre utilisation
      -- le quotient contient au maximum P+1 bits, donc 54 bits en
      -- binary64.
      ------------------------------------------------------------------

      procedure DIV_MOD
        ( NUMERATOR   : in  BIG;
          DENOMINATOR : in  BIG;
          Q           : out LONG_INTEGER;
          R           : out BIG )
      is
        T		: BIG := ( N => 0, D => ( others => 0 ) );
        SHIFT	: INTEGER;
        Q_I	: LONG_INTEGER	:= 0;

      begin
        R := NUMERATOR;
        Q := 0;

        SHIFT := BIT_LENGTH( NUMERATOR ) - BIT_LENGTH( DENOMINATOR );

        if SHIFT < 0 then
          return;
        end if;

        -- Dans l'utilisation normale le quotient ne peut depasser
        -- quelques dizaines de bits.
        if SHIFT > 61 then
          raise BIG_OVERFLOW;
        end if;

        T := DENOMINATOR;
        SHIFT_LEFT( T, SHIFT );

        for  I in reverse 0 .. SHIFT  loop
          Q_I := Q_I * 2;

          if COMPARE( R, T ) >= 0 then
            SUBTRACT( R, T );
            Q_I := Q_I + 1;
          end if;

          if I /= 0 then
            DIV_2( T );
          end if;

        end loop;
        Q := Q_I;

      end	DIV_MOD;
	-------

      ------------------------------------------------------------------
      -- Compare A/B a 2**E.
      ------------------------------------------------------------------

      function COMPARE_TO_POWER_OF_TWO
        ( A : BIG;
          B : BIG;
          E : INTEGER ) return INTEGER
      is
        X : BIG := ( N => 0, D => ( others => 0 ) );
        Y : BIG := ( N => 0, D => ( others => 0 ) );
      begin
        X := A;
        Y := B;

        if E >= 0 then
          SHIFT_LEFT( Y, E );
        else
          SHIFT_LEFT( X, -E );
        end if;

        return COMPARE( X, Y );
      end COMPARE_TO_POWER_OF_TWO;


      ------------------------------------------------------------------
      -- Retourne :
      --
      --       round_even( (A/B) * 2**K )
      --
      -- La comparaison de 2*reste avec le denominateur effectue
      -- exactement le round-to-nearest, ties-to-even.
      --
      -- Troncature a SIG_DIGITS_MAX chiffres : si STICKY, la valeur
      -- exacte est strictement au-dessus de la valeur tronquee, d'un
      -- ecart inferieur a une unite du dernier chiffre retenu ; comme
      -- SIG_DIGITS_MAX >= 768 (borne de Gay pour binary64), cet ecart
      -- ne peut pas faire franchir un demi-ulp binaire : seule
      -- l'egalite exacte C = 0 doit etre corrigee.
      -- Pour une base puissance de 2, un point milieu s'ecrit en au
      -- plus 55 chiffres : meme conclusion. Pour les autres bases
      -- (3, 5 .. 7, 9, 11 .. 15), seul un litteral de plus de
      -- SIG_DIGITS_MAX chiffres significatifs pourrait etre mal arrondi.
      ------------------------------------------------------------------

      function ROUNDED_QUOTIENT
        ( A : BIG;
          B : BIG;
          K : INTEGER ) return LONG_INTEGER
      is
        N      : BIG := ( N => 0, D => ( others => 0 ) );
        D      : BIG := ( N => 0, D => ( others => 0 ) );
        R      : BIG := ( N => 0, D => ( others => 0 ) );
        TWICE  : BIG := ( N => 0, D => ( others => 0 ) );

        Q      : LONG_INTEGER;
        C      : INTEGER;
      begin
        N := A;
        D := B;

        if K >= 0 then
          SHIFT_LEFT( N, K );
        else
          SHIFT_LEFT( D, -K );
        end if;

        DIV_MOD( N, D, Q, R );

        TWICE := R;
        MUL_2( TWICE );

        C := COMPARE( TWICE, D );

        if C > 0 then

          Q := Q + 1;

        elsif C = 0 then

          if STICKY then

            -- La valeur tronquee tombe a mi-chemin mais la valeur
            -- exacte lui est strictement superieure : arrondi vers
            -- le haut.

            Q := Q + 1;

          elsif Q mod 2 /= 0 then

            -- Exactement a mi-chemin :
            -- on choisit la significande paire.

            Q := Q + 1;

          end if;

        end if;

        return Q;
      end ROUNDED_QUOTIENT;


      function POW2_LONG
        ( N : NATURAL ) return LONG_INTEGER
      is
        R : LONG_INTEGER := 1;
      begin
        for I in 1 .. N loop
          R := R * 2;
        end loop;

        return R;
      end POW2_LONG;


      ------------------------------------------------------------------
      -- Construction finale du flottant.
      --
      -- Q <= 2**53 : la conversion LONG_INTEGER -> binary64 est exacte.
      --
      -- Les multiplications/divisions par 2 sont elles aussi exactes
      -- en arithmetique binaire IEEE tant que les subnormaux sont
      -- conserves.
      ------------------------------------------------------------------

      function MAKE_FLOAT
        ( Q     : LONG_INTEGER;
          SHIFT : INTEGER ) return NUM
      is
        V : NUM;
      begin
        if Q = 0 then
          return 0.0;
        end if;

        V := NUM( Q );

        if SHIFT > 0 then

          for I in 1 .. SHIFT loop
            V := V * 2.0;
          end loop;

        elsif SHIFT < 0 then

          for I in 1 .. -SHIFT loop
            V := V / 2.0;
          end loop;

        end if;

        return V;
      end MAKE_FLOAT;

    begin

      ----------------------------------------------------------------
      -- Cette implementation vise les formats binaires IEEE.
      ----------------------------------------------------------------

      if NUM'MACHINE_RADIX /= 2 then
        raise PROGRAM_ERROR;
      end if;

      -- Q et 2**P doivent tenir dans LONG_INTEGER.
      if P > 62 then
        raise PROGRAM_ERROR;
      end if;

      TWO_P := POW2_LONG( P );

      SET_ZERO( SIG );


      ----------------------------------------------------------------
      -- Blancs initiaux
      ----------------------------------------------------------------

      while POS <= FROM'LAST
        and then
          ( FROM(POS) = ' '
            or else FROM(POS) = ASCII.HT )
      loop
        POS := POS + 1;
      end loop;


      ----------------------------------------------------------------
      -- Signe
      ----------------------------------------------------------------

      if POS <= FROM'LAST then

        if FROM(POS) = '-' then
          NEG := TRUE;
          POS := POS + 1;

        elsif FROM(POS) = '+' then
          POS := POS + 1;
        end if;

      end if;


      ----------------------------------------------------------------
      -- Base eventuelle : numeral decimal (soulignes admis) suivi de
      -- '#' ou de ':'. BASE_VAL cesse de croitre au-dela de 16.
      ----------------------------------------------------------------

      SCAN := POS;

      while SCAN <= FROM'LAST loop

        CH := FROM(SCAN);

        if CH >= '0' and then CH <= '9' then

          if BASE_VAL <= 16 then
            BASE_VAL := BASE_VAL * 10 + DIGIT_VALUE( CH );
          end if;

          SCAN := SCAN + 1;

        elsif CH = '_'
          and then SCAN > POS
          and then SCAN < FROM'LAST
          and then DIGIT_VALUE( FROM(SCAN + 1) ) < 10
        then

          SCAN := SCAN + 1;

        else

          exit;

        end if;

      end loop;


      if SCAN > POS
        and then SCAN <= FROM'LAST
        and then ( FROM(SCAN) = '#' or else FROM(SCAN) = ':' )
      then

        if BASE_VAL >= 2 and then BASE_VAL <= 16 then

          BASED  := TRUE;
          RADIX  := BASE_VAL;
          DELIM  := FROM(SCAN);
          POS    := SCAN + 1;

          LOG2_R := 0;
          DIG    := RADIX;

          while DIG >= 2 loop
            LOG2_R := LOG2_R + 1;
            DIG    := DIG / 2;
          end loop;

        elsif FROM(SCAN) = '#' then

          -- Litteral base de base illegale.

          raise DATA_ERROR;

        end if;

      end if;


      ----------------------------------------------------------------
      -- Mantisse
      ----------------------------------------------------------------

      while POS <= FROM'LAST loop

        CH  := FROM(POS);
        DIG := DIGIT_VALUE( CH );

        if DIG < RADIX then

          if SIG_COUNT < SIG_DIGITS_MAX then

            MUL_SMALL( SIG, RADIX );
            ADD_SMALL( SIG, DIG );

            if NONZERO_SEEN then
              SIG_COUNT := SIG_COUNT + 1;

            elsif DIG /= 0 then
              NONZERO_SEEN := TRUE;
              SIG_COUNT    := 1;
            end if;

            if POINT_SEEN then
              FRAC_COUNT := FRAC_COUNT + 1;
            end if;

          else

            -- Chiffre au-dela de la capacite : il ne modifie ni SIG
            -- ni FRAC_COUNT. Avant le point il vaut un facteur RADIX ;
            -- partout il alimente le bit sticky.

            if not POINT_SEEN then
              DROPPED := DROPPED + 1;
            end if;

            if DIG /= 0 then
              STICKY := TRUE;
            end if;

          end if;

          HAVE_DIGIT := TRUE;

          LAST := POS;
          POS  := POS + 1;

        elsif CH = '_'
          and then POS > FROM'FIRST
          and then DIGIT_VALUE( FROM(POS - 1) ) < RADIX
          and then POS < FROM'LAST
          and then DIGIT_VALUE( FROM(POS + 1) ) < RADIX
        then

          -- Souligne isole entre deux chiffres : sans valeur.

          POS := POS + 1;

        elsif CH = '.' and then not POINT_SEEN then

          POINT_SEEN := TRUE;

          LAST := POS;
          POS  := POS + 1;

        else

          -- Fin de mantisse ('E', delimiteur de base, autre).

          exit;

        end if;

      end loop;


      if not HAVE_DIGIT then
        raise DATA_ERROR;
      end if;


      ----------------------------------------------------------------
      -- Delimiteur fermant d'un litteral base : le meme qu'a
      -- l'ouverture.
      ----------------------------------------------------------------

      if BASED then

        if POS > FROM'LAST or else FROM(POS) /= DELIM then
          raise DATA_ERROR;
        end if;

        LAST := POS;
        POS  := POS + 1;

      end if;


      ----------------------------------------------------------------
      -- Exposant decimal explicite
      ----------------------------------------------------------------

      if POS <= FROM'LAST
        and then
          ( FROM(POS) = 'E' or else FROM(POS) = 'e' )
      then

        LAST := POS;
        POS  := POS + 1;

        if POS <= FROM'LAST then

          if FROM(POS) = '-' then
            EXP_NEG := TRUE;
            LAST    := POS;
            POS     := POS + 1;

          elsif FROM(POS) = '+' then
            LAST := POS;
            POS  := POS + 1;
          end if;

        end if;


        while POS <= FROM'LAST loop

          CH := FROM(POS);

          -- Souligne isole entre deux chiffres de l'exposant.

          if CH = '_'
            and then EXP_DIGIT
            and then POS < FROM'LAST
            and then DIGIT_VALUE( FROM(POS + 1) ) < 10
          then
            POS := POS + 1;
            CH  := FROM(POS);
          end if;

          exit when CH < '0' or else CH > '9';

          EXP_DIGIT := TRUE;
          DIG := CHARACTER'POS(CH) - CHARACTER'POS('0');

          if not EXP_HUGE then

            if EXP_ABS > EXP_LIMIT / 10 then
              EXP_HUGE := TRUE;

            elsif EXP_ABS * 10 > EXP_LIMIT - DIG then
              EXP_HUGE := TRUE;

            else
              EXP_ABS := EXP_ABS * 10 + DIG;
            end if;

          end if;

          LAST := POS;
          POS  := POS + 1;

        end loop;


        if not EXP_DIGIT then
          raise DATA_ERROR;
        end if;

      end if;


      ----------------------------------------------------------------
      -- Zero est exact quelle que soit la valeur de l'exposant.
      ----------------------------------------------------------------

      if SIG.N = 0 then

        if NEG then
          ITEM := -0.0;
        else
          ITEM := 0.0;
        end if;

        return;
      end if;


      ----------------------------------------------------------------
      -- Exposant manifestement gigantesque.
      ----------------------------------------------------------------

      if EXP_HUGE then

        if EXP_NEG then

          if NEG then
            ITEM := -0.0;
          else
            ITEM := 0.0;
          end if;

          return;

        else
          raise DATA_ERROR;
        end if;

      end if;


      ----------------------------------------------------------------
      -- Valeur exacte (DEC_EXP est un exposant de la base RADIX) :
      --
      --   SIG * RADIX**DEC_EXP
      ----------------------------------------------------------------

      if EXP_NEG then
        DEC_EXP := -EXP_ABS - FRAC_COUNT + DROPPED;
      else
        DEC_EXP :=  EXP_ABS - FRAC_COUNT + DROPPED;
      end if;


      ----------------------------------------------------------------
      -- Ordre de grandeur dans la base RADIX :
      --
      --   RADIX**DEC_TOP <= |x| < RADIX**(DEC_TOP+1)
      --
      -- et 2**LOG2_R <= RADIX, d'ou, pour les puissances de 2 :
      --   DEC_TOP >= 0     : |x| >= 2**(LOG2_R*DEC_TOP)
      --   DEC_TOP + 1 <= 0 : |x| <  2**(LOG2_R*(DEC_TOP+1))
      --
      -- Ces tests sont volontairement conservateurs. Ils evitent
      -- seulement de construire des BIG absurdes.
      ----------------------------------------------------------------

      DEC_TOP := SIG_COUNT + DEC_EXP - 1;

      if LOG2_R * DEC_TOP > MAX_NORMAL_E + 1 then
        raise DATA_ERROR;
      end if;

      -- |x| < 2**(MIN_SUB_E-1) : moins d'un demi plus petit subnormal.

      if LOG2_R * ( DEC_TOP + 1 ) < MIN_SUB_E then

        if NEG then
          ITEM := -0.0;
        else
          ITEM := 0.0;
        end if;

        return;
      end if;


      ----------------------------------------------------------------
      -- Construction du rationnel exact A/B.
      ----------------------------------------------------------------

      A := SIG;
      SET_ONE( B );

      if DEC_EXP > 0 then

        for I in 1 .. DEC_EXP loop
          MUL_SMALL( A, RADIX );
        end loop;

      elsif DEC_EXP < 0 then

        for I in 1 .. -DEC_EXP loop
          MUL_SMALL( B, RADIX );
        end loop;

      end if;


      ----------------------------------------------------------------
      -- Calcul exact de :
      --
      --             E = floor( log2( A/B ) )
      --
      -- BIT_LENGTH(A)-BIT_LENGTH(B) donne E ou E+1.
      ----------------------------------------------------------------

      E := BIT_LENGTH(A) - BIT_LENGTH(B);

      if COMPARE_TO_POWER_OF_TWO( A, B, E ) < 0 then
        E := E - 1;
      end if;


      ----------------------------------------------------------------
      -- Hors plage haute.
      ----------------------------------------------------------------

      if E > MAX_NORMAL_E then
        raise DATA_ERROR;
      end if;


      ----------------------------------------------------------------
      -- Trop petit meme pour etre arrondi au plus petit subnormal.
      --
      -- Si E < MIN_SUB_E-1 :
      --
      --       |x| < 1/2 * 2**MIN_SUB_E
      --
      -- donc arrondi vers zero.
      ----------------------------------------------------------------

      if E < MIN_SUB_E - 1 then

        if NEG then
          ITEM := -0.0;
        else
          ITEM := 0.0;
        end if;

        return;
      end if;


      ----------------------------------------------------------------
      -- Nombre normal
      ----------------------------------------------------------------

      if E >= MIN_NORMAL_E then

        -- On veut P bits :
        --
        -- Q = round_even
        --       ( (A/B) * 2**(P-1-E) )
        --
        -- avec :
        --
        --       2**(P-1) <= Q < 2**P

        K := P - 1 - E;

        Q := ROUNDED_QUOTIENT( A, B, K );


        -- L'arrondi peut produire exactement 2**P.
        -- On renormalise alors.

        if Q = TWO_P then
          Q := Q / 2;
          E := E + 1;

          if E > MAX_NORMAL_E then
            raise DATA_ERROR;
          end if;
        end if;


        -- Valeur exacte :
        --
        --       Q * 2**(E-(P-1))

        V := MAKE_FLOAT( Q, E - (P - 1) );


      ----------------------------------------------------------------
      -- Nombre subnormal
      ----------------------------------------------------------------

      else

        -- Un subnormal est un multiple entier de :
        --
        --       2**MIN_SUB_E
        --
        -- Pour binary64 :
        --
        --       MIN_SUB_E = -1074
        --
        -- donc :
        --
        -- Q = round_even( (A/B) * 2**1074 )

        Q := ROUNDED_QUOTIENT( A, B, -MIN_SUB_E );

        V := MAKE_FLOAT( Q, MIN_SUB_E );

      end if;


      ----------------------------------------------------------------
      -- Signe final
      ----------------------------------------------------------------

      if NEG then
        ITEM := -V;
      else
        ITEM := V;
      end if;


    exception

      when BIG_OVERFLOW =>
        -- Garde-fou : le dimensionnement statique de MAX_LIMBS couvre
        -- tous les cas passant les gardes DEC_TOP ; ne devrait jamais
        -- arriver.
        raise DATA_ERROR;

    end	GET;
	---


			---
    procedure		PUT		( TO   :out STRING;
					  ITEM :in NUM;
					  AFT  :in FIELD		:= DEFAULT_AFT;
					  EXP  :in INTEGER		:= DEFAULT_EXP
					)
    is			---

      IMAGE		: STRING( 1 .. 80 );
      LEN			: NATURAL		:= 0;
      POS			: INTEGER;
      PAD			: INTEGER;

      VAL			: LONG_FLOAT	:= LONG_FLOAT( ITEM );
      ROUNDING		: LONG_FLOAT	:= 0.5;
      FRC_PART		: LONG_FLOAT	:= 0.0;

      IS_NEGATIVE		: BOOLEAN		:= FALSE;
      BAD_LAYOUT		: BOOLEAN		:= FALSE;

      DIGIT		: INTEGER;
      IPART		: LONG_INTEGER;
      IPART_WORK		: LONG_INTEGER;
      IBUF		: STRING( 1 .. 40 );
      NB			: NATURAL		:= 0;

      E			: INTEGER		:= 0;

			---------
      function		FLOOR_POS		( X : LONG_FLOAT )		return LONG_INTEGER
      is			---------
        R : LONG_INTEGER := LONG_INTEGER( X );
      begin
        -- La conversion Ada LONG_INTEGER(X) arrondit.
        -- Pour le formatage, on veut floor(X), avec X >= 0.0.
        if  LONG_FLOAT( R ) > X  then
	R := R - 1;
        end if;

        return R;

      end FLOOR_POS;
	---------


			----
      procedure		EMIT		( CH :in CHARACTER )
      is			----
      begin
        if  LEN < IMAGE'LAST  then
	LEN := LEN + 1;
	IMAGE( LEN ) := CH;
        else
	BAD_LAYOUT := TRUE;
        end if;

      end EMIT;
	----


			-------------
      procedure		EMIT_FRACTION	( FRACTION :in LONG_FLOAT )
      is			-------------
        F : LONG_FLOAT := FRACTION;
        D : INTEGER;
      begin
        for  K in 1 .. AFT  loop
	F := F * 10.0;
	D := INTEGER( FLOOR_POS( F ) );

	if  D > 9  then
	  D := 9;
	elsif  D < 0  then
	  D := 0;
	end if;

	EMIT( CHARACTER'VAL( CHARACTER'POS( '0' ) + D ) );
	F := F - LONG_FLOAT( D );
        end loop;

      end EMIT_FRACTION;
	-------------

    begin

      ------------------------------------------------------------
      -- Conversion initiale du type fixed formel vers LONG_FLOAT.
      -- Toute la mise en forme est ensuite faite en flottant.
      ------------------------------------------------------------

      if  VAL < 0.0  then
        IS_NEGATIVE := TRUE;
        VAL := -VAL;
      end if;

      if  IS_NEGATIVE  then
        EMIT( '-' );
      end if;

      ------------------------------------------------------------
      -- EXP <= 0 : notation decimale ordinaire
      --		 [-]ddd.ddd
      ------------------------------------------------------------

      if  EXP <= 0  then

        -- Arrondi global avant extraction des chiffres.
        for  K in 1 .. AFT  loop
	ROUNDING := ROUNDING / 10.0;
        end loop;

        if  VAL /= 0.0  then
	VAL := VAL + ROUNDING;
        end if;

        IPART := FLOOR_POS( VAL );
        FRC_PART := VAL - LONG_FLOAT( IPART );

        -- Construire la partie entiere en ordre inverse.
        IPART_WORK := IPART;

        if  IPART_WORK = 0  then
	NB := 1;
	IBUF( 1 ) := '0';
        else
	while  IPART_WORK > 0  loop
	  NB := NB + 1;
	  IBUF( NB ) :=
	    CHARACTER'VAL
	      ( CHARACTER'POS( '0' )
	        + INTEGER( IPART_WORK mod 10 ) );
	  IPART_WORK := IPART_WORK / 10;
	end loop;
        end if;

        -- Emettre les chiffres de la partie entiere dans le bon ordre.
        for  K in reverse 1 .. NB  loop
	EMIT( IBUF( K ) );
        end loop;

        EMIT( '.' );
        EMIT_FRACTION( FRC_PART );

      ------------------------------------------------------------
      -- EXP > 0 : notation scientifique
      --	         [-]d.dddE[+|-]dd...
      ------------------------------------------------------------

      else

        -- Normaliser 1.0 <= VAL < 10.0.
        if  VAL /= 0.0  then
	while  VAL >= 10.0  loop
	  VAL := VAL / 10.0;
	  E := E + 1;
	end loop;

	while  VAL < 1.0  loop
	  VAL := VAL * 10.0;
	  E := E - 1;
	end loop;
        end if;

        -- Arrondir la mantisse a AFT chiffres.
        ROUNDING := 0.5;

        for  K in 1 .. AFT  loop
	ROUNDING := ROUNDING / 10.0;
        end loop;

        if  VAL /= 0.0  then
	VAL := VAL + ROUNDING;
        end if;

        -- Propager la retenue eventuelle :
        -- 9.9999996E+n devient 1.000000E+(n+1).
        if  VAL >= 10.0  then
	VAL := VAL / 10.0;
	E := E + 1;
        end if;

        -- Chiffre avant le point.
        DIGIT := INTEGER( FLOOR_POS( VAL ) );

        if  DIGIT > 9  then
	DIGIT := 9;
        elsif  DIGIT < 0  then
	DIGIT := 0;
        end if;

        EMIT( CHARACTER'VAL( CHARACTER'POS( '0' ) + DIGIT ) );

        FRC_PART := VAL - LONG_FLOAT( DIGIT );

        EMIT( '.' );
        EMIT_FRACTION( FRC_PART );

        -- Exposant.
        EMIT( 'E' );

        if  E < 0  then
	EMIT( '-' );
	E := -E;
        else
	EMIT( '+' );
        end if;

        declare
	EXP_STR	: STRING( 1 .. EXP );
	EVAL		: INTEGER := E;
	CHECK		: INTEGER := E;
        begin
	-- Verifier que l'exposant tient dans EXP chiffres.
	for  K in 1 .. EXP  loop
	  CHECK := CHECK / 10;
	end loop;

	if  CHECK /= 0  then
	  BAD_LAYOUT := TRUE;
	end if;

	-- Image de l'exposant avec zeros de tete.
	for  K in reverse 1 .. EXP  loop
	  EXP_STR( K ) :=
	    CHARACTER'VAL
	      ( CHARACTER'POS( '0' ) + EVAL mod 10 );
	  EVAL := EVAL / 10;
	end loop;

	for  K in 1 .. EXP  loop
	  EMIT( EXP_STR( K ) );
	end loop;
        end;

      end if;

      ------------------------------------------------------------
      -- Justification dans TO.
      -- La variante STRING n'a pas FORE : TO'LENGTH est le champ.
      ------------------------------------------------------------

      if  BAD_LAYOUT  or else  LEN > TO'LENGTH  then
        raise LAYOUT_ERROR;								-- LRM 14.3.8(15)
      else

        PAD := TO'LENGTH - LEN;

        POS := TO'FIRST;

        for  K in 1 .. PAD  loop
	TO( POS ) := ' ';
	POS := POS + 1;
        end loop;

        for  K in 1 .. LEN  loop
	TO( POS ) := IMAGE( K );
	POS := POS + 1;
        end loop;

      end if;

    end	PUT;
	---


	--------
  end	FLOAT_IO;
	--------


				--------
  package body			FIXED_IO
  is				--------

			---
    procedure		GET		( FILE  :in FILE_TYPE;
					  ITEM  :out NUM;
					  WIDTH :in FIELD		:= 0
					)
    is			---

      CH		: CHARACTER;
      VAL		: LONG_FLOAT	:= 0.0;
      FRAC	: LONG_FLOAT	:= 0.1;
      NEG		: BOOLEAN		:= FALSE;
      IN_FRAC	: BOOLEAN		:= FALSE;
      EXP_VAL	: INTEGER		:= 0;
      EXP_NEG	: BOOLEAN		:= FALSE;
      CHARS_READ	: NATURAL		:= 0;
      DONE	: BOOLEAN		:= FALSE;
      HAVE_DIGIT	: BOOLEAN		:= FALSE;

    begin
      if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
      if  FILE.MODE /= IN_FILE  then raise MODE_ERROR; end if;

      if  WIDTH = 0  then
        loop
	exit when  FILE.AT_END_OF_FILE;
	GET_RAW( FILE, CH );
	exit when  FILE.AT_END_OF_FILE;
	exit when  CH /= ' '  and then  CH /= ASCII.HT
			and then  CH /= ASCII.LF
			and then  CH /= ASCII.CR
			and then  CH /= ASCII.FF;
        end loop;
      else
        GET_RAW( FILE, CH );
        CHARS_READ := 0;
      end if;
      if  FILE.AT_END_OF_FILE  then raise END_ERROR; end if;				-- LRM 14.3.7(?) fin de fichier avant l'item

      -- Signe optionnel
      if  not FILE.AT_END_OF_FILE  and then  CH = '-'  then
        NEG := TRUE;
        if  WIDTH > 0  then
	CHARS_READ := CHARS_READ + 1;
	if  CHARS_READ >= WIDTH  then  DONE := TRUE;
	else  GET_RAW( FILE, CH );
	end if;
        else
	GET_RAW( FILE, CH );
        end if;
      elsif  not FILE.AT_END_OF_FILE  and then  CH = '+'  then
        if  WIDTH > 0  then
	CHARS_READ := CHARS_READ + 1;
	if  CHARS_READ >= WIDTH  then  DONE := TRUE;
	else  GET_RAW( FILE, CH );
	end if;
        else
	GET_RAW( FILE, CH );
        end if;
      end if;

      -- Mantisse et exposant
      loop
        exit when  DONE  or else  FILE.AT_END_OF_FILE;
        if  WIDTH > 0  and then  CHARS_READ >= WIDTH  then  exit;  end if;

        if  CH = '.'  then
	IN_FRAC := TRUE;
	if  WIDTH > 0  then
	  CHARS_READ := CHARS_READ + 1;
	  if  CHARS_READ >= WIDTH  then  DONE := TRUE;
	  else  GET_RAW( FILE, CH );
	  end if;
	else
	  GET_RAW( FILE, CH );
	end if;

        elsif  CH = 'E'  or else  CH = 'e'  then
	if  WIDTH > 0  then
	  CHARS_READ := CHARS_READ + 1;
	  if  CHARS_READ >= WIDTH  then  DONE := TRUE;
	  else  GET_RAW( FILE, CH );
	  end if;
	else
	  GET_RAW( FILE, CH );
	end if;
	if  not DONE  and then  not FILE.AT_END_OF_FILE  then
	  if  CH = '-'  then
	    EXP_NEG := TRUE;
	    if  WIDTH > 0  then
	      CHARS_READ := CHARS_READ + 1;
	      if  CHARS_READ >= WIDTH  then  DONE := TRUE;
	      else  GET_RAW( FILE, CH );
	      end if;
	    else
	      GET_RAW( FILE, CH );
	    end if;
	  elsif  CH = '+'  then
	    if  WIDTH > 0  then
	      CHARS_READ := CHARS_READ + 1;
	      if  CHARS_READ >= WIDTH  then  DONE := TRUE;
	      else  GET_RAW( FILE, CH );
	      end if;
	    else
	      GET_RAW( FILE, CH );
	    end if;
	  end if;
	end if;
	loop
	  exit when  DONE  or else  FILE.AT_END_OF_FILE;
	  exit when  CH < '0'  or else  CH > '9';
	  EXP_VAL := 10 * EXP_VAL
		       + CHARACTER'POS( CH ) - CHARACTER'POS( '0' );
	  if  WIDTH > 0  then
	    CHARS_READ := CHARS_READ + 1;
	    if  CHARS_READ >= WIDTH  then  DONE := TRUE;
	    else  GET_RAW( FILE, CH );
	    end if;
	  else
	    GET_RAW( FILE, CH );
	  end if;
	end loop;
	if  WIDTH = 0  and then  not FILE.AT_END_OF_FILE
		     and then  ( CH < '0'  or else  CH > '9' )  then
	  FILE.LOOK_AHEAD	  := CH;
	  FILE.HAS_LOOK_AHEAD := TRUE;
	end if;
	DONE := TRUE;

        elsif  CH >= '0'  and then  CH <= '9'  then
	if  IN_FRAC  then
	  VAL  := VAL + FRAC
		    * LONG_FLOAT( CHARACTER'POS( CH ) - CHARACTER'POS( '0' ) );
	  FRAC := FRAC / 10.0;
	else
	  VAL  := 10.0 * VAL
		    + LONG_FLOAT( CHARACTER'POS( CH ) - CHARACTER'POS( '0' ) );
	end if;
	HAVE_DIGIT := TRUE;
	if  WIDTH > 0  then
	  CHARS_READ := CHARS_READ + 1;
	  if  CHARS_READ >= WIDTH  then  DONE := TRUE;
	  else  GET_RAW( FILE, CH );
	  end if;
	else
	  GET_RAW( FILE, CH );
	end if;

        else
	if  WIDTH = 0  then
	  FILE.LOOK_AHEAD	  := CH;
	  FILE.HAS_LOOK_AHEAD := TRUE;
	end if;
	DONE := TRUE;
        end if;
      end loop;

      if  not HAVE_DIGIT  then raise DATA_ERROR; end if;					-- LRM 14.3.8 image invalide

      if  EXP_NEG  then
        for  J in 1 .. EXP_VAL  loop  VAL := VAL / 10.0;  end loop;
      else
        for  J in 1 .. EXP_VAL  loop  VAL := VAL * 10.0;  end loop;
      end if;

      if  NEG  then  ITEM := NUM( -VAL );
      else	 ITEM := NUM(  VAL );
      end if;

    end	GET;
	---


			---
    procedure		GET		( ITEM  :out NUM; WIDTH :in FIELD := 0 )
    is			---
    begin
      GET( DEFAULT_INPUT, ITEM, WIDTH );

    end	GET;
	----


			---
    procedure		PUT		( FILE :in FILE_TYPE;
					  ITEM :in NUM;
					  FORE :in FIELD		:= DEFAULT_FORE;
					  AFT  :in FIELD		:= DEFAULT_AFT;
					  EXP  :in FIELD		:= DEFAULT_EXP
					)
    is			---

      VAL		: LONG_FLOAT	:= LONG_FLOAT( ITEM );
      IS_NEGATIVE	: BOOLEAN		:= LONG_FLOAT( ITEM ) < 0.0;
      ROUNDING	: LONG_FLOAT	:= 0.5;
      INT_PART	: LONG_FLOAT;
      FRC_PART	: LONG_FLOAT;
      DIGIT	: LONG_INTEGER;

      BAD_LAYOUT	: BOOLEAN		:= FALSE;

      IPART	: LONG_INTEGER;
      IPART_WORK	: LONG_INTEGER;
      IBUF	: STRING( 1 .. 40 );
      NB		: NATURAL		:= 0;

      E		: INTEGER		:= 0;

			---------
      function		FLOOR_POS		( X : LONG_FLOAT )		return LONG_INTEGER
      is			---------
        R		: LONG_INTEGER	:= LONG_INTEGER( X );

      begin
        if  LONG_FLOAT( R ) > X  then
	R := R - 1;
        end if;
        return  R;

      end FLOOR_POS;
	---------


			-------------
      procedure		EMIT_FRACTION	( FRACTION :in LONG_FLOAT )
      is			-------------
        F : LONG_FLOAT := FRACTION;
        D : INTEGER;
      begin
        for  K in 1 .. AFT  loop
	F := F * 10.0;
	D := INTEGER( FLOOR_POS( F ) );

	if  D > 9  then
	  D := 9;
	elsif  D < 0  then
	  D := 0;
	end if;

	PUT( FILE, CHARACTER'VAL( CHARACTER'POS( '0' ) + D ) );
	F := F - LONG_FLOAT( D );
        end loop;

      end EMIT_FRACTION;
	-------------


    begin
      if  IS_NEGATIVE  then
        VAL := -VAL;
      end if;

      if  EXP = 0  then

        -- Arrondir a AFT chiffres avant extraction.
        for  K in 1 .. AFT  loop
	ROUNDING := ROUNDING / 10.0;
        end loop;

        VAL := VAL + ROUNDING;

        INT_PART := LONG_FLOAT( FLOOR_POS( VAL ) );
        FRC_PART := VAL - INT_PART;

        declare
	IBUF	: STRING( 1 .. 40 );
	NB	: NATURAL		:= 0;
	IPART	: LONG_INTEGER	:= LONG_INTEGER( INT_PART );
	FLEN	: NATURAL;
        begin
	if  IPART = 0  then
	  NB := 1;
	  IBUF( 1 ) := '0';
	else
	  while  IPART > 0  loop
	    NB := NB + 1;
	    IBUF( NB ) := CHARACTER'VAL( CHARACTER'POS( '0' ) + IPART mod 10 );
	    IPART := IPART / 10;
	  end loop;
	end if;

	FLEN := NB;
	if  IS_NEGATIVE  then
	  FLEN := FLEN + 1;
	end if;

	if  FORE > FLEN  then
	  for  K in 1 .. FORE - FLEN  loop
	    PUT( FILE, ' ' );
	  end loop;
	end if;

	if  IS_NEGATIVE  then
	  PUT( FILE, '-' );
	end if;

	for  K in reverse 1 .. NB  loop
	  PUT( FILE, IBUF( K ) );
	end loop;
        end;

        PUT( FILE, '.' );

        for  K in 1 .. AFT  loop
	FRC_PART := FRC_PART * 10.0;
	DIGIT := FLOOR_POS( FRC_PART );

	if  DIGIT > 9  then DIGIT := 9; end if;
	if  DIGIT < 0  then DIGIT := 0; end if;

	PUT( FILE, CHARACTER'VAL( CHARACTER'POS( '0' ) + INTEGER( DIGIT ) ) );
	FRC_PART := FRC_PART - LONG_FLOAT( DIGIT );
        end loop;

      else											-- EXP > 0
        -- Normaliser 1.0 <= VAL < 10.0.
        if  VAL /= 0.0  then
	while  VAL >= 10.0  loop
	  VAL := VAL / 10.0;
	  E := E + 1;
	end loop;

	while  VAL < 1.0  loop
	  VAL := VAL * 10.0;
	  E := E - 1;
	end loop;
        end if;

        -- Arrondir la mantisse a AFT chiffres.
        ROUNDING := 0.5;

        for  K in 1 .. AFT  loop
	ROUNDING := ROUNDING / 10.0;
        end loop;

        if  VAL /= 0.0  then
	VAL := VAL + ROUNDING;
        end if;

        -- Propager la retenue eventuelle :
        -- 9.9999996E+n devient 1.000000E+(n+1).
        if  VAL >= 10.0  then
	VAL := VAL / 10.0;
	E := E + 1;
        end if;

        -- Chiffre avant le point.
        DIGIT := LONG_INTEGER( FLOOR_POS( VAL ) );

        if  DIGIT > 9  then
	DIGIT := 9;
        elsif  DIGIT < 0  then
	DIGIT := 0;
        end if;

        PUT( FILE, CHARACTER'VAL( CHARACTER'POS( '0' ) + DIGIT ) );

        FRC_PART := VAL - LONG_FLOAT( DIGIT );

        PUT( FILE, '.' );
        EMIT_FRACTION( FRC_PART );

        -- Exposant.
        PUT( FILE, 'E' );

        if  E < 0  then
	PUT( FILE, '-' );
	E := -E;
        else
	PUT( FILE, '+' );
        end if;

        declare
	EXP_STR	: STRING( 1 .. EXP );
	EVAL		: INTEGER := E;
	CHECK		: INTEGER := E;
        begin
	-- Verifier que l'exposant tient dans EXP chiffres.
	for  K in 1 .. EXP  loop
	  CHECK := CHECK / 10;
	end loop;

	if  CHECK /= 0  then
	  BAD_LAYOUT := TRUE;
	end if;

	-- Image de l'exposant avec zeros de tete.
	for  K in reverse 1 .. EXP  loop
	  EXP_STR( K ) :=
	    CHARACTER'VAL
	      ( CHARACTER'POS( '0' ) + EVAL mod 10 );
	  EVAL := EVAL / 10;
	end loop;

	for  K in 1 .. EXP  loop
	  PUT( FILE, EXP_STR( K ) );
	end loop;
        end;

       end if;

    end	PUT;
	---


			---
    procedure		PUT		( ITEM :in NUM;
					  FORE :in FIELD		:= DEFAULT_FORE;
					  AFT  :in FIELD		:= DEFAULT_AFT;
					  EXP  :in FIELD		:= DEFAULT_EXP
					)
    is			---
    begin
      PUT( DEFAULT_OUTPUT, ITEM, FORE, AFT, EXP );

    end	PUT;
	----


			---
    procedure		GET		( FROM :in STRING;
					  ITEM :out NUM;
					  LAST :out POSITIVE
					)
    is			---

      I			: INTEGER		:= FROM'FIRST;
      VAL			: LONG_FLOAT	:= 0.0;
      FRAC		: LONG_FLOAT	:= 0.1;
      NEG			: BOOLEAN		:= FALSE;
      IN_FRAC		: BOOLEAN		:= FALSE;
      HAVE_DIGIT		: BOOLEAN		:= FALSE;
      HAVE_FRAC_DIGIT	: BOOLEAN		:= FALSE;
      EXP_SEEN		: BOOLEAN		:= FALSE;
      EXP_VAL		: INTEGER		:= 0;
      EXP_NEG		: BOOLEAN		:= FALSE;
      HAVE_EXP_DIGIT	: BOOLEAN		:= FALSE;
      BAD_IMAGE		: BOOLEAN		:= FALSE;

begin

  -- Ignorer les espaces initiaux.
  while  I <= FROM'LAST
    and then
      ( FROM( I ) = ' '  or else  FROM( I ) = ASCII.HT )
  loop
    I := I + 1;
  end loop;

  -- Signe optionnel.
  if  I <= FROM'LAST  and then  FROM( I ) = '-'  then
    NEG := TRUE;
    I := I + 1;

  elsif  I <= FROM'LAST  and then  FROM( I ) = '+'  then
    I := I + 1;
  end if;

  -- Mantisse decimale.
  while  I <= FROM'LAST  loop

    if  FROM( I ) >= '0'  and then  FROM( I ) <= '9'  then

      HAVE_DIGIT := TRUE;

      if  IN_FRAC  then
        HAVE_FRAC_DIGIT := TRUE;

        VAL :=
	VAL
	+ FRAC
	* LONG_FLOAT
	    ( CHARACTER'POS( FROM( I ) )
	      - CHARACTER'POS( '0' ) );

        FRAC := FRAC / 10.0;

      else
        VAL :=
	10.0 * VAL
	+ LONG_FLOAT
	    ( CHARACTER'POS( FROM( I ) )
	      - CHARACTER'POS( '0' ) );
      end if;

      I := I + 1;

    elsif  FROM( I ) = '.'  and then  not IN_FRAC  then

      IN_FRAC := TRUE;
      I := I + 1;

    elsif  ( FROM( I ) = 'E'  or else  FROM( I ) = 'e' )
      and then  HAVE_DIGIT
    then

      EXP_SEEN := TRUE;
      I := I + 1;

      -- Signe optionnel de l'exposant.
      if  I <= FROM'LAST  and then  FROM( I ) = '-'  then
        EXP_NEG := TRUE;
        I := I + 1;

      elsif  I <= FROM'LAST  and then  FROM( I ) = '+'  then
        I := I + 1;
      end if;

      -- Chiffres de l'exposant.
      while  I <= FROM'LAST
        and then  FROM( I ) >= '0'
        and then  FROM( I ) <= '9'
      loop
        HAVE_EXP_DIGIT := TRUE;

        EXP_VAL :=
	10 * EXP_VAL
	+ CHARACTER'POS( FROM( I ) )
	- CHARACTER'POS( '0' );

        I := I + 1;
      end loop;

      exit;

    else
      exit;
    end if;

  end loop;

  -- Controle lexical minimal.
  BAD_IMAGE :=
    not HAVE_DIGIT
    or else  ( IN_FRAC  and then  not HAVE_FRAC_DIGIT )
    or else  ( EXP_SEEN  and then  not HAVE_EXP_DIGIT );

  if  BAD_IMAGE  then
    raise DATA_ERROR;									-- LRM 14.3.8(?) image invalide
  end if;

  -- Appliquer l'exposant decimal.
  if  EXP_NEG  then
    for  J in 1 .. EXP_VAL  loop
      VAL := VAL / 10.0;
    end loop;
  else
    for  J in 1 .. EXP_VAL  loop
      VAL := VAL * 10.0;
    end loop;
  end if;

  -- I designe le premier caractere non consomme.
  LAST := POSITIVE( I - 1 );

  -- Conversion unique LONG_FLOAT -> type fixed reel de l'instance.
  if  NEG  then
    ITEM := NUM( -VAL );
  else
    ITEM := NUM( VAL );
  end if;

    end	GET;
	---


			---
    procedure		PUT		( TO   :out STRING;
					  ITEM :in NUM;
					  AFT  :in FIELD		:= DEFAULT_AFT;
					  EXP  :in INTEGER		:= DEFAULT_EXP
					)
    is			---

      IMAGE		: STRING( 1 .. 80 );
      LEN			: NATURAL		:= 0;
      POS			: INTEGER;
      PAD			: INTEGER;

      VAL			: LONG_FLOAT	:= LONG_FLOAT( ITEM );
      ROUNDING		: LONG_FLOAT	:= 0.5;
      FRC_PART		: LONG_FLOAT	:= 0.0;

      IS_NEGATIVE		: BOOLEAN		:= FALSE;
      BAD_LAYOUT		: BOOLEAN		:= FALSE;

      DIGIT		: INTEGER;
      IPART		: LONG_INTEGER;
      IPART_WORK		: LONG_INTEGER;
      IBUF		: STRING( 1 .. 40 );
      NB			: NATURAL		:= 0;

      E			: INTEGER		:= 0;

			---------
      function		FLOOR_POS		( X : LONG_FLOAT )		return LONG_INTEGER
      is			---------
        R : LONG_INTEGER := LONG_INTEGER( X );
      begin
        -- La conversion Ada LONG_INTEGER(X) arrondit.
        -- Pour le formatage, on veut floor(X), avec X >= 0.0.
        if  LONG_FLOAT( R ) > X  then
	R := R - 1;
        end if;

        return R;

      end FLOOR_POS;
	---------


			----
      procedure		EMIT		( CH :in CHARACTER )
      is			----
      begin
        if  LEN < IMAGE'LAST  then
	LEN := LEN + 1;
	IMAGE( LEN ) := CH;
        else
	BAD_LAYOUT := TRUE;
        end if;

      end EMIT;
	----


			-------------
      procedure		EMIT_FRACTION	( FRACTION :in LONG_FLOAT )
      is			-------------
        F : LONG_FLOAT := FRACTION;
        D : INTEGER;
      begin
        for  K in 1 .. AFT  loop
	F := F * 10.0;
	D := INTEGER( FLOOR_POS( F ) );

	if  D > 9  then
	  D := 9;
	elsif  D < 0  then
	  D := 0;
	end if;

	EMIT( CHARACTER'VAL( CHARACTER'POS( '0' ) + D ) );
	F := F - LONG_FLOAT( D );
        end loop;

      end EMIT_FRACTION;
	-------------

    begin

      ------------------------------------------------------------
      -- Conversion initiale du type fixed formel vers LONG_FLOAT.
      -- Toute la mise en forme est ensuite faite en flottant.
      ------------------------------------------------------------

      if  VAL < 0.0  then
        IS_NEGATIVE := TRUE;
        VAL := -VAL;
      end if;

      if  IS_NEGATIVE  then
        EMIT( '-' );
      end if;

      ------------------------------------------------------------
      -- EXP <= 0 : notation decimale ordinaire
      --		 [-]ddd.ddd
      ------------------------------------------------------------

      if  EXP <= 0  then

        -- Arrondi global avant extraction des chiffres.
        for  K in 1 .. AFT  loop
	ROUNDING := ROUNDING / 10.0;
        end loop;

        if  VAL /= 0.0  then
	VAL := VAL + ROUNDING;
        end if;

        IPART := FLOOR_POS( VAL );
        FRC_PART := VAL - LONG_FLOAT( IPART );

        -- Construire la partie entiere en ordre inverse.
        IPART_WORK := IPART;

        if  IPART_WORK = 0  then
	NB := 1;
	IBUF( 1 ) := '0';
        else
	while  IPART_WORK > 0  loop
	  NB := NB + 1;
	  IBUF( NB ) :=
	    CHARACTER'VAL
	      ( CHARACTER'POS( '0' )
	        + INTEGER( IPART_WORK mod 10 ) );
	  IPART_WORK := IPART_WORK / 10;
	end loop;
        end if;

        -- Emettre les chiffres de la partie entiere dans le bon ordre.
        for  K in reverse 1 .. NB  loop
	EMIT( IBUF( K ) );
        end loop;

        EMIT( '.' );
        EMIT_FRACTION( FRC_PART );

      ------------------------------------------------------------
      -- EXP > 0 : notation scientifique
      --	         [-]d.dddE[+|-]dd...
      ------------------------------------------------------------

      else

        -- Normaliser 1.0 <= VAL < 10.0.
        if  VAL /= 0.0  then
	while  VAL >= 10.0  loop
	  VAL := VAL / 10.0;
	  E := E + 1;
	end loop;

	while  VAL < 1.0  loop
	  VAL := VAL * 10.0;
	  E := E - 1;
	end loop;
        end if;

        -- Arrondir la mantisse a AFT chiffres.
        ROUNDING := 0.5;

        for  K in 1 .. AFT  loop
	ROUNDING := ROUNDING / 10.0;
        end loop;

        if  VAL /= 0.0  then
	VAL := VAL + ROUNDING;
        end if;

        -- Propager la retenue eventuelle :
        -- 9.9999996E+n devient 1.000000E+(n+1).
        if  VAL >= 10.0  then
	VAL := VAL / 10.0;
	E := E + 1;
        end if;

        -- Chiffre avant le point.
        DIGIT := INTEGER( FLOOR_POS( VAL ) );

        if  DIGIT > 9  then
	DIGIT := 9;
        elsif  DIGIT < 0  then
	DIGIT := 0;
        end if;

        EMIT( CHARACTER'VAL( CHARACTER'POS( '0' ) + DIGIT ) );

        FRC_PART := VAL - LONG_FLOAT( DIGIT );

        EMIT( '.' );
        EMIT_FRACTION( FRC_PART );

        -- Exposant.
        EMIT( 'E' );

        if  E < 0  then
	EMIT( '-' );
	E := -E;
        else
	EMIT( '+' );
        end if;

        declare
	EXP_STR	: STRING( 1 .. EXP );
	EVAL		: INTEGER := E;
	CHECK		: INTEGER := E;
        begin
	-- Verifier que l'exposant tient dans EXP chiffres.
	for  K in 1 .. EXP  loop
	  CHECK := CHECK / 10;
	end loop;

	if  CHECK /= 0  then
	  BAD_LAYOUT := TRUE;
	end if;

	-- Image de l'exposant avec zeros de tete.
	for  K in reverse 1 .. EXP  loop
	  EXP_STR( K ) :=
	    CHARACTER'VAL
	      ( CHARACTER'POS( '0' ) + EVAL mod 10 );
	  EVAL := EVAL / 10;
	end loop;

	for  K in 1 .. EXP  loop
	  EMIT( EXP_STR( K ) );
	end loop;
        end;

      end if;

      ------------------------------------------------------------
      -- Justification dans TO.
      -- La variante STRING n'a pas FORE : TO'LENGTH est le champ.
      ------------------------------------------------------------

      if  BAD_LAYOUT  or else  LEN > TO'LENGTH  then
        raise LAYOUT_ERROR;								-- LRM 14.3.8(15)
      else

        PAD := TO'LENGTH - LEN;

        POS := TO'FIRST;

        for  K in 1 .. PAD  loop
	TO( POS ) := ' ';
	POS := POS + 1;
        end loop;

        for  K in 1 .. LEN  loop
	TO( POS ) := IMAGE( K );
	POS := POS + 1;
        end loop;

      end if;

    end	PUT;
	----

	--------
  end	FIXED_IO;
	--------


			-- Generic package for Input-Output of Enumeration types


			--------------
  package body		ENUMERATION_IO
  is			--------------

			---
    procedure		PUT		( FILE  :in FILE_TYPE;
					  ITEM  :in ENUM;
					  WIDTH :in FIELD		:= DEFAULT_WIDTH;
					  SET   :in TYPE_SET	:= DEFAULT_SETTING
					)
    is			---

		---------------
      function	GET_ENUM_IMAGES			return STRING
      is		---------------
      begin
        ASM_OP_2'( OPCODE => La,  LVL => 1, OFS => -40 );							-- empiler @GFP_disp
        ASM_OP_3'( OPCODE => LIVa,  DISP => -8, OFS=> 16 );							-- deref __u_ofs → IMAGES
        ASM_OP_2'( OPCODE => Sa,  LVL => 2, OFS => -8 );							-- stocker dans result_ofs

      end GET_ENUM_IMAGES;
	---------------

    begin
      declare
        IMAGES_STR		:constant STRING		:= GET_ENUM_IMAGES;
        POS_VAL		: INTEGER			:= ENUM'POS( ITEM );
        I			: POSITIVE		:= IMAGES_STR'FIRST;
        REP		: INTEGER;
        LEN		: INTEGER;
        IMG_START		: POSITIVE;
        PAD		: INTEGER;
      begin
        -- Parcourir les triplets (REP, LEN, cars...) dans IMAGES_STR
        while  I <= IMAGES_STR'LAST  loop
	REP := CHARACTER'POS( IMAGES_STR( I ) );
	LEN := CHARACTER'POS( IMAGES_STR( I + 1 ) );
	if  REP = POS_VAL  then
	  IMG_START := I + 2;
	  -- Ecrire les caracteres de l'image
	  for  J in 0 .. LEN - 1  loop
	    if  SET = LOWER_CASE  then
	      declare
	        CH	: CHARACTER	:= IMAGES_STR( IMG_START + J );
	      begin
	        if  CH >= 'A'  and then  CH <= 'Z'  then
		CH := CHARACTER'VAL( CHARACTER'POS( CH ) + 32 );
	        end if;
	        PUT( FILE, CH );
	      end;
	    else
	      PUT( FILE, IMAGES_STR( IMG_START + J ) );
	    end if;
	  end loop;
	  -- LRM 14.3.9(10) : cadrage a GAUCHE, blancs de QUEUE si
	  -- WIDTH depasse l'image (deviation console corrigee).
	  PAD := WIDTH - LEN;
	  if  PAD > 0  then
	    for  J in 1 .. PAD  loop
	      PUT( FILE, ' ' );
	    end loop;
	  end if;
	  return;
	end if;
	I := I + 2 + LEN;
        end loop;
      end;

    end	PUT;
	---

			---
    procedure		PUT		( ITEM  :in ENUM;
					  WIDTH :in FIELD		:= DEFAULT_WIDTH;
					  SET   :in TYPE_SET	:= DEFAULT_SETTING
					)
    is			---
    begin
      PUT( DEFAULT_OUTPUT, ITEM, WIDTH, SET );

    end	PUT;
	----


			---
    procedure		GET		( FILE :in FILE_TYPE; ITEM :out ENUM)
    is			---

      TOKEN	: STRING( 1 .. 80 );
      TOK_LEN	: NATURAL		:= 0;
      TOK_TOO_LONG  : BOOLEAN		:= FALSE;

      CH		: CHARACTER;
      DONE	: BOOLEAN		:= FALSE;

      I		: POSITIVE;
      REP		: INTEGER;
      IMG_LEN	: INTEGER;
      IMG_START	: POSITIVE;
      FOUND	: BOOLEAN		:= FALSE;
      OK		: BOOLEAN;
      HAS_QUOTE	: BOOLEAN;
      IMG_CH	: CHARACTER;
      TOK_CH	: CHARACTER;

		---------------
      function	GET_ENUM_IMAGES			return STRING
      is		---------------
      begin
        ASM_OP_2'( OPCODE => La,   LVL => 1, OFS => -24 );							-- empiler @GFP_disp
        ASM_OP_3'( OPCODE => LIVa, DISP => -8, OFS => 16 );							-- deref __u_ofs -> IMAGES
        ASM_OP_2'( OPCODE => Sa,   LVL => 2, OFS => -8 );							-- stocker dans result_ofs

      end GET_ENUM_IMAGES;
	---------------


		-----
      function	UPPER		( CH : CHARACTER ) return CHARACTER
      is		-----
      begin
        if  CH >= 'a'  and then  CH <= 'z'  then
	return CHARACTER'VAL( CHARACTER'POS( CH ) - 32 );
        else
	return CH;
        end if;

      end UPPER;
	-----

		------------
      function	IS_SEPARATOR	( CH : CHARACTER ) return BOOLEAN
      is		------------
      begin
        return
	CH = ' '
	or else CH = ASCII.HT
	or else CH = ASCII.LF
	or else CH = ASCII.CR
	or else CH = ASCII.FF;

      end IS_SEPARATOR;
	------------

		-------------
      function	IS_IDENT_CHAR	( CH : CHARACTER ) return BOOLEAN
      is		-------------
      begin
        return
	( CH >= 'A'  and then  CH <= 'Z' )
	or else
	( CH >= 'a'  and then  CH <= 'z' )
	or else
	( CH >= '0'  and then  CH <= '9' )
	or else
	CH = '_';

      end IS_IDENT_CHAR;
	-------------


		----------
      procedure	UNGET_CHAR	( CH :in CHARACTER )
      is		----------
      begin
        FILE.LOOK_AHEAD     := CH;
        FILE.HAS_LOOK_AHEAD := TRUE;

      end UNGET_CHAR;
	----------
    begin
      declare
        IMAGES_STR  : constant STRING	:= GET_ENUM_IMAGES;

      begin
      if  FILE.IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
      if  FILE.MODE /= IN_FILE  then raise MODE_ERROR; end if;

SKIP_BLANKS:
        loop
        exit when  FILE.AT_END_OF_FILE;
	GET_RAW( FILE, CH );
        exit when  FILE.AT_END_OF_FILE;
        exit when not IS_SEPARATOR( CH );
      end loop  SKIP_BLANKS;
      if  FILE.AT_END_OF_FILE  then raise END_ERROR; end if;				-- fin de fichier avant l'item

      ------------------------------------------------------------
      -- 2. Lire l'image du literal enumere.
      --
      --	  Cas courant : identificateur Ada, donc lettres/chiffres/'_'.
      --	  Cas CHARACTER : image de forme 'X', lue jusqu'au second
      --	  apostrophe inclus.
      --
      --	  Le premier caractere lu qui n'appartient plus au token est
      --	  remis en anticipation.
      ------------------------------------------------------------

      if  CH = '''  then

        -- Literal caractere : recopier l'apostrophe initiale.
        TOK_LEN := 1;
        TOKEN( 1 ) := CH;

        loop
	GET_RAW( FILE, CH );

	if  TOK_LEN < TOKEN'LAST  then
	  TOK_LEN := TOK_LEN + 1;
	  TOKEN( TOK_LEN ) := CH;
	else
	  TOK_TOO_LONG := TRUE;
	end if;

	exit when CH = ''';
        end loop;

      else											-- Identificateur enumere.
        loop
	if  IS_IDENT_CHAR( CH )  then

	  if  TOK_LEN < TOKEN'LAST  then
	    TOK_LEN := TOK_LEN + 1;
	    TOKEN( TOK_LEN ) := CH;
	  else
	    TOK_TOO_LONG := TRUE;
	  end if;

	  GET_RAW( FILE, CH );

	else
	  UNGET_CHAR( CH );
	  DONE := TRUE;
	end if;

	exit when DONE;
        end loop;

      end if;

      ------------------------------------------------------------
      -- 3. Chercher l'image correspondante dans IMAGES_STR.
      --	  Les identificateurs sont compares sans tenir compte de
      --	  la casse. Les images contenant une apostrophe sont
      --	  comparees exactement, pour ne pas confondre 'a' et 'A'.
      ------------------------------------------------------------

      if  TOK_LEN = 0  or else  TOK_TOO_LONG  then
        raise DATA_ERROR;								-- LRM 14.3.9(8)
      end if;

      I := IMAGES_STR'FIRST;

      while  I <= IMAGES_STR'LAST  loop

        REP       := CHARACTER'POS( IMAGES_STR( I ) );
        IMG_LEN   := CHARACTER'POS( IMAGES_STR( I + 1 ) );
        IMG_START := I + 2;

        if  IMG_LEN = TOK_LEN  then

	HAS_QUOTE := FALSE;

	for  J in 0 .. IMG_LEN - 1  loop
	  if  IMAGES_STR( IMG_START + J ) = '''  then
	    HAS_QUOTE := TRUE;
	  end if;
	end loop;

	OK := TRUE;

	for  J in 0 .. IMG_LEN - 1  loop
	  IMG_CH := IMAGES_STR( IMG_START + J );
	  TOK_CH := TOKEN( J + 1 );

	  if  HAS_QUOTE  then
	    -- Images de caracteres : comparaison exacte.
	    if  TOK_CH /= IMG_CH  then
	      OK := FALSE;
	    end if;
	  else
	    -- Identificateurs : insensibles a la casse.
	    if  UPPER( TOK_CH ) /= UPPER( IMG_CH )  then
	      OK := FALSE;
	    end if;
	  end if;
	end loop;

	if  OK  then
	  ITEM := ENUM'VAL( REP );
	  return;
	end if;

        end if;

        I := I + 2 + IMG_LEN;
      end loop;

      ------------------------------------------------------------
      -- 4. Aucune image trouvee.
      ------------------------------------------------------------

      raise DATA_ERROR;									-- LRM 14.3.9(8) image inconnue
      end;

    end	GET;
	---


			---
    procedure		GET		( ITEM :out ENUM)
    is			---
    begin
      GET( DEFAULT_INPUT, ITEM );

    end	GET;
	---


			---
    procedure		GET		( FROM :in STRING;
					  ITEM :out ENUM;
					  LAST :out POSITIVE
					)
    is			---

      I			: INTEGER		:= FROM'FIRST;
      P			: INTEGER;
      REP			: INTEGER;
      LEN			: INTEGER;
      IMG_START		: INTEGER;

      MATCH_FOUND		: BOOLEAN		:= FALSE;
      MATCH_REP		: INTEGER		:= 0;
      MATCH_LEN		: INTEGER		:= 0;

      OK			: BOOLEAN;

		---------------
      function	GET_ENUM_IMAGES			return STRING
      is		---------------
      begin
        ASM_OP_2'( OPCODE => La,   LVL => 1, OFS => -32 );							-- empiler @GFP_disp
        ASM_OP_3'( OPCODE => LIVa, DISP => -8, OFS => 16 );							-- deref __u_ofs -> IMAGES
        ASM_OP_2'( OPCODE => Sa,   LVL => 2, OFS => -8 );							-- stocker dans result_ofs

      end GET_ENUM_IMAGES;
	---------------

		-----
      function	UPPER		( CH : CHARACTER )		return CHARACTER
      is		-----
      begin
        if  CH >= 'a'  and then  CH <= 'z'  then
	return  CHARACTER'VAL( CHARACTER'POS( CH ) - 32 );
        else
	return  CH;
        end if;

      end UPPER;
	-----

		---------
      function	SAME_CHAR		( LEFT, RIGHT : CHARACTER )	return BOOLEAN
      is		---------
      begin
        return  UPPER( LEFT ) = UPPER( RIGHT );

      end SAME_CHAR;
	---------

    begin
      declare
        IMAGES_STR		: constant STRING	:= GET_ENUM_IMAGES;

      begin
IGNORE_BLANKS:
        while  I <= FROM'LAST  and then
	( FROM( I ) = ' '
	  or else FROM( I ) = ASCII.HT
	  or else FROM( I ) = ASCII.LF
	  or else FROM( I ) = ASCII.FF )
        loop
	I := I + 1;
        end loop  IGNORE_BLANKS;

        P := IMAGES_STR'FIRST;

      -- IMAGES_STR contient des triplets :
      --	 REP, LEN, caracteres_de_l_image
        while  P <= IMAGES_STR'LAST  loop

	REP := CHARACTER'POS( IMAGES_STR( P ) );
	LEN := CHARACTER'POS( IMAGES_STR( P + 1 ) );

	IMG_START := P + 2;

	if  I + LEN - 1 <= FROM'LAST  then
	  OK := TRUE;

	  for  J in 0 .. LEN - 1  loop
	    if  not SAME_CHAR( FROM( I + J ), IMAGES_STR( IMG_START + J ) )  then
	      OK := FALSE;
	    end if;
	  end loop;

	  if  OK  then
	  -- Retenir la plus longue image correspondante.
	  -- C'est utile si deux images ont un prefixe commun.
	    if  not MATCH_FOUND  or else  LEN > MATCH_LEN  then
	      MATCH_FOUND := TRUE;
	      MATCH_REP   := REP;
	      MATCH_LEN   := LEN;
	    end if;
	  end if;

	end if;

	P := P + 2 + LEN;
        end loop;

        if  MATCH_FOUND  then
	ITEM := ENUM'VAL( MATCH_REP );
	LAST := POSITIVE( I + MATCH_LEN - 1 );

        else
	raise DATA_ERROR;								-- LRM 14.3.9(12)
        end if;
      end;

    end	GET;
	---


			---
    procedure		PUT		( TO   :out STRING;
					  ITEM :in ENUM;
					  SET  :in TYPE_SET		:= DEFAULT_SETTING
					)
    is			---

		---------------
      function	GET_ENUM_IMAGES			return STRING
      is		---------------
      begin
        ASM_OP_2'( OPCODE => La,   LVL => 1, OFS => -32 );		-- empiler @GFP_disp
        ASM_OP_3'( OPCODE => LIVa, DISP => -8, OFS => 16 );		-- deref __u_ofs -> IMAGES
        ASM_OP_2'( OPCODE => Sa,   LVL => 2, OFS => -8 );		-- stocker dans result_ofs

      end GET_ENUM_IMAGES;
	---------------

    begin
      declare
        IMAGES_STR		: constant STRING		:= GET_ENUM_IMAGES;
        POS_VAL		: INTEGER			:= ENUM'POS( ITEM );
        I			: POSITIVE		:= IMAGES_STR'FIRST;
        REP		: INTEGER;
        LEN		: INTEGER;
        IMG_START		: POSITIVE;
        PAD		: INTEGER;
        DST		: INTEGER;
        CH		: CHARACTER;
      begin

        -- Par defaut, remplir le champ avec des blancs.
        for  K in TO'FIRST .. TO'LAST  loop
	TO( K ) := ' ';
        end loop;

        -- Parcourir les triplets (REP, LEN, caracteres...) dans IMAGES_STR.
        while  I <= IMAGES_STR'LAST  loop

	REP := CHARACTER'POS( IMAGES_STR( I ) );
	LEN := CHARACTER'POS( IMAGES_STR( I + 1 ) );

	if  REP = POS_VAL  then

	  IMG_START := I + 2;

	  if  LEN > TO'LENGTH  then
	    raise LAYOUT_ERROR;							-- LRM 14.3.9(13)
	  end if;

--	    PAD := TO'LENGTH - LEN;
--	    DST := TO'FIRST + PAD;
	  DST := TO'FIRST;

	  for  J in 0 .. LEN - 1  loop
	    CH := IMAGES_STR( IMG_START + J );

	    if  SET = LOWER_CASE  then
	      if  CH >= 'A'  and then  CH <= 'Z'  then
	        CH := CHARACTER'VAL( CHARACTER'POS( CH ) + 32 );
	      end if;
	    end if;

	    TO( DST + J ) := CH;
	  end loop;

	  return;

	end if;

	I := I + 2 + LEN;
        end loop;

        -- Cas normalement impossible : ITEM doit toujours avoir une image.
        raise PROGRAM_ERROR;

      end;

    end	PUT;
	---


  end	ENUMERATION_IO;
	--------------


begin
  -- Initialisation EXPLICITE et complete des fichiers standard : la
  -- VARzone n'etant pas zeroee, aucun champ ne doit dependre des
  -- defauts de composants du record (dette consignee, ETAT_PILIERS).
  STD_INPUT.ID		:= -1;								-- -1 = console
  STD_INPUT.NAME_LEN	:= 0;
  STD_INPUT.MODE		:= IN_FILE;
  STD_INPUT.PAGE_LENGTH	:= 0;								-- LRM 14.3.3 : non borne
  STD_INPUT.LINE_LENGTH	:= 0;
  STD_INPUT.PAGE := 1;
  STD_INPUT.LINE := 1;
  STD_INPUT.COL  := 1;
  STD_INPUT.IS_OPENED	:= TRUE;
  STD_INPUT.IS_DEFAULT_IO	:= TRUE;
  STD_INPUT.LOOK_AHEAD	:= ASCII.NUL;
  STD_INPUT.HAS_LOOK_AHEAD	:= FALSE;
  STD_INPUT.AT_END_OF_FILE	:= FALSE;

  STD_OUTPUT.ID		:= -1;
  STD_OUTPUT.NAME_LEN	:= 0;
  STD_OUTPUT.MODE		:= OUT_FILE;
  STD_OUTPUT.PAGE_LENGTH	:= 0;
  STD_OUTPUT.LINE_LENGTH	:= 0;
  STD_OUTPUT.PAGE := 1;
  STD_OUTPUT.LINE := 1;
  STD_OUTPUT.COL  := 1;
  STD_OUTPUT.IS_OPENED	:= TRUE;
  STD_OUTPUT.IS_DEFAULT_IO	:= TRUE;
  STD_OUTPUT.LOOK_AHEAD	:= ASCII.NUL;
  STD_OUTPUT.HAS_LOOK_AHEAD	:= FALSE;
  STD_OUTPUT.AT_END_OF_FILE	:= FALSE;

  DEFAULT_INPUT		:= STD_INPUT;
  DEFAULT_OUTPUT		:= STD_OUTPUT;

  for  ID in 0 .. MAX_BUF_ID  loop									-- VARzone non zeroee : compteurs a 0 explicitement
    BUFS( ID ).OUT_LEN := 0;
    BUFS( ID ).IN_POS  := 0;
    BUFS( ID ).IN_LEN  := 0;
  end loop;

end	TEXT_IO;
	-------
