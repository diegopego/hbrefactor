// lexdiff - porta de precisão da Fase B1 (roadmap v3)
//
// Compara, por arquivo do corpus, as posições de identificadores do dump
// ast-1 (tokens do compilador, com coluna) contra o TokenScan da primeira
// encarnação (smoketest/hbrefactor-occ.prg - copiado abaixo, verbatim).
//
// Direções e classes adjudicadas (divergência esperada POR DESENHO):
//   TS-só  em linha de diretiva (#...)      -> pp consome, nunca chega ao yylex
//   TS-só  em linha de continuação (termina em ';' no texto limpo) - o
//          compilador vê o statement na última linha física
//   AST-só precedido de ':' ou '->'         -> TokenScan os excluía de propósito
//   AST-só de proveniência de reescrita     -> TokenScan não sabe o que o pp fez
// Qualquer outra divergência é REAL e sai com exit != 0.
//
// Uso: lexdiff <dir-dos-ast.json> <fonte1.prg> [<fonte2.prg> ...]

PROCEDURE Main()

   LOCAL aArgs := hb_AParams()
   LOCAL cDir, cSrc, nBad := 0, nOkT := 0, nAdj := 0

   IF Len( aArgs ) < 2
      OutStd( "uso: lexdiff <dir-ast> <fonte.prg> ..." + hb_eol() )
      ErrorLevel( 2 )
      RETURN
   ENDIF
   cDir := hb_DirSepAdd( aArgs[ 1 ] )

   FOR EACH cSrc IN aArgs
      IF cSrc:__enumIndex() == 1
         LOOP
      ENDIF
      LexDiffFile( cDir, cSrc, @nOkT, @nAdj, @nBad )
   NEXT

   OutStd( "lexdiff: " + hb_ntos( nOkT ) + " concordantes, " + ;
           hb_ntos( nAdj ) + " adjudicadas por desenho, " + ;
           hb_ntos( nBad ) + " divergências REAIS" + hb_eol() )
   ErrorLevel( iif( nBad == 0, 0, 1 ) )

   RETURN

