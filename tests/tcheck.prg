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
   CASE "pof102"  ; lOk := Pof102( cA1 )            ; EXIT
   CASE "rtr101"  ; lOk := Rtr101( cA1 )            ; EXIT
   CASE "enveq"   ; lOk := EnvEq( cA1, cA2, cA3 )   ; EXIT
   CASE "envhas"  ; lOk := EnvHas( cA1, cA2, cA3 )  ; EXIT
   CASE "envloc"  ; lOk := EnvLoc( cA1, cA2, cA3 )  ; EXIT
   CASE "envrow"  ; lOk := EnvRow( cA1, cA2, cA3 )  ; EXIT
   CASE "scen"    ; lOk := Scen( cA1, cA2 )         ; EXIT
   CASE "scenlint"; lOk := ScenLint( cA1 )          ; EXIT
   CASE "cmdcount"; lOk := CmdCount( cA1 )          ; EXIT
   CASE "cmdargs" ; lOk := CmdArgs( cA1, cA2 )      ; EXIT
   OTHERWISE
      OutErr( "tcheck: subcomando desconhecido: " + hb_defaultValue( cSub, "(vazio)" ) + hb_eol() )
      lOk := .F.
   ENDSWITCH

   ErrorLevel( iif( lOk, 0, 1 ) )

   RETURN

STATIC FUNCTION Fail( cMsg )

   OutStd( "tcheck falhou: " + cMsg + hb_eol() )

   RETURN .F.

// ---------------------------------------------------------------------------
#define CLI_SCHEMA "cli-2"   // acompanha o CLI_SCHEMA de src/hbrefactor.prg

// A.1 passo 2 - asserção GENÉRICA sobre o envelope. Migra o grep de
// prosa para o FATO estruturado: em vez de casar a frase na saída (que o passo
// 3 deleta), navega o campo por dot-path e compara. `result.` é implícito -
// `verdict` = `result.verdict` (o consumidor fala da carga, não do envelope).
// ---------------------------------------------------------------------------

// navega o dot-path num envelope lido de arquivo. Sem prefixo explícito
// (schema/command/status/reason/action/detail/diagnostics/edits), o path é
// relativo a `result` - onde vive quase todo o fato
STATIC FUNCTION EnvNav( cPath, cDot )

   STATIC s_aTop := { "schema", "command", "argv", "status", "exit", "reason", "action", ;
                      "detail", "diagnostics", "result", "edits" }
   LOCAL x := hb_jsonDecode( hb_MemoRead( cPath ) )
   LOCAL aKeys := hb_ATokens( cDot, "." ), cKey, nI

   IF ! HB_ISHASH( x )
      RETURN NIL
   ENDIF
   IF ! Empty( aKeys ) .AND. hb_AScan( s_aTop, aKeys[ 1 ],,, .T. ) == 0
      x := hb_HGetDef( x, "result", { => } )   // path relativo à carga
   ENDIF
   FOR nI := 1 TO Len( aKeys )
      cKey := aKeys[ nI ]
      IF HB_ISHASH( x ) .AND. hb_HHasKey( x, cKey )
         x := x[ cKey ]
      ELSEIF HB_ISARRAY( x ) .AND. Val( cKey ) >= 1 .AND. Val( cKey ) <= Len( x )
         x := x[ Val( cKey ) ]
      ELSE
         RETURN NIL
      ENDIF
   NEXT

   RETURN x

// stringifica um escalar do envelope para comparar
STATIC FUNCTION EnvStr( x )
   DO CASE
   CASE x == NIL          ; RETURN "(nil)"
   CASE HB_ISCHAR( x )    ; RETURN x
   CASE HB_ISNUMERIC( x ) ; RETURN hb_ntos( x )
   CASE HB_ISLOGICAL( x ) ; RETURN iif( x, "true", "false" )
   ENDCASE
   RETURN hb_jsonEncode( x )

// campo == valor exato
STATIC FUNCTION EnvEq( cPath, cDot, cVal )

   LOCAL cGot := EnvStr( EnvNav( cPath, cDot ) )

   IF cGot == hb_defaultValue( cVal, "" )
      RETURN .T.
   ENDIF

   RETURN Fail( cDot + " = " + cGot + " (esperado: " + hb_defaultValue( cVal, "" ) + ")" )

