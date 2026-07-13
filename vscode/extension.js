// hbrefactor - extensão VSCode fina.
// Toda a inteligência (oráculo do compilador, verificação, rollback) vive no
// CLI hbrefactor; a extensão só coleta argumentos, invoca e mostra resultados.
// A única heurística local é descobrir o nome da função que contém o cursor
// (para montar a linha de comando) - se errar, o CLI recusa com mensagem.

const vscode = require('vscode');
const cp = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');

let channel;

function out() {
  if (!channel) channel = vscode.window.createOutputChannel('hbrefactor');
  return channel;
}

function cfg() { return vscode.workspace.getConfiguration('hbrefactor'); }

// o CLI aceita qualquer alvo que o hbmk2 entenda: .hbp, .hbc com sources=,
// ou lista de .prg. Com um arquivo em foco, a DESCOBERTA é fato do CLI
// (projects-of modo descoberta, B5+): ele caminha os diretórios ANCESTRAIS
// do arquivo, sonda o hbmk2 do mais próximo ao mais distante e devolve donos
// + candidatos JÁ ordenados por proximidade - a extensão nunca parseia .hbp
// nem ranqueia, só passa o arquivo + as raízes do workspace e renderiza.
// Dono único (fato) entra sem perguntar; um único projeto ao redor também
// (resposta única); órfão/fonte compartilhada oferece a lista com o mais
// próximo no topo. Sem arquivo (relatórios de projeto inteiro) ou descoberta
// indisponível: varredura do workspace, SEM teto, deduplicada.
async function projectSpec(forFile) {
  const fixed = cfg().get('project');
  if (fixed) return fixed;

  if (forFile) {
    const disc = await ownerOf(forFile);
    if (disc && (disc.owners.length || disc.candidates.length)) {
      const pick = pickerChoices(disc.candidates, disc.owners);
      if (pick.auto) return pick.auto;
      if (disc.owners.length === 0 && disc.candidates.length === 1) return disc.candidates[0];
      return await askProject(pick.ask, 'Project (.hbp/.hbc) - nearest first');
    }
    // disc null (CLI/hbmk2 indisponível) ou nada perto do arquivo: cai para
    // a varredura do workspace abaixo
  }

  const files = dedupFsPaths(await vscode.workspace.findFiles(
    '**/*.{hbp,hbc}', '**/{node_modules,.git,.hbmk}/**'));
  if (files.length === 0) {
    vscode.window.showErrorMessage('hbrefactor: no .hbp/.hbc in the workspace (set hbrefactor.project).');
    return null;
  }
  if (files.length === 1) return files[0];
  return await askProject(files.slice().sort());
}

// decisão pura do picker: donos vindos do CLI; null (pergunta falhou) ou
// vazio (arquivo órfão) -> oferece todos; um dono -> direto, sem pergunta;
// vários donos (fonte compartilhada) -> pergunta só entre eles
function pickerChoices(all, owners) {
  if (!owners || owners.length === 0) return { auto: null, ask: all };
  if (owners.length === 1) return { auto: owners[0], ask: null };
  return { auto: null, ask: owners };
}

// descoberta de FATO pelo CLI (projects-of modo descoberta): passa o arquivo
// e as raízes do workspace; o CLI caminha os ancestrais, sonda o hbmk2 do
// mais próximo ao mais distante e devolve { owners, candidates } JÁ ordenados
// por proximidade (a extensão nunca parseia .hbp nem ranqueia). null = a
// pergunta falhou (CLI/hbmk2 indisponível), distinto de owners vazio (órfão)
async function ownerOf(file) {
  const json = tmpJson();
  const roots = (vscode.workspace.workspaceFolders || []).map(f => f.uri.fsPath);
  const args = ['projects-of', file];
  roots.forEach(r => args.push('--root', r));
  args.push('--json', json);
  const res = await run(args, path.dirname(file));
  if (res.code !== 0) return null;
  try {
    const out = JSON.parse(fs.readFileSync(json, 'utf8'));
    fs.unlinkSync(json);
    return { owners: out.owners || [], candidates: out.candidates || [] };
  } catch (e) { return null; }
}

