// fixmk (fase P, P4+P5): DSL inventada nao-espelho que exercita TODOS os mkinds
// escriviveis do pp - 6 de match e 7 de result. (O strdump, o `#<x>`, tem
// familia PROPRIA no corpus - ppc-strdump/, docs/pp-corpus/strdump.md: ate
// 2026-07-13 esta fixture o dava como "so' em stream", e era FALSO. So' o
// dynval - `__FILE__`/`__LINE__`, interno do pp - segue com recusa documentada
// no ast-schema.) Regua do caso 64: nenhuma palavra daqui
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
