// tcheck - asserts da suíte que eram heredocs python3 (B-infra Etapa 2)
//
// Cada subcomando espelha 1:1 o bloco python que substituiu; o nome leva a
// unidade dona. Contrato: exit 0/1 idêntico e as MESMAS saídas de sucesso
// assertadas pelo run.sh ("json ok", "consistente", "b4g-invariantes-ok").
// Na falha imprime o assert que quebrou (diagnóstico, não contrato).
//
// Toolchain única: JSON via hb_jsonDecode - nenhum python no make test.

PROCEDURE Main( cSub, cA1, cA2, cA3 )

   LOCAL lOk

   SWITCH hb_defaultValue( cSub, "" )
   CASE "locs18"  ; lOk := Locs18( cA1 )            ; EXIT
   CASE "absuri18"; lOk := AbsUri18( cA1 )          ; EXIT
   CASE "cols26"  ; lOk := Cols26( cA1 )            ; EXIT
   CASE "ppt42"   ; lOk := Ppt42( cA1, cA2 )        ; EXIT
   CASE "json62"  ; lOk := Json62( cA1 )            ; EXIT
   CASE "cons65"  ; lOk := Cons65( cA1 )            ; EXIT
   CASE "json66"  ; lOk := Json66( cA1, cA2 )       ; EXIT
   CASE "json70"  ; lOk := Json70( cA1 )            ; EXIT
   CASE "json72"  ; lOk := Json72( cA1 )            ; EXIT
   CASE "b4g82"   ; lOk := B4g82( cA1, cA2, cA3 )   ; EXIT
   CASE "pof83"   ; lOk := Pof83( cA1 )             ; EXIT
   OTHERWISE
      OutErr( "tcheck: subcomando desconhecido: " + hb_defaultValue( cSub, "(vazio)" ) + hb_eol() )
      lOk := .F.
   ENDSWITCH

   ErrorLevel( iif( lOk, 0, 1 ) )

   RETURN

STATIC FUNCTION Fail( cMsg )

   OutStd( "tcheck falhou: " + cMsg + hb_eol() )

   RETURN .F.

STATIC FUNCTION JLoad( cPath )
   RETURN hb_jsonDecode( hb_MemoRead( cPath ) )

STATIC FUNCTION EndsW( cText, cSuf )
   RETURN Right( cText, Len( cSuf ) ) == cSuf

// linhas 1-based (start.line do LSP é 0-based) de Location[] cujo uri
// termina no arquivo pedido
STATIC FUNCTION LocLines( aLocs, cFile )

   LOCAL hLoc, aLines := {}

   FOR EACH hLoc IN aLocs
      IF EndsW( hLoc[ "uri" ], cFile )
         AAdd( aLines, hLoc[ "range" ][ "start" ][ "line" ] + 1 )
      ENDIF
   NEXT

   RETURN aLines

// unidade 18: usages --json emite LSP Location[] com definição e chamada
STATIC FUNCTION Locs18( cJson )

   LOCAL aLocs := JLoad( cJson )
   LOCAL hLoc, lDef := .F., lCall := .F.

   IF ! HB_ISARRAY( aLocs ) .OR. Len( aLocs ) < 2
      RETURN Fail( "few locations" )
   ENDIF
   FOR EACH hLoc IN aLocs
      IF EndsW( hLoc[ "uri" ], "b.prg" ) .AND. hLoc[ "range" ][ "start" ][ "line" ] == 4
         lDef := .T.
      ENDIF
      IF EndsW( hLoc[ "uri" ], "a.prg" )
         lCall := .T.
      ENDIF
   NEXT
   IF ! lDef
      RETURN Fail( "definition loc" )
   ENDIF
   IF ! lCall
      RETURN Fail( "call loc" )
   ENDIF

   RETURN .T.

// unidade 18 (spec absoluto): o URI não pode duplicar o prefixo do cwd
STATIC FUNCTION AbsUri18( cJson )

   LOCAL aLocs := JLoad( cJson )
   LOCAL hLoc, cPath, lDef := .F.

   FOR EACH hLoc IN aLocs
      cPath := SubStr( hLoc[ "uri" ], Len( "file://" ) + 1 )
      IF "/absl" $ cPath
         RETURN Fail( "path prefix doubled: " + hLoc[ "uri" ] )
      ENDIF
      IF "/case18/case18" $ cPath
         RETURN Fail( "cwd doubled in uri: " + hLoc[ "uri" ] )
      ENDIF
      IF EndsW( hLoc[ "uri" ], "b.prg" )
         lDef := .T.
      ENDIF
   NEXT
   IF ! lDef
      RETURN Fail( "def loc present" )
   ENDIF

   RETURN .T.

