export const COLOR_INK: string = '#10110E';
export const COLOR_PAPER: string = '#F5F5F1';
export const COLOR_BLUE: string = '#245BFF';
export const COLOR_MUTED: string = '#777970';
export const COLOR_LINE: string = '#E2E3DC';
export const COLOR_PANEL: string = '#FFFFFF';
export const COLOR_PANEL_LINE: string = '#E8E9E3';
export const COLOR_SOFT_BLUE: string = '#EDF0FF';
export const COLOR_WHITE: string = '#FFFFFF';
export const COLOR_STAGE: string = '#17181A';
export const COLOR_FIELD: string = '#F1F2ED';
export const COLOR_SUBTLE: string = '#9A9C95';
export const COLOR_SECONDARY: string = '#6B6D65';

export enum PageKind {
  Explore = 'explore',
  Create = 'create',
  Gallery = 'gallery'
}

export interface NavSpec {
  page: PageKind;
  label: string;
}

export const NAV_ITEMS: NavSpec[] = [
  { page: PageKind.Explore, label: '灵感' },
  { page: PageKind.Create, label: '创作' },
  { page: PageKind.Gallery, label: '作品' }
];

/** 创作台的底部工具标签。 */
export interface ToolSpec {
  id: string;
  label: string;
}

export const EDITOR_TOOLS: ToolSpec[] = [
  { id: 'text', label: '文字' },
  { id: 'style', label: '样式' },
  { id: 'font', label: '字体' },
  { id: 'layout', label: '排版' },
  { id: 'color', label: '颜色' }
];


export interface PresetSpec {
  id: string;
  label: string;
  name: string;
  note: string;
  background: string;
  color: string;
  font: string;
  weight: number;
  letterSpacing: number;
  lineHeight: number;
  uppercase: boolean;
  tilt: number;
  swatchText: string;
  swatchBackground: string;
  swatchColor: string;
}

export const PRESETS: PresetSpec[] = [
  {
    id: 'brutalist',
    label: 'BRUTALIST / 01',
    name: 'Brutalist',
    note: '粗粝 · 大胆',
    background: '#245BFF',
    color: '#FFFFFF',
    font: 'sans',
    weight: 900,
    letterSpacing: -9,
    lineHeight: 83,
    uppercase: true,
    tilt: 0,
    swatchText: 'Aa',
    swatchBackground: '#245BFF',
    swatchColor: '#FFFFFF'
  },
  {
    id: 'editorial',
    label: 'EDITORIAL / 02',
    name: 'Editorial',
    note: '优雅 · 留白',
    background: '#EAE7DF',
    color: '#171714',
    font: 'serif',
    weight: 500,
    letterSpacing: -7.5,
    lineHeight: 98,
    uppercase: false,
    tilt: 10,
    swatchText: 'Ag',
    swatchBackground: '#ECE8DF',
    swatchColor: '#171714'
  },
  {
    id: 'playful',
    label: 'PLAYFUL / 03',
    name: 'Playful',
    note: '明快 · 有趣',
    background: '#191A17',
    color: '#245BFF',
    font: 'sans',
    weight: 900,
    letterSpacing: -8,
    lineHeight: 82,
    uppercase: true,
    tilt: 5,
    swatchText: 'Hi!',
    swatchBackground: '#191A17',
    swatchColor: '#245BFF'
  },
  {
    id: 'mono',
    label: 'MONO GRID / 04',
    name: 'Mono Grid',
    note: '理性 · 精准',
    background: '#ECEEE8',
    color: '#20211D',
    font: 'mono',
    weight: 500,
    letterSpacing: -7.5,
    lineHeight: 98,
    uppercase: true,
    tilt: 0,
    swatchText: '01',
    swatchBackground: '#E8E9E4',
    swatchColor: '#20211D'
  }
];

export function findPreset(id: string): PresetSpec {
  for (let i = 0; i < PRESETS.length; i++) {
    if (PRESETS[i].id === id) {
      return PRESETS[i];
    }
  }
  return PRESETS[0];
}

export interface FontSpec {
  id: string;
  name: string;
  sample: string;
  family: string;
  weightBoost: number;
}

