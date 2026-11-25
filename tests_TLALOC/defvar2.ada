WITH REPORT; USE REPORT;
PROCEDURE DEFVAR2 IS
     TYPE R (E : INTEGER := 1) IS
          RECORD
               C : CHARACTER := 'C';
               CASE E IS
                    WHEN 1 => N : INTEGER := 5;
                    WHEN 2 .. 5 => M : INTEGER := 6;
                    WHEN OTHERS => NULL;
               END CASE;
          END RECORD;
     TYPE SANS IS
          RECORD
               I : INTEGER := 11;
          END RECORD;
     TYPE O (K : INTEGER := 3) IS
          RECORD
               X : R;
               Y : R (K);
               Z : SANS;
          END RECORD;
     TYPE DEUX IS
          RECORD
               P : O;
               Q : O (1);
          END RECORD;
     SUBTYPE PETIT IS INTEGER RANGE 0 .. 10;
     TYPE DYN (L : PETIT := 2) IS
          RECORD
               S : STRING (1 .. L) := (1 .. L => 'D');
               T : INTEGER := 7;
          END RECORD;
     TYPE AR IS ACCESS R;
     TYPE AO IS ACCESS O;
     TYPE AD IS ACCESS DYN;
     V : O;
     W : DEUX;
     P1 : AR := NEW R;
     P2 : AR := NEW R (IDENT_INT (4));
     P3 : AO := NEW O (IDENT_INT (2));
     P4 : AD := NEW DYN (IDENT_INT (3));
     P5 : AD := NEW DYN;
BEGIN
     TEST ("DEFVAR2", "VALEURS IMPLICITES DES COMPOSANTS RECORDS ET DES OBJETS ALLOUES (LRM 3.2.1, 4.8)");
     IF V.X.E /= 1 OR V.X.C /= 'C' OR V.X.N /= 5 THEN FAILED ("V.X"); END IF;
     IF V.Y.E /= 3 OR V.Y.C /= 'C' OR V.Y.M /= 6 THEN FAILED ("V.Y (CONTRAINTE PAR K)"); END IF;
     IF V.Z.I /= 11 THEN FAILED ("V.Z"); END IF;
     IF W.P.K /= 3 OR W.P.Y.M /= 6 OR W.P.X.N /= 5 OR W.P.Z.I /= 11 THEN FAILED ("W.P"); END IF;
     IF W.Q.K /= 1 OR W.Q.Y.N /= 5 THEN FAILED ("W.Q"); END IF;
     IF P1.C /= 'C' OR P1.N /= 5 THEN FAILED ("P1 : NEW R"); END IF;
     IF P2.E /= 4 OR P2.M /= 6 THEN FAILED ("P2 : NEW R (4)"); END IF;
     IF P3.K /= 2 OR P3.Y.M /= 6 OR P3.X.N /= 5 OR P3.Z.I /= 11 THEN FAILED ("P3 : NEW O (2)"); END IF;
     IF P4.S /= "DDD" OR P4.T /= 7 THEN FAILED ("P4 : NEW DYN (3)"); END IF;
     IF P5.S /= "DD" OR P5.T /= 7 THEN FAILED ("P5 : NEW DYN"); END IF;
     RESULT;
END DEFVAR2;
