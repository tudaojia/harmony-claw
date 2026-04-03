/**
 * Bootstrap 安装管理器
 * 参考 android-openclaw BootstrapManager.kt
 */
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import fs from '@ohos.file.fs';

const DOMAIN = 0x0000;
const TAG = 'BootstrapManager';

/**
 * 安装状态
 */
export interface SetupStatus {
  bootstrapInstalled: boolean;
  runtimeInstalled: boolean;
  wwwInstalled: boolean;
}

/**
 * Bootstrap 管理器
 */
export class BootstrapManager {
  private context: common.Context;
  
  // 目录
  readonly prefixDir: string;
  readonly homeDir: string;
  readonly tmpDir: string;
  readonly wwwDir: string;

  constructor(context: common.Context) {
    this.context = context;
    
    this.prefixDir = `${context.filesDir}/usr`;
    this.homeDir = `${context.filesDir}/home`;
    this.tmpDir = `${context.filesDir}/tmp`;
    this.wwwDir = `${this.prefixDir}/share/openclaw-app/www`;
    
    hilog.info(DOMAIN, TAG, `BootstrapManager created`);
    hilog.info(DOMAIN, TAG, `prefixDir: ${this.prefixDir}`);
    hilog.info(DOMAIN, TAG, `homeDir: ${this.homeDir}`);
  }

  /**
   * 检查是否已安装
   */
  isInstalled(): boolean {
    return this.fileExists(`${this.prefixDir}/bin/sh`);
  }

  /**
   * 是否需要后续设置
   */
  needsPostSetup(): boolean {
    const marker = `${this.homeDir}/.openclaw-android/.post-setup-done`;
    return this.isInstalled() && !this.fileExists(marker);
  }

  /**
   * 获取后续设置脚本路径
   */
  get postSetupScript(): string {
    return `${this.homeDir}/.openclaw-android/post-setup.sh`;
  }

  /**
   * 获取安装状态
   */
  getStatus(): SetupStatus {
    return {
      bootstrapInstalled: this.isInstalled(),
      runtimeInstalled: this.fileExists(`${this.prefixDir}/bin/node`),
      wwwInstalled: this.fileExists(`${this.wwwDir}/index.html`)
    };
  }

  /**
   * 执行完整安装
   */
  async startSetup(
    onProgress: (progress: number, message: string) => void
  ): Promise<void> {
    if (this.isInstalled()) {
      onProgress(1, 'Already installed');
      return;
    }

    try {
      // 步骤 1: 准备目录
      onProgress(0.1, 'Creating directories...');
      this.setupDirectories();

      // 步骤 2: 下载资源
      onProgress(0.3, 'Downloading resources...');
      // TODO: 实现下载

      // 步骤 3: 解压安装
      onProgress(0.6, 'Extracting...');
      // TODO: 实现解压

      // 步骤 4: 配置环境
      onProgress(0.8, 'Configuring...');
      this.configureEnvironment();

      // 步骤 5: 完成
      onProgress(1, 'Setup complete');
      
      hilog.info(DOMAIN, TAG, 'Bootstrap setup completed');
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Setup failed: ${e}`);
      throw e;
    }
  }

  /**
   * 设置目录
   */
  private setupDirectories(): void {
    const dirs = [
      this.prefixDir,
      `${this.prefixDir}/bin`,
      `${this.prefixDir}/lib`,
      `${this.prefixDir}/etc`,
      this.homeDir,
      `${this.homeDir}/.openclaw-android`,
      this.tmpDir,
      this.wwwDir
    ];
    
    for (const dir of dirs) {
      this.createDir(dir);
    }
  }

  /**
   * 配置环境
   */
  private configureEnvironment(): void {
    // 创建环境配置文件
    const envContent = `# OpenClaw Environment
export PREFIX="${this.prefixDir}"
export HOME="${this.homeDir}"
export PATH="${this.prefixDir}/bin:$PATH"
export TERM="xterm-256color"
`;
    this.writeFile(`${this.homeDir}/.openclaw-android/env.sh`, envContent);
  }

  // ========== 文件操作辅助方法 ==========

  private fileExists(path: string): boolean {
    try {
      fs.accessSync(path);
      return true;
    } catch (e) {
      return false;
    }
  }

  private createDir(path: string): void {
    try {
      if (!fs.accessSync(path)) {
        fs.mkdirSync(path);
      }
    } catch (e) {
      // 忽略
    }
  }

  private writeFile(path: string, content: string): void {
    try {
      const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
      fs.writeSync(file.fd, content);
      fs.closeSync(file);
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Failed to write file: ${path}`);
    }
  }
}

export default BootstrapManager;
