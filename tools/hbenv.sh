#!/bin/sh
# ---------------------------------------------------------------------------
# FONTE ÚNICA da localização do harbour-core (branch feature/compiler-ast-dump).
#
# Antes, cada script e o Makefile tinham o caminho cravado como default próprio -
# mudar de layout obrigava a editar N arquivos. Aqui a detecção mora num lugar
# só; todos derivam.
#
# DOIS modos de uso:
#   . tools/hbenv.sh             -> define HB_CORE/HB_BIN/HB/ROOT/CORE no shell
#   sh tools/hbenv.sh --print HB_BIN  -> ecoa uma variável (para o Makefile
#                                        via $(shell ...))
#
# REGRA: um valor já presente no ambiente VENCE (override sempre respeitado);
# senão, escolhe o PRIMEIRO layout conhecido que de fato tem o binário `harbour`;
# se nenhum existe, cai no preferido (o novo) - o erro aponta o caminho pretendido.
# ---------------------------------------------------------------------------

if [ -z "${HB_CORE:-}" ]; then
   for _d in \
      "$HOME/devel/harbour-hbrefactor/harbour-core" \
      "$HOME/devel/harbour-core/harbour"; do
      if [ -x "$_d/bin/linux/gcc/harbour" ]; then HB_CORE="$_d"; break; fi
   done
   [ -z "${HB_CORE:-}" ] && HB_CORE="$HOME/devel/harbour-hbrefactor/harbour-core"
fi

# derivados de HB_CORE (a detecção), cada um respeitando um valor já exportado.
# NAMESPACE: HBREFACTOR_HB_BIN vem do FORK DETECTADO, nunca de um HB_BIN
# herdado - por isso um HB_BIN global de OUTRO harbour no computador NAO
# contamina o hbrefactor. Só um HBREFACTOR_HB_BIN explícito (make/extensao/
# usuario) o sobrescreve. O HB_BIN (make var / build) e' separado.
HB_BIN="${HB_BIN:-$HB_CORE/bin/linux/gcc}"           # Makefile (HBMK2) + fallback da ferramenta
HBREFACTOR_HB_BIN="${HBREFACTOR_HB_BIN:-$HB_CORE/bin/linux/gcc}"   # o que a ferramenta le PRIMEIRO
HB="${HB:-$HB_CORE}"                          # tests/lexdiff.sh
ROOT="${ROOT:-$HB_CORE}"                      # tools/pcode-identity.sh
CORE="${CORE:-$HB_CORE}"                      # tools/publish-core-site.sh

# modo --print: ecoa a variável pedida (só quando invocado explicitamente;
# sourceado, o $1 seria o argumento do script-pai, então exige o literal --print)
if [ "${1:-}" = "--print" ]; then
   eval "printf '%s\n' \"\${$2}\""
fi