export const FONTS: FontSpec[] = [
  { id: 'sans', name: '无衬线', sample: 'Aa', family: 'HarmonyOS Sans', weightBoost: 0 },
  { id: 'serif', name: '衬线', sample: 'Ag', family: 'serif', weightBoost: -100 },
  { id: 'mono', name: '等宽', sample: '01', family: 'monospace', weightBoost: -200 },
  { id: 'display', name: '粗体', sample: 'A!', family: 'HarmonyOS Sans Condensed', weightBoost: 100 }
];

export function findFont(id: string): FontSpec {
  for (let i = 0; i < FONTS.length; i++) {
    if (FONTS[i].id === id) {
      return FONTS[i];
    }
  }
  return FONTS[0];
}

export interface ColorSpec {
  name: string;
  value: string;
}

/**
 * 固定色板按“文字色 / 背景色”成对排列：每一列是一组对比度足够的推荐配色，
 * 两行数量与列位一致，但同一列上下是互相搭配的两种颜色，而不是同一个颜色。
 */
export interface ColorPairSpec {
  text: ColorSpec;
  background: ColorSpec;
}

const SWATCH_INK: ColorSpec = { name: '墨黑', value: '#10110E' };
const SWATCH_WHITE: ColorSpec = { name: '纯白', value: '#FFFFFF' };
const SWATCH_BLUE: ColorSpec = { name: '电蓝', value: '#245BFF' };
const SWATCH_WARM: ColorSpec = { name: '暖白', value: '#F6F6F2' };
const SWATCH_BEIGE: ColorSpec = { name: '米色', value: '#EAE7DF' };
const SWATCH_GRAY: ColorSpec = { name: '中灰', value: '#777970' };

export const COLOR_PAIRS: ColorPairSpec[] = [
  { text: SWATCH_WHITE, background: SWATCH_BLUE },
  { text: SWATCH_INK, background: SWATCH_BEIGE },
  { text: SWATCH_GRAY, background: SWATCH_WHITE },
  { text: SWATCH_BEIGE, background: SWATCH_INK },
  { text: SWATCH_BLUE, background: SWATCH_WARM },
  { text: SWATCH_WARM, background: SWATCH_GRAY }
];

export interface AlignmentSpec {
  id: string;
  label: string;
  glyph: string;
}

export const ALIGNMENTS: AlignmentSpec[] = [
  { id: 'left', label: '左对齐', glyph: '☰' },
  { id: 'center', label: '居中', glyph: '≡' },
  { id: 'right', label: '右对齐', glyph: '☷' }
];

export interface FeatureSpec {
  preset: string;
  index: string;
  sample: string;
  title: string;
  note: string;
  tone: string;
}

export const FEATURES: FeatureSpec[] = [
  {
    preset: 'brutalist',
    index: 'A / 01',
    sample: 'MAKE\nIT LOUD',
    title: 'BRUTALIST',
    note: '强烈 · 直接',
    tone: 'blue'
  },
  {
    preset: 'editorial',
    index: 'B / 02',
    sample: 'A good\nstory',
    title: 'EDITORIAL',
    note: '克制 · 有故事',
    tone: 'paper'
  },
  {
    preset: 'playful',
    index: 'C / 03',
    sample: 'STAY\nCURIOUS!',
    title: 'PLAYFUL',
    note: '轻快 · 出其不意',
    tone: 'ink'
  }
];

export interface StyleCardSpec {
  preset: string;
  index: string;
  kicker: string;
  sample: string;
  title: string;
  note: string;
  tone: string;
  meta: string;
}

