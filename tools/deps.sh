#!/bin/sh
# ---------------------------------------------------------------------------
# Dependências EXTERNAS da suíte (Diego, 2026-07-26: *"o correto é colocar logo
# no makefile a instalação das dependências"*).
#
# NÃO são dependências do hbrefactor - ele é um ELF único, compilado pelo
# harbour do fork. São dos TESTES: hoje só o `node`, que roda o harness da
# extensão VSCode (a extensão é JS, então o harness dela também é).
#
# POR QUE UM ALVO PRÓPRIO, e não acoplado ao `make test`: instalar pacote no
# sistema é efeito colateral invasivo, pede sudo, e está errado em CI/container.
# A mesma regra do `make setup-env`. O teste que precisa da dependência FALHA
# nomeando-a e apontando para cá - nunca pula em silêncio.
#
# Uso:  tools/deps.sh            instala o que falta
#       tools/deps.sh --check    só relata (exit 1 se falta alguma)
# ---------------------------------------------------------------------------
set -u

CHECK=no
[ "${1:-}" = "--check" ] && CHECK=yes

# a tabela é `comando|pacote-apt|para-que-serve`, lida por LINHA (a descrição
# tem espaços - separar por espaço quebrava a tabela em pedaços)
missing=""
echo "dependências externas da suíte:"
while IFS='|' read -r cmd pkg why; do
   [ -n "$cmd" ] || continue
   if command -v "$cmd" > /dev/null 2>&1; then
      printf '  ok      %-6s  %s\n' "$cmd" "$why"
   else
      printf '  FALTA   %-6s  %s  -> pacote %s\n' "$cmd" "$why" "$pkg"
      missing="$missing $pkg"
   fi
done <<'EOF'
node|nodejs|harness da extensão VSCode (a extensão é JS, o harness dela também)
EOF

[ -z "$missing" ] && { echo "nada a instalar."; exit 0; }
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
exec "$0" --check
