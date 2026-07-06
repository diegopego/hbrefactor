// hbrefactor - refatoração para Harbour sobre a AST do compilador
//
// Segunda encarnação (roadmap v3): TODO conhecimento sintático e semântico
// vem do dump .ast.json (schema ast-1/ast-2) emitido pelos ganchos do
// compilador (branch feature/compiler-ast-dump). A ferramenta não replica
// lexer nem estrutura: decide e edita texto com fatos do compilador, e
// verifica recompilando e comparando (editor != verificador).
//
//   projeto  : hbmk2 -traceonly resolve qualquer alvo que o hbmk2 aceite
//   dumps    : hbmk2 <alvos> -hbcmp -rebuild -prgflag=-x<dir>/
//   fatos    : tokens com linha/coluna/proveniência, declarações com escopo,
//              occurrences r/w/x, calls, sends, blocks, statements
//
// A primeira encarnação (sobre .occ.json) está em smoketest/ como referência.

#define APP_VERSION "0.5.0"

#define EXIT_OK       0
#define EXIT_REFUSED  1
#define EXIT_USAGE    2

PROCEDURE Main()

   LOCAL aArgs := hb_AParams()
   LOCAL nExit

   DO CASE
   CASE Len( aArgs ) >= 1 .AND. ( Lower( aArgs[ 1 ] ) == "rename-local" .OR. ;
                                  Lower( aArgs[ 1 ] ) == "rename-param" )
      nExit := RenameLocal( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "reorder-params"
      nExit := ReorderParams( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "rename-static"
      nExit := RenameStatic( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "rename-function"
      nExit := RenameFunction( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "extract-function"
      nExit := ExtractFunction( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "inline-local"
      nExit := InlineLocal( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "unused-locals"
      nExit := UnusedLocals( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "call-graph"
      nExit := CallGraph( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "find-dynamic-calls"
      nExit := FindDynamicCalls( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "rename-dsl"
      nExit := RenameDsl( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "rename-memvar"
      nExit := RenameMemvar( aArgs )
   CASE Len( aArgs ) >= 1 .AND. ( Lower( aArgs[ 1 ] ) == "rename-method" .OR. ;
                                  Lower( aArgs[ 1 ] ) == "rename-pp-marker" )
      // mesmo motor (B4d): rename-method é o açúcar com política de
      // mensagem; rename-pp-marker renomeia qualquer nome que preencha um
      // match marker de diretiva de pp (e os artefatos que ele deriva)
      nExit := RenameMethod( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "usages"
      nExit := Usages( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "dump"
      nExit := DumpOnly( aArgs )
   OTHERWISE
      Usage()
      nExit := EXIT_USAGE
   ENDCASE

   ErrorLevel( nExit )

   RETURN

STATIC PROCEDURE Usage()

   OutStd( "hbrefactor " + APP_VERSION + " - Harbour refactoring (compiler AST)" + hb_eol() )
   OutStd( "Usage:" + hb_eol() )
   OutStd( "  hbrefactor rename-local <projeto> <arq.prg> <função> <velho> <novo> [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor rename-param <projeto> <arq.prg> <função> <velho> <novo> [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor rename-function <projeto> <velho> <novo> [--file <f.prg>] [--force] [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor rename-static <projeto> <arq.prg> <velho> <novo> [--func <função>] [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor reorder-params <projeto> <função> <n1,n2,...> [--file <f.prg>] [--force] [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor extract-function <projeto> <arq.prg> <ini>-<fim> <nome> [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor inline-local <projeto> <arq.prg> <função> <nome> [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor usages <projeto> <nome> [--func <função>] [--json <out>] [--show-expansion]" + hb_eol() )
   OutStd( "  hbrefactor rename-dsl <projeto> <velha> <nova> [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor rename-memvar <projeto> <velho> <novo> [--force] [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor rename-method <projeto> <Classe:Método> <novo> [--force] [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor rename-pp-marker <projeto> <nome> <novo> [--force] [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor unused-locals <projeto>" + hb_eol() )
   OutStd( "  hbrefactor call-graph <projeto> [<função>]" + hb_eol() )
   OutStd( "  hbrefactor find-dynamic-calls <projeto>" + hb_eol() )
   OutStd( "  hbrefactor dump <projeto>          (gera os .ast.json e informa o diretório)" + hb_eol() )
   OutStd( "  <projeto> = qualquer alvo que o hbmk2 aceite (.hbp, .hbc com sources=," + hb_eol() )
   OutStd( "              lista de .prg separada por vírgula ou espaço)" + hb_eol() )

   RETURN

// ---------------------------------------------------------------------------
// projeto - delegado ao hbmk2 (builder oficial): -traceonly expõe a linha
// de comando completa do compilador com fontes e flags resolvidos
// ---------------------------------------------------------------------------

STATIC FUNCTION LoadProject( cSpec )

   LOCAL cOut := "", cErr := "", cCmdLine := "", cTok, cDir, aLines, nI
   LOCAL hProj, lNext := .F.

   // -rebuild: sem ele, projeto com -inc e alvo em dia não mostra comando
   IF hb_processRun( HbMk2Bin() + " " + StrTran( cSpec, ",", " " ) + ;
                     " -traceonly -rebuild",, @cOut, @cErr ) != 0
      OutErr( ErrLines( cOut + cErr ) )
      RETURN NIL
   ENDIF

   aLines := hb_ATokens( StrTran( cOut, Chr( 13 ), "" ), Chr( 10 ) )
   FOR nI := 1 TO Len( aLines )
      IF lNext
         cCmdLine := aLines[ nI ]
         EXIT
      ENDIF
      lNext := "Harbour compiler command" $ aLines[ nI ]
   NEXT
   IF Empty( cCmdLine )
      OutErr( "hbrefactor: hbmk2 não produziu comando do compilador para '" + ;
              cSpec + "'" + hb_eol() )
      RETURN NIL
   ENDIF

   hProj := { "spec" => cSpec, "files" => {}, "hbx" => {}, "inc" => {}, "flags" => {} }

   FOR EACH cTok IN CmdTokens( cCmdLine )
      DO CASE
      CASE cTok:__enumIndex() == 1              // o binário harbour
      CASE ! Left( cTok, 1 ) == "-"
         DO CASE
         CASE Lower( hb_FNameExt( cTok ) ) == ".prg"
            AAdd( hProj[ "files" ], cTok )
         CASE Lower( hb_FNameExt( cTok ) ) == ".hbx"
            AAdd( hProj[ "hbx" ], cTok )
         ENDCASE
      CASE Left( cTok, 2 ) == "-o" .OR. Left( cTok, 2 ) == "-q"
      CASE Left( cTok, 2 ) == "-i"
         AAdd( hProj[ "inc" ], SubStr( cTok, 3 ) )
         AAdd( hProj[ "flags" ], cTok )
      OTHERWISE
         AAdd( hProj[ "flags" ], cTok )
      ENDCASE
   NEXT

   IF Empty( hProj[ "files" ] )
      RETURN NIL
   ENDIF

   FOR EACH cTok IN hProj[ "files" ]
      cDir := hb_FNameDir( cTok )
      IF Empty( cDir )
         cDir := "." + hb_ps()
      ENDIF
      IF hb_AScan( hProj[ "inc" ], cDir,,, .T. ) == 0
         AAdd( hProj[ "inc" ], cDir )
      ENDIF
   NEXT

   RETURN hProj

// hbmk2 cita tokens com '...' no unix e o argv[0] vem entre parênteses
STATIC FUNCTION CmdTokens( cLine )

   LOCAL aTok := {}, cCur := "", lQ := .F., nI, cCh

   FOR nI := 1 TO Len( cLine )
      cCh := SubStr( cLine, nI, 1 )
      DO CASE
      CASE cCh == "'"
         lQ := ! lQ
      CASE cCh == " " .AND. ! lQ
         IF ! Empty( cCur )
            AAdd( aTok, cCur )
         ENDIF
         cCur := ""
      OTHERWISE
         cCur += cCh
      ENDCASE
   NEXT
   IF ! Empty( cCur )
      AAdd( aTok, cCur )
   ENDIF
   FOR EACH cCur IN aTok
      IF Left( cCur, 1 ) == "(" .AND. Right( cCur, 1 ) == ")"
         cCur := SubStr( cCur, 2, Len( cCur ) - 2 )
      ENDIF
   NEXT

   RETURN aTok

STATIC FUNCTION HbMk2Bin()

   LOCAL cBin := hb_GetEnv( "HB_BIN" )

   RETURN iif( Empty( cBin ), "hbmk2", hb_DirSepAdd( cBin ) + "hbmk2" )

// ---------------------------------------------------------------------------
// dumps - o hbmk2 compila o projeto repassando -x<dir>/ a cada módulo
// (-rebuild: dump sempre fresco mesmo com -inc no projeto)
// ---------------------------------------------------------------------------

STATIC FUNCTION AstDumps( hProj, cTmp )

   LOCAL cOut := "", cErr := ""

   IF hb_processRun( HbMk2Bin() + " " + StrTran( hProj[ "spec" ], ",", " " ) + ;
                     " -hbcmp -rebuild -q '-prgflag=-x" + hb_DirSepAdd( cTmp ) + ;
                     "'",, @cOut, @cErr ) != 0
      OutErr( ErrLines( cOut + cErr ) )
      RETURN .F.
   ENDIF

   RETURN .T.

STATIC FUNCTION ReadAst( cTmp, cModPath )

   LOCAL cPath := hb_DirSepAdd( cTmp ) + hb_FNameName( cModPath ) + ".ast.json"
   LOCAL hAst := hb_jsonDecode( hb_MemoRead( cPath ) )

   // ast-3 = ast-2 + rastro de derivação ("from" nos tokens sintetizados,
   // fase B4d); o leitor usa só seções presentes em ambos - comandos que
   // exigem o rastro recusam o dump antigo com mensagem clara (FromReady)
   IF ! HB_ISHASH( hAst ) .OR. ;
      hb_AScan( { "ast-2", "ast-3" }, hb_HGetDef( hAst, "schema", "" ) ) == 0
      RETURN NIL
   ENDIF

   RETURN hAst

// scratch único por invocação (R1 da suíte paralela e de qualquer uso
// concorrente real - o timestamp de 1 s colidia entre processos no mesmo
// segundo): mkdir é atômico, então o nome é aleatório e a criação é
// tentar-até-conseguir; hb_DirCreate devolve 0 só quando criou AGORA
STATIC FUNCTION WorkDir()

   LOCAL cTmp, nTry := 0

   DO WHILE .T.
      cTmp := hb_DirSepAdd( hb_DirTemp() ) + "hbrefactor_" + ;
              hb_ntos( hb_RandomInt( 100000000, 999999999 ) )
      IF hb_DirCreate( cTmp ) == 0
         EXIT
      ENDIF
      IF ++nTry > 50      // erro persistente (permissão/disco): deixa o
         EXIT             // consumidor falhar alto na primeira gravação
      ENDIF
   ENDDO

   RETURN cTmp

// coluna exata de um símbolo numa linha, direto dos tokens do compilador
// (0-based no dump; devolve lista de colunas 1-based, vazia se nenhum token
// com coluna cobre o símbolo naquela linha)
STATIC FUNCTION TokenCols( hAst, nLine, cSym )

   LOCAL aCols := {}, hTok
   LOCAL cUp := Upper( cSym )

   FOR EACH hTok IN hAst[ "tokens" ]
      IF hTok[ "line" ] == nLine .AND. hTok[ "col" ] != NIL .AND. ;
         Upper( hTok[ "text" ] ) == cUp
         AAdd( aCols, hTok[ "col" ] + 1 )
      ENDIF
   NEXT

   RETURN aCols

// ---------------------------------------------------------------------------
// usages - todas as referências de um símbolo no projeto, com coluna real
// ---------------------------------------------------------------------------

STATIC FUNCTION Usages( aArgs )

   LOCAL cSpec, cName, cFuncFilter := "", cJsonOut := "", lShowExp := .F.
   LOCAL hProj, cTmp, cPath, hAst, hAsts := { => }, hFunc, hItem, nI, aLift
   LOCAL nHits := 0, cModFile, aSrc, cUp, aLoc := {}, aDefSeen := {}

   IF Len( aArgs ) < 3
      Usage()
      RETURN EXIT_USAGE
   ENDIF
   cSpec := aArgs[ 2 ]
   cName := aArgs[ 3 ]
   FOR nI := 4 TO Len( aArgs )
      DO CASE
      CASE Lower( aArgs[ nI ] ) == "--func" .AND. nI < Len( aArgs )
         cFuncFilter := Upper( aArgs[ ++nI ] )
      CASE Lower( aArgs[ nI ] ) == "--json" .AND. nI < Len( aArgs )
         cJsonOut := aArgs[ ++nI ]
      CASE Lower( aArgs[ nI ] ) == "--show-expansion"
         lShowExp := .T.
      ENDCASE
   NEXT
   cUp := Upper( cName )

   hProj := LoadProject( cSpec )
   IF hProj == NIL
      RETURN Refuse( "não consegui resolver o projeto '" + cSpec + "'" )
   ENDIF

   cTmp := WorkDir()
   IF ! AstDumps( hProj, cTmp )
      RETURN Refuse( "o projeto não compila - corrija os erros de build primeiro" )
   ENDIF

   FOR EACH cPath IN hProj[ "files" ]
      hAst := ReadAst( cTmp, cPath )
      IF hAst == NIL
         RETURN Refuse( "dump ast-1 ausente/inválido para '" + cPath + ;
                        "' (harbour com -x do branch feature/compiler-ast-dump)" )
      ENDIF
      hAsts[ cPath ] := hAst
      cModFile := hb_FNameNameExt( cPath )
      aSrc := hb_ATokens( StrTran( hb_MemoRead( cPath ), Chr( 13 ), "" ), Chr( 10 ) )

      FOR EACH hFunc IN hAst[ "functions" ]
         IF hFunc[ "fileDecl" ]
            LOOP
         ENDIF
         IF ! Empty( cFuncFilter ) .AND. !( Upper( hFunc[ "name" ] ) == cFuncFilter )
            LOOP
         ENDIF

         IF Upper( hFunc[ "name" ] ) == cUp
            nHits++
            LocAdd( aLoc, cPath, hFunc[ "line" ], TokenCols( hAst, hFunc[ "line" ], cName ), Len( cName ) )
            OutStd( cModFile + ":" + hb_ntos( hFunc[ "line" ] ) + ": definition (" + ;
               iif( hFunc[ "static" ], "static ", "" ) + hFunc[ "kind" ] + ")" + hb_eol() )
         ELSEIF FromReady( hAst ) .AND. ( aLift := PpMarkerLift( hAst, hFunc, cUp ) ) != NIL
            // lifting B4d: o programador escreveu METHOD Paint() CLASS
            // UWMenu (ou HANDLER Click de qualquer DSL); a função gerada é
            // detalhe da expansão - a resposta vem no vocabulário do fonte
            // (a cabeça da regra raiz), com a posição real do nome escrito
            nHits++
            LocAdd( aLoc, cPath, aLift[ 3 ], { aLift[ 4 ] }, Len( cName ) )
            OutStd( cModFile + ":" + hb_ntos( aLift[ 3 ] ) + ": " + aLift[ 5 ] + " definition " + ;
               aLift[ 1 ] + iif( Empty( aLift[ 2 ] ), "", " (class " + aLift[ 2 ] + ")" ) + ;
               iif( lShowExp, " -> " + hFunc[ "name" ], "" ) + ;
               SrcLine( aSrc, aLift[ 3 ] ) + hb_eol() )
         ENDIF

         FOR EACH hItem IN hFunc[ "declarations" ]
            IF Upper( hItem[ "sym" ] ) == cUp
               nHits++
               LocAdd( aLoc, cPath, hItem[ "declLine" ], TokenCols( hAst, hItem[ "declLine" ], cName ), Len( cName ) )
               OutStd( cModFile + ":" + hb_ntos( hItem[ "declLine" ] ) + ": declaration (" + ;
                  hItem[ "scope" ] + iif( hItem[ "param" ], ", parameter", "" ) + ") in " + ;
                  hFunc[ "name" ] + SrcLine( aSrc, hItem[ "declLine" ] ) + hb_eol() )
            ENDIF
         NEXT

         FOR EACH hItem IN hFunc[ "occurrences" ]
            IF Upper( hItem[ "sym" ] ) == cUp
               nHits++
               LocAdd( aLoc, cPath, hItem[ "line" ], TokenCols( hAst, hItem[ "line" ], cName ), Len( cName ) )
               OutStd( cModFile + ":" + hb_ntos( hItem[ "line" ] ) + ": " + hItem[ "access" ] + ;
                  " (" + hItem[ "scope" ] + iif( hItem[ "block" ], ", codeblock", "" ) + ") in " + ;
                  hFunc[ "name" ] + SrcLine( aSrc, hItem[ "line" ] ) + hb_eol() )
            ENDIF
         NEXT

         FOR EACH hItem IN hFunc[ "calls" ]
            IF Upper( hItem[ "sym" ] ) == cUp
               nHits++
               LocAdd( aLoc, cPath, hItem[ "line" ], TokenCols( hAst, hItem[ "line" ], cName ), Len( cName ) )
               OutStd( cModFile + ":" + hb_ntos( hItem[ "line" ] ) + ": call" + ;
                  iif( hItem[ "block" ], " (codeblock)", "" ) + " in " + ;
                  hFunc[ "name" ] + SrcLine( aSrc, hItem[ "line" ] ) + hb_eol() )
            ENDIF
         NEXT

         FOR EACH hItem IN hFunc[ "sends" ]
            IF Upper( hItem[ "sym" ] ) == cUp
               nHits++
               LocAdd( aLoc, cPath, hItem[ "line" ], TokenCols( hAst, hItem[ "line" ], cName ), Len( cName ) )
               OutStd( cModFile + ":" + hb_ntos( hItem[ "line" ] ) + ": send" + ;
                  iif( hItem[ "block" ], " (codeblock)", "" ) + " in " + ;
                  hFunc[ "name" ] + SrcLine( aSrc, hItem[ "line" ] ) + hb_eol() )
            ENDIF
         NEXT
      NEXT

      // referências possíveis em strings: tokens tipo 41 cujo conteúdo é
      // exatamente o nome (call-by-name) - do próprio stream do compilador
      FOR EACH hItem IN hAst[ "tokens" ]
         IF hItem[ "type" ] == 41 .AND. hItem[ "line" ] > 0 .AND. ;
            Upper( hItem[ "text" ] ) == cUp
            nHits++
            LocAdd( aLoc, cPath, hItem[ "line" ], ;
                    iif( hItem[ "col" ] == NIL, {}, { hItem[ "col" ] + 1 } ), Len( cName ) )
            OutStd( cModFile + ":" + hb_ntos( hItem[ "line" ] ) + ;
                    ": possible reference in string" + SrcLine( aSrc, hItem[ "line" ] ) + hb_eol() )
         ENDIF
      NEXT

      // o nome pode ser palavra de DSL de pp (consumida antes do yylex e
      // portanto invisível em tokens[]): diretivas e aplicações (ast-2)
      nHits += DslHits( hAst, cUp, cModFile, aSrc, aDefSeen, aLoc, cPath, Len( cName ) )

      // sites do NOME DE MARKER que atravessam diretivas (B4d): posições
      // escritas que nenhum relator acima cobriu (decl. de método/handler...)
      IF FromReady( hAst )
         nHits += PpMarkerHits( hAst, cUp, cModFile, aSrc, aLoc, cPath, Len( cName ), lShowExp )
      ENDIF
   NEXT

   // memvar: mapa de visibilidade DINÂMICA (criadores, alcance, sombras,
   // furos) - análise B4b sobre os fatos já listados acima
   MvMapReport( hProj, hAsts, cUp )

   OutStd( hb_ntos( nHits ) + " result(s) for '" + cName + "'" + hb_eol() )

   IF ! Empty( cJsonOut )
      hb_MemoWrit( cJsonOut, LocationsJson( aLoc ) )
   ENDIF

   RETURN iif( nHits > 0, EXIT_OK, EXIT_REFUSED )

// ---------------------------------------------------------------------------
// dump - só gera os .ast.json (depuração / consumo externo)
// ---------------------------------------------------------------------------

STATIC FUNCTION DumpOnly( aArgs )

   LOCAL hProj, cTmp

   IF Len( aArgs ) < 2
      Usage()
      RETURN EXIT_USAGE
   ENDIF
   hProj := LoadProject( aArgs[ 2 ] )
   IF hProj == NIL
      RETURN Refuse( "não consegui resolver o projeto '" + aArgs[ 2 ] + "'" )
   ENDIF
   cTmp := WorkDir()
   IF ! AstDumps( hProj, cTmp )
      RETURN Refuse( "o projeto não compila" )
   ENDIF
   OutStd( "dumps em: " + cTmp + hb_eol() )

   RETURN EXIT_OK

// ---------------------------------------------------------------------------
// saída LSP Location[] (linhas/colunas 0-based)
// ---------------------------------------------------------------------------

STATIC PROCEDURE LocAdd( aLoc, cPath, nLine, aCols, nLen )

   IF Empty( aCols )
      AAdd( aLoc, { cPath, nLine, 0, 0 } )
   ELSE
      AAdd( aLoc, { cPath, nLine, aCols[ 1 ] - 1, nLen } )
   ENDIF

   RETURN

STATIC FUNCTION LocationsJson( aLoc )

   LOCAL aOut := {}, aL

   // aL[1] pode ser relativo (spec relativo, como no run.sh) OU absoluto
   // (spec absoluto, como a extensão VSCode sempre passa): hb_PathJoin
   // devolve o segundo argumento intacto quando já é absoluto - hb_FNameMerge
   // concatenava e DUPLICAVA o prefixo (URI file:// inválido no editor)
   FOR EACH aL IN aLoc
      AAdd( aOut, { ;
         "uri" => "file://" + hb_PathNormalize( hb_PathJoin( ;
                     hb_DirSepAdd( hb_cwd() ), aL[ 1 ] ) ), ;
         "range" => { ;
            "start" => { "line" => aL[ 2 ] - 1, "character" => aL[ 3 ] }, ;
            "end"   => { "line" => aL[ 2 ] - 1, "character" => aL[ 3 ] + aL[ 4 ] } } } )
   NEXT

   RETURN hb_jsonEncode( aOut )

// ---------------------------------------------------------------------------
// utilidades
// ---------------------------------------------------------------------------

STATIC FUNCTION SrcLine( aSrc, nLine )
   RETURN iif( nLine >= 1 .AND. nLine <= Len( aSrc ), ;
               "  | " + AllTrim( aSrc[ nLine ] ), "" )

STATIC FUNCTION Refuse( cMsg )

   OutErr( "hbrefactor: " + cMsg + hb_eol() )

   RETURN EXIT_REFUSED

STATIC FUNCTION ErrLines( cText )

   LOCAL cLine, cRes := ""

   FOR EACH cLine IN hb_ATokens( StrTran( cText, Chr( 13 ), "" ), Chr( 10 ) )
      IF " Error " $ cLine .OR. " Warning " $ cLine .OR. "Error:" $ cLine
         cRes += AllTrim( cLine ) + hb_eol()
      ENDIF
   NEXT

   RETURN iif( Empty( cRes ), cText, cRes )

// ---------------------------------------------------------------------------
// rename-local / rename-param - edição por token: cada site vem com linha e
// coluna do compilador (sobrevive a linhas reescritas pelo pp e a
// continuações ';' - sem tokenizer próprio, sem juntar statements).
// Verificação: nomes de locais não existem no pcode, então o .hrb -gh -l de
// TODOS os módulos deve sair byte-idêntico; senão, rollback.
// ---------------------------------------------------------------------------

STATIC FUNCTION RenameLocal( aArgs )

   LOCAL cSpec, cFile, cFunc, cOld, cNew, lParamOnly, lDryRun := .F.
   LOCAL hProj, cTmp, cSrcPath, hAst, hFunc, hItem, hTok, hRule
   LOCAL hDecl := NIL, aEdits := {}, nSpanEnd := 0, nI
   LOCAL cText, cUpOld, cUpNew, aPrev, cPrevType, nLine

   IF Len( aArgs ) < 6
      Usage()
      RETURN EXIT_USAGE
   ENDIF
   cSpec := aArgs[ 2 ]
   cFile := aArgs[ 3 ]
   cFunc := aArgs[ 4 ]
   cOld  := aArgs[ 5 ]
   cNew  := aArgs[ 6 ]
   lParamOnly := Lower( aArgs[ 1 ] ) == "rename-param"
   FOR nI := 7 TO Len( aArgs )
      IF Lower( aArgs[ nI ] ) == "--dry-run"
         lDryRun := .T.
      ENDIF
   NEXT
   cUpOld := Upper( cOld )
   cUpNew := Upper( cNew )

   IF ! OneWord( cNew )
      RETURN Refuse( "novo nome '" + cNew + "' não é uma palavra única" )
   ENDIF
   IF cUpOld == cUpNew
      RETURN Refuse( "nomes velho e novo são idênticos" )
   ENDIF

   hProj := LoadProject( cSpec )
   IF hProj == NIL
      RETURN Refuse( "não consegui resolver o projeto '" + cSpec + "'" )
   ENDIF
   cSrcPath := ProjectMember( hProj, cFile )
   IF cSrcPath == ""
      RETURN Refuse( "'" + cFile + "' não é fonte do projeto '" + cSpec + "'" )
   ENDIF
   cTmp := WorkDir()
   IF ! NameAccepted( hProj, cNew, .F. )
      RETURN Refuse( "o compilador do projeto rejeita '" + cNew + "' como nome de variável" )
   ENDIF
   IF ! AstDumps( hProj, cTmp )
      RETURN Refuse( "o projeto não compila - corrija os erros de build primeiro" )
   ENDIF
   hAst := ReadAst( cTmp, cSrcPath )
   IF hAst == NIL
      RETURN Refuse( "dump ast-1 ausente/inválido para '" + cSrcPath + "'" )
   ENDIF
   IF ( hRule := RuleHeadCollision( hAst, cUpNew ) ) != NIL
      RETURN Refuse( "novo nome '" + cNew + "' colide com regra de pré-processador (" + ;
                     RuleTag( hRule ) + ", " + RuleWhere( hRule ) + ")" )
   ENDIF

   hFunc := PickFunc( hAst, cFunc )
   IF hFunc == NIL
      RETURN Refuse( "função '" + cFunc + "' não encontrada em '" + cFile + "'" )
   ENDIF

   // o alvo precisa ser LOCAL (ou parâmetro) declarado na função
   FOR EACH hItem IN hFunc[ "declarations" ]
      IF Upper( hItem[ "sym" ] ) == cUpNew
         RETURN Refuse( "novo nome '" + cNew + "' já declarado na função (escopo " + hItem[ "scope" ] + ")" )
      ENDIF
      IF Upper( hItem[ "sym" ] ) == cUpOld .AND. hItem[ "scope" ] == "local"
         hDecl := hItem
      ENDIF
   NEXT
   // nome novo já referenciado na função como memvar/field: a LOCAL nova
   // sombrearia esses usos em silêncio (muda binding, não sintaxe - B4b)
   FOR EACH hItem IN hFunc[ "occurrences" ]
      IF Upper( hItem[ "sym" ] ) == cUpNew .AND. ;
         ( hItem[ "scope" ] == "memvar" .OR. hItem[ "scope" ] == "memvar_implicit" .OR. ;
           hItem[ "scope" ] == "field" )
         RETURN Refuse( "'" + cNew + "' já é " + hItem[ "scope" ] + " referenciada na função (linha " + ;
                        hb_ntos( hItem[ "line" ] ) + ") - a LOCAL nova sombrearia esses usos" )
      ENDIF
   NEXT
   IF hDecl == NIL
      RETURN Refuse( "'" + cOld + "' não é LOCAL declarada em " + hFunc[ "name" ] )
   ENDIF
   IF lParamOnly .AND. ! hDecl[ "param" ]
      RETURN Refuse( "'" + cOld + "' não é parâmetro de " + hFunc[ "name" ] )
   ENDIF

   // sombras: parâmetro de codeblock homônimo (do velho: ambíguo demais;
   // do novo: os usos do novo dentro do bloco passariam a apontar p/ outro)
   FOR EACH hItem IN hFunc[ "occurrences" ]
      IF hItem[ "block" ] .AND. hItem[ "scope" ] == "local"
         IF Upper( hItem[ "sym" ] ) == cUpOld
            RETURN Refuse( "parâmetro de codeblock homônimo sombreia (shadows) '" + cOld + "' - recusando" )
         ENDIF
         IF Upper( hItem[ "sym" ] ) == cUpNew
            RETURN Refuse( "'" + cNew + "' é parâmetro de codeblock na função - o rename seria sombreado" )
         ENDIF
      ENDIF
   NEXT

   // span da função no fonte: dentro dele, TODO token identificador com o
   // nome é a nossa local (o compilador liga todos os usos à local depois
   // das recusas acima; statements continuados por ';' vêm de graça porque
   // cada token sabe sua linha física verdadeira)
   FOR EACH hItem IN hAst[ "functions" ]
      IF ! hItem[ "fileDecl" ] .AND. hItem[ "line" ] > hFunc[ "line" ] .AND. ;
         ( nSpanEnd == 0 .OR. hItem[ "line" ] < nSpanEnd )
         nSpanEnd := hItem[ "line" ]
      ENDIF
   NEXT

   // contexto :msg e alias->campo excluído pelo TIPO do token anterior no
   // stream (58=SEND, 59=ALIAS); 21=identificador; prov 's'=fonte principal
   aPrev := NIL
   FOR EACH hTok IN hAst[ "tokens" ]
      cPrevType := iif( aPrev == NIL, 0, aPrev[ "type" ] )
      IF hTok[ "type" ] == 21 .AND. hTok[ "prov" ] == "s" .AND. ;
         hTok[ "line" ] >= hFunc[ "line" ] .AND. ;
         ( nSpanEnd == 0 .OR. hTok[ "line" ] < nSpanEnd ) .AND. ;
         Upper( hTok[ "text" ] ) == cUpOld .AND. ;
         !( cPrevType == 58 .OR. cPrevType == 59 )
         IF hTok[ "col" ] == NIL
            RETURN Refuse( "referência na linha " + hb_ntos( hTok[ "line" ] ) + ;
                           " sem posição confiável no fonte (reescrita de pp) - recusando" )
         ENDIF
         AAdd( aEdits, { hTok[ "line" ], hTok[ "col" ] + 1 } )
      ENDIF
      aPrev := hTok
   NEXT
   // vários tokens do stream podem compartilhar a MESMA (linha,col) de
   // origem - clones de um único token-fonte que uma diretiva de pp
   // multiplicou na expansão (ex.: o parâmetro de uma FUNCTION gerada,
   // declarado e usado no corpo, deriva do mesmo marker). Sem deduplicar,
   // ApplyTokenEdits escreveria na mesma span mais de uma vez (nA->nAlfa
   // vira nAlfalfa). Um site = uma posição-fonte.
   DedupHits( aEdits )
   IF Empty( aEdits )
      RETURN Refuse( "nenhum site editável encontrado" )
   ENDIF

   OutStd( aArgs[ 1 ] + ": " + cOld + " -> " + cNew + " in " + ;
           iif( ":" $ cFunc .OR. Upper( cFunc ) == Upper( hFunc[ "name" ] ), cFunc, cFunc ) + ;
           " (" + hb_FNameNameExt( cSrcPath ) + ")" + hb_eol() )
   FOR nI := 1 TO Len( aEdits )
      OutStd( "  " + hb_FNameNameExt( cSrcPath ) + ":" + hb_ntos( aEdits[ nI ][ 1 ] ) + ;
              ":" + hb_ntos( aEdits[ nI ][ 2 ] ) + hb_eol() )
   NEXT
   IF lDryRun
      OutStd( "dry run - nada foi escrito" + hb_eol() )
      RETURN EXIT_OK
   ENDIF

   // estado "antes" para a verificação byte-idêntica
   IF ! CompileHrbAll( hProj, cTmp, "before" )
      RETURN Refuse( "falha ao compilar o estado de referência" )
   ENDIF

   cText := hb_MemoRead( cSrcPath )
   hb_MemoWrit( cSrcPath, ApplyTokenEdits( cText, aEdits, cOld, cNew, @nLine ) )
   IF nLine > 0
      hb_MemoWrit( cSrcPath, cText )
      RETURN Refuse( "texto na linha " + hb_ntos( nLine ) + " não confere com o esperado - rollback" )
   ENDIF

   IF ! CompileHrbAll( hProj, cTmp, "after" )
      hb_MemoWrit( cSrcPath, cText )
      RETURN Refuse( "o projeto parou de compilar após o rename - rollback" )
   ENDIF
   FOR EACH cSpec IN hProj[ "files" ]           // reuso de cSpec como iterador
      IF !( hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cSpec ) + ".before.hrb" ) == ;
            hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cSpec ) + ".after.hrb" ) )
         hb_MemoWrit( cSrcPath, cText )
         RETURN Refuse( "verificação FALHOU: " + hb_FNameName( cSpec ) + ".hrb mudou - rollback" )
      ENDIF
   NEXT

   OutStd( "verified: all " + hb_ntos( Len( hProj[ "files" ] ) ) + ;
           " module(s) byte-identical (-gh -l)" + hb_eol() )

   RETURN EXIT_OK

// aplica edições { linha, col 1-based } trocando cOld->cNew; devolve o texto
// novo; nLineBad > 0 quando o texto no site não confere (sanidade: a coluna
// do dump tem que apontar exatamente para o nome velho no fonte)
STATIC FUNCTION ApplyTokenEdits( cText, aEdits, cOld, cNew, nLineBad )

   LOCAL aOffs := { 1 }, nI, nAt
   LOCAL nOldLen := hb_BLen( cOld )

   nLineBad := 0
   FOR nI := 1 TO hb_BLen( cText )
      IF hb_BSubStr( cText, nI, 1 ) == Chr( 10 )
         AAdd( aOffs, nI + 1 )
      ENDIF
   NEXT

   // ordena descendente por (linha, col) para os offsets não se moverem
   ASort( aEdits,,, {| x, y | iif( x[ 1 ] == y[ 1 ], x[ 2 ] > y[ 2 ], x[ 1 ] > y[ 1 ] ) } )

   FOR nI := 1 TO Len( aEdits )
      IF aEdits[ nI ][ 1 ] > Len( aOffs )
         nLineBad := aEdits[ nI ][ 1 ]
         RETURN cText
      ENDIF
      nAt := aOffs[ aEdits[ nI ][ 1 ] ] + aEdits[ nI ][ 2 ] - 1
      IF ! Upper( hb_BSubStr( cText, nAt, nOldLen ) ) == Upper( cOld )
         nLineBad := aEdits[ nI ][ 1 ]
         RETURN cText
      ENDIF
      cText := hb_BLeft( cText, nAt - 1 ) + cNew + hb_BSubStr( cText, nAt + nOldLen )
   NEXT

   RETURN cText

// compila cada módulo p/ .hrb portável (-gh -l: sem números de linha, nomes
// de locais fora) com os flags que o hbmk2 resolveu p/ o projeto; com lAst
// também regrava os .ast.json em cTmp (verificação de artefatos previstos)
STATIC FUNCTION CompileHrbAll( hProj, cTmp, cTag, lAst )

   LOCAL cPath, cFlags := "", cTok, cOut, cErr

   FOR EACH cTok IN hProj[ "flags" ]
      cFlags += " " + cTok
   NEXT
   IF hb_defaultValue( lAst, .F. )
      cFlags += " -x" + hb_DirSepAdd( cTmp )
   ENDIF
   FOR EACH cPath IN hProj[ "files" ]
      cOut := cErr := ""
      IF hb_processRun( HarbourBin() + " " + cPath + " -q -gh -l" + cFlags + ;
             " -o" + hb_DirSepAdd( cTmp ) + hb_FNameName( cPath ) + "." + cTag + ".hrb",, ;
             @cOut, @cErr ) != 0
         OutErr( "hbrefactor: " + cPath + ":" + hb_eol() + ErrLines( cOut + cErr ) )
         RETURN .F.
      ENDIF
   NEXT

   RETURN .T.

STATIC FUNCTION HarbourBin()

   LOCAL cBin := hb_GetEnv( "HB_BIN" )

   RETURN iif( Empty( cBin ), "harbour", hb_DirSepAdd( cBin ) + "harbour" )

// função por nome, aceitando Classe:Metodo e nome de método puro - o mapa
// método/classe -> função gerada vem do lifting por ppApplications (fatos
// da B4; a convenção textual <CLASSE>_<METODO> da era smoke test morreu)
STATIC FUNCTION PickFunc( hAst, cFunc )

   LOCAL hFunc, hHit := NIL, nHits := 0, nAt
   LOCAL cUp := Upper( cFunc ), cClass := "", cMethod

   FOR EACH hFunc IN hAst[ "functions" ]
      IF ! hFunc[ "fileDecl" ] .AND. Upper( hFunc[ "name" ] ) == cUp
         RETURN hFunc
      ENDIF
   NEXT
   IF ( nAt := At( ":", cUp ) ) > 0
      cClass  := Left( cUp, nAt - 1 )
      cMethod := SubStr( cUp, nAt + 1 )
   ELSE
      cMethod := cUp
   ENDIF
   FOR EACH hFunc IN hAst[ "functions" ]
      IF ! hFunc[ "fileDecl" ] .AND. ;
         MethodImplOf( hAst, hFunc, cClass, cMethod ) != NIL
         nHits++
         hHit := hFunc
      ENDIF
   NEXT

   RETURN iif( nHits == 1, hHit, NIL )

// a função IMPLEMENTA Classe:Metodo? Fato do rastro (B4d): o token do nome
// da função é um artefato composto cujas faixas de "from" soletram o método
// (e a classe, quando dada). Devolve { cClasse, cMetodo, aFrom } ou NIL -
// os textos na grafia REAL do composto (a colagem preserva caixa)
STATIC FUNCTION MethodImplOf( hAst, hFunc, cUpClass, cUpMethod )

   LOCAL hTok, hFrom, cPart, cM, cC, aFromM
   LOCAL cUpName := Upper( hFunc[ "name" ] )

   FOR EACH hTok IN hAst[ "tokens" ]
      IF hTok[ "type" ] == 21 .AND. hb_HHasKey( hTok, "from" ) .AND. ;
         Upper( hTok[ "text" ] ) == cUpName .AND. ! ( cUpName == cUpMethod )
         cM := cC := ""
         aFromM := NIL
         FOR EACH hFrom IN hTok[ "from" ]
            cPart := SubStr( hTok[ "text" ], hFrom[ "at" ] + 1, hFrom[ "len" ] )
            IF Upper( cPart ) == cUpMethod .AND. Empty( cM )
               cM := cPart
               aFromM := hFrom
            ELSEIF Empty( cC )
               cC := cPart
            ENDIF
         NEXT
         IF ! Empty( cM ) .AND. ( Empty( cUpClass ) .OR. Upper( cC ) == cUpClass )
            RETURN { cC, cM, aFromM }
         ENDIF
      ENDIF
   NEXT

   RETURN NIL

STATIC FUNCTION ProjectMember( hProj, cFile )

   LOCAL cPath

   FOR EACH cPath IN hProj[ "files" ]
      IF Lower( hb_FNameNameExt( cPath ) ) == Lower( hb_FNameNameExt( cFile ) )
         RETURN cPath
      ENDIF
   NEXT

   RETURN ""

// validade de nome novo - decidida pelo COMPILADOR, não por listas
// próprias: um trecho mínimo (LOCAL <nome> em contexto de variável;
// FUNCTION <nome>() em contexto de função) vai a hb_compileFromBuf() - o
// compilador como biblioteca, embutido na ferramenta como no hbmk2 - com o
// dialeto (-k*) resolvido para o projeto. Não existe "lista de reservadas"
// consultável: reserva é CONTEXTUAL na gramática (LOOP vale como variável,
// WHILE não), e a lista da era occ divergia do oráculo nas duas direções
// (26 de 39 "reservadas" eram aceitas; ENDFOR, rejeitado, faltava). O que
// o compilador aceitar aqui mas quebrar num site específico cai na rede
// recompila+compara+rollback.
STATIC FUNCTION NameAccepted( hProj, cName, lAsFunc )

   LOCAL cSnip, cTok, aArgs := { "harbour", "-n2", "-q2", "-w0", "-gh" }

   FOR EACH cTok IN hProj[ "flags" ]
      IF Left( cTok, 2 ) == "-k"          // o dialeto muda o que é reservado
         AAdd( aArgs, cTok )
      ENDIF
   NEXT
   IF lAsFunc
      cSnip := "FUNCTION " + cName + "()" + hb_eol() + hb_eol() + ;
               "   RETURN NIL" + hb_eol()
   ELSE
      cSnip := "PROCEDURE __hbrfprobe()" + hb_eol() + hb_eol() + ;
               "   LOCAL " + cName + hb_eol() + hb_eol() + ;
               "   " + cName + " := 1" + hb_eol() + ;
               "   IF " + cName + " == 1" + hb_eol() + ;
               "      " + cName + "++" + hb_eol() + ;
               "   ENDIF" + hb_eol() + hb_eol() + ;
               "   RETURN" + hb_eol()
   ENDIF

   // devolve o .hrb compilado (string) no sucesso; NIL quando o compilador
   // rejeita o fonte
   RETURN HB_ISSTRING( hb_compileFromBuf( cSnip, aArgs ) )

// o nome é função do core/runtime Harbour? Duas fontes existentes do
// próprio Harbour: include/harbour.hbx (lista canônica COMPLETA das
// públicas do core, achada pelos -i que o hbmk2 resolveu p/ o projeto) e
// hb_IsFunction (símbolos vivos no runtime da ferramenta - pega o que
// estiver linkado além do core). Nenhuma lista própria.
STATIC FUNCTION CoreFunction( hProj, cUpName )

   LOCAL cDir, cText, cLine

   FOR EACH cDir IN hProj[ "inc" ]
      cText := hb_MemoRead( hb_DirSepAdd( cDir ) + "harbour.hbx" )
      IF ! Empty( cText )
         FOR EACH cLine IN hb_ATokens( StrTran( cText, Chr( 13 ), "" ), Chr( 10 ) )
            IF Left( cLine, 8 ) == "DYNAMIC " .AND. ;
               Upper( AllTrim( SubStr( cLine, 9 ) ) ) == cUpName
               RETURN .T.
            ENDIF
         NEXT
      ENDIF
   NEXT

   RETURN hb_IsFunction( cUpName )

// anti-injeção do probe (não é gramática: só garante que o nome é UMA
// palavra imprimível - o que é identificador quem diz é o compilador)
STATIC FUNCTION OneWord( cName )

   LOCAL nI

   IF Empty( cName )
      RETURN .F.
   ENDIF
   FOR nI := 1 TO hb_BLen( cName )
      IF hb_BSubStr( cName, nI, 1 ) <= " " .OR. hb_BSubStr( cName, nI, 1 ) == ";"
         RETURN .F.
      ENDIF
   NEXT

   RETURN .T.

// colisão do nome novo com cabeça de regra de pp VISÍVEL no módulo - fatos
// de ppRules (ast-2): cobre includes aninhados, regras builtin aplicadas e
// a abreviação dBase de #command/#translate. Substitui o DefineCollision/
// PpHeadIn textual da era B2 (auditoria: réplica marcada para morrer na B4).
STATIC FUNCTION RuleHeadCollision( hAst, cUpNew )

   LOCAL hRule

   IF hb_HHasKey( hAst, "ppRules" )
      FOR EACH hRule IN hAst[ "ppRules" ]
         IF hRule[ "head" ] != NIL .AND. ;
            AbbrevClash( cUpNew, "?", Upper( hRule[ "head" ] ), hRule[ "kind" ] )
            RETURN hRule
         ENDIF
      NEXT
   ENDIF

   RETURN NIL

// ---------------------------------------------------------------------------
// resolução linha -> tokens editáveis: os statements[] trazem span de
// ÍNDICES de token [tokMin,tokMax] - statements continuados por ';' são
// cobertos por índice, sem juntar texto. Para linhas fora de statement
// (assinaturas, declarações) cai na busca por linha física.
// ---------------------------------------------------------------------------

STATIC FUNCTION LineTokens( hAst, hFunc, nLine, cUpName )

   LOCAL aHits := {}, hStmt, hTok, nI
   LOCAL aToks := hAst[ "tokens" ]

   FOR EACH hStmt IN hFunc[ "statements" ]
      IF hStmt[ "line" ] == nLine .AND. HB_ISHASH( hStmt[ "expr" ] ) .AND. ;
         hb_HHasKey( hStmt[ "expr" ], "tok" )
         // varre do span do statement (índices 0-based no dump)
         FOR nI := SpanMin( hStmt[ "expr" ] ) + 1 TO SpanMax( hStmt[ "expr" ] ) + 2
            IF nI >= 1 .AND. nI <= Len( aToks )
               hTok := aToks[ nI ]
               IF hTok[ "type" ] == 21 .AND. hTok[ "prov" ] == "s" .AND. ;
                  hTok[ "col" ] != NIL .AND. Upper( hTok[ "text" ] ) == cUpName
                  AddHit( aHits, hTok )
               ENDIF
            ENDIF
         NEXT
      ENDIF
   NEXT

   // fallback/complemento: tokens na própria linha física
   FOR EACH hTok IN aToks
      IF hTok[ "line" ] == nLine .AND. hTok[ "type" ] == 21 .AND. ;
         hTok[ "prov" ] == "s" .AND. hTok[ "col" ] != NIL .AND. ;
         Upper( hTok[ "text" ] ) == cUpName
         AddHit( aHits, hTok )
      ENDIF
   NEXT

   RETURN aHits

STATIC PROCEDURE AddHit( aHits, hTok )

   LOCAL aH

   FOR EACH aH IN aHits
      IF aH[ 1 ] == hTok[ "line" ] .AND. aH[ 2 ] == hTok[ "col" ] + 1
         RETURN
      ENDIF
   NEXT
   AAdd( aHits, { hTok[ "line" ], hTok[ "col" ] + 1 } )

   RETURN

STATIC FUNCTION SpanMin( hExpr )

   LOCAL nMin := hb_HGetDef( hExpr, "tok", 0 ), hKid, xVal

   FOR EACH xVal IN hb_HValues( hExpr )
      IF HB_ISHASH( xVal )
         nMin := Min( nMin, SpanMin( xVal ) )
      ELSEIF HB_ISARRAY( xVal )
         FOR EACH hKid IN xVal
            IF HB_ISHASH( hKid )
               nMin := Min( nMin, SpanMin( hKid ) )
            ENDIF
         NEXT
      ENDIF
   NEXT

   RETURN nMin

STATIC FUNCTION SpanMax( hExpr )

   LOCAL nMax := hb_HGetDef( hExpr, "tok", 0 ), hKid, xVal

   FOR EACH xVal IN hb_HValues( hExpr )
      IF HB_ISHASH( xVal )
         nMax := Max( nMax, SpanMax( xVal ) )
      ELSEIF HB_ISARRAY( xVal )
         FOR EACH hKid IN xVal
            IF HB_ISHASH( hKid )
               nMax := Max( nMax, SpanMax( hKid ) )
            ENDIF
         NEXT
      ENDIF
   NEXT

   RETURN nMax

// ---------------------------------------------------------------------------
// rename-static - STATIC de função ou file-wide, restrita ao módulo.
// Nomes de estáticas não existem no pcode: verificação byte-idêntica.
// ---------------------------------------------------------------------------

STATIC FUNCTION RenameStatic( aArgs )

   LOCAL cSpec, cFile, cOld, cNew, cFuncFilter := "", lDryRun := .F.
   LOCAL hProj, cTmp, cSrcPath, hAst, hFunc, hItem, hTok, aPrev, cPrevType
   LOCAL hOwner := NIL, lFileWide := .F., aEdits := {}, nI, cText, nLine
   LOCAL cUpOld, cUpNew, hRule

   IF Len( aArgs ) < 5
      Usage()
      RETURN EXIT_USAGE
   ENDIF
   cSpec := aArgs[ 2 ]
   cFile := aArgs[ 3 ]
   cOld  := aArgs[ 4 ]
   cNew  := aArgs[ 5 ]
   FOR nI := 6 TO Len( aArgs )
      DO CASE
      CASE Lower( aArgs[ nI ] ) == "--func" .AND. nI < Len( aArgs )
         cFuncFilter := Upper( aArgs[ ++nI ] )
      CASE Lower( aArgs[ nI ] ) == "--dry-run"
         lDryRun := .T.
      ENDCASE
   NEXT
   cUpOld := Upper( cOld )
   cUpNew := Upper( cNew )

   IF ! OneWord( cNew )
      RETURN Refuse( "novo nome '" + cNew + "' não é uma palavra única" )
   ENDIF
   IF cUpOld == cUpNew
      RETURN Refuse( "nomes velho e novo são idênticos" )
   ENDIF

   hProj := LoadProject( cSpec )
   IF hProj == NIL
      RETURN Refuse( "não consegui resolver o projeto '" + cSpec + "'" )
   ENDIF
   cSrcPath := ProjectMember( hProj, cFile )
   IF cSrcPath == ""
      RETURN Refuse( "'" + cFile + "' não é fonte do projeto '" + cSpec + "'" )
   ENDIF
   cTmp := WorkDir()
   IF ! NameAccepted( hProj, cNew, .F. )
      RETURN Refuse( "o compilador do projeto rejeita '" + cNew + "' como nome de variável" )
   ENDIF
   IF ! AstDumps( hProj, cTmp )
      RETURN Refuse( "o projeto não compila - corrija os erros de build primeiro" )
   ENDIF
   hAst := ReadAst( cTmp, cSrcPath )
   IF hAst == NIL
      RETURN Refuse( "dump ast-1 ausente/inválido para '" + cSrcPath + "'" )
   ENDIF
   IF ( hRule := RuleHeadCollision( hAst, cUpNew ) ) != NIL
      RETURN Refuse( "novo nome '" + cNew + "' colide com regra de pré-processador (" + ;
                     RuleTag( hRule ) + ", " + RuleWhere( hRule ) + ")" )
   ENDIF

   // localiza a declaração STATIC (file-wide mora na pseudo-função fileDecl)
   FOR EACH hFunc IN hAst[ "functions" ]
      IF ! Empty( cFuncFilter ) .AND. ! hFunc[ "fileDecl" ] .AND. ;
         !( Upper( hFunc[ "name" ] ) == cFuncFilter )
         LOOP
      ENDIF
      FOR EACH hItem IN hFunc[ "declarations" ]
         IF Upper( hItem[ "sym" ] ) == cUpOld .AND. hItem[ "scope" ] == "static"
            IF hOwner != NIL
               RETURN Refuse( "STATIC '" + cOld + "' declarada em mais de um lugar - use --func" )
            ENDIF
            hOwner := hFunc
            lFileWide := hFunc[ "fileDecl" ]
         ENDIF
         IF Upper( hItem[ "sym" ] ) == cUpNew
            RETURN Refuse( "novo nome '" + cNew + "' já declarado em " + hFunc[ "name" ] )
         ENDIF
      NEXT
   NEXT
   IF hOwner == NIL
      RETURN Refuse( "STATIC '" + cOld + "' não encontrada em '" + cFile + "'" )
   ENDIF

   // sombras: qualquer declaração homônima não-static no alcance torna a
   // varredura por nome ambígua - recusa (o compilador resolveu diferente)
   FOR EACH hFunc IN hAst[ "functions" ]
      IF lFileWide .OR. hFunc == hOwner
         FOR EACH hItem IN hFunc[ "declarations" ]
            IF Upper( hItem[ "sym" ] ) == cUpOld .AND. ! hItem[ "scope" ] == "static"
               RETURN Refuse( "'" + cOld + "' também é " + hItem[ "scope" ] + " em " + ;
                              hFunc[ "name" ] + " - sombra; recusando" )
            ENDIF
         NEXT
      ENDIF
   NEXT

   // coleta por span: file-wide = módulo inteiro; de função = span da função
   aPrev := NIL
   FOR EACH hTok IN hAst[ "tokens" ]
      cPrevType := iif( aPrev == NIL, 0, aPrev[ "type" ] )
      IF hTok[ "type" ] == 21 .AND. hTok[ "prov" ] == "s" .AND. ;
         Upper( hTok[ "text" ] ) == cUpOld .AND. ;
         !( cPrevType == 58 .OR. cPrevType == 59 ) .AND. ;
         ( lFileWide .OR. InFuncSpan( hAst, hOwner, hTok[ "line" ] ) )
         IF hTok[ "col" ] == NIL
            RETURN Refuse( "referência na linha " + hb_ntos( hTok[ "line" ] ) + ;
                           " sem posição confiável (reescrita de pp) - recusando" )
         ENDIF
         AAdd( aEdits, { hTok[ "line" ], hTok[ "col" ] + 1 } )
      ENDIF
      aPrev := hTok
   NEXT
   // dedup por (linha,col): clones de um mesmo token-fonte multiplicado por
   // expansão de pp não podem gerar edição dupla na mesma span (ver
   // RenameLocal) - um site = uma posição-fonte
   DedupHits( aEdits )
   IF Empty( aEdits )
      RETURN Refuse( "nenhum site editável encontrado" )
   ENDIF

   OutStd( "rename-static: " + cOld + " -> " + cNew + ;
           iif( lFileWide, " (file-wide)", " em " + hOwner[ "name" ] ) + ;
           " (" + hb_FNameNameExt( cSrcPath ) + ")" + hb_eol() )
   FOR nI := 1 TO Len( aEdits )
      OutStd( "  " + hb_FNameNameExt( cSrcPath ) + ":" + hb_ntos( aEdits[ nI ][ 1 ] ) + ;
              ":" + hb_ntos( aEdits[ nI ][ 2 ] ) + hb_eol() )
   NEXT
   IF lDryRun
      OutStd( "dry run - nada foi escrito" + hb_eol() )
      RETURN EXIT_OK
   ENDIF

   IF ! CompileHrbAll( hProj, cTmp, "before" )
      RETURN Refuse( "falha ao compilar o estado de referência" )
   ENDIF
   cText := hb_MemoRead( cSrcPath )
   hb_MemoWrit( cSrcPath, ApplyTokenEdits( cText, aEdits, cOld, cNew, @nLine ) )
   IF nLine > 0
      hb_MemoWrit( cSrcPath, cText )
      RETURN Refuse( "texto na linha " + hb_ntos( nLine ) + " não confere - rollback" )
   ENDIF
   IF ! CompileHrbAll( hProj, cTmp, "after" )
      hb_MemoWrit( cSrcPath, cText )
      RETURN Refuse( "o projeto parou de compilar após o rename - rollback" )
   ENDIF
   FOR EACH cSpec IN hProj[ "files" ]
      IF !( hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cSpec ) + ".before.hrb" ) == ;
            hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cSpec ) + ".after.hrb" ) )
         hb_MemoWrit( cSrcPath, cText )
         RETURN Refuse( "verificação FALHOU: " + hb_FNameName( cSpec ) + ".hrb mudou - rollback" )
      ENDIF
   NEXT
   OutStd( "verified: all " + hb_ntos( Len( hProj[ "files" ] ) ) + ;
           " module(s) byte-identical (-gh -l)" + hb_eol() )

   RETURN EXIT_OK

STATIC FUNCTION InFuncSpan( hAst, hFunc, nLine )

   LOCAL hOther, nEnd := 0

   FOR EACH hOther IN hAst[ "functions" ]
      IF ! hOther[ "fileDecl" ] .AND. hOther[ "line" ] > hFunc[ "line" ] .AND. ;
         ( nEnd == 0 .OR. hOther[ "line" ] < nEnd )
         nEnd := hOther[ "line" ]
      ENDIF
   NEXT

   RETURN nLine >= hFunc[ "line" ] .AND. ( nEnd == 0 .OR. nLine < nEnd )

// ---------------------------------------------------------------------------
// rename-function - FUNCTION/PROCEDURE no projeto inteiro (STATIC restrita
// ao módulo). Nomes de função EXISTEM na tabela de símbolos do .hrb: a
// verificação é estrutural (símbolos renomeados como esperado, pcode
// byte-idêntico). Strings que citam o nome: relato + --force, nunca edição.
// ---------------------------------------------------------------------------

STATIC FUNCTION RenameFunction( aArgs )

   LOCAL cSpec, cOld, cNew, cOnlyFile := "", lForce := .F., lDryRun := .F.
   LOCAL hProj, cTmp, cPath, hAst, hAsts := { => }, hFunc, hItem, nI
   LOCAL lStatic := .F., cDefFile := "", aWarn := {}, hEdits := { => }, aE
   LOCAL cUpOld, cUpNew, cText, hOrig := { => }, nLine, nTotal := 0, aHit

   IF Len( aArgs ) < 4
      Usage()
      RETURN EXIT_USAGE
   ENDIF
   cSpec := aArgs[ 2 ]
   cOld  := aArgs[ 3 ]
   cNew  := aArgs[ 4 ]
   FOR nI := 5 TO Len( aArgs )
      DO CASE
      CASE Lower( aArgs[ nI ] ) == "--force"
         lForce := .T.
      CASE Lower( aArgs[ nI ] ) == "--dry-run"
         lDryRun := .T.
      CASE Lower( aArgs[ nI ] ) == "--file" .AND. nI < Len( aArgs )
         cOnlyFile := aArgs[ ++nI ]
      ENDCASE
   NEXT
   cUpOld := Upper( cOld )
   cUpNew := Upper( cNew )

   IF ! OneWord( cNew )
      RETURN Refuse( "novo nome '" + cNew + "' não é uma palavra única" )
   ENDIF
   IF cUpOld == cUpNew
      RETURN Refuse( "nomes velho e novo são idênticos" )
   ENDIF

   hProj := LoadProject( cSpec )
   IF hProj == NIL
      RETURN Refuse( "não consegui resolver o projeto '" + cSpec + "'" )
   ENDIF
   cTmp := WorkDir()
   IF ! NameAccepted( hProj, cNew, .T. )
      RETURN Refuse( "o compilador do projeto rejeita '" + cNew + "' como nome de função" )
   ENDIF
   // função do core/runtime Harbour (harbour.hbx + hb_IsFunction): definir
   // no projeto uma função homônima sombreia a nativa em TODAS as chamadas
   IF CoreFunction( hProj, cUpNew )
      AAdd( aWarn, "'" + cNew + "' é função do runtime Harbour - defini-la no projeto " + ;
            "sombreia (shadows) a nativa em todas as chamadas" )
   ENDIF
   IF ! AstDumps( hProj, cTmp )
      RETURN Refuse( "o projeto não compila - corrija os erros de build primeiro" )
   ENDIF

   // definições e colisões, projeto inteiro
   FOR EACH cPath IN hProj[ "files" ]
      hAst := ReadAst( cTmp, cPath )
      IF hAst == NIL
         RETURN Refuse( "dump ast-1 ausente/inválido para '" + cPath + "'" )
      ENDIF
      hAsts[ cPath ] := hAst
      FOR EACH hFunc IN hAst[ "functions" ]
         IF hFunc[ "fileDecl" ]
            LOOP
         ENDIF
         IF Upper( hFunc[ "name" ] ) == cUpNew
            RETURN Refuse( "'" + cNew + "' já é função definida em " + hb_FNameNameExt( cPath ) )
         ENDIF
         // chamadas existentes ao nome novo passariam a cair na renomeada
         FOR EACH hItem IN hFunc[ "calls" ]
            IF Upper( hItem[ "sym" ] ) == cUpNew
               RETURN Refuse( "'" + cNew + "' já é chamada em " + hb_FNameNameExt( cPath ) + ;
                              ":" + hb_ntos( hItem[ "line" ] ) + " - o rename sequestraria essas chamadas" )
            ENDIF
         NEXT
         IF Upper( hFunc[ "name" ] ) == cUpOld
            IF ! Empty( cOnlyFile ) .AND. ;
               ! Lower( hb_FNameNameExt( cPath ) ) == Lower( hb_FNameNameExt( cOnlyFile ) )
               LOOP
            ENDIF
            IF ! Empty( cDefFile )
               RETURN Refuse( "'" + cOld + "' definida em mais de um módulo - use --file" )
            ENDIF
            cDefFile := cPath
            lStatic := hFunc[ "static" ]
         ENDIF
      NEXT
   NEXT
   IF Empty( cDefFile )
      RETURN Refuse( "função '" + cOld + "' não está definida no projeto" )
   ENDIF

   // sites: definição + calls; STATIC fica no módulo da definição
   FOR EACH cPath IN hProj[ "files" ]
      IF lStatic .AND. ! cPath == cDefFile
         LOOP
      ENDIF
      hAst := hAsts[ cPath ]
      aE := {}
      FOR EACH hFunc IN hAst[ "functions" ]
         IF ! hFunc[ "fileDecl" ] .AND. Upper( hFunc[ "name" ] ) == cUpOld .AND. cPath == cDefFile
            FOR EACH aHit IN LineTokens( hAst, hFunc, hFunc[ "line" ], cUpOld )
               AAdd( aE, aHit )
            NEXT
         ENDIF
         FOR EACH hItem IN hFunc[ "calls" ]
            IF Upper( hItem[ "sym" ] ) == cUpOld
               FOR EACH aHit IN LineTokens( hAst, hFunc, hItem[ "line" ], cUpOld )
                  AAdd( aE, aHit )
               NEXT
            ENDIF
         NEXT
      NEXT
      // colisão do novo nome com locais/estáticas do módulo (sombra léxica)
      FOR EACH hFunc IN hAst[ "functions" ]
         FOR EACH hItem IN hFunc[ "declarations" ]
            IF Upper( hItem[ "sym" ] ) == cUpNew .AND. ! Empty( aE )
               AAdd( aWarn, hb_FNameNameExt( cPath ) + ":" + hb_ntos( hItem[ "declLine" ] ) + ;
                     ": '" + cNew + "' é " + hItem[ "scope" ] + " em " + hFunc[ "name" ] + ;
                     " - chamadas ali seriam sombreadas" )
            ENDIF
         NEXT
      NEXT
      IF ! Empty( aE )
         DedupHits( aE )
         hEdits[ cPath ] := aE
         nTotal += Len( aE )
      ENDIF
      // strings que citam o nome (call-by-name possível): relato, nunca edição
      FOR EACH hItem IN hAst[ "tokens" ]
         IF hItem[ "type" ] == 41 .AND. hItem[ "line" ] > 0 .AND. ;
            Upper( hItem[ "text" ] ) == cUpOld
            AAdd( aWarn, hb_FNameNameExt( cPath ) + ":" + hb_ntos( hItem[ "line" ] ) + ;
                  ": string igual a '" + cOld + "' - possível chamada por nome (não será alterada)" )
         ENDIF
      NEXT
   NEXT

   // .hbx: exports DYNAMIC gerados pelo hbmk2 (não editamos; regenerar)
   FOR EACH cPath IN hProj[ "hbx" ]
      cText := hb_MemoRead( cPath )
      nI := 0
      FOR EACH cSpec IN hb_ATokens( StrTran( cText, Chr( 13 ), "" ), Chr( 10 ) )   // reuso
         nI++
         IF Upper( AllTrim( cSpec ) ) == "DYNAMIC " + cUpOld
            AAdd( aWarn, hb_FNameNameExt( cPath ) + ":" + hb_ntos( nI ) + ;
                  ": DYNAMIC " + cUpOld + " em export (.hbx) - regenerar com -hbx=" )
         ENDIF
      NEXT
   NEXT

   IF nTotal == 0
      RETURN Refuse( "nenhum site editável encontrado para '" + cOld + "'" )
   ENDIF

   FOR nI := 1 TO Len( aWarn )
      OutErr( "warning: " + aWarn[ nI ] + hb_eol() )
   NEXT
   IF ! Empty( aWarn ) .AND. ! lForce
      RETURN Refuse( "referências textuais encontradas (ver warnings) - repita com --force para prosseguir sem tocá-las" )
   ENDIF

   OutStd( "rename-function: " + cOld + " -> " + cNew + ;
           iif( lStatic, " (static, só " + hb_FNameNameExt( cDefFile ) + ")", "" ) + hb_eol() )
   FOR EACH cPath IN hb_HKeys( hEdits )
      FOR EACH aE IN hEdits[ cPath ]
         OutStd( "  " + hb_FNameNameExt( cPath ) + ":" + hb_ntos( aE[ 1 ] ) + ;
                 ":" + hb_ntos( aE[ 2 ] ) + hb_eol() )
      NEXT
   NEXT
   IF lDryRun
      OutStd( "dry run - nada foi escrito" + hb_eol() )
      RETURN EXIT_OK
   ENDIF

   IF ! CompileHrbAll( hProj, cTmp, "before" )
      RETURN Refuse( "falha ao compilar o estado de referência" )
   ENDIF
   FOR EACH cPath IN hb_HKeys( hEdits )
      cText := hb_MemoRead( cPath )
      hOrig[ cPath ] := cText
      hb_MemoWrit( cPath, ApplyTokenEdits( cText, hEdits[ cPath ], cOld, cNew, @nLine ) )
      IF nLine > 0
         RollbackAll( hOrig )
         RETURN Refuse( "texto em " + hb_FNameNameExt( cPath ) + ":" + hb_ntos( nLine ) + ;
                        " não confere - rollback" )
      ENDIF
   NEXT
   IF ! CompileHrbAll( hProj, cTmp, "after" )
      RollbackAll( hOrig )
      RETURN Refuse( "o projeto parou de compilar após o rename - rollback" )
   ENDIF
   FOR EACH cPath IN hProj[ "files" ]
      IF ! HrbEquivalent( hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cPath ) + ".before.hrb" ), ;
                          hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cPath ) + ".after.hrb" ), ;
                          cUpOld, cUpNew, @cSpec )              // reuso de cSpec p/ motivo
         RollbackAll( hOrig )
         RETURN Refuse( "verificação FALHOU em " + hb_FNameName( cPath ) + ": " + cSpec + " - rollback" )
      ENDIF
   NEXT

   OutStd( "verified: " + hb_ntos( nTotal ) + " edit(s); symbol tables renamed as expected, pcode byte-identical" + hb_eol() )

   RETURN EXIT_OK

