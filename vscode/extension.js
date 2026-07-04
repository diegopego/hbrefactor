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

async function projectHbp() {
  const fixed = cfg().get('project');
  if (fixed) return fixed;
  const files = await vscode.workspace.findFiles('**/*.hbp', '**/{node_modules,.git}/**', 16);
  if (files.length === 0) {
    vscode.window.showErrorMessage('hbrefactor: nenhum .hbp no workspace (configure hbrefactor.project).');
    return null;
  }
  if (files.length === 1) return files[0].fsPath;
  return await vscode.window.showQuickPick(files.map(f => f.fsPath), { placeHolder: 'Projeto .hbp' }) || null;
}

function run(args, cwd) {
  return new Promise(resolve => {
    const env = Object.assign({}, process.env);
    const hb = cfg().get('hbBin');
    if (hb) env.HB_BIN = hb.replace(/^~/, os.homedir());
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

// heurística de exibição/argumento: o CLI valida contra o oráculo
function enclosingFunction(document, line) {
  const re = /^\s*(?:static\s+)?(?:function|procedure)\s+([A-Za-z_]\w*)/i;
  for (let i = line; i >= 0; i--) {
    const m = re.exec(document.lineAt(i).text);
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
  const hbp = await projectHbp();
  if (!hbp) return null;
  return { editor, hbp, cwd: path.dirname(hbp), file: path.basename(editor.document.fileName) };
}

async function cmdUsages() {
  const c = await ctx();
  if (!c) return;
  const word = wordAt(c.editor);
  if (!word) return;
  await c.editor.document.save();
  const json = tmpJson();
  const res = await run(['usages', c.hbp, word, '--json', json], c.cwd);
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
    vscode.window.showErrorMessage('hbrefactor: não achei FUNCTION/PROCEDURE acima do cursor.');
    return;
  }
  const novo = await vscode.window.showInputBox({ prompt: `Novo nome para ${word} (local/param de ${func})` });
  if (!novo) return;
  await saveAll();
  const res = await run(['rename-local', c.hbp, c.file, func, word, novo], c.cwd);
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
  let res = await run(['rename-function', c.hbp, word, novo], c.cwd);
  if (res.code !== 0 && /textual references found/.test(res.stderr + res.stdout)) {
    report(`rename-function ${word} -> ${novo} (referências textuais)`, res);
    const go = await vscode.window.showWarningMessage(
      'Há referências textuais (strings/HB_FUNC) que NÃO serão alteradas. Prosseguir mesmo assim?',
      'Prosseguir (--force)', 'Cancelar');
    if (go !== 'Prosseguir (--force)') return;
    res = await run(['rename-function', c.hbp, word, novo, '--force'], c.cwd);
  }
  report(`rename-function ${word} -> ${novo}`, res);
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
  const res = await run(['reorder-params', c.hbp, word, ordem], c.cwd);
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
  const res = await run(['extract-function', c.hbp, c.file, `${first}-${last}`, nome], c.cwd);
  report(`extract-function ${first}-${last} -> ${nome}`, res);
}

function activate(context) {
  context.subscriptions.push(
    vscode.commands.registerCommand('hbrefactor.usages', cmdUsages),
    vscode.commands.registerCommand('hbrefactor.renameLocal', cmdRenameLocal),
    vscode.commands.registerCommand('hbrefactor.renameFunction', cmdRenameFunction),
    vscode.commands.registerCommand('hbrefactor.reorderParams', cmdReorderParams),
    vscode.commands.registerCommand('hbrefactor.extractFunction', cmdExtractFunction)
  );
}

function deactivate() {}

module.exports = { activate, deactivate };
