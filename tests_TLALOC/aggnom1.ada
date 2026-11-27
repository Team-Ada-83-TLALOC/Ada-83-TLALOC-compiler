WITH REPORT; USE REPORT;
PROCEDURE AGGNOM1 IS
     TYPE A10 IS ARRAY (INTEGER RANGE 1 .. 10) OF INTEGER;
     TYPE AN IS ARRAY (INTEGER RANGE <>) OF INTEGER;
     X : A10 := (1 .. 2 | 4 .. 10 => 7, 3 => 5);
     Y : A10;
     PROCEDURE P (V : AN; F, L : INTEGER; M : STRING) IS
     BEGIN
          IF V'FIRST /= F OR V'LAST /= L THEN FAILED ("BORNES " & M & INTEGER'IMAGE (V'FIRST) & INTEGER'IMAGE (V'LAST)); END IF;
     END P;
BEGIN
     TEST ("AGGNOM1", "AGREGATS NOMMES SANS OTHERS, CHOIX DANS LE DESORDRE (LRM 4.3.2)");
     IF X (3) /= 5 OR X (1) /= 7 OR X (10) /= 7 OR X (4) /= 7 THEN FAILED ("X"); END IF;
     Y := (10 => 1, 1 .. 9 => 2);
     IF Y (10) /= 1 OR Y (1) /= 2 OR Y (9) /= 2 THEN FAILED ("Y"); END IF;
     IF X /= (1 .. 2 | 4 .. 10 => 7, 3 => 5) THEN FAILED ("X /= AGG"); END IF;
     IF X /= (3 => 5, 4 .. 10 | 1 .. 2 => 7) THEN FAILED ("X /= AGG 2"); END IF;
     P ((5 => 1, 3 .. 4 => 2), 3, 5, "AN");
     P (AN'(5 => 1, 3 | 4 => 2), 3, 5, "AN QUAL");
     IF AN'(5 => 1, 3 | 4 => 2) /= (2, 2, 1) THEN FAILED ("AN VALEURS"); END IF;
     RESULT;
END AGGNOM1;
