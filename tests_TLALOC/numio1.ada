WITH REPORT; USE REPORT;
WITH TEXT_IO; USE TEXT_IO;
PROCEDURE NUMIO1 IS
     PACKAGE IIO IS NEW INTEGER_IO (INTEGER);
     TYPE PETIT IS RANGE 1 .. 10;
     PACKAGE PIO IS NEW INTEGER_IO (PETIT);
     TYPE FL IS DIGITS 3;
     PACKAGE FIO IS NEW FLOAT_IO (FL);
     TYPE FX IS DELTA 0.001 RANGE -200.0 .. 200.0;
     PACKAGE XIO IS NEW FIXED_IO (FX);
     TYPE COULEUR IS (ROUGE, VERT_PALE, 'A');
     PACKAGE CIO IS NEW ENUMERATION_IO (COULEUR);
     USE IIO, FIO, XIO, CIO;
     X : INTEGER := 402;
     P : PETIT := 5;
     R : FL := 1.0;
     Y : FX := 1.0;
     K : COULEUR := ROUGE;
     L : POSITIVE := 4;
     F : FILE_TYPE;
     C : CHARACTER;
     S : STRING (1 .. 10);
     LIGNE : STRING (1 .. 80);

     PROCEDURE ENTIER (T : STRING; V, LV : INTEGER) IS
     BEGIN
          GET (T, X, L);
          IF X /= V OR L /= LV THEN FAILED ("ENTIER """ & T & """"); END IF;
     EXCEPTION
          WHEN OTHERS => FAILED ("ENTIER : EXCEPTION SUR """ & T & """");
     END ENTIER;

     PROCEDURE MAUVAIS_ENTIER (T : STRING) IS
     BEGIN
          X := 402;
          GET (T, X, L);
          FAILED ("ENTIER : DATA_ERROR ATTENDU SUR """ & T & """");
     EXCEPTION
          WHEN DATA_ERROR => IF X /= 402 THEN FAILED ("ITEM TOUCHE " & T); END IF;
          WHEN OTHERS => FAILED ("ENTIER : AUTRE EXCEPTION SUR """ & T & """");
     END MAUVAIS_ENTIER;

     PROCEDURE REEL (T : STRING; V : FL; LV : INTEGER) IS
     BEGIN
          GET (T, R, L);
          IF R /= V OR L /= LV THEN FAILED ("FLOAT """ & T & """"); END IF;
          GET (T, Y, L);
          IF ABS (Y - FX (V)) > 0.001 OR L /= LV THEN FAILED ("FIXED """ & T & """"); END IF;
     EXCEPTION
          WHEN OTHERS => FAILED ("REEL : EXCEPTION SUR """ & T & """");
     END REEL;

     PROCEDURE MAUVAIS_REEL (T : STRING) IS
     BEGIN
          BEGIN
               R := 1.0;
               GET (T, R, L);
               FAILED ("FLOAT : DATA_ERROR ATTENDU SUR """ & T & """");
          EXCEPTION
               WHEN DATA_ERROR => IF R /= 1.0 THEN FAILED ("ITEM TOUCHE " & T); END IF;
               WHEN OTHERS => FAILED ("FLOAT : AUTRE EXCEPTION SUR """ & T & """");
          END;
          BEGIN
               GET (T, Y, L);
               FAILED ("FIXED : DATA_ERROR ATTENDU SUR """ & T & """");
          EXCEPTION
               WHEN DATA_ERROR => NULL;
               WHEN OTHERS => FAILED ("FIXED : AUTRE EXCEPTION SUR """ & T & """");
          END;
     END MAUVAIS_REEL;

BEGIN
     TEST ("NUMIO1", "GET ET PUT NUMERIQUES ET ENUMERES (LRM 14.3.5 A 14.3.9)");

     -- 1. INTEGER_IO.GET sur chaine : syntaxe, base, LAST, END_ERROR.
     ENTIER ("  123", 123, 5);
     ENTIER ("-12_3 ", -123, 5);
     ENTIER ("16#FF#", 255, 6);
     ENTIER ("2:101:E2", 20, 8);
     ENTIER ("2.15", 2, 1);
     ENTIER (ASCII.HT & "+7", 7, 3);
     ENTIER ("1E3", 1000, 3);
     MAUVAIS_ENTIER ("_312");
     MAUVAIS_ENTIER ("12__3");
     MAUVAIS_ENTIER ("312_");
     MAUVAIS_ENTIER ("17#1#");
     MAUVAIS_ENTIER ("2#102#");
     MAUVAIS_ENTIER ("16#FF:");
     MAUVAIS_ENTIER ("1E-1");
     MAUVAIS_ENTIER ("- 5");
     MAUVAIS_ENTIER ("99999999999");
     BEGIN
          L := 4;
          GET ("  ", X, L);
          FAILED ("ENTIER : END_ERROR ATTENDU");
     EXCEPTION
          WHEN END_ERROR => IF L /= 4 THEN FAILED ("LAST TOUCHE"); END IF;
     END;
     BEGIN
          PIO.GET ("11", P, L);
          FAILED ("DATA_ERROR ATTENDU HORS DE NUM");
     EXCEPTION
          WHEN DATA_ERROR => NULL;
     END;

     -- 2. FLOAT_IO et FIXED_IO.GET sur chaine.
     REEL (" 2.5", 2.5, 4);
     REEL ("-1_2.2_5E-1 ", -1.225, 11);
     REEL ("16#A.8#", 10.5, 7);
     REEL ("2:1.1:E2", 6.0, 8);
     REEL ("0.5E+1X", 5.0, 6);
     MAUVAIS_REEL ("12");
     MAUVAIS_REEL ("12E1");
     MAUVAIS_REEL ("12.");
     MAUVAIS_REEL (".5");
     MAUVAIS_REEL ("1.5E");
     MAUVAIS_REEL ("16#A.8:");
     MAUVAIS_REEL ("17#1.0#");
     MAUVAIS_REEL ("1__0.0");

     -- 3. ENUMERATION_IO.GET sur chaine : lexeme entier, casse.
     GET (ASCII.HT & "vert_pale,", K, L);
     IF K /= VERT_PALE OR L /= 10 THEN FAILED ("ENUM VERT_PALE"); END IF;
     GET ("'A'", K, L);
     IF K /= 'A' OR L /= 3 THEN FAILED ("ENUM 'A'"); END IF;
     BEGIN
          GET ("ROUGEATRE", K, L);
          FAILED ("ENUM : DATA_ERROR ATTENDU (PREFIXE)");
     EXCEPTION
          WHEN DATA_ERROR => NULL;
     END;
     BEGIN
          GET ("'a'", K, L);
          FAILED ("ENUM : DATA_ERROR ATTENDU ('a')");
     EXCEPTION
          WHEN DATA_ERROR => NULL;
     END;

     -- 4. GET sur fichier : WIDTH, reprise apres DATA_ERROR, fin.
     CREATE (F, OUT_FILE, "numio1.txt");
     PUT (F, "3.14152"); NEW_LINE (F);
     PUT (F, "  123"); NEW_LINE (F);
     PUT (F, "-312_ 45 1.25 3.5X ROUGE"); NEW_LINE (F);
     PUT (F, "-3.525");
     CLOSE (F);
     OPEN (F, IN_FILE, "numio1.txt");
     BEGIN
          GET (F, X, 3);
          FAILED ("FICHIER : DATA_ERROR ATTENDU (3.1)");
     EXCEPTION
          WHEN DATA_ERROR => NULL;
     END;
     GET (F, C);
     IF C /= '4' THEN FAILED ("FICHIER : POSITION APRES 3.1"); END IF;
     SKIP_LINE (F);
     GET (F, X, 5);
     IF X /= 123 THEN FAILED ("FICHIER : WIDTH 5"); END IF;
     BEGIN
          GET (F, X, 2);
          FAILED ("FICHIER : DATA_ERROR ATTENDU EN FIN DE LIGNE");
     EXCEPTION
          WHEN DATA_ERROR => NULL;
     END;
     BEGIN
          GET (F, X);
          FAILED ("FICHIER : DATA_ERROR ATTENDU (-312_)");
     EXCEPTION
          WHEN DATA_ERROR => NULL;
     END;
     GET (F, X);
     IF X /= 45 THEN FAILED ("FICHIER : REPRISE APRES DATA_ERROR"); END IF;
     GET (F, R);
     IF R /= 1.25 THEN FAILED ("FICHIER : 1.25"); END IF;
     GET (F, Y);
     IF Y /= 3.5 THEN FAILED ("FICHIER : 3.5"); END IF;
     BEGIN
          GET (F, R);
          FAILED ("FICHIER : DATA_ERROR ATTENDU (X)");
     EXCEPTION
          WHEN DATA_ERROR => NULL;
     END;
     GET (F, C);
     GET (F, K);
     IF K /= ROUGE THEN FAILED ("FICHIER : ROUGE"); END IF;
     SKIP_LINE (F);
     GET (F, Y, 6);
     IF Y /= -3.525 THEN FAILED ("FICHIER : FIXE ARRONDI AU PLUS PROCHE"); END IF;
     BEGIN
          GET (F, X);
          FAILED ("FICHIER : END_ERROR ATTENDU");
     EXCEPTION
          WHEN END_ERROR => NULL;
     END;

     -- 5. PUT : format, CONSTRAINT_ERROR, LAYOUT_ERROR.
     RESET (F, OUT_FILE);
     PUT (F, FL (134.0), FORE => 1);
     PUT (F, '#');
     PUT (F, FL (134.0), FORE => 1, AFT => 2, EXP => 1);
     PUT (F, '#');
     PUT (F, FX (120.0), FORE => 3, AFT => 0);
     PUT (F, '#');
     PUT (F, 'A', SET => LOWER_CASE);
     PUT (F, VERT_PALE, SET => LOWER_CASE);
     NEW_LINE (F);
     BEGIN
          PIO.PUT (F, 11);
          FAILED ("PUT : CONSTRAINT_ERROR ATTENDU");
     EXCEPTION
          WHEN CONSTRAINT_ERROR => NULL;
     END;
     SET_LINE_LENGTH (F, 4);
     BEGIN
          PUT (F, 32_000, WIDTH => 0);
          FAILED ("PUT : LAYOUT_ERROR ATTENDU");
     EXCEPTION
          WHEN LAYOUT_ERROR => NULL;
     END;
     PUT (F, 123, WIDTH => 0);
     PUT (F, 457, WIDTH => 0);
     IF LINE (F) /= 3 OR COL (F) /= 4 THEN FAILED ("PUT : NEW_LINE AVANT 457"); END IF;
     RESET (F, IN_FILE);
     GET_LINE (F, LIGNE, L);
     IF LIGNE (1 .. L) /= "1.34E+02#1.34E+2#120.0#'A'vert_pale" THEN
          FAILED ("PUT : FORMAT """ & LIGNE (1 .. L) & """");
     END IF;
     GET_LINE (F, LIGNE, L);
     IF LIGNE (1 .. L) /= "123" THEN FAILED ("PUT : 123"); END IF;
     GET_LINE (F, LIGNE, L);
     IF LIGNE (1 .. L) /= "457" THEN FAILED ("PUT : 457"); END IF;
     DELETE (F);

     PUT (S, FL (234.5));
     IF S /= "  2.34E+02" AND S /= "  2.35E+02" THEN FAILED ("PUT CHAINE """ & S & """"); END IF;

     RESULT;
END NUMIO1;
