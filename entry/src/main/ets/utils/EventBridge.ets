/**
 * 事件桥接器
 * 参考 android-openclaw EventBridge.kt
 */
import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'EventBridge';

/**
 * 事件桥接器
 * 从 ArkTS 向 WebView 发送事件
 */
export class EventBridge {
  private webController: webview.WebviewController;

  constructor(webController: webview.WebviewController) {
    this.webController = webController;
  }

  /**
   * 向 WebView 发送事件
   */
  emit(type: string, data: any | null): void {
    const json = JSON.stringify(data || {});
    const script = `window.__oc && window.__oc.emit('${type}', ${json})`;
    
    try {
      this.webController.runJavaScript(script);
      hilog.debug(DOMAIN, TAG, `Event emitted: ${type}`);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, `Failed to emit event: ${e}`);
    }
  }

  /**
   * 发送进度事件
   */
  emitProgress(target: string, progress: number, message: string): void {
    this.emit('install_progress', {
      target,
      progress,
      message
    });
  }

  /**
   * 发送命令输出事件
   */
  emitCommandOutput(callbackId: string, data: string, done: boolean): void {
    this.emit('command_output', {
      callbackId,
      data,
      done
    });
  }

  /**
   * 发送会话变更事件
   */
  emitSessionChanged(id: string, action: 'created' | 'switched' | 'closed' | 'finished'): void {
    this.emit('session_changed', {
      id,
      action
    });
  }

  /**
   * 发送设置进度事件
   */
  emitSetupProgress(progress: number, message: string): void {
    this.emit('setup_progress', {
      progress,
      message
    });
  }
}

export default EventBridge;
