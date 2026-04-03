/**
 * Terminal Session (模块版本)
 */
export class TerminalSession {
  private _id: string;
  private _title: string = 'Terminal';
  
  constructor(
    shell: string,
    cwd: string,
    args: string[],
    env: Map<string, string>,
    transcriptRows: number
  ) {
    this._id = `session_${Date.now()}`;
    this._title = shell.split('/').pop() || 'Terminal';
  }
  
  get id(): string { return this._id; }
  get title(): string { return this._title; }
  
  write(data: string): void {}
  destroy(): void {}
}

export default TerminalSession;