// campo CONTÉM substring (o campo pode ser escalar ou estrutura - stringifica)
STATIC FUNCTION EnvHas( cPath, cDot, cSub )

   LOCAL cGot := EnvStr( EnvNav( cPath, cDot ) )

   IF hb_defaultValue( cSub, "" ) $ cGot
      RETURN .T.
   ENDIF

   RETURN Fail( cDot + " nao contem '" + hb_defaultValue( cSub, "" ) + "' (tem: " + cGot + ")" )

// existe uma location (result.locations OU edits[]) em <arquivo:linha>? A linha
// é 1-based (o LSP é 0-based). Prova o que o grep "arquivo:linha: papel" dava,
// mas pelo FATO estruturado (uri + range + kind + owner), não pela frase.
// O 3o arg espelha a prosa do usages: "<kind> in <owner>" -> separa e confere
// os DOIS campos; sem " in ", casa só o kind (definição não tem owner).
STATIC FUNCTION EnvLoc( cPath, cAt, cWhat )

   LOCAL x := hb_jsonDecode( hb_MemoRead( cPath ) )
   LOCAL aLoc, hLoc, nColon, cFile, nLine, cKind, cOwner := NIL, nIn

   IF ! HB_ISHASH( x )
      RETURN Fail( "envelope invalido" )
   ENDIF
   aLoc := hb_HGetDef( hb_HGetDef( x, "result", { => } ), "locations", NIL )
   IF aLoc == NIL
      aLoc := hb_HGetDef( x, "edits", {} )
   ENDIF
   nColon := RAt( ":", cAt )
   cFile := Left( cAt, nColon - 1 )
   nLine := Val( SubStr( cAt, nColon + 1 ) )

   cKind := hb_defaultValue( cWhat, "" )
   IF ( nIn := RAt( " in ", cKind ) ) > 0
      cOwner := SubStr( cKind, nIn + 4 )
      cKind  := Left( cKind, nIn - 1 )
   ENDIF

   FOR EACH hLoc IN aLoc
      IF EndsW( hLoc[ "uri" ], cFile ) .AND. ;
         hLoc[ "range" ][ "start" ][ "line" ] + 1 == nLine .AND. ;
         ( Empty( cKind ) .OR. cKind $ hb_HGetDef( hLoc, "kind", "" ) ) .AND. ;
         ( cOwner == NIL .OR. cOwner == EnvStr( hb_HGetDef( hLoc, "owner", NIL ) ) )
         RETURN .T.
      ENDIF
   NEXT

   RETURN Fail( "nenhuma location em " + cAt + ;
                iif( Empty( cKind ), "", " com kind ~ '" + cKind + "'" ) + ;
                iif( cOwner == NIL, "", " owner '" + cOwner + "'" ) )

// alguma LINHA de um array-de-objetos do result casa TODOS os pares k=v?
// (`result.<arr>` implícito). Genérico: serve call-graph (edges), find-
// dynamic-calls (findings), annotate (candidates), location sem linha, etc.
// Valor casado por SUBSTRING (external=true, in=b.prg, kind=write (memvar)).
// Pares separados por ';'.  Ex: envrow cg.json edges "caller=MAIN;callee=DUPLA;in=b.prg"
STATIC FUNCTION EnvRow( cPath, cArr, cSpec )

   LOCAL x := hb_jsonDecode( hb_MemoRead( cPath ) )
   LOCAL aRows, hRow, cPair, nEq, cK, cV, lAll

   IF HB_ISHASH( x ) .AND. hb_HGetDef( x, "schema", "" ) == CLI_SCHEMA
      x := hb_HGetDef( x, "result", { => } )
   ENDIF
   aRows := iif( HB_ISHASH( x ), hb_HGetDef( x, hb_defaultValue( cArr, "" ), {} ), {} )
   IF ! HB_ISARRAY( aRows )
      RETURN Fail( "result." + hb_defaultValue( cArr, "" ) + " nao e' array" )
   ENDIF

   FOR EACH hRow IN aRows
      IF ! HB_ISHASH( hRow )
         LOOP
      ENDIF
      lAll := .T.
      FOR EACH cPair IN hb_ATokens( hb_defaultValue( cSpec, "" ), ";" )
         nEq := At( "=", cPair )
         cK  := Left( cPair, nEq - 1 )
         cV  := SubStr( cPair, nEq + 1 )
         IF ! ( cV $ EnvStr( hb_HGetDef( hRow, cK, NIL ) ) )
            lAll := .F.
            EXIT
         ENDIF
      NEXT
      IF lAll
         RETURN .T.
      ENDIF
   NEXT

   RETURN Fail( "nenhuma linha em result." + hb_defaultValue( cArr, "" ) + " casa: " + ;
                hb_defaultValue( cSpec, "" ) )

