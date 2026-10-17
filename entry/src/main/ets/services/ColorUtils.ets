const HEX_DIGITS: string = '0123456789ABCDEF';

export class HsvColor {
  h: number;
  s: number;
  v: number;

  constructor(h: number, s: number, v: number) {
    this.h = h;
    this.s = s;
    this.v = v;
  }
}

export function clamp01(value: number): number {
  if (value < 0) {
    return 0;
  }
  if (value > 1) {
    return 1;
  }
  return value;
}

function clampHue(value: number): number {
  let hue = value % 360;
  if (hue < 0) {
    hue += 360;
  }
  return hue;
}

function isHexDigit(char: string): boolean {
  return HEX_DIGITS.indexOf(char.toUpperCase()) >= 0;
}

/**
 * 把用户输入整理成 #RRGGBB。支持 `#abc`、`abc`、`#aabbcc`、`aabbcc`。
 * 非法输入返回空字符串。
 */
export function normalizeHex(input: string): string {
  let value = input.trim();
  if (value.length === 0) {
    return '';
  }
  if (value.charAt(0) === '#') {
    value = value.substring(1);
  }
  if (value.length === 3) {
    const red = value.charAt(0);
    const green = value.charAt(1);
    const blue = value.charAt(2);
    value = `${red}${red}${green}${green}${blue}${blue}`;
  }
  if (value.length !== 6) {
    return '';
  }
  for (let i = 0; i < value.length; i++) {
    if (!isHexDigit(value.charAt(i))) {
      return '';
    }
  }
  return `#${value.toUpperCase()}`;
}

export function hexToHsv(hex: string): HsvColor {
  const normalized = normalizeHex(hex);
  if (normalized === '') {
    return new HsvColor(0, 0, 0);
  }
  const red = parseInt(normalized.substring(1, 3), 16) / 255;
  const green = parseInt(normalized.substring(3, 5), 16) / 255;
  const blue = parseInt(normalized.substring(5, 7), 16) / 255;
  const max = Math.max(red, Math.max(green, blue));
  const min = Math.min(red, Math.min(green, blue));
  const delta = max - min;
  let hue = 0;
  if (delta > 0) {
    if (max === red) {
      hue = 60 * (((green - blue) / delta) % 6);
    } else if (max === green) {
      hue = 60 * (((blue - red) / delta) + 2);
    } else {
      hue = 60 * (((red - green) / delta) + 4);
    }
  }
  const saturation = max === 0 ? 0 : delta / max;
  return new HsvColor(clampHue(hue), saturation, max);
}

function toHexChannel(value: number): string {
  const level = Math.round(clamp01(value) * 255);
  const high = Math.floor(level / 16);
  const low = level % 16;
  return `${HEX_DIGITS.charAt(high)}${HEX_DIGITS.charAt(low)}`;
}

export function hsvToHex(hsv: HsvColor): string {
  const hue = clampHue(hsv.h);
  const saturation = clamp01(hsv.s);
  const value = clamp01(hsv.v);
  const chroma = value * saturation;
  const second = chroma * (1 - Math.abs(((hue / 60) % 2) - 1));
  const offset = value - chroma;
  let red = 0;
  let green = 0;
  let blue = 0;
  if (hue < 60) {
    red = chroma;
    green = second;
  } else if (hue < 120) {
    red = second;
    green = chroma;
  } else if (hue < 180) {
    green = chroma;
    blue = second;
  } else if (hue < 240) {
    green = second;
    blue = chroma;
  } else if (hue < 300) {
    red = second;
    blue = chroma;
  } else {
    red = chroma;
    blue = second;
  }
  return `#${toHexChannel(red + offset)}${toHexChannel(green + offset)}${toHexChannel(blue + offset)}`;
}

/** 只取色相、开到最亮最纯，用来给调色盘画纯色渐变。 */
export function pureHueHex(hue: number): string {
  return hsvToHex(new HsvColor(hue, 1, 1));
}

/** 感知亮度，用于判断画布上的选中框该用白还是蓝。 */
export function isDarkColor(hex: string): boolean {
  const normalized = normalizeHex(hex);
  if (normalized === '') {
    return false;
  }
  const red = parseInt(normalized.substring(1, 3), 16) / 255;
  const green = parseInt(normalized.substring(3, 5), 16) / 255;
  const blue = parseInt(normalized.substring(5, 7), 16) / 255;
  const luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue;
  return luminance < 0.55;
}
