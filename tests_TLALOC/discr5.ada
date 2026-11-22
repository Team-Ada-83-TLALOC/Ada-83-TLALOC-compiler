WITH REPORT; USE REPORT;
PROCEDURE DISCR5 IS
     TYPE REC (N : INTEGER) IS
          RECORD
               B : INTEGER;
               A : STRING (1 .. N);
          END RECORD;
     X : REC (IDENT_INT (3)) := (3, 1, "ABC");
     Y : REC (IDENT_INT (2)) := (2, 2, "PQ");
BEGIN
     TEST ("DISCR5", "CONTROLE DES DISCRIMINANTS");
     BEGIN
          X := Y;
          FAILED ("X := Y : CONSTRAINT_ERROR NON LEVEE");
     EXCEPTION
          WHEN CONSTRAINT_ERROR => NULL;
     END;
     BEGIN
          X := (IDENT_INT (2), 5, "ZZ");
          FAILED ("X := AGREGAT : CONSTRAINT_ERROR NON LEVEE");
     EXCEPTION
          WHEN CONSTRAINT_ERROR => NULL;
     END;
     IF X.A /= "ABC" OR X.B /= 1 THEN
          FAILED ("X MODIFIE MALGRE LE CONTROLE");
     END IF;
     RESULT;
END DISCR5;
