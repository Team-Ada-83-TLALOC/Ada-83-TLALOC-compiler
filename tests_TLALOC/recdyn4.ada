WITH REPORT; USE REPORT;
PROCEDURE RECDYN4 IS
     SUBTYPE SM IS INTEGER RANGE 0 .. 10;
     TYPE MUT (D : SM := 2) IS
          RECORD
               N : INTEGER := 7;
               S : STRING (1 .. D) := (1 .. D => 'M');
          END RECORD;
     TYPE ENC IS
          RECORD
               A : INTEGER := 1;
               B : MUT;
               C : CHARACTER := 'C';
          END RECORD;
     TYPE ENC2 (L : SM) IS
          RECORD
               E : MUT;
               F : MUT (L);
               G : INTEGER := 9;
          END RECORD;
     X, Y : ENC;
     Z : ENC2 (3);
     NB : INTEGER := 0;
     FUNCTION F (V : INTEGER) RETURN INTEGER IS BEGIN NB := NB + 1; RETURN V; END F;
BEGIN
     TEST ("RECDYN4", "COMPOSANT RECORD DYNAMIQUE MUTABLE DANS UN RECORD");
     IF X.B.D /= 2 OR X.B.S /= "MM" OR X.B.N /= 7 OR X.A /= 1 OR X.C /= 'C' THEN FAILED ("X : DEFAUTS"); END IF;
     IF X.B'CONSTRAINED THEN FAILED ("X.B'CONSTRAINED"); END IF;
     X.B := (5, 3, "ABCDE");
     IF X.B.D /= 5 OR X.B.S /= "ABCDE" OR X.B.N /= 3 OR X.C /= 'C' THEN FAILED ("X.B := (5, ...)"); END IF;
     Y := X;
     IF Y /= X OR Y.B.S /= "ABCDE" THEN FAILED ("Y := X"); END IF;
     Y.B := (1, 0, "Z");
     IF Y = X OR Y.B.D /= 1 OR Y.B.S /= "Z" THEN FAILED ("Y.B := (1, ...)"); END IF;
     X := (4, (10, 8, (1 .. 10 => 'T')), 'K');
     IF X.A /= 4 OR X.B.D /= 10 OR X.B.S (10) /= 'T' OR X.C /= 'K' THEN FAILED ("X := AGREGAT"); END IF;
     IF X /= (4, (10, 8, (1 .. 10 => 'T')), 'K') THEN FAILED ("X /= AGREGAT"); END IF;
     IF Z.E.D /= 2 OR Z.F.D /= 3 OR Z.F.S /= "MMM" OR Z.G /= 9 THEN FAILED ("Z"); END IF;
     IF NOT Z.F'CONSTRAINED OR Z.E'CONSTRAINED THEN FAILED ("Z'CONSTRAINED"); END IF;
     Z.E := (0, 1, "");
     IF Z.E.D /= 0 OR Z.F.S /= "MMM" OR Z.G /= 9 THEN FAILED ("Z.E := (0, ...)"); END IF;
     BEGIN Z.F := (2, 1, "AB"); FAILED ("Z.F : PAS DE CONSTRAINT_ERROR"); EXCEPTION WHEN CONSTRAINT_ERROR => NULL; END;
     BEGIN
          DECLARE
               TYPE M2 (D : SM := F (11)) IS RECORD S : STRING (1 .. D); END RECORD;
               TYPE E2 IS RECORD B : M2; END RECORD;
          BEGIN
               IF NB /= 0 THEN FAILED ("DEFAUT EVALUE AU TYPE"); END IF;
               DECLARE
                    V : E2;
               BEGIN
                    FAILED ("V : PAS DE CONSTRAINT_ERROR");
               END;
          END;
     EXCEPTION WHEN CONSTRAINT_ERROR => NULL;
     END;
     IF NB /= 1 THEN FAILED ("DEFAUT EVALUE" & INTEGER'IMAGE (NB) & " FOIS"); END IF;
     RESULT;
END RECDYN4;
