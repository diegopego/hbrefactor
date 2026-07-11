// DSL inventada NÃO-espelho (fase P, caso 108): DEFREGRA <n> GERA uma
// regra nova em tempo de pp - o valor do marker vira palavra LITERAL da
// regra gerada (match) E string no resultado (stringify). É a genealogia
// de regra (ast-13): a regra USA nasce ligada à aplicação que a criou.
#xcommand DEFREGRA <n> => #xcommand USA <n> => ? Marca( <"n"> )
