WITH REPORT; USE REPORT;
PROCEDURE AGGOTH1 IS
     TYPE ARR IS ARRAY (INTEGER RANGE <>) OF INTEGER;
     SUBTYPE A23 IS ARR (2 .. 3);
     SUBTYPE A15 IS ARR (1 .. 5);
     TYPE M IS ARRAY (1 .. 2, 1 .. 3) OF INTEGER;
     SUBTYPE S5 IS STRING (1 .. 5);
     TYPE COULEUR IS (ROUGE, VERT, BLEU, NOIR);
     TYPE PAR_COULEUR IS ARRAY (COULEUR) OF INTEGER;
     N : INTEGER := 0;
     FUNCTION F RETURN INTEGER;
     X : A23 := A23'(3 => 5, OTHERS => 0);
     Y : A15 := A15'(4 => 4, 2 => 2, OTHERS => F);
     Z : A15 := A15'(5 => 50, 1 => 10, 2 .. 4 => 7);
     W : A15 := A15'(2 | 4 => 1, OTHERS => 0);
     V : A15 := A15'(2 .. 3 => 6, OTHERS => 0);
     MM : M := M'(2 => (3 => 1, OTHERS => 0), OTHERS => (2 => 5, OTHERS => 8));
     S : S5 := S5'(3 => 'X', OTHERS => '.');
     C : PAR_COULEUR := PAR_COULEUR'(VERT => 1, NOIR => 3, OTHERS => 0);
     FUNCTION F RETURN INTEGER IS BEGIN N := N + 1; RETURN 9; END F;
     FUNCTION SOMME (A : ARR) RETURN INTEGER IS
          R : INTEGER := 0;
     BEGIN
          FOR I IN A'RANGE LOOP R := R * 10 + A (I); END LOOP;
          RETURN R;
     END SOMME;
BEGIN
     TEST ("AGGOTH1", "AGREGATS : CHOIX NOMMES AVEC OTHERS, PLACES A LEUR INDICE (LRM 4.3.2)");
     IF X /= (0, 5) THEN FAILED ("X"); END IF;
     IF Y /= (9, 2, 9, 4, 9) THEN FAILED ("Y"); END IF;
     IF N /= 3 THEN FAILED ("OTHERS EVALUE" & INTEGER'IMAGE (N) & " FOIS AU LIEU DE 3"); END IF;
     IF Z /= (10, 7, 7, 7, 50) THEN FAILED ("Z : SANS OTHERS"); END IF;
     IF W /= (0, 1, 0, 1, 0) THEN FAILED ("W : CHOIX MULTIPLE"); END IF;
     IF V /= (0, 6, 6, 0, 0) THEN FAILED ("V : INTERVALLE"); END IF;
     IF MM /= ((8, 5, 8), (0, 0, 1)) THEN FAILED ("MM : DEUX DIMENSIONS"); END IF;
     IF S /= "..X.." THEN FAILED ("S : CHAINE"); END IF;
     IF C /= (0, 1, 0, 3) THEN FAILED ("C : INDICE ENUMERE"); END IF;
     IF SOMME (A15'(3 => 3, OTHERS => 1)) /= 11311 THEN FAILED ("OPERANDE"); END IF;
     DECLARE
          SUBTYPE AD IS ARR (IDENT_INT (4) .. IDENT_INT (7));
          D : AD := AD'(5 => 5, 7 => 7, OTHERS => 0);
     BEGIN
          IF D /= (0, 5, 0, 7) THEN FAILED ("D : BORNES DYNAMIQUES"); END IF;
     END;
     BEGIN
          DECLARE
               SUBTYPE AD IS ARR (IDENT_INT (1) .. IDENT_INT (3));
               D : AD := AD'(5 => 5, OTHERS => 0);
          BEGIN
               FAILED ("PAS DE CONSTRAINT_ERROR (CHOIX HORS DES BORNES)");
          END;
     EXCEPTION
          WHEN CONSTRAINT_ERROR => NULL;
     END;
     RESULT;
END AGGOTH1;