export const STYLE_CARDS: StyleCardSpec[] = [
  {
    preset: 'brutalist',
    index: '01 / POSTER',
    kicker: 'NO SOFT',
    sample: 'NO\nSOFT\nEDGES.',
    title: 'BRUTALIST',
    note: '冲击力 · 几何感 · 直给',
    tone: 'blue',
    meta: 'STUDY 024'
  },
  {
    preset: 'editorial',
    index: '02 / EDITION',
    kicker: 'ISSUE 08',
    sample: 'Words\nthat stay.',
    title: 'EDITORIAL',
    note: '叙事感 · 对比 · 细节',
    tone: 'paper',
    meta: 'THE ART OF PAUSE'
  },
  {
    preset: 'playful',
    index: '03 / EXPERIMENT',
    kicker: 'GOOD THINGS',
    sample: 'TAKE\nPLAY!',
    title: 'PLAYFUL',
    note: '跳跃感 · 色彩 · 不设限',
    tone: 'ink',
    meta: 'CURIOUS BY DEFAULT'
  },
  {
    preset: 'mono',
    index: '04 / SYSTEM',
    kicker: 'GRID STUDY 005',
    sample: 'FORM\nFOLLOWS\nFUNCTION.',
    title: 'MONO GRID',
    note: '网格 · 秩序 · 克制',
    tone: 'mono',
    meta: 'ORDER IN EVERY LETTER'
  }
];

export const STYLE_NAME_MAX: number = 20;
/** 单个特点标签的字数上限。 */
export const STYLE_TAG_MAX: number = 8;
/** 一个风格最多可以添加几个标签。 */
export const STYLE_TAGS_MAX: number = 6;
/** 特点按「标签 · 标签」拼接后的总长度上限，与卡片两行展示的容量一致。 */
export const STYLE_NOTE_MAX: number = STYLE_TAGS_MAX * STYLE_TAG_MAX + (STYLE_TAGS_MAX - 1) * 3;
/** 没有标签时的兜底特点文案。 */
export const STYLE_NOTE_FALLBACK: string = '自定义风格';

export interface RawWork {
  id?: string;
  title?: string;
  text?: string;
  preset?: string;
  font?: string;
  size?: number;
  letterSpacing?: number;
  lineHeight?: number;
  tilt?: number;
  alignment?: string;
  textColor?: string;
  backgroundColor?: string;
  offsetX?: number;
  offsetY?: number;
  rotation?: number;
  savedAt?: number;
}

export class WorkData {
  id: string;
  title: string;
  text: string;
  preset: string;
  font: string;
  size: number;
  letterSpacing: number;
  lineHeight: number;
  tilt: number;
  alignment: string;
  textColor: string;
  backgroundColor: string;
  offsetX: number;
  offsetY: number;
  rotation: number;
  savedAt: number;

  constructor(id: string, title: string, text: string, preset: string, font: string, size: number,
    letterSpacing: number, lineHeight: number, tilt: number, alignment: string, textColor: string,
    backgroundColor: string, offsetX: number, offsetY: number, rotation: number, savedAt: number) {
    this.id = id;
    this.title = title;
    this.text = text;
    this.preset = preset;
    this.font = font;
    this.size = size;
    this.letterSpacing = letterSpacing;
    this.lineHeight = lineHeight;
    this.tilt = tilt;
    this.alignment = alignment;
    this.textColor = textColor;
    this.backgroundColor = backgroundColor;
    this.offsetX = offsetX;
    this.offsetY = offsetY;
    this.rotation = rotation;
    this.savedAt = savedAt;
  }
}

export interface RawStyle {
  id?: string;
  name?: string;
  note?: string;
  tags?: string[];
  sample?: string;
  preset?: string;
  font?: string;
  size?: number;
  letterSpacing?: number;
  lineHeight?: number;
  tilt?: number;
  alignment?: string;
  textColor?: string;
  backgroundColor?: string;
  savedAt?: number;
}

/** 用户从创作台收藏的排版配方。文案只作为预览样例，套用时不会覆盖正在编辑的文字。 */
export class SavedStyle {
  id: string;
  name: string;
  /** 由 tags 拼接而成的展示文案，例如「粗黑标题 · 高对比」。 */
  note: string;
  /** 用户逐个添加的特点标签，note 是它们的展示形式。 */
  tags: string[];
  sample: string;
  preset: string;
  font: string;
  size: number;
  letterSpacing: number;
  lineHeight: number;
  tilt: number;
  alignment: string;
  textColor: string;
  backgroundColor: string;
  savedAt: number;