// QuickPick legível: rótulo = nome do .hbp, descrição = diretório; o item
// carrega o caminho completo (o CLI já entrega o mais próximo no topo).
// Devolve o fsPath escolhido ou null
async function askProject(specs, placeHolder) {
  const items = specs.map(s => ({ label: path.basename(s), description: path.dirname(s), spec: s }));
  const chosen = await vscode.window.showQuickPick(items,
    { placeHolder: placeHolder || 'Project (.hbp/.hbc)' });
  return chosen ? chosen.spec : null;
}

// dedup de URIs por caminho canônico (raízes sobrepostas/symlink davam o
// mesmo projeto repetido no picker); devolve fsPaths na ordem de chegada
function dedupFsPaths(uris) {
  const seen = new Set(), out = [];
  uris.forEach(u => {
    const key = path.resolve(u.fsPath);
    if (!seen.has(key)) { seen.add(key); out.push(u.fsPath); }
  });
  return out;
}

// resolve o executável: caminho explícito na config vence; senão o binário
// construído ao lado da extensão (../bin/hbrefactor - layout do repo, faz o
// dev mode funcionar sem PATH e sempre com o build recente); senão conta com
// o PATH. Sem isto, dev mode dava "spawn hbrefactor ENOENT".
function resolveBin() {
  const configured = (cfg().get('binPath') || '').replace(/^~/, os.homedir());
  if (configured && configured !== 'hbrefactor') return configured;
  const local = path.join(__dirname, '..', 'bin', 'hbrefactor');
  if (fs.existsSync(local)) return local;
  return configured || 'hbrefactor';
}

function run(args, cwd) {
  return new Promise(resolve => {
    const env = Object.assign({}, process.env);
    const hb = cfg().get('hbBin');
    if (hb) env.HB_BIN = hb.replace(/^~/, os.homedir());
    const inc = cfg().get('includePaths');
    if (inc) env.INCLUDE = inc.replace(/~/g, os.homedir());
    const bin = resolveBin();
    // maxBuffer alto: call-graph/usages num projeto grande passa do default de
    // 1 MB do execFile e o erro (ERR_CHILD_PROCESS_STDOUT_MAXBUFFER) chegava
    // sem stdout/stderr - aparecia como "falhou" sem explicação
    cp.execFile(bin, args, { cwd, env, maxBuffer: 64 * 1024 * 1024 }, (err, stdout, stderr) => {
      // err.code é numérico só num exit != 0 do processo; para falha de spawn
      // (ENOENT: binário não encontrado) ou estouro de buffer é string/undef -
      // preserva err.message para o report NÃO cair no genérico "falhou"
      resolve({
        code: err ? (typeof err.code === 'number' ? err.code : 1) : 0,
        stdout: stdout || '', stderr: stderr || '',
        error: err ? (err.message || String(err)) : ''
      });
    });
  });
}

function report(title, res) {
  const ch = out();
  ch.appendLine('--- ' + title);
  if (res.stdout) ch.append(res.stdout);
  if (res.stderr) ch.append(res.stderr);
  if (res.error && !res.stdout && !res.stderr) ch.appendLine('[error] ' + res.error);
  ch.show(true);
  if (res.code !== 0) {
    // a mensagem do CLI (stderr/stdout) explica; sem ela, o erro do execFile
    // (ex.: "spawn hbrefactor ENOENT" = binário não encontrado) é o que ajuda
    const first = (res.stderr || res.stdout || res.error || 'failed')
      .split('\n').find(l => l.trim()) || res.error || 'failed';
    vscode.window.showWarningMessage('hbrefactor: ' + first.trim());
  }
}

function wordAt(editor) {
  const range = editor.document.getWordRangeAtPosition(editor.selection.active, /[A-Za-z_]\w*/);
  return range ? editor.document.getText(range) : null;
}

// heurística de exibição/argumento: o CLI valida contra o oráculo.
// METHOD Foo(...) CLASS Bar vira Bar:Foo - forma que o CLI resolve para a
// função de implementação BAR_FOO do hbclass.ch.
function enclosingFunction(document, line) {
  const reFunc = /^\s*(?:static\s+)?(?:function|procedure)\s+([A-Za-z_]\w*)/i;
  const reMethod = /^\s*method\s+([A-Za-z_]\w*).*\bclass\s+([A-Za-z_]\w*)/i;
  for (let i = line; i >= 0; i--) {
    const text = document.lineAt(i).text;
    let m = reMethod.exec(text);
    if (m) return m[2] + ':' + m[1];
    m = reFunc.exec(text);
    if (m) return m[1];
  }
  return null;
}

