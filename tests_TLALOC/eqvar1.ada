WITH REPORT; USE REPORT;
PROCEDURE EQVAR1 IS
     SUBTYPE PETIT IS INTEGER RANGE 0 .. 10;
     TYPE R (D : PETIT := 2; E : INTEGER := 1) IS
          RECORD
               C : CHARACTER := 'C';
               CASE E IS
                    WHEN 1 =>
                         S1 : STRING (1 .. D) := (1 .. D => 'X');
                    WHEN 2 .. 4 =>
                         S2 : INTEGER := 0;
                         CASE D IS
                              WHEN 0 | 1 => T1 : BOOLEAN := TRUE;
                              WHEN OTHERS => T2 : STRING (1 .. D) := (1 .. D => 'Y');
                         END CASE;
                    WHEN OTHERS =>
                         NULL;
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
     X1 : R (3, 1) := (3, 1, 'C', "ABC");
     Y1 : R (3, 1) := (3, 1, 'C', "ABC");
     Z1 : R (IDENT_INT (3), 1) := (3, 1, 'C', "ABD");
     X2 : R (4, 3) := (4, 3, 'C', 7, "WXYZ");
     Y2 : R (4, 3);
     X3 : R (1, 2) := (1, 2, 'C', 5, FALSE);
     X4 : R (5, 9);
     Y4 : R (5, 9);
     M  : R;
     SA : S (5) := (5, (4, 5, 6));
     SB : S (5) := (5, (4, 5, 6));
     SC : S (12) := (12, 'Q');
BEGIN
     TEST ("EQVAR1", "EGALITE DE RECORDS A VARIANTES, DYNAMIQUES ET STATIQUES (LRM 4.5.2)");
     IF X1 /= Y1 THEN FAILED ("X1 /= Y1"); END IF;
     IF X1 = Z1 THEN FAILED ("X1 = Z1"); END IF;
     IF X1 /= (3, 1, 'C', "ABC") THEN FAILED ("X1 /= AGREGAT"); END IF;
     Y2 := (4, 3, 'C', 7, "WXYZ");
     IF X2 /= Y2 THEN FAILED ("X2 /= Y2 (INTERVALLE, VARIANTE IMBRIQUEE)"); END IF;
     Y2.T2 (IDENT_INT (2)) := 'Q';
     IF X2 = Y2 THEN FAILED ("X2 = Y2 APRES MODIFICATION DE T2"); END IF;
     IF X3 /= (1, 2, 'C', 5, FALSE) OR X3 = (1, 2, 'C', 5, TRUE) THEN FAILED ("X3 : T1"); END IF;
     IF X4 /= Y4 THEN FAILED ("X4 /= Y4 (OTHERS => NULL)"); END IF;
     Y4.C := 'D';
     IF X4 = Y4 THEN FAILED ("X4 = Y4 APRES MODIFICATION DE C"); END IF;
     M := X2;
     IF M /= X2 OR M = X1 THEN FAILED ("M := X2"); END IF;
     M := (3, 1, 'C', "ABC");
     IF M /= X1 OR M = Z1 THEN FAILED ("M := AGREGAT"); END IF;
     IF SA /= SB THEN FAILED ("SA /= SB (CHAMP TABLEAU)"); END IF;
     SB.A (IDENT_INT (3)) := 0;
     IF SA = SB THEN FAILED ("SA = SB APRES MODIFICATION"); END IF;
     IF SC /= (12, 'Q') OR SC = (12, 'R') THEN FAILED ("SC"); END IF;
     RESULT;
END EQVAR1;
