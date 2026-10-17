import { Context } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { RawWork, WorkData, workFromRaw } from '../model/Typography';

const GALLERY_FILE_NAME: string = 'font_playground_gallery.json';

export class GalleryStore {
  private filePath: string;

  constructor(context: Context) {
    this.filePath = `${context.filesDir}/${GALLERY_FILE_NAME}`;
  }

  load(): WorkData[] {
    const works: WorkData[] = [];
    try {
      if (!fileIo.accessSync(this.filePath)) {
        return works;
      }
      const content = fileIo.readTextSync(this.filePath);
      const rawList = JSON.parse(content) as RawWork[];
      for (let i = 0; i < rawList.length; i++) {
        const raw = rawList[i];
        if (raw !== null && raw !== undefined && raw.id !== undefined) {
          works.push(workFromRaw(raw));
        }
      }
    } catch (error) {
      console.error(`FontPlayground gallery load failed: ${JSON.stringify(error)}`);
      return [];
    }
    return works;
  }

  save(works: WorkData[]): boolean {
    try {
      const file = fileIo.openSync(this.filePath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, JSON.stringify(works));
      fileIo.closeSync(file);
      return true;
    } catch (error) {
      console.error(`FontPlayground gallery save failed: ${JSON.stringify(error)}`);
      return false;
    }
  }
}