// unidade 26: colunas reais nas Location[]
STATIC FUNCTION Cols26( cJson )

   LOCAL aLocs := JLoad( cJson )
   LOCAL hLoc, lReal := .F.

   FOR EACH hLoc IN aLocs
      IF hLoc[ "range" ][ "start" ][ "character" ] > 0
         lReal := .T.
      ENDIF
      IF hLoc[ "range" ][ "end" ][ "character" ] < hLoc[ "range" ][ "start" ][ "character" ]
         RETURN Fail( "end before start" )
      ENDIF
   NEXT
   IF ! lReal
      RETURN Fail( "no real column found" )
   ENDIF

   RETURN .T.

// unidade 42: ppApplications bate 1:1 com o trace do pp (.ppt) - contagem,
// ordem, linhas e kinds
STATIC FUNCTION Ppt42( cPpt, cAst )

   LOCAL cLine, aHit, nPend := -1
   LOCAL aTraces := {}, aApps := {}, hAst, hApp, xKind

   FOR EACH cLine IN hb_ATokens( StrTran( hb_MemoRead( cPpt ), Chr( 13 ), "" ), Chr( 10 ) )
      aHit := hb_regex( "^\S+\((\d+)\) >", cLine )
      IF ! Empty( aHit )
         nPend := Val( aHit[ 2 ] )
      ELSEIF hb_LeftEq( cLine, "#" ) .AND. nPend >= 0
         AAdd( aTraces, { nPend, AllTrim( hb_TokenGet( SubStr( cLine, 2 ), 1, ">" ) ) } )
         nPend := -1
      ENDIF
   NEXT

   hAst := JLoad( cAst )
   FOR EACH hApp IN hAst[ "ppApplications" ]
      // "rule" é índice 0-based na lista ppRules do dump
      xKind := hAst[ "ppRules" ][ hApp[ "rule" ] + 1 ][ "kind" ]
      AAdd( aApps, { hApp[ "line" ], xKind } )
   NEXT

   IF Len( aApps ) == 0 .OR. Len( aTraces ) != Len( aApps )
      RETURN Fail( "contagem: trace=" + hb_ntos( Len( aTraces ) ) + " apps=" + hb_ntos( Len( aApps ) ) )
   ENDIF
   FOR EACH aHit IN aTraces
      IF !( aApps[ aHit:__enumIndex() ][ 1 ] == aHit[ 1 ] ) .OR. ;
         !( aApps[ aHit:__enumIndex() ][ 2 ] == aHit[ 2 ] )
         RETURN Fail( "divergência na aplicação " + hb_ntos( aHit:__enumIndex() ) )
      ENDIF
   NEXT

   RETURN .T.

// unidade 62: excluded fora das Location[]; confirmed/possible dentro
STATIC FUNCTION Json62( cJson )

   LOCAL aLines := LocLines( JLoad( cJson ), "r1.prg" )

   // r1.prg:39/44 dentro, :40 fora (aqui em 1-based; o python usava 0-based)
   IF AScan( aLines, 39 ) == 0
      RETURN Fail( "confirmed g:Soma fora do json" )
   ENDIF
   IF AScan( aLines, 44 ) == 0
      RETURN Fail( "possible r:Soma fora do json" )
   ENDIF
   IF AScan( aLines, 40 ) > 0
      RETURN Fail( "excluded a:Soma vazou para o json" )
   ENDIF

   RETURN .T.

