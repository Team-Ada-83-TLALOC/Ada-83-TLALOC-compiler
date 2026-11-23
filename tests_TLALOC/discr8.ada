WITH REPORT; USE REPORT;
PROCEDURE DISCR8 IS
     SUBTYPE INT IS INTEGER RANGE 0 .. 10;
     TYPE REC (N : INT := 2) IS
          RECORD
               B : INTEGER := 5;
               A : STRING (1 .. N);
          END RECORD;
     X : REC;
     Y : REC (3);
     CX, CY : BOOLEAN;
     FUNCTION CONTRAINT_IN (R : REC) RETURN BOOLEAN IS
     BEGIN
          RETURN R'CONSTRAINED;               -- FORMEL IN : TOUJOURS TRUE (LRM 3.7.4)
     END CONTRAINT_IN;
     PROCEDURE CONTRAINT_IO (R : IN OUT REC; C : OUT BOOLEAN) IS
     BEGIN
          C := R'CONSTRAINED;                 -- FORMEL IN OUT : CELUI DE L'ACTUEL
     END CONTRAINT_IO;
     FUNCTION F (L : INT) RETURN REC IS
          V : REC (L);
     BEGIN
          FOR I IN 1 .. L LOOP
               V.A (I) := CHARACTER'VAL (CHARACTER'POS ('A') + I - 1);
          END LOOP;
          V.B := L;
          RETURN V;
     END F;
BEGIN
     TEST ("DISCR8", "'CONSTRAINED DE FORMEL, RESULTAT DE FONCTION");
     CONTRAINT_IO (X, CX);
     CONTRAINT_IO (Y, CY);
     IF CX OR NOT CY OR NOT CONTRAINT_IN (X) THEN
          FAILED ("'CONSTRAINED DU FORMEL");
     END IF;
     X := F (IDENT_INT (4));
     IF X.N /= 4 OR X.A /= "ABCD" OR X.B /= 4 THEN
          FAILED ("X := F (4)");
     END IF;
     IF F (2) /= (2, 2, "AB") THEN
          FAILED ("F (2) = AGREGAT");
     END IF;
     RESULT;
END DISCR8;
