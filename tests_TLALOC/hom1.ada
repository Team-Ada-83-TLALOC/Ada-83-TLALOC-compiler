WITH REPORT; USE REPORT;
PROCEDURE HOM1 IS
     PACKAGE P IS
          TYPE T IS RANGE -100 .. 100;
          FUNCTION F RETURN T;
     END P;
     USE P;
     PACKAGE BODY P IS
          FUNCTION F RETURN T IS BEGIN RETURN T (IDENT_INT (1)); END F;
     END P;
BEGIN
     TEST ("HOM1", "DERIVE CACHE PAR UN HOMOGRAPHE EXPLICITE");
     DECLARE
          PACKAGE Q IS
               TYPE QT IS NEW T;
               X : QT := F;
               FUNCTION F RETURN QT;
               Y : QT := F;
          PRIVATE
               TYPE QS IS NEW QT;
          END Q;
          USE Q;
          W : QT := F;
          PACKAGE BODY Q IS
               FUNCTION F RETURN QT IS BEGIN RETURN QT (IDENT_INT (2)); END F;
               PACKAGE R IS
                    Z : QS := F;
               END R;
          BEGIN
               IF X /= 1 THEN FAILED ("X : DERIVE AVANT L'HOMOGRAPHE"); END IF;
               IF Y /= 2 THEN FAILED ("Y : HOMOGRAPHE DANS LA PARTIE VISIBLE"); END IF;
               IF R.Z /= 2 THEN FAILED ("Z : DERIVE DE L'HOMOGRAPHE"); END IF;
          END Q;
     BEGIN
          IF W /= 2 THEN FAILED ("W : HOMOGRAPHE VU PAR USE"); END IF;
     END;
     RESULT;
END HOM1;