// unidade 65: invariantes do canal de tipos (ast-4+) sobre o dump real
STATIC FUNCTION Cons65( cDir )

   LOCAL hD1 := JLoad( hb_DirSepAdd( cDir ) + "r1.ast.json" )
   LOCAL hD2 := JLoad( hb_DirSepAdd( cDir ) + "r2.ast.json" )
   LOCAL hDump, cCls, hFunc, hDecl, aSelfs, hFuncs, hCen
   LOCAL aWrites, aRefs, aAssigns, hStmt, hExpr, hRhs, nPass

   IF hb_AScan( { "ast-4", "ast-5" }, hD1[ "schema" ] ) == 0 .OR. ;
      hb_AScan( { "ast-4", "ast-5" }, hD2[ "schema" ] ) == 0
      RETURN Fail( "schema" )
   ENDIF

   // Self tipado (S + classe) em toda função de método <CLASSE>_<MÉTODO>
   FOR nPass := 1 TO 2
      hDump := iif( nPass == 1, hD1, hD2 )
      cCls := iif( nPass == 1, "CAIXA", "SEMCTOR" )
      FOR EACH hFunc IN hDump[ "functions" ]
         IF hb_LeftEq( hFunc[ "name" ], cCls + "_" )
            aSelfs := {}
            FOR EACH hDecl IN hFunc[ "declarations" ]
               IF hDecl[ "sym" ] == "SELF"
                  AAdd( aSelfs, hDecl )
               ENDIF
            NEXT
            IF Empty( aSelfs ) .OR. ;
               ! hb_HGetDef( aSelfs[ 1 ], "type", "" ) == "S" .OR. ;
               ! Upper( hb_HGetDef( aSelfs[ 1 ], "class", "" ) ) == cCls
               RETURN Fail( "Self tipado em " + hFunc[ "name" ] )
            ENDIF
         ENDIF
      NEXT
   NEXT

   // declared de r1: função-classe auto-declarada + ctor com retorno declarado
   hFuncs := { => }
   FOR EACH hDecl IN hD1[ "declared" ][ "functions" ]
      hFuncs[ hDecl[ "name" ] ] := hDecl
   NEXT
   IF ! hb_HGetDef( hFuncs[ "CAIXA" ], "type", "" ) == "S" .OR. ;
      ! Upper( hb_HGetDef( hFuncs[ "CAIXA" ], "class", "" ) ) == "CAIXA"
      RETURN Fail( "declared CAIXA" )
   ENDIF
   IF ! hb_HGetDef( hFuncs[ "FABRICA" ], "type", "" ) == "S" .OR. ;
      ! Upper( hb_HGetDef( hFuncs[ "FABRICA" ], "class", "" ) ) == "CAIXA"
      RETURN Fail( "declared FABRICA" )
   ENDIF
   hDecl := DeclMethod( hD1, "CAIXA", "NEW" )
   IF HB_ISNIL( hDecl ) .OR. ! hb_HGetDef( hDecl, "type", "" ) == "S" .OR. ;
      ! Upper( hb_HGetDef( hDecl, "class", "" ) ) == "CAIXA"
      RETURN Fail( "declared CAIXA:NEW" )
   ENDIF

   // declared de r2: o DSL inventado declarou classe, maker e método
   hFuncs := { => }
   FOR EACH hDecl IN hD2[ "declared" ][ "functions" ]
      hFuncs[ hDecl[ "name" ] ] := hDecl
   NEXT
   IF ! Upper( hb_HGetDef( hFuncs[ "MAKEDUP" ], "class", "" ) ) == "DUPLICADOR"
      RETURN Fail( "declared MAKEDUP" )
   ENDIF
   hDecl := DeclMethod( hD2, "DUPLICADOR", "ESPELHO" )
   IF HB_ISNIL( hDecl ) .OR. ! Upper( hb_HGetDef( hDecl, "class", "" ) ) == "DUPLICADOR"
      RETURN Fail( "declared DUPLICADOR:ESPELHO" )
   ENDIF

   // re-derivação do binding único de G (o fato que o TypeOf consome):
   // exatamente 1 write em occurrences E exatamente 1 ASSIGN de topo
   hCen := NIL
   FOR EACH hFunc IN hD1[ "functions" ]
      IF hFunc[ "name" ] == "CENARIOS"
         hCen := hFunc
         EXIT
      ENDIF
   NEXT
   IF HB_ISNIL( hCen )
      RETURN Fail( "CENARIOS ausente" )
   ENDIF
   aWrites := OccOf( hCen, "G", "write" )
   aRefs := OccOf( hCen, "G", "ref" )
   aAssigns := {}
   FOR EACH hStmt IN hCen[ "statements" ]
      hExpr := hb_HGetDef( hStmt, "expr", NIL )
      IF HB_ISHASH( hExpr ) .AND. hb_HGetDef( hExpr, "et", "" ) == "ASSIGN" .AND. ;
         HB_ISHASH( hb_HGetDef( hExpr, "left", NIL ) ) .AND. ;
         hb_HGetDef( hExpr[ "left" ], "val", "" ) == "G"
         AAdd( aAssigns, hStmt )
      ENDIF
   NEXT
   IF ! ( Len( aWrites ) == 1 .AND. Len( aRefs ) == 0 .AND. Len( aAssigns ) == 1 )
      RETURN Fail( "binding único de G" )
   ENDIF
   hRhs := aAssigns[ 1 ][ "expr" ][ "right" ]
   IF ! ( hRhs[ "et" ] == "SEND" .AND. hRhs[ "msg" ] == "NEW" .AND. ;
          hRhs[ "obj" ][ "et" ] == "FUNCALL" )
      RETURN Fail( "rhs de G" )
   ENDIF
   // e o contraexemplo: M tem 2 writes (não classifica)
   IF Len( OccOf( hCen, "M", "write" ) ) != 2
      RETURN Fail( "writes de M" )
   ENDIF

   OutStd( "consistente" + hb_eol() )

   RETURN .T.

