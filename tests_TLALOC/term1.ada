WITH REPORT; USE REPORT;
WITH TEXT_IO; USE TEXT_IO;
PROCEDURE TERM1 IS
     F : FILE_TYPE;
     C : CHARACTER;
     S : STRING (1 .. 10);
     L : NATURAL;
BEGIN
     TEST ("TERM1", "TERMINATEURS DE LIGNE, DE PAGE ET DE FICHIER " &
                    "(LRM 14.3)");

     -- 1. CLOSE termine la ligne et la page ; fin de fichier exacte.
     CREATE (F, OUT_FILE, "term1a.txt");
     PUT (F, "AB");
     CLOSE (F);
     OPEN (F, IN_FILE, "term1a.txt");
     IF END_OF_LINE (F) OR END_OF_PAGE (F) OR END_OF_FILE (F) THEN
          FAILED ("1 : FIN AVANT LES CARACTERES");
     END IF;
     GET (F, C);  GET (F, C);
     IF C /= 'B' OR COL (F) /= 3 THEN FAILED ("1 : LECTURE"); END IF;
     IF NOT END_OF_LINE (F) THEN FAILED ("1 : END_OF_LINE"); END IF;
     IF NOT END_OF_PAGE (F) THEN FAILED ("1 : END_OF_PAGE"); END IF;
     IF NOT END_OF_FILE (F) THEN FAILED ("1 : END_OF_FILE"); END IF;
     BEGIN
          GET (F, C);
          FAILED ("1 : END_ERROR NON LEVEE");
     EXCEPTION
          WHEN END_ERROR => NULL;
     END;
     DELETE (F);

     -- 2. Lignes et pages, SKIP_LINE saute le terminateur de page.
     CREATE (F, OUT_FILE, "term1b.txt");
     PUT (F, 'X');  NEW_LINE (F);
     PUT (F, 'Y');  NEW_PAGE (F);
     PUT (F, 'Z');
     RESET (F, IN_FILE);
     GET (F, C);
     IF C /= 'X' OR LINE (F) /= 1 OR COL (F) /= 2 THEN
          FAILED ("2 : X");
     END IF;
     IF END_OF_PAGE (F) THEN FAILED ("2 : END_OF_PAGE APRES X"); END IF;
     SKIP_LINE (F);
     GET (F, C);
     IF C /= 'Y' OR LINE (F) /= 2 THEN FAILED ("2 : Y"); END IF;
     IF NOT END_OF_PAGE (F) OR END_OF_FILE (F) THEN
          FAILED ("2 : FIN DE LA PAGE 1");
     END IF;
     SKIP_LINE (F);
     IF PAGE (F) /= 2 OR LINE (F) /= 1 OR COL (F) /= 1 THEN
          FAILED ("2 : SKIP_LINE N'A PAS SAUTE LA PAGE");
     END IF;
     GET (F, C);
     IF C /= 'Z' OR NOT END_OF_FILE (F) THEN FAILED ("2 : Z"); END IF;
     DELETE (F);

     -- 3. Les copies d'un FILE_TYPE partagent l'etat.
     CREATE (F, OUT_FILE, "term1c.txt");
     SET_OUTPUT (F);
     PUT ("ABC");
     IF COL (F) /= 4 OR COL /= 4 THEN FAILED ("3 : COL PARTAGEE"); END IF;
     NEW_LINE (F);
     IF LINE /= 2 OR COL /= 1 THEN FAILED ("3 : LINE PARTAGEE"); END IF;
     SET_OUTPUT (STANDARD_OUTPUT);
     CLOSE (F);
     IF IS_OPEN (CURRENT_INPUT) = FALSE THEN FAILED ("3 : ENTREE"); END IF;

     -- 4. SET_COL en lecture saute les lignes trop courtes.
     OPEN (F, OUT_FILE, "term1c.txt");
     PUT_LINE (F, "ABCDE");
     PUT_LINE (F, "FG");
     PUT_LINE (F, "HIJKL");
     RESET (F, IN_FILE);
     SET_COL (F, 4);
     GET (F, C);
     IF C /= 'D' THEN FAILED ("4 : SET_COL 4 -> " & C); END IF;
     SET_COL (F, 3);
     GET (F, C);
     IF C /= 'J' OR LINE (F) /= 3 THEN FAILED ("4 : SET_COL 3 -> " & C); END IF;
     BEGIN
          SET_COL (F, 2);
          FAILED ("4 : END_ERROR NON LEVEE");
     EXCEPTION
          WHEN END_ERROR => NULL;
     END;

     -- 5. SET_LINE en lecture passe la fin de page.
     RESET (F, OUT_FILE);
     PUT_LINE (F, "A");  PUT_LINE (F, "B");
     NEW_PAGE (F);
     PUT_LINE (F, "C");  PUT_LINE (F, "D");  PUT_LINE (F, "E");
     RESET (F, IN_FILE);
     SET_LINE (F, 3);
     GET (F, C);
     IF C /= 'E' OR PAGE (F) /= 2 THEN FAILED ("5 : SET_LINE -> " & C); END IF;

     -- 6. NEW_LINE avec longueur de page bornee.
     RESET (F, OUT_FILE);
     SET_PAGE_LENGTH (F, 2);
     PUT (F, 'A');
     NEW_LINE (F, 3);
     IF PAGE (F) /= 2 OR LINE (F) /= 2 THEN FAILED ("6 : PAGE BORNEE"); END IF;
     RESET (F, IN_FILE);
     SKIP_LINE (F, 2);
     IF PAGE (F) /= 2 OR LINE (F) /= 1 THEN FAILED ("6 : RELECTURE"); END IF;

     -- 7. GET_LINE : chaine nulle sans END_ERROR, CR LF lu comme LF.
     RESET (F, OUT_FILE);
     PUT (F, "AB" & ASCII.CR);
     NEW_LINE (F);
     RESET (F, IN_FILE);
     GET_LINE (F, S, L);
     IF L /= 2 OR S (1 .. 2) /= "AB" THEN FAILED ("7 : CR LF"); END IF;
     IF NOT END_OF_FILE (F) THEN FAILED ("7 : FIN"); END IF;
     GET_LINE (F, S (1 .. 0), L);
     IF L /= 0 THEN FAILED ("7 : CHAINE NULLE"); END IF;
     BEGIN
          GET_LINE (F, S, L);
          FAILED ("7 : END_ERROR NON LEVEE");
     EXCEPTION
          WHEN END_ERROR => NULL;
     END;
     DELETE (F);

     RESULT;
END TERM1;