// A.1: o `--json` passou a emitir UM ENVELOPE em stdout (a forma
// `--json <arquivo>` morreu - CLAUDE.md §1.5, sem compatibilidade para trás).
// O desembrulho fica AQUI, num ponto só: os assertos abaixo continuam falando
// da carga (Location[], {owners,candidates}), que é o que eles de fato provam.
STATIC FUNCTION JLoad( cPath )

   LOCAL xJson := hb_jsonDecode( hb_MemoRead( cPath ) )

   IF HB_ISHASH( xJson ) .AND. hb_HGetDef( xJson, "schema", "" ) == CLI_SCHEMA
      xJson := hb_HGetDef( xJson, "result", { => } )
      IF HB_ISHASH( xJson ) .AND. hb_HHasKey( xJson, "locations" )
         xJson := xJson[ "locations" ]
      ENDIF
   ENDIF

   RETURN xJson

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

   IF ! AstAtLeast( hD1, 4 ) .OR. ! AstAtLeast( hD2, 4 )
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

// unidade 66: --json com confirmed dentro e excluded (por FATO de parentesco,
// RE.6) fora. oS (UWSecondary own-hit) e oP (declarado, is-a imposto) NÃO são
// referências de UWMain:Paint - despacham para UWSECONDARY:PAINT
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
      RETURN Fail( "excluded (RE.6) vazou para o --json" )
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

// unidade 72: Location[] com os sites do dono consultado (decl 19, def 23,
// send próprio 39). Os sends homônimos oF(38)/oI(41) saem por EXCLUSÃO de
// FATO (RE.6, own-hit de FAROL/IDOLO) - a generalidade vale para DSL
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

   IF ! AstAtLeast( hA, 5 ) .OR. ! AstAtLeast( hB, 5 )
      RETURN Fail( "schema ast-5+" )
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

// unidade 102: modo DESCOBERTA do projects-of - o JSON é um OBJETO
// { owners, candidates }, não mais um array. owners = donos por FATO
// (proj.hbp, proj2.hbp) ordenados por proximidade; candidates = tudo
// descoberto com o mais PRÓXIMO no topo (o decoy em sub/ vem antes dos
// projetos da raiz, provando que a proximidade ordena a apresentação)
STATIC FUNCTION Pof102( cJson )

   LOCAL xVal := JLoad( cJson ), aOwn, aCand

   IF ! HB_ISHASH( xVal )
      RETURN Fail( "pof102: não é objeto JSON { owners, candidates }" )
   ENDIF
   aOwn := hb_HGetDef( xVal, "owners", NIL )
   aCand := hb_HGetDef( xVal, "candidates", NIL )
   IF ! HB_ISARRAY( aOwn ) .OR. ! HB_ISARRAY( aCand )
      RETURN Fail( "pof102: owners/candidates ausentes ou não-array" )
   ENDIF
   IF Len( aOwn ) != 2
      RETURN Fail( "pof102: esperava 2 donos, veio " + hb_ntos( Len( aOwn ) ) )
   ENDIF
   IF !( EndsW( aOwn[ 1 ], "proj.hbp" ) .AND. EndsW( aOwn[ 2 ], "proj2.hbp" ) )
      RETURN Fail( "pof102: donos/ordem errados: " + hb_jsonEncode( aOwn ) )
   ENDIF
   IF Len( aCand ) < 1 .OR. ! EndsW( aCand[ 1 ], "decoy.hbp" )
      RETURN Fail( "pof102: candidato mais próximo (decoy) não veio no topo: " + ;
                   hb_jsonEncode( aCand ) )
   ENDIF
   OutStd( "json ok" + hb_eol() )

   RETURN .T.