function tmpJson() {
  return path.join(os.tmpdir(), 'hbrefactor_' + Date.now() + '.json');
}

async function ctx() {
  const editor = vscode.window.activeTextEditor;
  if (!editor) return null;
  // documento sem arquivo no disco (untitled) não tem pertencimento a
  // perguntar - o picker cai para a lista completa
  const spec = await projectSpec(editor.document.isUntitled ? null : editor.document.fileName);
  if (!spec) return null;
  return { editor, spec, cwd: path.dirname(spec), file: path.basename(editor.document.fileName) };
}

// contexto sem editor ativo obrigatório (relatórios de projeto inteiro)
async function projCtx() {
  const spec = await projectSpec();
  if (!spec) return null;
  return { spec, cwd: path.dirname(spec) };
}

// posição do editor (0-based, UTF-16) -> arq:linha:col 1-based do CLI. A
// coluna do compilador é BYTE: linha com caractere multi-byte antes do
// cursor pode desalinhar - o CLI recusa/erra o token e o fallback abaixo
// consulta a palavra crua (degrada, nunca corrompe)
function atSpec(file, line0, char0) {
  return file + ':' + (line0 + 1) + ':' + (char0 + 1);
}

// find-references por POSIÇÃO (Q5 da revisão de generalidade): "o que
// está sob o cursor" é pergunta de FATO ao CLI - `usages --at` resolve
// pelo rastro do dump (mesmo core do resolve-at standalone) na MESMA
// invocação/compilação e promove membro de QUALQUER DSL a Dona:Membro,
// homônimos decididos pelo site. A heurística methodQuery (regex
// hbclass) morreu aqui. Posição sem identificador de compilação (cursor
// em comentário/string, coluna desalinhada) cai para a consulta crua da
// palavra - o comportamento antigo, nunca palpite.
// --show-expansion SEMPRE (B5): o flag só acrescenta sufixos de rótulo
// no canal (` -> CAIXA_SOMA`, ` -> derives ...`); o --json que alimenta
// o peek de referências é byte-idêntico com/sem ele - o peek segue no
// vocabulário do fonte. Ligado sempre porque cada invocação recompila o
// projeto (hbmk2 -rebuild): re-perguntar só para ver o nome gerado
// custaria outra compilação inteira.
async function cmdUsages() {
  const c = await ctx();
  if (!c) return;
  const word = wordAt(c.editor);
  if (!word) return;
  await c.editor.document.save();
  const pos = c.editor.selection.active;
  const at = atSpec(c.file, pos.line, pos.character);
  const json = tmpJson();
  let res = await run(['usages', c.spec, '--at', at, '--json', json, '--show-expansion'], c.cwd);
  let title = 'usages @ ' + at;
  if (res.code !== 0 && /no compile-time identifier/.test(res.stderr + res.stdout)) {
    res = await run(['usages', c.spec, word, '--json', json, '--show-expansion'], c.cwd);
    title = 'usages ' + word;
  }
  report(title, res);
  try {
    const locs = JSON.parse(fs.readFileSync(json, 'utf8')).map(l => new vscode.Location(
      vscode.Uri.parse(l.uri),
      new vscode.Position(l.range.start.line, l.range.start.character)));
    fs.unlinkSync(json);
    if (locs.length) {
      await vscode.commands.executeCommand('editor.action.showReferences',
        c.editor.document.uri, c.editor.selection.active, locs);
    }
  } catch (e) { /* saída textual já está no channel */ }
}

async function saveAll() { await vscode.workspace.saveAll(false); }

