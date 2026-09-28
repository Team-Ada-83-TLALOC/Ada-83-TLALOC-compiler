
   --|	ATTENTION : RESPECTER LA CASSE DES CARACTERES DES TYPES, LE COMPILATEUR Y PRETE ATTENTION

				--------
package				_standrd								--| Package invisible aux programmes
is				--------


					--------
  package					STANDARD
  is					--------

    type BOOLEAN			is (FALSE, TRUE);

    type SHORT_INTEGER		is range -2**15 .. 2**15-1;
    type INTEGER			is range -2**31 .. 2**31-1;
--    type LONG_INTEGER		is range -2**63 .. 2**63-1;
    type LONG_INTEGER		is range -16#7FFFFFFFFFFFFFFF# - 1 .. 16#7FFFFFFFFFFFFFFF#;			--| Evitement de debordement

    type FLOAT			is digits  6 range -1.0E38 .. 1.0E38;
    type LONG_FLOAT			is digits 15 range -1.0E308 .. 1.0E308;

    type CHARACTER is (
	_nul,  _soh,  _stx,  _etx,	  _eot, _enq,  _ack,  _bel,
	_bs,   _ht,   _lf,	 _vt,	  _ff,  _cr,   _so,	  _si,
	_dle,  _dc1,  _dc2,  _dc3,	  _dc4, _nak,  _syn,  _etb,
	_can,  _em,   _sub,  _esc,	  _fs,  _gs,   _rs,	  _us,

	' ',  '!',  '"',  '#',    '$',  '%',  '&',  ''',
	'(',  ')',  '*',  '+',    ',',  '-',  '.',  '/',
	'0',  '1',  '2',  '3',    '4',  '5',  '6',  '7',
	'8',  '9',  ':',  ';',    '<',  '=',  '>',  '?',

	'@',  'A',  'B',  'C',    'D',  'E',  'F',  'G',
	'H',  'I',  'J',  'K',    'L',  'M',  'N',  'O',
	'P',  'Q',  'R',  'S',    'T',  'U',  'V',  'W',
	'X',  'Y',  'Z',  '[',    '\',  ']',  '^',  '_',

	'`',  'a',  'b',  'c',    'd',  'e',  'f',  'g',
	'h',  'i',  'j',  'k',    'l',  'm',  'n',  'o',
	'p',  'q',  'r',  's',    't',  'u',  'v',  'w',
	'x',  'y',  'z',  '{',    '|',  '}',  '~',  _del
	);

		-----
    package	ASCII
    is		-----

	  NUL  : constant CHARACTER := _nul;  SOH  : constant CHARACTER := _soh;
	  STX  : constant CHARACTER := _stx;  ETX  : constant CHARACTER := _etx;
	  EOT  : constant CHARACTER := _eot;  ENQ  : constant CHARACTER := _enq;
	  ACK  : constant CHARACTER := _ack;  BEL  : constant CHARACTER := _bel;
	  BS   : constant CHARACTER := _bs;   HT   : constant CHARACTER := _ht;
	  LF   : constant CHARACTER := _lf;   VT   : constant CHARACTER := _vt;
	  FF   : constant CHARACTER := _ff;   CR   : constant CHARACTER := _cr;
	  SO   : constant CHARACTER := _so;   SI   : constant CHARACTER := _si;
	  DLE  : constant CHARACTER := _dle;  DC1  : constant CHARACTER := _dc1;
	  DC2  : constant CHARACTER := _dc2;  DC3  : constant CHARACTER := _dc3;
	  DC4  : constant CHARACTER := _dc4;  NAK  : constant CHARACTER := _nak;
	  SYN  : constant CHARACTER := _syn;  ETB  : constant CHARACTER := _etb;
	  CAN  : constant CHARACTER := _can;  EM   : constant CHARACTER := _em;
	  SUB  : constant CHARACTER := _sub;  ESC  : constant CHARACTER := _esc;
	  FS   : constant CHARACTER := _fs;   GS   : constant CHARACTER := _gs;
	  RS   : constant CHARACTER := _rs;   US   : constant CHARACTER := _us;
	  DEL  : constant CHARACTER := _del;

	  EXCLAM	      : constant CHARACTER := '!';
	  SHARP	      : constant CHARACTER := '#';
	  PERCENT	      : constant CHARACTER := '%';
	  COLON	      : constant CHARACTER := ':';
	  QUERY	      : constant CHARACTER := '?';
	  L_BRACKET     : constant CHARACTER := '[';
	  R_BRACKET     : constant CHARACTER := ']';
	  UNDERLINE     : constant CHARACTER := '_';
	  L_BRACE	      : constant CHARACTER := '{';
	  R_BRACE	      : constant CHARACTER := '}';

	  QUOTATION     : constant CHARACTER := '"';
	  DOLLAR	      : constant CHARACTER := '$';
	  AMPERSAND     : constant CHARACTER := '&';
	  SEMICOLON     : constant CHARACTER := ';';
	  AT_SIGN	      : constant CHARACTER := '@';
	  BACK_SLASH    : constant CHARACTER := '\';
	  CIRCUMFLEX    : constant CHARACTER := '^';
	  GRAVE	      : constant CHARACTER := '`';
	  BAR	      : constant CHARACTER := '|';
	  TILDE	      : constant CHARACTER := '~';

	  LC_A : constant CHARACTER := 'a';   LC_B : constant CHARACTER := 'b';
	  LC_C : constant CHARACTER := 'c';   LC_D : constant CHARACTER := 'd';
	  LC_E : constant CHARACTER := 'e';   LC_F : constant CHARACTER := 'f';
	  LC_G : constant CHARACTER := 'g';   LC_H : constant CHARACTER := 'h';
	  LC_I : constant CHARACTER := 'i';   LC_J : constant CHARACTER := 'j';
	  LC_K : constant CHARACTER := 'k';   LC_L : constant CHARACTER := 'l';
	  LC_M : constant CHARACTER := 'm';   LC_N : constant CHARACTER := 'n';
	  LC_O : constant CHARACTER := 'o';   LC_P : constant CHARACTER := 'p';
	  LC_Q : constant CHARACTER := 'q';   LC_R : constant CHARACTER := 'r';
	  LC_S : constant CHARACTER := 's';   LC_T : constant CHARACTER := 't';
	  LC_U : constant CHARACTER := 'u';   LC_V : constant CHARACTER := 'v';
	  LC_W : constant CHARACTER := 'w';   LC_X : constant CHARACTER := 'x';
	  LC_Y : constant CHARACTER := 'y';   LC_Z : constant CHARACTER := 'z';

	-----
    end	ASCII;
	-----

    subtype NATURAL		is INTEGER range 0 .. 2147483647;
    subtype POSITIVE	is INTEGER range 1 .. 2147483647;

    type STRING		is array (POSITIVE range <>) of CHARACTER;
	-- pragma PACK(STRING);

--    type DURATION		is delta 2.0**(-29) range -2.0**34 .. 2.0**34 - 1.0;				-- type DURATION souhaite, ecriture trop complexe
      type DURATION		is delta 0.00000000186264514923095703125 range -17179869184.0 .. 17179869183.0;

    CONSTRAINT_ERROR	: exception;
    NUMERIC_ERROR		: exception;
    PROGRAM_ERROR		: exception;
    STORAGE_ERROR		: exception;
    TASKING_ERROR		: exception;

		--| Type de base invisible renommé en ADDRESS (le type visible) dans SYSTEM

    type _address		is new LONG_INTEGER;


    private

      --| Ce type est invisible, il doit être en minuscules et sert de type de base pour DURATION

--      type _duration	is delta 2.0**(-29) range -2.0**34 .. 2.0**34 - 1.0;				-- type _duration souhaite, ecriture trop complexe
      type _duration	is delta 0.00000000186264514923095703125 range -17179869184.0 .. 17179869183.0;

      -- Specification of implementation sizes
	for BOOLEAN'size		use 1;
	for CHARACTER'size		use 8;
	for SHORT_INTEGER'size	use 16;
	for INTEGER'size		use 32;
	for LONG_INTEGER'size	use 64;
	for FLOAT'size		use 32;
	for LONG_FLOAT'size		use 64;
	for DURATION'size		use 64;

	--------
  end	STANDARD;
	--------

	--------
end	_standrd;
	--------
