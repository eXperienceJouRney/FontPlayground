import { Context } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { RawStyle, SavedStyle, styleFromRaw } from '../model/Typography';

const STYLE_FILE_NAME: string = 'font_playground_styles.json';

export class StyleStore {
  private filePath: string;

  constructor(context: Context) {
    this.filePath = `${context.filesDir}/${STYLE_FILE_NAME}`;
  }

  load(): SavedStyle[] {
    const styles: SavedStyle[] = [];
    try {
      if (!fileIo.accessSync(this.filePath)) {
        return styles;
      }
      const content = fileIo.readTextSync(this.filePath);
      const rawList = JSON.parse(content) as RawStyle[];
      for (let i = 0; i < rawList.length; i++) {
        const raw = rawList[i];
        if (raw !== null && raw !== undefined && raw.id !== undefined) {
          styles.push(styleFromRaw(raw));
        }
      }
    } catch (error) {
      console.error(`FontPlayground style load failed: ${JSON.stringify(error)}`);
      return [];
    }
    return styles;
  }

  save(styles: SavedStyle[]): boolean {
    try {
      const file = fileIo.openSync(this.filePath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, JSON.stringify(styles));
      fileIo.closeSync(file);
      return true;
    } catch (error) {
      console.error(`FontPlayground style save failed: ${JSON.stringify(error)}`);
      return false;
    }
  }
}