STATIC PROCEDURE DedupHits( aE )

   LOCAL nI := 1, nJ

   DO WHILE nI <= Len( aE )
      nJ := nI + 1
      DO WHILE nJ <= Len( aE )
         IF aE[ nJ ][ 1 ] == aE[ nI ][ 1 ] .AND. aE[ nJ ][ 2 ] == aE[ nI ][ 2 ]
            hb_ADel( aE, nJ, .T. )
         ELSE
            nJ++
         ENDIF
      ENDDO
      nI++
   ENDDO

   RETURN

STATIC PROCEDURE RollbackAll( hOrig )

   LOCAL cPath

   FOR EACH cPath IN hb_HKeys( hOrig )
      hb_MemoWrit( cPath, hOrig[ cPath ] )
   NEXT

   RETURN

// ---------------------------------------------------------------------------
// leitor do formato .hrb (portado da 1ª encarnação; ver src/vm/runner.c):
// assinatura \xC0HRB + versão 2 bytes + símbolos[nome\0 escopo tipo] +
// funções[nome\0 tam4 pcode]. Fail-safe: formato inesperado -> NIL -> recusa.
// ---------------------------------------------------------------------------

STATIC FUNCTION HrbParse( cBody )

   LOCAL nAt := 1, nSyms, nFuncs, nI, nLen, cName
   LOCAL aSyms := {}, aFuncs := {}

   IF ! hb_BLeft( cBody, 4 ) == Chr( 0xC0 ) + "HRB"
      RETURN NIL
   ENDIF
   nAt := 7                          // assinatura 4 + versão 2, 1-based
   nSyms := Bin2L( hb_BSubStr( cBody, nAt, 4 ) )
   nAt += 4
   FOR nI := 1 TO nSyms
      nLen := hb_BAt( Chr( 0 ), cBody, nAt ) - nAt
      IF nLen < 0
         RETURN NIL
      ENDIF
      cName := hb_BSubStr( cBody, nAt, nLen )
      nAt += nLen + 1
      AAdd( aSyms, { cName, hb_BSubStr( cBody, nAt, 2 ) } )
      nAt += 2
   NEXT
   nFuncs := Bin2L( hb_BSubStr( cBody, nAt, 4 ) )
   nAt += 4
   FOR nI := 1 TO nFuncs
      nLen := hb_BAt( Chr( 0 ), cBody, nAt ) - nAt
      IF nLen < 0
         RETURN NIL
      ENDIF
      cName := hb_BSubStr( cBody, nAt, nLen )
      nAt += nLen + 1
      nLen := Bin2L( hb_BSubStr( cBody, nAt, 4 ) )
      nAt += 4
      AAdd( aFuncs, { cName, hb_BSubStr( cBody, nAt, nLen ) } )
      nAt += nLen
   NEXT

   RETURN { "syms" => aSyms, "funcs" => aFuncs }

