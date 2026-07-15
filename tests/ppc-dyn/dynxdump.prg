// METODO-V2(2026-07-15): a IRMA raw-dumpavel de dynx.prg -- os fatos que so' o
// dump/oraculo mostra. (regua: docs/pp-corpus/METODO.md § 4)
//
// Familia DEFINE DINAMICO (docs/pp-corpus/dynval.md). O dynx.prg prova, com
// asserts que RODAM, as duas camadas (o pp vivo COLAPSA; o build SEGUE a
// posicao); aqui ficam os fatos ESTRUTURAIS do dump:
//   - .ppo: __LINE__ vira a LINHA CORRENTE do fonte e __FILE__ o nome do arquivo;
//   - ast: dynval existe em DUAS regras builtin (__FILE__/__LINE__) -- e SO' elas
//     (a recusa "o usuario nao escreve dynval" sobrevive a medicao: 0 em milhares
//     de regras reais; a ponte com P4/P5).

PROCEDURE Main()

   LOCAL nQuando := __LINE__
   LOCAL cOnde   := __FILE__

   ? nQuando, cOnde

   Registra()

   RETURN

STATIC PROCEDURE Registra()

   ? "log:", __LINE__

   RETURN
