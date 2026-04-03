/**
 * 终端模拟器核心
 * ANSI 转义序列解析和状态管理
 */
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'TerminalEmulator';

/**
 * 终端状态
 */
export class TerminalState {
  cols: number;
  rows: number;
  cursorX: number = 0;
  cursorY: number = 0;
  buffer: string[][] = [];
  scrollback: string[] = [];
  
  constructor(cols: number, rows: number) {
    this.cols = cols;
    this.rows = rows;
    this.initBuffer();
  }
  
  private initBuffer(): void {
    this.buffer = [];
    for (let y = 0; y < this.rows; y++) {
      this.buffer[y] = [];
      for (let x = 0; x < this.cols; x++) {
        this.buffer[y][x] = ' ';
      }
    }
  }
}

/**
 * 终端模拟器
 */
export class TerminalEmulator {
  private state: TerminalState;
  private onData: ((data: string) => void) | null = null;
  
  // 解析状态
  private parseState: 'normal' | 'escape' | 'csi' = 'normal';
  private csiParams: number[] = [];
  
  constructor(cols: number = 80, rows: number = 24) {
    this.state = new TerminalState(cols, rows);
    hilog.info(DOMAIN, TAG, `TerminalEmulator created: ${cols}x${rows}`);
  }
  
  /**
   * 处理输入数据
   */
  process(data: string): void {
    for (const char of data) {
      this.processChar(char);
    }
  }
  
  /**
   * 处理单个字符
   */
  private processChar(char: string): void {
    switch (this.parseState) {
      case 'normal':
        this.processNormal(char);
        break;
      case 'escape':
        this.processEscape(char);
        break;
      case 'csi':
        this.processCsi(char);
        break;
    }
  }
  
  /**
   * 处理普通字符
   */
  private processNormal(char: string): void {
    if (char === '\x1b') {
      this.parseState = 'escape';
    } else if (char === '\n') {
      this.lineFeed();
    } else if (char === '\r') {
      this.carriageReturn();
    } else if (char === '\t') {
      this.tab();
    } else if (char === '\b') {
      this.backspace();
    } else if (char.charCodeAt(0) >= 32) {
      this.putChar(char);
    }
  }
  
  /**
   * 处理转义字符
   */
  private processEscape(char: string): void {
    if (char === '[') {
      this.parseState = 'csi';
      this.csiParams = [];
    } else {
      this.parseState = 'normal';
    }
  }
  
  /**
   * 处理 CSI 序列
   */
  private processCsi(char: string): void {
    if (char >= '0' && char <= '9') {
      // 数字参数
    } else if (char >= '@' && char <= '~') {
      // 最终字符
      this.executeCsi(char);
      this.parseState = 'normal';
    }
  }
  
  /**
   * 执行 CSI 命令
   */
  private executeCsi(final: string): void {
    switch (final) {
      case 'A': // 光标上移
        this.cursorUp(this.csiParams[0] || 1);
        break;
      case 'B': // 光标下移
        this.cursorDown(this.csiParams[0] || 1);
        break;
      case 'C': // 光标右移
        this.cursorForward(this.csiParams[0] || 1);
        break;
      case 'D': // 光标左移
        this.cursorBack(this.csiParams[0] || 1);
        break;
      case 'H': // 光标定位
        this.cursorPosition(
          this.csiParams[0] || 1,
          this.csiParams[1] || 1
        );
        break;
      case 'J': // 清屏
        this.eraseDisplay(this.csiParams[0] || 0);
        break;
      case 'K': // 清行
        this.eraseLine(this.csiParams[0] || 0);
        break;
    }
  }
  
  // ========== 光标操作 ==========
  
  private cursorUp(n: number): void {
    this.state.cursorY = Math.max(0, this.state.cursorY - n);
  }
  
  private cursorDown(n: number): void {
    this.state.cursorY = Math.min(this.state.rows - 1, this.state.cursorY + n);
  }
  
  private cursorForward(n: number): void {
    this.state.cursorX = Math.min(this.state.cols - 1, this.state.cursorX + n);
  }
  
  private cursorBack(n: number): void {
    this.state.cursorX = Math.max(0, this.state.cursorX - n);
  }
  
