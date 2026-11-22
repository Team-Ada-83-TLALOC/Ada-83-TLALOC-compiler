WITH REPORT; USE REPORT;
PROCEDURE DISCR1 IS
     SUBTYPE INT IS INTEGER RANGE 0 .. 10;
     TYPE REC (N : INT) IS
          RECORD
               B : INTEGER;
               A : STRING (1 .. N);
               C : CHARACTER;
          END RECORD;
     X : REC (3);
     Y : REC (IDENT_INT (5));
BEGIN
     TEST ("DISCR1", "COMPOSANT DEPENDANT D'UN DISCRIMINANT");
     X.B := 7;
     X.C := 'K';
     X.A (1) := 'A';
     X.A (2) := 'B';
     X.A (3) := 'C';
     IF X.N /= 3 OR X.B /= 7 OR X.C /= 'K' THEN
          FAILED ("X : CHAMPS STATIQUES");
     END IF;
     IF X.A (1) /= 'A' OR X.A (2) /= 'B' OR X.A (3) /= 'C' THEN
          FAILED ("X : COMPOSANT DYNAMIQUE");
     END IF;
     FOR I IN 1 .. 5 LOOP
          Y.A (I) := 'Z';
     END LOOP;
     Y.A (2) := 'Q';
     IF Y.N /= 5 OR Y.A (2) /= 'Q' OR Y.A (5) /= 'Z' THEN
          FAILED ("Y");
     END IF;
     BEGIN
          Y.A (IDENT_INT (6)) := 'X';
          FAILED ("CONSTRAINT_ERROR NON LEVEE");
     EXCEPTION
          WHEN CONSTRAINT_ERROR => NULL;
     END;
     RESULT;
END DISCR1;