// unidade 101: conteúdo PROFUNDO do retrato rtr-1 do exec-registry (B9
// fatia 4) - proveniência por chamada, seletores com tipo (INLINE=3,
// self-cast SUPER=5 - o padrão do cls*cast), failed/ran/skipped honestos
// e a VM (baseline por nome: programa vazio = só ERROR) separada
STATIC FUNCTION Rtr101( cJson )

   LOCAL hSnap := JLoad( cJson ), hCls, hBronze, hForno, aSel

   IF ! HB_ISHASH( hSnap )
      RETURN Fail( "rtr101: json inválido" )
   ENDIF
   IF !( hb_HGetDef( hSnap, "schema", "" ) == "rtr-1" )
      RETURN Fail( "rtr101: schema rtr-1" )
   ENDIF
   IF !( hSnap[ "stamp" ] == "fixo" )
      RETURN Fail( "rtr101: carimbo vem de FORA (determinismo)" )
   ENDIF
   IF !( Len( hSnap[ "vm" ] ) == 1 .AND. hSnap[ "vm" ][ 1 ] == "ERROR" )
      RETURN Fail( "rtr101: VM (baseline ERROR) não separada" )
   ENDIF
   IF !( Len( hSnap[ "classes" ] ) == 3 .AND. ;
         hSnap[ "classes" ][ 1 ][ "name" ] == "FORNO_BASE" .AND. ;
         hSnap[ "classes" ][ 2 ][ "name" ] == "METAL_ACO" .AND. ;
         hSnap[ "classes" ][ 3 ][ "name" ] == "METAL_BRONZE" )
      RETURN Fail( "rtr101: classes[] fora da ordem/conteúdo esperado" )
   ENDIF
   hForno := hSnap[ "classes" ][ 1 ]
   hBronze := hSnap[ "classes" ][ 3 ]
   IF !( hForno[ "from" ] == "startup" )
      RETURN Fail( "rtr101: FORNO_BASE sem proveniência startup" )
   ENDIF
   IF !( hBronze[ "from" ] == "FORJA_BRONZE" )
      RETURN Fail( "rtr101: METAL_BRONZE sem proveniência da chamada" )
   ENDIF
   IF ! Empty( hBronze[ "parents" ] )
      RETURN Fail( "rtr101: METAL_BRONZE com pais inesperados" )
   ENDIF
   aSel := hBronze[ "sels" ]
   IF !( Len( aSel ) == 3 .AND. ;
         aSel[ 1 ][ "name" ] == "FUNDE" .AND. aSel[ 1 ][ "type" ] == 3 .AND. ;
         aSel[ 2 ][ "name" ] == "METAL_BRONZE" .AND. aSel[ 2 ][ "type" ] == 5 .AND. ;
         aSel[ 3 ][ "name" ] == "VERGA" .AND. aSel[ 3 ][ "type" ] == 3 )
      RETURN Fail( "rtr101: seletores de METAL_BRONZE (INLINE=3 + self-cast SUPER=5): " + ;
                   hb_jsonEncode( aSel ) )
   ENDIF
   IF !( Len( hSnap[ "ran" ] ) == 2 .AND. Len( hSnap[ "failed" ] ) == 1 .AND. ;
         hSnap[ "failed" ][ 1 ] == "MONTAMETAL" .AND. Empty( hSnap[ "skipped" ] ) )
      RETURN Fail( "rtr101: ran/failed/skipped fora do esperado" )
   ENDIF
   FOR EACH hCls IN hSnap[ "classes" ]
      IF hCls:__enumIndex() > 1 .AND. ;
         hSnap[ "classes" ][ hCls:__enumIndex() - 1 ][ "name" ] > hCls[ "name" ]
         RETURN Fail( "rtr101: classes[] fora de ordem (determinismo)" )
      ENDIF
   NEXT
   OutStd( "json ok" + hb_eol() )

   RETURN .T.

// portão por VERSÃO MÍNIMA do schema ("ast-N", N >= nMin) - a lista
// enumerada morria em silêncio a cada bump (lição do ast-8/RE.5)
STATIC FUNCTION AstAtLeast( hAst, nMin )
   LOCAL cSchema := hb_HGetDef( hAst, "schema", "" )
   RETURN hb_LeftEq( cSchema, "ast-" ) .AND. Val( SubStr( cSchema, 5 ) ) >= nMin

