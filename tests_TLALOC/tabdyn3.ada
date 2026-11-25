WITH REPORT; USE REPORT;
PROCEDURE TABDYN3 IS
     SUBTYPE SM IS INTEGER RANGE 1 .. 10;
     TYPE CONS (D : INTEGER) IS
          RECORD
               N : INTEGER := 7;
               S : STRING (1 .. D);
          END RECORD;
     SUBTYPE SUBINT IS INTEGER RANGE 1 .. 5;
     TYPE REC (DISC : SUBINT := 1) IS
          RECORD
               COMP : STRING (IDENT_INT (3) .. DISC);
          END RECORD;
     TYPE TC IS ARRAY (1 .. 3) OF CONS (2);
     TYPE TR IS ARRAY (1 .. 3) OF REC;
     A, B : TC;
     C : TC := (OTHERS => (2, 4, "OO"));
     R1, R2 : TR;
     E : CONS (2) := (2, 9, "EE");
BEGIN
     TEST ("TABDYN3", "TABLEAUX DE RECORDS DYNAMIQUES : EGALITE, AGREGATS");
     IF A /= B THEN FAILED ("A /= B (DEFAUTS)"); END IF;
     A (2).S := "XY";
     IF A = B THEN FAILED ("A = B APRES MODIFICATION"); END IF;
     B (2).S := "XY";
     IF A /= B THEN FAILED ("A /= B APRES MODIFICATION"); END IF;
     IF C (3).S /= "OO" OR C (1).N /= 4 THEN FAILED ("C : OTHERS"); END IF;
     A := (1 => (2, 1, "AA"), 2 => E, 3 => (2, 3, "CC"));
     IF A (1).S /= "AA" OR A (2).N /= 9 OR A (3).S /= "CC" THEN FAILED ("A : NOMME"); END IF;
     B := ((2, 1, "AA"), E, (2, 3, "CC"));
     IF A /= B THEN FAILED ("B : POSITIONNEL"); END IF;
     IF B /= ((2, 1, "AA"), (2, 9, "EE"), (2, 3, "CC")) THEN FAILED ("B /= AGREGAT"); END IF;
     IF B = (1 .. 3 => (2, 1, "AA")) THEN FAILED ("B = AGREGAT DIFFERENT"); END IF;
     B := (2 .. 4 => (2, 5, "GG"));
     IF B (1).S /= "GG" OR B (3).N /= 5 THEN FAILED ("B : GLISSEMENT"); END IF;
     BEGIN
          B := (1 .. 2 => (2, 5, "GG"));
          FAILED ("LONGUEUR : PAS DE CONSTRAINT_ERROR");
     EXCEPTION WHEN CONSTRAINT_ERROR => NULL;
     END;
     BEGIN
          B := (OTHERS => (IDENT_INT (3), 5, "GGG"));
          FAILED ("DISCRIMINANT : PAS DE CONSTRAINT_ERROR");
     EXCEPTION WHEN CONSTRAINT_ERROR => NULL;
     END;
     IF R1 /= R2 THEN FAILED ("R1 /= R2 (NULS)"); END IF;
     R1 (2) := (5, "ABC");
     IF R1 = R2 THEN FAILED ("R1 = R2"); END IF;
     R2 (2) := (5, "ABD");
     IF R1 = R2 THEN FAILED ("R1 = R2 (DERNIER)"); END IF;
     R2 (2) := (4, "AB");
     IF R1 = R2 THEN FAILED ("R1 = R2 (LONGUEURS)"); END IF;
     R1 (2) := (4, "AB");
     IF R1 /= R2 THEN FAILED ("R1 /= R2 (MUTABLES, QUEUE DIFFERENTE)"); END IF;
     R1 := (OTHERS => (5, "XYZ"));
     IF R1 (3).DISC /= 5 OR R1 (1).COMP /= "XYZ" THEN FAILED ("R1 : OTHERS MUTABLE"); END IF;
     RESULT;
END TABDYN3;
