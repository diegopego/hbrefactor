// Q4 m1: as donas. TEMPERA carrega o FORJADOR na linha da declaracao -
// Lousa forja o Totem mas NAO e pai dele; PedraBase/AfiaPedra sao funcoes
// comuns (candidatas a falso pai DE FORA do grafo).
#include "arsenal.ch"

ARMA Lousa TEMPERA PedraBase
GUME Pintar GIVES Lousa
ENDARMA

AFIA Pintar OF Lousa RETORNA 7

ARMA Totem TEMPERA Lousa
GUME Rodar GIVES Totem
ENDARMA

AFIA Rodar OF Totem RETORNA 3

ARMA Faca TEMPERA AfiaPedra
GUME Lamina GIVES Faca
ENDARMA

AFIA Lamina OF Faca RETORNA 1

FUNCTION PedraBase()
   RETURN 0

FUNCTION AfiaPedra()
   RETURN 0