  private cursorPosition(row: number, col: number): void {
    this.state.cursorY = Math.min(this.state.rows - 1, row - 1);
    this.state.cursorX = Math.min(this.state.cols - 1, col - 1);
  }
  
  // ========== 基本操作 ==========
  
  private putChar(char: string): void {
    if (this.state.cursorX >= this.state.cols) {
      this.carriageReturn();
      this.lineFeed();
    }
    
    if (this.state.cursorY < this.state.rows && 
        this.state.cursorX < this.state.cols) {
      this.state.buffer[this.state.cursorY][this.state.cursorX] = char;
      this.state.cursorX++;
    }
  }
  
  private carriageReturn(): void {
    this.state.cursorX = 0;
  }
  
  private lineFeed(): void {
    if (this.state.cursorY < this.state.rows - 1) {
      this.state.cursorY++;
    } else {
      // 滚动
      this.scrollUp();
    }
  }
  
  private tab(): void {
    const nextTab = Math.floor(this.state.cursorX / 8 + 1) * 8;
    this.state.cursorX = Math.min(nextTab, this.state.cols - 1);
  }
  
  private backspace(): void {
    if (this.state.cursorX > 0) {
      this.state.cursorX--;
    }
  }
  
  private scrollUp(): void {
    // 保存第一行到滚动缓冲区
    const firstLine = this.state.buffer[0].join('');
    this.state.scrollback.push(firstLine);
    if (this.state.scrollback.length > 1000) {
      this.state.scrollback.shift();
    }
    
    // 移动行
    for (let y = 0; y < this.state.rows - 1; y++) {
      this.state.buffer[y] = this.state.buffer[y + 1];
    }
    
    // 清空最后一行
    this.state.buffer[this.state.rows - 1] = [];
    for (let x = 0; x < this.state.cols; x++) {
      this.state.buffer[this.state.rows - 1][x] = ' ';
    }
  }
  
  // ========== 擦除操作 ==========
  
  private eraseDisplay(mode: number): void {
    switch (mode) {
      case 0: // 从光标到末尾
        this.eraseFromCursorToEnd();
        break;
      case 1: // 从开头到光标
        this.eraseFromStartToCursor();
        break;
      case 2: // 整个屏幕
        this.eraseAll();
        break;
    }
  }
  
  private eraseLine(mode: number): void {
    const y = this.state.cursorY;
    switch (mode) {
      case 0: // 从光标到行尾
        for (let x = this.state.cursorX; x < this.state.cols; x++) {
          this.state.buffer[y][x] = ' ';
        }
        break;
      case 1: // 从行首到光标
        for (let x = 0; x <= this.state.cursorX; x++) {
          this.state.buffer[y][x] = ' ';
        }
        break;
      case 2: // 整行
        for (let x = 0; x < this.state.cols; x++) {
          this.state.buffer[y][x] = ' ';
        }
        break;
    }
  }
  
  private eraseFromCursorToEnd(): void {
    const { cursorX, cursorY } = this.state;
    for (let x = cursorX; x < this.state.cols; x++) {
      this.state.buffer[cursorY][x] = ' ';
    }
    for (let y = cursorY + 1; y < this.state.rows; y++) {
      for (let x = 0; x < this.state.cols; x++) {
        this.state.buffer[y][x] = ' ';
      }
    }
  }
  
  private eraseFromStartToCursor(): void {
    const { cursorX, cursorY } = this.state;
    for (let y = 0; y < cursorY; y++) {
      for (let x = 0; x < this.state.cols; x++) {
        this.state.buffer[y][x] = ' ';
      }
    }
    for (let x = 0; x <= cursorX; x++) {
      this.state.buffer[cursorY][x] = ' ';
    }
  }
  
  private eraseAll(): void {
    for (let y = 0; y < this.state.rows; y++) {
      for (let x = 0; x < this.state.cols; x++) {
        this.state.buffer[y][x] = ' ';
      }
    }
  }
  
  // ========== 公共方法 ==========
  
  getState(): TerminalState {
    return this.state;
  }
  
  resize(cols: number, rows: number): void {
    this.state = new TerminalState(cols, rows);
  }
  
  getContent(): string {
    let content = '';
    for (let y = 0; y < this.state.rows; y++) {
      content += this.state.buffer[y].join('') + '\n';
    }
    return content;
  }
}

export default TerminalEmulator;
