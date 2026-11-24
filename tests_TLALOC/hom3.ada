WITH REPORT; USE REPORT;
PROCEDURE HOM3 IS
     PACKAGE P IS
          TYPE T IS RANGE -100 .. 100;
          FUNCTION "+" (X : T) RETURN T;
     END P;
     USE P;
     PACKAGE BODY P IS
          FUNCTION "+" (X : T) RETURN T IS BEGIN RETURN X - T (IDENT_INT (-1)); END "+";
     END P;
BEGIN
     TEST ("HOM3", "DERIVE CACHE PAR UN RENOMMAGE");
     DECLARE
          PACKAGE Q IS
               TYPE QT IS NEW T;
               X : QT := +0;
               FUNCTION G (X : QT) RETURN QT;
               FUNCTION "+" (Y : QT) RETURN QT RENAMES G;
               V : QT := +0;
          END Q;
          USE Q;
          PACKAGE BODY Q IS
               FUNCTION G (X : QT) RETURN QT IS BEGIN RETURN X - QT (IDENT_INT (-2)); END G;
          END Q;
     BEGIN
          IF X /= 1 THEN FAILED ("X =" & QT'IMAGE (X)); END IF;
          IF V /= 2 THEN FAILED ("V =" & QT'IMAGE (V)); END IF;
     END;
     RESULT;
END HOM3;
