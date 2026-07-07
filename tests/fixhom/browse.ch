// B4f-3 fatia 2 (alinhamento do Diego): a generalidade também é de
// COMANDOS NOVOS que embrulham classes JÁ EXISTENTES (pseudo-exemplo:
// `#command mybrowse <a> <b> => tbrowse`) - a instância e o send passam a
// existir só na EXPANSÃO; o fonte escrito só tem o comando. Nenhuma
// destas palavras existe no hbrefactor nem no core.

#command MYBROWSE <var> AT <n> => <var> := Grade():New( <n> )
#command MYLOUSA <var> AT <n> => <var> := Lousa():New( <n> )
#command MYPAINT <var> => <var>:Pintar()

// embrulho de classe de FORA do projeto (TBrowse real, da RTL): o fato de
// classificação não existe no projeto - camada honesta, nunca excluded
#command MYTELA <var> AT <n> => <var> := TBrowse():New( <n> )