// ---------------------------------------------------------------------------
// `scen` - o arquivo `case.json` de um CENÁRIO (tests/scenarios.sh), lido e
// VALIDADO (Diego, 2026-07-26: *"o case deve usar json também para garantir
// estrutura, com schema e versão do schema"*).
//
// A validação é o produto aqui, não a leitura: sem ela, uma chave com erro de
// digitação (`exitt`) é ignorada em SILÊNCIO e o cenário passa provando outra
// coisa - a mesma vacuidade que o formato existe para matar. Por isso:
//   - `schema` ausente ou diferente do corrente RECUSA, nomeando as duas
//     versões (a lei §1.5: schema é EXATO, e divergência BERRA);
//   - chave DESCONHECIDA recusa (é typo ou é campo que este runner não honra);
//   - chave obrigatória ausente recusa;
//   - tipo errado recusa (`exit` texto, `creates` que não é lista).
//
// Uso:  tcheck scen <case.json>          valida e cala
//       tcheck scen <case.json> <chave>  valida e ecoa a chave (vazio se não há)
// ---------------------------------------------------------------------------
#define CASE_SCHEMA "case-1"

STATIC FUNCTION Scen( cPath, cKey )

   // REGRA DO SCHEMA: uma chave só entra aqui quando o runner a HONRA. Chave
   // aceita e ignorada seria pior que chave desconhecida - o caso a declara,
   // acha que provou, e ninguém confere. (Por isso `kind` só aceita "command"
   // hoje: `oracle` e `harness` entram junto com o código que os executa.)
   STATIC s_aKnown := { "schema", "kind", "desc", "cmd", "creates", "forbid" }
   STATIC s_aReq   := { "schema", "kind", "desc" }
   STATIC s_aKinds := { "command" }
   STATIC s_aLists := { "creates", "forbid" }
   LOCAL cRaw := hb_MemoRead( hb_defaultValue( cPath, "" ) )
   LOCAL x, cK, cSchema, xVal, cOut, xI, xJ

   IF Len( cRaw ) == 0
      RETURN Fail( "scen: " + hb_defaultValue( cPath, "(sem arquivo)" ) + " vazio ou inexistente" )
   ENDIF
   // a forma de 2 args devolve os BYTES consumidos - 0 é JSON inválido. A de
   // 1 arg devolve hash vazio para texto quebrado, e o diagnóstico saía
   // "sem schema", mandando quem lê caçar a coisa errada
   IF hb_jsonDecode( cRaw, @x ) == 0 .OR. ! HB_ISHASH( x )
      RETURN Fail( "scen: " + cPath + " não é JSON válido (esperado um objeto)" )
   ENDIF
   cSchema := hb_HGetDef( x, "schema", NIL )
   IF cSchema == NIL
      RETURN Fail( "scen: " + cPath + " sem `schema` (esperado " + CASE_SCHEMA + ")" )
   ENDIF
   IF !( cSchema == CASE_SCHEMA )
      RETURN Fail( "scen: schema " + hb_jsonEncode( cSchema ) + " != " + CASE_SCHEMA + ;
                   " (o cenário e o runner estão fora de passo - " + cPath + ")" )
   ENDIF
   FOR EACH cK IN hb_HKeys( x )
      IF hb_AScan( s_aKnown, cK,,, .T. ) == 0
         RETURN Fail( "scen: chave desconhecida `" + cK + "` em " + cPath + ;
                      " (conhecidas: " + ArrJoin( s_aKnown ) + ")" )
      ENDIF
   NEXT
   FOR EACH cK IN s_aReq
      IF ! hb_HHasKey( x, cK ) .OR. ! HB_ISCHAR( x[ cK ] ) .OR. Len( x[ cK ] ) == 0
         RETURN Fail( "scen: `" + cK + "` ausente ou vazio em " + cPath )
      ENDIF
   NEXT
   IF hb_AScan( s_aKinds, x[ "kind" ],,, .T. ) == 0
      RETURN Fail( "scen: kind " + hb_jsonEncode( x[ "kind" ] ) + " não é honrado por este " + ;
                   "runner (honrados: " + ArrJoin( s_aKinds ) + ") - " + cPath )
   ENDIF
   // `cmd` é uma LISTA DE ARGV - uma lista de argumentos por comando, na ordem.
   // A mesma forma do campo `argv` do envelope (Diego, 2026-07-26: *"se o cmd no
   // case.json é em um formato, por que o do output está em outro?"* - a
   // invocação é UM fato, e representá-la de dois jeitos obriga quem lê o
   // cenário a traduzir de cabeça). Ganho concreto além da simetria: o runner
   // executa os argumentos DIRETO, sem `eval` - argumento com espaço ou aspas
   // deixa de ser uma bomba armada.
   IF ! hb_HHasKey( x, "cmd" )
      RETURN Fail( "scen: `cmd` ausente em " + cPath )
   ENDIF
   IF ! HB_ISARRAY( x[ "cmd" ] ) .OR. Len( x[ "cmd" ] ) == 0
      RETURN Fail( "scen: `cmd` tem de ser uma LISTA não-vazia de argv em " + cPath )
   ENDIF
   FOR EACH xI IN x[ "cmd" ]
      IF HB_ISCHAR( xI )
         RETURN Fail( "scen: `cmd` tem uma LINHA de texto em " + cPath + " - cada comando " + ;
                      "é uma LISTA de argumentos, como o `argv` do envelope: " + ;
                      "[ [ " + hb_jsonEncode( "rename" ) + ", " + hb_jsonEncode( "app.hbp" ) + ", ... ] ]" )
      ENDIF
      IF ! HB_ISARRAY( xI ) .OR. Len( xI ) == 0
         RETURN Fail( "scen: item de `cmd` não é uma lista de argumentos não-vazia em " + cPath )
      ENDIF
      FOR EACH xJ IN xI
         IF ! HB_ISCHAR( xJ ) .OR. Len( xJ ) == 0
            RETURN Fail( "scen: argumento vazio (ou não-texto) em `cmd` de " + cPath )
         ENDIF
      NEXT
   NEXT
   FOR EACH cK IN s_aLists
      IF hb_HHasKey( x, cK )
         IF ! HB_ISARRAY( x[ cK ] )
            RETURN Fail( "scen: `" + cK + "` tem de ser LISTA em " + cPath )
         ENDIF
         FOR EACH xI IN x[ cK ]
            IF ! HB_ISCHAR( xI ) .OR. Len( xI ) == 0
               RETURN Fail( "scen: item vazio (ou não-texto) em `" + cK + "` de " + cPath )
            ENDIF
         NEXT
      ENDIF
   NEXT

   IF ! Empty( cKey )
      xVal := hb_HGetDef( x, cKey, NIL )
      DO CASE
      // LISTA sai UMA POR LINHA - juntar com espaço quebraria `cmd`, cujos
      // itens TÊM espaços (o shell lê linha a linha)
      CASE HB_ISARRAY( xVal )   ; cOut := ArrLines( xVal )
      CASE xVal == NIL          ; cOut := ""
      CASE HB_ISNUMERIC( xVal ) ; cOut := hb_ntos( xVal )
      OTHERWISE                 ; cOut := xVal
      ENDCASE
      OutStd( cOut + hb_eol() )
   ENDIF

   RETURN .T.

