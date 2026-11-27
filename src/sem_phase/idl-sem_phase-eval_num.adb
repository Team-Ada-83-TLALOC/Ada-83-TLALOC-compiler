------------------------------------------------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2026 VINCENT MORIN, UBO
-- SPDX-License-Identifier: GPL-3.0-or-later
------------------------------------------------------------------------------------------------------------------------
--	1	2	3	4	5	6	7	8	9	0	1	2

separate (IDL.SEM_PHASE)
      --||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
      --|
function EVAL_NUM (TXT : String) return TREE is
  use UNIV_OPS;

  MAXCOL		: constant Integer := TXT'LAST;
  COL		: Integer	         := TXT'FIRST;
  CHR		: Character        := TXT (TXT'FIRST);
  SCALEFACTOR	: Integer	         := Integer'LAST;
  VNUMER		: VECTOR;
  VDENOM		: VECTOR;
  RADIX		: Integer	         := 10;
  EXPONENT	: Integer	         := 0;
  EXPONENT_POSITIVE : Boolean	         := True;

  procedure V_CLEAR (ARG : out VECTOR) is
  begin
    ARG.S	    := +1;
    ARG.L	    := 1;
    ARG.D (1) := 0;
  end V_CLEAR;

  procedure V_INCREMENT (DLTA : Integer; V : in out VECTOR) is
    TEMP  : UDIGIT;
    CARRY : UDIGIT := 0;
  begin
    V_SCALE (RADIX, V);
    TEMP := V.D (1) + UDIGIT (DLTA);
    if TEMP >= 10_000 then
      CARRY := 1;
      TEMP  := TEMP - 10_000;
    end if;
    V.D (1) := TEMP;
    for I in 2 .. V.L loop
      if CARRY = 0 then
        return;
      end if;
      TEMP := V.D (I) + 1;
      if TEMP >= 10_000 then
        CARRY := 1;
        TEMP  := TEMP - 10_000;
      else
        CARRY := 0;
      end if;
      V.D (I) := TEMP;
    end loop;
    if CARRY > 0 then
      V.L	      := V.L + 1;
      V.D (V.L) := CARRY;
      NORMALIZE (V); -- TO CHECK FOR OVERFLOW
    end if;
  end V_INCREMENT;

  procedure NEXT_CHR is
  begin
    COL := COL + 1;
    if COL <= MAXCOL then
      CHR := TXT (COL);
    else
      CHR := ' ';
    end if;
  end NEXT_CHR;

begin
  V_CLEAR (VNUMER);
	      -- GET INTEGER VAL OR RADIX
  while CHR in '0' .. '9' or else CHR = '.' or else CHR = '_' loop
    if CHR = '.' then
      SCALEFACTOR := 0;
    elsif CHR /= '_' then
      V_INCREMENT (Character'POS (CHR) - Character'POS ('0'), VNUMER);
      SCALEFACTOR := SCALEFACTOR - 1;
    end if;
    NEXT_CHR;
  end loop;
  if CHR = '#' then
    RADIX	       := Integer (VNUMER.D (1));
    VNUMER.D (1) := 0;
    NEXT_CHR;
    while CHR /= '#' loop
      if CHR = '.' then
        SCALEFACTOR := 0;
      elsif CHR = '_' then
        null;
      elsif CHR <= '9' then
        V_INCREMENT (Character'POS (CHR) - Character'POS ('0'), VNUMER);
        SCALEFACTOR := SCALEFACTOR - 1;
      else
        V_INCREMENT (Character'POS (CHR) - Character'POS ('A') + 10, VNUMER);
        SCALEFACTOR := SCALEFACTOR - 1;
      end if;
      NEXT_CHR;
    end loop;
    NEXT_CHR;

  end if;
  if CHR = 'E' then
    NEXT_CHR;
    if CHR = '+' then
      NEXT_CHR;
    elsif CHR = '-' then
      NEXT_CHR;
      EXPONENT_POSITIVE := False;
    end if;
    while CHR /= ' ' loop
      if EXPONENT > 3_275 then
        Put_Line ("!! EXPONENT IN NUMERIC LIT TOO LARGE");
        raise Program_Error;
      end if;
      if CHR /= '_' then					-- LOT 42 : SOULIGNE DE L'EXPOSANT (LRM 2.4.1)
        EXPONENT := EXPONENT * 10 + Character'POS (CHR) - Character'POS ('0');
      end if;
      NEXT_CHR;
    end loop;
    if not EXPONENT_POSITIVE then
      EXPONENT := -EXPONENT;
    end if;
  end if;
  if SCALEFACTOR < 0 then
    EXPONENT := EXPONENT + SCALEFACTOR;
    V_CLEAR (VDENOM);
    VDENOM.D (1) := 1;
  end if;

  if EXPONENT > 0 then
    for I in 1 .. EXPONENT loop
      V_SCALE (RADIX, VNUMER);
    end loop;
  elsif EXPONENT < 0 then
    for I in 1 .. -EXPONENT loop
      V_SCALE (RADIX, VDENOM);
    end loop;
  end if;


  if SCALEFACTOR >= 0 then
    VNUMER.D( VNUMER.L + 1 ) := 0;
    return U_INT( VNUMER );

  else
    V_LOWEST_TERMS( VNUMER, VDENOM );
    VNUMER.D( VNUMER.L + 1 ) := 0;
    VDENOM.D( VDENOM.L + 1 ) := 0;
    return U_REAL( VNUMER, VDENOM );
  end if;
end EVAL_NUM;
