// hbrefactor - refatoração para Harbour sobre a AST do compilador
//
// Segunda encarnação (roadmap v3): TODO conhecimento sintático e semântico
// vem do dump .ast.json (schema ast-1) emitido pelos ganchos do compilador
// (branch feature/compiler-ast-dump). A ferramenta não replica lexer nem
// estrutura: decide e edita texto com fatos do compilador, e verifica
// recompilando e comparando (editor != verificador).
//
//   projeto  : hbmk2 -traceonly resolve qualquer alvo que o hbmk2 aceite
//   dumps    : hbmk2 <alvos> -hbcmp -rebuild -prgflag=-x<dir>/
//   fatos    : tokens com linha/coluna/proveniência, declarações com escopo,
//              occurrences r/w/x, calls, sends, blocks, statements
//
// A primeira encarnação (sobre .occ.json) está em smoketest/ como referência.

#define APP_VERSION "0.2.0"

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
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "unused-locals"
      nExit := UnusedLocals( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "call-graph"
      nExit := CallGraph( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "find-dynamic-calls"
      nExit := FindDynamicCalls( aArgs )
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
   OutStd( "  hbrefactor usages <projeto> <nome> [--func <função>] [--json <out>]" + hb_eol() )
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

   IF ! HB_ISHASH( hAst ) .OR. ! hb_HGetDef( hAst, "schema", "" ) == "ast-1"
      RETURN NIL
   ENDIF

   RETURN hAst

STATIC FUNCTION WorkDir()

   LOCAL cTmp := hb_DirSepAdd( hb_DirTemp() ) + "hbrefactor_" + ;
                 StrTran( StrTran( hb_TSToStr( hb_DateTime() ), ":", "" ), " ", "_" )

   hb_DirCreate( cTmp )

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

   LOCAL cSpec, cName, cFuncFilter := "", cJsonOut := ""
   LOCAL hProj, cTmp, cPath, hAst, hFunc, hItem, nI
   LOCAL nHits := 0, cModFile, aSrc, cUp, aLoc := {}

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
         ELSEIF Upper( Right( hFunc[ "name" ], Len( cName ) + 1 ) ) == "_" + cUp
            nHits++
            LocAdd( aLoc, cPath, hFunc[ "line" ], {}, Len( cName ) )
            OutStd( cModFile + ":" + hb_ntos( hFunc[ "line" ] ) + ": possible method definition (" + ;
               hFunc[ "name" ] + ", name convention)" + hb_eol() )
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
   NEXT

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
   OutStd( "dumps ast-1 em: " + cTmp + hb_eol() )

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

   FOR EACH aL IN aLoc
      AAdd( aOut, { ;
         "uri" => "file://" + hb_PathNormalize( hb_FNameMerge( ;
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
   LOCAL hProj, cTmp, cSrcPath, hAst, hFunc, hItem, hTok
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

   IF ! IsValidIdent( cNew )
      RETURN Refuse( "novo nome '" + cNew + "' não é um identificador válido" )
   ENDIF
   IF IsReserved( cNew )
      RETURN Refuse( "novo nome '" + cNew + "' é palavra reservada" )
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
   IF DefineCollision( hProj, cSrcPath, cNew )
      RETURN Refuse( "novo nome '" + cNew + "' colide com regra de pré-processador (#define/#command/#translate)" )
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

   // o alvo precisa ser LOCAL (ou parâmetro) declarado na função
   FOR EACH hItem IN hFunc[ "declarations" ]
      IF Upper( hItem[ "sym" ] ) == cUpNew
         RETURN Refuse( "novo nome '" + cNew + "' já declarado na função (escopo " + hItem[ "scope" ] + ")" )
      ENDIF
      IF Upper( hItem[ "sym" ] ) == cUpOld .AND. hItem[ "scope" ] == "local"
         hDecl := hItem
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
// de locais fora) com os flags que o hbmk2 resolveu p/ o projeto
STATIC FUNCTION CompileHrbAll( hProj, cTmp, cTag )

   LOCAL cPath, cFlags := "", cTok, cOut, cErr

   FOR EACH cTok IN hProj[ "flags" ]
      cFlags += " " + cTok
   NEXT
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

// função por nome, aceitando Classe:Metodo e nome de método puro quando o
// sufixo <Classe>_<Metodo> é único (convenção do hbclass.ch; morre quando
// os fatos ppApplications da fase B4 existirem)
STATIC FUNCTION PickFunc( hAst, cFunc )

   LOCAL hFunc, hHit := NIL, nHits := 0
   LOCAL cUp := Upper( StrTran( cFunc, ":", "_" ) )

   FOR EACH hFunc IN hAst[ "functions" ]
      IF ! hFunc[ "fileDecl" ] .AND. Upper( hFunc[ "name" ] ) == cUp
         RETURN hFunc
      ENDIF
   NEXT
   FOR EACH hFunc IN hAst[ "functions" ]
      IF ! hFunc[ "fileDecl" ] .AND. ;
         Upper( Right( hFunc[ "name" ], Len( cFunc ) + 1 ) ) == "_" + Upper( cFunc )
         nHits++
         hHit := hFunc
      ENDIF
   NEXT

   RETURN iif( nHits == 1, hHit, NIL )

STATIC FUNCTION ProjectMember( hProj, cFile )

   LOCAL cPath

   FOR EACH cPath IN hProj[ "files" ]
      IF Lower( hb_FNameNameExt( cPath ) ) == Lower( hb_FNameNameExt( cFile ) )
         RETURN cPath
      ENDIF
   NEXT

   RETURN ""

// identificadores e reservadas (UX: recusa antes do rollback pegar)
STATIC FUNCTION IsIdStart( cCh )
   RETURN ( cCh >= "A" .AND. cCh <= "Z" ) .OR. ( cCh >= "a" .AND. cCh <= "z" ) .OR. cCh == "_"

STATIC FUNCTION IsIdChar( cCh )
   RETURN IsIdStart( cCh ) .OR. ( cCh >= "0" .AND. cCh <= "9" )

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

STATIC FUNCTION IsReserved( cName )

   STATIC s_aRes := { "NIL", "IF", "ELSE", "ELSEIF", "ENDIF", "END", "ENDCASE", ;
      "ENDDO", "ENDSWITCH", "FUNCTION", "PROCEDURE", "RETURN", "LOCAL", "STATIC", ;
      "PRIVATE", "PUBLIC", "MEMVAR", "FIELD", "PARAMETERS", "DO", "WHILE", "FOR", ;
      "NEXT", "TO", "STEP", "CASE", "OTHERWISE", "SWITCH", "EXIT", "LOOP", ;
      "BEGIN", "SEQUENCE", "RECOVER", "ALWAYS", "WITH", "SELF", "IIF", "EACH", "IN" }

   RETURN hb_AScan( s_aRes, Upper( cName ),,, .T. ) > 0

// colisão do nome novo com cabeça de regra de pp no fonte e nos #include
// diretos (domínio de diretivas: os fatos ppApplications da B4 assumirão)
STATIC FUNCTION DefineCollision( hProj, cSrcPath, cName )

   LOCAL cText := hb_MemoRead( cSrcPath )
   LOCAL cLine, cInc, cIncPath, cIncText, cUp := Upper( cName )

   IF PpHeadIn( cText, cUp )
      RETURN .T.
   ENDIF
   FOR EACH cLine IN hb_ATokens( StrTran( cText, Chr( 13 ), "" ), Chr( 10 ) )
      cLine := AllTrim( cLine )
      IF Lower( Left( cLine, 8 ) ) == "#include"
         cInc := AllTrim( SubStr( cLine, 9 ) )
         cInc := StrTran( StrTran( StrTran( cInc, '"', "" ), "<", "" ), ">", "" )
         FOR EACH cIncPath IN hProj[ "inc" ]
            cIncText := hb_MemoRead( hb_DirSepAdd( cIncPath ) + cInc )
            IF ! Empty( cIncText ) .AND. PpHeadIn( cIncText, cUp )
               RETURN .T.
            ENDIF
         NEXT
      ENDIF
   NEXT

   RETURN .F.

STATIC FUNCTION PpHeadIn( cText, cUpName )

   LOCAL cLine, aTok

   FOR EACH cLine IN hb_ATokens( StrTran( cText, Chr( 13 ), "" ), Chr( 10 ) )
      cLine := AllTrim( cLine )
      IF Left( cLine, 1 ) == "#"
         aTok := hb_ATokens( cLine )
         IF Len( aTok ) >= 2 .AND. Upper( aTok[ 2 ] ) == cUpName .AND. ;
            hb_AScan( { "#define", "#xtranslate", "#translate", "#command", ;
                        "#xcommand", "#ycommand", "#ytranslate" }, ;
                      Lower( aTok[ 1 ] ),,, .T. ) > 0
            RETURN .T.
         ENDIF
      ENDIF
   NEXT

   RETURN .F.

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
   LOCAL cUpOld, cUpNew

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

   IF ! IsValidIdent( cNew )
      RETURN Refuse( "novo nome '" + cNew + "' não é um identificador válido" )
   ENDIF
   IF IsReserved( cNew )
      RETURN Refuse( "novo nome '" + cNew + "' é palavra reservada" )
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
   IF DefineCollision( hProj, cSrcPath, cNew )
      RETURN Refuse( "novo nome '" + cNew + "' colide com regra de pré-processador" )
   ENDIF

   cTmp := WorkDir()
   IF ! AstDumps( hProj, cTmp )
      RETURN Refuse( "o projeto não compila - corrija os erros de build primeiro" )
   ENDIF
   hAst := ReadAst( cTmp, cSrcPath )
   IF hAst == NIL
      RETURN Refuse( "dump ast-1 ausente/inválido para '" + cSrcPath + "'" )
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

   IF ! IsValidIdent( cNew )
      RETURN Refuse( "novo nome '" + cNew + "' não é um identificador válido" )
   ENDIF
   IF IsReserved( cNew )
      RETURN Refuse( "novo nome '" + cNew + "' é palavra reservada" )
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
         IF hItem[ "type" ] == 41 .AND. hItem[ "line" ] > 0 .AND. ;
            IsValidIdent( hItem[ "text" ] ) .AND. Upper( hItem[ "text" ] ) $ hDefined
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
      hb_MemoWrit( cPath, ApplyRangeEdits( cText, hEdits[ cPath ] ) )
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
// física; o token do nome sabe a sua). Devolve lista de listas de spans
// { {linha, col1based, texto}, ... } por chamada; NIL+cWhy em recusa.
STATIC FUNCTION CallSitesArgs( hAst, hFunc, cUpFunc, cWhy )

   LOCAL aToks := hAst[ "tokens" ], nI, nJ, nDepth, hTok
   LOCAL aAll := {}, aSpans, hT1, hT2, aPrev, nEnd := 0

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
         aSpans := {}
         nDepth := 1
         hT1 := hT2 := NIL
         FOR nJ := nI + 2 TO Len( aToks )
            hTok := aToks[ nJ ]
            DO CASE
            CASE hTok[ "type" ] == 50 .OR. hTok[ "type" ] == 52 .OR. hTok[ "type" ] == 54
               nDepth++
            CASE hTok[ "type" ] == 51 .OR. hTok[ "type" ] == 53 .OR. hTok[ "type" ] == 55
               nDepth--
               IF nDepth == 0
                  IF hT1 != NIL
                     AAdd( aSpans, { hT1[ "line" ], hT1[ "col" ] + 1, ;
                                     CutRange( hAst[ "__src" ], hT1, hT2 ) } )
                  ELSEIF ! Empty( aSpans )
                     cWhy := "argumento vazio/sem posição na chamada da linha " + ;
                             hb_ntos( aToks[ nI ][ "line" ] )
                     RETURN NIL
                  ENDIF
                  AAdd( aAll, aSpans )
                  EXIT
               ENDIF
            CASE hTok[ "type" ] == 29 .AND. nDepth == 1
               IF hT1 == NIL
                  cWhy := "argumento vazio/sem posição na chamada da linha " + ;
                          hb_ntos( aToks[ nI ][ "line" ] )
                  RETURN NIL
               ENDIF
               AAdd( aSpans, { hT1[ "line" ], hT1[ "col" ] + 1, ;
                               CutRange( hAst[ "__src" ], hT1, hT2 ) } )
               hT1 := hT2 := NIL
               LOOP
            ENDCASE
            IF hTok[ "col" ] != NIL .AND. hTok[ "prov" ] == "s" .AND. nDepth >= 1
               IF hT1 == NIL
                  hT1 := hTok
               ENDIF
               hT2 := hTok
            ENDIF
         NEXT
      ENDIF
   NEXT

   RETURN aAll

// recorta do fonte o intervalo do início do 1º token ao fim do último
STATIC FUNCTION CutRange( aSrc, hT1, hT2 )

   LOCAL cOut := "", nL

   IF hT1[ "line" ] == hT2[ "line" ]
      RETURN SubStr( aSrc[ hT1[ "line" ] ], hT1[ "col" ] + 1, ;
                     hT2[ "col" ] + hT2[ "len" ] - hT1[ "col" ] )
   ENDIF
   FOR nL := hT1[ "line" ] TO hT2[ "line" ]
      DO CASE
      CASE nL == hT1[ "line" ]
         cOut += SubStr( aSrc[ nL ], hT1[ "col" ] + 1 )
      CASE nL == hT2[ "line" ]
         cOut += Chr( 10 ) + Left( aSrc[ nL ], hT2[ "col" ] + hT2[ "len" ] )
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
// em ordem descendente de posição
STATIC FUNCTION ApplyRangeEdits( cText, aEdits )

   LOCAL aOffs := { 1 }, nI, nAt

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
         LOOP                                    // deixa a verificação pegar
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
