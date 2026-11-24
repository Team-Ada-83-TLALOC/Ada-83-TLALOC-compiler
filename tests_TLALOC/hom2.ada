WITH REPORT; USE REPORT;
PROCEDURE HOM2 IS
     PACKAGE P IS
          TYPE T IS RANGE -100 .. 100;
          FUNCTION F RETURN T;
     END P;
     USE P;
     PACKAGE BODY P IS
          FUNCTION F RETURN T IS BEGIN RETURN T (IDENT_INT (1)); END F;
     END P;
BEGIN
     TEST ("HOM2", "DEFAUT DE COMPOSANT : HOMOGRAPHE EXPLICITE");
     DECLARE
          PACKAGE Q IS
               TYPE QT IS NEW T;
               FUNCTION F RETURN QT;
               TYPE QR IS RECORD C : QT := F; END RECORD;
               V : QT := F;
          END Q;
          USE Q;
          Y : QR;
          PACKAGE BODY Q IS
               FUNCTION F RETURN QT IS BEGIN RETURN QT (IDENT_INT (2)); END F;
          END Q;
     BEGIN
          IF V /= 2 THEN FAILED ("V"); END IF;
          IF Y.C /= 2 THEN FAILED ("Y.C =" & QT'IMAGE (Y.C)); END IF;
     END;
     RESULT;
END HOM2;
