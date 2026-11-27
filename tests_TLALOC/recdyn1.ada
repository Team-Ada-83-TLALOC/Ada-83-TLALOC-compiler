WITH REPORT; USE REPORT;
PROCEDURE RECDYN1 IS
     SUBTYPE SM IS INTEGER RANGE 0 .. 10;
     TYPE CONS (D : SM) IS
          RECORD
               N : INTEGER := 7;
               S : STRING (1 .. D);
          END RECORD;
     TYPE ENC (L : SM) IS
          RECORD
               A : INTEGER := 1;
               B : CONS (L);
               C : CHARACTER := 'C';
               E : CONS (2);
               F : INTEGER := 9;
          END RECORD;
     TYPE ENC2 (K : SM) IS
          RECORD
               G : ENC (K);
               H : INTEGER := 4;
          END RECORD;
     TYPE ENC3 (L : INTEGER) IS
          RECORD
               B : CONS (L);
          END RECORD;
     TYPE AE IS ACCESS ENC;
     X : ENC (3);
     Y : ENC (IDENT_INT (3));
     Z : ENC (IDENT_INT (4));
     W : ENC2 (2);
     P : AE := NEW ENC (IDENT_INT (5));
     FUNCTION LONG (R : CONS) RETURN INTEGER IS BEGIN RETURN R.S'LENGTH; END LONG;
BEGIN
     TEST ("RECDYN1", "COMPOSANT RECORD DYNAMIQUE CONTRAINT DANS UN RECORD");
     IF X.A /= 1 OR X.B.D /= 3 OR X.B.N /= 7 OR X.B.S'LENGTH /= 3 OR X.C /= 'C' THEN FAILED ("X : B"); END IF;
     IF X.E.D /= 2 OR X.E.N /= 7 OR X.E.S'LAST /= 2 OR X.F /= 9 THEN FAILED ("X : E"); END IF;
     X.B.S := "ABC";  X.E.S := "XY";  X.B.N := 8;
     IF X.B.S /= "ABC" OR X.E.S /= "XY" OR X.B.N /= 8 OR X.F /= 9 OR X.C /= 'C' THEN FAILED ("X : SELECTION"); END IF;
     IF LONG (X.B) /= 3 OR LONG (X.E) /= 2 THEN FAILED ("PARAMETRE"); END IF;
     IF Z.B.D /= 4 OR Z.B.S'LENGTH /= 4 OR Z.F /= 9 THEN FAILED ("Z"); END IF;
     Y := X;
     IF Y.B.S /= "ABC" OR Y.E.S /= "XY" OR Y.B.N /= 8 THEN FAILED ("Y := X"); END IF;
     IF Y /= X THEN FAILED ("Y /= X"); END IF;
     Y.E.S (1) := 'Q';
     IF Y = X THEN FAILED ("Y = X APRES MODIFICATION"); END IF;
     Y := (3, 2, (3, 5, "PQR"), 'D', (2, 6, "MN"), 8);
     IF Y.A /= 2 OR Y.B.S /= "PQR" OR Y.B.N /= 5 OR Y.C /= 'D' OR Y.E.S /= "MN" OR Y.F /= 8 THEN FAILED ("Y := AGREGAT"); END IF;
     IF Y /= (3, 2, (3, 5, "PQR"), 'D', (2, 6, "MN"), 8) THEN FAILED ("Y /= AGREGAT"); END IF;
     X.B := (3, 1, "LMN");
     IF X.B.S /= "LMN" OR X.B.N /= 1 OR X.E.S /= "XY" THEN FAILED ("X.B := AGREGAT"); END IF;
     BEGIN Z.B := X.B; FAILED ("Z.B := X.B : PAS DE CONSTRAINT_ERROR"); EXCEPTION WHEN CONSTRAINT_ERROR => NULL; END;
     IF W.G.L /= 2 OR W.G.B.S'LENGTH /= 2 OR W.H /= 4 OR W.G.E.N /= 7 THEN FAILED ("W : IMBRICATION"); END IF;
     W.G.B.S := "QR";
     IF W.G.B.S /= "QR" OR W.G.F /= 9 THEN FAILED ("W.G.B.S"); END IF;
     IF P.B.S'LENGTH /= 5 OR P.E.N /= 7 OR P.F /= 9 THEN FAILED ("P : ALLOCATEUR"); END IF;
     BEGIN
          DECLARE V : ENC3 (IDENT_INT (11)); BEGIN FAILED ("V : PAS DE CONSTRAINT_ERROR"); END;
     EXCEPTION WHEN CONSTRAINT_ERROR => NULL;
     END;
     RESULT;
END RECDYN1;