// verbo unificado (fase U): "Rename Symbol" no estilo F2 do editor. O
// usuário NÃO classifica o alvo (local? método? palavra de DSL?) - dá só a
// POSIÇÃO e o CLI resolve o kind por FATO (o mesmo motor do resolve-at:
// papel estrutural do site + escopo declarado da função dona) e despacha
// para o rename-* específico por dentro, com saída byte-idêntica. Substitui
// os comandos por-kind (Local/Static/Function/Dsl/PpMarker, DESCONTINUADOS):
// a taxonomia é do compilador, não uma escolha remontada na UX. Os fluxos de
// confirmação (--edit-rules quando o nome é citado em diretiva, --force
// quando há strings/HB_FUNC) chegam pela MESMA mensagem do CLI - o rename
// delega ao rename-* que já as emite, então há um único ponto de confirmação.
// Posição sem identificador de compilação: o CLI recusa nomeando a exceção
// (degrade honesto, nunca palpite).
async function cmdRename() {
  const c = await ctx();
  if (!c) return;
  const word = wordAt(c.editor);
  if (!word) return;
  const novo = await vscode.window.showInputBox({
    prompt: `New name for "${word}" under the cursor (the kind comes from the fact: local/param/static/memvar/function/method/dsl/marker)` });
  if (!novo) return;
  await saveAll();
  const pos = c.editor.selection.active;
  const at = atSpec(c.file, pos.line, pos.character);
  const flags = [];
  let res = await run(['rename', c.spec, at, novo], c.cwd);
  // o nome é citado DENTRO de regra de pp: --edit-rules edita as diretivas junto
  if (res.code !== 0 && /--edit-rules/.test(res.stderr + res.stdout)) {
    report(`rename @ ${at} -> ${novo} (named in a pp rule)`, res);
    const go = await vscode.window.showWarningMessage(
      'The name is used INSIDE preprocessor rule(s) (the directives are named in the output). Edit the directives too?',
      'Proceed (--edit-rules)', 'Cancelar');
    if (go !== 'Proceed (--edit-rules)') return;
    flags.push('--edit-rules');
    res = await run(['rename', c.spec, at, novo, ...flags], c.cwd);
  }
  // strings/HB_FUNC iguais ao nome NÃO são editadas: o CLI pede --force
  if (res.code !== 0 && /--force/.test(res.stderr + res.stdout)) {
    report(`rename @ ${at} -> ${novo} (textual references)`, res);
    const go = await vscode.window.showWarningMessage(
      'There are textual references (strings/HB_FUNC) that will NOT be changed. Proceed anyway?',
      'Proceed (--force)', 'Cancelar');
    if (go !== 'Proceed (--force)') return;
    flags.push('--force');
    res = await run(['rename', c.spec, at, novo, ...flags], c.cwd);
  }
  report(`rename @ ${at} -> ${novo}`, res);
}

async function cmdReorderParams() {
  const c = await ctx();
  if (!c) return;
  const word = wordAt(c.editor) || enclosingFunction(c.editor.document, c.editor.selection.active.line);
  if (!word) return;
  const ordem = await vscode.window.showInputBox({
    prompt: `New parameter order for ${word} (names separated by commas)` });
  if (!ordem) return;
  await saveAll();
  const res = await run(['reorder-params', c.spec, word, ordem], c.cwd);
  report(`reorder-params ${word} (${ordem})`, res);
}

async function cmdExtractFunction() {
  const c = await ctx();
  if (!c) return;
  const sel = c.editor.selection;
  if (sel.isEmpty) {
    vscode.window.showErrorMessage('hbrefactor: select the lines to extract.');
    return;
  }
  const first = sel.start.line + 1;
  const last = sel.end.character === 0 ? sel.end.line : sel.end.line + 1;
  const nome = await vscode.window.showInputBox({ prompt: `Name of the new function (lines ${first}-${last})` });
  if (!nome) return;
  await saveAll();
  const res = await run(['extract-function', c.spec, c.file, `${first}-${last}`, nome], c.cwd);
  report(`extract-function ${first}-${last} -> ${nome}`, res);
}

async function cmdCallGraph() {
  const c = await projCtx();
  if (!c) return;
  const editor = vscode.window.activeTextEditor;
  const word = editor ? wordAt(editor) : null;
  await saveAll();
  const args = word ? ['call-graph', c.spec, word] : ['call-graph', c.spec];
  report('call-graph' + (word ? ' ' + word : ''), await run(args, c.cwd));
}

async function cmdFindDynamicCalls() {
  const c = await projCtx();
  if (!c) return;
  await saveAll();
  report('find-dynamic-calls', await run(['find-dynamic-calls', c.spec], c.cwd));
}

