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
   OutStd( "  hbrefactor usages <projeto> <nome> [--func <função>] [--json <out>]" + hb_eol() )
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
