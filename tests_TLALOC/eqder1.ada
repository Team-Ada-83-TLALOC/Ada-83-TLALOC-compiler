WITH REPORT; USE REPORT;
PROCEDURE EQDER1 IS
     SUBTYPE SM IS INTEGER RANGE 1..10;
     TYPE REC (D1, D2 : SM) IS RECORD NULL; END RECORD;
     TYPE CONS (D3 : INTEGER) IS
          RECORD
               C1 : REC (D3, IDENT_INT (1));
               N  : INTEGER := 7;
          END RECORD;
     TYPE NREC IS NEW CONS (2);
     TYPE NNREC IS NEW NREC;
     X : NREC;
     Y : NNREC;
BEGIN
     TEST ("EQDER1", "EGALITE D'UN RECORD DERIVE CONTRAINT AVEC UN AGREGAT (LRM 3.4, 4.5.2)");
     IF X /= (2, (2, 1), 7) THEN FAILED ("X /= (2, (2, 1), 7)"); END IF;
     IF X = (2, (2, 1), IDENT_INT (8)) THEN FAILED ("X = (2, (2, 1), 8)"); END IF;
     IF NOT (X /= (2, (2, IDENT_INT (1)), 6)) THEN FAILED ("NOT (X /= ...)"); END IF;
     IF (2, (2, 1), 7) /= X THEN FAILED ("AGREGAT A GAUCHE"); END IF;
     IF Y /= (2, (2, 1), 7) THEN FAILED ("Y, DERIVE DE DERIVE"); END IF;
     Y.N := 9;
     IF Y = (2, (2, 1), 7) OR Y /= (2, (2, 1), 9) THEN FAILED ("Y.N := 9"); END IF;
     IF NREC (Y) /= (2, (2, 1), 9) THEN FAILED ("CONVERSION"); END IF;
     RESULT;
END EQDER1;
