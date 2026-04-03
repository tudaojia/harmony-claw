/**
 * 常量定义
 */
export class Constants {
  // 应用信息
  static readonly APP_NAME = 'HarmonyClaw';
  static readonly APP_VERSION = '1.0.0';
  
  // 颜色
  static readonly COLORS = {
    PRIMARY: '#2196F3',
    SECONDARY: '#4CAF50',
    BACKGROUND: '#0a0a0a',
    CARD_BG: '#1a1a2e',
    TEXT_PRIMARY: '#FFFFFF',
    TEXT_SECONDARY: '#888888',
    TERMINAL_BG: '#000000',
    TERMINAL_TEXT: '#00FF00'
  };
  
  // 终端默认配置
  static readonly TERMINAL = {
    DEFAULT_COLS: 80,
    DEFAULT_ROWS: 24,
    FONT_SIZE: 14,
    SCROLLBACK: 2000
  };
  
  // URL
  static readonly URLS = {
    BOOTSTRAP: 'https://github.com/tudaojia/android-openclaw/releases/download/bootstrap/bootstrap-aarch64.zip',
    WWW: ''
  };
}

export default Constants;
