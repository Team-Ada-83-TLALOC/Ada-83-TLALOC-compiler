WITH REPORT; USE REPORT;
PROCEDURE RECOTH1 IS
     SUBTYPE SM IS INTEGER RANGE 0 .. 10;
     TYPE R3 IS RECORD A, B, C : INTEGER; D : BOOLEAN; END RECORD;
     TYPE V (K : INTEGER := 1) IS RECORD
          P : INTEGER;
          CASE K IS
               WHEN 1 => Q : INTEGER;
               WHEN OTHERS => S : CHARACTER;
          END CASE;
     END RECORD;
     TYPE DYN (L : SM := 2) IS RECORD
          A, B : INTEGER;
          T : STRING (1 .. L);
     END RECORD;
     TYPE R IS RECORD A, B : INTEGER; C : FLOAT; END RECORD;
     TYPE AR IS ACCESS R;
     N : INTEGER := 0;
     X : R3 := (A => 1, D => TRUE, OTHERS => 0);
     Y : R3 := (2, D => FALSE, OTHERS => 5);
     Z : R3;
     W : V := (K => 1, OTHERS => 4);
     W1 : V := (OTHERS => 1);
     D : DYN := (L => 3, T => "ABC", OTHERS => 7);
     E : DYN (2);
     P : AR := NEW R'(C => 1.5, OTHERS => 6);
     FUNCTION F RETURN INTEGER IS BEGIN N := N + 1; RETURN 9; END F;
     PROCEDURE PR (X : R) IS BEGIN IF X.A /= 8 OR X.B /= 8 THEN FAILED ("PARAMETRE"); END IF; END PR;
BEGIN
     TEST ("RECOTH1", "AGREGATS DE RECORD AVEC OTHERS (LRM 4.3.1)");
     IF X /= (1, 0, 0, TRUE) THEN FAILED ("X"); END IF;
     IF Y /= (2, 5, 5, FALSE) THEN FAILED ("Y : POSITIONNEL ET OTHERS"); END IF;
     Z := (B => 7, D => TRUE, OTHERS => F);
     IF Z /= (9, 7, 9, TRUE) THEN FAILED ("Z"); END IF;
     IF N /= 2 THEN FAILED ("OTHERS EVALUE" & INTEGER'IMAGE (N) & " FOIS AU LIEU DE 2"); END IF;
     IF W.P /= 4 OR W.Q /= 4 THEN FAILED ("W : VARIANTE"); END IF;
     IF W1.K /= 1 OR W1.P /= 1 OR W1.Q /= 1 THEN FAILED ("W1 : DISCRIMINANT PAR OTHERS"); END IF;
     IF D.L /= 3 OR D.A /= 7 OR D.B /= 7 OR D.T /= "ABC" THEN FAILED ("D : RECORD DYNAMIQUE"); END IF;
     E := (L => 2, T => "XY", OTHERS => IDENT_INT (4));
     IF E.A /= 4 OR E.B /= 4 OR E.T /= "XY" THEN FAILED ("E : AFFECTATION"); END IF;
     IF P.A /= 6 OR P.B /= 6 OR P.C /= 1.5 THEN FAILED ("P : ALLOCATEUR"); END IF;
     PR ((C => 0.0, OTHERS => 8));
     IF R'(C => 2.0, OTHERS => 1) /= (1, 1, 2.0) THEN FAILED ("EGALITE"); END IF;
     RESULT;
END RECOTH1;
