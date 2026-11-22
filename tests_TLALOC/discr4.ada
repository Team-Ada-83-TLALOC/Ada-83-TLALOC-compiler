WITH REPORT; USE REPORT;
PROCEDURE DISCR4 IS
     SUBTYPE INT IS INTEGER RANGE 0 .. 10;
     TYPE REC (N : INT) IS
          RECORD
               B : INTEGER;
               A : STRING (1 .. N);
               C : CHARACTER;
          END RECORD;
     TYPE A_REC IS ACCESS REC;
     X : REC (3) := (3, 7, "ABC", 'K');
     Y : REC (IDENT_INT (3));
     P : A_REC;
     Q : A_REC;
BEGIN
     TEST ("DISCR4", "AFFECTATION, EGALITE, ALLOCATEURS");
     Y := X;
     IF Y /= X OR Y.A /= "ABC" OR Y.C /= 'K' THEN
          FAILED ("Y := X");
     END IF;
     Y := (3, 8, "XYZ", 'M');
     IF Y = X OR Y.A /= "XYZ" OR Y.B /= 8 THEN
          FAILED ("Y := AGREGAT");
     END IF;
     Y.A (2) := 'B';
     IF Y = (3, 8, "XBZ", 'M') THEN
          NULL;
     ELSE
          FAILED ("EGALITE AVEC AGREGAT");
     END IF;
     P := NEW REC (IDENT_INT (4));
     P.A := "PQRS";
     P.B := 1;
     IF P.N /= 4 OR P.A /= "PQRS" OR P.A'LAST /= 4 THEN
          FAILED ("NEW REC (4)");
     END IF;
     Q := NEW REC'(2, 9, "UV", 'W');
     IF Q.N /= 2 OR Q.A /= "UV" OR Q.C /= 'W' THEN
          FAILED ("NEW REC'(AGREGAT)");
     END IF;
     Q.ALL := (2, 3, "AB", 'C');
     IF Q.A /= "AB" OR Q.B /= 3 THEN
          FAILED ("Q.ALL := AGREGAT");
     END IF;
     RESULT;
END DISCR4;
