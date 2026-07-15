// METODO-V2(2026-07-15): comentario INTERPRETA o oraculo; cada afirmacao esta' provada
// por assert que passa PELO pp vivo. (regua: docs/pp-corpus/METODO.md § 4b)
// COMPLETUDE(2026-07-15): COMPLETE
//   O loop dos 4 oraculos convergiu: a familia prova live-pp == build-pp, e a AST e' a
//   SAIDA do build-pp -- o que a ferramenta consome. Ela carrega a migracao completa
//   com proveniencia (far_Migrado: Alfa=stringify/dado, nX=clone/simbolo posicionado).
//   Logo o fato ao qual o pp VIVO e' provado equivalente esta' COBERTO na AST: a
//   ferramenta pode usar qualquer um dos dois motores e obtem o mesmo fato. O check
//   COMPLETUDE(ppc-live=COMPLETE) em corpus_pplive le' a AST e afirma isso.
//
// Familia PP VIVO (P11, docs/pp-corpus/pp-as-instrument.md § 4). O pp do core EM
// PROCESSO, dirigido por codigo Harbour: __pp_Init cria um estado, __pp_Process
// registra a regra e transforma linha a linha -- SEM compilar, SEM executar o alvo.
//
// A prova e' de EQUIVALENCIA (camada A): registra a MESMA regra do far.ch (o ANTIGO)
// e alimenta o MESMO site do m.prg. O estado aqui tem SO' o ANTIGO -> ele para em
// `MODERNO Alfa VALOR nX`, que e' exatamente o passo INTERMEDIARIO que o .ppt do pp do
// BUILD mostra (a guarda corpus_pplive cruza os dois). Mesmo motor, nao uma imitacao.
//
// NAO incluir far.ch: se a regra estivesse registrada no COMPILADOR, a string de
// entrada 'ANTIGO Alfa COM nX' expandiria ANTES de chegar ao __pp_Process em runtime
// (a armadilha do METODO.md § 4). Aqui ela chega crua, e so' o pp VIVO a transforma.
//
// COMO RODAR:  hbmk2 live.prg <core>/contrib/hbtest/hbtest.hbc -w3 -es2 -gtcgi

#include "hbtest.ch"

PROCEDURE Main()

   LOCAL pp := __pp_Init( , "", .F. )   // isolado: sem std rules, sem arch defines

   __pp_Process( pp, '#xcommand ANTIGO <n> COM <v> => MODERNO <n> VALOR <v>' )

   // (1) o SPAN da statement: o pp vivo devolve o MESMO texto que o pp do BUILD grava
   //     no .ppo/.ppt. As posicoes de byte, quando a ferramenta escreve, vem do dump;
   //     aqui o que importa e' que o TEXTO transformado bate.
   HBTEST AllTrim( __pp_Process( pp, 'ANTIGO Alfa COM nX' ) ) IS "MODERNO Alfa VALOR nX"

   // (2) o LIMITE HONESTO: alimentando a LINHA INTEIRA (com o comentario de fim de
   //     linha), o pp COME o comentario. A destruicao NAO e' do canal de arquivo -- e'
   //     do que voce ALIMENTA. Por isso o escritor alimenta o SPAN, nunca a linha.
   HBTEST AllTrim( __pp_Process( pp, 'ANTIGO Alfa COM nX   // manter!' ) ) IS "MODERNO Alfa VALOR nX"

   RETURN
