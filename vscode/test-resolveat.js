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

// 3. --show-expansion sempre-ligado (B5): o flag é só-rótulo do canal
// (o --json do peek é byte-idêntico com/sem ele) e cada invocação
// recompila o projeto - as DUAS consultas (posição e fallback) já levam
// o flag para a expansão não custar uma segunda compilação
check('consulta por posição leva --show-expansion',
  /\[\s*'usages',\s*c\.spec,\s*'--at',\s*at,\s*'--json',\s*json,\s*'--show-expansion'\s*\]/.test(src));
check('fallback de palavra crua leva --show-expansion',
  /\[\s*'usages',\s*c\.spec,\s*word,\s*'--json',\s*json,\s*'--show-expansion'\s*\]/.test(src));

// 4. a morte do methodQuery (V1): nenhuma promoção por regex de construto
// (menção em comentário é história legítima; definição/chamada não)
check('methodQuery não existe mais (nem definição nem chamada)',
  !/function methodQuery|methodQuery\(/.test(src));
check('nenhuma regex de bloco de classe na extensão',
  !/endclass/i.test(src) && !/create\\s\+\)\?class/i.test(src));

// 5. HB_BIN definitivo (0.7.2): sem default no setting, o host de
// desenvolvimento não passava HB_BIN, o CLI caía no hbmk2 do PATH (sem -x)
// e todo comando morria com "o projeto não compila" - default = layout do
// repo (mesmo do Makefile), e o run() tem que repassá-lo como env
const pkg = JSON.parse(fs.readFileSync(path.join(__dirname, 'package.json'), 'utf8'));
const hbBinDefault = pkg.contributes.configuration.properties['hbrefactor.hbBin'].default;
check('hbrefactor.hbBin tem default não-vazio (bin do fork, layout do repo)',
  /harbour.*bin/.test(hbBinDefault), '-> ' + JSON.stringify(hbBinDefault));
check('run() repassa hbBin como env HB_BIN com ~ expandido',
  /env\.HB_BIN = hb\.replace\(\/\^~\/, os\.homedir\(\)\)/.test(src));

// 6. picker ciente do arquivo (B5): a DECISÃO é pura (pickerChoices,
// extraída e executada aqui) e a PERGUNTA é fato do CLI (projects-of) -
// a extensão nunca parseia .hbp (réplica proibida). Degradações: pergunta
// falhada (null) e arquivo órfão ([]) caem para a lista completa, nunca
// escondem projeto.
const mp = src.match(/function pickerChoices\(all, owners\) \{[\s\S]*?\n\}/);
check('pickerChoices existe no extension.js', !!mp);
if (mp) {
  const pickerChoices = eval('(' + mp[0].replace(/^function pickerChoices/, 'function') + ')');
  const all = ['x.hbp', 'y.hbp', 'z.hbp'];
  let r = pickerChoices(all, null);
  check('pergunta falhada (null) -> oferece todos (degrada, nunca esconde)',
    r.auto === null && r.ask === all);
  r = pickerChoices(all, []);
  check('arquivo órfão ([]) -> oferece todos (comportamento antigo)',
    r.auto === null && r.ask === all);
  r = pickerChoices(all, ['y.hbp']);
  check('dono único -> projeto direto, SEM pergunta', r.auto === 'y.hbp' && r.ask === null);
  r = pickerChoices(all, ['x.hbp', 'z.hbp']);
  check('fonte compartilhada -> pergunta só entre os donos',
    r.auto === null && JSON.stringify(r.ask) === '["x.hbp","z.hbp"]');
}
check('a pergunta é fato do CLI: run projects-of com arquivo + candidatos + --json',
  /run\(\s*\[\s*'projects-of',\s*file\]\.concat\(candidates,\s*\['--json',\s*json\]\)/.test(src));
check('ctx passa o arquivo do editor ao picker (untitled fica de fora)',
  /projectSpec\(\s*editor\.document\.isUntitled\s*\?\s*null\s*:\s*editor\.document\.fileName\s*\)/.test(src));
check('relatórios de projeto inteiro não mudam: projCtx pergunta sem arquivo',
  /async function projCtx\(\) \{[\s\S]*?projectSpec\(\)[\s\S]*?\n\}/.test(src));
check('extensão não lê .hbp (o fato vem do hbmk2 via CLI)',
  !/readFileSync\([^)]*\.hbp/i.test(src) && !/hb[pc]'?\s*\)\s*\.map[^)]*parse/i.test(src));

// 7. annotate (B9 fatia 2 F2.4): a capacidade nova do CLI chega à extensão
// (regra "extensão sempre com os últimos recursos"). RELATÓRIO e --apply,
// os dois registrados; o --apply confirma ANTES de escrever fonte (modal)
// e só então roda 'annotate ... --apply'
check('hbrefactor.annotate registrado (relatório)',
  /registerCommand\('hbrefactor\.annotate',\s*cmdAnnotate\)/.test(src));
check('hbrefactor.annotateApply registrado (edição)',
  /registerCommand\('hbrefactor\.annotateApply',\s*cmdAnnotateApply\)/.test(src));
check('annotate relatório: roda annotate sem --apply (nenhuma edição)',
  /run\(\s*\[\s*'annotate',\s*c\.spec,\s*c\.file\s*\]\s*,\s*c\.cwd\s*\)/.test(src));
check('annotate --apply confirma (modal) ANTES de escrever fonte',
  /showWarningMessage\([\s\S]*?\{\s*modal:\s*true\s*\}[\s\S]*?\)/.test(src) &&
  /run\(\s*\[\s*'annotate',\s*c\.spec,\s*c\.file,\s*'--apply'\s*\]/.test(src));
const pkg2 = JSON.parse(fs.readFileSync(path.join(__dirname, 'package.json'), 'utf8'));
const cmds = pkg2.contributes.commands.map(x => x.command);
check('os dois comandos annotate no package.json (paleta os expõe)',
  cmds.includes('hbrefactor.annotate') && cmds.includes('hbrefactor.annotateApply'));

console.log('\n' + pass + ' pass, ' + fail + ' fail');
process.exit(fail ? 1 : 0);
