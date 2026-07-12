// DSL inventada NAO-espelho (P-AUDIT / ast-15): a keyword SECUNDARIA GRAV e
// prefixo de 4 letras da CABECA GRAVAR. Como #command (familia SEM 'x') casa
// abreviado a partir de 4 letras (dBase), um consumidor que ADIVINHE por texto
// nao consegue distinguir "GRAV escrito por extenso" (literal #2 da regra) de
// "GRAVAR abreviado". O pp SABE (ele casou); o ast-15 exporta o fato.
#command GRAVAR <x> GRAV <y> => zz_( <x>, <y> )

// e a mesma cabeca SEM a keyword colidente, para o uso ABREVIADO de verdade
#command APAGAR <x> => zz_( <x>, 0 )
