WITH REPORT; USE REPORT;
WITH SYSTEM;
PROCEDURE FXSTAT1 IS
     FS   : CONSTANT := 2 ** 11;
     DEL1 : CONSTANT := 0.5 / FS;                         -- 2**-12
     D4   : CONSTANT := DEL1 * 4;                         -- 2**-10
     TYPE FX_1 IS DELTA DEL1 * 2 RANGE -1.0 .. 1.0 - DEL1 * 2;
     TYPE FX_2 IS DELTA D4 RANGE -2.0 .. 2.0;
     DF   : CONSTANT := SYSTEM.FINE_DELTA;
     TYPE FIN IS DELTA DF RANGE -1.0 .. 1.0;
     A1 : FX_2 := FX_2 (DEL1 * (FS / 4 + 4));             -- conversion d'une expression universelle
     A2 : FX_2 := D4;                                     -- nombre nomme, contexte implicite
     A3 : FX_2 := D4 * 3;                                 -- operateur type fixe statique
     A4 : FX_2 := 3 * D4;
     A5 : FX_1 := FX_1 (0.125);
     A6 : FX_2 := FX_2 (D4 * 128) + D4;
     F1 : FIN := 0.5;
     F2 : FIN := 1.0 - DF;
     FUNCTION REP (X : FX_2) RETURN INTEGER IS
     BEGIN
          RETURN INTEGER (X * 1024);
     END REP;
BEGIN
     TEST ("FXSTAT1", "VALEURS STATIQUES DES FIXES (LRM 4.6, 4.9, 4.10)");
     IF REP (A1) /= 129 THEN FAILED ("A1" & INTEGER'IMAGE (REP (A1))); END IF;
     IF REP (A2) /= 1 THEN FAILED ("A2" & INTEGER'IMAGE (REP (A2))); END IF;
     IF REP (A3) /= 3 THEN FAILED ("A3" & INTEGER'IMAGE (REP (A3))); END IF;
     IF REP (A4) /= 3 THEN FAILED ("A4" & INTEGER'IMAGE (REP (A4))); END IF;
     IF INTEGER (A5 * 2048) /= 256 THEN FAILED ("A5"); END IF;
     IF REP (A6) /= 129 THEN FAILED ("A6" & INTEGER'IMAGE (REP (A6))); END IF;
     IF A2 /= D4 OR A3 /= D4 * 3 OR A2 = D4 * 2 THEN FAILED ("COMPARAISONS A UN NOMBRE NOMME"); END IF;
     IF A1 /= FX_2 (DEL1 * 516) THEN FAILED ("EGALITE DE CONVERSIONS"); END IF;
     IF F2 - F1 /= F1 - DF * IDENT_INT (1) THEN FAILED ("F2 = 1.0 - FINE_DELTA"); END IF;
     IF F1 * IDENT_INT (1) /= 0.5 THEN FAILED ("F1"); END IF;
     BEGIN
          F1 := ABS (-1.5);
          FAILED ("PAS D'EXCEPTION : ABS (-1.5) HORS DU TYPE DE BASE");
          IF F1 = 0.0 THEN COMMENT ("F1"); END IF;
     EXCEPTION
          WHEN CONSTRAINT_ERROR | NUMERIC_ERROR => NULL;
     END;
     BEGIN
          A1 := FX_2 (FX_2'SAFE_LARGE ** 2);
          FAILED ("PAS D'EXCEPTION : CONVERSION HORS DU TYPE DE BASE");
          IF A1 = 0.0 THEN COMMENT ("A1"); END IF;
     EXCEPTION
          WHEN CONSTRAINT_ERROR | NUMERIC_ERROR => NULL;
     END;
     RESULT;
END FXSTAT1;
