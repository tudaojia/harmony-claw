/**
 * 终端会话管理器
 * 参考 android-openclaw TerminalSessionManager.kt
 */
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TerminalSession } from './TerminalSession';
import { EventBridge } from '../utils/EventBridge';
import { EnvironmentBuilder } from '../utils/EnvironmentBuilder';

const DOMAIN = 0x0000;
const TAG = 'TerminalSessionManager';

/**
 * 会话信息
 */
export interface SessionInfo {
  id: string;
  name: string;
  active: boolean;
  finished: boolean;
}

/**
 * 终端会话管理器
 */
export class TerminalSessionManager {
  private context: common.Context;
  private eventBridge: EventBridge;
  private sessions: TerminalSession[] = [];
  private activeSessionIndex: number = -1;
  private finishedSessionIds: Set<string> = new Set();
  private onSessionsChangedCallback: (() => void) | null = null;
  
  private static readonly TRANSCRIPT_ROWS = 2000;
  private sessionCounter: number = 0;

  constructor(context: common.Context, eventBridge: EventBridge) {
    this.context = context;
    this.eventBridge = eventBridge;
    hilog.info(DOMAIN, TAG, 'TerminalSessionManager created');
  }

  /**
   * 获取活动会话
   */
  get activeSession(): TerminalSession | null {
    return this.sessions[this.activeSessionIndex] || null;
  }

  /**
   * 获取活动会话 ID
   */
  get activeSessionId(): string | null {
    return this.activeSession?.id || null;
  }

  /**
   * 获取会话数量
   */
  get sessionCount(): number {
    return this.sessions.length;
  }

  /**
   * 创建新会话
   */
  createSession(): TerminalSession {
    hilog.info(DOMAIN, TAG, 'Creating new session');
    
    const env = EnvironmentBuilder.build(this.context);
    const prefix = env.get('PREFIX') || '';
    const homeDir = env.get('HOME') || this.context.filesDir;

    // 选择 shell
    let shell = '/system/bin/sh';
    // 检查 bash 是否存在
    // if (this.fileExists(`${prefix}/bin/bash`)) {
    //   shell = `${prefix}/bin/bash`;
    // }

    // 创建会话
    const session = new TerminalSession(
      shell,
      homeDir,
      [],
      env,
      TerminalSessionManager.TRANSCRIPT_ROWS
    );

    this.sessions.push(session);
    this.switchSession(this.sessions.length - 1);

    // 发送事件
    this.eventBridge.emit('session_changed', {
      id: session.id,
      action: 'created'
    });

    if (this.onSessionsChangedCallback) {
      this.onSessionsChangedCallback();
    }

    hilog.info(DOMAIN, TAG, `Session created: ${session.id}, total: ${this.sessions.length}`);
    return session;
  }

  /**
   * 切换会话
   */
  switchSession(idOrIndex: string | number): void {
    let index: number;
    
    if (typeof idOrIndex === 'string') {
      index = this.sessions.findIndex(s => s.id === idOrIndex);
    } else {
      index = idOrIndex;
    }
    
    if (index < 0 || index >= this.sessions.length) return;
    
    this.activeSessionIndex = index;
    const session = this.sessions[index];

    // 发送事件
    this.eventBridge.emit('session_changed', {
      id: session.id,
      action: 'switched'
    });

    if (this.onSessionsChangedCallback) {
      this.onSessionsChangedCallback();
    }
    
    hilog.info(DOMAIN, TAG, `Switched to session: ${session.id}`);
  }

  /**
   * 根据 ID 获取会话
   */
  getSessionById(id: string): TerminalSession | null {
    return this.sessions.find(s => s.id === id) || null;
  }

  /**
   * 关闭会话
   */
  closeSession(id: string): void {
    const index = this.sessions.findIndex(s => s.id === id);
    if (index < 0) return;

    this.finishedSessionIds.delete(id);
    const session = this.sessions.splice(index, 1)[0];
    session.destroy();

    // 发送事件
    this.eventBridge.emit('session_changed', {
      id: id,
      action: 'closed'
    });

    // 切换到其他会话
    if (this.sessions.length > 0) {
      const newIndex = Math.min(index, this.sessions.length - 1);
      this.switchSession(newIndex);
    } else {
      this.activeSessionIndex = -1;
    }

    if (this.onSessionsChangedCallback) {
      this.onSessionsChangedCallback();
    }

    hilog.info(DOMAIN, TAG, `Session closed: ${id}, remaining: ${this.sessions.length}`);
  }

  /**
   * 会话结束回调
   */
  onSessionFinished(session: TerminalSession): void {
    this.finishedSessionIds.add(session.id);
    
    this.eventBridge.emit('session_changed', {
      id: session.id,
      action: 'finished'
    });

    if (this.onSessionsChangedCallback) {
      this.onSessionsChangedCallback();
    }
  }

  /**
   * 获取所有会话信息
   */
  getSessionsInfo(): SessionInfo[] {
    return this.sessions.map((session, index) => ({
      id: session.id,
      name: session.title || `Session ${index + 1}`,
      active: index === this.activeSessionIndex,
      finished: this.finishedSessionIds.has(session.id)
    }));
  }

  /**
   * 设置会话变更回调
   */
  setOnSessionsChanged(callback: () => void): void {
    this.onSessionsChangedCallback = callback;
  }
}

export default TerminalSessionManager;