STATIC FUNCTION DeclMethod( hDump, cClass, cMethod )

   LOCAL hCls, hMth

   FOR EACH hCls IN hDump[ "declared" ][ "classes" ]
      IF hCls[ "name" ] == cClass
         FOR EACH hMth IN hCls[ "methods" ]
            IF hMth[ "name" ] == cMethod
               RETURN hMth
            ENDIF
         NEXT
      ENDIF
   NEXT

   RETURN NIL

STATIC FUNCTION OccOf( hFunc, cSym, cAccess )

   LOCAL hOcc, aHits := {}

   FOR EACH hOcc IN hFunc[ "occurrences" ]
      IF hOcc[ "sym" ] == cSym .AND. hOcc[ "access" ] == cAccess
         AAdd( aHits, hOcc )
      ENDIF
   NEXT

   RETURN aHits

// unidade 66: --json com confirmed dentro e excluded (ambos os sabores) fora
STATIC FUNCTION Json66( cJson, cPrg )

   LOCAL aSrc := hb_ATokens( StrTran( hb_MemoRead( cPrg ), Chr( 13 ), "" ), Chr( 10 ) )
   LOCAL nConf := AScan( aSrc, {| c | c == "   oM:Paint()" } )
   LOCAL nExcl := AScan( aSrc, {| c | c == "   oS:Paint()" } )
   LOCAL nProm := AScan( aSrc, {| c | c == "   oP:Paint()" } )
   LOCAL aLines := LocLines( JLoad( cJson ), "d1.prg" )

   IF nConf == 0 .OR. nExcl == 0 .OR. nProm == 0
      RETURN Fail( "site não encontrado em d1.prg" )
   ENDIF
   IF AScan( aLines, nConf ) == 0
      RETURN Fail( "confirmed sumiu do --json" )
   ENDIF
   IF AScan( aLines, nExcl ) > 0 .OR. AScan( aLines, nProm ) > 0
      RETURN Fail( "excluded vazou para o --json" )
   ENDIF
   OutStd( "json ok" + hb_eol() )

   RETURN .T.

// unidade 70: Location[] só com os sites da consultada
STATIC FUNCTION Json70( cJson )

   LOCAL aLines := LocLines( JLoad( cJson ), "d1.prg" )
   LOCAL nOther

   IF AScan( aLines, 13 ) == 0 .OR. AScan( aLines, 23 ) == 0
      RETURN Fail( "declaração/definição da consultada sumiu do --json" )
   ENDIF
   FOR EACH nOther IN { 31, 41, 47, 50, 56, 59 }
      IF AScan( aLines, nOther ) > 0
         RETURN Fail( "site homônimo " + hb_ntos( nOther ) + " vazou para o --json" )
      ENDIF
   NEXT
   OutStd( "json ok" + hb_eol() )

   RETURN .T.

