// fixture da fase U (revisão externa): homônimos que forçam o degrade
// honesto do verbo unificado. 'Dobra' é LOCAL em Main, FUNCTION em sh2.prg
// e FIELD em Calc; o `rename` resolve pela POSIÇÃO - chamada Dobra(...) é a
// função, 'Dobra' sozinho é o local, e o campo de RDD RECUSA (nenhum verbo
// o cobre). Nunca adivinha o símbolo errado.
PROCEDURE Main()

   LOCAL Dobra := 0

   Dobra := Dobra + 1
   ? Dobra, Dobra( Dobra )

   RETURN

FUNCTION Calc( nX )

   FIELD Dobra

   RETURN nX + Dobra

FUNCTION Cont()

   LOCAL Dobra := 1

   RETURN Dobra + ;
          Dobra( Dobra ) + ;
          1
