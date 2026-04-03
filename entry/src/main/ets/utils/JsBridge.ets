/**
 * JS Bridge
 * 参考 android-openclaw JsBridge.kt
 */
import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { TerminalSessionManager } from '../models/TerminalSessionManager';
import { BootstrapManager } from '../models/BootstrapManager';
import { EventBridge } from './EventBridge';
import { EnvironmentBuilder } from './EnvironmentBuilder';

const DOMAIN = 0x0000;
const TAG = 'JsBridge';

/**
 * JS Bridge
 * WebView ↔ ArkTS 桥接
 */
export class JsBridge {
  private activity: any;
  private sessionManager: TerminalSessionManager;
  private bootstrapManager: BootstrapManager;
  private eventBridge: EventBridge;
  private context: common.Context;

  constructor(
    activity: any,
    sessionManager: TerminalSessionManager,
    bootstrapManager: BootstrapManager,
    eventBridge: EventBridge
  ) {
    this.activity = activity;
    this.sessionManager = sessionManager;
    this.bootstrapManager = bootstrapManager;
    this.eventBridge = eventBridge;
    this.context = activity.context;
    
    hilog.info(DOMAIN, TAG, 'JsBridge created');
  }

  // ========== 终端域 ==========

  showTerminal(): void {
    hilog.info(DOMAIN, TAG, 'showTerminal called');
    if (!this.sessionManager.activeSession) {
      this.sessionManager.createSession();
    }
    this.activity.showTerminalView();
  }

  showWebView(): void {
    hilog.info(DOMAIN, TAG, 'showWebView called');
    this.activity.showWebView();
  }

  createSession(): string {
    const session = this.sessionManager.createSession();
    return JSON.stringify({
      id: session.id,
      name: session.title
    });
  }

  switchSession(id: string): void {
    this.sessionManager.switchSession(id);
  }

  closeSession(id: string): void {
    this.sessionManager.closeSession(id);
  }

  getTerminalSessions(): string {
    return JSON.stringify(this.sessionManager.getSessionsInfo());
  }

  writeToTerminal(id: string, data: string): void {
    const session = id
      ? this.sessionManager.getSessionById(id) || this.sessionManager.activeSession
      : this.sessionManager.activeSession;
    session?.write(data);
  }

  // ========== 设置域 ==========

  getSetupStatus(): string {
    return JSON.stringify(this.bootstrapManager.getStatus());
  }

  startSetup(): void {
    hilog.info(DOMAIN, TAG, 'startSetup called');
    this.bootstrapManager.startSetup((progress, message) => {
      this.eventBridge.emitSetupProgress(progress, message);
    }).catch((e) => {
      hilog.error(DOMAIN, TAG, `Setup failed: ${e}`);
      this.eventBridge.emitSetupProgress(0, `Error: ${e}`);
    });
  }

  // ========== 系统域 ==========

  getStorageInfo(): string {
    return JSON.stringify({
      totalBytes: 64 * 1024 * 1024 * 1024,
      freeBytes: 32 * 1024 * 1024 * 1024,
      bootstrapBytes: 200 * 1024 * 1024
    });
  }

  getNetworkStatus(): string {
    return JSON.stringify({
      connected: true,
      type: 'wifi'
    });
  }

  getSystemInfo(): string {
    return JSON.stringify({
      os: 'harmony',
      arch: 'arm64',
      version: '4.0.0',
      sdk: 10
    });
  }

  copyToClipboard(text: string): void {
    try {
      const pasteData = pasteboard.createPlainTextData(text);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      systemPasteboard.setPasteData(pasteData);
      hilog.info(DOMAIN, TAG, 'Text copied to clipboard');
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Failed to copy: ${e}`);
    }
  }

  // ========== 命令域 ==========

  runCommand(cmd: string): string {
    hilog.info(DOMAIN, TAG, `runCommand: ${cmd}`);
    
    // 简单实现：直接写入终端
    this.sessionManager.activeSession?.write(cmd + '\n');
    
    return JSON.stringify({
      exitCode: 0,
      stdout: '',
      stderr: ''
    });
  }
}

export default JsBridge;
