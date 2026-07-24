// Familia COMPILACAO CONDICIONAL (P17) - o ramo DESLIGADO.
//
// Compilado SEM -DVERSAO_DEMO: o bloco do #ifdef nao vira codigo, nao vira
// erro, nao vira nada -- o pp o pula. Hoje ele some de TODOS os oraculos
// (.ppo vira linha em branco, .ppt fica mudo, dump nao cita), e por isso a
// ferramenta renomeia `AvisaLimite` e anuncia "verified" com o ramo desligado
// ainda apontando para o nome velho.
//
// O que este fixture prova: o pp LE aquelas linhas (quebra em tokens) antes de
// descartar -- entao o fato existe do lado de dentro e so' falta ser contado.

#ifdef VERSAO_DEMO
   #xcommand PINTA <x> => pt_Rascunho( <x> )
#else
   #xcommand PINTA <x> => pt_Final( <x> )
#endif

PROCEDURE Main()

   LOCAL nQuantas := 0

#ifdef VERSAO_DEMO
   AvisaLimite( 50 )
#endif

   PINTA nQuantas

   RETURN

PROCEDURE pt_Final( n )

   QOut( "final:", n )

   RETURN

PROCEDURE AvisaLimite( nMax )

   QOut( "limite:", nMax )

   RETURN
