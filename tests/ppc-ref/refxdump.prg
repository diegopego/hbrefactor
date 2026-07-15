// METODO-V2(2026-07-14): a IRMA raw-dumpavel de refx.prg -- ancora o que so' o
// DUMP/oraculo mostra e nao tem valor em runtime. (regua: docs/pp-corpus/METODO.md § 4)
//
// Familia <@> (docs/pp-corpus/reference-guard.md). O refx.prg prova, com asserts,
// o que o guarda VIRA e VALE; aqui ficam os fatos ESTRUTURAIS que so' aparecem no
// .ppo/.ppt/ast -- por isso o arquivo e' dumpavel pelo `harbour` cru (sem hbtest).
//
// O __DIM e' identidade aqui (como o __FP_DIM escalar de hbfoxpro.ch:60), para o
// .ppo mostrar o guarda SUMINDO e deixando o `PUBLIC nA, nB` intacto, sem ruido.
//
// O QUE ESTE ARQUIVO ANCORA (guarda corpus_ref):
//   - .ppo: o <@> some antes do compilador (ppcore.c:7019, o token reference e'
//     liberado do fluxo de saida); sobra o `PUBLIC nA, nB` reemitido;
//   - .ppt: a regra REEMITE `<@> PUBLIC __DIM(...)`, e o PUBLIC emitido NAO re-casa
//     a regra (o traco nao abre um segundo #command para ele) -- e' o guarda agindo;
//   - ast: o guarda chega como marker mkind 'reference', sem nome nem posicao
//     (text '~', col null; ppcore.c:4352) -- nao e' marker que se nomeia, e' um sinal.
#xtranslate __DIM( <exp> ) => <exp>
#command PUBLIC <var1> [, <varN> ] => ;
         <@> PUBLIC __DIM( <var1> ) [, __DIM( <varN> ) ]

MEMVAR nA, nB
PROCEDURE Main()
   PUBLIC nA, nB
   nA := 1
   nB := 2
   ? nA, nB
   RETURN
