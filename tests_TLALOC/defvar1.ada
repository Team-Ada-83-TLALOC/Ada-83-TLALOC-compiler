WITH REPORT; USE REPORT;
PROCEDURE DEFVAR1 IS
     SUBTYPE PETIT IS INTEGER RANGE 0 .. 10;
     TYPE R (D : PETIT := 2; E : INTEGER := 1) IS
          RECORD
               C : CHARACTER := 'C';
               CASE E IS
                    WHEN 1 =>
                         S1 : STRING (1 .. D) := (1 .. D => 'X');
                    WHEN 2 .. 4 =>
                         S2 : INTEGER := 7;
                         CASE D IS
                              WHEN 0 | 1 => T1 : BOOLEAN := TRUE;
                              WHEN OTHERS => T2 : STRING (1 .. D) := (1 .. D => 'Y');
                         END CASE;
                    WHEN OTHERS =>
                         N : INTEGER := 99;
               END CASE;
          END RECORD;
     TYPE V3 IS ARRAY (1 .. 3) OF INTEGER;
     TYPE S (K : INTEGER := 0) IS
          RECORD
               CASE K IS
                    WHEN 0 .. 9 => A : V3 := (1, 2, 3);
                    WHEN OTHERS => B : CHARACTER := 'B';
               END CASE;
          END RECORD;
     M  : R;
     P  : R (IDENT_INT (3), IDENT_INT (1));
     Q  : R (IDENT_INT (4), 3);
     Q1 : R (1, IDENT_INT (2));
     W  : R (5, IDENT_INT (9));
     SA : S;
     SB : S (IDENT_INT (12));
BEGIN
     TEST ("DEFVAR1", "VALEURS PAR DEFAUT DES COMPOSANTS DE VARIANTE (LRM 3.7.2)");
     IF M.C /= 'C' OR M.S1 /= "XX" THEN FAILED ("M : S1 /= ""XX"""); END IF;
     IF P.S1 /= "XXX" THEN FAILED ("P : S1 /= ""XXX"""); END IF;
     IF Q.S2 /= 7 OR Q.T2 /= "YYYY" THEN FAILED ("Q : VARIANTE IMBRIQUEE T2"); END IF;
     IF Q1.S2 /= 7 OR NOT Q1.T1 THEN FAILED ("Q1 : VARIANTE IMBRIQUEE T1"); END IF;
     IF W.N /= 99 THEN FAILED ("W : OTHERS => N /= 99"); END IF;
     IF SA.A /= (1, 2, 3) THEN FAILED ("SA : A /= (1, 2, 3)"); END IF;
     IF SB.B /= 'B' THEN FAILED ("SB : B /= 'B'"); END IF;
     RESULT;
END DEFVAR1;
