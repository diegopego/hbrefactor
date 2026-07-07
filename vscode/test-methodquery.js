// Verificação da heurística methodQuery da extensão (lifting de método no
// find-references, fatia B4f-2 da B5): extrai a função REAL do extension.js
// (não uma cópia) e a exercita contra fixtures reais da suíte + sintéticos.
// Rodar da raiz ou de qualquer lugar: node vscode/test-methodquery.js
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '..');
const src = fs.readFileSync(path.join(__dirname, 'extension.js'), 'utf8');
const m = src.match(/function methodQuery\(document, line, word\) \{[\s\S]*?\n\}/);
if (!m) { console.error('methodQuery não encontrada no extension.js'); process.exit(1); }
const methodQuery = eval('(' + m[0].replace(/^function methodQuery/, 'function') + ')');

function doc(lines) {
  return { lineAt: i => ({ text: lines[i] }), lines };
}
function fileDoc(file) {
  return doc(fs.readFileSync(path.join(root, file), 'utf8').split('\n'));
}

let pass = 0, fail = 0;
function check(desc, d, where, line0, word, expected) {
  const got = methodQuery(d, line0, word);
  const ok = got === expected;
  ok ? pass++ : fail++;
  console.log((ok ? 'PASS' : 'FAIL') + ' ' + desc +
    ' [' + where + ':' + (line0 + 1) + ' "' + (d.lines[line0] || '').trim() + '"]' +
    ' word=' + word + ' -> ' + JSON.stringify(got) +
    (ok ? '' : ' (esperado ' + JSON.stringify(expected) + ')'));
}

// fixtures reais (fixdis/d1.prg: as duas classes homônimas do caso 66)
const d1 = fileDoc('tests/fixdis/d1.prg');
const c1 = fileDoc('tests/fixmth/c1.prg');
check('impl externa', d1, 'fixdis/d1.prg', 22, 'Paint', 'UWMain:Paint');
check('impl externa 2a classe', d1, 'fixdis/d1.prg', 40, 'Paint', 'UWSecondary:Paint');
check('proto no bloco', d1, 'fixdis/d1.prg', 12, 'Paint', 'UWMain:Paint');
check('proto 2a classe (não vaza p/ a 1a)', d1, 'fixdis/d1.prg', 30, 'Paint', 'UWSecondary:Paint');
check('proto CONSTRUCTOR', d1, 'fixdis/d1.prg', 28, 'New', 'UWSecondary:New');
check('METHOD INLINE', c1, 'fixmth/c1.prg', 6, 'Dobro', 'Caixa:Dobro');
const sendLine = d1.lines.findIndex(l => /:Paint\(\)/.test(l) && !/^\s*METHOD/i.test(l));
check('send site -> null (consulta crua)', d1, 'fixdis/d1.prg', sendLine, 'Paint', null);
check('word = nome da classe na impl -> null', d1, 'fixdis/d1.prg', 22, 'UWMain', null);

// sintéticos: ACCESS/ASSIGN, CLASS sem CREATE, FROM, protótipo órfão
const synth = doc([
  'CLASS Widget FROM UWMain, UWSecondary',
  '   ACCESS Ping INLINE ::nP',
  '   ASSIGN Ping( x ) INLINE ::nP := x',
  '   METHOD Paint()',
  'ENDCLASS',
  '',
  'METHOD Paint() CLASS Widget',
  'RETURN Self',
  '',
  'FUNCTION Solta()',
  'RETURN NIL',
  '   METHOD Orfao()',
]);
check('ACCESS no bloco', synth, 'synth', 1, 'Ping', 'Widget:Ping');
check('ASSIGN no bloco', synth, 'synth', 2, 'Ping', 'Widget:Ping');
check('proto com CLASS-sem-CREATE + FROM', synth, 'synth', 3, 'Paint', 'Widget:Paint');
check('impl externa CLASS-sem-CREATE', synth, 'synth', 6, 'Paint', 'Widget:Paint');
check('proto órfão abaixo de FUNCTION -> null', synth, 'synth', 11, 'Orfao', null);

console.log('\n' + pass + ' pass, ' + fail + ' fail');
process.exit(fail ? 1 : 0);
