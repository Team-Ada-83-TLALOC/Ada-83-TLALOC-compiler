WITH REPORT; USE REPORT;
PROCEDURE RECDYN2 IS
     SUBTYPE SM IS INTEGER RANGE 1 .. 10;
     TYPE ARR IS ARRAY (SM RANGE <>) OF INTEGER;
     TYPE CONS (D : SM) IS
          RECORD
               S : STRING (1 .. D);
          END RECORD;
     TYPE DEF (L : SM) IS
          RECORD
               B : CONS (L) := (L, (1 .. L => 'D'));
               K : INTEGER := 5;
          END RECORD;
     TYPE VAR (V : SM) IS
          RECORD
               CASE V IS
                    WHEN 1 .. 3 => P : CONS (V);
                    WHEN OTHERS => Q : INTEGER := 0;
               END CASE;
          END RECORD;
     TYPE R (D : INTEGER) IS RECORD V : INTEGER := 4; END RECORD;
     TYPE N IS NEW R (3);
     TYPE NC IS NEW CONS (4);
     NB : INTEGER := 0;
     X : DEF (3);
     Y : VAR (2);
     Z : VAR (7);
     U : N;
     W : NC;
     FUNCTION F (X : INTEGER) RETURN INTEGER IS BEGIN NB := NB + 1; RETURN X; END F;
     FUNCTION MK (L : SM) RETURN DEF IS
          T : DEF (L);
     BEGIN
          T.K := L;
          RETURN T;
     END MK;
BEGIN
     TEST ("RECDYN2", "COMPOSANT RECORD DYNAMIQUE : DEFAUT, VARIANTE, DERIVES, CONTROLE AU TYPE");
     IF X.B.S /= "DDD" OR X.K /= 5 THEN FAILED ("X : DEFAUT DU COMPOSANT"); END IF;
     IF Y.P.D /= 2 OR Y.P.S'LENGTH /= 2 THEN FAILED ("Y : VARIANTE"); END IF;
     Y.P.S := "YZ";
     IF Y.P.S /= "YZ" THEN FAILED ("Y.P.S"); END IF;
     IF Z.Q /= 0 THEN FAILED ("Z : AUTRE VARIANTE"); END IF;
     IF U.D /= 3 OR U.V /= 4 THEN FAILED ("U : DERIVE STATIQUE"); END IF;
     W.S := "ABCD";
     IF W.D /= 4 OR W.S /= "ABCD" THEN FAILED ("W : DERIVE DYNAMIQUE"); END IF;
     DECLARE
          M : DEF := MK (IDENT_INT (4));
     BEGIN
          IF M.L /= 4 OR M.B.S /= "DDDD" OR M.K /= 4 THEN FAILED ("M : RESULTAT DE FONCTION"); END IF;
     END;
     BEGIN
          DECLARE
               TYPE CA (D : INTEGER) IS RECORD A : ARR (F (0) .. D); END RECORD;
               TYPE ENC IS RECORD C : CA (1); END RECORD;
          BEGIN
               FAILED ("PAS DE CONSTRAINT_ERROR A L'ELABORATION DE ENC");
          END;
     EXCEPTION WHEN CONSTRAINT_ERROR => NULL;
     END;
     IF NB /= 1 THEN FAILED ("F EVALUEE" & INTEGER'IMAGE (NB) & " FOIS"); END IF;
     RESULT;
END RECDYN2;
