WITH REPORT; USE REPORT;
PROCEDURE DISCR6 IS
     TYPE REC (N : INTEGER) IS
          RECORD
               B : INTEGER;
               A : STRING (1 .. N);
          END RECORD;
BEGIN
     TEST ("DISCR6", "DISCRIMINANT D'AGREGAT PAR APPEL");
     COMMENT ("ETAPE 1");
     DECLARE
          X : REC (IDENT_INT (3)) := (IDENT_INT (3), 1, "ABC");
     BEGIN
          COMMENT ("ETAPE 2");
          IF X.A /= "ABC" THEN FAILED ("X"); END IF;
     END;
     RESULT;
END DISCR6;
