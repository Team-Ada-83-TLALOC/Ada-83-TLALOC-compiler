WITH REPORT; USE REPORT;
PROCEDURE ELABD1 IS
     SUBTYPE SM IS INTEGER RANGE 1 .. 10;
     TYPE ARR IS ARRAY (SM RANGE <>) OF INTEGER;
     TYPE REC (D1, D2 : SM) IS RECORD NULL; END RECORD;
     NB : INTEGER := 0;
     FUNCTION F (V : INTEGER) RETURN INTEGER IS BEGIN NB := NB + 1; RETURN V; END F;
BEGIN
     TEST ("ELABD1", "BORNES ET CONTRAINTES SANS DISCRIMINANT EVALUEES AU TYPE ; VARIANTES ABSENTES");
     DECLARE
          TYPE CONS (D : SM := 2) IS RECORD A : ARR (D .. F (5)); B : REC (D, F (3)); END RECORD;
          X, Y : CONS;
          Z : CONS (4);
     BEGIN
          IF NB /= 2 THEN FAILED ("EVALUATIONS AU TYPE :" & INTEGER'IMAGE (NB)); END IF;
          IF X.A'FIRST /= 2 OR X.A'LAST /= 5 OR X.B.D2 /= 3 OR Z.A'LENGTH /= 2 OR Z.B.D1 /= 4 THEN FAILED ("VALEURS"); END IF;
          X := (4, (4 .. 5 => 1), (4, 3));
          IF X.A'FIRST /= 4 OR X.A /= (1, 1) OR X.B.D2 /= 3 THEN FAILED ("X := AGREGAT"); END IF;
     END;
     IF NB /= 2 THEN FAILED ("REEVALUATION :" & INTEGER'IMAGE (NB)); END IF;
     DECLARE
          TYPE CV (D : INTEGER := 11) IS
               RECORD
                    CASE D IS
                         WHEN 1 .. 5 => A : ARR (D .. F (8));
                         WHEN OTHERS => C : INTEGER := 0;
                    END CASE;
               END RECORD;
          TYPE TV IS ARRAY (1 .. 3) OF CV;
          TYPE EN IS RECORD E : CV; END RECORD;
          V : CV (11);
          T : TV;
          W : EN;
     BEGIN
          IF V.C /= 0 OR T (2).C /= 0 OR W.E.C /= 0 THEN FAILED ("VARIANTE ABSENTE : VALEURS"); END IF;
          IF T /= (1 .. 3 => (11, 0)) THEN FAILED ("T /= AGREGAT"); END IF;
          IF W /= (E => (11, 0)) THEN FAILED ("W /= AGREGAT"); END IF;
     EXCEPTION WHEN CONSTRAINT_ERROR => FAILED ("VARIANTE ABSENTE CONTROLEE");
     END;
     BEGIN
          DECLARE
               TYPE CC (D : INTEGER) IS RECORD A : ARR (F (0) .. D); END RECORD;
               SUBTYPE S1 IS CC (1);
          BEGIN
               FAILED ("SOUS-TYPE : PAS DE CONSTRAINT_ERROR");
          END;
     EXCEPTION WHEN CONSTRAINT_ERROR => NULL;
     END;
     BEGIN
          DECLARE
               TYPE CC (D : INTEGER) IS RECORD A : ARR (F (0) .. D); END RECORD;
               TYPE AC IS ACCESS CC (1);
          BEGIN
               FAILED ("TYPE D'ACCES : PAS DE CONSTRAINT_ERROR");
          END;
     EXCEPTION WHEN CONSTRAINT_ERROR => NULL;
     END;
     DECLARE
          TYPE RD (D : INTEGER) IS RECORD V : INTEGER := 0; END RECORD;
          TYPE ARD IS ACCESS RD;
          R : RD (5) := (5, 1);
          P : ARD := NEW RD'(5, 2);
          PROCEDURE Q (X : OUT RD) IS BEGIN X := (6, 3); END Q;
     BEGIN
          BEGIN R := (4, 1); FAILED ("R := (4, 1)"); EXCEPTION WHEN CONSTRAINT_ERROR => NULL; END;
          BEGIN P.ALL := (4, 1); FAILED ("P.ALL := (4, 1)"); EXCEPTION WHEN CONSTRAINT_ERROR => NULL; END;
          BEGIN Q (R); FAILED ("Q (R)"); EXCEPTION WHEN CONSTRAINT_ERROR => NULL; END;
          IF R /= (5, 1) OR P.ALL /= (5, 2) THEN FAILED ("MODIFIE MALGRE LE CONTROLE"); END IF;
          R := (5, 7);
          IF R.V /= 7 THEN FAILED ("R := (5, 7)"); END IF;
     END;
     RESULT;
END ELABD1;
