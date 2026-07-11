// fixture da revisão (Codex #1): duas STATIC FUNCTION homônimas em módulos
// diferentes. O `rename` na posição sabe o ARQUIVO e passa --file ao motor,
// desambiguando o que o rename-function pelado recusaria ('use --file').
FUNCTION A()
   RETURN Helper() + 1
STATIC FUNCTION Helper()
   RETURN 1
