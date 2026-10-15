/**
 * Minimal JPEG header reader: finds the frame size (SOFn marker) and whether an EXIF APP1
 * segment is present. Only marker segments before the first scan are read.
 */

export interface JpegInfo {
  width: number;
  height: number;
  hasExif: boolean;
}

const SOF_MARKERS = new Set([0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf]);

export function readJpegInfo(buf: Uint8Array): JpegInfo | null {
  if (buf.length < 4 || buf[0] !== 0xff || buf[1] !== 0xd8) return null;
  const view = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
  let offset = 2;
  let size: { width: number; height: number } | null = null;
  let hasExif = false;
  while (offset + 4 <= buf.length) {
    if (buf[offset] !== 0xff) return null;
    let marker = buf[offset + 1] ?? 0;
    while (marker === 0xff && offset + 2 < buf.length) {
      offset += 1; // fill byte
      marker = buf[offset + 1] ?? 0;
    }
    if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd8)) {
      offset += 2; // standalone marker, no length
      continue;
    }
    if (marker === 0xd9 || marker === 0xda) break; // end of image / start of scan
    if (offset + 4 > buf.length) return null;
    const len = view.getUint16(offset + 2);
    if (len < 2 || offset + 2 + len > buf.length) return null;
    if (marker === 0xe1 && len >= 8) {
      const id = String.fromCharCode(...buf.subarray(offset + 4, offset + 10));
      if (id === "Exif\u0000\u0000") hasExif = true;
    }
    if (SOF_MARKERS.has(marker) && size === null) {
      if (len < 7) return null;
      size = { height: view.getUint16(offset + 5), width: view.getUint16(offset + 7) };
    }
    offset += 2 + len;
  }
  if (size === null || size.width === 0 || size.height === 0) return null;
  return { ...size, hasExif };
}

/** Decoded byte length of a base64 string (no whitespace, standard alphabet). */
export function base64DecodedLength(b64: string): number {
  const padding = b64.endsWith("==") ? 2 : b64.endsWith("=") ? 1 : 0;
  return Math.floor((b64.length * 3) / 4) - padding;
}
