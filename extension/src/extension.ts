import * as vscode from 'vscode';
import { SidecarClient } from './sidecarClient';

let client: SidecarClient | undefined;

export function activate(context: vscode.ExtensionContext): void {
  const output = vscode.window.createOutputChannel('OpenPi', { log: true });
  context.subscriptions.push(output);

  client = new SidecarClient(context, output);
  context.subscriptions.push(client);

  const status = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
  status.text = '$(pi) OpenPi';
  status.command = 'openpi.openChat';
  status.show();
  context.subscriptions.push(status);

  client.onStatusChange((up) => {
    status.text = up ? '$(pi) OpenPi' : '$(circle-slash) OpenPi (offline)';
    status.tooltip = up ? 'Connected to agent harness' : 'Sidecar daemon not responding';
  });

  void client.connect();

  context.subscriptions.push(
    vscode.commands.registerCommand('openpi.openChat', () => {
      output.info('openChat: chat webview lands in Phase 3');
      void vscode.window.showInformationMessage('OpenPi chat is coming online in Phase 3.');
    }),
    vscode.commands.registerCommand('openpi.inlineEdit', async () => {
      const editor = vscode.window.activeTextEditor;
      if (!editor || editor.selection.isEmpty) {
        void vscode.window.showWarningMessage('Select some code first, then run OpenPi inline edit.');
        return;
      }
      output.info(`inlineEdit requested on ${editor.document.fileName}`);
    }),
    vscode.commands.registerCommand('openpi.manageKeys', async () => {
      const key = await vscode.window.showInputBox({
        prompt: 'Paste your API key (stored locally via secret storage)',
        password: true,
        placeHolder: 'sk-...'
      });
      if (key) {
        await context.secrets.store('openpi.byok.key', key);
        void vscode.window.showInformationMessage('API key stored locally. It never leaves your machine except to your chosen provider.');
      }
    }),
    vscode.commands.registerCommand('openpi.showOnboarding', async () => {
      const choice = await vscode.window.showQuickPick(
        ['Use my own API key (free forever)', 'Learn about Go Tier (Rs.299/month UPI)'],
        { placeHolder: 'Welcome to OpenPi - how would you like to start?' }
      );
      if (choice?.startsWith('Use')) {
        await vscode.commands.executeCommand('openpi.manageKeys');
      } else if (choice) {
        output.info('Go Tier onboarding: Razorpay integration lands in a later phase');
      }
    })
  );
}

export function deactivate(): void {
  client = undefined;
}
