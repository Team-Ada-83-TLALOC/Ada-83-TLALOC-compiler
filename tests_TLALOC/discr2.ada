WITH REPORT; USE REPORT;
PROCEDURE DISCR2 IS
     SUBTYPE INT IS INTEGER RANGE 0 .. 10;
     TYPE REC (N : INT) IS
          RECORD
               A : STRING (1 .. N);
               C : CHARACTER;
          END RECORD;
     X : REC (3);
     Y : REC (IDENT_INT (4));
     K : INTEGER := 0;
     FUNCTION LONG (S : STRING) RETURN INTEGER IS
     BEGIN
          RETURN S'LENGTH;
     END LONG;
BEGIN
     TEST ("DISCR2", "ACCES AU COMPOSANT DYNAMIQUE ENTIER");
     IF X.A'FIRST /= 1 OR X.A'LAST /= 3 OR X.A'LENGTH /= 3 THEN
          FAILED ("ATTRIBUTS DE X.A");
     END IF;
     IF Y.A'LAST /= 4 OR Y.A'LENGTH /= IDENT_INT (4) THEN
          FAILED ("ATTRIBUTS DE Y.A");
     END IF;
     FOR I IN Y.A'RANGE LOOP
          Y.A (I) := 'P';
          K := K + 1;
     END LOOP;
     IF K /= 4 THEN
          FAILED ("BOUCLE SUR Y.A'RANGE");
     END IF;
     X.A := "ABC";
     X.C := 'Z';
     IF X.A /= "ABC" OR X.C /= 'Z' THEN
          FAILED ("AFFECTATION / EGALITE DE X.A");
     END IF;
     IF X.A (2 .. 3) /= "BC" THEN
          FAILED ("TRANCHE DE X.A");
     END IF;
     IF LONG (Y.A) /= 4 THEN
          FAILED ("PARAMETRE Y.A");
     END IF;
     RESULT;
END DISCR2;
