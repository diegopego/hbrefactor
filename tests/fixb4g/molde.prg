// molde.prg - B4g P5: regra definida DENTRO de expansao (padrao real do
// xhb/cstruct.ch: #xcommand cujo result emite outra diretiva; markers da
// regra INTERNA escapados com \< >). Fato 13 da spec-b4g: as posicoes da
// regra sintetizada sao REAIS (cabeca aponta o result da diretiva-mae,
// recheio aponta o site de uso).
#xcommand MOLDE <!n!> => #xtranslate CUNHO <n> => CunhoNovo( #<n> )

// regra interna COM marker proprio escapado
#xcommand MOLDE2 <!n!> => #xtranslate CUNHO2 <n> \<v> => CunhoNovo2( #<n>, \<v> )

PROCEDURE Main()

   LOCAL nC

   MOLDE Ferro
   nC := CUNHO Ferro
   ForjaNota( nC )

   MOLDE2 Aco
   nC := CUNHO2 Aco 7
   ForjaNota( nC )

   RETURN
