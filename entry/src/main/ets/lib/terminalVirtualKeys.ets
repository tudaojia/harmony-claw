/**
 * 虚拟按键序列
 */

/**
 * 功能键序列
 */
export const FunctionKeySequences = {
  F1: '\x1bOP',
  F2: '\x1bOQ',
  F3: '\x1bOR',
  F4: '\x1bOS',
  F5: '\x1b[15~',
  F6: '\x1b[17~',
  F7: '\x1b[18~',
  F8: '\x1b[19~',
  F9: '\x1b[20~',
  F10: '\x1b[21~',
  F11: '\x1b[23~',
  F12: '\x1b[24~'
};

/**
 * 普通键序列
 */
export const NormalKeySequences = {
  ESC: '\x1b',
  TAB: '\t',
  UP: '\x1b[A',
  DOWN: '\x1b[B',
  LEFT: '\x1b[D',
  RIGHT: '\x1b[C',
  HOME: '\x1b[H',
  END: '\x1b[F',
  PGUP: '\x1b[5~',
  PGDN: '\x1b[6~',
  // 应用模式
  UP_APP: '\x1bOA',
  DOWN_APP: '\x1bOB',
  LEFT_APP: '\x1bOD',
  RIGHT_APP: '\x1bOC'
};

/**
 * 虚拟按键尺寸
 */
export interface VKeyMetrics {
  margin: number;
  padding: number;
  height: number;
  width: number;
  fontSize: number;
  radius: number;
}

/**
 * 获取虚拟按键尺寸
 */
export function getVirtualKeyMetrics(deviceType: string): VKeyMetrics {
  // 根据设备类型调整尺寸
  if (deviceType === 'phone') {
    return {
      margin: 2,
      padding: 8,
      height: 36,
      width: 48,
      fontSize: 12,
      radius: 6
    };
  } else if (deviceType === 'tablet') {
    return {
      margin: 3,
      padding: 10,
      height: 40,
      width: 56,
      fontSize: 14,
      radius: 8
    };
  }
  
  // 默认
  return {
    margin: 2,
    padding: 8,
    height: 36,
    width: 48,
    fontSize: 12,
    radius: 6
  };
}

/**
 * 应用修饰键
 */
export function applyVirtualKeyModifiers(
  data: string,
  ctrlPressed: boolean,
  shiftPressed: boolean
): { data: string; ctrlConverted: boolean; shiftConverted: boolean; shouldResetCtrl: boolean } {
  let result = data;
  let ctrlConverted = false;
  let shiftConverted = false;
  let shouldResetCtrl = false;
  
  // Ctrl 组合
  if (ctrlPressed && data.length === 1) {
    const code = data.charCodeAt(0);
    if (code >= 97 && code <= 122) {
      // a-z -> Ctrl+A 到 Ctrl+Z
      result = String.fromCharCode(code - 96);
      ctrlConverted = true;
      shouldResetCtrl = true;
    }
  }
  
  // Shift 组合
  if (shiftPressed && data.length === 1) {
    const code = data.charCodeAt(0);
    if (code >= 97 && code <= 122) {
      // a-z -> A-Z
      result = data.toUpperCase();
      shiftConverted = true;
    }
  }
  
  return { data: result, ctrlConverted, shiftConverted, shouldResetCtrl };
}
