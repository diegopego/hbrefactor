// DSL INVENTADA da fixture B4d - prova de futuro (G6): nenhuma destas
// diretivas existe em include do core e a ferramenta não menciona nenhuma
// palavra daqui; tudo que usages/rename fazem com elas sai do rastro de
// derivação ("from") do dump ast-3.

// G2 - colagem por PREFIXO (sem o '_' de sufixo do padrão hbclass)
#xcommand HANDLER <n> => FUNCTION on_<n>() ;; RETURN "on"

// G4 - o mesmo nome CLONADO (local), COLADO (reg_) e STRINGIFICADO,
// tudo na MESMA regra
#xcommand REGISTRO <n> => FUNCTION reg_<n>() ;; LOCAL <n> := <"n"> ;; RETURN Anota( <n> )

// uso derivado: o site de CHAMADA também nasce do nome escrito
#xcommand DISPARA <n> => ? reg_<n>()

// G5 - artefato colado de DOIS nomes
#xcommand LIGA <a> COM <b> => FUNCTION <a>_<b>() ;; RETURN <"a"> + "-" + <"b">

// G3 - stringify puro no meio de statement
#xtranslate EVENTO <n> => Anota( <"n"> )
