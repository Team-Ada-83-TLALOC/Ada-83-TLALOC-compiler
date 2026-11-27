WITH REPORT; USE REPORT;
PROCEDURE AGGTT1 IS
     TYPE T1 IS ARRAY (INTEGER RANGE <>) OF INTEGER;
     TYPE T2 IS ARRAY (1 .. 2) OF T1 (2 .. 3);
     A : T2;
BEGIN
     TEST ("AGGTT1", "SOUS-AGREGAT D'UN TABLEAU DE TABLEAUX : PAS DE GLISSEMENT (LRM 4.3.2)");
     BEGIN
          A := (1 => (3 .. 4 => -1), 2 => (3 => -2, 4 => -3));
          FAILED ("PAS D'EXCEPTION : NOMME 3 .. 4");
     EXCEPTION WHEN CONSTRAINT_ERROR => NULL;
     END;
     A := (1 => (2 .. 3 => -1), 2 => (3 => -3, 2 => -2));
     IF A /= (1 => (2 => -1, 3 => -1), 2 => (2 => -2, 3 => -3)) THEN FAILED ("VALEURS NOMMEES"); END IF;
     RESULT;
END AGGTT1;