// unidade 72: Location[] só com os 3 sites do dono consultado
STATIC FUNCTION Json72( cJson )

   LOCAL hLoc, aSites := {}

   FOR EACH hLoc IN JLoad( cJson )
      AAdd( aSites, { hb_TokenGet( hLoc[ "uri" ], hb_TokenCount( hLoc[ "uri" ], "/" ), "/" ), ;
                      hLoc[ "range" ][ "start" ][ "line" ] + 1 } )
   NEXT
   ASort( aSites,,, {| a, b | iif( a[ 1 ] == b[ 1 ], a[ 2 ] < b[ 2 ], a[ 1 ] < b[ 1 ] ) } )
   IF ! ( Len( aSites ) == 3 .AND. ;
          aSites[ 1 ][ 1 ] == "m1.prg" .AND. aSites[ 1 ][ 2 ] == 19 .AND. ;
          aSites[ 2 ][ 1 ] == "m1.prg" .AND. aSites[ 2 ][ 2 ] == 23 .AND. ;
          aSites[ 3 ][ 1 ] == "m1.prg" .AND. aSites[ 3 ][ 2 ] == 39 )
      RETURN Fail( "sites divergentes (" + hb_ntos( Len( aSites ) ) + " Locations)" )
   ENDIF
   OutStd( "json ok" + hb_eol() )

   RETURN .T.

