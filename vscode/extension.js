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
// ou lista de .prg
async function projectSpec() {
  const fixed = cfg().get('project');
  if (fixed) return fixed;
  const files = await vscode.workspace.findFiles('**/*.{hbp,hbc}', '**/{node_modules,.git,.hbmk}/**', 32);
  if (files.length === 0) {
    vscode.window.showErrorMessage('hbrefactor: nenhum .hbp/.hbc no workspace (configure hbrefactor.project).');
    return null;
  }
  if (files.length === 1) return files[0].fsPath;
  return await vscode.window.showQuickPick(files.map(f => f.fsPath), { placeHolder: 'Projeto (.hbp/.hbc)' }) || null;
}

function run(args, cwd) {
  return new Promise(resolve => {
    const env = Object.assign({}, process.env);
    const hb = cfg().get('hbBin');
    if (hb) env.HB_BIN = hb.replace(/^~/, os.homedir());
    const inc = cfg().get('includePaths');
    if (inc) env.INCLUDE = inc.replace(/~/g, os.homedir());
    const bin = (cfg().get('binPath') || 'hbrefactor').replace(/^~/, os.homedir());
    cp.execFile(bin, args, { cwd, env }, (err, stdout, stderr) => {
      resolve({ code: err ? (typeof err.code === 'number' ? err.code : 1) : 0, stdout, stderr });
    });
  });
}

function report(title, res) {
  const ch = out();
  ch.appendLine('--- ' + title);
  if (res.stdout) ch.append(res.stdout);
  if (res.stderr) ch.append(res.stderr);
  ch.show(true);
  if (res.code !== 0) {
    const first = (res.stderr || res.stdout || 'falhou').split('\n').find(l => l.trim()) || 'falhou';
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
  const spec = await projectSpec();
  if (!spec) return null;
  return { editor, spec, cwd: path.dirname(spec), file: path.basename(editor.document.fileName) };
}

// contexto sem editor ativo obrigatório (relatórios de projeto inteiro)
async function projCtx() {
  const spec = await projectSpec();
  if (!spec) return null;
  return { spec, cwd: path.dirname(spec) };
}

async function cmdUsages() {
  const c = await ctx();
  if (!c) return;
  const word = wordAt(c.editor);
  if (!word) return;
  await c.editor.document.save();
  const json = tmpJson();
  const res = await run(['usages', c.spec, word, '--json', json], c.cwd);
  report('usages ' + word, res);
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

async function cmdRenameLocal() {
  const c = await ctx();
  if (!c) return;
  const word = wordAt(c.editor);
  if (!word) return;
  const func = enclosingFunction(c.editor.document, c.editor.selection.active.line);
  if (!func) {
    vscode.window.showErrorMessage('hbrefactor: não achei FUNCTION/PROCEDURE/METHOD acima do cursor.');
    return;
  }
  const novo = await vscode.window.showInputBox({ prompt: `Novo nome para ${word} (local/param de ${func})` });
  if (!novo) return;
  await saveAll();
  const res = await run(['rename-local', c.spec, c.file, func, word, novo], c.cwd);
  report(`rename-local ${func}:${word} -> ${novo}`, res);
}

async function cmdRenameFunction() {
  const c = await ctx();
  if (!c) return;
  const word = wordAt(c.editor);
  if (!word) return;
  const novo = await vscode.window.showInputBox({ prompt: `Novo nome para a função ${word}` });
  if (!novo) return;
  await saveAll();
  let res = await run(['rename-function', c.spec, word, novo], c.cwd);
  if (res.code !== 0 && /textual references found/.test(res.stderr + res.stdout)) {
    report(`rename-function ${word} -> ${novo} (referências textuais)`, res);
    const go = await vscode.window.showWarningMessage(
      'Há referências textuais (strings/HB_FUNC) que NÃO serão alteradas. Prosseguir mesmo assim?',
      'Prosseguir (--force)', 'Cancelar');
    if (go !== 'Prosseguir (--force)') return;
    res = await run(['rename-function', c.spec, word, novo, '--force'], c.cwd);
  }
  report(`rename-function ${word} -> ${novo}`, res);
}

// renomeia a palavra-cabeça de uma diretiva de pp (#command/#xcommand/
// #[x]translate/#define) na definição E em todos os sites de aplicação.
// Projeto inteiro (a diretiva pode viver num .ch compartilhado); o CLI
// verifica .ppo/.hrb byte-idênticos e faz rollback em qualquer divergência.
async function cmdRenameDsl() {
  const c = await ctx();
  if (!c) return;
  const word = wordAt(c.editor);
  if (!word) return;
  const novo = await vscode.window.showInputBox({
    prompt: `Novo nome para a palavra de DSL/diretiva ${word} (definição + todos os usos)` });
  if (!novo) return;
  await saveAll();
  const res = await run(['rename-dsl', c.spec, word, novo], c.cwd);
  report(`rename-dsl ${word} -> ${novo}`, res);
}

async function cmdRenameStatic() {
  const c = await ctx();
  if (!c) return;
  const word = wordAt(c.editor);
  if (!word) return;
  const novo = await vscode.window.showInputBox({ prompt: `Novo nome para a STATIC ${word} (módulo ${c.file})` });
  if (!novo) return;
  await saveAll();
  const res = await run(['rename-static', c.spec, c.file, word, novo], c.cwd);
  report(`rename-static ${word} -> ${novo}`, res);
}

async function cmdReorderParams() {
  const c = await ctx();
  if (!c) return;
  const word = wordAt(c.editor) || enclosingFunction(c.editor.document, c.editor.selection.active.line);
  if (!word) return;
  const ordem = await vscode.window.showInputBox({
    prompt: `Nova ordem dos parâmetros de ${word} (nomes separados por vírgula)` });
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
    vscode.window.showErrorMessage('hbrefactor: selecione as linhas a extrair.');
    return;
  }
  const first = sel.start.line + 1;
  const last = sel.end.character === 0 ? sel.end.line : sel.end.line + 1;
  const nome = await vscode.window.showInputBox({ prompt: `Nome da nova função (linhas ${first}-${last})` });
  if (!nome) return;
  await saveAll();
  const res = await run(['extract-function', c.spec, c.file, `${first}-${last}`, nome], c.cwd);
  report(`extract-function ${first}-${last} -> ${nome}`, res);
}

async function cmdUnusedLocals() {
  const c = await projCtx();
  if (!c) return;
  await saveAll();
  report('unused-locals', await run(['unused-locals', c.spec], c.cwd));
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

function activate(context) {
  context.subscriptions.push(
    vscode.commands.registerCommand('hbrefactor.usages', cmdUsages),
    vscode.commands.registerCommand('hbrefactor.renameLocal', cmdRenameLocal),
    vscode.commands.registerCommand('hbrefactor.renameFunction', cmdRenameFunction),
    vscode.commands.registerCommand('hbrefactor.renameDsl', cmdRenameDsl),
    vscode.commands.registerCommand('hbrefactor.renameStatic', cmdRenameStatic),
    vscode.commands.registerCommand('hbrefactor.reorderParams', cmdReorderParams),
    vscode.commands.registerCommand('hbrefactor.extractFunction', cmdExtractFunction),
    vscode.commands.registerCommand('hbrefactor.unusedLocals', cmdUnusedLocals),
    vscode.commands.registerCommand('hbrefactor.callGraph', cmdCallGraph),
    vscode.commands.registerCommand('hbrefactor.findDynamicCalls', cmdFindDynamicCalls)
  );
}

function deactivate() {}

module.exports = { activate, deactivate };
