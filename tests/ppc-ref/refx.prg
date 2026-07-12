// P-DOC corpus - familia <@> (reference): o GUARDA ANTI-RECURSAO do pp.
// Idioma REAL do hbfoxpro.ch:63 - a regra reemite a PROPRIA palavra que casa
// (PUBLIC, statement de verdade do Harbour). Sem o <@> isso seria loop
// infinito: a saida casaria a regra outra vez, para sempre.
#xtranslate __DIM( <exp> ) => <exp>
#command PUBLIC <var1> [, <varN> ] => ;
         <@> PUBLIC __DIM( <var1> ) [, __DIM( <varN> ) ]

MEMVAR nA, nB
PROCEDURE Main()
   PUBLIC nA, nB
   nA := 1
   nB := 2
   ? nA, nB
   RETURN
