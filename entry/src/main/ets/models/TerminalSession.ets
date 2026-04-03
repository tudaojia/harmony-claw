/**
 * 终端会话
 * 参考 Termux TerminalSession 和 android-openclaw
 */
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'TerminalSession';

/**
 * 终端会话类
 */
export class TerminalSession {
  private _id: string;
  private _title: string = 'Terminal';
  private _pid: number = -1;
  private _exitCode: number = -1;
  private _finished: boolean = false;
  
  // 终端尺寸
  private _cols: number = 80;
  private _rows: number = 24;
  
  // 环境变量
  private _env: Map<string, string> = new Map();
  
  // 工作目录
  private _cwd: string = '';
  
  // 回调
  private _onData: ((data: string) => void) | null = null;
  private _onExit: ((code: number) => void) | null = null;
  private _onTitleChange: ((title: string) => void) | null = null;
  
  // 输出缓冲区
  private outputBuffer: string = '';
  private maxBufferSize: number = 1024 * 1024; // 1MB
  
  // 会话计数器
  private static sessionCounter: number = 0;

  constructor(
    shell: string,
    cwd: string,
    args: string[],
    env: Map<string, string>,
    transcriptRows: number
  ) {
    this._id = this.generateId();
    this._cwd = cwd;
    this._cols = 80;
    this._rows = transcriptRows;
    
    // 设置环境变量
    for (const [key, value] of env) {
      this._env.set(key, value);
    }
    
    // 设置标题
    this._title = shell.split('/').pop() || 'Terminal';
    
    hilog.info(DOMAIN, TAG, `TerminalSession created: ${this._id}`);
  }

  // ========== 属性 ==========

  get id(): string {
    return this._id;
  }

  get title(): string {
    return this._title;
  }

  get pid(): number {
    return this._pid;
  }

  get exitCode(): number {
    return this._exitCode;
  }

  get finished(): boolean {
    return this._finished;
  }

  get cols(): number {
    return this._cols;
  }

  get rows(): number {
    return this._rows;
  }

  get cwd(): string {
    return this._cwd;
  }

  // ========== 方法 ==========

  /**
   * 写入数据到终端
   */
  write(data: string): void {
    if (this._finished) return;
    
    // 添加到输出缓冲区
    this.outputBuffer += data;
    
    // 限制缓冲区大小
    if (this.outputBuffer.length > this.maxBufferSize) {
      this.outputBuffer = this.outputBuffer.slice(-this.maxBufferSize);
    }
    
    // 触发回调
    if (this._onData) {
      this._onData(data);
    }
    
    hilog.debug(DOMAIN, TAG, `Session ${this._id} write: ${data.length} bytes`);
  }

  /**
   * 调整终端大小
   */
  resize(cols: number, rows: number): void {
    this._cols = cols;
    this._rows = rows;
    hilog.info(DOMAIN, TAG, `Session ${this._id} resize: ${cols}x${rows}`);
  }

  /**
   * 设置标题
   */
  setTitle(title: string): void {
    this._title = title;
    if (this._onTitleChange) {
      this._onTitleChange(title);
    }
  }

  /**
   * 获取终端内容
   */
  getContent(): string {
    return this.outputBuffer;
  }

  /**
   * 销毁会话
   */
  destroy(): void {
    if (this._finished) return;
    
    this._finished = true;
    this._exitCode = 0;
    
    // 清理资源
    this.outputBuffer = '';
    this._onData = null;
    this._onExit = null;
    this._onTitleChange = null;
    
    hilog.info(DOMAIN, TAG, `Session ${this._id} destroyed`);
  }

  // ========== 回调设置 ==========

  onData(callback: (data: string) => void): void {
    this._onData = callback;
  }

  onExit(callback: (code: number) => void): void {
    this._onExit = callback;
  }

  onTitleChange(callback: (title: string) => void): void {
    this._onTitleChange = callback;
  }

  // ========== 辅助方法 ==========

  private generateId(): string {
    TerminalSession.sessionCounter++;
    return `session_${Date.now()}_${TerminalSession.sessionCounter}`;
  }
}

export default TerminalSession;
