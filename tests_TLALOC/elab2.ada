WITH REPORT; USE REPORT;
PROCEDURE ELAB2 IS
     TYPE ARR IS ARRAY (POSITIVE RANGE <>) OF INTEGER;
     NB : INTEGER := 0;
     FUNCTION F (X : INTEGER) RETURN INTEGER IS
     BEGIN
          NB := NB + 1;
          RETURN X;
     END F;
     PROCEDURE P (V : ARR; L : INTEGER) IS
     BEGIN
          IF V'LENGTH /= L OR V (V'LAST) /= L THEN FAILED ("PARAMETRE"); END IF;
     END P;
BEGIN
     TEST ("ELAB2", "COMPOSANTS A BORNES NON STATIQUES ELABOREES AU TYPE");
     DECLARE
          SUBTYPE S IS ARR (1 .. F (3));
          TYPE R IS RECORD
               A : S;
               B : INTEGER := 7;
               C : ARR (1 .. F (2));
               E : CHARACTER := 'E';
          END RECORD;
          X, Y : R;
          Z : R := ((1, 2, 3), 8, (4, 5), 'Z');
     BEGIN
          IF NB /= 2 THEN FAILED ("EVALUATIONS :" & INTEGER'IMAGE (NB)); END IF;
          IF X.A'LAST /= 3 OR X.C'LAST /= 2 OR X.B /= 7 OR X.E /= 'E' THEN FAILED ("X"); END IF;
          X.A := (7, 8, 3);
          X.C := (1, 2);
          Y := X;
          IF Y.A (2) /= 8 OR Y.C (2) /= 2 OR Y /= X THEN FAILED ("Y"); END IF;
          IF Z.A (3) /= 3 OR Z.C (1) /= 4 OR Z.B /= 8 OR Z.E /= 'Z' THEN FAILED ("Z"); END IF;
          P (Z.A, 3);
          P (Y.C, 2);
          IF NB /= 2 THEN FAILED ("REEVALUATION :" & INTEGER'IMAGE (NB)); END IF;
     END;
     RESULT;
END ELAB2;