// pós-rename de função: símbolos/funções com o nome velho viram o novo,
// TODO o resto (inclusive pcode byte a byte) idêntico
STATIC FUNCTION HrbEquivalent( cBefore, cAfter, cUpOld, cUpNew, cWhy )

   LOCAL hB := HrbParse( cBefore ), hA := HrbParse( cAfter )
   LOCAL nI, cExp

   cWhy := ""
   IF hB == NIL .OR. hA == NIL
      cWhy := "não consegui ler o .hrb"
      RETURN .F.
   ENDIF
   IF Len( hB[ "syms" ] ) != Len( hA[ "syms" ] ) .OR. ;
      Len( hB[ "funcs" ] ) != Len( hA[ "funcs" ] )
      cWhy := "quantidade de símbolos/funções mudou"
      RETURN .F.
   ENDIF
   FOR nI := 1 TO Len( hB[ "syms" ] )
      cExp := iif( Upper( hB[ "syms" ][ nI ][ 1 ] ) == cUpOld, cUpNew, hB[ "syms" ][ nI ][ 1 ] )
      IF !( Upper( hA[ "syms" ][ nI ][ 1 ] ) == Upper( cExp ) ) .OR. ;
         !( hA[ "syms" ][ nI ][ 2 ] == hB[ "syms" ][ nI ][ 2 ] )
         cWhy := "símbolo " + hb_ntos( nI ) + " inesperado: " + hA[ "syms" ][ nI ][ 1 ]
         RETURN .F.
      ENDIF
   NEXT
   FOR nI := 1 TO Len( hB[ "funcs" ] )
      cExp := iif( Upper( hB[ "funcs" ][ nI ][ 1 ] ) == cUpOld, cUpNew, hB[ "funcs" ][ nI ][ 1 ] )
      IF !( Upper( hA[ "funcs" ][ nI ][ 1 ] ) == Upper( cExp ) )
         cWhy := "função " + hb_ntos( nI ) + " inesperada: " + hA[ "funcs" ][ nI ][ 1 ]
         RETURN .F.
      ENDIF
      IF !( hA[ "funcs" ][ nI ][ 2 ] == hB[ "funcs" ][ nI ][ 2 ] )
         cWhy := "pcode de " + hA[ "funcs" ][ nI ][ 1 ] + " mudou"
         RETURN .F.
      ENDIF
   NEXT

   RETURN .T.

// ---------------------------------------------------------------------------
// extract-function - move um intervalo de linhas para uma função STATIC nova
// e substitui a seleção pela chamada. Fatos do compilador:
//   estrutura : blocks[] da função (pares open/close por pilha) - estrutura
//               aberta/fechada cruzando a borda = recusa
//   saltos    : tokens RETURN/EXIT/LOOP/BREAK no intervalo fora de bloco
//               fechado dentro da seleção = recusa
//   data flow : occurrences da função no intervalo vs fora (antes/depois):
//               dentro+fora = parâmetro; write-first + uso posterior = valor
//               de retorno; só dentro (decl fora) = a declaração MIGRA
// Verificação: HrbExtractCheck (símbolos +1 exato no módulo editado, demais
// byte-idênticos) + rollback. Grafia original recuperada dos tokens.
// ---------------------------------------------------------------------------

STATIC FUNCTION ExtractFunction( aArgs )

   LOCAL cSpec, cFile, cRange, cNewName, lDryRun := .F.
   LOCAL hProj, cTmp, cSrcPath, cPath, hAst, hAsts := { => }, hFunc, hItem
   LOCAL nFirst, nLast, nI, nFuncEnd, hTarget := NIL, aFuncs
   LOCAL cText, aSrc, aPairs, hTok, hVar, aVars := {}, hMovedLines
   LOCAL cOut := "", lOutParam := .F., aParams := {}, aMoved := {}
   LOCAL cEol, cIndent, cCall, cNewFunc, cTextNew, cWhy, cUpNew, hRule

   IF Len( aArgs ) < 5
      Usage()
      RETURN EXIT_USAGE
   ENDIF
   cSpec    := aArgs[ 2 ]
   cFile    := aArgs[ 3 ]
   cRange   := aArgs[ 4 ]
   cNewName := aArgs[ 5 ]
   FOR nI := 6 TO Len( aArgs )
      IF Lower( aArgs[ nI ] ) == "--dry-run"
         lDryRun := .T.
      ENDIF
   NEXT
   cUpNew := Upper( cNewName )

   nI := At( "-", cRange )
   IF nI == 0
      RETURN Refuse( "intervalo deve ser <ini>-<fim> (números de linha do fonte)" )
   ENDIF
   nFirst := Val( Left( cRange, nI - 1 ) )
   nLast  := Val( SubStr( cRange, nI + 1 ) )
   IF nFirst <= 0 .OR. nLast < nFirst
      RETURN Refuse( "intervalo de linhas inválido" )
   ENDIF

   IF ! OneWord( cNewName )
      RETURN Refuse( "novo nome '" + cNewName + "' não é uma palavra única" )
   ENDIF

   hProj := LoadProject( cSpec )
   IF hProj == NIL
      RETURN Refuse( "não consegui resolver o projeto '" + cSpec + "'" )
   ENDIF
   cSrcPath := ProjectMember( hProj, cFile )
   IF cSrcPath == ""
      RETURN Refuse( "'" + cFile + "' não é fonte do projeto '" + cSpec + "'" )
   ENDIF
   cTmp := WorkDir()
   IF ! NameAccepted( hProj, cNewName, .T. )
      RETURN Refuse( "o compilador do projeto rejeita '" + cNewName + "' como nome de função" )
   ENDIF
   IF ! AstDumps( hProj, cTmp )
      RETURN Refuse( "o projeto não compila - corrija os erros de build primeiro" )
   ENDIF

   // o nome novo não pode existir nem ser referenciado em nenhum módulo
   FOR EACH cPath IN hProj[ "files" ]
      hAst := ReadAst( cTmp, cPath )
      IF hAst == NIL
         RETURN Refuse( "dump ast-1 ausente/inválido para '" + cPath + "'" )
      ENDIF
      hAsts[ cPath ] := hAst
      IF cPath == cSrcPath .AND. ( hRule := RuleHeadCollision( hAst, cUpNew ) ) != NIL
         RETURN Refuse( "novo nome '" + cNewName + "' colide com regra de pré-processador (" + ;
                        RuleTag( hRule ) + ", " + RuleWhere( hRule ) + ")" )
      ENDIF
      FOR EACH hFunc IN hAst[ "functions" ]
         IF ! hFunc[ "fileDecl" ] .AND. Upper( hFunc[ "name" ] ) == cUpNew
            RETURN Refuse( "'" + cNewName + "' já é função definida em " + hb_FNameNameExt( cPath ) )
         ENDIF
         FOR EACH hItem IN hFunc[ "calls" ]
            IF Upper( hItem[ "sym" ] ) == cUpNew
               RETURN Refuse( "'" + cNewName + "' já é referenciada em " + hb_FNameNameExt( cPath ) )
            ENDIF
         NEXT
      NEXT
   NEXT
   hAst := hAsts[ cSrcPath ]

   cText := hb_MemoRead( cSrcPath )
   aSrc := hb_ATokens( StrTran( cText, Chr( 13 ), "" ), Chr( 10 ) )
   IF nLast > Len( aSrc )
      RETURN Refuse( "intervalo além do fim do arquivo" )
   ENDIF

   // função contêiner: a seleção tem que caber INTEIRA numa única função
   aFuncs := {}
   FOR EACH hFunc IN hAst[ "functions" ]
      IF ! hFunc[ "fileDecl" ] .AND. hFunc[ "line" ] > 0
         AAdd( aFuncs, hFunc )
      ENDIF
   NEXT
   ASort( aFuncs,,, {| x, y | x[ "line" ] < y[ "line" ] } )
   FOR nI := 1 TO Len( aFuncs )
      IF aFuncs[ nI ][ "line" ] < nFirst .AND. ;
         ( nI == Len( aFuncs ) .OR. aFuncs[ nI + 1 ][ "line" ] > nLast )
         hTarget := aFuncs[ nI ]
         nFuncEnd := iif( nI == Len( aFuncs ), 0x7FFFFFFF, aFuncs[ nI + 1 ][ "line" ] - 1 )
         EXIT
      ENDIF
   NEXT
   IF hTarget == NIL
      RETURN Refuse( "o intervalo não está inteiro dentro de uma única função" )
   ENDIF
   IF hTarget[ "usesMacro" ]
      OutStd( "warning: a função usa macros & - revise com cuidado" + hb_eol() )
   ENDIF

   // macro na seleção: semântica movida não-provável (memvar via &) - recusa
   FOR EACH hItem IN hTarget[ "statements" ]
      IF hItem[ "line" ] >= nFirst .AND. hItem[ "line" ] <= nLast .AND. ;
         ExprHasEt( hb_HGetDef( hItem, "expr", NIL ), "MACRO" )
         RETURN Refuse( "a seleção usa macro (&) na linha " + hb_ntos( hItem[ "line" ] ) + " - recusando" )
      ENDIF
   NEXT

   // criação de memvar/field na seleção: escopo dinâmico não sobrevive à
   // extração (PRIVATE morre no RETURN da função nova)
   FOR EACH hItem IN hTarget[ "declarations" ]
      IF hItem[ "declLine" ] >= nFirst .AND. hItem[ "declLine" ] <= nLast .AND. ;
         !( hItem[ "scope" ] == "local" )
         RETURN Refuse( "declaração " + Upper( hItem[ "scope" ] ) + " '" + hItem[ "sym" ] + ;
                        "' dentro da seleção (linha " + hb_ntos( hItem[ "declLine" ] ) + ") - recusando" )
      ENDIF
   NEXT

   // estrutura: pares open/close dos blocks[] do compilador - nenhum par
   // pode cruzar a borda da seleção
   aPairs := BlockPairs( hTarget )
   FOR EACH hItem IN aPairs
      IF ( hItem[ 2 ] >= nFirst .AND. hItem[ 2 ] <= nLast ) .AND. ;
         !( hItem[ 3 ] >= nFirst .AND. hItem[ 3 ] <= nLast )
         RETURN Refuse( "a seleção abre " + hItem[ 1 ] + " (linha " + hb_ntos( hItem[ 2 ] ) + ;
                        ") que fecha fora dela" )
      ENDIF
      IF !( hItem[ 2 ] >= nFirst .AND. hItem[ 2 ] <= nLast ) .AND. ;
         ( hItem[ 3 ] >= nFirst .AND. hItem[ 3 ] <= nLast )
         RETURN Refuse( "a seleção fecha " + hItem[ 1 ] + " aberto fora dela (linha " + ;
                        hb_ntos( hItem[ 2 ] ) + ")" )
      ENDIF
   NEXT

   // saltos cruzando a borda: RETURN sempre recusa; EXIT/LOOP precisam de
   // for/while inteiro na seleção; BREAK (não-função) precisa de sequence
   FOR EACH hTok IN hAst[ "tokens" ]
      IF hTok[ "type" ] == 21 .AND. hTok[ "line" ] >= nFirst .AND. hTok[ "line" ] <= nLast
         DO CASE
         CASE Upper( hTok[ "text" ] ) == "RETURN"
            RETURN Refuse( "RETURN dentro da seleção (linha " + hb_ntos( hTok[ "line" ] ) + ") - recusando" )
         CASE Upper( hTok[ "text" ] ) == "EXIT" .OR. Upper( hTok[ "text" ] ) == "LOOP"
            IF ! JumpCovered( aPairs, hTok[ "line" ], nFirst, nLast, { "for", "while" } )
               RETURN Refuse( Upper( hTok[ "text" ] ) + " na linha " + hb_ntos( hTok[ "line" ] ) + ;
                              " saltaria para fora da seleção" )
            ENDIF
         CASE Upper( hTok[ "text" ] ) == "BREAK" .AND. ;
              !( hTok:__enumIndex() < Len( hAst[ "tokens" ] ) .AND. ;
                 hAst[ "tokens" ][ hTok:__enumIndex() + 1 ][ "type" ] == 50 )
            IF ! JumpCovered( aPairs, hTok[ "line" ], nFirst, nLast, { "sequence" } )
               RETURN Refuse( "BREAK na linha " + hb_ntos( hTok[ "line" ] ) + ;
                              " saltaria para fora da seleção" )
            ENDIF
         ENDCASE
      ENDIF
   NEXT

   // data flow: partição das occurrences de cada LOCAL da função em
   // dentro/antes/depois da seleção (linhas físicas do fonte)
   FOR EACH hItem IN hTarget[ "declarations" ]
      IF !( hItem[ "scope" ] == "local" )
         LOOP
      ENDIF
      hVar := { "sym" => hItem[ "sym" ], "declLine" => hItem[ "declLine" ], ;
                "declIn" => ( hItem[ "declLine" ] >= nFirst .AND. hItem[ "declLine" ] <= nLast ), ;
                "param" => hItem[ "param" ], "detachedIn" => .F., ;
                "in" => {}, "before" => .F., "after" => .F., "firstIn" => "" }
      FOR EACH hFunc IN hTarget[ "occurrences" ]     // reuso de hFunc como iterador
         IF Upper( hFunc[ "sym" ] ) == Upper( hItem[ "sym" ] )
            DO CASE
            CASE hFunc[ "line" ] >= nFirst .AND. hFunc[ "line" ] <= nLast
               AAdd( hVar[ "in" ], hFunc )
               IF Empty( hVar[ "firstIn" ] )
                  hVar[ "firstIn" ] := hFunc[ "access" ]
               ENDIF
               IF hFunc[ "block" ] .AND. hFunc[ "scope" ] == "detached"
                  hVar[ "detachedIn" ] := .T.
               ENDIF
            CASE hFunc[ "line" ] > nLast .AND. hFunc[ "line" ] <= nFuncEnd
               hVar[ "after" ] := .T.
            CASE hFunc[ "line" ] < nFirst
               hVar[ "before" ] := .T.
            ENDCASE
         ENDIF
      NEXT
      IF ! Empty( hVar[ "in" ] )
         AAdd( aVars, hVar )
      ENDIF
   NEXT

   FOR EACH hVar IN aVars
      IF hVar[ "declIn" ]
         IF hVar[ "after" ]
            RETURN Refuse( "'" + hVar[ "sym" ] + "' é declarada dentro da seleção mas usada depois dela" )
         ENDIF
         LOOP                                    // move junto com o código
      ENDIF
      // codeblock na seleção capturando local viva fora: a captura passaria
      // a apontar para o parâmetro da função nova - recusa conservadora
      IF hVar[ "detachedIn" ] .AND. ( hVar[ "before" ] .OR. hVar[ "after" ] )
         RETURN Refuse( "codeblock na seleção captura '" + hVar[ "sym" ] + ;
                        "' usada fora dela - a captura mudaria de alvo; recusando" )
      ENDIF
      cWhy := TokenSpell( hAst, hTarget, nFuncEnd, hVar[ "sym" ] )   // grafia original
      IF ! hVar[ "param" ] .AND. ! hVar[ "before" ] .AND. ! hVar[ "after" ] .AND. ;
         hVar[ "declLine" ] < nFirst .AND. ;
         DeclCutRange( hAst, aSrc, hVar[ "declLine" ], hVar[ "sym" ] ) != NIL
         // local usada só dentro da seleção: a declaração migra para a
         // função nova (ficar para trás quebra o build -w3/-es2 do projeto)
         AAdd( aMoved, { hVar[ "declLine" ], hVar[ "sym" ], cWhy } )
         LOOP
      ENDIF
      IF VarWrittenIn( hVar ) .AND. hVar[ "after" ]
         IF ! Empty( cOut )
            RETURN Refuse( "mais de uma variável modificada e usada depois da seleção ('" + ;
                           cOut + "' e '" + cWhy + "') - recusando" )
         ENDIF
         cOut := cWhy
         lOutParam := !( hVar[ "firstIn" ] == "write" )
         IF lOutParam
            AAdd( aParams, cWhy )
         ENDIF
      ELSE
         AAdd( aParams, cWhy )
      ENDIF
   NEXT

   // texto novo das linhas de declaração afetadas (agrupado por linha:
   // duas migrações na mesma linha são cortes sucessivos, e a linha cai
   // inteira quando todas as declarações dela migram)
   hMovedLines := { => }
   FOR nI := 1 TO Len( aMoved )
      IF ! aMoved[ nI ][ 1 ] $ hMovedLines
         hMovedLines[ aMoved[ nI ][ 1 ] ] := {}
      ENDIF
      AAdd( hMovedLines[ aMoved[ nI ][ 1 ] ], aMoved[ nI ][ 2 ] )
   NEXT
   FOR EACH nI IN hb_HKeys( hMovedLines )         // reuso: nI = linha
      hMovedLines[ nI ] := BuildDeclLine( hAst, hTarget, aSrc, nI, hMovedLines[ nI ] )
      IF hMovedLines[ nI ] == NIL
         RETURN Refuse( "não consegui editar com segurança a declaração da linha " + hb_ntos( nI ) )
      ENDIF
   NEXT

   // montagem: chamada no lugar da seleção + função nova no fim do arquivo
   cEol := iif( Chr( 13 ) + Chr( 10 ) $ cText, Chr( 13 ) + Chr( 10 ), Chr( 10 ) )
   cIndent := Space( Len( aSrc[ nFirst ] ) - Len( LTrim( aSrc[ nFirst ] ) ) )
   cCall := cIndent + iif( Empty( cOut ), "", cOut + " := " ) + cNewName + ;
            iif( Empty( aParams ), "()", "( " + ArrJoin( aParams, ", " ) + " )" )

   cNewFunc := cEol + iif( Empty( cOut ), "STATIC PROCEDURE ", "STATIC FUNCTION " ) + ;
               cNewName + iif( Empty( aParams ), "()", "( " + ArrJoin( aParams, ", " ) + " )" ) + ;
               cEol + cEol
   IF ! Empty( cOut ) .AND. ! lOutParam
      cNewFunc += "   LOCAL " + cOut + cEol + cEol
   ENDIF
   IF ! Empty( aMoved )
      cNewFunc += "   LOCAL "
      FOR nI := 1 TO Len( aMoved )
         cNewFunc += iif( nI == 1, "", ", " ) + aMoved[ nI ][ 3 ]
      NEXT
      cNewFunc += cEol + cEol
   ENDIF
   FOR nI := nFirst TO nLast
      cNewFunc += aSrc[ nI ] + cEol
   NEXT
   cNewFunc += cEol + "   RETURN" + iif( Empty( cOut ), "", " " + cOut ) + cEol

   OutStd( "extract-function: linhas " + hb_ntos( nFirst ) + "-" + hb_ntos( nLast ) + ;
           " de " + hTarget[ "name" ] + " -> " + cNewName + ;
           "( " + ArrJoin( aParams, ", " ) + " )" + ;
           iif( Empty( cOut ), "", " retornando " + cOut ) + hb_eol() )
   FOR nI := 1 TO Len( aMoved )
      OutStd( "  LOCAL " + aMoved[ nI ][ 3 ] + " (linha " + hb_ntos( aMoved[ nI ][ 1 ] ) + ;
              ") só é usada na seleção - migra para " + cNewName + hb_eol() )
   NEXT
   IF lDryRun
      OutStd( "dry run - nada foi escrito" + hb_eol() )
      RETURN EXIT_OK
   ENDIF

   IF ! CompileHrbAll( hProj, cTmp, "before" )
      RETURN Refuse( "falha ao compilar o estado de referência" )
   ENDIF

   cTextNew := ReplaceLines( cText, nFirst, nLast, cCall, cEol ) + cNewFunc
   // migra as declarações das locais só-da-seleção (de baixo para cima:
   // linha removida desloca as de baixo; todas estão antes de nFirst)
   aVars := ASort( hb_HKeys( hMovedLines ),,, {| x, y | x > y } )   // reuso
   FOR nI := 1 TO Len( aVars )
      cTextNew := EditLine( cTextNew, aVars[ nI ], hMovedLines[ aVars[ nI ] ], cEol )
   NEXT
   hb_MemoWrit( cSrcPath, cTextNew )

   IF ! CompileHrbAll( hProj, cTmp, "after" )
      hb_MemoWrit( cSrcPath, cText )
      RETURN Refuse( "o projeto parou de compilar após a extração - rollback" )
   ENDIF
   FOR EACH cPath IN hProj[ "files" ]
      cWhy := ""
      IF cPath == cSrcPath
         IF ! HrbExtractCheck( hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cPath ) + ".before.hrb" ), ;
                               hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cPath ) + ".after.hrb" ), ;
                               cUpNew, @cWhy )
            hb_MemoWrit( cSrcPath, cText )
            RETURN Refuse( "verificação FALHOU: " + cWhy + " - rollback" )
         ENDIF
      ELSEIF !( hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cPath ) + ".before.hrb" ) == ;
                hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cPath ) + ".after.hrb" ) )
         hb_MemoWrit( cSrcPath, cText )
         RETURN Refuse( "verificação FALHOU: módulo não-editado mudou - rollback" )
      ENDIF
   NEXT

   OutStd( "verified: símbolos preservados (+" + cNewName + "); rode sua suíte para confirmar comportamento" + hb_eol() )

   RETURN EXIT_OK

// pares { kind, linhaOpen, linhaClose } dos eventos de bloco do compilador
// (pilha na ordem de parse; open/close da mesma kind casam por construção)
STATIC FUNCTION BlockPairs( hFunc )

   LOCAL aPairs := {}, aStack := {}, hEv

   FOR EACH hEv IN hFunc[ "blocks" ]
      IF hEv[ "event" ] == "open"
         AAdd( aStack, { hEv[ "kind" ], hEv[ "line" ] } )
      ELSEIF ! Empty( aStack )
         AAdd( aPairs, { ATail( aStack )[ 1 ], ATail( aStack )[ 2 ], hEv[ "line" ] } )
         ASize( aStack, Len( aStack ) - 1 )
      ENDIF
   NEXT

   RETURN aPairs

// EXIT/LOOP/BREAK na linha nLine é coberto se algum par das kinds pedidas
// o envolve e está INTEIRO dentro da seleção
STATIC FUNCTION JumpCovered( aPairs, nLine, nFirst, nLast, aKinds )

   LOCAL aP

   FOR EACH aP IN aPairs
      IF hb_AScan( aKinds, aP[ 1 ],,, .T. ) > 0 .AND. ;
         aP[ 2 ] <= nLine .AND. aP[ 3 ] >= nLine .AND. ;
         aP[ 2 ] >= nFirst .AND. aP[ 3 ] <= nLast
         RETURN .T.
      ENDIF
   NEXT

   RETURN .F.

STATIC FUNCTION ExprHasEt( hExpr, cEt )

   LOCAL xVal, hKid

   IF ! HB_ISHASH( hExpr )
      RETURN .F.
   ENDIF
   IF hb_HGetDef( hExpr, "et", "" ) == cEt
      RETURN .T.
   ENDIF
   FOR EACH xVal IN hb_HValues( hExpr )
      IF HB_ISHASH( xVal )
         IF ExprHasEt( xVal, cEt )
            RETURN .T.
         ENDIF
      ELSEIF HB_ISARRAY( xVal )
         FOR EACH hKid IN xVal
            IF HB_ISHASH( hKid ) .AND. ExprHasEt( hKid, cEt )
               RETURN .T.
            ENDIF
         NEXT
      ENDIF
   NEXT

   RETURN .F.

