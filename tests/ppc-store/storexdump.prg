// METODO-V2(2026-07-15): a IRMA raw-dumpavel de storex.prg -- os fatos que so' o
// dump/oraculo mostra e nao tem valor em runtime. (regua: docs/pp-corpus/METODO.md § 4)
//
// Familia STORE (docs/pp-corpus/store.md). O storex.prg prova, com asserts, o que
// a diretiva VIRA e VALE; aqui ficam os fatos ESTRUTURAIS do dump.
//
// O QUE ANCORA (guarda corpus_store):
//   - .ppo: STORE 0 TO a -> `a := 0`; STORE 9 TO a,b,c -> `a := b := c := 9`
//     (o grupo opcional [,<vN>] repetiu uma vez por variavel extra);
//   - ast: o [,<vN>] chega como grupo opcional (role opt-open/opt-close), e o <vN>
//     e' marker REGULAR dentro dele -- NAO e' mkind 'list'. A "lista" nasce da
//     REPETICAO do grupo, nao de um marker de lista (std.ch:78).
PROCEDURE Main()
   LOCAL a, b, c
   STORE 0 TO a
   ? a
   STORE 9 TO a, b, c
   ? a, b, c
   RETURN
