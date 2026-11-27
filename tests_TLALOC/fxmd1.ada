WITH REPORT; USE REPORT;
PROCEDURE FXMD1 IS
     TYPE F40 IS DELTA 2.0 ** (-40) RANGE -4.0 .. 4.0;
     TYPE F12 IS DELTA 2.0 ** (-12) RANGE -100.0 .. 100.0;
     TYPE F20 IS DELTA 2.0 ** (-20) RANGE -1000.0 .. 1000.0;
     A, B, R : F40;
     P, Q    : F12;
     S       : F20;
     DEUX_TIERS : CONSTANT := 2.0 / 3.0;
     SIXIEME    : CONSTANT := 1.0 / 6.0;
BEGIN
     TEST ("FXMD1", "FIXES : ""*"" ET ""/"" EXACTS (LRM 4.5.5)");
     IF EQUAL (3, 3) THEN
          A := 1.5;  B := 2.25;  P := 12.5;  Q := 0.25;
     END IF;
     R := F40 (A * B);                                        -- produit des representations : 2**80 environ
     IF R /= 3.375 THEN FAILED ("F40 (A * B)"); END IF;
     R := F40 (A / B);
     IF ABS (R - DEUX_TIERS) > F40'DELTA THEN FAILED ("F40 (A / B) HORS DE L'INTERVALLE"); END IF;
     R := F40 (B / A);
     IF R /= 1.5 THEN FAILED ("F40 (B / A)"); END IF;
     S := F20 (P * A);                                        -- smalls differents
     IF S /= 18.75 THEN FAILED ("F20 (P * A)"); END IF;
     S := F20 (P / Q);
     IF S /= 50.0 THEN FAILED ("F20 (P / Q)"); END IF;
     S := F20 (Q / A);                                        -- 1/6 : sans pre-troncature de Q
     IF ABS (S - SIXIEME) > F20'DELTA THEN FAILED ("F20 (Q / A) HORS DE L'INTERVALLE"); END IF;
     P := P / IDENT_INT (4);
     IF P /= 3.125 THEN FAILED ("P / 4"); END IF;
     P := P * IDENT_INT (-3);
     IF P /= -9.375 THEN FAILED ("P * (-3)"); END IF;
     S := F20 (P * Q);
     IF S /= -2.34375 THEN FAILED ("F20 (P * Q) NEGATIF"); END IF;
     BEGIN
          Q := 0.0;
          IF EQUAL (3, 3) THEN
               S := F20 (P / Q);
          END IF;
          FAILED ("PAS D'EXCEPTION : DIVISION PAR ZERO");
          IF S = 0.0 THEN COMMENT ("S"); END IF;
     EXCEPTION
          WHEN NUMERIC_ERROR | CONSTRAINT_ERROR => NULL;
     END;
     RESULT;
END FXMD1;
