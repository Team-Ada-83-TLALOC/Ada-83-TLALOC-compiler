WITH REPORT; USE REPORT;
PROCEDURE AGGSELF1 IS
     TYPE REC IS RECORD X, Y : INTEGER; END RECORD;
     TYPE SUB_ENUM IS (AA, BB, CC, DD);
     SUBTYPE S3 IS SUB_ENUM RANGE AA .. CC;
     TYPE RE IS RECORD X, Y : S3; END RECORD;
     TYPE R2 IS RECORD A : REC; B : INTEGER; END RECORD;
     R : REC;
     E : RE;
     Z : R2;
BEGIN
     TEST ("AGGSELF1", "AGREGAT AFFECTE A L'OBJET QU'IL LIT : SEMANTIQUE DE COPIE (LRM 5.2)");
     R := (5, 8);
     R := (X => 1, Y => R.X);
     IF R /= (1, 5) THEN FAILED ("1"); END IF;
     R := (R.Y + 1, R.X + 1);
     IF R /= (6, 2) THEN FAILED ("2"); END IF;
     E := (AA, BB);
     E := (S3'SUCC (E.Y), S3'SUCC (E.X));
     IF E /= (CC, BB) THEN FAILED ("3"); END IF;
     Z := ((1, 2), 3);
     Z := ((Z.B, Z.A.X), Z.A.Y);
     IF Z /= ((3, 1), 2) THEN FAILED ("4"); END IF;
     RESULT;
END AGGSELF1;