STATIC PROCEDURE LexDiffFile( cDir, cSrc, nOkT, nAdj, nBad )

   LOCAL hAst := hb_jsonDecode( hb_MemoRead( cDir + hb_FNameName( cSrc ) + ".ast.json" ) )
   LOCAL cText := hb_MemoRead( cSrc )
   LOCAL aSrc := hb_ATokens( StrTran( cText, Chr( 13 ), "" ), Chr( 10 ) )
   LOCAL hByName := { => }, hTok, cUp, hScan, nL, aHit
   LOCAL cKey, hSeen, cLine, cPrev, nI, hRewr := { => }, hAnyTok := { => }

   IF ! HB_ISHASH( hAst )
      OutStd( cSrc + ": sem dump ast - pulado" + hb_eol() )
      RETURN
   ENDIF

   // linhas tocadas por reescrita de regra: têm token sintetizado (prov n).
   // identificador consumido pela regra SEM passar por marker (ex.: nome de
   // método colado em <Classe>_<Método> pelo hbclass.ch) não tem posição no
   // stream - classe adjudicada; a fase B4 (ppApplications) a exporá.
   FOR EACH hTok IN hAst[ "tokens" ]
      IF hTok[ "prov" ] == "n" .AND. hTok[ "line" ] > 0
         hRewr[ hTok[ "line" ] ] := .T.
      ENDIF
      IF hTok[ "line" ] > 0
         hAnyTok[ hTok[ "line" ] ] := .T.
      ENDIF
   NEXT

   // identificadores do dump com coluna, agrupados por nome
   FOR EACH hTok IN hAst[ "tokens" ]
      IF hTok[ "type" ] == 21 .AND. hTok[ "col" ] != NIL .AND. ;
         hTok[ "prov" ] == "s" .AND. hTok[ "line" ] > 0
         cUp := Upper( hTok[ "text" ] )
         IF ! cUp $ hByName
            hByName[ cUp ] := { => }
         ENDIF
         hByName[ cUp ][ hb_ntos( hTok[ "line" ] ) + ":" + hb_ntos( hTok[ "col" ] + 1 ) ] := hTok
      ENDIF
   NEXT

   FOR EACH cUp IN hb_HKeys( hByName )
      hScan := TokenScan( cText, cUp )
      hSeen := { => }

      // direção 1: tudo que o TokenScan acharia, o AST cobre?
      FOR EACH nL IN hb_HKeys( hScan[ "hits" ] )
         FOR EACH aHit IN hScan[ "hits" ][ nL ]
            cKey := hb_ntos( nL ) + ":" + hb_ntos( aHit[ 1 ] )
            hSeen[ cKey ] := .T.
            IF cKey $ hByName[ cUp ]
               nOkT++
            ELSE
               cLine := AllTrim( hb_HGetDef( hScan[ "clean" ], nL, "" ) )
               IF Left( cLine, 1 ) == "#"
                  nAdj++                       // linha de diretiva
               ELSEIF Right( RTrim( hb_HGetDef( hScan[ "clean" ], nL, "" ) ), 1 ) == ";"
                  nAdj++                       // continuação: compilador vê na última linha
               ELSEIF nL $ hRewr
                  nAdj++                       // identificador consumido por regra de pp
               ELSEIF ! nL $ hAnyTok
                  nAdj++                       // statement inteiro consumido pela regra
                                               // (ex.: METHOD x() CLASS y sem parâmetros)
               ELSEIF Upper( hb_TokenGet( cLine, 1 ) ) $ "METHOD|ACCESS|ASSIGN|DATA|VAR|CLASSDATA" ;
                      .OR. " CLASS " $ Upper( cLine )
                  nAdj++                       // nomes consumidos pelo hbclass.ch
                                               // (colados em <Classe>_<Método>); a
                                               // fase B4/ppApplications os exporá
               ELSE
                  nBad++
                  OutStd( cSrc + ":" + hb_ntos( nL ) + ":" + hb_ntos( aHit[ 1 ] ) + ;
                          ": TS acha '" + cUp + "' e o AST não" + hb_eol() )
               ENDIF
            ENDIF
         NEXT
      NEXT

      // direção 2: posições do AST que o TokenScan não tem
      FOR EACH cKey IN hb_HKeys( hByName[ cUp ] )
         IF ! cKey $ hSeen
            hTok := hByName[ cUp ][ cKey ]
            nL := hTok[ "line" ]
            cLine := iif( nL >= 1 .AND. nL <= Len( aSrc ), aSrc[ nL ], "" )
            cPrev := ""
            FOR nI := hTok[ "col" ] TO 1 STEP -1     // col é 0-based: char anterior
               cPrev := SubStr( cLine, nI, 1 )
               IF ! cPrev == " "
                  EXIT
               ENDIF
            NEXT
            IF cPrev == ":" .OR. ( nI > 1 .AND. SubStr( cLine, nI - 1, 2 ) == "->" )
               nAdj++                          // send/alias: TS excluía por desenho
            ELSEIF cPrev == ">"
               // BUG do TokenScan arquivado, achado por esta porta: em
               // "x-- > y" ele enxerga '-'+'>' ATRAVÉS do espaço como seta
               // de alias e exclui o identificador; o AST está certo
               nAdj++
               OutStd( cSrc + ":" + hb_ntos( nL ) + ": adjudicada: bug do TS" + ;
                       " (falsa seta de alias através de espaço) - AST correto" + hb_eol() )
            ELSE
               nBad++
               OutStd( cSrc + ":" + hb_ntos( nL ) + ":" + hb_ntos( hTok[ "col" ] + 1 ) + ;
                       ": AST tem '" + cUp + "' e o TS não" + hb_eol() )
            ENDIF
         ENDIF
      NEXT
   NEXT

   RETURN

// === TokenScan da primeira encarnação (verbatim de smoketest/) ===
// ---------------------------------------------------------------------------
// source tokenizer: finds identifier occurrences of cName outside strings,
// comments, and outside ->field / :message contexts; also produces per-line
// source text stripped of comments (for the .ppo comparison)
// ---------------------------------------------------------------------------

