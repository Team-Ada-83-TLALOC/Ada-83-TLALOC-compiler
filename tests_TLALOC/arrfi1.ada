WITH REPORT; USE REPORT;
WITH TEXT_IO; USE TEXT_IO;
PROCEDURE ARRFI1 IS
     TYPE FT IS DIGITS 6;
     TYPE LT IS RANGE -1_000_000 .. 1_000_000;
     PACKAGE FIO IS NEW FLOAT_IO (FT);
     F : FILE_TYPE;
     S : STRING (1 .. 40);
     L : NATURAL;
     PROCEDURE V (X : FT; I : INTEGER; MSG : STRING) IS
     BEGIN
          IF INTEGER (X) /= I THEN
               FAILED ("INTEGER (" & MSG & ") =" & INTEGER'IMAGE (INTEGER (X)));
          END IF;
     END V;
     PROCEDURE LIGNE (ATTENDU : STRING) IS
     BEGIN
          GET_LINE (F, S, L);
          IF S (1 .. L) /= ATTENDU THEN
               FAILED ("FLOAT_IO.PUT : '" & S (1 .. L) & "' AU LIEU DE '" & ATTENDU & "'");
          END IF;
     END LIGNE;
BEGIN
     TEST ("ARRFI1", "CONVERSION REEL -> ENTIER ARRONDIE (LRM 4.6), FLOAT_IO.PUT");
     V (1.4, 1, "1.4");      V (1.6, 2, "1.6");
     V (-1.4, -1, "-1.4");   V (-1.6, -2, "-1.6");
     V (0.49, 0, "0.49");    V (2.7, 3, "2.7");
     V (FT (IDENT_INT (7)) + 0.9, 8, "7.9");
     IF LT (FT (IDENT_INT (-7)) - 0.6) /= -8 THEN FAILED ("LT"); END IF;
     IF LONG_INTEGER (LONG_FLOAT (IDENT_INT (3)) / 4.0) /= 1 THEN FAILED ("LONG_INTEGER"); END IF;
     CREATE (F, OUT_FILE, "arrfi1.tmp");
     FIO.PUT (F, 4.7, 2, 3, 2);      NEW_LINE (F);
     FIO.PUT (F, -0.0625, 2, 2, 2);  NEW_LINE (F);
     FIO.PUT (F, 9.96, 2, 1, 2);     NEW_LINE (F);
     FIO.PUT (F, 123.456, 3, 4, 3);  NEW_LINE (F);
     FIO.PUT (F, 0.0, 2, 2, 2);      NEW_LINE (F);
     RESET (F, IN_FILE);
     LIGNE (" 4.700E+00");
     LIGNE ("-6.25E-02");
     LIGNE (" 1.0E+01");
     LIGNE ("  1.2346E+002");
     LIGNE (" 0.00E+00");
     DELETE (F);
     RESULT;
END ARRFI1;
