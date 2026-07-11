// DSL inventada NÃO-espelho (fase P, caso 108): dois jeitos de GERAR
// artefato do valor do marker - stringify puro e paste. A fixture colide
// o valor com uma FUNÇÃO real homônima para provar que a coleta de
// sementes só edita o que pertence ao marker POR FATO.
#xtranslate LABEL <n> => RegLabel( <"n"> )
#xcommand MAKE <n> => FUNCTION mk_<n>() ;; RETURN "mk"