// ---------------------------------------------------------------------------
// `scenlint <dir>` - a DISCIPLINA do cenário, cobrada sem rodá-lo.
//
// Por que existe, e por que é CÓDIGO e não parágrafo no README: cada régua aqui
// nasceu de um erro que ACONTECEU, e a lei do repo (§1.6) diz que "regra nova
// sem portão novo é regra que eu vou violar de novo". O README continua sendo o
// contrato que se LÊ; isto é o que MORDE. Régua nova entra nos dois lugares.
//
// Separado do `scen` de propósito: aquele valida a FORMA do case.json e é
// chamado a cada leitura de chave (barato, sem I/O de diretório); este olha o
// cenário INTEIRO e roda uma vez só.
// ---------------------------------------------------------------------------
STATIC FUNCTION ScenLint( cDir )

   LOCAL cName, cOut, cLine, aCmd, cCmd, aBad := {}, cCh
   LOCAL x, cRaw

   IF Empty( cDir ) .OR. ! hb_DirExists( cDir )
      RETURN Fail( "scenlint: diretório de cenário ausente: " + hb_defaultValue( cDir, "(vazio)" ) )
   ENDIF
   cDir  := hb_DirSepDel( cDir )
   cName := hb_FNameNameExt( cDir )
   cRaw  := hb_MemoRead( cDir + hb_ps() + "case.json" )
   IF hb_jsonDecode( cRaw, @x ) == 0 .OR. ! HB_ISHASH( x )
      RETURN Fail( "scenlint: " + cName + " sem case.json legível (o `scen` diz o quê)" )
   ENDIF
   aCmd := hb_HGetDef( x, "cmd", {} )   // lista de argv (o `scen` já validou a forma)

   // (a) o `desc` não amarra ao runner LEGADO. Cenário se identifica pelo que
   // prova; número de caso é o vocabulário do formato que está morrendo
   IF hb_regexHas( "(?i)\b(case|unit|caso)\s+[0-9]+", hb_HGetDef( x, "desc", "" ) )
      AAdd( aBad, "`desc` cita número de caso/unit - o cenário se identifica pelo que PROVA, " + ;
                  "não pela posição no runner antigo" )
   ENDIF

   // (b) o `output` é o coração: ele é ESCRITO do contrato, nunca gravado da
   // execução. Não dá para provar a ordem em que foi escrito, mas dá para pegar
   // os dois CHEIROS de gravado:
   //   - `unclassified` congelado como contrato: é o campo pelo qual a extensão
   //     e o agente DECIDEM, e sair "não classificado" é dívida a pagar NESTE
   //     cenário, não fato a gravar (aconteceu comigo em 2026-07-26);
   //   - caminho ABSOLUTO de máquina: o runner normaliza <CWD>/<CORE>, então um
   //     path cru só chega ali se veio colado de outra execução.
   // `outputs/` é um DIRETÓRIO, um arquivo por comando na ordem do `cmd` (Diego,
   // 2026-07-26). O runner confere a correspondência 1:1 e o byte a byte; aqui
   // vale a disciplina do CONTEÚDO, e ela vale para todos os arquivos.
   IF hb_vfExists( cDir + hb_ps() + "outputs" ) .AND. ! hb_DirExists( cDir + hb_ps() + "outputs" )
      AAdd( aBad, "`outputs` é um ARQUIVO: virou DIRETÓRIO, um por comando na ordem do `cmd`" )
   ELSEIF ! hb_DirExists( cDir + hb_ps() + "outputs" )
      AAdd( aBad, "sem `outputs/`: o cenário tem de declarar a transcrição esperada de cada comando" )
   ELSE
      FOR EACH cCh IN hb_Directory( cDir + hb_ps() + "outputs" + hb_ps() + "*" )
         cOut := hb_MemoRead( cDir + hb_ps() + "outputs" + hb_ps() + cCh[ 1 ] )
         FOR EACH cLine IN hb_ATokens( StrTran( cOut, Chr( 13 ), "" ), Chr( 10 ) )
            IF "unclassified" $ cLine
               AAdd( aBad, "outputs/" + cCh[ 1 ] + " congela reason `unclassified` - esse é o " + ;
                           "campo pelo qual o agente DECIDE. Classifique a recusa NESTE " + ;
                           "cenário (o código nasce aqui)" )
               EXIT
            ENDIF
            IF "/home/" $ cLine .OR. "/Users/" $ cLine .OR. hb_regexHas( "[A-Za-z]:\\", cLine )
               AAdd( aBad, "outputs/" + cCh[ 1 ] + " tem caminho ABSOLUTO de máquina (" + ;
                           AllTrim( cLine ) + ") - o runner normaliza <CWD>/<CORE>; isso só " + ;
                           "chega aí colado de uma execução" )
               EXIT
            ENDIF
         NEXT
      NEXT
   ENDIF

   // (d) SÓ O CANAL JSON - e o cenário que congela PROSA reprova.
   //
   // Eu escrevi aqui, em 2026-07-26, o portão EXATAMENTE INVERTIDO (exigindo o
   // par prosa+json) por ter lido a spec §2.2 - a prosa como renderização do
   // fato - e NÃO o roadmap A.1, onde está a decisão FINAL e posterior do
   // Diego (2026-07-24/25): *"a saída é o envelope (JSON), e nada mais. Sem
   // renderizador humano (a prosa é arrasto -> deletada); a flag --json some"*.
   // O passo 3 da própria fase que estou executando é "arrancar prosa+flag".
   //
   // Logo, congelar a transcrição da prosa não é cobertura: é ARRASTO. Cada
   // `output` com prosa é um arquivo a reescrever no passo 3, e ~127 cenários
   // com prosa congelada transformariam a remoção num mutirão. O cenário testa
   // o que vai SOBREVIVER. (A prosa ainda existe enquanto o passo 3 não roda;
   // o que este portão proíbe é AMARRÁ-LA num teste novo.)
   FOR EACH cCmd IN aCmd
      IF ! HB_ISARRAY( cCmd ) .OR. hb_AScan( cCmd, "--json",,, .T. ) == 0
         AAdd( aBad, "o comando `" + ArrJoin( cCmd ) + "` roda sem --json, e a transcrição " + ;
                     "da PROSA vira arrasto: a decisão da fase A.1 é envelope e nada mais " + ;
                     "(roadmap A.1 - passo 3: arrancar prosa+flag). Teste o que sobrevive" )
         EXIT
      ENDIF
   NEXT

   // (e) fixture que traz DIRETIVA traz VOCABULÁRIO, e ele não pode vazar para
   // o fonte da ferramenta (a régua do caso 64). O `forbid` fica no cenário que
   // introduz a palavra - senão quem cria fixture nova precisa LEMBRAR de
   // escrever a régua dela, e lembrar não é portão
   IF Len( hb_HGetDef( x, "forbid", {} ) ) == 0
      FOR EACH cCh IN hb_Directory( cDir + hb_ps() + "source" + hb_ps() + "*.ch" )
         IF hb_regexHas( "(?im)^\s*#x?(command|translate)", ;   // `m`: a diretiva não está na 1ª linha
                         hb_MemoRead( cDir + hb_ps() + "source" + hb_ps() + cCh[ 1 ] ) )
            AAdd( aBad, "a source traz diretiva em " + cCh[ 1 ] + " e o cenário não declara " + ;
                        "`forbid`: o vocabulário da fixture não pode aparecer em " + ;
                        "src/hbrefactor.prg (régua do caso 64)" )
            EXIT
         ENDIF
      NEXT
   ENDIF

   IF Len( aBad ) > 0
      OutStd( "tcheck falhou: scenlint " + cName + hb_eol() )
      FOR EACH cLine IN aBad
         OutStd( "   - " + cLine + hb_eol() )
      NEXT
      RETURN .F.
   ENDIF

   RETURN .T.

