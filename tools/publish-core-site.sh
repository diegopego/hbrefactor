#!/usr/bin/env bash
# tools/publish-core-site.sh - publica a PROPOSTA AOS MANTENEDORES
# (harbour-core/site/index.html) como a landing page do fork, no GitHub Pages.
#
# POR QUE um branch gh-pages ÓRFÃO, e não servir do próprio branch de trabalho:
# o GitHub Pages só serve da RAIZ ou de /docs de um branch - nunca de /site. E o
# branch `feature/compiler-ast-dump` é UPSTREAMÁVEL: tudo que vive nele entra no
# diff do PR, e a landing page do fork do Diego não tem o que fazer num PR para
# o harbour/core (são 436 linhas de ruído). O branch órfão resolve os dois: URL
# estável, e ZERO bytes no diff do PR.
#
# "Órfão" só quer dizer que ele não compartilha histórico com o branch de
# trabalho. ATUALIZAR é um commit normal - este script é idempotente e pode
# rodar quantas vezes for preciso.
#
# A FONTE continua sendo `site/index.html` no branch de trabalho (é lá que a
# skill /update-manual a mantém). Este script só a DERIVA: copia para a raiz do
# gh-pages e reescreve os links relativos, que quebrariam quando servidos da
# raiz do site.

set -euo pipefail

CORE="${CORE:-$HOME/devel/harbour-core/harbour}"
BR_FONTE="feature/compiler-ast-dump"
FORK="diegopego/harbour-core"

cd "$CORE"
[ -f site/index.html ] || { echo "site/index.html não existe em $CORE"; exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# links relativos -> absolutos (na raiz do Pages não existe NEWS.md ao lado)
BLOB="https://github.com/$FORK/blob/$BR_FONTE"
sed -e "s|href=\"NEWS.md\"|href=\"$BLOB/NEWS.md\"|g" \
    -e "s|href=\"ChangeLog.txt\"|href=\"$BLOB/ChangeLog.txt\"|g" \
    site/index.html > "$TMP/index.html"

# .nojekyll: sem ele o Jekyll do Pages engole arquivos iniciados por _ e pode
# reprocessar o HTML - a página é estática e auto-contida, não quer nada disso
touch "$TMP/.nojekyll"

WT=$(mktemp -d)
if git show-ref --verify --quiet refs/remotes/origin/gh-pages; then
   git worktree add -f "$WT" -b gh-pages-tmp origin/gh-pages > /dev/null 2>&1
else
   git worktree add -f --detach "$WT" > /dev/null 2>&1
   ( cd "$WT" && git checkout --orphan gh-pages-tmp > /dev/null 2>&1 && git rm -rf . > /dev/null 2>&1 || true )
fi

cp "$TMP/index.html" "$TMP/.nojekyll" "$WT/"
cd "$WT"
git add -A
if git diff --cached --quiet; then
   echo "gh-pages: nada mudou (a página publicada já está em dia)"
else
   git commit -q -m "site: publish the maintainer-facing page for $BR_FONTE"
   git push -q -f origin gh-pages-tmp:gh-pages
   echo "gh-pages: publicado"
fi

cd "$CORE"
git worktree remove --force "$WT" > /dev/null 2>&1 || true
git branch -D gh-pages-tmp > /dev/null 2>&1 || true

echo "URL: https://diegopego.github.io/harbour-core/"
