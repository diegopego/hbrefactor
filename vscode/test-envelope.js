// Verificação do CONTRATO DE MÁQUINA na extensão (W.2): a decisão de fluxo
// vem do campo `action` do envelope, nunca de casar a prosa.
//
// Por que isto é um teste, e não uma leitura: a fase W.2 criou uma recusa cuja
// ação é REPETIR (`retry-later`) - outro processo está refatorando o mesmo
// projeto, o pedido continua válido, e mandar o usuário "parar e chamar um
// humano" seria conselho errado sobre algo que bastava refazer. Se essa
// distinção sumir da extensão, o CLI segue certo e o usuário segue mal
// informado, que é a pior combinação: ninguém reprova.
//
// Técnica do harness irmão (test-resolveat.js): extrai as funções REAIS do
// extension.js e as executa, em vez de reimplementá-las aqui - uma cópia
// passaria verde depois de a extensão mudar.
// Rodar de qualquer lugar: node vscode/test-envelope.js
const fs = require('fs');
const path = require('path');
const src = fs.readFileSync(path.join(__dirname, 'extension.js'), 'utf8');

let pass = 0, fail = 0;
function check(desc, ok, extra) {
  ok ? pass++ : fail++;
  console.log((ok ? 'PASS' : 'FAIL') + ' ' + desc + (extra ? ' ' + extra : ''));
}

// 1. envelopeOf: a função real, extraída
const m = src.match(/function envelopeOf\(res\) \{[\s\S]*?\n\}/);
check('envelopeOf existe no extension.js', !!m);
if (!m) { console.log('\n' + pass + ' pass, ' + fail + ' fail'); process.exit(1); }
const envelopeOf = eval('(' + m[0].replace(/^function envelopeOf/, 'function') + ')');

const recusaBusy = JSON.stringify({
  schema: 'cli-2', command: 'rename', status: 'refused', exit: 1,
  reason: 'project-busy-another-process', action: 'retry-later',
  detail: "another process is refactoring 'p.hbp' - waited 30s"
});

check('envelope de recusa é lido do stdout',
  (envelopeOf({ stdout: recusaBusy }) || {}).reason === 'project-busy-another-process');
check('a AÇÃO é lida do campo, não da prosa',
  (envelopeOf({ stdout: recusaBusy }) || {}).action === 'retry-later');
check('prosa (comando que ainda não fala o contrato) devolve null',
  envelopeOf({ stdout: 'hbrefactor: verified: 3 module(s) byte-identical\n' }) === null);
check('JSON quebrado devolve null em vez de explodir',
  envelopeOf({ stdout: '{ "status": "refu' }) === null);
check('stdout vazio devolve null',
  envelopeOf({ stdout: '' }) === null);
// um JSON que não é envelope nosso não pode ser tratado como se fosse
check('JSON sem `status` não passa por envelope',
  envelopeOf({ stdout: '{"locations":[]}' }) === null);

// 2. o fluxo de escrita consulta o CAMPO, e o faz no funil
check('runWrite existe e decide por action === retry-later',
  /async function runWrite\(/.test(src) &&
  /env\.action\s*!==\s*'retry-later'/.test(src));
check('runWrite passa --json (sem envelope não há campo para ler)',
  /runWrite[\s\S]{0,400}?run\(\[\.\.\.args,\s*'--json'\]/.test(src));
check('a repetição é OFERECIDA ao usuário, nunca automática',
  /showWarningMessage\([\s\S]{0,200}?'Try again'/.test(src));

// 3. todo comando que ESCREVE no projeto passa pelo funil
['rename', 'reorder-params', 'extract-function', 'verify'].forEach(cmd => {
  const re = new RegExp("runWrite\\(\\[\\s*'" + cmd + "'");
  check('comando de escrita no funil: ' + cmd, re.test(src));
});
// e nenhum deles ficou para trás chamando run() direto
['reorder-params', 'extract-function'].forEach(cmd => {
  const re = new RegExp("await run\\(\\[\\s*'" + cmd + "'");
  check('não sobrou chamada crua de ' + cmd, !re.test(src));
});

// 4. o canal do usuário mostra a FRASE, não o envelope cru
check('report imprime env.detail quando há envelope',
  /if \(env\) \{[\s\S]{0,200}?env\.detail/.test(src));

console.log('\n' + pass + ' pass, ' + fail + ' fail');
process.exit(fail ? 1 : 0);
