WITH REPORT; USE REPORT;
PROCEDURE REEL1 IS
     A, B, C, D : FLOAT;
BEGIN
     TEST ("REEL1", "LITTERAUX REELS");
     A := 16#F.FF#E+2;
     B := 4095.0;
     C := 1.2E2;
     D := 120.0;
     IF A /= B THEN FAILED ("A /= B"); END IF;
     IF C /= D THEN FAILED ("C /= D"); END IF;
     IF A /= 4095.0 THEN FAILED ("A /= 4095.0"); END IF;
     RESULT;
END REEL1;
