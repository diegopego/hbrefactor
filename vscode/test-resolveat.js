// Verificação do contrato de POSIÇÃO da extensão (Q5 da revisão de
// generalidade, mata o methodQuery por regex): extrai a função REAL do
// extension.js (não uma cópia), testa a conversão 0-based do editor ->
// 1-based do CLI (o off-by-one é o risco real), confere que o cmdUsages
// consulta por `usages --at` com fallback para a palavra crua, e ASSERTA
// a morte da heurística de construto. Os fatos da resolução em si são
// contrato do CLI (caso 81 da suíte).
// Rodar da raiz ou de qualquer lugar: node vscode/test-resolveat.js
const fs = require('fs');
const path = require('path');
const src = fs.readFileSync(path.join(__dirname, 'extension.js'), 'utf8');

let pass = 0, fail = 0;
function check(desc, ok, extra) {
  ok ? pass++ : fail++;
  console.log((ok ? 'PASS' : 'FAIL') + ' ' + desc + (extra ? ' ' + extra : ''));
}

// 1. a conversão real de posição
const m = src.match(/function atSpec\(file, line0, char0\) \{[\s\S]*?\n\}/);
check('atSpec existe no extension.js', !!m);
if (!m) { console.log('\n' + pass + ' pass, ' + fail + ' fail'); process.exit(1); }
const atSpec = eval('(' + m[0].replace(/^function atSpec/, 'function') + ')');

check('0-based do editor vira 1-based do CLI', atSpec('a.prg', 12, 10) === 'a.prg:13:11',
  '-> ' + atSpec('a.prg', 12, 10));
check('origem (0,0) vira 1:1', atSpec('x.prg', 0, 0) === 'x.prg:1:1');
check('nome de arquivo passa intacto', atSpec('sub dir.prg', 4, 2) === 'sub dir.prg:5:3');

// 2. cmdUsages consulta por POSIÇÃO numa única invocação
check('cmdUsages invoca usages --at com a posição',
  /run\(\s*\[\s*'usages',\s*c\.spec,\s*'--at',\s*at,/.test(src));
check('documento salvo ANTES da consulta (posição tem que casar com o disco)',
  src.indexOf('document.save()') > 0 && src.indexOf('document.save()') < src.indexOf("'--at'"));
check('fallback para a palavra crua quando o CLI recusa a posição',
  /nenhum identificador/.test(src) && /\[\s*'usages',\s*c\.spec,\s*word,/.test(src));

// 3. a morte do methodQuery (V1): nenhuma promoção por regex de construto
// (menção em comentário é história legítima; definição/chamada não)
check('methodQuery não existe mais (nem definição nem chamada)',
  !/function methodQuery|methodQuery\(/.test(src));
check('nenhuma regex de bloco de classe na extensão',
  !/endclass/i.test(src) && !/create\\s\+\)\?class/i.test(src));

console.log('\n' + pass + ' pass, ' + fail + ' fail');
process.exit(fail ? 1 : 0);
