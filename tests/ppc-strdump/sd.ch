// Familia STRDUMP do corpus: o `#<x>` -- o mkind que a doc dava como
// INEXISTENTE em regra. Duas formas, as duas VIVAS no core:
//
//   (a) stringify de um NOME que tambem e simbolo de verdade
//       -- e a forma de hbclass.ch:576 (ASSOCIATE ... #<type>) e de
//          hbnf/ftmenuto.ch:67 (MENU TO <v> => <v> := ft_MenuTo( ..., #<v>, ... ))
//
//   (b) stringify de TEXTO arbitrario (recheio de wild): o que se escreve nao
//       e simbolo nenhum, e conteudo
//       -- e a forma de hbtest.ch:50 (HBTEST <x> IS <r> => hbtest_Call( #<x>, ... ))

#xcommand SELO <v> AFERIDO => <v> := sd_Afere( #<v> )

#xcommand LAVRA <*txt*>    => sd_Lavra( #<txt> )
