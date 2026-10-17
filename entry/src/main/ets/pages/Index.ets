import { KeyboardAvoidMode, matrix4 } from '@kit.ArkUI';
import { Context } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { GalleryStore } from '../services/GalleryStore';
import { StyleStore } from '../services/StyleStore';
import { ArtworkExporter, ExportResult } from '../services/ArtworkExporter';
import {
  HsvColor,
  clamp01,
  hexToHsv,
  hsvToHex,
  isDarkColor,
  normalizeHex,
  pureHueHex
} from '../services/ColorUtils';
import {
  ALIGNMENTS,
  AlignmentSpec,
  COLOR_BLUE,
  COLOR_FIELD,
  COLOR_INK,
  COLOR_LINE,
  COLOR_PAIRS,
  COLOR_PAPER,
  COLOR_SECONDARY,
  COLOR_SOFT_BLUE,
  COLOR_STAGE,
  COLOR_SUBTLE,
  COLOR_WHITE,
  ColorPairSpec,
  ColorSpec,
  EDITOR_TOOLS,
  FONTS,
  FontSpec,
  NAV_ITEMS,
  NavSpec,
  PRESETS,
  PageKind,
  PresetSpec,
  STYLE_CARDS,
  STYLE_NAME_MAX,
  STYLE_TAGS_MAX,
  STYLE_TAG_MAX,
  SavedStyle,
  StyleCardSpec,
  StyleCardView,
  ToolSpec,
  WorkData,
  defaultSample,
  defaultSize,
  findFont,
  findPreset,
  formatSavedDate,
  normalizeStyleTag,
  styleNoteFromTags,
  stylePreviewWork,
  workTitle
} from '../model/Typography';

const TOOL_TEXT: string = 'text';
const TOOL_STYLE: string = 'style';
const TOOL_FONT: string = 'font';
const TOOL_LAYOUT: string = 'layout';
const TOOL_COLOR: string = 'color';

const TAB_WORKS: string = 'works';
const TAB_STYLES: string = 'styles';

const PANEL_BODY_HEIGHT: number = 132;
const SHEET_HEIGHT: number = 560;
const STYLE_SHEET_HEIGHT: number = 600;
const PICKER_TEXT: string = 'text';
const PICKER_BACKGROUND: string = 'background';

@Entry
@Component
struct Index {
  @State currentPage: PageKind = PageKind.Explore;
  @State draftText: string = 'MAKE IT\nDIFFERENT';
  @State draftPreset: string = 'brutalist';
  @State draftFont: string = 'sans';
  @State draftSize: number = 56;
  @State draftLetterSpacing: number = -9;
  @State draftLineHeight: number = 83;
  @State draftTilt: number = 0;
  @State draftAlignment: string = 'left';
  @State draftTextColor: string = '#FFFFFF';
  @State draftBackgroundColor: string = '#245BFF';
  @State draftOffsetX: number = 0;
  @State draftOffsetY: number = 0;
  @State draftRotation: number = 0;
  @State selected: boolean = false;
  @State savedWorks: WorkData[] = [];
  @State savedStyles: SavedStyle[] = [];
  @State isExporting: boolean = false;
  @State pendingExport: boolean = false;
  @State activeTool: string = TOOL_TEXT;
  @State galleryTab: string = TAB_WORKS;
  @State canvasHostWidth: number = 0;
  @State canvasHostHeight: number = 0;
  @State textFocused: boolean = false;
  @State showColorPicker: boolean = false;
  @State pickerTarget: string = PICKER_TEXT;
  @State textHsv: HsvColor = hexToHsv('#FFFFFF');
  @State backgroundHsv: HsvColor = hexToHsv('#245BFF');
  @State hexDraft: string = '#FFFFFF';
  @State padWidth: number = 0;
  @State padHeight: number = 0;
  @State hueWidth: number = 0;
  @State recentColors: string[] = [];
  @State pickerDragging: boolean = false;
  @State showStyleSheet: boolean = false;
  @State styleNameDraft: string = '';
  @State styleTags: string[] = [];
  @State styleTagDraft: string = '';
  @State editingStyleId: string = '';
  @State editSyncRecipe: boolean = false;
  /** 编辑已有风格时递增，让复用同一 id 的卡片重新渲染。 */
  @State styleRevision: number = 0;

  private appContext: Context | undefined = undefined;
  private store: GalleryStore | undefined = undefined;
  private styleStore: StyleStore | undefined = undefined;
  private dragStartX: number = 0;
  private dragStartY: number = 0;
  private rotateStart: number = 0;
  private artboardWidth: number = 320;
  private artboardHeight: number = 400;
  private textBlockHeight: number = 120;
  private pickerBackupText: string = '#FFFFFF';
  private pickerBackupBackground: string = '#245BFF';

  aboutToAppear(): void {
    try {
      this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    } catch (error) {
      console.error(`FontPlayground keyboard mode failed: ${JSON.stringify(error)}`);
    }
    this.appContext = this.getUIContext().getHostContext();
    if (this.appContext !== undefined) {
      this.store = new GalleryStore(this.appContext);
      this.savedWorks = this.store.load();
      this.styleStore = new StyleStore(this.appContext);
      this.savedStyles = this.styleStore.load();
    }
  }

