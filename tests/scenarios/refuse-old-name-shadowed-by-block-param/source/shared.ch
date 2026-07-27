// header compartilhado do fixture 01
#define K_LIMITE 4
// marker duplo: stringify + passthrough - rename do argumento muda o pcode
// (string literal) e DEVE ser barrado pela verificacao -gh -l com rollback
#xcommand MOSTRA <v> => QOut( <"v">, <v> )
