WITH REPORT; USE REPORT;
WITH TEXT_IO; USE TEXT_IO;
PROCEDURE REEL2 IS
     PACKAGE FIO IS NEW FLOAT_IO (LONG_FLOAT);
     V : LONG_FLOAT; L : POSITIVE;
     A : LONG_FLOAT := 16#F.FF#E+2;
     PROCEDURE T (S : STRING; X : LONG_FLOAT; N : POSITIVE) IS
     BEGIN
          FIO.GET (S, V, L);
          IF V /= X OR L /= N THEN FAILED ("GET " & S); END IF;
     EXCEPTION WHEN OTHERS => FAILED ("EXCEPTION " & S);
     END T;
     PROCEDURE E (S : STRING) IS
     BEGIN
          FIO.GET (S, V, L);
          FAILED ("PAS DE DATA_ERROR " & S);
     EXCEPTION WHEN DATA_ERROR => NULL;
               WHEN OTHERS => FAILED ("AUTRE EXCEPTION " & S);
     END E;
BEGIN
     TEST ("REEL2", "FLOAT_IO.GET : LITTERAUX BASES ET SOULIGNES");
     IF A /= 4095.0 THEN FAILED ("LITTERAL BASE DU SOURCE"); END IF;
     T ("16#F.FF#E+2", 4095.0, 11);
     T ("16#f.ff#e+2", 4095.0, 11);
     T ("16:A.8:", 10.5, 7);
     T (" +2#1.0#E-1 ", 0.5, 11);
     T ("2#1.1#E1", 3.0, 8);
     T ("8#7.7#", 7.875, 6);
     T ("1_000.5", 1000.5, 7);
     T ("1.0E1_0", 1.0E10, 7);
     T ("10#1.5#E1", 15.0, 9);
     T ("3#0.1#", 1.0 / LONG_FLOAT (IDENT_INT (3)), 6);
     T ("-16#0.8#", -0.5, 8);
     -- LRM 14.3.8 (lot 39) : un reel exige un point ; deux soulignes de suite font DATA_ERROR.
     E ("2_5E1"); E ("1__0.0");
     E ("17#1.0#"); E ("16#F.F"); E ("2#1.2#"); E ("5.0E400");
     RESULT;
END REEL2;
