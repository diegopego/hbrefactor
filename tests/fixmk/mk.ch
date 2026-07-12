// fixmk (fase P, P4+P5): DSL inventada nao-espelho que exercita TODOS os mkinds
// escriviveis do pp - 6 de match e 7 de result (strdump so existe em stream
// `#pragma __text`; dynval e interno do pp: `__FILE__`/`__LINE__` - os dois com
// RECUSA DOCUMENTADA no ast-schema). Regua do caso 64: nenhuma palavra daqui
// aparece em src/hbrefactor.prg.

// --- MATCH mkinds ---
#xcommand M_REG <x>                 => QOut( <x> )              // regular
#xcommand M_LST <x,...>             => QOut( <x> )              // list
#xcommand M_RST <x: LIGA, DESLIGA>  => QOut( <(x)> )            // restrict (VAZA)
#xcommand M_WLD <*x*>               => QOut( "wild" )           // wild (DESCARTA)
#xcommand M_EXT <(x)>               => QOut( <x> )              // extexp
#xcommand M_NAM <!x!>               => QOut( <"x"> )            // name

// --- RESULT mkinds ---
#xcommand R_STD <x>                 => QOut( <"x"> )            // strstd
#xcommand R_BLK <x>                 => QOut( Eval( <{x}> ) )    // block
#xcommand R_LOG <x>                 => QOut( <.x.> )            // logical (DESCARTA o valor)
#xcommand R_NUL <x> <y>             => QOut( <y> <-x-> )        // nul (DESCARTA)