// unidade 82: invariantes do ast-5 (a regra POR DENTRO) sobre o dump real
STATIC FUNCTION B4g82( cAstA, cAstB, cDir )

   LOCAL hA := JLoad( cAstA ), hB := JLoad( cAstB )
   LOCAL hDump, hRule, hTok, cSide, cFile, hSrcs, cLine
   LOCAL nByteOk := 0, nPass, hRules, hFj, aLines, hMk, cText
   LOCAL lStd := .F., lSmart := .F., hKinds, aAlts, aTp, aTexts
   LOCAL nOpens, nCloses, aPr, aWant, hCunho, nAt

   IF !( hA[ "schema" ] == "ast-5" ) .OR. !( hB[ "schema" ] == "ast-5" )
      RETURN Fail( "schema ast-5" )
   ENDIF

   // 1. byte-exato: todo token posicionado de match[]/result[] soletra o
   //    texto no arquivo da regra (col emitida também para include)
   FOR nPass := 1 TO 2
      hDump := iif( nPass == 1, hA, hB )
      hSrcs := { => }
      FOR EACH hRule IN hDump[ "ppRules" ]
         cFile := hb_HGetDef( hRule, "file", NIL )
         FOR EACH cSide IN { "match", "result" }
            FOR EACH hTok IN hb_HGetDef( hRule, cSide, {} )
               IF HB_ISNIL( cFile ) .OR. !( "text" $ hTok ) .OR. HB_ISNIL( hb_HGetDef( hTok, "col", NIL ) )
                  LOOP
               ENDIF
               IF !( cFile $ hSrcs )
                  hSrcs[ cFile ] := hb_ATokens( hb_MemoRead( hb_DirSepAdd( cDir ) + cFile ), Chr( 10 ) )
               ENDIF
               cLine := hSrcs[ cFile ][ hTok[ "line" ] ]
               IF ! SubStr( cLine, hTok[ "col" ] + 1, hTok[ "len" ] ) == hTok[ "text" ]
                  RETURN Fail( "byte-exato: " + cFile + ":" + hb_ntos( hTok[ "line" ] ) + " " + hTok[ "text" ] )
               ENDIF
               nByteOk++
            NEXT
         NEXT
      NEXT
   NEXT
   IF nByteOk <= 60
      RETURN Fail( "poucos tokens byte-exatos: " + hb_ntos( nByteOk ) )
   ENDIF

   hRules := { => }
   FOR EACH hRule IN hA[ "ppRules" ]
      IF hb_HGetDef( hRule, "file", "" ) == "forja.ch"
         hRules[ hb_HGetDef( hRule, "head", "" ) ] := hRule
      ENDIF
   NEXT
   hFj := hRules[ "FORJA" ]

   // 2. diretiva continuada (P3): a regra registra a ÚLTIMA linha física,
   //    mas a cabeça é match[1] com linha/coluna físicas reais
   IF !( hFj[ "line" ] == 15 .AND. hFj[ "match" ][ 1 ][ "text" ] == "FORJA" )
      RETURN Fail( "P3: linha da regra/cabeça" )
   ENDIF
   IF !( hFj[ "match" ][ 1 ][ "line" ] == 12 .AND. hFj[ "match" ][ 1 ][ "col" ] == 10 )
      RETURN Fail( "P3: posição física da cabeça" )
   ENDIF
   aLines := {}
   FOR EACH hTok IN hFj[ "match" ]
      IF "line" $ hTok .AND. ! Empty( hTok[ "line" ] )
         AAdd( aLines, hTok[ "line" ] )
      ENDIF
   NEXT
   aWant := { 12, 12, 12, 12, 13, 13, 14, 14, 14, 14, 14 }
   IF Len( aLines ) != Len( aWant )
      RETURN Fail( "P3: linhas físicas do match (contagem)" )
   ENDIF
   FOR nAt := 1 TO Len( aWant )
      IF !( aLines[ nAt ] == aWant[ nAt ] )
         RETURN Fail( "P3: linhas físicas do match (posição " + hb_ntos( nAt ) + ")" )
      ENDIF
   NEXT

   // 3. papéis e mkinds: o vocabulário do próprio pp
   hMk := { => }
   FOR EACH hTok IN hFj[ "match" ]
      IF hb_HGetDef( hTok, "role", "" ) == "marker"
         hMk[ hTok[ "text" ] ] := hTok[ "mkind" ]
      ENDIF
   NEXT
   IF ! ( Len( hMk ) == 4 .AND. ;
          hb_HGetDef( hMk, "oIt", "" ) == "regular" .AND. ;
          hb_HGetDef( hMk, "nTam", "" ) == "regular" .AND. ;
          hb_HGetDef( hMk, "modo", "" ) == "restrict" .AND. ;
          hb_HGetDef( hMk, "cRot", "" ) == "regular" )
      RETURN Fail( "mkinds do match" )
   ENDIF
   FOR EACH hTok IN hFj[ "result" ]
      IF hb_HGetDef( hTok, "role", "" ) == "marker"
         cText := hTok[ "text" ]
         IF cText == "modo" .AND. hTok[ "mkind" ] == "strstd"
            lStd := .T.
         ENDIF
         IF cText == "cRot" .AND. hTok[ "mkind" ] == "strsmart"
            lSmart := .T.
         ENDIF
      ENDIF
   NEXT
   IF ! ( lStd .AND. lSmart )
      RETURN Fail( "mkinds do result (strstd/strsmart)" )
   ENDIF
   hKinds := { => }
   FOR EACH hRule IN hRules
      FOR EACH hTok IN hRule[ "match" ]
         IF hb_HGetDef( hTok, "role", "" ) == "marker"
            hKinds[ hTok[ "mkind" ] ] := .T.
         ENDIF
      NEXT
   NEXT
   FOR EACH cText IN { "regular", "list", "restrict", "wild", "extexp", "name" }
      IF !( cText $ hKinds )
         RETURN Fail( "mkind ausente: " + cText )
      ENDIF
   NEXT

   // 4. restrição com posição própria (renomeável) e marker do dono
   aAlts := {}
   FOR EACH hTok IN hFj[ "match" ]
      IF hb_HGetDef( hTok, "role", "" ) == "restrict" .AND. ! HB_ISNIL( hb_HGetDef( hTok, "col", NIL ) )
         AAdd( aAlts, { hTok[ "text" ], hTok[ "marker" ], hTok[ "line" ], hTok[ "col" ] } )
      ENDIF
   NEXT
   IF ! ( Len( aAlts ) == 2 .AND. ;
          aAlts[ 1 ][ 1 ] == "RAPIDO" .AND. aAlts[ 1 ][ 2 ] == 3 .AND. aAlts[ 1 ][ 3 ] == 14 .AND. aAlts[ 1 ][ 4 ] == 18 .AND. ;
          aAlts[ 2 ][ 1 ] == "LENTO" .AND. aAlts[ 2 ][ 2 ] == 3 .AND. aAlts[ 2 ][ 3 ] == 14 .AND. aAlts[ 2 ][ 4 ] == 26 )
      RETURN Fail( "restrições posicionadas" )
   ENDIF

   // 5. opcionais consecutivos REORDENADOS no registro (fato 12): o grupo
   //    com keyword (GRAU) fica ANTES do sem keyword no match ARMAZENADO
   aTp := hRules[ "TEMPERA" ][ "match" ]
   aTexts := {}
   FOR EACH hTok IN aTp
      AAdd( aTexts, hb_HGetDef( hTok, "text", NIL ) )
   NEXT
   IF ! ( AScan( aTexts, {| c | HB_ISSTRING( c ) .AND. c == "GRAU" } ) < ;
          AScan( aTexts, {| c | HB_ISSTRING( c ) .AND. c == "n" } ) )
      RETURN Fail( "reordenação dos opcionais (GRAU antes de n)" )
   ENDIF
   nOpens := 0
   nCloses := 0
   FOR EACH hTok IN aTp
      IF hb_HGetDef( hTok, "role", "" ) == "opt-open"
         nOpens++
      ELSEIF hb_HGetDef( hTok, "role", "" ) == "opt-close"
         nCloses++
      ENDIF
   NEXT
   IF ! ( nOpens == 2 .AND. nCloses == 2 )
      RETURN Fail( "pares opt-open/close do TEMPERA" )
   ENDIF

   // 6. opcional ANINHADO no match (critério 2): o achatamento recursa -
   //    pares opt-open/close reconstroem a árvore por pilha
   aPr := {}
   FOR EACH hTok IN hRules[ "PRENSA" ][ "match" ]
      AAdd( aPr, { hb_HGetDef( hTok, "role", "" ), hb_HGetDef( hTok, "text", NIL ) } )
   NEXT
   aWant := { { "literal", "PRENSA" }, { "marker", "p" }, { "opt-open", NIL }, ;
              { "literal", "COM" }, { "marker", "f" }, { "opt-open", NIL }, ;
              { "literal", "EM" }, { "marker", "t" }, { "opt-close", NIL }, ;
              { "opt-close", NIL } }
   IF Len( aPr ) != Len( aWant )
      RETURN Fail( "opcional aninhado do PRENSA (contagem)" )
   ENDIF
   FOR nAt := 1 TO Len( aWant )
      IF !( aPr[ nAt ][ 1 ] == aWant[ nAt ][ 1 ] ) .OR. ;
         ! ( ( HB_ISNIL( aPr[ nAt ][ 2 ] ) .AND. HB_ISNIL( aWant[ nAt ][ 2 ] ) ) .OR. ;
             ( HB_ISSTRING( aPr[ nAt ][ 2 ] ) .AND. HB_ISSTRING( aWant[ nAt ][ 2 ] ) .AND. ;
               aPr[ nAt ][ 2 ] == aWant[ nAt ][ 2 ] ) )
         RETURN Fail( "opcional aninhado do PRENSA (elemento " + hb_ntos( nAt ) + ")" )
      ENDIF
   NEXT

   // 7. P5 (fato 13): regra nascida de expansão tem posições REAIS - a
   //    cabeça da regra interna aponta para DENTRO do result da diretiva-mãe
   hCunho := NIL
   FOR EACH hRule IN hB[ "ppRules" ]
      IF hb_HGetDef( hRule, "head", "" ) == "CUNHO"
         hCunho := hRule
         EXIT
      ENDIF
   NEXT
   IF HB_ISNIL( hCunho )
      RETURN Fail( "P5: regra CUNHO ausente" )
   ENDIF
   IF !( hCunho[ "file" ] == "molde.prg" .AND. hCunho[ "line" ] == 15 )
      RETURN Fail( "P5: site da aplicação" )
   ENDIF
   IF !( hCunho[ "match" ][ 1 ][ "line" ] == 6 .AND. hCunho[ "match" ][ 1 ][ "col" ] == 37 )
      RETURN Fail( "P5: cabeça aponta para dentro do result da mãe" )
   ENDIF
   IF !( hCunho[ "match" ][ 2 ][ "text" ] == "Ferro" .AND. hCunho[ "match" ][ 2 ][ "line" ] == 15 )
      RETURN Fail( "P5: recheio do marker externo no site de uso" )
   ENDIF

   OutStd( "b4g-invariantes-ok" + hb_eol() )

   RETURN .T.

// unidade 83: projects-of --json emite o array de donos que a extensão
// decodifica (JSON.parse) para filtrar o picker de projeto - o assert
// prova o round-trip pelo decodificador, não só a forma textual
STATIC FUNCTION Pof83( cJson )

   LOCAL xVal := JLoad( cJson )

   IF ! HB_ISARRAY( xVal )
      RETURN Fail( "pof83: não é array JSON" )
   ENDIF
   IF Len( xVal ) != 2
      RETURN Fail( "pof83: esperava 2 donos, veio " + hb_ntos( Len( xVal ) ) )
   ENDIF
   IF !( xVal[ 1 ] == "p1.hbp" .AND. xVal[ 2 ] == "p2.hbp" )
      RETURN Fail( "pof83: donos errados: " + hb_jsonEncode( xVal ) )
   ENDIF
   OutStd( "json ok" + hb_eol() )

   RETURN .T.
