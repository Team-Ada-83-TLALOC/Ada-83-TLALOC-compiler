WITH REPORT; USE REPORT;
PROCEDURE AGG2D2 IS
     SUBTYPE SINT IS INTEGER RANGE 1 .. 8;
     TYPE T0 IS ARRAY (SINT RANGE <>, SINT RANGE <>) OF INTEGER;
     SUBTYPE T22 IS T0 (1 .. 2, 2 .. 3);
     TYPE COMPTE IS ARRAY (1 .. 4) OF INTEGER;
     NB : COMPTE := (OTHERS => 0);
     A : T22 := (OTHERS => (OTHERS => 0));
     N : INTEGER := 0;
     FUNCTION CALC (K, V : INTEGER) RETURN INTEGER IS
     BEGIN
          NB (K) := NB (K) + 1;
          RETURN IDENT_INT (V);
     END CALC;
     PROCEDURE P (X : T0) IS BEGIN N := N + 1; END P;
     PROCEDURE CE (NOM : STRING) IS BEGIN FAILED ("PAS DE CONSTRAINT_ERROR : " & NOM); END CE;
BEGIN
     TEST ("AGG2D2", "AGREGATS MULTIDIMENSIONNELS : CONTROLES DE LRM 4.3.2");
     -- sous-agregats de bornes differentes (meme longueur)
     BEGIN A := (1 => (2 .. 3 => 1), 2 => (IDENT_INT (3) .. 4 => 2)); CE ("AFFECTATION, BORNES"); EXCEPTION WHEN CONSTRAINT_ERROR => NULL; END;
     BEGIN P ((1 => (2 .. 3 => 1), 2 => (IDENT_INT (3) .. 4 => 2))); CE ("OPERANDE, BORNES"); EXCEPTION WHEN CONSTRAINT_ERROR => NULL; END;
     -- nomme contre positionnel (S'FIRST)
     BEGIN P ((1 => (3 .. 4 => 0), 2 => (1, 2))); CE ("NOMME / POSITIONNEL"); EXCEPTION WHEN CONSTRAINT_ERROR => NULL; END;
     -- longueurs differentes
     BEGIN P ((1 => (1, 2), 2 => (1, 2, 3))); CE ("LONGUEURS"); EXCEPTION WHEN CONSTRAINT_ERROR => NULL; END;
     -- borne hors du sous-type d'indice : intervalle, valeur, positionnel trop long
     BEGIN P ((2 .. IDENT_INT (9) => (1 .. 2 => 0))); CE ("INTERVALLE HORS SOUS-TYPE"); EXCEPTION WHEN CONSTRAINT_ERROR => NULL; END;
     BEGIN A := (8 => (1 .. 2 => 0), 9 => (1 .. 2 => 0)); CE ("VALEUR HORS SOUS-TYPE"); EXCEPTION WHEN CONSTRAINT_ERROR => NULL; END;
     BEGIN P ((1 => (1, 2, 3, 4, 5, 6, 7, 8, 9))); CE ("POSITIONNEL TROP LONG"); EXCEPTION WHEN CONSTRAINT_ERROR => NULL; END;
     IF N /= 0 THEN FAILED ("CORPS EXECUTE SANS CONTROLE"); END IF;
     IF A /= ((0, 0), (0, 0)) THEN NULL; END IF;
     -- intervalle nul hors sous-type : admis
     P ((9 .. 0 => (1 .. 2 => 0)));
     -- glissement admis a l'affectation, sous-agregats de memes bornes
     A := (5 .. 6 => (IDENT_INT (6) .. 7 => 3));
     IF A (2, 3) /= 3 THEN FAILED ("GLISSEMENT"); END IF;
     -- others : bornes du contexte, choix nommes differents admis (pas de controle de bornes)
     A := T22'(1 => (2 => 4, OTHERS => 0), 2 => (2 => 5, OTHERS => 0));
     IF A /= ((4, 0), (5, 0)) THEN FAILED ("OTHERS"); END IF;
     -- une seule evaluation des bornes du premier sous-agregat d'un operande
     NB := (OTHERS => 0);
     P ((CALC (1, 1) .. CALC (2, 2) => (CALC (3, 2) .. CALC (4, 3) => 0)));
     IF NB (1) /= 1 OR NB (2) /= 1 THEN FAILED ("EVALUATIONS F, G :" & INTEGER'IMAGE (NB (1)) & INTEGER'IMAGE (NB (2))); END IF;
     -- intervalle exterieur nul : bornes interieures evaluees une fois
     NB := (OTHERS => 0);
     DECLARE
          C1 : T0 (8 .. 4, 1 .. 2);
     BEGIN
          C1 := (CALC (1, 8) .. CALC (2, 4) => (CALC (3, 1) .. CALC (4, 2) => 0));
          IF NB /= (1, 1, 1, 1) THEN FAILED ("INTERVALLE NUL : EVALUATIONS"); END IF;
     END;
     IF N /= 2 THEN FAILED ("APPELS :" & INTEGER'IMAGE (N)); END IF;
     RESULT;
END AGG2D2;