STATIC FUNCTION VarWrittenIn( hVar )

   LOCAL hOcc

   FOR EACH hOcc IN hVar[ "in" ]
      IF !( hOcc[ "access" ] == "read" )   // write, ref e use contam como escrita, pessimista
         RETURN .T.
      ENDIF
   NEXT

   RETURN .F.

// grafia original de um símbolo: primeiro token identificador do span da
// função com esse nome (o dump normaliza declarations/occurrences p/ upper)
STATIC FUNCTION TokenSpell( hAst, hFunc, nFuncEnd, cSym )

   LOCAL hTok, cUp := Upper( cSym )

   FOR EACH hTok IN hAst[ "tokens" ]
      IF hTok[ "type" ] == 21 .AND. hTok[ "prov" ] == "s" .AND. ;
         hTok[ "line" ] >= hFunc[ "line" ] .AND. hTok[ "line" ] <= nFuncEnd .AND. ;
         Upper( hTok[ "text" ] ) == cUp
         RETURN hTok[ "text" ]
      ENDIF
   NEXT

   RETURN cSym

// LOCAL declarada fora da seleção mas usada só dentro: a declaração pode
// migrar quando a VIZINHANÇA do nome na linha é trivial - decisão POR
// VARIÁVEL, então `LOCAL nI, cI, cRet := ""` libera nI e cI mesmo com o
// inicializador de cRet na mesma linha. Devolve a faixa de bytes a cortar
// { de, até } (1-based, inclusiva), "" quando a variável é a única
// declaração da linha (linha inteira cai), ou NIL quando não é seguro
// (inicializador NO nome, continuação ';', comentário atrás, mais de um
// token com o nome) - a variável então vira parâmetro (fallback
// conservador). Posições byte-exatas dos tokens; o texto só valida os vãos.
STATIC FUNCTION DeclCutRange( hAst, aSrc, nLine, cSym )

   LOCAL hTok, aLine := {}, nHits := 0, nHitAt := 0
   LOCAL cLine, cUp := Upper( cSym ), nEnd, nStartNext, nEndPrev

   IF nLine <= 0 .OR. nLine > Len( aSrc )
      RETURN NIL
   ENDIF
   cLine := aSrc[ nLine ]

   // tokens POSICIONADOS da linha, em ordem de coluna (vírgulas e ':='
   // nunca têm coluna - os vãos entre vizinhos são validados no texto)
   FOR EACH hTok IN hAst[ "tokens" ]
      IF hTok[ "line" ] == nLine .AND. hTok[ "col" ] != NIL
         AAdd( aLine, hTok )
      ENDIF
   NEXT
   ASort( aLine,,, {| x, y | x[ "col" ] < y[ "col" ] } )
   FOR EACH hTok IN aLine
      IF hTok[ "type" ] == 21 .AND. Upper( hTok[ "text" ] ) == cUp
         nHits++
         nHitAt := hTok:__enumIndex()
      ENDIF
   NEXT
   IF nHits != 1 .OR. nHitAt < 2 .OR. ;
      ! ( aLine[ 1 ][ "type" ] == 21 .AND. Upper( aLine[ 1 ][ "text" ] ) == "LOCAL" ) .OR. ;
      ! Empty( Left( cLine, aLine[ 1 ][ "col" ] ) )      // nada antes do LOCAL
      RETURN NIL
   ENDIF

   nEnd := aLine[ nHitAt ][ "col" ] + aLine[ nHitAt ][ "len" ]     // fim 1-based
   IF nHitAt == 2
      // primeira da lista: o vão LOCAL->nome deve ser só espaço
      IF ! GapOnlySpace( cLine, aLine[ 1 ][ "col" ] + aLine[ 1 ][ "len" ] + 1, aLine[ 2 ][ "col" ] )
         RETURN NIL
      ENDIF
   ENDIF
   IF nHitAt < Len( aLine )
      // tem vizinho à direita: o vão deve ser espaços + UMA vírgula (sem
      // ':=', sem ')', sem nada) - corta [nome .. antes-do-próximo)
      nStartNext := aLine[ nHitAt + 1 ][ "col" ] + 1
      IF ! GapOneComma( cLine, nEnd + 1, nStartNext - 1 )
         RETURN NIL
      ENDIF
      RETURN { aLine[ nHitAt ][ "col" ] + 1, nStartNext - 1 }
   ENDIF
   // última da linha: nada além de espaço depois dela (comentário ou ';'
   // de continuação barram a migração)
   IF ! Empty( RTrim( SubStr( cLine, nEnd + 1 ) ) )
      RETURN NIL
   ENDIF
   IF nHitAt == 2
      RETURN ""                                   // única variável da linha
   ENDIF
   // corta [depois-do-anterior .. fim-do-nome], levando a vírgula junto
   nEndPrev := aLine[ nHitAt - 1 ][ "col" ] + aLine[ nHitAt - 1 ][ "len" ]
   IF ! GapOneComma( cLine, nEndPrev + 1, aLine[ nHitAt ][ "col" ] )
      RETURN NIL
   ENDIF

   RETURN { nEndPrev + 1, nEnd }

STATIC FUNCTION GapOnlySpace( cLine, nFrom, nTo )

   LOCAL nI, cCh

   FOR nI := nFrom TO nTo
      cCh := SubStr( cLine, nI, 1 )
      IF !( cCh == " " .OR. cCh == Chr( 9 ) )
         RETURN .F.
      ENDIF
   NEXT

   RETURN .T.

STATIC FUNCTION GapOneComma( cLine, nFrom, nTo )

   LOCAL nI, cCh, nCommas := 0

   FOR nI := nFrom TO nTo
      cCh := SubStr( cLine, nI, 1 )
      DO CASE
      CASE cCh == ","
         nCommas++
      CASE !( cCh == " " .OR. cCh == Chr( 9 ) )
         RETURN .F.
      ENDCASE
   NEXT

   RETURN nCommas == 1

// texto novo de uma linha de declaração da qual os aSyms migram: "" quando
// TODAS as declarações da linha migram (a linha cai inteira); senão aplica
// os cortes individuais da direita para a esquerda
STATIC FUNCTION BuildDeclLine( hAst, hTarget, aSrc, nLine, aSyms )

   LOCAL hItem, nDecls := 0, aCuts := {}, xCut, cLine, nI

   FOR EACH hItem IN hTarget[ "declarations" ]
      IF hItem[ "declLine" ] == nLine
         nDecls++
      ENDIF
   NEXT
   IF Len( aSyms ) == nDecls
      RETURN ""
   ENDIF
   FOR EACH hItem IN aSyms                        // reuso: hItem = nome
      xCut := DeclCutRange( hAst, aSrc, nLine, hItem )
      IF ! HB_ISARRAY( xCut )
         RETURN NIL
      ENDIF
      AAdd( aCuts, xCut )
   NEXT
   ASort( aCuts,,, {| x, y | x[ 1 ] > y[ 1 ] } )
   cLine := aSrc[ nLine ]
   FOR nI := 1 TO Len( aCuts )
      cLine := Left( cLine, aCuts[ nI ][ 1 ] - 1 ) + SubStr( cLine, aCuts[ nI ][ 2 ] + 1 )
   NEXT

   RETURN cLine

STATIC FUNCTION LineOffsets( cText )

   LOCAL aOffs := { 1 }, nI

   FOR nI := 1 TO hb_BLen( cText )
      IF hb_BSubStr( cText, nI, 1 ) == Chr( 10 )
         AAdd( aOffs, nI + 1 )
      ENDIF
   NEXT

   RETURN aOffs

STATIC FUNCTION ReplaceLines( cText, nFirst, nLast, cNewLine, cEol )

   LOCAL aOffs := LineOffsets( cText )
   LOCAL nStart := aOffs[ nFirst ]
   LOCAL nEnd := iif( nLast + 1 <= Len( aOffs ), aOffs[ nLast + 1 ], hb_BLen( cText ) + 1 )

   RETURN hb_BLeft( cText, nStart - 1 ) + cNewLine + cEol + hb_BSubStr( cText, nEnd )

// troca o conteúdo de uma linha, ou apaga a linha quando cNew é vazio
STATIC FUNCTION EditLine( cText, nLine, cNew, cEol )

   LOCAL aOffs := LineOffsets( cText )
   LOCAL nStart := aOffs[ nLine ]
   LOCAL nEnd := iif( nLine + 1 <= Len( aOffs ), aOffs[ nLine + 1 ], hb_BLen( cText ) + 1 )

   RETURN hb_BLeft( cText, nStart - 1 ) + iif( Empty( cNew ), "", cNew + cEol ) + ;
          hb_BSubStr( cText, nEnd )

// pós-extração o módulo mantém todos os símbolos/funções que tinha (mesmos
// escopos) mais exatamente a função nova; casamento por nome porque o ponto
// de inserção desloca a ordem posicional
STATIC FUNCTION HrbExtractCheck( cBefore, cAfter, cUpNew, cWhy )

   LOCAL hB := HrbParse( cBefore ), hA := HrbParse( cAfter )
   LOCAL nI, nJ, lFound

   cWhy := ""
   IF hB == NIL .OR. hA == NIL
      cWhy := "não consegui ler o .hrb"
      RETURN .F.
   ENDIF
   IF Len( hA[ "syms" ] ) != Len( hB[ "syms" ] ) + 1 .OR. ;
      Len( hA[ "funcs" ] ) != Len( hB[ "funcs" ] ) + 1
      cWhy := "esperava exatamente um símbolo e uma função novos"
      RETURN .F.
   ENDIF
   FOR nI := 1 TO Len( hB[ "syms" ] )
      lFound := .F.
      FOR nJ := 1 TO Len( hA[ "syms" ] )
         IF hA[ "syms" ][ nJ ][ 1 ] == hB[ "syms" ][ nI ][ 1 ] .AND. ;
            hA[ "syms" ][ nJ ][ 2 ] == hB[ "syms" ][ nI ][ 2 ]
            lFound := .T.
            EXIT
         ENDIF
      NEXT
      IF ! lFound
         cWhy := "símbolo perdido ou alterado: " + hB[ "syms" ][ nI ][ 1 ]
         RETURN .F.
      ENDIF
   NEXT
   lFound := .F.
   FOR nJ := 1 TO Len( hA[ "syms" ] )
      IF hA[ "syms" ][ nJ ][ 1 ] == cUpNew
         lFound := .T.
         EXIT
      ENDIF
   NEXT
   IF ! lFound
      cWhy := "símbolo novo " + cUpNew + " não encontrado"
      RETURN .F.
   ENDIF

   RETURN .T.

// ---------------------------------------------------------------------------
// inline-local - substitui os usos de uma LOCAL pela sua expressão de
// inicialização e remove a declaração. A expressão é duplicada e reavaliada
// em cada uso, então a ANÁLISE DE PUREZA é o portão: só folhas literais/
// variáveis e operadores puros (allowlist da árvore de expressão do
// compilador); qualquer FUNCALL/SEND/MACRO/ARRAYAT/atribuição embutida
// recusa. As variáveis da expressão não podem ser reescritas depois do
// próprio init. Verificação: símbolos/funções intactos (o pcode muda
// legitimamente) + demais módulos byte-idênticos + rollback.
// ---------------------------------------------------------------------------

STATIC FUNCTION InlineLocal( aArgs )

   LOCAL cSpec, cFile, cFunc, cName, lDryRun := .F.
   LOCAL hProj, cTmp, cSrcPath, hAst, hFunc, hItem, hTok, aPrev, cPrevType
   LOCAL hDecl := NIL, nDeclLine, lInit := .F., nReads := 0, nI
   LOCAL hInit := NIL, hExpr, cWhy := "", aVarsExpr, cVar, nDeclsOnLine := 0
   LOCAL aToks, iName := 0, iA, iB, aSpan, cExpr, cRepl, nSpanEnd
   LOCAL aSrc, cText, aEdits := {}, cUp, nLine

   IF Len( aArgs ) < 5
      Usage()
      RETURN EXIT_USAGE
   ENDIF
   cSpec := aArgs[ 2 ]
   cFile := aArgs[ 3 ]
   cFunc := aArgs[ 4 ]
   cName := aArgs[ 5 ]
   FOR nI := 6 TO Len( aArgs )
      IF Lower( aArgs[ nI ] ) == "--dry-run"
         lDryRun := .T.
      ENDIF
   NEXT
   cUp := Upper( cName )

   hProj := LoadProject( cSpec )
   IF hProj == NIL
      RETURN Refuse( "não consegui resolver o projeto '" + cSpec + "'" )
   ENDIF
   cSrcPath := ProjectMember( hProj, cFile )
   IF cSrcPath == ""
      RETURN Refuse( "'" + cFile + "' não é fonte do projeto '" + cSpec + "'" )
   ENDIF

   cTmp := WorkDir()
   IF ! AstDumps( hProj, cTmp )
      RETURN Refuse( "o projeto não compila - corrija os erros de build primeiro" )
   ENDIF
   hAst := ReadAst( cTmp, cSrcPath )
   IF hAst == NIL
      RETURN Refuse( "dump ast-1 ausente/inválido para '" + cSrcPath + "'" )
   ENDIF
   hFunc := PickFunc( hAst, cFunc )
   IF hFunc == NIL
      RETURN Refuse( "função '" + cFunc + "' não encontrada em '" + cFile + "'" )
   ENDIF

   cText := hb_MemoRead( cSrcPath )
   aSrc := hb_ATokens( StrTran( cText, Chr( 13 ), "" ), Chr( 10 ) )
   hAst[ "__src" ] := aSrc

   // alvo: LOCAL não-parâmetro declarada na função
   FOR EACH hItem IN hFunc[ "declarations" ]
      IF Upper( hItem[ "sym" ] ) == cUp .AND. hItem[ "scope" ] == "local"
         hDecl := hItem
      ENDIF
   NEXT
   IF hDecl == NIL
      RETURN Refuse( "'" + cName + "' não é LOCAL declarada em " + hFunc[ "name" ] )
   ENDIF
   IF hDecl[ "param" ]
      RETURN Refuse( "'" + cName + "' é parâmetro - sem expressão de init para inline" )
   ENDIF
   nDeclLine := hDecl[ "declLine" ]
   FOR EACH hItem IN hFunc[ "declarations" ]
      IF hItem[ "declLine" ] == nDeclLine
         nDeclsOnLine++
      ENDIF
   NEXT
   IF nDeclsOnLine != 1
      RETURN Refuse( "a declaração de '" + cName + "' compartilha a linha " + ;
                     hb_ntos( nDeclLine ) + " com outras - recusando" )
   ENDIF

   // usos: só leituras simples fora de codeblock; a única escrita é o init
   FOR EACH hItem IN hFunc[ "occurrences" ]
      IF Upper( hItem[ "sym" ] ) == cUp
         DO CASE
         CASE hItem[ "block" ]
            RETURN Refuse( "'" + cName + "' é usada/capturada em codeblock (linha " + ;
                           hb_ntos( hItem[ "line" ] ) + ") - inline mudaria a captura" )
         CASE hItem[ "line" ] == nDeclLine .AND. hItem[ "access" ] == "write"
            lInit := .T.
         CASE hItem[ "access" ] == "read"
            nReads++
         OTHERWISE
            RETURN Refuse( "'" + cName + "' é " + hItem[ "access" ] + " na linha " + ;
                           hb_ntos( hItem[ "line" ] ) + " - só leituras permitem inline" )
         ENDCASE
      ENDIF
   NEXT
   IF ! lInit
      RETURN Refuse( "'" + cName + "' não tem inicializador na declaração" )
   ENDIF
   IF nReads == 0
      RETURN Refuse( "'" + cName + "' não tem leituras - use unused-locals" )
   ENDIF

   // nome citado em string no módulo (stringify de pp/call-by-name): a
   // verificação de símbolos não pegaria a troca - recusa. SEM filtro de
   // linha: o token do stringify nasce sintetizado com line 0/prov 'n'
   FOR EACH hTok IN hAst[ "tokens" ]
      IF hTok[ "type" ] == 41 .AND. Upper( hTok[ "text" ] ) == cUp
         RETURN Refuse( "string igual a '" + cName + "'" + ;
                        iif( hTok[ "line" ] > 0, " na linha " + hb_ntos( hTok[ "line" ] ), ;
                             " gerada por regra de pp" ) + ;
                        " (stringify/chamada por nome) - recusando" )
      ENDIF
   NEXT

   // init = statement ASSIGN da linha da declaração com left = a variável
   FOR EACH hItem IN hFunc[ "statements" ]
      IF hItem[ "line" ] == nDeclLine .AND. ! hItem[ "block" ] .AND. ;
         HB_ISHASH( hItem[ "expr" ] ) .AND. hItem[ "expr" ][ "et" ] == "ASSIGN" .AND. ;
         HB_ISHASH( hItem[ "expr" ][ "left" ] ) .AND. ;
         hb_HGetDef( hItem[ "expr" ][ "left" ], "val", "" ) == cUp
         hInit := hItem
      ENDIF
   NEXT
   IF hInit == NIL
      RETURN Refuse( "não encontrei o statement de init de '" + cName + "'" )
   ENDIF
   hExpr := hInit[ "expr" ][ "right" ]

   IF ! ExprPure( hExpr, @cWhy )
      RETURN Refuse( "expressão de init impura/não-duplicável (" + cWhy + ") - recusando" )
   ENDIF
   // variáveis da expressão: nenhuma pode ser reescrita fora do próprio init
   aVarsExpr := {}
   ExprVars( hExpr, aVarsExpr )
   FOR EACH cVar IN aVarsExpr
      FOR EACH hItem IN hFunc[ "occurrences" ]
         IF Upper( hItem[ "sym" ] ) == cVar .AND. ! hItem[ "access" ] == "read"
            // a única escrita tolerada é o init da própria variável
            IF ! ( hItem[ "access" ] == "write" .AND. ! hItem[ "block" ] .AND. ;
                   hItem[ "line" ] == VarDeclLine( hFunc, cVar ) )
               RETURN Refuse( "'" + cVar + "' (usada na expressão) é reescrita na linha " + ;
                              hb_ntos( hItem[ "line" ] ) + " - o valor de '" + cName + ;
                              "' não é estável" )
            ENDIF
         ENDIF
      NEXT
   NEXT

   // texto da expressão: fatia do stream depois de nome+':=' até o fim da
   // linha da declaração (declaração continuada por ';' recusa)
   IF Right( RTrim( aSrc[ nDeclLine ] ), 1 ) == ";"
      RETURN Refuse( "declaração continuada por ';' - recusando" )
   ENDIF
   aToks := hAst[ "tokens" ]
   FOR nI := 1 TO Len( aToks )
      IF aToks[ nI ][ "line" ] == nDeclLine .AND. aToks[ nI ][ "type" ] == 21 .AND. ;
         aToks[ nI ][ "col" ] != NIL .AND. Upper( aToks[ nI ][ "text" ] ) == cUp
         iName := nI
         EXIT
      ENDIF
   NEXT
   IF iName == 0 .OR. iName + 2 > Len( aToks ) .OR. ! aToks[ iName + 1 ][ "text" ] == ":="
      RETURN Refuse( "init de '" + cName + "' com formato inesperado na linha " + hb_ntos( nDeclLine ) )
   ENDIF
   iA := iName + 2
   iB := iA
   DO WHILE iB + 1 <= Len( aToks ) .AND. aToks[ iB + 1 ][ "line" ] == nDeclLine
      iB++
   ENDDO
   aSpan := BuildArgSpan( hAst, iA, iB, @cWhy )
   IF aSpan == NIL
      RETURN Refuse( cWhy + " - não consegui recortar a expressão (linha " + ;
                     hb_ntos( nDeclLine ) + "; um #define no init não tem posição no fonte)" )
   ENDIF
   cExpr := aSpan[ 3 ]
   // nada (comentário) depois da expressão: a linha inteira vai cair
   IF ! Empty( RTrim( SubStr( aSrc[ nDeclLine ], aSpan[ 2 ] + Len( cExpr ) ) ) )
      RETURN Refuse( "comentário/resto depois do init na linha " + hb_ntos( nDeclLine ) + ;
                     " se perderia - recusando" )
   ENDIF
   cRepl := iif( iB > iA, "( " + cExpr + " )", cExpr )

   // sites de leitura: tokens do span da função fora da linha da declaração
   nSpanEnd := 0
   FOR EACH hItem IN hAst[ "functions" ]
      IF ! hItem[ "fileDecl" ] .AND. hItem[ "line" ] > hFunc[ "line" ] .AND. ;
         ( nSpanEnd == 0 .OR. hItem[ "line" ] < nSpanEnd )
         nSpanEnd := hItem[ "line" ]
      ENDIF
   NEXT
   aPrev := NIL
   FOR EACH hTok IN aToks
      cPrevType := iif( aPrev == NIL, 0, aPrev[ "type" ] )
      IF hTok[ "type" ] == 21 .AND. hTok[ "prov" ] == "s" .AND. ;
         hTok[ "line" ] >= hFunc[ "line" ] .AND. hTok[ "line" ] != nDeclLine .AND. ;
         ( nSpanEnd == 0 .OR. hTok[ "line" ] < nSpanEnd ) .AND. ;
         Upper( hTok[ "text" ] ) == cUp .AND. ;
         !( cPrevType == 58 .OR. cPrevType == 59 )
         IF hTok[ "col" ] == NIL
            RETURN Refuse( "uso na linha " + hb_ntos( hTok[ "line" ] ) + ;
                           " sem posição confiável (reescrita de pp) - recusando" )
         ENDIF
         AAdd( aEdits, { hTok[ "line" ], hTok[ "col" ] + 1, hTok[ "text" ], cRepl } )
      ENDIF
      aPrev := hTok
   NEXT
   IF Len( aEdits ) != nReads
      RETURN Refuse( "usos no fonte (" + hb_ntos( Len( aEdits ) ) + ") não casam com as " + ;
                     "leituras do compilador (" + hb_ntos( nReads ) + ") - recusando" )
   ENDIF

   OutStd( "inline-local: " + cName + " := " + cExpr + " em " + hFunc[ "name" ] + ;
           " (" + hb_FNameNameExt( cSrcPath ) + ")" + hb_eol() )
   FOR nI := 1 TO Len( aEdits )
      OutStd( "  " + hb_FNameNameExt( cSrcPath ) + ":" + hb_ntos( aEdits[ nI ][ 1 ] ) + ;
              ":" + hb_ntos( aEdits[ nI ][ 2 ] ) + hb_eol() )
   NEXT
   OutStd( "  declaração da linha " + hb_ntos( nDeclLine ) + " removida" + hb_eol() )
   IF lDryRun
      OutStd( "dry run - nada foi escrito" + hb_eol() )
      RETURN EXIT_OK
   ENDIF

   IF ! CompileHrbAll( hProj, cTmp, "before" )
      RETURN Refuse( "falha ao compilar o estado de referência" )
   ENDIF
   cSpec := ApplyRangeEdits( cText, aEdits, @nLine )          // reuso de cSpec
   IF nLine > 0
      RETURN Refuse( "texto na linha " + hb_ntos( nLine ) + " não confere com o esperado" )
   ENDIF
   cWhy := iif( Chr( 13 ) + Chr( 10 ) $ cText, Chr( 13 ) + Chr( 10 ), Chr( 10 ) )   // reuso: eol
   cSpec := EditLine( cSpec, nDeclLine, "", cWhy )
   // declaração era a única linha entre duas em branco: colapsa a sobra
   IF nDeclLine > 1 .AND. nDeclLine < Len( aSrc ) .AND. ;
      Empty( aSrc[ nDeclLine - 1 ] ) .AND. Empty( aSrc[ nDeclLine + 1 ] )
      cSpec := EditLine( cSpec, nDeclLine, "", cWhy )
   ENDIF
   hb_MemoWrit( cSrcPath, cSpec )

   IF ! CompileHrbAll( hProj, cTmp, "after" )
      hb_MemoWrit( cSrcPath, cText )
      RETURN Refuse( "o projeto parou de compilar após o inline - rollback" )
   ENDIF
   FOR EACH cSpec IN hProj[ "files" ]                          // reuso
      IF cSpec == cSrcPath
         IF ! HrbSymbolsEqual( hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cSpec ) + ".before.hrb" ), ;
                               hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cSpec ) + ".after.hrb" ), @cWhy )
            hb_MemoWrit( cSrcPath, cText )
            RETURN Refuse( "verificação FALHOU: " + cWhy + " - rollback" )
         ENDIF
      ELSEIF !( hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cSpec ) + ".before.hrb" ) == ;
                hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cSpec ) + ".after.hrb" ) )
         hb_MemoWrit( cSrcPath, cText )
         RETURN Refuse( "verificação FALHOU: módulo não-editado mudou - rollback" )
      ENDIF
   NEXT
   OutStd( "verified: " + hb_ntos( nReads ) + " uso(s) substituídos; símbolos intactos; " + ;
           "rode sua suíte para confirmar comportamento" + hb_eol() )

   RETURN EXIT_OK

// pureza p/ duplicação: allowlist da árvore do compilador - folhas
// literais/variáveis e operadores sem efeito colateral; QUALQUER outro nó
// (FUNCALL, SEND, MACRO, ARRAYAT, atribuições, ++/--, ARRAY/HASH que criam
// identidade nova, codeblock) recusa
STATIC FUNCTION ExprPure( hExpr, cWhy )

   STATIC s_aLeaf := { "NIL", "NUMERIC", "DATE", "TIMESTAMP", "STRING", "LOGICAL", "VARIABLE" }
   STATIC s_aComb := { "IIF", "LIST", "OR", "AND", "NOT", "EQUAL", "EQ", "NE", "IN", ;
                       "LT", "GT", "LE", "GE", "PLUS", "MINUS", "MULT", "DIV", ;
                       "MOD", "POWER", "NEGATE" }
   LOCAL cEt, xVal, hKid

   IF ! HB_ISHASH( hExpr )
      RETURN .T.
   ENDIF
   cEt := hb_HGetDef( hExpr, "et", "?" )
   IF hb_AScan( s_aLeaf, cEt,,, .T. ) > 0
      RETURN .T.
   ENDIF
   IF hb_AScan( s_aComb, cEt,,, .T. ) == 0
      cWhy := cEt
      RETURN .F.
   ENDIF
   FOR EACH xVal IN hb_HValues( hExpr )
      IF HB_ISHASH( xVal )
         IF ! ExprPure( xVal, @cWhy )
            RETURN .F.
         ENDIF
      ELSEIF HB_ISARRAY( xVal )
         FOR EACH hKid IN xVal
            IF HB_ISHASH( hKid ) .AND. ! ExprPure( hKid, @cWhy )
               RETURN .F.
            ENDIF
         NEXT
      ENDIF
   NEXT

   RETURN .T.

STATIC PROCEDURE ExprVars( hExpr, aVars )

   LOCAL xVal, hKid

   IF ! HB_ISHASH( hExpr )
      RETURN
   ENDIF
   IF hb_HGetDef( hExpr, "et", "" ) == "VARIABLE" .AND. ;
      hb_AScan( aVars, Upper( hb_HGetDef( hExpr, "val", "" ) ),,, .T. ) == 0
      AAdd( aVars, Upper( hExpr[ "val" ] ) )
   ENDIF
   FOR EACH xVal IN hb_HValues( hExpr )
      IF HB_ISHASH( xVal )
         ExprVars( xVal, aVars )
      ELSEIF HB_ISARRAY( xVal )
         FOR EACH hKid IN xVal
            IF HB_ISHASH( hKid )
               ExprVars( hKid, aVars )
            ENDIF
         NEXT
      ENDIF
   NEXT

   RETURN

STATIC FUNCTION VarDeclLine( hFunc, cUpSym )

   LOCAL hItem

   FOR EACH hItem IN hFunc[ "declarations" ]
      IF Upper( hItem[ "sym" ] ) == cUpSym
         RETURN hItem[ "declLine" ]
      ENDIF
   NEXT

   RETURN 0

// ---------------------------------------------------------------------------
// relatórios (read-only)
// ---------------------------------------------------------------------------

STATIC FUNCTION UnusedLocals( aArgs )

   LOCAL hProj, cPath, cFlags := "", cTok, cOut, cErr, cLine, nFound := 0

   IF Len( aArgs ) < 2
      Usage()
      RETURN EXIT_USAGE
   ENDIF
   hProj := LoadProject( aArgs[ 2 ] )
   IF hProj == NIL
      RETURN Refuse( "não consegui resolver o projeto '" + aArgs[ 2 ] + "'" )
   ENDIF
   // análise do próprio compilador (W0003/W0032); -w/-es do projeto saem
   // para o -w3 desta análise não virar erro de build
   FOR EACH cTok IN hProj[ "flags" ]
      IF ! Left( cTok, 2 ) == "-w" .AND. ! Left( cTok, 3 ) == "-es"
         cFlags += " " + cTok
      ENDIF
   NEXT
   FOR EACH cPath IN hProj[ "files" ]
      cOut := cErr := ""
      IF hb_processRun( HarbourBin() + " " + cPath + " -q0 -w3 -s" + cFlags,, @cOut, @cErr ) != 0
         OutErr( "hbrefactor: " + cPath + " não compila:" + hb_eol() + ErrLines( cOut + cErr ) )
         RETURN Refuse( "'" + cPath + "' não compila" )
      ENDIF
      FOR EACH cLine IN hb_ATokens( StrTran( cOut + cErr, Chr( 13 ), "" ), Chr( 10 ) )
         IF "W0003" $ cLine .OR. "W0032" $ cLine
            nFound++
            OutStd( AllTrim( cLine ) + hb_eol() )
         ENDIF
      NEXT
   NEXT
   OutStd( hb_ntos( nFound ) + " finding(s)" + hb_eol() )

   RETURN EXIT_OK

