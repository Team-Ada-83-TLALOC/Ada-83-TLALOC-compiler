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
  TEMP_COUNT		: NATURAL		:= 0;						-- fichiers temporaires crees (CREATE sans nom)

  DEFAULT_INPUT		: FILE_TYPE;
  DEFAULT_OUTPUT		: FILE_TYPE;
  STD_INPUT		: FILE_TYPE;
  STD_OUTPUT		: FILE_TYPE;


			-- Tampons d'entree-sortie par descripteur Linux (hors LRM).
			-- Indexes par ETATS( FILE.SLOT ).ID et non loges dans FILE_TYPE, dont les
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


			-- Etat des fichiers ouverts (hors LRM), indexe par FILE.SLOT.
			-- LRM 14.2.1 : CURRENT_OUTPUT et les autres copies d'un
			-- FILE_TYPE designent le meme fichier ; elles partagent donc
			-- l'etat (compteurs, anticipation, mode, ouverture).
			-- SLOT -1 : fichier jamais ouvert, toujours ferme, jamais ecrit.
			-- SLOT  0 : entree standard ; SLOT 1 : sortie standard (console).
			-- SLOT  2 .. MAX_ETAT : fichiers, alloues en tourniquet pour
			-- qu'une copie perimee ne designe pas aussitot un autre fichier.

  MAX_ETAT		:constant		:= 31;
  PREMIER_SLOT		:constant		:= 2;
  MAX_LOOK		:constant		:= 4;						-- 3 caracteres d'anticipation + 1 remis

  type ETAT_FICHIER		is record
			  ID		: INTEGER;						-- descripteur Linux, -1 : console
			  NAME		: FILE_NAME_BUFFER;
			  NAME_LEN		: NATURAL;
			  IS_OPENED		: BOOLEAN;
			  MODE		: FILE_MODE;
			  PAGE_LENGTH	: COUNT;						-- LRM 14.3.3 : 0 = non borne
			  LINE_LENGTH	: COUNT;
			  PAGE,
			  LINE,
			  COL		: POSITIVE_COUNT;
			  PREC_PAGE,								-- compteurs avant le dernier caractere
			  PREC_LINE,								-- consomme, pour REMETTRE
			  PREC_COL		: POSITIVE_COUNT;
			  IS_DEFAULT_IO	: BOOLEAN;
			  LOOK		: STRING( 1 .. MAX_LOOK );				-- caracteres logiques a venir, deja lus
			  NB_LOOK		: NATURAL;
			  DERNIER		: CHARACTER;						-- dernier caractere logique produit
			  FIN_PHYSIQUE	: BOOLEAN;						-- fin physique du fichier atteinte
			  AT_END_OF_FILE	: BOOLEAN;						-- GET_RAW a rencontre la fin logique
			  IS_TEMP		: BOOLEAN;						-- LRM 14.2.1 : CREATE sans nom
			end record;

  ETATS			: array( INTEGER range -1 .. MAX_ETAT ) of ETAT_FICHIER;		-- INTEGER : -1 seul serait ambigu (COUNT...)
  PROCHAIN_SLOT		: INTEGER		:= PREMIER_SLOT;


			-- Analyse lexicale des GET (hors LRM) : un automate commun aux
			-- quatre paquetages generiques, ecrit hors des generiques.
			-- LRM 14.3.5 : on lit le plus long prefixe de la syntaxe du
			-- lexeme ; le premier caractere qui ne le prolonge pas reste a
			-- lire. Si le prefixe n'est pas un lexeme complet : DATA_ERROR.

  MAX_LEXEME		:constant		:= 255;

  type GENRE_LEXEME		is ( LEX_ENTIER,							-- [signe] litteral entier (LRM 2.4)
			     LEX_REEL,							-- [signe] litteral reel : point obligatoire
			     LEX_ENUM );							-- identificateur ou litteral caractere

  type PHASE_LEXEME		is ( P_DEBUT, P_SIGNE,
			     P_ENT, P_ENT_SOUL,						-- chiffres decimaux (ou base avant #)
			     P_OUVERT, P_BASE, P_BASE_SOUL,					-- litteral base : apres # ou :
			     P_BASE_PT, P_BASE_FR, P_BASE_FR_SOUL,
			     P_FERME,							-- apres le delimiteur fermant
			     P_PT, P_FR, P_FR_SOUL,						-- partie fractionnaire decimale
			     P_EXP, P_EXP_SIGNE, P_EXP_CH, P_EXP_SOUL,
			     P_ID, P_ID_SOUL,						-- identificateur
			     P_CAR_OUVERT, P_CAR, P_CAR_FERME );				-- litteral caractere

			-- Element d'un PUT numerique ou enumere (LRM 14.3.5) : sur une
			-- ligne bornee, ses caracteres sont d'abord captes, pour connaitre
			-- sa longueur (LAYOUT_ERROR s'il depasse la ligne, NEW_LINE s'il ne
			-- tient pas dans ce qu'il en reste), puis ecrits. Ligne non bornee :
			-- aucune capture, ecriture directe.

  MAX_CAPTE		:constant		:= 4096;
  CAPTE_SLOT		: INTEGER		:= -2;						-- -2 : aucune capture en cours
  CAPTE		: STRING( 1 .. MAX_CAPTE );
  CAPTE_LEN		: NATURAL		:= 0;

  type AUTOMATE_LEXEME	is record
			  GENRE	: GENRE_LEXEME;
			  PHASE	: PHASE_LEXEME;
			  DELIM	: CHARACTER;						-- # ou : d'ouverture (LRM 2.10)
			  POINT	: BOOLEAN;
			end record;


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


			----------
  procedure		FLUSH_TOUT							-- toutes les sorties en attente partent :
  is			----------							-- un fichier externe ouvert deux fois
  begin												-- (ecriture et lecture) se relit a jour
    for  ID in 0 .. MAX_BUF_ID  loop
      FLUSH_OUT( ID );
    end loop;

  end	FLUSH_TOUT;
	----------


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


			---------
  procedure		INSTALLER		( FILE :in out FILE_TYPE;				-- prend un SLOT libre et y installe
					  ID   :in INTEGER;					-- l'etat initial d'un fichier ouvert
					  NAME :in STRING;
					  MODE :in FILE_MODE
					)
  is			---------

    S		: INTEGER	:= PROCHAIN_SLOT;

  begin
    loop												-- tourniquet sur PREMIER_SLOT .. MAX_ETAT
      exit when  not ETATS( S ).IS_OPENED;
      S := S + 1;
      if  S > MAX_ETAT  then S := PREMIER_SLOT; end if;
      if  S = PROCHAIN_SLOT  then raise USE_ERROR; end if;						-- table pleine
    end loop;
    PROCHAIN_SLOT := S + 1;
    if  PROCHAIN_SLOT > MAX_ETAT  then PROCHAIN_SLOT := PREMIER_SLOT; end if;

    FILE.SLOT := S;
    ETATS( S ).ID		:= ID;
    ETATS( S ).NAME( 1 .. NAME'LENGTH ) := NAME;
    ETATS( S ).NAME_LEN	:= NAME'LENGTH;
    ETATS( S ).IS_OPENED	:= TRUE;
    ETATS( S ).MODE		:= MODE;
    ETATS( S ).PAGE_LENGTH	:= STDOUT_PAGE_LENGTH;
    ETATS( S ).LINE_LENGTH	:= STDOUT_LINE_LENGTH;
    ETATS( S ).PAGE		:= 1;
    ETATS( S ).LINE		:= 1;
    ETATS( S ).COL		:= 1;
    ETATS( S ).PREC_PAGE	:= 1;
    ETATS( S ).PREC_LINE	:= 1;
    ETATS( S ).PREC_COL	:= 1;
    ETATS( S ).IS_DEFAULT_IO	:= FALSE;
    ETATS( S ).NB_LOOK	:= 0;
    ETATS( S ).DERNIER	:= ASCII.NUL;
    ETATS( S ).FIN_PHYSIQUE	:= FALSE;
    ETATS( S ).AT_END_OF_FILE	:= FALSE;
    ETATS( S ).IS_TEMP	:= FALSE;

  end	INSTALLER;
	---------


			-------------
  function		PAGE_TERMINEE	( FILE :in FILE_TYPE )		return BOOLEAN		-- sortie : la page courante est deja
  is			-------------						-- terminee (juste apres NEW_PAGE) ;
  begin												-- toute ecriture change LINE ou COL
    return  ETATS( FILE.SLOT ).PAGE > 1  and then  ETATS( FILE.SLOT ).LINE = 1
					and then  ETATS( FILE.SLOT ).COL = 1;

  end	PAGE_TERMINEE;
	-------------


  procedure		TERMINER_FICHIER	( FILE :in FILE_TYPE );				-- corps apres PUT_RAW


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
    if  ETATS( FILE.SLOT ).IS_OPENED  then raise STATUS_ERROR; end if;					-- LRM 14.2.1(4)
    if  NAME'LENGTH = 0  then								-- LRM 14.2.1(3) : nom nul -> fichier
      TEMP_COUNT := TEMP_COUNT + 1;							-- temporaire, nom engendre dans le
      declare										-- repertoire courant, supprime a CLOSE
        NUM	:constant STRING	:= INTEGER'IMAGE( TEMP_COUNT );
      begin
        CREATE( FILE, MODE, "TLALOC_TMP_" & NUM( NUM'FIRST + 1 .. NUM'LAST ) & ".tmp", FORM );
      end;
      ETATS( FILE.SLOT ).IS_TEMP := TRUE;
      return;
    end if;
    ERR_OR_ID := CREATE_SYSTEM_CALL( NAME );
    if  ERR_OR_ID >= 0  then
      RESET_BUFFER( ERR_OR_ID );
      INSTALLER( FILE, ERR_OR_ID, NAME, MODE );
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
    if  ETATS( FILE.SLOT ).IS_OPENED  then raise STATUS_ERROR; end if;					-- LRM 14.2.1(4)
    FLUSH_TOUT;
    ERR_OR_ID := OPEN_SYSTEM_CALL( NAME );
    if  ERR_OR_ID >= 0  then
      RESET_BUFFER( ERR_OR_ID );
      INSTALLER( FILE, ERR_OR_ID, NAME, MODE );
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

		------------------
    function	DELETE_SYSTEM_CALL  ( NAME : STRING )	return INTEGER			-- fichier temporaire : supprime
    is		------------------							-- a la fermeture (LRM 14.2.1)
    begin
      ASM_OP_2'( OPCODE => La, LVL => 2, OFS => -8 );
      ASM_OP_0'( OPCODE => SYS_FILE_DELETE );
      ASM_OP_2'( OPCODE => SD, LVL => 2, OFS => -16 );

    end	DELETE_SYSTEM_CALL;
	------------------

  begin
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  ETATS( FILE.SLOT ).MODE = OUT_FILE  then
      TERMINER_FICHIER( FILE );
    end if;
    FLUSH_OUT( ETATS( FILE.SLOT ).ID );									-- ce qui attend dans le tampon part avant la fermeture
    ERR_CODE := CLOSE_SYSTEM_CALL( ETATS( FILE.SLOT ).ID );
    RESET_BUFFER( ETATS( FILE.SLOT ).ID );
    ETATS( FILE.SLOT ).ID := -1;
    ETATS( FILE.SLOT ).IS_OPENED := FALSE;
    if  ETATS( FILE.SLOT ).IS_TEMP  then
      ERR_CODE := DELETE_SYSTEM_CALL( ETATS( FILE.SLOT ).NAME( 1 .. ETATS( FILE.SLOT ).NAME_LEN ) );
      ETATS( FILE.SLOT ).IS_TEMP := FALSE;
    end if;
    FILE.SLOT := -1;										-- les copies (CURRENT_OUTPUT...) gardent l'ancien SLOT, ferme

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
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    declare
      S	:constant INTEGER	:= FILE.SLOT;							-- CLOSE remet FILE.SLOT a -1 ; le nom
    begin											-- reste dans ETATS( S )
      CLOSE( FILE );
      ERR_CODE := DELETE_SYSTEM_CALL( ETATS( S ).NAME( 1 .. ETATS( S ).NAME_LEN ) );
    end;

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

		-----------------
    function	CLOSE_SYSTEM_CALL	( FILE_ID :in INTEGER )	return INTEGER
    is		-----------------
    begin
      ASM_OP_2'( OPCODE => Ld, LVL => 2, OFS => -8 );
      ASM_OP_0'( OPCODE => SYS_FILE_CLOSE );
      ASM_OP_2'( OPCODE => SD, LVL => 2, OFS => -16 );

    end	CLOSE_SYSTEM_CALL;
	-----------------

		------------------
    function	CREATE_SYSTEM_CALL  ( NAME :in STRING ) return INTEGER			-- O_TRUNC : vide le fichier
    is		------------------
    begin
      ASM_OP_2'( OPCODE => LA, LVL => 2, OFS => -8 );
      ASM_OP_0'( OPCODE => SYS_FILE_CREATE );
      ASM_OP_2'( OPCODE => SD, LVL => 2, OFS => -16 );

    end	CREATE_SYSTEM_CALL;
	------------------

  begin
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  ETATS( FILE.SLOT ).MODE = OUT_FILE  then							-- comme CLOSE
      TERMINER_FICHIER( FILE );
    end if;
    FLUSH_OUT( ETATS( FILE.SLOT ).ID );									-- ecrire a l'ancienne position avant de revenir au debut
    if  MODE = OUT_FILE  then										-- LRM 14.2.1 : l'ecriture reprend au debut,
      ERR_CODE := CLOSE_SYSTEM_CALL( ETATS( FILE.SLOT ).ID );						-- l'ancien contenu ne doit pas survivre
      RESET_BUFFER( ETATS( FILE.SLOT ).ID );								-- au-dela : fermer puis recreer (O_TRUNC)
      ERR_CODE := CREATE_SYSTEM_CALL( ETATS( FILE.SLOT ).NAME( 1 .. ETATS( FILE.SLOT ).NAME_LEN ) );
      if  ERR_CODE < 0  then
        ETATS( FILE.SLOT ).IS_OPENED := FALSE;
        raise USE_ERROR;
      end if;
      ETATS( FILE.SLOT ).ID := ERR_CODE;
    else
      ERR_CODE := SEEK_SYSTEM_CALL( ETATS( FILE.SLOT ).ID );
    end if;
    RESET_BUFFER( ETATS( FILE.SLOT ).ID );								-- la lecture anticipee ne vaut plus
    ETATS( FILE.SLOT ).MODE := MODE;
    if  MODE = OUT_FILE  then										-- LRM 14.3.3 : longueurs non bornees
      ETATS( FILE.SLOT ).LINE_LENGTH := 0;
      ETATS( FILE.SLOT ).PAGE_LENGTH := 0;
    end if;
    ETATS( FILE.SLOT ).PAGE := 1;
    ETATS( FILE.SLOT ).LINE := 1;
    ETATS( FILE.SLOT ).COL  := 1;
    ETATS( FILE.SLOT ).NB_LOOK	:= 0;
    ETATS( FILE.SLOT ).DERNIER	:= ASCII.NUL;
    ETATS( FILE.SLOT ).FIN_PHYSIQUE	:= FALSE;
    ETATS( FILE.SLOT ).AT_END_OF_FILE	:= FALSE;

  end	RESET;
	-----


			-----
  procedure		RESET		( FILE :in out FILE_TYPE )
  is			-----
  begin
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    RESET( FILE, ETATS( FILE.SLOT ).MODE );

  end	RESET;
	-----


			----
  function		MODE		( FILE :in FILE_TYPE )		return FILE_MODE
  is			----
  begin
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    return ETATS( FILE.SLOT ).MODE;

  end	MODE;
	----


			----
  function		NAME		( FILE :in FILE_TYPE )		return STRING
  is			----
  begin
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    return ETATS( FILE.SLOT ).NAME( 1 .. ETATS( FILE.SLOT ).NAME_LEN );

  end	NAME;
	----


			----
  function		FORM		( FILE :in FILE_TYPE )		return STRING
  is			----
  begin
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    return "";

  end	FORM;
	----


			-------
  function		IS_OPEN		( FILE :in FILE_TYPE )		return BOOLEAN
  is			-------
  begin
    return ETATS( FILE.SLOT ).IS_OPENED;

  end	IS_OPEN;
	-------


			-- Control of default input and output files


			---------
  procedure		SET_INPUT		( FILE :in FILE_TYPE )
  is			---------
  begin
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  ETATS( FILE.SLOT ).MODE /= IN_FILE  then raise MODE_ERROR; end if;
    DEFAULT_INPUT := FILE;

  end	SET_INPUT;
	---------


			----------
  procedure		SET_OUTPUT	( FILE :in FILE_TYPE )
  is			----------
  begin
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  ETATS( FILE.SLOT ).MODE /= OUT_FILE  then raise MODE_ERROR; end if;
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
		-- Deux niveaux d'entree. LIRE_PHYSIQUE lit les octets du fichier
		-- et arme FIN_PHYSIQUE a la fin. Au-dessus, le flux logique :
		-- CR retires (CR LF compte pour un seul terminateur de ligne) et
		-- fin physique precedee des terminateurs manquants, de sorte que
		-- tout fichier lu se termine par LF FF puis la fin (LRM 14.3).
		-- REGARDER via TERMINE_A / CAR_A anticipe jusqu'a 3 caracteres
		-- logiques sans les consommer ; GET_RAW consomme un caractere
		-- logique et tient PAGE / LINE / COL a jour (seul endroit) ;
		-- REMETTRE annule le dernier GET_RAW (scanners numeriques). A la
		-- fin logique, GET_RAW arme AT_END_OF_FILE et rend NUL.
		-- En sortie, PUT_RAW ecrit les octets ; les terminateurs sont LF
		-- (ligne) et FF (page), la fin physique termine le fichier.


			-------------
  procedure		LIRE_PHYSIQUE	( FILE :in FILE_TYPE; ITEM :out CHARACTER )
  is			-------------

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
    if  ETATS( FILE.SLOT ).ID = -1  then										-- standard console input
      ASM_OP_2'( OPCODE => La, LVL => 1, OFS => -16 );							-- push @ITEM : charge l'adresse destination (out param GET level 1 offset -16)
      ASM_OP_0'( OPCODE => SYS_GET_CHAR );								-- get console char

    elsif  ETATS( FILE.SLOT ).ID > MAX_BUF_ID  then									-- descripteur hors table : ancien chemin
      BYTES_READ := READ_SYSTEM_CALL( ETATS( FILE.SLOT ).ID );								-- general file
      if  BYTES_READ <= 0  then
        ETATS( FILE.SLOT ).FIN_PHYSIQUE := TRUE;
        ITEM := ASCII.NUL;
      end if;

    else												-- fichier tamponne : blocs de BUF_SIZE
      if  BUFS( ETATS( FILE.SLOT ).ID ).IN_POS >= BUFS( ETATS( FILE.SLOT ).ID ).IN_LEN  then
        FLUSH_TOUT;
        BYTES_READ := READ_RAW( ETATS( FILE.SLOT ).ID, BUFS( ETATS( FILE.SLOT ).ID ).DATA );
        if  BYTES_READ < 0  then BYTES_READ := 0; end if;						-- erreur assimilee a la fin de fichier
        BUFS( ETATS( FILE.SLOT ).ID ).IN_LEN := BYTES_READ;
        BUFS( ETATS( FILE.SLOT ).ID ).IN_POS := 0;
      end if;
      if  BUFS( ETATS( FILE.SLOT ).ID ).IN_LEN = 0  then
        ETATS( FILE.SLOT ).FIN_PHYSIQUE := TRUE;
        ITEM := ASCII.NUL;
      else
        BUFS( ETATS( FILE.SLOT ).ID ).IN_POS := BUFS( ETATS( FILE.SLOT ).ID ).IN_POS + 1;
        ITEM := BUFS( ETATS( FILE.SLOT ).ID ).DATA( BUFS( ETATS( FILE.SLOT ).ID ).IN_POS );
      end if;
    end if;

  end	LIRE_PHYSIQUE;
	-------------


			---------------
  procedure		SUIVANT_LOGIQUE	( FILE :in FILE_TYPE; FIN :out BOOLEAN )		-- ajoute a la file LOOK le caractere
  is			---------------						-- logique suivant ; FIN : il n'y en a plus

    S		:constant INTEGER	:= FILE.SLOT;
    CH		: CHARACTER;

  begin
    if  not ETATS( S ).FIN_PHYSIQUE  then
      loop
        LIRE_PHYSIQUE( FILE, CH );
        exit when  ETATS( S ).FIN_PHYSIQUE;
        if  CH /= ASCII.CR  then									-- CR LF : un seul terminateur de ligne
	ETATS( S ).NB_LOOK := ETATS( S ).NB_LOOK + 1;
	ETATS( S ).LOOK( ETATS( S ).NB_LOOK ) := CH;
	ETATS( S ).DERNIER := CH;
	FIN := FALSE;
	return;
        end if;
      end loop;
    end if;

    if  ETATS( S ).DERNIER = ASCII.FF  then								-- fichier bien termine : LF FF puis fin
      FIN := TRUE;
    else												-- terminateurs implicites avant la fin
      if  ETATS( S ).DERNIER = ASCII.LF  then CH := ASCII.FF;					-- physique (fichier ecrit par un autre
      else				  CH := ASCII.LF;					-- outil, ou fichier vide)
      end if;
      ETATS( S ).NB_LOOK := ETATS( S ).NB_LOOK + 1;
      ETATS( S ).LOOK( ETATS( S ).NB_LOOK ) := CH;
      ETATS( S ).DERNIER := CH;
      FIN := FALSE;
    end if;

  end	SUIVANT_LOGIQUE;
	---------------


			-------
  procedure		REMPLIR		( FILE :in FILE_TYPE; K :in POSITIVE )			-- au moins K caracteres dans LOOK,
  is			-------								-- sauf fin logique avant
    FIN		: BOOLEAN	:= FALSE;
  begin
    while  ETATS( FILE.SLOT ).NB_LOOK < K  loop
      SUIVANT_LOGIQUE( FILE, FIN );
      exit when  FIN;
    end loop;

  end	REMPLIR;
	-------


			---------
  function		TERMINE_A		( FILE :in FILE_TYPE; K :in POSITIVE )	return BOOLEAN	-- la fin logique vient avant le
  is			---------							-- K-ieme caractere a venir
  begin
    REMPLIR( FILE, K );
    return ETATS( FILE.SLOT ).NB_LOOK < K;

  end	TERMINE_A;
	---------


			-----
  function		CAR_A		( FILE :in FILE_TYPE; K :in POSITIVE )	return CHARACTER	-- K-ieme caractere a venir, NUL
  is			-----								-- apres la fin logique
  begin
    REMPLIR( FILE, K );
    if  ETATS( FILE.SLOT ).NB_LOOK < K  then return ASCII.NUL; end if;
    return ETATS( FILE.SLOT ).LOOK( K );

  end	CAR_A;
	-----


			-------
  procedure		GET_RAW		( FILE :in FILE_TYPE; ITEM :out CHARACTER )		-- consomme un caractere logique
  is			-------

    S		:constant INTEGER	:= FILE.SLOT;
    CH		: CHARACTER;

  begin
    REMPLIR( FILE, 1 );
    if  ETATS( S ).NB_LOOK = 0  then									-- fin logique
      ETATS( S ).AT_END_OF_FILE := TRUE;
      ITEM := ASCII.NUL;
      return;
    end if;
    CH := ETATS( S ).LOOK( 1 );
    for  I in 1 .. ETATS( S ).NB_LOOK - 1  loop
      ETATS( S ).LOOK( I ) := ETATS( S ).LOOK( I + 1 );
    end loop;
    ETATS( S ).NB_LOOK := ETATS( S ).NB_LOOK - 1;

    ETATS( S ).PREC_PAGE := ETATS( S ).PAGE;								-- pour REMETTRE
    ETATS( S ).PREC_LINE := ETATS( S ).LINE;
    ETATS( S ).PREC_COL  := ETATS( S ).COL;
    if  CH = ASCII.LF  then										-- LRM 14.3.4 et 14.3.6 : terminateur de
      ETATS( S ).LINE := ETATS( S ).LINE + 1;								-- ligne, puis de page
      ETATS( S ).COL  := 1;
    elsif  CH = ASCII.FF  then
      ETATS( S ).PAGE := ETATS( S ).PAGE + 1;
      ETATS( S ).LINE := 1;
      ETATS( S ).COL  := 1;
    else
      ETATS( S ).COL  := ETATS( S ).COL + 1;
    end if;
    ITEM := CH;

  end	GET_RAW;
	-------


			--------
  procedure		REMETTRE		( FILE :in FILE_TYPE; ITEM :in CHARACTER )		-- annule le dernier GET_RAW : ITEM
  is			--------								-- redevient le prochain caractere
    S		:constant INTEGER	:= FILE.SLOT;
  begin
    for  I in reverse 1 .. ETATS( S ).NB_LOOK  loop
      ETATS( S ).LOOK( I + 1 ) := ETATS( S ).LOOK( I );
    end loop;
    ETATS( S ).LOOK( 1 ) := ITEM;
    ETATS( S ).NB_LOOK := ETATS( S ).NB_LOOK + 1;
    ETATS( S ).PAGE := ETATS( S ).PREC_PAGE;
    ETATS( S ).LINE := ETATS( S ).PREC_LINE;
    ETATS( S ).COL  := ETATS( S ).PREC_COL;
    ETATS( S ).AT_END_OF_FILE := FALSE;

  end	REMETTRE;
	--------


			-------
  procedure		AVANCER		( A	   :in out AUTOMATE_LEXEME;			-- l'automate accepte-t-il CH ? S'il
					  CH	   :in CHARACTER;				-- l'accepte, il avance ; sinon il ne
					  ACCEPTE :out BOOLEAN				-- change pas
					)
  is			-------

    P		: PHASE_LEXEME	:= A.PHASE;
    OK		: BOOLEAN		:= TRUE;

    function	CHIFFRE	( C :CHARACTER )	return BOOLEAN
    is
    begin
      return  C >= '0'  and then  C <= '9';
    end	CHIFFRE;

    function	ETENDU	( C :CHARACTER )	return BOOLEAN			-- LRM 2.4.2 : chiffre etendu ; sa valeur
    is										-- est controlee a la conversion
    begin
      return  CHIFFRE( C )  or else  ( C >= 'A'  and then  C <= 'F' )
			or else  ( C >= 'a'  and then  C <= 'f' );
    end	ETENDU;

    function	LETTRE	( C :CHARACTER )	return BOOLEAN
    is
    begin
      return  ( C >= 'A'  and then  C <= 'Z' )  or else  ( C >= 'a'  and then  C <= 'z' );
    end	LETTRE;

    function	EXPOSANT	( C :CHARACTER )	return BOOLEAN
    is
    begin
      return  C = 'E'  or else  C = 'e';
    end	EXPOSANT;

  begin
    case  A.PHASE  is
      when P_DEBUT =>
        if  A.GENRE = LEX_ENUM  then
	if    LETTRE( CH )  then P := P_ID;
	elsif CH = '''    then P := P_CAR_OUVERT;
	else			   OK := FALSE;
	end if;
        elsif  CH = '+'  or else  CH = '-'  then P := P_SIGNE;
        elsif  CHIFFRE( CH )		    then P := P_ENT;
        else					 OK := FALSE;
        end if;
      when P_SIGNE =>
        if  CHIFFRE( CH )  then P := P_ENT; else OK := FALSE; end if;
      when P_ENT =>
        if    CHIFFRE( CH )			  then null;
        elsif CH = '_'			  then P := P_ENT_SOUL;
        elsif CH = '#'  or else  CH = ':'	  then P := P_OUVERT;
        elsif CH = '.'  and then  A.GENRE = LEX_REEL then P := P_PT;
        elsif EXPOSANT( CH )  and then  A.GENRE = LEX_ENTIER then P := P_EXP;			-- reel : point avant l'exposant
        else					       OK := FALSE;
        end if;
      when P_ENT_SOUL =>
        if  CHIFFRE( CH )  then P := P_ENT; else OK := FALSE; end if;
      when P_OUVERT =>
        if  ETENDU( CH )  then P := P_BASE; else OK := FALSE; end if;
      when P_BASE =>
        if    ETENDU( CH )			  then null;
        elsif CH = '_'			  then P := P_BASE_SOUL;
        elsif CH = A.DELIM  and then  A.GENRE = LEX_ENTIER then P := P_FERME;			-- reel : point avant le # fermant
        elsif CH = '.'  and then  A.GENRE = LEX_REEL then P := P_BASE_PT;
        else					       OK := FALSE;
        end if;
      when P_BASE_SOUL =>
        if  ETENDU( CH )  then P := P_BASE; else OK := FALSE; end if;
      when P_BASE_PT =>
        if  ETENDU( CH )  then P := P_BASE_FR; else OK := FALSE; end if;
      when P_BASE_FR =>
        if    ETENDU( CH )	then null;
        elsif CH = '_'	then P := P_BASE_FR_SOUL;
        elsif CH = A.DELIM	then P := P_FERME;
        else		     OK := FALSE;
        end if;
      when P_BASE_FR_SOUL =>
        if  ETENDU( CH )  then P := P_BASE_FR; else OK := FALSE; end if;
      when P_FERME =>
        if  EXPOSANT( CH )  then P := P_EXP; else OK := FALSE; end if;
      when P_PT =>
        if  CHIFFRE( CH )  then P := P_FR; else OK := FALSE; end if;
      when P_FR =>
        if    CHIFFRE( CH )	then null;
        elsif CH = '_'	then P := P_FR_SOUL;
        elsif EXPOSANT( CH )	then P := P_EXP;
        else		     OK := FALSE;
        end if;
      when P_FR_SOUL =>
        if  CHIFFRE( CH )  then P := P_FR; else OK := FALSE; end if;
      when P_EXP =>										-- LRM 2.4.1 : le signe - d'un exposant
        if    CH = '+'  or else  CH = '-'	then P := P_EXP_SIGNE;					-- d'entier est refuse a la conversion
        elsif CHIFFRE( CH )		then P := P_EXP_CH;
        else				     OK := FALSE;
        end if;
      when P_EXP_SIGNE =>
        if  CHIFFRE( CH )  then P := P_EXP_CH; else OK := FALSE; end if;
      when P_EXP_CH =>
        if    CHIFFRE( CH )  then null;
        elsif CH = '_'     then P := P_EXP_SOUL;
        else		  OK := FALSE;
        end if;
      when P_EXP_SOUL =>
        if  CHIFFRE( CH )  then P := P_EXP_CH; else OK := FALSE; end if;
      when P_ID =>
        if    LETTRE( CH )  or else  CHIFFRE( CH )  then null;
        elsif CH = '_'				then P := P_ID_SOUL;
        else					     OK := FALSE;
        end if;
      when P_ID_SOUL =>
        if  LETTRE( CH )  or else  CHIFFRE( CH )  then P := P_ID; else OK := FALSE; end if;
      when P_CAR_OUVERT =>									-- LRM 2.5 : caractere graphique
        if  CHARACTER'POS( CH ) >= 32  and then  CHARACTER'POS( CH ) <= 126  then P := P_CAR;
        else										     OK := FALSE;
        end if;
      when P_CAR =>
        if  CH = '''  then P := P_CAR_FERME; else OK := FALSE; end if;
      when P_CAR_FERME =>
        OK := FALSE;
    end case;

    if  OK  then
      if  P = P_OUVERT  then A.DELIM := CH; end if;
      if  P = P_PT  or else  P = P_BASE_PT  then A.POINT := TRUE; end if;
      A.PHASE := P;
    end if;
    ACCEPTE := OK;

  end	AVANCER;
	-------


			-------
  function		COMPLET		( A :in AUTOMATE_LEXEME )	return BOOLEAN		-- le prefixe lu est un lexeme entier
  is			-------
  begin
    case  A.GENRE  is
      when LEX_ENTIER =>
        return  not A.POINT  and then
	  ( A.PHASE = P_ENT  or else  A.PHASE = P_FERME  or else  A.PHASE = P_EXP_CH );
      when LEX_REEL =>
        return  A.POINT  and then
	  ( A.PHASE = P_FR  or else  A.PHASE = P_FERME  or else  A.PHASE = P_EXP_CH );
      when LEX_ENUM =>
        return  A.PHASE = P_ID  or else  A.PHASE = P_CAR_FERME;
    end case;

  end	COMPLET;
	-------


			-----------
  procedure		LIRE_LEXEME	( FILE   :in FILE_TYPE;				-- GET sur fichier, LRM 14.3.5 : collecte
					  WIDTH  :in FIELD;					-- le champ dans TAMPON( 1 .. LONG )
					  GENRE  :in GENRE_LEXEME;
					  TAMPON :out STRING;
					  LONG   :out NATURAL
					)
  is			-----------

    A		: AUTOMATE_LEXEME	:= ( GENRE => GENRE, PHASE => P_DEBUT, DELIM => '#', POINT => FALSE );
    CH		: CHARACTER;
    OK		: BOOLEAN;
    L		: NATURAL		:= 0;
    TROP		: BOOLEAN		:= FALSE;

  begin
    if  WIDTH = 0  then
      loop											-- blancs et terminateurs sautes ;
        if  TERMINE_A( FILE, 1 )  then raise END_ERROR; end if;					-- END_ERROR sur le terminateur de fichier
        CH := CAR_A( FILE, 1 );
        exit when  CH /= ' '  and then  CH /= ASCII.HT
		and then  CH /= ASCII.LF  and then  CH /= ASCII.FF;
        GET_RAW( FILE, CH );
      end loop;
      loop											-- plus long prefixe de la syntaxe
        exit when  TERMINE_A( FILE, 1 );
        AVANCER( A, CAR_A( FILE, 1 ), OK );
        exit when  not OK;
        GET_RAW( FILE, CH );
        if  L < TAMPON'LENGTH  then L := L + 1; TAMPON( TAMPON'FIRST + L - 1 ) := CH;
        else			      TROP := TRUE;
        end if;
      end loop;
    else
      if  TERMINE_A( FILE, 1 )  then raise END_ERROR; end if;
      loop											-- WIDTH caracteres au plus, sans franchir
        exit when  L >= WIDTH;										-- un terminateur de ligne (blancs de tete
        exit when  TERMINE_A( FILE, 1 )								-- compris)
	or else  CAR_A( FILE, 1 ) = ASCII.LF  or else  CAR_A( FILE, 1 ) = ASCII.FF;
        GET_RAW( FILE, CH );
        if  L < TAMPON'LENGTH  then L := L + 1; TAMPON( TAMPON'FIRST + L - 1 ) := CH;
        else			      TROP := TRUE; exit;
        end if;
      end loop;
    end if;
    if  TROP  then raise DATA_ERROR; end if;							-- lexeme plus long que MAX_LEXEME
    LONG := L;

  end	LIRE_LEXEME;
	-----------


			--------
  procedure		ANALYSER		( FROM  :in STRING;					-- GET sur chaine, LRM 14.3.5 : blancs
					  GENRE :in GENRE_LEXEME;				-- sautes (END_ERROR s'il n'y a qu'eux),
					  DEBUT :out INTEGER;				-- puis lexeme FROM( DEBUT .. FIN )
					  FIN   :out INTEGER
					)
  is			--------

    A		: AUTOMATE_LEXEME	:= ( GENRE => GENRE, PHASE => P_DEBUT, DELIM => '#', POINT => FALSE );
    P		: INTEGER		:= FROM'FIRST;
    K		: INTEGER;
    OK		: BOOLEAN;

  begin
    while  P <= FROM'LAST  and then  ( FROM( P ) = ' '  or else  FROM( P ) = ASCII.HT )  loop
      P := P + 1;
    end loop;
    if  P > FROM'LAST  then raise END_ERROR; end if;
    K := P;
    while  K <= FROM'LAST  loop
      AVANCER( A, FROM( K ), OK );
      exit when  not OK;
      K := K + 1;
    end loop;
    if  not COMPLET( A )  then raise DATA_ERROR; end if;
    DEBUT := P;
    FIN   := K - 1;

  end	ANALYSER;
	--------


			-----------
  procedure		FIN_DE_CHAMP	( CHAMP :in STRING; DERNIER :in INTEGER )			-- WIDTH > 0 : apres le lexeme, des
  is			-----------								-- blancs seulement
  begin
    for  I in DERNIER + 1 .. CHAMP'LAST  loop
      if  CHAMP( I ) /= ' '  and then  CHAMP( I ) /= ASCII.HT  then raise DATA_ERROR; end if;
    end loop;

  end	FIN_DE_CHAMP;
	-----------


			--------------
  function		VALEUR_CHIFFRE	( C :CHARACTER )		return INTEGER		-- chiffre etendu ; 99 sinon
  is			--------------
  begin
    if    C >= '0'  and then  C <= '9'  then return CHARACTER'POS( C ) - CHARACTER'POS( '0' );
    elsif C >= 'A'  and then  C <= 'F'  then return CHARACTER'POS( C ) - CHARACTER'POS( 'A' ) + 10;
    elsif C >= 'a'  and then  C <= 'f'  then return CHARACTER'POS( C ) - CHARACTER'POS( 'a' ) + 10;
    end if;
    return 99;

  end	VALEUR_CHIFFRE;
	--------------


			--------------
  function		VALEUR_ENTIERE	( S :in STRING )		return LONG_INTEGER	-- lexeme LEX_ENTIER complet ; DATA_ERROR
  is			--------------							-- si base, chiffre ou valeur hors limites

    LIM		:constant LONG_INTEGER	:= LONG_INTEGER'LAST;
    I		: INTEGER		:= S'FIRST;
    NEG		: BOOLEAN		:= FALSE;
    BASE		: LONG_INTEGER	:= 10;
    V		: LONG_INTEGER	:= 0;
    D		: LONG_INTEGER;
    E		: LONG_INTEGER	:= 0;

  begin
    if  S( I ) = '-'  then NEG := TRUE; I := I + 1;
    elsif  S( I ) = '+'  then I := I + 1;
    end if;
    while  I <= S'LAST  and then  ( S( I ) in '0' .. '9'  or else  S( I ) = '_' )  loop		-- numeral decimal
      if  S( I ) /= '_'  then
        D := LONG_INTEGER( VALEUR_CHIFFRE( S( I ) ) );
        if  V > ( LIM - D ) / 10  then raise DATA_ERROR; end if;
        V := 10 * V + D;
      end if;
      I := I + 1;
    end loop;
    if  I <= S'LAST  and then  ( S( I ) = '#'  or else  S( I ) = ':' )  then				-- litteral base : V est la base
      if  V < 2  or else  V > 16  then raise DATA_ERROR; end if;					-- LRM 2.4.2
      BASE := V;
      V := 0;
      I := I + 1;
      while  S( I ) /= '#'  and then  S( I ) /= ':'  loop
        if  S( I ) /= '_'  then
	D := LONG_INTEGER( VALEUR_CHIFFRE( S( I ) ) );
	if  D >= BASE  then raise DATA_ERROR; end if;
	if  V > ( LIM - D ) / BASE  then raise DATA_ERROR; end if;
	V := BASE * V + D;
        end if;
        I := I + 1;
      end loop;
      I := I + 1;
    end if;
    if  I <= S'LAST  then										-- exposant
      I := I + 1;
      if  S( I ) = '-'  then raise DATA_ERROR; end if;						-- LRM 2.4.1 : pas d'exposant negatif
      if  S( I ) = '+'  then I := I + 1; end if;
      while  I <= S'LAST  loop
        if  S( I ) /= '_'  then
	D := LONG_INTEGER( VALEUR_CHIFFRE( S( I ) ) );
	if  E > 10_000  then E := 10_000; else E := 10 * E + D; end if;
        end if;
        I := I + 1;
      end loop;
      if  V /= 0  then
        for  N in 1 .. E  loop
	if  V > LIM / BASE  then raise DATA_ERROR; end if;
	V := V * BASE;
        end loop;
      end if;
    end if;
    if  NEG  then return -V; end if;
    return V;

  end	VALEUR_ENTIERE;
	--------------


			-------------
  function		VALEUR_REELLE	( S :in STRING )		return LONG_FLOAT	-- lexeme LEX_REEL complet, pour FIXED_IO :
  is			-------------							-- accumulation en flottant (inexacte,
											-- comme avant le lot 39 ; a reprendre)
    I		: INTEGER		:= S'FIRST;
    NEG		: BOOLEAN		:= FALSE;
    BASE		: INTEGER		:= 10;
    B		: INTEGER		:= 0;
    V		: LONG_FLOAT	:= 0.0;
    D		: INTEGER;
    FRAC		: INTEGER		:= 0;
    APRES_POINT	: BOOLEAN		:= FALSE;
    E		: INTEGER		:= 0;
    E_NEG		: BOOLEAN		:= FALSE;
    BASEE		: BOOLEAN		:= FALSE;

  begin
    if  S( I ) = '-'  then NEG := TRUE; I := I + 1;
    elsif  S( I ) = '+'  then I := I + 1;
    end if;
    declare
      J	: INTEGER	:= I;
    begin
      while  J <= S'LAST  and then  ( S( J ) in '0' .. '9'  or else  S( J ) = '_' )  loop
        if  S( J ) /= '_'  and then  B <= 16  then B := 10 * B + VALEUR_CHIFFRE( S( J ) ); end if;
        J := J + 1;
      end loop;
      if  J <= S'LAST  and then  ( S( J ) = '#'  or else  S( J ) = ':' )  then
        if  B < 2  or else  B > 16  then raise DATA_ERROR; end if;					-- LRM 2.4.2
        BASE  := B;
        BASEE := TRUE;
        I := J + 1;
      end if;
    end;
    while  I <= S'LAST  loop										-- mantisse
      exit when  S( I ) = '#'  or else  S( I ) = ':'
	or else  ( not BASEE  and then  ( S( I ) = 'E'  or else  S( I ) = 'e' ) );
      if  S( I ) = '.'  then
        APRES_POINT := TRUE;
      elsif  S( I ) /= '_'  then
        D := VALEUR_CHIFFRE( S( I ) );
        if  D >= BASE  then raise DATA_ERROR; end if;
        V := V * LONG_FLOAT( BASE ) + LONG_FLOAT( D );
        if  APRES_POINT  then FRAC := FRAC + 1; end if;
      end if;
      I := I + 1;
    end loop;
    if  BASEE  then I := I + 1; end if;								-- delimiteur fermant
    if  I <= S'LAST  then										-- exposant : puissance de la base
      I := I + 1;
      if    S( I ) = '-'  then E_NEG := TRUE; I := I + 1;
      elsif S( I ) = '+'  then I := I + 1;
      end if;
      while  I <= S'LAST  loop
        if  S( I ) /= '_'  then
	if  E < 10_000  then E := 10 * E + VALEUR_CHIFFRE( S( I ) ); end if;
        end if;
        I := I + 1;
      end loop;
    end if;
    if  E_NEG  then E := -E; end if;
    E := E - FRAC;
    if  V /= 0.0  then
      if  E > 0  then
        for  N in 1 .. E  loop
	if  V > LONG_FLOAT'LAST / LONG_FLOAT( BASE )  then raise DATA_ERROR; end if;
	V := V * LONG_FLOAT( BASE );
        end loop;
      else
        for  N in 1 .. -E  loop
	V := V / LONG_FLOAT( BASE );
        end loop;
      end if;
    end if;
    if  NEG  then return -V; end if;
    return V;

  end	VALEUR_REELLE;
	-------------


			-------------
  procedure		DEBUT_ELEMENT	( FILE :in FILE_TYPE )					-- ligne bornee : capter l'element
  is			-------------
  begin
    if  ETATS( FILE.SLOT ).IS_OPENED  and then  ETATS( FILE.SLOT ).MODE = OUT_FILE
      and then  ETATS( FILE.SLOT ).LINE_LENGTH /= 0
    then
      CAPTE_SLOT := FILE.SLOT;
      CAPTE_LEN  := 0;
    end if;

  end	DEBUT_ELEMENT;
	-------------


			-----------
  procedure		FIN_ELEMENT		( FILE :in FILE_TYPE )					-- LRM 14.3.5 : l'element capte est ecrit
  is			-----------								-- s'il tient dans une ligne
  begin
    if  CAPTE_SLOT = FILE.SLOT  then
      CAPTE_SLOT := -2;
      if  COUNT( CAPTE_LEN ) > ETATS( FILE.SLOT ).LINE_LENGTH  then raise LAYOUT_ERROR; end if;
      if  ETATS( FILE.SLOT ).COL + COUNT( CAPTE_LEN ) - 1 > ETATS( FILE.SLOT ).LINE_LENGTH  then
        NEW_LINE( FILE );										-- pas la place dans le reste de la ligne
      end if;
      PUT( FILE, CAPTE( 1 .. CAPTE_LEN ) );
    end if;

  end	FIN_ELEMENT;
	-----------


			---------------
  procedure		ABANDON_ELEMENT							-- exception pendant l'element : rien
  is			---------------							-- n'est ecrit
  begin
    CAPTE_SLOT := -2;

  end	ABANDON_ELEMENT;
	---------------


			--------------
  function		IMAGE_EXPOSANT	( E :in NATURAL; EXP :in FIELD )	return STRING		-- LRM 14.3.8 : exposant de EXP - 1
  is			--------------							-- chiffres au moins (EXP compte le signe)
    B		: STRING( 1 .. 40 )	:= ( others => '0' );
    P		: INTEGER		:= B'LAST + 1;
    V		: NATURAL		:= E;
  begin
    loop
      P := P - 1;
      B( P ) := CHARACTER'VAL( CHARACTER'POS( '0' ) + V mod 10 );
      V := V / 10;
      exit when  V = 0;
    end loop;
    while  B'LAST - P + 1 < EXP - 1  and then  P > B'FIRST  loop					-- zeros de tete
      P := P - 1;
    end loop;
    return  B( P .. B'LAST );

  end	IMAGE_EXPOSANT;
	--------------


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
    if  ETATS( FILE.SLOT ).ID = -1  then										-- standard console output
      ASM_OP_2'( OPCODE => LB, LVL => 1, OFS => -16 );
      ASM_OP_0'( OPCODE => SYS_PUT_CHAR );

    elsif  ETATS( FILE.SLOT ).ID > MAX_BUF_ID  then									-- descripteur hors table : ancien chemin
      ERR_CODE := WRITE_SYSTEM_CALL( ETATS( FILE.SLOT ).ID );								-- general file

    else												-- fichier tamponne
      if  BUFS( ETATS( FILE.SLOT ).ID ).OUT_LEN = BUF_SIZE  then
        FLUSH_OUT( ETATS( FILE.SLOT ).ID );
      end if;
      BUFS( ETATS( FILE.SLOT ).ID ).OUT_LEN := BUFS( ETATS( FILE.SLOT ).ID ).OUT_LEN + 1;
      BUFS( ETATS( FILE.SLOT ).ID ).DATA( BUFS( ETATS( FILE.SLOT ).ID ).OUT_LEN ) := ITEM;
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
    if  ETATS( FILE.SLOT ).ID = -1  then
      ASM_OP_2'( OPCODE => LA, LVL => 1, OFS => -16 );
      ASM_OP_0'( OPCODE => SYS_PUT_STR );

    elsif  ETATS( FILE.SLOT ).ID > MAX_BUF_ID  then									-- descripteur hors table : ancien chemin
      ERR_CODE := WRITE_SYSTEM_CALL( ETATS( FILE.SLOT ).ID, ITEM'LENGTH );

    else												-- fichier tamponne
      if  ITEM'LENGTH > BUF_SIZE - BUFS( ETATS( FILE.SLOT ).ID ).OUT_LEN  then					-- ne tient pas derriere ce qui attend
        FLUSH_OUT( ETATS( FILE.SLOT ).ID );
      end if;
      if  ITEM'LENGTH > BUF_SIZE  then									-- ne tiendra jamais : ecriture directe
        WRITE_RAW( ETATS( FILE.SLOT ).ID, ITEM );
      else
        BUFS( ETATS( FILE.SLOT ).ID ).DATA( BUFS( ETATS( FILE.SLOT ).ID ).OUT_LEN + 1 .. BUFS( ETATS( FILE.SLOT ).ID ).OUT_LEN + ITEM'LENGTH ) := ITEM;
        BUFS( ETATS( FILE.SLOT ).ID ).OUT_LEN := BUFS( ETATS( FILE.SLOT ).ID ).OUT_LEN + ITEM'LENGTH;
      end if;
    end if;

  end	PUT_RAW;
	-------


			---------------
  procedure		TERMINER_FICHIER	( FILE :in FILE_TYPE )				-- CLOSE, RESET d'un OUT_FILE
  is			---------------
  begin
    -- LRM 14.3.1 : NEW_PAGE sauf si la page courante est deja
    -- terminee, puis terminateur de fichier. Representation : le
    -- terminateur de page qui precede immediatement la fin physique
    -- n'est pas ecrit, la lecture le retablit (SUIVANT_LOGIQUE) ; seul
    -- le terminateur de ligne l'est. Ainsi un texte se termine par LF,
    -- comme sous Unix, et fasmg (qui refuse FF) lit les .FINC.
    if  not PAGE_TERMINEE( FILE )
      and then  ( ETATS( FILE.SLOT ).COL > 1  or else  ETATS( FILE.SLOT ).LINE = 1 )  then
      PUT_RAW( FILE, ASCII.LF );
    end if;

  end	TERMINER_FICHIER;
	---------------



			-- Specification of line and page lengths


			---------------
  procedure		SET_LINE_LENGTH	( FILE :in FILE_TYPE; TO :in COUNT )
  is			---------------
  begin
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  ETATS( FILE.SLOT ).MODE /= OUT_FILE  then raise MODE_ERROR; end if;
    ETATS( FILE.SLOT ).LINE_LENGTH := TO;

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
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  ETATS( FILE.SLOT ).MODE /= OUT_FILE  then raise MODE_ERROR; end if;
    ETATS( FILE.SLOT ).PAGE_LENGTH := TO;
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
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  ETATS( FILE.SLOT ).MODE /= OUT_FILE  then raise MODE_ERROR; end if;
    return ETATS( FILE.SLOT ).LINE_LENGTH;

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
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  ETATS( FILE.SLOT ).MODE /= OUT_FILE  then raise MODE_ERROR; end if;
    return ETATS( FILE.SLOT ).PAGE_LENGTH;

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
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  ETATS( FILE.SLOT ).MODE /= OUT_FILE  then raise MODE_ERROR; end if;

    for  N in 1 .. SPACING  loop									-- LRM 14.3.4 : SPACING fois
      PUT_RAW( FILE, ASCII.LF );									-- terminateur de ligne : LF seul
      ETATS( FILE.SLOT ).COL := 1;
      if  ETATS( FILE.SLOT ).PAGE_LENGTH /= 0
	and then  ETATS( FILE.SLOT ).LINE >= ETATS( FILE.SLOT ).PAGE_LENGTH  then		-- page bornee pleine : terminateur
        PUT_RAW( FILE, ASCII.FF );									-- de page
        ETATS( FILE.SLOT ).PAGE := ETATS( FILE.SLOT ).PAGE + 1;
        ETATS( FILE.SLOT ).LINE := 1;
      else
        ETATS( FILE.SLOT ).LINE := ETATS( FILE.SLOT ).LINE + 1;
      end if;
    end loop;

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

  begin
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  ETATS( FILE.SLOT ).MODE /= IN_FILE  then raise MODE_ERROR; end if;

    for  N in 1 .. SPACING  loop									-- LRM 14.3.4 : SPACING fois
      loop											-- jusqu'au terminateur de ligne compris
        if  TERMINE_A( FILE, 1 )  then raise END_ERROR; end if;					-- LRM 14.3.4 : terminateur de fichier
        GET_RAW( FILE, CH );
        exit when  CH = ASCII.LF  or else  CH = ASCII.FF;
      end loop;
      if  CH = ASCII.LF  and then  CAR_A( FILE, 1 ) = ASCII.FF  then				-- suivi d'un terminateur de page :
        GET_RAW( FILE, CH );									-- saute aussi (PAGE + 1, LINE := 1)
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
  begin
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  ETATS( FILE.SLOT ).MODE /= IN_FILE  then raise MODE_ERROR; end if;
    return  TERMINE_A( FILE, 1 )									-- LRM 14.3.4 : terminateur de ligne
	or else  CAR_A( FILE, 1 ) = ASCII.LF								-- ou de fichier au prochain caractere
	or else  CAR_A( FILE, 1 ) = ASCII.FF;

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
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  ETATS( FILE.SLOT ).MODE /= OUT_FILE  then raise MODE_ERROR; end if;

    if  ETATS( FILE.SLOT ).COL > 1  or else  ETATS( FILE.SLOT ).LINE = 1  then			-- LRM 14.3.4 : ligne non terminee
      PUT_RAW( FILE, ASCII.LF );									-- ou page vide : terminateur de ligne
    end if;
    PUT_RAW( FILE, ASCII.FF );										-- puis terminateur de page
    ETATS( FILE.SLOT ).PAGE := ETATS( FILE.SLOT ).PAGE + 1;
    ETATS( FILE.SLOT ).LINE := 1;
    ETATS( FILE.SLOT ).COL  := 1;

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
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  ETATS( FILE.SLOT ).MODE /= IN_FILE  then raise MODE_ERROR; end if;
    loop												-- LRM 14.3.4 : jusqu'au terminateur
      if  TERMINE_A( FILE, 1 )  then raise END_ERROR; end if;						-- de page compris ; END_ERROR sur le
      GET_RAW( FILE, CH );										-- terminateur de fichier
      exit when  CH = ASCII.FF;
    end loop;

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
  begin
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  ETATS( FILE.SLOT ).MODE /= IN_FILE  then raise MODE_ERROR; end if;
    if  TERMINE_A( FILE, 1 )  or else  CAR_A( FILE, 1 ) = ASCII.FF  then return TRUE; end if;		-- LRM 14.3.4 : terminateur de ligne
    return  CAR_A( FILE, 1 ) = ASCII.LF									-- suivi d'un terminateur de page, ou
	and then  ( TERMINE_A( FILE, 2 )  or else  CAR_A( FILE, 2 ) = ASCII.FF );			-- terminateur de fichier

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
  begin
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  ETATS( FILE.SLOT ).MODE /= IN_FILE  then raise MODE_ERROR; end if;
    if  TERMINE_A( FILE, 1 )  then return TRUE; end if;							-- LRM 14.3.4 : terminateur de ligne,
    if  CAR_A( FILE, 1 ) = ASCII.FF  then return TERMINE_A( FILE, 2 ); end if;			-- de page, puis de fichier ; ou
    return  CAR_A( FILE, 1 ) = ASCII.LF								-- terminateur de fichier
	and then  ( TERMINE_A( FILE, 2 )
		  or else  ( CAR_A( FILE, 2 ) = ASCII.FF  and then  TERMINE_A( FILE, 3 ) ) );

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

    CH		: CHARACTER;

  begin
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;

    if  ETATS( FILE.SLOT ).MODE /= IN_FILE  then
      -- Sortie, LRM 14.3.4(29-31) : espaces jusqu'a la colonne TO ;
      -- si TO est en arriere, terminateur de ligne d'abord.
      if  ETATS( FILE.SLOT ).LINE_LENGTH /= 0  and then  TO > ETATS( FILE.SLOT ).LINE_LENGTH  then
        raise LAYOUT_ERROR;								-- LRM 14.3.4(31)
      end if;
      if  TO < ETATS( FILE.SLOT ).COL  then
        NEW_LINE( FILE );
      end if;
      while  ETATS( FILE.SLOT ).COL < TO  loop
        PUT_RAW( FILE, ' ' );
        ETATS( FILE.SLOT ).COL := ETATS( FILE.SLOT ).COL + 1;
      end loop;
    elsif  ETATS( FILE.SLOT ).COL /= TO  then
      -- Entree, LRM 14.3.4(32-33) : lit et jette caracteres et
      -- terminateurs jusqu'a ce que le prochain caractere soit a la
      -- colonne TO (les lignes trop courtes sont sautees) ; END_ERROR
      -- sur le terminateur de fichier.
      loop
        exit when  ETATS( FILE.SLOT ).COL = TO
	and then  not TERMINE_A( FILE, 1 )
	and then  CAR_A( FILE, 1 ) /= ASCII.LF
	and then  CAR_A( FILE, 1 ) /= ASCII.FF;
        if  TERMINE_A( FILE, 1 )  then raise END_ERROR; end if;
        GET_RAW( FILE, CH );
      end loop;
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

    CH		: CHARACTER;

  begin
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;

    if  ETATS( FILE.SLOT ).MODE /= IN_FILE  then
      -- Sortie, LRM 14.3.4(36-38) : NEW_LINE jusqu'a la ligne TO ;
      -- si TO est en arriere, terminateur de page d'abord.
      if  ETATS( FILE.SLOT ).PAGE_LENGTH /= 0  and then  TO > ETATS( FILE.SLOT ).PAGE_LENGTH  then
        raise LAYOUT_ERROR;								-- LRM 14.3.4(38)
      end if;
      if  TO < ETATS( FILE.SLOT ).LINE  then
        NEW_PAGE( FILE );
      end if;
      while  ETATS( FILE.SLOT ).LINE < TO  loop
        NEW_LINE( FILE );
      end loop;
    elsif  ETATS( FILE.SLOT ).LINE /= TO  then
      -- Entree, LRM 14.3.4(39-40) : lit et jette caracteres et
      -- terminateurs jusqu'a la ligne TO ; END_ERROR sur le
      -- terminateur de fichier.
      loop											-- une ligne TO qui n'est qu'un LF suivi
        exit when  ETATS( FILE.SLOT ).LINE = TO						-- de FF n'existe pas : on continue
	and then  not TERMINE_A( FILE, 1 )
	and then  CAR_A( FILE, 1 ) /= ASCII.FF;
        if  TERMINE_A( FILE, 1 )  then raise END_ERROR; end if;
        GET_RAW( FILE, CH );
      end loop;
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
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  ETATS( FILE.SLOT ).COL > COUNT'LAST  then raise LAYOUT_ERROR; end if;
    return ETATS( FILE.SLOT ).COL;

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
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  ETATS( FILE.SLOT ).LINE > COUNT'LAST  then raise LAYOUT_ERROR; end if;
    return ETATS( FILE.SLOT ).LINE;

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
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  ETATS( FILE.SLOT ).PAGE > COUNT'LAST  then raise LAYOUT_ERROR; end if;
    return ETATS( FILE.SLOT ).PAGE;

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
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  ETATS( FILE.SLOT ).MODE /= IN_FILE  then raise MODE_ERROR; end if;

    -- LRM 14.3.6(4-5) : saute les terminateurs de ligne et de page en
    -- tenant LINE/COL/PAGE a jour ; leve END_ERROR sur le terminateur
    -- de fichier. La lecture physique est deleguee a GET_RAW.
    loop
      if  TERMINE_A( FILE, 1 )  then raise END_ERROR; end if;
      GET_RAW( FILE, CH );									-- compteurs tenus par GET_RAW
      exit when  CH /= ASCII.LF  and then  CH /= ASCII.FF;
    end loop;
    ITEM := CH;

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
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  ETATS( FILE.SLOT ).MODE /= OUT_FILE  then raise MODE_ERROR; end if;

    if  CAPTE_SLOT = FILE.SLOT  then									-- element en cours de capture
      if  CAPTE_LEN >= MAX_CAPTE  then
        CAPTE_SLOT := -2;
        raise LAYOUT_ERROR;										-- plus long que toute ligne bornee admise
      end if;
      CAPTE_LEN := CAPTE_LEN + 1;
      CAPTE( CAPTE_LEN ) := ITEM;
      return;
    end if;

    -- LRM 14.3.6(4) : coupure implicite si la longueur de ligne est
    -- bornee et que la colonne courante la depasse.
    if  ETATS( FILE.SLOT ).LINE_LENGTH /= 0  and then  ETATS( FILE.SLOT ).COL > ETATS( FILE.SLOT ).LINE_LENGTH  then
      NEW_LINE( FILE );
    end if;
    PUT_RAW( FILE, ITEM );
    ETATS( FILE.SLOT ).COL := ETATS( FILE.SLOT ).COL + 1;

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
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  ETATS( FILE.SLOT ).MODE /= OUT_FILE  then raise MODE_ERROR; end if;

    if  ETATS( FILE.SLOT ).LINE_LENGTH /= 0  then
      -- Ligne bornee : caractere par caractere pour beneficier des
      -- coupures implicites du PUT public (LRM 14.3.6(4)).
      for  I  in  ITEM'FIRST .. ITEM'LAST  loop
        PUT( FILE, ITEM( I ) );
      end loop;
    else
      -- Ligne non bornee : ecriture en bloc, comptabilite de colonne.
      PUT_RAW( FILE, ITEM );
      ETATS( FILE.SLOT ).COL := ETATS( FILE.SLOT ).COL + COUNT( ITEM'LENGTH );
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
    DERNIER	: INTEGER;										-- LAST est en mode out : non relu

  begin
    if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
    if  ETATS( FILE.SLOT ).MODE /= IN_FILE  then raise MODE_ERROR; end if;
    if  ETATS( FILE.SLOT ).ID = -1  then										-- standard console input : utiliser SYS_GET_STR (mode canonique avec echo)
      ASM_OP_2'( OPCODE => La, LVL => 1, OFS => -24 );							-- push @LAST  (adresse du parametre out LAST)
      ASM_OP_2'( OPCODE => La, LVL => 1, OFS => -16 );							-- push @ITEM descripteur (adresse du parametre out ITEM = descripteur string)
      ASM_OP_0'( OPCODE => SYS_GET_STR );								-- lit une ligne stdin avec echo, stocke longueur dans LAST
    else
      DERNIER := ITEM'FIRST - 1;									-- chaine nulle : rien lu, pas d'END_ERROR
      loop
        exit when  POS > ITEM'LAST;									-- chaine pleine : terminateur non lu
        if  TERMINE_A( FILE, 1 )  then raise END_ERROR; end if;
        if  CAR_A( FILE, 1 ) = ASCII.LF  then								-- fin de ligne : SKIP_LINE( 1 )
	SKIP_LINE( FILE, 1 );
	exit;
        end if;
        if  CAR_A( FILE, 1 ) = ASCII.FF  then								-- terminateur de page isole
	GET_RAW( FILE, CH );
	exit;
        end if;
        GET_RAW( FILE, CH );
        ITEM( POS ) := CH;
        DERNIER := POS;
        POS := POS + 1;
      end loop;
      LAST := DERNIER;
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

      TAMPON		: STRING( 1 .. MAX_LEXEME );
      LONG		: NATURAL;
      V			: NUM;
      DERNIER		: POSITIVE;

    begin
      if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
      if  ETATS( FILE.SLOT ).MODE /= IN_FILE  then raise MODE_ERROR; end if;

      LIRE_LEXEME( FILE, WIDTH, LEX_ENTIER, TAMPON, LONG );						-- LRM 14.3.7 : lexeme du fichier,
      begin												-- converti par le GET sur chaine
        GET( TAMPON( 1 .. LONG ), V, DERNIER );
      exception
        when END_ERROR =>  raise DATA_ERROR;								-- champ blanc ou vide
      end;
      FIN_DE_CHAMP( TAMPON( 1 .. LONG ), DERNIER );
      ITEM := V;											-- ITEM intact en cas d'erreur

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
      if  ITEM < NUM'FIRST  or else  ITEM > NUM'LAST  then						-- LRM 6.4.1 : ITEM hors du sous-type NUM
        raise CONSTRAINT_ERROR;									-- (controle que l'appel d'une instance omet)
      end if;
      DEBUT_ELEMENT( FILE );										-- LRM 14.3.5 : LAYOUT_ERROR, NEW_LINE
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


      FIN_ELEMENT( FILE );

    exception
      when others =>												-- rien n'est ecrit
        ABANDON_ELEMENT;
        raise;
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

      DEBUT, FIN		: INTEGER;
      VAL		: LONG_INTEGER;

    begin
      ANALYSER( FROM, LEX_ENTIER, DEBUT, FIN );							-- END_ERROR, DATA_ERROR (syntaxe)
      VAL := VALEUR_ENTIERE( FROM( DEBUT .. FIN ) );							-- DATA_ERROR (base, chiffre, valeur)
      if  VAL < LONG_INTEGER( NUM'FIRST )  or else  VAL > LONG_INTEGER( NUM'LAST )  then
        raise DATA_ERROR;										-- LRM 14.3.7 : hors du sous-type NUM
      end if;
      ITEM := NUM( VAL );
      LAST := FIN;

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

      TAMPON		: STRING( 1 .. MAX_LEXEME );
      LONG		: NATURAL;
      V			: NUM;
      DERNIER		: POSITIVE;

    begin
      if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
      if  ETATS( FILE.SLOT ).MODE /= IN_FILE  then raise MODE_ERROR; end if;

      LIRE_LEXEME( FILE, WIDTH, LEX_REEL, TAMPON, LONG );						-- LRM 14.3.8 : lexeme du fichier,
      begin												-- converti par le GET sur chaine
        GET( TAMPON( 1 .. LONG ), V, DERNIER );
      exception
        when END_ERROR =>  raise DATA_ERROR;								-- champ blanc ou vide
      end;
      FIN_DE_CHAMP( TAMPON( 1 .. LONG ), DERNIER );
      ITEM := V;											-- ITEM intact en cas d'erreur

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

      AFT_EFF		: FIELD		:= AFT + BOOLEAN'POS( AFT = 0 );		-- LRM 14.3.8 : un chiffre au moins apres le point

      VAL		: NUM		:= ITEM;
      IS_NEGATIVE	: BOOLEAN		:= ITEM < 0.0;
      E		: INTEGER		:= 0;
      DIGIT	: INTEGER;
      FORE_LEN	: NATURAL;

    begin
      DEBUT_ELEMENT( FILE );										-- LRM 14.3.5 : LAYOUT_ERROR, NEW_LINE
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
        for  I in  1 .. AFT_EFF  loop
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
      for  I in 1 .. AFT_EFF  loop
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
        PUT( FILE, IMAGE_EXPOSANT( E, EXP ) );								-- LRM 14.3.8 : EXP compte le signe
      end if;


      FIN_ELEMENT( FILE );

    exception
      when others =>												-- rien n'est ecrit
        ABANDON_ELEMENT;
        raise;
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
    procedure		CONVERTIR		( FROM :in STRING; ITEM :out NUM; LAST :out POSITIVE )	-- litteral reel exact
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

    end	CONVERTIR;
	---------


			---
    procedure		GET		( FROM :in STRING; ITEM :out NUM; LAST :out POSITIVE )		-- LRM 14.3.8
    is			---

      DEBUT, FIN		: INTEGER;
      V			: NUM;
      L			: POSITIVE;

    begin
      ANALYSER( FROM, LEX_REEL, DEBUT, FIN );							-- END_ERROR, DATA_ERROR (syntaxe)
      CONVERTIR( FROM( DEBUT .. FIN ), V, L );							-- DATA_ERROR (base, chiffre)
        if  L /= FIN  then raise DATA_ERROR; end if;
      -- LRM 14.3.8 : DATA_ERROR si V est hors du sous-type NUM. NUM'FIRST et
      -- NUM'LAST d'un formel reel ne sont pas compiles dans le corps generique
      -- (ils rendent 0) : controle differe a la session des generiques.
      ITEM := V;
      LAST := FIN;

    end	GET;
	---


			---
    procedure		PUT		( TO   :out STRING;
					  ITEM :in NUM;
					  AFT  :in FIELD		:= DEFAULT_AFT;
					  EXP  :in INTEGER		:= DEFAULT_EXP
					)
    is			---

      AFT_EFF		: FIELD		:= AFT + BOOLEAN'POS( AFT = 0 );		-- LRM 14.3.8 : un chiffre au moins apres le point

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
        for  K in 1 .. AFT_EFF  loop
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
        for  K in 1 .. AFT_EFF  loop
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

        for  K in 1 .. AFT_EFF  loop
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
	EXP_STR	:constant STRING	:= IMAGE_EXPOSANT( E, EXP );				-- LRM 14.3.8 : EXP compte le signe
        begin
	for  K in EXP_STR'RANGE  loop
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

      TAMPON		: STRING( 1 .. MAX_LEXEME );
      LONG		: NATURAL;
      V			: NUM;
      DERNIER		: POSITIVE;

    begin
      if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
      if  ETATS( FILE.SLOT ).MODE /= IN_FILE  then raise MODE_ERROR; end if;

      LIRE_LEXEME( FILE, WIDTH, LEX_REEL, TAMPON, LONG );						-- LRM 14.3.8 : lexeme du fichier,
      begin												-- converti par le GET sur chaine
        GET( TAMPON( 1 .. LONG ), V, DERNIER );
      exception
        when END_ERROR =>  raise DATA_ERROR;								-- champ blanc ou vide
      end;
      FIN_DE_CHAMP( TAMPON( 1 .. LONG ), DERNIER );
      ITEM := V;											-- ITEM intact en cas d'erreur

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

      AFT_EFF		: FIELD		:= AFT + BOOLEAN'POS( AFT = 0 );		-- LRM 14.3.8 : un chiffre au moins apres le point

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
        for  K in 1 .. AFT_EFF  loop
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
      DEBUT_ELEMENT( FILE );										-- LRM 14.3.5 : LAYOUT_ERROR, NEW_LINE
      if  IS_NEGATIVE  then
        VAL := -VAL;
      end if;

      if  EXP = 0  then

        -- Arrondir a AFT chiffres avant extraction.
        for  K in 1 .. AFT_EFF  loop
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

        for  K in 1 .. AFT_EFF  loop
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

        for  K in 1 .. AFT_EFF  loop
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

        PUT( FILE, IMAGE_EXPOSANT( E, EXP ) );								-- LRM 14.3.8 : EXP compte le signe

       end if;


      FIN_ELEMENT( FILE );

    exception
      when others =>												-- rien n'est ecrit
        ABANDON_ELEMENT;
        raise;
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

      DEBUT, FIN		: INTEGER;
      VAL		: LONG_FLOAT;
      R			: LONG_FLOAT;

    begin
      ANALYSER( FROM, LEX_REEL, DEBUT, FIN );							-- END_ERROR, DATA_ERROR (syntaxe)
      VAL := VALEUR_REELLE( FROM( DEBUT .. FIN ) );							-- DATA_ERROR (base, chiffre, valeur)
      -- LRM 14.3.8 : DATA_ERROR si V est hors du sous-type NUM. NUM'FIRST et
      -- NUM'LAST d'un formel reel ne sont pas compiles dans le corps generique
      -- (ils rendent 0) : controle differe a la session des generiques.
      R := VAL - LONG_FLOAT( NUM( VAL ) );								-- la conversion tronque (LRM 4.6 l'admet) ;
											-- valeur du litteral : multiple de SMALL
      ITEM := NUM( VAL + R );										-- le plus proche (VAL + R = X + 2R)
      LAST := FIN;

    end	GET;
	---


			---
    procedure		PUT		( TO   :out STRING;
					  ITEM :in NUM;
					  AFT  :in FIELD		:= DEFAULT_AFT;
					  EXP  :in INTEGER		:= DEFAULT_EXP
					)
    is			---

      AFT_EFF		: FIELD		:= AFT + BOOLEAN'POS( AFT = 0 );		-- LRM 14.3.8 : un chiffre au moins apres le point

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
        for  K in 1 .. AFT_EFF  loop
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
        for  K in 1 .. AFT_EFF  loop
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

        for  K in 1 .. AFT_EFF  loop
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
	EXP_STR	:constant STRING	:= IMAGE_EXPOSANT( E, EXP );				-- LRM 14.3.8 : EXP compte le signe
        begin
	for  K in EXP_STR'RANGE  loop
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
      DEBUT_ELEMENT( FILE );										-- LRM 14.3.5 : LAYOUT_ERROR, NEW_LINE
      if  ENUM'POS( ITEM ) < ENUM'POS( ENUM'FIRST )  or else  ENUM'POS( ITEM ) > ENUM'POS( ENUM'LAST )  then
        raise CONSTRAINT_ERROR;								-- LRM 6.4.1 : ITEM hors du sous-type ENUM (lot 29 ;
      end if;										-- controle que l'appel d'une instance omet)
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
	    if  SET = LOWER_CASE  and then  IMAGES_STR( IMG_START ) /= '''  then			-- LRM 14.3.9 : un litteral caractere
	      declare										-- s'ecrit tel quel
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
	  FIN_ELEMENT( FILE );
	  return;
	end if;
	I := I + 2 + LEN;
        end loop;
      end;


      FIN_ELEMENT( FILE );

    exception
      when others =>												-- rien n'est ecrit
        ABANDON_ELEMENT;
        raise;
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

      TAMPON		: STRING( 1 .. MAX_LEXEME );
      LONG		: NATURAL;
      V			: ENUM;
      DERNIER		: POSITIVE;

    begin
      if  ETATS( FILE.SLOT ).IS_OPENED = FALSE  then raise STATUS_ERROR; end if;
      if  ETATS( FILE.SLOT ).MODE /= IN_FILE  then raise MODE_ERROR; end if;

      LIRE_LEXEME( FILE, 0, LEX_ENUM, TAMPON, LONG );						-- LRM 14.3.9 : identificateur ou
      begin												-- litteral caractere, reconnu par le
        GET( TAMPON( 1 .. LONG ), V, DERNIER );							-- GET sur chaine
      exception
        when END_ERROR =>  raise DATA_ERROR;								-- aucun caractere ne commence un lexeme
      end;
      ITEM := V;

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

      DEBUT, FIN		: INTEGER;
      P			: INTEGER;
      REP			: INTEGER;
      LEN			: INTEGER;
      IMG_START		: INTEGER;
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

    begin
      ANALYSER( FROM, LEX_ENUM, DEBUT, FIN );							-- LRM 14.3.9 : END_ERROR, DATA_ERROR
      declare
        IMAGES_STR		: constant STRING	:= GET_ENUM_IMAGES;

      begin
        P := IMAGES_STR'FIRST;

      -- IMAGES_STR contient des triplets :
      --	 REP, LEN, caracteres_de_l_image
        while  P <= IMAGES_STR'LAST  loop

	REP := CHARACTER'POS( IMAGES_STR( P ) );
	LEN := CHARACTER'POS( IMAGES_STR( P + 1 ) );
	IMG_START := P + 2;

	if  LEN = FIN - DEBUT + 1  then							-- le lexeme entier, pas un prefixe
	  OK := TRUE;
	  for  J in 0 .. LEN - 1  loop
	    if  FROM( DEBUT ) = '''  then							-- litteral caractere : exact
	      if  FROM( DEBUT + J ) /= IMAGES_STR( IMG_START + J )  then OK := FALSE; end if;
	    elsif  UPPER( FROM( DEBUT + J ) ) /= UPPER( IMAGES_STR( IMG_START + J ) )  then	-- identificateur : sans casse
	      OK := FALSE;
	    end if;
	  end loop;

	  if  OK  then
	    if  REP < ENUM'POS( ENUM'FIRST )  or else  REP > ENUM'POS( ENUM'LAST )  then
	      raise DATA_ERROR;								-- LRM 14.3.9(12) : hors du sous-type ENUM (lot 29)
	    end if;
	    ITEM := ENUM'VAL( REP );
	    LAST := FIN;
	    return;
	  end if;
	end if;

	P := P + 2 + LEN;
        end loop;

        raise DATA_ERROR;								-- LRM 14.3.9(12) : image inconnue
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
      if  ENUM'POS( ITEM ) < ENUM'POS( ENUM'FIRST )  or else  ENUM'POS( ITEM ) > ENUM'POS( ENUM'LAST )  then
        raise CONSTRAINT_ERROR;								-- LRM 6.4.1 : ITEM hors du sous-type ENUM (lot 29)
      end if;
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
  for  S in ETATS'RANGE  loop										-- tous fermes ; SLOT -1 le reste
    ETATS( S ).ID		:= -1;
    ETATS( S ).NAME_LEN	:= 0;
    ETATS( S ).IS_OPENED	:= FALSE;
    ETATS( S ).MODE		:= IN_FILE;
    ETATS( S ).PAGE_LENGTH	:= 0;								-- LRM 14.3.3 : non borne
    ETATS( S ).LINE_LENGTH	:= 0;
    ETATS( S ).PAGE		:= 1;
    ETATS( S ).LINE		:= 1;
    ETATS( S ).COL		:= 1;
    ETATS( S ).PREC_PAGE	:= 1;
    ETATS( S ).PREC_LINE	:= 1;
    ETATS( S ).PREC_COL	:= 1;
    ETATS( S ).IS_DEFAULT_IO	:= FALSE;
    ETATS( S ).NB_LOOK	:= 0;
    ETATS( S ).DERNIER	:= ASCII.NUL;
    ETATS( S ).FIN_PHYSIQUE	:= FALSE;
    ETATS( S ).AT_END_OF_FILE	:= FALSE;
    ETATS( S ).IS_TEMP	:= FALSE;
  end loop;
  PROCHAIN_SLOT := PREMIER_SLOT;

  ETATS( 0 ).IS_OPENED	:= TRUE;								-- entree standard : console
  ETATS( 0 ).IS_DEFAULT_IO	:= TRUE;
  ETATS( 1 ).IS_OPENED	:= TRUE;								-- sortie standard : console
  ETATS( 1 ).MODE		:= OUT_FILE;
  ETATS( 1 ).IS_DEFAULT_IO	:= TRUE;
  STD_INPUT.SLOT		:= 0;
  STD_OUTPUT.SLOT		:= 1;

  DEFAULT_INPUT		:= STD_INPUT;
  DEFAULT_OUTPUT		:= STD_OUTPUT;

  for  ID in 0 .. MAX_BUF_ID  loop									-- VARzone non zeroee : compteurs a 0 explicitement
    BUFS( ID ).OUT_LEN := 0;
    BUFS( ID ).IN_POS  := 0;
    BUFS( ID ).IN_LEN  := 0;
  end loop;

end	TEXT_IO;
	-------
