WITH REPORT; USE REPORT;
PROCEDURE SUB2 IS
     TYPE R (D : INTEGER := 1) IS RECORD V : INTEGER := 4; END RECORD;
     TYPE DR IS NEW R;
     TYPE TR IS ARRAY (1 .. 2) OF R;
     TYPE AR IS ACCESS R;
BEGIN
     TEST ("SUB2", "SOUS-TYPE NON CONTRAINT, DISCRIMINANTS HERITES, " &
                   "'CONSTRAINED INDEXE ET DESIGNE");
     DECLARE
          X : R;
     BEGIN
          IF X.V /= 4 THEN FAILED ("X"); END IF;
     END;
     DECLARE
          SUBTYPE S IS R;
          Y : S;
          Z : S (IDENT_INT (3));
     BEGIN
          IF Y.V /= 4 OR Y.D /= 1 THEN FAILED ("Y"); END IF;
          IF Z.D /= 3 OR NOT Z'CONSTRAINED THEN FAILED ("Z"); END IF;
          Y := (2, 5);
          IF Y.D /= 2 OR Y.V /= 5 THEN FAILED ("Y AFFECTE"); END IF;
     END;
     DECLARE
          W : DR;
          W2 : DR (IDENT_INT (7));
     BEGIN
          IF W.D /= 1 OR W.V /= 4 THEN FAILED ("W"); END IF;
          IF W2.D /= 7 THEN FAILED ("W2"); END IF;
          W := (8, 9);
          IF W.D /= 8 OR W.V /= 9 THEN FAILED ("W AFFECTE"); END IF;
     END;
     DECLARE
          T : TR;
          P : AR := NEW R (IDENT_INT (5));
     BEGIN
          IF T (1)'CONSTRAINED THEN FAILED ("T(1)'CONSTRAINED"); END IF;
          IF NOT P.ALL'CONSTRAINED THEN FAILED ("P.ALL'CONSTRAINED"); END IF;
     END;
     RESULT;
END SUB2;