STATIC FUNCTION CallGraph( aArgs )

   LOCAL hProj, cTmp, cPath, hAst, hFunc, hItem
   LOCAL cFilter := "", hDefined := { => }, hSeen, cKey, cCallee

   IF Len( aArgs ) < 2
      Usage()
      RETURN EXIT_USAGE
   ENDIF
   hProj := LoadProject( aArgs[ 2 ] )
   IF hProj == NIL
      RETURN Refuse( "não consegui resolver o projeto '" + aArgs[ 2 ] + "'" )
   ENDIF
   IF Len( aArgs ) >= 3
      cFilter := Upper( aArgs[ 3 ] )
   ENDIF
   cTmp := WorkDir()
   IF ! AstDumps( hProj, cTmp )
      RETURN Refuse( "o projeto não compila" )
   ENDIF
   FOR EACH cPath IN hProj[ "files" ]
      hAst := ReadAst( cTmp, cPath )
      IF hAst == NIL
         RETURN Refuse( "dump ausente para '" + cPath + "'" )
      ENDIF
      FOR EACH hFunc IN hAst[ "functions" ]
         IF ! hFunc[ "fileDecl" ]
            hDefined[ Upper( hFunc[ "name" ] ) ] := hb_FNameNameExt( cPath )
         ENDIF
      NEXT
   NEXT
   FOR EACH cPath IN hProj[ "files" ]
      hAst := ReadAst( cTmp, cPath )
      FOR EACH hFunc IN hAst[ "functions" ]
         IF hFunc[ "fileDecl" ]
            LOOP
         ENDIF
         hSeen := { => }
         FOR EACH hItem IN hFunc[ "calls" ]
            cCallee := Upper( hItem[ "sym" ] )
            cKey := Upper( hFunc[ "name" ] ) + ">" + cCallee
            IF cKey $ hSeen
               LOOP
            ENDIF
            hSeen[ cKey ] := .T.
            IF Empty( cFilter ) .OR. Upper( hFunc[ "name" ] ) == cFilter .OR. cCallee == cFilter
               OutStd( hb_FNameNameExt( cPath ) + ": " + hFunc[ "name" ] + " -> " + hItem[ "sym" ] + ;
                  iif( cCallee $ hDefined, "  [" + hDefined[ cCallee ] + "]", "  [external]" ) + hb_eol() )
            ENDIF
         NEXT
      NEXT
   NEXT

   RETURN EXIT_OK

STATIC FUNCTION FindDynamicCalls( aArgs )

   LOCAL hProj, cTmp, cPath, hAst, hFunc, hItem
   LOCAL hDefined := { => }, nFound := 0, aSrc

   IF Len( aArgs ) < 2
      Usage()
      RETURN EXIT_USAGE
   ENDIF
   hProj := LoadProject( aArgs[ 2 ] )
   IF hProj == NIL
      RETURN Refuse( "não consegui resolver o projeto '" + aArgs[ 2 ] + "'" )
   ENDIF
   cTmp := WorkDir()
   IF ! AstDumps( hProj, cTmp )
      RETURN Refuse( "o projeto não compila" )
   ENDIF
   FOR EACH cPath IN hProj[ "files" ]
      hAst := ReadAst( cTmp, cPath )
      IF hAst == NIL
         RETURN Refuse( "dump ausente para '" + cPath + "'" )
      ENDIF
      FOR EACH hFunc IN hAst[ "functions" ]
         IF ! hFunc[ "fileDecl" ]
            hDefined[ Upper( hFunc[ "name" ] ) ] := hb_FNameNameExt( cPath )
         ENDIF
      NEXT
   NEXT
   FOR EACH cPath IN hProj[ "files" ]
      hAst := ReadAst( cTmp, cPath )
      aSrc := hb_ATokens( StrTran( hb_MemoRead( cPath ), Chr( 13 ), "" ), Chr( 10 ) )
      // strings do stream do compilador que são identificadores de funções
      // do projeto (possível Do()/dispatch por nome)
      FOR EACH hItem IN hAst[ "tokens" ]
         // nome ∈ funções do projeto (fato do compilador) já implica
         // identificador - sem cheque próprio de gramática
         IF hItem[ "type" ] == 41 .AND. hItem[ "line" ] > 0 .AND. ;
            Upper( hItem[ "text" ] ) $ hDefined
            nFound++
            OutStd( hb_FNameNameExt( cPath ) + ":" + hb_ntos( hItem[ "line" ] ) + ;
               ": string '" + hItem[ "text" ] + "' names a project function [" + ;
               hDefined[ Upper( hItem[ "text" ] ) ] + "]" + SrcLine( aSrc, hItem[ "line" ] ) + hb_eol() )
         ENDIF
      NEXT
      FOR EACH hFunc IN hAst[ "functions" ]
         IF ! hFunc[ "fileDecl" ] .AND. hFunc[ "usesMacro" ]
            nFound++
            OutStd( hb_FNameNameExt( cPath ) + ":" + hb_ntos( hFunc[ "line" ] ) + ;
               ": function " + hFunc[ "name" ] + " uses & macros (dynamic names possible)" + hb_eol() )
         ENDIF
      NEXT
   NEXT
   OutStd( hb_ntos( nFound ) + " finding(s)" + hb_eol() )

   RETURN EXIT_OK

// ---------------------------------------------------------------------------
// reorder-params - reordena parâmetros na assinatura e os ARGUMENTOS em
// todos os call sites. Os argumentos vêm dos spans de token da árvore
// (FUNCALL -> parms.items[]): recorte por posição, INCLUSIVE call sites
// multi-linha (a era occ recusava). Aridade menor que a assinatura muda
// semântica (NIL implícito se moveria) -> recusa.
// Verificação: o pcode MUDA legitimamente (ordem de push) - o comparador
// exige símbolos e conjunto de funções intactos (HrbSymbolsEqual).
// ---------------------------------------------------------------------------

STATIC FUNCTION ReorderParams( aArgs )

   LOCAL cSpec, cFunc, cOrder, cOnlyFile := "", lForce := .F., lDryRun := .F.
   LOCAL hProj, cTmp, cPath, hAst, hAsts := { => }, hFunc, hItem, nI, nJ
   LOCAL cDefFile := "", hDef := NIL, aParams := {}, aNew, aPerm := {}
   LOCAL hEdits := { => }, aE, aWarn := {}, cText, hOrig := { => }
   LOCAL cUpFunc, aArgsSpans, aSigHits, nTotal := 0, cWhy

   IF Len( aArgs ) < 4
      Usage()
      RETURN EXIT_USAGE
   ENDIF
   cSpec  := aArgs[ 2 ]
   cFunc  := aArgs[ 3 ]
   cOrder := aArgs[ 4 ]
   FOR nI := 5 TO Len( aArgs )
      DO CASE
      CASE Lower( aArgs[ nI ] ) == "--force"
         lForce := .T.
      CASE Lower( aArgs[ nI ] ) == "--dry-run"
         lDryRun := .T.
      CASE Lower( aArgs[ nI ] ) == "--file" .AND. nI < Len( aArgs )
         cOnlyFile := aArgs[ ++nI ]
      ENDCASE
   NEXT
   cUpFunc := Upper( cFunc )

   hProj := LoadProject( cSpec )
   IF hProj == NIL
      RETURN Refuse( "não consegui resolver o projeto '" + cSpec + "'" )
   ENDIF
   cTmp := WorkDir()
   IF ! AstDumps( hProj, cTmp )
      RETURN Refuse( "o projeto não compila - corrija os erros de build primeiro" )
   ENDIF

   // definição e lista de parâmetros (na ordem de declaração)
   FOR EACH cPath IN hProj[ "files" ]
      hAst := ReadAst( cTmp, cPath )
      IF hAst == NIL
         RETURN Refuse( "dump ast-1 ausente/inválido para '" + cPath + "'" )
      ENDIF
      hAst[ "__src" ] := hb_ATokens( StrTran( hb_MemoRead( cPath ), Chr( 13 ), "" ), Chr( 10 ) )
      hAsts[ cPath ] := hAst
      FOR EACH hFunc IN hAst[ "functions" ]
         IF ! hFunc[ "fileDecl" ] .AND. Upper( hFunc[ "name" ] ) == cUpFunc
            IF ! Empty( cOnlyFile ) .AND. ;
               ! Lower( hb_FNameNameExt( cPath ) ) == Lower( hb_FNameNameExt( cOnlyFile ) )
               LOOP
            ENDIF
            IF hDef != NIL
               RETURN Refuse( "'" + cFunc + "' definida em mais de um módulo - use --file" )
            ENDIF
            hDef := hFunc
            cDefFile := cPath
         ENDIF
      NEXT
   NEXT
   IF hDef == NIL
      RETURN Refuse( "função '" + cFunc + "' não está definida no projeto" )
   ENDIF
   FOR EACH hItem IN hDef[ "declarations" ]
      IF hItem[ "param" ]
         AAdd( aParams, hItem[ "sym" ] )        // uppercase do dump
      ENDIF
   NEXT
   IF Len( aParams ) < 2
      RETURN Refuse( "'" + cFunc + "' tem menos de 2 parâmetros" )
   ENDIF

   // nova ordem: permutação exata
   aNew := hb_ATokens( Upper( cOrder ), "," )
   FOR nI := 1 TO Len( aNew )
      aNew[ nI ] := AllTrim( aNew[ nI ] )
   NEXT
   IF Len( aNew ) != Len( aParams )
      RETURN Refuse( "a nova ordem deve listar todos os " + hb_ntos( Len( aParams ) ) + " parâmetro(s)" )
   ENDIF
   FOR nI := 1 TO Len( aNew )
      nJ := hb_AScan( aParams, aNew[ nI ],,, .T. )
      IF nJ == 0 .OR. hb_AScan( aPerm, nJ ) > 0
         RETURN Refuse( "a nova ordem deve ser permutação de: " + ArrJoin( aParams, ", " ) )
      ENDIF
      AAdd( aPerm, nJ )
   NEXT

   // edições por módulo: assinatura (nomes) + call sites (argumentos)
   FOR EACH cPath IN hProj[ "files" ]
      hAst := hAsts[ cPath ]
      aE := {}
      FOR EACH hFunc IN hAst[ "functions" ]
         IF hFunc[ "fileDecl" ]
            LOOP
         ENDIF
         // assinatura: troca os NOMES dos parâmetros pela nova ordem
         IF cPath == cDefFile .AND. Upper( hFunc[ "name" ] ) == cUpFunc
            FOR nI := 1 TO Len( aParams )
               aSigHits := LineTokens( hAst, hFunc, hFunc[ "line" ], aParams[ nI ] )
               IF Len( aSigHits ) != 1
                  RETURN Refuse( "parâmetro '" + aParams[ nI ] + "' não localizado com precisão na assinatura" )
               ENDIF
               AAdd( aE, { aSigHits[ 1 ][ 1 ], aSigHits[ 1 ][ 2 ], ;
                           SpellAt( cPath, aSigHits[ 1 ], Len( aParams[ nI ] ) ), ;
                           SigSpell( cPath, hAst, hFunc, aParams[ aPerm[ nI ] ] ) } )
            NEXT
         ENDIF
         // call sites: varredura do span da função (registro de call em
         // statement continuado aponta a última linha física - o stream
         // resolve pelo token do nome)
         IF hb_AScan( hFunc[ "calls" ], {| h | Upper( h[ "sym" ] ) == cUpFunc } ) > 0
            aArgsSpans := CallSitesArgs( hAst, hFunc, cUpFunc, @cWhy )
            IF aArgsSpans == NIL
               RETURN Refuse( hb_FNameNameExt( cPath ) + ": " + cWhy )
            ENDIF
            FOR EACH hItem IN aArgsSpans          // reuso: hItem = spans de UMA chamada
               IF Len( hItem ) < Len( aParams )
                  RETURN Refuse( hb_FNameNameExt( cPath ) + ":" + ;
                                 hb_ntos( iif( Empty( hItem ), hFunc[ "line" ], hItem[ 1 ][ 1 ] ) ) + ;
                                 ": chamada com " + hb_ntos( Len( hItem ) ) + " arg(s) < " + ;
                                 hb_ntos( Len( aParams ) ) + " parâmetro(s) - implicit NIL would move" )
               ENDIF
               FOR nI := 1 TO Len( aParams )
                  AAdd( aE, { hItem[ nI ][ 1 ], hItem[ nI ][ 2 ], ;
                              hItem[ nI ][ 3 ], hItem[ aPerm[ nI ] ][ 3 ] } )
               NEXT
            NEXT
         ENDIF
      NEXT
      // strings citando a função
      FOR EACH hItem IN hAst[ "tokens" ]
         IF hItem[ "type" ] == 41 .AND. hItem[ "line" ] > 0 .AND. ;
            Upper( hItem[ "text" ] ) == cUpFunc
            AAdd( aWarn, hb_FNameNameExt( cPath ) + ":" + hb_ntos( hItem[ "line" ] ) + ;
                  ": string igual a '" + cFunc + "' - possível chamada por nome" )
         ENDIF
      NEXT
      IF ! Empty( aE )
         hEdits[ cPath ] := aE
         nTotal += Len( aE )
      ENDIF
   NEXT
   IF nTotal == 0
      RETURN Refuse( "nenhum site encontrado" )
   ENDIF

   FOR nI := 1 TO Len( aWarn )
      OutErr( "warning: " + aWarn[ nI ] + hb_eol() )
   NEXT
   IF ! Empty( aWarn ) .AND. ! lForce
      RETURN Refuse( "referências textuais encontradas - repita com --force" )
   ENDIF

   OutStd( "reorder-params: " + cFunc + "( " + ArrJoin( aParams, ", " ) + " ) -> ( " + ;
           ArrJoin( aNew, ", " ) + " )" + hb_eol() )
   FOR EACH cPath IN hb_HKeys( hEdits )
      FOR EACH aE IN hEdits[ cPath ]
         IF HB_ISNUMERIC( aE[ 1 ] )
            OutStd( "  " + hb_FNameNameExt( cPath ) + ":" + hb_ntos( aE[ 1 ] ) + hb_eol() )
         ENDIF
      NEXT
   NEXT
   IF lDryRun
      OutStd( "dry run - nada foi escrito" + hb_eol() )
      RETURN EXIT_OK
   ENDIF

   IF ! CompileHrbAll( hProj, cTmp, "before" )
      RETURN Refuse( "falha ao compilar o estado de referência" )
   ENDIF
   FOR EACH cPath IN hb_HKeys( hEdits )
      cText := hb_MemoRead( cPath )
      hOrig[ cPath ] := cText
      hb_MemoWrit( cPath, ApplyRangeEdits( cText, hEdits[ cPath ], @nI ) )   // reuso de nI
      IF nI > 0
         RollbackAll( hOrig )
         RETURN Refuse( "texto em " + hb_FNameNameExt( cPath ) + ":" + hb_ntos( nI ) + ;
                        " não confere com o esperado - rollback" )
      ENDIF
   NEXT
   IF ! CompileHrbAll( hProj, cTmp, "after" )
      RollbackAll( hOrig )
      RETURN Refuse( "o projeto parou de compilar após o reorder - rollback" )
   ENDIF
   FOR EACH cPath IN hProj[ "files" ]
      IF ! HrbSymbolsEqual( hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cPath ) + ".before.hrb" ), ;
                            hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cPath ) + ".after.hrb" ), @cWhy )
         RollbackAll( hOrig )
         RETURN Refuse( "verificação FALHOU em " + hb_FNameName( cPath ) + ": " + cWhy + " - rollback" )
      ENDIF
   NEXT
   OutStd( "verified: " + hb_ntos( nTotal ) + " site(s) reordenados; símbolos intactos; rode sua suíte para confirmar comportamento" + hb_eol() )

   RETURN EXIT_OK

// TODOS os call sites de uma função-alvo dentro do span de uma função
// contêiner, balanceando o STREAM de tokens por TIPO (50='(' 51=')'
// 52='[' 53=']' 54='{' 55='}' 29=','), padrão nome+'(' - imune ao skew de
// birthTok e a continuação ';' (o registro de call aponta a última linha
// física; o token do nome sabe a sua). Cada argumento vira uma FAIXA DE
// ÍNDICES do stream, materializada em span de fonte por BuildArgSpan
// (strings com delimitadores validados; caudas sem posição - ')' ']' '}'
// nunca têm coluna - casadas byte a byte contra o fonte, senão recusa).
// Devolve lista de listas { {linha, col1based, texto}, ... } por chamada;
// NIL+cWhy em recusa.
STATIC FUNCTION CallSitesArgs( hAst, hFunc, cUpFunc, cWhy )

   LOCAL aToks := hAst[ "tokens" ], nI, nJ, nDepth, hTok, nArgFrom
   LOCAL aAll := {}, aIdx, aSpans, aSpan, aPrev, nEnd := 0, aR

   cWhy := ""
   FOR EACH hTok IN hAst[ "functions" ]
      IF ! hTok[ "fileDecl" ] .AND. hTok[ "line" ] > hFunc[ "line" ] .AND. ;
         ( nEnd == 0 .OR. hTok[ "line" ] < nEnd )
         nEnd := hTok[ "line" ]
      ENDIF
   NEXT

   FOR nI := 1 TO Len( aToks )
      hTok := aToks[ nI ]
      IF hTok[ "line" ] < hFunc[ "line" ] .OR. ;
         ( nEnd > 0 .AND. hTok[ "line" ] >= nEnd )
         LOOP
      ENDIF
      aPrev := iif( nI > 1, aToks[ nI - 1 ], NIL )
      IF hTok[ "type" ] == 21 .AND. hTok[ "prov" ] == "s" .AND. ;
         hTok[ "col" ] != NIL .AND. Upper( hTok[ "text" ] ) == cUpFunc .AND. ;
         !( aPrev != NIL .AND. ( aPrev[ "type" ] == 58 .OR. aPrev[ "type" ] == 59 ) )
         // próximo token deve ser '(' (senão é referência, não chamada)
         IF nI + 1 > Len( aToks ) .OR. aToks[ nI + 1 ][ "type" ] != 50
            LOOP
         ENDIF
         aIdx := {}
         nDepth := 1
         nArgFrom := nI + 2
         FOR nJ := nI + 2 TO Len( aToks )
            hTok := aToks[ nJ ]
            DO CASE
            CASE hTok[ "type" ] == 50 .OR. hTok[ "type" ] == 52 .OR. hTok[ "type" ] == 54
               nDepth++
            CASE hTok[ "type" ] == 51 .OR. hTok[ "type" ] == 53 .OR. hTok[ "type" ] == 55
               nDepth--
               IF nDepth == 0
                  IF nJ > nArgFrom
                     AAdd( aIdx, { nArgFrom, nJ - 1 } )
                  ELSEIF ! Empty( aIdx )
                     cWhy := "argumento vazio na chamada da linha " + ;
                             hb_ntos( aToks[ nI ][ "line" ] )
                     RETURN NIL
                  ENDIF
                  EXIT
               ENDIF
            CASE hTok[ "type" ] == 29 .AND. nDepth == 1
               IF nJ == nArgFrom
                  cWhy := "argumento vazio na chamada da linha " + ;
                          hb_ntos( aToks[ nI ][ "line" ] )
                  RETURN NIL
               ENDIF
               AAdd( aIdx, { nArgFrom, nJ - 1 } )
               nArgFrom := nJ + 1
            ENDCASE
         NEXT
         aSpans := {}
         FOR EACH aR IN aIdx
            aSpan := BuildArgSpan( hAst, aR[ 1 ], aR[ 2 ], @cWhy )
            IF aSpan == NIL
               cWhy += " (chamada da linha " + hb_ntos( aToks[ nI ][ "line" ] ) + ")"
               RETURN NIL
            ENDIF
            AAdd( aSpans, aSpan )
         NEXT
         AAdd( aAll, aSpans )
      ENDIF
   NEXT

   RETURN aAll

// materializa a faixa de tokens [iA..iB] de UM argumento num span de fonte
// { linha, col 1-based, texto }. O miolo é copiado byte a byte entre o
// primeiro e o último token POSICIONADOS; strings (type 41, col aponta o
// conteúdo e len é o valor normalizado) são estendidas aos delimitadores
// com validação byte-exata; tokens de borda SEM posição (parênteses,
// colchetes, chaves, pipes) são casados um a um contra o fonte, pulando
// espaço e continuação ';' - qualquer não-conferência (escape de string,
// comentário no meio) devolve NIL+cWhy e o comando recusa.
STATIC FUNCTION BuildArgSpan( hAst, iA, iB, cWhy )

   LOCAL aToks := hAst[ "tokens" ], aSrc := hAst[ "__src" ]
   LOCAL iP1 := 0, iP2 := 0, nI
   LOCAL nL1, nC1, nL2, nC2, aPos

   FOR nI := iA TO iB
      IF aToks[ nI ][ "col" ] != NIL
         iP1 := nI
         EXIT
      ENDIF
   NEXT
   FOR nI := iB TO iA STEP -1
      IF aToks[ nI ][ "col" ] != NIL
         iP2 := nI
         EXIT
      ENDIF
   NEXT
   IF iP1 == 0
      cWhy := "argumento sem nenhum token com posição no fonte"
      RETURN NIL
   ENDIF

   nL1 := aToks[ iP1 ][ "line" ]
   nC1 := TokStartCol( aSrc, aToks[ iP1 ], @cWhy )
   IF nC1 == 0
      RETURN NIL
   ENDIF
   nL2 := aToks[ iP2 ][ "line" ]
   nC2 := TokEndCol( aSrc, aToks[ iP2 ], @cWhy )
   IF nC2 == 0
      RETURN NIL
   ENDIF

   // borda esquerda: tokens sem posição antes do 1º posicionado
   FOR nI := iP1 - 1 TO iA STEP -1
      aPos := MatchBack( aSrc, nL1, nC1, aToks[ nI ][ "text" ] )
      IF aPos == NIL
         cWhy := "'" + aToks[ nI ][ "text" ] + "' do argumento não conferiu no fonte" + ;
                 " (linha " + hb_ntos( nL1 ) + ")"
         RETURN NIL
      ENDIF
      nL1 := aPos[ 1 ]
      nC1 := aPos[ 2 ]
   NEXT
   // borda direita: tokens sem posição depois do último posicionado
   FOR nI := iP2 + 1 TO iB
      aPos := MatchFwd( aSrc, nL2, nC2, aToks[ nI ][ "text" ] )
      IF aPos == NIL
         cWhy := "'" + aToks[ nI ][ "text" ] + "' do argumento não conferiu no fonte" + ;
                 " (linha " + hb_ntos( nL2 ) + ")"
         RETURN NIL
      ENDIF
      nL2 := aPos[ 1 ]
      nC2 := aPos[ 2 ]
   NEXT

   RETURN { nL1, nC1, CutRange( aSrc, nL1, nC1, nL2, nC2 ) }

// início do span ORIGINAL de um token, coluna 1-based; strings: col do dump
// aponta o conteúdo e len é o valor normalizado - valida delimitador +
// conteúdo byte a byte e inclui o delimitador; 0 = não-provável
STATIC FUNCTION TokStartCol( aSrc, hTok, cWhy )

   LOCAL cLine, nC

   IF hTok[ "col" ] == NIL .OR. hTok[ "line" ] < 1 .OR. hTok[ "line" ] > Len( aSrc )
      cWhy := "token sem posição confiável na linha " + hb_ntos( hTok[ "line" ] )
      RETURN 0
   ENDIF
   nC := hTok[ "col" ]                    // 0-based
   IF hTok[ "type" ] == 41
      cLine := aSrc[ hTok[ "line" ] ]
      IF nC < 1 .OR. ! StrDelimsOk( cLine, nC, hTok )
         cWhy := "string na linha " + hb_ntos( hTok[ "line" ] ) + ;
                 " com escape/delimitador não trivial - recusando"
         RETURN 0
      ENDIF
      RETURN nC                           // 1-based do delimitador de abertura
   ENDIF

   RETURN nC + 1

// fim do span ORIGINAL de um token, coluna 1-based inclusiva; 0 = não-provável
STATIC FUNCTION TokEndCol( aSrc, hTok, cWhy )

   LOCAL cLine, nC

   IF hTok[ "col" ] == NIL .OR. hTok[ "line" ] < 1 .OR. hTok[ "line" ] > Len( aSrc )
      cWhy := "token sem posição confiável na linha " + hb_ntos( hTok[ "line" ] )
      RETURN 0
   ENDIF
   nC := hTok[ "col" ]
   IF hTok[ "type" ] == 41
      cLine := aSrc[ hTok[ "line" ] ]
      IF nC < 1 .OR. ! StrDelimsOk( cLine, nC, hTok )
         cWhy := "string na linha " + hb_ntos( hTok[ "line" ] ) + ;
                 " com escape/delimitador não trivial - recusando"
         RETURN 0
      ENDIF
      RETURN nC + 1 + hTok[ "len" ]       // delimitador de fechamento
   ENDIF

   RETURN nC + hTok[ "len" ]

// string simples: fonte[col-1] é o delimitador, o conteúdo confere byte a
// byte com o texto normalizado e o fechamento casa com a abertura
STATIC FUNCTION StrDelimsOk( cLine, nC, hTok )

   LOCAL cOpen := SubStr( cLine, nC, 1 )
   LOCAL cClose := SubStr( cLine, nC + 1 + hTok[ "len" ], 1 )

   IF ! SubStr( cLine, nC + 1, hTok[ "len" ] ) == hTok[ "text" ]
      RETURN .F.
   ENDIF

   RETURN ( cOpen == '"' .AND. cClose == '"' ) .OR. ;
          ( cOpen == "'" .AND. cClose == "'" ) .OR. ;
          ( cOpen == "[" .AND. cClose == "]" )

// casa cText no fonte ANTES de (nLine,nCol), pulando espaço, TAB e a
// continuação ';' inclusive através de linhas; devolve { linha, col } do
// início do casamento ou NIL
STATIC FUNCTION MatchBack( aSrc, nLine, nCol, cText )

   LOCAL nPos := nCol - 1, cCh

   DO WHILE .T.
      DO WHILE nPos < 1
         IF nLine <= 1
            RETURN NIL
         ENDIF
         nLine--
         nPos := Len( aSrc[ nLine ] )
      ENDDO
      cCh := SubStr( aSrc[ nLine ], nPos, 1 )
      IF cCh == " " .OR. cCh == Chr( 9 ) .OR. cCh == ";"
         nPos--
      ELSE
         EXIT
      ENDIF
   ENDDO
   IF nPos >= Len( cText ) .AND. ;
      SubStr( aSrc[ nLine ], nPos - Len( cText ) + 1, Len( cText ) ) == cText
      RETURN { nLine, nPos - Len( cText ) + 1 }
   ENDIF

   RETURN NIL

// casa cText no fonte DEPOIS de (nLine,nCol); devolve { linha, col-final }
// do casamento ou NIL
STATIC FUNCTION MatchFwd( aSrc, nLine, nCol, cText )

   LOCAL nPos := nCol + 1, cCh

   DO WHILE .T.
      DO WHILE nPos > Len( aSrc[ nLine ] )
         IF nLine >= Len( aSrc )
            RETURN NIL
         ENDIF
         nLine++
         nPos := 1
      ENDDO
      cCh := SubStr( aSrc[ nLine ], nPos, 1 )
      IF cCh == " " .OR. cCh == Chr( 9 ) .OR. cCh == ";"
         nPos++
      ELSE
         EXIT
      ENDIF
   ENDDO
   IF SubStr( aSrc[ nLine ], nPos, Len( cText ) ) == cText
      RETURN { nLine, nPos + Len( cText ) - 1 }
   ENDIF

   RETURN NIL

// recorta do fonte o intervalo [ (nL1,nC1) .. (nL2,nC2) ], colunas 1-based
// inclusivas
STATIC FUNCTION CutRange( aSrc, nL1, nC1, nL2, nC2 )

   LOCAL cOut := "", nL

   IF nL1 == nL2
      RETURN SubStr( aSrc[ nL1 ], nC1, nC2 - nC1 + 1 )
   ENDIF
   FOR nL := nL1 TO nL2
      DO CASE
      CASE nL == nL1
         cOut += SubStr( aSrc[ nL ], nC1 )
      CASE nL == nL2
         cOut += Chr( 10 ) + Left( aSrc[ nL ], nC2 )
      OTHERWISE
         cOut += Chr( 10 ) + aSrc[ nL ]
      ENDCASE
   NEXT

   RETURN cOut

STATIC FUNCTION SpellAt( cPath, aHit, nLen )

   LOCAL aSrc := hb_ATokens( StrTran( hb_MemoRead( cPath ), Chr( 13 ), "" ), Chr( 10 ) )

   RETURN SubStr( aSrc[ aHit[ 1 ] ], aHit[ 2 ], nLen )

// grafia original de um parâmetro (o dump é uppercase): token na assinatura
STATIC FUNCTION SigSpell( cPath, hAst, hFunc, cUpName )

   LOCAL aHits := LineTokens( hAst, hFunc, hFunc[ "line" ], cUpName )

   IF Len( aHits ) >= 1
      RETURN SpellAt( cPath, aHits[ 1 ], Len( cUpName ) )
   ENDIF

   RETURN cUpName

// edições por FAIXA { linha, col 1-based, textoVelho, textoNovo } aplicadas
// em ordem descendente de posição; nLineBad > 0 quando o texto numa faixa
// não confere (edição parcial mudaria semântica em silêncio - a verificação
// de símbolos do reorder não pegaria)
STATIC FUNCTION ApplyRangeEdits( cText, aEdits, nLineBad )

   LOCAL aOffs := { 1 }, nI, nAt

   nLineBad := 0
   FOR nI := 1 TO hb_BLen( cText )
      IF hb_BSubStr( cText, nI, 1 ) == Chr( 10 )
         AAdd( aOffs, nI + 1 )
      ENDIF
   NEXT
   ASort( aEdits,,, {| x, y | iif( x[ 1 ] == y[ 1 ], x[ 2 ] > y[ 2 ], x[ 1 ] > y[ 1 ] ) } )
   FOR nI := 1 TO Len( aEdits )
      nAt := aOffs[ aEdits[ nI ][ 1 ] ] + aEdits[ nI ][ 2 ] - 1
      // sanidade: o texto na faixa deve ser exatamente o esperado
      IF ! hb_BSubStr( cText, nAt, hb_BLen( aEdits[ nI ][ 3 ] ) ) == aEdits[ nI ][ 3 ]
         nLineBad := aEdits[ nI ][ 1 ]
         RETURN cText
      ENDIF
      cText := hb_BLeft( cText, nAt - 1 ) + aEdits[ nI ][ 4 ] + ;
               hb_BSubStr( cText, nAt + hb_BLen( aEdits[ nI ][ 3 ] ) )
   NEXT

   RETURN cText

// pós-reorder: tabela de símbolos e CONJUNTO de funções intactos (pcode
// muda legitimamente - ordem de push)
STATIC FUNCTION HrbSymbolsEqual( cBefore, cAfter, cWhy )

   LOCAL hB := HrbParse( cBefore ), hA := HrbParse( cAfter )
   LOCAL nI

   cWhy := ""
   IF hB == NIL .OR. hA == NIL
      cWhy := "não consegui ler o .hrb"
      RETURN .F.
   ENDIF
   IF Len( hB[ "syms" ] ) != Len( hA[ "syms" ] ) .OR. ;
      Len( hB[ "funcs" ] ) != Len( hA[ "funcs" ] )
      cWhy := "quantidade de símbolos/funções mudou"
      RETURN .F.
   ENDIF
   FOR nI := 1 TO Len( hB[ "syms" ] )
      IF !( hA[ "syms" ][ nI ][ 1 ] == hB[ "syms" ][ nI ][ 1 ] ) .OR. ;
         !( hA[ "syms" ][ nI ][ 2 ] == hB[ "syms" ][ nI ][ 2 ] )
         cWhy := "símbolo " + hb_ntos( nI ) + " mudou"
         RETURN .F.
      ENDIF
   NEXT
   FOR nI := 1 TO Len( hB[ "funcs" ] )
      IF !( hA[ "funcs" ][ nI ][ 1 ] == hB[ "funcs" ][ nI ][ 1 ] )
         cWhy := "função " + hb_ntos( nI ) + " mudou de nome"
         RETURN .F.
      ENDIF
   NEXT

   RETURN .T.

