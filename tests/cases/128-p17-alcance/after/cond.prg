// fixture da P17: COMPILACAO CONDICIONAL esconde codigo do alcance da prova.
//
// Compilado SEM -DVERSAO_DEMO, o bloco do #ifdef nao vira codigo nenhum: o pp
// o pula, e ate o ast-19 ele sumia de todos os oraculos. A chamada la' dentro
// referencia AvisaLimite, que e' declarada FORA do bloco (compila sempre).
//
// Renomear AvisaLimite edita a declaracao e mais nada -- e ate' agora o
// veredito dizia "verified: pcode byte-identical", que e' verdade sobre a
// configuracao compilada e mentira por omissao sobre a outra: com
// -DVERSAO_DEMO o projeto passa a chamar um nome que nao existe mais.

PROCEDURE Main()

   LOCAL nQuantas := 0

#ifdef VERSAO_DEMO
   AvisaLimite( 50 )
#endif

   nQuantas += Dobro( 3 )

   QOut( "quantas:", nQuantas )

   RETURN

FUNCTION Dobro( nX )

   RETURN nX * 2

PROCEDURE AvisaCota( nMax )

   QOut( "limite:", nMax )

   RETURN
