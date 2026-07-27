#!/bin/sh
# ---------------------------------------------------------------------------
# Dependências EXTERNAS da suíte (Diego, 2026-07-26: *"o correto é colocar logo
# no makefile a instalação das dependências"*).
#
# NÃO são dependências do hbrefactor - ele é um ELF único, compilado pelo
# harbour do fork. São dos TESTES:
#   - `node`, que roda o harness da extensão VSCode (a extensão é JS);
#   - `go`, que roda a suíte da classe A (tests-go/). O compilador é o portão
#     de tipos, e o `go test` traz descoberta, tmp e paralelismo prontos;
#   - `python3`, que roda os utilitários de tools/ e as sondas do pp-corpus
#     (só a stdlib - nenhum pacote a instalar).
#
# `hbtest` (do harbour-core) segue sendo o certo para a suíte EXPLORATÓRIA do
# pp - lá o objeto de estudo é Harbour, e escrever o teste em Harbour dá acesso
# direto ao pp vivo.
#
# O Go vem do SITE OFICIAL, não do apt: a versão do apt fica anos atrás, e o
# toolchain fora de passo é erro de build que berra.
#
# POR QUE UM ALVO PRÓPRIO, e não acoplado ao `make test`: instalar pacote no
# sistema é efeito colateral invasivo, pede sudo, e está errado em CI/container.
# A mesma regra do `make setup-env`. O teste que precisa da dependência FALHA
# nomeando-a e apontando para cá - nunca pula em silêncio.
#
# Uso:  tools/deps.sh            instala o que falta (pede sudo se precisar)
#       tools/deps.sh --check    só relata (exit 1 se falta alguma)
# ---------------------------------------------------------------------------
set -u

CHECK=no
[ "${1:-}" = "--check" ] && CHECK=yes

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# --- o venv da camada de controle, numa função só --------------------------
# UMA função porque o fluxo tem dois caminhos (com e sem instalação apt antes)
# e duas cópias divergiriam - foi o que aconteceu na primeira versão deste
# script, escrita hoje.
GO_VERSAO="go1.26.5"
GO_DIR="$HOME/.local/go"

go_garante() {
   if command -v go > /dev/null 2>&1 || [ -x "$GO_DIR/bin/go" ]; then
      GO=$(command -v go 2>/dev/null || echo "$GO_DIR/bin/go")
      printf '  ok      %-7s %s\n' "go" "$("$GO" version 2>&1 | cut -d" " -f3-4)"
      return 0
   fi
   printf '  FALTA   %-7s %s\n' "go" "testes do hbrefactor (tests-go/)"
   [ "$CHECK" = yes ] && return 1
   echo
   echo "baixando o $GO_VERSAO do site oficial (o apt fica anos atrás)"
   tgz="$(mktemp -d)/go.tgz"
   if ! curl -fsSL -o "$tgz" "https://go.dev/dl/$GO_VERSAO.linux-amd64.tar.gz"; then
      echo "  falhou baixar - instale à mão de https://go.dev/dl/"; return 1
   fi
   mkdir -p "$HOME/.local"
   rm -rf "$GO_DIR"
   tar -C "$HOME/.local" -xzf "$tgz" || return 1
   rm -f "$tgz"
   printf '  ok      %-7s %s (em %s)\n' "go" "$("$GO_DIR/bin/go" version | cut -d" " -f3)" "$GO_DIR"
   echo "  (acrescente ao PATH: export PATH=\$HOME/.local/go/bin:\$PATH)"
   return 0
}

# --- comandos de sistema ---------------------------------------------------
# a tabela é `comando|pacote-apt|para-que-serve`, lida por LINHA (a descrição
# tem espaços - separar por espaço quebrava a tabela em pedaços)
missing=""
echo "dependências externas da suíte:"
while IFS='|' read -r cmd pkg why; do
   [ -n "$cmd" ] || continue
   if command -v "$cmd" > /dev/null 2>&1; then
      printf '  ok      %-7s %s\n' "$cmd" "$why"
   else
      printf '  FALTA   %-7s %s  -> pacote %s\n' "$cmd" "$why" "$pkg"
      missing="$missing $pkg"
   fi
done <<'EOF'
node|nodejs|harness da extensão VSCode (a extensão é JS, o harness dela também)
python3|python3|utilitários de tools/ e sondas do pp-corpus (só stdlib)
curl|curl|baixar o Go do site oficial
EOF

# --- instalação ------------------------------------------------------------
if [ -n "$missing" ]; then
   [ "$CHECK" = yes ] && exit 1
   if ! command -v apt-get > /dev/null 2>&1; then
      echo
      echo "este script instala via apt-get (Debian/Ubuntu). Noutro sistema, instale"
      echo "à mão os pacotes:$missing"
      exit 1
   fi
   SUDO=""
   [ "$(id -u)" -ne 0 ] && SUDO="sudo"
   echo
   echo "instalando:$missing"
   echo "  ($SUDO apt-get install -y$missing - vai pedir a sua senha)"
   # shellcheck disable=SC2086
   $SUDO apt-get install -y $missing || exit 1
   echo
fi

go_garante || exit 1

echo
echo "tudo pronto."