  private switchPage(page: PageKind): void {
    if (page !== PageKind.Create) {
      this.selected = false;
    }
    this.currentPage = page;
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
    } catch (error) {
      console.error(`FontPlayground toast failed: ${JSON.stringify(error)}`);
    }
  }

  private activePreset(): PresetSpec {
    return findPreset(this.draftPreset);
  }

  private activeFont(): FontSpec {
    return findFont(this.draftFont);
  }

  private fontWeightValue(): number {
    return Math.max(100, Math.min(900, this.activePreset().weight + this.activeFont().weightBoost));
  }

  private workFontWeight(work: WorkData): number {
    return Math.max(100, Math.min(900,
      findPreset(work.preset).weight + findFont(work.font).weightBoost));
  }

  private textAlignValue(): TextAlign {
    if (this.draftAlignment === 'center') {
      return TextAlign.Center;
    }
    if (this.draftAlignment === 'right') {
      return TextAlign.End;
    }
    return TextAlign.Start;
  }

  private alignmentValue(id: string): HorizontalAlign {
    if (id === 'center') {
      return HorizontalAlign.Center;
    }
    if (id === 'right') {
      return HorizontalAlign.End;
    }
    return HorizontalAlign.Start;
  }

  private selectionColor(): string {
    // 背景变深后选中框改用白色，自定义颜色也能保持可见。
    return isDarkColor(this.draftBackgroundColor) ? COLOR_WHITE : COLOR_BLUE;
  }

  private sameColor(first: string, second: string): boolean {
    return first.toUpperCase() === second.toUpperCase();
  }

  private toolColor(id: string): string {
    return this.activeTool === id ? COLOR_BLUE : COLOR_SUBTLE;
  }

  private pickerHsv(): HsvColor {
    return this.pickerTarget === PICKER_BACKGROUND ? this.backgroundHsv : this.textHsv;
  }

  private pickerColor(): string {
    return this.pickerTarget === PICKER_BACKGROUND ? this.draftBackgroundColor : this.draftTextColor;
  }

  private syncPickerHsv(): void {
    this.textHsv = hexToHsv(this.draftTextColor);
    this.backgroundHsv = hexToHsv(this.draftBackgroundColor);
  }

  private pureHue(): string {
    return pureHueHex(this.pickerHsv().h);
  }

  private applyPickerHsv(hsv: HsvColor, syncHex: boolean): void {
    const hex = hsvToHex(hsv);
    if (this.pickerTarget === PICKER_BACKGROUND) {
      this.backgroundHsv = hsv;
      this.draftBackgroundColor = hex;
    } else {
      this.textHsv = hsv;
      this.draftTextColor = hex;
    }
    if (syncHex) {
      this.hexDraft = hex;
    }
  }

  private openColorPicker(target: string): void {
    this.pickerTarget = target;
    this.syncPickerHsv();
    this.pickerBackupText = this.draftTextColor;
    this.pickerBackupBackground = this.draftBackgroundColor;
    this.hexDraft = target === PICKER_BACKGROUND ? this.draftBackgroundColor : this.draftTextColor;
    this.selected = false;
    this.showColorPicker = true;
  }

  private closeColorPicker(commit: boolean): void {
    if (!commit) {
      this.draftTextColor = this.pickerBackupText;
      this.draftBackgroundColor = this.pickerBackupBackground;
    } else {
      this.rememberColor(this.pickerColor());
    }
    this.syncPickerHsv();
    this.hexDraft = this.pickerColor();
    this.showColorPicker = false;
  }

  private switchPickerTarget(target: string): void {
    this.pickerTarget = target;
    this.hexDraft = target === PICKER_BACKGROUND ? this.draftBackgroundColor : this.draftTextColor;
  }

  private isPresetColor(hex: string): boolean {
    for (let i = 0; i < COLOR_PAIRS.length; i++) {
      if (this.sameColor(COLOR_PAIRS[i].text.value, hex) ||
        this.sameColor(COLOR_PAIRS[i].background.value, hex)) {
        return true;
      }
    }
    return false;
  }

  private rememberColor(hex: string): void {
    const normalized = normalizeHex(hex);
    if (normalized === '' || this.isPresetColor(normalized)) {
      return;
    }
    const next: string[] = [normalized];
    for (let i = 0; i < this.recentColors.length && next.length < 8; i++) {
      if (!this.sameColor(this.recentColors[i], normalized)) {
        next.push(this.recentColors[i]);
      }
    }
    this.recentColors = next;
  }

  private isCustomColor(kind: string): boolean {
    const current = kind === PICKER_BACKGROUND ? this.draftBackgroundColor : this.draftTextColor;
    return !this.isPresetColor(current);
  }

  private swatchSelected(kind: string, value: string): boolean {
    const current = kind === PICKER_BACKGROUND ? this.draftBackgroundColor : this.draftTextColor;
    return this.sameColor(current, value);
  }

  private targetSwatch(target: string): string {
    return target === PICKER_BACKGROUND ? this.draftBackgroundColor : this.draftTextColor;
  }

  /** 取一列配色里属于该目标的一端：文字行取 text，背景行取 background。 */
  private pairColor(pair: ColorPairSpec, kind: string): ColorSpec {
    return kind === PICKER_BACKGROUND ? pair.background : pair.text;
  }

  private targetLabel(target: string): string {
    return target === PICKER_BACKGROUND ? '背景' : '文字';
  }

  private applyHexInput(value: string): void {
    const normalized = normalizeHex(value);
    if (normalized === '') {
      return;
    }
    const hsv = hexToHsv(normalized);
    if (this.pickerTarget === PICKER_BACKGROUND) {
      this.backgroundHsv = hsv;
      this.draftBackgroundColor = normalized;
    } else {
      this.textHsv = hsv;
      this.draftTextColor = normalized;
    }
  }

  private handlePadTouch(event: TouchEvent): void {
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.pickerDragging = false;
      return;
    }
    if (this.padWidth <= 0 || this.padHeight <= 0 || event.touches.length === 0) {
      return;
    }
    if (event.type !== TouchType.Down && event.type !== TouchType.Move) {
      return;
    }
    this.pickerDragging = true;
    const point = event.touches[0];
    const saturation = clamp01(point.x / this.padWidth);
    const value = clamp01(1 - point.y / this.padHeight);
    this.applyPickerHsv(new HsvColor(this.pickerHsv().h, saturation, value), true);
  }

  private handleHueTouch(event: TouchEvent): void {
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.pickerDragging = false;
      return;
    }
    if (this.hueWidth <= 0 || event.touches.length === 0) {
      return;
    }
    if (event.type !== TouchType.Down && event.type !== TouchType.Move) {
      return;
    }
    this.pickerDragging = true;
    const point = event.touches[0];
    const hue = clamp01(point.x / this.hueWidth) * 360;
    const current = this.pickerHsv();
    // 纯白或纯黑时拖动色相不会有变化，顺手把饱和度/明度拉起来，操作才有反馈。
    const saturation = current.s < 0.05 ? 1 : current.s;
    const value = current.v < 0.05 ? 1 : current.v;
    this.applyPickerHsv(new HsvColor(hue, saturation, value), true);
  }

  private padThumbX(): number {
    const x = this.pickerHsv().s * this.padWidth - 11;
    return Math.max(0, Math.min(Math.max(0, this.padWidth - 22), x));
  }

  private padThumbY(): number {
    const y = (1 - this.pickerHsv().v) * this.padHeight - 11;
    return Math.max(0, Math.min(Math.max(0, this.padHeight - 22), y));
  }

  private hueThumbX(): number {
    const x = this.pickerHsv().h / 360 * this.hueWidth - 11;
    return Math.max(0, Math.min(Math.max(0, this.hueWidth - 22), x));
  }

  private toneBackground(tone: string): string {
    if (tone === 'blue') {
      return COLOR_BLUE;
    }
    if (tone === 'paper') {
      return '#EAE7DF';
    }
    if (tone === 'ink') {
      return '#1A1B18';
    }
    return '#ECEEE8';
  }

  private toneForeground(tone: string): string {
    return tone === 'blue' || tone === 'ink' ? COLOR_WHITE : COLOR_INK;
  }

  private tileFontSize(tone: string): number {
    if (tone === 'blue' || tone === 'ink') {
      return 24;
    }
    if (tone === 'paper') {
      return 20;
    }
    return 15;
  }

  private tileLineHeight(tone: string): number {
    if (tone === 'blue' || tone === 'ink') {
      return 24;
    }
    if (tone === 'paper') {
      return 25;
    }
    return 18;
  }

  /**
   * 画布的逻辑宽度只跟舞台宽度走，不再被舞台高度反向压缩。
   * 键盘弹出时舞台会变矮，如果按高度缩画布，字号不变就会重新换行、压住角标。
   */
  private canvasWidth(): number {
    const hostWidth = this.canvasHostWidth > 0 ? this.canvasHostWidth : 320;
    return Math.max(150, hostWidth - 24);
  }

  private canvasHeight(): number {
    return this.canvasWidth() * 1.25;
  }

  /** 舞台高度不够时整体等比缩放画布，保持文字换行与各元素比例不变。 */
  private canvasViewScale(): number {
    const hostHeight = this.canvasHostHeight > 0 ? this.canvasHostHeight : 400;
    const available = hostHeight - 20;
    if (available <= 0) {
      return 1;
    }
    const ratio = available / this.canvasHeight();
    return ratio < 1 ? ratio : 1;
  }

  private workRowIndexes(): number[] {
    const rows: number[] = [];
    const total = Math.ceil(this.savedWorks.length / 2);
    for (let index = 0; index < total; index++) {
      rows.push(index);
    }
    return rows;
  }

  // 行 key 带上作品 id，删除/新增后 ForEach 才会重建对应行，避免残留旧卡片。
  private workRowKey(rowIndex: number): string {
    const first = this.savedWorks[rowIndex * 2];
    const second = this.savedWorks[rowIndex * 2 + 1];
    const firstId = first !== undefined ? first.id : 'none';
    const secondId = second !== undefined ? second.id : 'none';
    return `work-row-${firstId}-${secondId}`;
  }

  private normalizeRotation(angle: number): number {
    return ((angle + 180) % 360 + 360) % 360 - 180;
  }

  private rotationDelta(offsetX: number, offsetY: number): number {
    // 旋转手柄位于文字块正上方。以文字块中心为圆心，把手指位移换算成角度增量。
    const distance = Math.max(48, this.textBlockHeight / 2 + 14);
    const base = this.rotateStart * Math.PI / 180;
    const baseX = distance * Math.sin(base);
    const baseY = -distance * Math.cos(base);
    const startAngle = Math.atan2(baseY, baseX);
    const currentAngle = Math.atan2(baseY + offsetY, baseX + offsetX);
    return (currentAngle - startAngle) * 180 / Math.PI;
  }

  private applyPreset(presetId: string): void {
    const preset = findPreset(presetId);
    this.draftPreset = preset.id;
    this.draftFont = preset.font;
    this.draftLetterSpacing = preset.letterSpacing;
    this.draftLineHeight = preset.lineHeight;
    this.draftTilt = preset.tilt;
    this.draftTextColor = preset.color;
    this.draftBackgroundColor = preset.background;
    this.syncPickerHsv();
    this.hexDraft = this.pickerColor();
    this.draftOffsetX = 0;
    this.draftOffsetY = 0;
    this.draftRotation = 0;
    this.selected = false;
  }

  private openPreset(presetId: string, sample: string): void {
    this.draftText = sample;
    this.draftSize = defaultSize(presetId);
    this.applyPreset(presetId);
    this.activeTool = TOOL_TEXT;
    this.currentPage = PageKind.Create;
  }

  private randomPreset(): void {
    const index = Math.floor(Math.random() * PRESETS.length);
    const preset = PRESETS[index];
    this.openPreset(preset.id, defaultSample(preset.id));
    this.toast(`试试「${preset.name}」`);
  }

  private resetTransform(): void {
    this.draftOffsetX = 0;
    this.draftOffsetY = 0;
    this.draftRotation = 0;
    this.selected = false;
    this.toast('已复位文字位置');
  }

  private saveCurrent(): void {
    const work = new WorkData(
      `${Date.now()}-${Math.floor(Math.random() * 1000000)}`,
      workTitle(this.draftText),
      this.draftText,
      this.activePreset().id,
      this.draftFont,
      this.draftSize,
      this.draftLetterSpacing,
      this.draftLineHeight,
      this.draftTilt,
      this.draftAlignment,
      this.draftTextColor,
      this.draftBackgroundColor,
      this.draftOffsetX,
      this.draftOffsetY,
      this.draftRotation,
      Date.now()
    );
    const next: WorkData[] = [work];
    for (let i = 0; i < this.savedWorks.length; i++) {
      next.push(this.savedWorks[i]);
    }
    this.savedWorks = next;
    let persisted = false;
    if (this.store !== undefined) {
      persisted = this.store.save(this.savedWorks);
    }
    this.toast(persisted ? '已保存到作品' : '已加入作品（本地存储暂不可用）');
  }

  private loadWork(work: WorkData): void {
    this.draftText = work.text;
    this.draftPreset = findPreset(work.preset).id;
    this.draftFont = work.font;
    this.draftSize = work.size;
    this.draftLetterSpacing = work.letterSpacing;
    this.draftLineHeight = work.lineHeight;
    this.draftTilt = work.tilt;
    this.draftAlignment = work.alignment;
    this.draftTextColor = work.textColor;
    this.draftBackgroundColor = work.backgroundColor;
    this.syncPickerHsv();
    this.hexDraft = this.pickerColor();
    this.draftOffsetX = work.offsetX;
    this.draftOffsetY = work.offsetY;
    this.draftRotation = work.rotation;
    this.selected = false;
    this.currentPage = PageKind.Create;
  }

  private async downloadCurrent(): Promise<void> {
    if (this.isExporting) {
      return;
    }
    this.selected = false;
    this.isExporting = true;
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      await new Promise<void>((resolve: () => void) => {
        setTimeout(() => {
          resolve();
        }, 90);
      });
      pixelMap = await this.getUIContext().getComponentSnapshot().get('artboard', {
        scale: 2,
        waitUntilRenderFinished: true
      });
      if (this.appContext === undefined) {
        this.toast('无法获取应用上下文');
        return;
      }
      const result: ExportResult = await ArtworkExporter.saveToAlbum(
        this.appContext, pixelMap, workTitle(this.draftText));
      if (result.success) {
        this.toast('已导出到相册');
      } else if (result.canceled) {
        this.toast('已取消导出');
      } else {
        this.toast('导出失败，请稍后重试');
      }
    } catch (error) {
      console.error(`FontPlayground export failed: ${JSON.stringify(error)}`);
      this.toast('导出失败，请稍后重试');
    } finally {
      if (pixelMap !== undefined) {
        try {
          await pixelMap.release();
        } catch (error) {
          console.error(`FontPlayground pixelMap release failed: ${JSON.stringify(error)}`);
        }
      }
      this.isExporting = false;
    }
  }

  private downloadWork(work: WorkData): void {
    if (this.isExporting) {
      return;
    }
    this.loadWork(work);
    this.pendingExport = true;
    this.toast('作品已载入创作台，正在导出');
    // 兜底：正常路径由画布 onAppear 触发导出，若页面未重新挂载则在此触发。
    setTimeout(() => {
      if (this.pendingExport) {
        this.pendingExport = false;
        this.downloadCurrent();
      }
    }, 700);
  }

  private removeWork(work: WorkData): void {
    const next: WorkData[] = [];
    for (let i = 0; i < this.savedWorks.length; i++) {
      const item = this.savedWorks[i];
      if (item.id !== work.id) {
        next.push(item);
      }
    }
    if (next.length === this.savedWorks.length) {
      return;
    }
    this.savedWorks = next;
    let persisted = false;
    if (this.store !== undefined) {
      persisted = this.store.save(this.savedWorks);
    }
    this.toast(persisted ? '已删除作品' : '已从列表移除（本地存储暂不可用）');
  }

  private confirmDeleteWork(work: WorkData): void {
    const dialog: AlertDialogParamWithButtons = {
      title: '删除作品',
      message: `「${work.title}」删除后无法恢复。`,
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#E5484D',
        action: () => {
          this.removeWork(work);
        }
      }
    };
    try {
      this.getUIContext().showAlertDialog(dialog);
    } catch (error) {
      console.error(`FontPlayground delete dialog failed: ${JSON.stringify(error)}`);
      this.removeWork(work);
    }
  }

  // ---------------------------------------------------------------- 风格库

  private draftPreviewWork(): WorkData {
    const text = this.draftText.trim().length > 0 ? this.draftText : defaultSample(this.draftPreset);
    return new WorkData(
      'draft-style-preview',
      workTitle(text),
      text,
      this.activePreset().id,
      this.draftFont,
      this.draftSize,
      this.draftLetterSpacing,
      this.draftLineHeight,
      this.draftTilt,
      this.draftAlignment,
      this.draftTextColor,
      this.draftBackgroundColor,
      0,
      0,
      0,
      Date.now()
    );
  }

  private findSavedStyle(id: string): SavedStyle | undefined {
    for (let i = 0; i < this.savedStyles.length; i++) {
      if (this.savedStyles[i].id === id) {
        return this.savedStyles[i];
      }
    }
    return undefined;
  }

  private copyTags(tags: string[]): string[] {
    const copy: string[] = [];
    for (let i = 0; i < tags.length; i++) {
      copy.push(tags[i]);
    }
    return copy;
  }

  private persistStyles(): boolean {
    if (this.styleStore === undefined) {
      return false;
    }
    return this.styleStore.save(this.savedStyles);
  }

  /** 从创作台打开：把当前画布的排版存成新风格。 */
  private openStyleSheet(): void {
    this.editingStyleId = '';
    this.editSyncRecipe = false;
    this.styleNameDraft = `我的 ${this.activePreset().name}`;
    this.styleTags = [];
    this.styleTagDraft = '';
    this.selected = false;
    this.showStyleSheet = true;
  }

  /** 从风格库打开：编辑已有风格的名称与标签（可选择同步当前排版参数）。 */
  private openEditStyleSheet(style: SavedStyle): void {
    this.editingStyleId = style.id;
    this.editSyncRecipe = false;
    this.styleNameDraft = style.name;
    this.styleTags = this.copyTags(style.tags);
    this.styleTagDraft = '';
    this.selected = false;
    this.showStyleSheet = true;
  }

  private closeStyleSheet(): void {
    this.showStyleSheet = false;
    this.styleNameDraft = '';
    this.styleTags = [];
    this.styleTagDraft = '';
    this.editingStyleId = '';
    this.editSyncRecipe = false;
  }

  private addStyleTag(): void {
    const tag = normalizeStyleTag(this.styleTagDraft);
    if (tag.length === 0) {
      this.toast('先输入一个特点，比如「高对比」');
      return;
    }
    if (this.styleTags.length >= STYLE_TAGS_MAX) {
      this.toast(`最多添加 ${STYLE_TAGS_MAX} 个标签`);
      return;
    }
    for (let i = 0; i < this.styleTags.length; i++) {
      if (this.styleTags[i] === tag) {
        this.styleTagDraft = '';
        this.toast('这个标签已经添加过了');
        return;
      }
    }
    const next: string[] = this.copyTags(this.styleTags);
    next.push(tag);
    this.styleTags = next;
    this.styleTagDraft = '';
  }

  private removeStyleTag(tag: string): void {
    const next: string[] = [];
    for (let i = 0; i < this.styleTags.length; i++) {
      if (this.styleTags[i] !== tag) {
        next.push(this.styleTags[i]);
      }
    }
    if (next.length !== this.styleTags.length) {
      this.styleTags = next;
    }
  }

  /** 标签自动拼成「简洁 · 美观」，无需用户自己输入分隔符。 */
  private styleNotePreview(): string {
    return styleNoteFromTags(this.styleTags, '添加标签后自动生成，例如：简洁 · 美观');
  }

  private styleSheetPreviewWork(): WorkData {
    if (this.editingStyleId !== '' && !this.editSyncRecipe) {
      const style = this.findSavedStyle(this.editingStyleId);
      if (style !== undefined) {
        return stylePreviewWork(style);
      }
    }
    return this.draftPreviewWork();
  }

  private saveStyle(): void {
    const name = this.styleNameDraft.replace(/\s+/g, ' ').trim();
    if (name.length === 0) {
      this.toast('先给这个风格起个名字');
      return;
    }
    if (this.editingStyleId !== '') {
      this.updateStyle(name);
      return;
    }
    const sample = this.draftText.trim().length > 0 ? this.draftText.trim() : defaultSample(this.draftPreset);
    const style = new SavedStyle(
      `${Date.now()}-${Math.floor(Math.random() * 1000000)}`,
      name.slice(0, STYLE_NAME_MAX),
      this.copyTags(this.styleTags),
      sample,
      this.activePreset().id,
      this.draftFont,
      this.draftSize,
      this.draftLetterSpacing,
      this.draftLineHeight,
      this.draftTilt,
      this.draftAlignment,
      this.draftTextColor,
      this.draftBackgroundColor,
      Date.now()
    );
    const next: SavedStyle[] = [style];
    for (let i = 0; i < this.savedStyles.length; i++) {
      next.push(this.savedStyles[i]);
    }
    this.savedStyles = next;
    const persisted = this.persistStyles();
    this.closeStyleSheet();
    this.toast(persisted ? '已保存到风格库' : '已加入风格库（本地存储暂不可用）');
  }

  private updateStyle(name: string): void {
    const target = this.findSavedStyle(this.editingStyleId);
    if (target === undefined) {
      this.closeStyleSheet();
      return;
    }
    const tags: string[] = this.copyTags(this.styleTags);
    let updated: SavedStyle;
    if (this.editSyncRecipe) {
      // 勾选后把当前画布的字号、颜色、间距一并写回这个风格。
      const sample = this.draftText.trim().length > 0 ? this.draftText.trim() : defaultSample(this.draftPreset);
      updated = new SavedStyle(target.id, name.slice(0, STYLE_NAME_MAX), tags, sample,
        this.activePreset().id, this.draftFont, this.draftSize, this.draftLetterSpacing,
        this.draftLineHeight, this.draftTilt, this.draftAlignment, this.draftTextColor,
        this.draftBackgroundColor, target.savedAt);
    } else {
      updated = new SavedStyle(target.id, name.slice(0, STYLE_NAME_MAX), tags, target.sample,
        target.preset, target.font, target.size, target.letterSpacing, target.lineHeight,
        target.tilt, target.alignment, target.textColor, target.backgroundColor, target.savedAt);
    }
    const next: SavedStyle[] = [];
    for (let i = 0; i < this.savedStyles.length; i++) {
      const item = this.savedStyles[i];
      next.push(item.id === updated.id ? updated : item);
    }
    this.styleRevision = this.styleRevision + 1;
    this.savedStyles = next;
    const persisted = this.persistStyles();
    this.closeStyleSheet();
    this.toast(persisted ? `已更新「${updated.name}」` : '已更新（本地存储暂不可用）');
  }

  private applyStyle(style: SavedStyle): void {
    this.draftPreset = findPreset(style.preset).id;
    this.draftFont = style.font;
    this.draftSize = style.size;
    this.draftLetterSpacing = style.letterSpacing;
    this.draftLineHeight = style.lineHeight;
    this.draftTilt = style.tilt;
    this.draftAlignment = style.alignment;
    this.draftTextColor = style.textColor;
    this.draftBackgroundColor = style.backgroundColor;
    if (this.draftText.trim().length === 0) {
      this.draftText = style.sample;
    }
    this.syncPickerHsv();
    this.hexDraft = this.pickerColor();
    this.draftOffsetX = 0;
    this.draftOffsetY = 0;
    this.draftRotation = 0;
    this.selected = false;
    this.activeTool = TOOL_STYLE;
    this.currentPage = PageKind.Create;
    this.toast(`已套用「${style.name}」`);
  }

  private removeStyle(style: SavedStyle): void {
    const next: SavedStyle[] = [];
    for (let i = 0; i < this.savedStyles.length; i++) {
      const item = this.savedStyles[i];
      if (item.id !== style.id) {
        next.push(item);
      }
    }
    if (next.length === this.savedStyles.length) {
      return;
    }
    this.savedStyles = next;
    const persisted = this.persistStyles();
    this.toast(persisted ? '已删除风格' : '已从列表移除（本地存储暂不可用）');
  }

  private confirmDeleteStyle(style: SavedStyle): void {
    const dialog: AlertDialogParamWithButtons = {
      title: '删除风格',
      message: `「${style.name}」将从风格库移除，删除后无法恢复。`,
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#E5484D',
        action: () => {
          this.removeStyle(style);
        }
      }
    };
    try {
      this.getUIContext().showAlertDialog(dialog);
    } catch (error) {
      console.error(`FontPlayground style delete dialog failed: ${JSON.stringify(error)}`);
      this.removeStyle(style);
    }
  }

  // ---------------------------------------------------------------- 风格卡片

  /** 预设卡片的缩略图：沿用色调背景，再交给作品预览统一绘制文字。 */
  private presetCardPreview(card: StyleCardSpec): WorkData {
    const preset = findPreset(card.preset);
    return new WorkData(
      `preset-preview-${card.preset}`,
      card.title,
      card.sample,
      preset.id,
      preset.font,
      45,
      -3,
      115,
      0,
      'left',
      this.toneForeground(card.tone),
      this.toneBackground(card.tone),
      0,
      0,
      0,
      0
    );
  }

  private presetStyleCard(card: StyleCardSpec): StyleCardView {
    return {
      id: card.preset,
      custom: false,
      kicker: card.kicker,
      title: card.title,
      note: card.note,
      meta: card.meta,
      preset: card.preset,
      sample: card.sample,
      preview: this.presetCardPreview(card)
    };
  }

  private customStyleCard(style: SavedStyle): StyleCardView {
    return {
      id: style.id,
      custom: true,
      kicker: '我的风格',
      title: style.name,
      note: style.note,
      meta: `${findPreset(style.preset).name} · ${formatSavedDate(style.savedAt)}`,
      preset: style.preset,
      sample: style.sample,
      preview: stylePreviewWork(style)
    };
  }

  // ---------------------------------------------------------------- 图标

  @Builder
  BrandMark() {
    Row({ space: 0 }) {
      Text('F')
        .fontSize(25)
        .fontWeight(900)
        .fontColor(COLOR_INK)
        .letterSpacing(-1.2)
      Text('.')
        .fontSize(25)
        .fontWeight(900)
        .fontColor(COLOR_BLUE)
        .letterSpacing(-1.2)
    }
    .alignItems(VerticalAlign.Bottom)
  }

  @Builder
  NavIcon(page: PageKind) {
    if (page === PageKind.Explore) {
      Stack() {
        Column()
          .width(19)
          .height(19)
          .borderRadius(10)
          .border({ width: 1.6, color: this.currentPage === page ? COLOR_BLUE : COLOR_SUBTLE })
        Column()
          .width(6)
          .height(6)
          .borderRadius(2)
          .backgroundColor(this.currentPage === page ? COLOR_BLUE : COLOR_SUBTLE)
          .rotate({ angle: 45 })
      }
      .width(20)
      .height(20)
    } else if (page === PageKind.Create) {
      Stack() {
        Column()
          .width(16)
          .height(1.8)
          .borderRadius(1)
          .backgroundColor(this.currentPage === page ? COLOR_BLUE : COLOR_SUBTLE)
        Column()
          .width(1.8)
          .height(16)
          .borderRadius(1)
          .backgroundColor(this.currentPage === page ? COLOR_BLUE : COLOR_SUBTLE)
      }
      .width(20)
      .height(20)
    } else {
      Stack() {
        Column()
          .width(17)
          .height(17)
          .borderRadius(4)
          .border({ width: 1.6, color: this.currentPage === page ? COLOR_BLUE : COLOR_SUBTLE })
        Row() {
          Blank()
          Column()
            .width(4.5)
            .height(4.5)
            .borderRadius(3)
            .backgroundColor(this.currentPage === page ? COLOR_BLUE : COLOR_SUBTLE)
        }
        .width(17)
        .height(17)
        .padding({ top: 2.5, right: 2.5 })
        .alignItems(VerticalAlign.Top)
        Row() {
          Column()
            .width(7)
            .height(1.6)
            .borderRadius(1)
            .backgroundColor(this.currentPage === page ? COLOR_BLUE : COLOR_SUBTLE)
          Blank()
        }
        .width(17)
        .height(17)
        .padding({ left: 3, bottom: 3 })
        .alignItems(VerticalAlign.Bottom)
      }
      .width(20)
      .height(20)
    }
  }

  @Builder
  NavTab(item: NavSpec) {
    Column({ space: 2 }) {
      Stack() {
        this.NavIcon(item.page)
        if (item.page === PageKind.Gallery && this.savedWorks.length > 0) {
          Row() {
            Blank()
            Column()
              .width(6)
              .height(6)
              .borderRadius(3)
              .backgroundColor(COLOR_BLUE)
              .border({ width: 1.5, color: COLOR_WHITE })
          }
          .width(24)
          .height(22)
          .padding({ top: 1, right: 1 })
          .alignItems(VerticalAlign.Top)
        }
      }
      .width(24)
      .height(22)

      Text(item.label)
        .fontSize(10)
        .fontWeight(this.currentPage === item.page ? 700 : 500)
        .fontColor(this.currentPage === item.page ? COLOR_BLUE : COLOR_SUBTLE)
    }
    .layoutWeight(1)
    .height(50)
    .justifyContent(FlexAlign.Center)
    .accessibilityText(item.label)
    .onClick(() => {
      this.switchPage(item.page);
    })
  }

  @Builder
  BottomNav() {
    Row() {
      Row() {
        ForEach(NAV_ITEMS, (item: NavSpec) => {
          this.NavTab(item)
        }, (item: NavSpec) => item.page)
      }
      .layoutWeight(1)
      .height(58)
      .padding({ left: 6, right: 6 })
      .backgroundColor(COLOR_WHITE)
      .borderRadius(24)
      .shadow({ radius: 18, color: '#14000000', offsetX: 0, offsetY: 6 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 8 })
  }

  // ---------------------------------------------------------------- 灵感页

  @Builder
  SectionHeader(title: string, action: string, actionKind: string) {
    Row() {
      Text(title)
        .fontSize(17)
        .fontWeight(800)
        .fontColor(COLOR_INK)
        .letterSpacing(-0.4)
      Blank()
      if (action.length > 0) {
        Row({ space: 3 }) {
          Text(action)
            .fontSize(11)
            .fontColor(COLOR_SECONDARY)
          Text('›')
            .fontSize(14)
            .fontColor(COLOR_SUBTLE)
        }
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .height(32)
    .margin({ top: 24, bottom: 10 })
    .onClick(() => {
      if (actionKind === TAB_STYLES) {
        this.galleryTab = TAB_STYLES;
        this.switchPage(PageKind.Gallery);
      } else if (actionKind === TAB_WORKS) {
        this.galleryTab = TAB_WORKS;
        this.switchPage(PageKind.Gallery);
      }
    })
  }

  @Builder
  ExploreHeroCard() {
    Stack() {
      Column() {
        Row() {
          Text('MAKE\nROOM\nFOR TYPE.')
            .fontSize(34)
            .fontWeight(900)
            .fontColor(COLOR_WHITE)
            .lineHeight(33)
            .letterSpacing(-1.6)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Top)

        Blank()

        Row() {
          Text('STUDY 024')
            .fontSize(10)
            .fontWeight(700)
            .fontColor('#CCFFFFFF')
            .letterSpacing(0.8)
          Text('点按开始 →')
            .fontSize(10)
            .fontColor('#CCFFFFFF')
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Bottom)
      }
      .width('100%')
      .height('100%')
      .padding(20)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(220)
    .backgroundColor(COLOR_BLUE)
    .borderRadius(22)
    .clip(true)
    .margin({ top: 20 })
    .shadow({ radius: 20, color: '#26245BFF', offsetX: 0, offsetY: 10 })
    .accessibilityText('打开 Brutalist 风格开始创作')
    .onClick(() => {
      this.openPreset('brutalist', 'MAKE ROOM\nFOR TYPE.');
    })
  }

  @Builder
  StyleTile(card: StyleCardSpec) {
    Stack() {
      Column() {
        Text(card.sample)
          .fontSize(this.tileFontSize(card.tone))
          .fontWeight(900)
          .fontColor(this.toneForeground(card.tone))
          .lineHeight(this.tileLineHeight(card.tone))
          .letterSpacing(-0.8)
          .width('100%')

        Blank()

        Column() {
          Text(card.title)
            .fontSize(10)
            .fontWeight(800)
            .fontColor(this.toneForeground(card.tone))
            .letterSpacing(0.8)
          Text(card.note)
            .fontSize(9)
            .fontColor(this.toneForeground(card.tone))
            .opacity(0.66)
            .margin({ top: 3 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width(164)
      .height(202)
      .padding({ left: 14, right: 14, top: 16, bottom: 14 })
      .alignItems(HorizontalAlign.Start)
    }
    .width(164)
    .height(202)
    .backgroundColor(this.toneBackground(card.tone))
    .borderRadius(18)
    .clip(true)
    .accessibilityText(`${card.title}风格`)
    .onClick(() => {
      this.openPreset(card.preset, card.sample);
    })
  }

  @Builder
  RecentWork(work: WorkData) {
    Column() {
      Stack() {
        this.ArtworkPreview(work, 0.29)
      }
      .width(100)
      .height(125)
      .borderRadius(14)
      .clip(true)
      .shadow({ radius: 10, color: '#10000000', offsetX: 0, offsetY: 3 })

      Text(work.title)
        .fontSize(10)
        .fontColor(COLOR_SECONDARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(100)
        .margin({ top: 6 })
    }
    .width(100)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.loadWork(work);
    })
  }

  @Builder
  ExploreHeader() {
    Row() {
      Row({ space: 8 }) {
        this.BrandMark()
        Column() {
          Text('FONT PLAYGROUND')
            .fontSize(10)
            .fontWeight(800)
            .fontColor(COLOR_INK)
            .letterSpacing(0.8)
          Text('排版游乐园')
            .fontSize(9)
            .fontColor(COLOR_SUBTLE)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
      }
      .alignItems(VerticalAlign.Center)

      Blank()

      Stack() {
        Text('✦')
          .fontSize(15)
          .fontColor(COLOR_INK)
      }
      .width(38)
      .height(38)
      .borderRadius(19)
      .backgroundColor(COLOR_WHITE)
      .shadow({ radius: 10, color: '#0F000000', offsetX: 0, offsetY: 3 })
      .accessibilityText('随机灵感')
      .onClick(() => {
        this.randomPreset();
      })
    }
    .width('100%')
    .height(52)
  }

  @Builder
  ExploreIntro() {
    Column() {
      Text() {
        Span('把文字，\n')
          .fontColor(COLOR_INK)
        Span('玩出格。')
          .fontColor(COLOR_BLUE)
      }
      .fontSize(32)
      .fontWeight(900)
      .lineHeight(40)
      .letterSpacing(-1.4)
      .width('100%')
      .margin({ top: 10 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  StyleCarousel() {
    Scroll() {
      Row({ space: 12 }) {
        ForEach(STYLE_CARDS, (card: StyleCardSpec) => {
          this.StyleTile(card)
        }, (card: StyleCardSpec) => card.preset)
      }
      .padding({ right: 4 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .height(202)
  }

  @Builder
  RecentStrip() {
    Scroll() {
      Row({ space: 10 }) {
        ForEach(this.savedWorks.slice(0, 8), (work: WorkData) => {
          this.RecentWork(work)
        }, (work: WorkData) => work.id)
      }
      .padding({ right: 4 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
    .width('100%')
    .height(147)
  }

  @Builder
  ExplorePage() {
    List() {
      ListItem() {
        this.ExploreHeader()
      }

      ListItem() {
        this.ExploreIntro()
      }

      ListItem() {
        this.ExploreHeroCard()
      }

      ListItem() {
        this.SectionHeader('挑一个起点', '全部风格', TAB_STYLES)
      }

      ListItem() {
        this.StyleCarousel()
      }

      if (this.savedWorks.length > 0) {
        ListItem() {
          this.SectionHeader('最近作品', '查看全部', TAB_WORKS)
        }

        ListItem() {
          this.RecentStrip()
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 4, bottom: 18 })
    .constraintSize({ maxWidth: 720 })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  // ---------------------------------------------------------------- 作品页

  @Builder
  Segmented() {
    Row() {
      Row() {
        Text('我的作品')
          .fontSize(12)
          .fontWeight(this.galleryTab === TAB_WORKS ? 700 : 500)
          .fontColor(this.galleryTab === TAB_WORKS ? COLOR_INK : COLOR_SUBTLE)
      }
      .layoutWeight(1)
      .height(34)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.galleryTab === TAB_WORKS ? COLOR_WHITE : Color.Transparent)
      .borderRadius(9)
      .shadow({
        radius: this.galleryTab === TAB_WORKS ? 6 : 0,
        color: '#12000000',
        offsetX: 0,
        offsetY: 2
      })
      .onClick(() => {
        this.galleryTab = TAB_WORKS;
      })

      Row() {
        Text('风格库')
          .fontSize(12)
          .fontWeight(this.galleryTab === TAB_STYLES ? 700 : 500)
          .fontColor(this.galleryTab === TAB_STYLES ? COLOR_INK : COLOR_SUBTLE)
      }
      .layoutWeight(1)
      .height(34)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.galleryTab === TAB_STYLES ? COLOR_WHITE : Color.Transparent)
      .borderRadius(9)
      .shadow({
        radius: this.galleryTab === TAB_STYLES ? 6 : 0,
        color: '#12000000',
        offsetX: 0,
        offsetY: 2
      })
      .onClick(() => {
        this.galleryTab = TAB_STYLES;
      })
    }
    .width('100%')
    .height(42)
    .padding(4)
    .backgroundColor(COLOR_FIELD)
    .borderRadius(12)
    .margin({ top: 4, bottom: 14 })
  }

  @Builder
  ArtworkPreview(work: WorkData, scale: number) {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(work.backgroundColor)

      Column() {
        Text(work.text)
          .fontSize(`${Math.min(52, Math.max(11, work.size * scale))}vp`)
          .fontFamily(findFont(work.font).family)
          .fontWeight(this.workFontWeight(work))
          .fontColor(work.textColor)
          .letterSpacing(`${work.letterSpacing * work.size * scale / 100}vp`)
          .lineHeight(`${work.size * scale * work.lineHeight / 100}vp`)
          .textCase(findPreset(work.preset).uppercase ? TextCase.UpperCase : TextCase.Normal)
          .textAlign(work.alignment === 'center' ? TextAlign.Center :
            (work.alignment === 'right' ? TextAlign.End : TextAlign.Start))
          .width('100%')
          .maxLines(6)
          .textOverflow({ overflow: TextOverflow.Clip })
          .transform(matrix4.identity().skew(Math.tan(work.tilt * Math.PI / 180), 0))
          .translate({ x: work.offsetX * scale, y: work.offsetY * scale })
          .rotate({ angle: work.rotation })
      }
      .width('84%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  WorkCard(work: WorkData) {
    Column() {
      Stack() {
        this.ArtworkPreview(work, 0.46)

        Row() {
          Stack() {
            Text('✕')
              .fontSize(12)
              .fontWeight(700)
              .fontColor(COLOR_WHITE)
          }
          .width(28)
          .height(28)
          .borderRadius(14)
          .backgroundColor('#66000000')
          .accessibilityText('删除这张作品')
          .onClick(() => {
            this.confirmDeleteWork(work);
          })

          Blank()

          Stack() {
            Text('↓')
              .fontSize(13)
              .fontColor(COLOR_WHITE)
          }
          .width(28)
          .height(28)
          .borderRadius(14)
          .backgroundColor('#66000000')
          .accessibilityText('导出这张作品')
          .onClick(() => {
            this.downloadWork(work);
          })
        }
        .width('100%')
        .height('100%')
        .padding(8)
        .alignItems(VerticalAlign.Top)
      }
      .width('100%')
      .aspectRatio(0.8)
      .borderRadius(14)
      .clip(true)
      .backgroundColor(work.backgroundColor)

      Text(work.title)
        .fontSize(12)
        .fontWeight(600)
        .fontColor(COLOR_INK)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 8 })

      Text(`${findPreset(work.preset).name} · ${formatSavedDate(work.savedAt)}`)
        .fontSize(10)
        .fontColor(COLOR_SUBTLE)
        .maxLines(1)
        .width('100%')
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.loadWork(work);
    })
  }

  /** 自定义风格与预设风格共用同一张卡片：缩略图、标签行、标题、特点、底部信息与操作位一致。 */
  @Builder
  StyleLibraryCard(view: StyleCardView) {
    Row() {
      Stack() {
        this.ArtworkPreview(view.preview, 0.29)

        if (view.custom) {
          Row() {
            Stack() {
              Text('✕')
                .fontSize(11)
                .fontWeight(700)
                .fontColor(COLOR_WHITE)
            }
            .width(26)
            .height(26)
            .borderRadius(13)
            .backgroundColor('#66000000')
            .accessibilityText('删除这个风格')
            .onClick(() => {
              const style = this.findSavedStyle(view.id);
              if (style !== undefined) {
                this.confirmDeleteStyle(style);
              }
            })

            Blank()

            Stack() {
              Text('编辑')
                .fontSize(9)
                .fontWeight(700)
                .fontColor(COLOR_WHITE)
            }
            .height(24)
            .padding({ left: 8, right: 8 })
            .borderRadius(12)
            .backgroundColor('#66000000')
            .accessibilityText('编辑这个风格的名称和标签')
            .onClick(() => {
              const style = this.findSavedStyle(view.id);
              if (style !== undefined) {
                this.openEditStyleSheet(style);
              }
            })
          }
          .width('100%')
          .height('100%')
          .padding(6)
          .alignItems(VerticalAlign.Top)
        }
      }
      .width(100)
      .height(125)
      .borderRadius(12)
      .clip(true)
      .backgroundColor(view.preview.backgroundColor)

      Column() {
        Text(view.kicker)
          .fontSize(9)
          .fontWeight(700)
          .fontColor(COLOR_BLUE)
          .letterSpacing(0.6)
        Text(view.title)
          .fontSize(16)
          .fontWeight(800)
          .fontColor(COLOR_INK)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 4 })
        Text(view.note)
          .fontSize(11)
          .fontColor(COLOR_SECONDARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 4 })

        Blank()

        Row() {
          Text(view.meta)
            .fontSize(9)
            .fontColor(COLOR_SUBTLE)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Row({ space: 4 }) {
            Text('使用这个风格')
              .fontSize(11)
              .fontWeight(700)
              .fontColor(COLOR_INK)
            Text('→')
              .fontSize(12)
              .fontColor(COLOR_INK)
          }
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .layoutWeight(1)
      .height(125)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
    }
    .width('100%')
    .padding(10)
    .backgroundColor(COLOR_WHITE)
    .borderRadius(16)
    .margin({ bottom: 10 })
    .onClick(() => {
      if (view.custom) {
        const style = this.findSavedStyle(view.id);
        if (style !== undefined) {
          this.applyStyle(style);
        }
      } else {
        this.openPreset(view.preset, view.sample);
      }
    })
  }

  @Builder
  StyleSectionLabel(title: string, caption: string) {
    Row() {
      Text(title)
        .fontSize(13)
        .fontWeight(800)
        .fontColor(COLOR_INK)
        .letterSpacing(-0.3)
      Blank()
      Text(caption)
        .fontSize(10)
        .fontColor(COLOR_SUBTLE)
    }
    .width('100%')
    .height(32)
    .padding({ top: 6 })
  }

  @Builder
  EmptyStyles() {
    Column() {
      Text('还没有自定义风格')
        .fontSize(14)
        .fontWeight(700)
        .fontColor(COLOR_INK)
      Text('在创作页「样式」里点「存当前风格」，\n把调好的字体、颜色和间距保存下来。')
        .fontSize(11)
        .fontColor(COLOR_SECONDARY)
        .lineHeight(18)
        .textAlign(TextAlign.Center)
        .margin({ top: 6 })
      Button('去创作')
        .type(ButtonType.Normal)
        .height(36)
        .padding({ left: 18, right: 18 })
        .fontSize(12)
        .fontWeight(700)
        .fontColor(COLOR_WHITE)
        .backgroundColor(COLOR_BLUE)
        .borderRadius(12)
        .margin({ top: 14 })
        .onClick(() => {
          this.activeTool = TOOL_STYLE;
          this.switchPage(PageKind.Create);
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 22, bottom: 22 })
    .backgroundColor(COLOR_WHITE)
    .borderRadius(18)
    .border({ width: 1, color: COLOR_LINE, style: BorderStyle.Dashed })
    .alignItems(HorizontalAlign.Center)
    .margin({ bottom: 8 })
  }

  @Builder
  EmptyWorks() {
    Column() {
      Column() {
        Text('还没有保存的作品')
          .fontSize(15)
          .fontWeight(700)
          .fontColor(COLOR_INK)
        Text('在创作台调好版面后点「保存」，\n作品就会出现在这里。')
          .fontSize(12)
          .fontColor(COLOR_SECONDARY)
          .lineHeight(19)
          .textAlign(TextAlign.Center)
          .margin({ top: 6 })
        Button('去创作')
          .type(ButtonType.Normal)
          .height(40)
          .padding({ left: 20, right: 20 })
          .fontSize(13)
          .fontWeight(700)
          .fontColor(COLOR_WHITE)
          .backgroundColor(COLOR_BLUE)
          .borderRadius(12)
          .margin({ top: 16 })
          .onClick(() => {
            this.switchPage(PageKind.Create);
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 30, bottom: 30 })
      .backgroundColor(COLOR_WHITE)
      .borderRadius(20)
      .border({ width: 1, color: COLOR_LINE, style: BorderStyle.Dashed })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 20, right: 20, bottom: 20 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  GalleryPage() {
    Column() {
      Row() {
        Column() {
          Text(this.galleryTab === TAB_WORKS ? '作品' : '风格库')
            .fontSize(26)
            .fontWeight(900)
            .fontColor(COLOR_INK)
            .letterSpacing(-0.8)
          Text(this.galleryTab === TAB_WORKS ? '收藏、回看、再次编辑' : '保存排版配方，随时复用')
            .fontSize(11)
            .fontColor(COLOR_SUBTLE)
            .margin({ top: 3 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height(60)
      .padding({ left: 20, right: 16, top: 8 })
      .alignItems(VerticalAlign.Center)

      this.Segmented()

      if (this.galleryTab === TAB_WORKS) {
        if (this.savedWorks.length === 0) {
          this.EmptyWorks()
        } else {
          List() {
            ForEach(this.workRowIndexes(), (rowIndex: number) => {
              ListItem() {
                Row({ space: 12 }) {
                  this.WorkCard(this.savedWorks[rowIndex * 2])
                  if (rowIndex * 2 + 1 < this.savedWorks.length) {
                    this.WorkCard(this.savedWorks[rowIndex * 2 + 1])
                  } else {
                    Column()
                      .layoutWeight(1)
                  }
                }
                .width('100%')
                .alignItems(VerticalAlign.Top)
                .margin({ bottom: 16 })
              }
            }, (rowIndex: number) => this.workRowKey(rowIndex))
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 20, right: 20, top: 2, bottom: 16 })
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
      } else {
        List() {
          if (this.savedStyles.length > 0) {
            // 用 ForEach 承载标题行：数量变化时 List 才会重建这一行，避免「N 个」停留在旧值。
            ForEach([this.savedStyles.length], (count: number) => {
              ListItem() {
                this.StyleSectionLabel('我的风格', `${count} 个`)
              }
            }, (count: number) => `my-styles-label-${count}`)
            ForEach(this.savedStyles, (style: SavedStyle) => {
              ListItem() {
                this.StyleLibraryCard(this.customStyleCard(style))
              }
            }, (style: SavedStyle) => `my-style-${style.id}-${this.styleRevision}`)
          } else {
            ListItem() {
              this.EmptyStyles()
            }
          }

          ListItem() {
            this.StyleSectionLabel('预设风格', `内置 ${STYLE_CARDS.length} 款`)
          }
          ForEach(STYLE_CARDS, (card: StyleCardSpec) => {
            ListItem() {
              this.StyleLibraryCard(this.presetStyleCard(card))
            }
          }, (card: StyleCardSpec) => `library-${card.preset}`)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 20, right: 20, top: 2, bottom: 16 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: 4 })
  }

  // ---------------------------------------------------------------- 创作台

  @Builder
  EditorTopBar() {
    Row() {
      Column() {
        Text('创作台')
          .fontSize(19)
          .fontWeight(800)
          .fontColor(COLOR_INK)
          .letterSpacing(-0.5)
        Text(`4:5 · ${this.activePreset().name}`)
          .fontSize(10)
          .fontColor(COLOR_SUBTLE)
          .margin({ top: 2 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Stack() {
        Text('↺')
          .fontSize(15)
          .fontColor(COLOR_INK)
      }
      .width(32)
      .height(32)
      .borderRadius(16)
      .backgroundColor(COLOR_FIELD)
      .margin({ right: 8 })
      .accessibilityText('复位文字位置')
      .onClick(() => {
        this.resetTransform();
      })

      Button() {
        Text('保存')
          .fontSize(12)
          .fontWeight(700)
          .fontColor(COLOR_INK)
      }
      .type(ButtonType.Normal)
      .width(52)
      .height(32)
      .backgroundColor(COLOR_FIELD)
      .borderRadius(16)
      .onClick(() => {
        this.saveCurrent();
      })

      Button() {
        Row({ space: 5 }) {
          Text(this.isExporting ? '导出中' : '导出')
            .fontSize(12)
            .fontWeight(700)
            .fontColor(COLOR_WHITE)
          Text(this.isExporting ? '↻' : '↓')
            .fontSize(12)
            .fontColor(COLOR_WHITE)
        }
      }
      .type(ButtonType.Normal)
      .width(84)
      .height(32)
      .backgroundColor(COLOR_BLUE)
      .borderRadius(16)
      .margin({ left: 8 })
      .enabled(!this.isExporting)
      .onClick(() => {
        this.downloadCurrent();
      })
    }
    .width('100%')
    .height(56)
    .padding({ left: 20, right: 16 })
  }

  @Builder
  Artboard() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.draftBackgroundColor)
        .onClick(() => {
          this.selected = false;
        })

      Column() {
        Row() {
          Text('FONT PLAYGROUND')
            .fontSize(7)
            .fontWeight(600)
            .fontColor(this.draftTextColor)
            .opacity(0.62)
            .letterSpacing(0.5)
          Text('STUDY 001')
            .fontSize(7)
            .fontWeight(600)
            .fontColor(this.draftTextColor)
            .opacity(0.62)
            .letterSpacing(0.5)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)

        Blank()

        Row() {
          Text('01 — 03')
            .fontSize(8)
            .fontColor(this.draftTextColor)
            .opacity(0.8)
            .letterSpacing(0.4)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Bottom)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 12 })
      .hitTestBehavior(HitTestMode.None)

      Column({ space: 0 }) {
        Column() {
          if (this.selected) {
            Column() {
              Column()
                .width(1.5)
                .height(10)
                .backgroundColor(this.selectionColor())
              Stack() {
                Text('↻')
                  .fontSize(14)
                  .fontColor(COLOR_WHITE)
              }
              .width(28)
              .height(28)
              .borderRadius(14)
              .backgroundColor(COLOR_BLUE)
              .border({ width: 1.5, color: COLOR_WHITE })
              .accessibilityText('旋转手柄，围绕文字中心拖动可旋转')
              .gesture(
                PanGesture({ fingers: 1, direction: PanDirection.All, distance: 1 })
                  .onActionStart(() => {
                    this.rotateStart = this.draftRotation;
                  })
                  .onActionUpdate((event: GestureEvent) => {
                    this.draftRotation = this.normalizeRotation(
                      this.rotateStart + this.rotationDelta(event.offsetX, event.offsetY));
                  })
              )
            }
            .alignItems(HorizontalAlign.Center)
          }
        }
        .width('100%')
        .height(40)
        .justifyContent(FlexAlign.End)
        .alignItems(HorizontalAlign.Center)
        .hitTestBehavior(this.selected ? HitTestMode.Default : HitTestMode.None)

        Stack() {
          Text(this.draftText)
            .fontSize(`${this.draftSize}vp`)
            .fontFamily(this.activeFont().family)
            .fontWeight(this.fontWeightValue())
            .fontColor(this.draftTextColor)
            .letterSpacing(`${this.draftLetterSpacing * this.draftSize / 100}vp`)
            .lineHeight(`${this.draftSize * this.draftLineHeight / 100}vp`)
            .textCase(this.activePreset().uppercase ? TextCase.UpperCase : TextCase.Normal)
            .textAlign(this.textAlignValue())
            .width('100%')
        }
        .width('100%')
        .padding(8)
        .border({
          width: 1.5,
          color: this.selected ? this.selectionColor() : Color.Transparent,
          style: BorderStyle.Solid
        })
        .transform(matrix4.identity().skew(Math.tan(this.draftTilt * Math.PI / 180), 0))
        .onAreaChange((_oldArea: Area, newArea: Area) => {
          const height = Number(newArea.height);
          if (!Number.isNaN(height) && height > 0) {
            this.textBlockHeight = height;
          }
        })
        .gesture(
          PanGesture({ fingers: 1, direction: PanDirection.All, distance: 1 })
            .onActionStart(() => {
              this.selected = true;
              this.dragStartX = this.draftOffsetX;
              this.dragStartY = this.draftOffsetY;
            })
            .onActionUpdate((event: GestureEvent) => {
              // 文字对象的可移动范围约为画布的 ±42%，避免整块文字被拖出画布。
              const limitX = Math.max(60, this.artboardWidth * 0.42);
              const limitY = Math.max(60, this.artboardHeight * 0.42);
              this.draftOffsetX = Math.max(-limitX,
                Math.min(limitX, this.dragStartX + event.offsetX));
              this.draftOffsetY = Math.max(-limitY,
                Math.min(limitY, this.dragStartY + event.offsetY));
            })
        )
        .onClick(() => {
          this.selected = true;
        })

        Column()
          .width('100%')
          .height(40)
          .hitTestBehavior(HitTestMode.None)
      }
      .width('86%')
      .align(Alignment.Center)
      .translate({ x: this.draftOffsetX, y: this.draftOffsetY })
      .rotate({ angle: this.draftRotation })

    }
    .id('artboard')
    .width(this.canvasWidth())
    .height(this.canvasHeight())
    .backgroundColor(this.draftBackgroundColor)
    .clip(true)
    .borderRadius(4)
    .shadow({ radius: 26, color: '#80000000', offsetX: 0, offsetY: 10 })
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const width = Number(newArea.width);
      const height = Number(newArea.height);
      if (!Number.isNaN(width) && width > 0) {
        this.artboardWidth = width;
      }
      if (!Number.isNaN(height) && height > 0) {
        this.artboardHeight = height;
      }
    })
    .onAppear(() => {
      if (this.pendingExport) {
        this.pendingExport = false;
        setTimeout(() => {
          this.downloadCurrent();
        }, 160);
      }
    })
  }

  @Builder
  CanvasStage() {
    Stack() {
      // 画布按逻辑尺寸排布，再由外层等比缩放塞进舞台，避免键盘弹出时文字重排。
      Stack() {
        this.Artboard()
      }
      .width(this.canvasWidth())
      .height(this.canvasHeight())
      .scale({ x: this.canvasViewScale(), y: this.canvasViewScale() })
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor(COLOR_STAGE)
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const width = Number(newArea.width);
      const height = Number(newArea.height);
      if (!Number.isNaN(width) && width > 0) {
        this.canvasHostWidth = width;
      }
      if (!Number.isNaN(height) && height > 0) {
        this.canvasHostHeight = height;
      }
    })
  }

  @Builder
  ToolIcon(tool: ToolSpec) {
    if (tool.id === TOOL_TEXT) {
      Text('T')
        .fontSize(15)
        .fontWeight(800)
        .fontColor(this.toolColor(tool.id))
    } else if (tool.id === TOOL_STYLE) {
      Text('✦')
        .fontSize(14)
        .fontColor(this.toolColor(tool.id))
    } else if (tool.id === TOOL_FONT) {
      Text('Aa')
        .fontSize(12)
        .fontWeight(800)
        .fontColor(this.toolColor(tool.id))
    } else if (tool.id === TOOL_LAYOUT) {
      Column({ space: 2 }) {
        Column()
          .width(14)
          .height(2)
          .borderRadius(1)
          .backgroundColor(this.toolColor(tool.id))
        Column()
          .width(9)
          .height(2)
          .borderRadius(1)
          .backgroundColor(this.toolColor(tool.id))
        Column()
          .width(14)
          .height(2)
          .borderRadius(1)
          .backgroundColor(this.toolColor(tool.id))
      }
    } else {
      Stack() {
        Column()
          .width(15)
          .height(15)
          .borderRadius(8)
          .border({ width: 1.5, color: this.toolColor(tool.id) })
        Column()
          .width(7)
          .height(15)
          .backgroundColor(this.toolColor(tool.id))
          .borderRadius({ topRight: 7, bottomRight: 7 })
      }
      .width(15)
      .height(15)
      .clip(true)
    }
  }

  @Builder
  TextToolBody() {
    Column() {
      Row() {
        Text('文案')
          .fontSize(12)
          .fontWeight(700)
          .fontColor(COLOR_INK)
        Blank()
        Text(`${this.draftText.length} / 60`)
          .fontSize(10)
          .fontColor(COLOR_SUBTLE)
      }
      .width('100%')
      .height(16)

      TextArea({ text: this.draftText, placeholder: '写下你的文字…' })
        .width('100%')
        .height(56)
        .fontSize(13)
        .fontColor(COLOR_INK)
        .placeholderColor('#A9ABA4')
        .placeholderFont({ size: 13 })
        .backgroundColor(COLOR_FIELD)
        .borderRadius(12)
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .maxLength(60)
        .margin({ top: 7 })
        .onChange((value: string) => {
          this.draftText = value;
        })
        .onFocus(() => {
          this.textFocused = true;
        })
        .onBlur(() => {
          this.textFocused = false;
        })

      Row() {
        Text('对齐')
          .fontSize(10)
          .fontColor(COLOR_SECONDARY)
        Blank()
        Row({ space: 6 }) {
          ForEach(ALIGNMENTS, (option: AlignmentSpec) => {
            Stack() {
              Column({ space: 2.5 }) {
                Column()
                  .width(14)
                  .height(2)
                  .borderRadius(1)
                  .backgroundColor(this.draftAlignment === option.id ? COLOR_WHITE : COLOR_INK)
                Column()
                  .width(9)
                  .height(2)
                  .borderRadius(1)
                  .backgroundColor(this.draftAlignment === option.id ? COLOR_WHITE : COLOR_INK)
                Column()
                  .width(12)
                  .height(2)
                  .borderRadius(1)
                  .backgroundColor(this.draftAlignment === option.id ? COLOR_WHITE : COLOR_INK)
              }
              .width(16)
              .alignItems(this.alignmentValue(option.id))
            }
            .width(34)
            .height(30)
            .borderRadius(9)
            .backgroundColor(this.draftAlignment === option.id ? COLOR_INK : COLOR_FIELD)
            .accessibilityText(option.label)
            .onClick(() => {
              this.draftAlignment = option.id;
              this.selected = false;
            })
          }, (option: AlignmentSpec) => option.id)
        }
      }
      .width('100%')
      .height(30)
      .margin({ top: 7 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  StyleToolBody() {
    Column() {
      Row() {
        Text('预设风格')
          .fontSize(12)
          .fontWeight(700)
          .fontColor(COLOR_INK)
        Blank()
        Button() {
          Row({ space: 4 }) {
            Text('＋')
              .fontSize(12)
              .fontWeight(700)
              .fontColor(COLOR_BLUE)
            Text('存当前风格')
              .fontSize(11)
              .fontWeight(700)
              .fontColor(COLOR_BLUE)
          }
          .alignItems(VerticalAlign.Center)
        }
        .type(ButtonType.Normal)
        .height(26)
        .padding({ left: 10, right: 10 })
        .backgroundColor(COLOR_SOFT_BLUE)
        .borderRadius(13)
        .accessibilityText('把当前画布的排版保存到风格库')
        .onClick(() => {
          this.openStyleSheet();
        })
      }
      .width('100%')
      .height(28)
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Row({ space: 10 }) {
          ForEach(PRESETS, (preset: PresetSpec) => {
            Column() {
              Row() {
                Stack() {
                  Text(preset.swatchText)
                    .fontSize(12)
                    .fontWeight(900)
                    .fontColor(preset.swatchColor)
                    .fontFamily(preset.font === 'serif' ? 'serif' :
                      (preset.font === 'mono' ? 'monospace' : 'HarmonyOS Sans'))
                    .letterSpacing(-0.7)
                }
                .width(30)
                .height(30)
                .backgroundColor(preset.swatchBackground)

                Blank()

                if (this.draftPreset === preset.id) {
                  Text('✓')
                    .fontSize(11)
                    .fontWeight(800)
                    .fontColor(COLOR_BLUE)
                }
              }
              .width('100%')

              Text(preset.name)
                .fontSize(11)
                .fontWeight(700)
                .fontColor(COLOR_INK)
                .margin({ top: 7 })
              Text(preset.note)
                .fontSize(9)
                .fontColor(COLOR_SUBTLE)
                .margin({ top: 2 })
                .maxLines(1)
            }
            .width(104)
            .height(96)
            .padding(10)
            .backgroundColor(this.draftPreset === preset.id ? COLOR_SOFT_BLUE : COLOR_FIELD)
            .borderRadius(14)
            .border({
              width: this.draftPreset === preset.id ? 1.5 : 0,
              color: COLOR_BLUE
            })
            .alignItems(HorizontalAlign.Start)
            .accessibilityText(preset.name)
            .onClick(() => {
              this.applyPreset(preset.id);
            })
          }, (preset: PresetSpec) => preset.id)
        }
        .padding({ right: 4 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(96)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  FontToolBody() {
    Row({ space: 8 }) {
      ForEach(FONTS, (font: FontSpec) => {
        Column() {
          Text(font.sample)
            .fontSize(22)
            .fontWeight(700)
            .fontFamily(font.family)
            .fontColor(this.draftFont === font.id ? COLOR_BLUE : COLOR_INK)
          Text(font.name)
            .fontSize(10)
            .fontColor(this.draftFont === font.id ? COLOR_BLUE : COLOR_SUBTLE)
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .height(96)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.draftFont === font.id ? COLOR_SOFT_BLUE : COLOR_FIELD)
        .borderRadius(14)
        .border({ width: this.draftFont === font.id ? 1.5 : 0, color: COLOR_BLUE })
        .accessibilityText(font.name)
        .onClick(() => {
          this.draftFont = font.id;
          this.selected = false;
        })
      }, (font: FontSpec) => font.id)
    }
    .width('100%')
    .height(96)
  }

  @Builder
  SliderCard(label: string, valueText: string, value: number, min: number, max: number,
    step: number, kind: string) {
    Column() {
      Row() {
        Text(label)
          .fontSize(10)
          .fontColor(COLOR_SECONDARY)
        Blank()
        Text(valueText)
          .fontSize(10)
          .fontWeight(700)
          .fontColor(COLOR_INK)
      }
      .width('100%')
      .height(14)

      Slider({
        value: value,
        min: min,
        max: max,
        step: step,
        style: SliderStyle.OutSet
      })
        .width('100%')
        .height(34)
        .trackThickness(3)
        .blockSize({ width: 14, height: 14 })
        .blockColor(COLOR_INK)
        .selectedColor(COLOR_INK)
        .trackColor('#DADBD4')
        .showTips(false)
        .onChange((next: number, mode: SliderChangeMode) => {
          if (kind === 'size') {
            this.draftSize = next;
          } else if (kind === 'spacing') {
            this.draftLetterSpacing = next;
          } else if (kind === 'lineHeight') {
            this.draftLineHeight = next;
          } else if (kind === 'tilt') {
            this.draftTilt = next;
          }
        })
    }
    .layoutWeight(1)
    .height(56)
    .padding({ left: 11, right: 11, top: 6 })
    .backgroundColor(COLOR_FIELD)
    .borderRadius(12)
  }

  @Builder
  LayoutToolBody() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        this.SliderCard('字号', `${this.draftSize}`, this.draftSize, 24, 120, 1, 'size')
        this.SliderCard('字间距', `${(this.draftLetterSpacing / 100).toFixed(2)}`,
          this.draftLetterSpacing, -15, 15, 1, 'spacing')
      }
      .width('100%')

      Row({ space: 8 }) {
        this.SliderCard('行间距', `${this.draftLineHeight}%`,
          this.draftLineHeight, 70, 150, 1, 'lineHeight')
        this.SliderCard('倾斜', `${this.draftTilt}°`, this.draftTilt, 0, 20, 1, 'tilt')
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  ColorSwatch(kind: string, option: ColorSpec) {
    Stack() {
      Column()
        .width(24)
        .height(24)
        .borderRadius(12)
        .backgroundColor(option.value)
        .border({ width: 1, color: '#1A000000' })
    }
    .width(30)
    .height(30)
    .borderRadius(15)
    .border({
      width: this.swatchSelected(kind, option.value) ? 2 : 0,
      color: COLOR_BLUE
    })
    .accessibilityText(option.name)
    .onClick(() => {
      const hsv = hexToHsv(option.value);
      if (kind === 'text') {
        this.draftTextColor = option.value;
        this.textHsv = hsv;
      } else {
        this.draftBackgroundColor = option.value;
        this.backgroundHsv = hsv;
      }
      this.selected = false;
    })
  }

  @Builder
  PaletteButton(kind: string) {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(30)
        .height(30)
        .borderRadius(15)
        .linearGradient({
          angle: 135,
          colors: [
            ['#FF3B30', 0],
            ['#FFCC00', 0.2],
            ['#34C759', 0.4],
            ['#32ADE6', 0.6],
            ['#5E5CE6', 0.8],
            ['#FF2D55', 1]
          ]
        })
        .border({ width: 1, color: '#1A000000' })

      Column()
        .width(17)
        .height(17)
        .borderRadius(9)
        .backgroundColor(COLOR_WHITE)

      Text('+')
        .fontSize(13)
        .fontWeight(700)
        .fontColor(COLOR_INK)
    }
    .width(30)
    .height(30)
    .borderRadius(15)
    .border({
      width: this.isCustomColor(kind) ? 2 : 0,
      color: COLOR_BLUE
    })
    .accessibilityText('打开调色盘')
    .onClick(() => {
      this.openColorPicker(kind);
    })
  }

  @Builder
  PaletteRow(kind: string, label: string) {
    Row({ space: 5 }) {
      Text(label)
        .fontSize(10)
        .fontColor(COLOR_SECONDARY)
        .width(28)

      Row({ space: 5 }) {
        ForEach(COLOR_PAIRS, (pair: ColorPairSpec) => {
          this.ColorSwatch(kind, this.pairColor(pair, kind))
        }, (pair: ColorPairSpec) => `pair-${pair.text.value}-${pair.background.value}`)
        this.PaletteButton(kind)
      }

      Blank()

      Text(this.targetSwatch(kind).toUpperCase())
        .fontSize(9)
        .fontColor(COLOR_SUBTLE)
    }
    .width('100%')
    .height(34)
    .alignItems(VerticalAlign.Center)
  }

  /** 两行色点之间的竖向连线：让“同一列 = 一组文字/背景配色”一目了然。 */
  @Builder
  PairLinks() {
    Row() {
      Blank()
        .width(33)

      Row({ space: 5 }) {
        ForEach(COLOR_PAIRS, (pair: ColorPairSpec) => {
          Row() {
            Column()
              .width(2)
              .height(11)
              .borderRadius(1)
              .backgroundColor(COLOR_LINE)
          }
          .width(30)
          .height(11)
          .justifyContent(FlexAlign.Center)
        }, (pair: ColorPairSpec) => `link-${pair.text.value}-${pair.background.value}`)
      }

      Blank()
    }
    .width('100%')
    .height(11)
  }

  @Builder
  ColorToolBody() {
    Column() {
      this.PaletteRow('text', '文字')
      this.PairLinks()
      this.PaletteRow('background', '背景')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  PickerTargetChip(target: string) {
    Row({ space: 6 }) {
      Column()
        .width(14)
        .height(14)
        .borderRadius(7)
        .backgroundColor(this.targetSwatch(target))
        .border({ width: 1, color: '#26000000' })

      Text(this.targetLabel(target))
        .fontSize(12)
        .fontWeight(this.pickerTarget === target ? 700 : 500)
        .fontColor(this.pickerTarget === target ? COLOR_INK : COLOR_SUBTLE)
    }
    .height(32)
    .padding({ left: 10, right: 12 })
    .borderRadius(16)
    .backgroundColor(this.pickerTarget === target ? COLOR_SOFT_BLUE : COLOR_FIELD)
    .border({ width: this.pickerTarget === target ? 1.5 : 0, color: COLOR_BLUE })
    .accessibilityText(`选择${this.targetLabel(target)}颜色`)
    .onClick(() => {
      this.switchPickerTarget(target);
    })
  }

  @Builder
  TextColorLine() {
    Row({ space: 6 }) {
      Column()
        .width(12)
        .height(12)
        .borderRadius(6)
        .backgroundColor(this.draftTextColor)
        .border({ width: 1, color: '#26000000' })

      Text('文字')
        .fontSize(10)
        .fontColor(COLOR_SECONDARY)
        .width(24)

      Text(this.draftTextColor.toUpperCase())
        .fontSize(10)
        .fontColor(COLOR_SUBTLE)
    }
    .height(18)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  BackgroundColorLine() {
    Row({ space: 6 }) {
      Column()
        .width(12)
        .height(12)
        .borderRadius(6)
        .backgroundColor(this.draftBackgroundColor)
        .border({ width: 1, color: '#26000000' })

      Text('背景')
        .fontSize(10)
        .fontColor(COLOR_SECONDARY)
        .width(24)

      Text(this.draftBackgroundColor.toUpperCase())
        .fontSize(10)
        .fontColor(COLOR_SUBTLE)
    }
    .height(18)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  ColorPickerSheet() {
    Column() {
      Scroll() {
        Column({ space: 12 }) {
      Row() {
        Text('调色盘')
          .fontSize(17)
          .fontWeight(700)
          .fontColor(COLOR_INK)
        Blank()
        Text(this.pickerColor().toUpperCase())
          .fontSize(12)
          .fontWeight(600)
          .fontColor(COLOR_SUBTLE)
      }
      .width('100%')

      Row({ space: 8 }) {
        this.PickerTargetChip(PICKER_TEXT)
        this.PickerTargetChip(PICKER_BACKGROUND)
        Blank()
        Text('点按或拖动取色')
          .fontSize(10)
          .fontColor(COLOR_SUBTLE)
      }
      .width('100%')
      .height(32)
      .alignItems(VerticalAlign.Center)

      Stack({ alignContent: Alignment.TopStart }) {
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 90,
            colors: [[this.pureHue(), 0], ['#FFFFFF', 1]]
          })

        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 180,
            colors: [['#00000000', 0], ['#000000', 1]]
          })

        Column()
          .width(22)
          .height(22)
          .borderRadius(11)
          .backgroundColor(this.pickerColor())
          .border({ width: 2.5, color: COLOR_WHITE })
          .shadow({ radius: 6, color: '#40000000', offsetX: 0, offsetY: 1 })
          .position({ x: this.padThumbX(), y: this.padThumbY() })
      }
      .width('100%')
      .height(176)
      .borderRadius(14)
      .clip(true)
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        const width = Number(newArea.width);
        const height = Number(newArea.height);
        if (!Number.isNaN(width) && width > 0) {
          this.padWidth = width;
        }
        if (!Number.isNaN(height) && height > 0) {
          this.padHeight = height;
        }
      })
      .onTouch((event: TouchEvent) => {
        this.handlePadTouch(event);
      })
      .accessibilityText('饱和度与明度取色区')

      Stack({ alignContent: Alignment.TopStart }) {
        Row()
          .width('100%')
          .height(24)
          .borderRadius(12)
          .linearGradient({
            angle: 90,
            colors: [
              ['#FF0000', 0],
              ['#FFFF00', 0.17],
              ['#00FF00', 0.33],
              ['#00FFFF', 0.5],
              ['#0000FF', 0.67],
              ['#FF00FF', 0.83],
              ['#FF0000', 1]
            ]
          })

        Column()
          .width(22)
          .height(22)
          .borderRadius(11)
          .backgroundColor(this.pureHue())
          .border({ width: 2.5, color: COLOR_WHITE })
          .shadow({ radius: 6, color: '#40000000', offsetX: 0, offsetY: 1 })
          .position({ x: this.hueThumbX(), y: 1 })
      }
      .width('100%')
      .height(24)
      .clip(true)
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        const width = Number(newArea.width);
        if (!Number.isNaN(width) && width > 0) {
          this.hueWidth = width;
        }
      })
      .onTouch((event: TouchEvent) => {
        this.handleHueTouch(event);
      })
      .accessibilityText('色相条')

      Row({ space: 10 }) {
        Text('HEX')
          .fontSize(10)
          .fontWeight(600)
          .fontColor(COLOR_SECONDARY)
          .width(26)

        TextInput({ text: this.hexDraft, placeholder: '#245BFF' })
          .height(40)
          .layoutWeight(1)
          .maxLength(9)
          .fontSize(14)
          .fontColor(COLOR_INK)
          .placeholderColor(COLOR_SUBTLE)
          .backgroundColor(COLOR_FIELD)
          .borderRadius(10)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.hexDraft = value;
            this.applyHexInput(value);
          })
          .onSubmit(() => {
            const normalized = normalizeHex(this.hexDraft);
            this.hexDraft = normalized === '' ? this.pickerColor() : normalized;
          })
      }
      .width('100%')

      if (this.recentColors.length > 0) {
        Row({ space: 8 }) {
          Text('最近')
            .fontSize(10)
            .fontColor(COLOR_SECONDARY)
            .width(26)

          ForEach(this.recentColors, (color: string) => {
            Column()
              .width(24)
              .height(24)
              .borderRadius(12)
              .backgroundColor(color)
              .border({
                width: this.sameColor(this.pickerColor(), color) ? 2 : 1,
                color: this.sameColor(this.pickerColor(), color) ? COLOR_BLUE : '#1A000000'
              })
              .accessibilityText(color.toUpperCase())
              .onClick(() => {
                this.applyHexInput(color);
                this.hexDraft = color;
              })
          }, (color: string) => `recent-${color}`)
          Blank()
        }
        .width('100%')
        .height(24)
        .alignItems(VerticalAlign.Center)
      }

      Row({ space: 12 }) {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(this.draftBackgroundColor)
            .borderRadius(10)

          Text(this.draftText)
            .width('100%')
            .fontSize(12)
            .fontWeight(700)
            .lineHeight(15)
            .fontColor(this.draftTextColor)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({ left: 10, right: 10 })
        }
        .width(112)
        .height(72)
        .borderRadius(10)
        .clip(true)
        .border({ width: 1, color: '#14000000' })

        Column({ space: 8 }) {
          this.TextColorLine()
          this.BackgroundColorLine()
          Text('画布会实时更新')
            .fontSize(10)
            .fontColor(COLOR_SUBTLE)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height(72)
      .alignItems(VerticalAlign.Center)
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
      .enableScrollInteraction(!this.pickerDragging)

      Row({ space: 12 }) {
        Button('取消', { type: ButtonType.Normal, stateEffect: true })
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .fontColor(COLOR_INK)
          .backgroundColor(COLOR_FIELD)
          .borderRadius(12)
          .onClick(() => {
            this.closeColorPicker(false);
          })

        Button('完成', { type: ButtonType.Normal, stateEffect: true })
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .fontWeight(600)
          .fontColor(COLOR_WHITE)
          .backgroundColor(COLOR_BLUE)
          .borderRadius(12)
          .onClick(() => {
            this.closeColorPicker(true);
          })
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 8, bottom: 18 })
  }

  @Builder
  StyleFormSheet() {
    Column() {
      Scroll() {
        Column({ space: 14 }) {
          Row() {
            Column() {
              Text(this.editingStyleId === '' ? '保存风格' : '编辑风格')
                .fontSize(17)
                .fontWeight(700)
                .fontColor(COLOR_INK)
              Text(this.editingStyleId === '' ? '命名并添加特点标签，存进风格库' :
                '修改名称与标签，排版参数保持不变')
                .fontSize(10)
                .fontColor(COLOR_SUBTLE)
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)

            Blank()

            Text(`${findPreset(this.styleSheetPreviewWork().preset).name} · ` +
              `${findFont(this.styleSheetPreviewWork().font).name}`)
              .fontSize(10)
              .fontColor(COLOR_SUBTLE)
              .maxLines(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Row({ space: 12 }) {
            Stack() {
              this.ArtworkPreview(this.styleSheetPreviewWork(), 0.29)
            }
            .width(112)
            .height(72)
            .borderRadius(10)
            .clip(true)
            .border({ width: 1, color: '#14000000' })

            Column({ space: 4 }) {
              Text(`${this.styleSheetPreviewWork().size} 号字 · ` +
                `字距 ${(this.styleSheetPreviewWork().letterSpacing / 100).toFixed(2)}`)
                .fontSize(10)
                .fontColor(COLOR_SECONDARY)
              Text(`行距 ${this.styleSheetPreviewWork().lineHeight}% · ` +
                `倾斜 ${this.styleSheetPreviewWork().tilt}°`)
                .fontSize(10)
                .fontColor(COLOR_SECONDARY)
              Text('套用风格不会替换正在编辑的文字')
                .fontSize(9)
                .fontColor(COLOR_SUBTLE)
                .margin({ top: 2 })
                .maxLines(2)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Column() {
            Row() {
              Text('风格名称')
                .fontSize(11)
                .fontWeight(700)
                .fontColor(COLOR_INK)
              Blank()
              Text(`${this.styleNameDraft.length} / ${STYLE_NAME_MAX}`)
                .fontSize(9)
                .fontColor(COLOR_SUBTLE)
            }
            .width('100%')
            .height(18)

            TextInput({ text: this.styleNameDraft, placeholder: '例如：蓝色海报体' })
              .width('100%')
              .height(42)
              .maxLength(STYLE_NAME_MAX)
              .fontSize(14)
              .fontColor(COLOR_INK)
              .placeholderColor(COLOR_SUBTLE)
              .backgroundColor(COLOR_FIELD)
              .borderRadius(10)
              .padding({ left: 12, right: 12 })
              .margin({ top: 6 })
              .onChange((value: string) => {
                this.styleNameDraft = value;
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Column() {
            Row() {
              Text('风格特点')
                .fontSize(11)
                .fontWeight(700)
                .fontColor(COLOR_INK)
              Blank()
              Text(`${this.styleTags.length} / ${STYLE_TAGS_MAX} 个标签`)
                .fontSize(9)
                .fontColor(COLOR_SUBTLE)
            }
            .width('100%')
            .height(18)

            Row({ space: 8 }) {
              TextInput({ text: this.styleTagDraft, placeholder: '输入一个特点，如「高对比」' })
                .layoutWeight(1)
                .height(40)
                .maxLength(STYLE_TAG_MAX)
                .fontSize(13)
                .fontColor(COLOR_INK)
                .placeholderColor(COLOR_SUBTLE)
                .backgroundColor(COLOR_FIELD)
                .borderRadius(10)
                .padding({ left: 12, right: 12 })
                .onChange((value: string) => {
                  this.styleTagDraft = value;
                })
                .onSubmit(() => {
                  this.addStyleTag();
                })

              Button('添加', { type: ButtonType.Normal, stateEffect: true })
                .height(40)
                .padding({ left: 16, right: 16 })
                .fontSize(12)
                .fontWeight(700)
                .fontColor(COLOR_WHITE)
                .backgroundColor(COLOR_BLUE)
                .borderRadius(10)
                .onClick(() => {
                  this.addStyleTag();
                })
            }
            .width('100%')
            .margin({ top: 6 })
            .alignItems(VerticalAlign.Center)

            if (this.styleTags.length > 0) {
              Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
                ForEach(this.styleTags, (tag: string) => {
                  Row({ space: 4 }) {
                    Text(tag)
                      .fontSize(11)
                      .fontColor(COLOR_BLUE)
                    Text('✕')
                      .fontSize(9)
                      .fontColor(COLOR_BLUE)
                      .opacity(0.75)
                  }
                  .padding({ left: 10, right: 8, top: 5, bottom: 5 })
                  .backgroundColor(COLOR_SOFT_BLUE)
                  .borderRadius(12)
                  .margin({ right: 6, bottom: 6 })
                  .accessibilityText(`删除标签 ${tag}`)
                  .onClick(() => {
                    this.removeStyleTag(tag);
                  })
                }, (tag: string) => `style-tag-${tag}`)
              }
              .width('100%')
              .margin({ top: 8 })
            } else {
              Text('还没有标签，输入后点「添加」')
                .fontSize(10)
                .fontColor(COLOR_SUBTLE)
                .margin({ top: 8 })
            }

            Row() {
              Text('展示为')
                .fontSize(9)
                .fontColor(COLOR_SUBTLE)
                .margin({ right: 6 })
              Text(this.styleNotePreview())
                .fontSize(10)
                .fontColor(COLOR_SECONDARY)
                .layoutWeight(1)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .margin({ top: 2 })
            .alignItems(VerticalAlign.Top)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          if (this.editingStyleId !== '') {
            Row() {
              Column({ space: 2 }) {
                Text('同时更新排版参数')
                  .fontSize(11)
                  .fontWeight(700)
                  .fontColor(COLOR_INK)
                Text('把当前画布的字号、颜色、间距写回这个风格')
                  .fontSize(9)
                  .fontColor(COLOR_SUBTLE)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Toggle({ type: ToggleType.Switch, isOn: this.editSyncRecipe })
                .selectedColor(COLOR_BLUE)
                .onChange((isOn: boolean) => {
                  this.editSyncRecipe = isOn;
                })
            }
            .width('100%')
            .padding(12)
            .backgroundColor(COLOR_FIELD)
            .borderRadius(12)
            .alignItems(VerticalAlign.Center)
          }
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)

      Row({ space: 12 }) {
        Button('取消', { type: ButtonType.Normal, stateEffect: true })
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .fontColor(COLOR_INK)
          .backgroundColor(COLOR_FIELD)
          .borderRadius(12)
          .onClick(() => {
            this.closeStyleSheet();
          })

        Button(this.editingStyleId === '' ? '保存到风格库' : '保存修改',
          { type: ButtonType.Normal, stateEffect: true })
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .fontWeight(600)
          .fontColor(COLOR_WHITE)
          .backgroundColor(COLOR_BLUE)
          .borderRadius(12)
          .onClick(() => {
            this.saveStyle();
          })
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 8, bottom: 18 })
  }

  @Builder
  ToolPanel() {
    Column() {
      if (!this.textFocused) {
        Column()
          .width(36)
          .height(4)
          .borderRadius(2)
          .backgroundColor('#E3E4DD')
          .margin({ top: 7, bottom: 3 })

        Row() {
          ForEach(EDITOR_TOOLS, (tool: ToolSpec) => {
          Column({ space: 2 }) {
            Stack() {
              this.ToolIcon(tool)
            }
            .width(30)
            .height(24)
            .borderRadius(8)
            .backgroundColor(this.activeTool === tool.id ? COLOR_SOFT_BLUE : Color.Transparent)

            Text(tool.label)
              .fontSize(10)
              .fontWeight(this.activeTool === tool.id ? 700 : 500)
              .fontColor(this.activeTool === tool.id ? COLOR_BLUE : COLOR_SUBTLE)
          }
          .layoutWeight(1)
          .height(44)
          .justifyContent(FlexAlign.Center)
          .accessibilityText(tool.label)
          .onClick(() => {
            this.activeTool = tool.id;
          })
          }, (tool: ToolSpec) => tool.id)
        }
        .width('100%')
        .padding({ left: 8, right: 8 })
      }

      Column() {
        if (this.activeTool === TOOL_TEXT) {
          this.TextToolBody()
        } else if (this.activeTool === TOOL_STYLE) {
          this.StyleToolBody()
        } else if (this.activeTool === TOOL_FONT) {
          this.FontToolBody()
        } else if (this.activeTool === TOOL_LAYOUT) {
          this.LayoutToolBody()
        } else {
          this.ColorToolBody()
        }
      }
      .width('100%')
      .height(PANEL_BODY_HEIGHT)
      .padding({ left: 18, right: 18, bottom: 6 })
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .backgroundColor(COLOR_WHITE)
    .borderRadius({ topLeft: 22, topRight: 22 })
    .shadow({ radius: 20, color: '#14000000', offsetX: 0, offsetY: -4 })
  }

  @Builder
  CreatePage() {
    Column() {
      this.EditorTopBar()
      this.CanvasStage()
      this.ToolPanel()
    }
    .width('100%')
    .height('100%')
  }

  onBackPress(): boolean {
    if (this.currentPage !== PageKind.Explore) {
      this.switchPage(PageKind.Explore);
      return true;
    }
    return false;
  }

  build() {
    Column() {
      Stack() {
        if (this.currentPage === PageKind.Explore) {
          this.ExplorePage()
        } else if (this.currentPage === PageKind.Create) {
          this.CreatePage()
        } else {
          this.GalleryPage()
        }
      }
      .width('100%')
      .layoutWeight(1)
      .clip(true)
      .bindSheet(this.showStyleSheet, this.StyleFormSheet(), {
        height: STYLE_SHEET_HEIGHT,
        dragBar: true,
        showClose: false,
        backgroundColor: COLOR_WHITE,
        keyboardAvoidMode: SheetKeyboardAvoidMode.RESIZE_ONLY,
        onDisappear: () => {
          this.closeStyleSheet();
        }
      })

      if (!this.textFocused) {
        this.BottomNav()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_PAPER)
    .bindSheet(this.showColorPicker, this.ColorPickerSheet(), {
      height: SHEET_HEIGHT,
      dragBar: true,
      showClose: false,
      backgroundColor: COLOR_WHITE,
      keyboardAvoidMode: SheetKeyboardAvoidMode.RESIZE_ONLY,
      onDisappear: () => {
        this.showColorPicker = false;
        this.rememberColor(this.pickerColor());
        this.syncPickerHsv();
        this.hexDraft = this.pickerColor();
      }
    })
  }
}
