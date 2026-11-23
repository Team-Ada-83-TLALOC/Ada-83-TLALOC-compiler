WITH REPORT; USE REPORT;
PROCEDURE ELAB1 IS
     SUBTYPE SM IS INTEGER RANGE 1 .. 10;
     TYPE R (D : SM := 1) IS RECORD V : INTEGER := 0; END RECORD;
     TYPE AR IS ACCESS R;
     NB : INTEGER := 0;
     FUNCTION F (X : INTEGER) RETURN INTEGER IS
     BEGIN
          NB := NB + 1;
          RETURN X;
     END F;
BEGIN
     TEST ("ELAB1", "CONTRAINTES ELABOREES UNE FOIS, CONTROLEES A L'ELABORATION");
     DECLARE
          SUBTYPE S IS R (F (3));
          SUBTYPE A3 IS AR (F (3));
          TYPE T IS ACCESS R (F (3));
          X, Y : S;
          P : A3 := NEW R (3);
          Q : T := NEW R'(3, 0);
          Z : AR := NEW S;
     BEGIN
          IF NB /= 3 THEN FAILED ("EVALUATIONS A L'ELABORATION :" & INTEGER'IMAGE (NB)); END IF;
          IF X.D /= 3 OR Y.D /= 3 OR Z.D /= 3 THEN FAILED ("VALEURS"); END IF;
          IF NOT (P IN A3) OR NOT (X IN S) THEN FAILED ("APPARTENANCE"); END IF;
          P := NEW R (3);
          IF NB /= 3 THEN FAILED ("REEVALUATION :" & INTEGER'IMAGE (NB)); END IF;
     END;
     BEGIN
          DECLARE
               SUBTYPE S0 IS R (F (0));
          BEGIN
               FAILED ("SOUS-TYPE : PAS D'EXCEPTION");
          END;
     EXCEPTION WHEN CONSTRAINT_ERROR => NULL;
     END;
     BEGIN
          DECLARE
               TYPE T11 IS ACCESS R (F (11));
          BEGIN
               FAILED ("TYPE D'ACCES : PAS D'EXCEPTION");
          END;
     EXCEPTION WHEN CONSTRAINT_ERROR => NULL;
     END;
     BEGIN
          DECLARE
               SUBTYPE A11 IS AR (11);
          BEGIN
               FAILED ("SOUS-TYPE D'ACCES : PAS D'EXCEPTION");
          END;
     EXCEPTION WHEN CONSTRAINT_ERROR => NULL;
     END;
     RESULT;
END ELAB1;
