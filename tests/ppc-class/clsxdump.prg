// METODO-V2(2026-07-15): a IRMA raw-dumpavel de clsx.prg -- os fatos que so' o
// .ppt/dump mostra. (regua: docs/pp-corpus/METODO.md § 4)
//
// Familia hbclass (docs/pp-corpus/class.md). O clsx.prg prova, com asserts que
// RODAM, que o dialeto COMPILA e VALE; aqui ficam os fatos ESTRUTURAIS -- o que a
// diretiva VIRA, que na hbclass e' o .ppt (o dialeto sao dezenas de regras
// entrelacadas, nao da' para exercitar por pp vivo uma diretiva isolada).
//
// hbclass.ch NAO e' auto-incluida (precisa #include + -I <core>/include).
//
// O QUE ANCORA (guarda corpus_class), no .ppt de UMA classe minima:
//   - o PASTE do nome da funcao gerada: Conta + _ + Deposita -> Conta_Deposita
//     (a concatenacao de tokens, P1/P2);
//   - a diretiva que GERA outra diretiva: o METHOD (decl) emite um #xcommand que
//     reconhece a IMPL `METHOD Deposita CLASS Conta` (genealogia ast-13, 'from');
//   - a impl nasce com o Self TIPADO: local Self AS CLASS Conta := QSelf() (RD/M-B).
#include "hbclass.ch"

CREATE CLASS Conta
   VAR nSaldo INIT 0
   METHOD Deposita( nValor )
ENDCLASS

METHOD Deposita( nValor ) CLASS Conta
   ::nSaldo += nValor
   RETURN Self
