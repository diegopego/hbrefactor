// METODO-V2(2026-07-15): a IRMA raw-dumpavel de sayx.prg -- os fatos que so' o
// dump/oraculo mostra. (regua: docs/pp-corpus/METODO.md § 4)
//
// Familia @ ... SAY (docs/pp-corpus/say.md). O sayx.prg prova, com asserts que
// RODAM, o que cada forma VIRA (selecao DevOut x DevOutPict); aqui ficam os fatos
// ESTRUTURAIS do dump.
//
// O QUE ANCORA (guarda corpus_say):
//   - .ppo: sem opcionais -> DevOut; [PICTURE] -> DevOutPict; o grupo opcional do
//     result [, <clr>] so' emite a cor quando COLOR casou;
//   - ast: os grupos opcionais [PICTURE]/[COLOR] chegam como roles opt-open/opt-close
//     (std.ch:249). E' o mesmo mecanismo do [,<vN>] do STORE -- so' que ali o grupo
//     REPETE, e aqui casa 0 ou 1 vez (presenca).
PROCEDURE Main()
   LOCAL nX := 42, cName := "Ana"
   @ 1, 1 SAY "Ola"
   @ 2, 1 SAY nX PICTURE "999"
   @ 3, 1 SAY nX PICTURE "999" COLOR "R/W"
   @ 4, 1 SAY cName COLOR "W/B"
   RETURN