STATIC FUNCTION ArrJoin( aArr, cSep )

   LOCAL cOut := "", nI

   FOR nI := 1 TO Len( aArr )
      cOut += iif( nI == 1, "", cSep ) + aArr[ nI ]
   NEXT

   RETURN cOut

// ---------------------------------------------------------------------------
// fase B4 - DSLs de pré-processador. As PALAVRAS de uma DSL (#command/
// #xcommand/#[x]translate/#define) são consumidas pelo pp e nunca chegam ao
// yylex - não existem em tokens[]. Os fatos vêm das seções ppRules[] (a
// diretiva: arquivo/linha/cabeça/markers) e ppApplications[] (cada aplicação,
// com os tokens consumidos e a atribuição token->marker; marker 0 = palavra
// literal da própria regra) do dump ast-2 - ver docs/ast-schema.md.
// ---------------------------------------------------------------------------

STATIC FUNCTION PpReady( hAst )
   RETURN hb_HHasKey( hAst, "ppRules" ) .AND. hb_HHasKey( hAst, "ppApplications" )

STATIC FUNCTION RuleTag( hRule )
   RETURN "#" + hRule[ "kind" ] + " " + ;
          iif( hRule[ "head" ] == NIL, "<sem cabeça>", hRule[ "head" ] )

STATIC FUNCTION RuleWhere( hRule )
   RETURN iif( hRule[ "file" ] == NIL, "builtin", ;
               hRule[ "file" ] + ":" + hb_ntos( hRule[ "line" ] ) )

// ---------------------------------------------------------------------------
// palavras de DSL no usages - definição (diretiva) e aplicações da palavra.
// Genérico por construção: opera só sobre os fatos ppRules/ppApplications
// (cabeça, kind, atribuição token->marker) - vale para QUALQUER comando
// criado por diretiva, das cinco famílias e das que vierem a existir no
// mesmo funil (hb_pp_patternReplace).
// ---------------------------------------------------------------------------

STATIC FUNCTION DslHits( hAst, cUp, cModFile, aSrc, aDefSeen, aLoc, cPath, nLen )

   LOCAL hRule, hApp, hTok, nHits := 0, cKey, lHead, cWhat

   IF ! PpReady( hAst )      // dump ast-1: sem os fatos, sem os hits
      RETURN 0
   ENDIF

   // definição: a diretiva (o mesmo .ch registra a regra em cada módulo
   // que o inclui - dedupe global por arquivo+linha+tipo)
   FOR EACH hRule IN hAst[ "ppRules" ]
      IF hRule[ "head" ] != NIL .AND. Upper( hRule[ "head" ] ) == cUp
         cKey := RuleWhere( hRule ) + "|" + hRule[ "kind" ]
         IF hb_AScan( aDefSeen, cKey,,, .T. ) == 0
            AAdd( aDefSeen, cKey )
            nHits++
            IF hRule[ "file" ] == NIL
               OutStd( "(builtin): directive (" + RuleTag( hRule ) + ", " + ;
                  hb_ntos( hRule[ "markers" ] ) + " marker(s)) - regra do core/-D, sem arquivo" + hb_eol() )
            ELSE
               OutStd( hRule[ "file" ] + ":" + hb_ntos( hRule[ "line" ] ) + ;
                  ": directive (" + RuleTag( hRule ) + ", " + ;
                  hb_ntos( hRule[ "markers" ] ) + " marker(s))" + hb_eol() )
            ENDIF
         ENDIF
      ENDIF
   NEXT

   // aplicações: tokens marker 0 (palavra literal da regra) com o texto -
   // cobre a cabeça e as palavras secundárias (ACTION, AT, SAY...)
   FOR EACH hApp IN hAst[ "ppApplications" ]
      hRule := hAst[ "ppRules" ][ hApp[ "rule" ] + 1 ]
      FOR EACH hTok IN hApp[ "tokens" ]
         IF hTok[ "marker" ] == 0 .AND. Upper( hTok[ "text" ] ) == cUp
            nHits++
            lHead := hRule[ "head" ] != NIL .AND. Upper( hRule[ "head" ] ) == cUp
            cWhat := iif( lHead, "application", "keyword" ) + ;
                     " (" + RuleTag( hRule ) + ", " + RuleWhere( hRule ) + ")"
            IF hTok[ "prov" ] == "s" .AND. hTok[ "col" ] != NIL
               LocAdd( aLoc, cPath, hTok[ "line" ], { hTok[ "col" ] + 1 }, nLen )
               OutStd( cModFile + ":" + hb_ntos( hTok[ "line" ] ) + ":" + ;
                  hb_ntos( hTok[ "col" ] + 1 ) + ": " + cWhat + ;
                  SrcLine( aSrc, hTok[ "line" ] ) + hb_eol() )
            ELSE
               OutStd( cModFile + ":" + hb_ntos( hApp[ "line" ] ) + ": " + cWhat + ;
                  " - sem posição no fonte (expansão de outra regra/include)" + hb_eol() )
            ENDIF
         ENDIF
      NEXT
   NEXT

   RETURN nHits

// ---------------------------------------------------------------------------
// rename-dsl - renomeia a CABEÇA de uma regra de pp: a palavra na diretiva
// (lado do match, antes do '=>') + todos os sites de aplicação (posições de
// ppApplications, marker 0). Verificação padrão-ouro: rename consistente
// produz expansão idêntica -> .ppo e .hrb de TODOS os módulos byte-idênticos
// antes/depois; qualquer diferença = rollback. O #define constante é o caso
// degenerado (regra sem markers).
// ---------------------------------------------------------------------------

STATIC FUNCTION RenameDsl( aArgs )

   LOCAL cSpec, cOld, cNew, lDryRun := .F., nI
   LOCAL hProj, cTmp, cPath, hAst, hAsts := { => }, hRule, hApp, hTok
   LOCAL cUpOld, cUpNew, aTargets := {}, cKey, aDefSeen := {}
   LOCAL hEdits := { => }, aE, cChPath, cText, hOrig := { => }
   LOCAL nSites := 0, nDirEdits := 0, cWhy := "", nLine
   LOCAL hPpoBefore := { => }, cPpo, cCwd

   IF Len( aArgs ) < 4
      Usage()
      RETURN EXIT_USAGE
   ENDIF
   cSpec := aArgs[ 2 ]
   cOld  := aArgs[ 3 ]
   cNew  := aArgs[ 4 ]
   FOR nI := 5 TO Len( aArgs )
      IF Lower( aArgs[ nI ] ) == "--dry-run"
         lDryRun := .T.
      ENDIF
   NEXT
   cUpOld := Upper( cOld )
   cUpNew := Upper( cNew )

   IF ! OneWord( cNew )
      RETURN Refuse( "novo nome '" + cNew + "' não é uma palavra única" )
   ENDIF
   IF cUpOld == cUpNew
      RETURN Refuse( "nomes velho e novo são idênticos" )
   ENDIF

   hProj := LoadProject( cSpec )
   IF hProj == NIL
      RETURN Refuse( "não consegui resolver o projeto '" + cSpec + "'" )
   ENDIF
   cTmp := WorkDir()
   IF ! AstDumps( hProj, cTmp )
      RETURN Refuse( "o projeto não compila - corrija os erros de build primeiro" )
   ENDIF

   // regras alvo (cabeça == velha) + colisões do nome novo, projeto inteiro
   FOR EACH cPath IN hProj[ "files" ]
      hAst := ReadAst( cTmp, cPath )
      IF hAst == NIL
         RETURN Refuse( "dump ausente/inválido para '" + cPath + "'" )
      ENDIF
      IF ! PpReady( hAst )
         RETURN Refuse( "dump sem ppRules/ppApplications (schema ast-2) - " + ;
                        "recompile o harbour do branch feature/compiler-ast-dump" )
      ENDIF
      hAsts[ cPath ] := hAst

      FOR EACH hRule IN hAst[ "ppRules" ]
         IF hRule[ "head" ] == NIL
            LOOP
         ENDIF
         IF Upper( hRule[ "head" ] ) == cUpOld
            IF hRule[ "file" ] == NIL
               RETURN Refuse( "'" + cOld + "' é regra builtin (std rules/-D, sem arquivo " + ;
                              "de diretiva) - não há diretiva a editar" )
            ENDIF
            cKey := RuleWhere( hRule ) + "|" + hRule[ "kind" ]
            IF hb_AScan( aDefSeen, cKey,,, .T. ) == 0
               AAdd( aDefSeen, cKey )
               AAdd( aTargets, hRule )
            ENDIF
         ELSE
            IF Upper( hRule[ "head" ] ) == cUpNew
               RETURN Refuse( "'" + cNew + "' já é cabeça de regra (" + RuleTag( hRule ) + ;
                              ", " + RuleWhere( hRule ) + ")" )
            ENDIF
            // abreviação dBase: #command/#translate casam cabeça abreviada
            // em 4+ letras - colisão nova OU velha com outra regra recusa
            IF AbbrevClash( cUpNew, "?", Upper( hRule[ "head" ] ), hRule[ "kind" ] )
               RETURN Refuse( "'" + cNew + "' colide por abreviação (4 letras) com a regra " + ;
                              RuleTag( hRule ) + " (" + RuleWhere( hRule ) + ")" )
            ENDIF
            IF AbbrevClash( cUpOld, "?", Upper( hRule[ "head" ] ), hRule[ "kind" ] )
               RETURN Refuse( "'" + cOld + "' colide por abreviação (4 letras) com a regra " + ;
                              RuleTag( hRule ) + " (" + RuleWhere( hRule ) + ") - " + ;
                              "ambiguidade pré-existente, resolva antes do rename" )
            ENDIF
         ENDIF
      NEXT
   NEXT
   IF Empty( aTargets )
      RETURN Refuse( "'" + cOld + "' não é cabeça de regra de pp do projeto" )
   ENDIF

   // sequestro: o nome novo já vive no projeto como identificador ou como
   // palavra de outra regra em aplicações - a regra renomeada o capturaria
   FOR EACH cPath IN hProj[ "files" ]
      hAst := hAsts[ cPath ]
      FOR EACH hTok IN hAst[ "tokens" ]
         IF hTok[ "type" ] == 21 .AND. hTok[ "prov" ] == "s" .AND. ;
            Upper( hTok[ "text" ] ) == cUpNew
            RETURN Refuse( "'" + cNew + "' já é identificador usado em " + ;
                           hb_FNameNameExt( cPath ) + ":" + hb_ntos( hTok[ "line" ] ) + ;
                           " - a regra renomeada o capturaria" )
         ENDIF
      NEXT
      FOR EACH hApp IN hAst[ "ppApplications" ]
         FOR EACH hTok IN hApp[ "tokens" ]
            IF hTok[ "marker" ] == 0 .AND. Upper( hTok[ "text" ] ) == cUpNew
               RETURN Refuse( "'" + cNew + "' já é palavra da regra " + ;
                              RuleTag( hAst[ "ppRules" ][ hApp[ "rule" ] + 1 ] ) + ;
                              " em aplicações (" + hb_FNameNameExt( cPath ) + ":" + ;
                              hb_ntos( hApp[ "line" ] ) + ")" )
            ENDIF
         NEXT
      NEXT
   NEXT

   // sites de aplicação nos módulos (tokens marker 0 com o texto da cabeça)
   FOR EACH cPath IN hProj[ "files" ]
      hAst := hAsts[ cPath ]
      aE := {}
      FOR EACH hApp IN hAst[ "ppApplications" ]
         hRule := hAst[ "ppRules" ][ hApp[ "rule" ] + 1 ]
         IF hRule[ "head" ] == NIL .OR. ! Upper( hRule[ "head" ] ) == cUpOld
            LOOP
         ENDIF
         FOR EACH hTok IN hApp[ "tokens" ]
            IF hTok[ "marker" ] != 0
               LOOP
            ENDIF
            IF Upper( hTok[ "text" ] ) == cUpOld
               IF !( hTok[ "prov" ] == "s" .AND. hTok[ "col" ] != NIL )
                  RETURN Refuse( "aplicação de " + RuleTag( hRule ) + " em " + ;
                                 hb_FNameNameExt( cPath ) + ":" + hb_ntos( hApp[ "line" ] ) + ;
                                 " sem posição no fonte (include ou expansão de outra regra) - recuso" )
               ENDIF
               AAdd( aE, { hTok[ "line" ], hTok[ "col" ] + 1 } )
            ELSEIF hb_BLen( hTok[ "text" ] ) >= 4 .AND. ;
               Upper( hTok[ "text" ] ) == Left( cUpOld, hb_BLen( hTok[ "text" ] ) )
               // uso ABREVIADO da cabeça (dBase 4 letras): o texto do site
               // não é a palavra inteira - edição cega deixaria site órfão
               RETURN Refuse( "uso abreviado '" + hTok[ "text" ] + "' da regra em " + ;
                              hb_FNameNameExt( cPath ) + ":" + hb_ntos( hTok[ "line" ] ) + ;
                              " - normalize para '" + cOld + "' antes do rename" )
            ENDIF
         NEXT
      NEXT
      IF ! Empty( aE )
         DedupHits( aE )
         nSites += Len( aE )
         AbsEditsAdd( hEdits, cPath, aE )
      ENDIF
   NEXT

   // a diretiva: a palavra no lado do MATCH (antes do '=>')
   cCwd := hb_PathNormalize( hb_DirSepAdd( hb_cwd() ) )
   FOR EACH hRule IN aTargets
      cChPath := ResolveInclude( hProj, hRule[ "file" ] )
      IF Empty( cChPath )
         RETURN Refuse( "não achei o arquivo da diretiva '" + hRule[ "file" ] + "'" )
      ENDIF
      IF ! Left( hb_PathNormalize( hb_PathJoin( cCwd, cChPath ) ), Len( cCwd ) ) == cCwd
         RETURN Refuse( "diretiva em '" + cChPath + "' fora do diretório do projeto - " + ;
                        "recuso editar include de sistema/compartilhado" )
      ENDIF
      aE := {}
      IF ! DirectiveHeadEdits( hb_MemoRead( cChPath ), hRule[ "line" ], hRule[ "kind" ], ;
                               cUpOld, aE, @cWhy )
         RETURN Refuse( "diretiva " + RuleTag( hRule ) + " em " + RuleWhere( hRule ) + ;
                        ": " + cWhy )
      ENDIF
      nDirEdits += Len( aE )
      AbsEditsAdd( hEdits, cChPath, aE )
   NEXT

   OutStd( "rename-dsl: " + cOld + " -> " + cNew + hb_eol() )
   FOR EACH cKey IN hb_HKeys( hEdits )
      FOR EACH aE IN hEdits[ cKey ]
         OutStd( "  " + hb_FNameNameExt( cKey ) + ":" + hb_ntos( aE[ 1 ] ) + ;
                 ":" + hb_ntos( aE[ 2 ] ) + hb_eol() )
      NEXT
   NEXT
   IF lDryRun
      OutStd( "dry run - nada foi escrito" + hb_eol() )
      RETURN EXIT_OK
   ENDIF

   // referência: expansão (.ppo) e pcode (.hrb) de todos os módulos
   FOR EACH cPath IN hProj[ "files" ]
      cPpo := PpoGen( hProj, cPath )
      IF cPpo == NIL
         RETURN Refuse( "falha ao gerar .ppo de referência para '" + cPath + "'" )
      ENDIF
      hPpoBefore[ cPath ] := cPpo
   NEXT
   IF ! CompileHrbAll( hProj, cTmp, "before" )
      RETURN Refuse( "falha ao compilar o estado de referência" )
   ENDIF

   FOR EACH cKey IN hb_HKeys( hEdits )
      cText := hb_MemoRead( cKey )
      hOrig[ cKey ] := cText
      hb_MemoWrit( cKey, ApplyTokenEdits( cText, hEdits[ cKey ], cOld, cNew, @nLine ) )
      IF nLine > 0
         RollbackAll( hOrig )
         RETURN Refuse( "texto em " + hb_FNameNameExt( cKey ) + ":" + hb_ntos( nLine ) + ;
                        " não confere - rollback" )
      ENDIF
   NEXT

   FOR EACH cPath IN hProj[ "files" ]
      cPpo := PpoGen( hProj, cPath )
      IF cPpo == NIL
         RollbackAll( hOrig )
         RETURN Refuse( "o projeto parou de pré-processar após o rename - rollback" )
      ENDIF
      IF !( cPpo == hPpoBefore[ cPath ] )
         RollbackAll( hOrig )
         RETURN Refuse( "expansão (.ppo) de " + hb_FNameNameExt( cPath ) + ;
                        " mudou - rename inconsistente - rollback" )
      ENDIF
   NEXT
   IF ! CompileHrbAll( hProj, cTmp, "after" )
      RollbackAll( hOrig )
      RETURN Refuse( "o projeto parou de compilar após o rename - rollback" )
   ENDIF
   FOR EACH cPath IN hProj[ "files" ]
      IF !( hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cPath ) + ".before.hrb" ) == ;
            hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cPath ) + ".after.hrb" ) )
         RollbackAll( hOrig )
         RETURN Refuse( "pcode (.hrb) de " + hb_FNameName( cPath ) + " mudou - rollback" )
      ENDIF
   NEXT

   OutStd( "verified: " + hb_ntos( nSites ) + " application site(s) + " + ;
           hb_ntos( nDirEdits ) + " directive occurrence(s); .ppo and .hrb byte-identical" + hb_eol() )

   RETURN EXIT_OK

// agrupa edições por arquivo com chave normalizada (a diretiva pode viver
// num .prg do próprio projeto - as edições têm que ir na MESMA aplicação)
STATIC PROCEDURE AbsEditsAdd( hEdits, cPath, aNew )

   LOCAL cKey := hb_PathNormalize( hb_PathJoin( hb_DirSepAdd( hb_cwd() ), cPath ) )
   LOCAL aE

   IF ! hb_HHasKey( hEdits, cKey )
      hEdits[ cKey ] := {}
   ENDIF
   FOR EACH aE IN aNew
      AAdd( hEdits[ cKey ], aE )
   NEXT

   RETURN

// colisão por abreviação dBase: cabeças de #command/#translate (famílias
// sem 'x') casam abreviadas em >= 4 letras - uma palavra e uma cabeça
// colidem quando uma é prefixo >= 4 da outra (ou iguais)
STATIC FUNCTION AbbrevClash( cUpA, cKindA, cUpB, cKindB )

   IF cUpA == cUpB
      RETURN .T.
   ENDIF
   IF hb_BLen( cUpA ) >= 4 .AND. cUpA == Left( cUpB, hb_BLen( cUpA ) ) .AND. ;
      ( cKindB == "command" .OR. cKindB == "translate" )
      RETURN .T.
   ENDIF
   IF hb_BLen( cUpB ) >= 4 .AND. cUpB == Left( cUpA, hb_BLen( cUpB ) ) .AND. ;
      ( cKindA == "command" .OR. cKindA == "translate" )
      RETURN .T.
   ENDIF

   RETURN .F.

// resolve o arquivo da diretiva como o pp resolveu o include: caminho como
// registrado (absoluto ou relativo ao cwd) ou pelos -i do projeto
STATIC FUNCTION ResolveInclude( hProj, cFile )

   LOCAL cDir

   IF hb_vfExists( cFile )
      RETURN cFile
   ENDIF
   FOR EACH cDir IN hProj[ "inc" ]
      IF hb_vfExists( hb_DirSepAdd( cDir ) + cFile )
         RETURN hb_DirSepAdd( cDir ) + cFile
      ENDIF
   NEXT

   RETURN ""

// ocorrências (linha, col 1-based) da palavra-cabeça no lado do MATCH da
// diretiva (da linha da diretiva até o '=>'; continuação por ';'). O lado
// do RESULTADO fica intocado: regra recursiva que emita a própria cabeça
// quebra a expansão e a rede .ppo/.hrb recusa com rollback. #define não tem
// '=>': só a primeira ocorrência (a cabeça logo após #define).
STATIC FUNCTION DirectiveHeadEdits( cText, nLine, cKind, cUpOld, aEdits, cWhy )

   LOCAL aSrc := hb_ATokens( StrTran( cText, Chr( 13 ), "" ), Chr( 10 ) )
   LOCAL nL, cLine, cScan, nArrow, nCol, lArrow := .F.

   IF nLine < 1 .OR. nLine > Len( aSrc )
      cWhy := "linha " + hb_ntos( nLine ) + " fora do arquivo"
      RETURN .F.
   ENDIF
   // o line da regra segue a convenção do pp (linha de INPUT corrente =
   // última linha física da diretiva continuada por ';') - reancorar no
   // INÍCIO físico: a linha '#<kind>' mais próxima, para trás
   nL := nLine
   DO WHILE nL >= 1 .AND. ! DirectiveStart( aSrc[ nL ], cKind )
      nL--
   ENDDO
   IF nL < 1
      cWhy := "início da diretiva #" + cKind + " não encontrado até a linha " + ;
              hb_ntos( nLine )
      RETURN .F.
   ENDIF
   DO WHILE nL <= Len( aSrc )
      cLine := aSrc[ nL ]
      nArrow := At( "=>", cLine )
      cScan := iif( nArrow > 0, Left( cLine, nArrow - 1 ), cLine )
      FOR EACH nCol IN WordOccs( cScan, cUpOld )
         AAdd( aEdits, { nL, nCol } )
         IF cKind == "define"
            RETURN .T.
         ENDIF
      NEXT
      IF nArrow > 0
         lArrow := .T.
         EXIT
      ENDIF
      IF !( Right( RTrim( cLine ), 1 ) == ";" )
         EXIT
      ENDIF
      nL++
   ENDDO

   IF cKind == "define"
      cWhy := "cabeça '" + cUpOld + "' não encontrada na linha da diretiva"
      RETURN .F.
   ENDIF
   IF ! lArrow
      cWhy := "diretiva sem '=>' reconhecível"
      RETURN .F.
   ENDIF
   IF Empty( aEdits )
      cWhy := "cabeça '" + cUpOld + "' não encontrada no lado do match"
      RETURN .F.
   ENDIF

   RETURN .T.

// a linha abre a diretiva do tipo dado? ('#' + nome, aceitando o nome
// abreviado em >= 4 letras que o pp aceita, ex.: #xtrans p/ #xtranslate)
STATIC FUNCTION DirectiveStart( cLine, cKind )

   LOCAL cWord

   cLine := LTrim( cLine )
   IF ! Left( cLine, 1 ) == "#"
      RETURN .F.
   ENDIF
   cLine := LTrim( SubStr( cLine, 2 ) )
   cWord := Lower( hb_TokenGet( cLine, 1 ) )

   RETURN cWord == cKind .OR. ;
          ( hb_BLen( cWord ) >= 4 .AND. cWord == Left( cKind, hb_BLen( cWord ) ) )

// colunas 1-based das ocorrências INTEIRAS da palavra na linha (fronteira =
// vizinho não alfanumérico/_). Territorio textual assumido: linhas de
// diretiva não têm tokens no dump (o pp as consome) - e toda edição passa
// pela rede .ppo/.hrb byte-idênticos.
STATIC FUNCTION WordOccs( cLine, cUpWord )

   LOCAL aCols := {}, cUp := Upper( cLine )
   LOCAL nAt := 0, nLen := hb_BLen( cUpWord )

   DO WHILE ( nAt := hb_BAt( cUpWord, cUp, nAt + 1 ) ) > 0
      IF ! IsIdByte( hb_BSubStr( cUp, nAt - 1, 1 ) ) .AND. ;
         ! IsIdByte( hb_BSubStr( cUp, nAt + nLen, 1 ) )
         AAdd( aCols, nAt )
      ENDIF
   ENDDO

   RETURN aCols

STATIC FUNCTION IsIdByte( cCh )
   RETURN ! Empty( cCh ) .AND. ( hb_asciiIsAlpha( cCh ) .OR. hb_asciiIsDigit( cCh ) .OR. cCh == "_" )

// .ppo do módulo com os flags do projeto - o harbour grava <fonte>.ppo ao
// lado do FONTE (independe de -o/cwd): preserva um .ppo pré-existente do
// usuário e devolve o conteúdo gerado (NIL em falha)
STATIC FUNCTION PpoGen( hProj, cPath )

   LOCAL cPpoPath := hb_FNameExtSet( cPath, ".ppo" )
   LOCAL lHad := hb_vfExists( cPpoPath )
   LOCAL cPre := iif( lHad, hb_MemoRead( cPpoPath ), "" )
   LOCAL cFlags := "", cTok, cOut := "", cErr := "", cPpo

   FOR EACH cTok IN hProj[ "flags" ]
      cFlags += " " + cTok
   NEXT
   IF hb_processRun( HarbourBin() + " " + cPath + " -q -s -p" + cFlags,, ;
                     @cOut, @cErr ) != 0
      OutErr( ErrLines( cOut + cErr ) )
      RETURN NIL
   ENDIF
   cPpo := hb_MemoRead( cPpoPath )
   IF lHad
      hb_MemoWrit( cPpoPath, cPre )
   ELSE
      hb_vfErase( cPpoPath )
   ENDIF

   RETURN cPpo

// ---------------------------------------------------------------------------
// fase B4b - variáveis de escopo DINÂMICO (PRIVATE/PUBLIC/memvar). O
// compilador já resolveu a sombra LÉXICA em cada occurrence (local vence
// memvar na função); o que é análise NOVA da ferramenta é a visibilidade
// dinâmica: um PRIVATE vive na extensão dinâmica do criador (o fecho
// transitivo dos callees, pelo call graph do projeto), com furos onde o
// grafo estático não enxerga (macro '&', sends, chamada dinâmica por nome,
// função fora do projeto). Fatos usados (ver docs/ast-schema.md):
//   criador PRIVATE  = declaration scope 'private' (declLine exata)
//   criador PUBLIC   = call __MVPUBLIC na linha + occurrence write/use
//   criação via '&'  = call __MV{PRIVATE|PUBLIC} SEM occurrence na linha
//   uso              = occurrence scope memvar|memvar_implicit
//   declarado MEMVAR = declaration scope 'memvar' (fileDecl = file-wide)
// ---------------------------------------------------------------------------

// fatos por nome, projeto inteiro
STATIC FUNCTION MvFacts( hProj, hAsts, cUp )

   LOCAL hF := { "creators" => {}, "decls" => {}, "uses" => {}, ;
                 "lexshadow" => {}, "fields" => {}, "macrocreates" => {} }
   LOCAL cPath, hAst, hFunc, hItem, cMod, lHit

   FOR EACH cPath IN hProj[ "files" ]
      hAst := hAsts[ cPath ]
      cMod := hb_FNameNameExt( cPath )
      FOR EACH hFunc IN hAst[ "functions" ]
         FOR EACH hItem IN hFunc[ "declarations" ]
            IF Upper( hItem[ "sym" ] ) == cUp
               DO CASE
               CASE hItem[ "scope" ] == "private"
                  AAdd( hF[ "creators" ], { cMod, hFunc[ "name" ], hItem[ "declLine" ], "PRIVATE", cPath } )
               CASE hItem[ "scope" ] == "memvar"
                  AAdd( hF[ "decls" ], { cMod, iif( hFunc[ "fileDecl" ], "(file-wide)", hFunc[ "name" ] ), ;
                                         hItem[ "declLine" ], cPath } )
               CASE hItem[ "scope" ] == "field"
                  AAdd( hF[ "fields" ], { cMod, hFunc[ "name" ], hItem[ "declLine" ] } )
               CASE hItem[ "scope" ] == "local" .OR. hItem[ "scope" ] == "static"
                  AAdd( hF[ "lexshadow" ], { cMod, hFunc[ "name" ], hItem[ "scope" ], hItem[ "declLine" ] } )
               ENDCASE
            ENDIF
         NEXT
         FOR EACH hItem IN hFunc[ "occurrences" ]
            IF Upper( hItem[ "sym" ] ) == cUp .AND. ;
               ( hItem[ "scope" ] == "memvar" .OR. hItem[ "scope" ] == "memvar_implicit" )
               AAdd( hF[ "uses" ], { cMod, hFunc[ "name" ], hItem[ "line" ], hItem[ "access" ], ;
                                     hItem[ "scope" ] == "memvar_implicit", hItem[ "block" ], cPath } )
            ENDIF
         NEXT
         // criador PUBLIC: __MVPUBLIC na linha com occurrence write/use do
         // nome (o PRIVATE tem declaration própria; o PUBLIC não)
         FOR EACH hItem IN hFunc[ "calls" ]
            IF hItem[ "sym" ] == "__MVPUBLIC"
               lHit := MvOccAtLine( hFunc, cUp, hItem[ "line" ] )
               IF lHit
                  AAdd( hF[ "creators" ], { cMod, hFunc[ "name" ], hItem[ "line" ], "PUBLIC", cPath } )
               ENDIF
            ENDIF
            // criação com nome invisível ao compilador (PRIVATE/PUBLIC &macro)
            IF ( hItem[ "sym" ] == "__MVPRIVATE" .OR. hItem[ "sym" ] == "__MVPUBLIC" ) .AND. ;
               ! MvAnyOccAtLine( hFunc, hItem[ "line" ] )
               AAdd( hF[ "macrocreates" ], { cMod, hFunc[ "name" ], hItem[ "line" ] } )
            ENDIF
         NEXT
      NEXT
   NEXT

   RETURN hF

STATIC FUNCTION MvOccAtLine( hFunc, cUp, nLine )

   LOCAL hItem

   FOR EACH hItem IN hFunc[ "occurrences" ]
      IF Upper( hItem[ "sym" ] ) == cUp .AND. hItem[ "line" ] == nLine .AND. ;
         ( hItem[ "scope" ] == "memvar" .OR. hItem[ "scope" ] == "memvar_implicit" ) .AND. ;
         ( hItem[ "access" ] == "write" .OR. hItem[ "access" ] == "use" )
         RETURN .T.
      ENDIF
   NEXT

   RETURN .F.

STATIC FUNCTION MvAnyOccAtLine( hFunc, nLine )

   LOCAL hItem

   FOR EACH hItem IN hFunc[ "occurrences" ]
      IF hItem[ "line" ] == nLine .AND. ;
         ( hItem[ "scope" ] == "memvar" .OR. hItem[ "scope" ] == "memvar_implicit" ) .AND. ;
         ( hItem[ "access" ] == "write" .OR. hItem[ "access" ] == "use" )
         RETURN .T.
      ENDIF
   NEXT

   RETURN .F.

