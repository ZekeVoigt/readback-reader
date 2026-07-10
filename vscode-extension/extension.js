const vscode = require('vscode');
const { execFile, spawn } = require('child_process');

let currentProcess = null;

function activate(context) {
  context.subscriptions.push(
    vscode.commands.registerCommand('readback.readSelection', readSelection),
    vscode.commands.registerCommand('readback.readClipboard', readClipboard),
    vscode.commands.registerCommand('readback.stop', stopReading),
    vscode.commands.registerCommand('readback.chooseSpeed', chooseSpeed),
    vscode.commands.registerCommand('readback.chooseVoice', chooseVoice)
  );
}

function deactivate() {
  stopReading();
}

async function readSelection() {
  const editor = vscode.window.activeTextEditor;
  const selectedText = editor
    ? editor.selections.map((selection) => editor.document.getText(selection)).filter(Boolean).join('\n\n')
    : '';

  if (!selectedText.trim()) {
    vscode.window.showInformationMessage('Readback: no selected text.');
    return;
  }

  speak(selectedText);
}

async function readClipboard() {
  const text = await vscode.env.clipboard.readText();
  if (!text.trim()) {
    vscode.window.showInformationMessage('Readback: clipboard is empty.');
    return;
  }

  speak(text);
}

function speak(text) {
  stopReading();

  const config = vscode.workspace.getConfiguration('readback');
  const voice = config.get('voice', '').trim();
  const speed = Number(config.get('speed', 1)) || 1;
  const rate = String(Math.round(180 * Math.min(2, Math.max(0.5, speed))));
  const args = ['-r', rate];

  if (voice) {
    args.push('-v', voice);
  }

  currentProcess = spawn('/usr/bin/say', args, { stdio: ['pipe', 'ignore', 'pipe'] });
  currentProcess.stdin.end(text);
  currentProcess.on('exit', () => {
    currentProcess = null;
  });
  currentProcess.stderr.on('data', (chunk) => {
    vscode.window.showWarningMessage(`Readback: ${chunk.toString().trim()}`);
  });
}

function stopReading() {
  if (currentProcess) {
    currentProcess.kill();
    currentProcess = null;
  }
}

async function chooseSpeed() {
  const picks = ['0.5', '0.75', '1', '1.25', '1.5', '1.75', '2'];
  const choice = await vscode.window.showQuickPick(picks.map((value) => `${value}x`), {
    placeHolder: 'Choose readback speed'
  });

  if (!choice) {
    return;
  }

  await vscode.workspace.getConfiguration('readback').update('speed', Number(choice.replace('x', '')), vscode.ConfigurationTarget.Global);
}

async function chooseVoice() {
  const voices = await getPreferredMacVoices();
  const choice = await vscode.window.showQuickPick(['System default', ...voices], {
    placeHolder: 'Choose macOS voice'
  });

  if (!choice) {
    return;
  }

  await vscode.workspace.getConfiguration('readback').update(
    'voice',
    choice === 'System default' ? '' : choice,
    vscode.ConfigurationTarget.Global
  );
}

function getPreferredMacVoices() {
  return new Promise((resolve) => {
    execFile('/usr/bin/say', ['-v', '?'], (error, stdout) => {
      if (error && !stdout) {
        resolve([]);
        return;
      }

      const available = stdout
        .split('\n')
        .map((line) => {
          const match = line.match(/^(.*?)\s+[a-z]{2}[_-][A-Z]{2}\s+#/);
          return match ? match[1].trim() : '';
        })
        .filter(Boolean)
        .filter((voice, index, all) => all.indexOf(voice) === index);

      const preferred = ['Samantha', 'Flo (English (US))', 'Shelley (English (US))', 'Reed (English (US))'];
      const backups = ['Karen', 'Daniel', 'Moira', 'Tessa'];
      const voices = [...preferred, ...backups].filter((voice) => available.includes(voice)).slice(0, 4);

      resolve(voices);
    });
  });
}

module.exports = {
  activate,
  deactivate
};
