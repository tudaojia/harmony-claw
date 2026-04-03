/**
 * 字符串转 ArrayBuffer
 */
export default function stringToArrayBuffer(str: string, encoding: string = 'utf-8'): ArrayBuffer {
  const encoder = new TextEncoder();
  return encoder.encode(str).buffer;
}
