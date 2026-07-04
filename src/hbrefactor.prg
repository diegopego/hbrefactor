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
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "rename-local"
      nExit := RenameLocal( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "rename-function"
      nExit := RenameFunction( aArgs )
   CASE Len( aArgs ) >= 1 .AND. Lower( aArgs[ 1 ] ) == "usages"
      nExit := Usages( aArgs )
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
   OutStd( "  hbrefactor rename-function <project.hbp> <old> <new> [--file <f.prg>] [--force] [--dry-run]" + hb_eol() )
   OutStd( "  hbrefactor usages <project.hbp> <name> [--func <function>]" + hb_eol() )

   RETURN

// ---------------------------------------------------------------------------
// rename-local
// ---------------------------------------------------------------------------

STATIC FUNCTION RenameLocal( aArgs )

   LOCAL cHbp, cFile, cFunc, cOld, cNew
   LOCAL lDryRun := .F., cJsonOut := ""
   LOCAL hProj, cSrcPath, cTmp, cText, cTextNew
   LOCAL hDump, hFunc, aLines, hScan, aEdits
   LOCAL hPpo, nLine, cClean, cPpoLine
   LOCAL aHits, hHit, nPos, cOut
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

   aLines := CollectTargetLines( hFunc, cOld, cNew )
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
   FOR EACH nLine IN aLines
      cClean := Squeeze( hb_HGetDef( hScan[ "clean" ], nLine, "" ) )
      cPpoLine := Squeeze( hb_HGetDef( hPpo, nLine, "" ) )
      IF !( cClean == cPpoLine ) .AND. ;
         CountIdent( cPpoLine, cOld ) != Len( hb_HGetDef( hScan[ "hits" ], nLine, {} ) )
         RETURN Refuse( "line " + hb_ntos( nLine ) + " is rewritten by the preprocessor - refusing unsafe rename" )
      ENDIF
   NEXT

   // --- build edit list ------------------------------------------------------
   aEdits := {}
   FOR EACH nLine IN aLines
      aHits := hb_HGetDef( hScan[ "hits" ], nLine, {} )
      IF Empty( aHits )
         RETURN Refuse( "line " + hb_ntos( nLine ) + ": oracle reports an occurrence but no matching token found" )
      ENDIF
      FOR EACH hHit IN aHits
         AAdd( aEdits, { nLine, hHit[ 1 ], hHit[ 2 ], cNew } )
      NEXT
   NEXT

   IF Empty( aEdits )
      RETURN Refuse( "nothing to rename" )
   ENDIF

   // --- report / dry run -----------------------------------------------------
   OutStd( "rename-local: " + cOld + " -> " + cNew + " in " + cFunc + " (" + cFile + ")" + hb_eol() )
   FOR EACH hHit IN aEdits
      OutStd( "  " + cFile + ":" + hb_ntos( hHit[ 1 ] ) + ":" + hb_ntos( hHit[ 2 ] ) + hb_eol() )
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
   LOCAL aWarn := {}, hScan, hPpo, aLines, nLine, cClean, cPpoLine
   LOCAL hFileEdits := { => }, aEdits, aHits, hHit
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
      // EXTERNAL, homonymous variables...) - flag for human review
      IF hb_AScan( aScope, {| c | c == cPath } ) > 0
         FOR EACH nLine IN hb_HKeys( hScan[ "hits" ] )
            IF Empty( hb_HGetDef( hEditLines, cPath, {} ) ) .OR. ;
               hb_AScan( hEditLines[ cPath ], nLine ) == 0
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
         cClean := Squeeze( hb_HGetDef( hScan[ "clean" ], nLine, "" ) )
         cPpoLine := Squeeze( hb_HGetDef( hPpo, nLine, "" ) )
         IF !( cClean == cPpoLine ) .AND. ;
            CountIdent( cPpoLine, cOld ) != Len( hb_HGetDef( hScan[ "hits" ], nLine, {} ) )
            RETURN Refuse( hb_FNameNameExt( cPath ) + ":" + hb_ntos( nLine ) + ;
                           " is rewritten by the preprocessor - refusing unsafe rename" )
         ENDIF
         aHits := hb_HGetDef( hScan[ "hits" ], nLine, {} )
         IF Empty( aHits )
            RETURN Refuse( hb_FNameNameExt( cPath ) + ":" + hb_ntos( nLine ) + ;
                           ": oracle reports a reference but no matching token found" )
         ENDIF
         FOR EACH hHit IN aHits
            AAdd( aEdits, { nLine, hHit[ 1 ], hHit[ 2 ], cNew } )
         NEXT
      NEXT
      hFileEdits[ cPath ] := aEdits
      hOrig[ cPath ] := cText
      nTotal += Len( aEdits )
   NEXT

   OutStd( "rename-function: " + cOld + " -> " + cNew + iif( lStatic, " (static, single module)", "" ) + hb_eol() )
   FOR EACH cPath IN hb_HKeys( hFileEdits )
      FOR EACH hHit IN hFileEdits[ cPath ]
         OutStd( "  " + hb_FNameNameExt( cPath ) + ":" + hb_ntos( hHit[ 1 ] ) + ":" + hb_ntos( hHit[ 2 ] ) + hb_eol() )
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
// usages: list every definition, declaration, use and call of a symbol
// across the whole project (read-only)
// ---------------------------------------------------------------------------

STATIC FUNCTION Usages( aArgs )

   LOCAL cHbp, cName, cFuncFilter := ""
   LOCAL hProj, cTmp, cPath, hDump, hFunc, hItem
   LOCAL nHits := 0, nI, cModFile, aSrc, cCtx

   IF Len( aArgs ) < 3
      Usage()
      RETURN EXIT_USAGE
   ENDIF

   cHbp  := aArgs[ 2 ]
   cName := aArgs[ 3 ]
   FOR nI := 4 TO Len( aArgs )
      IF Lower( aArgs[ nI ] ) == "--func" .AND. nI < Len( aArgs )
         cFuncFilter := Upper( aArgs[ ++nI ] )
      ENDIF
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
      aSrc := hb_ATokens( StrTran( hb_MemoRead( cPath ), Chr( 13 ), "" ), Chr( 10 ) )

      FOR EACH hFunc IN hDump[ "functions" ]
         IF hFunc[ "fileDecl" ]
            LOOP
         ENDIF
         IF ! Empty( cFuncFilter ) .AND. !( Upper( hFunc[ "name" ] ) == cFuncFilter )
            LOOP
         ENDIF

         IF Upper( hFunc[ "name" ] ) == Upper( cName )
            nHits++
            OutStd( cModFile + ":" + hb_ntos( hFunc[ "line" ] ) + ": definition (" + ;
               iif( hFunc[ "static" ], "static ", "" ) + hFunc[ "kind" ] + ")" + hb_eol() )
         ENDIF

         FOR EACH hItem IN hFunc[ "declarations" ]
            IF Upper( hItem[ "sym" ] ) == Upper( cName )
               nHits++
               cCtx := SrcLine( aSrc, hItem[ "declLine" ] )
               OutStd( cModFile + ":" + hb_ntos( hItem[ "declLine" ] ) + ": declaration (" + ;
                  hItem[ "scope" ] + iif( hItem[ "param" ], ", parameter", "" ) + ") in " + ;
                  hFunc[ "name" ] + cCtx + hb_eol() )
            ENDIF
         NEXT

         FOR EACH hItem IN hFunc[ "occurrences" ]
            IF Upper( hItem[ "sym" ] ) == Upper( cName )
               nHits++
               cCtx := SrcLine( aSrc, hItem[ "line" ] )
               OutStd( cModFile + ":" + hb_ntos( hItem[ "line" ] ) + ": " + hItem[ "access" ] + ;
                  " (" + hItem[ "scope" ] + iif( hItem[ "block" ], ", codeblock", "" ) + ") in " + ;
                  hFunc[ "name" ] + cCtx + hb_eol() )
            ENDIF
         NEXT

         FOR EACH hItem IN hFunc[ "calls" ]
            IF Upper( hItem[ "sym" ] ) == Upper( cName )
               nHits++
               cCtx := SrcLine( aSrc, hItem[ "line" ] )
               OutStd( cModFile + ":" + hb_ntos( hItem[ "line" ] ) + ": call" + ;
                  iif( hItem[ "block" ], " (codeblock)", "" ) + " in " + ;
                  hFunc[ "name" ] + cCtx + hb_eol() )
            ENDIF
         NEXT
      NEXT
   NEXT

   OutStd( hb_ntos( nHits ) + " result(s) for '" + cName + "'" + hb_eol() )

   RETURN iif( nHits > 0, EXIT_OK, EXIT_REFUSED )

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
STATIC FUNCTION CollectTargetLines( hFunc, cOld, cNew )

   LOCAL cUp := Upper( cOld ), cUpNew := Upper( cNew )
   LOCAL hDecl, hOcc, aLines := {}, lFound := .F.

   // the target must be a declared LOCAL (or parameter) of this function
   FOR EACH hDecl IN hFunc[ "declarations" ]
      IF Upper( hDecl[ "sym" ] ) == cUpNew
         RETURN "new name '" + cNew + "' already declared in function (scope " + hDecl[ "scope" ] + ")"
      ENDIF
      IF Upper( hDecl[ "sym" ] ) == cUp
         IF !( hDecl[ "scope" ] == "local" )
            RETURN "'" + cOld + "' is " + hDecl[ "scope" ] + ", not LOCAL - out of Phase 0 scope"
         ENDIF
         lFound := .T.
         AddLine( aLines, hDecl[ "declLine" ] )
      ENDIF
   NEXT
   IF ! lFound
      RETURN "'" + cOld + "' is not a LOCAL of this function"
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

   LOCAL hHits := { => }, hClean := { => }, aStrHits := {}
   LOCAL cUp := Upper( cName )
   LOCAL nLen := hb_BLen( cText )
   LOCAL nAt := 1, nLine := 1, nCol := 1
   LOCAL cState := "code"            // code | dq | sq | br | lc | bc
   LOCAL cLineBuf := "", cStrBuf := "", cPrev1 := "", cPrev2 := ""
   LOCAL lLineStart := .T.
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
            IF cUp $ Upper( cStrBuf )
               AddLine( aStrHits, nLine )
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
         cState := "dq" ; cLineBuf += cCh ; nAt++ ; nCol++
      CASE cCh == "'"
         cState := "sq" ; cLineBuf += cCh ; nAt++ ; nCol++
      CASE cCh == "[" .AND. !( cPrev1 $ ")]}" ) .AND. ! IsIdChar( cPrev1 )
         cState := "br" ; cLineBuf += cCh ; nAt++ ; nCol++
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

   RETURN { "hits" => hHits, "clean" => hClean, "strhits" => aStrHits }

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
