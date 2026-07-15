// METODO-V2(2026-07-15): a IRMA raw-dumpavel de setx.prg -- os fatos que so' o
// dump/oraculo mostra. (regua: docs/pp-corpus/METODO.md § 4)
//
// Familia SET - SET EXACT (docs/pp-corpus/set-exact.md). O setx.prg prova, com
// asserts que RODAM, o que a diretiva VIRA (o texto) e VALE (o flag); aqui ficam
// os fatos ESTRUTURAIS do dump.
//
// std.ch e' AUTO-incluida; NAO incluir explicito (duplicaria os #define -> W0002/-es2).
//
// O QUE ANCORA (guarda corpus_set):
//   - .ppt: os DOIS passes por linha -- #command emite Set( _SET_EXACT, "ON" ), e
//     depois o #define transforma _SET_EXACT em 1 (std.ch:121);
//   - ast: o match traz o marker mkind 'restrict' (<x:ON,OFF,&>: so' ON/OFF/& casam)
//     e o result traz mkind 'strsmart' (<(x)>: palavra nua vira string, expressao
//     entre parenteses passa crua) -- a ponte com P4/P5.
PROCEDURE Main()
   LOCAL lFlag := .T.
   SET EXACT ON
   SET EXACT OFF
   SET EXACT (lFlag)
   RETURN
