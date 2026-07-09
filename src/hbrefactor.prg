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
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "resolve-at"
      nExit := ResolveAt( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "dump"
      nExit := DumpOnly( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "projects-of"
      nExit := ProjectsOf( aArgs )
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
   OutStd( "  hbrefactor rename-function <projeto> <velho> <novo> [--file <f.prg>] [--force] [--edit-rules] [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor rename-static <projeto> <arq.prg> <velho> <novo> [--func <função>] [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor reorder-params <projeto> <função> <n1,n2,...> [--file <f.prg>] [--force] [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor extract-function <projeto> <arq.prg> <ini>-<fim> <nome> [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor inline-local <projeto> <arq.prg> <função> <nome> [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor usages <projeto> <nome|Classe:Método|--at arq:linha:col> [--func <função>] [--json <out>] [--show-expansion]" + hb_eol() )
   OutStd( "  hbrefactor resolve-at <projeto> <arq.prg> <linha> <coluna>   (posição -> 'query: <spec>')" + hb_eol() )
   OutStd( "  hbrefactor rename-dsl <projeto> <velha> <nova> [--dry-run]   (cabeça, keyword do match ou palavra de restrição)" + hb_eol() )
   OutStd( "  hbrefactor rename-memvar <projeto> <velho> <novo> [--force] [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor rename-method <projeto> <Classe:Método> <novo> [--force] [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor rename-pp-marker <projeto> <nome> <novo> [--force] [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor unused-locals <projeto>" + hb_eol() )
   OutStd( "  hbrefactor call-graph <projeto> [<função>]" + hb_eol() )
   OutStd( "  hbrefactor find-dynamic-calls <projeto>" + hb_eol() )
   OutStd( "  hbrefactor dump <projeto>          (gera os .ast.json e informa o diretório)" + hb_eol() )
   OutStd( "  hbrefactor projects-of <arq.prg> <projeto1> [<projeto2> ...] [--json <out>]" + hb_eol() )
   OutStd( "                                     (quais destes projetos têm o arquivo como fonte)" + hb_eol() )
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
      // a falha clássica sem HB_BIN é o hbmk2 do PATH (sem -x) reprovando
      // um projeto que compila - nomear a causa provável evita o
      // diagnóstico enganoso "o projeto não compila"
      IF Empty( hb_GetEnv( "HB_BIN" ) )
         OutErr( "hbrefactor: HB_BIN não definido - usei o hbmk2 do PATH, " + ;
                 "que pode não ter o -x do fork; exporte " + ;
                 "HB_BIN=<dir dos binários com -x> (ou configure " + ;
                 "hbrefactor.hbBin na extensão)" + hb_eol() )
      ENDIF
      RETURN .F.
   ENDIF

   RETURN .T.

STATIC FUNCTION ReadAst( cTmp, cModPath )

   LOCAL cPath := hb_DirSepAdd( cTmp ) + hb_FNameName( cModPath ) + ".ast.json"
   LOCAL hAst := hb_jsonDecode( hb_MemoRead( cPath ) )

   // ast-3 = ast-2 + rastro de derivação ("from" nos tokens sintetizados,
   // fase B4d); ast-4 = ast-3 + canal de tipos da linguagem (declarations
   // tipadas parse-time + tabelas DECLARE em "declared", fase B4f);
   // ast-5 = ast-4 + a regra por dentro (match[]/result[] em ppRules,
   // fase B4g); ast-6 = ast-5 + "ret": true no push que carrega o valor
   // de RETURN (fase B7). O leitor usa só seções presentes em todos -
   // comandos que exigem o rastro/o canal/a regra recusam ou degradam com
   // mensagem clara (FromReady/Ast4Ready/RuleToksReady)
   IF ! HB_ISHASH( hAst ) .OR. ;
      hb_AScan( { "ast-2", "ast-3", "ast-4", "ast-5", "ast-6", "ast-7" }, hb_HGetDef( hAst, "schema", "" ) ) == 0
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
   LOCAL nHits := 0, cModFile, aSrc, cUp, aLoc := {}, aDefSeen := {}, aRuleSeen := {}
   LOCAL cClass := "", cMethTok, cUpMeth, nAt, hDecl, hGraph, aVerd, hInter
   LOCAL aSpans, hEnt, aArt, hFn, hDone, cKey, hRule, cVocab, cOwn, cOwnerQ
   LOCAL aDecl, aSite, cCur, nState, hOwnV
   LOCAL cAtSpec := NIL, aAtParts, cAtFile, cAtPath, nAtLine, nAtCol0, hResAt

   IF Len( aArgs ) < 3
      Usage()
      RETURN EXIT_USAGE
   ENDIF
   cSpec := aArgs[ 2 ]
   // `--at arq:linha:col` no lugar do nome (revisão Q5): a consulta vem
   // da POSIÇÃO, resolvida por fato depois que os dumps carregarem -
   // uma única compilação para o consumo da extensão
   IF Lower( aArgs[ 3 ] ) == "--at"
      IF Len( aArgs ) < 4
         Usage()
         RETURN EXIT_USAGE
      ENDIF
      cAtSpec := aArgs[ 4 ]
      nI      := 5
   ELSE
      cName := aArgs[ 3 ]
      nI    := 4
   ENDIF
   FOR nI := nI TO Len( aArgs )
      DO CASE
      CASE Lower( aArgs[ nI ] ) == "--func" .AND. nI < Len( aArgs )
         cFuncFilter := Upper( aArgs[ ++nI ] )
      CASE Lower( aArgs[ nI ] ) == "--json" .AND. nI < Len( aArgs )
         cJsonOut := aArgs[ ++nI ]
      CASE Lower( aArgs[ nI ] ) == "--show-expansion"
         lShowExp := .T.
      ENDCASE
   NEXT
   IF cAtSpec != NIL
      // arquivo pode conter ':' (patológico): linha e coluna são os DOIS
      // últimos segmentos
      aAtParts := hb_ATokens( cAtSpec, ":" )
      IF Len( aAtParts ) < 3
         RETURN Refuse( "forma do --at é arq:linha:col (1-based): '" + cAtSpec + "'" )
      ENDIF
      nAtCol0 := Val( ATail( aAtParts ) ) - 1
      nAtLine := Val( aAtParts[ Len( aAtParts ) - 1 ] )
      cAtFile := aAtParts[ 1 ]
      FOR nI := 2 TO Len( aAtParts ) - 2
         cAtFile += ":" + aAtParts[ nI ]
      NEXT
      IF nAtLine < 1 .OR. nAtCol0 < 0
         RETURN Refuse( "posição inválida no --at: linha e coluna são 1-based" )
      ENDIF
   ENDIF

   hProj := LoadProject( cSpec )
   IF hProj == NIL
      RETURN Refuse( "não consegui resolver o projeto '" + cSpec + "'" )
   ENDIF

   cTmp := WorkDir()
   IF ! AstDumps( hProj, cTmp )
      RETURN Refuse( "o projeto não compila - corrija os erros de build primeiro" )
   ENDIF

   // duas passadas: as tabelas DECLARE do dump são POR MÓDULO e a
   // classificação de receptor precisa do agregado do projeto (B4f)
   FOR EACH cPath IN hProj[ "files" ]
      hAst := ReadAst( cTmp, cPath )
      IF hAst == NIL
         RETURN Refuse( "dump ast-1 ausente/inválido para '" + cPath + ;
                        "' (harbour com -x do branch feature/compiler-ast-dump)" )
      ENDIF
      hAsts[ cPath ] := hAst
   NEXT

   IF cAtSpec != NIL
      cAtPath := ProjectMember( hProj, cAtFile )
      IF cAtPath == ""
         RETURN Refuse( "'" + cAtFile + "' não é fonte do projeto '" + cSpec + "'" )
      ENDIF
      hResAt := ResolveAtQuery( hAsts[ cAtPath ], hAsts, nAtLine, nAtCol0 )
      IF hResAt == NIL
         RETURN Refuse( "nenhum identificador de compilação em " + cAtFile + ":" + ;
                        hb_ntos( nAtLine ) + ":" + hb_ntos( nAtCol0 + 1 ) )
      ENDIF
      OutStd( cAtFile + ":" + hb_ntos( nAtLine ) + ":" + hb_ntos( nAtCol0 + 1 ) + ;
              ": " + hResAt[ "name" ] + " - " + hResAt[ "kind" ] + hb_eol() )
      OutStd( "query: " + hResAt[ "query" ] + hb_eol() )
      cName := hResAt[ "query" ]
   ENDIF
   cUp := Upper( cName )

   // forma Classe:Método (backlog 5): a DEFINIÇÃO filtra pela classe (mesma
   // resolução por rastro do PickFunc); sends continuam por MENSAGEM - o
   // dispatch é dinâmico e o receptor é desconhecido no ast-3
   IF ( nAt := At( ":", cName ) ) > 0
      cClass   := Upper( Left( cName, nAt - 1 ) )
      cMethTok := SubStr( cName, nAt + 1 )
      IF Empty( cClass ) .OR. Empty( cMethTok ) .OR. ":" $ cMethTok
         RETURN Refuse( "forma Classe:Método malformada: '" + cName + "'" )
      ENDIF
   ELSE
      cMethTok := cName
   ENDIF
   cUpMeth := Upper( cMethTok )

   hDecl := DeclTables( hAsts )
   // grafo de classes do projeto (B4f-2): consumido pela resolução de
   // dispatch dos sends; NIL degrada para as camadas B4f
   hGraph := iif( hDecl == NIL, NIL, ClassGraph( hAsts, hDecl ) )
   // contexto interprocedural (B7): índice de funções, vínculos de
   // construção por classe, registro (STRING, @F()) por classe e o teto de
   // runtime pelo oráculo (D3). Só a TIPAGEM do receptor consome (D1:
   // travessia de vínculo escrito vale para tipar, em mundo fechado, com a
   // ressalva no rótulo); as camadas de dispatch da Q4 ficam como estão.
   // NIL degrada para o TypeOf local de sempre
   hInter := iif( hDecl == NIL, NIL, B7Ctx( hAsts, hDecl ) )
   // resolução do dispatch da CLASSE CONSULTADA (B4f-2, sites de
   // declaração): a dona que Classe:Método alcança - decide os sites de
   // declaração/implementação homônimos; NIL = indecidível (classe fora
   // do grafo, pai de fora antes de um hit - fato 9), nunca exclui.
   // Q4 (revisao-generalidade): dono alcançado ATRAVÉS de vínculo escrito
   // não decide - a leitura "identificador na linha da declaração = pai" é
   // por FORMA e uma DSL qualquer põe ali argumento que não é pai (probe
   // da revisão: o forjador viaja na linha por @ref); rebaixa a indecidível
   cOwnerQ := iif( Empty( cClass ) .OR. hGraph == NIL, NIL, ;
                   ResolveDispatch( cClass, cUpMeth, hGraph ) )
   IF DispatchVia( cClass, cOwnerQ )
      cOwnerQ := NIL
   ENDIF
   // vocabulário dos DONOS (revisão Q6): o rótulo de tipo do dono sai na
   // palavra da DSL que o declarou; hbclass segue "class" (a regra CLASS
   // é quem liga o nome ao canal)
   hOwnV := OwnerVocabMap( hAsts )

   FOR EACH cPath IN hProj[ "files" ]
      hAst := hAsts[ cPath ]
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
         ELSEIF FromReady( hAst ) .AND. ;
            ( aLift := PpMarkerLift( hAst, hFunc, cUpMeth ) ) != NIL
            // lifting B4d: o programador escreveu METHOD Paint() CLASS
            // UWMenu (ou HANDLER Click de qualquer DSL); a função gerada é
            // detalhe da expansão - a resposta vem no vocabulário do fonte
            // (a cabeça da regra raiz), com a posição real do nome escrito
            IF Empty( cClass ) .OR. Upper( aLift[ 2 ] ) == cClass
               nHits++
               LocAdd( aLoc, cPath, aLift[ 3 ], { aLift[ 4 ] }, Len( aLift[ 1 ] ) )
               OutStd( cModFile + ":" + hb_ntos( aLift[ 3 ] ) + ": " + aLift[ 5 ] + " definition " + ;
                  aLift[ 1 ] + iif( Empty( aLift[ 2 ] ), "", ;
                     " (" + OwnerWord( hOwnV, aLift[ 2 ] ) + " " + aLift[ 2 ] + ")" ) + ;
                  iif( lShowExp, " -> " + hFunc[ "name" ], "" ) + ;
                  SrcLine( aSrc, aLift[ 3 ] ) + hb_eol() )
            ELSEIF ! Empty( aLift[ 2 ] )
               // homônimo de IMPLEMENTAÇÃO (B4f-2, fatia dos sites de
               // declaração): o site implementa o método de OUTRA dona.
               // Se o dispatch da CONSULTADA resolve NESTA dona (herança,
               // caso 67), o site é o alvo - confirmado; resolução
               // decidível em OUTRA dona provada no grafo (fato 5) ->
               // excluded (no relato, fora das Location[] - política
               // B4f-2); indecidível (fato 9) -> possible honesto
               nHits++
               IF cOwnerQ != NIL .AND. cOwnerQ == Upper( aLift[ 2 ] )
                  LocAdd( aLoc, cPath, aLift[ 3 ], { aLift[ 4 ] }, Len( aLift[ 1 ] ) )
                  OutStd( cModFile + ":" + hb_ntos( aLift[ 3 ] ) + ": " + aLift[ 5 ] + " definition " + ;
                     aLift[ 1 ] + " (" + OwnerWord( hOwnV, aLift[ 2 ] ) + " " + ;
                     aLift[ 2 ] + ", dispatch target of " + ;
                     cClass + ":" + cUpMeth + ")" + iif( lShowExp, " -> " + hFunc[ "name" ], "" ) + ;
                     SrcLine( aSrc, aLift[ 3 ] ) + hb_eol() )
               ELSEIF cOwnerQ != NIL .AND. DeclOwnerProven( hGraph, Upper( aLift[ 2 ] ), cUpMeth )
                  OutStd( cModFile + ":" + hb_ntos( aLift[ 3 ] ) + ": excluded " + aLift[ 5 ] + ;
                     " definition (implements " + Upper( aLift[ 2 ] ) + ":" + cUpMeth + ")" + ;
                     SrcLine( aSrc, aLift[ 3 ] ) + hb_eol() )
               ELSE
                  LocAdd( aLoc, cPath, aLift[ 3 ], { aLift[ 4 ] }, Len( aLift[ 1 ] ) )
                  OutStd( cModFile + ":" + hb_ntos( aLift[ 3 ] ) + ": possible " + aLift[ 5 ] + ;
                     " definition (registered under " + Upper( aLift[ 2 ] ) + ", relation to " + ;
                     cClass + " unknown)" + SrcLine( aSrc, aLift[ 3 ] ) + hb_eol() )
               ENDIF
            ENDIF
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
            // send é despacho dinâmico; a classificação vem SÓ do canal de
            // tipos da linguagem (ast-4): tipo declarado do receptor,
            // propagado pela árvore (TypeOf), e da resolução de dispatch
            // pela regra da linguagem sobre o grafo do projeto (B4f-2).
            // Sem fato, a camada honesta é "possible" - nunca "uso" seco.
            // A ESCRITA `o:x := v` envia a mensagem `_X` (fato 11) - o
            // site escrito é do MESMO nome; casa e resolve pelo par
            IF Upper( hItem[ "sym" ] ) == cUpMeth .OR. ;
               Upper( hItem[ "sym" ] ) == "_" + cUpMeth
               nHits++
               aVerd := SendVerdict( SendReceiverType( hFunc, hItem, hDecl, hInter, hAst ), ;
                                     cClass, cUpMeth, Upper( hItem[ "sym" ] ), ;
                                     hGraph, hItem[ "block" ] )
               // excluded é não-referência PROVADA: fica no relato (com o
               // rótulo) mas fora das Location[] do --json - o editor
               // (find all references via extensão) não deve listá-lo
               IF ! aVerd[ 2 ]
                  LocAdd( aLoc, cPath, hItem[ "line" ], TokenCols( hAst, hItem[ "line" ], cMethTok ), Len( cMethTok ) )
               ENDIF
               OutStd( cModFile + ":" + hb_ntos( hItem[ "line" ] ) + ": " + aVerd[ 1 ] + ;
                  " in " + hFunc[ "name" ] + SrcLine( aSrc, hItem[ "line" ] ) + hb_eol() )
            ENDIF
         NEXT
      NEXT

      // sites de DECLARAÇÃO para a forma Classe:Método (B4f-2 fatia dos
      // homônimos de declaração; generalizada na B4f-3). Duas fontes de
      // FATO, ambas genéricas:
      //   1. canal declared NO STREAM: `_HB_CLASS <nome>` muda a classe
      //      corrente (semântica SEQUENCIAL do compilador - harbour.y,
      //      não convenção) e `_HB_MEMBER <nome>` declara nela; o nome
      //      vem POSICIONADO no site escrito. Cobre hbclass, DSL espelho
      //      e DSL declarativa pura pelo MESMO canal da linguagem.
      //   2. registro por STRING contido (por índice) na função GERADA -
      //      posse por containment (PpMarkerOwners, site a site). Cobre
      //      builds do hbclass sem declarações e DSLs que só registram.
      // Dedup por posição; veredito pela resolução da CONSULTADA
      hDone := { => }
      IF ! Empty( cClass ) .AND. FromReady( hAst )
         aDecl  := {}
         cCur   := NIL
         nState := 0
         FOR EACH hItem IN hAst[ "tokens" ]
            IF nState == 3
               // grupo `{ a, b, ... }` do _HB_MEMBER (a lista de membros
               // do canal - forma do VAR no hbclass): todo identificador
               // posicionado dentro do grupo é nome de membro declarado
               IF hItem[ "type" ] == 55
                  nState := 0
               ELSEIF hItem[ "type" ] == 21 .AND. Upper( hItem[ "text" ] ) == cUpMeth .AND. ;
                  cCur != NIL .AND. hItem[ "line" ] > 0 .AND. hItem[ "col" ] != NIL
                  AAdd( aDecl, { hItem[ "line" ], hItem[ "col" ], cCur } )
               ENDIF
            ELSEIF hItem[ "type" ] == 21
               DO CASE
               CASE Upper( hItem[ "text" ] ) == "_HB_CLASS"
                  nState := 1
               CASE Upper( hItem[ "text" ] ) == "_HB_MEMBER"
                  nState := 2
               CASE nState == 1
                  cCur   := Upper( hItem[ "text" ] )
                  nState := 0
               CASE nState == 2
                  IF Upper( hItem[ "text" ] ) == cUpMeth .AND. cCur != NIL .AND. ;
                     hItem[ "line" ] > 0 .AND. hItem[ "col" ] != NIL
                     AAdd( aDecl, { hItem[ "line" ], hItem[ "col" ], cCur } )
                  ENDIF
                  nState := 0
               ENDCASE
            ELSEIF nState == 2 .AND. hItem[ "type" ] == 54
               nState := 3
            ELSE
               nState := 0
            ENDIF
         NEXT
         aSpans := FuncStmtSpans( hAst )
         hEnt   := PpMarkerSeeds( hAst, cUpMeth )
         FOR EACH aArt IN PpMarkerArtifacts( hAst, hEnt[ "pairs" ], cUpMeth )
            hItem := aArt[ 2 ]
            IF hItem[ "type" ] == 41 .AND. hItem[ "line" ] > 0 .AND. hItem[ "col" ] != NIL .AND. ;
               ( hFn := FuncOfTokIdx( aSpans, aArt[ 1 ] ) ) != NIL .AND. ! hFn[ "fileDecl" ] .AND. ;
               FuncDerived( hAst, hFn ) .AND. MethodImplOf( hAst, hFn, "", cUpMeth ) == NIL
               AAdd( aDecl, { hItem[ "line" ], hItem[ "col" ], Upper( hFn[ "name" ] ) } )
            ENDIF
         NEXT
         FOR EACH aSite IN aDecl
            cKey := hb_ntos( aSite[ 1 ] ) + "|" + hb_ntos( aSite[ 2 ] )
            IF hb_HHasKey( hDone, cKey )
               LOOP
            ENDIF
            hDone[ cKey ] := .T.
            nHits++
            cOwn   := aSite[ 3 ]
            hRule  := SeedRootRule( hAst, aSite[ 1 ], aSite[ 2 ] )
            cVocab := iif( hRule == NIL .OR. hRule[ "head" ] == NIL, "dsl", Lower( hRule[ "head" ] ) )
            IF cOwn == cClass
               LocAdd( aLoc, cPath, aSite[ 1 ], { aSite[ 2 ] + 1 }, Len( cMethTok ) )
               OutStd( cModFile + ":" + hb_ntos( aSite[ 1 ] ) + ": " + cVocab + ;
                  " declaration (" + OwnerWord( hOwnV, cOwn ) + " " + cOwn + ")" + ;
                  SrcLine( aSrc, aSite[ 1 ] ) + hb_eol() )
            ELSEIF cOwnerQ != NIL .AND. cOwnerQ == cOwn
               LocAdd( aLoc, cPath, aSite[ 1 ], { aSite[ 2 ] + 1 }, Len( cMethTok ) )
               OutStd( cModFile + ":" + hb_ntos( aSite[ 1 ] ) + ": " + cVocab + ;
                  " declaration (" + OwnerWord( hOwnV, cOwn ) + " " + cOwn + ;
                  ", dispatch target of " + cClass + ":" + ;
                  cUpMeth + ")" + SrcLine( aSrc, aSite[ 1 ] ) + hb_eol() )
            ELSEIF cOwnerQ != NIL .AND. DeclOwnerProven( hGraph, cOwn, cUpMeth )
               OutStd( cModFile + ":" + hb_ntos( aSite[ 1 ] ) + ": excluded " + cVocab + ;
                  " declaration (declares " + cOwn + ":" + cUpMeth + ")" + ;
                  SrcLine( aSrc, aSite[ 1 ] ) + hb_eol() )
            ELSE
               LocAdd( aLoc, cPath, aSite[ 1 ], { aSite[ 2 ] + 1 }, Len( cMethTok ) )
               OutStd( cModFile + ":" + hb_ntos( aSite[ 1 ] ) + ": possible " + cVocab + ;
                  " declaration (registered under " + cOwn + ", relation to " + cClass + ;
                  " unknown)" + SrcLine( aSrc, aSite[ 1 ] ) + hb_eol() )
            ENDIF
         NEXT
      ENDIF

      // referências possíveis em strings: tokens tipo 41 cujo conteúdo é
      // exatamente o nome (call-by-name) - do próprio stream do compilador.
      // Posições já respondidas pelo passe de declaração acima (a string de
      // registro É o artefato da declaração) não se repetem aqui
      FOR EACH hItem IN hAst[ "tokens" ]
         IF hItem[ "type" ] == 41 .AND. hItem[ "line" ] > 0 .AND. ;
            Upper( hItem[ "text" ] ) == cUpMeth .AND. ;
            ( hItem[ "col" ] == NIL .OR. ;
              ! hb_HHasKey( hDone, hb_ntos( hItem[ "line" ] ) + "|" + hb_ntos( hItem[ "col" ] ) ) )
            nHits++
            LocAdd( aLoc, cPath, hItem[ "line" ], ;
                    iif( hItem[ "col" ] == NIL, {}, { hItem[ "col" ] + 1 } ), Len( cMethTok ) )
            OutStd( cModFile + ":" + hb_ntos( hItem[ "line" ] ) + ;
                    ": possible reference in string" + SrcLine( aSrc, hItem[ "line" ] ) + hb_eol() )
         ENDIF
      NEXT

      // o nome pode ser palavra de DSL de pp (consumida antes do yylex e
      // portanto invisível em tokens[]): diretivas e aplicações (ast-2)
      nHits += DslHits( hAst, cUp, cModFile, aSrc, aDefSeen, aLoc, cPath, Len( cName ) )

      // o nome citado DENTRO do texto das regras (match[]/result[], B4g):
      // keyword de match, identificador em result, palavra de restrição
      nHits += RuleSiteHits( hAst, cUp, aRuleSeen )

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
// projects-of - de quais destes projetos o arquivo é fonte (picker ciente
// do arquivo na extensão): pertencer = o hbmk2 resolve o arquivo como
// fonte na linha de comando do compilador (-traceonly, ~3 ms por
// candidato) - fato do builder oficial, nunca parse de .hbp. Identidade
// por caminho canônico COMPLETO (o ProjectMember do --at compara só
// nome+ext, que entre projetos daria falso positivo com main.prg em
// diretórios distintos). Candidato que o hbmk2 não resolve não pode
// reivindicar o arquivo: sai do páreo com nota no stderr; se NENHUM
// resolver a pergunta não foi respondida (exit != 0) - diferente de
// arquivo órfão, que é resposta válida: lista vazia com exit 0.
// ---------------------------------------------------------------------------

STATIC FUNCTION ProjectsOf( aArgs )

   LOCAL cFile, cAbs, cCwd, cJsonOut := "", aCand := {}, aOwn := {}
   LOCAL cSpec, hProj, cPath, nResolved := 0, nI

   IF Len( aArgs ) < 3
      Usage()
      RETURN EXIT_USAGE
   ENDIF
   cFile := aArgs[ 2 ]
   FOR nI := 3 TO Len( aArgs )
      IF Lower( aArgs[ nI ] ) == "--json" .AND. nI < Len( aArgs )
         cJsonOut := aArgs[ ++nI ]
      ELSE
         AAdd( aCand, aArgs[ nI ] )
      ENDIF
   NEXT
   IF Empty( aCand )
      Usage()
      RETURN EXIT_USAGE
   ENDIF

   cCwd := hb_DirSepAdd( hb_cwd() )
   cAbs := hb_PathNormalize( hb_PathJoin( cCwd, cFile ) )

   FOR EACH cSpec IN aCand
      hProj := LoadProject( cSpec )
      IF hProj == NIL
         OutErr( "hbrefactor: candidato '" + cSpec + ;
                 "' não resolveu no hbmk2 - fora do picker" + hb_eol() )
         LOOP
      ENDIF
      nResolved++
      FOR EACH cPath IN hProj[ "files" ]
         IF hb_PathNormalize( hb_PathJoin( cCwd, cPath ) ) == cAbs
            AAdd( aOwn, cSpec )
            EXIT
         ENDIF
      NEXT
   NEXT

   IF nResolved == 0
      RETURN Refuse( "nenhum candidato resolveu no hbmk2 - a pergunta ficou sem resposta" )
   ENDIF

   FOR EACH cSpec IN aOwn
      OutStd( cSpec + hb_eol() )
   NEXT
   IF ! Empty( cJsonOut )
      hb_MemoWrit( cJsonOut, hb_jsonEncode( aOwn ) )
   ENDIF

   RETURN EXIT_OK

// ---------------------------------------------------------------------------
// resolve-at - "o que está sob o cursor" como pergunta de FATO (revisão
// Q5, mata o methodQuery por regex da extensão): a extensão passa posição
// (linha/coluna 1-based), a resposta sai dos tokens consumidos de
// ppApplications (posicionados byte-exatos) + rastro de derivação. A
// linha final "query: <spec>" é o contrato de consumo (a extensão a
// repassa ao usages). Camadas de fato, da mais específica:
//   1. nome que preenche match marker de regra -> fecho de derivação
//      DESTE site (não do nome no módulo inteiro: homônimo em outra
//      linha não contamina); dona única por co-derivação
//      (PpMarkerOwners sobre os artefatos do site) que nomeia
//      função-de-classe do projeto -> promove a Dona:Nome
//   2. palavra da própria regra (marker 0) -> a palavra (usages de DSL)
//   3. identificador comum do stream -> cru (send/alias só relatados:
//      dispatch é dinâmico, o receptor não é fato do site)
// Dump sem rastro (ast-2) degrada para a consulta crua, sem recusar.
// B4g (match[]/result[]) estende a cobertura a sites DENTRO de diretiva.
// ---------------------------------------------------------------------------

STATIC FUNCTION ResolveAt( aArgs )

   LOCAL cSpec, cFile, nLine, nCol0, hProj, cTmp, cSrcPath, cPath
   LOCAL hAsts := { => }, hRes, aSrc

   IF Len( aArgs ) < 5
      Usage()
      RETURN EXIT_USAGE
   ENDIF
   cSpec := aArgs[ 2 ]
   cFile := aArgs[ 3 ]
   nLine := Val( aArgs[ 4 ] )
   nCol0 := Val( aArgs[ 5 ] ) - 1
   IF nLine < 1 .OR. nCol0 < 0
      RETURN Refuse( "posição inválida: linha e coluna são 1-based" )
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
   IF ! AstDumps( hProj, cTmp )
      RETURN Refuse( "o projeto não compila - corrija os erros de build primeiro" )
   ENDIF
   FOR EACH cPath IN hProj[ "files" ]
      IF ( hAsts[ cPath ] := ReadAst( cTmp, cPath ) ) == NIL
         RETURN Refuse( "dump ast ausente/inválido para '" + cPath + "'" )
      ENDIF
   NEXT

   hRes := ResolveAtQuery( hAsts[ cSrcPath ], hAsts, nLine, nCol0 )
   IF hRes == NIL
      RETURN Refuse( "nenhum identificador de compilação em " + cFile + ":" + ;
                     hb_ntos( nLine ) + ":" + hb_ntos( nCol0 + 1 ) )
   ENDIF
   aSrc := hb_ATokens( StrTran( hb_MemoRead( cSrcPath ), Chr( 13 ) , "" ), Chr( 10 ) )
   OutStd( cFile + ":" + hb_ntos( nLine ) + ":" + hb_ntos( nCol0 + 1 ) + ": " + ;
           hRes[ "name" ] + " - " + hRes[ "kind" ] + ;
           SrcLine( aSrc, nLine ) + hb_eol() )
   OutStd( "query: " + hRes[ "query" ] + hb_eol() )

   RETURN EXIT_OK

// o core do resolve-at, comum ao comando e ao `usages --at` (uma única
// compilação no consumo da extensão). Devolve { "name" (grafia escrita),
// "kind" (o fato), "query" (a consulta p/ usages) } ou NIL (nada na
// posição - quem chama recusa/degrada)
STATIC FUNCTION ResolveAtQuery( hAst, hAsts, nLine, nCol0 )

   LOCAL hClassMap, hRule
   LOCAL hApp, hTok, nApp, hPairs := { => }, cMk := NIL, cWd := NIL
   LOCAL aArts, hOwners, cUpName, cOwn, hCand := { => }, aPrev, cKind, cQuery
   LOCAL aPosApps := {}, hMk, hFunc, aParts, cPart, nCls, cCur, nState, cSide

   // camadas 1/2: o site escrito nas aplicações de pp (a assinatura de um
   // construto gerado só tem posição byte-exata AQUI - tokens[] colapsa)
   FOR EACH hApp IN hAst[ "ppApplications" ]
      nApp := hApp:__enumIndex() - 1
      FOR EACH hTok IN hApp[ "tokens" ]
         IF hTok[ "type" ] == 21 .AND. hTok[ "prov" ] == "s" .AND. ;
            hTok[ "col" ] != NIL .AND. hTok[ "line" ] == nLine .AND. ;
            nCol0 >= hTok[ "col" ] .AND. nCol0 < hTok[ "col" ] + hTok[ "len" ]
            IF hTok[ "marker" ] >= 1
               cMk := hTok[ "text" ]
               hPairs[ PairKey( nApp, hTok[ "marker" ] ) ] := .T.
               AAdd( aPosApps, nApp )
            ELSEIF cWd == NIL
               cWd   := hTok[ "text" ]
               hRule := hAst[ "ppRules" ][ hApp[ "rule" ] + 1 ]
            ENDIF
         ENDIF
      NEXT
   NEXT

   IF cMk != NIL
      cUpName := Upper( cMk )
      // fecho de derivação DESTE site: a mesma varredura de PpMarkerSeeds,
      // semeada só com os pares da posição (from referencia aplicações
      // anteriores - uma passada em ordem fecha o transitivo)
      FOR EACH hApp IN hAst[ "ppApplications" ]
         nApp := hApp:__enumIndex() - 1
         FOR EACH hTok IN hApp[ "tokens" ]
            IF hTok[ "marker" ] >= 1 .AND. hb_HHasKey( hTok, "from" ) .AND. ;
               ! Empty( PpMarkerRanges( hAst, hTok, hPairs, cUpName ) )
               hPairs[ PairKey( nApp, hTok[ "marker" ] ) ] := .T.
            ENDIF
         NEXT
      NEXT
      hClassMap := ClassFuncMap( hAsts )
      // fato 1 da dona: co-derivação a partir DESTE site (PpMarkerOwners
      // sobre os artefatos do fecho) - cobre protótipo/registro (o from
      // liga o site à colagem e ao stringify)
      aArts     := PpMarkerArtifacts( hAst, hPairs, cUpName )
      hOwners   := PpMarkerOwners( hAst, aArts, FuncStmtSpans( hAst ), cUpName )
      FOR EACH cOwn IN hb_HKeys( hOwners )
         IF hb_HHasKey( hClassMap, cOwn )
            hCand[ cOwn ] := hClassMap[ cOwn ][ 3 ][ "name" ]
         ENDIF
      NEXT
      // fato 2 da dona: aplicação-identidade (P1a) - a app da posição
      // carrega TODAS as partes de um composto gerado como markers
      // posicionados (a linha de implementação do hbclass deriva o
      // composto das posições da DECLARAÇÃO - provado no probe da Q5: o
      // from não liga este site; a identidade na MESMA app liga)
      FOR EACH nApp IN aPosApps
         hApp := hAst[ "ppApplications" ][ nApp + 1 ]
         hMk  := { => }
         FOR EACH hTok IN hApp[ "tokens" ]
            IF hTok[ "marker" ] >= 1 .AND. hTok[ "type" ] == 21 .AND. ;
               hTok[ "prov" ] == "s" .AND. hTok[ "col" ] != NIL
               hMk[ Upper( hTok[ "text" ] ) ] := .T.
            ENDIF
         NEXT
         FOR EACH hFunc IN hAst[ "functions" ]
            IF ! hFunc[ "fileDecl" ] .AND. ;
               Len( aParts := GenNameParts( hAst, hFunc ) ) >= 2 .AND. ;
               AScan( aParts, cUpName ) > 0 .AND. IdentSubset( aParts, hMk ) .AND. ;
               GenMsgPart( aParts, hClassMap ) == cUpName
               // a dona é a parte que nomeia função-de-classe; composto
               // com mais de uma parte-classe não decide (fica de fora)
               nCls := 0
               cOwn := ""
               FOR EACH cPart IN aParts
                  IF hb_HHasKey( hClassMap, cPart )
                     nCls++
                     cOwn := cPart
                  ENDIF
               NEXT
               IF nCls == 1
                  hCand[ cOwn ] := hClassMap[ cOwn ][ 3 ][ "name" ]
               ENDIF
            ENDIF
         NEXT
      NEXT
      // fato 3 da dona: canal declared no stream - `_HB_CLASS <dona>` muda
      // a classe corrente e `_HB_MEMBER <nome>` declara nela (semântica
      // SEQUENCIAL do compilador; o nome chega POSICIONADO). Cobre DSL
      // declarativa PURA: dona sem função geradora fica fora do
      // hClassMap e da co-derivação, mas o canal a nomeia
      cCur   := NIL
      nState := 0
      FOR EACH hTok IN hAst[ "tokens" ]
         IF nState == 3
            IF hTok[ "type" ] == 55
               nState := 0
            ELSEIF hTok[ "type" ] == 21 .AND. cCur != NIL .AND. ;
               hTok[ "col" ] != NIL .AND. hTok[ "line" ] == nLine .AND. ;
               nCol0 >= hTok[ "col" ] .AND. nCol0 < hTok[ "col" ] + hTok[ "len" ]
               hCand[ Upper( cCur ) ] := cCur
            ENDIF
         ELSEIF hTok[ "type" ] == 21
            DO CASE
            CASE Upper( hTok[ "text" ] ) == "_HB_CLASS"
               nState := 1
            CASE Upper( hTok[ "text" ] ) == "_HB_MEMBER"
               nState := 2
            CASE nState == 1
               cCur   := hTok[ "text" ]
               nState := 0
            CASE nState == 2
               IF cCur != NIL .AND. hTok[ "col" ] != NIL .AND. ;
                  hTok[ "line" ] == nLine .AND. ;
                  nCol0 >= hTok[ "col" ] .AND. nCol0 < hTok[ "col" ] + hTok[ "len" ]
                  hCand[ Upper( cCur ) ] := cCur
               ENDIF
               nState := 0
            ENDCASE
         ELSEIF nState == 2 .AND. hTok[ "type" ] == 54
            nState := 3
         ELSE
            nState := 0
         ENDIF
      NEXT
      IF hb_HHasKey( hClassMap, cUpName )
         cKind  := "função-de-classe do projeto"
         cQuery := cMk
      ELSEIF Len( hCand ) == 1
         cKind  := "nome de marker, dona única no site (co-derivação/identidade/declared)"
         cQuery := hb_HValueAt( hCand, 1 ) + ":" + cMk
      ELSEIF Len( hCand ) > 1
         // um site com mais de uma dona não decide: consulta crua honesta
         cKind  := "nome de marker com mais de uma dona no site"
         cQuery := cMk
      ELSE
         cKind  := "nome de marker (sem dona identificável)"
         cQuery := cMk
      ENDIF
   ELSEIF cWd != NIL
      cKind  := "palavra de regra de pp (" + RuleTag( hRule ) + ", " + ;
                RuleWhere( hRule ) + ")"
      cQuery := cWd
   ELSE
      // camada 3 (B4g): posição DENTRO do texto de uma diretiva do próprio
      // módulo - vem ANTES do stream: linhas de diretiva não têm tokens
      // próprios (o pp as consome), mas um CLONE de expansão carrega esta
      // mesma posição (fato 13 da spec-b4g) e descreveria o site como
      // identificador comum; o fato do SITE é a palavra da regra.
      // match[]/result[] do ast-5 dão a palavra por posição-fato; consulta
      // crua (o usages responde com os sites, RuleSiteHits inclusos)
      IF RuleToksReady( hAst )
         FOR EACH hRule IN hAst[ "ppRules" ]
            IF hRule[ "file" ] == NIL .OR. ;
               ! Lower( hb_FNameNameExt( hRule[ "file" ] ) ) == ;
                 Lower( hb_FNameNameExt( hAst[ "module" ] ) )
               LOOP
            ENDIF
            FOR EACH cSide IN { "match", "result" }
               FOR EACH hTok IN hRule[ cSide ]
                  IF Len( hb_HGetDef( hTok, "text", "" ) ) > 0 .AND. ;
                     hTok[ "col" ] != NIL .AND. hTok[ "line" ] == nLine .AND. ;
                     nCol0 >= hTok[ "col" ] .AND. nCol0 < hTok[ "col" ] + hTok[ "len" ]
                     cMk    := hTok[ "text" ]
                     cKind  := iif( hTok[ "role" ] == "marker", ;
                                    "nome de marker da regra (local à diretiva; ", ;
                               iif( hTok[ "role" ] == "restrict", ;
                                    "palavra de restrição (", ;
                                    "palavra no " + cSide + " da regra (" ) ) + ;
                               RuleTag( hRule ) + ", " + RuleWhere( hRule ) + ")"
                     cQuery := cMk
                     EXIT
                  ENDIF
               NEXT
               IF cQuery != NIL
                  EXIT
               ENDIF
            NEXT
            IF cQuery != NIL
               EXIT
            ENDIF
         NEXT
      ENDIF
      // camada 4: identificador comum do stream do compilador
      IF cQuery == NIL
         aPrev := NIL
         FOR EACH hTok IN hAst[ "tokens" ]
            IF hTok[ "type" ] == 21 .AND. hTok[ "prov" ] == "s" .AND. ;
               hTok[ "col" ] != NIL .AND. hTok[ "line" ] == nLine .AND. ;
               nCol0 >= hTok[ "col" ] .AND. nCol0 < hTok[ "col" ] + hTok[ "len" ]
               cMk    := hTok[ "text" ]
               cKind  := iif( aPrev != NIL .AND. aPrev[ "type" ] == 58, ;
                              "site de send (mensagem; dispatch dinâmico)", ;
                         iif( aPrev != NIL .AND. aPrev[ "type" ] == 59, ;
                              "campo com alias", "identificador" ) )
               cQuery := cMk
               EXIT
            ENDIF
            aPrev := hTok
         NEXT
      ENDIF
      IF cQuery == NIL
         RETURN NIL
      ENDIF
   ENDIF

   RETURN { "name" => iif( cMk != NIL, cMk, cWd ), "kind" => cKind, ;
            "query" => cQuery }

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
   LOCAL cText, cUpOld, cUpNew, aPrev, cPrevType, nLine, aIdent

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
   // assinatura de método (P1a): o protótipo no CREATE CLASS e a linha
   // METHOD ... CLASS declaram o param FORA do corpo. Em tokens[] a posição da
   // assinatura COLAPSA para a do protótipo (clone multi-passe), então o span
   // da função não a alcança - o hbclass casa protótipo<->implementação pela
   // assinatura INTEIRA (nomes de param inclusos), logo renomear só o corpo
   // deixa a declaração órfã e o build recusa. Colher os sites da assinatura
   // dos markers posicionados de ppApplications, escopados pela IDENTIDADE do
   // nome gerado (classe+método) p/ não pegar param homônimo de outro método.
   // Para LOCAL puro (não param) o nome não aparece na assinatura -> {} de graça
   aIdent := GenNameParts( hAst, hFunc )
   IF ! Empty( aIdent )
      FOR EACH hItem IN SigParamHits( hAst, aIdent, cUpOld )
         AAdd( aEdits, hItem )
      NEXT
   ENDIF
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

// nomes constituintes (UPPER) do nome GERADO de uma função de expansão: as
// faixas de colagem do composto (<Classe>_<Metodo> -> { CLASSE, METODO }).
// {} quando a função não nasceu de expansão. Fato do rastro (B4d): o token do
// nome traz "from" com um item por faixa derivada; o composto decompõe em
// >= 2 partes (o clone do composto inteiro, len == nome, não é constituinte)
STATIC FUNCTION GenNameParts( hAst, hFunc )

   LOCAL cUpName := Upper( hFunc[ "name" ] ), hTok, hFrom, aParts, cPart

   FOR EACH hTok IN hAst[ "tokens" ]
      IF hTok[ "type" ] == 21 .AND. hb_HHasKey( hTok, "from" ) .AND. ;
         Upper( hTok[ "text" ] ) == cUpName
         aParts := {}
         FOR EACH hFrom IN hTok[ "from" ]
            cPart := SubStr( hTok[ "text" ], hFrom[ "at" ] + 1, hFrom[ "len" ] )
            IF Len( cPart ) < Len( hTok[ "text" ] )
               AAdd( aParts, Upper( cPart ) )
            ENDIF
         NEXT
         IF Len( aParts ) >= 2
            RETURN aParts
         ENDIF
      ENDIF
   NEXT

   RETURN {}

// a parte-MENSAGEM de um nome gerado composto: entre as partes
// constituintes (GenNameParts), a mensagem é a ÚNICA que NÃO nomeia
// função-de-classe do projeto - a outra parte é a dona (co-derivação).
// FATO, não posição: o hbclass cola <Classe>_<Metodo>, mas uma DSL
// própria pode colar a mensagem primeiro e a dona por último - eleger a
// última parte (ATail) era leitura por forma e elegia a DONA como
// mensagem (revisão de generalidade Q1/Q3). "" quando o fato não decide
// (nenhuma ou mais de uma candidata) - quem chama recusa/degrada honesto.
STATIC FUNCTION GenMsgPart( aIdentUp, hClassMap )

   LOCAL cPart, cMsg := ""

   FOR EACH cPart IN aIdentUp
      IF ! hb_HHasKey( hClassMap, cPart )
         IF ! Empty( cMsg )
            RETURN ""
         ENDIF
         cMsg := cPart
      ENDIF
   NEXT

   RETURN cMsg

// os nomes de aIdentUp estão TODOS presentes no conjunto hNames (chaves)?
STATIC FUNCTION IdentSubset( aIdentUp, hNames )

   LOCAL cUp

   FOR EACH cUp IN aIdentUp
      IF ! hb_HHasKey( hNames, cUp )
         RETURN .F.
      ENDIF
   NEXT

   RETURN .T.

// sites escritos { linha, col 1-based } do PARÂMETRO na ASSINATURA de um
// construto gerado (o protótipo no CREATE CLASS + a linha METHOD ... CLASS):
// markers posicionados de ppApplications cujo app carrega TODA a identidade
// do nome gerado (classe+método). O corpo do método usa o param normalmente
// em tokens[], mas a ASSINATURA colapsa em tokens[] para a posição do
// protótipo (clone) - só ppApplications a enxerga com posição byte-exata. O
// escopo por identidade evita colher param homônimo de OUTRO método/classe
// (nenhuma aplicação mistura dois métodos - provado no dump). Dedup por
// posição-fonte: a mesma assinatura reaparece em várias aplicações de expansão
STATIC FUNCTION SigParamHits( hAst, aIdentUp, cUpParam )

   LOCAL aHits := {}, hApp, hTok, hNames, aParm, cUp

   FOR EACH hApp IN hAst[ "ppApplications" ]
      hNames := { => }
      aParm  := {}
      FOR EACH hTok IN hApp[ "tokens" ]
         IF hTok[ "type" ] == 21 .AND. hTok[ "prov" ] == "s" .AND. ;
            hTok[ "col" ] != NIL .AND. hTok[ "marker" ] >= 1
            cUp := Upper( hTok[ "text" ] )
            hNames[ cUp ] := .T.
            IF cUp == cUpParam
               AAdd( aParm, hTok )
            ENDIF
         ENDIF
      NEXT
      IF Empty( aParm ) .OR. ! IdentSubset( aIdentUp, hNames )
         LOOP
      ENDIF
      FOR EACH hTok IN aParm
         AddHit( aHits, hTok )
      NEXT
   NEXT

   RETURN aHits

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
   LOCAL lEditRules := .F., aRuleSeen := {}, aRuleSites := {}, aSite
   LOCAL hRule, hTok, cSide, cKey, cChPath, cCwd, cSiteDesc

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
      CASE Lower( aArgs[ nI ] ) == "--edit-rules"
         lEditRules := .T.
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

   // B4g: o nome citado DENTRO de regras de pp (match[]/result[] do ast-5) -
   // depois do rename a regra reescreveria sites para o nome VELHO (órfã;
   // regra nunca aplicada nem dispara o oráculo). Recusa ACIONÁVEL nomeando
   // diretiva+posição (upgrade do caso 74); com --edit-rules a diretiva
   // entra no conjunto de edições e passa pelo MESMO oráculo de sempre
   FOR EACH cPath IN hProj[ "files" ]
      hAst := hAsts[ cPath ]
      IF ! RuleToksReady( hAst )
         LOOP           // dump antigo: sem o fato (o oráculo pega regra aplicada)
      ENDIF
      FOR EACH hRule IN hAst[ "ppRules" ]
         cKey := RuleWhere( hRule ) + "|" + hRule[ "kind" ] + "|" + ;
                 iif( hRule[ "head" ] == NIL, "", hRule[ "head" ] )
         IF hb_AScan( aRuleSeen, cKey,,, .T. ) > 0
            LOOP
         ENDIF
         AAdd( aRuleSeen, cKey )
         FOR EACH cSide IN { "match", "result" }
            FOR EACH hTok IN hRule[ cSide ]
               IF Len( hb_HGetDef( hTok, "text", "" ) ) > 0 .AND. ;
                  Upper( hTok[ "text" ] ) == cUpOld .AND. ;
                  ( ( hTok[ "role" ] == "literal" .AND. hTok[ "type" ] == 21 ) .OR. ;
                    hTok[ "role" ] == "restrict" )
                  AAdd( aRuleSites, { hRule, hTok, cSide } )
               ENDIF
            NEXT
         NEXT
      NEXT
   NEXT
   IF ! Empty( aRuleSites )
      FOR EACH aSite IN aRuleSites
         hRule := aSite[ 1 ]
         hTok  := aSite[ 2 ]
         cSiteDesc := iif( hRule[ "file" ] == NIL, "(builtin)", ;
                           hRule[ "file" ] + ;
                           iif( hTok[ "line" ] == NIL, "", ;
                                ":" + hb_ntos( hTok[ "line" ] ) ) + ;
                           iif( hTok[ "col" ] == NIL, "", ;
                                ":" + hb_ntos( hTok[ "col" ] + 1 ) ) ) + ;
                      ": in rule " + aSite[ 3 ] + " (" + RuleTag( hRule ) + ")"
         OutErr( "rule site: " + cSiteDesc + hb_eol() )
      NEXT
      IF ! lEditRules
         RETURN Refuse( "'" + cOld + "' é citado dentro de regra(s) de pp (sites acima) - " + ;
                        "a regra reescreveria para o nome velho; repita com --edit-rules " + ;
                        "para editar as diretivas junto" )
      ENDIF
      cCwd := hb_PathNormalize( hb_DirSepAdd( hb_cwd() ) )
      FOR EACH aSite IN aRuleSites
         hRule := aSite[ 1 ]
         hTok  := aSite[ 2 ]
         IF hRule[ "file" ] == NIL
            RETURN Refuse( "'" + cOld + "' citado em regra BUILTIN (" + RuleTag( hRule ) + ;
                           ") - não há diretiva a editar" )
         ENDIF
         IF hTok[ "line" ] == NIL .OR. hTok[ "col" ] == NIL
            RETURN Refuse( "site de '" + cOld + "' na regra " + RuleTag( hRule ) + " (" + ;
                           RuleWhere( hRule ) + ") sem posição no fonte (diretiva nascida " + ;
                           "de expansão) - recuso editar" )
         ENDIF
         cChPath := ResolveInclude( hProj, hRule[ "file" ] )
         IF Empty( cChPath )
            RETURN Refuse( "não achei o arquivo da diretiva '" + hRule[ "file" ] + "'" )
         ENDIF
         IF ! Left( hb_PathNormalize( hb_PathJoin( cCwd, cChPath ) ), Len( cCwd ) ) == cCwd
            RETURN Refuse( "diretiva em '" + cChPath + "' fora do diretório do projeto - " + ;
                           "recuso editar include de sistema/compartilhado" )
         ENDIF
         cChPath := hb_PathNormalize( hb_PathJoin( cCwd, cChPath ) )
         // diretiva num fonte do PROJETO (regra no próprio .prg): a chave
         // tem que ser o cPath do projeto - as edições vão na mesma aplicação
         FOR EACH cPath IN hProj[ "files" ]
            IF hb_PathNormalize( hb_PathJoin( cCwd, cPath ) ) == cChPath
               cChPath := cPath
               EXIT
            ENDIF
         NEXT
         IF ! hb_HHasKey( hEdits, cChPath )
            hEdits[ cChPath ] := {}
         ENDIF
         AAdd( hEdits[ cChPath ], { hTok[ "line" ], hTok[ "col" ] + 1 } )
         nTotal++
      NEXT
      FOR EACH cKey IN hb_HKeys( hEdits )
         DedupHits( hEdits[ cKey ] )
      NEXT
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
         IF hb_HHasKey( hEdits, cPath )          // já há edição de diretiva aqui
            FOR EACH aHit IN aE
               AAdd( hEdits[ cPath ], aHit )
            NEXT
            DedupHits( hEdits[ cPath ] )
         ELSE
            hEdits[ cPath ] := aE
         ENDIF
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
   LOCAL lUsesSelf := .F., lMethod, aGenParts, aImplInfo, cClassReal
   LOCAL cMsgPart, aLift, cDslRule := ""
   LOCAL cGenNew := "", cUpGenNew := "", nAnchor := 0, aParentsUnk := {}
   LOCAL hClassMap, aChainQ, hChainSeen, aPP, cUpCur, hMembers, aCF, cPar
   LOCAL hOcc, hFrom, aRangeM, hAst2, hFn2, hIt2, cProtoLine

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

   // P2a: o CONTÊINER é método? Nome composto pelo rastro (dona+mensagem);
   // a MENSAGEM é a parte que não nomeia função-de-classe do projeto e a
   // dona a que nomeia - fato da co-derivação, não posição (Q1/Q3 da
   // revisão; composto de DSL sem classe cai no caminho de função).
   // Contêiner método => o alvo é um novo MÉTODO mesmo com range sem Self
   // (dogfooding do Diego: extrair função de dentro de método surpreende).
   // PORÉM a síntese do alvo (METHOD ... CLASS + protótipo) é a exceção
   // documentada de biblioteca (V4: o pp não roda ao contrário; a forma do
   // hbclass é a ÚNICA que a ferramenta sabe emitir - decisão do Diego,
   // 2026-07-06). O portão é FATO do rastro: o vocábulo da regra raiz que
   // consumiu o nome no site escrito (PpMarkerLift). Contêiner de DSL
   // própria => alvo degrada para FUNÇÃO verificada, com o fato relatado -
   // nunca síntese de hbclass em projeto alheio (Q7).
   aGenParts := GenNameParts( hAst, hTarget )
   hClassMap := ClassFuncMap( hAsts )
   cMsgPart  := GenMsgPart( aGenParts, hClassMap )
   lMethod   := Len( aGenParts ) >= 2 .AND. ! Empty( cMsgPart )
   IF lMethod
      aLift := PpMarkerLift( hAst, hTarget, cMsgPart )
      IF aLift == NIL .OR. !( aLift[ 5 ] == "method" )
         cDslRule := iif( aLift == NIL, "?", aLift[ 5 ] )
         lMethod  := .F.
      ENDIF
   ENDIF
   // occurrences de SELF no range (a atribuição sintética do preâmbulo do
   // hbclass fica na linha do METHOD, fora de qualquer range válido).
   // Reatribuir/referenciar Self extraído mudaria o alvo (o Self do método
   // novo é OUTRA local) - recusa
   FOR EACH hOcc IN hTarget[ "occurrences" ]
      IF hOcc[ "sym" ] == "SELF" .AND. hOcc[ "line" ] >= nFirst .AND. hOcc[ "line" ] <= nLast
         IF hOcc[ "access" ] == "write"
            RETURN Refuse( "a seleção reatribui Self (linha " + hb_ntos( hOcc[ "line" ] ) + ") - recusando" )
         ENDIF
         IF hOcc[ "access" ] == "ref"
            RETURN Refuse( "a seleção passa Self por referência (linha " + hb_ntos( hOcc[ "line" ] ) + ") - recusando" )
         ENDIF
         lUsesSelf := .T.
      ENDIF
   NEXT
   IF lUsesSelf .AND. ! lMethod
      RETURN Refuse( "a seleção usa Self/:: mas " + hTarget[ "name" ] + ;
                     " não é método de classe - extração recusada" )
   ENDIF
   IF lMethod
      // extração PARA MÉTODO da mesma classe: o corpo move verbatim (::/sends
      // continuam válidos; Super preserva o binding - mesma classe).
      aImplInfo := MethodImplOf( hAst, hTarget, "", cMsgPart )
      IF aImplInfo == NIL
         RETURN Refuse( "não consegui decompor o nome gerado de " + hTarget[ "name" ] )
      ENDIF
      cClassReal := aImplInfo[ 1 ]
      // símbolo previsto da função gerada: o composto com a faixa do MÉTODO
      // substituída pelo nome novo (PredictText - sem assumir separador)
      FOR EACH hTok IN hAst[ "tokens" ]
         IF hTok[ "type" ] == 21 .AND. hb_HHasKey( hTok, "from" ) .AND. ;
            Upper( hTok[ "text" ] ) == Upper( hTarget[ "name" ] )
            aRangeM := NIL
            FOR EACH hFrom IN hTok[ "from" ]
               IF Upper( SubStr( hTok[ "text" ], hFrom[ "at" ] + 1, hFrom[ "len" ] ) ) == cMsgPart
                  aRangeM := { hFrom[ "at" ], hFrom[ "len" ] }
               ENDIF
            NEXT
            IF aRangeM != NIL
               cGenNew := PredictText( hTok[ "text" ], { aRangeM }, cNewName )
               EXIT
            ENDIF
         ENDIF
      NEXT
      IF Empty( cGenNew )
         RETURN Refuse( "não consegui prever o símbolo gerado do novo método" )
      ENDIF
      cUpGenNew := Upper( cGenNew )
      // âncora do protótipo: aplicações com a identidade INTEIRA do método
      // (P1a) cujos tokens posicionados ficam ANTES da implementação
      nAnchor := MethodProtoAnchor( hAst, aGenParts, hTarget[ "line" ] )
      IF nAnchor == 0
         RETURN Refuse( "não localizei o protótipo de " + cClassReal + ":" + cMsgPart + ;
                        " no módulo (classe declarada em include?) - recusando" )
      ENDIF
      // colisões nos módulos: símbolo gerado já existente/referenciado e
      // mensagem já ENVIADA (send é despacho dinâmico - o método novo
      // sombrearia o dispatch existente)
      FOR EACH cPath IN hProj[ "files" ]
         hAst2 := hAsts[ cPath ]
         FOR EACH hFn2 IN hAst2[ "functions" ]
            IF ! hFn2[ "fileDecl" ] .AND. Upper( hFn2[ "name" ] ) == cUpGenNew
               RETURN Refuse( "o símbolo gerado " + cGenNew + " já é função em " + hb_FNameNameExt( cPath ) )
            ENDIF
            FOR EACH hIt2 IN hFn2[ "calls" ]
               IF Upper( hIt2[ "sym" ] ) == cUpGenNew
                  RETURN Refuse( "o símbolo gerado " + cGenNew + " já é referenciado em " + hb_FNameNameExt( cPath ) )
               ENDIF
            NEXT
            FOR EACH hIt2 IN hFn2[ "sends" ]
               IF Upper( hIt2[ "sym" ] ) == cUpNew .OR. Upper( hIt2[ "sym" ] ) == "_" + cUpNew
                  RETURN Refuse( "'" + cNewName + "' já é mensagem enviada em " + hb_FNameNameExt( cPath ) + ;
                                 ":" + hb_ntos( hIt2[ "line" ] ) + " - o método novo mudaria o dispatch; recusando" )
               ENDIF
            NEXT
         NEXT
      NEXT
      // membros da classe e dos ancestrais NO projeto (strings de registro
      // por stringify, fato do rastro); ancestral fora do projeto = fato
      // inexistente em compilação -> AVISO honesto, nunca palpite
      aChainQ := { Upper( cClassReal ) }
      hChainSeen := { => }
      DO WHILE ! Empty( aChainQ )
         cUpCur := ATail( aChainQ )
         ASize( aChainQ, Len( aChainQ ) - 1 )
         IF hb_HHasKey( hChainSeen, cUpCur ) .OR. ! hb_HHasKey( hClassMap, cUpCur )
            LOOP
         ENDIF
         hChainSeen[ cUpCur ] := .T.
         aCF := hClassMap[ cUpCur ]
         hMembers := ClassMembersOf( aCF[ 2 ], aCF[ 3 ] )
         IF hb_HHasKey( hMembers, cUpNew )
            RETURN Refuse( "'" + cNewName + "' já é membro (VAR/DATA/METHOD) da classe " + cUpCur )
         ENDIF
         aPP := ClassParentsOf( aCF[ 2 ], cUpCur, aCF[ 3 ], hClassMap )
         FOR EACH cPar IN aPP[ 1 ]
            AAdd( aChainQ, cPar )
         NEXT
         FOR EACH cPar IN aPP[ 2 ]
            IF hb_AScan( aParentsUnk, cPar,,, .T. ) == 0
               AAdd( aParentsUnk, cPar )
            ENDIF
         NEXT
      ENDDO
      // strings soltas que soletram o nome novo: relato (nunca edição)
      FOR EACH hTok IN hAst[ "tokens" ]
         IF hTok[ "type" ] == 41 .AND. hTok[ "line" ] > 0 .AND. Upper( hTok[ "text" ] ) == cUpNew
            OutStd( "warning: string na linha " + hb_ntos( hTok[ "line" ] ) + ;
                    " soletra '" + cNewName + "'" + hb_eol() )
         ENDIF
      NEXT
   ENDIF

   // macro na seleção: semântica movida não-provável (memvar via &) - recusa
   FOR EACH hItem IN hTarget[ "statements" ]
      IF hItem[ "line" ] >= nFirst .AND. hItem[ "line" ] <= nLast .AND. ;
         ExprHasEt( hb_HGetDef( hItem, "expr", NIL ), "MACRO" )
         RETURN Refuse( "a seleção usa macro (&) na linha " + hb_ntos( hItem[ "line" ] ) + " - recusando" )
      ENDIF
   NEXT

   // Self-análogo na seleção com alvo FUNÇÃO: QSelf() vira nó SELF na
   // árvore (fato do dump) e o receptor não viaja numa chamada comum (o
   // vínculo é do dispatch) - extrair mudaria o comportamento EM SILÊNCIO
   // (a verificação de símbolos passa). Em alvo MÉTODO (hbclass) o
   // dispatch continua e o nó move válido; em contêiner de DSL própria a
   // recusa nomeia a exceção de síntese (Q7 da revisão).
   IF ! lMethod
      FOR EACH hItem IN hTarget[ "statements" ]
         IF hItem[ "line" ] >= nFirst .AND. hItem[ "line" ] <= nLast .AND. ;
            ExprHasEt( hb_HGetDef( hItem, "expr", NIL ), "SELF" )
            RETURN Refuse( "a seleção usa QSelf()/Self (linha " + hb_ntos( hItem[ "line" ] ) + ;
                           ") e o alvo é uma FUNÇÃO - o receptor não viajaria" + ;
                           iif( Empty( cDslRule ), "", ": o contêiner nasce de regra de DSL própria ('" + ;
                                cDslRule + "') e a síntese de método é a exceção do hbclass (não sei " + ;
                                "sintetizar o construto desta DSL)" ) + "; recusando" )
         ENDIF
      NEXT
   ENDIF

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
   // for/while inteiro na seleção; BREAK (não-função) precisa de sequence.
   // Só tokens prov 's': linha de token de include é a do ARQUIVO INCLUÍDO
   // e pode colidir com o range por coincidência
   FOR EACH hTok IN hAst[ "tokens" ]
      IF hTok[ "type" ] == 21 .AND. hTok[ "prov" ] == "s" .AND. ;
         hTok[ "line" ] >= nFirst .AND. hTok[ "line" ] <= nLast
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
   // dentro/antes/depois da seleção (linhas físicas do fonte). SELF fica
   // fora: é o RECEPTOR (declarado pela expansão do hbclass e visível nas
   // declarations desde o ast-4), não local de data-flow - o método novo
   // ganha o dele próprio do QSelf(), e range com Self fora de método já
   // tem recusa dedicada
   FOR EACH hItem IN hTarget[ "declarations" ]
      IF !( hItem[ "scope" ] == "local" ) .OR. Upper( hItem[ "sym" ] ) == "SELF"
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
   cCall := cIndent + iif( Empty( cOut ), "", cOut + " := " ) + ;
            iif( lMethod, "::", "" ) + cNewName + ;
            iif( Empty( aParams ), "()", "( " + ArrJoin( aParams, ", " ) + " )" )

   // método: a implementação nova é METHOD ... CLASS (Self implícito de novo,
   // corpo verbatim); função: STATIC como antes. A assinatura do protótipo é
   // idêntica à da implementação (o hbclass casa a assinatura INTEIRA - P1a)
   IF lMethod
      cNewFunc := cEol + "METHOD " + cNewName + ;
                  iif( Empty( aParams ), "()", "( " + ArrJoin( aParams, ", " ) + " )" ) + ;
                  " CLASS " + cClassReal + cEol + cEol
   ELSE
      cNewFunc := cEol + iif( Empty( cOut ), "STATIC PROCEDURE ", "STATIC FUNCTION " ) + ;
                  cNewName + iif( Empty( aParams ), "()", "( " + ArrJoin( aParams, ", " ) + " )" ) + ;
                  cEol + cEol
   ENDIF
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
   // método é função gerada: RETURN sempre com valor (RETURN vazio = W0005)
   IF lMethod
      cNewFunc += cEol + "   RETURN " + iif( Empty( cOut ), "NIL", cOut ) + cEol
   ELSE
      cNewFunc += cEol + "   RETURN" + iif( Empty( cOut ), "", " " + cOut ) + cEol
   ENDIF

   OutStd( "extract-function: linhas " + hb_ntos( nFirst ) + "-" + hb_ntos( nLast ) + ;
           " de " + hTarget[ "name" ] + " -> " + ;
           iif( lMethod, "novo método " + cClassReal + ":" + cNewName, cNewName ) + ;
           "( " + ArrJoin( aParams, ", " ) + " )" + ;
           iif( Empty( cOut ), "", " retornando " + cOut ) + hb_eol() )
   IF ! Empty( cDslRule )
      OutStd( "  contêiner de DSL própria (regra '" + cDslRule + "'): a síntese de método é a " + ;
              "exceção do hbclass - o alvo é FUNÇÃO verificada" + hb_eol() )
   ENDIF
   IF lMethod
      OutStd( "  protótipo METHOD " + cNewName + " inserido após a linha " + hb_ntos( nAnchor ) + ;
              " (junto ao protótipo do método de origem)" + hb_eol() )
      FOR EACH cPar IN aParentsUnk
         OutStd( "  warning: pai " + cPar + " fora do projeto - membros herdados não verificáveis" + hb_eol() )
      NEXT
   ENDIF
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
   IF lMethod
      // protótipo por último: a âncora está acima de todas as outras
      // edições, então inseri-la agora não desloca nenhuma linha editada
      cProtoLine := Space( Len( aSrc[ nAnchor ] ) - Len( LTrim( aSrc[ nAnchor ] ) ) ) + ;
                    "METHOD " + cNewName + ;
                    iif( Empty( aParams ), "()", "( " + ArrJoin( aParams, ", " ) + " )" )
      cTextNew := InsertLineAfter( cTextNew, nAnchor, cProtoLine, cEol )
   ENDIF
   hb_MemoWrit( cSrcPath, cTextNew )

   IF ! CompileHrbAll( hProj, cTmp, "after" )
      hb_MemoWrit( cSrcPath, cText )
      RETURN Refuse( "o projeto parou de compilar após a extração - rollback" )
   ENDIF
   FOR EACH cPath IN hProj[ "files" ]
      cWhy := ""
      IF cPath == cSrcPath
         IF lMethod
            // método: além da função gerada nova, o módulo ganha o símbolo
            // da MENSAGEM (send ::Nome) e a registração da classe embute o
            // nome - verificação por fatos previstos, não byte-idêntica
            IF ! HrbMethodExtractCheck( hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cPath ) + ".before.hrb" ), ;
                                        hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cPath ) + ".after.hrb" ), ;
                                        cUpGenNew, cUpNew, Upper( cClassReal ), cNewName, @cWhy )
               hb_MemoWrit( cSrcPath, cText )
               RETURN Refuse( "verificação FALHOU: " + cWhy + " - rollback" )
            ENDIF
         ELSEIF ! HrbExtractCheck( hb_MemoRead( hb_DirSepAdd( cTmp ) + hb_FNameName( cPath ) + ".before.hrb" ), ;
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

   OutStd( "verified: símbolos preservados (+" + ;
           iif( lMethod, cGenNew + "), mensagem " + cNewName + " registrada", cNewName + ")" ) + ;
           "; rode sua suíte para confirmar comportamento" + hb_eol() )

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

// pós-extração PARA MÉTODO: além da função gerada nova, o módulo ganha o
// símbolo da MENSAGEM (o send ::Nome no método de origem) e a registração da
// classe embute o nome novo (string no pcode da função da classe) - não há
// byte-idêntico; cada fato PREVISTO é conferido (espírito do PredictText)
STATIC FUNCTION HrbMethodExtractCheck( cBefore, cAfter, cUpGen, cUpMsg, cUpClass, cNewSpelled, cWhy )

   LOCAL hB := HrbParse( cBefore ), hA := HrbParse( cAfter )
   LOCAL nI, nJ, lFound, cName

   cWhy := ""
   IF hB == NIL .OR. hA == NIL
      cWhy := "não consegui ler o .hrb"
      RETURN .F.
   ENDIF
   IF Len( hA[ "funcs" ] ) != Len( hB[ "funcs" ] ) + 1
      cWhy := "esperava exatamente uma função nova"
      RETURN .F.
   ENDIF
   FOR nI := 1 TO Len( hB[ "funcs" ] )
      lFound := .F.
      FOR nJ := 1 TO Len( hA[ "funcs" ] )
         IF hA[ "funcs" ][ nJ ][ 1 ] == hB[ "funcs" ][ nI ][ 1 ]
            lFound := .T.
            EXIT
         ENDIF
      NEXT
      IF ! lFound
         cWhy := "função perdida: " + hB[ "funcs" ][ nI ][ 1 ]
         RETURN .F.
      ENDIF
   NEXT
   // todo símbolo anterior sobrevive (nome+escopo); os NOVOS só podem ser o
   // símbolo gerado e o da mensagem
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
   FOR nI := 1 TO Len( hA[ "syms" ] )
      cName := hA[ "syms" ][ nI ][ 1 ]
      lFound := .F.
      FOR nJ := 1 TO Len( hB[ "syms" ] )
         IF hB[ "syms" ][ nJ ][ 1 ] == cName
            lFound := .T.
            EXIT
         ENDIF
      NEXT
      IF ! lFound .AND. !( cName == cUpGen ) .AND. !( cName == cUpMsg )
         cWhy := "símbolo inesperado: " + cName
         RETURN .F.
      ENDIF
   NEXT
   lFound := .F.
   FOR nJ := 1 TO Len( hA[ "syms" ] )
      IF hA[ "syms" ][ nJ ][ 1 ] == cUpGen
         lFound := .T.
         EXIT
      ENDIF
   NEXT
   IF ! lFound
      cWhy := "símbolo novo " + cUpGen + " não encontrado"
      RETURN .F.
   ENDIF
   // fato de registro: o nome novo (grafia escrita) tem que aparecer no
   // pcode da função da CLASSE - sem ele o método não seria registrado e o
   // send ::Nome só falharia em runtime
   lFound := .F.
   FOR nI := 1 TO Len( hA[ "funcs" ] )
      IF hA[ "funcs" ][ nI ][ 1 ] == cUpClass .AND. ;
         hb_BAt( cNewSpelled, hA[ "funcs" ][ nI ][ 2 ] ) > 0
         lFound := .T.
         EXIT
      ENDIF
   NEXT
   IF ! lFound
      cWhy := "registro da mensagem " + cNewSpelled + " não encontrado na classe " + cUpClass
      RETURN .F.
   ENDIF

   RETURN .T.

// insere uma linha nova APÓS a linha nLine (cNew sem EOL)
STATIC FUNCTION InsertLineAfter( cText, nLine, cNew, cEol )

   LOCAL aOffs := LineOffsets( cText )
   LOCAL nAt := iif( nLine + 1 <= Len( aOffs ), aOffs[ nLine + 1 ], hb_BLen( cText ) + 1 )

   RETURN hb_BLeft( cText, nAt - 1 ) + cNew + cEol + hb_BSubStr( cText, nAt )

// última linha física do PROTÓTIPO de um método: aplicações que carregam a
// identidade INTEIRA do nome gerado (classe+método, como em SigParamHits)
// cujos tokens posicionados ficam TODOS antes da linha da implementação.
// 0 = protótipo sem posição no módulo (classe declarada em include)
STATIC FUNCTION MethodProtoAnchor( hAst, aIdentUp, nImplLine )

   LOCAL hApp, hTok, hNames, nMax, nBest := 0

   FOR EACH hApp IN hAst[ "ppApplications" ]
      hNames := { => }
      nMax := 0
      FOR EACH hTok IN hApp[ "tokens" ]
         IF hTok[ "type" ] == 21 .AND. hTok[ "prov" ] == "s" .AND. ;
            hTok[ "col" ] != NIL .AND. hTok[ "marker" ] >= 1
            hNames[ Upper( hTok[ "text" ] ) ] := .T.
            nMax := Max( nMax, hTok[ "line" ] )
         ENDIF
      NEXT
      IF nMax > 0 .AND. nMax < nImplLine .AND. IdentSubset( aIdentUp, hNames )
         nBest := Max( nBest, nMax )
      ENDIF
   NEXT

   RETURN nBest

// funções de CLASSE do projeto: nasceram de expansão (FuncDerived) e o nome
// NÃO é composto (composto = implementação de método). Não há vocabulário de
// família: só rastro. { NOME => { módulo, hAst, hFunc } }
STATIC FUNCTION ClassFuncMap( hAsts )

   LOCAL hMap := { => }, cPath, hAst, hFunc

   FOR EACH cPath IN hb_HKeys( hAsts )
      hAst := hAsts[ cPath ]
      FOR EACH hFunc IN hAst[ "functions" ]
         IF ! hFunc[ "fileDecl" ] .AND. Empty( GenNameParts( hAst, hFunc ) ) .AND. ;
            FuncDerived( hAst, hFunc )
            hMap[ Upper( hFunc[ "name" ] ) ] := { cPath, hAst, hFunc }
         ENDIF
      NEXT
   NEXT

   RETURN hMap

// membros REGISTRADOS de uma classe: as strings de STRINGIFY contidas (por
// índice de token - nascem com line 0) na função da classe. VAR/DATA/METHOD/
// ACCESS viram string de registro na expansão; string escrita pelo usuário
// não tem "from" e fica de fora
STATIC FUNCTION ClassMembersOf( hAst, hClassFunc )

   LOCAL hMembers := { => }, aSpans := FuncStmtSpans( hAst )
   LOCAL hTok, hFrom, hOwn, cUpCF := Upper( hClassFunc[ "name" ] )

   FOR EACH hTok IN hAst[ "tokens" ]
      IF hTok[ "type" ] == 41 .AND. hb_HHasKey( hTok, "from" )
         hOwn := FuncOfTokIdx( aSpans, hTok:__enumIndex() - 1 )
         IF hOwn != NIL .AND. ! hOwn[ "fileDecl" ] .AND. Upper( hOwn[ "name" ] ) == cUpCF
            FOR EACH hFrom IN hTok[ "from" ]
               IF hFrom[ "op" ] == "stringify"
                  hMembers[ Upper( hTok[ "text" ] ) ] := .T.
                  EXIT
               ENDIF
            NEXT
         ENDIF
      ENDIF
   NEXT

   RETURN hMembers

// aplicações que DECLARAM a classe: o fecho de derivação do token que NOMEIA
// a função da classe (na linha dela). Só esse token: o clone do nome usado
// na registração de uma classe FILHA fica na linha do CREATE da filha - de
// fora por construção
STATIC FUNCTION ClassDeclApps( hAst, hClassFunc )

   LOCAL hApps := { => }, hTok
   LOCAL cUp := Upper( hClassFunc[ "name" ] )

   FOR EACH hTok IN hAst[ "tokens" ]
      IF hTok[ "type" ] == 21 .AND. hb_HHasKey( hTok, "from" ) .AND. ;
         Upper( hTok[ "text" ] ) == cUp .AND. hTok[ "line" ] == hClassFunc[ "line" ]
         DeclAppWalk( hAst, hTok, hApps )
      ENDIF
   NEXT

   RETURN hApps

// desce a cadeia de derivação (mesmo padrão de PpMarkerRanges): o from do
// token aponta a aplicação; o token CONSUMIDO correspondente carrega o
// próximo elo (a cópia feita no instante da aplicação, ast-3)
STATIC PROCEDURE DeclAppWalk( hAst, hTok, hApps )

   LOCAL hFrom, hApp, hTA, cPart

   FOR EACH hFrom IN hTok[ "from" ]
      IF hb_HHasKey( hApps, hFrom[ "app" ] )
         LOOP
      ENDIF
      hApps[ hFrom[ "app" ] ] := .T.
      hApp  := hAst[ "ppApplications" ][ hFrom[ "app" ] + 1 ]
      cPart := SubStr( hTok[ "text" ], hFrom[ "at" ] + 1, hFrom[ "len" ] )
      FOR EACH hTA IN hApp[ "tokens" ]
         IF hTA[ "marker" ] == hFrom[ "marker" ] .AND. hTA[ "text" ] == cPart .AND. ;
            hb_HHasKey( hTA, "from" )
            DeclAppWalk( hAst, hTA, hApps )
            EXIT
         ENDIF
      NEXT
   NEXT

   RETURN

// pais da classe NA ORDEM TEXTUAL da cláusula (fatos 8-9 da B4f-2 - a
// resolução de dispatch depende da ordem E do interleaving projeto×fora):
// os OUTROS identificadores POSICIONADOS (escritos pelo usuário:
// FROM <pai>) nas aplicações declarantes, NA LINHA da declaração da classe
// (= linha da função da classe; o fecho de derivação arrasta apps de
// protótipo de método, cujos markers ficam em OUTRAS linhas - o pai de
// verdade está escrito na própria linha do CREATE CLASS). Palavra de regra
// tem marker 0 e token sintetizado não tem posição - ficam de fora.
// Devolve { { PAI, noProjeto? }, ... }; declaração CONTINUADA por ';'
// deixa o pai em outra linha física - fica de fora (não-detecção
// conservadora, nunca palpite)
STATIC FUNCTION ClassParentsSeq( hAst, cUpClass, hClassFunc, hClassMap )

   LOCAL hApps := ClassDeclApps( hAst, hClassFunc )
   LOCAL aSeq := {}, hSeen := { => }
   LOCAL nApp, hApp, hTok, cUp

   FOR EACH nApp IN hb_HKeys( hApps )
      hApp := hAst[ "ppApplications" ][ nApp + 1 ]
      FOR EACH hTok IN hApp[ "tokens" ]
         IF hTok[ "marker" ] >= 1 .AND. hTok[ "type" ] == 21 .AND. ;
            hTok[ "prov" ] == "s" .AND. hTok[ "col" ] != NIL .AND. ;
            hTok[ "line" ] == hClassFunc[ "line" ]
            cUp := Upper( hTok[ "text" ] )
            IF !( cUp == cUpClass ) .AND. ! hb_HHasKey( hSeen, cUp )
               hSeen[ cUp ] := .T.
               // a palavra FROM da cláusula vem sob o MESMO marker do pai;
               // o pai de verdade CHEGA ao parser (a registração o
               // referencia), a palavra da cláusula o pp consome - só é
               // candidato quem existe no stream
               IF hb_HHasKey( hClassMap, cUp )
                  AAdd( aSeq, { cUp, .T. } )
               ELSEIF StreamHasIdent( hAst, cUp )
                  AAdd( aSeq, { cUp, .F. } )
               ENDIF
            ENDIF
         ENDIF
      NEXT
   NEXT

   RETURN aSeq

// visão { noProjeto[], foraDoProjeto[] } da sequência (consumidores que
// não dependem do interleaving - membros herdados do extract-function)
STATIC FUNCTION ClassParentsOf( hAst, cUpClass, hClassFunc, hClassMap )

   LOCAL aIn := {}, aOut := {}, aPar

   FOR EACH aPar IN ClassParentsSeq( hAst, cUpClass, hClassFunc, hClassMap )
      AAdd( iif( aPar[ 2 ], aIn, aOut ), aPar[ 1 ] )
   NEXT

   RETURN { aIn, aOut }

// o identificador aparece no stream que o PARSER consumiu?
STATIC FUNCTION StreamHasIdent( hAst, cUp )

   LOCAL hTok

   FOR EACH hTok IN hAst[ "tokens" ]
      IF hTok[ "type" ] == 21 .AND. Upper( hTok[ "text" ] ) == cUp
         RETURN .T.
      ENDIF
   NEXT

   RETURN .F.

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

   LOCAL hProj, cTmp, cPath, hAst, hFunc, hItem, hAsts := { => }
   LOCAL cFilter := "", hDefined := { => }, hSeen, cKey, cCallee
   LOCAL hMethods := { => }, aParts, cMsg, cUpMsgFilter := "", cUpClassFilter := ""
   LOCAL nAt, aOwn, cGen, hClassMap, cOwn, cPart

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
   // funções definidas + índice de MENSAGENS de construto gerado: o nome
   // composto decompõe pelo rastro (GenNameParts); a MENSAGEM é a parte
   // que NÃO nomeia função-de-classe e a DONA a que nomeia (fato da
   // co-derivação, não posição - Q3 da revisão: eleger a última parte
   // era forma-de-hbclass e elegia a DONA em DSL que cola a mensagem
   // primeiro, respondendo vazio). Composto sem dona identificável
   // (DSL sem classe) fica fora do índice de mensagens - honesto.
   FOR EACH cPath IN hProj[ "files" ]
      hAst := ReadAst( cTmp, cPath )
      IF hAst == NIL
         RETURN Refuse( "dump ausente para '" + cPath + "'" )
      ENDIF
      hAsts[ cPath ] := hAst
      FOR EACH hFunc IN hAst[ "functions" ]
         IF ! hFunc[ "fileDecl" ]
            hDefined[ Upper( hFunc[ "name" ] ) ] := hb_FNameNameExt( cPath )
         ENDIF
      NEXT
   NEXT
   hClassMap := ClassFuncMap( hAsts )
   FOR EACH cPath IN hProj[ "files" ]
      hAst := hAsts[ cPath ]
      FOR EACH hFunc IN hAst[ "functions" ]
         IF hFunc[ "fileDecl" ]
            LOOP
         ENDIF
         aParts := GenNameParts( hAst, hFunc )
         cMsg   := GenMsgPart( aParts, hClassMap )
         IF Len( aParts ) >= 2 .AND. ! Empty( cMsg )
            cOwn := ""
            FOR EACH cPart IN aParts
               IF hb_HHasKey( hClassMap, cPart )
                  cOwn := cPart
                  EXIT
               ENDIF
            NEXT
            IF ! hb_HHasKey( hMethods, cMsg )
               hMethods[ cMsg ] := {}
            ENDIF
            AAdd( hMethods[ cMsg ], { cOwn, hFunc[ "name" ], hb_FNameNameExt( cPath ) } )
         ENDIF
      NEXT
   NEXT
   // o filtro é um MÉTODO? (Classe:Metodo, ou mensagem conhecida crua)
   IF ! Empty( cFilter )
      IF ( nAt := At( ":", cFilter ) ) > 0
         cUpClassFilter := Left( cFilter, nAt - 1 )
         cUpMsgFilter   := SubStr( cFilter, nAt + 1 )
      ELSEIF hb_HHasKey( hMethods, cFilter )
         cUpMsgFilter := cFilter
      ENDIF
   ENDIF
   // definição do(s) método(s) sob o filtro (classe estreita quando dada)
   IF ! Empty( cUpMsgFilter ) .AND. hb_HHasKey( hMethods, cUpMsgFilter )
      FOR EACH aOwn IN hMethods[ cUpMsgFilter ]
         IF Empty( cUpClassFilter ) .OR. aOwn[ 1 ] == cUpClassFilter
            OutStd( aOwn[ 3 ] + ": definition " + aOwn[ 1 ] + ":" + cUpMsgFilter + ;
                    " -> " + aOwn[ 2 ] + hb_eol() )
         ENDIF
      NEXT
   ENDIF
   // arestas ESTÁTICAS (calls)
   FOR EACH cPath IN hProj[ "files" ]
      FOR EACH hFunc IN hAsts[ cPath ][ "functions" ]
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
   // arestas DINÂMICAS: send para MENSAGEM de método do projeto é despacho
   // dinâmico - NUNCA aresta estática. Alvo = nome(s) gerado(s); homônimo em
   // várias classes = alvo ambíguo (todos listados, unicidade visível)
   FOR EACH cPath IN hProj[ "files" ]
      FOR EACH hFunc IN hAsts[ cPath ][ "functions" ]
         IF hFunc[ "fileDecl" ]
            LOOP
         ENDIF
         FOR EACH hItem IN hFunc[ "sends" ]
            cMsg := Upper( hItem[ "sym" ] )
            IF ! hb_HHasKey( hMethods, cMsg )
               LOOP
            ENDIF
            IF ! Empty( cFilter ) .AND. ;
               !( cMsg == cUpMsgFilter .OR. Upper( hFunc[ "name" ] ) == cFilter )
               LOOP
            ENDIF
            cGen := ""
            FOR EACH aOwn IN hMethods[ cMsg ]
               cGen += iif( Empty( cGen ), "", " | " ) + aOwn[ 2 ]
            NEXT
            OutStd( hb_FNameNameExt( cPath ) + ":" + hb_ntos( hItem[ "line" ] ) + ": " + ;
               hFunc[ "name" ] + " ~> " + hItem[ "sym" ] + "  [dynamic: " + cGen + "]" + hb_eol() )
         NEXT
      NEXT
   NEXT

   RETURN EXIT_OK

// a função tem macro '&' ESCRITO PELO USUÁRIO? Um macro real é token type 22
// posicionado (prov 's', ex.: '&cVar.'); o '&' interno da expansão do
// hbclass.ch (usesMacro na função da classe) não gera token posicionado, então
// é falso positivo. Varre o span de linhas da função por um type 22 prov 's'.
STATIC FUNCTION HasUserMacro( hAst, hFunc )

   LOCAL nEnd := 0, hItem, hTok

   FOR EACH hItem IN hAst[ "functions" ]
      IF ! hItem[ "fileDecl" ] .AND. hItem[ "line" ] > hFunc[ "line" ] .AND. ;
         ( nEnd == 0 .OR. hItem[ "line" ] < nEnd )
         nEnd := hItem[ "line" ]
      ENDIF
   NEXT
   FOR EACH hTok IN hAst[ "tokens" ]
      IF hTok[ "type" ] == 22 .AND. hTok[ "prov" ] == "s" .AND. hTok[ "col" ] != NIL .AND. ;
         hTok[ "line" ] >= hFunc[ "line" ] .AND. ( nEnd == 0 .OR. hTok[ "line" ] < nEnd )
         RETURN .T.
      ENDIF
   NEXT

   RETURN .F.

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
         // só macro REAL do usuário: usesMacro provindo da expansão do
         // hbclass.ch (função da classe) não tem '&' posicionado - falso
         // positivo suprimido (P3)
         IF ! hFunc[ "fileDecl" ] .AND. hFunc[ "usesMacro" ] .AND. HasUserMacro( hAst, hFunc )
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
   LOCAL aIdent, lIsMethod, cUpMsg := "", nAt, aOwnerClasses := {}
   LOCAL hOwn, cOwn, aSpell, hF, cCallName

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

   // definição e lista de parâmetros. PickFunc resolve nome puro, Classe:Metodo
   // e nome de método (reuso da P1a); um método tem a assinatura em
   // ppApplications (colapsa em tokens[]) e há SENDS a reordenar
   FOR EACH cPath IN hProj[ "files" ]
      hAst := ReadAst( cTmp, cPath )
      IF hAst == NIL
         RETURN Refuse( "dump ast ausente/inválido para '" + cPath + "'" )
      ENDIF
      hAst[ "__src" ] := hb_ATokens( StrTran( hb_MemoRead( cPath ), Chr( 13 ), "" ), Chr( 10 ) )
      hAsts[ cPath ] := hAst
   NEXT
   FOR EACH cPath IN hProj[ "files" ]
      IF ! Empty( cOnlyFile ) .AND. ;
         ! Lower( hb_FNameNameExt( cPath ) ) == Lower( hb_FNameNameExt( cOnlyFile ) )
         LOOP
      ENDIF
      hFunc := PickFunc( hAsts[ cPath ], cFunc )
      IF hFunc != NIL .AND. ! hFunc[ "fileDecl" ]
         IF hDef != NIL
            RETURN Refuse( "'" + cFunc + "' definida em mais de um módulo - use --file" )
         ENDIF
         hDef := hFunc
         cDefFile := cPath
      ENDIF
   NEXT
   IF hDef == NIL
      RETURN Refuse( "função '" + cFunc + "' não está definida no projeto" )
   ENDIF
   cUpFunc := Upper( hDef[ "name" ] )         // nome REAL (gerado, p/ métodos)
   FOR EACH hItem IN hDef[ "declarations" ]
      IF hItem[ "param" ]
         AAdd( aParams, hItem[ "sym" ] )        // uppercase do dump
      ENDIF
   NEXT
   IF Len( aParams ) < 2
      RETURN Refuse( "'" + cFunc + "' tem menos de 2 parâmetros" )
   ENDIF

   // método? identidade (classe+método) do nome gerado; assinatura e política
   // de send diferem de uma função comum. cUpMsg = a MENSAGEM (nome do método)
   aIdent := GenNameParts( hAsts[ cDefFile ], hDef )
   lIsMethod := Len( aIdent ) >= 2
   IF lIsMethod
      IF ( nAt := At( ":", cFunc ) ) > 0
         cUpMsg := Upper( AllTrim( SubStr( cFunc, nAt + 1 ) ) )
      ELSE
         // a mensagem é a parte que NÃO nomeia função-de-classe (fato da
         // co-derivação) - a posição no composto é forma, não fato (Q1)
         cUpMsg := GenMsgPart( aIdent, ClassFuncMap( hAsts ) )
         IF Empty( cUpMsg )
            RETURN Refuse( "não consegui identificar a mensagem no composto '" + ;
                           hDef[ "name" ] + "' - use a forma Classe:Metodo" )
         ENDIF
      ENDIF
   ENDIF
   cCallName := iif( lIsMethod, cUpMsg, cUpFunc )

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

   // grafia real de cada parâmetro (o dump é uppercase): na assinatura do
   // método os sites vêm de ppApplications (SigParamHits), numa função comum
   // da própria linha (SigSpell)
   aSpell := Array( Len( aParams ) )
   FOR nI := 1 TO Len( aParams )
      IF lIsMethod
         aSigHits := SigParamHits( hAsts[ cDefFile ], aIdent, aParams[ nI ] )
         aSpell[ nI ] := iif( Empty( aSigHits ), aParams[ nI ], ;
                              SpellAt( cDefFile, aSigHits[ 1 ], Len( aParams[ nI ] ) ) )
      ELSE
         aSpell[ nI ] := SigSpell( cDefFile, hAsts[ cDefFile ], hDef, aParams[ nI ] )
      ENDIF
   NEXT

   // política de unicidade da mensagem (mesma do rename-method): sends não
   // carregam classe, então só reordenamos os :Msg( quando o método pertence
   // a UMA classe do projeto - senão o despacho é dinâmico e ambíguo
   IF lIsMethod
      FOR EACH cPath IN hProj[ "files" ]
         hF   := PpMarkerSeeds( hAsts[ cPath ], cUpMsg )
         hOwn := PpMarkerOwners( hAsts[ cPath ], ;
                    PpMarkerArtifacts( hAsts[ cPath ], hF[ "pairs" ], cUpMsg ), ;
                    FuncStmtSpans( hAsts[ cPath ] ), cUpMsg )
         FOR EACH cOwn IN hb_HKeys( hOwn )
            IF hb_AScan( aOwnerClasses, cOwn,,, .T. ) == 0
               AAdd( aOwnerClasses, cOwn )
            ENDIF
         NEXT
      NEXT
      IF Len( aOwnerClasses ) > 1
         RETURN Refuse( "'" + cFunc + "': a mensagem é membro de mais de uma classe (" + ;
                        ArrJoin( aOwnerClasses, ", " ) + ") - send é despacho dinâmico, " + ;
                        "reordenar os argumentos seria ambíguo; recuso" )
      ENDIF
   ENDIF

   // edições por módulo: assinatura (nomes) + call sites (argumentos)
   FOR EACH cPath IN hProj[ "files" ]
      hAst := hAsts[ cPath ]
      aE := {}
      FOR EACH hFunc IN hAst[ "functions" ]
         IF hFunc[ "fileDecl" ]
            LOOP
         ENDIF
         // assinatura: troca os NOMES dos parâmetros pela nova ordem. Método:
         // os sites (protótipo no CREATE CLASS + linha METHOD ... CLASS) vêm
         // de ppApplications, pois colapsam em tokens[] (P1a). Comum: da
         // própria linha da função
         IF cPath == cDefFile .AND. Upper( hFunc[ "name" ] ) == cUpFunc
            FOR nI := 1 TO Len( aParams )
               IF lIsMethod
                  aSigHits := SigParamHits( hAst, aIdent, aParams[ nI ] )
                  IF Empty( aSigHits )
                     RETURN Refuse( "parâmetro '" + aParams[ nI ] + ;
                                    "' não localizado na assinatura do método" )
                  ENDIF
                  FOR EACH hItem IN aSigHits          // hItem = { linha, col1based }
                     AAdd( aE, { hItem[ 1 ], hItem[ 2 ], ;
                                 SpellAt( cPath, hItem, Len( aParams[ nI ] ) ), ;
                                 aSpell[ aPerm[ nI ] ] } )
                  NEXT
               ELSE
                  aSigHits := LineTokens( hAst, hFunc, hFunc[ "line" ], aParams[ nI ] )
                  IF Len( aSigHits ) != 1
                     RETURN Refuse( "parâmetro '" + aParams[ nI ] + "' não localizado com precisão na assinatura" )
                  ENDIF
                  AAdd( aE, { aSigHits[ 1 ][ 1 ], aSigHits[ 1 ][ 2 ], ;
                              SpellAt( cPath, aSigHits[ 1 ], Len( aParams[ nI ] ) ), ;
                              aSpell[ aPerm[ nI ] ] } )
               ENDIF
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
      // método: os SENDS (o:Msg(a,b)) são as arestas dinâmicas - reordena os
      // argumentos como numa chamada. Varredura do módulo inteiro (send em
      // qualquer função); a unicidade da mensagem já foi garantida acima
      IF lIsMethod
         aArgsSpans := SendSitesArgs( hAst, cUpMsg, @cWhy )
         IF aArgsSpans == NIL
            RETURN Refuse( hb_FNameNameExt( cPath ) + ": " + cWhy )
         ENDIF
         FOR EACH hItem IN aArgsSpans          // hItem = spans de UM send
            IF Len( hItem ) < Len( aParams )
               RETURN Refuse( hb_FNameNameExt( cPath ) + ":" + ;
                              hb_ntos( iif( Empty( hItem ), 0, hItem[ 1 ][ 1 ] ) ) + ;
                              ": send com " + hb_ntos( Len( hItem ) ) + " arg(s) < " + ;
                              hb_ntos( Len( aParams ) ) + " parâmetro(s) - implicit NIL would move" )
            ENDIF
            FOR nI := 1 TO Len( aParams )
               AAdd( aE, { hItem[ nI ][ 1 ], hItem[ nI ][ 2 ], ;
                           hItem[ nI ][ 3 ], hItem[ aPerm[ nI ] ][ 3 ] } )
            NEXT
         NEXT
      ENDIF
      // strings citando a função/mensagem (possível acesso por nome:
      // __objSendMsg, &; string DERIVADA por regra tem "from" e não é isso)
      FOR EACH hItem IN hAst[ "tokens" ]
         IF hItem[ "type" ] == 41 .AND. hItem[ "line" ] > 0 .AND. ;
            Upper( hItem[ "text" ] ) == cCallName .AND. ;
            !( lIsMethod .AND. hb_HHasKey( hItem, "from" ) )
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

   LOCAL aToks := hAst[ "tokens" ], nI, hTok
   LOCAL aAll := {}, aSpans, aPrev, nEnd := 0

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
         aSpans := ArgSpansAt( hAst, nI, @cWhy )
         IF aSpans == NIL
            RETURN NIL
         ENDIF
         AAdd( aAll, aSpans )
      ENDIF
   NEXT

   RETURN aAll

// spans dos argumentos de UMA chamada/send cujo token do nome está em
// nNameIdx (o token seguinte é '('): balanceia o STREAM por TIPO (50/52/54
// abrem, 51/53/55 fecham, 29=',' de nível 1 separa) até o ')' casado e
// materializa cada faixa por BuildArgSpan. Reutilizado por CallSitesArgs
// (FUNCALL) e SendSitesArgs (SEND). Devolve { {linha,col1based,texto}, ... }
// ou NIL+cWhy.
STATIC FUNCTION ArgSpansAt( hAst, nNameIdx, cWhy )

   LOCAL aToks := hAst[ "tokens" ], nJ, nDepth := 1, hTok
   LOCAL nArgFrom := nNameIdx + 2, aIdx := {}, aSpans := {}, aR, aSpan
   LOCAL nCallLine := aToks[ nNameIdx ][ "line" ]

   FOR nJ := nNameIdx + 2 TO Len( aToks )
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
               cWhy := "argumento vazio na chamada da linha " + hb_ntos( nCallLine )
               RETURN NIL
            ENDIF
            EXIT
         ENDIF
      CASE hTok[ "type" ] == 29 .AND. nDepth == 1
         IF nJ == nArgFrom
            cWhy := "argumento vazio na chamada da linha " + hb_ntos( nCallLine )
            RETURN NIL
         ENDIF
         AAdd( aIdx, { nArgFrom, nJ - 1 } )
         nArgFrom := nJ + 1
      ENDCASE
   NEXT
   FOR EACH aR IN aIdx
      aSpan := BuildArgSpan( hAst, aR[ 1 ], aR[ 2 ], @cWhy )
      IF aSpan == NIL
         cWhy += " (chamada da linha " + hb_ntos( nCallLine ) + ")"
         RETURN NIL
      ENDIF
      AAdd( aSpans, aSpan )
   NEXT

   RETURN aSpans

// spans dos argumentos de todo SEND da mensagem cUpMsg no módulo: token type
// 21 posicionado cujo ANTERIOR é ':' (type 58) e o SEGUINTE é '(' - o mesmo
// recorte de args de uma chamada (ArgSpansAt). Send sem '(' (acesso a DADO,
// não chamada) é ignorado; a política de unicidade da mensagem já decidiu que
// todos os :Msg( despacham para a mesma classe. NIL+cWhy em recusa.
STATIC FUNCTION SendSitesArgs( hAst, cUpMsg, cWhy )

   LOCAL aToks := hAst[ "tokens" ], nI, hTok, aPrev, aAll := {}, aSpans

   cWhy := ""
   FOR nI := 1 TO Len( aToks )
      hTok  := aToks[ nI ]
      aPrev := iif( nI > 1, aToks[ nI - 1 ], NIL )
      IF hTok[ "type" ] == 21 .AND. hTok[ "prov" ] == "s" .AND. ;
         hTok[ "col" ] != NIL .AND. Upper( hTok[ "text" ] ) == cUpMsg .AND. ;
         aPrev != NIL .AND. aPrev[ "type" ] == 58 .AND. ;
         nI + 1 <= Len( aToks ) .AND. aToks[ nI + 1 ][ "type" ] == 50
         aSpans := ArgSpansAt( hAst, nI, @cWhy )
         IF aSpans == NIL
            RETURN NIL
         ENDIF
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
// B4g - sites DENTRO das regras (match[]/result[] do ast-5): identificador
// ou palavra citado no TEXTO da diretiva - o último esconderijo de um nome.
// Papéis do próprio pp: literal type 21 (keyword/identificador) e
// alternativa de restrição; nome de MARKER fica de fora (é variável local
// da regra, não uso do nome). Dedupe global por regra (o mesmo .ch registra
// a regra em cada módulo que o inclui). Sai pelo canal textual; a posição é
// no ARQUIVO DA REGRA (não no módulo), por isso não entra nas Location[].
// ---------------------------------------------------------------------------

STATIC FUNCTION RuleSiteHits( hAst, cUp, aRuleSeen )

   LOCAL hRule, hTok, cSide, nHits := 0, cKey, cWhat, cWhere

   IF ! RuleToksReady( hAst )
      RETURN 0                  // dump antigo: sem o fato, sem os hits
   ENDIF
   FOR EACH hRule IN hAst[ "ppRules" ]
      cKey := RuleWhere( hRule ) + "|" + hRule[ "kind" ] + "|" + ;
              iif( hRule[ "head" ] == NIL, "", hRule[ "head" ] )
      IF hb_AScan( aRuleSeen, cKey,,, .T. ) > 0
         LOOP
      ENDIF
      AAdd( aRuleSeen, cKey )
      FOR EACH cSide IN { "match", "result" }
         FOR EACH hTok IN hRule[ cSide ]
            IF Len( hb_HGetDef( hTok, "text", "" ) ) == 0 .OR. ;
               ! Upper( hTok[ "text" ] ) == cUp
               LOOP
            ENDIF
            IF hTok[ "role" ] == "restrict"
               cWhat := "in rule restriction (" + RuleTag( hRule ) + ;
                        ", marker " + hb_ntos( hTok[ "marker" ] ) + ")"
            ELSEIF hTok[ "role" ] == "literal" .AND. hTok[ "type" ] == 21
               cWhat := "in rule " + cSide + " (" + RuleTag( hRule ) + ")"
            ELSE
               LOOP
            ENDIF
            nHits++
            cWhere := iif( hRule[ "file" ] == NIL, "(builtin)", ;
                           hRule[ "file" ] + ;
                           iif( hTok[ "line" ] == NIL, "", ;
                                ":" + hb_ntos( hTok[ "line" ] ) ) + ;
                           iif( hTok[ "col" ] == NIL, "", ;
                                ":" + hb_ntos( hTok[ "col" ] + 1 ) ) )
            OutStd( cWhere + ": " + cWhat + hb_eol() )
         NEXT
      NEXT
   NEXT

   RETURN nHits

// ---------------------------------------------------------------------------
// rename-dsl - renomeia uma PALAVRA de regra de pp: a cabeça, a keyword
// secundária do match ou a palavra de RESTRIÇÃO. Edições por posição-fato
// (match[] do ast-5 na diretiva; tokens posicionados de ppApplications nos
// sites de uso - marker 0 para palavra literal, marker N para o recheio da
// restrição). A reancoragem textual da cabeça morreu na B4g (P3: cada token
// da diretiva carrega linha/coluna físicas reais). Verificação padrão-ouro:
// rename consistente produz expansão idêntica -> .ppo e .hrb de TODOS os
// módulos byte-idênticos antes/depois; qualquer diferença = rollback (uma
// restrição cujo valor VAZA para o resultado - stringify do marker - muda a
// expansão e recusa aqui, honesto). O #define constante é o caso degenerado.
// ---------------------------------------------------------------------------

STATIC FUNCTION RenameDsl( aArgs )

   LOCAL cSpec, cOld, cNew, lDryRun := .F., nI
   LOCAL hProj, cTmp, cPath, hAst, hAsts := { => }, hRule, hApp, hTok
   LOCAL cUpOld, cUpNew, aTargets := {}, cKey, aDefSeen := {}
   LOCAL hEdits := { => }, aE, cChPath, cText, hOrig := { => }
   LOCAL nSites := 0, nDirEdits := 0, nLine
   LOCAL hPpoBefore := { => }, cPpo, cCwd
   LOCAL lTarget, hTargetKeys := { => }, aMk

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
      IF ! RuleToksReady( hAst )
         RETURN Refuse( "dump sem match[]/result[] (schema anterior ao ast-5) - " + ;
                        "recompile o harbour do branch feature/compiler-ast-dump" )
      ENDIF
      hAsts[ cPath ] := hAst

      FOR EACH hRule IN hAst[ "ppRules" ]
         // alvo: a palavra vive no MATCH da regra - cabeça (qualquer tipo
         // de token: '@'/'?' são cabeças de pontuação), keyword secundária
         // (literal identificador) ou alternativa de restrição
         lTarget := hRule[ "head" ] != NIL .AND. Upper( hRule[ "head" ] ) == cUpOld
         IF ! lTarget
            FOR EACH hTok IN hRule[ "match" ]
               IF Len( hb_HGetDef( hTok, "text", "" ) ) > 0 .AND. ;
                  Upper( hTok[ "text" ] ) == cUpOld .AND. ;
                  ( ( hTok[ "role" ] == "literal" .AND. hTok[ "type" ] == 21 ) .OR. ;
                    hTok[ "role" ] == "restrict" )
                  lTarget := .T.
                  EXIT
               ENDIF
            NEXT
         ENDIF
         IF lTarget
            IF hRule[ "file" ] == NIL
               RETURN Refuse( "'" + cOld + "' é palavra de regra builtin (std rules/-D, sem " + ;
                              "arquivo de diretiva) - não há diretiva a editar" )
            ENDIF
            cKey := RuleWhere( hRule ) + "|" + hRule[ "kind" ]
            IF hb_AScan( aDefSeen, cKey,,, .T. ) == 0
               AAdd( aDefSeen, cKey )
               AAdd( aTargets, hRule )
               hTargetKeys[ cKey ] := .T.
            ENDIF
         ENDIF
         IF hRule[ "head" ] != NIL .AND. ! Upper( hRule[ "head" ] ) == cUpOld
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
         // o nome novo já é palavra do match de alguma regra: a renomeada o
         // capturaria (ou vice-versa) - visível mesmo em regra nunca
         // aplicada, pelo ast-5
         FOR EACH hTok IN hRule[ "match" ]
            IF Len( hb_HGetDef( hTok, "text", "" ) ) > 0 .AND. ;
               Upper( hTok[ "text" ] ) == cUpNew .AND. ;
               ( ( hTok[ "role" ] == "literal" .AND. hTok[ "type" ] == 21 ) .OR. ;
                 hTok[ "role" ] == "restrict" )
               RETURN Refuse( "'" + cNew + "' já é palavra do match da regra " + ;
                              RuleTag( hRule ) + " (" + RuleWhere( hRule ) + ")" )
            ENDIF
         NEXT
      NEXT
   NEXT
   IF Empty( aTargets )
      RETURN Refuse( "'" + cOld + "' não é palavra de match de regra de pp do projeto " + ;
                     "(cabeça, keyword secundária ou restrição)" )
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

   // sites de aplicação nos módulos: tokens marker 0 (palavra literal da
   // regra - cabeça e secundárias) + recheio de marker de RESTRIÇÃO que
   // carrega a palavra (marker N da regra alvo, texto == velho)
   FOR EACH cPath IN hProj[ "files" ]
      hAst := hAsts[ cPath ]
      aE := {}
      FOR EACH hApp IN hAst[ "ppApplications" ]
         hRule := hAst[ "ppRules" ][ hApp[ "rule" ] + 1 ]
         IF ! hb_HHasKey( hTargetKeys, RuleWhere( hRule ) + "|" + hRule[ "kind" ] )
            LOOP
         ENDIF
         // markers de restrição da regra alvo que carregam a palavra
         aMk := {}
         FOR EACH hTok IN hRule[ "match" ]
            IF hTok[ "role" ] == "restrict" .AND. ;
               Upper( hb_HGetDef( hTok, "text", "" ) ) == cUpOld .AND. ;
               hb_AScan( aMk, hTok[ "marker" ] ) == 0
               AAdd( aMk, hTok[ "marker" ] )
            ENDIF
         NEXT
         FOR EACH hTok IN hApp[ "tokens" ]
            IF ! ( hTok[ "marker" ] == 0 .OR. hb_AScan( aMk, hTok[ "marker" ] ) > 0 )
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
               // uso ABREVIADO da palavra (dBase 4 letras): o texto do site
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

   // a diretiva: as ocorrências da palavra no lado do MATCH, por
   // POSIÇÃO-FATO (match[] do ast-5; cada token com linha/coluna físicas
   // reais - P3). A reancoragem textual da cabeça morreu aqui (B4g). O
   // lado do RESULTADO fica intocado: regra recursiva que emita a própria
   // palavra quebra a expansão e a rede .ppo/.hrb recusa com rollback
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
      FOR EACH hTok IN hRule[ "match" ]
         IF Len( hb_HGetDef( hTok, "text", "" ) ) > 0 .AND. ;
            Upper( hTok[ "text" ] ) == cUpOld .AND. ;
            ( hTok[ "role" ] == "literal" .OR. hTok[ "role" ] == "restrict" )
            IF hTok[ "line" ] == NIL .OR. hTok[ "col" ] == NIL
               RETURN Refuse( "palavra '" + cOld + "' na diretiva " + RuleTag( hRule ) + ;
                              " (" + RuleWhere( hRule ) + ") sem posição no fonte " + ;
                              "(diretiva nascida de expansão) - recuso editar" )
            ENDIF
            AAdd( aE, { hTok[ "line" ], hTok[ "col" ] + 1 } )
         ENDIF
      NEXT
      IF Empty( aE )
         RETURN Refuse( "palavra '" + cOld + "' não encontrada no match da diretiva " + ;
                        RuleTag( hRule ) + " (" + RuleWhere( hRule ) + ")" )
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

// (a reancoragem textual da cabeça - DirectiveHeadEdits/DirectiveStart/
// WordOccs/IsIdByte - morreu na B4g: a diretiva é editada por
// posição-fato, via match[] do ast-5)

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
   RETURN hb_AScan( { "ast-3", "ast-4", "ast-5", "ast-6", "ast-7" }, hb_HGetDef( hAst, "schema", "" ) ) > 0

// ---------------------------------------------------------------------------
// B4f - canal de tipos da linguagem (schema ast-4). O compilador PARSEIA e
// transporta as declarações de tipo da gramática (AS CLASS/AS <tipo> nas
// declarations[], tabelas DECLARE/_HB_CLASS/_HB_MEMBER em "declared") e a
// ferramenta PROPAGA esses tipos declarados sobre a árvore de expressão que
// o dump já carrega (TypeOf) - regra FECHADA, sem ordem, sem caminhos, sem
// fixpoint. O hbclass é apenas o PRIMEIRO CLIENTE do canal: qualquer comando
// de pp que declare pelo canal na expansão é coberto sem mudar nada aqui nem
// no core (contrato de extensão no ast-schema.md). Caveat honesto: tipo
// declarado é promessa do programador, não verificada em runtime.
// ---------------------------------------------------------------------------

STATIC FUNCTION Ast4Ready( hAst )
   RETURN hb_AScan( { "ast-4", "ast-5", "ast-6", "ast-7" }, hb_HGetDef( hAst, "schema", "" ) ) > 0

// ---------------------------------------------------------------------------
// B4g - a regra por dentro (schema ast-5): ppRules[] ganha match[]/result[],
// um item por token do padrão com o PAPEL que o próprio pp atribuiu ao
// parsear a diretiva (literal | marker+mkind | restrict | opt-open/close) e
// posição byte-exata no arquivo da diretiva (col emitida também para .ch
// incluído - diferente de tokens[]). A ordem é a ARMAZENADA pelo pp (grupos
// opcionais consecutivos sem keyword no primeiro são reordenados no
// registro); a ordem do fonte é recuperável pelas posições. Comandos que
// exigem a regra por dentro degradam/recusam com o fato em dump antigo.
// ---------------------------------------------------------------------------

STATIC FUNCTION RuleToksReady( hAst )
   RETURN hb_AScan( { "ast-5", "ast-6", "ast-7" }, hb_HGetDef( hAst, "schema", "" ) ) > 0

// tabelas DECLARE agregadas do PROJETO (as do dump são por módulo):
// { "f" => { FUNÇÃO => item }, "c" => { CLASSE => { MÉTODO => item } } }.
// NIL quando qualquer módulo não é ast-4 - as camadas confirmed/excluded
// degradam para "possible" (fatia 0) em dumps antigos
STATIC FUNCTION DeclTables( hAsts )

   LOCAL hDecl := { "f" => { => }, "c" => { => } }
   LOCAL hAst, hItem, hCls, hMth, cCls

   FOR EACH hAst IN hAsts
      IF ! Ast4Ready( hAst )
         RETURN NIL
      ENDIF
      FOR EACH hItem IN hAst[ "declared" ][ "functions" ]
         hDecl[ "f" ][ Upper( hItem[ "name" ] ) ] := hItem
      NEXT
      FOR EACH hCls IN hAst[ "declared" ][ "classes" ]
         cCls := Upper( hCls[ "name" ] )
         IF ! hb_HHasKey( hDecl[ "c" ], cCls )
            hDecl[ "c" ][ cCls ] := { => }
         ENDIF
         FOR EACH hMth IN hCls[ "methods" ]
            hDecl[ "c" ][ cCls ][ Upper( hMth[ "name" ] ) ] := hMth
         NEXT
      NEXT
   NEXT

   RETURN hDecl

// tipo declarado de um item do canal (declaração de variável, função ou
// método): { "cls" =>, "how" => } instância de classe ('S' exato); tipos
// escalares/array declarados são VALORES (nunca instância - 's' minúsculo
// é ARRAY de classe); 'B' fica fora (codeblock aceita send: :Eval()) e 'O'
// é objeto de classe desconhecida - nem confirma nem exclui
STATIC FUNCTION DeclType( hItem, cHow )

   LOCAL cT

   IF hItem == NIL
      RETURN NIL
   ENDIF
   // B9/ast-7: a forma DIMENSIONADA (LOCAL a[n]) carrega o 'A' interno do
   // compilador, não promessa escrita - reatribuir é legal. Sem o fato
   // "dim" (dumps antigos) esse 'A' era consumido como promessa de array
   // (exposição pré-existente desde a B4f, fechada aqui)
   IF hb_HGetDef( hItem, "dim", .F. )
      RETURN NIL
   ENDIF
   cT := hb_HGetDef( hItem, "type", "" )
   DO CASE
   CASE cT == "S" .AND. hb_HHasKey( hItem, "class" )
      RETURN { "cls" => Upper( hItem[ "class" ] ), "how" => cHow }
   CASE cT == "N"
      RETURN { "val" => "numeric" }
   CASE cT == "C"
      RETURN { "val" => "string" }
   CASE cT == "D"
      RETURN { "val" => "date" }
   CASE cT == "L"
      RETURN { "val" => "logical" }
   CASE cT == "A" .OR. ( ! Empty( cT ) .AND. cT == Lower( cT ) )
      RETURN { "val" => "array" }
   ENDCASE

   RETURN NIL

// TypeOf - propagação bottom-up de tipos DECLARADOS sobre um nó da árvore
// de expressão do dump. Regra local: VARIABLE (declarada, ou binding
// único), FUNCALL (retorno declarado), SEND (retorno declarado do método na
// classe do obj), literais de valor, LIST (valor do último item), SELF.
// B7 (extensão autorizada no portão de 2026-07-08, spec-b7): com hInter,
// FUNCALL sem retorno declarado propaga o retorno ROTULADO (ast-6) da
// função do projeto; SEND cujo método não é declarado na classe resolve
// pela cadeia de construção ESCRITA até o teto de runtime (oráculo D3),
// com QSelf() = identidade do receptor; `::Super:` tipa pela cadeia.
// B7b (portão de 2026-07-08, spec-b7b): método declarado SEM tipo cai
// para a implementação registrada (pushes "ret"); parâmetro de bloco é
// decidido pelo FATO da declaração (param + declLine na linha do bloco) e
// tipado pelo registro inline (1º param = receptor, classes.c:4554) ou
// pela união dos sites de Eval rastreáveis. Travessia de vínculo escrito
// marca "via" (D1: vale em mundo fechado, o rótulo carrega a ressalva).
// Venenos: `Self := x` e `@Self` => NIL. Fora da regra => NIL
// (desconhecido, camada "possible"). hSeen quebra ciclos de binding
// (a := b, b := a). xBlock: .F. fora de bloco, .T. bloco DESCONHECIDO
// (degrada como sempre), ou o próprio nó CODEBLOCK que contém hExpr
STATIC FUNCTION TypeOf( hExpr, hFunc, hDecl, xBlock, hSeen, hInter, hAst )

   LOCAL cEt, cSym, cMsg, hItem, hExprA, hRes, hOcc, hFun, lBlock, hBlk, aBP
   LOCAL nWrites := 0, nRefs := 0, nAssigns := 0, hAssign := NIL, lAsgBlock := .F.

   IF ! HB_ISHASH( hExpr )
      RETURN NIL
   ENDIF
   cEt    := hb_HGetDef( hExpr, "et", "" )
   hBlk   := iif( HB_ISHASH( xBlock ), xBlock, NIL )
   lBlock := iif( HB_ISLOGICAL( xBlock ), xBlock, .T. )

   DO CASE
   CASE cEt == "VARIABLE"
      cSym := Upper( hb_HGetDef( hExpr, "val", "" ) )
      // veneno B7: `Self := x` (ASSIGN real, não o prólogo Self := Self
      // do método) ou `@Self` - a instância deixa de ser a declarada;
      // regra sem ordem => a função inteira degrada (conservador)
      IF cSym == "SELF" .AND. B7SelfPoisoned( hFunc )
         RETURN NIL
      ENDIF
      FOR EACH hOcc IN hFunc[ "occurrences" ]
         IF Upper( hOcc[ "sym" ] ) == cSym
            // memvar/field: escopo dinâmico, fora do canal
            IF hb_AScan( { "memvar", "memvar_implicit", "field" }, hOcc[ "scope" ] ) > 0
               RETURN NIL
            ENDIF
            IF hOcc[ "access" ] == "write"
               nWrites++
            ELSEIF hOcc[ "access" ] == "ref"
               nRefs++
            ENDIF
         ENDIF
      NEXT
      // dentro de codeblock, uso de local EXTERNA resolve como 'detached'
      // (segue o caminho normal); PARÂMETRO de bloco é fato da declaração
      // (param + declLine na linha do bloco - B7b): tipo declarado do
      // próprio param vence; senão o registro inline tipa o 1º param como
      // o RECEPTOR (classes.c:4554) e a união dos sites de Eval cobre o
      // resto; bloco irrastreável/ambíguo degrada (NIL)
      IF lBlock .AND. ( aBP := B7BlockParam( hFunc, hBlk, cSym ) ) != NIL
         IF Len( aBP ) == 0
            RETURN NIL      // param de bloco sem atribuição única de bloco
         ENDIF
         IF ( hRes := DeclType( aBP[ 3 ], "declared" ) ) != NIL
            RETURN B7KtMark( hRes, hAst )   // {|x AS CLASS Foo|...}: canal declarado
         ENDIF
         // veneno: param reescrito/@ref dentro do bloco (regra sem ordem)
         IF nWrites > 0 .OR. nRefs > 0 .OR. hInter == NIL
            RETURN NIL
         ENDIF
         IF hSeen == NIL
            hSeen := { => }
         ENDIF
         IF hb_HHasKey( hSeen, cSym )
            RETURN NIL
         ENDIF
         hSeen[ cSym ] := .T.
         IF ( hRes := B7InlineSelfType( hFunc, hAst, aBP, hInter ) ) != NIL
            RETURN hRes
         ENDIF
         RETURN B7BlockEvalType( hFunc, hAst, aBP, cSym, hDecl, hSeen, hInter )
      ENDIF
      // 1) classe/tipo DECLARADO da própria variável (Self entra por aqui);
      //    em módulo -kt (ast-7) a anotação é INVARIANTE imposta - marca
      //    "kt" para o rótulo guaranteed
      FOR EACH hItem IN hFunc[ "declarations" ]
         IF Upper( hItem[ "sym" ] ) == cSym .AND. ;
            ( hRes := DeclType( hItem, "declared" ) ) != NIL
            RETURN B7KtMark( hRes, hAst )
         ENDIF
      NEXT
      // 2) binding único: exatamente 1 write, 0 refs e UM ASSIGN de topo
      //    para a variável - o tipo é o do RHS. Sem análise de ordem: com
      //    binding único o único valor não-NIL possível é esse (send em
      //    NIL é erro de runtime, nunca dispatch em outra classe); '@'
      //    excluído pelos refs; '&' não alcança LOCAL (fato de linguagem)
      IF hSeen == NIL
         hSeen := { => }
      ENDIF
      IF hb_HHasKey( hSeen, cSym )
         RETURN NIL
      ENDIF
      hSeen[ cSym ] := .T.
      IF nWrites == 1 .AND. nRefs == 0
         FOR EACH hItem IN hFunc[ "statements" ]
            hExprA := hb_HGetDef( hItem, "expr", NIL )
            IF HB_ISHASH( hExprA ) .AND. hb_HGetDef( hExprA, "et", "" ) == "ASSIGN" .AND. ;
               HB_ISHASH( hb_HGetDef( hExprA, "left", NIL ) ) .AND. ;
               hb_HGetDef( hExprA[ "left" ], "et", "" ) == "VARIABLE" .AND. ;
               Upper( hb_HGetDef( hExprA[ "left" ], "val", "" ) ) == cSym
               nAssigns++
               hAssign  := hExprA
               lAsgBlock := hItem[ "block" ]
            ENDIF
         NEXT
         IF nAssigns == 1
            RETURN TypeOf( hb_HGetDef( hAssign, "right", NIL ), hFunc, hDecl, ;
                           lAsgBlock, hSeen, hInter, hAst )
         ENDIF
      ENDIF
      // B7: parâmetro sem escrita nem @ref - o tipo é a UNIÃO dos
      // argumentos de TODOS os call sites do projeto (mundo fechado só
      // com o fechamento auditado: macro no projeto, nome em string ou
      // @F() referenciada => ⊤)
      IF hInter != NIL .AND. nWrites == 0 .AND. nRefs == 0
         FOR EACH hItem IN hFunc[ "declarations" ]
            IF Upper( hItem[ "sym" ] ) == cSym .AND. hb_HGetDef( hItem, "param", .F. )
               RETURN B7ParamType( hFunc, hAst, cSym, hInter )
            ENDIF
         NEXT
      ENDIF

   CASE cEt == "SELF"
      IF B7SelfPoisoned( hFunc )
         RETURN NIL
      ENDIF
      FOR EACH hItem IN hFunc[ "declarations" ]
         IF Upper( hItem[ "sym" ] ) == "SELF" .AND. ;
            ( hRes := DeclType( hItem, "declared" ) ) != NIL
            RETURN B7KtMark( hRes, hAst )
         ENDIF
      NEXT

   CASE cEt == "FUNCALL"
      hFun := hb_HGetDef( hExpr, "fun", NIL )
      IF HB_ISHASH( hFun ) .AND. hb_HGetDef( hFun, "et", "" ) == "FUNNAME"
         // B9/-kt: o compilador embrulha o valor de RETURN declarado em
         // __HB_CHKTYPE( expr, spec, site ) - o helper devolve o 1º
         // argumento (identidade, fato do runtime); o tipo é o do miolo
         IF Upper( hb_HGetDef( hFun, "val", "" ) ) == "__HB_CHKTYPE" .AND. ;
            ! Empty( hb_HGetDef( hb_HGetDef( hExpr, "parms", { => } ), "items", {} ) )
            RETURN TypeOf( hExpr[ "parms" ][ "items" ][ 1 ], hFunc, hDecl, ;
                           xBlock, hSeen, hInter, hAst )
         ENDIF
         hRes := DeclType( hb_HGetDef( hDecl[ "f" ], ;
                           Upper( hb_HGetDef( hFun, "val", "" ) ), NIL ), "chain" )
         // B7: fábrica sem DECLARE - o retorno vem dos pushes ROTULADOS
         // de RETURN (ast-6) da própria função do projeto
         IF hRes == NIL .AND. hInter != NIL
            hRes := B7FunRet( Upper( hb_HGetDef( hFun, "val", "" ) ), hAst, hInter )
         ENDIF
         RETURN hRes
      ENDIF

   CASE cEt == "SEND"
      cMsg := Upper( hb_HGetDef( hExpr, "msg", "" ) )
      IF ! Empty( cMsg )
         // `::Super:Msg()` - obj é SEND SUPER: o MESMO objeto visto pela
         // cadeia escrita do pai (B7/D1; só decide com vínculo ÚNICO)
         IF cMsg == "SUPER"
            RETURN B7SuperType( hExpr, hFunc, hDecl, xBlock, hSeen, hInter, hAst )
         ENDIF
         hRes := TypeOf( hb_HGetDef( hExpr, "obj", NIL ), hFunc, hDecl, xBlock, ;
                         hSeen, hInter, hAst )
         IF hRes != NIL .AND. hb_HHasKey( hRes, "cls" )
            IF hb_HHasKey( hDecl[ "c" ], hRes[ "cls" ] ) .AND. ;
               hb_HHasKey( hDecl[ "c" ][ hRes[ "cls" ] ], cMsg )
               hExprA := B7ViaMark( DeclType( hDecl[ "c" ][ hRes[ "cls" ] ][ cMsg ], "chain" ), ;
                                    hb_HGetDef( hRes, "via", .F. ) )
               // B7b: método DECLARADO mas sem tipo de retorno - o fato
               // vem dos pushes "ret" da implementação registrada (a
               // resolução declared/registro é a mesma do B7MethodRet)
               IF hExprA == NIL .AND. hInter != NIL
                  hExprA := B7SendRet( hRes, cMsg, hInter )
               ENDIF
               RETURN hExprA
            ENDIF
            // B7: método NÃO declarado na classe do receptor - resolve
            // pela cadeia de construção escrita até o teto de runtime
            IF hInter != NIL
               RETURN B7SendRet( hRes, cMsg, hInter )
            ENDIF
         ELSEIF hRes != NIL .AND. hb_HHasKey( hRes, "clsset" ) .AND. hInter != NIL
            // conjunto finito (B7): resolve para CADA candidato; só
            // decide com acordo
            RETURN B7SendRet( hRes, cMsg, hInter )
         ENDIF
      ENDIF

   CASE cEt == "ARRAY"
      RETURN { "val" => "array" }
   CASE cEt == "HASH"
      RETURN { "val" => "hash" }
   CASE cEt == "STRING"
      RETURN { "val" => "string" }
   CASE cEt == "NUMERIC"
      RETURN { "val" => "numeric" }
   CASE cEt == "LOGICAL"
      RETURN { "val" => "logical" }
   CASE cEt == "DATE"
      RETURN { "val" => "date" }
   CASE cEt == "TIMESTAMP"
      RETURN { "val" => "timestamp" }
   CASE cEt == "NIL"
      RETURN { "val" => "nil" }

   CASE cEt == "LIST"
      // expressão parentetizada: o valor é o do ÚLTIMO item
      IF ! Empty( hb_HGetDef( hExpr, "items", {} ) )
         RETURN TypeOf( ATail( hExpr[ "items" ] ), hFunc, hDecl, xBlock, hSeen, ;
                        hInter, hAst )
      ENDIF

   CASE cEt == "IIF"
      // condição LOGICAL constante segue só o ramo tomado (a semântica do
      // HB_EA_REDUCE, que elimina o ramo morto do pcode); condição de
      // runtime (B7): o valor é a UNIÃO dos dois ramos - conjunto finito;
      // ramo sem fato envenena a união (B7Merge => NIL)
      IF Len( hb_HGetDef( hExpr, "items", {} ) ) == 3
         IF HB_ISHASH( hExpr[ "items" ][ 1 ] ) .AND. ;
            hb_HGetDef( hExpr[ "items" ][ 1 ], "et", "" ) == "LOGICAL"
            RETURN TypeOf( hExpr[ "items" ][ ;
                              iif( hb_HGetDef( hExpr[ "items" ][ 1 ], "val", .F. ), 2, 3 ) ], ;
                           hFunc, hDecl, xBlock, hSeen, hInter, hAst )
         ENDIF
         IF hInter != NIL
            RETURN B7Merge( ;
               TypeOf( hExpr[ "items" ][ 2 ], hFunc, hDecl, xBlock, hSeen, hInter, hAst ), ;
               TypeOf( hExpr[ "items" ][ 3 ], hFunc, hDecl, xBlock, hSeen, hInter, hAst ) )
         ENDIF
      ENDIF
   ENDCASE

   RETURN NIL

// classificação do receptor de um send PLANO: localiza o(s) nó(s) SEND da
// mesma mensagem na mesma linha em statements[] e tipa o obj. Vários nós
// candidatos só classificam se concordarem; nó sem obj (WITH OBJECT) ou
// mensagem por macro => desconhecido
STATIC FUNCTION SendReceiverType( hFunc, hSend, hDecl, hInter, hAst )

   LOCAL aNodes := {}, aNode, hStmt, hType := NIL, hOne

   IF hDecl == NIL
      RETURN NIL
   ENDIF
   FOR EACH hStmt IN hFunc[ "statements" ]
      SendNodesWalk( hb_HGetDef( hStmt, "expr", NIL ), Upper( hSend[ "sym" ] ), ;
                     hSend[ "line" ], hStmt[ "block" ], aNodes )
   NEXT
   // a ESCRITA `o:x := v` envia `_X` (fato 11) mas a ÁRVORE guarda o nó
   // como ASSIGN cuja esquerda é SEND do nome BASE - sem nó para `_X`,
   // procurar o nó base na mesma linha
   IF Empty( aNodes ) .AND. hb_LeftEq( hSend[ "sym" ], "_" )
      FOR EACH hStmt IN hFunc[ "statements" ]
         SendNodesWalk( hb_HGetDef( hStmt, "expr", NIL ), SubStr( Upper( hSend[ "sym" ] ), 2 ), ;
                        hSend[ "line" ], hStmt[ "block" ], aNodes )
      NEXT
   ENDIF
   FOR EACH aNode IN aNodes
      hOne := TypeOf( aNode[ 1 ], hFunc, hDecl, aNode[ 2 ], NIL, hInter, hAst )
      IF hOne == NIL
         RETURN NIL
      ENDIF
      IF hType == NIL
         hType := hOne
      ELSEIF !( hb_HGetDef( hType, "cls", "*" ) == hb_HGetDef( hOne, "cls", "*" ) .AND. ;
                hb_HGetDef( hType, "val", "*" ) == hb_HGetDef( hOne, "val", "*" ) )
         RETURN NIL
      ENDIF
   NEXT

   RETURN hType

// coleta recursiva dos nós SEND de uma mensagem numa linha; desce a árvore
// inteira carregando o contexto de codeblock (B7b: o próprio nó CODEBLOCK
// mais interno, para a decisão de parâmetro de bloco por fato)
STATIC PROCEDURE SendNodesWalk( hExpr, cUpMsg, nLine, xBlock, aNodes )

   LOCAL xVal, xChildBlock

   IF ! HB_ISHASH( hExpr )
      RETURN
   ENDIF
   IF hb_HGetDef( hExpr, "et", "" ) == "SEND" .AND. ;
      hb_HGetDef( hExpr, "line", -1 ) == nLine .AND. ;
      Upper( hb_HGetDef( hExpr, "msg", "" ) ) == cUpMsg
      AAdd( aNodes, { hb_HGetDef( hExpr, "obj", NIL ), xBlock } )
   ENDIF
   xChildBlock := iif( hb_HGetDef( hExpr, "et", "" ) == "CODEBLOCK", hExpr, xBlock )
   FOR EACH xVal IN hExpr
      IF HB_ISHASH( xVal )
         SendNodesWalk( xVal, cUpMsg, nLine, xChildBlock, aNodes )
      ELSEIF HB_ISARRAY( xVal )
         AEval( xVal, {| xItem | SendNodesWalk( xItem, cUpMsg, nLine, xChildBlock, aNodes ) } )
      ENDIF
   NEXT

   RETURN

// ---------------------------------------------------------------------------
// B7 - tipos interprocedurais (spec-b7-tipos-interprocedurais.md, portão
// fechado em 2026-07-08). Extensão AUTORIZADA da TypeOf: retorno rotulado
// de RETURN (ast-6) das funções do projeto, cadeia de construção ESCRITA
// (FUNREFs na árvore da função-classe - fato da expansão, com fold de IIF
// de condição constante = a semântica do próprio reduce) e o teto de
// runtime pelo ORÁCULO (D3: src/rtl/tobject.prg compilado com -x, cache).
// QSelf() devolve o receptor por IDENTIDADE (probe executado, registrado
// na spec) - no dump compila para et SELF, então "retorna o receptor" =
// todo push de RETURN da implementação é et SELF. D1: travessia de
// vínculo escrito vale para TIPAR em mundo fechado; toda travessia marca
// "via" e o rótulo do SendVerdict carrega a ressalva ("class graph as
// written"). SÓ a tipagem consome isto - as camadas de dispatch da Q4
// (DispatchVia etc.) ficam intocadas.
// ---------------------------------------------------------------------------

// contexto interprocedural: índices e memos de um run de usages
STATIC FUNCTION B7Ctx( hAsts, hDecl )

   LOCAL hInter := { "decl" => hDecl, "clsmap" => ClassFuncMap( hAsts ), ;
                     "orc" => OracleLoad(), "funcs" => { => }, ;
                     "links" => { => }, "regs" => { => }, "rets" => { => }, ;
                     "params" => { => }, "asts" => hAsts, "dyn" => NIL, ;
                     "strs" => NIL, "active" => { => }, ;
                     "clsfn" => { => }, "inlblk" => { => } }
   LOCAL cPath, hAst, hFunc, hMod, cUpF, aCF

   FOR EACH cPath IN hb_HKeys( hAsts )
      hAst := hAsts[ cPath ]
      hMod := { => }
      FOR EACH hFunc IN hAst[ "functions" ]
         IF hFunc[ "fileDecl" ]
            LOOP
         ENDIF
         cUpF := Upper( hFunc[ "name" ] )
         hMod[ cUpF ] := { hAst, hFunc }
         // índice global só de PÚBLICAS; colisão de nome => NIL (⊤ -
         // vínculo inválido de qualquer forma, nunca palpite)
         IF ! hFunc[ "static" ]
            hInter[ "funcs" ][ cUpF ] := ;
               iif( hb_HHasKey( hInter[ "funcs" ], cUpF ), NIL, { hAst, hFunc } )
         ENDIF
      NEXT
      // resolução LOCAL-primeiro (STATIC homônima entre módulos)
      hAst[ "_b7funcs" ] := hMod
   NEXT
   IF hInter[ "orc" ] != NIL
      // as impls do oráculo resolvem no módulo do próprio oráculo
      hMod := { => }
      FOR EACH hFunc IN hInter[ "orc" ][ "ast" ][ "functions" ]
         IF ! hFunc[ "fileDecl" ]
            hMod[ Upper( hFunc[ "name" ] ) ] := { hInter[ "orc" ][ "ast" ], hFunc }
         ENDIF
      NEXT
      hInter[ "orc" ][ "ast" ][ "_b7funcs" ] := hMod
   ENDIF
   // B7b: mapa reverso função-classe -> classe (módulo!função), para o
   // tipo do 1º parâmetro de bloco inline registrado (co-derivação: a
   // função-classe já vem ligada à classe pelo rastro - ClassFuncMap)
   FOR EACH cUpF IN hb_HKeys( hInter[ "clsmap" ] )
      aCF := hInter[ "clsmap" ][ cUpF ]
      hInter[ "clsfn" ][ hb_HGetDef( aCF[ 2 ], "module", "" ) + "!" + ;
                         Upper( aCF[ 3 ][ "name" ] ) ] := cUpF
   NEXT
   IF hInter[ "orc" ] != NIL
      hInter[ "clsfn" ][ hb_HGetDef( hInter[ "orc" ][ "ast" ], "module", "" ) + "!" + ;
                         Upper( hInter[ "orc" ][ "fun" ][ "name" ] ) ] := hInter[ "orc" ][ "cls" ]
   ENDIF

   RETURN hInter

// o dump carrega o rótulo de RETURN? (ast-6+)
STATIC FUNCTION B7Ret6( hAst )
   RETURN hb_AScan( { "ast-6", "ast-7" }, hb_HGetDef( hAst, "schema", "" ) ) > 0

// função por nome: STATIC/pública do MÓDULO primeiro, depois pública do
// projeto (colisão de públicas = NIL). Fora do projeto => NIL
STATIC FUNCTION B7FunOf( cUpFun, hAst, hInter )

   IF hAst != NIL .AND. hb_HHasKey( hAst, "_b7funcs" ) .AND. ;
      hb_HHasKey( hAst[ "_b7funcs" ], cUpFun )
      RETURN hAst[ "_b7funcs" ][ cUpFun ]
   ENDIF

   RETURN hb_HGetDef( hInter[ "funcs" ], cUpFun, NIL )

// `Self := x` real (right não é o prólogo Self := Self) ou `@Self` na
// função? Memoizado no próprio hFunc
STATIC FUNCTION B7SelfPoisoned( hFunc )

   LOCAL hStmt, hOcc, lPoison

   IF hb_HHasKey( hFunc, "_b7selfp" )
      RETURN hFunc[ "_b7selfp" ]
   ENDIF
   lPoison := .F.
   FOR EACH hOcc IN hFunc[ "occurrences" ]
      IF Upper( hOcc[ "sym" ] ) == "SELF" .AND. hOcc[ "access" ] == "ref"
         lPoison := .T.
         EXIT
      ENDIF
   NEXT
   IF ! lPoison
      FOR EACH hStmt IN hFunc[ "statements" ]
         IF B7SelfWriteWalk( hb_HGetDef( hStmt, "expr", NIL ) )
            lPoison := .T.
            EXIT
         ENDIF
      NEXT
   ENDIF
   hFunc[ "_b7selfp" ] := lPoison

   RETURN lPoison

STATIC FUNCTION B7SelfWriteWalk( hExpr )

   LOCAL xVal, hItem

   IF ! HB_ISHASH( hExpr )
      RETURN .F.
   ENDIF
   IF hb_HGetDef( hExpr, "et", "" ) == "ASSIGN" .AND. ;
      HB_ISHASH( hb_HGetDef( hExpr, "left", NIL ) ) .AND. ;
      hb_HGetDef( hExpr[ "left" ], "et", "" ) == "VARIABLE" .AND. ;
      Upper( hb_HGetDef( hExpr[ "left" ], "val", "" ) ) == "SELF" .AND. ;
      !( hb_HGetDef( hb_HGetDef( hExpr, "right", { => } ), "et", "" ) == "SELF" )
      RETURN .T.
   ENDIF
   FOR EACH xVal IN hExpr
      IF HB_ISHASH( xVal ) .AND. hb_HHasKey( xVal, "et" )
         IF B7SelfWriteWalk( xVal )
            RETURN .T.
         ENDIF
      ELSEIF HB_ISARRAY( xVal )
         FOR EACH hItem IN xVal
            IF B7SelfWriteWalk( hItem )
               RETURN .T.
            ENDIF
         NEXT
      ENDIF
   NEXT

   RETURN .F.

// B9: em módulo compilado com -kt (ast-7), a anotação declarada é
// INVARIANTE imposta em runtime (fail-fast) - o tipo carrega "kt" e o
// veredito sai na camada guaranteed, distinta da promessa declarada
STATIC FUNCTION B7KtMark( hType, hAst )

   IF hType != NIL .AND. hAst != NIL .AND. hb_HGetDef( hAst, "kt", .F. )
      hType[ "kt" ] := .T.
   ENDIF

   RETURN hType

// marca a travessia de vínculo escrito no tipo (D1)
STATIC FUNCTION B7ViaMark( hType, lVia )

   IF hType != NIL .AND. lVia
      hType := hb_HClone( hType )
      hType[ "via" ] := .T.
   ENDIF

   RETURN hType

// pushes ROTULADOS de RETURN da função (ast-6), fora de codeblock (RETURN
// de bloco estendido devolve do BLOCO, não da função)
STATIC FUNCTION B7RetPushes( hFunc )

   LOCAL aOut := {}, hStmt

   FOR EACH hStmt IN hFunc[ "statements" ]
      IF hStmt[ "kind" ] == "push" .AND. ! hStmt[ "block" ] .AND. ;
         hb_HGetDef( hStmt, "ret", .F. )
         AAdd( aOut, hb_HGetDef( hStmt, "expr", NIL ) )
      ENDIF
   NEXT

   RETURN aOut

// todo RETURN da implementação devolve QSelf()? (o compilador traduz
// QSelf() para o nó SELF - fato do dump, probe qself.prg na spec).
// B7b: corpo com Self envenenado (`Self := x`/`@Self`) NÃO é identidade -
// o Self devolvido pode ser outra instância (regra sem ordem, conservador)
STATIC FUNCTION B7AllRetsSelf( hFunc )

   LOCAL aPushes := B7RetPushes( hFunc ), hExpr

   IF Empty( aPushes ) .OR. B7SelfPoisoned( hFunc )
      RETURN .F.
   ENDIF
   FOR EACH hExpr IN aPushes
      IF ! HB_ISHASH( hExpr ) .OR. !( hb_HGetDef( hExpr, "et", "" ) == "SELF" )
         RETURN .F.
      ENDIF
   NEXT

   RETURN .T.

// une dois tipos B7 com ACORDO: classes unem em conjunto finito; valores
// iguais mantêm; mistura ou desconhecido => NIL (⊤)
STATIC FUNCTION B7Merge( hA, hB )

   LOCAL hSet, cK

   IF hA == NIL .OR. hB == NIL
      RETURN NIL
   ENDIF
   IF hb_HHasKey( hA, "val" ) .AND. hb_HHasKey( hB, "val" )
      RETURN iif( hA[ "val" ] == hB[ "val" ], hA, NIL )
   ENDIF
   IF ( hb_HHasKey( hA, "cls" ) .OR. hb_HHasKey( hA, "clsset" ) ) .AND. ;
      ( hb_HHasKey( hB, "cls" ) .OR. hb_HHasKey( hB, "clsset" ) )
      hSet := { => }
      FOR EACH cK IN B7ClsList( hA )
         hSet[ cK ] := .T.
      NEXT
      FOR EACH cK IN B7ClsList( hB )
         hSet[ cK ] := .T.
      NEXT
      IF Len( hSet ) == 1
         RETURN { "cls" => hb_HKeys( hSet )[ 1 ], "how" => "chain", ;
                  "via" => hb_HGetDef( hA, "via", .F. ) .OR. hb_HGetDef( hB, "via", .F. ) }
      ENDIF
      RETURN { "clsset" => hSet, "how" => "chain", ;
               "via" => hb_HGetDef( hA, "via", .F. ) .OR. hb_HGetDef( hB, "via", .F. ) }
   ENDIF

   RETURN NIL

STATIC FUNCTION B7ClsList( hType )

   IF hb_HHasKey( hType, "cls" )
      RETURN { hType[ "cls" ] }
   ENDIF

   RETURN hb_HKeys( hb_HGetDef( hType, "clsset", { => } ) )

// retorno interprocedural de uma função do projeto: união com acordo dos
// pushes rotulados de RETURN (ast-6). Ciclo/módulo sem rótulo/função de
// fora => NIL. Memo por módulo!função
STATIC FUNCTION B7FunRet( cUpFun, hAst, hInter )

   LOCAL aFA := B7FunOf( cUpFun, hAst, hInter )
   LOCAL cKey, hOut, hOne, hExpr, aPushes

   IF aFA == NIL
      RETURN NIL
   ENDIF
   cKey := hb_HGetDef( aFA[ 1 ], "module", "" ) + "!" + Upper( aFA[ 2 ][ "name" ] )
   IF hb_HHasKey( hInter[ "rets" ], cKey )
      RETURN hInter[ "rets" ][ cKey ]
   ENDIF
   IF hb_HHasKey( hInter[ "active" ], cKey ) .OR. ! B7Ret6( aFA[ 1 ] )
      RETURN NIL
   ENDIF
   hInter[ "active" ][ cKey ] := .T.
   aPushes := B7RetPushes( aFA[ 2 ] )
   hOut := NIL
   FOR EACH hExpr IN aPushes
      hOne := TypeOf( hExpr, aFA[ 2 ], hInter[ "decl" ], .F., NIL, hInter, aFA[ 1 ] )
      hOut := iif( hExpr:__enumIndex() == 1, hOne, B7Merge( hOut, hOne ) )
      IF hOut == NIL
         EXIT
      ENDIF
   NEXT
   IF Empty( aPushes )
      hOut := NIL
   ENDIF
   hb_HDel( hInter[ "active" ], cKey )
   // um retorno de classe vindo de OUTRA função é sempre cadeia (promessa
   // herdada) - nunca "declared"/"kt" do ponto de vista do chamador
   IF hOut != NIL .AND. hb_HHasKey( hOut, "cls" ) .AND. ;
      hb_HGetDef( hOut, "how", "" ) == "declared"
      hOut := hb_HClone( hOut )
      hOut[ "how" ] := "chain"
      hb_HDel( hOut, "kt" )
   ENDIF
   hInter[ "rets" ][ cKey ] := hOut

   RETURN hOut

// vínculos de construção ESCRITOS de uma classe: FUNREFs na árvore da
// função-classe que apontam OUTRA função-classe do projeto ou o teto de
// runtime (oráculo). IIF de condição LOGICAL constante segue só o ramo
// tomado (a semântica do próprio HB_EA_REDUCE). Ordem de escrita, dedup
STATIC FUNCTION B7Links( cUpCls, hInter )

   LOCAL aOut, aRefs, cRef, aCF, hStmt

   IF hb_HHasKey( hInter[ "links" ], cUpCls )
      RETURN hInter[ "links" ][ cUpCls ]
   ENDIF
   aOut := {}
   IF hInter[ "orc" ] != NIL .AND. cUpCls == hInter[ "orc" ][ "cls" ]
      // raiz de runtime: sem pais
   ELSEIF ( aCF := hb_HGetDef( hInter[ "clsmap" ], cUpCls, NIL ) ) != NIL
      aRefs := {}
      FOR EACH hStmt IN aCF[ 3 ][ "statements" ]
         B7FunRefsWalk( hb_HGetDef( hStmt, "expr", NIL ), aRefs )
      NEXT
      FOR EACH cRef IN aRefs
         IF !( cRef == cUpCls ) .AND. AScan( aOut, {| c | c == cRef } ) == 0 .AND. ;
            ( hb_HHasKey( hInter[ "clsmap" ], cRef ) .OR. ;
              ( hInter[ "orc" ] != NIL .AND. cRef == hInter[ "orc" ][ "cls" ] ) )
            AAdd( aOut, cRef )
         ENDIF
      NEXT
   ENDIF
   hInter[ "links" ][ cUpCls ] := aOut

   RETURN aOut

STATIC PROCEDURE B7FunRefsWalk( hExpr, aRefs )

   LOCAL xVal, hItem, aItems

   IF ! HB_ISHASH( hExpr )
      RETURN
   ENDIF
   IF hb_HGetDef( hExpr, "et", "" ) == "FUNREF"
      AAdd( aRefs, Upper( hb_HGetDef( hExpr, "val", "" ) ) )
      RETURN
   ENDIF
   // fold do IIF constante: o ramo morto não é vínculo (o reduce do
   // compilador o elimina do pcode)
   IF hb_HGetDef( hExpr, "et", "" ) == "IIF" .AND. ;
      Len( aItems := hb_HGetDef( hExpr, "items", {} ) ) == 3 .AND. ;
      HB_ISHASH( aItems[ 1 ] ) .AND. ;
      hb_HGetDef( aItems[ 1 ], "et", "" ) == "LOGICAL"
      B7FunRefsWalk( aItems[ iif( hb_HGetDef( aItems[ 1 ], "val", .F. ), 2, 3 ) ], aRefs )
      RETURN
   ENDIF
   FOR EACH xVal IN hExpr
      IF HB_ISHASH( xVal ) .AND. hb_HHasKey( xVal, "et" )
         B7FunRefsWalk( xVal, aRefs )
      ELSEIF HB_ISARRAY( xVal )
         FOR EACH hItem IN xVal
            B7FunRefsWalk( hItem, aRefs )
         NEXT
      ENDIF
   NEXT

   RETURN

// pares de REGISTRO (STRING, @F()|codeblock) da função-classe: itens
// DIRETOS do mesmo ARGLIST - a primeira STRING nomeia, o primeiro FUNREF
// direto é a impl (codeblock direto = membro inline, sem fato de retorno).
// O par-classe (impl == a própria função-classe) fica de fora. Mesma
// leitura para classes do projeto e para o oráculo (genérica: nenhum nome
// de biblioteca)
STATIC FUNCTION B7Regs( cUpCls, hInter )

   LOCAL hRegs, aCF, hFunCls, hStmt, hBlks

   IF hb_HHasKey( hInter[ "regs" ], cUpCls )
      RETURN hInter[ "regs" ][ cUpCls ]
   ENDIF
   hRegs := { => }
   hBlks := { => }
   IF hInter[ "orc" ] != NIL .AND. cUpCls == hInter[ "orc" ][ "cls" ]
      hFunCls := hInter[ "orc" ][ "fun" ]
   ELSEIF ( aCF := hb_HGetDef( hInter[ "clsmap" ], cUpCls, NIL ) ) != NIL
      hFunCls := aCF[ 3 ]
   ENDIF
   IF hFunCls != NIL
      FOR EACH hStmt IN hFunCls[ "statements" ]
         B7RegPairsWalk( hb_HGetDef( hStmt, "expr", NIL ), ;
                         Upper( hFunCls[ "name" ] ), hRegs, hBlks )
      NEXT
   ENDIF
   hInter[ "regs" ][ cUpCls ] := hRegs
   hInter[ "inlblk" ][ cUpCls ] := hBlks      // blocos de membro INLINE (B7b)

   RETURN hRegs

// B7b: a leitura é em PROFUNDIDADE-0 (não desce em corpo de CODEBLOCK) -
// registro dentro de bloco não roda na construção da classe (executaria
// por dispatch: fronteira de runtime, fora do como-escrito). hBlks
// (opcional) colhe os blocos de membro INLINE: chave do nó => mensagem
STATIC PROCEDURE B7RegPairsWalk( hExpr, cUpClsFun, hRegs, hBlks )

   LOCAL xVal, hItem, hParms, cName, cImpl, lInline, hCb

   IF ! HB_ISHASH( hExpr ) .OR. hb_HGetDef( hExpr, "et", "" ) == "CODEBLOCK"
      RETURN
   ENDIF
   hParms := hb_HGetDef( hExpr, "parms", NIL )
   IF HB_ISHASH( hParms ) .AND. hb_HGetDef( hParms, "et", "" ) == "ARGLIST"
      cName := NIL
      cImpl := NIL
      lInline := .F.
      hCb := NIL
      FOR EACH hItem IN hb_HGetDef( hParms, "items", {} )
         IF ! HB_ISHASH( hItem )
            LOOP
         ENDIF
         DO CASE
         CASE hb_HGetDef( hItem, "et", "" ) == "STRING" .AND. cName == NIL .AND. ;
              Len( hb_HGetDef( hItem, "val", "" ) ) > 0
            cName := Upper( hItem[ "val" ] )
         CASE hb_HGetDef( hItem, "et", "" ) == "FUNREF" .AND. cImpl == NIL
            cImpl := Upper( hb_HGetDef( hItem, "val", "" ) )
         CASE hb_HGetDef( hItem, "et", "" ) == "CODEBLOCK" .AND. cImpl == NIL .AND. ! lInline
            lInline := .T.
            hCb := hItem
         ENDCASE
      NEXT
      IF cName != NIL .AND. ( cImpl != NIL .OR. lInline ) .AND. ;
         !( cImpl == cUpClsFun ) .AND. ! hb_HHasKey( hRegs, cName )
         hRegs[ cName ] := cImpl      // NIL quando inline (sem fato)
         IF hBlks != NIL .AND. cImpl == NIL .AND. hCb != NIL
            hBlks[ B7NodeKey( hCb ) ] := cName
         ENDIF
      ENDIF
   ENDIF
   FOR EACH xVal IN hExpr
      IF HB_ISHASH( xVal ) .AND. hb_HHasKey( xVal, "et" )
         B7RegPairsWalk( xVal, cUpClsFun, hRegs, hBlks )
      ELSEIF HB_ISARRAY( xVal )
         FOR EACH hItem IN xVal
            B7RegPairsWalk( hItem, cUpClsFun, hRegs, hBlks )
         NEXT
      ENDIF
   NEXT

   RETURN

// retorno do MÉTODO resolvido pela cadeia escrita a partir da classe do
// receptor (B7/D1). Devolve { lAchado, hTipo }: achado sem fato de
// retorno = { .T., NIL } (para a subida - o dispatch pararia ali)
STATIC FUNCTION B7MethodRet( cCur, hRecv, cUpMsg, lVia, hInter, hSeen )

   LOCAL hDecl := hInter[ "decl" ], hRegs, aFA, cLink, aR, hAstCls, aCF
   LOCAL lDeclHit := .F., hT

   IF hSeen == NIL
      hSeen := { => }
   ENDIF
   IF hb_HHasKey( hSeen, cCur )
      RETURN { .F., NIL }
   ENDIF
   hSeen[ cCur ] := .T.

   // 1. método DECLARADO na classe corrente (canal declared). Declarado
   //    SEM tipo (B7b): a mensagem é PRÓPRIA daqui (o dispatch para), mas
   //    o fato de retorno vem da implementação registrada - cai ao passo 2
   IF hb_HHasKey( hDecl[ "c" ], cCur ) .AND. hb_HHasKey( hDecl[ "c" ][ cCur ], cUpMsg )
      hT := B7ViaMark( DeclType( hDecl[ "c" ][ cCur ][ cUpMsg ], "chain" ), lVia )
      IF hT != NIL
         RETURN { .T., hT }
      ENDIF
      lDeclHit := .T.
   ENDIF

   // 2. método REGISTRADO na classe corrente (pares STRING/@F())
   hRegs := B7Regs( cCur, hInter )
   IF hb_HHasKey( hRegs, cUpMsg )
      IF hRegs[ cUpMsg ] == NIL
         RETURN { .T., NIL }      // inline/codeblock: sem fato de retorno
      ENDIF
      hAstCls := iif( hInter[ "orc" ] != NIL .AND. cCur == hInter[ "orc" ][ "cls" ], ;
                      hInter[ "orc" ][ "ast" ], ;
                      iif( ( aCF := hb_HGetDef( hInter[ "clsmap" ], cCur, NIL ) ) != NIL, ;
                           aCF[ 2 ], NIL ) )
      aFA := B7FunOf( hRegs[ cUpMsg ], hAstCls, hInter )
      IF aFA == NIL
         RETURN { .T., NIL }
      ENDIF
      // QSelf() = o RECEPTOR por identidade (fato provado): o tipo é o do
      // próprio receptor, não o da classe dona da implementação
      IF B7AllRetsSelf( aFA[ 2 ] )
         RETURN { .T., B7ViaMark( hb_HClone( hRecv ), lVia ) }
      ENDIF
      RETURN { .T., B7ViaMark( B7FunRet( hRegs[ cUpMsg ], hAstCls, hInter ), lVia ) }
   ENDIF
   // declarada aqui sem registro visível: achada, sem fato (não sobe -
   // o acerto é próprio)
   IF lDeclHit
      RETURN { .T., NIL }
   ENDIF

   // 3. sobe pelos vínculos escritos, na ordem; primeiro ACHADO vence
   //    (profundidade - regra do VM sobre o grafo como-escrito)
   FOR EACH cLink IN B7Links( cCur, hInter )
      aR := B7MethodRet( cLink, hRecv, cUpMsg, .T., hInter, hSeen )
      IF aR[ 1 ]
         RETURN aR
      ENDIF
   NEXT

   RETURN { .F., NIL }

// retorno de um SEND resolvido pela cadeia (receptor de classe conhecida
// ou conjunto finito): acordo entre os candidatos ou NIL
STATIC FUNCTION B7SendRet( hRecv, cUpMsg, hInter )

   LOCAL aCls := B7ClsList( hRecv ), cCls, hOne, hOut := NIL, aR
   LOCAL cKey, lVia := hb_HGetDef( hRecv, "via", .F. )

   IF Empty( aCls )
      RETURN NIL
   ENDIF
   FOR EACH cCls IN aCls
      // guarda de ciclo entre sends aninhados (a():b():a()...)
      cKey := "s!" + cCls + "!" + cUpMsg
      IF hb_HHasKey( hInter[ "active" ], cKey )
         RETURN NIL
      ENDIF
      hInter[ "active" ][ cKey ] := .T.
      aR := B7MethodRet( cCls, iif( Len( aCls ) == 1, hRecv, ;
              { "cls" => cCls, "how" => "chain", "via" => lVia } ), ;
              cUpMsg, lVia, hInter, NIL )
      hb_HDel( hInter[ "active" ], cKey )
      hOne := iif( aR[ 1 ], aR[ 2 ], NIL )
      IF hOne == NIL
         RETURN NIL
      ENDIF
      hOut := iif( cCls:__enumIndex() == 1, hOne, B7Merge( hOut, hOne ) )
      IF hOut == NIL
         RETURN NIL
      ENDIF
   NEXT

   RETURN hOut

// tipo de `::Super:...` - o MESMO objeto visto pela cadeia do pai escrito;
// só decide com vínculo ÚNICO (multiherança: conservador, NIL)
STATIC FUNCTION B7SuperType( hExpr, hFunc, hDecl, xBlock, hSeen, hInter, hAst )

   LOCAL hBase, aLinks

   IF hInter == NIL
      RETURN NIL
   ENDIF
   hBase := TypeOf( hb_HGetDef( hExpr, "obj", NIL ), hFunc, hDecl, xBlock, ;
                    hSeen, hInter, hAst )
   IF hBase == NIL .OR. ! hb_HHasKey( hBase, "cls" )
      RETURN NIL
   ENDIF
   aLinks := B7Links( hBase[ "cls" ], hInter )
   IF Len( aLinks ) == 1
      RETURN { "cls" => aLinks[ 1 ], "how" => "chain", "via" => .T. }
   ENDIF

   RETURN NIL

// ---------------------------------------------------------------------------
// B7b - inferência fatia 3 (spec-b7b-inferencia.md, portão de 2026-07-08):
// parâmetro de bloco decidido por FATO da declaração (o dump registra os
// params do bloco com param=true e declLine na linha do `{|`, em ordem);
// 1º parâmetro de bloco de membro INLINE registrado = o RECEPTOR (fato do
// VM: classes.c:4554 empilha Self como 1º argumento do bloco - vale para
// __clsAddMsg/AddInline/qualquer DSL, nada keyed a hbclass); demais params
// de bloco tipam pela união dos argumentos dos sites de Eval QUANDO o
// bloco é rastreável até eles (obj direto de Eval, ou binding único de
// local cujas leituras são TODAS obj de Eval) - ponto cego => NIL honesto
// ---------------------------------------------------------------------------

// identidade de um nó da árvore no dump (tok de nascimento + linha):
// suficiente para distinguir nós CODEBLOCK entre si dentro de uma função
STATIC FUNCTION B7NodeKey( hNode )
   RETURN hb_ntos( hb_HGetDef( hNode, "tok", -1 ) ) + "|" + ;
          hb_ntos( hb_HGetDef( hNode, "line", -1 ) )

// quantos nós CODEBLOCK a função tem naquela linha? (>1 = as declarações
// de param da linha não são atribuíveis a um bloco - ambíguo, degrada)
STATIC FUNCTION B7BlkLineCount( hFunc, nLine )

   LOCAL hCnt, hStmt

   IF hb_HHasKey( hFunc, "_b7blkl" )
      hCnt := hFunc[ "_b7blkl" ]
   ELSE
      hCnt := { => }
      FOR EACH hStmt IN hFunc[ "statements" ]
         B7BlkCountWalk( hb_HGetDef( hStmt, "expr", NIL ), hCnt )
      NEXT
      hFunc[ "_b7blkl" ] := hCnt
   ENDIF

   RETURN hb_HGetDef( hCnt, nLine, 0 )

STATIC PROCEDURE B7BlkCountWalk( hExpr, hCnt )

   LOCAL xVal, hItem, nLine

   IF ! HB_ISHASH( hExpr )
      RETURN
   ENDIF
   IF hb_HGetDef( hExpr, "et", "" ) == "CODEBLOCK"
      nLine := hb_HGetDef( hExpr, "line", -1 )
      hCnt[ nLine ] := hb_HGetDef( hCnt, nLine, 0 ) + 1
   ENDIF
   FOR EACH xVal IN hExpr
      IF HB_ISHASH( xVal ) .AND. hb_HHasKey( xVal, "et" )
         B7BlkCountWalk( xVal, hCnt )
      ELSEIF HB_ISARRAY( xVal )
         FOR EACH hItem IN xVal
            B7BlkCountWalk( hItem, hCnt )
         NEXT
      ENDIF
   NEXT

   RETURN

// pilha de blocos que envolvem hBlk (do mais externo ao próprio hBlk),
// achada nas árvores de statements; NIL = não localizado
STATIC FUNCTION B7BlkStack( hFunc, hBlk )

   LOCAL hStmt, aOut, cKey := B7NodeKey( hBlk )

   FOR EACH hStmt IN hFunc[ "statements" ]
      aOut := B7BlkStackWalk( hb_HGetDef( hStmt, "expr", NIL ), cKey, {} )
      IF aOut != NIL
         RETURN aOut
      ENDIF
   NEXT

   RETURN NIL

STATIC FUNCTION B7BlkStackWalk( hExpr, cKey, aStack )

   LOCAL xVal, hItem, aR

   IF ! HB_ISHASH( hExpr )
      RETURN NIL
   ENDIF
   IF hb_HGetDef( hExpr, "et", "" ) == "CODEBLOCK"
      aStack := AClone( aStack )
      AAdd( aStack, hExpr )
      IF B7NodeKey( hExpr ) == cKey
         RETURN aStack
      ENDIF
   ENDIF
   FOR EACH xVal IN hExpr
      IF HB_ISHASH( xVal ) .AND. hb_HHasKey( xVal, "et" )
         aR := B7BlkStackWalk( xVal, cKey, aStack )
         IF aR != NIL
            RETURN aR
         ENDIF
      ELSEIF HB_ISARRAY( xVal )
         FOR EACH hItem IN xVal
            aR := B7BlkStackWalk( hItem, cKey, aStack )
            IF aR != NIL
               RETURN aR
            ENDIF
         NEXT
      ENDIF
   NEXT

   RETURN NIL

// cSym é PARÂMETRO DE BLOCO neste uso? Resolução LÉXICA por fato: a
// declaração param fora da linha da função é de bloco; o binder é o bloco
// mais interno da pilha de hBlk cuja linha declara cSym. Devolve:
//   NIL                  -> não é param de bloco daqui (caminho normal)
//   {} (vazio)           -> é/pode ser param de bloco sem vinculação
//                           decidível -> degrada (conservador)
//   { hCb, nIdx, hDecl } -> param nIdx (1-based) do bloco hCb
STATIC FUNCTION B7BlockParam( hFunc, hBlk, cSym )

   LOCAL hItem, lIsPar := .F., nFnLine := hFunc[ "line" ], aStack, nI, nLine
   LOCAL nIdx, hMine

   FOR EACH hItem IN hFunc[ "declarations" ]
      IF hb_HGetDef( hItem, "param", .F. ) .AND. ;
         !( hItem[ "declLine" ] == nFnLine ) .AND. Upper( hItem[ "sym" ] ) == cSym
         lIsPar := .T.
         EXIT
      ENDIF
   NEXT
   IF ! lIsPar
      RETURN NIL
   ENDIF
   IF hBlk == NIL
      RETURN {}      // contexto de bloco desconhecido: degrada como sempre
   ENDIF
   IF ( aStack := B7BlkStack( hFunc, hBlk ) ) == NIL
      RETURN {}
   ENDIF
   FOR nI := Len( aStack ) TO 1 STEP -1
      nLine := hb_HGetDef( aStack[ nI ], "line", -1 )
      nIdx  := 0
      hMine := NIL
      FOR EACH hItem IN hFunc[ "declarations" ]
         IF hb_HGetDef( hItem, "param", .F. ) .AND. hItem[ "declLine" ] == nLine .AND. ;
            !( nLine == nFnLine )
            nIdx++
            IF Upper( hItem[ "sym" ] ) == cSym
               hMine := hItem
               EXIT
            ENDIF
         ENDIF
      NEXT
      IF hMine != NIL
         // dois blocos na mesma linha: as declarações da linha não são
         // atribuíveis a um só bloco - ambíguo
         IF B7BlkLineCount( hFunc, nLine ) != 1
            RETURN {}
         ENDIF
         RETURN { aStack[ nI ], nIdx, hMine }
      ENDIF
   NEXT

   RETURN NIL      // param de bloco que NÃO envolve o uso: captura externa

// alvo 2 (B7b): o bloco é membro INLINE registrado da classe cuja
// função-classe é hFunc? Então o 1º parâmetro é o RECEPTOR (classes.c:4554
// empilha Self como 1º argumento) - tipo = a classe, com a ressalva do
// como-escrito ("via"): o registro é vínculo escrito e um descendente que
// herde o inline chega aqui com receptor próprio
STATIC FUNCTION B7InlineSelfType( hFunc, hAst, aBP, hInter )

   LOCAL cCls

   IF aBP[ 2 ] != 1
      RETURN NIL
   ENDIF
   cCls := hb_HGetDef( hInter[ "clsfn" ], ;
                       hb_HGetDef( hAst, "module", "" ) + "!" + Upper( hFunc[ "name" ] ), NIL )
   IF cCls == NIL
      RETURN NIL
   ENDIF
   B7Regs( cCls, hInter )      // materializa o memo dos blocos inline
   IF hb_HHasKey( hb_HGetDef( hInter[ "inlblk" ], cCls, { => } ), B7NodeKey( aBP[ 1 ] ) )
      RETURN { "cls" => cCls, "how" => "chain", "via" => .T. }
   ENDIF

   RETURN NIL

// alvo 3b (B7b): tipo de um parâmetro de bloco pela união dos argumentos
// dos sites de Eval rastreáveis (o compilador traduz Eval(b,...) para o
// send b:EVAL(...) - fato do dump). Rastreável = o bloco é obj direto de
// um Eval, OU é o único write de uma local (binding único) cujas leituras
// são TODAS obj de Eval. Qualquer outra aparição/leitura (arg de função,
// item de array, RETURN, @ref) = ponto cego => NIL. Memo + guarda de ciclo
STATIC FUNCTION B7BlockEvalType( hFunc, hAst, aBP, cSym, hDecl, hSeen, hInter )

   LOCAL cKey, aSites, aSite, hOne, hOut := NIL

   HB_SYMBOL_UNUSED( hSeen )
   cKey := "b!" + hb_HGetDef( hAst, "module", "" ) + "!" + Upper( hFunc[ "name" ] ) + ;
           "!" + B7NodeKey( aBP[ 1 ] ) + "!" + cSym
   IF hb_HHasKey( hInter[ "params" ], cKey )
      RETURN hInter[ "params" ][ cKey ]
   ENDIF
   IF hb_HHasKey( hInter[ "active" ], cKey )
      RETURN NIL
   ENDIF
   hInter[ "active" ][ cKey ] := .T.
   aSites := B7BlockEvalArgs( hFunc, aBP[ 1 ], aBP[ 2 ] )
   IF aSites == NIL .OR. Empty( aSites )
      hOut := NIL
   ELSE
      FOR EACH aSite IN aSites
         // arg ausente/NONE = omitido (NIL em runtime)
         hOne := iif( aSite[ 1 ] == NIL, { "val" => "nil" }, ;
                      TypeOf( aSite[ 1 ], hFunc, hDecl, aSite[ 2 ], NIL, hInter, hAst ) )
         hOut := iif( aSite:__enumIndex() == 1, hOne, B7Merge( hOut, hOne ) )
         IF hOut == NIL
            EXIT
         ENDIF
      NEXT
   ENDIF
   hb_HDel( hInter[ "active" ], cKey )
   IF hOut != NIL .AND. hb_HGetDef( hOut, "how", "" ) == "declared"
      hOut := hb_HClone( hOut )
      hOut[ "how" ] := "chain"
      hb_HDel( hOut, "kt" )
   ENDIF
   hInter[ "params" ][ cKey ] := hOut

   RETURN hOut

// os argumentos na posição nIdx de cada site de Eval do bloco hBlk, com o
// contexto de bloco de cada site; NIL = bloco não rastreável até os Evals
STATIC FUNCTION B7BlockEvalArgs( hFunc, hBlk, nIdx )

   LOCAL aCtx := B7BlkNodeCtx( hFunc, hBlk ), aOut := {}, aEvals, aE
   LOCAL cVar, hOcc, nWrites := 0, nRefs := 0

   IF aCtx == NIL
      RETURN NIL
   ENDIF
   IF aCtx[ 1 ] == "evalobj"
      AAdd( aOut, { B7EvalArgAt( aCtx[ 2 ], nIdx ), aCtx[ 3 ] } )
      RETURN aOut
   ENDIF
   IF !( aCtx[ 1 ] == "bind" )
      RETURN NIL
   ENDIF
   // binding único da local que recebeu o bloco: 1 write, 0 refs, fora do
   // alcance dinâmico (memvar/field ficam de fora pelo scope da occurrence)
   cVar := aCtx[ 2 ]
   FOR EACH hOcc IN hFunc[ "occurrences" ]
      IF Upper( hOcc[ "sym" ] ) == cVar
         IF hb_AScan( { "memvar", "memvar_implicit", "field" }, hOcc[ "scope" ] ) > 0
            RETURN NIL
         ENDIF
         IF hOcc[ "access" ] == "write"
            nWrites++
         ELSEIF hOcc[ "access" ] == "ref"
            nRefs++
         ENDIF
      ENDIF
   NEXT
   IF nWrites != 1 .OR. nRefs != 0
      RETURN NIL
   ENDIF
   IF ( aEvals := B7VarEvalReads( hFunc, cVar ) ) == NIL
      RETURN NIL
   ENDIF
   FOR EACH aE IN aEvals
      AAdd( aOut, { B7EvalArgAt( aE[ 1 ], nIdx ), aE[ 2 ] } )
   NEXT

   RETURN aOut

// argumento nIdx (1-based) de um nó SEND Eval; NIL = omitido/NONE
STATIC FUNCTION B7EvalArgAt( hSend, nIdx )

   LOCAL aItems := hb_HGetDef( hb_HGetDef( hSend, "parms", { => } ), "items", {} )

   IF nIdx <= Len( aItems ) .AND. HB_ISHASH( aItems[ nIdx ] ) .AND. ;
      !( hb_HGetDef( aItems[ nIdx ], "et", "" ) == "NONE" )
      RETURN aItems[ nIdx ]
   ENDIF

   RETURN NIL

// classifica a aparição do bloco nas árvores da função:
//   { "evalobj", hSend, xBlkCtx } -> obj direto de um send EVAL
//   { "bind", cVarUpper }         -> lado direito de ASSIGN de topo p/ local
//   { "other" }                   -> qualquer outra posição (não rastreável)
//   NIL                           -> não localizado
STATIC FUNCTION B7BlkNodeCtx( hFunc, hBlk )

   LOCAL hStmt, hExpr, cKey := B7NodeKey( hBlk ), aR

   FOR EACH hStmt IN hFunc[ "statements" ]
      hExpr := hb_HGetDef( hStmt, "expr", NIL )
      IF HB_ISHASH( hExpr ) .AND. hb_HGetDef( hExpr, "et", "" ) == "ASSIGN" .AND. ;
         HB_ISHASH( hb_HGetDef( hExpr, "right", NIL ) ) .AND. ;
         hb_HGetDef( hExpr[ "right" ], "et", "" ) == "CODEBLOCK" .AND. ;
         B7NodeKey( hExpr[ "right" ] ) == cKey .AND. ;
         HB_ISHASH( hb_HGetDef( hExpr, "left", NIL ) ) .AND. ;
         hb_HGetDef( hExpr[ "left" ], "et", "" ) == "VARIABLE"
         RETURN { "bind", Upper( hb_HGetDef( hExpr[ "left" ], "val", "" ) ) }
      ENDIF
      aR := B7BlkCtxWalk( hExpr, cKey, iif( hStmt[ "block" ], .T., .F. ), NIL )
      IF aR != NIL
         RETURN aR
      ENDIF
   NEXT

   RETURN NIL

STATIC FUNCTION B7BlkCtxWalk( hExpr, cKey, xBlk, hParent )

   LOCAL xVal, hItem, aR, xChild

   IF ! HB_ISHASH( hExpr )
      RETURN NIL
   ENDIF
   IF hb_HGetDef( hExpr, "et", "" ) == "CODEBLOCK" .AND. B7NodeKey( hExpr ) == cKey
      IF hParent != NIL .AND. hb_HGetDef( hParent, "et", "" ) == "SEND" .AND. ;
         Upper( hb_HGetDef( hParent, "msg", "" ) ) == "EVAL" .AND. ;
         HB_ISHASH( hb_HGetDef( hParent, "obj", NIL ) ) .AND. ;
         hb_HGetDef( hParent[ "obj" ], "et", "" ) == "CODEBLOCK" .AND. ;
         B7NodeKey( hParent[ "obj" ] ) == cKey
         RETURN { "evalobj", hParent, xBlk }
      ENDIF
      RETURN { "other" }
   ENDIF
   xChild := iif( hb_HGetDef( hExpr, "et", "" ) == "CODEBLOCK", hExpr, xBlk )
   FOR EACH xVal IN hExpr
      IF HB_ISHASH( xVal ) .AND. hb_HHasKey( xVal, "et" )
         aR := B7BlkCtxWalk( xVal, cKey, xChild, hExpr )
         IF aR != NIL
            RETURN aR
         ENDIF
      ELSEIF HB_ISARRAY( xVal )
         FOR EACH hItem IN xVal
            aR := B7BlkCtxWalk( hItem, cKey, xChild, hExpr )
            IF aR != NIL
               RETURN aR
            ENDIF
         NEXT
      ENDIF
   NEXT

   RETURN NIL

// TODAS as leituras da local cVar nas árvores devem ser obj de send EVAL
// (a escrita do binding fica de fora); devolve { hSend, xBlkCtx } por site
// ou NIL se alguma leitura está em outra posição (ponto cego)
STATIC FUNCTION B7VarEvalReads( hFunc, cUpVar )

   LOCAL hStmt, aOut := {}, lOk := .T.

   FOR EACH hStmt IN hFunc[ "statements" ]
      B7VarReadsWalk( hb_HGetDef( hStmt, "expr", NIL ), cUpVar, ;
                      iif( hStmt[ "block" ], .T., .F. ), NIL, aOut, @lOk )
      IF ! lOk
         RETURN NIL
      ENDIF
   NEXT

   RETURN aOut

STATIC PROCEDURE B7VarReadsWalk( hExpr, cUpVar, xBlk, hParent, aOut, lOk )

   LOCAL xVal, hItem, xChild

   IF ! HB_ISHASH( hExpr ) .OR. ! lOk
      RETURN
   ENDIF
   IF hb_HGetDef( hExpr, "et", "" ) == "VARIABLE" .AND. ;
      Upper( hb_HGetDef( hExpr, "val", "" ) ) == cUpVar
      DO CASE
      CASE hParent != NIL .AND. hb_HGetDef( hParent, "et", "" ) == "ASSIGN" .AND. ;
           HB_ISHASH( hb_HGetDef( hParent, "left", NIL ) ) .AND. ;
           hParent[ "left" ] [ "et" ] == "VARIABLE" .AND. ;
           Upper( hb_HGetDef( hParent[ "left" ], "val", "" ) ) == cUpVar .AND. ;
           B7NodeKey( hParent[ "left" ] ) == B7NodeKey( hExpr )
         // a escrita do binding (left do ASSIGN): fora
      CASE hParent != NIL .AND. hb_HGetDef( hParent, "et", "" ) == "SEND" .AND. ;
           Upper( hb_HGetDef( hParent, "msg", "" ) ) == "EVAL" .AND. ;
           HB_ISHASH( hb_HGetDef( hParent, "obj", NIL ) ) .AND. ;
           B7NodeKey( hParent[ "obj" ] ) == B7NodeKey( hExpr ) .AND. ;
           hParent[ "obj" ][ "et" ] == "VARIABLE"
         AAdd( aOut, { hParent, xBlk } )
      OTHERWISE
         lOk := .F.      // leitura fora de Eval: ponto cego
         RETURN
      ENDCASE
   ENDIF
   xChild := iif( hb_HGetDef( hExpr, "et", "" ) == "CODEBLOCK", hExpr, xBlk )
   FOR EACH xVal IN hExpr
      IF HB_ISHASH( xVal ) .AND. hb_HHasKey( xVal, "et" )
         B7VarReadsWalk( xVal, cUpVar, xChild, hExpr, aOut, @lOk )
      ELSEIF HB_ISARRAY( xVal )
         FOR EACH hItem IN xVal
            B7VarReadsWalk( hItem, cUpVar, xChild, hExpr, aOut, @lOk )
         NEXT
      ENDIF
   NEXT

   RETURN

// tipo de um PARÂMETRO pela união dos argumentos de todos os call sites
// do projeto (B7). Só com o mundo fechado AUDITADO: macro em qualquer
// módulo, o nome da função citado em string ou a função referenciada por
// @F() (chamada indireta/dispatch) => ⊤. STATIC une só o próprio módulo;
// pública pula módulos onde um STATIC homônimo a sombreia. Argumento
// omitido = NIL em runtime. Memo por módulo!função!parâmetro
STATIC FUNCTION B7ParamType( hFuncOwn, hAstOwn, cUpSym, hInter )

   LOCAL nIdx := 0, nP := 0, hItem, cUpFun := Upper( hFuncOwn[ "name" ] )
   LOCAL cKey, hOut := NIL, aSites, aSite, hOne

   // B7b: só parâmetro da FUNÇÃO conta (declLine na linha da função);
   // param de codeblock (declLine na linha do bloco) corrompia o índice
   // e cairia na união de call sites errada - degrada honesto
   FOR EACH hItem IN hFuncOwn[ "declarations" ]
      IF hb_HGetDef( hItem, "param", .F. ) .AND. ;
         hItem[ "declLine" ] == hFuncOwn[ "line" ]
         nP++
         IF Upper( hItem[ "sym" ] ) == cUpSym
            nIdx := nP
            EXIT
         ENDIF
      ENDIF
   NEXT
   IF nIdx == 0
      RETURN NIL
   ENDIF
   B7DynAudit( hInter )
   IF hInter[ "dyn" ] .OR. hb_HHasKey( hInter[ "strs" ], cUpFun ) .OR. ;
      hb_HHasKey( hInter[ "funrefs" ], cUpFun )
      RETURN NIL
   ENDIF
   cKey := "p!" + hb_HGetDef( hAstOwn, "module", "" ) + "!" + cUpFun + "!" + cUpSym
   IF hb_HHasKey( hInter[ "params" ], cKey )
      RETURN hInter[ "params" ][ cKey ]
   ENDIF
   IF hb_HHasKey( hInter[ "active" ], cKey )
      RETURN NIL
   ENDIF
   hInter[ "active" ][ cKey ] := .T.
   aSites := B7CallArgs( cUpFun, hFuncOwn[ "static" ], hAstOwn, nIdx, hInter )
   FOR EACH aSite IN aSites
      // NONE/faltante = argumento omitido (NIL em runtime)
      hOne := iif( aSite[ 1 ] == NIL, { "val" => "nil" }, ;
                   TypeOf( aSite[ 1 ], aSite[ 2 ], hInter[ "decl" ], aSite[ 4 ], ;
                           NIL, hInter, aSite[ 3 ] ) )
      hOut := iif( aSite:__enumIndex() == 1, hOne, B7Merge( hOut, hOne ) )
      IF hOut == NIL
         EXIT
      ENDIF
   NEXT
   IF Empty( aSites )
      hOut := NIL      // sem chamador visível: sem fato
   ENDIF
   hb_HDel( hInter[ "active" ], cKey )
   IF hOut != NIL .AND. hb_HGetDef( hOut, "how", "" ) == "declared"
      hOut := hb_HClone( hOut )
      hOut[ "how" ] := "chain"
      hb_HDel( hOut, "kt" )
   ENDIF
   hInter[ "params" ][ cKey ] := hOut

   RETURN hOut

// call sites FUNCALL de uma função no projeto: { arg-expr|NIL, hFunc,
// hAst, block } por site
STATIC FUNCTION B7CallArgs( cUpFun, lStatic, hAstOwn, nIdx, hInter )

   LOCAL aOut := {}, cPath, hAst, hFunc, hStmt, aFA
   LOCAL cModOwn := hb_HGetDef( hAstOwn, "module", "" )

   FOR EACH cPath IN hb_HKeys( hInter[ "asts" ] )
      hAst := hInter[ "asts" ][ cPath ]
      IF lStatic .AND. !( hb_HGetDef( hAst, "module", "" ) == cModOwn )
         LOOP
      ENDIF
      IF ! lStatic .AND. !( hb_HGetDef( hAst, "module", "" ) == cModOwn )
         // STATIC homônimo naquele módulo sombreia a pública
         aFA := hb_HGetDef( hAst[ "_b7funcs" ], cUpFun, NIL )
         IF aFA != NIL .AND. aFA[ 2 ][ "static" ]
            LOOP
         ENDIF
      ENDIF
      FOR EACH hFunc IN hAst[ "functions" ]
         IF hFunc[ "fileDecl" ]
            LOOP
         ENDIF
         FOR EACH hStmt IN hFunc[ "statements" ]
            B7ArgWalk( hb_HGetDef( hStmt, "expr", NIL ), cUpFun, nIdx, ;
                       hFunc, hAst, hStmt[ "block" ], aOut )
         NEXT
      NEXT
   NEXT

   RETURN aOut

STATIC PROCEDURE B7ArgWalk( hExpr, cUpFun, nIdx, hFunc, hAst, xBlock, aOut )

   LOCAL xVal, hItem, hFun, aItems, hArg, xChild

   IF ! HB_ISHASH( hExpr )
      RETURN
   ENDIF
   IF hb_HGetDef( hExpr, "et", "" ) == "FUNCALL" .AND. ;
      HB_ISHASH( hFun := hb_HGetDef( hExpr, "fun", NIL ) ) .AND. ;
      hb_HGetDef( hFun, "et", "" ) == "FUNNAME" .AND. ;
      Upper( hb_HGetDef( hFun, "val", "" ) ) == cUpFun
      aItems := hb_HGetDef( hb_HGetDef( hExpr, "parms", { => } ), "items", {} )
      hArg := NIL
      IF nIdx <= Len( aItems ) .AND. HB_ISHASH( aItems[ nIdx ] ) .AND. ;
         !( hb_HGetDef( aItems[ nIdx ], "et", "" ) == "NONE" )
         hArg := aItems[ nIdx ]
      ENDIF
      AAdd( aOut, { hArg, hFunc, hAst, xBlock } )
   ENDIF
   FOR EACH xVal IN hExpr
      IF HB_ISHASH( xVal ) .AND. hb_HHasKey( xVal, "et" )
         xChild := iif( hb_HGetDef( xVal, "et", "" ) == "CODEBLOCK", xVal, xBlock )
         B7ArgWalk( xVal, cUpFun, nIdx, hFunc, hAst, xChild, aOut )
      ELSEIF HB_ISARRAY( xVal )
         FOR EACH hItem IN xVal
            B7ArgWalk( hItem, cUpFun, nIdx, hFunc, hAst, xBlock, aOut )
         NEXT
      ENDIF
   NEXT

   RETURN

// auditoria dos pontos cegos do mundo fechado, UMA vez por run: strings
// do projeto (nome citado), FUNREFs (chamada indireta/registro) e
// presença de macro (& ou send por macro) em qualquer módulo
STATIC PROCEDURE B7DynAudit( hInter )

   LOCAL cPath, hAst, hFunc, hStmt

   IF hInter[ "strs" ] != NIL
      RETURN
   ENDIF
   hInter[ "strs" ]    := { => }
   hInter[ "funrefs" ] := { => }
   hInter[ "dyn" ]     := .F.
   FOR EACH cPath IN hb_HKeys( hInter[ "asts" ] )
      hAst := hInter[ "asts" ][ cPath ]
      FOR EACH hFunc IN hAst[ "functions" ]
         FOR EACH hStmt IN hFunc[ "statements" ]
            B7AuditWalk( hb_HGetDef( hStmt, "expr", NIL ), hInter )
         NEXT
      NEXT
   NEXT

   RETURN

STATIC PROCEDURE B7AuditWalk( hExpr, hInter )

   LOCAL xVal, hItem, cEt

   IF ! HB_ISHASH( hExpr )
      RETURN
   ENDIF
   cEt := hb_HGetDef( hExpr, "et", "" )
   DO CASE
   CASE cEt == "STRING"
      hInter[ "strs" ][ Upper( hb_HGetDef( hExpr, "val", "" ) ) ] := .T.
   CASE cEt == "FUNREF"
      hInter[ "funrefs" ][ Upper( hb_HGetDef( hExpr, "val", "" ) ) ] := .T.
   CASE "MACRO" $ cEt
      hInter[ "dyn" ] := .T.
   ENDCASE
   IF hb_HGetDef( hExpr, "msgmacro", NIL ) != NIL
      hInter[ "dyn" ] := .T.
   ENDIF
   FOR EACH xVal IN hExpr
      IF HB_ISHASH( xVal ) .AND. hb_HHasKey( xVal, "et" )
         B7AuditWalk( xVal, hInter )
      ELSEIF HB_ISARRAY( xVal )
         FOR EACH hItem IN xVal
            B7AuditWalk( hItem, hInter )
         NEXT
      ENDIF
   NEXT

   RETURN

// D3: teto de runtime pelo ORÁCULO - compila UMA vez (cache por
// tamanho+mtime) o fonte da raiz de runtime do PRÓPRIO Harbour
// (src/rtl/tobject.prg, achado a partir de HB_BIN) com -x e lê o registro
// como escrito: o par (STRING, @F()) cuja impl é a PRÓPRIA função
// container nomeia a classe; os demais pares são os membros. Sem HB_BIN,
// sem a árvore de fontes ou sem dump com rótulo de RETURN: NIL - degrada
// honesto para o comportamento de hoje (possible)
STATIC FUNCTION OracleLoad()

   LOCAL cBin := hb_GetEnv( "HB_BIN" ), cRoot, cSrc, cCacheDir, cJson
   LOCAL tSrc, cOut := "", cErr := "", hAst, hFunc, hRegs, cM, cCls, hMembers
   LOCAL cPs := hb_ps()

   IF Empty( cBin )
      RETURN NIL
   ENDIF
   cRoot := hb_PathNormalize( hb_DirSepAdd( cBin ) + ".." + cPs + ".." + cPs + ".." )
   cSrc  := hb_DirSepAdd( cRoot ) + "src" + cPs + "rtl" + cPs + "tobject.prg"
   IF ! hb_vfExists( cSrc )
      RETURN NIL
   ENDIF
   hb_vfTimeGet( cSrc, @tSrc )
   cCacheDir := hb_GetEnv( "XDG_CACHE_HOME" )
   IF Empty( cCacheDir )
      cCacheDir := hb_DirSepAdd( hb_GetEnv( "HOME" ) ) + ".cache"
   ENDIF
   cCacheDir += cPs + "hbrefactor"
   cJson := hb_DirSepAdd( cCacheDir ) + "tobject-" + ;
            hb_ntos( hb_vfSize( cSrc ) ) + "-" + ;
            StrTran( StrTran( hb_TToS( tSrc ), ":", "" ), " ", "" ) + ".ast.json"
   IF ! hb_vfExists( cJson )
      hb_DirBuild( cCacheDir )
      IF hb_processRun( hb_DirSepAdd( cBin ) + "harbour " + cSrc + ;
            " -n -q0 -w0 -gh -o" + hb_DirSepAdd( cCacheDir ) + "tobject.hrb" + ;
            " -x" + hb_DirSepAdd( cCacheDir ) + ;
            " -i" + hb_DirSepAdd( cRoot ) + "include",, @cOut, @cErr ) != 0
         RETURN NIL
      ENDIF
      hb_vfErase( hb_DirSepAdd( cCacheDir ) + "tobject.hrb" )
      IF hb_vfRename( hb_DirSepAdd( cCacheDir ) + "tobject.ast.json", cJson ) != 0
         RETURN NIL
      ENDIF
   ENDIF
   hAst := hb_jsonDecode( hb_MemoRead( cJson ) )
   IF ! HB_ISHASH( hAst ) .OR. ! B7Ret6( hAst )
      RETURN NIL
   ENDIF
   // acha a função-classe pelo par que se auto-referencia
   FOR EACH hFunc IN hAst[ "functions" ]
      IF hFunc[ "fileDecl" ]
         LOOP
      ENDIF
      hRegs := { => }
      B7RegSelfScan( hFunc, hRegs, @cCls )
      IF cCls != NIL
         hMembers := { => }
         FOR EACH cM IN hb_HKeys( hRegs )
            IF !( cM == cCls )
               hMembers[ cM ] := hRegs[ cM ]
            ENDIF
         NEXT
         RETURN { "cls" => cCls, "ast" => hAst, "fun" => hFunc, ;
                  "members" => hMembers }
      ENDIF
   NEXT

   RETURN NIL

// pares de registro de uma função + o nome de classe do par-classe (a
// STRING pareada com @F() da PRÓPRIA função container), se houver
STATIC PROCEDURE B7RegSelfScan( hFunc, hRegs, cCls )

   LOCAL hStmt, hAll := { => }, cM

   cCls := NIL
   FOR EACH hStmt IN hFunc[ "statements" ]
      B7RegPairsWalk( hb_HGetDef( hStmt, "expr", NIL ), "", hAll )
   NEXT
   FOR EACH cM IN hb_HKeys( hAll )
      IF hAll[ cM ] != NIL .AND. hAll[ cM ] == Upper( hFunc[ "name" ] )
         cCls := cM
      ELSE
         hRegs[ cM ] := hAll[ cM ]
      ENDIF
   NEXT

   RETURN

// ---------------------------------------------------------------------------
// B4f-2 - resolução de dispatch (spec-b4f2-dispatch.md). A REGRA é da
// LINGUAGEM (classes.c, provada em runtime pelos probes - fatos 1+7):
// método PRÓPRIO vence herdado; em conflito entre pais vence o PRIMEIRO da
// cláusula, em PROFUNDIDADE (o 1º pai leva junto tudo que herdou, pelo
// flattening do __clsNew). Os FATOS (pais na ordem, mensagens próprias)
// vêm dos canais genéricos - rastro de expansão e declared do ast-4 -
// nenhuma convenção de biblioteca (caso 64 vigia)
// ---------------------------------------------------------------------------

// grafo de classes do projeto: CLASSE => { "parents" => sequência de
// { NOME, noProjeto? } na ordem textual (ClassParentsSeq), "members" =>
// mensagens PRÓPRIAS (união do registro por stringify e do canal declared
// - fato 5) }. As entradas vêm de ClassFuncMap (funções derivadas de
// expansão); entrada que não é classe fica com pais/membros vazios e
// nunca decide nada.
// Q4 (revisao-generalidade, 2026-07-07): "parents" são VÍNCULOS ESCRITOS
// na linha da declaração - leitura por FORMA, não fato. No hbclass a
// palavra depois do FROM é pai; numa DSL qualquer pode ser argumento
// (probe da revisão, caso 75: a DSL passa um forjador por @ref na linha
// da declaração - a MESMA forma do pai do hbclass). A linguagem não tem
// canal de herança (fato 4: DECLARE não carrega superclasse) - portanto
// resolução que ATRAVESSA um vínculo é indecidível para confirmar/excluir
// (o consumidor gateia com DispatchVia); acerto PRÓPRIO segue decidindo
// (regra do VM, independe de pais)
STATIC FUNCTION ClassGraph( hAsts, hDecl )

   LOCAL hGraph := { => }, hClassMap := ClassFuncMap( hAsts )
   LOCAL cUp, aCF, hMembers, cM

   FOR EACH cUp IN hb_HKeys( hClassMap )
      aCF := hClassMap[ cUp ]
      hMembers := ClassMembersOf( aCF[ 2 ], aCF[ 3 ] )
      IF hb_HHasKey( hDecl[ "c" ], cUp )
         FOR EACH cM IN hb_HKeys( hDecl[ "c" ][ cUp ] )
            hMembers[ cM ] := .T.
         NEXT
      ENDIF
      hGraph[ cUp ] := { "parents" => ClassParentsSeq( aCF[ 2 ], cUp, aCF[ 3 ], hClassMap ), ;
                         "members" => hMembers }
   NEXT

   // classes SÓ do canal declared (B4f-3: DSL declarativa pura -
   // _HB_CLASS/_HB_MEMBER por #xcommand próprio, sem função geradora): a
   // interface declarada é a PROMESSA fechada do autor - o canal não
   // carrega superclasse (fato 4), então pais vazios e membros = declared.
   // Mesma natureza de promessa de todo tipo declarado (caveat no
   // ast-schema)
   FOR EACH cUp IN hb_HKeys( hDecl[ "c" ] )
      IF ! hb_HHasKey( hGraph, cUp )
         hMembers := { => }
         FOR EACH cM IN hb_HKeys( hDecl[ "c" ][ cUp ] )
            hMembers[ cM ] := .T.
         NEXT
         hGraph[ cUp ] := { "parents" => {}, "members" => hMembers }
      ENDIF
   NEXT

   RETURN hGraph

// a classe DONA da implementação que o dispatch de cMsg sobre cUpClass
// alcança NO GRAFO COMO-ESCRITO: própria > vínculos na ordem escrita, em
// profundidade, primeiro hit vence (fatos 1+7 - a regra do VM). Devolve
// "" quando a mensagem não existe na cadeia escrita visível do projeto,
// NIL quando indecidível - classe fora do grafo ou vínculo de FORA do
// projeto encontrado ANTES de um hit. hSeen guarda contra ciclo.
// Q4: dono != cUpClass significa que o alcance ATRAVESSOU vínculo
// escrito (não-provado como pai) - o consumidor É OBRIGADO a gatear com
// DispatchVia antes de confirmar/excluir; só o acerto próprio decide
STATIC FUNCTION ResolveDispatch( cUpClass, cUpMsg, hGraph, hSeen )

   LOCAL hNode, aPar, xOwn

   IF ! hb_HHasKey( hGraph, cUpClass )
      RETURN NIL
   ENDIF
   IF hSeen == NIL
      hSeen := { => }
   ENDIF
   IF hb_HHasKey( hSeen, cUpClass )
      RETURN ""
   ENDIF
   hSeen[ cUpClass ] := .T.
   hNode := hGraph[ cUpClass ]
   IF hb_HHasKey( hNode[ "members" ], cUpMsg )
      RETURN cUpClass
   ENDIF
   FOR EACH aPar IN hNode[ "parents" ]
      IF ! aPar[ 2 ]
         RETURN NIL
      ENDIF
      xOwn := ResolveDispatch( aPar[ 1 ], cUpMsg, hGraph, hSeen )
      IF xOwn == NIL
         RETURN NIL
      ENDIF
      IF Len( xOwn ) > 0
         RETURN xOwn
      ENDIF
   NEXT

   RETURN ""

// o resultado de ResolveDispatch atravessou VÍNCULO ESCRITO? Acerto
// PRÓPRIO devolve a própria classe (regra do VM - fato); dono DIFERENTE
// só se alcança pelos "parents" do grafo, que são leitura POR FORMA da
// linha da declaração (Q4 da revisão de generalidade: numa DSL qualquer o
// identificador escrito ali pode ser argumento, não pai - provado no
// probe da revisão, caso 75). Nenhum consumidor confirma/exclui sobre
// resultado que atravessou vínculo - possible NOMEANDO o candidato
STATIC FUNCTION DispatchVia( cUpClass, xOwn )
   RETURN HB_ISSTRING( xOwn ) .AND. Len( xOwn ) > 0 .AND. !( xOwn == cUpClass )

// a dona registrada de um site de declaração/implementação é CLASSE do
// grafo do projeto com a mensagem PRÓPRIA (fato 5: stringify ∪ declared)?
// É o que autoriza EXCLUIR um site homônimo na consulta Classe:Método -
// dona fora do grafo (DSL sem classe, dump sem declared) nunca exclui
STATIC FUNCTION DeclOwnerProven( hGraph, cUpOwn, cUpMsg )
   RETURN hGraph != NIL .AND. hb_HHasKey( hGraph, cUpOwn ) .AND. ;
      hb_HHasKey( hGraph[ cUpOwn ][ "members" ], cUpMsg )

// descendentes TRANSITIVOS de uma classe no grafo, por arestas DO PROJETO
// (descendência que atravessa pai de fora é invisível - limite honesto,
// coberto pela indecidibilidade do próprio ResolveDispatch nesses ramos)
STATIC FUNCTION ClassDescendants( cUpClass, hGraph )

   LOCAL aOut := {}, hSeen := { cUpClass => .T. }, aQueue := { cUpClass }
   LOCAL cCur, cK, aPar

   DO WHILE ! Empty( aQueue )
      cCur := ATail( aQueue )
      ASize( aQueue, Len( aQueue ) - 1 )
      FOR EACH cK IN hb_HKeys( hGraph )
         IF ! hb_HHasKey( hSeen, cK )
            FOR EACH aPar IN hGraph[ cK ][ "parents" ]
               IF aPar[ 2 ] .AND. aPar[ 1 ] == cCur
                  hSeen[ cK ] := .T.
                  AAdd( aOut, cK )
                  AAdd( aQueue, cK )
                  EXIT
               ENDIF
            NEXT
         ENDIF
      NEXT
   ENDDO

   RETURN aOut

// descendentes do receptor que SEQUESTRARIAM o dispatch para a
// implementação consultada (ou cuja resolução é indecidível - também
// impede exclusão): receptor DECLARADO é promessa e pode carregar
// qualquer um deles em runtime
STATIC FUNCTION DispatchHijackers( cRcls, cUpSym, cUpBase, cOwnerQ, hGraph )

   LOCAL aOut := {}, cD, xOwn

   FOR EACH cD IN ClassDescendants( cRcls, hGraph )
      xOwn := ResolveDispatchMsg( cD, cUpSym, cUpBase, hGraph )
      // Q4: resolução do descendente que atravessa vínculo escrito é
      // não-provada - também impede a exclusão (conservador)
      IF xOwn == NIL .OR. xOwn == cOwnerQ .OR. DispatchVia( cD, xOwn )
         AAdd( aOut, cD )
      ENDIF
   NEXT

   RETURN aOut

// resolução da MENSAGEM EFETIVA de um send: a escrita `o:x := v` envia
// `_X` (fato 11); VAR registra o PAR leitura/escrita em runtime (X e _X,
// provado no probe vprobe) mas o registro por stringify/declared carrega
// só X - quando a forma de escrita não acha dona própria (ASSIGN
// explícito registra _NOME e resolve direto), resolve pelo nome BASE (a
// regra do par de dados da linguagem)
STATIC FUNCTION ResolveDispatchMsg( cUpClass, cUpSym, cUpBase, hGraph )

   LOCAL xOwn := ResolveDispatch( cUpClass, cUpSym, hGraph )

   IF HB_ISSTRING( xOwn ) .AND. Len( xOwn ) == 0 .AND. !( cUpSym == cUpBase )
      xOwn := ResolveDispatch( cUpClass, cUpBase, hGraph )
   ENDIF

   RETURN xOwn

// veredito em camadas de um send para a consulta [Classe:]Método. Camadas
// B4f (canal de tipos) decididas ALÉM quando a B4f-2 resolve: receptor de
// classe conhecida DIFERENTE da consultada, com a implementação consultada
// E o dispatch do receptor resolvíveis no grafo => mesmo dono = confirmed;
// dono diferente com receptor de classe EXATA (cadeia declarada) =
// excluded; com receptor DECLARADO (promessa - pode carregar descendente
// em runtime) a exclusão só vale no MUNDO FECHADO do grafo do projeto
// (rótulo carrega a ressalva) e um descendente que sequestre o dispatch a
// impede (possible nomeando-o). Indecidível => camadas B4f de sempre.
// Devolve { rótulo, fora-do-json? } - excluded fica fora das Location[]
STATIC FUNCTION SendVerdict( hType, cClass, cUpMeth, cUpSym, hGraph, lBlock )

   LOCAL cSuf := iif( lBlock, ", codeblock", "" )
   LOCAL cRcls, cOwnerQ, cOwnerR, aHij, lVia, aSet

   IF hType == NIL
      RETURN { "possible send (dynamic dispatch, receiver unknown" + cSuf + ")", .F. }
   ENDIF
   IF hb_HHasKey( hType, "val" )
      RETURN { "excluded send (receiver holds a value of kind " + ;
               hType[ "val" ] + cSuf + ")", .T. }
   ENDIF
   lVia := hb_HGetDef( hType, "via", .F. )
   // conjunto finito >1 (B7): possible NOMEANDO os candidatos - nunca
   // decide (a regra de consumo da spec)
   IF hb_HHasKey( hType, "clsset" )
      aSet := hb_HKeys( hType[ "clsset" ] )
      ASort( aSet )
      RETURN { "possible send (receiver one of " + B7JoinOr( aSet ) + ;
               iif( lVia, " via construction chain, class graph as written", "" ) + ;
               cSuf + ")", .F. }
   ENDIF
   cRcls := hType[ "cls" ]
   IF Empty( cClass ) .OR. cRcls == cClass
      // D1: tipagem que atravessou vínculo escrito confirma só em mundo
      // fechado - o rótulo carrega a ressalva
      IF lVia
         RETURN { "confirmed send (receiver class " + cRcls + ;
                  " via construction chain, class graph as written" + cSuf + ")", .F. }
      ENDIF
      // B9: anotação em módulo -kt é INVARIANTE imposta em runtime
      // (fail-fast) - camada guaranteed, acima da promessa declarada
      IF hType[ "how" ] == "declared" .AND. hb_HGetDef( hType, "kt", .F. )
         RETURN { "guaranteed send (receiver AS CLASS " + cRcls + ;
                  " imposed by -kt checks" + cSuf + ")", .F. }
      ENDIF
      RETURN { "confirmed send (receiver " + ;
               iif( hType[ "how" ] == "declared", "declared AS CLASS " + cRcls, ;
                    "class " + cRcls + " via declared types" ) + cSuf + ")", .F. }
   ENDIF
   IF hGraph != NIL
      cOwnerQ := ResolveDispatchMsg( cClass, cUpSym, cUpMeth, hGraph )
      cOwnerR := ResolveDispatchMsg( cRcls, cUpSym, cUpMeth, hGraph )
      IF cOwnerQ != NIL .AND. cOwnerR != NIL .AND. ;
         Len( cOwnerQ ) > 0 .AND. Len( cOwnerR ) > 0
         // Q4 (revisao-generalidade): alcance que ATRAVESSA vínculo
         // escrito (leitura por forma da linha de declaração) não é fato
         // de parentesco - nunca confirma nem exclui; camada possible
         // NOMEANDO o candidato e o vínculo não-provado
         IF DispatchVia( cRcls, cOwnerR )
            RETURN { "possible send (receiver class " + cRcls + " may dispatch to " + ;
                     cOwnerR + ":" + cUpMeth + " through written parents, unproven" + ;
                     cSuf + ")", .F. }
         ENDIF
         IF DispatchVia( cClass, cOwnerQ )
            RETURN { "possible send (" + cClass + ":" + cUpMeth + ;
                     " resolves through written parents, unproven; receiver class " + ;
                     cRcls + cSuf + ")", .F. }
         ENDIF
         IF cOwnerR == cOwnerQ
            IF lVia
               RETURN { "confirmed send (receiver class " + cRcls + ;
                        " via construction chain dispatches to " + cOwnerQ + ":" + ;
                        cUpMeth + ", class graph as written" + cSuf + ")", .F. }
            ENDIF
            RETURN { "confirmed send (receiver class " + cRcls + " dispatches to " + ;
                     cOwnerQ + ":" + cUpMeth + cSuf + ")", .F. }
         ENDIF
         IF !( hType[ "how" ] == "declared" )
            // instância EXATA (cadeia declarada): a resolução é absoluta;
            // com travessia (D1) a exclusão vale no mundo fechado do grafo
            // como-escrito - o rótulo nomeia o fato E a ressalva
            IF lVia
               RETURN { "excluded send within the written class graph (receiver class " + ;
                        cRcls + " via construction chain, dispatches to " + ;
                        cOwnerR + ":" + cUpMeth + cSuf + ")", .T. }
            ENDIF
            RETURN { "excluded send (dispatches to " + cOwnerR + ":" + cUpMeth + ;
                     cSuf + ")", .T. }
         ENDIF
         aHij := DispatchHijackers( cRcls, cUpSym, cUpMeth, cOwnerQ, hGraph )
         IF Empty( aHij )
            RETURN { "excluded send within the project's class graph (dispatches to " + ;
                     cOwnerR + ":" + cUpMeth + cSuf + ")", .T. }
         ENDIF
         RETURN { "possible send (descendant " + aHij[ 1 ] + " of " + cRcls + ;
                  " may dispatch to " + cOwnerQ + ":" + cUpMeth + cSuf + ")", .F. }
      ENDIF
   ENDIF

   // classe conhecida != consultada sem resolução NÃO exclui: promessa
   // não verificada + cadeia indecidível (pai fora do projeto, classe
   // desconhecida, runtime)
   RETURN { "possible send (receiver class " + cRcls + ;
            iif( lVia, " via construction chain", "" ) + ", relation to " + cClass + ;
            " unknown" + cSuf + ")", .F. }

STATIC FUNCTION B7JoinOr( aNames )

   LOCAL cOut := "", cN

   FOR EACH cN IN aNames
      cOut += iif( cN:__enumIndex() == 1, "", " or " ) + cN
   NEXT

   RETURN cOut

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

// vocabulário do DONO (revisão Q6): a cabeça (minúscula) da regra cuja
// expansão LIGOU o nome ao canal de classe - o `from` (ast-3) do próprio
// nome, colhido no `_HB_CLASS` do stream e no nome da função-de-classe
// gerada. NÃO é a regra raiz do site: `CREATE CLASS Conta` tem raiz
// CREATE (açúcar sobre açúcar), mas quem declara é a regra CLASS - o
// rótulo diz o que o dono É, não como a linha dele começa. Nome sem
// derivação (canal escrito à mão) fica fora do mapa e o chamador cai para
// "class", o nome do próprio canal da linguagem - nunca palpite
STATIC FUNCTION OwnerVocabMap( hAsts )

   LOCAL hMap := { => }, cPath, hAst, hTok, hFunc, lNext

   FOR EACH cPath IN hb_HKeys( hAsts )
      hAst := hAsts[ cPath ]
      IF ! FromReady( hAst )
         LOOP
      ENDIF
      // fonte 1: canal declared no stream (cobre dona SEM função geradora)
      lNext := .F.
      FOR EACH hTok IN hAst[ "tokens" ]
         IF hTok[ "type" ] == 21
            IF lNext
               OwnerVocabAdd( hMap, hAst, hTok )
            ENDIF
            lNext := Upper( hTok[ "text" ] ) == "_HB_CLASS"
         ELSE
            lNext := .F.
         ENDIF
      NEXT
      // fonte 2: função-de-classe gerada (cobre registro runtime puro,
      // sem canal declared) - mesmo recorte do ClassFuncMap/ClassDeclApps
      FOR EACH hFunc IN hAst[ "functions" ]
         IF ! hFunc[ "fileDecl" ] .AND. Empty( GenNameParts( hAst, hFunc ) ) .AND. ;
            FuncDerived( hAst, hFunc )
            FOR EACH hTok IN hAst[ "tokens" ]
               IF hTok[ "type" ] == 21 .AND. hb_HHasKey( hTok, "from" ) .AND. ;
                  Upper( hTok[ "text" ] ) == Upper( hFunc[ "name" ] ) .AND. ;
                  hTok[ "line" ] == hFunc[ "line" ]
                  OwnerVocabAdd( hMap, hAst, hTok )
               ENDIF
            NEXT
         ENDIF
      NEXT
   NEXT

   RETURN hMap

STATIC PROCEDURE OwnerVocabAdd( hMap, hAst, hTok )

   LOCAL hRule, cUp := Upper( hTok[ "text" ] )

   IF ! hb_HHasKey( hMap, cUp ) .AND. hb_HHasKey( hTok, "from" ) .AND. ;
      ! Empty( hTok[ "from" ] )
      hRule := hAst[ "ppRules" ][ hAst[ "ppApplications" ][ ;
               hTok[ "from" ][ 1 ][ "app" ] + 1 ][ "rule" ] + 1 ]
      IF hRule[ "head" ] != NIL
         hMap[ cUp ] := Lower( hRule[ "head" ] )
      ENDIF
   ENDIF

   RETURN

STATIC FUNCTION OwnerWord( hOwnV, cOwn )
   RETURN iif( hOwnV != NIL .AND. hb_HHasKey( hOwnV, Upper( cOwn ) ), ;
               hOwnV[ Upper( cOwn ) ], "class" )

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
