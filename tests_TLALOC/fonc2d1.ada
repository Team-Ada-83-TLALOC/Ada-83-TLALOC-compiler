WITH REPORT; USE REPORT;
PROCEDURE FONC2D1 IS
     TYPE M IS ARRAY (INTEGER RANGE <>, INTEGER RANGE <>) OF INTEGER;
     TYPE MC IS ARRAY (INTEGER RANGE <>, POSITIVE RANGE <>) OF CHARACTER;
     Y : MC (1 .. 2, 1 .. 3) := ("AB""", "DEF");
     FUNCTION F (L : INTEGER) RETURN M IS
          R : M (IDENT_INT (3) .. 4, 5 .. IDENT_INT (4 + L)) := (OTHERS => (OTHERS => L));
     BEGIN
          R (4, 5) := 7;
          RETURN R;
     END F;
     FUNCTION G RETURN M IS BEGIN RETURN (1 .. 2 => (0 .. 2 => 3)); END G;
     PROCEDURE P (X : M) IS
     BEGIN
          IF X'FIRST (1) /= 3 OR X'LAST (2) /= 6 OR X (4, 5) /= 7 OR X (3, 6) /= 2 THEN FAILED ("P"); END IF;
     END P;
     PROCEDURE PC (X : MC) IS
     BEGIN
          IF X'LENGTH (1) /= 2 OR X'FIRST (2) /= 1 OR X'LAST (2) /= 3 OR X (X'LAST (1), 2) /= 'E'
             OR X (X'FIRST (1), 3) /= '"'
          THEN
               FAILED ("PC");
          END IF;
     END PC;
BEGIN
     TEST ("FONC2D1", "RESULTAT DE FONCTION MULTIDIMENSIONNEL, SOUS-AGREGATS CHAINES");
     IF F (2)'FIRST (1) /= 3 OR F (2)'LAST (1) /= 4 OR F (2)'FIRST (2) /= 5 OR F (2)'LAST (2) /= 6 THEN
          FAILED ("ATTRIBUTS");
     END IF;
     IF F (2)'LENGTH (2) /= 2 THEN FAILED ("LENGTH (2)"); END IF;
     IF F (2) (4, 5) /= 7 OR F (2) (3, 6) /= 2 THEN FAILED ("INDEXATION"); END IF;
     P (F (2));
     IF F (2) /= ((2, 2), (7, 2)) THEN FAILED ("EGALITE"); END IF;
     IF G'LAST (2) /= 2 OR G (2, 0) /= 3 THEN FAILED ("G"); END IF;
     DECLARE
          X : M (1 .. 2, 1 .. 2) := F (2);
     BEGIN
          IF X (2, 1) /= 7 THEN FAILED ("X := F"); END IF;
     END;
     PC (("AB""", "DEF"));
     PC ((5 => "AB""", 6 => "DEF"));
     IF Y /= ("AB""", "DEF") OR Y = ("ABC", "DEF") THEN FAILED ("EGALITE CHAINES"); END IF;
     RESULT;
END FONC2D1;
