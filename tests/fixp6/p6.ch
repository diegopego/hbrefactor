// DSL INVENTADA NAO-espelho (fase P/P6 - ESTRUTURA DA REGRA). Nenhuma destas
// palavras existe em include do core nem e mencionada por src/hbrefactor.prg
// (regua do caso 64): tudo que a ferramenta faz aqui sai dos FATOS do dump.

// (1) regra SEM CABECA - o match comeca com um MARKER, nao com uma palavra
//     ("head": null no dump; ppcore.c:1284 szHead = NULL quando o 1o token de
//     match e marker). O backlog pedia "fixture de RELATO"; o fato e que a
//     ferramenta ja resolve/renomeia por CONSTRUCAO - nunca chaveia no head,
//     so em marker-0 (literal da regra) e nas posicoes de match[]/result[]
#xtranslate <x> ZORBADO => ( <x> * 2 )

// (2) dois grupos OPCIONAIS: o pp casa em QUALQUER ORDEM (e ausentes tambem)
#xcommand VULK <n> [ KRAN <cMat> ] [ PLIX <nPeso> ] => ;
          FUNCTION vk_<n>() ;; RETURN { <"n">, <cMat>, <nPeso> }

// (3) MULTI-PASSE: o resultado desta regra e RE-CONSUMIDO pela VULK acima
#xcommand GLIMER <n> => VULK <n> KRAN "base"

// (4) grupos opcionais numa regra que expande DENTRO da statement: o valor que
//     ATRAVESSA (clone/pass-through) e um LOCAL de verdade - a posicao do site
//     tem de sobreviver a REORDENACAO dos grupos
#xcommand REGA <n> [ AGUA <cQ> ] [ SOL <nH> ] => rg_( <"n">, <cQ>, <nH> )
