WITH REPORT; USE REPORT;
PROCEDURE TABVAR1 IS
     SUBTYPE SM IS INTEGER RANGE 1..10;
     TYPE REC (D1, D2 : SM) IS RECORD NULL; END RECORD;
     TYPE CONS (D3 : INTEGER) IS
          RECORD
               CASE D3 IS
                    WHEN -5..10 => C1 : REC(D3, IDENT_INT (1));
                    WHEN OTHERS => C2 : INTEGER := IDENT_INT(0);
               END CASE;
          END RECORD;
     TYPE ARR IS ARRAY (1..5) OF CONS(IDENT_INT(-6));
     X : ARR;
     Y : ARR;
     Z : ARR := (1..5 => (-6, 0));
BEGIN
     TEST ("TABVAR1", "TABLEAU DE RECORDS A VARIANTES");
     IF X /= Y THEN FAILED ("X /= Y"); END IF;
     IF Z /= Y THEN FAILED ("Z /= Y"); END IF;
     FOR I IN 1 .. 5 LOOP
          IF Z (I) /= (-6, 0) THEN FAILED ("Z (" & INTEGER'IMAGE (I) & ")" & INTEGER'IMAGE (Z(I).D3)& INTEGER'IMAGE (Z(I).C2)); END IF;
     END LOOP;
     IF X /= (1..5 => (-6, 0)) THEN FAILED ("X /= AGG"); END IF;
     IF X /= (X(1), X(2), X(3), X(4), X(5)) THEN FAILED ("X /= POS"); END IF;
     RESULT;
END TABVAR1;
