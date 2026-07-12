// Familia PP VIVO (P11): o pp do core EM PROCESSO, dirigido por codigo Harbour.
// Registra a MESMA regra do ppc-instr/far.ch e alimenta o MESMO site do m.prg -
// a saida e comparada com o .ppo do pp do BUILD (prova de equivalencia).
PROCEDURE Main()

   LOCAL pp := __pp_init( , "", .F. )   // isolado: sem std rules, sem arch defines

   __pp_process( pp, '#xcommand ANTIGO <n> COM <v> => MODERNO <n> VALOR <v>' )

   // (1) so o SPAN da statement (o que a ferramenta alimentaria: as posicoes
   //     de byte vem do dump) -> tem de bater com o pp do BUILD
   OutStd( "SPAN=[" + __pp_process( pp, 'ANTIGO Alfa COM nX' ) + "]" + hb_eol() )

   // (2) a LINHA INTEIRA, com o comentario de fim de linha: o pp COME o
   //     comentario. A destruicao nao e do canal de arquivo - e do que voce
   //     ALIMENTA. Por isso o escritor alimenta o span, nunca a linha.
   OutStd( "LINHA=[" + __pp_process( pp, 'ANTIGO Alfa COM nX   // manter!' ) + "]" + hb_eol() )

   RETURN
