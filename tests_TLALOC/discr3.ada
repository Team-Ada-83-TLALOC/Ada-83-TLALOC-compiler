WITH REPORT; USE REPORT;
PROCEDURE DISCR3 IS
     SUBTYPE INT IS INTEGER RANGE 0 .. 10;
     TYPE REC (N : INT) IS
          RECORD
               B : INTEGER;
               A : STRING (1 .. N);
               C : CHARACTER;
          END RECORD;
     X : REC (3) := (3, 7, "ABC", 'K');
     Y : REC (IDENT_INT (4)) := (N => 4, B => 1, A => (OTHERS => 'Z'), C => 'L');
     K : CONSTANT REC := (2, 5, "PQ", 'M');
     Z : REC (3) := X;
BEGIN
     TEST ("DISCR3", "OBJETS DYNAMIQUES INITIALISES");
     IF X.N /= 3 OR X.B /= 7 OR X.A /= "ABC" OR X.C /= 'K' THEN
          FAILED ("X");
     END IF;
     IF Y.N /= 4 OR Y.B /= 1 OR Y.A /= "ZZZZ" OR Y.C /= 'L' THEN
          FAILED ("Y");
     END IF;
     IF K.N /= 2 OR K.B /= 5 OR K.A /= "PQ" OR K.C /= 'M' OR K.A'LAST /= 2 THEN
          FAILED ("K");
     END IF;
     IF Z.A /= "ABC" OR Z.C /= 'K' THEN
          FAILED ("Z");
     END IF;
     RESULT;
END DISCR3;