// snapshot/verify (A.2): o ORÁCULO EXPOSTO. Vale para QUALQUER edição - a sua,
// a de um agente, a de outra ferramenta. Grave a linha de base, edite à vontade,
// e o verify diz o que o COMPILADOR entendeu que mudou
async function cmdSnapshot() {
  const c = await projCtx();
  if (!c) return;
  await saveAll();
  report('snapshot', await run(['snapshot', c.spec], c.cwd));
}

async function cmdVerify() {
  const c = await projCtx();
  if (!c) return;
  await saveAll();
  const res = await run(['verify', c.spec], c.cwd);
  report('verify', res);
  // BROKEN é o único veredito adverso: só aí faz sentido oferecer o rollback.
  // Reverter um CHANGED destruiria trabalho legítimo - o pcode muda em toda
  // refatoração honesta, e "mudou" nunca quer dizer "errado"
  if (res.code !== 0 && /BROKEN/.test(res.stdout + res.stderr)) {
    const pick = await vscode.window.showWarningMessage(
      'The project no longer compiles after the edit. Restore the snapshot, byte for byte?',
      { modal: true }, 'Roll back');
    if (pick === 'Roll back') {
      report('verify --rollback', await run(['verify', c.spec, '--rollback'], c.cwd));
    }
  }
}

// annotate ESTÁGIO 1 (relatório): a escada de anotações do arquivo atual,
// nenhuma edição. O consumidor de uso diário vê o que fecharia por fato
async function cmdAnnotate() {
  const c = await ctx();
  if (!c) return;
  await saveAll();
  report('annotate ' + c.file, await run(['annotate', c.spec, c.file], c.cwd));
}

// annotate ESTÁGIO 2 (--apply): materializa DECLAREs + AS CLASS com
// verificação padrão-ouro (byte-inerte sem -kt, compila limpo, roda sob
// -kt) e rollback automático. Confirmação modal antes de escrever fonte
async function cmdAnnotateApply() {
  const c = await ctx();
  if (!c) return;
  const ok = await vscode.window.showWarningMessage(
    `hbrefactor: materialize annotations in ${c.file}? It writes DECLAREs + AS CLASS ` +
    `(gold-standard verification; automatic rollback on any failure).`,
    { modal: true }, 'Materialize');
  if (ok !== 'Materialize') return;
  await saveAll();
  report('annotate --apply ' + c.file, await run(['annotate', c.spec, c.file, '--apply'], c.cwd));
}

// exec-registry (B9 fatia 4): EXECUTA as funções de registro de classes do
// projeto em sandbox (driver próprio, timeout) e grava o retrato da tabela
// viva (.astr.json). O snapshot só SUGERE - o veredito é do -kt. Executar
// código do usuário é ação real: confirmação modal SEMPRE (contrato D4)
async function cmdExecRegistry() {
  const c = await projCtx();
  if (!c) return;
  const ok = await vscode.window.showWarningMessage(
    `hbrefactor: RUN the class-registration functions of ${c.spec} in a sandbox? ` +
    `It runs your project's code (INITs + registrars) with a timeout and records the ` +
    `live table snapshot (.astr.json). No source file is edited.`,
    { modal: true }, 'Run registration');
  if (ok !== 'Run registration') return;
  await saveAll();
  report('exec-registry', await run(['exec-registry', c.spec], c.cwd));
}

function activate(context) {
  context.subscriptions.push(
    vscode.commands.registerCommand('hbrefactor.usages', cmdUsages),
    vscode.commands.registerCommand('hbrefactor.rename', cmdRename),
    vscode.commands.registerCommand('hbrefactor.execRegistry', cmdExecRegistry),
    vscode.commands.registerCommand('hbrefactor.annotate', cmdAnnotate),
    vscode.commands.registerCommand('hbrefactor.annotateApply', cmdAnnotateApply),
    vscode.commands.registerCommand('hbrefactor.reorderParams', cmdReorderParams),
    vscode.commands.registerCommand('hbrefactor.extractFunction', cmdExtractFunction),
    vscode.commands.registerCommand('hbrefactor.callGraph', cmdCallGraph),
    vscode.commands.registerCommand('hbrefactor.findDynamicCalls', cmdFindDynamicCalls),
    vscode.commands.registerCommand('hbrefactor.snapshot', cmdSnapshot),
    vscode.commands.registerCommand('hbrefactor.verify', cmdVerify)
  );
}

function deactivate() {}

module.exports = { activate, deactivate };