  constructor(id: string, name: string, tags: string[], sample: string, preset: string, font: string,
    size: number, letterSpacing: number, lineHeight: number, tilt: number, alignment: string,
    textColor: string, backgroundColor: string, savedAt: number) {
    this.id = id;
    this.name = name;
    this.tags = tags;
    this.note = styleNoteFromTags(tags, STYLE_NOTE_FALLBACK);
    this.sample = sample;
    this.preset = preset;
    this.font = font;
    this.size = size;
    this.letterSpacing = letterSpacing;
    this.lineHeight = lineHeight;
    this.tilt = tilt;
    this.alignment = alignment;
    this.textColor = textColor;
    this.backgroundColor = backgroundColor;
    this.savedAt = savedAt;
  }
}

function validColor(value: string | undefined, fallback: string): string {
  if (value !== undefined && /^#[0-9a-fA-F]{6}$/.test(value)) {
    return value.toUpperCase();
  }
  return fallback;
}

function validAlignment(value: string | undefined): string {
  if (value === 'left' || value === 'center' || value === 'right') {
    return value;
  }
  return 'left';
}

function validFont(value: string | undefined): string {
  if (value === 'sans' || value === 'serif' || value === 'mono' || value === 'display') {
    return value;
  }
  return 'sans';
}

function clampNumber(value: number | undefined, fallback: number, min: number, max: number): number {
  if (typeof value !== 'number' || Number.isNaN(value)) {
    return fallback;
  }
  return Math.max(min, Math.min(max, value));
}

function normalizedText(value: string | undefined, fallback: string, maxLength: number): string {
  if (value === undefined) {
    return fallback;
  }
  const compact = value.replace(/\s+/g, ' ').trim();
  if (compact.length === 0) {
    return fallback;
  }
  return compact.slice(0, maxLength);
}

function normalizedSample(value: string | undefined, fallback: string): string {
  if (value === undefined) {
    return fallback;
  }
  const trimmed = value.trim();
  if (trimmed.length === 0) {
    return fallback;
  }
  return trimmed.slice(0, 60);
}

/** 把用户输入的一个标签压成单行并截到上限长度。 */
export function normalizeStyleTag(value: string): string {
  return value.replace(/\s+/g, ' ').trim().slice(0, STYLE_TAG_MAX);
}

function hasTag(tags: string[], tag: string): boolean {
  for (let i = 0; i < tags.length; i++) {
    if (tags[i] === tag) {
      return true;
    }
  }
  return false;
}

/** 校验并去重标签列表，保证数量与单个长度都在上限内。 */
export function normalizeStyleTags(values: string[] | undefined): string[] {
  const tags: string[] = [];
  if (values === undefined) {
    return tags;
  }
  for (let i = 0; i < values.length && tags.length < STYLE_TAGS_MAX; i++) {
    // JSON 反序列化的数据不可信，先确认每个元素确实是字符串。
    if (typeof values[i] !== 'string') {
      continue;
    }
    const tag = normalizeStyleTag(values[i]);
    if (tag.length > 0 && !hasTag(tags, tag)) {
      tags.push(tag);
    }
  }
  return tags;
}

/**
 * 兼容旧数据：早期版本让用户手写「简洁 · 美观」格式的特点，
 * 读取时按中点拆回标签，再统一按标签渲染。
 */
export function parseStyleTags(note: string | undefined): string[] {
  const tags: string[] = [];
  if (note === undefined || note === STYLE_NOTE_FALLBACK) {
    return tags;
  }
  const parts = note.split('·');
  for (let i = 0; i < parts.length && tags.length < STYLE_TAGS_MAX; i++) {
    const tag = normalizeStyleTag(parts[i]);
    if (tag.length > 0 && !hasTag(tags, tag)) {
      tags.push(tag);
    }
  }
  return tags;
}

/** 标签自动拼成卡片上展示的特点文案：简洁 · 美观。 */
export function styleNoteFromTags(tags: string[], fallback: string): string {
  if (tags.length === 0) {
    return fallback;
  }
  return tags.join(' · ').slice(0, STYLE_NOTE_MAX);
}

export function defaultSize(presetId: string): number {
  if (presetId === 'editorial') {
    return 52;
  }
  if (presetId === 'playful') {
    return 58;
  }
  if (presetId === 'mono') {
    return 40;
  }
  return 56;
}

export function defaultSample(presetId: string): string {
  if (presetId === 'editorial') {
    return 'A good\nstory';
  }
  if (presetId === 'playful') {
    return 'STAY\nCURIOUS!';
  }
  if (presetId === 'mono') {
    return 'FORM\nFOLLOWS\nFUNCTION.';
  }
  return 'MAKE IT\nDIFFERENT';
}

