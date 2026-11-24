WITH REPORT; USE REPORT;
PROCEDURE HOM4 IS
     PACKAGE P IS
          TYPE T IS RANGE -100 .. 100;
          FUNCTION F RETURN T;
     END P;
     USE P;
     PACKAGE BODY P IS
          FUNCTION F RETURN T IS BEGIN RETURN T (IDENT_INT (1)); END F;
     END P;
BEGIN
     TEST ("HOM4", "DERIVE CACHE PAR UNE INSTANCIATION");
     DECLARE
          GENERIC
               TYPE T IS RANGE <>;
          FUNCTION G RETURN T;
          FUNCTION G RETURN T IS BEGIN RETURN T (IDENT_INT (2)); END G;
          PACKAGE Q IS
               TYPE QT IS NEW T;
               X : QT := F;
               FUNCTION F IS NEW G (QT);
               W : QT := F;
          END Q;
          USE Q;
     BEGIN
          IF X /= 1 THEN FAILED ("X"); END IF;
          IF W /= 2 THEN FAILED ("W =" & QT'IMAGE (W)); END IF;
     END;
     RESULT;
END HOM4;
