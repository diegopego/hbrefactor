// fixdado (P16 a, revisado 2026-07-22) - o FATO op:"stream" no papel de
// SUPRESSAO, nunca de busca.
//
// O relato "possible reference in string" existe para um MECANISMO real: uma
// string ESCRITA igual a um nome pode virar chamada-por-nome (&(), __mvGet).
// A MESMA palavra como linha de um bloco de stream e' DADO impresso, sem
// mecanismo nenhum - so' coincidencia de letras. O fato op:"stream" (ast-18)
// deixa o tool SABER, por FATO, que a linha e' dado, e CALAR sobre ela - sem
// NUNCA buscar o texto do nome dentro do dado (isso seria gatilho 1: casar
// TEXTO para afirmar identidade). Compila limpo sob -w3 -es2.

PROCEDURE Main()

   LOCAL cIsca := "Farol"    // string ESCRITA = o nome: chamada-por-nome possivel

   // a linha do bloco esta' DEDENTADA de proposito: assim a string fabricada
   // e' exatamente "Farol" (== o nome) - o candidato que o fato tem de suprimir.
   TEXT
Farol
   ENDTEXT

   ? cIsca, Farol(), Apoio()

   RETURN

FUNCTION Farol()

   RETURN 7
