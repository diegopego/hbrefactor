// METODO-V2(2026-07-15): a IRMA raw-dumpavel de genx.prg -- os fatos que so' o
// .ppt/dump mostra. (regua: docs/pp-corpus/METODO.md § 4)
//
// Familia REGRA QUE GERA REGRA (docs/pp-corpus/generated-rules.md). O genx.prg
// prova, com asserts que RODAM, que a regra nasce e casa (pp vivo) e o que ela
// VALE; aqui ficam os fatos ESTRUTURAIS -- o multi-passe no .ppt e a genealogia.
// Fixture NAO-espelho (regua caso 64).
//
// O QUE ANCORA (guarda corpus_gen):
//   - .ppt: DEFREGRA Ponto EMITE `#xcommand USA Ponto` (a regra nova), a linha
//     seguinte ja casa `USA Ponto` -> `? Marca( "Ponto" )`, e ainda passa pelo `?`
//     (tres passes numa compilacao);
//   - ast-13: a regra gerada carrega `from` -> a aplicacao (DEFREGRA) que a criou.
#xcommand DEFREGRA <n> => #xcommand USA <n> => ? Marca( <"n"> )

PROCEDURE Main()
   DEFREGRA Ponto      // cria, em tempo de pp, a regra `USA Ponto`
   USA Ponto           // usa a regra que acabou de nascer
   RETURN

FUNCTION Marca( c )
   RETURN c
