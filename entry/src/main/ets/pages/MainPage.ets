/**
 * 主入口页面
 * 参考 HiSH 和 android-openclaw 设计
 */
import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { pasteboard, deviceInfo } from '@kit.BasicServicesKit';
import { TerminalSessionManager } from '../models/TerminalSessionManager';
import { BootstrapManager } from '../models/BootstrapManager';
import { JsBridge } from '../utils/JsBridge';
import { EventBridge } from '../utils/EventBridge';
import { Constants } from '../common/Constants';
import terminalNative from '../lib/TerminalNative';
import stringToArrayBuffer from '../lib/stringToArrayBuffer';
import {
  applyVirtualKeyModifiers,
  FunctionKeySequences,
  getVirtualKeyMetrics,
  NormalKeySequences
} from '../lib/terminalVirtualKeys';

const DOMAIN = 0x0000;
const TAG = 'MainPage';

// 虚拟按键尺寸
const VKeyMetrics = getVirtualKeyMetrics(deviceInfo.deviceType);
const VKeyMargin = VKeyMetrics.margin;
const VKeyPadding = VKeyMetrics.padding;
const VKeyHeight = VKeyMetrics.height;
const VKeyWidth = VKeyMetrics.width;
const VKeyFontSize = VKeyMetrics.fontSize;
const VKeyRadius = VKeyMetrics.radius;

@Entry
@Component
struct MainPage {
  // 状态
  @State currentTextSize: number = 14;
  @State ctrlPressed: boolean = false;
  @State altPressed: boolean = false;
  @State shiftPressed: boolean = false;
  @State showTerminal: boolean = false;
  @State sessions: Array<SessionInfo> = [];
  @State activeSessionId: string = '';
  @State showVirtKey: boolean = true;
  @State fnPressed: boolean = false;
  @State applicationMode: boolean = false;
  
  // 控制器
  private webController: webview.WebviewController = new webview.WebviewController();
  private context: common.Context = getContext(this) as common.Context;
  
  // 管理器
  private sessionManager: TerminalSessionManager | null = null;
  private bootstrapManager: BootstrapManager | null = null;
  private eventBridge: EventBridge | null = null;
  private jsBridge: JsBridge | null = null;
  
  // 输出缓冲
  private pendingChunks: Uint8Array[] = [];
  private flushTimeoutID: number | undefined = undefined;
  private readonly FLUSH_INTERVAL = 16; // 60FPS

  aboutToAppear() {
    hilog.info(DOMAIN, TAG, 'MainPage aboutToAppear');
    
    // 初始化管理器
    this.bootstrapManager = new BootstrapManager(this.context);
    this.eventBridge = new EventBridge(this.webController);
    this.sessionManager = new TerminalSessionManager(this.context, this.eventBridge);
    this.jsBridge = new JsBridge(this, this.sessionManager, this.bootstrapManager, this.eventBridge);
    
    // 设置会话变更回调
    this.sessionManager.setOnSessionsChanged(() => {
      this.updateSessionTabs();
    });
    
    // 检查安装状态
    const isInstalled = this.bootstrapManager.isInstalled();
    hilog.info(DOMAIN, TAG, `Bootstrap installed: ${isInstalled}`);
    
    if (isInstalled) {
      this.showTerminalView();
    }
  }

