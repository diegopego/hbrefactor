// fixture do ROLLBACK PROVOCADO (B9 fatia 2, resíduo 3 da F2.4): o fato
// DECLARADO mente sobre o runtime. Semântica da linha da mentira (fato
// do core, não interpretação): em `_HB_MEMBER ACHA() AS CLASS MOEDA` o
// PERTENCIMENTO vem da POSIÇÃO - o membro gruda na última classe
// declarada (pLastClass), aqui BAU - e o sufixo `AS CLASS` declara o
// TIPO DE RETORNO do método (hbclass.ch:282: `METHOD <m> AS <type>`
// vira exatamente este sufixo; CONSTRUCTOR vira `AS CLASS <própria>`
// porque o construtor DEVOLVE a instância). Dona e retorno são classes
// DIFERENTES de propósito, para as duas leituras não se confundirem.
// A mentira: Acha() promete devolver MOEDA e devolve NUMERIC. Promessa
// de membro NÃO é imposta pelo -kt (fato 6 do plano da escada), então
// este fonte compila E RODA limpo sob -kt - a mentira fica dormente.
// A análise decide por fato declarado (honestamente) e materializa
// LOCAL x AS CLASS MOEDA; o cheque pós-store da local anotada pega a
// contradição EM EXECUÇÃO sob -kt e o --apply desfaz TUDO byte a byte,
// nomeando o motivo. Este arquivo NUNCA é editado no lugar - os casos
// operam em cópia (WorkDir).
#include "hbclass.ch"

CREATE CLASS Moeda
   VAR nValor INIT 0
ENDCLASS

CREATE CLASS Bau
   VAR nOuro INIT 0
   METHOD Acha()
ENDCLASS

// a MENTIRA declarada: Acha() (método de BAU, por posição) promete
// DEVOLVER uma MOEDA; o runtime devolve N
_HB_MEMBER ACHA() AS CLASS MOEDA

METHOD Acha() CLASS Bau

   ::nOuro++

   RETURN ::nOuro

PROCEDURE Main()

   LOCAL b := Bau():New()
   LOCAL x := b:Acha()

   ? x

   RETURN
