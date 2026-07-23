// METODO-V2(2026-07-14): revisado pelo metodo novo -- comentario INTERPRETA o
// oraculo (nao o transcreve), e o que ele afirma esta' provado por assert ou
// pelo dump. Prova: o bloco de stream vira DADO, verbatim e posicionado (ast-17).
// (regua: docs/pp-corpus/METODO.md § 4b)
// COMPLETUDE(2026-07-15; revisto 2026-07-22 apos a P16 fechar): COMPLETE
//   O loop dos 4 oraculos convergiu -- e ele FECHOU um buraco no caminho (ast-17/ast-18).
//   A AST cobre o que a ferramenta precisa para tratar a linha de bloco como DADO: ela
//   chega com a linha-fonte + col 0 + prov 's' (ast-17) e SELADA com `from op:"stream"`
//   (ast-18); o compilador NAO ve simbolo na linha (e' dado, nao variavel). O consumo
//   disso e' a fase P16(a), feature do CONSUMIDOR -- mas o dever entregue e' SUPRIMIR,
//   nao relatar: tudo num bloco de stream e' texto, entao uma palavra igual a um nome
//   ali e' coincidencia de letras, sem mecanismo de chamada-por-nome. O consumidor usa
//   o selo so' para CALAR (nao confundir o dado com uma referencia), jamais para busca-lo
//   -- buscar o nome dentro do dado seria gatilho 1 (identidade por texto). O check
//   COMPLETUDE(ppc-text=COMPLETE) em corpus_text le' a AST e afirma essa cobertura; o
//   consumo esta' provado no caso 125 (fixture fixdado).
// Fixture da familia TEXT/ENDTEXT (docs/pp-corpus/text-stream.md).
// Compila limpo sob -w3 -es2. Diretiva REAL: o `#command TEXT => text QOut, QQOut`
// do std.ch (grep a linha, nao a decore), que poe o pp em modo de STREAM.
//
// COMO COMPILAR:
//   sintaxe:  harbour txt.prg -n -q0 -w3 -es2 -s -I$HB_CORE/contrib/hbtest
//   rodar:    hbmk2  txt.prg $HB_CORE/contrib/hbtest/hbtest.hbc -w3 -es2 -gtcgi
//
// Os asserts capturam a saida do bloco redefinindo o `QOut` -- que e' o idioma dos
// proprios testes do core (contrib/.../clsscope.prg faz o mesmo). Assim o que o
// bloco produziu deixa de ser afirmacao minha e vira valor comparado.

#include "hbtest.ch"

// Tudo o que o TEXT emitir cai aqui, em vez de ir para a tela.
// Repare no que isto revela, e esta' no .ppo: as chamadas que o pp FABRICOU no modo
// de stream (`QOut( ... )`) sao re-escaneadas pelas regras -- a minha regra as pega.
// O pp nao "termina" quando emite: o que ele emite volta para a fila.
#xtranslate QOut( <x> ) => tx_Cap( <x> )

STATIC s_aLinhas := {}

PROCEDURE Main()

   LOCAL cSaldo := "1.234,00"

   // O pp entra em modo de STREAM na linha do TEXT e sai no ENDTEXT. As linhas do
   // meio nao passam pela maquinaria de regras: o dump mostra que a UNICA aplicacao
   // aqui consumiu um token so' -- a palavra `TEXT`. As duas linhas do bloco nao
   // casaram com nada, nao tem marker, nao sao recheio de coisa nenhuma.
   //
   // Elas viram argumento de chamada: o pp monta `QOut( <a linha crua> )` -- e monta
   // isso sozinho, fabricando um marker `strdump` (o `HB_PP_RMARKER_STRDUMP` que o pp
   // monta ao detectar a diretiva TEXT, em ppcore.c). Ninguem escreveu `%s` em lugar
   // nenhum.
   //
   // No dump, os dois `QOut` emitidos carregam a posicao da linha do TEXT (a chamada
   // pertence a' DIRETIVA), e cada STRING carrega a linha do bloco de onde saiu -- e'
   // o `ast-17`. Antes dele a string chegava com line 0 / col null: o conteudo do
   // bloco nao tinha origem nenhuma, e nada podia ser dito sobre ele.
   TEXT
   Relatorio mensal
   cSaldo apurado no periodo
   ENDTEXT

   // Duas linhas dentro do bloco, duas chamadas emitidas.
   HBTEST Len( s_aLinhas ) IS 2

   // A linha crua chega VERBATIM -- inclusive a margem de tres espacos que voce
   // digitou. O bloco nao e' codigo formatado: e' texto, byte a byte.
   HBTEST s_aLinhas[ 1 ] IS "   Relatorio mensal"

   // A cilada desta familia. A palavra `cSaldo` dentro do bloco e' o nome do LOCAL
   // declarado acima -- e nao vale nada disso: ela chega como TEXTO, dentro da
   // string. O compilador nunca ve uma variavel ali (o dump registra ocorrencias de
   // cSaldo so' na declaracao e no `? cSaldo` la' embaixo; a linha do bloco nao esta'
   // entre elas).
   // Se fosse simbolo, aqui viria o valor "1.234,00" no lugar do nome.
   HBTEST s_aLinhas[ 2 ] IS "   cSaldo apurado no periodo"

   // ...e a variavel de verdade continua intacta: o bloco nao a leu nem a escreveu.
   HBTEST cSaldo IS "1.234,00"

   // Consequencia para a ferramenta: renomear `cSaldo` NAO pode tocar a linha do
   // bloco -- seria editar DADO por coincidencia de nome. E o selo `op:"stream"`
   // (ast-18) faz mais: deixa a ferramenta SABER, por fato, que a linha e' dado e
   // CALAR sobre ela -- nao lista a coincidencia como "possible reference in string"
   // (o que so' cabe a uma string ESCRITA, candidata a chamada-por-nome). A edicao do
   // simbolo de verdade (`? cSaldo` abaixo) segue certa e verificada; o dado fica
   // intacto e silenciado, nao relatado. (Consumo provado no caso 125.)
   ? cSaldo

   RETURN

STATIC FUNCTION tx_Cap( cLinha )
   AAdd( s_aLinhas, cLinha )
   RETURN NIL
