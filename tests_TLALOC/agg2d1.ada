WITH REPORT; USE REPORT;
PROCEDURE AGG2D1 IS
     TYPE M IS ARRAY (INTEGER RANGE <>, INTEGER RANGE <>) OF INTEGER;
     SUBTYPE M22 IS M (1 .. 2, 1 .. 2);
     TYPE COULEUR IS (ROUGE, VERT, BLEU);
     TYPE MC IS ARRAY (COULEUR RANGE <>, POSITIVE RANGE <>) OF CHARACTER;
     TYPE M3 IS ARRAY (INTEGER RANGE <>, INTEGER RANGE <>, INTEGER RANGE <>) OF INTEGER;
     A : M22 := ((1, 2), (3, 4));
     N : INTEGER := 0;
     X23 : M (1 .. 2, 1 .. 3) := (OTHERS => (OTHERS => 0));
     X32 : M (1 .. 3, 1 .. 2) := (OTHERS => (OTHERS => 0));
     N1 : M (1 .. 0, 1 .. 3);
     N2 : M (1 .. 2, 1 .. IDENT_INT (0));
     PROCEDURE P (X : M; F1, L1, F2, L2, S : INTEGER) IS
          T : INTEGER := 0;
     BEGIN
          IF X'FIRST (1) /= F1 OR X'LAST (1) /= L1 OR X'FIRST (2) /= F2 OR X'LAST (2) /= L2 THEN
               FAILED ("BORNES" & INTEGER'IMAGE (X'FIRST (1)) & INTEGER'IMAGE (X'LAST (1))
                       & INTEGER'IMAGE (X'FIRST (2)) & INTEGER'IMAGE (X'LAST (2)));
          END IF;
          FOR I IN X'RANGE (1) LOOP
               FOR J IN X'RANGE (2) LOOP
                    T := T + X (I, J) * (10 * (I - X'FIRST (1)) + (J - X'FIRST (2)) + 1);
               END LOOP;
          END LOOP;
          IF T /= S THEN FAILED ("SOMME PONDEREE" & INTEGER'IMAGE (T)); END IF;
          N := N + 1;
     END P;
     PROCEDURE PC (X : MC; F : COULEUR; L2 : INTEGER; C : CHARACTER) IS
     BEGIN
          IF X'FIRST (1) /= F OR X'LAST (2) /= L2 OR X (X'LAST (1), L2) /= C THEN FAILED ("MC"); END IF;
          N := N + 1;
     END PC;
     PROCEDURE P3 (X : M3) IS
     BEGIN
          IF X'LENGTH (1) /= 2 OR X'LENGTH (2) /= 2 OR X'LENGTH (3) /= 3 OR X (2, 1, 6) /= 9
             OR X'FIRST (3) /= 4 OR X (1, 2, 4) /= 4
          THEN
               FAILED ("M3");
          END IF;
          N := N + 1;
     END P3;
     FUNCTION F RETURN M22 IS BEGIN RETURN A; END F;
BEGIN
     TEST ("AGG2D1", "AGREGATS MULTIDIMENSIONNELS EN OPERANDE (LRM 4.3.2)");
     IF A /= ((1, 2), (3, 4)) THEN FAILED ("A /= AGREGAT EGAL"); END IF;
     IF A = ((1, 2), (3, 5)) THEN FAILED ("A = AGREGAT DIFFERENT"); END IF;
     IF F /= (1 .. 2 => (1 .. 2 => 9)) AND F /= ((1, 2), (3, 4)) THEN FAILED ("F"); END IF;
     IF A = (5 .. 6 => (1 .. 2 => 1)) THEN FAILED ("A = BORNES DIFFERENTES"); END IF;
     IF A /= (5 .. 6 => (7 .. 8 => 0)) AND A /= (5 .. 6 => (7, 8)) THEN NULL; ELSE FAILED ("GLISSEMENT"); END IF;
     IF X23 = X32 THEN FAILED ("2 x 3 = 3 x 2"); END IF;
     IF N1 /= N2 THEN FAILED ("TABLEAUX NULS"); END IF;
     IF M'((1, 2), (3, 4)) /= (11 .. 12 => (0 => 1, 1 => 2)) AND M'((1, 2), (3, 4)) = (11 .. 12 => (0 .. 1 => 1)) THEN
          NULL;
     ELSIF M'((1, 2), (3, 4)) /= (11 .. 12 => (0 => 1, 1 => 2)) THEN
          NULL;
     ELSE
          FAILED ("DEUX AGREGATS");
     END IF;
     IF M'((1, 2), (3, 4)) /= (11 .. 12 => (0 => 1, 1 => 2)) THEN NULL; END IF;
     -- positionnel : S'FIRST du sous-type d'indice ; somme ponderee = 1*1 + 2*2 + 3*11 + 4*12
     P (((1, 2), (3, 4)), INTEGER'FIRST, INTEGER'FIRST + 1, INTEGER'FIRST, INTEGER'FIRST + 1, 86);
     -- nomme, intervalles statiques et dynamiques
     P ((5 .. 6 => (IDENT_INT (2) .. 3 => 1)), 5, 6, 2, 3, 1 + 2 + 11 + 12);
     -- nomme, choix individuels
     P ((7 => (0 => 1, 1 => 2), 8 => (0 => 3, 1 => 4)), 7, 8, 0, 1, 86);
     -- nomme dehors, positionnel dedans
     P ((3 .. 4 => (5, 6, 7)), 3, 4, INTEGER'FIRST, INTEGER'FIRST + 2, 5 + 12 + 21 + 55 + 72 + 91);
     -- vide sur une dimension
     P ((1 .. 0 => (1 .. 3 => 0)), 1, 0, 1, 3, 0);
     -- indice enumere, composant caractere
     PC ((VERT .. BLEU => (1 .. 2 => 'Z')), VERT, 2, 'Z');
     PC (((1 => 'A', 2 => 'B'), (1 => 'C', 2 => 'D')), ROUGE, 2, 'D');
     -- trois dimensions
     P3 ((1 => (1 .. 2 => (4 .. 6 => 4)), 2 => (1 => (4 => 7, 5 => 8, 6 => 9), 2 => (4 .. 6 => 1))));
     IF N /= 8 THEN FAILED ("APPELS :" & INTEGER'IMAGE (N)); END IF;
     RESULT;
END AGG2D1;