  build() {
    Column() {
      // 顶部栏
      this.TopBar();
      
      // 主内容区域
      Stack() {
        // WebView (设置界面)
        if (!this.showTerminal) {
          this.WebViewComponent();
        }
        
        // 终端容器
        if (this.showTerminal) {
          this.TerminalContainer();
        }
      }
      .layoutWeight(1);
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0a0a0a');
  }

  @Builder
  TopBar() {
    Row() {
      if (this.showTerminal) {
        // 返回按钮
        Button() {
          Text('←')
            .fontSize(20)
            .fontColor(Color.White);
        }
        .backgroundColor(Color.Transparent)
        .onClick(() => this.showWebView());
        
        // 会话标签
        Scroll() {
          Row() {
            ForEach(this.sessions, (session: SessionInfo) => {
              this.SessionTab(session);
            });
            
            // 新建按钮
            Button('+')
              .fontSize(16)
              .fontColor('#888888')
              .backgroundColor(Color.Transparent)
              .onClick(() => {
                this.sessionManager?.createSession();
                this.webController.runJavaScript('exports.clear()');
              });
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .layoutWeight(1);
      } else {
        Text('HarmonyClaw')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .margin({ left: 16 });
      }
      
      Blank();
      
      // 字体大小调节
      if (this.showTerminal) {
        Row() {
          Button('-')
            .fontSize(14)
            .backgroundColor('#333333')
            .fontColor(Color.White)
            .width(32)
            .height(32)
            .onClick(() => {
              if (this.currentTextSize > 10) {
                this.currentTextSize -= 2;
                this.webController.runJavaScript(`exports.setFontSize(${this.currentTextSize})`);
              }
            });
          
          Text(`${this.currentTextSize}`)
            .fontSize(12)
            .fontColor(Color.White)
            .margin({ left: 8, right: 8 });
          
          Button('+')
            .fontSize(14)
            .backgroundColor('#333333')
            .fontColor(Color.White)
            .width(32)
            .height(32)
            .onClick(() => {
              if (this.currentTextSize < 24) {
                this.currentTextSize += 2;
                this.webController.runJavaScript(`exports.setFontSize(${this.currentTextSize})`);
              }
            });
        }
        .margin({ right: 16 });
      }
    }
    .width('100%')
    .height(48)
    .backgroundColor('#1a1a2e');
  }

  @Builder
  SessionTab(session: SessionInfo) {
    Row() {
      Text(session.name)
        .fontSize(12)
        .fontColor(session.active ? Color.White : '#888888')
        .maxLines(1);
      
      if (this.sessions.length > 1) {
        Text('×')
          .fontSize(14)
          .fontColor('#888888')
          .margin({ left: 4 })
          .onClick(() => this.sessionManager?.closeSession(session.id));
      }
    }
    .padding({ left: 12, right: 12, top: 4, bottom: 4 })
    .backgroundColor(session.active ? '#0f3460' : '#1a1a1a')
    .borderRadius({ topLeft: 8, topRight: 8 })
    .onClick(() => this.sessionManager?.switchSession(session.id));
  }

  @Builder
  WebViewComponent() {
    Web({
      src: $rawfile('www/index.html'),
      controller: this.webController
    })
      .javaScriptAccess(true)
      .domStorageAccess(true)
      .fileAccess(true)
      .javaScriptProxy({
        object: this.jsBridge,
        name: 'OpenClaw',
        methodList: [
          'showTerminal', 'showWebView',
          'createSession', 'switchSession', 'closeSession', 'getTerminalSessions',
          'writeToTerminal', 'runCommand',
          'getSetupStatus', 'startSetup',
          'getStorageInfo', 'getNetworkStatus', 'getSystemInfo',
          'copyToClipboard'
        ],
        controller: this.webController,
        asyncMethodList: []
      })
      .onPageEnd(() => {
        hilog.info(DOMAIN, TAG, 'WebView page loaded');
      })
      .onConsole((event) => {
        hilog.debug(DOMAIN, TAG, `WebViewJS: ${event?.message?.getMessage()}`);
        return false;
      })
      .width('100%')
      .height('100%');
  }

  @Builder
  TerminalContainer() {
    Column() {
      // 终端视图 (WebView 渲染)
      Web({
        src: $rawfile('term/term.html'),
        controller: this.webController
      })
        .javaScriptProxy({
          object: this,
          name: 'native',
          methodList: ['sendInput', 'resize', 'load', 'getFontSize', 'getDeviceType', 'setApplicationMode'],
          controller: this.webController,
          asyncMethodList: []
        })
        .backgroundColor('#000')
        .layoutWeight(1);
      
      // 虚拟按键栏
      if (this.showVirtKey) {
        this.VirtualKeys();
      } else {
        this.ShowVirtualKeysButton();
      }
    }
    .width('100%')
    .layoutWeight(1);
  }

  @Builder
  VirtualKeys() {
    Column() {
      if (this.fnPressed) {
        // FN 模式 - 功能键
        Row() {
          this.VKey('FN', () => this.fnPressed = !this.fnPressed, this.fnPressed);
          this.VKey('F1', () => this.sendKey(FunctionKeySequences.F1));
          this.VKey('F2', () => this.sendKey(FunctionKeySequences.F2));
          this.VKey('F3', () => this.sendKey(FunctionKeySequences.F3));
          this.VKey('F4', () => this.sendKey(FunctionKeySequences.F4));
          Blank();
          this.VKey('F5', () => this.sendKey(FunctionKeySequences.F5));
          this.VKey('F6', () => this.sendKey(FunctionKeySequences.F6));
          this.HideVKeyButton();
        }
        Row() {
          this.VKey('F7', () => this.sendKey(FunctionKeySequences.F7));
          this.VKey('F8', () => this.sendKey(FunctionKeySequences.F8));
          this.VKey('F9', () => this.sendKey(FunctionKeySequences.F9));
          this.VKey('F10', () => this.sendKey(FunctionKeySequences.F10));
          this.VKey('F11', () => this.sendKey(FunctionKeySequences.F11));
          this.VKey('F12', () => this.sendKey(FunctionKeySequences.F12));
        }
      } else {
        // 普通模式
        Row() {
          this.VKey('ESC', () => this.sendKey(NormalKeySequences.ESC));
          this.VKey('FN', () => this.fnPressed = !this.fnPressed, this.fnPressed);
          this.VKey('/', () => this.sendKey('/'));
          Blank();
          this.VKey('PGUP', () => this.sendKey(NormalKeySequences.PGUP));
          this.VKey('HOME', () => this.sendKey(NormalKeySequences.HOME));
          this.VKey('↑', () => this.sendKey(this.applicationMode ? NormalKeySequences.UP_APP : NormalKeySequences.UP));
          this.VKey('END', () => this.sendKey(NormalKeySequences.END));
        }
        Row() {
          this.VKey('TAB', () => this.sendKey(NormalKeySequences.TAB));
          this.VKey('CTRL', () => this.ctrlPressed = !this.ctrlPressed, this.ctrlPressed);
          this.VKey('-', () => this.sendKey('-'));
          Blank();
          this.VKey('PGDN', () => this.sendKey(NormalKeySequences.PGDN));
          this.VKey('←', () => this.sendKey(this.applicationMode ? NormalKeySequences.LEFT_APP : NormalKeySequences.LEFT));
          this.VKey('↓', () => this.sendKey(this.applicationMode ? NormalKeySequences.DOWN_APP : NormalKeySequences.DOWN));
          this.VKey('→', () => this.sendKey(this.applicationMode ? NormalKeySequences.RIGHT_APP : NormalKeySequences.RIGHT));
          this.HideVKeyButton();
        }
      }
    }
    .width('100%')
    .backgroundColor('#1a1a1a')
    .padding({ top: 4, bottom: 4 });
  }

  @Builder
  VKey(label: string, action: () => void, active: boolean = false) {
    Button(label)
      .fontSize(VKeyFontSize)
      .fontWeight(active ? FontWeight.Bold : FontWeight.Normal)
      .backgroundColor(active ? '#2196F3' : '#333333')
      .fontColor(Color.White)
      .height(VKeyHeight)
      .borderRadius(VKeyRadius)
      .margin({ left: VKeyMargin, right: VKeyMargin })
      .padding({ left: VKeyPadding, right: VKeyPadding })
      .onClick(action);
  }

  @Builder
  HideVKeyButton() {
    Button('▼')
      .fontSize(VKeyFontSize)
      .backgroundColor('#333333')
      .fontColor('#888888')
      .height(VKeyHeight)
      .width(VKeyHeight)
      .borderRadius(VKeyRadius)
      .margin({ left: VKeyMargin, right: VKeyMargin })
      .onClick(() => this.showVirtKey = false);
  }

  @Builder
  ShowVirtualKeysButton() {
    Button('▲')
      .fontSize(12)
      .backgroundColor('#1a1a1a')
      .fontColor('#444444')
      .height(20)
      .width(100)
      .onClick(() => this.showVirtKey = true);
  }

  // ========== 方法 ==========

  showTerminalView(): void {
    if (!this.sessionManager?.activeSession) {
      this.sessionManager?.createSession();
    }
    this.showTerminal = true;
    this.updateSessionTabs();
  }

  showWebView(): void {
    this.showTerminal = false;
  }

  private updateSessionTabs(): void {
    if (this.sessionManager) {
      this.sessions = this.sessionManager.getSessionsInfo();
      this.activeSessionId = this.sessionManager.activeSessionId || '';
    }
  }

  private sendKey(key: string): void {
    // 应用修饰键
    const result = applyVirtualKeyModifiers(key, this.ctrlPressed, this.shiftPressed);
    let data = result.data;
    
    if (result.shouldResetCtrl) {
      this.ctrlPressed = false;
    }
    
    // 发送输入
    this.sendInput(data);
  }

  // ========== JavaScript 接口 ==========

  sendInput(data: string): void {
    hilog.debug(DOMAIN, TAG, `sendInput: ${data}`);
    
    // 转换为 ArrayBuffer
    const buffer = stringToArrayBuffer(data, 'utf-8');
    
    // 发送到原生模块
    terminalNative.sendInput(buffer);
  }

  resize(width: number, height: number): void {
    hilog.info(DOMAIN, TAG, `resize: ${width}x${height}`);
    // 发送终端大小变化
    this.sendInput('\x1b' + `[8;${height};${width}t`);
  }

  load(): void {
    hilog.info(DOMAIN, TAG, 'load terminal');
    
    // 设置焦点
    this.webController.runJavaScript('exports.setFocused(true)');
    
    // 注册数据回调
    terminalNative.onData((data: ArrayBuffer) => {
      this.onData(data);
    });
    
    // 注册关闭回调
    terminalNative.onShutdown(() => {
      hilog.info(DOMAIN, TAG, 'terminal shutdown');
    });
  }

  getFontSize(): number {
    return this.currentTextSize;
  }

  getDeviceType(): string {
    return deviceInfo.deviceType;
  }

  setApplicationMode(mode: boolean): void {
    this.applicationMode = mode;
    hilog.info(DOMAIN, TAG, `applicationMode: ${mode}`);
  }

  // ========== 数据处理 ==========

  private onData(ab: ArrayBuffer): void {
    try {
      // 将收到的数据块加入队列
      this.pendingChunks.push(new Uint8Array(ab));
      
      // 如果没有正在等待的 Flush 任务，则调度一个
      if (this.flushTimeoutID === undefined) {
        this.flushTimeoutID = setTimeout(() => {
          this.flushData();
        }, this.FLUSH_INTERVAL);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, `onData failed: ${e}`);
    }
  }

  private flushData(): void {
    this.flushTimeoutID = undefined;
    
    if (this.pendingChunks.length === 0) return;
    
    try {
      // 计算总长度
      let totalLength = 0;
      for (const chunk of this.pendingChunks) {
        totalLength += chunk.length;
      }
      
      // 合并所有 Chunk
      const merged = new Uint8Array(totalLength);
      let offset = 0;
      for (const chunk of this.pendingChunks) {
        merged.set(chunk, offset);
        offset += chunk.length;
      }
      
      // 清空缓冲区
      this.pendingChunks = [];
      
      // 转换为 base64 并发送到 WebView
      const base64 = this.arrayBufferToBase64(merged.buffer);
      this.webController.runJavaScript(`exports.writeBase64("${base64}", ${this.applicationMode})`);
      
    } catch (e) {
      hilog.error(DOMAIN, TAG, `flushData failed: ${e}`);
      this.pendingChunks = [];
    }
  }

  private arrayBufferToBase64(buffer: ArrayBuffer): string {
    const bytes = new Uint8Array(buffer);
    let binary = '';
    for (let i = 0; i < bytes.length; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary);
  }
}

/**
 * 会话信息
 */
interface SessionInfo {
  id: string;
  name: string;
  active: boolean;
  finished: boolean;
}

export default MainPage;
