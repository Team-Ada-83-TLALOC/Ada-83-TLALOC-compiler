------------------------------------------------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2026 VINCENT MORIN, UBO
-- SPDX-License-Identifier: GPL-3.0-or-later
------------------------------------------------------------------------------------------------------------------------
--	1	2	3	4	5	6	7	8	9	0	1	2

separate ( TARGET_CODE.EMITS )

					-------------
package body				X86_64_TARGET
is					-------------

  use IR;												--| operateurs ELT_KIND / OPERAND_TAG (LRM 8.4)

  --|  Widths des sequences disp (codi FETCH_*/STORE_*) : W0 pour disp=0,
  --|  W0+1 pour -128..127, W0+4 au dela. LEA de LVA : 0 octet si disp=0.

			------
  function		S_DISP		( D, W0 :SYMBOLS.VALUE_TYPE )		return SYMBOLS.VALUE_TYPE
  is			------
  begin
    if  D = 0  then
      return W0;
    elsif  D >= -128  and then  D < 128  then
      return  W0 + 1;
    end if;
    return  W0 + 4;

  end	S_DISP;
	------

			-----
  function		S_FPA		( LVL :SYMBOLS.VALUE_TYPE )		return SYMBOLS.VALUE_TYPE
  is			-----
  begin
    if  LVL = 0  then
      return  3;
    elsif  LVL <= 15  then
      return  4;
    end if;
    return  7;

  end	S_FPA;
	-----

			------
  function		S_BASE		( LVL :SYMBOLS.VALUE_TYPE )		return SYMBOLS.VALUE_TYPE
  is			------
  begin
    if  LVL = -1  then
      return  8;											--| POP_RAX : adresse empilee
    end if;
    return  S_FPA( LVL );

  end	S_BASE;
	------

		-- briques ancillaires (codi : PUSH_RAX / POP_RAX)

			----------
  procedure		E_PUSH_RAX								--| 8 octets
  is			----------
  begin
    B( 16#48# ); B( 16#89# ); B( 16#45# ); B( 16#08# );							--| mov [rbp+8], rax
    B( 16#48# ); B( 16#8D# ); B( 16#6D# ); B( 16#08# );							--| lea rbp, [rbp+8]
  end	E_PUSH_RAX;
	----------

			---------
  procedure		E_POP_RAX									--| 8 octets
  is			---------
  begin
    B( 16#48# ); B( 16#8B# ); B( 16#45# ); B( 16#00# );							--| mov rax, [rbp]
    B( 16#48# ); B( 16#8D# ); B( 16#6D# ); B( 16#F8# );							--| lea rbp, [rbp-8]
  end	E_POP_RAX;
	---------

			---------
  procedure		E_POP_RBX									--| 8 octets (rangements, comparaisons)
  is			---------
  begin
    B( 16#48# ); B( 16#8B# ); B( 16#5D# ); B( 16#00# );							--| mov rbx, [rbp]
    B( 16#48# ); B( 16#8D# ); B( 16#6D# ); B( 16#F8# );							--| lea rbp, [rbp-8]
  end	E_POP_RBX;
	---------

			-----------------
  procedure		E_SETCC_CELLULE		( CC :INTEGER )						--| 10 octets (lot 44)
  is			-----------------
	--| Booleen d'une comparaison dans la cellule ENTIERE du sommet : setcc al, movzx eax, al,
	--| mov [rbp], rax.  Avant : setcc [rbp], qui laissait les 7 octets hauts de l'operande A
	--| (BT / BF ne lisent que l'octet bas ; une valeur entiere du booleen etait fausse).
  begin
    B( 16#0F# ); B( CC ); B( 16#C0# );									--| setcc al
    B( 16#0F# ); B( 16#B6# ); B( 16#C0# );								--| movzx eax, al
    B( 16#48# ); B( 16#89# ); B( 16#45# ); B( 16#00# );							--| mov [rbp], rax
  end	E_SETCC_CELLULE;
	-----------------

			--------
  procedure		E_JCC_NE		( CC :INTEGER )						--| 6 octets (lot 46)
  is			--------
	--| jcc rel32 vers STANDARD.ne_raise_ (NUMERIC_ERROR) : alignement sur LLIR V8, ou
	--| les fautes 128 (diviseur nul) et 129 (resultat signe hors de 64 bits) valent un
	--| raise NUMERIC_ERROR a l'instruction fautive (TAHX). CC : 80 jo, 82 jc, 83 jae,
	--| 84 jz, 88 js, 8F jg.
    V	: SYMBOLS.VALUE_TYPE	:= SYMBOLS.VALUE_OF( SYMBOLS.RESOLVE( "STANDARD.ne_raise_" ) );
  begin
    B( 16#0F# ); B( CC );
    D32( INTEGER( V - ( ORG + SYMBOLS.VALUE_TYPE( TOP ) + 4 ) ) );
  end	E_JCC_NE;
	--------

			---------------------
  procedure		E_DIVISEUR_NON_NUL								--| 9 octets (lot 46)
  is			---------------------
	--| rbx = diviseur : nul -> NUMERIC_ERROR (faute 128)
  begin
    B( 16#48# ); B( 16#85# ); B( 16#DB# );								--| test rbx, rbx
    E_JCC_NE( 16#84# );										--| jz ne_raise_
  end	E_DIVISEUR_NON_NUL;
	---------------------

			-------------------
  procedure		E_DIVISION_EXACTE								--| 41 octets (lot 46)
  is			-------------------
	--| rdx:rax = dividende sur 128 bits, rbx = diviseur non nul. Quotient tronque vers zero
	--| dans rax, |reste| dans rdx, signe du quotient dans le bit 63 de r8. Quotient hors de
	--| [-2**63, 2**63) -> NUMERIC_ERROR (faute 129 de CVTIX, CVTXI), sans idiv (#DE). rbx
	--| ressort avec |diviseur|.
	--| Division non signee des valeurs absolues, puis signe.
  begin
    B( 16#49# ); B( 16#89# ); B( 16#D0# );								--| mov r8, rdx
    B( 16#49# ); B( 16#31# ); B( 16#D8# );								--| xor r8, rbx (signe du quotient)
    B( 16#48# ); B( 16#85# ); B( 16#D2# );								--| test rdx, rdx
    B( 16#79# ); B( 16#0A# );									--| jns +10
    B( 16#48# ); B( 16#F7# ); B( 16#D8# );								--| neg rax
    B( 16#48# ); B( 16#83# ); B( 16#D2# ); B( 16#00# );							--| adc rdx, 0
    B( 16#48# ); B( 16#F7# ); B( 16#DA# );								--| neg rdx (|dividende|)
    B( 16#48# ); B( 16#85# ); B( 16#DB# );								--| test rbx, rbx
    B( 16#79# ); B( 16#03# );									--| jns +3
    B( 16#48# ); B( 16#F7# ); B( 16#DB# );								--| neg rbx (|diviseur|, 2**63 non signe)
    B( 16#48# ); B( 16#39# ); B( 16#DA# );								--| cmp rdx, rbx
    E_JCC_NE( 16#83# );										--| jae ne_raise_ (quotient >= 2**64)
    B( 16#48# ); B( 16#F7# ); B( 16#F3# );								--| div rbx (non signe)
  end	E_DIVISION_EXACTE;
	-------------------

			-------------------
  procedure		E_SIGNE_QUOTIENT								--| 28 octets (lot 46)
  is			-------------------
	--| rax = |quotient| (non signe), signe dans le bit 63 de r8 : rax := quotient signe,
	--| NUMERIC_ERROR s'il sort de [-2**63, 2**63).
  begin
    B( 16#4D# ); B( 16#85# ); B( 16#C0# );								--| test r8, r8
    B( 16#78# ); B( 16#0B# );									--| js +11 (negatif)
    B( 16#48# ); B( 16#85# ); B( 16#C0# );								--| test rax, rax
    E_JCC_NE( 16#88# );										--| js ne_raise_ (>= 2**63)
    B( 16#EB# ); B( 16#0C# );									--| jmp +12
    B( 16#48# ); B( 16#F7# ); B( 16#D8# );								--| neg rax
    B( 16#48# ); B( 16#85# ); B( 16#C0# );								--| test rax, rax
    E_JCC_NE( 16#8F# );										--| jg ne_raise_ (|q| > 2**63)
  end	E_SIGNE_QUOTIENT;
	-------------------

			---------
  procedure		E_POP_RCX									--| 8 octets (decalages, conversions)
  is			---------
  begin
    B( 16#48# ); B( 16#8B# ); B( 16#4D# ); B( 16#00# );							--| mov rcx, [rbp]
    B( 16#48# ); B( 16#8D# ); B( 16#6D# ); B( 16#F8# );							--| lea rbp, [rbp-8]
  end	E_POP_RCX;
	---------

			---------
  procedure		E_POP_RDX									--| 8 octets (E/S fichiers)
  is			---------
  begin
    B( 16#48# ); B( 16#8B# ); B( 16#55# ); B( 16#00# );							--| mov rdx, [rbp]
    B( 16#48# ); B( 16#8D# ); B( 16#6D# ); B( 16#F8# );							--| lea rbp, [rbp-8]
  end	E_POP_RDX;
	---------

			---------
  procedure		E_POP_RDI									--| 8 octets (BLKMOV)
  is			---------
  begin
    B( 16#48# ); B( 16#8B# ); B( 16#7D# ); B( 16#00# );							--| mov rdi, [rbp]
    B( 16#48# ); B( 16#8D# ); B( 16#6D# ); B( 16#F8# );							--| lea rbp, [rbp-8]
  end	E_POP_RDI;
	---------

			---------
  procedure		E_POP_RSI									--| 8 octets (SYS_PUT_STR)
  is			---------
  begin
    B( 16#48# ); B( 16#8B# ); B( 16#75# ); B( 16#00# );							--| mov rsi, [rbp]
    B( 16#48# ); B( 16#8D# ); B( 16#6D# ); B( 16#F8# );							--| lea rbp, [rbp-8]
  end	E_POP_RSI;
	---------


			-----------------
  procedure		E_COPY_STRING_NUL								--| COPY_STRING_APPEND_NUL du codi (31) :
  is			-----------------								--| copie la chaine Ada (doublet en rsi) sur
  begin												--| la pile montante, NUL final, rdi = debut
    B( 16#48# ); B( 16#8B# ); B( 16#46# ); B( 16#08# );							--| mov rax, [rsi+8]
    B( 16#8B# ); B( 16#48# ); B( 16#0C# );								--| mov ecx, [rax+12]
    B( 16#FF# ); B( 16#C1# );										--| inc ecx
    B( 16#2B# ); B( 16#48# ); B( 16#08# );								--| sub ecx, [rax+8]
    B( 16#48# ); B( 16#8B# ); B( 16#36# );								--| mov rsi, [rsi]
    B( 16#48# ); B( 16#8D# ); B( 16#7D# ); B( 16#08# );							--| lea rdi, [rbp+8]
    B( 16#FC# );											--| cld
    B( 16#E3# ); B( 16#04# );										--| jrcxz +4 : chaine vide (rcx = 0), sinon
    B( 16#AC# ); B( 16#AA# );										--| lodsb ; stosb		loop copierait 2**64
    B( 16#E2# ); B( 16#FC# );										--| loop			octets

    B( 16#C6# ); B( 16#07# ); B( 16#00# );								--| mov byte [rdi], 0
    B( 16#48# ); B( 16#8D# ); B( 16#7D# ); B( 16#08# );							--| lea rdi, [rbp+8]
  end	E_COPY_STRING_NUL;
	-----------------


  --| queue ModRM(+disp) commune aux FETCH/STORE : [rax] / [rax+d8] / [rax+d32]

			------------
  procedure		E_MODRM_DISP	( M0, M8, M32 :INTEGER; D :SYMBOLS.VALUE_TYPE )
  is			------------
  begin
    if  D = 0  then
      B( M0 );
    elsif  D >= -128  and then  D < 128  then
      B( M8 ); B( INTEGER( D mod 256 ) );
    else
      B( M32 );
      D32( INTEGER( D ) );
    end if;

  end	E_MODRM_DISP;
	------------


  --| motif commun FP_IN_RAX / FP_IN_RBP / RAX_IN_FP : 49 xx (yy|zz [8l])
			--------
  procedure		E_R15_OP		( OP0, OP1, OPD :INTEGER;
					  LVL :SYMBOLS.VALUE_TYPE )
  is			--------
  begin
    B( 16#49# ); B( OP0 );
    if  LVL = 0  then
      B( OP1 );
    elsif  LVL <= 15  then
      B( OPD ); B( INTEGER( 8 * LVL ) );
    else
      B( OPD + 16#40# );										--| ModRM disp32 (ex. 47->87, 6F->AF)
      D32( INTEGER( 8 * LVL ) );
    end if;

  end	E_R15_OP;
	--------

			-----
  procedure		E_FPA		( LVL :SYMBOLS.VALUE_TYPE )					--| mov rax, [r15+8l]
  is			-----
  begin
    E_R15_OP( 16#8B#, 16#07#, 16#47#, LVL );

  end	E_FPA;
	-----

			--------
  procedure		E_FP_RBP		( LVL :SYMBOLS.VALUE_TYPE )					--| mov rbp, [r15+8l]
  is			--------
  begin
    E_R15_OP( 16#8B#, 16#2F#, 16#6F#, LVL );

  end	E_FP_RBP;
	--------

			--------
  procedure		E_RAX_FP		( LVL :SYMBOLS.VALUE_TYPE )					--| mov [r15+8l], rax
  is			--------
  begin
    E_R15_OP( 16#89#, 16#07#, 16#47#, LVL );

  end	E_RAX_FP;
	--------
			------
  procedure		E_BASE ( LVL :SYMBOLS.VALUE_TYPE )
  is			------
  begin
    if  LVL = -1  then
      E_POP_RAX;
    else
      E_FPA( LVL );
    end if;

  end	E_BASE;
	------

			---------
  procedure		E_FETCH_B		( D :SYMBOLS.VALUE_TYPE )					--| movsx rax, byte [rax+d]
  is			---------
  begin
    B( 16#48# ); B( 16#0F# ); B( 16#BE# );
    E_MODRM_DISP( 16#00#, 16#40#, 16#80#, D );
  end	E_FETCH_B;
	---------

			---------
  procedure		E_FETCH_W		( D :SYMBOLS.VALUE_TYPE )					--| movsx rax, word [rax+d]
  is			---------
  begin
    B( 16#48# ); B( 16#0F# ); B( 16#BF# );
    E_MODRM_DISP( 16#00#, 16#40#, 16#80#, D );
  end	E_FETCH_W;
	---------

			---------
  procedure		E_FETCH_D		( D :SYMBOLS.VALUE_TYPE )					--| movsx rax, dword [rax+d]
  is			---------
  begin
    B( 16#48# ); B( 16#63# );
    E_MODRM_DISP( 16#00#, 16#40#, 16#80#, D );
  end	E_FETCH_D;
	---------

			---------
  procedure		E_FETCH_Q		( D :SYMBOLS.VALUE_TYPE )					--| mov rax, qword [rax+d]
  is			---------
  begin
    B( 16#48# ); B( 16#8B# );
    E_MODRM_DISP( 16#00#, 16#40#, 16#80#, D );
  end	E_FETCH_Q;
	---------

			---------
  procedure		E_STORE_B		( D :SYMBOLS.VALUE_TYPE )					--| mov byte [rax+d], bl
  is			---------
  begin
    B( 16#88# );
    E_MODRM_DISP( 16#18#, 16#58#, 16#98#, D );
  end	E_STORE_B;
	---------

			---------
  procedure		E_STORE_W		( D :SYMBOLS.VALUE_TYPE )					--| mov word [rax+d], bx
  is			---------
  begin
    B( 16#66# ); B( 16#89# );
    E_MODRM_DISP( 16#18#, 16#58#, 16#98#, D );
  end	E_STORE_W;
	---------

			---------
  procedure		E_STORE_D		( D :SYMBOLS.VALUE_TYPE )					--| mov dword [rax+d], ebx
  is			---------
  begin
    B( 16#89# );
    E_MODRM_DISP( 16#18#, 16#58#, 16#98#, D );
  end	E_STORE_D;
	---------
			---------
  procedure		E_STORE_Q		( D :SYMBOLS.VALUE_TYPE )					--| mov qword [rax+d], rbx
  is			---------
  begin
    B( 16#48# ); B( 16#89# );
    E_MODRM_DISP( 16#18#, 16#58#, 16#98#, D );
  end	E_STORE_Q;
	---------

			----------
  procedure		E_FETCH_BU	( D :SYMBOLS.VALUE_TYPE )					--| movzx rax, byte [rax+d]
  is			----------
  begin
    B( 16#48# ); B( 16#0F# ); B( 16#B6# );
    E_MODRM_DISP( 16#00#, 16#40#, 16#80#, D );
  end	E_FETCH_BU;
	----------

			----------
  procedure		E_FETCH_WU	( D :SYMBOLS.VALUE_TYPE )					--| movzx rax, word [rax+d]
  is			----------
  begin
    B( 16#48# ); B( 16#0F# ); B( 16#B7# );
    E_MODRM_DISP( 16#00#, 16#40#, 16#80#, D );
  end	E_FETCH_WU;
	----------

			----------
  procedure		E_FETCH_DU	( D :SYMBOLS.VALUE_TYPE )					--| mov eax, dword [rax+d] (zero-etend)
  is
  begin
    B( 16#8B# );
    E_MODRM_DISP( 16#00#, 16#40#, 16#80#, D );
  end	E_FETCH_DU;
	----------

			-------
  procedure		E_IBASE		( LVL, DISP :SYMBOLS.VALUE_TYPE )				--| INDIRECT_BASE_IN_RAX du codi :
  is			-------									--| base (pile ou frame) puis
  begin												--| rax := [rax + disp]
    E_BASE( LVL );
    B( 16#48# ); B( 16#8B# );
    E_MODRM_DISP( 16#00#, 16#40#, 16#80#, DISP );

  end	E_IBASE;
	-------

			-------
  function		SIZE_OF		( E :IR.ELT_ID )		return SYMBOLS.VALUE_TYPE
  is			-------

    M	:constant STRING	:= LEX.IMAGE( IR.MNEMO_OF( E ) );

  begin
    if  IR.KIND_OF( E ) /= IR.MACRO_CALL then  return 0;							--| labels, virtual, map : zero octet
    end if;

    if  M = "DROP"  then return  4;
    elsif  M = "DUP"  then return  12;


			---------------------------------------------------
--			L O A D	C O N S T A N T E S	  I M M E D I A T E S

    elsif  M = "LI"  then return  18;									--| movabs(10) + PUSH_RAX(8) : taille FIXE (canonique)
    elsif  M = "LIF"  then return 18;									--| movabs + IEEE double + push (fixe)


			-------------------------------------------------------------
--			L O A D	C O N S T A N T  /  V A R I A B L E   A D R E S S E

    elsif  M = "LCA"  then return 18;									--| movabs ptr+disp (10) + PUSH_RAX (8)
    elsif  M = "LSPA"  then return  18;									--| movabs .elab (canonique) + PUSH_RAX
    elsif  M = "LVA"  then
      declare
        D	:constant SYMBOLS.VALUE_TYPE := OPV( E, 2, 0 );
        L	: SYMBOLS.VALUE_TYPE := 0;
      begin
	if D /= 0
	then
	  L := S_DISP( D, 3 );									--| lea : 4 ou 7 ; RIEN si disp = 0
	end if;
	return S_BASE( OPV( E, 1, -1 ) ) + L + 8;
      end;
    elsif  M = "LIVA"
    then
      declare
        O	:constant SYMBOLS.VALUE_TYPE	:= OPV( E, 3, 0 );
      begin
        if  O = 0  then
	return  S_BASE( OPV( E, 1, -1 ) ) + S_DISP( OPV( E, 2, 0 ), 3 ) + 8;
        end if;
        return  S_BASE( OPV( E, 1, -1 ) ) + S_DISP( OPV( E, 2, 0 ), 3 ) + S_DISP( O, 3 ) + 8;			--| lea rax, [rax+ofs]
      end;

				-----------------
--				L O A D	D A T A		(unsigned/signed)

    elsif  M = "ULB"  then return S_BASE( OPV( E, 1, -1 ) ) + S_DISP( OPV( E, 2, 0 ), 4 ) + 8;
    elsif  M = "ULW"  then return S_BASE( OPV( E, 1, -1 ) ) + S_DISP( OPV( E, 2, 0 ), 4 ) + 8;
    elsif  M = "ULD"  then return S_BASE( OPV( E, 1, -1 ) ) + S_DISP( OPV( E, 2, 0 ), 2 ) + 8;
    elsif  M = "LB"  then return S_BASE( OPV( E, 1, -1 ) ) + S_DISP( OPV( E, 2, 0 ), 4 ) + 8;
    elsif  M = "LW"  then return S_BASE( OPV( E, 1, -1 ) ) + S_DISP( OPV( E, 2, 0 ), 4 ) + 8;
    elsif  M = "LD"  then return S_BASE( OPV( E, 1, -1 ) ) + S_DISP( OPV( E, 2, 0 ), 3 ) + 8;
    elsif  M = "LQ"  or else  M = "LA"  then
      return S_BASE( OPV( E, 1, -1 ) ) + S_DISP( OPV( E, 2, 0 ), 3 ) + 8;

    elsif  M = "ULIB"  then return S_BASE( OPV( E, 1, -1 ) ) + S_DISP( OPV( E, 2, 0 ), 3 )
						+ S_DISP( OPV( E, 3, 0 ), 4 ) + 8;
    elsif  M = "ULIW"  then return S_BASE( OPV( E, 1, -1 ) ) + S_DISP( OPV( E, 2, 0 ), 3 )
						+ S_DISP( OPV( E, 3, 0 ), 4 ) + 8;
    elsif  M = "ULID"  then return S_BASE( OPV( E, 1, -1 ) ) + S_DISP( OPV( E, 2, 0 ), 3 )
						+ S_DISP( OPV( E, 3, 0 ), 2 ) + 8;
    elsif  M = "LIB"  then return S_BASE( OPV( E, 1, -1 ) ) + S_DISP( OPV( E, 2, 0 ), 3 )
						+ S_DISP( OPV( E, 3, 0 ), 4 ) + 8;
    elsif  M = "LIW"  then return S_BASE( OPV( E, 1, -1 ) ) + S_DISP( OPV( E, 2, 0 ), 3 )
						+ S_DISP( OPV( E, 3, 0 ), 4 ) + 8;
    elsif  M = "LID"  then return S_BASE( OPV( E, 1, -1 ) ) + S_DISP( OPV( E, 2, 0 ), 3 )
						+ S_DISP( OPV( E, 3, 0 ), 3 ) + 8;
    elsif  M = "LIQ"  or else  M = "LIA" then								--| LIA = LIQ (alias du codi)
      return S_BASE( OPV( E, 1, -1 ) ) + S_DISP( OPV( E, 2, 0 ), 3 )
	     + S_DISP( OPV( E, 3, 0 ), 3 ) + 8;


				-------------------
--				S T O R E	  D A T A

    elsif  M = "SB"  then return 8 + S_BASE( OPV( E, 1, -1 ) ) + S_DISP( OPV( E, 2, 0 ), 2 );
    elsif  M = "SW"  then return 8 + S_BASE( OPV( E, 1, -1 ) ) + S_DISP( OPV( E, 2, 0 ), 3 );
    elsif  M = "SD"  then return 8 + S_BASE( OPV( E, 1, -1 ) ) + S_DISP( OPV( E, 2, 0 ), 2 );
    elsif  M = "SQ"  or else  M = "SA"  then
      return 8 + S_BASE( OPV( E, 1, -1 ) ) + S_DISP( OPV( E, 2, 0 ), 3 );
    elsif  M = "SIB"  then
      return 8 + S_BASE( OPV( E, 1, -1 ) ) + S_DISP( OPV( E, 2, 0 ), 3 )
	     + S_DISP( OPV( E, 3, 0 ), 2 );
    elsif  M = "SIW"  then
      return 8 + S_BASE( OPV( E, 1, -1 ) ) + S_DISP( OPV( E, 2, 0 ), 3 )
	     + S_DISP( OPV( E, 3, 0 ), 3 );
    elsif  M = "SID"  then
      return 8 + S_BASE( OPV( E, 1, -1 ) ) + S_DISP( OPV( E, 2, 0 ), 3 )
	     + S_DISP( OPV( E, 3, 0 ), 2 );
    elsif  M = "SIQ"  or else  M = "SIA"  then
      return 8 + S_BASE( OPV( E, 1, -1 ) ) + S_DISP( OPV( E, 2, 0 ), 3 )
	     + S_DISP( OPV( E, 3, 0 ), 3 );


		-------------------------------------
--		O P E R A T I O N S	  L O G I Q U E S

    elsif M = "ET"  or  M = "OU"  or  M = "OUX"  or  M = "SHL"  or  M = "SHR"  then return  12;
    elsif  M = "NON"  then return  4;									--| not qword [rbp]


		-----------------------------------------
--		O P E R A T I O N S	  B I T	F I E L D S

    elsif  M = "UBFX"  then return  42;									--| champ non signe (val, LSB, Width empiles)
    elsif  M = "SBFX"  then return  39;									--| champ signe (shl puis sar)
    elsif  M = "BFI"  then return  56;									--| insertion de champ (old, val, LSB, Width)


		-------------------------------------------------------------
--		O P E R A T I O N S	  A R I T H M E T I Q U E   E N T I E R E

    elsif  M = "DEC"  or else  M = "INC"  or else  M = "NEG"  then return  10;					--| + jo ne_raise_ (lot 46)
    elsif  M = "ABS"  then return  22;									--| (x xor allsign) - allsign
    elsif  M = "CLAMP0"  then return  15;
    elsif  M = "ADD"  or else  M = "SUB"  then return 18;							--| POP_RAX(8) + op qword [rbp],rax (4) + jo (6)
    elsif  M = "MUL"  then return  30;									--| POP_RAX + imul qword [rbp] + jo + DROP + PUSH_RAX
    elsif  M = "DIV"  then return  29 + 9 + 4 + 2 + 3 + 6 + 2;						--| lot 46 : diviseur nul, -2**63 / -1
    elsif  M = "REMI"  then return  32 + 9 + 4 + 2 + 2 + 2;
    elsif  M = "MODI"  then return  48 + 9 + 4 + 2 + 2 + 2;
    elsif  M = "SAR"  then return  12;									--| POP_RCX + sar qword [rbp], cl


	---------------------------------------------------------------------------------------------
--	O P E R A T I O N S	  A R I T H M E T I Q U E   F L O T T A N T E   ( S S E 2	d o u b l e )

    elsif  M = "FADD"  or else  M = "FSUB"  or else  M = "FMUL"  or else  M = "FDIV"
    then return  23;
    elsif  M = "FNEG"  then return  4;
    elsif  M = "FABS"  then return  4;									--| and byte [rbp+7], 7F (signe IEEE)
    elsif  M = "FEXP"  then return  47;									--| A ** N entier (boucle mulsd)


	---------------------------------------------------------
--	C O N V E R S I O N S   E N T I E R  <->  F L O T T A N T

    elsif M = "CVTIF"  or else  M = "CVTFI"  or else  M = "CVTFIR"
    then return  14;


	---------------------------------------------------
--	C O N V E R S I O N S   E N T I E R  <->  F I X E D

    elsif  M = "CVTIX"  then return  24 + 9 + 3 + 41 + 28 + 8;						--| lot 46 : division exacte controlee
    elsif  M = "CVTXI"  then return  24 + 9 + 3 + 41 + 18 + 28 + 8;						--| lot 46 : division exacte controlee, arrondi								--| X*NUMER/DENOM arrondi au plus pres


				-----------------------
--				C O M P A R A I S O N S

    elsif  M = "CEQ"  then return  22;									--| POP_RBX + cmp + setcc al, movzx, mov (lot 44)
    elsif  M = "CNE"  or else  M = "CGT"  or else  M = "CGE"  or else  M = "CLT"  or else  M = "CLE"
    then return  22;


		-------------------------------------------------------------------------
--		C O M P A R A I S O N S   F L O T T A N T E S   ( S S E 2	d o u b l e )

    elsif  M = "FCEQ"  then return  33;									--| ucomisd + sete, NaN exclu (setnp) ; cellule entiere (lot 44)
    elsif  M = "FCNE"  then return  33;
    elsif  M = "FCGT"  or else  M = "FCGE"  or else  M = "FCLT"
    then return  28;
    elsif  M = "FCLE"  then return  28;									--| ucomisd inverse + setae


			-----------------------------------------------------
--			O P E R A T I O N S	  C O N T R O L E	D E   F L O T

    elsif  M = "BRA"  then return  5;									--| E9 rel32 SYSTEMATIQUE (piege n 82)
    elsif  M = "BT"  or else  M = "BF"  then return 16;							--| POP_RAX + or al,al + jnz rel32 (n 82)
    elsif  M = "CALL"  then return 5;									--| E8/E9 rel32, taille FIXE
    elsif  M = "CALLI"  then return 10;									--| POP_RAX + FF D0
    elsif  M = "RTD"  then
      declare
        P	:constant SYMBOLS.VALUE_TYPE := OPV( E, 1, 0 );
      begin
        if  P = 0  then
	return  1;										--| C3 seul
        elsif  P < 128  then
	return  5;										--| lea rbp,-p8 + C3
        end if;
        return  8;											--| lea rbp,-p32 + C3
      end;

			---------------------------------------------------
--			O P E R A T I O N S	  G E S T I O N   D E   P I L E

    elsif  M = "LINK"  then
      declare
	LVL		: constant SYMBOLS.VALUE_TYPE := OPV( E, 1, 0 );
	A8		: constant SYMBOLS.VALUE_TYPE
			:= 8 * ( ( OPV( E, 2, 0 ) + 7 ) / 8 );
	N		: SYMBOLS.VALUE_TYPE := 10;							--| co-pile : 3 + 3 + 4
      begin
	if LVL > 0
	then
	  N := N + S_FPA( LVL ) + 8;									--| FP(lvl) + PUSH
	  if LVL <= 15
	  then
	    N := N + 4;
	  else
	    N := N + 7;										--| fidele au codi (ModRM 6F + dd :
	  end if;											--| suspect au dela de lvl 15 - a auditer)
	end if;
	if A8 /= 0
	then
	  if A8 < 128
	  then
	    N := N + 4;
	  else
	    N := N + 7;
	  end if;
	end if;
	return N;
      end;

    elsif  M = "UNLINK"  then
      declare
	LVL		: constant SYMBOLS.VALUE_TYPE := OPV( E, 1, 0 );
      begin
	return S_FPA( LVL ) + 8 + S_FPA( LVL ) + 4;							--| FP_IN_RBP + POP_RAX + RAX_IN_FP + copile
      end;

    elsif  M = "UNLINKR"  then
      declare
	LVL		: constant SYMBOLS.VALUE_TYPE := OPV( E, 1, 0 );
      begin
	return S_FPA( LVL ) + 8 + S_FPA( LVL ) + 4 + 3;							--| FP_IN_RBP + POP_RAX + RAX_IN_FP + copile + sommet
      end;

    elsif  M = "PRO"  then return 5;									--| E8/E9 rel32, taille FIXE

    elsif  M = "ELB"  then										--| elab: + LINK lvl, loc_siz - meme compte que LINK
      declare
	LVL	:constant SYMBOLS.VALUE_TYPE := OPV( E, 1, 0 );
	A8	:constant SYMBOLS.VALUE_TYPE
			:= 8 * ( ( SYMBOLS.VALUE_OF( SYMBOLS.RESOLVE( "loc_siz" ) ) + 7 ) / 8 );
	N	: SYMBOLS.VALUE_TYPE := 10;
      begin
        if  LVL > 0  then
	N := N + S_FPA( LVL ) + 8;
	if  LVL <= 15  then
	  N := N + 4;
	else
	  N := N + 7;
	end if;
        end if;
        if  A8 /= 0  then
	if  A8 < 128  then
	  N := N + 4;
	else
	  N := N + 7;
	end if;
        end if;
        return N;
      end;

    elsif  M = "BEGIN_BLOC_DEF"  then return 5;								--| BRA IMAGES.skip (les db suivent, inline)

    elsif  M = "CO_VAR"  then return  28;

    elsif  M = "HEAP_ALLOC"  then return  34;

    elsif  M = "EXC_MACH"  then									--| pilier 11 : photo machine (codi) - chemin froid,
      declare											--| deplacements disp32 UNIFORMES : taille fixe
        LVL	:constant SYMBOLS.VALUE_TYPE := OPV( E, 1, 0 );
      begin
        if  LVL < 0  or else  LVL > 31  then
	FAULT( "EXC_MACH : lvl hors 0..31 (assert du codi)" );
        end if;
        return  S_FPA( LVL ) + 57;
      end;

    elsif  M = "EXC_RAISE"  then return  53;								--| deroulage : instance unique, taille fixe


		-----------------------------------------------------------------------------
--		O P E R A T I O N S	  L O G I Q U E S	D E   B L O C   (LRM 4.5.1) -- lot D3

    elsif  M = "BLKAND"  or else  M = "BLKOU"  or else  M = "BLKOUX"  then
      return  41;											--| BLK_OP_OCTET (and 20 / or 08 / xor 30)

    elsif  M = "BLKNOT"  then return  29;								--| xor byte 1 (NON booleen par octet)
    elsif  M = "BLKMOV"  then return  34;
    elsif  M = "BLKCMP"  then return  45;
    elsif  M = "LEXCMP"  then									--| 96 + paire de charges normalisees
      declare
        SIZC	:constant SYMBOLS.VALUE_TYPE	:= OPV( E, 1, 8 );
        SGN	:constant SYMBOLS.VALUE_TYPE	:= OPV( E, 2, 0 );
      begin
        if  SIZC = 1  or else  SIZC = 2  then
	if  SGN = 1  then  return  104;  end if;
	return  102;
        elsif  SIZC = 4  then
	if  SGN = 1  then  return  102;  end if;
	return  100;
        elsif  SIZC = 8  then
	return  102;
        end if;
        FAULT( "LEXCMP : taille de composant non supportee" );
        return  0;
      end;


				------------------------------
--				SPECIFIQUE  L I N U X   X86-64

    elsif  M = "SYS_CLOCK_GETTIME"  then return  19;							--| clock_gettime(REALTIME, @timespec)
    elsif  M = "SYS_PUT_CHAR"  then return  18;
    elsif  M = "SYS_PUT_STR"  then return  31;								--| POP_RSI (8) + 23
    elsif  M = "SYS_GET_CHAR"  then return  91;
    elsif  M = "SYS_GET_STR"  then return  41;
    elsif  M = "SYS_FILE_CREATE"  then return  60;							--| + jrcxz (chaine vide) dans E_COPY_STRING_NUL
    elsif  M = "SYS_FILE_OPEN"  then return  56;
    elsif  M = "SYS_FILE_SET_POS"  then return  28;
    elsif  M = "SYS_FILE_GET_POS"  then return  23;							--| lseek(SEEK_CUR, 0) - resultat sur [rbp]
    elsif  M = "SYS_FILE_GET_SIZE"  then return  51;							--| lseek END puis SET (position preservee)
    elsif  M = "SYS_FILE_WRITE"  or else  M = "SYS_FILE_READ"  then return  33;
    elsif  M = "SYS_FILE_CLOSE"  then return  17;
    elsif  M = "SYS_FILE_DELETE"  then return  52;
    elsif  M = "SYS_EXIT"  then
      if  IR.N_OPS( E ) >= 1  and then  IR.OP_TAG( E, 1 ) = IR.INT_OP  and then  IR.OP_INT( E, 1 ) /= 0  then
        return  10;
      end if;
      return 7;											--| code = 0 : xor edi, edi

    end if;

    FAULT( "mnemonique hors tranche TC-04 : " & M );
    return 0;								--| jamais atteint

  end	SIZE_OF;
	-------


			------
  procedure		ENCODE		( E :IR.ELT_ID )
  is			------

    M			: constant STRING		:= LEX.IMAGE( IR.MNEMO_OF( E ) );
    V			: SYMBOLS.VALUE_TYPE;

  begin
    if  M = "DROP"  then
      B( 16#48# ); B( 16#8D# ); B( 16#6D# ); B( 16#F8# );

    elsif  M = "DUP"  then
      B( 16#48# ); B( 16#8B# ); B( 16#45# ); B( 16#00# );
      B( 16#48# ); B( 16#89# ); B( 16#45# ); B( 16#08# );
      B( 16#48# ); B( 16#8D# ); B( 16#6D# ); B( 16#08# );

--    elsif  M = "db"  then  EMIT_DB( E );
--    elsif  M = "rd"  then  null;									--| pure declaration : zero octet
--    elsif  M = "rq"  then  null;									--| pure declaration : zero octet


			---------------------------------------------------
--			L O A D	C O N S T A N T E S	  I M M E D I A T E S

    elsif  M = "LI"  then
      if  IR.N_OPS( E ) < 1  then
        FAULT( "LI : operande attendu" );
      end if;

      B( 16#48# ); B( 16#B8# );									--| movabs rax, imm64
      Q64( OPV( E, 1, 0 ) );										--| litteral, nom ou EXPR (corpus : LI size*8)
      E_PUSH_RAX;

    elsif  M = "LIF"  then
      if  IR.N_OPS( E ) < 1  or else  IR.OP_TAG( E, 1 ) /= IR.FLT_OP  then
        FAULT( "LIF : litteral flottant attendu" );
      end if;

      B( 16#48# ); B( 16#B8# );									--| movabs rax, imm64 (IEEE double)
      Q64F( IR.OP_FLT( E, 1 ) );
      E_PUSH_RAX;


			-------------------------------------------------------------
--			L O A D	C O N S T A N T  /  V A R I A B L E   A D R E S S E

    elsif  M = "LCA"  then
      if  IR.N_OPS( E ) < 1  or else  IR.OP_TAG( E, 1 ) /= IR.NAME_OP  then
        FAULT( "LCA : nom attendu" );
      end if;
      SYMBOLS.USE_SCOPE( IR.SCOPE_OF( E ) );
      V := SYMBOLS.VALUE_OF( SYMBOLS.RESOLVE( LEX.IMAGE( IR.OP_TXT( E, 1 ) ) ) );
      if  IR.N_OPS( E ) >= 2  and then  IR.OP_TAG( E, 2 ) = IR.INT_OP  then
	V := V + IR.OP_INT( E, 2 );
      elsif  IR.N_OPS( E ) >= 2  and then  IR.OP_TAG( E, 2 ) = IR.EXPR_OP  then
	V := V + LEX.EVAL( IR.OP_TXT( E, 2 ) );
      end if;
      B( 16#48# ); B( 16#B8# );									--| movabs rax, ptr+disp
      Q64( V );
      E_PUSH_RAX;

    elsif  M = "LSPA"  then
      V := ELAB_TARGET( E );
      B( 16#48# ); B( 16#B8# );									--| movabs rax, .elab (forme canonique)
      Q64( V );
      E_PUSH_RAX;

    elsif  M = "LVA"  then
      declare
        D		:constant SYMBOLS.VALUE_TYPE := OPV( E, 2, 0 );
      begin
        E_BASE( OPV( E, 1, -1 ) );
        if  D /= 0  then
	B( 16#48# ); B( 16#8D# );									--| lea rax, [rax+d]
	E_MODRM_DISP( 16#00#, 16#40#, 16#80#, D );
        end if;
        E_PUSH_RAX;
      end;

    elsif M = "LIVA"
    then
      declare
	O		: constant SYMBOLS.VALUE_TYPE := OPV( E, 3, 0 );
      begin
	E_IBASE( OPV( E, 1, -1 ), OPV( E, 2, 0 ) );
	if O /= 0
	then
	  B( 16#48# ); B( 16#8D# );									--| lea rax, [rax+ofs]
	  E_MODRM_DISP( 16#00#, 16#40#, 16#80#, O );
	end if;
	E_PUSH_RAX;
      end;


				-----------------
--				L O A D	D A T A		(unsigned/signed)

    elsif  M = "ULB"  then
      E_BASE( OPV( E, 1, -1 ) );
      E_FETCH_BU( OPV( E, 2, 0 ) );
      E_PUSH_RAX;

    elsif  M = "ULW"  then
      E_BASE( OPV( E, 1, -1 ) );
      E_FETCH_WU( OPV( E, 2, 0 ) );
      E_PUSH_RAX;

    elsif  M = "ULD"  then
      E_BASE( OPV( E, 1, -1 ) );
      E_FETCH_DU( OPV( E, 2, 0 ) );
      E_PUSH_RAX;

    elsif  M = "LB"  then
      E_BASE( OPV( E, 1, -1 ) );
      E_FETCH_B( OPV( E, 2, 0 ) );
      E_PUSH_RAX;

    elsif  M = "LW"  then
      E_BASE( OPV( E, 1, -1 ) );
      E_FETCH_W( OPV( E, 2, 0 ) );
      E_PUSH_RAX;

    elsif  M = "LD"  then
      E_BASE( OPV( E, 1, -1 ) );
      E_FETCH_D( OPV( E, 2, 0 ) );
      E_PUSH_RAX;

    elsif  M = "LQ"  or else  M = "LA"  then
      E_BASE( OPV( E, 1, -1 ) );
      E_FETCH_Q( OPV( E, 2, 0 ) );
      E_PUSH_RAX;

    elsif  M = "ULIB"  then
      E_IBASE( OPV( E, 1, -1 ), OPV( E, 2, 0 ) );
      E_FETCH_BU( OPV( E, 3, 0 ) );
      E_PUSH_RAX;

    elsif  M = "ULIW"  then
      E_IBASE( OPV( E, 1, -1 ), OPV( E, 2, 0 ) );
      E_FETCH_WU( OPV( E, 3, 0 ) );
      E_PUSH_RAX;

    elsif  M = "ULID"  then
      E_IBASE( OPV( E, 1, -1 ), OPV( E, 2, 0 ) );
      E_FETCH_DU( OPV( E, 3, 0 ) );
      E_PUSH_RAX;

    elsif  M = "LIB"  then
      E_IBASE( OPV( E, 1, -1 ), OPV( E, 2, 0 ) );
      E_FETCH_B( OPV( E, 3, 0 ) );
      E_PUSH_RAX;

    elsif  M = "LIW"  then
      E_IBASE( OPV( E, 1, -1 ), OPV( E, 2, 0 ) );
      E_FETCH_W( OPV( E, 3, 0 ) );
      E_PUSH_RAX;

    elsif M = "LID"  then
      E_IBASE( OPV( E, 1, -1 ), OPV( E, 2, 0 ) );
      E_FETCH_D( OPV( E, 3, 0 ) );
      E_PUSH_RAX;

    elsif M = "LIQ"  or else  M = "LIA"  then												--| LIA = LIQ (alias du codi)
      E_IBASE( OPV( E, 1, -1 ), OPV( E, 2, 0 ) );
      E_FETCH_Q( OPV( E, 3, 0 ) );
      E_PUSH_RAX;

				-------------------
--				S T O R E	  D A T A

    elsif  M = "SB"  then
      E_POP_RBX;
      E_BASE( OPV( E, 1, -1 ) );
      E_STORE_B( OPV( E, 2, 0 ) );

    elsif  M = "SW"  then
      E_POP_RBX;
      E_BASE( OPV( E, 1, -1 ) );
      E_STORE_W( OPV( E, 2, 0 ) );

    elsif  M = "SD"  then
      E_POP_RBX;
      E_BASE( OPV( E, 1, -1 ) );
      E_STORE_D( OPV( E, 2, 0 ) );

    elsif  M = "SQ"  or else  M = "SA"  then
      E_POP_RBX;
      E_BASE( OPV( E, 1, -1 ) );
      E_STORE_Q( OPV( E, 2, 0 ) );

    elsif  M = "SIB"  then
      E_POP_RBX;
      E_IBASE( OPV( E, 1, -1 ), OPV( E, 2, 0 ) );
      E_STORE_B( OPV( E, 3, 0 ) );

    elsif  M = "SIW"  then
      E_POP_RBX;
      E_IBASE( OPV( E, 1, -1 ), OPV( E, 2, 0 ) );
      E_STORE_W( OPV( E, 3, 0 ) );

    elsif M = "SID"
    then
      E_POP_RBX;
      E_IBASE( OPV( E, 1, -1 ), OPV( E, 2, 0 ) );
      E_STORE_D( OPV( E, 3, 0 ) );

    elsif M = "SIQ"  or else  M = "SIA"  then
      E_POP_RBX;
      E_IBASE( OPV( E, 1, -1 ), OPV( E, 2, 0 ) );
      E_STORE_Q( OPV( E, 3, 0 ) );


		-------------------------------------
--		O P E R A T I O N S	  L O G I Q U E S

    elsif  M = "ET"  then
      E_POP_RAX;
      B( 16#48# ); B( 16#21# ); B( 16#45# ); B( 16#00# );

    elsif  M = "OU"  then										--| ou logique
      E_POP_RAX;
      B( 16#48# ); B( 16#09# ); B( 16#45# ); B( 16#00# );							--| or qword [rbp], rax

    elsif  M = "NON"  then										--| non bit a bit
      B( 16#48# ); B( 16#F7# ); B( 16#55# ); B( 16#00# );							--| not qword [rbp]

    elsif M  = "OUX"  then										--| xor qword [rbp], rax
      E_POP_RAX;
      B( 16#48# ); B( 16#31# ); B( 16#45# ); B( 16#00# );

    elsif  M = "SHL"  then										--| shl qword [rbp], cl
      E_POP_RCX;
      B( 16#48# ); B( 16#D3# ); B( 16#65# ); B( 16#00# );

    elsif  M = "SHR"  then										--| decalage droit logique
      E_POP_RCX;
      B( 16#48# ); B( 16#D3# ); B( 16#6D# ); B( 16#00# );							--| shr qword [rbp], cl



		-----------------------------------------
--		O P E R A T I O N S	  B I T	F I E L D S

    elsif  M = "UBFX"  then										--| extraction de champ non signe
      E_POP_RDX;											--| Width
      E_POP_RCX;											--| LSB
      B( 16#48# ); B( 16#8B# ); B( 16#45# ); B( 16#00# );							--| mov rax, [rbp]
      B( 16#48# ); B( 16#D3# ); B( 16#E8# );								--| shr rax, cl
      B( 16#48# ); B( 16#89# ); B( 16#D1# );								--| mov rcx, rdx
      B( 16#6A# ); B( 16#01# ); B( 16#5A# );								--| rdx := 1
      B( 16#48# ); B( 16#D3# ); B( 16#E2# );								--| shl rdx, cl
      B( 16#48# ); B( 16#FF# ); B( 16#CA# );								--| dec rdx (masque)
      B( 16#48# ); B( 16#21# ); B( 16#D0# );								--| and rax, rdx
      B( 16#48# ); B( 16#89# ); B( 16#45# ); B( 16#00# );							--| mov [rbp], rax

    elsif  M = "SBFX"  then										--| extraction de champ signe
      E_POP_RDX;											--| Width
      E_POP_RCX;											--| LSB
      B( 16#48# ); B( 16#8B# ); B( 16#45# ); B( 16#00# );							--| mov rax, [rbp]
      B( 16#48# ); B( 16#D3# ); B( 16#E8# );								--| shr rax, cl
      B( 16#6A# ); B( 16#40# ); B( 16#59# );								--| rcx := 64
      B( 16#48# ); B( 16#29# ); B( 16#D1# );								--| sub rcx, rdx (64 - Width)
      B( 16#48# ); B( 16#D3# ); B( 16#E0# );								--| shl rax, cl
      B( 16#48# ); B( 16#D3# ); B( 16#F8# );								--| sar rax, cl (extension)
      B( 16#48# ); B( 16#89# ); B( 16#45# ); B( 16#00# );							--| mov [rbp], rax

    elsif  M = "BFI"  then										--| insertion de champ dans [rbp]
      E_POP_RCX;											--| Width
      E_POP_RDX;											--| LSB
      E_POP_RAX;											--| valeur a inserer
      B( 16#6A# ); B( 16#01# ); B( 16#5B# );								--| rbx := 1
      B( 16#48# ); B( 16#D3# ); B( 16#E3# );								--| shl rbx, cl
      B( 16#48# ); B( 16#FF# ); B( 16#CB# );								--| dec rbx (masque)
      B( 16#48# ); B( 16#21# ); B( 16#D8# );								--| and rax, rbx
      B( 16#48# ); B( 16#89# ); B( 16#D1# );								--| mov rcx, rdx (LSB)
      B( 16#48# ); B( 16#D3# ); B( 16#E0# );								--| shl rax, cl
      B( 16#48# ); B( 16#D3# ); B( 16#E3# );								--| shl rbx, cl
      B( 16#48# ); B( 16#F7# ); B( 16#D3# );								--| not rbx
      B( 16#48# ); B( 16#21# ); B( 16#5D# ); B( 16#00# );							--| and [rbp], rbx (nettoyer)
      B( 16#48# ); B( 16#09# ); B( 16#45# ); B( 16#00# );							--| or [rbp], rax (inserer)


		-------------------------------------------------------------
--		O P E R A T I O N S	  A R I T H M E T I Q U E   E N T I E R E

    elsif  M = "DEC"  then										--| dec qword [rbp]
      B( 16#48# ); B( 16#FF# ); B( 16#4D# ); B( 16#00# );
      E_JCC_NE( 16#80# );										--| jo ne_raise_ (lot 46, faute 129)

    elsif  M = "INC"  then										--| inc qword [rbp]
      B( 16#48# ); B( 16#FF# ); B( 16#45# ); B( 16#00# );
      E_JCC_NE( 16#80# );										--| jo ne_raise_ (lot 46, faute 129)

    elsif  M = "NEG"  then										--| neg qword [rbp]
      B( 16#48# ); B( 16#F7# ); B( 16#5D# ); B( 16#00# );
      E_JCC_NE( 16#80# );										--| jo ne_raise_ (lot 46, faute 129)

    elsif  M = "ABS"  then										--| valeur absolue entiere
      B( 16#48# ); B( 16#8B# ); B( 16#45# ); B( 16#00# );							--| mov rax, [rbp]
      B( 16#48# ); B( 16#C1# ); B( 16#F8# ); B( 16#3F# );							--| sar rax, 63 (allsign)
      B( 16#48# ); B( 16#31# ); B( 16#45# ); B( 16#00# );							--| xor [rbp], rax
      B( 16#48# ); B( 16#29# ); B( 16#45# ); B( 16#00# );							--| sub [rbp], rax
      E_JCC_NE( 16#80# );										--| jo ne_raise_ (lot 46, faute 129)

    elsif  M = "CLAMP0"  then										--| sommet := max(0, sommet)
      B( 16#48# ); B( 16#8B# ); B( 16#45# ); B( 16#00# );
      B( 16#48# ); B( 16#C1# ); B( 16#F8# ); B( 16#3F# );
      B( 16#48# ); B( 16#F7# ); B( 16#D0# );
      B( 16#48# ); B( 16#21# ); B( 16#45# ); B( 16#00# );

    elsif  M = "ADD"  then
      E_POP_RAX;
      B( 16#48# ); B( 16#01# ); B( 16#45# ); B( 16#00# );							--| add qword [rbp], rax
      E_JCC_NE( 16#80# );										--| jo ne_raise_ (lot 46, faute 129)

    elsif  M = "SUB"  then
      E_POP_RAX;
      B( 16#48# ); B( 16#29# ); B( 16#45# ); B( 16#00# );							--| sub qword [rbp], rax
      E_JCC_NE( 16#80# );										--| jo ne_raise_ (lot 46, faute 129)

    elsif  M = "MUL"  then
      E_POP_RAX;
      B( 16#48# ); B( 16#F7# ); B( 16#6D# ); B( 16#00# );							--| imul qword [rbp]
      E_JCC_NE( 16#80# );										--| jo ne_raise_ (lot 46, faute 129)
      B( 16#48# ); B( 16#8D# ); B( 16#6D# ); B( 16#F8# );							--| DROP
      E_PUSH_RAX;

    elsif  M = "DIV"  then										--| division signee tronquee
      E_POP_RBX;
      E_POP_RAX;
      E_DIVISEUR_NON_NUL;									--| lot 46 : fautes 128, 129 (V8)
      B( 16#48# ); B( 16#83# ); B( 16#FB# ); B( 16#FF# );							--| cmp rbx, -1
      B( 16#75# ); B( 16#0B# );									--| jne +11
      B( 16#48# ); B( 16#F7# ); B( 16#D8# );								--| neg rax (a / -1 = -a)
      E_JCC_NE( 16#80# );										--| jo ne_raise_ (-2**63 / -1)
      B( 16#EB# ); B( 16#05# );									--| jmp +5 (sans idiv)
      B( 16#48# ); B( 16#99# );
      B( 16#48# ); B( 16#F7# ); B( 16#FB# );
      E_PUSH_RAX;

    elsif  M = "REMI"  then										--| reste (signe du dividende)
      E_POP_RBX;
      E_POP_RAX;
      E_DIVISEUR_NON_NUL;									--| lot 46 : faute 128 ; a rem -1 = 0
      B( 16#48# ); B( 16#83# ); B( 16#FB# ); B( 16#FF# );							--| cmp rbx, -1
      B( 16#75# ); B( 16#04# );									--| jne +4
      B( 16#31# ); B( 16#C0# );									--| xor eax, eax
      B( 16#EB# ); B( 16#08# );									--| jmp +8 (sans idiv : -2**63 rem -1 = 0)
      B( 16#48# ); B( 16#99# );
      B( 16#48# ); B( 16#F7# ); B( 16#FB# );
      B( 16#48# ); B( 16#89# ); B( 16#D0# );
      E_PUSH_RAX;

    elsif  M = "MODI"  then										--| modulo Ada (signe du diviseur)
      E_POP_RBX;
      E_POP_RAX;
      E_DIVISEUR_NON_NUL;									--| lot 46 : faute 128 ; a rem -1 = 0
      B( 16#48# ); B( 16#83# ); B( 16#FB# ); B( 16#FF# );							--| cmp rbx, -1
      B( 16#75# ); B( 16#04# );									--| jne +4
      B( 16#31# ); B( 16#C0# );									--| xor eax, eax
      B( 16#EB# ); B( 16#18# );									--| jmp +24 (sans idiv : -2**63 rem -1 = 0)
      B( 16#48# ); B( 16#99# );
      B( 16#48# ); B( 16#F7# ); B( 16#FB# );
      B( 16#48# ); B( 16#89# ); B( 16#D0# );
      B( 16#48# ); B( 16#85# ); B( 16#C0# );
      B( 16#74# ); B( 16#0B# );
      B( 16#48# ); B( 16#89# ); B( 16#C1# );
      B( 16#48# ); B( 16#31# ); B( 16#D9# );
      B( 16#79# ); B( 16#03# );
      B( 16#48# ); B( 16#01# ); B( 16#D8# );
      E_PUSH_RAX;

    elsif  M = "SAR"  then										--| decalage droit arithmetique
      E_POP_RCX;
      B( 16#48# ); B( 16#D3# ); B( 16#7D# ); B( 16#00# );							--| sar qword [rbp], cl


	---------------------------------------------------------------------------------------------
--	O P E R A T I O N S	  A R I T H M E T I Q U E   F L O T T A N T E   ( S S E 2	d o u b l e )

    elsif  M = "FADD"  then										--| addsd
      B( 16#F2# ); B( 16#0F# ); B( 16#10# ); B( 16#4D# ); B( 16#00# );
      B( 16#48# ); B( 16#8D# ); B( 16#6D# ); B( 16#F8# );
      B( 16#F2# ); B( 16#0F# ); B( 16#10# ); B( 16#45# ); B( 16#00# );
      B( 16#F2# ); B( 16#0F# ); B( 16#58# ); B( 16#C1# );
      B( 16#F2# ); B( 16#0F# ); B( 16#11# ); B( 16#45# ); B( 16#00# );

    elsif  M = "FSUB"  then										--| subsd
      B( 16#F2# ); B( 16#0F# ); B( 16#10# ); B( 16#4D# ); B( 16#00# );
      B( 16#48# ); B( 16#8D# ); B( 16#6D# ); B( 16#F8# );
      B( 16#F2# ); B( 16#0F# ); B( 16#10# ); B( 16#45# ); B( 16#00# );
      B( 16#F2# ); B( 16#0F# ); B( 16#5C# ); B( 16#C1# );
      B( 16#F2# ); B( 16#0F# ); B( 16#11# ); B( 16#45# ); B( 16#00# );

    elsif  M = "FMUL"  then										--| mulsd
      B( 16#F2# ); B( 16#0F# ); B( 16#10# ); B( 16#4D# ); B( 16#00# );
      B( 16#48# ); B( 16#8D# ); B( 16#6D# ); B( 16#F8# );
      B( 16#F2# ); B( 16#0F# ); B( 16#10# ); B( 16#45# ); B( 16#00# );
      B( 16#F2# ); B( 16#0F# ); B( 16#59# ); B( 16#C1# );
      B( 16#F2# ); B( 16#0F# ); B( 16#11# ); B( 16#45# ); B( 16#00# );

    elsif  M = "FDIV"  then										--| divsd
      B( 16#F2# ); B( 16#0F# ); B( 16#10# ); B( 16#4D# ); B( 16#00# );
      B( 16#48# ); B( 16#8D# ); B( 16#6D# ); B( 16#F8# );
      B( 16#F2# ); B( 16#0F# ); B( 16#10# ); B( 16#45# ); B( 16#00# );
      B( 16#F2# ); B( 16#0F# ); B( 16#5E# ); B( 16#C1# );
      B( 16#F2# ); B( 16#0F# ); B( 16#11# ); B( 16#45# ); B( 16#00# );

    elsif  M = "FNEG"  then										--| bascule du bit de signe IEEE
      B( 16#80# ); B( 16#75# ); B( 16#07# ); B( 16#80# );

    elsif  M = "FABS"  then										--| bit 63 a zero (signe IEEE 754)
      B( 16#80# ); B( 16#65# ); B( 16#07# ); B( 16#7F# );							--| and byte [rbp+7], 7F

    elsif  M = "FEXP"  then										--| A ** N (N entier positif depile)
      E_POP_RCX;
      B( 16#F2# ); B( 16#0F# ); B( 16#10# ); B( 16#45# ); B( 16#00# );					--| movsd xmm0, [rbp] (base)
      B( 16#48# ); B( 16#B8# ); B( 16#00# ); B( 16#00# ); B( 16#00# ); B( 16#00# ); B( 16#00# ); B( 16#00# );
			B( 16#F0# ); B( 16#3F# );							--| movabs rax, 1.0
      B( 16#66# ); B( 16#48# ); B( 16#0F# ); B( 16#6E# ); B( 16#C8# );					--| movq xmm1, rax (accumulateur)
      B( 16#48# ); B( 16#85# ); B( 16#C9# );								--| test rcx, rcx
      B( 16#74# ); B( 16#09# );									--| jz +9 (N = 0 : resultat 1.0)
      B( 16#F2# ); B( 16#0F# ); B( 16#59# ); B( 16#C8# );							--| mulsd xmm1, xmm0
      B( 16#48# ); B( 16#FF# ); B( 16#C9# );								--| dec rcx
      B( 16#75# ); B( 16#F7# );									--| jnz -9
      B( 16#F2# ); B( 16#0F# ); B( 16#11# ); B( 16#4D# ); B( 16#00# );					--| movsd [rbp], xmm1


	---------------------------------------------------------
--	C O N V E R S I O N S   E N T I E R  <->  F L O T T A N T

    elsif  M = "CVTIF"  then										--| entier -> double (cvtsi2sd)
      B( 16#48# ); B( 16#8B# ); B( 16#45# ); B( 16#00# );
      B( 16#F2# ); B( 16#48# ); B( 16#0F# ); B( 16#2A# ); B( 16#C0# );
      B( 16#F2# ); B( 16#0F# ); B( 16#11# ); B( 16#45# ); B( 16#00# );

    elsif  M = "CVTFI"  then										--| double -> entier, troncature (cvttsd2si)
      B( 16#F2# ); B( 16#0F# ); B( 16#10# ); B( 16#45# ); B( 16#00# );
      B( 16#F2# ); B( 16#48# ); B( 16#0F# ); B( 16#2C# ); B( 16#C0# );
      B( 16#48# ); B( 16#89# ); B( 16#45# ); B( 16#00# );

    elsif  M = "CVTFIR"  then										--| double -> entier, arrondi machine (cvtsd2si)
      B( 16#F2# ); B( 16#0F# ); B( 16#10# ); B( 16#45# ); B( 16#00# );
      B( 16#F2# ); B( 16#48# ); B( 16#0F# ); B( 16#2D# ); B( 16#C0# );
      B( 16#48# ); B( 16#89# ); B( 16#45# ); B( 16#00# );


	---------------------------------------------------
--	C O N V E R S I O N S   E N T I E R  <->  F I X E D

    elsif  M = "CVTIX"  then										--| entier -> fixed : I * DENOM / NUMER
      E_POP_RBX;
      E_POP_RCX;
      E_POP_RAX;
      E_DIVISEUR_NON_NUL;									--| lot 46 : faute 128
      B( 16#48# ); B( 16#F7# ); B( 16#E9# );								--| imul rcx (128 bits)
      E_DIVISION_EXACTE;									--| lot 46 : quotient tronque, faute 129
      E_SIGNE_QUOTIENT;
      E_PUSH_RAX;

    elsif  M = "CVTXI"  then										--| X * NUMER / DENOM, arrondi au plus pres
      E_POP_RBX;											--| DENOM
      E_POP_RCX;											--| NUMER
      E_POP_RAX;											--| X
      E_DIVISEUR_NON_NUL;									--| lot 46 : faute 128
      B( 16#48# ); B( 16#F7# ); B( 16#E9# );								--| imul rcx
      E_DIVISION_EXACTE;									--| |q| dans rax, |r| dans rdx, |DENOM| dans rbx
      B( 16#48# ); B( 16#29# ); B( 16#D3# );								--| sub rbx, rdx (|DENOM| - |r|)
      B( 16#48# ); B( 16#39# ); B( 16#DA# );								--| cmp rdx, rbx
      B( 16#72# ); B( 16#0A# );									--| jb +10 (2.|r| < |DENOM| : pas d'arrondi)
      B( 16#48# ); B( 16#83# ); B( 16#C0# ); B( 16#01# );							--| add rax, 1 (a l'ecart de zero)
      E_JCC_NE( 16#82# );										--| jc ne_raise_ (|q| + 1 = 2**64)
      E_SIGNE_QUOTIENT;									--| sur le quotient exact arrondi (V8, [Q16])
      E_PUSH_RAX;


				-----------------------
--				C O M P A R A I S O N S

    elsif  M = "CEQ"  then
      E_POP_RBX;
      B( 16#48# ); B( 16#39# ); B( 16#5D# ); B( 16#00# );							--| cmp [rbp], rbx
      E_SETCC_CELLULE( 16#94# );								--| lot 44 : cellule entiere

    elsif  M = "CNE"  then										--| A /= B
      E_POP_RBX;
      B( 16#48# ); B( 16#39# ); B( 16#5D# ); B( 16#00# );
      E_SETCC_CELLULE( 16#95# );								--| lot 44 : cellule entiere

    elsif  M = "CGT"  then										--| A > B
      E_POP_RBX;
      B( 16#48# ); B( 16#39# ); B( 16#5D# ); B( 16#00# );
      E_SETCC_CELLULE( 16#9F# );								--| lot 44 : cellule entiere

    elsif  M = "CGE"  then										--| A >= B
      E_POP_RBX;
      B( 16#48# ); B( 16#39# ); B( 16#5D# ); B( 16#00# );
      E_SETCC_CELLULE( 16#9D# );								--| lot 44 : cellule entiere

    elsif  M = "CLT"  then										--| A < B
      E_POP_RBX;
      B( 16#48# ); B( 16#39# ); B( 16#5D# ); B( 16#00# );
      E_SETCC_CELLULE( 16#9C# );								--| lot 44 : cellule entiere

    elsif  M = "CLE"  then										--| A <= B
      E_POP_RBX;
      B( 16#48# ); B( 16#39# ); B( 16#5D# ); B( 16#00# );
      E_SETCC_CELLULE( 16#9E# );								--| lot 44 : cellule entiere


		-------------------------------------------------------------------------
--		C O M P A R A I S O N S   F L O T T A N T E S   ( S S E 2	d o u b l e )

    elsif  M = "FCEQ"  then										--| egalite flottante (NaN exclu)
      B( 16#F2# ); B( 16#0F# ); B( 16#10# ); B( 16#4D# ); B( 16#00# );					--| movsd xmm1, [rbp] (B)
      B( 16#48# ); B( 16#8D# ); B( 16#6D# ); B( 16#F8# );							--| DROP
      B( 16#F2# ); B( 16#0F# ); B( 16#10# ); B( 16#45# ); B( 16#00# );					--| movsd xmm0, [rbp] (A)
      B( 16#66# ); B( 16#0F# ); B( 16#2E# ); B( 16#C1# );							--| ucomisd xmm0, xmm1
      B( 16#0F# ); B( 16#94# ); B( 16#C0# );								--| sete al (lot 44)
      B( 16#0F# ); B( 16#9B# ); B( 16#C1# );								--| setnp cl (pas NaN)
      B( 16#20# ); B( 16#C8# );									--| and al, cl
      B( 16#0F# ); B( 16#B6# ); B( 16#C0# );								--| movzx eax, al
      B( 16#48# ); B( 16#89# ); B( 16#45# ); B( 16#00# );							--| mov [rbp], rax

    elsif  M = "FCNE"  then										--| A /= B flottant (NaN -> vrai)
      B( 16#F2# ); B( 16#0F# ); B( 16#10# ); B( 16#4D# ); B( 16#00# );
      B( 16#48# ); B( 16#8D# ); B( 16#6D# ); B( 16#F8# );
      B( 16#F2# ); B( 16#0F# ); B( 16#10# ); B( 16#45# ); B( 16#00# );
      B( 16#66# ); B( 16#0F# ); B( 16#2E# ); B( 16#C1# );
      B( 16#0F# ); B( 16#95# ); B( 16#C0# );								--| setne al (lot 44)
      B( 16#0F# ); B( 16#9A# ); B( 16#C1# );								--| setp cl (NaN)
      B( 16#08# ); B( 16#C8# );									--| or al, cl
      B( 16#0F# ); B( 16#B6# ); B( 16#C0# );								--| movzx eax, al
      B( 16#48# ); B( 16#89# ); B( 16#45# ); B( 16#00# );							--| mov [rbp], rax

    elsif  M = "FCGT"  then										--| A > B flottant
      B( 16#F2# ); B( 16#0F# ); B( 16#10# ); B( 16#4D# ); B( 16#00# );
      B( 16#48# ); B( 16#8D# ); B( 16#6D# ); B( 16#F8# );
      B( 16#F2# ); B( 16#0F# ); B( 16#10# ); B( 16#45# ); B( 16#00# );
      B( 16#66# ); B( 16#0F# ); B( 16#2E# ); B( 16#C1# );
      E_SETCC_CELLULE( 16#97# );								--| lot 44 : cellule entiere

    elsif  M = "FCGE"  then										--| A >= B flottant
      B( 16#F2# ); B( 16#0F# ); B( 16#10# ); B( 16#4D# ); B( 16#00# );
      B( 16#48# ); B( 16#8D# ); B( 16#6D# ); B( 16#F8# );
      B( 16#F2# ); B( 16#0F# ); B( 16#10# ); B( 16#45# ); B( 16#00# );
      B( 16#66# ); B( 16#0F# ); B( 16#2E# ); B( 16#C1# );
      E_SETCC_CELLULE( 16#93# );								--| lot 44 : cellule entiere

    elsif  M = "FCLT"  then										--| A < B flottant (ucomisd inverse)
      B( 16#F2# ); B( 16#0F# ); B( 16#10# ); B( 16#4D# ); B( 16#00# );
      B( 16#48# ); B( 16#8D# ); B( 16#6D# ); B( 16#F8# );
      B( 16#F2# ); B( 16#0F# ); B( 16#10# ); B( 16#45# ); B( 16#00# );
      B( 16#66# ); B( 16#0F# ); B( 16#2E# ); B( 16#C8# );
      E_SETCC_CELLULE( 16#97# );								--| lot 44 : cellule entiere

    elsif  M = "FCLE"  then										--| A <= B flottant
      B( 16#F2# ); B( 16#0F# ); B( 16#10# ); B( 16#4D# ); B( 16#00# );					--| movsd xmm1, [rbp] (B)
      B( 16#48# ); B( 16#8D# ); B( 16#6D# ); B( 16#F8# );							--| DROP
      B( 16#F2# ); B( 16#0F# ); B( 16#10# ); B( 16#45# ); B( 16#00# );					--| movsd xmm0, [rbp] (A)
      B( 16#66# ); B( 16#0F# ); B( 16#2E# ); B( 16#C8# );							--| ucomisd xmm1, xmm0 (inverse)
      E_SETCC_CELLULE( 16#93# );								--| lot 44 : cellule entiere


			-----------------------------------------------------
--			O P E R A T I O N S	  C O N T R O L E	D E   F L O T

    elsif  M = "BRA"  then
      if  IR.N_OPS( E ) < 1  or else  IR.OP_TAG( E, 1 ) /= IR.NAME_OP  then
        FAULT( "BRA : label attendu" );
      end if;
      SYMBOLS.USE_SCOPE( IR.SCOPE_OF( E ) );
      V := SYMBOLS.VALUE_OF( SYMBOLS.RESOLVE( LEX.IMAGE( IR.OP_TXT( E, 1 ) ) ) );
      B( 16#E9# );											--| jmp rel32
      D32( INTEGER( V - ( ORG + SYMBOLS.VALUE_TYPE( TOP ) + 4 ) ) );						--| disp = cible - fin d'instruction

    elsif  M = "BT"  then
      if  IR.N_OPS( E ) < 1  or else  IR.OP_TAG( E, 1 ) /= IR.NAME_OP  then
        FAULT( "BT : label attendu" );
      end if;
      V := SYMBOLS.VALUE_OF( SYMBOLS.RESOLVE( LEX.IMAGE( IR.OP_TXT( E, 1 ) ) ) );
      E_POP_RAX;
      B( 16#08# ); B( 16#C0# );									--| or al, al
      B( 16#0F# ); B( 16#85# );									--| jnz rel32 (n 82)
      D32( INTEGER( V - ( ORG + SYMBOLS.VALUE_TYPE( TOP ) + 4 ) ) );

    elsif  M = "BF"  then										--| branch false : comme BT, jz rel32
      if  IR.N_OPS( E ) < 1  or else  IR.OP_TAG( E, 1 ) /= IR.NAME_OP  then
        FAULT( "BF : label attendu" );
      end if;
      V := SYMBOLS.VALUE_OF( SYMBOLS.RESOLVE( LEX.IMAGE( IR.OP_TXT( E, 1 ) ) ) );
      E_POP_RAX;
      B( 16#08# ); B( 16#C0# );									--| or al, al
      B( 16#0F# ); B( 16#84# );									--| jz rel32
      D32( INTEGER( V - ( ORG + SYMBOLS.VALUE_TYPE( TOP ) + 4 ) ) );

    elsif  M = "CALL"  then
      V := ELAB_TARGET( E );
      B( 16#E8# );											--| call rel32 vers .elab (lazy reel)
      D32( INTEGER( V - ( ORG + SYMBOLS.VALUE_TYPE( TOP ) + 4 ) ) );

    elsif  M = "CALLI"  then
      E_POP_RAX;
      B( 16#FF# ); B( 16#D0# );									--| call rax

    elsif  M = "RTD"  then
      declare
        P		: constant SYMBOLS.VALUE_TYPE := OPV( E, 1, 0 );
      begin
        if  P /= 0  then
	B( 16#48# ); B( 16#8D# );
	if  P < 128  then
	  B( 16#6D# ); B( INTEGER( ( -P ) mod 256 ) );							--| lea rbp, [rbp - p8]
	else
	  B( 16#AD# );
	  D32( INTEGER( -P ) );									--| lea rbp, [rbp - p32]
	end if;
        end if;
        B( 16#C3# );										--| ret (micro-pile rsp)
      end;


			---------------------------------------------------
--			O P E R A T I O N S	  G E S T I O N   D E   P I L E

    elsif  M = "LINK"  then
      declare
        LVL	: constant SYMBOLS.VALUE_TYPE		:= OPV( E, 1, 0 );
        A8	: constant SYMBOLS.VALUE_TYPE		:= 8 * ( ( OPV( E, 2, 0 ) + 7 ) / 8 );
      begin
        if  LVL > 0  then
	E_FPA( LVL );
	E_PUSH_RAX;
	B( 16#49# ); B( 16#89# );
	if  LVL <= 15  then
	  B( 16#6F# ); B( INTEGER( 8 * LVL ) );								--| mov [r15+8l], rbp
	else
	  B( 16#6F# );										--| FIDELE AU CODI (ModRM 6F + dd : suspect
	  D32( INTEGER( 8 * LVL ) );									--| au dela de lvl 15, jamais exerce - auditer
	end if;											--| DES DEUX COTES le jour venu)
        end if;
        if  A8 /= 0  then
	B( 16#48# ); B( 16#8D# );
	if  A8 < 128  then
	  B( 16#6D# ); B( INTEGER( A8 ) );								--| lea rbp, [rbp+alloc8]
	else
	  B( 16#AD# );
	  D32( INTEGER( A8 ) );									--| lea rbp, [rbp+alloc32]
	end if;
        end if;
        B( 16#4D# ); B( 16#89# ); B( 16#2E# );								--| mov [r14], r13
        B( 16#4D# ); B( 16#89# ); B( 16#F5# );								--| mov r13, r14
        B( 16#4D# ); B( 16#8D# ); B( 16#76# ); B( 16#08# );							--| lea r14, [r14+8]
      end;

    elsif  M = "UNLINK"  then
      declare
        LVL	: constant SYMBOLS.VALUE_TYPE		:= OPV( E, 1, 0 );
      begin
        E_FP_RBP( LVL );
        E_POP_RAX;
        E_RAX_FP( LVL );
        B( 16#4D# ); B( 16#8B# ); B( 16#6D# ); B( 16#00# );							--| mov r13, [r13]
      end;

    elsif  M = "UNLINKR"  then
      declare
        LVL	: constant SYMBOLS.VALUE_TYPE		:= OPV( E, 1, 0 );
      begin
        E_FP_RBP( LVL );
        E_POP_RAX;
        E_RAX_FP( LVL );
        B( 16#4D# ); B( 16#89# ); B( 16#EE# );								--| mov r14, r13
        B( 16#4D# ); B( 16#8B# ); B( 16#6D# ); B( 16#00# );							--| mov r13, [r13]
      end;

    elsif  M = "PRO"  then
      V := SYMBOLS.VALUE_OF( SYMBOLS.RESOLVE( "post" ) );							--| contournement d'elaboration
      B( 16#E9# );
      D32( INTEGER( V - ( ORG + SYMBOLS.VALUE_TYPE( TOP ) + 4 ) ) );

--    elsif M = "PRMS"  or else  M = "PRM"  or else  M = "endPRMS"						--| reservation statique (TC-12)
--    then  null;											--| pure declaration : zero octet

    elsif  M = "ELB"  then										--| LINK lvl, loc_siz (elab deja adresse en P2B)
      declare
        LVL		: constant SYMBOLS.VALUE_TYPE := OPV( E, 1, 0 );
        A8		: constant SYMBOLS.VALUE_TYPE
			:= 8 * ( ( SYMBOLS.VALUE_OF( SYMBOLS.RESOLVE( "loc_siz" ) ) + 7 ) / 8 );
      begin
        if  LVL > 0  then
	E_FPA( LVL );
	E_PUSH_RAX;
	B( 16#49# ); B( 16#89# );
	if  LVL <= 15  then
	  B( 16#6F# ); B( INTEGER( 8 * LVL ) );
	else
	  B( 16#6F# );										--| fidele au codi (suspect > 15, cf. TC-06)
	  D32( INTEGER( 8 * LVL ) );
	end if;
        end if;
        if  A8 /= 0  then
	B( 16#48# ); B( 16#8D# );
	if  A8 < 128  then
	  B( 16#6D# ); B( INTEGER( A8 ) );
	else
	  B( 16#AD# );
	  D32( INTEGER( A8 ) );
	end if;
        end if;
        B( 16#4D# ); B( 16#89# ); B( 16#2E# );
        B( 16#4D# ); B( 16#89# ); B( 16#F5# );
        B( 16#4D# ); B( 16#8D# ); B( 16#76# ); B( 16#08# );
      end;

    elsif  M = "BEGIN_BLOC_DEF"  then									--| BRA IMAGES.skip (resolution posee a P2B)
      V := SYMBOLS.VALUE_OF( SYMBOLS.RESOLVE( "IMAGES.skip" ) );
      B( 16#E9# );
      D32( INTEGER( V - ( ORG + SYMBOLS.VALUE_TYPE( TOP ) + 4 ) ) );

--    elsif  M = "END_BLOC_DEF"  then
--      declare
--        D0	: constant SYMBOLS.VALUE_TYPE
--			:= SYMBOLS.VALUE_OF( SYMBOLS.RESOLVE( "IMAGES.data" ) );
--        D1	: constant SYMBOLS.VALUE_TYPE
--			:= SYMBOLS.VALUE_OF( SYMBOLS.RESOLVE( "IMAGES.data_end" ) );
--      begin
--        D32( INTEGER( 8 * ( D1 - D0 ) ) );								--| info : longueur en BITS
--        D32( 8 );
--        D32( 1 );
--        D32( INTEGER( D1 - D0 ) );
--        while  ( ORG + SYMBOLS.VALUE_TYPE( TOP ) ) mod 8 /= 0  loop
--	B( 16#90# );										--| align_q : bourrage NOP
--        end loop;
--        D32( INTEGER( OPV( E, 1, 0 ) ) );								--| SIZ (en bits pour un enumere)
--        D32( INTEGER( OPV( E, 2, 0 ) ) );								--| FST
--        D32( INTEGER( OPV( E, 3, 0 ) ) );								--| LST
--        D32( 0 );
--        Q64( D0 );											--| data_ptr
--        Q64( SYMBOLS.VALUE_OF( SYMBOLS.RESOLVE( "IMAGES.info" ) ) );						--| info_ptr
--      end;

--    elsif  M = "STR"  or else  M = "CST"  then
--      null;											--| differe : emis apres le code par DO_DEFERRED

--    elsif  M = "USEINFO"  or else  M = "STATOFS"  or else  M = "VAR"  then
--      null;											--| pure declaration : zero octet

    elsif  M = "CO_VAR"  then										--| alloue N octets (arrondis qword) sur la
      E_POP_RAX;											--| co-pile, empile l'adresse de debut de bloc
      B( 16#4C# ); B( 16#89# ); B( 16#75# ); B( 16#08# );							--| mov [rbp+8], r14
      B( 16#48# ); B( 16#8D# ); B( 16#6D# ); B( 16#08# );							--| lea rbp, [rbp+8]
      B( 16#48# ); B( 16#83# ); B( 16#C0# ); B( 16#07# );							--| add rax, 7
      B( 16#48# ); B( 16#C1# ); B( 16#F8# ); B( 16#03# );							--| sar rax, 3
      B( 16#4D# ); B( 16#8D# ); B( 16#34# ); B( 16#C6# );							--| lea r14, [r14 + 8*rax]

    elsif  M = "HEAP_ALLOC"  then									--| alloue N octets (arrondis qword) sur la
      E_POP_RAX;											--| rax = taille demandee
      B( 16#48# ); B( 16#83# ); B( 16#C0# ); B( 16#07# );							--| add rax, 7
      B( 16#48# ); B( 16#C1# ); B( 16#F8# ); B( 16#03# );							--| sar rax, 3	nombre de qwords
      B( 16#48# ); B( 16#C1# ); B( 16#E0# ); B( 16#03# );							--| shl rax, 3	taille alignee en octets
      B( 16#49# ); B( 16#29# ); B( 16#C4# );								--| sub r12, rax	tas descendant depuis le haut reserve
      B( 16#4C# ); B( 16#89# ); B( 16#E0# );								--| mov rax, r12	adresse du nouveau bloc
      E_PUSH_RAX;

--    elsif  M = "endPRO"										--| code expanse au LEX (TC-10)
--    then  null;											--| pure declaration : zero octet

    elsif  M = "EXC_MACH"  then									--| pilier 11 : photographie de l'etat machine
      declare											--| dans le contexte a [FP(lvl) + ctx]
        LVL	:constant SYMBOLS.VALUE_TYPE	:= OPV( E, 1, 0 );
        CTX	:constant SYMBOLS.VALUE_TYPE	:= OPV( E, 2, 0 );
      begin
        if  LVL < 0  or else  LVL > 31  then
	FAULT( "EXC_MACH : lvl hors 0..31 (assert du codi)" );
        end if;
        E_FPA( LVL );										--| rax := FP(lvl)
        B( 16#48# ); B( 16#89# ); B( 16#A8# );								--| mov [rax + ctx+16], rbp
        D32( INTEGER( CTX + 16 ) );
        B( 16#48# ); B( 16#89# ); B( 16#A0# );								--| mov [rax + ctx+24], rsp
        D32( INTEGER( CTX + 24 ) );
        B( 16#4C# ); B( 16#89# ); B( 16#A8# );								--| mov [rax + ctx+32], r13
        D32( INTEGER( CTX + 32 ) );
        B( 16#4C# ); B( 16#89# ); B( 16#B0# );								--| mov [rax + ctx+40], r14
        D32( INTEGER( CTX + 40 ) );
        B( 16#48# ); B( 16#C7# ); B( 16#80# );								--| mov qword [rax + ctx+48], lvl+1   (nlvl)
        D32( INTEGER( CTX + 48 ) );
        D32( INTEGER( LVL + 1 ) );
        B( 16#48# ); B( 16#8D# ); B( 16#B8# );								--| lea rdi, [rax + ctx+56]   (dest. du prefixe)
        D32( INTEGER( CTX + 56 ) );
        B( 16#4C# ); B( 16#89# ); B( 16#FE# );								--| mov rsi, r15   (source : le display)
        B( 16#B9# );										--| mov ecx, lvl+1
        D32( INTEGER( LVL + 1 ) );
        B( 16#F3# ); B( 16#48# ); B( 16#A5# );								--| rep movsq   (FP(0..lvl) -> ctx+56..)
      end;

    elsif  M = "EXC_RAISE"  then									--| deroulage (LRM 11.4.1) : POP avant dispatch ;
      declare											--| atteint par BRA, jamais par CALL
        TOPD	:constant SYMBOLS.VALUE_TYPE	:= OPV( E, 1, 0 );
      begin
        B( 16#49# ); B( 16#8B# ); B( 16#1F# );								--| mov rbx, [r15]      (rbx := FP(0))
        B( 16#48# ); B( 16#8B# ); B( 16#83# );								--| mov rax, [rbx + top]   (contexte sommet)
        D32( INTEGER( TOPD ) );
        B( 16#48# ); B( 16#8B# ); B( 16#08# );								--| mov rcx, [rax]      (PREV_CTX)
        B( 16#48# ); B( 16#89# ); B( 16#8B# );								--| mov [rbx + top], rcx   (POP avant dispatch)
        D32( INTEGER( TOPD ) );
        B( 16#4C# ); B( 16#8B# ); B( 16#68# ); B( 16#20# );							--| mov r13, [rax+32]   (frame pointer co-pile)
        B( 16#4C# ); B( 16#8B# ); B( 16#70# ); B( 16#28# );							--| mov r14, [rax+40]   (sommet co-pile)
        B( 16#48# ); B( 16#8B# ); B( 16#60# ); B( 16#18# );							--| mov rsp, [rax+24]   (micro-pile purgee)
        B( 16#48# ); B( 16#8B# ); B( 16#48# ); B( 16#30# );							--| mov rcx, [rax+48]   (NXT_LVL)
        B( 16#48# ); B( 16#8D# ); B( 16#70# ); B( 16#38# );							--| lea rsi, [rax+56]
        B( 16#4C# ); B( 16#89# ); B( 16#FF# );								--| mov rdi, r15
        B( 16#F3# ); B( 16#48# ); B( 16#A5# );								--| rep movsq   (FP(0..lvl) restaures)
        B( 16#48# ); B( 16#8B# ); B( 16#68# ); B( 16#10# );							--| mov rbp, [rax+16]   (pile de travail)
        B( 16#FF# ); B( 16#60# ); B( 16#08# );								--| jmp [rax+8]   (DISPATCH du frame porteur)
      end;

		-----------------------------------------------------------------------------
--		O P E R A T I O N S	  L O G I Q U E S	D E   B L O C   (LRM 4.5.1) -- lot D3

    elsif  M = "BLKAND"  or else  M = "BLKOU"  or else  M = "BLKOUX"  then					--| [DST] op= [SRC] octet a octet
      declare
        OPC		:INTEGER := 16#20#;								--| and
      begin
        if  M = "BLKOU"  then  OPC := 16#08#;  end if;							--| or
        if  M = "BLKOUX"  then  OPC := 16#30#;  end if;							--| xor
        E_POP_RSI;											--| @SRC
        E_POP_RCX;											--| LEN
        E_POP_RDI;											--| @DST
        B( 16#48# ); B( 16#85# ); B( 16#C9# );								--| test rcx, rcx
        B( 16#74# ); B( 16#0C# );									--| jz fin (LEN = 0)
        B( 16#8A# ); B( 16#06# );									--| mov al, [rsi]
        B( OPC ); B( 16#07# );									--| op [rdi], al
        B( 16#48# ); B( 16#FF# ); B( 16#C6# );								--| inc rsi
        B( 16#48# ); B( 16#FF# ); B( 16#C7# );								--| inc rdi
        B( 16#E2# ); B( 16#F4# );									--| loop
      end;

    elsif  M = "BLKNOT"  then										--| NON booleen par octet (xor 1)
      E_POP_RCX;											--| LEN
      E_POP_RDI;											--| @DST
      B( 16#48# ); B( 16#85# ); B( 16#C9# );								--| test rcx, rcx
      B( 16#74# ); B( 16#08# );									--| jz fin
      B( 16#80# ); B( 16#37# ); B( 16#01# );								--| xor byte [rdi], 1
      B( 16#48# ); B( 16#FF# ); B( 16#C7# );								--| inc rdi
      B( 16#E2# ); B( 16#F8# );									--| loop

    elsif  M = "BLKMOV"  then										--| dest, compte, source empiles (source au sommet)
      E_POP_RSI;
      E_POP_RCX;
      E_POP_RDI;
      B( 16#48# ); B( 16#85# ); B( 16#C9# );								--| test rcx, rcx
      B( 16#74# ); B( 16#05# );									--| jz +5
      B( 16#FC# );											--| cld
      B( 16#AC# );											--| lodsb
      B( 16#AA# );											--| stosb
      B( 16#E2# ); B( 16#FC# );									--| loop

    elsif  M = "BLKCMP"  then										--| dest, compte, source empiles (source au sommet)
      E_POP_RSI;
      E_POP_RCX;
      E_POP_RDI;
      B( 16#31# ); B( 16#C0# );									--| xor eax, eax
      B( 16#48# ); B( 16#85# ); B( 16#C9# );								--| test rcx, rcx
      B( 16#74# ); B( 16#03# );									--| jz +3
      B( 16#FC# );											--| cld
      B( 16#F3# ); B( 16#A6# );									--| repe cmpsb
      B( 16#0F# ); B( 16#94# ); B( 16#C0# );								--| sete al
      E_PUSH_RAX;

    elsif  M = "LEXCMP"  then										--| comparaison lexicographique (LRM 4.5.2)
      declare
        SIZC	:constant SYMBOLS.VALUE_TYPE	:= OPV( E, 1, 8 );
        SGN	:constant SYMBOLS.VALUE_TYPE	:= OPV( E, 2, 0 );
        F		:INTEGER := 6;									--| taille de la paire de charges
      begin
        if  ( SIZC = 1  or else  SIZC = 2 )  and then  SGN = 1  then
	F := 8;
        elsif  SIZC = 4  then
	F := 4;
	if  SGN = 1  then  F := 6;  end if;
        end if;
        E_POP_RDX;											--| LEN_D
        E_POP_RSI;											--| @D
        E_POP_RCX;											--| LEN_G
        E_POP_RDI;											--| @G
        B( 16#48# ); B( 16#85# ); B( 16#C9# );								--| boucle : test rcx, rcx
        B( 16#74# ); B( 28 + F );									--| jz epuise
        B( 16#48# ); B( 16#85# ); B( 16#D2# );								--| test rdx, rdx
        B( 16#74# ); B( 23 + F );									--| jz epuise
        if  SIZC = 1  then
	if  SGN = 1  then
	  B( 16#48# ); B( 16#0F# ); B( 16#BE# ); B( 16#07# ); B( 16#48# ); B( 16#0F# ); B( 16#BE# ); B( 16#1E# );	--| movsx octets
	else
	  B( 16#0F# ); B( 16#B6# ); B( 16#07# ); B( 16#0F# ); B( 16#B6# ); B( 16#1E# );				--| movzx octets
	end if;
        elsif  SIZC = 2  then
	if  SGN = 1  then
	  B( 16#48# ); B( 16#0F# ); B( 16#BF# ); B( 16#07# ); B( 16#48# ); B( 16#0F# ); B( 16#BF# ); B( 16#1E# );	--| movsx mots
	else
	  B( 16#0F# ); B( 16#B7# ); B( 16#07# ); B( 16#0F# ); B( 16#B7# ); B( 16#1E# );				--| movzx mots
	end if;
        elsif  SIZC = 4  then
	if  SGN = 1  then
	  B( 16#48# ); B( 16#63# ); B( 16#07# ); B( 16#48# ); B( 16#63# ); B( 16#1E# );				--| movsxd dwords
	else
	  B( 16#8B# ); B( 16#07# ); B( 16#8B# ); B( 16#1E# );						--| mov dwords (zero-etend)
	end if;
        else
	B( 16#48# ); B( 16#8B# ); B( 16#07# ); B( 16#48# ); B( 16#8B# ); B( 16#1E# );				--| mov qwords
        end if;
        B( 16#48# ); B( 16#39# ); B( 16#D8# );								--| cmp rax, rbx (signee, normalisee)
        B( 16#75# ); B( 16#1E# );									--| jne differe
        B( 16#48# ); B( 16#83# ); B( 16#C7# ); B( INTEGER( SIZC ) );						--| add rdi, siz
        B( 16#48# ); B( 16#83# ); B( 16#C6# ); B( INTEGER( SIZC ) );						--| add rsi, siz
        B( 16#48# ); B( 16#83# ); B( 16#E9# ); B( INTEGER( SIZC ) );						--| sub rcx, siz
        B( 16#48# ); B( 16#83# ); B( 16#EA# ); B( INTEGER( SIZC ) );						--| sub rdx, siz
        B( 16#EB# ); B( 256 - 33 - F );									--| jmp boucle
        B( 16#48# ); B( 16#29# ); B( 16#D1# );								--| epuise : sub rcx, rdx (prefixe commun)
        B( 16#74# ); B( 16#0B# );									--| jz egal
        B( 16#78# ); B( 16#0D# );									--| js moins
        B( 16#6A# ); B( 16#01# ); B( 16#58# );								--| plus : rax := +1
        B( 16#EB# ); B( 16#0B# );									--| jmp empile
        B( 16#7C# ); B( 16#06# );									--| differe : jl moins
        B( 16#EB# ); B( 16#F7# );									--| jmp plus
        B( 16#31# ); B( 16#C0# );									--| egal : rax := 0
        B( 16#EB# ); B( 16#03# );									--| jmp empile
        B( 16#6A# ); B( 16#FF# ); B( 16#58# );								--| moins : rax := -1
        E_PUSH_RAX;											--| empile : -1 / 0 / +1
      end;


				------------------------------
--				SPECIFIQUE  L I N U X   X86-64

    elsif  M = "SYS_CLOCK_GETTIME"  then								--| clock_gettime(REALTIME, @timespec)
      E_POP_RSI;
      B( 16#48# ); B( 16#31# ); B( 16#FF# );								--| xor rdi, rdi (CLOCK_REALTIME)
      B( 16#68# ); B( 16#E4# ); B( 16#00# ); B( 16#00# ); B( 16#00# );					--| push 228
      B( 16#58# );											--| pop rax
      B( 16#0F# ); B( 16#05# );									--| syscall

    elsif  M = "SYS_PUT_CHAR"  then									--| caractere au sommet, ecrit sur stdout, DROP
      B( 16#48# ); B( 16#89# ); B( 16#EE# );
      B( 16#6A# ); B( 16#01# );
      B( 16#58# );
      B( 16#48# ); B( 16#89# ); B( 16#C2# );
      B( 16#48# ); B( 16#89# ); B( 16#C7# );
      B( 16#0F# ); B( 16#05# );
      B( 16#48# ); B( 16#8D# ); B( 16#6D# ); B( 16#F8# );

    elsif  M = "SYS_PUT_STR"  then
      E_POP_RSI;											--| @doublet (name.data_ptr)
      B( 16#48# ); B( 16#8B# ); B( 16#46# ); B( 16#08# );							--| mov rax, [rsi+8]
      B( 16#8B# ); B( 16#50# ); B( 16#0C# );								--| mov edx, [rax+12]  (last)
      B( 16#FF# ); B( 16#C2# );									--| inc edx
      B( 16#2B# ); B( 16#50# ); B( 16#08# );								--| sub edx, [rax+8]   (longueur)
      B( 16#6A# ); B( 16#01# );  B( 16#58# );								--| push 1 ; pop rax   (sys_write)
      B( 16#48# ); B( 16#89# ); B( 16#C7# );								--| mov rdi, rax       (stdout)
      B( 16#48# ); B( 16#8B# ); B( 16#36# );								--| mov rsi, [rsi]     (@caracteres)
      B( 16#0F# ); B( 16#05# );									--| syscall

    elsif  M = "SYS_GET_CHAR"  then									--| lecture stdin non canonique (termios modifie puis restaure)
      B( 16#48# ); B( 16#83# ); B( 16#EC# ); B( 16#40# );
      B( 16#6A# ); B( 16#10# );
      B( 16#58# );
      B( 16#48# ); B( 16#31# ); B( 16#FF# );
      B( 16#48# ); B( 16#C7# ); B( 16#C6# ); B( 16#01# ); B( 16#54# ); B( 16#00# ); B( 16#00# );
      B( 16#48# ); B( 16#89# ); B( 16#E2# );
      B( 16#0F# ); B( 16#05# );
      B( 16#83# ); B( 16#64# ); B( 16#24# ); B( 16#0C# ); B( 16#F5# );
      B( 16#6A# ); B( 16#10# );
      B( 16#58# );
      B( 16#48# ); B( 16#31# ); B( 16#FF# );
      B( 16#48# ); B( 16#C7# ); B( 16#C6# ); B( 16#02# ); B( 16#54# ); B( 16#00# ); B( 16#00# );
      B( 16#48# ); B( 16#89# ); B( 16#E2# );
      B( 16#0F# ); B( 16#05# );
      E_POP_RSI;
      B( 16#6A# ); B( 16#00# );
      B( 16#58# );
      B( 16#48# ); B( 16#89# ); B( 16#C7# );
      B( 16#6A# ); B( 16#01# );
      B( 16#5A# );
      B( 16#0F# ); B( 16#05# );
      B( 16#83# ); B( 16#4C# ); B( 16#24# ); B( 16#0C# ); B( 16#0A# );
      B( 16#6A# ); B( 16#10# );
      B( 16#58# );
      B( 16#48# ); B( 16#31# ); B( 16#FF# );
      B( 16#48# ); B( 16#C7# ); B( 16#C6# ); B( 16#02# ); B( 16#54# ); B( 16#00# ); B( 16#00# );
      B( 16#48# ); B( 16#89# ); B( 16#E2# );
      B( 16#0F# ); B( 16#05# );
      B( 16#48# ); B( 16#83# ); B( 16#C4# ); B( 16#40# );

    elsif  M = "SYS_GET_STR"  then									--| lit une ligne dans la chaine (doublet), reporte la longueur lue
      E_POP_RSI;
      B( 16#48# ); B( 16#8B# ); B( 16#46# ); B( 16#08# );
      B( 16#8B# ); B( 16#50# ); B( 16#0C# );
      B( 16#FF# ); B( 16#C2# );
      B( 16#2B# ); B( 16#50# ); B( 16#08# );
      B( 16#31# ); B( 16#C0# );
      B( 16#31# ); B( 16#FF# );
      B( 16#48# ); B( 16#8B# ); B( 16#36# );
      B( 16#0F# ); B( 16#05# );
      E_POP_RSI;
      B( 16#FF# ); B( 16#C8# );
      B( 16#89# ); B( 16#06# );

    elsif  M = "SYS_FILE_CREATE"  then									--| creat(O_CREAT|O_RDWR|O_TRUNC, u+rwx) - resultat sur [rbp]
      E_POP_RSI;
      E_COPY_STRING_NUL;
      B( 16#6A# ); B( 16#02# );
      B( 16#58# );
      B( 16#BE# ); B( 16#42# ); B( 16#02# ); B( 16#00# ); B( 16#00# );
      B( 16#BA# ); B( 16#C0# ); B( 16#01# ); B( 16#00# ); B( 16#00# );
      B( 16#0F# ); B( 16#05# );
      B( 16#48# ); B( 16#89# ); B( 16#45# ); B( 16#00# );

    elsif  M = "SYS_FILE_OPEN"  then									--| open(RDWR) - resultat sur [rbp]
      E_POP_RSI;
      E_COPY_STRING_NUL;
      B( 16#6A# ); B( 16#02# );
      B( 16#58# );
      B( 16#6A# ); B( 16#02# );
      B( 16#5E# );
      B( 16#48# ); B( 16#31# ); B( 16#D2# );
      B( 16#0F# ); B( 16#05# );
      B( 16#48# ); B( 16#89# ); B( 16#45# ); B( 16#00# );

    elsif  M = "SYS_FILE_SET_POS"  then									--| lseek(SEEK_SET) - resultat sur [rbp]
      E_POP_RDI;
      E_POP_RSI;
      B( 16#48# ); B( 16#31# ); B( 16#D2# );
      B( 16#6A# ); B( 16#08# );
      B( 16#58# );
      B( 16#0F# ); B( 16#05# );
      B( 16#48# ); B( 16#89# ); B( 16#45# ); B( 16#00# );

    elsif  M = "SYS_FILE_GET_POS"  then									--| lseek(fd, 0, SEEK_CUR)
      E_POP_RDI;
      B( 16#48# ); B( 16#31# ); B( 16#F6# );								--| xor rsi, rsi
      B( 16#6A# ); B( 16#01# ); B( 16#5A# );								--| rdx := 1 (SEEK_CUR)
      B( 16#6A# ); B( 16#08# ); B( 16#58# );								--| rax := 8 (lseek)
      B( 16#0F# ); B( 16#05# );									--| syscall
      B( 16#48# ); B( 16#89# ); B( 16#45# ); B( 16#00# );							--| mov [rbp], rax (lieu result)

    elsif  M = "SYS_FILE_GET_SIZE"  then								--| taille, position preservee
      E_POP_RDI;
      B( 16#48# ); B( 16#31# ); B( 16#F6# );								--| xor rsi, rsi
      B( 16#6A# ); B( 16#01# ); B( 16#5A# );								--| SEEK_CUR
      B( 16#6A# ); B( 16#08# ); B( 16#58# ); B( 16#0F# ); B( 16#05# );					--| lseek : position courante
      B( 16#49# ); B( 16#89# ); B( 16#C0# );								--| mov r8, rax
      B( 16#48# ); B( 16#31# ); B( 16#F6# );								--| xor rsi, rsi
      B( 16#6A# ); B( 16#02# ); B( 16#5A# );								--| SEEK_END
      B( 16#6A# ); B( 16#08# ); B( 16#58# ); B( 16#0F# ); B( 16#05# );					--| lseek : taille
      B( 16#49# ); B( 16#89# ); B( 16#C1# );								--| mov r9, rax
      B( 16#4C# ); B( 16#89# ); B( 16#C6# );								--| mov rsi, r8
      B( 16#48# ); B( 16#31# ); B( 16#D2# );								--| xor rdx, rdx (SEEK_SET)
      B( 16#6A# ); B( 16#08# ); B( 16#58# ); B( 16#0F# ); B( 16#05# );					--| lseek : restauration
      B( 16#4C# ); B( 16#89# ); B( 16#4D# ); B( 16#00# );							--| mov [rbp], r9 (lieu result)

    elsif  M = "SYS_FILE_READ"  then									--| read(fd, tampon, longueur) - resultat sur [rbp]
      E_POP_RDI;
      E_POP_RSI;
      E_POP_RDX;
      B( 16#6A# ); B( 16#00# );
      B( 16#58# );
      B( 16#0F# ); B( 16#05# );
      B( 16#48# ); B( 16#89# ); B( 16#45# ); B( 16#00# );

    elsif  M = "SYS_FILE_WRITE"  then									--| write(fd, tampon, longueur) - resultat sur [rbp]
      E_POP_RDI;
      E_POP_RSI;
      E_POP_RDX;
      B( 16#6A# ); B( 16#01# );
      B( 16#58# );
      B( 16#0F# ); B( 16#05# );
      B( 16#48# ); B( 16#89# ); B( 16#45# ); B( 16#00# );

    elsif  M = "SYS_FILE_CLOSE"  then									--| close(fd) - resultat sur [rbp]
      E_POP_RDI;
      B( 16#6A# ); B( 16#03# );
      B( 16#58# );
      B( 16#0F# ); B( 16#05# );
      B( 16#48# ); B( 16#89# ); B( 16#45# ); B( 16#00# );

    elsif  M = "SYS_FILE_DELETE"  then									--| unlink(nom copie NUL-termine) - resultat sur [rbp]
      E_POP_RSI;
      E_COPY_STRING_NUL;
      B( 16#B8# ); B( 16#57# ); B( 16#00# ); B( 16#00# ); B( 16#00# );
      B( 16#0F# ); B( 16#05# );
      B( 16#48# ); B( 16#89# ); B( 16#45# ); B( 16#00# );

    elsif  M = "SYS_EXIT"  then
      B( 16#6A# ); B( 16#3C# );									--| push 60
      B( 16#58# );											--| pop rax
      if IR.N_OPS( E ) >= 1  and then  IR.OP_TAG( E, 1 ) = IR.INT_OP
	 and then  IR.OP_INT( E, 1 ) /= 0
      then
	B( 16#BF# );										--| mov edi, imm32
	D32( INTEGER( IR.OP_INT( E, 1 ) ) );
      else
	B( 16#31# ); B( 16#FF# );									--| xor edi, edi
      end if;
      B( 16#0F# ); B( 16#05# );									--| syscall

    else
      FAULT( "mnemonique hors tranche TC-04 : " & M );
    end if;

  end	ENCODE;
	------


  --|  AMORCAGE (codi queue) : org 0x400000, entree 0x400078 (= 64 ELF +
  --|  56 Phdr), 82 octets : xor rax ; mmap tas 64 Mo (r12 = haut) ; pile
  --|  montante (rsp -4 Mo, r15 display 32, rbp, FP0) ; co-pile (r14 =
  --|  ENTRY + 8*((ASM_SIZE+7)/8), premier frame, r13).

			--------
  procedure		PROLOGUE
  is			--------

    T0			: constant INTEGER := TOP;
    COPILE_BASE		: constant SYMBOLS.VALUE_TYPE
			:= ENTRY_PT + 8 * ( ( ASM + 7 ) / 8 );
  begin
    B( 16#48# ); B( 16#31# ); B( 16#C0# );				--| xor rax, rax
    --  tas : mmap anonyme 64 Mo
    B( 16#48# ); B( 16#31# ); B( 16#FF# );				--| xor rdi, rdi
    B( 16#BE# );  D32( HEAP_SIZE );					--| mov esi, TAILLE_TAS
    B( 16#6A# ); B( 16#03# );  B( 16#5A# );				--| push 3 ; pop rdx
    B( 16#41# ); B( 16#BA# ); B( 16#22# ); B( 0 ); B( 0 ); B( 0 );	--| mov r10d, 0x22
    B( 16#49# ); B( 16#C7# ); B( 16#C0# );
    B( 16#FF# ); B( 16#FF# ); B( 16#FF# ); B( 16#FF# );			--| mov r8, -1
    B( 16#45# ); B( 16#31# ); B( 16#C9# );				--| xor r9d, r9d
    B( 16#6A# ); B( 16#09# );  B( 16#58# );				--| push 9 ; pop rax
    B( 16#0F# ); B( 16#05# );						--| syscall
    B( 16#4C# ); B( 16#8D# ); B( 16#A0# );  D32( HEAP_SIZE );		--| lea r12, [rax + TAILLE_TAS]
    --  pile montante + display
    B( 16#48# ); B( 16#8D# ); B( 16#A4# ); B( 16#24# );
    B( 16#00# ); B( 16#00# ); B( 16#C0# ); B( 16#FF# );			--| lea rsp, [rsp - 4 Mo]
    B( 16#49# ); B( 16#89# ); B( 16#E7# );				--| mov r15, rsp
    B( 16#48# ); B( 16#8D# ); B( 16#AC# ); B( 16#24# );
    B( 16#00# ); B( 16#01# ); B( 16#00# ); B( 16#00# );			--| lea rbp, [rsp + 8*32]
    B( 16#49# ); B( 16#89# ); B( 16#2F# );				--| mov [r15], rbp
    --  co-pile
    B( 16#4C# ); B( 16#8D# ); B( 16#34# ); B( 16#25# );
    D32( INTEGER( COPILE_BASE ) );					--| lea r14, [ENTRY + 8*((ASM_SIZE+7)/8)]
    B( 16#4D# ); B( 16#89# ); B( 16#36# );				--| mov [r14], r14
    B( 16#4D# ); B( 16#89# ); B( 16#F5# );				--| mov r13, r14
    B( 16#4D# ); B( 16#8D# ); B( 16#76# ); B( 16#08# );			--| lea r14, [r14 + 8]
    if TOP - T0 /= TRAITS.PROLOGUE_SIZE
    then
      FAULT( "amorcage : longueur inattendue" );
    end if;

  end	PROLOGUE;
	--------


	-------------
end	X86_64_TARGET;
	-------------

------------------------------------------------------------------------------------------------------------------------
--	1	2	3	4	5	6	7	8	9	0	1	2
