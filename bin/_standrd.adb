-- INCLUSION DE RUNTIME VIA BODY STANDARD

				--------
package body			_standrd
is				--------

  type ENUM_USE_INFO	is record
			  SIZ		: NATURAL;
			  FST, LST	: INTEGER;
			end record;

  type FIXED_USE_INFO	is record
			  SIZ		: NATURAL;
			  FST, LST	: LONG_INTEGER;
			  NUMER, DENOM	: LONG_INTEGER;
			end record;

  type FLOAT_USE_INFO	is record							-- info d'un type flottant (EMIT_FLOAT_MODEL_INFO) :
			  SIZ		: NATURAL;					-- grandeurs du MODELE (LRM 3.5.7, 3.5.8) lues par
			  FST, LST	: LONG_FLOAT;					-- un corps generique pour un formel DIGITS <>
			  NB_DIGITS, MANTISSA, SAFE_EMAX	: INTEGER;
			  BASE_DIGITS, BASE_MANTISSA	: INTEGER;
			end record;


				-- EXCEPTIONS SERVICE

  EXCEPTIONS_TOP_CTX	: LONG_INTEGER;								-- PILIER 11 : sommet de la pile des contextes de reprise
  EXCEPTIONS_CURRENT	: LONG_INTEGER;								-- identite (@doublet STR) de l'exception en cours

  type FP_ARRAY		is array ( 0 .. 31 ) of LONG_INTEGER;
  type EXCEPTION_CONTEXT	is record
			  PREV_CTX, DISPATCH,
			  RBP, RSP, R13, R14,
			  NXT_LVL			: LONG_INTEGER;
			  FRAME_POINTERS		: FP_ARRAY;
			end record;
  EXC_CTX0		: EXCEPTION_CONTEXT;							-- contexte-sentinelle : 7 qwords d'en-tete + FP(0)

			-----
  function		WIDTH	( BIT_SIZE :INTEGER )	return INTEGER
  is			-----
  begin
    if  BIT_SIZE <= 8  then  return 4;									-- +255
    elsif  BIT_SIZE <= 16  then  return 6;								-- +32767
    elsif  BIT_SIZE <= 32  then  return 11;								-- +4294967295
    elsif  BIT_SIZE <= 64  then  return 21;								-- +1,844674407371E19
    else  return 40;										-- 128 bits 3,4028236692094E38
    end if;

  end	WIDTH;
	-----


			-------------
  function		INTEGER_IMAGE	( ITEM :LONG_INTEGER )	return STRING
  is			-------------
			--| ITEM et N en LONG_INTEGER : la valeur arrive sur 64 bits pour tout
			--| type entier ; en INTEGER, LONG_INTEGER'IMAGE (2**32) rendait " 0",
			--| y compris dans T2 (constantes de fixes de CODE_STATIC_FIXED_VALUE).

    LEN	: INTEGER;

  begin
		-------------------
		INTEGER_IMAGE_WIDTH:
    declare
      N	: LONG_INTEGER := ITEM;

    begin
      LEN := 1;
      if N = 0 then
        LEN := 2;

      else
        if N > 0 then
	N := -N;
        end if;

        while N /= 0 loop
	LEN := LEN + 1;
	N := N / 10;
        end loop;

      end if;

    end	INTEGER_IMAGE_WIDTH;
	-------------------
    declare
      BUF : STRING (1 .. LEN);
      POS : INTEGER := LEN;
      N	: LONG_INTEGER := ITEM;
      DIG : INTEGER;
    begin
      if N = 0 then
        BUF(POS) := '0';
        POS := POS - 1;

      else
    -- On travaille en négatif pour éviter le cas INTEGER'FIRST.
        if N > 0 then
	N := -N;
        end if;

        while N /= 0 loop
	DIG := INTEGER (-(N rem 10));
	BUF(POS) := CHARACTER'VAL(CHARACTER'POS('0') + DIG);
	POS := POS - 1;
	N := N / 10;
        end loop;
      end if;

      if ITEM < 0 then
        BUF(POS) := '-';
      else
        BUF(POS) := ' ';
      end if;

      return BUF;
    end;

  end	INTEGER_IMAGE;
	-------------


			----------
  function		ENUM_IMAGE	( IMAGES :STRING; REP :INTEGER )	return STRING
  is			----------
  -- Primitive Ada cachee de l''IMAGE des ENUMERES, pendant d'INTEGER_IMAGE.
  -- Appelee par le code genere : CODE_IMAGE empile le descripteur resultat,
  -- REP (l'argument de l'attribut, deja empile par l'appelant), puis le
  -- doublet IMAGES du type -- qui est le doublet contractuel pose par
  -- END_BLOC_DEF a use__info+16 (SIZ@0, FST@4, LST@8, pad, data_ptr@16,
  -- info_ptr@24 ; pieges n 29 et 87) : directement un doublet STRING,
  -- zero copie.  Format IMAGES : triplets ( REP, LEN, caracteres... ),
  -- le meme que celui parcouru par TEXT_IO.ENUMERATION_IO (PUT/GET).
    I		: POSITIVE	:= IMAGES'FIRST;
    ITEM_REP	: INTEGER;
    LEN		: INTEGER;
  begin
    while  I <= IMAGES'LAST  loop
      ITEM_REP := CHARACTER'POS( IMAGES( I ) );
      LEN	     := CHARACTER'POS( IMAGES( I + 1 ) );

      if  ITEM_REP = REP  then
        declare
	-- Rebasage OBLIGATOIRE a 1..LEN (LRM 3.5.5 : la borne basse du
	-- resultat de 'IMAGE est 1) : LEX compte dessus (IMAGE(4..LGR)).
	-- Initialisation par tranche : c'est le patch n 3 de
	-- COMPILE_ARRAY_VAR qui rend cette declaration compilable.
	IMG	: constant STRING( 1 .. LEN ) := IMAGES( I + 2 .. I + 1 + LEN );
        begin
	return IMG;
        end;
      end if;

      I := I + 2 + LEN;
    end loop;

    raise PROGRAM_ERROR;										-- valeur hors table : bruyant (piege n 53)

  end	ENUM_IMAGE;
	----------


			-------------
  function		INTEGER_VALUE	( S :STRING )	return LONG_INTEGER
  is			-------------
  -- Primitive Ada cachee de 'VALUE des ENTIERS, reciproque
  -- d'INTEGER_IMAGE.  Appelee par le code genere : CODE_VALUE empile
  -- le lieu resultat (qword), puis @doublet de la chaine (l'argument,
  -- deja empile par l'appelant de la forme appel).
  -- LRM 3.5.5, SOUS-ENSEMBLE : blancs de tete/queue, signe optionnel,
  -- chiffres decimaux, soulignes admis (position non verifiee) ;
  -- base et exposant NON instruits ; chaine illicite ->
  -- CONSTRAINT_ERROR ; depassement 64 bits non controle (les valeurs
  -- du bootstrap viennent de PRINT_NUM).
    I		: INTEGER		:= S'FIRST;
    N		: LONG_INTEGER	:= 0;
    NEGATIVE	: BOOLEAN		:= FALSE;
    SOME_DIGIT	: BOOLEAN		:= FALSE;
  begin
    while  I <= S'LAST  and then  S(I) = ' '  loop				-- blancs de tete
      I := I + 1;
    end loop;

    if  I <= S'LAST  and then  ( S(I) = '-'  or else  S(I) = '+' )  then
      NEGATIVE := S(I) = '-';
      I := I + 1;
    end if;

    -- Accumulation en NEGATIF pour couvrir LONG_INTEGER'FIRST
    -- (le motif d'INTEGER_IMAGE).
    while  I <= S'LAST
    and then  (    ( S(I) >= '0'  and then  S(I) <= '9' )
	   or else  ( S(I) = '_'  and then  SOME_DIGIT ) )  loop
      if  S(I) /= '_'  then
        N := N * 10 - LONG_INTEGER( CHARACTER'POS( S(I) ) - CHARACTER'POS('0') );
        SOME_DIGIT := TRUE;
      end if;
      I := I + 1;
    end loop;

    while  I <= S'LAST  and then  S(I) = ' '  loop				-- blancs de queue
      I := I + 1;
    end loop;

    if  not SOME_DIGIT  or else  I <= S'LAST  then				-- rien lu, ou reliquat illicite
      raise CONSTRAINT_ERROR;
    end if;

    if  NEGATIVE  then
      return  N;
    else
      return  -N;
    end if;

  end	INTEGER_VALUE;
	-------------


		-----------
  function	INTEGER_POW	( X, N : LONG_INTEGER )	return LONG_INTEGER
  is		-----------

    R	: LONG_INTEGER	:= 1;
    B	: LONG_INTEGER	:= X;
    E	: LONG_INTEGER	:= N;

  begin
    if  E < 0  then
      raise  CONSTRAINT_ERROR;
    end if;
    while  E > 0  loop
      R := R * B;
      E := E - 1;
    end loop;

    return  R;

  end	INTEGER_POW;
	-----------


	--------
end	_standrd;
	--------