// quantos comandos o cenário roda - o runner precisa saber sem parsear JSON
STATIC FUNCTION CmdCount( cPath )

   LOCAL x

   IF hb_jsonDecode( hb_MemoRead( hb_defaultValue( cPath, "" ) ), @x ) == 0 .OR. ! HB_ISHASH( x )
      RETURN Fail( "cmdcount: " + hb_defaultValue( cPath, "" ) + " não é JSON válido" )
   ENDIF
   OutStd( hb_ntos( Len( hb_HGetDef( x, "cmd", {} ) ) ) + hb_eol() )

   RETURN .T.

// os argumentos do comando N, UM POR LINHA - o runner lê com `mapfile` e passa
// direto ao binário. É isto que aposenta o `eval`: o argumento atravessa sem o
// shell reinterpretar espaço, aspas ou glob.
STATIC FUNCTION CmdArgs( cPath, cN )

   LOCAL x, nN := Val( hb_defaultValue( cN, "0" ) ), a

   IF hb_jsonDecode( hb_MemoRead( hb_defaultValue( cPath, "" ) ), @x ) == 0 .OR. ! HB_ISHASH( x )
      RETURN Fail( "cmdargs: " + hb_defaultValue( cPath, "" ) + " não é JSON válido" )
   ENDIF
   a := hb_HGetDef( x, "cmd", {} )
   IF nN < 1 .OR. nN > Len( a )
      RETURN Fail( "cmdargs: não há comando " + hb_ntos( nN ) + " em " + cPath )
   ENDIF
   OutStd( ArrLines( a[ nN ] ) + hb_eol() )

   RETURN .T.

STATIC FUNCTION ArrLines( a )
   LOCAL c := "", x
   FOR EACH x IN a
      c += iif( Len( c ) == 0, "", hb_eol() ) + iif( HB_ISCHAR( x ), x, hb_jsonEncode( x ) )
   NEXT
   RETURN c

STATIC FUNCTION ArrJoin( a )
   LOCAL c := "", x
   FOR EACH x IN a
      c += iif( Len( c ) == 0, "", " " ) + iif( HB_ISCHAR( x ), x, hb_jsonEncode( x ) )
   NEXT
   RETURN c
