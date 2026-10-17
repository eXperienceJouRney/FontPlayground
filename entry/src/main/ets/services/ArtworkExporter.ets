import { Context } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';

export class ExportResult {
  success: boolean;
  canceled: boolean;

  constructor(success: boolean, canceled: boolean) {
    this.success = success;
    this.canceled = canceled;
  }
}

function safeExportTitle(title: string): string {
  const cleaned = title.replace(/[\\/:*?"<>|]/g, ' ').replace(/\s+/g, ' ').trim();
  if (cleaned.length === 0) {
    return 'font-playground';
  }
  return cleaned.slice(0, 32);
}

export class ArtworkExporter {
  static async saveToAlbum(context: Context, pixelMap: image.PixelMap, title: string): Promise<ExportResult> {
    let tempPath = '';
    let packer: image.ImagePacker | undefined = undefined;
    try {
      packer = image.createImagePacker();
      const buffer = await packer.packToData(pixelMap, { format: 'image/png', quality: 100 });
      tempPath = `${context.cacheDir}/font-playground-${Date.now()}.png`;
      const tempFile = fileIo.openSync(tempPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(tempFile.fd, buffer);
      fileIo.closeSync(tempFile);

      const helper = photoAccessHelper.getPhotoAccessHelper(context);
      const configs: photoAccessHelper.PhotoCreationConfig[] = [
        {
          title: safeExportTitle(title),
          fileNameExtension: 'png',
          photoType: photoAccessHelper.PhotoType.IMAGE
        }
      ];
      const destinationUris = await helper.showAssetsCreationDialog(
        [fileUri.getUriFromPath(tempPath)], configs);
      if (destinationUris.length === 0) {
        return new ExportResult(false, true);
      }
      const destination = fileIo.openSync(destinationUris[0],
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(destination.fd, buffer);
      fileIo.closeSync(destination);
      return new ExportResult(true, false);
    } catch (error) {
      console.error(`FontPlayground export failed: ${JSON.stringify(error)}`);
      return new ExportResult(false, false);
    } finally {
      if (packer !== undefined) {
        try {
          await packer.release();
        } catch (error) {
          console.error(`FontPlayground packer release failed: ${JSON.stringify(error)}`);
        }
      }
      if (tempPath.length > 0) {
        try {
          fileIo.unlinkSync(tempPath);
        } catch (error) {
          console.error(`FontPlayground temp cleanup failed: ${JSON.stringify(error)}`);
        }
      }
    }
  }
}
