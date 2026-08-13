import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { notificationManager } from '@kit.NotificationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'TaildriveNotifications';
const PROGRESS_NOTIFICATION_ID: number = 430001;
const COMPLETION_NOTIFICATION_ID: number = 430002;

export interface TaildriveNotificationTransfer {
  direction: string;
  fileName: string;
  bytes: number;
  totalBytes: number;
}

let notificationEnabled: boolean = false;

export async function publishTaildriveProgress(context: common.Context,
  transfer: TaildriveNotificationTransfer): Promise<void> {
  if (!await canPublish()) {
    return;
  }
  const progress: number | undefined = progressPercent(transfer);
  const uploading: boolean = transfer.direction === 'upload';
  const title: string = stringResource(context,
    uploading ? 'notification_taildrive_uploading_title' : 'notification_taildrive_downloading_title',
    uploading ? 'Uploading remote file' : 'Downloading remote file');
  const request: notificationManager.NotificationRequest = {
    id: PROGRESS_NOTIFICATION_ID,
    notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
    isOngoing: true,
    isAlertOnce: true,
    content: {
      notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
      normal: {
        title: title,
        text: transfer.fileName,
        additionalText: progress === undefined ? '' : `${progress}%`
      }
    }
  };
  try {
    if (progress !== undefined && await notificationManager.isSupportTemplate('downloadTemplate')) {
      request.template = {
        name: 'downloadTemplate',
        data: { title: title, fileName: transfer.fileName, progressValue: progress }
      };
    }
    await notificationManager.publish(request);
  } catch (error) {
    logPublishError('progress', error as BusinessError);
  }
}

export async function clearTaildriveProgress(): Promise<void> {
  try {
    await notificationManager.cancel(PROGRESS_NOTIFICATION_ID);
  } catch (_error) {
    // The system may already have dismissed the notification.
  }
}

export async function publishTaildriveCompletion(context: common.Context, fileName: string,
  succeeded: boolean): Promise<void> {
  if (!await canPublish()) {
    return;
  }
  try {
    await notificationManager.publish({
      id: COMPLETION_NOTIFICATION_ID,
      notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
      isAlertOnce: false,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: stringResource(context,
            succeeded ? 'notification_taildrive_completed_title' : 'notification_taildrive_failed_title',
            succeeded ? 'Remote file transfer completed' : 'Remote file transfer failed'),
          text: fileName
        }
      }
    });
  } catch (error) {
    logPublishError('completion', error as BusinessError);
  }
}

async function canPublish(): Promise<boolean> {
  if (notificationEnabled) {
    return true;
  }
  try {
    notificationEnabled = await notificationManager.isNotificationEnabled();
  } catch (error) {
    logPublishError('authorization', error as BusinessError);
    return false;
  }
  return notificationEnabled;
}

function progressPercent(transfer: TaildriveNotificationTransfer): number | undefined {
  if (transfer.totalBytes <= 0) {
    return undefined;
  }
  return Math.max(0, Math.min(100, Math.round(transfer.bytes * 100 / transfer.totalBytes)));
}

function stringResource(context: common.Context, name: string, fallback: string): string {
  try {
    return context.resourceManager.getStringByNameSync(name);
  } catch (_error) {
    return fallback;
  }
}

function logPublishError(operation: string, error: BusinessError): void {
  hilog.warn(DOMAIN, TAG, 'Taildrive notification %{public}s failed. code=%{public}d',
    operation, error.code ?? -1);
}
