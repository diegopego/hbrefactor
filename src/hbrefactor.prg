// hbrefactor - automated refactoring tool for Harbour source code
// Phase 0: scope-aware rename of LOCAL variables, project-wide operation.
//
// Foundation (see docs/ in this repo):
//   - occurrence oracle: harbour compiler -x dump (patch in harbour-core
//     branch feature/refactoring-mechanism)
//   - column precision: file-level tokenizer over the original source
//   - verification: harbour -gh -l byte-compare per module (local names
//     do not exist in pcode, so the .hrb must stay byte-identical)

#define APP_VERSION "0.1.0"

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
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "rename-function"
      nExit := RenameFunction( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "reorder-params"
      nExit := ReorderParams( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "extract-function"
      nExit := ExtractFunction( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "usages"
      nExit := Usages( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "rename-static"
      nExit := RenameStatic( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "find-dynamic-calls"
      nExit := FindDynamicCalls( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "unused-locals"
      nExit := UnusedLocals( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "call-graph"
      nExit := CallGraph( aArgs )
   OTHERWISE
      Usage()
      nExit := EXIT_USAGE
   ENDCASE

   ErrorLevel( nExit )

   RETURN

STATIC PROCEDURE Usage()

   OutStd( "hbrefactor " + APP_VERSION + " - Harbour refactoring tool" + hb_eol() )
   OutStd( "Usage:" + hb_eol() )
   OutStd( "  hbrefactor rename-local <project.hbp> <file.prg> <function> <old> <new> [--dry-run] [--json <out>]" + hb_eol() )
   OutStd( "  hbrefactor rename-param <project.hbp> <file.prg> <function> <old> <new> [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor rename-function <project.hbp> <old> <new> [--file <f.prg>] [--force] [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor reorder-params <project.hbp> <function> <name1,name2,...> [--file <f.prg>] [--force] [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor extract-function <project.hbp> <file.prg> <first>-<last> <newname> [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor usages <project.hbp> <name> [--func <function>]" + hb_eol() )
   OutStd( "  hbrefactor rename-static <project.hbp> <file.prg> <old> <new> [--func <function>] [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor find-dynamic-calls <project.hbp>" + hb_eol() )
   OutStd( "  hbrefactor unused-locals <project.hbp>" + hb_eol() )
   OutStd( "  hbrefactor call-graph <project.hbp> [<function>]" + hb_eol() )

   RETURN

// ---------------------------------------------------------------------------
// rename-local
// ---------------------------------------------------------------------------

STATIC FUNCTION RenameLocal( aArgs )

   LOCAL cHbp, cFile, cFunc, cOld, cNew
   LOCAL lDryRun := .F., cJsonOut := ""
   LOCAL hProj, cSrcPath, cTmp, cText, cTextNew
   LOCAL hDump, hFunc, aLines, hScan, aEdits
   LOCAL hPpo, nLine, cClean
   LOCAL aHit, nPos, cOut
   LOCAL nI

   IF Len( aArgs ) < 6
      Usage()
      RETURN EXIT_USAGE
   ENDIF

   cHbp  := aArgs[ 2 ]
   cFile := aArgs[ 3 ]
   cFunc := aArgs[ 4 ]
   cOld  := aArgs[ 5 ]
   cNew  := aArgs[ 6 ]

   FOR nI := 7 TO Len( aArgs )
      DO CASE
      CASE Lower( aArgs[ nI ] ) == "--dry-run"
         lDryRun := .T.
      CASE Lower( aArgs[ nI ] ) == "--json" .AND. nI < Len( aArgs )
         cJsonOut := aArgs[ ++nI ]
      ENDCASE
   NEXT

   // --- basic validation of the new name -----------------------------------
   IF ! IsValidIdent( cNew )
      RETURN Refuse( "new name '" + cNew + "' is not a valid identifier" )
   ENDIF
   IF IsReserved( cNew )
      RETURN Refuse( "new name '" + cNew + "' is a reserved word" )
   ENDIF
   IF Upper( cOld ) == Upper( cNew )
      RETURN Refuse( "old and new names are identical" )
   ENDIF

   // --- project -------------------------------------------------------------
   hProj := LoadProject( cHbp )
   IF hProj == NIL
      RETURN Refuse( "cannot read project file '" + cHbp + "'" )
   ENDIF

   cSrcPath := ProjectMember( hProj, cFile )
   IF cSrcPath == ""
      RETURN Refuse( "'" + cFile + "' is not a source of project '" + cHbp + "'" )
   ENDIF

   // #define / pp-rule head collision with the new name
   IF DefineCollision( hProj, cSrcPath, cNew )
      RETURN Refuse( "new name '" + cNew + "' collides with a preprocessor rule (#define/#command/#translate)" )
   ENDIF

   // --- compile all modules: before-hrb for everyone, dump+ppo for target ---
   cTmp := WorkDir()
   IF ! CompileAll( hProj, cSrcPath, cTmp, "before" )
      RETURN Refuse( "project does not compile - fix build errors first" )
   ENDIF

   // --- oracle --------------------------------------------------------------
   hDump := ReadDump( cTmp + hb_ps() + FNameBase( cSrcPath ) + ".occ.json" )
   IF hDump == NIL
      RETURN Refuse( "occurrence dump not found/invalid (compiler with -x support required)" )
   ENDIF

   hFunc := PickFunc( hDump, cFunc )
   IF hFunc == NIL
      RETURN Refuse( "function '" + cFunc + "' not found in '" + cFile + "'" )
   ENDIF

   aLines := CollectTargetLines( hFunc, cOld, cNew, Lower( aArgs[ 1 ] ) == "rename-param" )
   IF HB_ISSTRING( aLines )          // refusal message
      RETURN Refuse( aLines )
   ENDIF

   // --- tokenize the original source ----------------------------------------
   cText := hb_MemoRead( cSrcPath )
   IF Empty( cText )
      RETURN Refuse( "cannot read source '" + cSrcPath + "'" )
   ENDIF
   hScan := TokenScan( cText, cOld )

   // --- pp-transformation check on every target line ------------------------
   // a line rewritten by the preprocessor is acceptable only when the
   // target identifier passed through the rule untouched (same token count
   // on both sides); the -gh -l byte-compare after the edit remains the
   // final safety net for any subtle rule interaction
   hPpo := PpoMap( cTmp + hb_ps() + FNameBase( cSrcPath ) + ".ppo" )
   aEdits := {}
   FOR EACH nLine IN aLines
      cClean := ""
      IF ! StmtEdits( hScan, hPpo, nLine, cOld, cNew, aEdits, @cClean )
         RETURN Refuse( cClean )
      ENDIF
   NEXT

   IF Empty( aEdits )
      RETURN Refuse( "nothing to rename" )
   ENDIF

   // --- report / dry run -----------------------------------------------------
   OutStd( "rename-local: " + cOld + " -> " + cNew + " in " + cFunc + " (" + cFile + ")" + hb_eol() )
   FOR EACH aHit IN aEdits
      OutStd( "  " + cFile + ":" + hb_ntos( aHit[ 1 ] ) + ":" + hb_ntos( aHit[ 2 ] ) + hb_eol() )
   NEXT

   IF ! Empty( cJsonOut )
      hb_MemoWrit( cJsonOut, WorkspaceEditJson( cSrcPath, aEdits ) )
   ENDIF

   IF lDryRun
      OutStd( "dry run - no changes written" + hb_eol() )
      RETURN EXIT_OK
   ENDIF

   // --- apply (descending offsets so positions stay valid) -------------------
   cTextNew := ApplyEdits( cText, aEdits )
   hb_MemoWrit( cSrcPath, cTextNew )

   // --- verification: every module must recompile to a byte-identical .hrb ---
   IF ! CompileAll( hProj, cSrcPath, cTmp, "after" )
      hb_MemoWrit( cSrcPath, cText )      // rollback
      RETURN Refuse( "project stopped compiling after rename - rolled back" )
   ENDIF
   FOR EACH nPos IN hProj[ "files" ]
      cOut := FNameBase( nPos )
      IF !( hb_MemoRead( cTmp + hb_ps() + cOut + ".before.hrb" ) == ;
            hb_MemoRead( cTmp + hb_ps() + cOut + ".after.hrb" ) )
         hb_MemoWrit( cSrcPath, cText )   // rollback
         RETURN Refuse( "verification FAILED: " + cOut + ".hrb changed - rolled back" )
      ENDIF
   NEXT

   OutStd( "verified: all " + hb_ntos( Len( hProj[ "files" ] ) ) + " module(s) byte-identical (-gh -l)" + hb_eol() )

   RETURN EXIT_OK

// ---------------------------------------------------------------------------
// rename-function: rename FUNCTION/PROCEDURE across the whole project.
// STATIC functions are edited only inside their defining module (they are
// unreachable by name from elsewhere). String literals containing the name
// are never edited automatically: they are listed and require --force to
// proceed (leaving them untouched).
// ---------------------------------------------------------------------------

STATIC FUNCTION RenameFunction( aArgs )

   LOCAL cHbp, cOld, cNew, cOnlyFile := "", lForce := .F., lDryRun := .F., cJsonOut := ""
   LOCAL hProj, cTmp, cPath, hDump, hFunc, hItem
   LOCAL aDefs := {}, hDumps := { => }, hEditLines := { => }, aScope
   LOCAL lStatic, nI, cUpOld, cUpNew
   LOCAL aWarn := {}, hScan, hPpo, aLines, nLine, cClean
   LOCAL hFileEdits := { => }, aEdits, aHit
   LOCAL hOrig := { => }, cText, cWhy, nTotal := 0

   IF Len( aArgs ) < 4
      Usage()
      RETURN EXIT_USAGE
   ENDIF

   cHbp := aArgs[ 2 ]
   cOld := aArgs[ 3 ]
   cNew := aArgs[ 4 ]
   FOR nI := 5 TO Len( aArgs )
      DO CASE
      CASE Lower( aArgs[ nI ] ) == "--force"
         lForce := .T.
      CASE Lower( aArgs[ nI ] ) == "--dry-run"
         lDryRun := .T.
      CASE Lower( aArgs[ nI ] ) == "--file" .AND. nI < Len( aArgs )
         cOnlyFile := aArgs[ ++nI ]
      CASE Lower( aArgs[ nI ] ) == "--json" .AND. nI < Len( aArgs )
         cJsonOut := aArgs[ ++nI ]
      ENDCASE
   NEXT

   IF ! IsValidIdent( cNew )
      RETURN Refuse( "new name '" + cNew + "' is not a valid identifier" )
   ENDIF
   IF IsReserved( cNew )
      RETURN Refuse( "new name '" + cNew + "' is a reserved word" )
   ENDIF
   IF Upper( cOld ) == Upper( cNew )
      RETURN Refuse( "old and new names are identical" )
   ENDIF
   cUpOld := Upper( cOld )
   cUpNew := Upper( cNew )

   hProj := LoadProject( cHbp )
   IF hProj == NIL
      RETURN Refuse( "cannot read project file '" + cHbp + "'" )
   ENDIF

   cTmp := WorkDir()
   IF ! CompileAll( hProj, "", cTmp, "before", .T. )
      RETURN Refuse( "project does not compile - fix build errors first" )
   ENDIF

   // --- aggregate definitions and detect collisions --------------------------
   FOR EACH cPath IN hProj[ "files" ]
      hDump := ReadDump( cTmp + hb_ps() + FNameBase( cPath ) + ".occ.json" )
      IF hDump == NIL
         RETURN Refuse( "missing occurrence dump for '" + cPath + "'" )
      ENDIF
      hDumps[ cPath ] := hDump
      FOR EACH hFunc IN hDump[ "functions" ]
         IF ! hFunc[ "fileDecl" ]
            IF Upper( hFunc[ "name" ] ) == cUpNew
               RETURN Refuse( "'" + cNew + "' is already defined in " + hb_FNameNameExt( cPath ) )
            ENDIF
            IF Upper( hFunc[ "name" ] ) == cUpOld
               AAdd( aDefs, { cPath, hFunc } )
            ENDIF
         ENDIF
         FOR EACH hItem IN hFunc[ "calls" ]
            IF Upper( hItem[ "sym" ] ) == cUpNew
               RETURN Refuse( "'" + cNew + "' is already referenced in " + hb_FNameNameExt( cPath ) + ;
                              " (possibly a runtime/library function)" )
            ENDIF
         NEXT
      NEXT
   NEXT

   IF Empty( aDefs )
      RETURN Refuse( "function '" + cOld + "' is not defined in this project" )
   ENDIF

   IF ! Empty( cOnlyFile )
      FOR nI := Len( aDefs ) TO 1 STEP -1
         IF !( Lower( hb_FNameNameExt( aDefs[ nI ][ 1 ] ) ) == Lower( hb_FNameNameExt( cOnlyFile ) ) )
            hb_ADel( aDefs, nI, .T. )
         ENDIF
      NEXT
      IF Empty( aDefs )
         RETURN Refuse( "no definition of '" + cOld + "' in '" + cOnlyFile + "'" )
      ENDIF
   ENDIF

   IF Len( aDefs ) > 1
      IF aDefs[ 1 ][ 2 ][ "static" ]
         RETURN Refuse( "'" + cOld + "' is STATIC in more than one module - use --file to pick one" )
      ENDIF
      RETURN Refuse( "'" + cOld + "' has more than one public definition - fix the project first" )
   ENDIF
   lStatic := aDefs[ 1 ][ 2 ][ "static" ]

   // STATIC functions are invisible outside their module: edit only there
   aScope := iif( lStatic, { aDefs[ 1 ][ 1 ] }, hProj[ "files" ] )

   FOR EACH cPath IN aScope
      IF DefineCollision( hProj, cPath, cNew )
         RETURN Refuse( "new name '" + cNew + "' collides with a preprocessor rule" )
      ENDIF
   NEXT

   // --- collect edit lines (definition + every compiled call) ---------------
   hEditLines[ aDefs[ 1 ][ 1 ] ] := {}
   AddLine( hEditLines[ aDefs[ 1 ][ 1 ] ], aDefs[ 1 ][ 2 ][ "line" ] )
   FOR EACH cPath IN aScope
      FOR EACH hFunc IN hDumps[ cPath ][ "functions" ]
         FOR EACH hItem IN hFunc[ "calls" ]
            IF Upper( hItem[ "sym" ] ) == cUpOld
               IF ! ( cPath $ hEditLines )
                  hEditLines[ cPath ] := {}
               ENDIF
               AddLine( hEditLines[ cPath ], hItem[ "line" ] )
            ENDIF
         NEXT
      NEXT
   NEXT

   // --- H scan: textual references the compiler cannot vouch for ------------
   FOR EACH cPath IN hProj[ "files" ]
      cText := hb_MemoRead( cPath )
      hScan := TokenScan( cText, cOld )
      // strings are DATA: the tool never edits them (their meaning cannot be
      // verified). It reports them precisely so the human decides:
      // exact match = very likely a call by name (Do(), dispatch tables);
      // substring   = probably a label/message
      FOR EACH aHit IN hScan[ "strexact" ]
         AAdd( aWarn, hb_FNameNameExt( cPath ) + ":" + hb_ntos( aHit[ 1 ] ) + ;
               ": string equals '" + cOld + "' - likely a call by name, review manually" )
      NEXT
      FOR EACH nLine IN hScan[ "strhits" ]
         AAdd( aWarn, hb_FNameNameExt( cPath ) + ":" + hb_ntos( nLine ) + ;
               ": string literal contains '" + cOld + "' (not renamed)" )
      NEXT
      IF "HB_FUNC" $ Upper( cText ) .AND. cUpOld $ Upper( cText )
         IF "HB_FUNC(" + cUpOld $ StrTran( Upper( cText ), " ", "" )
            AAdd( aWarn, hb_FNameNameExt( cPath ) + ": HB_FUNC( " + cUpOld + " ) found in C dump (not renamed)" )
         ENDIF
      ENDIF
      // identifier tokens on lines the oracle did not report (REQUEST,
      // EXTERNAL, homonymous variables...) - flag for human review; a hit
      // belongs to an oracle line when it sits anywhere inside the
      // ;-continued statement that ENDS at that oracle line
      IF hb_AScan( aScope, {| c | c == cPath } ) > 0
         FOR EACH nLine IN hb_HKeys( hScan[ "hits" ] )
            IF ! LineCovered( hScan[ "clean" ], hb_HGetDef( hEditLines, cPath, {} ), nLine )
               AAdd( aWarn, hb_FNameNameExt( cPath ) + ":" + hb_ntos( nLine ) + ;
                     ": identifier '" + cOld + "' outside compiled references (not renamed)" )
            ENDIF
         NEXT
      ENDIF
   NEXT

   IF ! Empty( aWarn )
      FOR EACH cWhy IN aWarn
         OutStd( "warning: " + cWhy + hb_eol() )
      NEXT
      IF ! lForce
         RETURN Refuse( "textual references found (see warnings) - re-run with --force to proceed without touching them" )
      ENDIF
   ENDIF

   // --- build and apply edits -------------------------------------------------
   FOR EACH cPath IN hb_HKeys( hEditLines )
      cText := hb_MemoRead( cPath )
      hScan := TokenScan( cText, cOld )
      hPpo := PpoMap( cTmp + hb_ps() + FNameBase( cPath ) + ".ppo" )
      aLines := ASort( hEditLines[ cPath ] )
      aEdits := {}
      FOR EACH nLine IN aLines
         cClean := ""
         IF ! StmtEdits( hScan, hPpo, nLine, cOld, cNew, aEdits, @cClean )
            RETURN Refuse( hb_FNameNameExt( cPath ) + ": " + cClean )
         ENDIF
      NEXT
      hFileEdits[ cPath ] := aEdits
      hOrig[ cPath ] := cText
      nTotal += Len( aEdits )
   NEXT

   OutStd( "rename-function: " + cOld + " -> " + cNew + iif( lStatic, " (static, single module)", "" ) + hb_eol() )
   FOR EACH cPath IN hb_HKeys( hFileEdits )
      FOR EACH aHit IN hFileEdits[ cPath ]
         OutStd( "  " + hb_FNameNameExt( cPath ) + ":" + hb_ntos( aHit[ 1 ] ) + ":" + hb_ntos( aHit[ 2 ] ) + hb_eol() )
      NEXT
   NEXT

   IF ! Empty( cJsonOut )
      hb_MemoWrit( cJsonOut, WorkspaceEditJsonMulti( hFileEdits ) )
   ENDIF
   IF lDryRun
      OutStd( "dry run - no changes written" + hb_eol() )
      RETURN EXIT_OK
   ENDIF

   FOR EACH cPath IN hb_HKeys( hFileEdits )
      hb_MemoWrit( cPath, ApplyEdits( hOrig[ cPath ], hFileEdits[ cPath ] ) )
   NEXT

   // --- verification -----------------------------------------------------------
   IF ! CompileAll( hProj, "", cTmp, "after" )
      RollbackAll( hOrig )
      RETURN Refuse( "project stopped compiling after rename - rolled back" )
   ENDIF
   FOR EACH cPath IN hProj[ "files" ]
      cWhy := ""
      IF cPath $ hFileEdits
         IF ! HrbEquivalent( hb_MemoRead( cTmp + hb_ps() + FNameBase( cPath ) + ".before.hrb" ), ;
                             hb_MemoRead( cTmp + hb_ps() + FNameBase( cPath ) + ".after.hrb" ), ;
                             cUpOld, cUpNew, @cWhy )
            RollbackAll( hOrig )
            RETURN Refuse( "verification FAILED for " + hb_FNameNameExt( cPath ) + ": " + cWhy + " - rolled back" )
         ENDIF
      ELSEIF !( hb_MemoRead( cTmp + hb_ps() + FNameBase( cPath ) + ".before.hrb" ) == ;
                hb_MemoRead( cTmp + hb_ps() + FNameBase( cPath ) + ".after.hrb" ) )
         RollbackAll( hOrig )
         RETURN Refuse( "verification FAILED: untouched module " + hb_FNameNameExt( cPath ) + " changed - rolled back" )
      ENDIF
   NEXT

   OutStd( "verified: " + hb_ntos( nTotal ) + " edit(s); symbol tables renamed as expected, pcode byte-identical" + hb_eol() )

   RETURN EXIT_OK

// ---------------------------------------------------------------------------
// reorder-params: change the declared parameter order of a function and
// permute the arguments of every compiled call site accordingly (semantics
// preserved). Call sites whose argument count differs from the parameter
// count are listed and the operation is refused (implicit NIL would move).
// ---------------------------------------------------------------------------

STATIC FUNCTION ReorderParams( aArgs )

   LOCAL cHbp, cFunc, cOrder, cOnlyFile := "", lForce := .F., lDryRun := .F., cJsonOut := ""
   LOCAL hProj, cTmp, cPath, hDump, hFunc, hItem
   LOCAL aDefs := {}, hDumps := { => }, aScope, lStatic
   LOCAL aParams := {}, aNew, aPerm := {}, lIdentity
   LOCAL hSites := { => }, aBad := {}, aWarn := {}
   LOCAL nI, nJ, cUpFunc, hScan, hPpo, cText, aSrc
   LOCAL hFileEdits := { => }, hOrig := { => }, aEdits, aHits, aHit, hSpan
   LOCAL nLine, cClean, cPpoLine, cWhy, nTotal := 0

   IF Len( aArgs ) < 4
      Usage()
      RETURN EXIT_USAGE
   ENDIF
   cHbp   := aArgs[ 2 ]
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
      CASE Lower( aArgs[ nI ] ) == "--json" .AND. nI < Len( aArgs )
         cJsonOut := aArgs[ ++nI ]
      ENDCASE
   NEXT
   cUpFunc := Upper( cFunc )

   hProj := LoadProject( cHbp )
   IF hProj == NIL
      RETURN Refuse( "cannot read project file '" + cHbp + "'" )
   ENDIF
   cTmp := WorkDir()
   IF ! CompileAll( hProj, "", cTmp, "before", .T. )
      RETURN Refuse( "project does not compile - fix build errors first" )
   ENDIF

   FOR EACH cPath IN hProj[ "files" ]
      hDump := ReadDump( cTmp + hb_ps() + FNameBase( cPath ) + ".occ.json" )
      IF hDump == NIL
         RETURN Refuse( "missing occurrence dump for '" + cPath + "'" )
      ENDIF
      hDumps[ cPath ] := hDump
      FOR EACH hFunc IN hDump[ "functions" ]
         IF ! hFunc[ "fileDecl" ] .AND. Upper( hFunc[ "name" ] ) == cUpFunc
            AAdd( aDefs, { cPath, hFunc } )
         ENDIF
      NEXT
   NEXT
   IF Empty( aDefs )
      RETURN Refuse( "function '" + cFunc + "' is not defined in this project" )
   ENDIF
   IF ! Empty( cOnlyFile )
      FOR nI := Len( aDefs ) TO 1 STEP -1
         IF !( Lower( hb_FNameNameExt( aDefs[ nI ][ 1 ] ) ) == Lower( hb_FNameNameExt( cOnlyFile ) ) )
            hb_ADel( aDefs, nI, .T. )
         ENDIF
      NEXT
   ENDIF
   IF Len( aDefs ) != 1
      RETURN Refuse( "ambiguous or missing definition of '" + cFunc + "' - use --file" )
   ENDIF
   lStatic := aDefs[ 1 ][ 2 ][ "static" ]
   aScope := iif( lStatic, { aDefs[ 1 ][ 1 ] }, hProj[ "files" ] )

   // declared parameters, in order
   FOR EACH hItem IN aDefs[ 1 ][ 2 ][ "declarations" ]
      IF hItem[ "param" ]
         AAdd( aParams, hItem[ "sym" ] )
      ENDIF
   NEXT
   IF Empty( aParams )
      RETURN Refuse( "'" + cFunc + "' has no ()-declared parameters" )
   ENDIF

   aNew := hb_ATokens( cOrder, "," )
   FOR nI := 1 TO Len( aNew )
      aNew[ nI ] := AllTrim( aNew[ nI ] )
   NEXT
   IF Len( aNew ) != Len( aParams )
      RETURN Refuse( "new order must list all " + hb_ntos( Len( aParams ) ) + " parameter(s)" )
   ENDIF
   lIdentity := .T.
   FOR nI := 1 TO Len( aNew )
      nJ := 0
      FOR EACH cWhy IN aParams          // reuse cWhy as scratch iterator
         IF Upper( cWhy ) == Upper( aNew[ nI ] )
            nJ := cWhy:__enumIndex()
            EXIT
         ENDIF
      NEXT
      IF nJ == 0 .OR. hb_AScan( aPerm, nJ ) > 0
         RETURN Refuse( "new order must be a permutation of: " + ArrJoin( aParams, ", " ) )
      ENDIF
      AAdd( aPerm, nJ )
      IF nJ != nI
         lIdentity := .F.
      ENDIF
   NEXT
   IF lIdentity
      RETURN Refuse( "new order is identical to the current one" )
   ENDIF

   // sites: definition line + every compiled call line inside the scope
   hSites[ aDefs[ 1 ][ 1 ] ] := {}
   AddLine( hSites[ aDefs[ 1 ][ 1 ] ], aDefs[ 1 ][ 2 ][ "line" ] )
   FOR EACH cPath IN aScope
      FOR EACH hFunc IN hDumps[ cPath ][ "functions" ]
         FOR EACH hItem IN hFunc[ "calls" ]
            IF Upper( hItem[ "sym" ] ) == cUpFunc
               IF ! ( cPath $ hSites )
                  hSites[ cPath ] := {}
               ENDIF
               AddLine( hSites[ cPath ], hItem[ "line" ] )
            ENDIF
         NEXT
      NEXT
   NEXT

   // textual references (strings) - never edited; require --force
   FOR EACH cPath IN hProj[ "files" ]
      hScan := TokenScan( hb_MemoRead( cPath ), cFunc )
      FOR EACH nLine IN hScan[ "strhits" ]
         AAdd( aWarn, hb_FNameNameExt( cPath ) + ":" + hb_ntos( nLine ) + ;
               ": string literal contains '" + cFunc + "' (arguments there cannot be reordered)" )
      NEXT
   NEXT
   IF ! Empty( aWarn )
      FOR EACH cWhy IN aWarn
         OutStd( "warning: " + cWhy + hb_eol() )
      NEXT
      IF ! lForce
         RETURN Refuse( "textual references found - re-run with --force to proceed without touching them" )
      ENDIF
   ENDIF

   // build edits per site
   FOR EACH cPath IN hb_HKeys( hSites )
      cText := hb_MemoRead( cPath )
      aSrc := hb_ATokens( StrTran( cText, Chr( 13 ), "" ), Chr( 10 ) )
      hScan := TokenScan( cText, cFunc )
      hPpo := PpoMap( cTmp + hb_ps() + FNameBase( cPath ) + ".ppo" )
      aEdits := {}
      FOR EACH nLine IN ASort( hSites[ cPath ] )
         cClean := Squeeze( hb_HGetDef( hScan[ "clean" ], nLine, "" ) )
         cPpoLine := Squeeze( hb_HGetDef( hPpo, nLine, "" ) )
         IF !( cClean == cPpoLine ) .AND. ;
            CountIdent( cPpoLine, cFunc ) != Len( hb_HGetDef( hScan[ "hits" ], nLine, {} ) )
            RETURN Refuse( hb_FNameNameExt( cPath ) + ":" + hb_ntos( nLine ) + ;
                           " is rewritten by the preprocessor - refusing" )
         ENDIF
         aHits := hb_HGetDef( hScan[ "hits" ], nLine, {} )
         IF Empty( aHits )
            RETURN Refuse( hb_FNameNameExt( cPath ) + ":" + hb_ntos( nLine ) + ;
                           ": no matching token found" )
         ENDIF
         FOR EACH aHit IN aHits
            hSpan := ParseParenSpan( aSrc[ nLine ], aHit[ 1 ] + aHit[ 2 ] )
            IF hSpan == NIL
               AAdd( aBad, hb_FNameNameExt( cPath ) + ":" + hb_ntos( nLine ) + ;
                     ": cannot parse argument list (multi-line call?)" )
               LOOP
            ENDIF
            // definition line keeps the parameter names; call sites carry args
            IF Len( hSpan[ "pieces" ] ) != Len( aParams )
               AAdd( aBad, hb_FNameNameExt( cPath ) + ":" + hb_ntos( nLine ) + ;
                     ": " + hb_ntos( Len( hSpan[ "pieces" ] ) ) + " argument(s) for " + ;
                     hb_ntos( Len( aParams ) ) + " parameter(s) - implicit NIL would move" )
               LOOP
            ENDIF
            AAdd( aEdits, { nLine, hSpan[ "start" ], hSpan[ "len" ], ;
                            ReorderPieces( hSpan[ "pieces" ], aPerm ) } )
         NEXT
      NEXT
      IF ! Empty( aEdits )
         hFileEdits[ cPath ] := aEdits
         hOrig[ cPath ] := cText
         nTotal += Len( aEdits )
      ENDIF
   NEXT

   IF ! Empty( aBad )
      FOR EACH cWhy IN aBad
         OutErr( "blocked: " + cWhy + hb_eol() )
      NEXT
      RETURN Refuse( "call sites incompatible with reorder (fix them first)" )
   ENDIF

   OutStd( "reorder-params: " + cFunc + "( " + ArrJoin( aParams, ", " ) + " ) -> ( " + ;
           ArrJoin( aNew, ", " ) + " )" + hb_eol() )
   FOR EACH cPath IN hb_HKeys( hFileEdits )
      FOR EACH aHit IN hFileEdits[ cPath ]
         OutStd( "  " + hb_FNameNameExt( cPath ) + ":" + hb_ntos( aHit[ 1 ] ) + hb_eol() )
      NEXT
   NEXT
   IF ! Empty( cJsonOut )
      hb_MemoWrit( cJsonOut, WorkspaceEditJsonMulti( hFileEdits ) )
   ENDIF
   IF lDryRun
      OutStd( "dry run - no changes written" + hb_eol() )
      RETURN EXIT_OK
   ENDIF

   FOR EACH cPath IN hb_HKeys( hFileEdits )
      hb_MemoWrit( cPath, ApplyEdits( hOrig[ cPath ], hFileEdits[ cPath ] ) )
   NEXT

   // verification: everything must recompile; symbol tables and function
   // sets must be unchanged; pcode of edited modules legitimately changes
   // (push order), so behavior equality is delegated to the project's tests
   IF ! CompileAll( hProj, "", cTmp, "after" )
      RollbackAll( hOrig )
      RETURN Refuse( "project stopped compiling after reorder - rolled back" )
   ENDIF
   FOR EACH cPath IN hProj[ "files" ]
      cWhy := ""
      IF cPath $ hFileEdits
         IF ! HrbSymbolsEqual( hb_MemoRead( cTmp + hb_ps() + FNameBase( cPath ) + ".before.hrb" ), ;
                               hb_MemoRead( cTmp + hb_ps() + FNameBase( cPath ) + ".after.hrb" ), @cWhy )
            RollbackAll( hOrig )
            RETURN Refuse( "verification FAILED for " + hb_FNameNameExt( cPath ) + ": " + cWhy + " - rolled back" )
         ENDIF
      ELSEIF !( hb_MemoRead( cTmp + hb_ps() + FNameBase( cPath ) + ".before.hrb" ) == ;
                hb_MemoRead( cTmp + hb_ps() + FNameBase( cPath ) + ".after.hrb" ) )
         RollbackAll( hOrig )
         RETURN Refuse( "verification FAILED: untouched module " + hb_FNameNameExt( cPath ) + " changed - rolled back" )
      ENDIF
   NEXT

   OutStd( "verified: " + hb_ntos( nTotal ) + " site(s) reordered; symbols unchanged; run your test suite to confirm behavior" + hb_eol() )

   RETURN EXIT_OK

// parse "( arg1, arg2, ... )" starting right after the function name token;
// returns start column and length of the inside text plus the top-level
// pieces, or NIL when there is no balanced list on this line
STATIC FUNCTION ParseParenSpan( cLine, nCol )

   LOCAL nLen := Len( cLine ), nDepth, nStart
   LOCAL aPieces := {}, nPieceStart, cCh, cQuote := ""

   DO WHILE nCol <= nLen .AND. SubStr( cLine, nCol, 1 ) == " "
      nCol++
   ENDDO
   IF nCol > nLen .OR. !( SubStr( cLine, nCol, 1 ) == "(" )
      RETURN NIL
   ENDIF
   nStart := nCol + 1
   nPieceStart := nStart
   nDepth := 1
   nCol++
   DO WHILE nCol <= nLen
      cCh := SubStr( cLine, nCol, 1 )
      IF ! Empty( cQuote )
         IF cCh == cQuote
            cQuote := ""
         ENDIF
      ELSEIF cCh == '"' .OR. cCh == "'"
         cQuote := cCh
      ELSEIF cCh $ "([{"
         nDepth++
      ELSEIF cCh $ ")]}"
         nDepth--
         IF nDepth == 0
            IF nCol > nStart .OR. ! Empty( AllTrim( SubStr( cLine, nStart, nCol - nStart ) ) )
               AAdd( aPieces, AllTrim( SubStr( cLine, nPieceStart, nCol - nPieceStart ) ) )
            ENDIF
            IF Len( aPieces ) == 1 .AND. Empty( aPieces[ 1 ] )
               aPieces := {}
            ENDIF
            RETURN { "start" => nStart, "len" => nCol - nStart, "pieces" => aPieces }
         ENDIF
      ELSEIF cCh == "," .AND. nDepth == 1
         AAdd( aPieces, AllTrim( SubStr( cLine, nPieceStart, nCol - nPieceStart ) ) )
         nPieceStart := nCol + 1
      ENDIF
      nCol++
   ENDDO

   RETURN NIL          // unbalanced: call continues on the next line

STATIC FUNCTION ReorderPieces( aPieces, aPerm )

   LOCAL cOut := "", nI

   FOR nI := 1 TO Len( aPerm )
      cOut += iif( nI == 1, " ", ", " ) + aPieces[ aPerm[ nI ] ]
   NEXT

   RETURN cOut + " "

STATIC FUNCTION ArrJoin( aArr, cSep )

   LOCAL cOut := "", cItem

   FOR EACH cItem IN aArr
      cOut += iif( cItem:__enumIsFirst(), "", cSep ) + cItem
   NEXT

   RETURN cOut

// structural check for transformations that must keep the symbol table and
// the function set intact while pcode legitimately changes
STATIC FUNCTION HrbSymbolsEqual( cBefore, cAfter, cWhy )

   LOCAL hB := HrbParse( cBefore ), hA := HrbParse( cAfter )
   LOCAL nI

   IF hB == NIL .OR. hA == NIL
      cWhy := "cannot parse .hrb"
      RETURN .F.
   ENDIF
   IF Len( hB[ "syms" ] ) != Len( hA[ "syms" ] ) .OR. Len( hB[ "funcs" ] ) != Len( hA[ "funcs" ] )
      cWhy := "symbol/function count changed"
      RETURN .F.
   ENDIF
   FOR nI := 1 TO Len( hB[ "syms" ] )
      IF !( hA[ "syms" ][ nI ][ 1 ] == hB[ "syms" ][ nI ][ 1 ] ) .OR. ;
         hA[ "syms" ][ nI ][ 2 ] != hB[ "syms" ][ nI ][ 2 ]
         cWhy := "symbol table changed (" + hA[ "syms" ][ nI ][ 1 ] + ")"
         RETURN .F.
      ENDIF
   NEXT
   FOR nI := 1 TO Len( hB[ "funcs" ] )
      IF !( hA[ "funcs" ][ nI ][ 1 ] == hB[ "funcs" ][ nI ][ 1 ] )
         cWhy := "function set changed (" + hA[ "funcs" ][ nI ][ 1 ] + ")"
         RETURN .F.
      ENDIF
   NEXT

   RETURN .T.

STATIC PROCEDURE RollbackAll( hOrig )

   LOCAL cPath

   FOR EACH cPath IN hb_HKeys( hOrig )
      hb_MemoWrit( cPath, hOrig[ cPath ] )
   NEXT

   RETURN

// ---------------------------------------------------------------------------
// minimal HRB reader (format: src/vm/runner.c) and structural comparison:
// after a function rename the symbol tables must differ ONLY in the renamed
// entries and every pcode stream must stay byte-identical
// ---------------------------------------------------------------------------

STATIC FUNCTION HrbParse( cBody )

   LOCAL hHrb := { "syms" => {}, "funcs" => {} }
   LOCAL nAt, nCount, nI, nZero, cName, nSize

   IF !( hb_BLeft( cBody, 4 ) == Chr( 0xC0 ) + "HRB" )
      RETURN NIL
   ENDIF
   nAt := 7                                   // signature (4) + version (2), 1-based
   nCount := Bin2L( hb_BSubStr( cBody, nAt, 4 ) )
   nAt += 4
   FOR nI := 1 TO nCount
      nZero := hb_BAt( Chr( 0 ), cBody, nAt )
      cName := hb_BSubStr( cBody, nAt, nZero - nAt )
      AAdd( hHrb[ "syms" ], { cName, hb_BPeek( cBody, nZero + 1 ), hb_BPeek( cBody, nZero + 2 ) } )
      nAt := nZero + 3
   NEXT
   nCount := Bin2L( hb_BSubStr( cBody, nAt, 4 ) )
   nAt += 4
   FOR nI := 1 TO nCount
      nZero := hb_BAt( Chr( 0 ), cBody, nAt )
      cName := hb_BSubStr( cBody, nAt, nZero - nAt )
      nAt := nZero + 1
      nSize := Bin2L( hb_BSubStr( cBody, nAt, 4 ) )
      nAt += 4
      AAdd( hHrb[ "funcs" ], { cName, hb_BSubStr( cBody, nAt, nSize ) } )
      nAt += nSize
   NEXT

   RETURN hHrb

STATIC FUNCTION HrbEquivalent( cBefore, cAfter, cUpOld, cUpNew, cWhy )

   LOCAL hB := HrbParse( cBefore ), hA := HrbParse( cAfter )
   LOCAL nI, cExpect

   IF hB == NIL .OR. hA == NIL
      cWhy := "cannot parse .hrb"
      RETURN .F.
   ENDIF
   IF Len( hB[ "syms" ] ) != Len( hA[ "syms" ] ) .OR. Len( hB[ "funcs" ] ) != Len( hA[ "funcs" ] )
      cWhy := "symbol/function count changed"
      RETURN .F.
   ENDIF
   FOR nI := 1 TO Len( hB[ "syms" ] )
      cExpect := iif( hB[ "syms" ][ nI ][ 1 ] == cUpOld, cUpNew, hB[ "syms" ][ nI ][ 1 ] )
      IF !( hA[ "syms" ][ nI ][ 1 ] == cExpect ) .OR. ;
         hA[ "syms" ][ nI ][ 2 ] != hB[ "syms" ][ nI ][ 2 ] .OR. ;
         hA[ "syms" ][ nI ][ 3 ] != hB[ "syms" ][ nI ][ 3 ]
         cWhy := "unexpected symbol change at #" + hb_ntos( nI ) + " (" + hA[ "syms" ][ nI ][ 1 ] + ")"
         RETURN .F.
      ENDIF
   NEXT
   FOR nI := 1 TO Len( hB[ "funcs" ] )
      cExpect := iif( hB[ "funcs" ][ nI ][ 1 ] == cUpOld, cUpNew, hB[ "funcs" ][ nI ][ 1 ] )
      IF !( hA[ "funcs" ][ nI ][ 1 ] == cExpect )
         cWhy := "unexpected function name change (" + hA[ "funcs" ][ nI ][ 1 ] + ")"
         RETURN .F.
      ENDIF
      IF !( hA[ "funcs" ][ nI ][ 2 ] == hB[ "funcs" ][ nI ][ 2 ] )
         cWhy := "pcode changed in function " + hA[ "funcs" ][ nI ][ 1 ]
         RETURN .F.
      ENDIF
   NEXT

   RETURN .T.

STATIC FUNCTION WorkspaceEditJsonMulti( hFileEdits )

   LOCAL hEdit := { "changes" => { => } }
   LOCAL cPath, aChanges, aE

   FOR EACH cPath IN hb_HKeys( hFileEdits )
      aChanges := {}
      FOR EACH aE IN hFileEdits[ cPath ]
         AAdd( aChanges, { ;
            "range" => { ;
               "start" => { "line" => aE[ 1 ] - 1, "character" => aE[ 2 ] - 1 }, ;
               "end"   => { "line" => aE[ 1 ] - 1, "character" => aE[ 2 ] - 1 + aE[ 3 ] } }, ;
            "newText" => aE[ 4 ] } )
      NEXT
      hEdit[ "changes" ][ "file://" + cPath ] := aChanges
   NEXT

   RETURN hb_jsonEncode( hEdit, .T. )

// ---------------------------------------------------------------------------
// extract-function: move a range of complete statements into a new STATIC
// function/procedure. Data flow comes from the -x dump (per-line accesses);
// structure balance is checked on the .ppo text (what the compiler really
// sees, immune to #command expansions); everything ambiguous is refused.
// ---------------------------------------------------------------------------

STATIC FUNCTION ExtractFunction( aArgs )

   LOCAL cHbp, cFile, cRange, cNewName, lDryRun := .F.
   LOCAL hProj, cTmp, cSrcPath, cPath, hDump, hDumps := { => }, hFunc, hItem
   LOCAL nFirst, nLast, nI, nFuncEnd, hTarget := NIL
   LOCAL hPpo, cText, aSrc, cMsg, hScanAmp
   LOCAL aVars := {}, hVar, cOut := "", lOutParam := .F., aParams := {}, aFuncs
   LOCAL cEol, cIndent, cCall, cNewFunc, cTextNew, cWhy

   IF Len( aArgs ) < 5
      Usage()
      RETURN EXIT_USAGE
   ENDIF
   cHbp     := aArgs[ 2 ]
   cFile    := aArgs[ 3 ]
   cRange   := aArgs[ 4 ]
   cNewName := aArgs[ 5 ]
   FOR nI := 6 TO Len( aArgs )
      IF Lower( aArgs[ nI ] ) == "--dry-run"
         lDryRun := .T.
      ENDIF
   NEXT

   nI := At( "-", cRange )
   IF nI == 0
      RETURN Refuse( "range must be <first>-<last> (source line numbers)" )
   ENDIF
   nFirst := Val( Left( cRange, nI - 1 ) )
   nLast  := Val( SubStr( cRange, nI + 1 ) )
   IF nFirst <= 0 .OR. nLast < nFirst
      RETURN Refuse( "invalid line range" )
   ENDIF

   IF ! IsValidIdent( cNewName )
      RETURN Refuse( "new name '" + cNewName + "' is not a valid identifier" )
   ENDIF
   IF IsReserved( cNewName )
      RETURN Refuse( "new name '" + cNewName + "' is a reserved word" )
   ENDIF

   hProj := LoadProject( cHbp )
   IF hProj == NIL
      RETURN Refuse( "cannot read project file '" + cHbp + "'" )
   ENDIF
   cSrcPath := ProjectMember( hProj, cFile )
   IF cSrcPath == ""
      RETURN Refuse( "'" + cFile + "' is not a source of project '" + cHbp + "'" )
   ENDIF
   IF DefineCollision( hProj, cSrcPath, cNewName )
      RETURN Refuse( "new name '" + cNewName + "' collides with a preprocessor rule" )
   ENDIF

   cTmp := WorkDir()
   IF ! CompileAll( hProj, "", cTmp, "before", .T. )
      RETURN Refuse( "project does not compile - fix build errors first" )
   ENDIF

   // new name must not clash with anything defined or referenced anywhere
   FOR EACH cPath IN hProj[ "files" ]
      hDump := ReadDump( cTmp + hb_ps() + FNameBase( cPath ) + ".occ.json" )
      IF hDump == NIL
         RETURN Refuse( "missing occurrence dump for '" + cPath + "'" )
      ENDIF
      hDumps[ cPath ] := hDump
      FOR EACH hFunc IN hDump[ "functions" ]
         IF ! hFunc[ "fileDecl" ] .AND. Upper( hFunc[ "name" ] ) == Upper( cNewName )
            RETURN Refuse( "'" + cNewName + "' is already defined in " + hb_FNameNameExt( cPath ) )
         ENDIF
         FOR EACH hItem IN hFunc[ "calls" ]
            IF Upper( hItem[ "sym" ] ) == Upper( cNewName )
               RETURN Refuse( "'" + cNewName + "' is already referenced in " + hb_FNameNameExt( cPath ) )
            ENDIF
         NEXT
      NEXT
   NEXT

   // --- locate the enclosing function and its line range --------------------
   aFuncs := {}
   FOR EACH hFunc IN hDumps[ cSrcPath ][ "functions" ]
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
      RETURN Refuse( "line range is not fully inside a single function" )
   ENDIF
   IF hTarget[ "usesMacro" ]
      // conservative: macro anywhere in the function makes moved semantics
      // unprovable (macro may read memvars created around the selection)
      OutStd( "warning: function uses & macros - review carefully" + hb_eol() )
   ENDIF

   cText := hb_MemoRead( cSrcPath )
   aSrc := hb_ATokens( StrTran( cText, Chr( 13 ), "" ), Chr( 10 ) )
   IF nLast > Len( aSrc )
      RETURN Refuse( "range beyond end of file" )
   ENDIF

   // macro operator inside the selection text: refuse (cannot be proven)
   hScanAmp := TokenScan( cText, "hbrf_dummy" )
   FOR nI := nFirst TO nLast
      IF "&" $ hb_HGetDef( hScanAmp[ "clean" ], nI, "" )
         RETURN Refuse( "line " + hb_ntos( nI ) + " uses a macro (&) - refusing" )
      ENDIF
   NEXT

   // selection must not cut a ';'-continued statement
   hPpo := PpoMap( cTmp + hb_ps() + FNameBase( cSrcPath ) + ".ppo" )
   IF Empty( AllTrim( hb_HGetDef( hPpo, nFirst, "" ) ) ) .AND. ;
      ! Empty( AllTrim( hb_HGetDef( hScanAmp[ "clean" ], nFirst, "" ) ) )
      RETURN Refuse( "selection starts in the middle of a continued statement" )
   ENDIF
   IF Right( RTrim( hb_HGetDef( hScanAmp[ "clean" ], nLast, "" ) ), 1 ) == ";"
      RETURN Refuse( "selection ends in the middle of a continued statement" )
   ENDIF

   // --- structure balance on the preprocessed text ---------------------------
   cMsg := StructureCheck( hPpo, nFirst, nLast )
   IF ! Empty( cMsg )
      RETURN Refuse( cMsg )
   ENDIF

   // --- variable data flow from the oracle -----------------------------------
   FOR EACH hItem IN hTarget[ "declarations" ]
      IF !( hItem[ "scope" ] == "local" )
         LOOP
      ENDIF
      hVar := { "sym" => hItem[ "sym" ], "declLine" => hItem[ "declLine" ], ;
                "declIn" => ( hItem[ "declLine" ] >= nFirst .AND. hItem[ "declLine" ] <= nLast ), ;
                "in" => {}, "after" => .F., "firstIn" => "" }
      FOR EACH hFunc IN hTarget[ "occurrences" ]     // reuse hFunc as iterator
         IF Upper( hFunc[ "sym" ] ) == Upper( hItem[ "sym" ] )
            DO CASE
            CASE hFunc[ "line" ] >= nFirst .AND. hFunc[ "line" ] <= nLast
               AAdd( hVar[ "in" ], hFunc )
               IF Empty( hVar[ "firstIn" ] )
                  hVar[ "firstIn" ] := hFunc[ "access" ]
               ENDIF
            CASE hFunc[ "line" ] > nLast .AND. hFunc[ "line" ] <= nFuncEnd
               hVar[ "after" ] := .T.
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
            RETURN Refuse( "'" + hVar[ "sym" ] + "' is declared inside the selection but used after it" )
         ENDIF
         LOOP                                    // moves together with the code
      ENDIF
      cWhy := Spelling( cText, aSrc, hVar[ "sym" ], hVar[ "declLine" ] )   // original casing
      IF VarWrittenIn( hVar ) .AND. hVar[ "after" ]
         IF ! Empty( cOut )
            RETURN Refuse( "more than one variable modified and used after the selection ('" + ;
                           cOut + "' and '" + cWhy + "') - refusing" )
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

   // --- assemble ---------------------------------------------------------------
   cEol := iif( Chr( 13 ) + Chr( 10 ) $ cText, Chr( 13 ) + Chr( 10 ), Chr( 10 ) )
   cIndent := Space( Len( aSrc[ nFirst ] ) - Len( LTrim( aSrc[ nFirst ] ) ) )
   cCall := cIndent + iif( Empty( cOut ), "", cOut + " := " ) + cNewName + ;
            "( " + ArrJoin( aParams, ", " ) + " )"
   IF Empty( aParams )
      cCall := cIndent + iif( Empty( cOut ), "", cOut + " := " ) + cNewName + "()"
   ENDIF

   cNewFunc := cEol + iif( Empty( cOut ), "STATIC PROCEDURE ", "STATIC FUNCTION " ) + ;
               cNewName + "( " + ArrJoin( aParams, ", " ) + " )" + cEol + cEol
   IF Empty( aParams )
      cNewFunc := cEol + iif( Empty( cOut ), "STATIC PROCEDURE ", "STATIC FUNCTION " ) + ;
                  cNewName + "()" + cEol + cEol
   ENDIF
   IF ! Empty( cOut ) .AND. ! lOutParam
      cNewFunc += "   LOCAL " + cOut + cEol + cEol
   ENDIF
   FOR nI := nFirst TO nLast
      cNewFunc += aSrc[ nI ] + cEol
   NEXT
   cNewFunc += cEol + "   RETURN" + iif( Empty( cOut ), "", " " + cOut ) + cEol

   OutStd( "extract-function: lines " + hb_ntos( nFirst ) + "-" + hb_ntos( nLast ) + ;
           " of " + hTarget[ "name" ] + " -> " + cNewName + ;
           "( " + ArrJoin( aParams, ", " ) + " )" + ;
           iif( Empty( cOut ), "", " returning " + cOut ) + hb_eol() )
   IF lDryRun
      OutStd( "dry run - no changes written" + hb_eol() )
      RETURN EXIT_OK
   ENDIF

   cTextNew := ReplaceLines( cText, nFirst, nLast, cCall, cEol ) + cNewFunc
   hb_MemoWrit( cSrcPath, cTextNew )

   // --- verification ------------------------------------------------------------
   IF ! CompileAll( hProj, "", cTmp, "after" )
      hb_MemoWrit( cSrcPath, cText )
      RETURN Refuse( "project stopped compiling after extraction - rolled back" )
   ENDIF
   FOR EACH cPath IN hProj[ "files" ]
      cWhy := ""
      IF cPath == cSrcPath
         IF ! HrbExtractCheck( hb_MemoRead( cTmp + hb_ps() + FNameBase( cPath ) + ".before.hrb" ), ;
                               hb_MemoRead( cTmp + hb_ps() + FNameBase( cPath ) + ".after.hrb" ), ;
                               Upper( cNewName ), @cWhy )
            hb_MemoWrit( cSrcPath, cText )
            RETURN Refuse( "verification FAILED: " + cWhy + " - rolled back" )
         ENDIF
      ELSEIF !( hb_MemoRead( cTmp + hb_ps() + FNameBase( cPath ) + ".before.hrb" ) == ;
                hb_MemoRead( cTmp + hb_ps() + FNameBase( cPath ) + ".after.hrb" ) )
         hb_MemoWrit( cSrcPath, cText )
         RETURN Refuse( "verification FAILED: untouched module changed - rolled back" )
      ENDIF
   NEXT

   OutStd( "verified: symbols preserved (+" + cNewName + "); run your test suite to confirm behavior" + hb_eol() )

   RETURN EXIT_OK

// original spelling of a symbol (the dump uppercases it): take the token
// as written on its declaration line, or the first match in the file
STATIC FUNCTION Spelling( cText, aSrc, cSym, nDeclLine )

   LOCAL hS := TokenScan( cText, cSym )
   LOCAL aHits := hb_HGetDef( hS[ "hits" ], nDeclLine, {} )
   LOCAL nLine

   IF ! Empty( aHits ) .AND. nDeclLine <= Len( aSrc )
      RETURN SubStr( aSrc[ nDeclLine ], aHits[ 1 ][ 1 ], aHits[ 1 ][ 2 ] )
   ENDIF
   FOR EACH nLine IN ASort( hb_HKeys( hS[ "hits" ] ) )
      IF nLine <= Len( aSrc )
         aHits := hS[ "hits" ][ nLine ]
         RETURN SubStr( aSrc[ nLine ], aHits[ 1 ][ 1 ], aHits[ 1 ][ 2 ] )
      ENDIF
   NEXT

   RETURN cSym

STATIC FUNCTION VarWrittenIn( hVar )

   LOCAL hOcc

   FOR EACH hOcc IN hVar[ "in" ]
      IF !( hOcc[ "access" ] == "read" )      // write, ref and use are all writes, pessimistically
         RETURN .T.
      ENDIF
   NEXT

   RETURN .F.

// keyword-level structure balance over preprocessed lines: every control
// structure opened in the range must close inside it, and no statement may
// jump across the border
STATIC FUNCTION StructureCheck( hPpo, nFirst, nLast )

   LOCAL aStack := {}, nLine, aWords, nW, cW, cNx, lLoopOpen

   FOR nLine := nFirst TO nLast
      aWords := LineWords( hb_HGetDef( hPpo, nLine, "" ) )
      nW := 1
      DO WHILE nW <= Len( aWords )
         cW := aWords[ nW ][ 1 ]
         cNx := iif( nW < Len( aWords ), aWords[ nW + 1 ][ 1 ], "" )
         DO CASE
         CASE cW == "IF" .AND. !( aWords[ nW ][ 2 ] == "(" )
            AAdd( aStack, "IF" )
         CASE cW == "ENDIF"
            IF Empty( aStack ) .OR. !( ATail( aStack ) == "IF" )
               RETURN "line " + hb_ntos( nLine ) + ": ENDIF closes a structure opened outside the selection"
            ENDIF
            ASize( aStack, Len( aStack ) - 1 )
         CASE cW == "DO" .AND. ( cNx == "WHILE" .OR. cNx == "CASE" )
            AAdd( aStack, cNx )
            nW++
         CASE cW == "WHILE" .AND. !( aWords[ nW ][ 2 ] == "(" )
            // bare WHILE opener (the DO WHILE form was consumed above)
            AAdd( aStack, "WHILE" )
         CASE cW == "ENDDO"
            IF Empty( aStack ) .OR. !( ATail( aStack ) == "WHILE" )
               RETURN "line " + hb_ntos( nLine ) + ": ENDDO closes a structure opened outside the selection"
            ENDIF
            ASize( aStack, Len( aStack ) - 1 )
         CASE cW == "FOR"
            AAdd( aStack, "FOR" )
         CASE cW == "NEXT"
            IF Empty( aStack ) .OR. !( ATail( aStack ) == "FOR" )
               RETURN "line " + hb_ntos( nLine ) + ": NEXT closes a structure opened outside the selection"
            ENDIF
            ASize( aStack, Len( aStack ) - 1 )
         CASE cW == "ENDCASE"
            IF Empty( aStack ) .OR. !( ATail( aStack ) == "CASE" )
               RETURN "line " + hb_ntos( nLine ) + ": ENDCASE closes a structure opened outside the selection"
            ENDIF
            ASize( aStack, Len( aStack ) - 1 )
         CASE cW == "SWITCH" .AND. !( aWords[ nW ][ 2 ] == "(" )
            AAdd( aStack, "SWITCH" )
         CASE cW == "ENDSWITCH"
            IF Empty( aStack ) .OR. !( ATail( aStack ) == "SWITCH" )
               RETURN "line " + hb_ntos( nLine ) + ": ENDSWITCH closes a structure opened outside the selection"
            ENDIF
            ASize( aStack, Len( aStack ) - 1 )
         CASE cW == "BEGIN" .AND. cNx == "SEQUENCE"
            AAdd( aStack, "SEQ" )
            nW++
         CASE cW == "END"
            IF Empty( aStack )
               RETURN "line " + hb_ntos( nLine ) + ": END closes a structure opened outside the selection"
            ENDIF
            ASize( aStack, Len( aStack ) - 1 )
            IF cNx == "SEQUENCE" .OR. cNx == "IF" .OR. cNx == "CASE" .OR. cNx == "WHILE"
               nW++
            ENDIF
         CASE cW == "ELSE" .OR. cW == "ELSEIF"
            IF Empty( aStack ) .OR. !( ATail( aStack ) == "IF" )
               RETURN "line " + hb_ntos( nLine ) + ": " + cW + " belongs to an IF outside the selection"
            ENDIF
         CASE cW == "CASE" .OR. cW == "OTHERWISE"
            IF Empty( aStack ) .OR. !( ATail( aStack ) == "CASE" .OR. ATail( aStack ) == "SWITCH" )
               RETURN "line " + hb_ntos( nLine ) + ": " + cW + " belongs to a structure outside the selection"
            ENDIF
         CASE cW == "RECOVER" .OR. cW == "ALWAYS"
            IF Empty( aStack ) .OR. !( ATail( aStack ) == "SEQ" )
               RETURN "line " + hb_ntos( nLine ) + ": " + cW + " belongs to a SEQUENCE outside the selection"
            ENDIF
         CASE cW == "RETURN"
            RETURN "line " + hb_ntos( nLine ) + ": RETURN inside the selection - refusing"
         CASE cW == "EXIT" .OR. cW == "LOOP"
            lLoopOpen := hb_AScan( aStack, "FOR" ) > 0 .OR. hb_AScan( aStack, "WHILE" ) > 0
            IF ! lLoopOpen
               RETURN "line " + hb_ntos( nLine ) + ": " + cW + " would jump out of the selection"
            ENDIF
         CASE cW == "BREAK" .AND. !( aWords[ nW ][ 2 ] == "(" )
            IF hb_AScan( aStack, "SEQ" ) == 0
               RETURN "line " + hb_ntos( nLine ) + ": BREAK would jump out of the selection"
            ENDIF
         CASE ( cW == "PRIVATE" .OR. cW == "PUBLIC" .OR. cW == "PARAMETERS" .OR. ;
                cW == "MEMVAR" .OR. cW == "FIELD" ) .AND. nW == 1
            RETURN "line " + hb_ntos( nLine ) + ": " + cW + " declaration inside the selection - refusing"
         ENDCASE
         nW++
      ENDDO
   NEXT
   IF ! Empty( aStack )
      RETURN "selection opens a " + ATail( aStack ) + " that closes outside it"
   ENDIF

   RETURN ""

// uppercase words of a preprocessed line (strings blanked), each with the
// first non-blank character that follows it
STATIC FUNCTION LineWords( cLine )

   LOCAL aWords := {}, nAt := 1, nLen := Len( cLine )
   LOCAL cCh, cQuote := "", nStart, cWord, nJ, cAfter

   DO WHILE nAt <= nLen
      cCh := SubStr( cLine, nAt, 1 )
      IF ! Empty( cQuote )
         IF cCh == cQuote
            cQuote := ""
         ENDIF
      ELSEIF cCh == '"' .OR. cCh == "'"
         cQuote := cCh
      ELSEIF IsIdStart( cCh )
         nStart := nAt
         DO WHILE nAt <= nLen .AND. IsIdChar( SubStr( cLine, nAt, 1 ) )
            nAt++
         ENDDO
         cWord := Upper( SubStr( cLine, nStart, nAt - nStart ) )
         cAfter := ""
         nJ := nAt
         DO WHILE nJ <= nLen
            IF !( SubStr( cLine, nJ, 1 ) == " " )
               cAfter := SubStr( cLine, nJ, 1 )
               EXIT
            ENDIF
            nJ++
         ENDDO
         AAdd( aWords, { cWord, cAfter } )
         LOOP
      ENDIF
      nAt++
   ENDDO

   RETURN aWords

STATIC FUNCTION ReplaceLines( cText, nFirst, nLast, cNewLine, cEol )

   LOCAL aOffs := LineOffsets( cText )
   LOCAL nStart := aOffs[ nFirst ]
   LOCAL nEnd := iif( nLast + 1 <= Len( aOffs ), aOffs[ nLast + 1 ], hb_BLen( cText ) + 1 )

   RETURN hb_BLeft( cText, nStart - 1 ) + cNewLine + cEol + hb_BSubStr( cText, nEnd )

// after an extraction the module must keep every symbol/function it had
// (same scopes) plus exactly the new static function; matching is by name
// because the insertion point shifts positional order
STATIC FUNCTION HrbExtractCheck( cBefore, cAfter, cUpNew, cWhy )

   LOCAL hB := HrbParse( cBefore ), hA := HrbParse( cAfter )
   LOCAL nI, nJ, lFound

   IF hB == NIL .OR. hA == NIL
      cWhy := "cannot parse .hrb"
      RETURN .F.
   ENDIF
   IF Len( hA[ "syms" ] ) != Len( hB[ "syms" ] ) + 1 .OR. ;
      Len( hA[ "funcs" ] ) != Len( hB[ "funcs" ] ) + 1
      cWhy := "expected exactly one new symbol and one new function"
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
         cWhy := "symbol lost or changed: " + hB[ "syms" ][ nI ][ 1 ]
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
      cWhy := "new symbol " + cUpNew + " not found"
      RETURN .F.
   ENDIF

   RETURN .T.

// ---------------------------------------------------------------------------
// usages: list every definition, declaration, use and call of a symbol
// across the whole project (read-only)
// ---------------------------------------------------------------------------

STATIC FUNCTION Usages( aArgs )

   LOCAL cHbp, cName, cFuncFilter := "", cJsonOut := ""
   LOCAL hProj, cTmp, cPath, hDump, hFunc, hItem
   LOCAL nHits := 0, nI, cModFile, aSrc, cCtx, cSrcText, hStrScan
   LOCAL aLoc := {}

   IF Len( aArgs ) < 3
      Usage()
      RETURN EXIT_USAGE
   ENDIF

   cHbp  := aArgs[ 2 ]
   cName := aArgs[ 3 ]
   FOR nI := 4 TO Len( aArgs )
      DO CASE
      CASE Lower( aArgs[ nI ] ) == "--func" .AND. nI < Len( aArgs )
         cFuncFilter := Upper( aArgs[ ++nI ] )
      CASE Lower( aArgs[ nI ] ) == "--json" .AND. nI < Len( aArgs )
         cJsonOut := aArgs[ ++nI ]
      ENDCASE
   NEXT

   hProj := LoadProject( cHbp )
   IF hProj == NIL
      RETURN Refuse( "cannot read project file '" + cHbp + "'" )
   ENDIF

   cTmp := WorkDir()
   IF ! CompileAll( hProj, "", cTmp, "before", .T. )
      RETURN Refuse( "project does not compile - fix build errors first" )
   ENDIF

   FOR EACH cPath IN hProj[ "files" ]
      hDump := ReadDump( cTmp + hb_ps() + FNameBase( cPath ) + ".occ.json" )
      IF hDump == NIL
         RETURN Refuse( "missing occurrence dump for '" + cPath + "'" )
      ENDIF
      cModFile := hb_FNameNameExt( cPath )
      cSrcText := hb_MemoRead( cPath )
      aSrc := hb_ATokens( StrTran( cSrcText, Chr( 13 ), "" ), Chr( 10 ) )

      // possible references by name inside string literals (read-only info)
      hStrScan := TokenScan( cSrcText, cName )
      FOR EACH hItem IN hStrScan[ "strexact" ]
         nHits++
         AAdd( aLoc, { cPath, hItem[ 1 ] } )
         OutStd( cModFile + ":" + hb_ntos( hItem[ 1 ] ) + ": possible reference in string" + ;
                 SrcLine( aSrc, hItem[ 1 ] ) + hb_eol() )
      NEXT

      FOR EACH hFunc IN hDump[ "functions" ]
         IF hFunc[ "fileDecl" ]
            LOOP
         ENDIF
         IF ! Empty( cFuncFilter ) .AND. !( Upper( hFunc[ "name" ] ) == cFuncFilter )
            LOOP
         ENDIF

         IF Upper( hFunc[ "name" ] ) == Upper( cName )
            nHits++
            AAdd( aLoc, { cPath, hFunc[ "line" ] } )
            OutStd( cModFile + ":" + hb_ntos( hFunc[ "line" ] ) + ": definition (" + ;
               iif( hFunc[ "static" ], "static ", "" ) + hFunc[ "kind" ] + ")" + hb_eol() )
         ENDIF

         FOR EACH hItem IN hFunc[ "declarations" ]
            IF Upper( hItem[ "sym" ] ) == Upper( cName )
               nHits++
               AAdd( aLoc, { cPath, hItem[ "declLine" ] } )
               cCtx := SrcLine( aSrc, hItem[ "declLine" ] )
               OutStd( cModFile + ":" + hb_ntos( hItem[ "declLine" ] ) + ": declaration (" + ;
                  hItem[ "scope" ] + iif( hItem[ "param" ], ", parameter", "" ) + ") in " + ;
                  hFunc[ "name" ] + cCtx + hb_eol() )
            ENDIF
         NEXT

         FOR EACH hItem IN hFunc[ "occurrences" ]
            IF Upper( hItem[ "sym" ] ) == Upper( cName )
               nHits++
               AAdd( aLoc, { cPath, hItem[ "line" ] } )
               cCtx := SrcLine( aSrc, hItem[ "line" ] )
               OutStd( cModFile + ":" + hb_ntos( hItem[ "line" ] ) + ": " + hItem[ "access" ] + ;
                  " (" + hItem[ "scope" ] + iif( hItem[ "block" ], ", codeblock", "" ) + ") in " + ;
                  hFunc[ "name" ] + cCtx + hb_eol() )
            ENDIF
         NEXT

         FOR EACH hItem IN hFunc[ "calls" ]
            IF Upper( hItem[ "sym" ] ) == Upper( cName )
               nHits++
               AAdd( aLoc, { cPath, hItem[ "line" ] } )
               cCtx := SrcLine( aSrc, hItem[ "line" ] )
               OutStd( cModFile + ":" + hb_ntos( hItem[ "line" ] ) + ": call" + ;
                  iif( hItem[ "block" ], " (codeblock)", "" ) + " in " + ;
                  hFunc[ "name" ] + cCtx + hb_eol() )
            ENDIF
         NEXT

         FOR EACH hItem IN hb_HGetDef( hFunc, "sends", {} )
            IF Upper( hItem[ "sym" ] ) == Upper( cName )
               nHits++
               AAdd( aLoc, { cPath, hItem[ "line" ] } )
               cCtx := SrcLine( aSrc, hItem[ "line" ] )
               OutStd( cModFile + ":" + hb_ntos( hItem[ "line" ] ) + ": send" + ;
                  iif( hItem[ "block" ], " (codeblock)", "" ) + " in " + ;
                  hFunc[ "name" ] + cCtx + hb_eol() )
            ENDIF
         NEXT
      NEXT
   NEXT

   OutStd( hb_ntos( nHits ) + " result(s) for '" + cName + "'" + hb_eol() )

   IF ! Empty( cJsonOut )
      hb_MemoWrit( cJsonOut, LocationsJson( aLoc ) )
   ENDIF

   RETURN iif( nHits > 0, EXIT_OK, EXIT_REFUSED )

// LSP Location[] (0-based lines; column 0 - navigation granularity is the line)
STATIC FUNCTION LocationsJson( aLoc )

   LOCAL aOut := {}, aL

   FOR EACH aL IN aLoc
      AAdd( aOut, { ;
         "uri" => "file://" + aL[ 1 ], ;
         "range" => { ;
            "start" => { "line" => aL[ 2 ] - 1, "character" => 0 }, ;
            "end"   => { "line" => aL[ 2 ] - 1, "character" => 0 } } } )
   NEXT

   RETURN hb_jsonEncode( aOut, .T. )

// ---------------------------------------------------------------------------
// rename-static: STATIC variable, either function-level or file-wide.
// Static names never reach the pcode (without -b), so the verification is
// the strongest one: every module's -gh -l .hrb must stay byte-identical.
// Statics are invisible to runtime macros, so this is S territory.
// ---------------------------------------------------------------------------

STATIC FUNCTION RenameStatic( aArgs )

   LOCAL cHbp, cFile, cOld, cNew, cFuncFilter := "", lDryRun := .F.
   LOCAL hProj, cTmp, cSrcPath, hDump, hFunc, hDecl, hOcc
   LOCAL aDecls := {}, hDeclFunc, lFileWide, aLines := {}
   LOCAL hScan, hPpo, nLine, cClean, aHit, aEdits := {}
   LOCAL cText, cTextNew, nI, cPath

   IF Len( aArgs ) < 5
      Usage()
      RETURN EXIT_USAGE
   ENDIF
   cHbp := aArgs[ 2 ]
   cFile := aArgs[ 3 ]
   cOld := aArgs[ 4 ]
   cNew := aArgs[ 5 ]
   FOR nI := 6 TO Len( aArgs )
      DO CASE
      CASE Lower( aArgs[ nI ] ) == "--func" .AND. nI < Len( aArgs )
         cFuncFilter := Upper( aArgs[ ++nI ] )
      CASE Lower( aArgs[ nI ] ) == "--dry-run"
         lDryRun := .T.
      ENDCASE
   NEXT

   IF ! IsValidIdent( cNew )
      RETURN Refuse( "new name '" + cNew + "' is not a valid identifier" )
   ENDIF
   IF IsReserved( cNew )
      RETURN Refuse( "new name '" + cNew + "' is a reserved word" )
   ENDIF
   IF Upper( cOld ) == Upper( cNew )
      RETURN Refuse( "old and new names are identical" )
   ENDIF

   hProj := LoadProject( cHbp )
   IF hProj == NIL
      RETURN Refuse( "cannot read project file '" + cHbp + "'" )
   ENDIF
   cSrcPath := ProjectMember( hProj, cFile )
   IF cSrcPath == ""
      RETURN Refuse( "'" + cFile + "' is not a source of project '" + cHbp + "'" )
   ENDIF
   IF DefineCollision( hProj, cSrcPath, cNew )
      RETURN Refuse( "new name '" + cNew + "' collides with a preprocessor rule" )
   ENDIF

   cTmp := WorkDir()
   IF ! CompileAll( hProj, cSrcPath, cTmp, "before" )
      RETURN Refuse( "project does not compile - fix build errors first" )
   ENDIF
   hDump := ReadDump( cTmp + hb_ps() + FNameBase( cSrcPath ) + ".occ.json" )
   IF hDump == NIL
      RETURN Refuse( "occurrence dump not found/invalid (compiler with -x support required)" )
   ENDIF

   // locate the STATIC declaration (file-wide lives in the fileDecl pseudo
   // function) and refuse the new name if it is declared anywhere in the
   // module (conservative: any capture/shadow risk is a no)
   FOR EACH hFunc IN hDump[ "functions" ]
      FOR EACH hDecl IN hFunc[ "declarations" ]
         IF Upper( hDecl[ "sym" ] ) == Upper( cNew )
            RETURN Refuse( "new name '" + cNew + "' is already declared in this module (" + ;
                           hFunc[ "name" ] + ", scope " + hDecl[ "scope" ] + ")" )
         ENDIF
         IF Upper( hDecl[ "sym" ] ) == Upper( cOld ) .AND. hDecl[ "scope" ] == "static"
            IF Empty( cFuncFilter ) .OR. ;
               ( ! hFunc[ "fileDecl" ] .AND. Upper( hFunc[ "name" ] ) == cFuncFilter )
               AAdd( aDecls, { hFunc, hDecl } )
            ENDIF
         ENDIF
      NEXT
   NEXT
   IF Empty( aDecls )
      RETURN Refuse( "'" + cOld + "' is not a STATIC variable of '" + cFile + "'" )
   ENDIF
   IF Len( aDecls ) > 1
      RETURN Refuse( "'" + cOld + "' is STATIC in more than one function - use --func" )
   ENDIF
   hDeclFunc := aDecls[ 1 ][ 1 ]
   lFileWide := hDeclFunc[ "fileDecl" ]
   AddLine( aLines, aDecls[ 1 ][ 2 ][ "declLine" ] )

   FOR EACH hFunc IN hDump[ "functions" ]
      FOR EACH hOcc IN hFunc[ "occurrences" ]
         IF Upper( hOcc[ "sym" ] ) == Upper( cOld ) .AND. hOcc[ "scope" ] == "static"
            DO CASE
            CASE lFileWide .AND. ( hb_HGetDef( hOcc, "filewide", .F. ) .OR. hFunc[ "fileDecl" ] )
               AddLine( aLines, hOcc[ "line" ] )
            CASE ! lFileWide .AND. ! hb_HGetDef( hOcc, "filewide", .F. ) .AND. ;
                 Upper( hFunc[ "name" ] ) == Upper( hDeclFunc[ "name" ] )
               AddLine( aLines, hOcc[ "line" ] )
            ENDCASE
         ENDIF
      NEXT
   NEXT

   cText := hb_MemoRead( cSrcPath )
   hScan := TokenScan( cText, cOld )
   hPpo := PpoMap( cTmp + hb_ps() + FNameBase( cSrcPath ) + ".ppo" )
   FOR EACH nLine IN ASort( aLines )
      cClean := ""
      IF ! StmtEdits( hScan, hPpo, nLine, cOld, cNew, aEdits, @cClean )
         RETURN Refuse( cClean )
      ENDIF
   NEXT
   IF Empty( aEdits )
      RETURN Refuse( "nothing to rename" )
   ENDIF

   OutStd( "rename-static: " + cOld + " -> " + cNew + ;
           iif( lFileWide, " (file-wide, " + cFile + ")", " (in " + hDeclFunc[ "name" ] + ")" ) + hb_eol() )
   FOR EACH aHit IN aEdits
      OutStd( "  " + cFile + ":" + hb_ntos( aHit[ 1 ] ) + ":" + hb_ntos( aHit[ 2 ] ) + hb_eol() )
   NEXT
   IF lDryRun
      OutStd( "dry run - no changes written" + hb_eol() )
      RETURN EXIT_OK
   ENDIF

   cTextNew := ApplyEdits( cText, aEdits )
   hb_MemoWrit( cSrcPath, cTextNew )

   IF ! CompileAll( hProj, cSrcPath, cTmp, "after" )
      hb_MemoWrit( cSrcPath, cText )
      RETURN Refuse( "project stopped compiling after rename - rolled back" )
   ENDIF
   FOR EACH cPath IN hProj[ "files" ]
      IF !( hb_MemoRead( cTmp + hb_ps() + FNameBase( cPath ) + ".before.hrb" ) == ;
            hb_MemoRead( cTmp + hb_ps() + FNameBase( cPath ) + ".after.hrb" ) )
         hb_MemoWrit( cSrcPath, cText )
         RETURN Refuse( "verification FAILED: " + hb_FNameNameExt( cPath ) + ".hrb changed - rolled back" )
      ENDIF
   NEXT
   OutStd( "verified: all " + hb_ntos( Len( hProj[ "files" ] ) ) + " module(s) byte-identical (-gh -l)" + hb_eol() )

   RETURN EXIT_OK

// ---------------------------------------------------------------------------
// find-dynamic-calls: audit report of the blind spots - string literals that
// name a project function (possible Do()/dispatch-by-name) and functions
// using & macros (dynamic names may be built there)
// ---------------------------------------------------------------------------

STATIC FUNCTION FindDynamicCalls( aArgs )

   LOCAL hProj, cTmp, cPath, hDump, hFunc, hItem
   LOCAL hDefined := { => }, nFound := 0, cModFile, hScan, aSrc

   IF Len( aArgs ) < 2
      Usage()
      RETURN EXIT_USAGE
   ENDIF
   hProj := LoadProject( aArgs[ 2 ] )
   IF hProj == NIL
      RETURN Refuse( "cannot read project file '" + aArgs[ 2 ] + "'" )
   ENDIF
   cTmp := WorkDir()
   IF ! CompileAll( hProj, "", cTmp, "before", .T. )
      RETURN Refuse( "project does not compile - fix build errors first" )
   ENDIF

   FOR EACH cPath IN hProj[ "files" ]
      hDump := ReadDump( cTmp + hb_ps() + FNameBase( cPath ) + ".occ.json" )
      IF hDump == NIL
         RETURN Refuse( "missing occurrence dump for '" + cPath + "'" )
      ENDIF
      FOR EACH hFunc IN hDump[ "functions" ]
         IF ! hFunc[ "fileDecl" ]
            hDefined[ Upper( hFunc[ "name" ] ) ] := hb_FNameNameExt( cPath )
         ENDIF
      NEXT
   NEXT

   FOR EACH cPath IN hProj[ "files" ]
      cModFile := hb_FNameNameExt( cPath )
      hScan := TokenScan( hb_MemoRead( cPath ), "hbrf_dummy" )
      aSrc := hb_ATokens( StrTran( hb_MemoRead( cPath ), Chr( 13 ), "" ), Chr( 10 ) )
      FOR EACH hItem IN hScan[ "strids" ]
         IF Upper( hItem[ 2 ] ) $ hDefined
            nFound++
            OutStd( cModFile + ":" + hb_ntos( hItem[ 1 ] ) + ": string '" + hItem[ 2 ] + ;
               "' names a project function [" + hDefined[ Upper( hItem[ 2 ] ) ] + "]" + ;
               SrcLine( aSrc, hItem[ 1 ] ) + hb_eol() )
         ENDIF
      NEXT
      hDump := ReadDump( cTmp + hb_ps() + FNameBase( cPath ) + ".occ.json" )
      FOR EACH hFunc IN hDump[ "functions" ]
         IF ! hFunc[ "fileDecl" ] .AND. hFunc[ "usesMacro" ]
            nFound++
            OutStd( cModFile + ":" + hb_ntos( hFunc[ "line" ] ) + ": function " + hFunc[ "name" ] + ;
               " uses & macros (dynamic names possible)" + hb_eol() )
         ENDIF
      NEXT
   NEXT
   OutStd( hb_ntos( nFound ) + " finding(s)" + hb_eol() )

   RETURN EXIT_OK

// ---------------------------------------------------------------------------
// unused-locals: delegate to the compiler's own analysis (-w3 warnings
// W0003 "declared but not used" and W0032 "assigned but not used").
// The -x dump cannot see never-used locals: the optimizer removes them
// before the dump is saved - the warnings are emitted earlier and are
// exactly the report we want.
// ---------------------------------------------------------------------------

STATIC FUNCTION UnusedLocals( aArgs )

   LOCAL hProj, cPath, cInc := "", cOut, cErr, cLine
   LOCAL nFound := 0

   IF Len( aArgs ) < 2
      Usage()
      RETURN EXIT_USAGE
   ENDIF
   hProj := LoadProject( aArgs[ 2 ] )
   IF hProj == NIL
      RETURN Refuse( "cannot read project file '" + aArgs[ 2 ] + "'" )
   ENDIF
   FOR EACH cPath IN hProj[ "inc" ]
      cInc += " -I" + cPath
   NEXT

   FOR EACH cPath IN hProj[ "files" ]
      cOut := cErr := ""
      hb_processRun( HarbourBin() + " " + cPath + " -n -q0 -w3 -s" + cInc,, @cOut, @cErr )
      FOR EACH cLine IN hb_ATokens( StrTran( cOut + cErr, Chr( 13 ), "" ), Chr( 10 ) )
         IF "W0003" $ cLine .OR. "W0032" $ cLine
            nFound++
            OutStd( AllTrim( cLine ) + hb_eol() )
         ENDIF
      NEXT
   NEXT
   OutStd( hb_ntos( nFound ) + " finding(s)" + hb_eol() )

   RETURN EXIT_OK

// ---------------------------------------------------------------------------
// call-graph: who calls whom, from the compiled call records (read-only).
// With a function argument: its callers and callees only.
// ---------------------------------------------------------------------------

STATIC FUNCTION CallGraph( aArgs )

   LOCAL hProj, cTmp, cPath, hDump, hFunc, hItem
   LOCAL cFilter := "", hDefined := { => }, cModFile, cCallee
   LOCAL hSeen, cKey

   IF Len( aArgs ) < 2
      Usage()
      RETURN EXIT_USAGE
   ENDIF
   hProj := LoadProject( aArgs[ 2 ] )
   IF hProj == NIL
      RETURN Refuse( "cannot read project file '" + aArgs[ 2 ] + "'" )
   ENDIF
   IF Len( aArgs ) >= 3
      cFilter := Upper( aArgs[ 3 ] )
   ENDIF
   cTmp := WorkDir()
   IF ! CompileAll( hProj, "", cTmp, "before", .T. )
      RETURN Refuse( "project does not compile - fix build errors first" )
   ENDIF

   // project-defined names (to distinguish internal calls from RTL/external)
   FOR EACH cPath IN hProj[ "files" ]
      hDump := ReadDump( cTmp + hb_ps() + FNameBase( cPath ) + ".occ.json" )
      IF hDump == NIL
         RETURN Refuse( "missing occurrence dump for '" + cPath + "'" )
      ENDIF
      FOR EACH hFunc IN hDump[ "functions" ]
         IF ! hFunc[ "fileDecl" ]
            hDefined[ Upper( hFunc[ "name" ] ) ] := hb_FNameNameExt( cPath )
         ENDIF
      NEXT
   NEXT

   FOR EACH cPath IN hProj[ "files" ]
      hDump := ReadDump( cTmp + hb_ps() + FNameBase( cPath ) + ".occ.json" )
      cModFile := hb_FNameNameExt( cPath )
      FOR EACH hFunc IN hDump[ "functions" ]
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
               OutStd( cModFile + ": " + hFunc[ "name" ] + " -> " + hItem[ "sym" ] + ;
                  iif( cCallee $ hDefined, "  [" + hDefined[ cCallee ] + "]", "  [external]" ) + hb_eol() )
            ENDIF
         NEXT
      NEXT
   NEXT

   RETURN EXIT_OK

STATIC FUNCTION SrcLine( aSrc, nLine )
   RETURN iif( nLine >= 1 .AND. nLine <= Len( aSrc ), ;
               "  | " + AllTrim( aSrc[ nLine ] ), "" )

STATIC FUNCTION Refuse( cMsg )

   OutErr( "hbrefactor: " + cMsg + hb_eol() )

   RETURN EXIT_REFUSED

// ---------------------------------------------------------------------------
// project handling (.hbp)
// ---------------------------------------------------------------------------

STATIC FUNCTION LoadProject( cHbp )

   LOCAL cText := hb_MemoRead( cHbp )
   LOCAL hProj, cLine, cDir

   IF Empty( cText )
      RETURN NIL
   ENDIF

   cDir := hb_FNameDir( cHbp )
   IF Empty( cDir )
      cDir := "." + hb_ps()
   ENDIF

   hProj := { "dir" => cDir, "files" => {}, "inc" => { cDir } }

   FOR EACH cLine IN hb_ATokens( StrTran( cText, Chr( 13 ), "" ), Chr( 10 ) )
      cLine := AllTrim( cLine )
      DO CASE
      CASE Empty( cLine ) .OR. Left( cLine, 1 ) == "#"
      CASE Left( cLine, 2 ) == "-i"
         AAdd( hProj[ "inc" ], PathAt( cDir, SubStr( cLine, 3 ) ) )
      CASE Lower( hb_FNameExt( cLine ) ) == ".prg"
         AAdd( hProj[ "files" ], PathAt( cDir, cLine ) )
      ENDCASE
   NEXT

   RETURN hProj

STATIC FUNCTION PathAt( cDir, cPath )
   RETURN iif( Left( cPath, 1 ) == hb_ps() .OR. SubStr( cPath, 2, 1 ) == ":", ;
               cPath, cDir + cPath )

STATIC FUNCTION ProjectMember( hProj, cFile )

   LOCAL cPath

   FOR EACH cPath IN hProj[ "files" ]
      IF Lower( hb_FNameNameExt( cPath ) ) == Lower( hb_FNameNameExt( cFile ) )
         RETURN cPath
      ENDIF
   NEXT

   RETURN ""

STATIC FUNCTION FNameBase( cPath )
   RETURN hb_FNameName( cPath )

// resolve one level of #include and look for pp rules whose head is cName
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
            hb_AScan( { "#define", "#xtranslate", "#translate", "#command", "#xcommand", "#ycommand", "#ytranslate" }, ;
                      Lower( aTok[ 1 ] ),,, .T. ) > 0
            RETURN .T.
         ENDIF
      ENDIF
   NEXT

   RETURN .F.

// ---------------------------------------------------------------------------
// compiler invocations
// ---------------------------------------------------------------------------

STATIC FUNCTION HarbourBin()

   LOCAL cBin := hb_GetEnv( "HB_BIN" )

   RETURN iif( Empty( cBin ), "harbour", hb_DirSepAdd( cBin ) + "harbour" )

STATIC FUNCTION CompileAll( hProj, cTarget, cTmp, cTag, lDumpAll )

   LOCAL cPath, cCmd, cInc := "", cOut, cErr, nRes

   hb_default( @lDumpAll, .F. )

   FOR EACH cPath IN hProj[ "inc" ]
      cInc += " -I" + cPath
   NEXT

   FOR EACH cPath IN hProj[ "files" ]
      cCmd := HarbourBin() + " " + cPath + " -n -q2 -gh -l" + cInc + ;
              " -o" + cTmp + hb_ps() + FNameBase( cPath ) + "." + cTag + ".hrb"
      IF cTag == "before" .AND. ( lDumpAll .OR. cPath == cTarget )
         cCmd += " -x" + cTmp + hb_ps() + FNameBase( cPath ) + ".occ.json"
         cCmd += " -p" + cTmp + hb_ps()
      ENDIF
      cOut := cErr := ""
      nRes := hb_processRun( cCmd,, @cOut, @cErr )
      IF nRes != 0
         OutErr( cErr )
         RETURN .F.
      ENDIF
   NEXT

   RETURN .T.

STATIC FUNCTION WorkDir()

   LOCAL cTmp := hb_DirSepAdd( hb_DirTemp() ) + "hbrefactor_" + ;
                 StrTran( StrTran( hb_TSToStr( hb_DateTime() ), ":", "" ), " ", "_" )

   hb_DirCreate( cTmp )

   RETURN cTmp

// ---------------------------------------------------------------------------
// occurrence dump (oracle)
// ---------------------------------------------------------------------------

STATIC FUNCTION ReadDump( cPath )

   LOCAL cJson := hb_MemoRead( cPath )
   LOCAL hDump

   IF Empty( cJson )
      RETURN NIL
   ENDIF
   IF hb_jsonDecode( cJson, @hDump ) == 0 .OR. ! HB_ISHASH( hDump )
      RETURN NIL
   ENDIF

   RETURN hDump

STATIC FUNCTION PickFunc( hDump, cFunc )

   LOCAL hFunc

   FOR EACH hFunc IN hDump[ "functions" ]
      IF ! hFunc[ "fileDecl" ] .AND. Upper( hFunc[ "name" ] ) == Upper( cFunc )
         RETURN hFunc
      ENDIF
   NEXT

   RETURN NIL

// returns the set (array) of line numbers to edit, or a string refusal message
STATIC FUNCTION CollectTargetLines( hFunc, cOld, cNew, lParamOnly )

   LOCAL cUp := Upper( cOld ), cUpNew := Upper( cNew )
   LOCAL hDecl, hOcc, aLines := {}, lFound := .F.

   hb_default( @lParamOnly, .F. )

   // the target must be a declared LOCAL (or parameter) of this function
   FOR EACH hDecl IN hFunc[ "declarations" ]
      IF Upper( hDecl[ "sym" ] ) == cUpNew
         RETURN "new name '" + cNew + "' already declared in function (scope " + hDecl[ "scope" ] + ")"
      ENDIF
      IF Upper( hDecl[ "sym" ] ) == cUp
         IF !( hDecl[ "scope" ] == "local" )
            RETURN "'" + cOld + "' is " + hDecl[ "scope" ] + ", not LOCAL - out of Phase 0 scope"
         ENDIF
         IF lParamOnly .AND. ! hDecl[ "param" ]
            RETURN "'" + cOld + "' is a LOCAL, not a parameter - use rename-local"
         ENDIF
         lFound := .T.
         AddLine( aLines, hDecl[ "declLine" ] )
      ENDIF
   NEXT
   IF ! lFound
      RETURN "'" + cOld + "' is not a " + iif( lParamOnly, "parameter", "LOCAL" ) + " of this function"
   ENDIF

   FOR EACH hOcc IN hFunc[ "occurrences" ]
      IF Upper( hOcc[ "sym" ] ) == cUp
         DO CASE
         CASE hOcc[ "scope" ] == "local" .AND. hOcc[ "block" ]
            // a codeblock parameter/local with the same name shadows the
            // target inside a block - positional matching would be unsafe
            RETURN "'" + cOld + "' is shadowed by a homonymous codeblock parameter (line " + ;
                   hb_ntos( hOcc[ "line" ] ) + ") - refusing"
         CASE hOcc[ "scope" ] == "local" .OR. hOcc[ "scope" ] == "detached"
            AddLine( aLines, hOcc[ "line" ] )
         OTHERWISE
            RETURN "unexpected scope '" + hOcc[ "scope" ] + "' for '" + cOld + "' (line " + ;
                   hb_ntos( hOcc[ "line" ] ) + ") - refusing"
         ENDCASE
      ENDIF
   NEXT

   RETURN ASort( aLines )

STATIC PROCEDURE AddLine( aLines, nLine )

   IF nLine > 0 .AND. hb_AScan( aLines, nLine ) == 0
      AAdd( aLines, nLine )
   ENDIF

   RETURN

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

// resolve an oracle line (always the LAST physical line of a ;-continued
// statement - the compiler's currLine and the .ppo agree on that) to the
// whole statement, validate the joined text against the preprocessed line
// and collect the matching tokens across all its physical lines as edits
STATIC FUNCTION StmtEdits( hScan, hPpo, nLine, cOld, cNew, aEdits, cErr )

   LOCAL nStart := StmtStart( hScan[ "clean" ], nLine )
   LOCAL nN, cClean := "", cPiece
   LOCAL aHits, aHit, aNew := {}, cPpoLine

   FOR nN := nStart TO nLine
      cPiece := RTrim( hb_HGetDef( hScan[ "clean" ], nN, "" ) )
      IF nN < nLine .AND. Right( cPiece, 1 ) == ";"
         cPiece := hb_StrShrink( cPiece, 1 )
      ENDIF
      cClean += " " + cPiece
      aHits := hb_HGetDef( hScan[ "hits" ], nN, {} )
      FOR EACH aHit IN aHits
         AAdd( aNew, { nN, aHit[ 1 ], aHit[ 2 ], cNew } )
      NEXT
   NEXT

   cPpoLine := Squeeze( hb_HGetDef( hPpo, nLine, "" ) )
   IF !( Squeeze( cClean ) == cPpoLine ) .AND. ;
      CountIdent( cPpoLine, cOld ) != Len( aNew )
      cErr := "line " + hb_ntos( nLine ) + " is rewritten by the preprocessor - refusing unsafe rename"
      RETURN .F.
   ENDIF
   IF Empty( aNew )
      cErr := "line " + hb_ntos( nLine ) + ": oracle reports an occurrence but no matching token found"
      RETURN .F.
   ENDIF
   FOR EACH aHit IN aNew
      AAdd( aEdits, aHit )
   NEXT

   RETURN .T.

// first physical line of the ;-continued statement that ends at nLine
STATIC FUNCTION StmtStart( hClean, nLine )

   DO WHILE nLine > 1 .AND. ;
      Right( RTrim( hb_HGetDef( hClean, nLine - 1, "" ) ), 1 ) == ";"
      nLine--
   ENDDO

   RETURN nLine

// is nLine inside any ;-continued statement whose LAST line is in aOracle?
STATIC FUNCTION LineCovered( hClean, aOracle, nLine )

   LOCAL nEnd := nLine

   // walk forward to the end of the statement nLine belongs to
   DO WHILE Right( RTrim( hb_HGetDef( hClean, nEnd, "" ) ), 1 ) == ";"
      nEnd++
   ENDDO

   RETURN hb_AScan( aOracle, nEnd ) > 0

// count identifier tokens equal to cName in a single (comment-free) line,
// with the same string and ->/: context rules used by TokenScan
STATIC FUNCTION CountIdent( cLine, cName )

   LOCAL hScan := TokenScan( cLine, cName )

   RETURN Len( hb_HGetDef( hScan[ "hits" ], 1, {} ) )

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

// ---------------------------------------------------------------------------
// .ppo line map: line number -> preprocessed text
// ---------------------------------------------------------------------------

STATIC FUNCTION PpoMap( cPath )

   LOCAL hMap := { => }
   LOCAL cText := hb_MemoRead( cPath )
   LOCAL cLine, nCur := 0, aTok

   FOR EACH cLine IN hb_ATokens( StrTran( cText, Chr( 13 ), "" ), Chr( 10 ) )
      IF Left( LTrim( cLine ), 6 ) == "#line "
         aTok := hb_ATokens( LTrim( cLine ) )
         nCur := Val( aTok[ 2 ] ) - 1
      ELSE
         nCur++
         hMap[ nCur ] := cLine
      ENDIF
   NEXT

   RETURN hMap

STATIC FUNCTION Squeeze( cLine )

   // collapse any whitespace run into a single space
   cLine := StrTran( cLine, Chr( 9 ), " " )
   DO WHILE "  " $ cLine
      cLine := StrTran( cLine, "  ", " " )
   ENDDO

   RETURN AllTrim( cLine )

// ---------------------------------------------------------------------------
// edits
// ---------------------------------------------------------------------------

STATIC FUNCTION ApplyEdits( cText, aEdits )

   LOCAL aOffs := LineOffsets( cText )
   LOCAL aAbs := {}, aE, nOff

   FOR EACH aE IN aEdits
      AAdd( aAbs, { aOffs[ aE[ 1 ] ] + aE[ 2 ] - 1, aE[ 3 ], aE[ 4 ] } )
   NEXT
   ASort( aAbs,,, {| a, b | a[ 1 ] > b[ 1 ] } )     // descending

   FOR EACH aE IN aAbs
      nOff := aE[ 1 ]
      cText := hb_BLeft( cText, nOff - 1 ) + aE[ 3 ] + hb_BSubStr( cText, nOff + aE[ 2 ] )
   NEXT

   RETURN cText

STATIC FUNCTION LineOffsets( cText )

   LOCAL aOffs := { 1 }
   LOCAL nAt := 1, nLen := hb_BLen( cText )

   DO WHILE nAt <= nLen
      IF hb_BSubStr( cText, nAt, 1 ) == Chr( 10 )
         AAdd( aOffs, nAt + 1 )
      ENDIF
      nAt++
   ENDDO

   RETURN aOffs

// LSP WorkspaceEdit-compatible JSON (0-based positions)
STATIC FUNCTION WorkspaceEditJson( cSrcPath, aEdits )

   LOCAL hEdit := { "changes" => { => } }
   LOCAL aChanges := {}, aE

   FOR EACH aE IN aEdits
      AAdd( aChanges, { ;
         "range" => { ;
            "start" => { "line" => aE[ 1 ] - 1, "character" => aE[ 2 ] - 1 }, ;
            "end"   => { "line" => aE[ 1 ] - 1, "character" => aE[ 2 ] - 1 + aE[ 3 ] } }, ;
         "newText" => aE[ 4 ] } )
   NEXT
   hEdit[ "changes" ] := { "file://" + cSrcPath => aChanges }

   RETURN hb_jsonEncode( hEdit, .T. )
