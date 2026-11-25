WITH REPORT; USE REPORT;
PROCEDURE TABDYN1 IS
     SUBTYPE SM IS INTEGER RANGE 1 .. 10;
     TYPE MY_ARR IS ARRAY (SM RANGE <>) OF INTEGER;
     TYPE CONS (D : INTEGER) IS
          RECORD
               N : INTEGER := 7;
               S : STRING (1 .. D);
          END RECORD;
     TYPE MUT (L : SM := 2) IS
          RECORD
               T : STRING (1 .. L) := (1 .. L => 'M');
               K : INTEGER := 3;
          END RECORD;
     TYPE TC IS ARRAY (1 .. 4) OF CONS (3);
     TYPE TCD IS ARRAY (1 .. 3) OF CONS (IDENT_INT (2));
     TYPE TM IS ARRAY (1 .. 3) OF MUT;
     TYPE PTC IS ACCESS TC;
     A : TC;
     B : TCD;
     M : TM;
     P : PTC := NEW TC;
     R : CONS (3);
     N : INTEGER := 0;
BEGIN
     TEST ("TABDYN1", "TABLEAUX DE RECORDS DYNAMIQUES : OBJETS, INDEXATION, SELECTION, AFFECTATION");
     IF A (1).D /= 3 OR A (4).D /= 3 OR A (2).N /= 7 OR A (3).S'LENGTH /= 3 THEN FAILED ("A : GABARIT"); END IF;
     A (2).S := "XYZ";
     A (3).S (2) := 'Q';
     IF A (2).S /= "XYZ" OR A (3).S (2) /= 'Q' OR A (1).N /= 7 THEN FAILED ("A : SELECTION"); END IF;
     R.N := 9;  R.S := "RST";
     A (4) := R;
     IF A (4).N /= 9 OR A (4).S /= "RST" OR A (2).S /= "XYZ" THEN FAILED ("A (4) := R"); END IF;
     R := A (2);
     IF R.S /= "XYZ" THEN FAILED ("R := A (2)"); END IF;
     IF B (3).D /= 2 OR B (1).S'LAST /= 2 THEN FAILED ("B : CONTRAINTE DYNAMIQUE"); END IF;
     IF M (1).L /= 2 OR M (2).T /= "MM" OR M (3).K /= 3 THEN FAILED ("M : DEFAUTS"); END IF;
     M (2) := (5, "ABCDE", 4);
     IF M (2).L /= 5 OR M (2).T /= "ABCDE" OR M (3).T /= "MM" OR M (1).K /= 3 THEN FAILED ("M (2) := AGREGAT"); END IF;
     IF P (2).D /= 3 OR P (4).N /= 7 THEN FAILED ("P : NEW TC"); END IF;
     FOR I IN A'RANGE LOOP N := N + A (I).S'LENGTH; END LOOP;
     IF N /= 12 THEN FAILED ("BOUCLE"); END IF;
     BEGIN
          A (1) := (4, 1, "ABCD");
          FAILED ("PAS DE CONSTRAINT_ERROR");
     EXCEPTION WHEN CONSTRAINT_ERROR => NULL;
     END;
     BEGIN
          DECLARE
               TYPE TX IS ARRAY (1 .. 2) OF CONS (IDENT_INT (11));
               SUBTYPE S2 IS INTEGER RANGE 1 .. 2;
          BEGIN
               NULL;
          END;
     EXCEPTION WHEN OTHERS => FAILED ("CONS (11) : EXCEPTION INATTENDUE");
     END;
     RESULT;
END TABDYN1;
