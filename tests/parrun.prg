// parrun - despacho+join da suíte paralela em Harbour (B-infra Etapa 2)
//
// Mesma FORMA da Etapa 1 (pool dinâmico por-caso com teto, artefato por
// unidade, join NA ORDEM com tally somado); troca só a tecnologia do PAI:
// hb_processOpen/hb_processValue (fato do fonte: waitpid WNOHANG, -1
// enquanto roda) no lugar do xargs -P. O protocolo filho é intocado:
// `run.sh --unit N` escreve <pardir>/N.log e termina com
// "@@counts <pass> <fail>"; unidade sem @@counts conta FAIL e mostra o
// log (silêncio nunca parece sucesso). Saída byte-idêntica ao join bash.
//
// Uso (o run.sh delega aqui no modo JOBS>1):
//   parrun <run.sh> <pardir> <jobs> <unidade>...

PROCEDURE Main( ... )

   LOCAL cRunSh := hb_PValue( 1 )
   LOCAL cParDir := hb_PValue( 2 )
   LOCAL nJobs := Val( hb_defaultValue( hb_PValue( 3 ), "0" ) )
   LOCAL aUnits := {}, aRun := {}, nNext := 1, nAt, lReaped, nHandle
   LOCAL cUnit, cLog, cText, aLines, cLine, cCounts, nPass := 0, nFail := 0

   IF PCount() < 4 .OR. Empty( cRunSh ) .OR. Empty( cParDir ) .OR. nJobs < 2
      OutErr( "parrun: uso: parrun <run.sh> <pardir> <jobs> <unidade>..." + hb_eol() )
      ErrorLevel( 2 )
      RETURN
   ENDIF
   FOR nAt := 4 TO PCount()
      AAdd( aUnits, hb_PValue( nAt ) )
   NEXT

   // pool dinâmico: spawna até o teto, colhe quem terminou, repõe
   DO WHILE nNext <= Len( aUnits ) .OR. Len( aRun ) > 0
      DO WHILE Len( aRun ) < nJobs .AND. nNext <= Len( aUnits )
         nHandle := hb_processOpen( "/bin/bash " + cRunSh + " --unit " + aUnits[ nNext ] )
         IF nHandle != -1
            AAdd( aRun, nHandle )
         ENDIF
         // spawn falhado: sem log/@@counts, o join conta a unidade como morta
         nNext++
      ENDDO
      lReaped := .F.
      FOR nAt := Len( aRun ) TO 1 STEP -1
         IF hb_processValue( aRun[ nAt ], .F. ) != -1
            hb_ADel( aRun, nAt, .T. )
            lReaped := .T.
         ENDIF
      NEXT
      IF ! lReaped .AND. Len( aRun ) > 0
         hb_idleSleep( 0.02 )
      ENDIF
   ENDDO

   // join na ordem das unidades: imprime cada log sem as linhas @@counts e
   // soma o tally da última @@counts; sem ela = morreu no meio
   FOR EACH cUnit IN aUnits
      cLog := hb_DirSepAdd( cParDir ) + cUnit + ".log"
      cText := hb_MemoRead( cLog )
      aLines := hb_ATokens( cText, Chr( 10 ) )
      IF Len( aLines ) > 0 .AND. Len( ATail( aLines ) ) == 0
         ASize( aLines, Len( aLines ) - 1 )   // \n final não é linha vazia
      ENDIF
      cCounts := ""
      FOR EACH cLine IN aLines
         IF hb_LeftEq( cLine, "@@counts " )
            cCounts := cLine
         ELSE
            OutStd( cLine + hb_eol() )
         ENDIF
      NEXT
      IF Len( cCounts ) == 0
         OutStd( "  FAIL: unidade " + cUnit + " morreu sem contadores (ver " + cLog + ")" + hb_eol() )
         nFail++
      ELSE
         nPass += Val( hb_TokenGet( cCounts, 2, " " ) )
         nFail += Val( hb_TokenGet( cCounts, 3, " " ) )
      ENDIF
   NEXT

   OutStd( hb_eol() )
   OutStd( "passed: " + hb_ntos( nPass ) + "  failed: " + hb_ntos( nFail ) + hb_eol() )
   ErrorLevel( iif( nFail == 0, 0, 1 ) )

   RETURN