STATIC FUNCTION TokenScan( cText, cName )

   LOCAL hHits := { => }, hClean := { => }, aStrHits := {}, aStrExact := {}, aStrIds := {}
   LOCAL cUp := Upper( cName )
   LOCAL nLen := hb_BLen( cText )
   LOCAL nAt := 1, nLine := 1, nCol := 1
   LOCAL cState := "code"            // code | dq | sq | br | lc | bc
   LOCAL cLineBuf := "", cStrBuf := "", cPrev1 := "", cPrev2 := ""
   LOCAL lLineStart := .T., nStrCol := 0
   LOCAL cCh, cNx, nStart, nColStart, cTok

   DO WHILE nAt <= nLen
      cCh := hb_BSubStr( cText, nAt, 1 )
      cNx := hb_BSubStr( cText, nAt + 1, 1 )

      IF cCh == Chr( 10 )
         IF ( cState == "dq" .OR. cState == "sq" .OR. cState == "br" ) .AND. cUp $ Upper( cStrBuf )
            AddLine( aStrHits, nLine )
         ENDIF
         hClean[ nLine ] := cLineBuf
         cLineBuf := ""
         cStrBuf := ""
         nLine++
         nCol := 1
         nAt++
         lLineStart := .T.
         cPrev1 := cPrev2 := ""
         IF cState == "lc" .OR. cState == "dq" .OR. cState == "sq" .OR. cState == "br"
            cState := "code"          // strings do not span lines in Harbour
         ENDIF
         LOOP
      ENDIF

      DO CASE
      CASE cState == "bc"
         IF cCh == "*" .AND. cNx == "/"
            cState := "code"
            nAt += 2 ; nCol += 2
         ELSE
            nAt++ ; nCol++
         ENDIF
         LOOP

      CASE cState == "lc"
         nAt++ ; nCol++
         LOOP

      CASE cState == "dq" .OR. cState == "sq" .OR. cState == "br"
         cLineBuf += cCh
         IF ( cState == "dq" .AND. cCh == '"' ) .OR. ;
            ( cState == "sq" .AND. cCh == "'" ) .OR. ;
            ( cState == "br" .AND. cCh == "]" )
            IF Upper( cStrBuf ) == cUp
               // string literal is EXACTLY the searched name: very likely
               // a call/reference by name (Do(), dispatch tables, macros)
               AAdd( aStrExact, { nLine, nStrCol, Len( cStrBuf ) } )
            ELSEIF cUp $ Upper( cStrBuf )
               AddLine( aStrHits, nLine )
            ENDIF
            IF IsValidIdent( cStrBuf )
               AAdd( aStrIds, { nLine, cStrBuf } )
            ENDIF
            cStrBuf := ""
            cState := "code"
         ELSE
            cStrBuf += cCh
         ENDIF
         nAt++ ; nCol++
         LOOP
      ENDCASE

      // --- code state ---
      DO CASE
      CASE cCh == "/" .AND. cNx == "/"
         cState := "lc"
         nAt += 2 ; nCol += 2
      CASE cCh == "&" .AND. cNx == "&"
         cState := "lc"
         nAt += 2 ; nCol += 2
      CASE cCh == "*" .AND. lLineStart
         cState := "lc"
         nAt++ ; nCol++
      CASE cCh == "/" .AND. cNx == "*"
         cState := "bc"
         nAt += 2 ; nCol += 2
      CASE cCh == '"'
         cState := "dq" ; nStrCol := nCol + 1 ; cLineBuf += cCh ; nAt++ ; nCol++
      CASE cCh == "'"
         cState := "sq" ; nStrCol := nCol + 1 ; cLineBuf += cCh ; nAt++ ; nCol++
      CASE cCh == "[" .AND. !( cPrev1 $ ")]}" ) .AND. ! IsIdChar( cPrev1 )
         cState := "br" ; nStrCol := nCol + 1 ; cLineBuf += cCh ; nAt++ ; nCol++
      CASE IsIdStart( cCh )
         nStart := nAt
         nColStart := nCol
         DO WHILE nAt <= nLen .AND. IsIdChar( hb_BSubStr( cText, nAt, 1 ) )
            nAt++ ; nCol++
         ENDDO
         cTok := hb_BSubStr( cText, nStart, nAt - nStart )
         cLineBuf += cTok
         IF Upper( cTok ) == cUp .AND. ;
            !( cPrev1 == ":" ) .AND. !( cPrev2 + cPrev1 == "->" )
            IF ! ( nLine $ hHits )
               hHits[ nLine ] := {}
            ENDIF
            AAdd( hHits[ nLine ], { nColStart, Len( cTok ) } )
         ENDIF
         cPrev2 := cPrev1
         cPrev1 := Right( cTok, 1 )
         lLineStart := .F.
         LOOP
      OTHERWISE
         cLineBuf += cCh
         IF !( cCh == " " ) .AND. !( cCh == Chr( 9 ) ) .AND. !( cCh == Chr( 13 ) )
            cPrev2 := cPrev1
            cPrev1 := cCh
            lLineStart := .F.
         ENDIF
         nAt++ ; nCol++
         LOOP
      ENDCASE

      IF !( cCh == " " ) .AND. !( cCh == Chr( 9 ) )
         lLineStart := .F.
      ENDIF
   ENDDO
   hClean[ nLine ] := cLineBuf

   RETURN { "hits" => hHits, "clean" => hClean, "strhits" => aStrHits, ;
            "strexact" => aStrExact, "strids" => aStrIds }

STATIC FUNCTION IsIdStart( cCh )
   RETURN ( cCh >= "A" .AND. cCh <= "Z" ) .OR. ( cCh >= "a" .AND. cCh <= "z" ) .OR. cCh == "_"

STATIC FUNCTION IsIdChar( cCh )
   RETURN IsIdStart( cCh ) .OR. ( cCh >= "0" .AND. cCh <= "9" )
STATIC PROCEDURE AddLine( aLines, nLine )

   IF nLine > 0 .AND. hb_AScan( aLines, nLine ) == 0
      AAdd( aLines, nLine )
   ENDIF

   RETURN
STATIC FUNCTION IsValidIdent( cName )

   LOCAL nI

   IF Empty( cName ) .OR. ! IsIdStart( Left( cName, 1 ) )
      RETURN .F.
   ENDIF
   FOR nI := 2 TO Len( cName )
      IF ! IsIdChar( SubStr( cName, nI, 1 ) )
         RETURN .F.
      ENDIF
   NEXT

   RETURN .T.
