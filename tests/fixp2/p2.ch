// fixp2 - DSL INVENTADA nao-espelho (fase P, caso 109). Regua do caso 64:
// nenhuma palavra daqui aparece em src/hbrefactor.prg. Prova a FRONTEIRA
// do P2 (adr-003:87-90): um marker <n> que GERA (paste/stringify) E PASSA
// ADIANTE (clone <n> a um simbolo pre-existente FORA da expansao), e os
// cantos extremos (multiplicidade - o pp nao limita quantos usos no
// destino). Veredito: `generates` vence -> rename-pp-marker; a seguranca e
// ESTRUTURAL - a rede dupla (recompilacao -es2 + simbolos/identidade do
// .hrb) confere o ARTEFATO COMPILADO FINAL, indiferente a multiplicidade.
// Todo caso e rollback honesto OU re-derivacao verificada; nunca corrupcao
// silenciosa.

// (1) stringify (<"n">, gera STRING) + clone (<n>, referencia LOCAL externo)
#xtranslate LOG <n> => QOut( <"n">, <n> )

// (2) paste (w_<n>, gera SIMBOLO de funcao) + clone (<n>(), chamada a FUNCAO externa)
#xcommand WRAP <n> => FUNCTION w_<n>() ;; RETURN <n>()

// (3) MULTIPLICIDADE: o mesmo <n> colado 2x (g_, h_) e stringificado 2x - o
//     pp nao poe teto no numero de usos no destino; o fecho de artefatos
//     tem de prever TODOS
#xcommand SNAP <n> => FUNCTION g_<n>() ;; RETURN <"n"> ;; FUNCTION h_<n>() ;; RETURN <"n">