// índice de funções do projeto p/ resolução de chamada: STATIC vence no
// próprio módulo, pública em qualquer um (mesma regra do linker/VM)
STATIC FUNCTION FuncIndex( hProj, hAsts )

   LOCAL hIdx := { "static" => { => }, "public" => { => }, "names" => { => } }
   LOCAL cPath, hAst, hFunc, cKey

   FOR EACH cPath IN hProj[ "files" ]
      hAst := hAsts[ cPath ]
      FOR EACH hFunc IN hAst[ "functions" ]
         IF hFunc[ "fileDecl" ]
            LOOP
         ENDIF
         cKey := Upper( hFunc[ "name" ] )
         hIdx[ "names" ][ cKey ] := .T.
         IF hFunc[ "static" ]
            hIdx[ "static" ][ cPath + "!" + cKey ] := { cPath, hFunc }
         ELSE
            hIdx[ "public" ][ cKey ] := { cPath, hFunc }
         ENDIF
      NEXT
   NEXT

   RETURN hIdx

// fecho transitivo dos callees a partir de (módulo, função) com furos:
// tudo que roda ENQUANTO um PRIVATE do ponto de partida vive. Furos =
// arestas que o grafo estático não segue: macro '&', send, string com nome
// de função do projeto (chamada dinâmica possível), função nem do projeto
// nem do core Harbour.
STATIC FUNCTION ReachFrom( hProj, hAsts, hIdx, cStartPath, cStartFunc )

   LOCAL hSeen := { => }, aQueue := {}, aHoles := {}, aFuncs := {}
   LOCAL aCur, cPath, hFunc, hAst, hItem, cKey, cTgt, aDef, hTok

   AAdd( aQueue, { cStartPath, Upper( cStartFunc ) } )
   DO WHILE ! Empty( aQueue )
      aCur := aQueue[ 1 ]
      hb_ADel( aQueue, 1, .T. )
      cTgt := aCur[ 2 ]
      // resolução: static do módulo chamador > pública de qualquer módulo
      IF hb_HHasKey( hIdx[ "static" ], aCur[ 1 ] + "!" + cTgt )
         aDef := hIdx[ "static" ][ aCur[ 1 ] + "!" + cTgt ]
      ELSEIF hb_HHasKey( hIdx[ "public" ], cTgt )
         aDef := hIdx[ "public" ][ cTgt ]
      ELSE
         IF ! CoreFunction( hProj, cTgt )
            AAdd( aHoles, "função '" + cTgt + "' fora do projeto e do core Harbour" )
         ENDIF
         LOOP
      ENDIF
      cPath := aDef[ 1 ]
      hFunc := aDef[ 2 ]
      cKey := cPath + "!" + Upper( hFunc[ "name" ] )
      IF hb_HHasKey( hSeen, cKey )
         LOOP
      ENDIF
      hSeen[ cKey ] := .T.
      AAdd( aFuncs, { cPath, hFunc } )

      IF hFunc[ "usesMacro" ]
         AAdd( aHoles, hFunc[ "name" ] + " (" + hb_FNameNameExt( cPath ) + ") usa macro '&'" )
      ENDIF
      IF ! Empty( hFunc[ "sends" ] )
         AAdd( aHoles, hFunc[ "name" ] + " (" + hb_FNameNameExt( cPath ) + ") envia mensagens (método - alvo dinâmico)" )
      ENDIF
      // string com nome de função do projeto = chamada dinâmica possível
      hAst := hAsts[ cPath ]
      FOR EACH hTok IN hAst[ "tokens" ]
         IF hTok[ "type" ] == 41 .AND. hTok[ "line" ] > 0 .AND. ;
            hb_HHasKey( hIdx[ "names" ], Upper( hTok[ "text" ] ) ) .AND. ;
            InFuncSpan( hAst, hFunc, hTok[ "line" ] )
            AAdd( aHoles, hFunc[ "name" ] + " (" + hb_FNameNameExt( cPath ) + ":" + ;
                  hb_ntos( hTok[ "line" ] ) + ") cita '" + hTok[ "text" ] + "' em string (chamada dinâmica possível)" )
         ENDIF
      NEXT
      FOR EACH hItem IN hFunc[ "calls" ]
         IF ! Left( hItem[ "sym" ], 4 ) == "__MV"
            AAdd( aQueue, { cPath, hItem[ "sym" ] } )
         ENDIF
      NEXT
   ENDDO

   RETURN { "funcs" => aFuncs, "holes" => aHoles }

// o mapa impresso pelo usages quando o nome tem vida de memvar
STATIC PROCEDURE MvMapReport( hProj, hAsts, cUp )

   LOCAL hF := MvFacts( hProj, hAsts, cUp )
   LOCAL hIdx, aC, aI, hReach, cLine, nPub := 0, nPriv := 0

   IF Empty( hF[ "creators" ] ) .AND. Empty( hF[ "uses" ] )
      RETURN
   ENDIF

   OutStd( "memvar map for '" + cUp + "':" + hb_eol() )
   hIdx := FuncIndex( hProj, hAsts )

   FOR EACH aC IN hF[ "creators" ]
      OutStd( "  creator: " + aC[ 4 ] + " in " + aC[ 2 ] + " (" + aC[ 1 ] + ":" + ;
              hb_ntos( aC[ 3 ] ) + ")" + hb_eol() )
      IF aC[ 4 ] == "PUBLIC"
         nPub++
      ELSE
         nPriv++
      ENDIF
      hReach := ReachFrom( hProj, hAsts, hIdx, aC[ 5 ], aC[ 2 ] )
      cLine := ""
      FOR EACH aI IN hReach[ "funcs" ]
         IF ! Upper( aI[ 2 ][ "name" ] ) == Upper( aC[ 2 ] )
            cLine += iif( Empty( cLine ), "", ", " ) + aI[ 2 ][ "name" ]
         ENDIF
      NEXT
      OutStd( "    dynamic reach: " + iif( Empty( cLine ), "(nenhum callee no projeto)", cLine ) + hb_eol() )
      FOR EACH cLine IN hReach[ "holes" ]
         OutStd( "    hole in reach: " + cLine + hb_eol() )
      NEXT
   NEXT
   IF nPriv > 0 .AND. nPub > 0
      OutStd( "  dynamic shadowing: PRIVATE sombreia o PUBLIC homônimo enquanto viver" + hb_eol() )
   ENDIF
   IF nPriv + nPub > 1
      OutStd( "  more than one creator: bindings dependem do caminho de execução" + hb_eol() )
   ENDIF

   FOR EACH aC IN hF[ "decls" ]
      OutStd( "  declared MEMVAR: " + aC[ 1 ] + ":" + hb_ntos( aC[ 3 ] ) + " " + aC[ 2 ] + hb_eol() )
   NEXT
   FOR EACH aC IN hF[ "lexshadow" ]
      OutStd( "  lexical shadow: " + aC[ 2 ] + " (" + aC[ 1 ] + ":" + hb_ntos( aC[ 4 ] ) + ") declara " + ;
              aC[ 3 ] + " homônima - usos ali NÃO são esta memvar" + hb_eol() )
   NEXT
   FOR EACH aC IN hF[ "fields" ]
      OutStd( "  FIELD homônimo: " + aC[ 2 ] + " (" + aC[ 1 ] + ":" + hb_ntos( aC[ 3 ] ) + ;
              ") - dado externo (workarea), nunca editado" + hb_eol() )
   NEXT
   FOR EACH aC IN hF[ "macrocreates" ]
      OutStd( "  macro creation: " + aC[ 2 ] + " (" + aC[ 1 ] + ":" + hb_ntos( aC[ 3 ] ) + ;
              ") cria memvar via '&' - nome invisível ao compilador" + hb_eol() )
   NEXT
   FOR EACH aC IN hF[ "uses" ]
      IF aC[ 5 ]      // implícita (sem declaração) - vale destaque no mapa
         OutStd( "  implicit use: " + aC[ 2 ] + " (" + aC[ 1 ] + ":" + hb_ntos( aC[ 3 ] ) + ", " + ;
                 aC[ 4 ] + ") - memvar não declarada" + hb_eol() )
      ENDIF
   NEXT

   RETURN

// ---------------------------------------------------------------------------
// rename-memvar - só quando o fecho é FECHADO e LIMPO (território H por
// natureza; a recusa explica o furo):
//   1 criador exato; todos os usos do projeto dentro do alcance dinâmico
//   do criador; nenhum furo no alcance (macro/send/dinâmica/externa);
//   nome novo sem vida própria (memvar/criador/decl) e sem declaração
//   léxica homônima nas funções que usam o velho (mudaria binding em
//   silêncio - a recusa-chave da spec); strings com o nome velho =
//   call-by-name possível (TYPE/__mvGet) - aviso + --force.
// Verificação: HrbEquivalent (símbolo renomeado, pcode byte-idêntico) em
// todos os módulos + rollback; execução idêntica é contrato da suíte.
// ---------------------------------------------------------------------------

STATIC FUNCTION RenameMemvar( aArgs )

   LOCAL cSpec, cOld, cNew, lForce := .F., lDryRun := .F., nI
   LOCAL hProj, cTmp, cPath, hAst, hAsts := { => }, hRule, hFunc, hItem
   LOCAL cUpOld, cUpNew, hF, hFNew, hIdx, hReach, hInReach, aC, aU, aWarn := {}
   LOCAL hEdits := { => }, aE, hLines, nLine, cText, hOrig := { => }, nTotal := 0
   LOCAL cWhy := ""

   IF Len( aArgs ) < 4
      Usage()
      RETURN EXIT_USAGE
   ENDIF
   cSpec := aArgs[ 2 ]
   cOld  := aArgs[ 3 ]
   cNew  := aArgs[ 4 ]
   FOR nI := 5 TO Len( aArgs )
      DO CASE
      CASE Lower( aArgs[ nI ] ) == "--force"
         lForce := .T.
      CASE Lower( aArgs[ nI ] ) == "--dry-run"
         lDryRun := .T.
      ENDCASE
   NEXT
   cUpOld := Upper( cOld )
   cUpNew := Upper( cNew )

   IF ! OneWord( cNew )
      RETURN Refuse( "novo nome '" + cNew + "' não é uma palavra única" )
   ENDIF
   IF cUpOld == cUpNew
      RETURN Refuse( "nomes velho e novo são idênticos" )
   ENDIF

   hProj := LoadProject( cSpec )
   IF hProj == NIL
      RETURN Refuse( "não consegui resolver o projeto '" + cSpec + "'" )
   ENDIF
   cTmp := WorkDir()
   IF ! NameAccepted( hProj, cNew, .F. )
      RETURN Refuse( "o compilador do projeto rejeita '" + cNew + "' como nome de variável" )
   ENDIF
   IF ! AstDumps( hProj, cTmp )
      RETURN Refuse( "o projeto não compila - corrija os erros de build primeiro" )
   ENDIF
   FOR EACH cPath IN hProj[ "files" ]
      hAst := ReadAst( cTmp, cPath )
      IF hAst == NIL
         RETURN Refuse( "dump ausente/inválido para '" + cPath + "'" )
      ENDIF
      hAsts[ cPath ] := hAst
      IF ( hRule := RuleHeadCollision( hAst, cUpNew ) ) != NIL
         RETURN Refuse( "novo nome '" + cNew + "' colide com regra de pré-processador (" + ;
                        RuleTag( hRule ) + ", " + RuleWhere( hRule ) + ")" )
      ENDIF
   NEXT

   hF := MvFacts( hProj, hAsts, cUpOld )

   // o alvo existe como memvar?
   IF Empty( hF[ "creators" ] ) .AND. Empty( hF[ "uses" ] ) .AND. Empty( hF[ "decls" ] )
      RETURN Refuse( "'" + cOld + "' não é memvar do projeto (nenhum criador, uso ou MEMVAR)" )
   ENDIF

   // política de fecho: exatamente UM criador explícito
   IF Empty( hF[ "creators" ] )
      IF ! Empty( hF[ "uses" ] )
         aU := hF[ "uses" ][ 1 ]
         RETURN Refuse( "'" + cOld + "' não tem criador PRIVATE/PUBLIC no projeto (uso " + ;
                        iif( aU[ 5 ], "implícito", "declarado" ) + " em " + aU[ 1 ] + ":" + ;
                        hb_ntos( aU[ 3 ] ) + ") - criada fora do projeto ou só em runtime; recuso" )
      ENDIF
      RETURN Refuse( "'" + cOld + "' só existe como declaração MEMVAR (sem criador nem uso) - nada a renomear com segurança" )
   ENDIF
   IF Len( hF[ "creators" ] ) > 1
      cWhy := ""
      FOR EACH aC IN hF[ "creators" ]
         cWhy += iif( Empty( cWhy ), "", "; " ) + aC[ 4 ] + " em " + aC[ 2 ] + " (" + ;
                 aC[ 1 ] + ":" + hb_ntos( aC[ 3 ] ) + ")"
      NEXT
      RETURN Refuse( "'" + cOld + "' tem mais de um criador - bindings dependem do caminho de execução: " + cWhy )
   ENDIF
   aC := hF[ "creators" ][ 1 ]

   // alcance dinâmico do criador: fecho dos callees, sem furos
   hIdx := FuncIndex( hProj, hAsts )
   hReach := ReachFrom( hProj, hAsts, hIdx, aC[ 5 ], aC[ 2 ] )
   IF ! Empty( hReach[ "holes" ] )
      OutErr( "hbrefactor: o alcance dinâmico de " + aC[ 2 ] + " tem furos:" + hb_eol() )
      FOR EACH cWhy IN hReach[ "holes" ]
         OutErr( "  - " + cWhy + hb_eol() )
      NEXT
      RETURN Refuse( "alcance com furos - código fora do grafo estático pode ver '" + cOld + "'; recuso" )
   ENDIF
   hInReach := { => }
   FOR EACH aU IN hReach[ "funcs" ]
      hInReach[ aU[ 1 ] + "!" + Upper( aU[ 2 ][ "name" ] ) ] := .T.
   NEXT

   // todos os usos do projeto dentro do alcance
   FOR EACH aU IN hF[ "uses" ]
      IF ! hb_HHasKey( hInReach, aU[ 7 ] + "!" + Upper( aU[ 2 ] ) )
         RETURN Refuse( "uso de '" + cOld + "' fora do alcance do criador: " + aU[ 2 ] + ;
                        " (" + aU[ 1 ] + ":" + hb_ntos( aU[ 3 ] ) + ") nunca roda com esse " + ;
                        aC[ 4 ] + " vivo - outra memvar homônima; recuso" )
      ENDIF
   NEXT
   // criação via macro dentro do alcance = pode ser este nome
   FOR EACH aU IN hF[ "macrocreates" ]
      IF hb_HHasKey( hInReach, MvModPath( hProj, aU[ 1 ] ) + "!" + Upper( aU[ 2 ] ) )
         RETURN Refuse( "criação de memvar via '&' no alcance (" + aU[ 2 ] + ", " + aU[ 1 ] + ":" + ;
                        hb_ntos( aU[ 3 ] ) + ") - o nome criado é invisível ao compilador; recuso" )
      ENDIF
      AAdd( aWarn, "criação via '&' fora do alcance em " + aU[ 2 ] + " (" + aU[ 1 ] + ":" + ;
            hb_ntos( aU[ 3 ] ) + ") - não roda com o " + aC[ 4 ] + " vivo, mas confira" )
   NEXT

   // nome novo: sem vida própria de memvar e sem sombra léxica onde o velho vive
   hFNew := MvFacts( hProj, hAsts, cUpNew )
   IF ! Empty( hFNew[ "creators" ] ) .OR. ! Empty( hFNew[ "uses" ] ) .OR. ! Empty( hFNew[ "decls" ] )
      RETURN Refuse( "'" + cNew + "' já tem vida de memvar no projeto (criador/uso/MEMVAR) - o rename fundiria duas variáveis" )
   ENDIF
   FOR EACH cPath IN hProj[ "files" ]
      hAst := hAsts[ cPath ]
      FOR EACH hFunc IN hAst[ "functions" ]
         IF ! MvFuncUsesOld( hFunc, cUpOld )
            LOOP
         ENDIF
         FOR EACH hItem IN hFunc[ "declarations" ]
            IF Upper( hItem[ "sym" ] ) == cUpNew
               RETURN Refuse( "'" + cNew + "' é " + hItem[ "scope" ] + " em " + hFunc[ "name" ] + " (" + ;
                              hb_FNameNameExt( cPath ) + ":" + hb_ntos( hItem[ "declLine" ] ) + ;
                              ") que usa '" + cOld + "' - os usos renomeados mudariam de binding em silêncio" )
            ENDIF
         NEXT
         FOR EACH hItem IN hFunc[ "occurrences" ]
            IF Upper( hItem[ "sym" ] ) == cUpNew .AND. hItem[ "block" ] .AND. hItem[ "scope" ] == "local"
               RETURN Refuse( "'" + cNew + "' é parâmetro de codeblock em " + hFunc[ "name" ] + ;
                              " que usa '" + cOld + "' - usos dentro do bloco seriam sombreados" )
            ENDIF
         NEXT
      NEXT
      // strings com o nome velho: call-by-name possível (TYPE, __mvGet...)
      FOR EACH hItem IN hAst[ "tokens" ]
         IF hItem[ "type" ] == 41 .AND. hItem[ "line" ] > 0 .AND. Upper( hItem[ "text" ] ) == cUpOld
            AAdd( aWarn, hb_FNameNameExt( cPath ) + ":" + hb_ntos( hItem[ "line" ] ) + ;
                  ": string igual a '" + cOld + "' - possível acesso por nome (não será alterada)" )
         ENDIF
      NEXT
   NEXT

   FOR nI := 1 TO Len( aWarn )
      OutErr( "warning: " + aWarn[ nI ] + hb_eol() )
   NEXT
   IF ! Empty( aWarn ) .AND. ! lForce
      RETURN Refuse( "avisos acima - repita com --force para prosseguir sem tocá-los" )
   ENDIF

   // sites: declarações MEMVAR + declaração PRIVATE/linha do PUBLIC + usos
   FOR EACH cPath IN hProj[ "files" ]
      hAst := hAsts[ cPath ]
      hLines := { => }
      FOR EACH hFunc IN hAst[ "functions" ]
         FOR EACH hItem IN hFunc[ "declarations" ]
            IF Upper( hItem[ "sym" ] ) == cUpOld .AND. ;
               ( hItem[ "scope" ] == "memvar" .OR. hItem[ "scope" ] == "private" )
               hLines[ hItem[ "declLine" ] ] := .T.
            ENDIF
         NEXT
         FOR EACH hItem IN hFunc[ "occurrences" ]
            IF Upper( hItem[ "sym" ] ) == cUpOld .AND. ;
               ( hItem[ "scope" ] == "memvar" .OR. hItem[ "scope" ] == "memvar_implicit" )
               hLines[ hItem[ "line" ] ] := .T.
            ENDIF
         NEXT
      NEXT
      aE := {}
      FOR EACH nLine IN hb_HKeys( hLines )
         FOR EACH hItem IN MvLineHits( hAst, nLine, cUpOld )
            AAdd( aE, hItem )
         NEXT
      NEXT
      IF ! Empty( aE )
         DedupHits( aE )
         hEdits[ cPath ] := aE
         nTotal += Len( aE )
      ENDIF
   NEXT
   IF nTotal == 0
      RETURN Refuse( "nenhum site editável encontrado para '" + cOld + "'" )
   ENDIF

   OutStd( "rename-memvar: " + cOld + " -> " + cNew + " (criador " + aC[ 4 ] + " em " + ;
           aC[ 2 ] + ", alcance fechado e limpo)" + hb_eol() )
   FOR EACH cPath IN hb_HKeys( hEdits )
      FOR EACH aE IN hEdits[ cPath ]
         OutStd( "  " + hb_FNameNameExt( cPath ) + ":" + hb_ntos( aE[ 1 ] ) + ":" + ;
                 hb_ntos( aE[ 2 ] ) + hb_eol() )
      NEXT
   NEXT
   IF lDryRun
      OutStd( "dry run - nada foi escrito" + hb_eol() )
      RETURN EXIT_OK
   ENDIF

   IF ! CompileHrbAll( hProj, cTmp, "before" )
      RETURN Refuse( "falha ao compilar o estado de referência" )
   ENDIF
   FOR EACH cPath IN hb_HKeys( hEdits )
      cText := hb_MemoRead( cPath )
      hOrig[ cPath ] := cText
      hb_MemoWrit( cPath, ApplyTokenEdits( cText, hEdits[ cPath ], cOld, cNew, @nLine ) )
      IF nLine > 0
         RollbackAll( hOrig )
         RETURN Refuse( "texto em " + hb_FNameNameExt( cPath ) + ":" + hb_ntos( nLine ) + ;
                        " não confere - rollback" )
      ENDIF
   NEXT
   IF ! CompileHrbAll( hProj, cTmp, "after" )
      RollbackAll( hOrig )
      RETURN Refuse( "o projeto parou de compilar após o rename - rollback" )
   ENDIF
   FOR EACH cPath IN hProj[ "files" ]
      IF ! HrbEquivalent( hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cPath ) + ".before.hrb" ), ;
                          hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cPath ) + ".after.hrb" ), ;
                          cUpOld, cUpNew, @cWhy )
         RollbackAll( hOrig )
         RETURN Refuse( "verificação FALHOU em " + hb_FNameName( cPath ) + ": " + cWhy + " - rollback" )
      ENDIF
   NEXT

   OutStd( "verified: " + hb_ntos( nTotal ) + " edit(s); symbol renamed, pcode byte-identical" + hb_eol() )

   RETURN EXIT_OK

STATIC FUNCTION MvFuncUsesOld( hFunc, cUpOld )

   LOCAL hItem

   FOR EACH hItem IN hFunc[ "occurrences" ]
      IF Upper( hItem[ "sym" ] ) == cUpOld .AND. ;
         ( hItem[ "scope" ] == "memvar" .OR. hItem[ "scope" ] == "memvar_implicit" )
         RETURN .T.
      ENDIF
   NEXT

   RETURN .F.

STATIC FUNCTION MvModPath( hProj, cMod )

   LOCAL cPath

   FOR EACH cPath IN hProj[ "files" ]
      IF hb_FNameNameExt( cPath ) == cMod
         RETURN cPath
      ENDIF
   NEXT

   RETURN cMod

// tokens editáveis do nome numa linha: exclui contexto :msg (type 58) e
// alias->campo (type 59) - EXCETO o alias de memvar M->nome, que é uso da
// própria memvar (o token antes do '->' é o identificador 'M')
STATIC FUNCTION MvLineHits( hAst, nLine, cUpOld )

   LOCAL aHits := {}, hTok, aPrev := NIL, aPrev2 := NIL

   FOR EACH hTok IN hAst[ "tokens" ]
      IF hTok[ "type" ] == 21 .AND. hTok[ "prov" ] == "s" .AND. hTok[ "col" ] != NIL .AND. ;
         hTok[ "line" ] == nLine .AND. Upper( hTok[ "text" ] ) == cUpOld
         DO CASE
         CASE aPrev != NIL .AND. aPrev[ "type" ] == 58                       // :msg
         CASE aPrev != NIL .AND. aPrev[ "type" ] == 59 .AND. ;
              !( aPrev2 != NIL .AND. Upper( aPrev2[ "text" ] ) == "M" )      // alias-> que não é M->
         OTHERWISE
            AddHit( aHits, hTok )
         ENDCASE
      ENDIF
      aPrev2 := aPrev
      aPrev := hTok
   NEXT

   RETURN aHits

// ---------------------------------------------------------------------------
// fase B4d - refatoração do NOME DE MATCH MARKER de diretiva de pp, sobre o
// rastro de derivação (schema ast-3). O pp registra, no instante da
// expansão, de QUAL marker de QUAL aplicação cada token sintetizado deriva
// ("from": clone/paste/stringify + faixa de bytes [at, at+len) dentro do
// token composto). Nome de marker = o valor que o programador escreve e que
// preenche um match marker (<x>) de uma diretiva; artefatos = fecho dos
// tokens cujo "from" alcança esse nome (transitivo: multi-passe resolve
// pelos "from" copiados nos tokens consumidos de ppApplications). As âncoras
// por FORMA da B4c (MethodLift/ClassRegs/StmtStrings/DeclHits) morreram aqui:
// nenhuma colagem "_" tentada, nenhuma comparação de string com nome de
// função - só fatos gravados pelo pp no instante da síntese. Genérico por
// construção: vale para hbclass.ch, para as cinco famílias e para qualquer
// diretiva que venha a ser criada no mesmo funil.
// ---------------------------------------------------------------------------

STATIC FUNCTION FromReady( hAst )
   RETURN hb_HGetDef( hAst, "schema", "" ) == "ast-3"

STATIC FUNCTION PairKey( nApp, nMarker )
   RETURN hb_ntos( nApp ) + "|" + hb_ntos( nMarker )

// a faixa [at, at+len) de um item de "from" soletra o nome? A precisão vem
// daqui: o fecho por (aplicação, marker) é grosso - um marker carrega a
// expressão inteira - e o recorte byte-exato devolve só o nome
STATIC FUNCTION FromSpells( hTok, hFrom, cUp )
   RETURN Upper( SubStr( hTok[ "text" ], hFrom[ "at" ] + 1, hFrom[ "len" ] ) ) == cUp

// sementes do nome de marker num módulo: pares (aplicação, marker) alimentados
// pelo nome escrito - transitivo numa única passada, porque "from" só
// referencia aplicações ANTERIORES - e os sites escritos {linha, col 1-based}
STATIC FUNCTION PpMarkerSeeds( hAst, cUp )

   LOCAL hPairs := { => }, aSites := {}, hApp, hTok, nApp

   FOR EACH hApp IN hAst[ "ppApplications" ]
      nApp := hApp:__enumIndex() - 1
      FOR EACH hTok IN hApp[ "tokens" ]
         IF hTok[ "marker" ] == 0
            LOOP
         ENDIF
         IF hTok[ "type" ] == 21 .AND. hTok[ "prov" ] == "s" .AND. ;
            hTok[ "col" ] != NIL .AND. Upper( hTok[ "text" ] ) == cUp
            AddHit( aSites, hTok )
            hPairs[ PairKey( nApp, hTok[ "marker" ] ) ] := .T.
         ELSEIF hb_HHasKey( hTok, "from" ) .AND. ;
            ! Empty( PpMarkerRanges( hAst, hTok, hPairs, cUp ) )
            hPairs[ PairKey( nApp, hTok[ "marker" ] ) ] := .T.
         ENDIF
      NEXT
   NEXT

   RETURN { "pairs" => hPairs, "sites" => aSites }

// faixas de bytes de um token que derivam do nome de marker. O caso direto é a
// faixa de "from" soletrar o nome; um CLONE de token composto (multi-passe:
// a colagem re-consumida por outra regra) soletra o composto inteiro - aí a
// resolução desce um nível pelo apptoken consumido, cujas faixas valem aqui
// com o mesmo offset (textos idênticos por construção). Recursivo até o fato
STATIC FUNCTION PpMarkerRanges( hAst, hTok, hPairs, cUp )

   LOCAL aRanges := {}, hFrom, hApp, hTA, aR, cPart

   IF ! hb_HHasKey( hTok, "from" )
      RETURN aRanges
   ENDIF
   FOR EACH hFrom IN hTok[ "from" ]
      IF ! hb_HHasKey( hPairs, PairKey( hFrom[ "app" ], hFrom[ "marker" ] ) )
         LOOP
      ENDIF
      IF FromSpells( hTok, hFrom, cUp )
         AAdd( aRanges, { hFrom[ "at" ], hFrom[ "len" ] } )
      ELSE
         cPart := SubStr( hTok[ "text" ], hFrom[ "at" ] + 1, hFrom[ "len" ] )
         hApp  := hAst[ "ppApplications" ][ hFrom[ "app" ] + 1 ]
         FOR EACH hTA IN hApp[ "tokens" ]
            IF hTA[ "marker" ] == hFrom[ "marker" ] .AND. hTA[ "text" ] == cPart
               FOR EACH aR IN PpMarkerRanges( hAst, hTA, hPairs, cUp )
                  AAdd( aRanges, { hFrom[ "at" ] + aR[ 1 ], aR[ 2 ] } )
               NEXT
               EXIT
            ENDIF
         NEXT
      ENDIF
   NEXT

   RETURN aRanges

// artefatos do nome de marker no stream do módulo: tokens com faixa derivada do
// nome. Cada item: { índice 0-based no stream, o token, faixas do nome de marker
// {at,len} (aMine), co-derivações (aOthers - itens de "from" de OUTROS
// nomes no mesmo token composto, ex.: a CLASSE em CLASSE_METODO) }
STATIC FUNCTION PpMarkerArtifacts( hAst, hPairs, cUp )

   LOCAL aArts := {}, hTok, hFrom, aMine, aOthers

   FOR EACH hTok IN hAst[ "tokens" ]
      IF hb_HHasKey( hTok, "from" )
         aMine := PpMarkerRanges( hAst, hTok, hPairs, cUp )
         IF ! Empty( aMine )
            aOthers := {}
            FOR EACH hFrom IN hTok[ "from" ]
               IF ! hb_HHasKey( hPairs, PairKey( hFrom[ "app" ], hFrom[ "marker" ] ) )
                  AAdd( aOthers, hFrom )
               ENDIF
            NEXT
            AAdd( aArts, { hTok:__enumIndex() - 1, hTok, aMine, aOthers } )
         ENDIF
      ENDIF
   NEXT

   RETURN aArts

// texto previsto de um artefato após renomear o nome de marker: substitui cada
// faixa {at,len} que soletra o nome velho (descendente por "at" para os
// offsets não se moverem) - é daqui que sai o mapa de símbolos/strings
// esperado da verificação (computado do rastro, não declarado à mão)
STATIC FUNCTION PredictText( cText, aMine, cNew )

   LOCAL aSorted := AClone( aMine ), aR

   ASort( aSorted,,, {| x, y | x[ 1 ] > y[ 1 ] } )
   FOR EACH aR IN aSorted
      cText := hb_BLeft( cText, aR[ 1 ] ) + cNew + ;
               hb_BSubStr( cText, aR[ 1 ] + aR[ 2 ] + 1 )
   NEXT

   RETURN cText

// faixa de índices de token das statements de cada função: containment de
// artefato pelo ÍNDICE no stream (strings de registro nascem com line 0 -
// linha não serve; o índice não mente). birthTok tem folga de lookahead,
// suficiente para "a string está dentro desta função"
STATIC FUNCTION FuncStmtSpans( hAst )

   LOCAL aSpans := {}, hFunc, hStmt, nMin, nMax

   FOR EACH hFunc IN hAst[ "functions" ]
      nMin := -1
      nMax := -1
      FOR EACH hStmt IN hFunc[ "statements" ]
         nMin := iif( nMin < 0, SpanMin( hStmt[ "expr" ] ), ;
                      Min( nMin, SpanMin( hStmt[ "expr" ] ) ) )
         nMax := Max( nMax, SpanMax( hStmt[ "expr" ] ) )
      NEXT
      IF nMin >= 0
         AAdd( aSpans, { hFunc, nMin, nMax } )
      ENDIF
   NEXT

   RETURN aSpans

