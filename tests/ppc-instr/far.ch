// regra de MIGRACAO (familia PP COMO INSTRUMENTO): DSL velha -> DSL nova.
// Serve para provar o que o canal `-u` isola e o que o `.ppo` DESTROI.
#xcommand ANTIGO <n> COM <v> => MODERNO <n> VALOR <v>

// ...e a DSL nova e' codigo de verdade. Sem isto o m.prg nao COMPILARIA -- e
// fixture que nao compila gera diagnostico enganoso (CLAUDE.md §3; ordem do Diego,
// 2026-07-14: "tem e' que garantir que vai compilar todos os exemplos").
// O passo INTERMEDIARIO (`MODERNO Alfa VALOR nX`) nao se perde: ele fica visivel no
// .ppt, que e' o oraculo do multi-passe -- e e' la' que a guarda o confere.
#xcommand MODERNO <n> VALOR <v> => far_Migrado( #<n>, <v> )
