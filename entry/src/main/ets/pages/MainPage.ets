/**
 * 主入口页面
 * 参考 HiSH 和 android-openclaw 设计
 */
import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { TerminalSessionManager } from '../models/TerminalSessionManager';
import { BootstrapManager } from '../models/BootstrapManager';
import { JsBridge } from '../utils/JsBridge';
import { EventBridge } from '../utils/EventBridge';
import { Constants } from '../common/Constants';

const DOMAIN = 0x0000;
const TAG = 'MainPage';

@Entry
@Component
struct MainPage {
  // 状态
  @State currentTextSize: number = 14;
  @State ctrlPressed: boolean = false;
  @State altPressed: boolean = false;
  @State showTerminal: boolean = false;
  @State sessions: Array<SessionInfo> = [];
  @State activeSessionId: string = '';
  @State showVirtKey: boolean = true;
  @State fnPressed: boolean = false;
  
  // 控制器
  private webController: webview.WebviewController = new webview.WebviewController();
  private context: common.Context = getContext(this) as common.Context;
  
  // 管理器
  private sessionManager: TerminalSessionManager | null = null;
  private bootstrapManager: BootstrapManager | null = null;
  private eventBridge: EventBridge | null = null;
  private jsBridge: JsBridge | null = null;

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
      const session = this.sessionManager.createSession();
      if (this.bootstrapManager.needsPostSetup()) {
        setTimeout(() => {
          const script = this.bootstrapManager!.postSetupScript;
          session.write(`bash ${script}\n`);
        }, 500);
      }
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
              .onClick(() => this.sessionManager?.createSession());
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
              if (this.currentTextSize > 10) this.currentTextSize -= 2;
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
              if (this.currentTextSize < 24) this.currentTextSize += 2;
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
      src: this.getWebViewUrl(),
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
      // 终端视图
      this.TerminalView();
      
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
  TerminalView() {
    // 使用 WebView 渲染终端 (参考 HiSH)
    Web({
      src: $rawfile('term/term.html'),
      controller: this.webController
    })
      .javaScriptProxy({
        object: this,
        name: 'native',
        methodList: ['sendInput', 'resize', 'load', 'getFontSize'],
        controller: this.webController,
        asyncMethodList: []
      })
      .backgroundColor('#000')
      .layoutWeight(1);
  }

  @Builder
  VirtualKeys() {
    Column() {
      if (this.fnPressed) {
        // FN 模式 - 功能键
        Row() {
          this.VKey('FN', () => this.fnPressed = !this.fnPressed, true);
          this.VKey('F1', () => this.sendKey('\x1bOP'));
          this.VKey('F2', () => this.sendKey('\x1bOQ'));
          this.VKey('F3', () => this.sendKey('\x1bOR'));
          this.VKey('F4', () => this.sendKey('\x1bOS'));
          Blank();
          this.VKey('F5', () => this.sendKey('\x1b[15~'));
          this.VKey('F6', () => this.sendKey('\x1b[17~'));
          this.HideVKeyButton();
        }
        Row() {
          this.VKey('F7', () => this.sendKey('\x1b[18~'));
          this.VKey('F8', () => this.sendKey('\x1b[19~'));
          this.VKey('F9', () => this.sendKey('\x1b[20~'));
          this.VKey('F10', () => this.sendKey('\x1b[21~'));
          this.VKey('F11', () => this.sendKey('\x1b[23~'));
          this.VKey('F12', () => this.sendKey('\x1b[24~'));
        }
      } else {
        // 普通模式
        Row() {
          this.VKey('ESC', () => this.sendKey('\x1b'));
          this.VKey('FN', () => this.fnPressed = !this.fnPressed, this.fnPressed);
          this.VKey('/', () => this.sendKey('/'));
          Blank();
          this.VKey('PGUP', () => this.sendKey('\x1b[5~'));
          this.VKey('HOME', () => this.sendKey('\x1b[H'));
          this.VKey('↑', () => this.sendKey('\x1b[A'));
          this.VKey('END', () => this.sendKey('\x1b[F'));
        }
        Row() {
          this.VKey('TAB', () => this.sendKey('\t'));
          this.VKey('CTRL', () => this.ctrlPressed = !this.ctrlPressed, this.ctrlPressed);
          this.VKey('-', () => this.sendKey('-'));
          Blank();
          this.VKey('PGDN', () => this.sendKey('\x1b[6~'));
          this.VKey('←', () => this.sendKey('\x1b[D'));
          this.VKey('↓', () => this.sendKey('\x1b[B'));
          this.VKey('→', () => this.sendKey('\x1b[C'));
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
      .fontSize(12)
      .fontWeight(active ? FontWeight.Bold : FontWeight.Normal)
      .backgroundColor(active ? '#2196F3' : '#333333')
      .fontColor(Color.White)
      .height(36)
      .borderRadius(6)
      .margin({ left: 2, right: 2 })
      .onClick(action);
  }

  @Builder
  HideVKeyButton() {
    Button('▼')
      .fontSize(12)
      .backgroundColor('#333333')
      .fontColor('#888888')
      .height(36)
      .width(36)
      .borderRadius(6)
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

  private getWebViewUrl(): string {
    const wwwDir = this.bootstrapManager?.wwwDir;
    if (wwwDir) {
      return `file://${wwwDir}/index.html`;
    }
    return 'resource://rawfile/www/index.html';
  }

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
    let data = key;
    
    // 处理 Ctrl 组合
    if (this.ctrlPressed && key.length === 1) {
      const code = key.charCodeAt(0);
      if (code >= 97 && code <= 122) {
        data = String.fromCharCode(code - 96);
      }
    }
    
    this.sessionManager?.activeSession?.write(data);
    
    // 重置修饰键
    this.ctrlPressed = false;
  }

  // ========== JavaScript 接口 ==========

  sendInput(data: string): void {
    this.sessionManager?.activeSession?.write(data);
  }

  resize(width: number, height: number): void {
    hilog.info(DOMAIN, TAG, `resize: ${width}x${height}`);
  }

  load(): void {
    hilog.info(DOMAIN, TAG, 'load terminal');
  }

  getFontSize(): number {
    return this.currentTextSize;
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
