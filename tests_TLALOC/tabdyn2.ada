WITH REPORT; USE REPORT;
PROCEDURE TABDYN2 IS
     SUBTYPE SM IS INTEGER RANGE 1 .. 10;
     TYPE MY_ARR IS ARRAY (SM RANGE <>) OF INTEGER;
     NB : INTEGER := 0;
     FUNCTION F (X : INTEGER) RETURN INTEGER IS
     BEGIN
          NB := NB + 1;
          RETURN X;
     END F;
BEGIN
     TEST ("TABDYN2", "TABLEAUX DE RECORDS DYNAMIQUES : MOMENT DES CONTROLES (LRM 3.6.1, 3.7.2)");
     DECLARE
          TYPE CONS (D : INTEGER) IS RECORD C : MY_ARR (D .. 5); END RECORD;
     BEGIN
          BEGIN
               DECLARE
                    TYPE TA IS ARRAY (1 .. 3) OF CONS (IDENT_INT (0));
               BEGIN
                    FAILED ("CONTRAINT : PAS DE CONTROLE AU TYPE");
               END;
          EXCEPTION WHEN CONSTRAINT_ERROR => NULL;
          END;
          DECLARE
               TYPE TB IS ARRAY (1 .. 3) OF CONS (IDENT_INT (2));
               X : TB;
          BEGIN
               IF X (3).C'FIRST /= 2 OR X (1).C'LENGTH /= 4 THEN FAILED ("TB"); END IF;
          END;
     END;
     DECLARE
          TYPE MUT (D : INTEGER := IDENT_INT (0)) IS RECORD C : MY_ARR (D .. 5); END RECORD;
          TYPE TM IS ARRAY (1 .. 2) OF MUT;
     BEGIN
          BEGIN
               DECLARE
                    Y : TM;
               BEGIN
                    FAILED ("NON CONTRAINT : PAS DE CONTROLE A L'OBJET");
               END;
          EXCEPTION WHEN CONSTRAINT_ERROR => NULL;
          END;
     EXCEPTION WHEN OTHERS => FAILED ("NON CONTRAINT : CONTROLE AU TYPE (TROP TOT)");
     END;
     DECLARE
          TYPE MUT2 (D : SM := F (3)) IS RECORD C : MY_ARR (1 .. D); END RECORD;
          TYPE TM2 IS ARRAY (1 .. 4) OF MUT2;
          Z : TM2;
     BEGIN
          IF Z (4).D /= 3 OR Z (2).C'LAST /= 3 THEN FAILED ("Z"); END IF;
          Z (2) := (10, (1 .. 10 => 1));
          IF Z (2).C'LAST /= 10 OR Z (3).D /= 3 OR Z (2).C (10) /= 1 THEN FAILED ("Z (2) MUTABLE"); END IF;
     END;
     RESULT;
END TABDYN2;
