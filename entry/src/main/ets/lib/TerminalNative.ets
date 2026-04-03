/**
 * 终端原生桥接 (模拟实现)
 * 实际需要 NAPI 原生模块
 */
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'TerminalNative';

/**
 * 终端原生模块
 * 注意: 这是模拟实现，实际需要 C++ NAPI 模块
 */
export class TerminalNative {
  private onDataCallback: ((data: ArrayBuffer) => void) | null = null;
  private onShutdownCallback: (() => void) | null = null;
  private running: boolean = false;
  private outputInterval: number | null = null;

  /**
   * 发送输入
   */
  sendInput(data: ArrayBuffer): void {
    hilog.debug(DOMAIN, TAG, `sendInput: ${data.byteLength} bytes`);
    
    // 模拟: 将输入回显
    const decoder = new TextDecoder('utf-8');
    const text = decoder.decode(data);
    
    // 模拟 shell 响应
    setTimeout(() => {
      this.simulateOutput(text);
    }, 50);
  }

  /**
   * 设置数据回调
   */
  onData(callback: (data: ArrayBuffer) => void): void {
    this.onDataCallback = callback;
    this.running = true;
    
    // 发送欢迎消息
    setTimeout(() => {
      this.sendOutput('\x1b[32mHarmonyClaw Terminal v1.0.0\x1b[0m\r\n');
      this.sendOutput('\x1b[33m注意: 这是模拟终端，实际功能需要原生 PTY 支持\x1b[0m\r\n');
      this.sendOutput('\r\n');
      this.sendOutput('$ ');
    }, 100);
  }

  /**
   * 设置关闭回调
   */
  onShutdown(callback: () => void): void {
    this.onShutdownCallback = callback;
  }

  /**
   * 模拟输出
   */
  private simulateOutput(input: string): void {
    // 简单的命令模拟
    const cmd = input.trim().toLowerCase();
    
    if (cmd === 'help' || cmd === '?') {
      this.sendOutput('可用命令:\r\n');
      this.sendOutput('  help, ?    - 显示帮助\r\n');
      this.sendOutput('  clear      - 清屏\r\n');
      this.sendOutput('  date       - 显示日期\r\n');
      this.sendOutput('  echo <msg> - 回显消息\r\n');
      this.sendOutput('  exit       - 退出\r\n');
    } else if (cmd === 'clear') {
      this.sendOutput('\x1b[2J\x1b[H');
    } else if (cmd === 'date') {
      this.sendOutput(new Date().toLocaleString() + '\r\n');
    } else if (cmd.startsWith('echo ')) {
      this.sendOutput(cmd.substring(5) + '\r\n');
    } else if (cmd === 'exit') {
      this.sendOutput('Goodbye!\r\n');
      if (this.onShutdownCallback) {
        this.onShutdownCallback();
      }
      return;
    } else if (cmd === '') {
      // 空命令
    } else {
      this.sendOutput(`sh: ${cmd}: command not found\r\n`);
    }
    
    this.sendOutput('$ ');
  }

  /**
   * 发送输出
   */
  private sendOutput(text: string): void {
    if (this.onDataCallback) {
      const encoder = new TextEncoder();
      const data = encoder.encode(text);
      this.onDataCallback(data.buffer);
    }
  }

  /**
   * 关闭
   */
  close(): void {
    this.running = false;
    if (this.outputInterval !== null) {
      clearInterval(this.outputInterval);
    }
  }
}

// 导出单例
export const terminalNative = new TerminalNative();
export default terminalNative;