// função que contém o token de índice nTok - o span MAIS APERTADO ganha
// (o container fileDecl pode envolver o módulo inteiro)
STATIC FUNCTION FuncOfTokIdx( aSpans, nTok )

   LOCAL aSpan, aBest := NIL

   FOR EACH aSpan IN aSpans
      IF nTok >= aSpan[ 2 ] .AND. nTok <= aSpan[ 3 ] .AND. ;
         ( aBest == NIL .OR. aSpan[ 3 ] - aSpan[ 2 ] < aBest[ 3 ] - aBest[ 2 ] )
         aBest := aSpan
      ENDIF
   NEXT

   RETURN iif( aBest == NIL, NIL, aBest[ 1 ] )

// a própria função NASCEU de expansão? O token do nome dela carrega "from"
// (clone posicionado na linha da função, ou colagem sem linha)
STATIC FUNCTION FuncDerived( hAst, hFunc )

   LOCAL hTok, cUp := Upper( hFunc[ "name" ] )

   FOR EACH hTok IN hAst[ "tokens" ]
      IF hTok[ "type" ] == 21 .AND. hb_HHasKey( hTok, "from" ) .AND. ;
         Upper( hTok[ "text" ] ) == cUp .AND. ;
         ( hTok[ "line" ] == hFunc[ "line" ] .OR. hTok[ "line" ] == 0 )
         RETURN .T.
      ENDIF
   NEXT

   RETURN .F.

STATIC FUNCTION FuncByName( hAst, cName )

   LOCAL hFunc, cUp := Upper( cName )

   FOR EACH hFunc IN hAst[ "functions" ]
      IF ! hFunc[ "fileDecl" ] .AND. Upper( hFunc[ "name" ] ) == cUp
         RETURN hFunc
      ENDIF
   NEXT

   RETURN NIL

// donos do nome de marker num módulo (no hbclass: as classes; genérico: o outro
// nome da co-derivação). Dois fatos, nenhum vocabulário de família:
//   paste : artefato que NOMEIA função do módulo e co-deriva de outro nome
//           -> o outro nome é dono (implementação separada CLASSE_METODO)
//   string: artefato de stringify contido (por índice) numa função GERADA
//           por expansão -> o nome dela é dono (INLINE/VAR: sem colagem)
// Uma função cujo NOME co-deriva da próprio nome de marker nunca é dona dela
// (a string de registro de uma DSL simples vive DENTRO da função gerada -
// isso é o artefato, não uma dona). Clones não contam: um clone
// posicionado é o próprio nome escrito.
// Devolve { DONO_UPPER => { "via" =>, "impl" => hFunc|NIL } }
STATIC FUNCTION PpMarkerOwners( hAst, aArts, aSpans, cUp )

   LOCAL hOwners := { => }, aArt, hTok, hFrom, hFunc, cOwn

   FOR EACH aArt IN aArts
      hTok := aArt[ 2 ]
      IF hTok[ "type" ] == 21 .AND. ! Empty( aArt[ 4 ] ) .AND. ;
         ( hFunc := FuncByName( hAst, hTok[ "text" ] ) ) != NIL
         FOR EACH hFrom IN aArt[ 4 ]
            cOwn := Upper( SubStr( hTok[ "text" ], hFrom[ "at" ] + 1, hFrom[ "len" ] ) )
            IF ! Empty( cOwn )
               hOwners[ cOwn ] := { "via" => "paste", "impl" => hFunc }
            ENDIF
         NEXT
      ELSEIF hTok[ "type" ] == 41
         hFunc := FuncOfTokIdx( aSpans, aArt[ 1 ] )
         IF hFunc != NIL .AND. ! hFunc[ "fileDecl" ] .AND. ;
            FuncDerived( hAst, hFunc ) .AND. ;
            MethodImplOf( hAst, hFunc, "", cUp ) == NIL
            cOwn := Upper( hFunc[ "name" ] )
            IF ! hb_HHasKey( hOwners, cOwn )
               hOwners[ cOwn ] := { "via" => "string", "impl" => NIL }
            ENDIF
         ENDIF
      ENDIF
   NEXT

   RETURN hOwners

// vocabulário do fonte para um site escrito: a regra da PRIMEIRA aplicação
// que consumiu o token naquela posição (a raiz da cadeia) - "method" para
// hbclass, "handler" para uma DSL de handlers, sem tabela nenhuma
STATIC FUNCTION SeedRootRule( hAst, nLine, nCol0 )

   LOCAL hApp, hTok

   FOR EACH hApp IN hAst[ "ppApplications" ]
      FOR EACH hTok IN hApp[ "tokens" ]
         IF hTok[ "marker" ] > 0 .AND. hTok[ "col" ] != NIL .AND. ;
            hTok[ "line" ] == nLine .AND. hTok[ "col" ] == nCol0
            RETURN hAst[ "ppRules" ][ hApp[ "rule" ] + 1 ]
         ENDIF
      NEXT
   NEXT

   RETURN NIL

// lifting genérico de definição: a função cujo NOME é artefato composto da
// nome de marker. Devolve { método (grafia real), classe/co-derivação (grafia
// real, "" quando não há), linha, coluna 1-based do nome escrito, vocábulo }
// - o vocábulo é a cabeça (minúscula) da regra RAIZ que consumiu o nome:
// "method" no hbclass, "handler" numa DSL de handlers, sem tabela nenhuma
STATIC FUNCTION PpMarkerLift( hAst, hFunc, cUp )

   LOCAL aImpl := MethodImplOf( hAst, hFunc, "", cUp )
   LOCAL hApp, hTok, aHit := NIL, hRule, cVocab

   IF aImpl == NIL
      RETURN NIL
   ENDIF
   // posição real do nome escrito: apptoken posicionado, preferindo o da
   // linha da própria função (a aplicação DECLARED repete o nome com a
   // posição da declaração)
   FOR EACH hApp IN hAst[ "ppApplications" ]
      FOR EACH hTok IN hApp[ "tokens" ]
         IF hTok[ "marker" ] > 0 .AND. hTok[ "type" ] == 21 .AND. ;
            hTok[ "prov" ] == "s" .AND. hTok[ "col" ] != NIL .AND. ;
            Upper( hTok[ "text" ] ) == cUp
            IF hTok[ "line" ] == hFunc[ "line" ]
               aHit := { hTok[ "line" ], hTok[ "col" ] + 1 }
            ELSEIF aHit == NIL
               aHit := { hTok[ "line" ], hTok[ "col" ] + 1 }
            ENDIF
         ENDIF
      NEXT
      IF aHit != NIL .AND. aHit[ 1 ] == hFunc[ "line" ]
         EXIT
      ENDIF
   NEXT
   IF aHit == NIL
      RETURN NIL
   ENDIF
   hRule  := SeedRootRule( hAst, aHit[ 1 ], aHit[ 2 ] - 1 )
   cVocab := iif( hRule == NIL .OR. hRule[ "head" ] == NIL, "dsl", Lower( hRule[ "head" ] ) )

   RETURN { aImpl[ 2 ], aImpl[ 1 ], aHit[ 1 ], aHit[ 2 ], cVocab }

// sites escritos do nome de marker que atravessam diretivas e que nenhum relator
// clássico cobriu (declaração de método, uso em DSL de pp...) - resposta no
// vocabulário do fonte; nomes gerados só com --show-expansion
STATIC FUNCTION PpMarkerHits( hAst, cUp, cModFile, aSrc, aLoc, cPath, nLen, lShowExp )

   LOCAL hEnt := PpMarkerSeeds( hAst, cUp ), aArts, aHit, aL, lSeen
   LOCAL hRule, cWhat, cDeriv, aArt, nHits := 0

   IF Empty( hEnt[ "sites" ] )
      RETURN 0
   ENDIF
   aArts := PpMarkerArtifacts( hAst, hEnt[ "pairs" ], cUp )
   FOR EACH aHit IN hEnt[ "sites" ]
      lSeen := .F.
      FOR EACH aL IN aLoc
         IF aL[ 1 ] == cPath .AND. aL[ 2 ] == aHit[ 1 ] .AND. aL[ 3 ] == aHit[ 2 ] - 1
            lSeen := .T.
            EXIT
         ENDIF
      NEXT
      IF lSeen
         LOOP
      ENDIF
      nHits++
      hRule := SeedRootRule( hAst, aHit[ 1 ], aHit[ 2 ] - 1 )
      cWhat := "name through pp rule" + ;
               iif( hRule == NIL, "", " (" + RuleTag( hRule ) + ", " + RuleWhere( hRule ) + ")" )
      cDeriv := ""
      IF lShowExp
         FOR EACH aArt IN aArts
            cDeriv += iif( Empty( cDeriv ), " -> derives ", ", " ) + ;
                      iif( aArt[ 2 ][ "type" ] == 41, '"' + aArt[ 2 ][ "text" ] + '"', ;
                           aArt[ 2 ][ "text" ] )
         NEXT
      ENDIF
      LocAdd( aLoc, cPath, aHit[ 1 ], { aHit[ 2 ] }, nLen )
      OutStd( cModFile + ":" + hb_ntos( aHit[ 1 ] ) + ":" + hb_ntos( aHit[ 2 ] ) + ": " + ;
              cWhat + cDeriv + SrcLine( aSrc, aHit[ 1 ] ) + hb_eol() )
   NEXT

   RETURN nHits

// tokens do nome numa linha em contexto de SEND (token anterior type 58)
STATIC FUNCTION SendLineHits( hAst, nLine, cUp )

   LOCAL aHits := {}, hTok, aPrev := NIL

   FOR EACH hTok IN hAst[ "tokens" ]
      IF hTok[ "type" ] == 21 .AND. hTok[ "prov" ] == "s" .AND. hTok[ "col" ] != NIL .AND. ;
         hTok[ "line" ] == nLine .AND. Upper( hTok[ "text" ] ) == cUp .AND. ;
         aPrev != NIL .AND. aPrev[ "type" ] == 58
         AddHit( aHits, hTok )
      ENDIF
      aPrev := hTok
   NEXT

   RETURN aHits

STATIC FUNCTION RenameMethod( aArgs )

   LOCAL cSpec, cTarget, cNew, lForce := .F., lDryRun := .F., nI, nAt
   LOCAL cClass := "", cMethod, cUpOld, cUpNew, cUpClass
   LOCAL hProj, cTmp, cPath, hAst, hAsts := { => }, hRule, hFunc, hItem
   LOCAL hFacts := { => }, hF, aOwners := {}, cClassPath := "", lMethod
   LOCAL aWarn := {}, hEdits := { => }, aE, nLine, aSpans, hOwn, aArts
   LOCAL hMap := { => }, hPredStr := { => }, aPS, cPred, cOwn, aArt, hTok
   LOCAL cText, hOrig := { => }, nTotal := 0, cWhy := "", aHit, lOurs

   IF Len( aArgs ) < 4
      Usage()
      RETURN EXIT_USAGE
   ENDIF
   cSpec   := aArgs[ 2 ]
   cTarget := aArgs[ 3 ]
   cNew    := aArgs[ 4 ]
   FOR nI := 5 TO Len( aArgs )
      DO CASE
      CASE Lower( aArgs[ nI ] ) == "--force"
         lForce := .T.
      CASE Lower( aArgs[ nI ] ) == "--dry-run"
         lDryRun := .T.
      ENDCASE
   NEXT
   IF ( nAt := At( ":", cTarget ) ) > 0
      cClass  := Left( cTarget, nAt - 1 )
      cMethod := SubStr( cTarget, nAt + 1 )
   ELSE
      cMethod := cTarget
   ENDIF
   cUpClass := Upper( cClass )
   cUpOld   := Upper( cMethod )
   cUpNew   := Upper( cNew )

   IF ! OneWord( cNew )
      RETURN Refuse( "novo nome '" + cNew + "' não é uma palavra única" )
   ENDIF
   IF cUpOld == cUpNew
      RETURN Refuse( "nomes velho e novo são idênticos" )
   ENDIF

   hProj := LoadProject( cSpec )
   IF hProj == NIL
      RETURN Refuse( "não consegui resolver o projeto '" + cSpec + "'" )
   ENDIF
   cTmp := WorkDir()
   IF ! AstDumps( hProj, cTmp )
      RETURN Refuse( "o projeto não compila - corrija os erros de build primeiro" )
   ENDIF
   FOR EACH cPath IN hProj[ "files" ]
      hAst := ReadAst( cTmp, cPath )
      IF hAst == NIL
         RETURN Refuse( "dump ausente/inválido para '" + cPath + "'" )
      ENDIF
      IF ! FromReady( hAst )
         RETURN Refuse( "dump sem rastro de derivação (schema ast-3) - " + ;
                        "recompile harbour E hbmk2 do branch feature/compiler-ast-dump" )
      ENDIF
      hAsts[ cPath ] := hAst
      IF ( hRule := RuleHeadCollision( hAst, cUpNew ) ) != NIL
         RETURN Refuse( "novo nome '" + cNew + "' colide com regra de pré-processador (" + ;
                        RuleTag( hRule ) + ", " + RuleWhere( hRule ) + ")" )
      ENDIF
   NEXT

   // fatos por módulo: sementes (sites escritos), artefatos derivados e
   // donos por co-derivação - tudo do rastro, nada por forma
   FOR EACH cPath IN hProj[ "files" ]
      hAst   := hAsts[ cPath ]
      aSpans := FuncStmtSpans( hAst )
      hF     := PpMarkerSeeds( hAst, cUpOld )
      aArts  := PpMarkerArtifacts( hAst, hF[ "pairs" ], cUpOld )
      hOwn   := PpMarkerOwners( hAst, aArts, aSpans, cUpOld )
      hFacts[ cPath ] := { "sites" => hF[ "sites" ], "arts" => aArts, "own" => hOwn }
      // o nome NOVO com vida derivada em qualquer classe = mensagem viva
      hF    := PpMarkerSeeds( hAst, cUpNew )
      aArts := PpMarkerArtifacts( hAst, hF[ "pairs" ], cUpNew )
      hOwn  := PpMarkerOwners( hAst, aArts, aSpans, cUpNew )
      IF ! Empty( hOwn )
         cOwn := hb_HKeys( hOwn )[ 1 ]
         RETURN Refuse( "'" + cNew + "' já é membro/mensagem registrada da classe " + cOwn + ;
                        " (" + hb_FNameNameExt( cPath ) + ") - o rename fundiria mensagens" )
      ENDIF
   NEXT

   // donos agregados; a forma sem classe resolve no primeiro dono
   FOR EACH cPath IN hProj[ "files" ]
      hOwn := hFacts[ cPath ][ "own" ]
      FOR EACH cOwn IN hb_HKeys( hOwn )
         IF Empty( cUpClass )
            cUpClass := cOwn                   // resolve a forma sem classe
         ENDIF
         lOurs := cOwn == cUpClass
         AAdd( aOwners, { cOwn, hb_FNameNameExt( cPath ), lOurs } )
         IF lOurs .AND. Empty( cClassPath )
            cClassPath := cPath
         ENDIF
      NEXT
   NEXT
   lMethod := ! Empty( aOwners )

   IF ! lMethod
      // nome de marker sem dona: ou não existe, ou é nome de marker de DSL pura
      // (HANDLER, EVENTO...) - sem mensagem não há política de send
      IF ! Empty( cUpClass )
         RETURN Refuse( "método '" + cMethod + "' não encontrado na classe '" + cClass + "' no projeto" )
      ENDIF
      lOurs := .F.
      FOR EACH cPath IN hProj[ "files" ]
         lOurs := lOurs .OR. ! Empty( hFacts[ cPath ][ "sites" ] )
      NEXT
      IF ! lOurs
         RETURN Refuse( "método '" + cMethod + "' não encontrado no projeto" )
      ENDIF
      // mensagem enviada sem dona identificável = não dá para prever o
      // efeito do rename nos sends - recusa fato-based
      FOR EACH cPath IN hProj[ "files" ]
         FOR EACH hFunc IN hAsts[ cPath ][ "functions" ]
            FOR EACH hItem IN hFunc[ "sends" ]
               IF Upper( hItem[ "sym" ] ) == cUpOld
                  RETURN Refuse( "'" + cMethod + "' é mensagem enviada (" + ;
                                 hb_FNameNameExt( cPath ) + ":" + hb_ntos( hItem[ "line" ] ) + ;
                                 ") sem classe dona identificável - recuso" )
               ENDIF
            NEXT
         NEXT
      NEXT
   ELSE
      IF Empty( cClassPath )
         RETURN Refuse( "método '" + cMethod + "' não encontrado na classe '" + cClass + "' no projeto" )
      ENDIF
      // unicidade da mensagem: sends não têm classe - só renomeamos quando
      // o nome pertence a UMA classe do projeto
      cWhy := ""
      FOR EACH aE IN aOwners
         IF ! aE[ 3 ]
            cWhy += iif( Empty( cWhy ), "", "; " ) + aE[ 1 ] + " (" + aE[ 2 ] + ")"
         ENDIF
      NEXT
      IF ! Empty( cWhy )
         RETURN Refuse( "'" + cMethod + "' também é membro de: " + cWhy + ;
                        " - send é despacho dinâmico, rename ambíguo; recuso" )
      ENDIF
      // membro de DADOS (VAR/DATA): atribuição vira send '_NOME' que este
      // comando não cobre - fora do escopo v1
      FOR EACH cPath IN hProj[ "files" ]
         FOR EACH hFunc IN hAsts[ cPath ][ "functions" ]
            FOR EACH hItem IN hFunc[ "sends" ]
               IF Upper( hItem[ "sym" ] ) == "_" + cUpOld
                  RETURN Refuse( "'" + cMethod + "' recebe atribuição (send _" + cUpOld + " em " + ;
                                 hb_FNameNameExt( cPath ) + ":" + hb_ntos( hItem[ "line" ] ) + ;
                                 ") - é VAR/DATA, não método; fora do escopo do rename-method" )
               ENDIF
               IF Upper( hItem[ "sym" ] ) == cUpNew
                  RETURN Refuse( "'" + cNew + "' já é mensagem enviada em " + hb_FNameNameExt( cPath ) + ;
                                 ":" + hb_ntos( hItem[ "line" ] ) + " - o rename passaria a respondê-la" )
               ENDIF
            NEXT
         NEXT
      NEXT
   ENDIF

   // mapa de símbolos/strings esperado, COMPUTADO do rastro: cada artefato
   // derivado muda deterministicamente - texto previsto = faixas do nome
   // de marker substituídas pelo nome novo
   hMap[ cUpOld ] := cUpNew
   FOR EACH cPath IN hProj[ "files" ]
      aPS := {}
      FOR EACH aArt IN hFacts[ cPath ][ "arts" ]
         hTok  := aArt[ 2 ]
         cPred := PredictText( hTok[ "text" ], aArt[ 3 ], cNew )
         IF hTok[ "type" ] == 21 .AND. !( Upper( hTok[ "text" ] ) == cUpOld )
            hMap[ Upper( hTok[ "text" ] ) ] := Upper( cPred )
         ELSEIF hTok[ "type" ] == 41
            IF hb_AScan( aPS, {| a | a[ 2 ] == cPred }, , , .T. ) == 0
               AAdd( aPS, { hTok[ "text" ], cPred } )
            ENDIF
         ENDIF
      NEXT
      IF ! Empty( aPS )
         hPredStr[ cPath ] := aPS
      ENDIF
   NEXT
   // nomes previstos: o compilador do projeto tem que aceitá-los, e não
   // podem colidir com função existente (recusa por co-derivação: renomear
   // 'a' num artefato <a>_<b> prevê 'b' intacto - se o previsto já existe,
   // a recusa NOMEIA o artefato)
   FOR EACH cOwn IN hb_HKeys( hMap )
      cPred := hMap[ cOwn ]
      IF !( cOwn == cUpOld )
         IF ! NameAccepted( hProj, cPred, .T. )
            RETURN Refuse( "o compilador do projeto rejeita '" + cPred + ;
                           "' (nome da função gerada) - escolha outro nome" )
         ENDIF
         FOR EACH cPath IN hProj[ "files" ]
            IF FuncByName( hAsts[ cPath ], cPred ) != NIL
               RETURN Refuse( "'" + cPred + "' (previsto para o artefato " + cOwn + ;
                              ") já existe como função em " + hb_FNameNameExt( cPath ) + " - recuso" )
            ENDIF
         NEXT
      ENDIF
   NEXT
   // o fonte soletra um nome gerado que vai mudar? renomear o gerador
   // deixaria a grafia manual órfã - recusa nomeando o site
   FOR EACH cPath IN hProj[ "files" ]
      FOR EACH hTok IN hAsts[ cPath ][ "tokens" ]
         IF hTok[ "type" ] == 21 .AND. hTok[ "prov" ] == "s" .AND. ;
            hTok[ "col" ] != NIL .AND. ! hb_HHasKey( hTok, "from" ) .AND. ;
            hb_HHasKey( hMap, Upper( hTok[ "text" ] ) ) .AND. ;
            !( Upper( hTok[ "text" ] ) == cUpOld )
            RETURN Refuse( "o fonte soletra o nome gerado '" + hTok[ "text" ] + "' (" + ;
                           hb_FNameNameExt( cPath ) + ":" + hb_ntos( hTok[ "line" ] ) + ;
                           ") - renomear '" + cMethod + "' o deixaria órfão; recuso" )
         ENDIF
      NEXT
   NEXT

   // sites de edição: sementes escritas (declaração, implementação e
   // qualquer uso que atravessou regra) + sends (fatos do compilador)
   FOR EACH cPath IN hProj[ "files" ]
      hAst := hAsts[ cPath ]
      aE := {}
      FOR EACH aHit IN hFacts[ cPath ][ "sites" ]
         AddHit( aE, { "line" => aHit[ 1 ], "col" => aHit[ 2 ] - 1 } )
      NEXT
      IF lMethod
         FOR EACH hFunc IN hAst[ "functions" ]
            FOR EACH hItem IN hFunc[ "sends" ]
               IF Upper( hItem[ "sym" ] ) == cUpOld
                  FOR EACH aHit IN SendLineHits( hAst, hItem[ "line" ], cUpOld )
                     AddHit( aE, { "line" => aHit[ 1 ], "col" => aHit[ 2 ] - 1 } )
                  NEXT
               ENDIF
            NEXT
         NEXT
      ENDIF
      IF ! Empty( aE )
         hEdits[ cPath ] := aE
      ENDIF
      // string do USUÁRIO com o nome = possível acesso por nome
      // (__objSendMsg, :&) - aviso, nunca edição. O rastro dá o corte
      // exato: string derivada (com "from") se regenera da edição do
      // identificador; string sem "from" é do usuário
      FOR EACH hItem IN hAst[ "tokens" ]
         IF hItem[ "type" ] == 41 .AND. hItem[ "line" ] > 0 .AND. ;
            Upper( hItem[ "text" ] ) == cUpOld .AND. ! hb_HHasKey( hItem, "from" )
            AAdd( aWarn, hb_FNameNameExt( cPath ) + ":" + hb_ntos( hItem[ "line" ] ) + ;
                  ": string igual a '" + cMethod + "' - possível acesso por nome (não será alterada)" )
         ENDIF
      NEXT
   NEXT

   FOR nI := 1 TO Len( aWarn )
      OutErr( "warning: " + aWarn[ nI ] + hb_eol() )
   NEXT
   IF ! Empty( aWarn ) .AND. ! lForce
      RETURN Refuse( "referências textuais encontradas (ver warnings) - repita com --force" )
   ENDIF

   // AddHit já normalizou tudo para pares { linha, coluna 1-based }
   FOR EACH cPath IN hb_HKeys( hEdits )
      aE := hEdits[ cPath ]
      DedupHits( aE )
      nTotal += Len( aE )
   NEXT

   OutStd( "rename-" + iif( lMethod, "method: " + cUpClass + ":", "pp-marker: " ) + ;
           cMethod + " -> " + cNew + hb_eol() )
   FOR EACH cPath IN hb_HKeys( hEdits )
      FOR EACH aE IN hEdits[ cPath ]
         OutStd( "  " + hb_FNameNameExt( cPath ) + ":" + hb_ntos( aE[ 1 ] ) + ":" + ;
                 hb_ntos( aE[ 2 ] ) + hb_eol() )
      NEXT
   NEXT
   // o que o rastro PREVÊ que muda junto (símbolos gerados e strings)
   FOR EACH cOwn IN hb_HKeys( hMap )
      IF !( cOwn == cUpOld )
         OutStd( "  predicted: " + cOwn + " -> " + hMap[ cOwn ] + hb_eol() )
      ENDIF
   NEXT
   FOR EACH cPath IN hb_HKeys( hPredStr )
      FOR EACH aHit IN hPredStr[ cPath ]
         OutStd( "  predicted string: " + '"' + aHit[ 1 ] + '" -> "' + aHit[ 2 ] + '"' + ;
                 " (" + hb_FNameNameExt( cPath ) + ")" + hb_eol() )
      NEXT
   NEXT
   IF lDryRun
      OutStd( "dry run - nada foi escrito" + hb_eol() )
      RETURN EXIT_OK
   ENDIF

   IF ! CompileHrbAll( hProj, cTmp, "before" )
      RETURN Refuse( "falha ao compilar o estado de referência" )
   ENDIF
   FOR EACH cPath IN hb_HKeys( hEdits )
      cText := hb_MemoRead( cPath )
      hOrig[ cPath ] := cText
      hb_MemoWrit( cPath, ApplyTokenEdits( cText, hEdits[ cPath ], cMethod, cNew, @nLine ) )
      IF nLine > 0
         RollbackAll( hOrig )
         RETURN Refuse( "texto em " + hb_FNameNameExt( cPath ) + ":" + hb_ntos( nLine ) + ;
                        " não confere - rollback" )
      ENDIF
   NEXT
   // "after" também regrava os dumps (-x): é neles que as strings
   // previstas são conferidas fato a fato
   IF ! CompileHrbAll( hProj, cTmp, "after", .T. )
      RollbackAll( hOrig )
      RETURN Refuse( "o projeto parou de compilar após o rename - rollback" )
   ENDIF
   // módulos com artefato derivado: o pcode muda DE VERDADE (strings de
   // registro e nome da função gerada) - símbolos conferidos com o mapa
   // COMPUTADO; demais módulos: byte-idêntico com o símbolo renomeado
   FOR EACH cPath IN hProj[ "files" ]
      cText := hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cPath ) + ".before.hrb" )
      cWhy  := hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cPath ) + ".after.hrb" )
      IF ! Empty( hFacts[ cPath ][ "arts" ] )
         IF ! HrbSymbolsRenamed( cText, cWhy, hMap, @cSpec )
            RollbackAll( hOrig )
            RETURN Refuse( "verificação FALHOU em " + hb_FNameName( cPath ) + ": " + cSpec + " - rollback" )
         ENDIF
      ELSE
         IF ! HrbEquivalent( cText, cWhy, cUpOld, cUpNew, @cSpec )
            RollbackAll( hOrig )
            RETURN Refuse( "verificação FALHOU em " + hb_FNameName( cPath ) + ": " + cSpec + " - rollback" )
         ENDIF
      ENDIF
   NEXT
   // strings previstas: o dump pós-edição tem que conter cada uma,
   // byte-exata, como artefato de stringify do nome NOVO
   FOR EACH cPath IN hb_HKeys( hPredStr )
      hAst := ReadAst( cTmp, cPath )
      IF hAst == NIL .OR. ! FromReady( hAst )
         RollbackAll( hOrig )
         RETURN Refuse( "dump pós-edição ausente para " + hb_FNameNameExt( cPath ) + " - rollback" )
      ENDIF
      hF    := PpMarkerSeeds( hAst, cUpNew )
      aArts := PpMarkerArtifacts( hAst, hF[ "pairs" ], cUpNew )
      FOR EACH aHit IN hPredStr[ cPath ]
         lOurs := .F.
         FOR EACH aArt IN aArts
            IF aArt[ 2 ][ "type" ] == 41 .AND. aArt[ 2 ][ "text" ] == aHit[ 2 ]
               lOurs := .T.
               EXIT
            ENDIF
         NEXT
         IF ! lOurs
            RollbackAll( hOrig )
            RETURN Refuse( "string prevista " + '"' + aHit[ 2 ] + '"' + " não confirmada no dump de " + ;
                           hb_FNameNameExt( cPath ) + " - rollback" )
         ENDIF
      NEXT
   NEXT

   IF lMethod
      OutStd( "verified: " + hb_ntos( nTotal ) + " edit(s); message and generated function renamed, " + ;
              "other modules byte-identical" + hb_eol() )
   ELSE
      OutStd( "verified: " + hb_ntos( nTotal ) + " edit(s); derived artifacts renamed as predicted" + hb_eol() )
   ENDIF

   RETURN EXIT_OK

// símbolos/funções iguais módulo um conjunto de renomes esperados; o
// PCODE do módulo pode divergir (strings de registro de mensagem mudam
// de conteúdo e tamanho) - quem fecha o contrato é a execução idêntica
STATIC FUNCTION HrbSymbolsRenamed( cBefore, cAfter, hMap, cWhy )

   LOCAL hA := HrbParse( cBefore ), hB := HrbParse( cAfter )
   LOCAL nI, cName

   cWhy := ""
   IF hA == NIL .OR. hB == NIL
      cWhy := "formato .hrb inesperado"
      RETURN .F.
   ENDIF
   IF Len( hA[ "syms" ] ) != Len( hB[ "syms" ] ) .OR. Len( hA[ "funcs" ] ) != Len( hB[ "funcs" ] )
      cWhy := "contagem de símbolos/funções mudou"
      RETURN .F.
   ENDIF
   FOR nI := 1 TO Len( hA[ "syms" ] )
      cName := hA[ "syms" ][ nI ][ 1 ]
      cName := hb_HGetDef( hMap, cName, cName )
      IF !( cName == hB[ "syms" ][ nI ][ 1 ] )
         cWhy := "símbolo " + hA[ "syms" ][ nI ][ 1 ] + " -> " + hB[ "syms" ][ nI ][ 1 ] + " inesperado"
         RETURN .F.
      ENDIF
   NEXT
   FOR nI := 1 TO Len( hA[ "funcs" ] )
      cName := hA[ "funcs" ][ nI ][ 1 ]
      cName := hb_HGetDef( hMap, cName, cName )
      IF !( cName == hB[ "funcs" ][ nI ][ 1 ] )
         cWhy := "função " + hA[ "funcs" ][ nI ][ 1 ] + " -> " + hB[ "funcs" ][ nI ][ 1 ] + " inesperada"
         RETURN .F.
      ENDIF
   NEXT

   RETURN .T.
