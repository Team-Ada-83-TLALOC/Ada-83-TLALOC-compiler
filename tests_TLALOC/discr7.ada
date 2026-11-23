WITH REPORT; USE REPORT;
PROCEDURE DISCR7 IS
     SUBTYPE INT IS INTEGER RANGE 0 .. 10;
     TYPE REC (N : INT := 2) IS
          RECORD
               B : INTEGER := 5;
               A : STRING (1 .. N);
          END RECORD;
     X : REC;
     Y : REC (4) := (4, 1, "WXYZ");
     Z : REC := (3, 2, "ABC");
     PROCEDURE P (R : IN OUT REC) IS
     BEGIN
          R := (1, 9, "Q");
     END P;
BEGIN
     TEST ("DISCR7", "OBJETS NON CONTRAINTS (TAILLE MAX)");
     IF X.N /= 2 OR X.B /= 5 OR X.A'LENGTH /= 2 OR X'CONSTRAINED THEN
          FAILED ("X PAR DEFAUT");
     END IF;
     X := Y;
     IF X.N /= 4 OR X.A /= "WXYZ" OR X.B /= 1 THEN
          FAILED ("X := Y");
     END IF;
     X := (6, 3, "ABCDEF");
     IF X.N /= 6 OR X.A /= "ABCDEF" OR X.A'LAST /= 6 OR X.B /= 3 THEN
          FAILED ("X := AGREGAT (6)");
     END IF;
     IF Z.N /= 3 OR Z.A /= "ABC" THEN
          FAILED ("Z INITIALISE");
     END IF;
     P (Z);
     IF Z.N /= 1 OR Z.A /= "Q" OR Z.B /= 9 THEN
          FAILED ("P (Z) MUTABLE");
     END IF;
     BEGIN
          P (Y);
          FAILED ("P (Y) : CONSTRAINT_ERROR NON LEVEE");
     EXCEPTION
          WHEN CONSTRAINT_ERROR => NULL;
     END;
     DECLARE
          TYPE GROS (L : NATURAL := 0) IS
               RECORD
                    S : STRING (1 .. L);
               END RECORD;
     BEGIN
          DECLARE
               G : GROS;
          BEGIN
               FAILED ("STORAGE_ERROR NON LEVEE");
          END;
     EXCEPTION
          WHEN STORAGE_ERROR => NULL;
     END;
     RESULT;
END DISCR7;