export function workTitle(text: string): string {
  const compact = text.replace(/\s+/g, ' ').trim();
  if (compact.length === 0) {
    return 'Untitled Study';
  }
  return compact.slice(0, 36);
}

export function workFromRaw(raw: RawWork): WorkData {
  const preset = findPreset(raw.preset !== undefined ? raw.preset : 'brutalist');
  const text = raw.text !== undefined ? raw.text : 'MAKE IT\nDIFFERENT';
  return new WorkData(
    raw.id !== undefined ? raw.id : `${Date.now()}`,
    raw.title !== undefined && raw.title.length > 0 ? raw.title : workTitle(text),
    text,
    preset.id,
    validFont(raw.font),
    typeof raw.size === 'number' ? raw.size : 56,
    typeof raw.letterSpacing === 'number' ? raw.letterSpacing : preset.letterSpacing,
    typeof raw.lineHeight === 'number' ? raw.lineHeight : preset.lineHeight,
    typeof raw.tilt === 'number' ? raw.tilt : preset.tilt,
    validAlignment(raw.alignment),
    validColor(raw.textColor, preset.color),
    validColor(raw.backgroundColor, preset.background),
    typeof raw.offsetX === 'number' ? raw.offsetX : 0,
    typeof raw.offsetY === 'number' ? raw.offsetY : 0,
    typeof raw.rotation === 'number' ? raw.rotation : 0,
    typeof raw.savedAt === 'number' ? raw.savedAt : Date.now()
  );
}

export function styleFromRaw(raw: RawStyle): SavedStyle {
  const preset = findPreset(raw.preset !== undefined ? raw.preset : 'brutalist');
  // 新数据直接读 tags；旧数据没有 tags，就从「A · B」格式的 note 里还原标签。
  let tags: string[] = normalizeStyleTags(raw.tags);
  if (tags.length === 0) {
    tags = parseStyleTags(raw.note);
  }
  return new SavedStyle(
    raw.id !== undefined ? raw.id : `${Date.now()}`,
    normalizedText(raw.name, `我的 ${preset.name}`, STYLE_NAME_MAX),
    tags,
    normalizedSample(raw.sample, defaultSample(preset.id)),
    preset.id,
    validFont(raw.font),
    clampNumber(raw.size, defaultSize(preset.id), 24, 120),
    clampNumber(raw.letterSpacing, preset.letterSpacing, -15, 15),
    clampNumber(raw.lineHeight, preset.lineHeight, 70, 150),
    clampNumber(raw.tilt, preset.tilt, 0, 20),
    validAlignment(raw.alignment),
    validColor(raw.textColor, preset.color),
    validColor(raw.backgroundColor, preset.background),
    typeof raw.savedAt === 'number' ? raw.savedAt : Date.now()
  );
}

/** 把风格转换成作品结构，复用作品缩略图的绘制逻辑。 */
export function stylePreviewWork(style: SavedStyle): WorkData {
  return new WorkData(
    `style-preview-${style.id}`,
    style.name,
    style.sample,
    style.preset,
    style.font,
    style.size,
    style.letterSpacing,
    style.lineHeight,
    style.tilt,
    style.alignment,
    style.textColor,
    style.backgroundColor,
    0,
    0,
    0,
    style.savedAt
  );
}

/** 风格库卡片的展示数据：自定义风格与预设风格共用同一套排版。 */
export interface StyleCardView {
  /** 自定义风格为风格 id，预设风格为预设 id。 */
  id: string;
  custom: boolean;
  kicker: string;
  title: string;
  note: string;
  meta: string;
  preset: string;
  sample: string;
  /** 缩略图直接复用作品预览的绘制逻辑，两类卡片视觉一致。 */
  preview: WorkData;
}

export function formatSavedDate(timestamp: number): string {
  const date = new Date(timestamp);
  const month = date.getMonth() + 1;
  const day = date.getDate();
  return `${date.getFullYear()}.${month < 10 ? '0' : ''}${month}.${day < 10 ? '0' : ''}${day}`;
}
