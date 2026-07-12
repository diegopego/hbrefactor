// DSL inventada NAO-espelho (P13/ast-16): a diretiva tem TEMPO DE VIDA.
// A regra vale do #xcommand ate o #xuncommand - depois disso a palavra volta
// a ser codigo cru. Antes do ast-16 o dump nao enxergava a remocao, e o rename
// da cabeca deixava o #xuncommand ORFAO: ele passava a desligar uma regra que
// nao existia mais, e a regra VAZAVA para o resto do arquivo, em silencio.
#xcommand LACRA <x> => uu_( <x>, 1 )
