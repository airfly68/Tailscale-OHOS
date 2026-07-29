import nativeBridge from 'libtailscale_ohos.so';
import appProcess from '@ohos.process';
import { bundleManager, common, Want } from '@kit.AbilityKit';
import { vpnExtension } from '@kit.NetworkKit';
import { BusinessError, deviceInfo, pasteboard } from '@kit.BasicServicesKit';
import { fileIo, fileUri, picker } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { LengthMetrics } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { DiagnosticEventStore } from '../services/DiagnosticEventStore';
import {
  DiagnosticReportInput,
  DiagnosticReportResult,
  DiagnosticReportService
} from '../services/DiagnosticReportService';
import { DeviceNameService } from '../services/DeviceNameService';
import { APP_FOREGROUND_EVENT } from '../services/AppLifecycleEvents';
import { SunshineProbeService } from '../services/SunshineProbeService';
import { PeerPathService } from '../services/PeerPathService';
import { MoonlightLauncher } from '../services/MoonlightLauncher';
import { buildStreamProfile } from '../services/StreamProfileBuilder';
import { PeerPathResult, StreamLaunchProfile, SunshineProbeResult } from '../services/StreamingModels';
import { HosPlayerLauncher } from '../services/HosPlayerLauncher';
import {
  DiscoveredMediaService,
  HosPlayerLaunchRequest,
  MediaProbeResult
} from '../services/MediaIntegrationModels';
import { MediaServiceProbeService } from '../services/MediaServiceProbeService';
import { SunshineStatusBadge } from './SunshineStatusBadge';
import { MediaStatusBadge } from './MediaStatusBadge';
import { DeviceConnectionInfoPanel } from './DeviceConnectionInfoPanel';
import { DeviceActionButtons } from './DeviceActionButtons';
import { CompactConnectedHomeHeader } from './CompactConnectedHomeHeader';
import { ConnectionDetailsSheet } from './ConnectionDetailsSheet';
import { HomeConnectionSection } from './HomeConnectionSection';
import { LegacyConnectedHomeHeader } from './LegacyConnectedHomeHeader';
import { ConnectedHomeLayoutMode, DEFAULT_CONNECTED_HOME_LAYOUT } from './HomeLayoutConfig';
import { HomeLayoutPreferences } from './HomeLayoutPreferences';
import {
  BlurStrategy,
  DividerMode,
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
  ScrollEffectType,
  hdsEffect,
  hdsMaterial
} from '@kit.UIDesignKit';
import {
  ControlServerConfig,
  ControlServerSettings,
  DEFAULT_CONTROL_SERVER_URL
} from '../services/ControlServerConfig';

const MIN_CONNECTION_LOADING_MS: number = 250;
const CONNECTION_START_FRAME_DELAY_MS: number = 32;
const CONNECTION_POLL_INTERVAL_MS: number = 250;
const BACKEND_READINESS_POLL_INTERVAL_MS: number = 250;
const CACHE_SIZE_POLL_INTERVAL_MS: number = 500;
const VPN_HEARTBEAT_FRESH_MS: number = 5000;
const VPN_HEARTBEAT_CONFIRM_TIMEOUT_MS: number = 2500;
const VPN_CONNECTED_GRACE_MS: number = 8000;
const FILE_WATCH_CLOSE_WRITE: number = 0x8;
const FAST_RECONNECT_TTL_MS: number = 15000;
const VPN_STOP_POLL_INTERVAL_MS: number = 50;
const VPN_STOP_POLL_MAX_ATTEMPTS: number = 150;
const VPN_REPLACE_APPROVAL_FILE_NAME: string = 'vpn-replace-approved';
const PEER_CONNECTIVITY_REQUEST_FILE_NAME: string = 'peer-connectivity-request.json';
const PEER_CONNECTIVITY_RESPONSE_FILE_NAME: string = 'peer-connectivity-response.json';
const TAILDROP_OUTBOX_DIR_NAME: string = 'taildrop-outbox';
const TAILDROP_SEND_REQUEST_FILE_NAME: string = 'taildrop-send-request.json';
const TAILDROP_TARGETS_FILE_NAME: string = 'taildrop-targets.json';
const TAILDROP_CANCEL_REQUEST_FILE_NAME: string = 'taildrop-cancel-request.json';
const TAILDROP_INBOX_DIR_NAME: string = 'taildrop-inbox-export';
const TAILDROP_RECEIVE_REQUEST_FILE_NAME: string = 'taildrop-receive-request.json';
const TAILDROP_RECEIVE_RESPONSE_FILE_NAME: string = 'taildrop-receive-response.json';
const TAILDROP_HISTORY_FILE_NAME: string = 'taildrop-history.json';
const TAILDROP_INBOX_SNAPSHOT_FILE_NAME: string = 'taildrop-inbox-snapshot.json';
const TAILDROP_HISTORY_MEDIA_DIR_NAME: string = 'taildrop-history-media';
const TAILDROP_THUMBNAIL_EDGE_PX: number = 128;
const TAILDROP_THUMBNAIL_JPEG_QUALITY: number = 72;
const TAILDROP_HISTORY_LIMIT: number = 10;
const TAILDROP_MAX_FILE_SELECTION: number = 10;
const TAILDROP_MAX_MEDIA_SELECTION: number = 100;
const TAILDROP_RECEIVE_BACKEND_TIMEOUT_MS: number = 45000;
const TAILDROP_SAVE_TIMEOUT_MS: number = 60000;
const TAILDROP_TEXT_CLIPBOARD_MAX_BYTES: number = 1024 * 1024;
const TAILDROP_IMAGE_EXTENSIONS: string[] = [
  'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif', 'dng'
];
const TAILDROP_VIDEO_EXTENSIONS: string[] = [
  'mp4', 'mov', 'm4v', '3gp', '3g2', 'mkv', 'webm'
];
const TAILDROP_TEXT_EXTENSIONS: string[] = [
  'txt', 'md', 'markdown', 'csv', 'tsv', 'json', 'json5', 'xml', 'yaml', 'yml', 'log',
  'ini', 'conf', 'cfg', 'properties', 'env', 'sql', 'sh', 'ps1', 'bat', 'cmd', 'py',
  'js', 'ts', 'ets', 'css', 'html', 'htm', 'java', 'kt', 'go', 'rs', 'c', 'cc', 'cpp',
  'h', 'hpp'
];
const VPN_PEERS_FILE_NAME: string = 'vpn-peers.json';
const VPN_STOP_REQUEST_FILE_NAME: string = 'vpn-stop-request.json';
const VPN_STOP_RESPONSE_FILE_NAME: string = 'vpn-stop-response.json';
const VPN_CONNECT_CONFIG_FILE_NAME: string = 'vpn-connect-config.json';
const WELCOME_ACKNOWLEDGED_FILE_NAME: string = 'welcome-acknowledged';
const FEEDBACK_EMAIL: string = 'zzx15821178583@gmail.com';

interface ExitNodeChoice {
  id: string;
  name: string;
  online: boolean;
  selected: boolean;
}

interface PeerSummary {
  key: string;
  name: string;
  os: string;
  osVersion?: string;
  deviceModel: string;
  deviceType: string;
  addresses: string[];
  online: boolean;
  exitNode: boolean;
  keyExpired: boolean;
  keyExpiryUnixMs: number;
}

interface NetworkSettings {
  routeAll: boolean;
  exitNodeAllowLANAccess: boolean;
}

interface TrafficSample {
  downloadBytesPerSecond: number;
  uploadBytesPerSecond: number;
}

interface PeerConnectivityRequest {
  requestId: number;
  peerKey: string;
}

interface PeerConnectivityResponse {
  requestId: number;
  result: string;
}

interface PeerConnectivityResult {
  state: string;
  reason: string;
  sent: number;
  received: number;
  lossPercent: number;
  minLatencyMs: number;
  avgLatencyMs: number;
  maxLatencyMs: number;
}

interface DeviceStreamingState {
  peerKey: string;
  sunshine: SunshineProbeResult;
  path: PeerPathResult;
  checking: boolean;
  launching: boolean;
}

interface DeviceMediaState {
  peerKey: string;
  result: MediaProbeResult;
  checking: boolean;
  launching: boolean;
}

interface MediaProbeSelfTestResult {
  state: string;
  cases: number;
  errorMessage?: string;
}

interface AccountSummary {
  displayName: string;
  loginName: string;
  profilePicURL: string;
  tailnetName: string;
  deviceName: string;
  addresses: string[];
  needsApproval: boolean;
  keyExpired: boolean;
  keyExpiryUnixMs: number;
}

interface TaildropTargetSummary {
  key: string;
  name: string;
  os: string;
  deviceModel: string;
  deviceType: string;
  online: boolean;
}

interface TaildropSnapshot {
  state: string;
  reason: string;
  targets: TaildropTargetSummary[];
  waitingFiles: TaildropWaitingFileSummary[];
  inboxReason: string;
  transfer: TaildropTransferSummary;
  updatedAtMs: number;
}

interface TaildropWaitingFileSummary {
  name: string;
  size: number;
}

interface TaildropTransferSummary {
  requestId: number;
  state: string;
  reason: string;
  targetKey: string;
  targetName: string;
  fileName: string;
  fileIndex: number;
  fileCount: number;
  fileBytes: number;
  fileSize: number;
  bytesSent: number;
  totalBytes: number;
  previewPath: string;
  completedAtMs: number;
}

interface TaildropSendFile {
  path: string;
  name: string;
  size: number;
  previewPath: string;
}

interface TaildropSendRequest {
  requestId: number;
  targetKey: string;
  outboxRoot: string;
  files: TaildropSendFile[];
}

interface TaildropCancelRequest {
  requestId: number;
}

interface TaildropReceiveRequest {
  requestId: number;
  action: string;
  name: string;
  inboxRoot: string;
  path: string;
}

interface TaildropReceiveResult {
  requestId: number;
  action: string;
  state: string;
  reason: string;
  name: string;
  size: number;
  path: string;
}

interface TaildropMediaPreview {
  requestId: number;
  name: string;
  size: number;
  path: string;
  thumbnailPath: string;
  mediaType: photoAccessHelper.PhotoType;
}

interface TaildropCachedFile {
  requestId: number;
  name: string;
  size: number;
  path: string;
}

interface TaildropTransferRecord {
  requestId: number;
  direction: string;
  state: string;
  reason: string;
  targetKey: string;
  targetName: string;
  fileName: string;
  fileCount: number;
  totalBytes: number;
  previewPath: string;
  completedAtMs: number;
}

interface PersistedTaildropHistory {
  records: TaildropTransferRecord[];
}

interface PersistedTaildropInbox {
  files: TaildropWaitingFileSummary[];
  inboxReason: string;
  mediaPreviews?: TaildropMediaPreview[];
  cachedFiles?: TaildropCachedFile[];
}

interface PersistedPeerSnapshot {
  peers: PeerSummary[];
  updatedAtMs: number;
}

interface VpnStopRequest {
  requestId: number;
}

interface VpnStopResponse {
  requestId: number;
  status: string;
}

interface VpnConnectConfigHandoff {
  createdAtMs: number;
  config: string;
}

interface ControlServerTipStateChange {
  isVisible: boolean;
}

interface BackendSnapshot {
  status: string;
  exitNodes: ExitNodeChoice[];
  peers: PeerSummary[];
  networkSettings: NetworkSettings;
  account: AccountSummary;
  taildrop: TaildropSnapshot;
}

function emptyTaildropTransfer(): TaildropTransferSummary {
  return {
    requestId: 0, state: 'idle', reason: '', targetKey: '', targetName: '', fileName: '',
    fileIndex: 0, fileCount: 0, fileBytes: 0, fileSize: 0, bytesSent: 0, totalBytes: 0,
    previewPath: '', completedAtMs: 0
  };
}

function emptyTaildropReceive(): TaildropReceiveResult {
  return {
    requestId: 0, action: '', state: 'idle', reason: '', name: '', size: 0, path: ''
  };
}

class PeerDataSource implements IDataSource {
  private data: PeerSummary[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.data.length;
  }

  getData(index: number): PeerSummary {
    return this.data[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (!this.listeners.includes(listener)) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  replaceAll(peers: PeerSummary[]): void {
    this.data = [...peers];
    this.listeners.forEach((listener: DataChangeListener) => listener.onDataReloaded());
  }
}

@Component
export struct BridgeStatus {
  @State nativeStatus: string = 'Go Bridge Pending';
  @State engineStatus: string = 'Tailscale Engine Pending';
  @State backendStatus: string = 'Tailscale Backend Stopped';
  @State loginHandoffStatus: string = 'Secure Login Pending';
  @State controlProbeStatus: string = 'Control TLS Probe Pending';
  @State vpnStatus: string = 'HarmonyOS VPN Extension Stopped';
  @State exitNodes: ExitNodeChoice[] = [];
  @State peers: PeerSummary[] = [];
  @State networkSettings: NetworkSettings = {
    routeAll: true,
    exitNodeAllowLANAccess: false
  };
  @State networkSettingStatus: string = '';
  @State accountSummary: AccountSummary = {
    displayName: '',
    loginName: '',
    profilePicURL: '',
    tailnetName: '',
    deviceName: '',
    addresses: [],
    needsApproval: false,
    keyExpired: false,
    keyExpiryUnixMs: 0
  };
  @State avatarLoadFailed: boolean = false;
  @State appVersion: string = '0.9.1';
  @State tailscaleVersion: string = '—';
  @State exitNodeStatus: string = '未使用出口节点';
  @State logoutStatus: string = '';
  @State diagnosticsUnlocked: boolean = false;
  @State diagnosticsExpanded: boolean = false;
  @State diagnosticReportStatus: string = '';
  @State diagnosticReportInProgress: boolean = false;
  @State trafficDownloadBytes: number = 0;
  @State trafficUploadBytes: number = 0;
  @State trafficDownloadRate: number = 0;
  @State trafficUploadRate: number = 0;
  @State trafficSamples: TrafficSample[] = [];
  @State peerConnectivityKey: string = '';
  @State peerConnectivityInProgress: boolean = false;
  @State peerConnectivityResult: PeerConnectivityResult = {
    state: '', reason: '', sent: 0, received: 0, lossPercent: 0,
    minLatencyMs: 0, avgLatencyMs: 0, maxLatencyMs: 0
  };
  @State streamingStates: DeviceStreamingState[] = [];
  @State mediaStates: DeviceMediaState[] = [];
  @State mediaSelfTestStatus: string = '';
  @State mediaSelfTestInProgress: boolean = false;
  @State fakeMediaServiceOnline: boolean = false;
  @State taildropState: string = 'disconnected';
  @State taildropReason: string = '';
  @State taildropTargets: TaildropTargetSummary[] = [];
  @State taildropWaitingFiles: TaildropWaitingFileSummary[] = [];
  @State taildropInboxReason: string = '';
  @State taildropTransfer: TaildropTransferSummary = emptyTaildropTransfer();
  @State taildropReceive: TaildropReceiveResult = emptyTaildropReceive();
  @State taildropMediaPreviews: TaildropMediaPreview[] = [];
  @State taildropCachedFiles: TaildropCachedFile[] = [];
  @State taildropHistory: TaildropTransferRecord[] = [];
  @State taildropPreparing: boolean = false;
  @State taildropReceiveInProgress: boolean = false;
  @State taildropReceiveRouting: boolean = false;
  @State taildropMediaSaveInProgress: boolean = false;
  @State @Watch('onTaildropTextEditorVisibilityChanged') taildropTextEditorVisible: boolean = false;
  @State taildropTextPreviewVisible: boolean = false;
  @State taildropTextInput: string = '';
  @State taildropReceivedText: string = '';
  @State taildropTransferRate: number = 0;
  @State taildropTransferEtaSeconds: number = 0;
  @State taildropCancelPending: boolean = false;
  @State loginInProgress: boolean = false;
  @State connectInProgress: boolean = false;
  @State disconnectInProgress: boolean = false;
  @State backendReady: boolean = false;
  @State backendInitializationVisible: boolean = false;
  @State devicesLoading: boolean = true;
  @State hasAuthenticatedSession: boolean = false;
  @State currentTab: number = 0;
  @State activeTab: number = 0;
  @State controlServerURL: string = DEFAULT_CONTROL_SERVER_URL;
  @State controlServerInput: string = DEFAULT_CONTROL_SERVER_URL;
  @State controlServerConfirmed: boolean = false;
  @State controlServerStatus: string = '';
  @State controlServerEditorVisible: boolean = true;
  @State controlServerTipVisible: boolean = false;
  @State controlServerTipMessage: string = '';
  @State diagnosticActionStatus: string = '';
  @State diagnosticActionInProgress: boolean = false;
  @State glowLevel: number = 3;
  @State connectedHomeLayoutMode: ConnectedHomeLayoutMode = DEFAULT_CONNECTED_HOME_LAYOUT;
  @State cacheSizeBytes: number = 0;
  @State cacheSizeLoading: boolean = true;
  @State cacheClearInProgress: boolean = false;
  @State connectionDetailsVisible: boolean = false;
  @State homeTitleCompact: boolean = false;
  @State layoutWidth: number = 360;
  @State expandedPeerKeys: string[] = [];
  private connectionPollTimer: number = -1;
  private connectionStatusWatcher?: fileIo.Watcher;
  private connectionCompletionTimer: number = -1;
  private connectionStartedAtMs: number = 0;
  private backendReadinessPollTimer: number = -1;
  private backendRestartDeferred: boolean = false;
  private cachedVpnConnectConfig: string = '';
  private cachedVpnConnectConfigAtMs: number = 0;
  private healthPollTimer: number = -1;
  private loginPollTimer: number = -1;
  private transferScroller: Scroller = new Scroller();
  private settingsScroller: Scroller = new Scroller();
  private tabsController: HdsTabsController = new HdsTabsController();
  private diagnosticsTapCount: number = 0;
  private diagnosticsLastTapMs: number = 0;
  private lifecycleTimers: number[] = [];
  private lifecycleGeneration: number = 0;
  private cacheRefreshScheduled: boolean = false;
  private cacheSizeRefreshInFlight: boolean = false;
  private cacheSizeRefreshTimer: number = -1;
  private cacheSizePollTimer: number = -1;
  private cacheClearRequestedFromSettings: boolean = false;
  private refreshInFlight: boolean = false;
  private vpnConflictDialogVisible: boolean = false;
  private welcomeDialogVisible: boolean = false;
  private trafficSession: number = 0;
  private trafficLastHeartbeatMs: number = 0;
  private trafficLastDownloadBytes: number = 0;
  private trafficLastUploadBytes: number = 0;
  private lastConfirmedVpnStatus: string = '';
  private lastConfirmedVpnHeartbeatMs: number = 0;
  private vpnStatusGraceActive: boolean = false;
  private vpnHeartbeatObservationStartedAtMs: number = 0;
  private vpnHeartbeatBaselineMs: number = 0;
  private vpnHeartbeatConfirmed: boolean = false;
  private peerConnectivityPollTimer: number = -1;
  private peerConnectivityRequestId: number = 0;
  private vpnStopPollTimer: number = -1;
  private vpnStopRequestId: number = 0;
  private peerSnapshotSignature: string = '';
  private lastHandledTaildropRequestId: number = 0;
  private taildropRequestSubmittedAtMs: number = 0;
  private taildropProgressSampleRequestId: number = 0;
  private taildropProgressSampleBytes: number = 0;
  private taildropProgressSampleMs: number = 0;
  private taildropReceiveResponseInFlight: boolean = false;
  private taildropReceiveStateStartedAtMs: number = 0;
  private taildropReceiveDestinationUri: string = '';
  private taildropReceiveExpectedSize: number = 0;
  private taildropReceiveMediaType?: photoAccessHelper.PhotoType;
  private taildropReceivePreviewPath: string = '';
  private taildropReceiveStrategy: string = 'none';
  private taildropAutoPrefetchKey: string = '';
  private taildropAutoPrefetchFailedKeys: string[] = [];
  private taildropPendingTextPreview?: TaildropWaitingFileSummary;
  private taildropPendingMediaSave?: TaildropWaitingFileSummary;
  private taildropPickerOpen: boolean = false;
  private taildropTextTarget?: TaildropTargetSummary;
  private peerDataSource: PeerDataSource = new PeerDataSource();
  private sunshineProbeService?: SunshineProbeService;
  private peerPathService?: PeerPathService;
  private moonlightLauncher?: MoonlightLauncher;
  private mediaServiceProbeService?: MediaServiceProbeService;
  private hosPlayerLauncher?: HosPlayerLauncher;
  private streamingRequestIds: Map<string, number> = new Map();
  private mediaRequestIds: Map<string, number> = new Map();
  private autoProbedPeerSessions: Map<string, number> = new Map();
  private appForegroundListener: () => void = () => this.handleAppForeground();

  private applyPeers(peers: PeerSummary[]): void {
    this.peers = peers;
    this.peerDataSource.replaceAll(peers);
    const onlineKeys: string[] = peers.filter((peer: PeerSummary) => peer.online)
      .map((peer: PeerSummary) => peer.key);
    this.expandedPeerKeys = this.expandedPeerKeys.filter((key: string) => onlineKeys.includes(key));
    this.streamingStates = this.streamingStates.filter((state: DeviceStreamingState) => {
      const peer: PeerSummary | undefined = peers.find((item: PeerSummary) => item.key === state.peerKey);
      if (peer === undefined || !peer.online) {
        this.sunshineProbeService?.cancel(state.peerKey);
        this.peerPathService?.cancel(state.peerKey);
        return false;
      }
      return true;
    });
    this.mediaStates = this.mediaStates.filter((state: DeviceMediaState) => {
      const peer: PeerSummary | undefined = peers.find((item: PeerSummary) => item.key === state.peerKey);
      if (peer === undefined || !peer.online) {
        this.mediaServiceProbeService?.cancel(state.peerKey);
        return false;
      }
      return true;
    });
    if (this.isConnected()) {
      this.scheduleLifecycleTask(() => this.autoProbeConnectedPeerServices(), 50);
    }
  }

  aboutToAppear(): void {
    this.lifecycleGeneration++;
    this.lastConfirmedVpnStatus = '';
    this.lastConfirmedVpnHeartbeatMs = 0;
    this.vpnStatusGraceActive = false;
    this.vpnHeartbeatObservationStartedAtMs = Date.now();
    this.vpnHeartbeatBaselineMs = 0;
    this.vpnHeartbeatConfirmed = false;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.eventHub.on(APP_FOREGROUND_EVENT, this.appForegroundListener);
    this.loadGlowLevel();
    this.fakeMediaServiceOnline = false;
    this.loadConnectedHomeLayoutPreference(context);
    this.refreshCacheSize();
    this.resetDiagnosticsMode();
    this.backendReady = false;
    this.devicesLoading = true;
    this.verifyNativeBridge();
    this.loadAppVersion();
    this.loadTaildropHistory();
    this.loadPersistedTaildropInbox();
    this.loadControlServerSettings();
    this.scheduleLifecycleTask(() => this.showWelcomeDialogIfNeeded(), 350);
    this.recordDiagnosticEvent('ui_opened', 'lifecycle');
    const vpnIsLive: boolean = this.refreshVpnProbeStatus();
    if (!this.controlServerConfirmed) {
      this.backendStatus = 'Tailscale Backend Stopped | control server not configured';
      this.backendReady = true;
      this.backendInitializationVisible = false;
      this.devicesLoading = false;
      if (vpnIsLive) {
        vpnExtension.stopVpnExtensionAbility(this.vpnWant()).catch(() => {
          // The extension also refuses to restore its backend without a confirmed server.
        });
      }
      this.scheduleLifecycleTask(() => this.showControlServerTip(), 800);
    } else if (!vpnIsLive) {
      this.startBackend();
      this.scheduleLifecycleTask(() => this.refreshBackendStatus(), 1500);
    } else {
      this.backendReady = true;
      this.backendInitializationVisible = false;
      this.devicesLoading = false;
      this.hasAuthenticatedSession = true;
    }
    // Recheck after the heartbeat freshness window. This covers an extension
    // process that was killed just before the UI appeared (for example during
    // an application update) while its last heartbeat still looked current.
    this.scheduleLifecycleTask(() => {
      if (this.controlServerConfirmed && !this.refreshVpnProbeStatus()) {
        this.refreshOrRecoverBackend(this.lifecycleGeneration);
      }
    }, 6000);
    this.startHealthPolling();
  }

  aboutToDisappear(): void {
    this.lifecycleGeneration++;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.eventHub.off(APP_FOREGROUND_EVENT, this.appForegroundListener);
    this.vpnConflictDialogVisible = false;
    this.welcomeDialogVisible = false;
    this.controlServerTipVisible = false;
    this.stopConnectionPolling();
    this.clearConnectionCompletionTimer();
    this.stopBackendReadinessPolling();
    this.stopHealthPolling();
    this.stopLoginPolling();
    this.stopPeerConnectivityPolling();
    this.stopCacheSizePolling();
    this.streamingStates.forEach((state: DeviceStreamingState) => {
      this.sunshineProbeService?.cancel(state.peerKey);
      this.peerPathService?.cancel(state.peerKey);
    });
    this.mediaStates.forEach((state: DeviceMediaState) => {
      this.mediaServiceProbeService?.cancel(state.peerKey);
    });
    this.stopVpnStopPolling();
    this.peerConnectivityInProgress = false;
    this.clearLifecycleTimers();
    this.resetDiagnosticsMode();
  }

  private handleAppForeground(): void {
    const generation: number = this.lifecycleGeneration;
    const vpnIsLive: boolean = this.refreshVpnProbeStatus();
    this.startHealthPolling();
    if (this.activeTab === 2) {
      this.startCacheSizePolling();
    }
    if (!this.controlServerConfirmed) {
      return;
    }
    if (!vpnIsLive) {
      this.refreshOrRecoverBackend(generation);
      return;
    }
    // The VPN Extension runs in a separate process and keeps writing peer
    // snapshots while the UI is suspended. Read once immediately on return,
    // then recheck after its next one-second snapshot so admin-console changes
    // are reflected without restarting the application.
    this.scheduleLifecycleTask(() => this.refreshVpnProbeStatus(), 1200);
  }

  private scheduleLifecycleTask(task: () => void, delayMs: number): number {
    const generation: number = this.lifecycleGeneration;
    const timer: number = setTimeout(() => {
      if (generation === this.lifecycleGeneration) {
        task();
      }
    }, delayMs);
    this.lifecycleTimers.push(timer);
    return timer;
  }

  private clearLifecycleTimers(): void {
    this.lifecycleTimers.forEach((timer: number) => clearTimeout(timer));
    this.lifecycleTimers = [];
  }

  private loadAppVersion(): void {
    bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
      .then((info: bundleManager.BundleInfo) => {
        this.appVersion = info.versionName;
      })
      .catch(() => {
        // Keep the packaged fallback when bundle metadata is temporarily unavailable.
      });
  }

  private loadControlServerSettings(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const settings: ControlServerSettings = ControlServerConfig.load(context.filesDir);
    this.controlServerURL = settings.controlURL;
    this.controlServerInput = settings.controlURL;
    this.controlServerConfirmed = settings.confirmed;
    this.controlServerEditorVisible = !settings.confirmed;
    this.controlServerTipMessage = context.resourceManager.getStringSync(
      $r('app.string.control_server_first_run_tip').id);
    this.controlServerStatus = '';
  }

  private welcomeAcknowledgedPath(): string {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return `${context.filesDir}/${WELCOME_ACKNOWLEDGED_FILE_NAME}`;
  }

  private showWelcomeDialogIfNeeded(): void {
    if (this.welcomeDialogVisible) {
      return;
    }
    const markerPath: string = this.welcomeAcknowledgedPath();
    try {
      if (fileIo.accessSync(markerPath)) {
        return;
      }
    } catch (_error) {
      // A missing marker means this is the first acknowledged launch.
    }
    this.welcomeDialogVisible = true;
    this.getUIContext().showAlertDialog({
      title: $r('app.string.welcome_dialog_title'),
      message: $r('app.string.welcome_dialog_message'),
      autoCancel: false,
      secondaryButton: {
        value: $r('app.string.welcome_dialog_action'),
        action: () => {
          this.writePrivateTextFile(markerPath, 'acknowledged');
          this.welcomeDialogVisible = false;
          this.recordDiagnosticEvent('welcome_dialog_acknowledged', 'first_run');
        }
      }
    });
    this.recordDiagnosticEvent('welcome_dialog_shown', 'first_run');
  }

  private openFeedbackEmail(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.openLink(`mailto:${FEEDBACK_EMAIL}`, { appLinkingOnly: false })
      .then(() => this.recordDiagnosticEvent('feedback_email_opened', 'about'))
      .catch(() => this.showToast($r('app.string.feedback_open_failed')));
  }

  private showControlServerTip(): void {
    if (this.controlServerConfirmed || this.controlServerTipVisible) {
      return;
    }
    this.controlServerTipVisible = true;
    this.recordDiagnosticEvent('control_server_tip_shown', 'first_run');
  }

  private openControlServerSettings(): void {
    this.controlServerTipVisible = false;
    this.navigateToTab(2);
    this.showToast($r('app.string.control_server_required_to_connect'));
  }

  private navigateToTab(index: number): void {
    this.activeTab = index;
    this.updateCacheSizePolling(index);
    if (this.currentTab === index) {
      return;
    }
    this.tabsController.changeIndex(index);
  }

  private toggleControlServerEditor(): void {
    const visible: boolean = !this.controlServerEditorVisible;
    this.getUIContext().animateTo({ duration: 320, curve: Curve.EaseInOut }, () => {
      this.controlServerEditorVisible = visible;
    });
    this.recordDiagnosticEvent(visible ? 'control_server_editor_opened' :
      'control_server_editor_closed', 'account');
  }

  private saveControlServer(): void {
    if (this.isConnected() || this.isConnecting()) {
      this.controlServerStatus = 'disconnect';
      this.recordDiagnosticEvent('control_server_confirm_blocked', 'connected');
      return;
    }
    const normalized: string = ControlServerConfig.normalize(this.controlServerInput);
    if (normalized.length === 0) {
      this.controlServerStatus = 'invalid';
      this.recordDiagnosticEvent('control_server_confirm_failed', 'invalid');
      return;
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const settings: ControlServerSettings | undefined =
      ControlServerConfig.save(context.filesDir, normalized);
    if (settings === undefined) {
      this.controlServerStatus = 'failed';
      this.recordDiagnosticEvent('control_server_confirm_failed', 'storage');
      return;
    }
    const changed: boolean = !this.controlServerConfirmed || this.controlServerURL !== settings.controlURL;
    this.controlServerURL = settings.controlURL;
    this.controlServerInput = settings.controlURL;
    this.controlServerConfirmed = true;
    this.controlServerStatus = 'saved';
    this.controlServerTipVisible = false;
    this.recordDiagnosticEvent('control_server_confirmed',
      settings.controlURL === DEFAULT_CONTROL_SERVER_URL ? 'official' : 'custom');
    this.getUIContext().animateTo({ duration: 320, curve: Curve.EaseInOut }, () => {
      this.controlServerEditorVisible = false;
    });
    if (changed) {
      this.backendReady = false;
      this.backendInitializationVisible = true;
      this.devicesLoading = true;
      nativeBridge.backendStopAsync()
        .catch(() => 'FAILED | backend stop')
        .finally(() => {
          this.startBackend();
          this.scheduleLifecycleTask(() => this.refreshBackendStatus(), 1500);
        });
    }
  }

  private controlServerStatusText(): ResourceStr {
    switch (this.controlServerStatus) {
      case 'saved':
        return $r('app.string.control_server_saved');
      case 'disconnect':
        return $r('app.string.control_server_disconnect_first');
      case 'failed':
        return $r('app.string.control_server_save_failed');
      default:
        return $r('app.string.control_server_invalid');
    }
  }

  private verifyNativeBridge(): void {
    try {
      this.nativeStatus = nativeBridge.hello();
      this.tailscaleVersion = nativeBridge.tailscaleVersion();
    } catch (error) {
      this.nativeStatus = `Go Bridge Failed: ${JSON.stringify(error)}`;
    }
  }

  private async probeUserspaceEngine(): Promise<void> {
    try {
      this.engineStatus = await nativeBridge.probeEngineAsync();
    } catch (error) {
      this.engineStatus = `Tailscale Engine Failed: ${JSON.stringify(error)}`;
    }
  }

  private startBackend(showInitialization: boolean = true): void {
    this.backendRestartDeferred = false;
    if (!this.controlServerConfirmed) {
      this.backendStatus = 'Tailscale Backend Stopped | control server not configured';
      this.backendReady = true;
      this.backendInitializationVisible = false;
      this.devicesLoading = false;
      return;
    }
    this.peerSnapshotSignature = '';
    this.backendReady = false;
    this.backendInitializationVisible = showInitialization;
    this.devicesLoading = true;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.recordDiagnosticEvent('backend_start_requested', showInitialization ? 'visible' : 'silent');
      this.backendStatus = nativeBridge.backendStart(
        `${context.filesDir}/tailscale`, this.deviceModel(), this.harmonyOSVersion(), this.controlServerURL);
      this.startBackendReadinessPolling();
    } catch (error) {
      this.recordDiagnosticEvent('backend_start_failed', 'start');
      this.backendStatus = `Tailscale Backend Failed: ${JSON.stringify(error)}`;
      this.backendReady = true;
      this.backendInitializationVisible = false;
      this.devicesLoading = false;
    }
  }

  private deviceModel(): string {
    return DeviceNameService.model();
  }

  private harmonyOSVersion(): string {
    const displayVersion: string = deviceInfo.displayVersion.trim();
    const versionMatch: RegExpMatchArray | null = displayVersion.match(/(\d+)\.(\d+)/);
    if (versionMatch !== null) {
      return `${versionMatch[1]}.${versionMatch[2]}`;
    }
    if (deviceInfo.majorVersion > 0) {
      return `${deviceInfo.majorVersion}.${Math.max(0, deviceInfo.seniorVersion)}`;
    }
    return displayVersion.length > 0 ? displayVersion : '—';
  }

  private async refreshBackendStatus(): Promise<void> {
    if (!this.controlServerConfirmed) {
      this.backendStatus = 'Tailscale Backend Stopped | control server not configured';
      this.backendReady = true;
      this.backendInitializationVisible = false;
      this.devicesLoading = false;
      return;
    }
    if (this.refreshInFlight) {
      return;
    }
    const generation: number = this.lifecycleGeneration;
    this.refreshInFlight = true;
    try {
      const snapshotText: string = await nativeBridge.backendSnapshot();
      if (generation !== this.lifecycleGeneration) {
        return;
      }
      const snapshot: BackendSnapshot = JSON.parse(snapshotText) as BackendSnapshot;
      this.backendStatus = snapshot.status;
      if (this.backendStatus.includes('state=Running')) {
        this.backendReady = true;
        this.backendInitializationVisible = false;
        this.devicesLoading = false;
        this.hasAuthenticatedSession = true;
        this.exitNodes = snapshot.exitNodes;
        this.applyPeers(snapshot.peers);
        this.networkSettings = snapshot.networkSettings;
        this.applyAccountSummary(snapshot.account);
      } else if (snapshot.account.needsApproval || this.backendStatus.includes('NeedsMachineAuth')) {
        this.backendReady = true;
        this.backendInitializationVisible = false;
        this.devicesLoading = false;
        this.hasAuthenticatedSession = true;
        this.exitNodes = [];
        this.applyPeers([]);
        this.applyAccountSummary(snapshot.account);
      } else if (this.needsLogin()) {
        this.backendReady = true;
        this.backendInitializationVisible = false;
        this.devicesLoading = false;
        this.hasAuthenticatedSession = false;
        this.applyPeers([]);
        this.exitNodes = [];
        this.applyAccountSummary(snapshot.account);
      } else if (this.backendStatus.startsWith('FAILED')) {
        this.backendReady = true;
        this.backendInitializationVisible = false;
        this.devicesLoading = false;
      }
    } catch (error) {
      if (generation !== this.lifecycleGeneration) {
        return;
      }
      this.backendStatus = `Tailscale Backend Failed: ${JSON.stringify(error)}`;
      this.backendReady = true;
      this.backendInitializationVisible = false;
      this.devicesLoading = false;
    } finally {
      this.refreshInFlight = false;
    }
  }

  private refreshExitNodes(): void {
    try {
      const choicesText: string = nativeBridge.backendExitNodes();
      this.exitNodes = JSON.parse(choicesText) as ExitNodeChoice[];
      const selected: ExitNodeChoice | undefined = this.exitNodes.find(
        (choice: ExitNodeChoice) => choice.selected);
      this.exitNodeStatus = selected === undefined ? '未使用出口节点' : `已选择：${selected.name}`;
    } catch (_error) {
      this.exitNodes = [];
      this.exitNodeStatus = '出口节点列表暂不可用';
    }
  }

  private async setExitNode(id: string): Promise<void> {
    try {
      this.exitNodeStatus = await nativeBridge.backendSetExitNodeAsync(id);
      if (!this.exitNodeStatus.startsWith('FAILED')) {
        this.refreshBackendStatus();
      }
    } catch (_error) {
      this.exitNodeStatus = 'FAILED | exit node | update unavailable';
    }
  }

  private refreshPeers(): void {
    try {
      const peersText: string = nativeBridge.backendPeers();
      this.applyPeers(JSON.parse(peersText) as PeerSummary[]);
    } catch (_error) {
      this.applyPeers([]);
    }
    this.devicesLoading = false;
  }

  private refreshAccount(): void {
    try {
      const accountText: string = nativeBridge.backendAccount();
      const backendAccount: AccountSummary = JSON.parse(accountText) as AccountSummary;
      this.accountSummary = {
        displayName: backendAccount.displayName,
        loginName: backendAccount.loginName,
        profilePicURL: backendAccount.profilePicURL,
        tailnetName: backendAccount.tailnetName,
        deviceName: DeviceNameService.withoutHuaweiBrand(
          backendAccount.deviceName.length > 0 ? backendAccount.deviceName : this.deviceModel()),
        addresses: backendAccount.addresses,
        needsApproval: backendAccount.needsApproval,
        keyExpired: backendAccount.keyExpired,
        keyExpiryUnixMs: backendAccount.keyExpiryUnixMs
      };
      this.avatarLoadFailed = false;
    } catch (_error) {
      this.accountSummary = {
        displayName: '', loginName: '', profilePicURL: '', tailnetName: '', deviceName: '', addresses: [],
        needsApproval: false, keyExpired: false, keyExpiryUnixMs: 0
      };
      this.avatarLoadFailed = false;
    }
  }

  private refreshNetworkSettings(): void {
    try {
      const settingsText: string = nativeBridge.backendNetworkSettings();
      this.networkSettings = JSON.parse(settingsText) as NetworkSettings;
    } catch (_error) {
      this.networkSettingStatus = 'FAILED | network setting | unavailable';
    }
  }

  private async setNetworkSetting(key: string, enabled: boolean): Promise<void> {
    try {
      this.networkSettingStatus = await nativeBridge.backendSetNetworkSettingAsync(key, enabled);
      if (!this.networkSettingStatus.startsWith('FAILED')) {
        this.refreshBackendStatus();
      }
    } catch (_error) {
      this.networkSettingStatus = 'FAILED | network setting | update unavailable';
    }
  }

  private openSecureLogin(): void {
    if (this.loginInProgress || !this.controlServerConfirmed) {
      if (!this.controlServerConfirmed) {
        this.openControlServerSettings();
      }
      return;
    }
    this.loginInProgress = true;
    this.loginHandoffStatus = 'Preparing secure login';
    this.stopLoginPolling();
    // First-run confirmation restarts the backend asynchronously. Starting is
    // idempotent, so make sure a login tap also drives that startup forward.
    if (!this.backendReady || this.backendStatus.includes('Stopped') ||
      this.backendStatus.includes('not started')) {
      this.startBackend(false);
    }
    // Keep one visible frame for the in-button LoadingProgress before a fast
    // handoff switches the foreground application to the system browser.
    this.loginPollTimer = setTimeout(() => this.pollSecureLogin(0), 150);
  }

  private async pollSecureLogin(attempt: number): Promise<void> {
    try {
      const authUrl: string = await nativeBridge.backendAuthURLAsync();
      const backendStillStarting: boolean = authUrl.startsWith('PENDING') ||
        authUrl === 'FAILED | login URL | backend not ready' ||
        authUrl === 'FAILED | login URL | status unavailable' ||
        authUrl === 'FAILED | login URL | interactive login request';
      if (backendStillStarting) {
        if (attempt >= 60) {
          this.loginHandoffStatus = 'FAILED | login URL | timed out';
          this.loginInProgress = false;
          return;
        }
        if (attempt > 0 && attempt % 10 === 0) {
          this.refreshBackendStatus();
          if (this.backendStatus.includes('Stopped') || this.backendStatus.includes('not started')) {
            this.startBackend(false);
          }
        }
        this.loginPollTimer = setTimeout(() => this.pollSecureLogin(attempt + 1), 400);
        return;
      }
      if (!authUrl.startsWith('https://') && !authUrl.startsWith('http://')) {
        this.loginHandoffStatus = authUrl.startsWith('FAILED') ? authUrl :
          'FAILED | login URL | rejected unexpected origin';
        this.loginInProgress = false;
        return;
      }
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.loginHandoffStatus = 'Opening secure login in system browser';
      context.openLink(authUrl, { appLinkingOnly: false })
        .then(() => {
          this.loginHandoffStatus = 'Secure login page opened';
          this.loginInProgress = false;
        })
        .catch(() => {
          this.loginHandoffStatus = 'FAILED | secure browser handoff';
          this.loginInProgress = false;
        });
    } catch (error) {
      this.loginHandoffStatus = `FAILED | secure browser handoff | ${JSON.stringify(error)}`;
      this.loginInProgress = false;
    }
  }

  private stopLoginPolling(): void {
    if (this.loginPollTimer >= 0) {
      clearTimeout(this.loginPollTimer);
      this.loginPollTimer = -1;
    }
  }

  private runControlProbe(): void {
    if (!this.controlServerConfirmed || this.controlServerURL !== DEFAULT_CONTROL_SERVER_URL) {
      this.controlProbeStatus = 'SKIPPED | Control TLS probe | official backend not selected';
      this.recordDiagnosticEvent('control_probe_skipped', 'backend_selection');
      return;
    }
    try {
      this.controlProbeStatus = nativeBridge.controlProbe();
    } catch (error) {
      this.controlProbeStatus = `Control TLS Probe Failed: ${JSON.stringify(error)}`;
    }
  }

  private vpnWant(): Want {
    return {
      bundleName: 'io.github.tailscaleohos',
      abilityName: 'TailscaleVpnExtensionAbility'
    };
  }

  private stageVpnConnectConfig(config: string): boolean {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const path: string = `${context.filesDir}/${VPN_CONNECT_CONFIG_FILE_NAME}`;
    const temporaryPath: string = `${path}.tmp`;
    const handoff: VpnConnectConfigHandoff = {
      createdAtMs: Date.now(),
      config: config
    };
    if (!this.writePrivateTextFile(temporaryPath, JSON.stringify(handoff))) {
      return false;
    }
    try {
      fileIo.renameSync(temporaryPath, path);
      return true;
    } catch (_error) {
      try {
        if (fileIo.accessSync(temporaryPath)) {
          fileIo.unlinkSync(temporaryPath);
        }
      } catch (_cleanupError) {
        // A later connection attempt replaces the temporary handoff.
      }
      return false;
    }
  }

  private cacheVpnReconnectConfig(): boolean {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const path: string = `${context.filesDir}/${VPN_CONNECT_CONFIG_FILE_NAME}`;
    try {
      if (!fileIo.accessSync(path)) {
        return false;
      }
      const handoff: VpnConnectConfigHandoff = JSON.parse(fileIo.readTextSync(path)) as VpnConnectConfigHandoff;
      const ageMs: number = Date.now() - handoff.createdAtMs;
      if (handoff.createdAtMs <= 0 || ageMs < 0 || ageMs > FAST_RECONNECT_TTL_MS ||
        handoff.config.length === 0 || handoff.config.length > 8192 || handoff.config.startsWith('FAILED')) {
        return false;
      }
      this.cachedVpnConnectConfig = handoff.config;
      this.cachedVpnConnectConfigAtMs = handoff.createdAtMs;
      return true;
    } catch (_error) {
      return false;
    }
  }

  private tryFastReconnect(): boolean {
    const ageMs: number = Date.now() - this.cachedVpnConnectConfigAtMs;
    if (!this.backendRestartDeferred || this.cachedVpnConnectConfig.length === 0 ||
      ageMs < 0 || ageMs > FAST_RECONNECT_TTL_MS) {
      return false;
    }
    if (!this.stageVpnConnectConfig(this.cachedVpnConnectConfig)) {
      this.recordDiagnosticEvent('fast_reconnect_failed', 'persistence');
      return false;
    }
    this.backendRestartDeferred = false;
    this.recordDiagnosticEvent('fast_reconnect_used', 'cached_config');
    this.requestVpnExtensionStart();
    return true;
  }

  private deferBackendRestart(): boolean {
    if (!this.cacheVpnReconnectConfig()) {
      return false;
    }
    this.backendRestartDeferred = true;
    this.backendReady = true;
    this.backendInitializationVisible = false;
    this.devicesLoading = false;
    this.recordDiagnosticEvent('backend_restart_deferred', 'fast_reconnect_window');
    this.scheduleLifecycleTask(() => {
      if (!this.backendRestartDeferred || this.isConnected() || this.isConnecting() ||
        this.disconnectInProgress) {
        return;
      }
      this.backendRestartDeferred = false;
      this.recordDiagnosticEvent('backend_restart_deferred_completed', 'timeout');
      this.startBackend(false);
    }, FAST_RECONNECT_TTL_MS);
    return true;
  }

  private startBackendReadinessPolling(): void {
    this.stopBackendReadinessPolling();
    this.scheduleBackendReadinessPoll(this.lifecycleGeneration, 0);
  }

  private scheduleBackendReadinessPoll(generation: number, delayMs: number): void {
    this.backendReadinessPollTimer = setTimeout(() => {
      if (generation !== this.lifecycleGeneration || this.isConnected()) {
        return;
      }
      this.refreshBackendStatus().finally(() => {
        if (generation !== this.lifecycleGeneration || this.backendReady ||
          this.backendStatus.startsWith('FAILED') || this.backendStatus.startsWith('STOPPED')) {
          this.stopBackendReadinessPolling();
          return;
        }
        this.scheduleBackendReadinessPoll(generation, BACKEND_READINESS_POLL_INTERVAL_MS);
      });
    }, delayMs);
  }

  private stopBackendReadinessPolling(): void {
    if (this.backendReadinessPollTimer >= 0) {
      clearTimeout(this.backendReadinessPollTimer);
      this.backendReadinessPollTimer = -1;
    }
  }

  private beginVpnConnection(): void {
    if (!this.controlServerConfirmed) {
      this.openControlServerSettings();
      return;
    }
    if (this.connectInProgress || this.isConnecting()) {
      return;
    }
    this.clearConnectionCompletionTimer();
    this.connectionStartedAtMs = Date.now();
    this.recordDiagnosticEvent('connect_requested', 'preflight');
    this.setConnectInProgress(true);
    // Leave one rendering frame for the loading state before native/VPN calls.
    this.scheduleLifecycleTask(() => this.startVpnProbe(), CONNECTION_START_FRAME_DELAY_MS);
  }

  private async startVpnProbe(): Promise<void> {
    try {
      if (this.tryFastReconnect()) {
        return;
      }
      const backendConfig: string = await this.backendVpnConfigWithRecovery();
      if (backendConfig.startsWith('FAILED')) {
        this.recordDiagnosticEvent('vpn_preflight_failed', 'backend_config');
        this.vpnStatus = 'Sign in to Tailscale before connecting';
        this.clearConnectionCompletionTimer();
        this.setConnectInProgress(false);
        return;
      }
      if (this.stageVpnConnectConfig(backendConfig)) {
        this.recordDiagnosticEvent('vpn_config_handoff_staged', 'preflight');
      } else {
        this.recordDiagnosticEvent('vpn_config_handoff_failed', 'persistence');
      }
      this.backendStatus = await nativeBridge.backendStopAsync();
      this.requestVpnExtensionStart();
    } catch (_error) {
      this.recordDiagnosticEvent('vpn_preflight_failed', 'exception');
      this.vpnStatus = 'FAILED | VPN preflight | backend unavailable';
      this.clearConnectionCompletionTimer();
      this.setConnectInProgress(false);
    }
  }

  private async backendVpnConfigWithRecovery(): Promise<string> {
    let backendConfig: string = await nativeBridge.backendVpnConfigAsync();
    if (!backendConfig.startsWith('FAILED')) {
      return backendConfig;
    }
    this.recordDiagnosticEvent('backend_recovery_requested', 'connect_preflight');
    this.startBackend(false);
    for (let attempt: number = 0; attempt < 20; attempt++) {
      await new Promise<void>((resolve: () => void) => setTimeout(resolve, 500));
      if (!this.connectInProgress || !this.controlServerConfirmed) {
        return backendConfig;
      }
      backendConfig = await nativeBridge.backendVpnConfigAsync();
      if (!backendConfig.startsWith('FAILED')) {
        this.recordDiagnosticEvent('backend_recovery_completed', 'connect_preflight');
        return backendConfig;
      }
    }
    this.recordDiagnosticEvent('backend_recovery_failed', 'connect_preflight');
    return backendConfig;
  }

  private applyAccountSummary(account: AccountSummary): void {
    this.accountSummary = {
      displayName: account.displayName,
      loginName: account.loginName,
      profilePicURL: account.profilePicURL,
      tailnetName: account.tailnetName,
      deviceName: DeviceNameService.withoutHuaweiBrand(
        account.deviceName.length > 0 ? account.deviceName : this.deviceModel()),
      addresses: account.addresses,
      needsApproval: account.needsApproval,
      keyExpired: account.keyExpired,
      keyExpiryUnixMs: account.keyExpiryUnixMs
    };
    this.avatarLoadFailed = false;
  }

  private requestVpnExtensionStart(): void {
    this.vpnStatus = 'Requesting HarmonyOS VPN authorization';
    vpnExtension.startVpnExtensionAbility(this.vpnWant())
      .then(() => {
        this.recordDiagnosticEvent('vpn_start_requested', 'system');
        this.vpnStatus = 'HarmonyOS VPN Extension start requested';
        this.startConnectionPolling();
      })
      .catch((error: BusinessError) => {
        this.recordDiagnosticEvent('vpn_start_failed', 'system', error.code);
        this.vpnStatus = `FAILED | VPN start | code=${error.code}`;
        this.clearConnectionCompletionTimer();
        this.setConnectInProgress(false);
      });
  }

  private stopVpnProbe(): void {
    if (this.disconnectInProgress) {
      return;
    }
    this.lastConfirmedVpnStatus = '';
    this.lastConfirmedVpnHeartbeatMs = 0;
    this.vpnStatusGraceActive = false;
    this.clearConnectionCompletionTimer();
    this.setConnectInProgress(false);
    this.disconnectInProgress = true;
    this.recordDiagnosticEvent('disconnect_requested', 'user');
    this.stopVpnStopPolling();
    this.vpnStopRequestId = Date.now();
    const responsePath: string = this.vpnStopFilePath(VPN_STOP_RESPONSE_FILE_NAME);
    this.writePrivateTextFile(responsePath, '');
    const request: VpnStopRequest = { requestId: this.vpnStopRequestId };
    const requestPath: string = this.vpnStopFilePath(VPN_STOP_REQUEST_FILE_NAME);
    if (!this.writePrivateTextFile(requestPath, JSON.stringify(request))) {
      this.finishVpnExtensionStop();
      return;
    }
    this.pollVpnStopResponse(0);
  }

  private vpnStopFilePath(fileName: string): string {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return `${context.filesDir}/${fileName}`;
  }

  private pollVpnStopResponse(attempt: number): void {
    if (!this.disconnectInProgress) {
      return;
    }
    if (attempt >= VPN_STOP_POLL_MAX_ATTEMPTS) {
      this.recordDiagnosticEvent('vpn_backend_stop_timeout', 'disconnect');
      this.finishVpnExtensionStop();
      return;
    }
    const responsePath: string = this.vpnStopFilePath(VPN_STOP_RESPONSE_FILE_NAME);
    try {
      if (fileIo.accessSync(responsePath)) {
        const responseText: string = fileIo.readTextSync(responsePath).trim();
        if (responseText.length > 0) {
          const response: VpnStopResponse = JSON.parse(responseText) as VpnStopResponse;
          if (response.requestId === this.vpnStopRequestId) {
            this.writePrivateTextFile(responsePath, '');
            this.backendStatus = response.status;
            this.finishVpnExtensionStop();
            return;
          }
        }
      }
    } catch (_error) {
      // The Extension may be replacing the response file. Retry briefly before
      // falling back to the lifecycle stop, whose onDestroy path also closes it.
    }
    this.vpnStopPollTimer = setTimeout(() => {
      this.pollVpnStopResponse(attempt + 1);
    }, VPN_STOP_POLL_INTERVAL_MS);
  }

  private stopVpnStopPolling(): void {
    if (this.vpnStopPollTimer >= 0) {
      clearTimeout(this.vpnStopPollTimer);
      this.vpnStopPollTimer = -1;
    }
  }

  private finishVpnExtensionStop(): void {
    this.stopVpnStopPolling();
    vpnExtension.stopVpnExtensionAbility(this.vpnWant())
      .then(() => {
        this.recordDiagnosticEvent('disconnect_completed', 'system');
        this.getUIContext().animateTo({ duration: 420, curve: Curve.EaseInOut }, () => {
          this.vpnStatus = 'HarmonyOS VPN Extension stopped';
          this.disconnectInProgress = false;
          this.homeTitleCompact = false;
        });
        this.stopConnectionPolling();
        if (!this.deferBackendRestart()) {
          this.startBackend(false);
          this.scheduleLifecycleTask(() => this.refreshBackendStatus(), 1500);
        }
      })
      .catch((error: BusinessError) => {
        this.recordDiagnosticEvent('disconnect_failed', 'system', error.code);
        this.getUIContext().animateTo({ duration: 420, curve: Curve.EaseInOut }, () => {
          this.vpnStatus = `FAILED | VPN stop | code=${error.code}`;
          this.disconnectInProgress = false;
          this.homeTitleCompact = false;
        });
      });
  }

  private confirmLogout(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.logout_confirm_title'),
      message: $r('app.string.logout_confirm_message'),
      autoCancel: true,
      primaryButton: {
        value: $r('app.string.cancel_action'),
        action: () => {
        }
      },
      secondaryButton: {
        value: $r('app.string.logout_action'),
        fontColor: $r('app.color.status_error'),
        action: () => this.logout()
      }
    });
  }

  private async logout(): Promise<void> {
    try {
      this.logoutStatus = await nativeBridge.backendLogoutAsync();
      if (!this.logoutStatus.startsWith('FAILED')) {
        this.loginInProgress = false;
        this.hasAuthenticatedSession = false;
        this.stopLoginPolling();
        this.applyPeers([]);
        this.exitNodes = [];
        this.exitNodeStatus = '未使用出口节点';
        this.loginHandoffStatus = 'Secure Login Pending';
        this.scheduleLifecycleTask(() => this.refreshBackendStatus(), 500);
      }
    } catch (_error) {
      this.logoutStatus = 'FAILED | logout | unavailable';
    }
  }

  private statusNumber(status: string, key: string): number {
    const match: RegExpMatchArray | null = status.match(new RegExp(`(?:^|\\|\\s*)${key}=(\\d+)`));
    return match === null ? 0 : Number(match[1]);
  }

  private resetTrafficMetrics(): void {
    this.trafficSession = 0;
    this.trafficLastHeartbeatMs = 0;
    this.trafficLastDownloadBytes = 0;
    this.trafficLastUploadBytes = 0;
    this.trafficDownloadBytes = 0;
    this.trafficUploadBytes = 0;
    this.trafficDownloadRate = 0;
    this.trafficUploadRate = 0;
    this.trafficSamples = [];
  }

  private updateTrafficMetrics(status: string, heartbeatMs: number): void {
    if (!status.includes('state=Running')) {
      return;
    }
    const session: number = this.statusNumber(status, 'trafficSession');
    const uploadBytes: number = this.statusNumber(status, 'txBytes');
    const downloadBytes: number = this.statusNumber(status, 'rxBytes');
    if (session <= 0 || heartbeatMs <= 0) {
      return;
    }
    if (session !== this.trafficSession || heartbeatMs <= this.trafficLastHeartbeatMs) {
      if (session !== this.trafficSession) {
        this.trafficSession = session;
        this.trafficLastHeartbeatMs = heartbeatMs;
        this.trafficLastDownloadBytes = downloadBytes;
        this.trafficLastUploadBytes = uploadBytes;
        this.trafficDownloadBytes = downloadBytes;
        this.trafficUploadBytes = uploadBytes;
        this.trafficDownloadRate = 0;
        this.trafficUploadRate = 0;
        this.trafficSamples = [{ downloadBytesPerSecond: 0, uploadBytesPerSecond: 0 }];
      }
      return;
    }
    const elapsedMs: number = heartbeatMs - this.trafficLastHeartbeatMs;
    if (elapsedMs <= 0) {
      return;
    }
    const downloadDelta: number = downloadBytes >= this.trafficLastDownloadBytes ?
      downloadBytes - this.trafficLastDownloadBytes : 0;
    const uploadDelta: number = uploadBytes >= this.trafficLastUploadBytes ?
      uploadBytes - this.trafficLastUploadBytes : 0;
    this.trafficDownloadRate = Math.round(downloadDelta * 1000 / elapsedMs);
    this.trafficUploadRate = Math.round(uploadDelta * 1000 / elapsedMs);
    this.trafficDownloadBytes = downloadBytes;
    this.trafficUploadBytes = uploadBytes;
    this.trafficLastHeartbeatMs = heartbeatMs;
    this.trafficLastDownloadBytes = downloadBytes;
    this.trafficLastUploadBytes = uploadBytes;
    const nextSamples: TrafficSample[] = this.trafficSamples.concat({
      downloadBytesPerSecond: this.trafficDownloadRate,
      uploadBytesPerSecond: this.trafficUploadRate
    });
    this.trafficSamples = nextSamples.length > 60 ? nextSamples.slice(nextSamples.length - 60) : nextSamples;
  }

  private formatTrafficBytes(value: number, perSecond: boolean = false): string {
    const suffix: string = perSecond ? '/s' : '';
    if (value < 1024) {
      return `${Math.max(0, Math.round(value))} B${suffix}`;
    }
    if (value < 1024 * 1024) {
      return `${(value / 1024).toFixed(value >= 10240 ? 1 : 2)} KB${suffix}`;
    }
    if (value < 1024 * 1024 * 1024) {
      return `${(value / (1024 * 1024)).toFixed(value >= 10 * 1024 * 1024 ? 1 : 2)} MB${suffix}`;
    }
    return `${(value / (1024 * 1024 * 1024)).toFixed(2)} GB${suffix}`;
  }

  private cacheSizeLabel(): ResourceStr {
    if (this.cacheClearActive()) {
      return $r('app.string.settings_cache_clearing');
    }
    if (this.cacheSizeLoading) {
      return $r('app.string.settings_cache_calculating');
    }
    return this.formatTrafficBytes(this.cacheSizeBytes);
  }

  private cacheDirectorySize(path: string): number {
    if (!fileIo.accessSync(path)) {
      return 0;
    }
    const stat: fileIo.Stat = fileIo.statSync(path);
    if (stat.isFile()) {
      return stat.size;
    }
    if (!stat.isDirectory()) {
      return 0;
    }
    let size: number = 0;
    fileIo.listFileSync(path).forEach((name: string) => {
      size += this.cacheDirectorySize(`${path}/${name}`);
    });
    return size;
  }

  private appCacheRoots(context: common.UIAbilityContext): string[] {
    return [
      context.cacheDir,
      `${context.filesDir}/${TAILDROP_OUTBOX_DIR_NAME}`,
      `${context.filesDir}/${TAILDROP_INBOX_DIR_NAME}`,
      `${context.filesDir}/${TAILDROP_HISTORY_MEDIA_DIR_NAME}`
    ];
  }

  private taildropWaitingFilesSize(): number {
    let size: number = 0;
    this.taildropWaitingFiles.forEach((file: TaildropWaitingFileSummary) => {
      size += Math.max(0, file.size);
    });
    return size;
  }

  private taildropCacheClearInProgress(): boolean {
    return this.taildropReceiveInProgress && this.taildropReceiveStrategy === 'clear';
  }

  private cacheClearActive(): boolean {
    return this.cacheClearInProgress || this.taildropCacheClearInProgress();
  }

  private notifyCacheContentsChanged(): void {
    if (this.activeTab !== 2 || this.cacheClearInProgress || this.cacheRefreshScheduled) {
      return;
    }
    this.cacheRefreshScheduled = true;
    this.scheduleLifecycleTask(() => {
      this.cacheRefreshScheduled = false;
      this.refreshCacheSize(false);
    }, 80);
  }

  private refreshCacheSize(showLoading: boolean = true): void {
    if (this.cacheClearInProgress || this.cacheSizeRefreshInFlight) {
      return;
    }
    if (showLoading) {
      this.cacheSizeLoading = true;
    }
    this.cacheSizeRefreshInFlight = true;
    const generation: number = this.lifecycleGeneration;
    this.cacheSizeRefreshTimer = setTimeout(() => {
      this.cacheSizeRefreshTimer = -1;
      if (generation !== this.lifecycleGeneration) {
        this.cacheSizeRefreshInFlight = false;
        return;
      }
      try {
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        let totalSize: number = 0;
        this.appCacheRoots(context).forEach((path: string) => {
          totalSize += this.cacheDirectorySize(path);
        });
        totalSize += this.taildropWaitingFilesSize();
        if (this.cacheSizeBytes !== totalSize) {
          this.cacheSizeBytes = totalSize;
        }
      } catch (_error) {
        this.cacheSizeBytes = 0;
      } finally {
        this.cacheSizeRefreshInFlight = false;
        this.cacheSizeLoading = false;
      }
    }, 0);
  }

  private startCacheSizePolling(): void {
    if (this.cacheSizePollTimer >= 0) {
      this.refreshCacheSize(false);
      return;
    }
    this.refreshCacheSize();
    this.cacheSizePollTimer = setInterval(() => {
      if (this.activeTab === 2) {
        this.refreshCacheSize(false);
      }
    }, CACHE_SIZE_POLL_INTERVAL_MS);
  }

  private stopCacheSizePolling(): void {
    if (this.cacheSizePollTimer >= 0) {
      clearInterval(this.cacheSizePollTimer);
      this.cacheSizePollTimer = -1;
    }
    if (this.cacheSizeRefreshTimer >= 0) {
      clearTimeout(this.cacheSizeRefreshTimer);
      this.cacheSizeRefreshTimer = -1;
      this.cacheSizeRefreshInFlight = false;
    }
  }

  private updateCacheSizePolling(index: number): void {
    if (index === 2) {
      this.startCacheSizePolling();
    } else {
      this.stopCacheSizePolling();
    }
  }

  private cacheClearBlocked(): boolean {
    return this.cacheClearActive() || this.diagnosticReportInProgress ||
      this.taildropPreparing || this.taildropReceiveInProgress ||
      this.taildropTransfer.state === 'queued' || this.taildropTransfer.state === 'sending';
  }

  private cacheClearEnabled(): boolean {
    return !this.cacheSizeLoading && this.cacheSizeBytes > 0 && !this.cacheClearBlocked();
  }

  private removeCacheEntry(path: string): boolean {
    try {
      const stat: fileIo.Stat = fileIo.statSync(path);
      if (stat.isFile()) {
        fileIo.unlinkSync(path);
        return true;
      }
      if (!stat.isDirectory()) {
        return false;
      }
      let succeeded: boolean = true;
      fileIo.listFileSync(path).forEach((name: string) => {
        if (!this.removeCacheEntry(`${path}/${name}`)) {
          succeeded = false;
        }
      });
      if (succeeded) {
        fileIo.rmdirSync(path);
      }
      return succeeded;
    } catch (_error) {
      return false;
    }
  }

  private confirmClearAppCache(): void {
    if (!this.cacheClearEnabled()) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: $r('app.string.settings_clear_cache_confirm_title'),
      message: $r('app.string.settings_clear_cache_confirm_message'),
      autoCancel: true,
      primaryButton: {
        value: $r('app.string.cancel_action'),
        action: () => {
          // Keep the current cache untouched.
        }
      },
      secondaryButton: {
        value: $r('app.string.settings_clear_cache_action'),
        fontColor: $r('sys.color.font_emphasize'),
        action: () => this.clearAppCache()
      }
    });
  }

  private clearAppCache(): void {
    if (this.cacheClearBlocked()) {
      this.showToast($r('app.string.settings_clear_cache_busy'));
      return;
    }
    this.cacheClearInProgress = true;
    this.scheduleLifecycleTask(() => {
      const succeeded: boolean = this.clearAppCacheEntries();
      this.taildropMediaPreviews = [];
      this.taildropCachedFiles = [];
      this.taildropAutoPrefetchFailedKeys = [];
      this.taildropAutoPrefetchKey = '';
      this.taildropHistory = this.taildropHistory.map((record: TaildropTransferRecord) => {
        record.previewPath = '';
        return record;
      });
      this.persistTaildropHistory();
      if (succeeded && this.taildropWaitingFiles.length > 0 && this.taildropState === 'ready') {
        this.cacheClearRequestedFromSettings = true;
        if (this.requestTaildropInboxCacheClear()) {
          return;
        }
        this.cacheClearRequestedFromSettings = false;
        this.finishSettingsCacheClear(false);
        return;
      } else if (succeeded && this.taildropState !== 'ready') {
        this.clearTaildropInboxViewState();
      }
      this.finishSettingsCacheClear(succeeded);
    }, 0);
  }

  private clearAppCacheEntries(): boolean {
    let succeeded: boolean = true;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.appCacheRoots(context).forEach((root: string) => {
        if (!fileIo.accessSync(root)) {
          return;
        }
        fileIo.listFileSync(root).forEach((name: string) => {
          if (!this.removeCacheEntry(`${root}/${name}`)) {
            succeeded = false;
          }
        });
      });
    } catch (_error) {
      succeeded = false;
    }
    return succeeded;
  }

  private clearTaildropInboxViewState(): void {
    this.taildropMediaPreviews = [];
    this.taildropCachedFiles = [];
    this.taildropAutoPrefetchFailedKeys = [];
    this.taildropAutoPrefetchKey = '';
    this.taildropWaitingFiles = [];
    this.taildropInboxReason = '';
    this.persistTaildropInbox();
  }

  private finishSettingsCacheClear(succeeded: boolean): void {
    this.cacheClearRequestedFromSettings = false;
    this.cacheClearInProgress = false;
    this.refreshCacheSize(false);
    this.showToast(succeeded ? $r('app.string.settings_cache_cleared') :
      $r('app.string.settings_clear_cache_failed'));
  }

  private trafficChartWidth(): number {
    return Math.max(220, Math.min(760, this.layoutWidth - this.contentMargin() * 2 - 32));
  }

  private maximumTrafficRate(): number {
    let maximum: number = 1024;
    this.trafficSamples.forEach((sample: TrafficSample) => {
      maximum = Math.max(maximum, sample.downloadBytesPerSecond, sample.uploadBytesPerSecond);
    });
    return maximum;
  }

  private trafficChartPoints(download: boolean, height: number = 68): Array<Array<number>> {
    const width: number = this.trafficChartWidth();
    if (this.trafficSamples.length === 0) {
      return [[0, height - 4], [width, height - 4]];
    }
    const maximum: number = this.maximumTrafficRate();
    const step: number = width / 59;
    const startX: number = width - step * (this.trafficSamples.length - 1);
    const points: Array<Array<number>> = [];
    this.trafficSamples.forEach((sample: TrafficSample, index: number) => {
      const rate: number = download ? sample.downloadBytesPerSecond : sample.uploadBytesPerSecond;
      const y: number = height - 4 - Math.min(1, rate / maximum) * (height - 8);
      points.push([startX + index * step, y]);
    });
    if (points.length === 1) {
      points.unshift([Math.max(0, startX - step), points[0][1]]);
    }
    return points;
  }

  private refreshVpnProbeStatus(): boolean {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const statusPath: string = `${context.filesDir}/vpn-probe-status.txt`;
      if (!fileIo.accessSync(statusPath)) {
        if (this.preserveConfirmedVpnStatus('', 0)) {
          return true;
        }
        this.vpnStatus = 'HarmonyOS VPN Extension Stopped';
        return false;
      }
      const persistedStatus: string = fileIo.readTextSync(statusPath).trim();
      const heartbeatMatch: RegExpMatchArray | null = persistedStatus.match(/heartbeatMs=(\d+)/);
      const heartbeatMs: number = heartbeatMatch === null ? 0 : Number(heartbeatMatch[1]);
      const heartbeatAgeMs: number = Date.now() - heartbeatMs;
      const heartbeatIsFresh: boolean = heartbeatMs > 0 && heartbeatAgeMs >= 0 &&
        heartbeatAgeMs <= VPN_HEARTBEAT_FRESH_MS;
      const visibleStatus: string = persistedStatus.replace(/\s*\|\s*heartbeatMs=\d+/, '');
      let extensionIsLive: boolean = heartbeatIsFresh && !visibleStatus.includes('destroyed');
      if (extensionIsLive && !this.vpnHeartbeatConfirmed) {
        if (this.vpnHeartbeatBaselineMs <= 0) {
          this.vpnHeartbeatBaselineMs = heartbeatMs;
        }
        const heartbeatAdvanced: boolean = heartbeatMs > this.vpnHeartbeatBaselineMs ||
          heartbeatMs >= this.vpnHeartbeatObservationStartedAtMs;
        if (heartbeatAdvanced) {
          this.vpnHeartbeatConfirmed = true;
        } else if (Date.now() - this.vpnHeartbeatObservationStartedAtMs <=
          VPN_HEARTBEAT_CONFIRM_TIMEOUT_MS) {
          // A recent persisted Running state is not proof that the Extension
          // survived a process crash. Wait for one post-launch heartbeat
          // advance before exposing it as connected.
          this.vpnStatus = 'HarmonyOS VPN Extension starting verification';
          return true;
        } else {
          extensionIsLive = false;
        }
      }
      if (extensionIsLive && visibleStatus.includes('state=Running') &&
        visibleStatus.includes('tun=true')) {
        if (this.vpnStatusGraceActive) {
          this.recordDiagnosticEvent('vpn_status_grace_recovered', 'heartbeat');
          this.vpnStatusGraceActive = false;
        }
        this.lastConfirmedVpnStatus = visibleStatus;
        this.lastConfirmedVpnHeartbeatMs = heartbeatMs;
      } else if (this.preserveConfirmedVpnStatus(visibleStatus, heartbeatMs)) {
        return true;
      }
      if (extensionIsLive) {
        this.updateTrafficMetrics(visibleStatus, heartbeatMs);
        if (visibleStatus.includes('state=Running')) {
          this.refreshPeerSnapshot();
        }
        this.refreshTaildropSnapshot();
        this.checkTaildropReceiveTimeout();
        this.processTaildropReceiveResponse();
      } else {
        this.resetTrafficMetrics();
        this.resetTaildropSnapshot();
        this.resetStreamingStatesForDisconnect();
      }
      const shouldPromptVpnConflict: boolean = extensionIsLive && this.connectInProgress &&
        visibleStatus.includes(`code=2203002`);
      if (extensionIsLive && visibleStatus.includes('state=Running') && this.connectInProgress) {
        const remainingMs: number = MIN_CONNECTION_LOADING_MS -
          (Date.now() - this.connectionStartedAtMs);
        if (remainingMs > 0) {
          if (this.connectionCompletionTimer < 0) {
            this.connectionCompletionTimer = setTimeout(() => {
              this.commitConnectedStatus(visibleStatus);
            }, remainingMs);
          }
          return extensionIsLive;
        }
        this.commitConnectedStatus(visibleStatus);
        return extensionIsLive;
      }
      this.vpnStatus = !extensionIsLive && visibleStatus.includes('tun=true') ?
        'HarmonyOS VPN Extension Stopped (previous session ended)' : visibleStatus;
      this.syncHomeTitleCompact(this.connectedHomeLayoutActive());
      if (!visibleStatus.includes('state=Running')) {
        this.resetStreamingStatesForDisconnect();
      }
      if (extensionIsLive &&
        (visibleStatus.includes('state=Running') || visibleStatus.startsWith('FAILED'))) {
        this.clearConnectionCompletionTimer();
        this.setConnectInProgress(false);
      }
      if (shouldPromptVpnConflict) {
        this.showVpnConflictDialog();
      }
      return extensionIsLive;
    } catch (error) {
      if (this.preserveConfirmedVpnStatus('', 0)) {
        return true;
      }
      const businessError = error as BusinessError;
      this.vpnStatus = `FAILED | VPN status file | code=${businessError.code}`;
      return false;
    }
  }

  private preserveConfirmedVpnStatus(status: string, heartbeatMs: number): boolean {
    if (this.disconnectInProgress || this.lastConfirmedVpnStatus.length === 0 ||
      this.lastConfirmedVpnHeartbeatMs <= 0) {
      return false;
    }
    const confirmedAgeMs: number = Date.now() - this.lastConfirmedVpnHeartbeatMs;
    if (confirmedAgeMs < 0 || confirmedAgeMs > VPN_CONNECTED_GRACE_MS) {
      if (this.vpnStatusGraceActive) {
        this.recordDiagnosticEvent('vpn_status_grace_expired', 'heartbeat');
        this.vpnStatusGraceActive = false;
      }
      return false;
    }
    const normalizedStatus: string = status.toLowerCase();
    const explicitStop: boolean = normalizedStatus.includes('destroyed') ||
      normalizedStatus.includes('disconnect') || normalizedStatus.includes('stopped') ||
      normalizedStatus.startsWith('failed');
    const heartbeatUnavailable: boolean = heartbeatMs <= 0 ||
      Date.now() - heartbeatMs > VPN_HEARTBEAT_FRESH_MS;
    const liveTunTransition: boolean = status.includes('backend starting') ||
      (status.includes('tun=true') &&
        (status.includes('state=NoState') || status.includes('state=Starting')));
    if (explicitStop || (!heartbeatUnavailable && !liveTunTransition)) {
      return false;
    }
    if (!this.vpnStatusGraceActive) {
      this.vpnStatusGraceActive = true;
      this.recordDiagnosticEvent('vpn_status_grace_started',
        liveTunTransition ? 'tun_transition' : 'heartbeat');
    }
    this.vpnStatus = this.lastConfirmedVpnStatus;
    return true;
  }

  private startConnectionPolling(): void {
    this.stopConnectionPolling();
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const statusPath: string = `${context.filesDir}/vpn-probe-status.txt`;
    try {
      if (fileIo.accessSync(statusPath)) {
        this.connectionStatusWatcher = fileIo.createWatcher(statusPath, FILE_WATCH_CLOSE_WRITE, () => {
          this.handleConnectionStatusUpdate();
        });
        this.connectionStatusWatcher.start();
      }
    } catch (_error) {
      this.connectionStatusWatcher = undefined;
    }
    this.connectionPollTimer = setInterval(() => {
      this.handleConnectionStatusUpdate();
    }, CONNECTION_POLL_INTERVAL_MS);
  }

  private handleConnectionStatusUpdate(): void {
    this.refreshVpnProbeStatus();
    if (this.vpnStatus.includes('state=Running') || this.vpnStatus.startsWith('FAILED')) {
      this.stopConnectionPolling();
    }
  }

  private stopConnectionPolling(): void {
    if (this.connectionPollTimer >= 0) {
      clearInterval(this.connectionPollTimer);
      this.connectionPollTimer = -1;
    }
    if (this.connectionStatusWatcher !== undefined) {
      try {
        this.connectionStatusWatcher.stop();
      } catch (_error) {
        // The watcher may already have stopped with the Extension process.
      }
      this.connectionStatusWatcher = undefined;
    }
  }

  private clearConnectionCompletionTimer(): void {
    if (this.connectionCompletionTimer >= 0) {
      clearTimeout(this.connectionCompletionTimer);
      this.connectionCompletionTimer = -1;
    }
  }

  private commitConnectedStatus(status: string): void {
    this.clearConnectionCompletionTimer();
    // Keep every completion path in one explicit transaction. The traffic panel
    // also animates height, opacity, and position so the expansion stays visible.
    this.getUIContext().animateTo({ duration: 500, curve: Curve.EaseInOut }, () => {
      this.vpnStatus = status;
      this.setConnectInProgress(false);
      this.homeTitleCompact = true;
    });
    this.scheduleLifecycleTask(() => this.autoProbeConnectedPeerServices(), 50);
    this.stopConnectionPolling();
  }

  private syncHomeTitleCompact(compact: boolean): void {
    if (this.homeTitleCompact === compact) {
      return;
    }
    this.getUIContext().animateTo({ duration: 420, curve: Curve.EaseInOut }, () => {
      this.homeTitleCompact = compact;
    });
  }

  private taildropSnapshotFilePath(): string {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return `${context.filesDir}/${TAILDROP_TARGETS_FILE_NAME}`;
  }

  private peerSnapshotFilePath(): string {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return `${context.filesDir}/${VPN_PEERS_FILE_NAME}`;
  }

  private refreshPeerSnapshot(): void {
    try {
      const path: string = this.peerSnapshotFilePath();
      if (!fileIo.accessSync(path)) {
        return;
      }
      const snapshot: PersistedPeerSnapshot = JSON.parse(
        fileIo.readTextSync(path)) as PersistedPeerSnapshot;
      const ageMs: number = Date.now() - snapshot.updatedAtMs;
      if (snapshot.updatedAtMs <= 0 || ageMs < 0 || ageMs > 5000) {
        return;
      }
      const validPeers: PeerSummary[] = snapshot.peers.filter(
        (peer: PeerSummary) => /^peer-[a-f0-9]{16}$/.test(peer.key) && peer.name.length > 0);
      const signature: string = JSON.stringify(validPeers);
      if (signature === this.peerSnapshotSignature) {
        return;
      }
      this.peerSnapshotSignature = signature;
      this.applyPeers(validPeers);
      this.devicesLoading = false;
    } catch (_error) {
      // The Extension may be replacing the snapshot file. Retry on the next
      // one-second health poll without discarding the last valid device list.
    }
  }

  private resetTaildropSnapshot(): void {
    this.taildropState = 'disconnected';
    this.taildropReason = '';
    this.taildropTargets = [];
    this.taildropAutoPrefetchKey = '';
    this.taildropPendingTextPreview = undefined;
    this.taildropPendingMediaSave = undefined;
    if (this.taildropReceiveInProgress) {
      if (this.taildropReceive.state === 'awaiting_gallery_save' ||
        this.taildropReceive.state === 'awaiting_text_preview') {
        this.resetTaildropReceiveOperation();
      } else {
        this.failTaildropReceive('disconnected');
      }
    }
    if (this.taildropTransfer.state === 'queued' || this.taildropTransfer.state === 'sending') {
      this.applyTaildropTransfer(this.taildropTransferFailure(this.taildropTransfer, 'disconnected'));
    }
  }

  private validTaildropTransfer(transfer: TaildropTransferSummary): boolean {
    if (transfer.state !== 'idle' && transfer.state !== 'queued' && transfer.state !== 'sending' &&
      transfer.state !== 'completed' && transfer.state !== 'failed') {
      return false;
    }
    return transfer.requestId >= 0 && transfer.fileIndex >= 0 && transfer.fileCount >= 0 &&
      transfer.fileBytes >= 0 && transfer.fileSize >= 0 && transfer.bytesSent >= 0 &&
      transfer.totalBytes >= 0;
  }

  private taildropTransferFailure(
    transfer: TaildropTransferSummary, reason: string
  ): TaildropTransferSummary {
    return {
      requestId: transfer.requestId,
      state: 'failed',
      reason: reason,
      targetKey: transfer.targetKey,
      targetName: transfer.targetName,
      fileName: transfer.fileName,
      fileIndex: transfer.fileIndex,
      fileCount: transfer.fileCount,
      fileBytes: transfer.fileBytes,
      fileSize: transfer.fileSize,
      bytesSent: transfer.bytesSent,
      totalBytes: transfer.totalBytes,
      previewPath: transfer.previewPath,
      completedAtMs: Date.now()
    };
  }

  private taildropFailureMessage(reason: string): ResourceStr {
    switch (reason) {
      case 'target_unavailable':
      case 'target_offline':
        return $r('app.string.transfer_send_target_unavailable');
      case 'admin_disabled':
        return $r('app.string.transfer_admin_disabled_title');
      case 'disconnected':
        return $r('app.string.transfer_send_disconnected');
      case 'cancelled':
        return $r('app.string.transfer_send_cancelled');
      case 'permission_denied':
        return $r('app.string.transfer_send_permission_denied');
      case 'no_space':
        return $r('app.string.transfer_send_no_space');
      case 'file_unavailable':
        return $r('app.string.transfer_send_file_unavailable');
      case 'file_changed':
        return $r('app.string.transfer_send_file_changed');
      case 'busy':
        return $r('app.string.transfer_busy_message');
      case 'backend_unavailable':
      case 'extension_error':
        return $r('app.string.transfer_send_backend_unavailable');
      case 'timeout':
      case 'network_interrupted':
        return $r('app.string.transfer_send_interrupted');
      default:
        return $r('app.string.transfer_send_failed');
    }
  }

  private applyTaildropTransfer(transfer: TaildropTransferSummary): void {
    if (!this.validTaildropTransfer(transfer)) {
      return;
    }
    if (transfer.state === 'idle' &&
      (this.taildropTransfer.state === 'queued' || this.taildropTransfer.state === 'sending') &&
      Date.now() - this.taildropRequestSubmittedAtMs < 5000) {
      return;
    }
    if (transfer.state === 'idle' && this.taildropTransfer.state === 'queued' &&
      Date.now() - this.taildropRequestSubmittedAtMs >= 5000) {
      this.applyTaildropTransfer(this.taildropTransferFailure(
        this.taildropTransfer, 'extension_error'));
      return;
    }
    if (transfer.requestId === this.taildropTransfer.requestId) {
      if (typeof transfer.previewPath !== 'string') {
        transfer.previewPath = '';
      }
      if (transfer.targetName.length === 0) {
        transfer.targetName = this.taildropTransfer.targetName;
      }
      if (transfer.fileName.length === 0) {
        transfer.fileName = this.taildropTransfer.fileName;
      }
      if (transfer.previewPath.length === 0) {
        transfer.previewPath = this.taildropTransfer.previewPath;
      }
    } else if (typeof transfer.previewPath !== 'string') {
      transfer.previewPath = '';
    }
    this.updateTaildropProgressEstimate(transfer);
    this.taildropTransfer = transfer;
    if (transfer.state === 'completed' || transfer.state === 'failed' || transfer.state === 'idle') {
      this.taildropCancelPending = false;
    }
    if ((transfer.state === 'completed' || transfer.state === 'failed') && transfer.requestId > 0 &&
      transfer.requestId !== this.lastHandledTaildropRequestId) {
      this.lastHandledTaildropRequestId = transfer.requestId;
      const target: TaildropTargetSummary | undefined = this.displayedTaildropTargets().find(
        (item: TaildropTargetSummary) => item.key === transfer.targetKey);
      const targetName: string = transfer.targetName.length > 0 ? transfer.targetName :
        (target === undefined ? 'Tailscale' : target.name);
      const record: TaildropTransferRecord = {
        requestId: transfer.requestId,
        direction: 'send',
        state: transfer.state,
        reason: transfer.reason,
        targetKey: transfer.targetKey,
        targetName: targetName,
        fileName: transfer.fileName,
        fileCount: transfer.fileCount,
        totalBytes: transfer.totalBytes,
        previewPath: transfer.previewPath,
        completedAtMs: transfer.completedAtMs > 0 ? transfer.completedAtMs : Date.now()
      };
      this.taildropHistory = [record].concat(this.taildropHistory).slice(0, TAILDROP_HISTORY_LIMIT);
      this.persistTaildropHistory();
      this.showToast(transfer.state === 'completed' ?
        $r('app.string.transfer_send_completed') : this.taildropFailureMessage(transfer.reason));
    }
  }

  private refreshTaildropSnapshot(): void {
    try {
      const path: string = this.taildropSnapshotFilePath();
      if (!fileIo.accessSync(path)) {
        this.taildropState = 'loading';
        return;
      }
      const snapshot: TaildropSnapshot = JSON.parse(fileIo.readTextSync(path)) as TaildropSnapshot;
      const ageMs: number = Date.now() - snapshot.updatedAtMs;
      if (snapshot.updatedAtMs <= 0 || ageMs < 0 || ageMs > 5000) {
        this.taildropState = 'loading';
        return;
      }
      if (snapshot.state !== 'ready' && snapshot.state !== 'disabled' &&
        snapshot.state !== 'unavailable' && snapshot.state !== 'loading') {
        this.taildropState = 'unavailable';
        this.taildropReason = 'invalid_snapshot';
        this.taildropTargets = [];
        return;
      }
      const validTargets: TaildropTargetSummary[] = snapshot.targets.filter(
        (target: TaildropTargetSummary) => /^peer-[a-f0-9]{16}$/.test(target.key) && target.name.length > 0);
      const validWaitingFiles: TaildropWaitingFileSummary[] = snapshot.waitingFiles.filter(
        (file: TaildropWaitingFileSummary) => file.name.length > 0 && file.name.length <= 255 &&
          !file.name.includes('/') && !file.name.includes('\\') && file.size >= 0);
      this.taildropState = snapshot.state;
      this.taildropReason = snapshot.reason;
      if (JSON.stringify(this.taildropTargets) !== JSON.stringify(validTargets)) {
        this.taildropTargets = validTargets;
      }
      if (validWaitingFiles.length > 0) {
        const waitingFilesChanged: boolean =
          JSON.stringify(this.taildropWaitingFiles) !== JSON.stringify(validWaitingFiles);
        if (waitingFilesChanged) {
          this.taildropWaitingFiles = validWaitingFiles;
          this.notifyCacheContentsChanged();
        }
        this.taildropInboxReason = snapshot.inboxReason;
        if (waitingFilesChanged) {
          this.persistTaildropInbox();
        }
      } else if (this.taildropWaitingFiles.length === 0) {
        this.taildropInboxReason = snapshot.inboxReason;
      }
      this.applyTaildropTransfer(snapshot.transfer);
      this.prefetchTaildropImage(validWaitingFiles);
    } catch (_error) {
      // The Extension may be replacing the snapshot file. Keep the previous
      // valid result and retry on the next one-second health poll.
    }
  }

  private startHealthPolling(): void {
    this.stopHealthPolling();
    this.scheduleHealthPoll(this.lifecycleGeneration);
  }

  private scheduleHealthPoll(generation: number): void {
    this.healthPollTimer = setTimeout(() => {
      if (generation !== this.lifecycleGeneration) {
        return;
      }
      const vpnIsLive: boolean = this.refreshVpnProbeStatus();
      const refresh: Promise<void> = vpnIsLive ? Promise.resolve() : this.refreshOrRecoverBackend(generation);
      refresh.finally(() => {
        if (generation === this.lifecycleGeneration) {
          this.scheduleHealthPoll(generation);
        }
      });
    }, this.taildropReceiveInProgress &&
      this.taildropReceive.state !== 'awaiting_gallery_save' &&
      this.taildropReceive.state !== 'awaiting_text_preview' ? 120 : 1000);
  }

  private async refreshOrRecoverBackend(generation: number): Promise<void> {
    // The UI backend is intentionally stopped immediately before launching the
    // VPN extension. Do not mistake that short handoff window for a killed
    // extension and start a second backend against the same state directory.
    if (this.connectInProgress || this.disconnectInProgress || this.backendRestartDeferred) {
      return;
    }
    await this.refreshBackendStatus();
    if (generation !== this.lifecycleGeneration || !this.controlServerConfirmed ||
      !this.backendStatus.startsWith('STOPPED')) {
      return;
    }
    this.recordDiagnosticEvent('backend_recovery_requested', 'vpn_process_lost');
    this.startBackend(false);
  }

  private stopHealthPolling(): void {
    if (this.healthPollTimer >= 0) {
      clearTimeout(this.healthPollTimer);
      this.healthPollTimer = -1;
    }
  }

  private isConnected(): boolean {
    return this.vpnStatus.includes('state=Running');
  }

  private isConnecting(): boolean {
    return this.connectInProgress ||
      this.vpnStatus.includes('start requested') ||
      this.vpnStatus.includes('authorization') ||
      this.vpnStatus.includes('starting');
  }

  private needsLogin(): boolean {
    return this.backendStatus.includes('NeedsLogin') ||
      this.backendStatus.includes('loginURLReady=true');
  }

  private hasConnectionProblem(): boolean {
    return this.vpnStatus.startsWith('FAILED') || this.backendStatus.startsWith('FAILED');
  }

  private isAuthenticated(): boolean {
    return this.hasAuthenticatedSession;
  }

  private isBackendLoading(): boolean {
    return this.backendInitializationVisible && !this.backendReady && !this.hasConnectionProblem();
  }

  private vpnReplaceApprovalFilePath(): string {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return `${context.filesDir}/${VPN_REPLACE_APPROVAL_FILE_NAME}`;
  }

  private writeVpnReplaceApproval(): boolean {
    let file: fileIo.File | undefined = undefined;
    try {
      file = fileIo.openSync(this.vpnReplaceApprovalFilePath(),
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, Date.now().toString());
      return true;
    } catch (_error) {
      return false;
    } finally {
      if (file !== undefined) {
        try {
          fileIo.closeSync(file);
        } catch (_error) {
          // The descriptor may already be closed after a platform write failure.
        }
      }
    }
  }

  private recordDiagnosticEvent(event: string, phase: string, code: number = 0): void {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      DiagnosticEventStore.record(context.filesDir, 'ui', event, phase, code);
    } catch (_error) {
      // Diagnostic events are best-effort and must not alter app behavior.
    }
  }

  private async generateDiagnosticReport(): Promise<void> {
    if (this.diagnosticReportInProgress) {
      return;
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.diagnosticReportInProgress = true;
    this.diagnosticReportStatus = context.resourceManager.getStringSync(
      $r('app.string.diagnostic_report_generating').id);
    this.recordDiagnosticEvent('diagnostic_report_requested', 'generate');
    const input: DiagnosticReportInput = {
      appVersion: this.appVersion,
      tailscaleVersion: this.tailscaleVersion,
      nativeStatus: this.nativeStatus,
      engineStatus: this.engineStatus,
      backendStatus: this.backendStatus,
      vpnStatus: this.vpnStatus,
      peerCount: this.peers.length,
      onlinePeerCount: this.onlinePeerCount(),
      exitNodeCount: this.exitNodes.length,
      exitNodeSelected: this.exitNodes.some((choice: ExitNodeChoice) => choice.selected),
      addressCount: this.accountSummary.addresses.length,
      signedIn: this.isAuthenticated(),
      routeAll: this.networkSettings.routeAll,
      exitNodeAllowLANAccess: this.networkSettings.exitNodeAllowLANAccess
    };
    try {
      const result: DiagnosticReportResult = await DiagnosticReportService.generate(context, input);
      const sizeKb: number = Math.max(1, Math.ceil(result.size / 1024));
      this.diagnosticReportStatus = `${result.fileName} (${sizeKb} KB)`;
      this.recordDiagnosticEvent('diagnostic_report_generated', 'share');
      await DiagnosticReportService.share(context, result);
      this.recordDiagnosticEvent('diagnostic_share_opened', 'system');
    } catch (error) {
      const businessError = error as BusinessError;
      this.recordDiagnosticEvent('diagnostic_report_failed', 'generate', businessError.code ?? -1);
      this.diagnosticReportStatus = context.resourceManager.getStringSync(
        $r('app.string.diagnostic_report_failed').id);
    } finally {
      this.diagnosticReportInProgress = false;
    }
  }

  private showVpnConflictDialog(): void {
    if (this.vpnConflictDialogVisible) {
      return;
    }
    this.vpnConflictDialogVisible = true;
    this.recordDiagnosticEvent('vpn_conflict_detected', 'connect', 2203002);
    this.clearConnectionCompletionTimer();
    this.stopConnectionPolling();
    this.setConnectInProgress(false);
    try {
      this.getUIContext().showAlertDialog({
        title: $r('app.string.vpn_conflict_title'),
        message: $r('app.string.vpn_conflict_message'),
        autoCancel: false,
        primaryButton: {
          value: $r('app.string.cancel_action'),
          action: () => this.cancelVpnReplacement()
        },
        secondaryButton: {
          value: $r('app.string.continue_action'),
          action: () => this.confirmVpnReplacement()
        }
      });
    } catch (_error) {
      this.vpnConflictDialogVisible = false;
      this.cancelVpnReplacement();
    }
  }

  private cancelVpnReplacement(): void {
    this.vpnConflictDialogVisible = false;
    this.vpnStatus = 'HarmonyOS VPN Extension stopped';
    this.recordDiagnosticEvent('vpn_replacement_cancelled', 'dialog');
    this.stopConnectionPolling();
    vpnExtension.stopVpnExtensionAbility(this.vpnWant())
      .then(() => {
        this.startBackend(false);
        this.scheduleLifecycleTask(() => this.refreshBackendStatus(), 1500);
      })
      .catch(() => {
        this.startBackend(false);
        this.scheduleLifecycleTask(() => this.refreshBackendStatus(), 1500);
      });
  }

  private confirmVpnReplacement(): void {
    this.vpnConflictDialogVisible = false;
    this.recordDiagnosticEvent('vpn_replacement_confirmed', 'dialog');
    if (!this.writeVpnReplaceApproval()) {
      this.vpnStatus = 'FAILED | VPN replacement approval | status unavailable';
      this.startBackend(false);
      this.scheduleLifecycleTask(() => this.refreshBackendStatus(), 1500);
      return;
    }
    this.clearConnectionCompletionTimer();
    this.connectionStartedAtMs = Date.now();
    this.recordDiagnosticEvent('vpn_replacement_restart_requested', 'system');
    this.setConnectInProgress(true);
    this.vpnStatus = 'Disconnecting existing VPN connection';
    vpnExtension.stopVpnExtensionAbility(this.vpnWant())
      .then(() => {
        this.scheduleLifecycleTask(() => this.requestVpnExtensionStart(), 300);
      })
      .catch(() => {
        this.scheduleLifecycleTask(() => this.requestVpnExtensionStart(), 300);
      });
  }

  private setConnectInProgress(inProgress: boolean): void {
    // Loading state must enter the component tree synchronously. Animating the
    // surrounding panel is handled by its modifier; delaying this assignment
    // can otherwise let a fast native failure skip the progress frame.
    this.connectInProgress = inProgress;
  }

  private onlinePeerCount(): number {
    return this.peers.filter((peer: PeerSummary) => peer.online).length;
  }

  private peerDeviceIcon(deviceType: string): Resource {
    if (deviceType === 'tablet') {
      return $r('app.media.device_tablet');
    }
    if (deviceType === 'phone' || deviceType === 'foldable') {
      return $r('app.media.device_phone');
    }
    return $r('app.media.device_laptop');
  }

  private localDeviceIcon(): Resource {
    return this.peerDeviceIcon(deviceInfo.deviceType);
  }

  private nodeNameSlug(value: string): string {
    return value.split('.')[0]
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '');
  }

  private localDeviceName(): string {
    const sourceName: string = this.accountSummary.deviceName.length > 0 ?
      this.accountSummary.deviceName : this.deviceModel();
    const withoutMagicDns: string = sourceName
      .replace(/(?:[.\s_-]*magicdns)(?:[.\s_-].*)?$/i, '')
      .trim();
    let nodeName: string = this.nodeNameSlug(
      withoutMagicDns.length > 0 ? withoutMagicDns : this.deviceModel());
    const brandName: string = this.nodeNameSlug(deviceInfo.brand);
    if (brandName.length > 0 && nodeName.startsWith(`${brandName}-`)) {
      nodeName = nodeName.substring(brandName.length + 1);
    }
    return nodeName.length > 0 ? nodeName : sourceName;
  }

  private displayOsName(os: string): string {
    switch (os.trim().toLowerCase()) {
      case 'android':
        return 'Android';
      case 'windows':
        return 'Windows';
      case 'linux':
        return 'Linux';
      case 'macos':
      case 'darwin':
        return 'macOS';
      case 'ios':
        return 'iOS';
      case 'chromeos':
        return 'ChromeOS';
      case 'freebsd':
        return 'FreeBSD';
      case 'harmonyos':
      case 'openharmony':
        return 'HarmonyOS';
      default:
        return os;
    }
  }

  private peerDeviceDescription(peer: PeerSummary): string {
    const osName: string = peer.os.length > 0 ? this.displayOsName(peer.os) : '';
    const osVersion: string = peer.osVersion === undefined ? '' : peer.osVersion.trim();
    if (osVersion.length > 0) {
      return osName.length > 0 ? `${osName} ${osVersion}` : osVersion;
    }
    return osName.length > 0 ? osName : peer.deviceModel;
  }

  private taildropOnlineTargetCount(): number {
    return this.displayedTaildropTargets().filter((target: TaildropTargetSummary) => target.online).length;
  }

  private displayedTaildropTargets(): TaildropTargetSummary[] {
    if (this.isConnected()) {
      return this.taildropTargets;
    }
    // Taildrop target discovery only runs inside the connected VPN backend.
    // While disconnected, mirror the same peer snapshot rendered on Home so
    // the disabled transfer list never diverges from the device list.
    return this.peers.map((peer: PeerSummary): TaildropTargetSummary => {
      return {
        key: peer.key,
        name: this.peerDisplayName(peer.name),
        os: peer.os,
        deviceModel: peer.deviceModel,
        deviceType: peer.deviceType,
        online: peer.online
      };
    });
  }

  private taildropTargetDescription(target: TaildropTargetSummary): string {
    if (target.os.length > 0) {
      return this.displayOsName(target.os);
    }
    if (target.deviceModel.length > 0) {
      return target.deviceModel;
    }
    return 'Tailscale';
  }

  private primaryTailscaleAddress(addresses: string[]): string {
    const ipv4Address: string | undefined = addresses.find((address: string) =>
      !address.includes(':'));
    if (ipv4Address !== undefined) {
      return ipv4Address;
    }
    return addresses.length > 0 ? addresses[0] : '';
  }

  private peerDisplayName(name: string): string {
    if (!name.toLowerCase().endsWith('.ts.net')) {
      return name;
    }
    const firstDot: number = name.indexOf('.');
    return firstDot > 0 ? name.substring(0, firstDot) : name;
  }

  private deviceNeedsApproval(): boolean {
    return this.accountSummary.needsApproval || this.backendStatus.includes('NeedsMachineAuth');
  }

  private keyExpiresSoon(expiryUnixMs: number): boolean {
    const remainingMs: number = expiryUnixMs - Date.now();
    return remainingMs > 0 && remainingMs <= 7 * 24 * 60 * 60 * 1000;
  }

  private keyExpiryDays(expiryUnixMs: number): number {
    return Math.max(1, Math.ceil((expiryUnixMs - Date.now()) / (24 * 60 * 60 * 1000)));
  }

  private keyExpiryLabel(keyExpired: boolean, expiryUnixMs: number): ResourceStr {
    if (keyExpired) {
      return $r('app.string.device_key_expired');
    }
    return $r('app.string.device_key_expiring', this.keyExpiryDays(expiryUnixMs));
  }

  private settingsStatusText(): string {
    return this.isConnected() ? this.vpnStatus : this.backendStatus;
  }

  private routeSettingState(): ResourceStr {
    const status: string = this.settingsStatusText();
    if (!status.includes('routeAll=')) {
      return $r('app.string.setting_unavailable');
    }
    return status.includes('routeAll=true') ? $r('app.string.setting_enabled') :
      $r('app.string.setting_disabled');
  }

  private exitNodeLANSettingState(): ResourceStr {
    const status: string = this.settingsStatusText();
    if (!status.includes('exitNodeLAN=')) {
      return $r('app.string.setting_unavailable');
    }
    return status.includes('exitNodeLAN=true') ? $r('app.string.setting_enabled') :
      $r('app.string.setting_disabled');
  }

  private exitNodeSettingState(): ResourceStr {
    const status: string = this.settingsStatusText();
    if (!status.includes('exitNode=')) {
      return $r('app.string.setting_unavailable');
    }
    return status.includes('exitNode=true') ? $r('app.string.setting_enabled') :
      $r('app.string.setting_disabled');
  }

  private connectionTitle(): ResourceStr {
    if (!this.controlServerConfirmed) {
      return $r('app.string.connection_server_required');
    }
    if (this.isBackendLoading()) {
      return $r('app.string.connection_starting');
    }
    if (this.isConnected()) {
      return $r('app.string.connection_connected');
    }
    if (this.deviceNeedsApproval()) {
      return $r('app.string.connection_approval_required');
    }
    if (this.accountSummary.keyExpired) {
      return $r('app.string.connection_key_expired');
    }
    if (this.isConnecting()) {
      return $r('app.string.connection_connecting');
    }
    if (this.hasConnectionProblem()) {
      return $r('app.string.connection_problem');
    }
    if (this.needsLogin()) {
      return $r('app.string.connection_login_required');
    }
    return $r('app.string.connection_disconnected');
  }

  private connectionDescription(): ResourceStr {
    if (!this.controlServerConfirmed) {
      return $r('app.string.description_server_required');
    }
    if (this.isBackendLoading()) {
      return $r('app.string.description_starting');
    }
    if (this.isConnected()) {
      return $r('app.string.description_connected');
    }
    if (this.deviceNeedsApproval()) {
      return $r('app.string.description_approval_required');
    }
    if (this.accountSummary.keyExpired) {
      return $r('app.string.description_key_expired');
    }
    if (this.isConnecting()) {
      return $r('app.string.description_connecting');
    }
    if (this.needsLogin()) {
      return $r('app.string.description_login_required');
    }
    if (this.hasConnectionProblem()) {
      if (this.vpnStatus.includes('code=2203002')) {
        return $r('app.string.description_vpn_conflict_problem');
      }
      if (this.backendStatus.includes('tls-error') || this.backendStatus.includes('x509')) {
        return $r('app.string.description_tls_problem');
      }
      if (this.backendStatus.includes('network-timeout') ||
        this.backendStatus.includes('connection-error') || this.backendStatus.includes('netUp=false')) {
        return $r('app.string.description_network_problem');
      }
      if (this.vpnStatus.includes('VPN start') || this.vpnStatus.includes('authorization')) {
        return $r('app.string.description_vpn_permission_problem');
      }
      if (this.vpnStatus.includes('status file')) {
        return $r('app.string.description_status_problem');
      }
      return $r('app.string.description_problem');
    }
    return $r('app.string.description_disconnected');
  }

  private connectionColor(): ResourceColor {
    if (this.isConnected()) {
      return $r('app.color.status_success');
    }
    if (this.isConnecting()) {
      return $r('app.color.status_warning');
    }
    if (this.hasConnectionProblem()) {
      return $r('app.color.status_error');
    }
    return $r('app.color.status_neutral');
  }

  private glowFilePath(): string {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return `${context.filesDir}/ui-glow-level-v2`;
  }

  private resetDiagnosticsMode(): void {
    this.diagnosticsUnlocked = false;
    this.diagnosticsExpanded = false;
    this.diagnosticsTapCount = 0;
    this.diagnosticsLastTapMs = 0;
  }

  private unlockDiagnostics(): void {
    this.diagnosticsUnlocked = true;
    this.diagnosticsExpanded = false;
  }

  private showToast(message: ResourceStr): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch (_error) {
      // Toast is immediate feedback only; failure must not block the gesture.
    }
  }

  private onAppVersionTap(): void {
    if (this.diagnosticsUnlocked) {
      this.showToast('您已进入工程模式');
      return;
    }
    const nowMs: number = Date.now();
    if (nowMs - this.diagnosticsLastTapMs > 1500) {
      this.diagnosticsTapCount = 0;
    }
    this.diagnosticsLastTapMs = nowMs;
    this.diagnosticsTapCount += 1;
    if (this.diagnosticsTapCount >= 5) {
      this.diagnosticsTapCount = 0;
      this.unlockDiagnostics();
      this.showToast('您已进入工程模式');
      return;
    }
    const remainingCount: number = 5 - this.diagnosticsTapCount;
    this.showToast(`再点击${remainingCount}次即可进入工程诊断`);
  }

  private loadGlowLevel(): void {
    try {
      const path: string = this.glowFilePath();
      if (!fileIo.accessSync(path)) {
        return;
      }
      const level: number = Number(fileIo.readTextSync(path));
      if (level >= 0 && level <= 3) {
        this.glowLevel = level;
      }
    } catch (_error) {
      this.glowLevel = 3;
    }
  }

  private setGlowLevel(level: number): void {
    if (level < 0 || level > 3) {
      return;
    }
    this.glowLevel = level;
    try {
      const file = fileIo.openSync(this.glowFilePath(),
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, level.toString());
      fileIo.closeSync(file);
    } catch (_error) {
      // Visual preferences are best-effort and never affect VPN behavior.
    }
  }

  private glowRadius(): number {
    return this.glowLevel === 0 ? 28 : (this.glowLevel === 1 ? 18 : 10);
  }

  private glowColor(): ResourceColor {
    return $r('sys.color.comp_background_emphasize');
  }

  private glowSurface(): ResourceColor {
    return $r('sys.color.comp_background_tertiary');
  }

  private glowMaskColor(): ResourceColor {
    return $r('sys.color.background_primary');
  }

  private glowLightColor(): ResourceColor {
    return $r('sys.color.comp_background_emphasize');
  }

  private glowSaturation(): number {
    return this.glowLevel === 0 ? 1.38 : (this.glowLevel === 1 ? 1.2 : 1.05);
  }

  private glowBrightness(): number {
    return this.glowLevel === 0 ? 1.12 : (this.glowLevel === 1 ? 1.07 : 1.02);
  }

  private glowMaterialLevel(): hdsMaterial.MaterialLevel {
    if (this.glowLevel === 0) {
      return hdsMaterial.MaterialLevel.EXQUISITE;
    }
    if (this.glowLevel === 1) {
      return hdsMaterial.MaterialLevel.GENTLE;
    }
    if (this.glowLevel === 2) {
      return hdsMaterial.MaterialLevel.SMOOTH;
    }
    return hdsMaterial.MaterialLevel.ADAPTIVE;
  }

  private glowLevelDescription(): ResourceStr {
    if (this.glowLevel === 0) {
      return $r('app.string.glow_exquisite_description');
    }
    if (this.glowLevel === 1) {
      return $r('app.string.glow_gentle_description');
    }
    if (this.glowLevel === 2) {
      return $r('app.string.glow_smooth_description');
    }
    return $r('app.string.glow_adaptive_description');
  }

  private glowLevelLabel(): ResourceStr {
    if (this.glowLevel === 0) {
      return $r('app.string.glow_exquisite');
    }
    if (this.glowLevel === 1) {
      return $r('app.string.glow_gentle');
    }
    if (this.glowLevel === 2) {
      return $r('app.string.glow_smooth');
    }
    return $r('app.string.glow_adaptive');
  }

  private isWideNavigation(): boolean {
    return this.layoutWidth >= 840;
  }

  private pageMargin(): number {
    if (this.layoutWidth >= 840) {
      return 32;
    }
    if (this.layoutWidth >= 600) {
      return 24;
    }
    return 16;
  }

  private contentMargin(): number {
    return this.pageMargin() + 8;
  }

  private pageBottomInset(): number {
    return this.isWideNavigation() ? 32 : 120;
  }

  private groupBackground(): ResourceColor {
    return $r('sys.color.comp_background_primary');
  }

  private isPeerNameExpanded(peerKey: string): boolean {
    return this.expandedPeerKeys.includes(peerKey);
  }

  private togglePeerName(peerKey: string): void {
    this.getUIContext().animateTo({ duration: 260, curve: Curve.EaseInOut }, () => {
      if (this.isPeerNameExpanded(peerKey)) {
        this.expandedPeerKeys = this.expandedPeerKeys.filter((key: string) => key !== peerKey);
        return;
      }
      this.expandedPeerKeys = this.expandedPeerKeys.concat(peerKey);
    });
  }

  private async loadConnectedHomeLayoutPreference(context: common.Context): Promise<void> {
    this.connectedHomeLayoutMode = await HomeLayoutPreferences.load(context);
  }

  private setConnectedHomeLayoutMode(mode: ConnectedHomeLayoutMode): void {
    if (this.connectedHomeLayoutMode === mode) {
      return;
    }
    this.getUIContext().animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
      this.connectedHomeLayoutMode = mode;
    });
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    HomeLayoutPreferences.save(context, mode).catch(() => {
      // The layout is still changed for this session when persistence is unavailable.
    });
  }

  private connectedHomeLayoutActive(): boolean {
    return this.isConnected() || this.disconnectInProgress ||
      (this.isConnecting() && this.trafficSession > 0);
  }

  private selectedExitNodeName(): string {
    const selected: ExitNodeChoice | undefined = this.exitNodes.find(
      (choice: ExitNodeChoice) => choice.selected);
    return selected === undefined ? '' : selected.name;
  }

  private connectedDurationLabel(): string {
    if (this.connectionStartedAtMs <= 0) {
      return '\u521A\u521A\u8FDE\u63A5';
    }
    const elapsedSeconds: number = Math.max(0, Math.floor((Date.now() - this.connectionStartedAtMs) / 1000));
    const hours: number = Math.floor(elapsedSeconds / 3600);
    const minutes: number = Math.floor((elapsedSeconds % 3600) / 60);
    const seconds: number = elapsedSeconds % 60;
    if (hours > 0) {
      return `${hours} \u5C0F\u65F6 ${minutes} \u5206\u949F`;
    }
    if (minutes > 0) {
      return `${minutes} \u5206\u949F ${seconds} \u79D2`;
    }
    return `${seconds} 秒`;
  }

  private openConnectionDetails(): void {
    if (this.connectedHomeLayoutActive()) {
      this.connectionDetailsVisible = true;
    }
  }

  private showExitNodeConnectionHint(): void {
    this.showToast('\u8FDE\u63A5\u671F\u95F4\u4E0D\u53EF\u66F4\u6539\u51FA\u53E3\u8282\u70B9\uFF0C\u8BF7\u65AD\u5F00\u540E\u5728\u4E3B\u9875\u9009\u62E9\u3002');
  }

  private togglePeer(peer: PeerSummary): void {
    if (!peer.online && !this.isPeerNameExpanded(peer.key)) {
      return;
    }
    const opening: boolean = !this.isPeerNameExpanded(peer.key);
    this.togglePeerName(peer.key);
    if (opening && this.isSunshineCandidate(peer)) {
      this.detectStreamingForPeer(peer, false);
    }
  }

  private refreshPeerServices(peer: PeerSummary): void {
    if (this.isSunshineCandidate(peer)) {
      this.detectStreamingForPeer(peer, true);
    }
    this.detectMediaForPeer(peer, true);
  }

  private autoProbeConnectedPeerServices(): void {
    if (!this.isConnected()) {
      return;
    }
    const session: number = Math.max(1, this.trafficSession);
    this.peers.filter((peer: PeerSummary) => peer.online && peer.addresses.length > 0)
      .forEach((peer: PeerSummary) => {
        if (this.autoProbedPeerSessions.get(peer.key) === session) {
          return;
        }
        this.autoProbedPeerSessions.set(peer.key, session);
        if (this.isSunshineCandidate(peer)) {
          this.detectStreamingForPeer(peer, false);
        }
        this.detectMediaForPeer(peer, false);
      });
  }

  private isSunshineCandidate(peer: PeerSummary): boolean {
    if (!peer.online || peer.addresses.length === 0) {
      return false;
    }
    const os: string = peer.os.toLowerCase();
    return os.includes('windows') || os.includes('linux') || os.includes('macos') || os.includes('darwin');
  }

  private streamingState(peerKey: string): DeviceStreamingState {
    const existing: DeviceStreamingState | undefined = this.streamingStates.find(
      (state: DeviceStreamingState) => state.peerKey === peerKey);
    if (existing !== undefined) {
      return existing;
    }
    return {
      peerKey: peerKey,
      sunshine: { state: 'unknown', checkedAt: 0 },
      path: { type: 'unknown', checkedAt: 0 },
      checking: false,
      launching: false
    };
  }

  private copyStreamingState(state: DeviceStreamingState, sunshine?: SunshineProbeResult,
    path?: PeerPathResult, checking?: boolean, launching?: boolean): DeviceStreamingState {
    return {
      peerKey: state.peerKey,
      sunshine: sunshine === undefined ? state.sunshine : sunshine,
      path: path === undefined ? state.path : path,
      checking: checking === undefined ? state.checking : checking,
      launching: launching === undefined ? state.launching : launching
    };
  }

  private updateStreamingState(peerKey: string, update: DeviceStreamingState): void {
    const index: number = this.streamingStates.findIndex(
      (state: DeviceStreamingState) => state.peerKey === peerKey);
    if (index < 0) {
      this.streamingStates = this.streamingStates.concat(update);
      return;
    }
    const next: DeviceStreamingState[] = this.streamingStates.slice();
    next[index] = update;
    this.streamingStates = next;
  }

  private resetStreamingStatesForDisconnect(): void {
    this.streamingRequestIds.clear();
    this.mediaRequestIds.clear();
    this.autoProbedPeerSessions.clear();
    this.sunshineProbeService?.clearCache();
    this.peerPathService?.clearCache();
    this.mediaServiceProbeService?.clearCache();
    this.streamingStates = this.streamingStates.map((state: DeviceStreamingState) =>
      this.copyStreamingState(state,
        { state: 'unknown', checkedAt: Date.now(), errorMessage: 'mesh_disconnected' },
        { type: 'unknown', checkedAt: Date.now(), errorMessage: 'mesh_disconnected' }, false, false));
    this.mediaStates = this.mediaStates.map((state: DeviceMediaState): DeviceMediaState => {
      const result: MediaProbeResult = {
        state: 'unknown',
        checkedAt: Date.now(),
        services: [],
        errorMessage: 'mesh_disconnected'
      };
      const updated: DeviceMediaState = {
        peerKey: state.peerKey,
        result: result,
        checking: false,
        launching: false
      };
      return updated;
    });
  }

  private ensureStreamingServices(): void {
    if (this.sunshineProbeService !== undefined && this.peerPathService !== undefined &&
      this.moonlightLauncher !== undefined) {
      return;
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.sunshineProbeService = new SunshineProbeService(context);
    this.peerPathService = new PeerPathService(context);
    this.moonlightLauncher = new MoonlightLauncher(context);
  }

  private ensureMediaServices(): void {
    if (this.mediaServiceProbeService !== undefined && this.hosPlayerLauncher !== undefined) {
      return;
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.mediaServiceProbeService = new MediaServiceProbeService(context);
    this.hosPlayerLauncher = new HosPlayerLauncher(context);
  }

  private mediaState(peerKey: string): DeviceMediaState {
    if (this.fakeMediaServiceOnline) {
      const peer: PeerSummary | undefined = this.peers.find((item: PeerSummary) => item.key === peerKey);
      const host: string = peer === undefined ? '100.64.0.1' :
        this.primaryTailscaleAddress(peer.addresses);
      return {
        peerKey: peerKey,
        result: {
          state: 'available',
          checkedAt: Date.now(),
          services: [{
            type: 'jellyfin',
            name: 'Jellyfin（工程伪装）',
            url: `http://${host.length > 0 ? host : '100.64.0.1'}:8096`,
            latencyMs: 1
          }]
        },
        checking: false,
        launching: false
      };
    }
    const existing: DeviceMediaState | undefined = this.mediaStates.find(
      (state: DeviceMediaState) => state.peerKey === peerKey);
    if (existing !== undefined) {
      return existing;
    }
    return {
      peerKey: peerKey,
      result: { state: 'unknown', checkedAt: 0, services: [] },
      checking: false,
      launching: false
    };
  }

  private mediaServiceNames(peerKey: string): string {
    return this.mediaState(peerKey).result.services.map((service: DiscoveredMediaService) => {
      if (service.type === 'jellyfin') return 'Jellyfin';
      if (service.type === 'emby') return 'Emby';
      if (service.type === 'plex') return 'Plex';
      if (service.type === 'webdav') return 'WebDAV';
      return 'SMB';
    }).join(' · ');
  }

  private peerServiceBadgesVisible(peer: PeerSummary): boolean {
    const sunshineState: string = this.streamingState(peer.key).sunshine.state;
    return sunshineState === 'checking' || sunshineState === 'available' ||
      this.mediaState(peer.key).checking || this.mediaServiceNames(peer.key).length > 0;
  }

  private updateMediaState(peerKey: string, update: DeviceMediaState): void {
    const index: number = this.mediaStates.findIndex(
      (state: DeviceMediaState) => state.peerKey === peerKey);
    if (index < 0) {
      this.mediaStates = this.mediaStates.concat(update);
      return;
    }
    const next: DeviceMediaState[] = this.mediaStates.slice();
    next[index] = update;
    this.mediaStates = next;
  }

  private detectMediaForPeer(peer: PeerSummary, force: boolean): void {
    if (!peer.online || peer.addresses.length === 0 || !this.isConnected()) {
      this.showToast('请先连接 MeshArc，并确认目标设备在线。');
      return;
    }
    this.ensureMediaServices();
    this.ensureStreamingServices();
    const requestId: number = Date.now();
    this.mediaRequestIds.set(peer.key, requestId);
    const previous: DeviceMediaState = this.mediaState(peer.key);
    this.updateMediaState(peer.key, {
      peerKey: peer.key,
      result: {
        state: 'checking',
        checkedAt: Date.now(),
        services: previous.result.services
      },
      checking: true,
      launching: previous.launching
    });
    this.recordDiagnosticEvent('media_probe_start', 'requested');
    Promise.all([
      this.mediaServiceProbeService!.probe(peer.key, true, force),
      this.peerPathService!.probe(peer.key, true, force)
    ]).then((results: [MediaProbeResult, PeerPathResult]) => {
      if (this.mediaRequestIds.get(peer.key) !== requestId || !this.isConnected()) {
        return;
      }
      const currentPeer: PeerSummary | undefined = this.peers.find(
        (item: PeerSummary) => item.key === peer.key && item.online);
      if (currentPeer === undefined) {
        return;
      }
      const mediaResult: MediaProbeResult = results[0];
      const path: PeerPathResult = results[1];
      const streamState: DeviceStreamingState = this.streamingState(peer.key);
      this.updateStreamingState(peer.key,
        this.copyStreamingState(streamState, undefined, path, false, false));
      this.updateMediaState(peer.key, {
        peerKey: peer.key,
        result: mediaResult,
        checking: false,
        launching: false
      });
      this.recordDiagnosticEvent(mediaResult.services.length > 0 ?
        'media_probe_success' : 'media_probe_no_service', path.type);
      mediaResult.services.forEach((service: DiscoveredMediaService) => {
        this.recordDiagnosticEvent('media_service_detected', service.type);
      });
    }).catch(() => {
      if (this.mediaRequestIds.get(peer.key) !== requestId) {
        return;
      }
      this.updateMediaState(peer.key, {
        peerKey: peer.key,
        result: {
          state: 'error',
          checkedAt: Date.now(),
          services: [],
          errorMessage: 'probe_failed'
        },
        checking: false,
        launching: false
      });
      this.recordDiagnosticEvent('media_probe_failed', 'exception');
    });
  }

  private detectStreamingForPeer(peer: PeerSummary, force: boolean): void {
    if (!this.isSunshineCandidate(peer) || !this.isConnected()) {
      return;
    }
    this.ensureStreamingServices();
    const requestId: number = Date.now();
    this.streamingRequestIds.set(peer.key, requestId);
    const previous: DeviceStreamingState = this.streamingState(peer.key);
    const checkingPath: PeerPathResult = {
      type: previous.path.type,
      latencyMs: previous.path.latencyMs,
      relayRegion: previous.path.relayRegion,
      checkedAt: Date.now(),
      errorMessage: previous.path.errorMessage
    };
    this.updateStreamingState(peer.key, this.copyStreamingState(previous,
      { state: 'checking', checkedAt: Date.now() }, checkingPath, true));
    const host: string = this.primaryTailscaleAddress(peer.addresses);
    Promise.all([
      this.sunshineProbeService!.probe(peer.key, host, true, force),
      this.peerPathService!.probe(peer.key, true, force)
    ]).then((results: [SunshineProbeResult, PeerPathResult]) => {
      const sunshine: SunshineProbeResult = results[0];
      const path: PeerPathResult = results[1];
      const currentPeer: PeerSummary | undefined = this.peers.find((item: PeerSummary) => item.key === peer.key);
      if (this.streamingRequestIds.get(peer.key) !== requestId || currentPeer === undefined || !currentPeer.online ||
        !this.isConnected()) {
        return;
      }
      const current: DeviceStreamingState = this.streamingState(peer.key);
      this.updateStreamingState(peer.key, this.copyStreamingState(current, sunshine, path, false));
      this.recordDiagnosticEvent(sunshine.state === 'available' ? 'sunshine_probe_success' :
        sunshine.state === 'timeout' ? 'sunshine_probe_timeout' : 'sunshine_probe_failed', sunshine.state);
      this.recordDiagnosticEvent('peer_path_result', path.type);
    }).catch(() => {
      if (this.streamingRequestIds.get(peer.key) !== requestId) {
        return;
      }
      const current: DeviceStreamingState = this.streamingState(peer.key);
      this.updateStreamingState(peer.key, this.copyStreamingState(current,
        { state: 'error', checkedAt: Date.now(), errorMessage: 'probe_failed' },
        { type: 'unknown', checkedAt: Date.now(), errorMessage: 'probe_failed' }, false));
      this.recordDiagnosticEvent('sunshine_probe_failed', 'exception');
    });
    this.recordDiagnosticEvent('sunshine_probe_start', 'requested');
    this.recordDiagnosticEvent('peer_path_probe_start', 'requested');
  }

  private streamReachable(state: DeviceStreamingState): boolean {
    return state.path.type !== 'unreachable';
  }

  private sendFileToPeer(peer: PeerSummary): void {
    const target: TaildropTargetSummary | undefined = this.taildropTargets.find(
      (item: TaildropTargetSummary) => item.key === peer.key && item.online);
    if (target === undefined) {
      this.showToast($r('app.string.transfer_send_target_unavailable'));
      return;
    }
    this.selectTaildropDocuments(target).catch(() => this.handleTaildropSelectionFailure());
  }

  private launchRemoteStream(peer: PeerSummary): void {
    if (!this.isConnected()) {
      this.showToast('请先连接 MeshArc，再使用远程串流。');
      return;
    }
    if (!peer.online) {
      this.showToast('目标设备当前离线。');
      return;
    }
    const state: DeviceStreamingState = this.streamingState(peer.key);
    if (state.launching) {
      return;
    }
    this.updateStreamingState(peer.key, this.copyStreamingState(state, undefined, undefined, undefined, true));
    this.detectStreamingForPeer(peer, true);
    const launchStartedAt: number = Date.now();
    const waitForProbe = (): void => {
      const latest: DeviceStreamingState = this.streamingState(peer.key);
      if (latest.checking) {
        if (!this.isConnected() || Date.now() - launchStartedAt > 5000) {
          this.updateStreamingState(peer.key, this.copyStreamingState(latest, undefined, undefined, false, false));
          this.showToast('Sunshine 检测超时，请检查目标电脑防火墙或网络状态。');
          return;
        }
        setTimeout(waitForProbe, 120);
        return;
      }
      this.completeStreamLaunch(peer, latest);
    };
    setTimeout(waitForProbe, 0);
  }

  private completeStreamLaunch(peer: PeerSummary, state: DeviceStreamingState): void {
    if (state.sunshine.state !== 'available') {
      this.updateStreamingState(peer.key, this.copyStreamingState(state, undefined, undefined, undefined, false));
      this.showToast(state.sunshine.state === 'timeout' ? 'Sunshine 检测超时，请检查目标电脑防火墙或网络状态。' :
        '未检测到可用的 Sunshine 服务，请确认电脑已启动 Sunshine。');
      return;
    }
    if (!this.streamReachable(state)) {
      this.updateStreamingState(peer.key, this.copyStreamingState(state, undefined, undefined, undefined, false));
      this.showToast('当前无法访问目标设备。');
      return;
    }
    if (state.path.type === 'derp') {
      this.showDerpStreamConfirmation(peer, state);
      return;
    }
    this.openMoonlight(peer, state, false);
  }

  private showDerpStreamConfirmation(peer: PeerSummary, state: DeviceStreamingState): void {
    this.getUIContext().showAlertDialog({
      title: '当前通过 DERP 中继连接',
      message: '中继连接可能导致延迟升高或画面卡顿。MeshArc 将建议 MoonlightOH 使用较低码率。',
      autoCancel: true,
      primaryButton: { value: '使用兼容配置', action: () => this.openMoonlight(peer, state, false) },
      secondaryButton: { value: '使用原有配置', action: () => this.openMoonlight(peer, state, true) }
    });
  }

  private openMoonlight(peer: PeerSummary, state: DeviceStreamingState, useOriginalProfile: boolean): void {
    this.ensureStreamingServices();
    const host: string = this.primaryTailscaleAddress(peer.addresses);
    this.recordDiagnosticEvent('moonlight_launch_attempt', state.path.type);
    this.moonlightLauncher!.isAvailable().then((available: boolean) => {
      if (!available) {
        this.updateStreamingState(peer.key, this.copyStreamingState(this.streamingState(peer.key),
          undefined, undefined, undefined, false));
        this.getUIContext().showAlertDialog({
          title: '需要 MoonlightOH',
          message: 'MeshArc 使用 MoonlightOH 连接 Sunshine 串流服务。',
          autoCancel: true,
          primaryButton: { value: '取消', action: () => {} },
          secondaryButton: { value: '复制主机地址', action: () => this.copyDeviceValue(host, $r('app.string.peer_ip_copied')) }
        });
        return;
      }
      const originalProfile: StreamLaunchProfile = { profileName: 'default', allowUserOverride: true };
      const profile = useOriginalProfile ? originalProfile : buildStreamProfile(state.path);
      return this.moonlightLauncher!.launch({
        protocolVersion: 1,
        action: 'openHost',
        source: 'MeshArc',
        host: host,
        displayName: peer.name,
        dnsName: peer.name,
        pathType: state.path.type,
        relayRegion: state.path.relayRegion,
        latencyMs: state.path.latencyMs,
        streamProfile: profile
      }).then(() => {
        this.updateStreamingState(peer.key, this.copyStreamingState(this.streamingState(peer.key),
          undefined, undefined, undefined, false));
        this.recordDiagnosticEvent('moonlight_launch_success', state.path.type);
      });
    }).catch(() => {
      this.updateStreamingState(peer.key, this.copyStreamingState(this.streamingState(peer.key),
        undefined, undefined, undefined, false));
      this.recordDiagnosticEvent('moonlight_launch_failed', state.path.type);
      this.showToast('无法打开 MoonlightOH，请稍后重试。');
    });
  }

  private launchMediaForPeer(peer: PeerSummary): void {
    const state: DeviceMediaState = this.mediaState(peer.key);
    if (state.checking || state.launching) {
      return;
    }
    if (state.result.services.length === 0) {
      this.detectMediaForPeer(peer, true);
      return;
    }
    const service: DiscoveredMediaService = state.result.services[0];
    this.openHosPlayer(peer, service);
  }

  private openHosPlayer(peer: PeerSummary, service: DiscoveredMediaService): void {
    this.ensureMediaServices();
    const state: DeviceMediaState = this.mediaState(peer.key);
    const path: PeerPathResult = this.streamingState(peer.key).path;
    this.updateMediaState(peer.key, {
      peerKey: peer.key,
      result: state.result,
      checking: false,
      launching: true
    });
    this.recordDiagnosticEvent('hosplayer_launch_attempt', service.type);
    try {
      const request: HosPlayerLaunchRequest = {
        protocolVersion: 1,
        action: 'add',
        type: service.type,
        url: service.url,
        name: `${this.peerDisplayName(peer.name)} · ${service.name}`,
        network: 'tailnet',
        route: path.type,
        source: 'mesharc'
      };
      const prototypeUri: string = this.hosPlayerLauncher!.buildUri(request);
      if (!this.hosPlayerLauncher!.isEnabled()) {
        this.updateMediaState(peer.key, {
          peerKey: peer.key,
          result: state.result,
          checking: false,
          launching: false
        });
        this.recordDiagnosticEvent('hosplayer_contract_previewed', service.type);
        this.getUIContext().showAlertDialog({
          title: 'HosPlayer 联动协议原型',
          message: `已识别 ${service.name}。当前原型会传递服务类型、服务器地址、设备名称和网络路径；` +
            '不包含用户名、密码或访问令牌。等待 HosPlayer 发布正式接收协议后即可直接拉起。',
          autoCancel: true,
          primaryButton: { value: '关闭', action: () => {} },
          secondaryButton: {
            value: '复制参数链接',
            action: () => this.copyPlainText(prototypeUri, 'HosPlayer 参数原型已复制')
          }
        });
        return;
      }
      this.hosPlayerLauncher!.launch(request).then(() => {
        this.updateMediaState(peer.key, {
          peerKey: peer.key,
          result: this.mediaState(peer.key).result,
          checking: false,
          launching: false
        });
        this.recordDiagnosticEvent('hosplayer_launch_success', service.type);
      }).catch(() => {
        this.updateMediaState(peer.key, {
          peerKey: peer.key,
          result: this.mediaState(peer.key).result,
          checking: false,
          launching: false
        });
        this.recordDiagnosticEvent('hosplayer_launch_failed', service.type);
        this.showToast('无法打开 HosPlayer，请稍后重试。');
      });
    } catch (_error) {
      this.updateMediaState(peer.key, {
        peerKey: peer.key,
        result: state.result,
        checking: false,
        launching: false
      });
      this.recordDiagnosticEvent('hosplayer_contract_rejected', service.type);
      this.showToast('服务器地址不符合安全传参规则。');
    }
  }

  private copyPlainText(value: string, successMessage: string): void {
    const data: pasteboard.PasteData = pasteboard.createData(
      pasteboard.MIMETYPE_TEXT_PLAIN, value);
    pasteboard.getSystemPasteboard().setData(data)
      .then(() => this.showToast(successMessage))
      .catch(() => this.showToast($r('app.string.device_copy_failed')));
  }

  private runMediaIntegrationSelfTest(): void {
    if (this.mediaSelfTestInProgress) {
      return;
    }
    this.ensureMediaServices();
    this.mediaSelfTestInProgress = true;
    this.mediaSelfTestStatus = '正在运行离线测试…';
    this.recordDiagnosticEvent('media_self_test_started', 'offline');
    nativeBridge.mediaProbeSelfTestAsync().then((resultText: string) => {
      const nativeResult: MediaProbeSelfTestResult =
        JSON.parse(resultText) as MediaProbeSelfTestResult;
      const contractResult: string = this.hosPlayerLauncher!.runOfflineSelfTest();
      const passed: boolean = nativeResult.state === 'passed' &&
        nativeResult.cases === 4 && contractResult.startsWith('PASS');
      this.mediaSelfTestStatus = passed ?
        'PASS · 媒体服务识别 4/4 · HosPlayer 参数协议通过' :
        'FAILED · 请导出诊断报告并检查媒体联动日志';
      this.recordDiagnosticEvent(passed ? 'media_self_test_passed' :
        'media_self_test_failed', 'offline');
    }).catch(() => {
      this.mediaSelfTestStatus = 'FAILED · 无法运行媒体服务离线测试';
      this.recordDiagnosticEvent('media_self_test_failed', 'native_bridge');
    }).finally(() => {
      this.mediaSelfTestInProgress = false;
    });
  }

  private copyHosPlayerPrototype(): void {
    this.ensureMediaServices();
    try {
      const result: string = this.hosPlayerLauncher!.runOfflineSelfTest();
      const separator: number = result.indexOf(' | ');
      if (separator < 0) {
        throw new Error('prototype_unavailable');
      }
      this.copyPlainText(result.substring(separator + 3), 'HosPlayer 参数原型已复制');
      this.recordDiagnosticEvent('hosplayer_contract_copied', 'offline');
    } catch (_error) {
      this.showToast('无法生成 HosPlayer 参数原型。');
      this.recordDiagnosticEvent('hosplayer_contract_failed', 'offline');
    }
  }

  private copyDeviceValue(value: string, successMessage: ResourceStr): void {
    if (value.length === 0) {
      this.showToast($r('app.string.device_copy_unavailable'));
      return;
    }
    const data: pasteboard.PasteData = pasteboard.createData(
      pasteboard.MIMETYPE_TEXT_PLAIN, value);
    pasteboard.getSystemPasteboard().setData(data)
      .then(() => this.showToast(successMessage))
      .catch(() => this.showToast($r('app.string.device_copy_failed')));
  }

  private peerConnectivityFilePath(fileName: string): string {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return `${context.filesDir}/${fileName}`;
  }

  private writePrivateTextFile(path: string, content: string): boolean {
    let file: fileIo.File | undefined = undefined;
    try {
      file = fileIo.openSync(path,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, content);
      return true;
    } catch (_error) {
      return false;
    } finally {
      if (file !== undefined) {
        try {
          fileIo.closeSync(file);
        } catch (_error) {
          // The descriptor may already be closed after a platform write failure.
        }
      }
    }
  }

  private taildropTransferProgress(): number {
    if (this.taildropTransfer.totalBytes <= 0) {
      return this.taildropTransfer.state === 'completed' ? 100 : 0;
    }
    return Math.max(0, Math.min(100,
      Math.round(this.taildropTransfer.bytesSent * 100 / this.taildropTransfer.totalBytes)));
  }

  private resetTaildropProgressEstimate(): void {
    this.taildropTransferRate = 0;
    this.taildropTransferEtaSeconds = 0;
    this.taildropProgressSampleRequestId = 0;
    this.taildropProgressSampleBytes = 0;
    this.taildropProgressSampleMs = 0;
  }

  private updateTaildropProgressEstimate(transfer: TaildropTransferSummary): void {
    const active: boolean = transfer.state === 'queued' || transfer.state === 'sending';
    if (!active || transfer.requestId <= 0 || transfer.totalBytes <= 0) {
      this.resetTaildropProgressEstimate();
      return;
    }
    const nowMs: number = Date.now();
    if (transfer.requestId !== this.taildropProgressSampleRequestId ||
      transfer.bytesSent < this.taildropProgressSampleBytes || this.taildropProgressSampleMs <= 0) {
      this.taildropProgressSampleRequestId = transfer.requestId;
      this.taildropProgressSampleBytes = transfer.bytesSent;
      this.taildropProgressSampleMs = nowMs;
      this.taildropTransferRate = 0;
      this.taildropTransferEtaSeconds = 0;
      return;
    }
    const elapsedMs: number = nowMs - this.taildropProgressSampleMs;
    if (elapsedMs < 500) {
      return;
    }
    const byteDelta: number = transfer.bytesSent - this.taildropProgressSampleBytes;
    if (byteDelta <= 0) {
      if (elapsedMs >= 3000) {
        this.taildropTransferRate = 0;
        this.taildropTransferEtaSeconds = 0;
        this.taildropProgressSampleMs = nowMs;
      }
      return;
    }
    const measuredRate: number = Math.round(byteDelta * 1000 / elapsedMs);
    this.taildropTransferRate = this.taildropTransferRate > 0 ?
      Math.round(this.taildropTransferRate * 0.55 + measuredRate * 0.45) : measuredRate;
    const remainingBytes: number = Math.max(0, transfer.totalBytes - transfer.bytesSent);
    this.taildropTransferEtaSeconds = this.taildropTransferRate > 0 ?
      Math.ceil(remainingBytes / this.taildropTransferRate) : 0;
    this.taildropProgressSampleBytes = transfer.bytesSent;
    this.taildropProgressSampleMs = nowMs;
  }

  private formatTransferDuration(seconds: number): string {
    const safeSeconds: number = Math.max(0, Math.round(seconds));
    if (safeSeconds < 60) {
      return `${safeSeconds}s`;
    }
    const minutes: number = Math.floor(safeSeconds / 60);
    const remainingSeconds: number = safeSeconds % 60;
    if (minutes < 60) {
      return `${minutes}m ${remainingSeconds.toString().padStart(2, '0')}s`;
    }
    const hours: number = Math.floor(minutes / 60);
    const remainingMinutes: number = minutes % 60;
    return `${hours}h ${remainingMinutes.toString().padStart(2, '0')}m`;
  }

  private taildropTransferSpeedText(): ResourceStr {
    if (this.taildropPreparing || this.taildropTransfer.state === 'queued') {
      return $r('app.string.transfer_waiting_for_backend');
    }
    if (this.taildropTransferRate <= 0 || this.taildropTransferEtaSeconds <= 0) {
      return $r('app.string.transfer_calculating_speed');
    }
    return $r('app.string.transfer_speed_eta',
      this.formatTrafficBytes(this.taildropTransferRate, true),
      this.formatTransferDuration(this.taildropTransferEtaSeconds));
  }

  private taildropActiveReceiveText(): ResourceStr {
    if (this.taildropReceive.action === 'clear') {
      return $r('app.string.transfer_clearing_cache');
    }
    if (this.taildropReceive.state === 'awaiting_gallery_save') {
      return $r('app.string.transfer_media_ready_title');
    }
    if (this.taildropReceive.state === 'saving_gallery') {
      return $r('app.string.transfer_media_saving');
    }
    if (this.taildropReceiveStrategy === 'discard') {
      return $r('app.string.transfer_discarding_file');
    }
    if (this.taildropReceiveStrategy === 'image') {
      return $r('app.string.transfer_saving_image');
    }
    if (this.taildropReceiveStrategy === 'text') {
      return $r('app.string.transfer_copying_text');
    }
    return $r('app.string.transfer_receiving_file');
  }

  private taildropFileExtension(name: string): string {
    const dotIndex: number = name.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex === name.length - 1) {
      return '';
    }
    return name.substring(dotIndex + 1).toLowerCase();
  }

  private taildropFileTitle(name: string): string {
    const dotIndex: number = name.lastIndexOf('.');
    return dotIndex > 0 ? name.substring(0, dotIndex) : name;
  }

  private taildropGalleryAssetTitle(name: string): string {
    let title: string = this.taildropFileTitle(this.sanitizeTaildropFileName(name, 0))
      .replace(/[\\/:*?"'`<>|{}\[\]]/g, '_').trim();
    if (title.length === 0 || title === '.' || title === '..') {
      title = 'received_image';
    }
    return title.length > 180 ? title.substring(0, 180) : title;
  }

  private taildropContentKind(file: TaildropWaitingFileSummary): string {
    const extension: string = this.taildropFileExtension(file.name);
    if (TAILDROP_IMAGE_EXTENSIONS.includes(extension)) {
      return 'image';
    }
    if (file.size <= TAILDROP_TEXT_CLIPBOARD_MAX_BYTES && TAILDROP_TEXT_EXTENSIONS.includes(extension)) {
      return 'text';
    }
    return 'file';
  }

  private taildropContentKindText(file: TaildropWaitingFileSummary): ResourceStr {
    const kind: string = this.taildropContentKind(file);
    if (kind === 'image') {
      return $r('app.string.transfer_content_image');
    }
    if (kind === 'text') {
      return $r('app.string.transfer_content_text');
    }
    return $r('app.string.transfer_content_file');
  }

  private taildropReceiveActionText(file: TaildropWaitingFileSummary): ResourceStr {
    const kind: string = this.taildropContentKind(file);
    if (kind === 'image') {
      return $r('app.string.transfer_save_to_gallery_action');
    }
    if (kind === 'text') {
      return $r('app.string.transfer_copy_text_action');
    }
    return $r('app.string.transfer_save_action');
  }

  private taildropFileSymbol(name: string): Resource {
    const extension: string = this.taildropFileExtension(name);
    if (TAILDROP_IMAGE_EXTENSIONS.includes(extension)) {
      return $r('sys.symbol.picture');
    }
    if (TAILDROP_VIDEO_EXTENSIONS.includes(extension)) {
      return $r('sys.symbol.video');
    }
    if (TAILDROP_TEXT_EXTENSIONS.includes(extension)) {
      return $r('sys.symbol.doc_plaintext');
    }
    if (extension === 'pdf') {
      return $r('sys.symbol.pdf_doc');
    }
    if (['zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz'].includes(extension)) {
      return $r('sys.symbol.doc_zipper');
    }
    if (extension === 'hap' || extension === 'hsp' || extension === 'har' ||
      extension === 'app' || extension === 'apk') {
      return $r('sys.symbol.archivebox');
    }
    return $r('sys.symbol.doc');
  }

  private taildropReceiveMatches(file: TaildropWaitingFileSummary): boolean {
    return this.taildropReceiveInProgress && this.taildropReceive.name === file.name;
  }

  private taildropReceiveRowLoading(file: TaildropWaitingFileSummary): boolean {
    if (!this.taildropReceiveMatches(file)) {
      return false;
    }
    if (this.taildropReceiveStrategy === 'media-prefetch') {
      return false;
    }
    return this.taildropMediaSaveInProgress ||
      (this.taildropReceive.state !== 'awaiting_gallery_save' &&
        this.taildropReceive.state !== 'awaiting_text_preview');
  }

  private taildropTextPreviewLoading(file: TaildropWaitingFileSummary): boolean {
    return this.taildropReceiveMatches(file) &&
      this.taildropReceiveStrategy === 'text-preview' &&
      this.taildropReceive.state !== 'awaiting_text_preview';
  }

  private findTaildropMediaPreview(
    file: TaildropWaitingFileSummary
  ): TaildropMediaPreview | undefined {
    return this.taildropMediaPreviews.find((preview: TaildropMediaPreview) =>
      preview.name === file.name && preview.size === file.size);
  }

  private findTaildropCachedFile(
    file: TaildropWaitingFileSummary
  ): TaildropCachedFile | undefined {
    return this.taildropCachedFiles.find((cached: TaildropCachedFile) =>
      cached.name === file.name && cached.size === file.size &&
      this.validTaildropCachedFile(cached));
  }

  private validTaildropCachedFile(cached: TaildropCachedFile): boolean {
    if (cached.path.length === 0) {
      return false;
    }
    try {
      const stat: fileIo.Stat = fileIo.statSync(cached.path);
      return stat.isFile() && stat.size === cached.size;
    } catch (_error) {
      return false;
    }
  }

  private taildropWaitingFilePreviewUri(file: TaildropWaitingFileSummary): string {
    if (!this.isTaildropImageName(file.name)) {
      return '';
    }
    const preview: TaildropMediaPreview | undefined = this.findTaildropMediaPreview(file);
    return preview === undefined ? '' : this.taildropPreviewUri(preview.thumbnailPath);
  }

  private taildropActiveReceivePreviewUri(): string {
    if (this.taildropReceiveMediaType !== photoAccessHelper.PhotoType.IMAGE) {
      return '';
    }
    return this.taildropPreviewUri(this.taildropReceive.path);
  }

  private taildropHistoryPreviewUri(record: TaildropTransferRecord): string {
    if (record.fileCount !== 1 || !this.isTaildropImageName(record.fileName)) {
      return '';
    }
    return this.taildropPreviewUri(record.previewPath);
  }

  private taildropTransferStatusText(record: TaildropTransferRecord): ResourceStr {
    if (record.state === 'completed') {
      return record.direction === 'receive' ? $r('app.string.transfer_received_status') :
        $r('app.string.transfer_sent_status');
    }
    return $r('app.string.transfer_failed_status');
  }

  private taildropTransferRecordTitle(record: TaildropTransferRecord): string {
    const fileName: string = record.fileName.trim();
    if (fileName.length > 0) {
      return record.fileCount > 1 ? fileName + ' (' + record.fileCount + ' files)' : fileName;
    }
    return record.direction === 'send' ? record.targetName : 'Received file';
  }

  private taildropTransferRecordDescription(record: TaildropTransferRecord): string {
    const size: string = this.formatTrafficBytes(record.totalBytes);
    if (record.direction === 'send' && record.fileCount <= 1 && record.targetName.length > 0) {
      return `${size} · ${record.targetName}`;
    }
    return record.fileCount > 1 ? record.fileCount + ' files · ' + size + ' · ' + record.targetName :
      size + (record.direction === 'send' && record.targetName.length > 0 ? ' · ' + record.targetName : '');
  }

  private taildropHistoryPath(): string {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return `${context.filesDir}/${TAILDROP_HISTORY_FILE_NAME}`;
  }

  private taildropInboxSnapshotPath(): string {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return `${context.filesDir}/${TAILDROP_INBOX_SNAPSHOT_FILE_NAME}`;
  }

  private taildropHistoryMediaRoot(): string {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return `${context.filesDir}/${TAILDROP_HISTORY_MEDIA_DIR_NAME}`;
  }

  private isTaildropImageName(name: string): boolean {
    return TAILDROP_IMAGE_EXTENSIONS.includes(this.taildropFileExtension(name));
  }

  private taildropPreviewUri(path: string): string {
    if (path.length === 0) {
      return '';
    }
    try {
      return fileIo.accessSync(path) ? fileUri.getUriFromPath(path) : '';
    } catch (_error) {
      return '';
    }
  }

  private taildropWaitingFileKey(file: TaildropWaitingFileSummary): string {
    return `${file.name}:${file.size}`;
  }

  private removeTaildropMediaPreview(name: string, size: number, deleteFile: boolean): void {
    const removed: TaildropMediaPreview[] = this.taildropMediaPreviews.filter(
      (preview: TaildropMediaPreview) => preview.name === name && preview.size === size);
    if (deleteFile) {
      removed.forEach((preview: TaildropMediaPreview) => {
        [preview.path, preview.thumbnailPath].forEach((path: string) => {
          try {
            if (fileIo.accessSync(path)) {
              fileIo.unlinkSync(path);
            }
          } catch (_error) {
            // Cache cleanup is retried when the whole inbox cache is cleared.
          }
        });
      });
    }
    this.taildropMediaPreviews = this.taildropMediaPreviews.filter(
      (preview: TaildropMediaPreview) => preview.name !== name || preview.size !== size);
    if (deleteFile && removed.length > 0) {
      this.notifyCacheContentsChanged();
    }
  }

  private removeTaildropCachedFile(name: string, size: number, deleteFile: boolean): void {
    const removed: TaildropCachedFile[] = this.taildropCachedFiles.filter(
      (cached: TaildropCachedFile) => cached.name === name && cached.size === size);
    if (deleteFile) {
      removed.forEach((cached: TaildropCachedFile) => {
        try {
          if (fileIo.accessSync(cached.path)) {
            fileIo.unlinkSync(cached.path);
          }
        } catch (_error) {
          // A later full inbox-cache cleanup can retry an inaccessible file.
        }
      });
    }
    this.taildropCachedFiles = this.taildropCachedFiles.filter(
      (cached: TaildropCachedFile) => cached.name !== name || cached.size !== size);
    if (deleteFile && removed.length > 0) {
      this.notifyCacheContentsChanged();
    }
  }

  private reconcileTaildropMediaPreviews(files: TaildropWaitingFileSummary[]): void {
    const stale: TaildropMediaPreview[] = this.taildropMediaPreviews.filter(
      (preview: TaildropMediaPreview) => !files.some((file: TaildropWaitingFileSummary) =>
        file.name === preview.name && file.size === preview.size));
    stale.forEach((preview: TaildropMediaPreview) => {
      [preview.path, preview.thumbnailPath].forEach((path: string) => {
        try {
          if (fileIo.accessSync(path)) {
            fileIo.unlinkSync(path);
          }
        } catch (_error) {
          // The next inbox-cache cleanup can remove an inaccessible stale file.
        }
      });
    });
    const validPreviews: TaildropMediaPreview[] = this.taildropMediaPreviews.filter(
      (preview: TaildropMediaPreview) => files.some((file: TaildropWaitingFileSummary) =>
        file.name === preview.name && file.size === preview.size) &&
        this.taildropPreviewUri(preview.path).length > 0 &&
        this.taildropPreviewUri(preview.thumbnailPath).length > 0);
    const previewsChanged: boolean =
      JSON.stringify(this.taildropMediaPreviews) !== JSON.stringify(validPreviews);
    if (previewsChanged) {
      this.taildropMediaPreviews = validPreviews;
    }
    const staleCachedFiles: TaildropCachedFile[] = this.taildropCachedFiles.filter(
      (cached: TaildropCachedFile) => !files.some((file: TaildropWaitingFileSummary) =>
        file.name === cached.name && file.size === cached.size));
    staleCachedFiles.forEach((cached: TaildropCachedFile) => {
      try {
        if (fileIo.accessSync(cached.path)) {
          fileIo.unlinkSync(cached.path);
        }
      } catch (_error) {
        // A later full inbox-cache cleanup can retry an inaccessible file.
      }
    });
    const validCachedFiles: TaildropCachedFile[] = this.taildropCachedFiles.filter(
      (cached: TaildropCachedFile) => files.some((file: TaildropWaitingFileSummary) =>
        file.name === cached.name && file.size === cached.size) &&
      this.validTaildropCachedFile(cached));
    const cachedFilesChanged: boolean =
      JSON.stringify(this.taildropCachedFiles) !== JSON.stringify(validCachedFiles);
    if (cachedFilesChanged) {
      this.taildropCachedFiles = validCachedFiles;
    }
    if (stale.length > 0 || staleCachedFiles.length > 0) {
      this.notifyCacheContentsChanged();
    }
    if (previewsChanged || cachedFilesChanged || stale.length > 0 || staleCachedFiles.length > 0) {
      this.persistTaildropInbox();
    }
    this.taildropAutoPrefetchFailedKeys = this.taildropAutoPrefetchFailedKeys.filter(
      (key: string) => files.some((file: TaildropWaitingFileSummary) =>
        this.taildropWaitingFileKey(file) === key));
  }

  private prefetchTaildropImage(files: TaildropWaitingFileSummary[]): void {
    this.reconcileTaildropMediaPreviews(files);
    if (this.taildropAutoPrefetchKey.length > 0 &&
      !files.some((file: TaildropWaitingFileSummary) =>
        this.taildropWaitingFileKey(file) === this.taildropAutoPrefetchKey)) {
      this.taildropAutoPrefetchKey = '';
    }
    if (this.taildropState !== 'ready' || this.taildropReceiveInProgress ||
      this.taildropPickerOpen || this.taildropPreparing || this.taildropTransfer.state === 'queued' ||
      this.taildropTransfer.state === 'sending' || this.taildropAutoPrefetchKey.length > 0) {
      return;
    }
    const imageFile: TaildropWaitingFileSummary | undefined = files.find(
      (file: TaildropWaitingFileSummary) =>
        this.resolveTaildropMediaType(file.name) === photoAccessHelper.PhotoType.IMAGE &&
        this.findTaildropMediaPreview(file) === undefined &&
        !this.taildropAutoPrefetchFailedKeys.includes(this.taildropWaitingFileKey(file)));
    if (imageFile !== undefined) {
      this.taildropAutoPrefetchKey = this.taildropWaitingFileKey(imageFile);
      try {
        this.submitTaildropReceiveStage(
          imageFile, photoAccessHelper.PhotoType.IMAGE, 'media-prefetch', '');
      } catch (_error) {
        this.failTaildropMediaPrefetch('extension_error');
      }
      return;
    }
    const uncachedFile: TaildropWaitingFileSummary | undefined = files.find(
      (file: TaildropWaitingFileSummary) =>
        this.resolveTaildropMediaType(file.name) !== photoAccessHelper.PhotoType.IMAGE &&
        this.findTaildropCachedFile(file) === undefined &&
        !this.taildropAutoPrefetchFailedKeys.includes(this.taildropWaitingFileKey(file)));
    if (uncachedFile === undefined) {
      return;
    }
    this.taildropAutoPrefetchKey = this.taildropWaitingFileKey(uncachedFile);
    try {
      this.submitTaildropReceiveStage(uncachedFile, undefined, 'file-prefetch', '');
    } catch (_error) {
      this.failTaildropMediaPrefetch('extension_error');
    }
  }

  private async createTaildropHistoryPreview(
    sourcePath: string, name: string, requestId: number
  ): Promise<string> {
    if (!this.isTaildropImageName(name) || sourcePath.length === 0) {
      return '';
    }
    const root: string = this.taildropHistoryMediaRoot();
    const destination: string = `${root}/receive-${requestId}-thumb.jpg`;
    return this.createTaildropThumbnail(sourcePath, destination);
  }

  private async createTaildropThumbnail(sourcePath: string, destination: string): Promise<string> {
    let sourceFile: fileIo.File | undefined = undefined;
    let imageSource: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    let imagePacker: image.ImagePacker | undefined = undefined;
    let destinationFile: fileIo.File | undefined = undefined;
    try {
      const separator: number = destination.lastIndexOf('/');
      if (separator > 0) {
        const parent: string = destination.substring(0, separator);
        if (!fileIo.accessSync(parent)) {
          try {
            fileIo.mkdirSync(parent, true);
          } catch (error) {
            const businessError: BusinessError = error as BusinessError;
            if (businessError.code !== 13900015) {
              throw new Error(businessError.message);
            }
          }
        }
      }
      if (fileIo.accessSync(destination)) {
        fileIo.unlinkSync(destination);
      }
      sourceFile = fileIo.openSync(sourcePath, fileIo.OpenMode.READ_ONLY);
      imageSource = image.createImageSource(sourceFile.fd);
      const imageInfo: image.ImageInfo = await imageSource.getImageInfo();
      if (imageInfo.size.width <= 0 || imageInfo.size.height <= 0) {
        return '';
      }
      let width: number = TAILDROP_THUMBNAIL_EDGE_PX;
      let height: number = TAILDROP_THUMBNAIL_EDGE_PX;
      if (imageInfo.size.width >= imageInfo.size.height) {
        height = Math.max(1, Math.round(
          TAILDROP_THUMBNAIL_EDGE_PX * imageInfo.size.height / imageInfo.size.width));
      } else {
        width = Math.max(1, Math.round(
          TAILDROP_THUMBNAIL_EDGE_PX * imageInfo.size.width / imageInfo.size.height));
      }
      pixelMap = await imageSource.createPixelMap({
        index: 0,
        desiredSize: { width: width, height: height }
      });
      imagePacker = image.createImagePacker();
      const packed: ArrayBuffer = await imagePacker.packToData(pixelMap, {
        format: 'image/jpeg',
        quality: TAILDROP_THUMBNAIL_JPEG_QUALITY
      });
      if (packed.byteLength <= 0) {
        return '';
      }
      destinationFile = fileIo.openSync(destination,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      const written: number = fileIo.writeSync(destinationFile.fd, packed);
      fileIo.closeSync(destinationFile);
      destinationFile = undefined;
      const stat: fileIo.Stat = fileIo.statSync(destination);
      if (!stat.isFile() || stat.size !== written || written !== packed.byteLength) {
        fileIo.unlinkSync(destination);
        return '';
      }
      this.notifyCacheContentsChanged();
      return destination;
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      this.recordDiagnosticEvent(
        'taildrop_thumbnail_failed', 'imagekit', businessError.code ?? -1);
      try {
        if (fileIo.accessSync(destination)) {
          fileIo.unlinkSync(destination);
        }
      } catch (_cleanupError) {
      }
      return '';
    } finally {
      if (destinationFile !== undefined) {
        try {
          fileIo.closeSync(destinationFile);
        } catch (_error) {
        }
      }
      if (imagePacker !== undefined) {
        try {
          await imagePacker.release();
        } catch (_error) {
        }
      }
      if (pixelMap !== undefined) {
        try {
          await pixelMap.release();
        } catch (_error) {
        }
      }
      if (imageSource !== undefined) {
        try {
          await imageSource.release();
        } catch (_error) {
        }
      }
      if (sourceFile !== undefined) {
        try {
          fileIo.closeSync(sourceFile);
        } catch (_error) {
        }
      }
    }
  }

  private cleanupTaildropHistoryMedia(): void {
    const root: string = this.taildropHistoryMediaRoot();
    try {
      if (!fileIo.accessSync(root)) {
        return;
      }
      const referenced: Set<string> = new Set<string>(this.taildropHistory
        .map((record: TaildropTransferRecord) => record.previewPath)
        .filter((path: string) => path.length > 0));
      let removedAny: boolean = false;
      fileIo.listFileSync(root).forEach((name: string) => {
        const path: string = `${root}/${name}`;
        if (!referenced.has(path)) {
          try {
            fileIo.unlinkSync(path);
            removedAny = true;
          } catch (_error) {
            // A later history write retries stale preview cleanup.
          }
        }
      });
      if (removedAny) {
        this.notifyCacheContentsChanged();
      }
    } catch (_error) {
      // Preview cleanup is best effort and must not affect transfer history.
    }
  }

  private validTaildropHistoryRecord(record: TaildropTransferRecord): boolean {
    return record.requestId > 0 && (record.direction === 'send' || record.direction === 'receive') &&
      (record.state === 'completed' || record.state === 'failed') && record.fileCount > 0 &&
      record.totalBytes >= 0 && record.completedAtMs > 0 && record.fileName.length <= 255;
  }

  private loadTaildropHistory(): void {
    try {
      const path: string = this.taildropHistoryPath();
      if (!fileIo.accessSync(path)) {
        return;
      }
      const persisted: PersistedTaildropHistory = JSON.parse(fileIo.readTextSync(path)) as PersistedTaildropHistory;
      const records: TaildropTransferRecord[] = persisted.records.filter(
        (record: TaildropTransferRecord) => this.validTaildropHistoryRecord(record))
        .map((record: TaildropTransferRecord) => {
          if (typeof record.previewPath !== 'string') {
            record.previewPath = '';
          }
          return record;
        })
        .slice(0, TAILDROP_HISTORY_LIMIT);
      this.taildropHistory = records;
      this.cleanupTaildropHistoryMedia();
      records.forEach((record: TaildropTransferRecord) => {
        if (record.direction === 'send') {
          this.lastHandledTaildropRequestId = Math.max(this.lastHandledTaildropRequestId, record.requestId);
        }
      });
    } catch (_error) {
      this.taildropHistory = [];
    }
  }

  private persistTaildropHistory(): void {
    const path: string = this.taildropHistoryPath();
    const temporaryPath: string = `${path}.tmp`;
    const persisted: PersistedTaildropHistory = {
      records: this.taildropHistory.slice(0, TAILDROP_HISTORY_LIMIT)
    };
    if (!this.writePrivateTextFile(temporaryPath, JSON.stringify(persisted))) {
      return;
    }
    try {
      fileIo.renameSync(temporaryPath, path);
      this.cleanupTaildropHistoryMedia();
    } catch (_error) {
      try {
        if (fileIo.accessSync(temporaryPath)) {
          fileIo.unlinkSync(temporaryPath);
        }
      } catch (_cleanupError) {
        // History persistence is retried after the next completed transfer.
      }
    }
  }

  private clearTaildropHistory(): void {
    this.taildropHistory = [];
    const path: string = this.taildropHistoryPath();
    try {
      if (fileIo.accessSync(path)) {
        fileIo.unlinkSync(path);
      }
    } catch (_error) {
      this.writePrivateTextFile(path, JSON.stringify({ records: [] } as PersistedTaildropHistory));
    }
    this.cleanupTaildropHistoryMedia();
    this.showToast($r('app.string.transfer_history_cleared'));
  }

  private writeAtomicTaildropRequest(path: string, requestId: number, content: string): boolean {
    const temporaryPath: string = `${path}.${requestId}.tmp`;
    if (!this.writePrivateTextFile(temporaryPath, content)) {
      return false;
    }
    try {
      fileIo.renameSync(temporaryPath, path);
      return true;
    } catch (_error) {
      try {
        if (fileIo.accessSync(temporaryPath)) {
          fileIo.unlinkSync(temporaryPath);
        }
      } catch (_cleanupError) {
        // Extension startup cleanup removes any remaining temporary file.
      }
      return false;
    }
  }

  private taildropOutboxRoot(): string {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return `${context.filesDir}/${TAILDROP_OUTBOX_DIR_NAME}`;
  }

  private taildropSendRequestPath(): string {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return `${context.filesDir}/${TAILDROP_SEND_REQUEST_FILE_NAME}`;
  }

  private taildropCancelRequestPath(): string {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return `${context.filesDir}/${TAILDROP_CANCEL_REQUEST_FILE_NAME}`;
  }

  private taildropInboxRoot(): string {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return `${context.filesDir}/${TAILDROP_INBOX_DIR_NAME}`;
  }

  private taildropReceiveRequestPath(): string {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return `${context.filesDir}/${TAILDROP_RECEIVE_REQUEST_FILE_NAME}`;
  }

  private taildropReceiveResponsePath(): string {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return `${context.filesDir}/${TAILDROP_RECEIVE_RESPONSE_FILE_NAME}`;
  }

  private taildropSendActive(): boolean {
    return this.taildropPickerOpen || this.taildropPreparing || this.taildropTransfer.state === 'queued' ||
      this.taildropTransfer.state === 'sending';
  }

  private taildropContentChoiceEnabled(): boolean {
    return !this.taildropPreparing && this.taildropTransfer.state !== 'queued' &&
      this.taildropTransfer.state !== 'sending' &&
      (!this.taildropPickerOpen || this.taildropTextEditorVisible);
  }

  private taildropTextEditorMatches(target: TaildropTargetSummary): boolean {
    return this.taildropTextEditorVisible && this.taildropTextTarget !== undefined &&
      this.taildropTextTarget.key === target.key;
  }

  private closeTaildropTextEditor(): void {
    this.taildropTextEditorVisible = false;
    this.taildropPickerOpen = false;
    this.taildropTextTarget = undefined;
  }

  private interruptTaildropMediaPrefetch(): void {
    if (this.taildropReceiveInProgress && this.taildropReceiveStrategy === 'media-prefetch') {
      this.taildropAutoPrefetchKey = '';
      this.resetTaildropReceiveOperation();
    }
  }

  private loadPersistedTaildropInbox(): void {
    try {
      const path: string = this.taildropInboxSnapshotPath();
      if (!fileIo.accessSync(path)) {
        return;
      }
      const persisted: PersistedTaildropInbox =
        JSON.parse(fileIo.readTextSync(path)) as PersistedTaildropInbox;
      this.taildropWaitingFiles = persisted.files.filter((file: TaildropWaitingFileSummary) =>
        file.name.length > 0 && file.name.length <= 255 &&
        !file.name.includes('/') && !file.name.includes('\\') && file.size >= 0);
      this.taildropInboxReason = persisted.inboxReason;
      const mediaPreviews: TaildropMediaPreview[] =
        persisted.mediaPreviews === undefined ? [] : persisted.mediaPreviews;
      this.taildropMediaPreviews = mediaPreviews.filter((preview: TaildropMediaPreview) =>
        this.taildropWaitingFiles.some((file: TaildropWaitingFileSummary) =>
          file.name === preview.name && file.size === preview.size) &&
        this.taildropPreviewUri(preview.path).length > 0 &&
        this.taildropPreviewUri(preview.thumbnailPath).length > 0);
      const cachedFiles: TaildropCachedFile[] =
        persisted.cachedFiles === undefined ? [] : persisted.cachedFiles;
      this.taildropCachedFiles = cachedFiles.filter((cached: TaildropCachedFile) =>
        this.taildropWaitingFiles.some((file: TaildropWaitingFileSummary) =>
          file.name === cached.name && file.size === cached.size) &&
        this.validTaildropCachedFile(cached));
    } catch (_error) {
      this.taildropWaitingFiles = [];
      this.taildropInboxReason = '';
      this.taildropMediaPreviews = [];
      this.taildropCachedFiles = [];
    }
  }

  private persistTaildropInbox(): void {
    const persisted: PersistedTaildropInbox = {
      files: this.taildropWaitingFiles,
      inboxReason: this.taildropInboxReason,
      mediaPreviews: this.taildropMediaPreviews,
      cachedFiles: this.taildropCachedFiles
    };
    this.writePrivateTextFile(this.taildropInboxSnapshotPath(), JSON.stringify(persisted));
  }

  private writeTaildropSendRequest(request: TaildropSendRequest): boolean {
    const requestPath: string = this.taildropSendRequestPath();
    return this.writeAtomicTaildropRequest(requestPath, request.requestId, JSON.stringify(request));
  }

  private sanitizeTaildropFileName(name: string, index: number): string {
    let sanitized: string = name.replace(/[\\/\u0000]/g, '_').trim();
    if (sanitized.length === 0 || sanitized === '.' || sanitized === '..') {
      sanitized = `file-${index + 1}`;
    }
    if (sanitized.length > 180) {
      sanitized = sanitized.substring(0, 180);
    }
    return sanitized;
  }

  private async prepareTaildropFiles(uris: string[], requestId: number): Promise<TaildropSendFile[]> {
    const root: string = this.taildropOutboxRoot();
    const requestDir: string = `${root}/${requestId}`;
    fileIo.mkdirSync(requestDir, true);
    const historyMediaRoot: string = this.taildropHistoryMediaRoot();
    const prepared: TaildropSendFile[] = [];
    for (let index: number = 0; index < uris.length; index++) {
      let source: fileIo.File | undefined = undefined;
      try {
        source = fileIo.openSync(uris[index], fileIo.OpenMode.READ_ONLY);
        const stat: fileIo.Stat = fileIo.statSync(source.fd);
        if (!stat.isFile() || stat.size < 0) {
          throw new Error('Selected item is not a regular file.');
        }
        const name: string = this.sanitizeTaildropFileName(source.name, index);
        const destination: string = `${requestDir}/${index}.taildrop`;
        await fileIo.copyFile(source.fd, destination);
        const copiedStat: fileIo.Stat = fileIo.statSync(destination);
        if (!copiedStat.isFile() || copiedStat.size !== stat.size) {
          throw new Error('Copied Taildrop file failed verification.');
        }
        let previewPath: string = '';
        if (uris.length === 1 && this.isTaildropImageName(name)) {
          previewPath = await this.createTaildropThumbnail(
            destination, `${historyMediaRoot}/${requestId}-thumb.jpg`);
        }
        prepared.push({ path: destination, name: name, size: copiedStat.size, previewPath: previewPath });
      } finally {
        if (source !== undefined) {
          try {
            fileIo.closeSync(source);
          } catch (_error) {
            // The picker descriptor may already be closed after a copy failure.
          }
        }
      }
    }
    this.notifyCacheContentsChanged();
    return prepared;
  }

  private cleanupPreparedTaildropFiles(files: TaildropSendFile[]): void {
    files.forEach((file: TaildropSendFile) => {
      try {
        if (fileIo.accessSync(file.path)) {
          fileIo.unlinkSync(file.path);
        }
      } catch (_error) {
        // Extension startup cleanup handles any remaining outbox file.
      }
      if (file.previewPath.length > 0) {
        try {
          if (fileIo.accessSync(file.previewPath)) {
            fileIo.unlinkSync(file.previewPath);
          }
        } catch (_error) {
          // Preview cleanup is best effort.
        }
      }
    });
    if (files.length > 0) {
      const requestDir: string = files[0].path.substring(0, files[0].path.lastIndexOf('/'));
      try {
        fileIo.rmdirSync(requestDir);
      } catch (_error) {
        // The directory may still contain a file whose cleanup failed.
      }
    }
    this.notifyCacheContentsChanged();
  }

  private chooseTaildropDocuments(target: TaildropTargetSummary): void {
    if (this.taildropTextEditorVisible) {
      this.closeTaildropTextEditor();
    }
    if (!this.ensureTaildropSendAvailable(target)) {
      return;
    }
    this.selectTaildropDocuments(target).catch(() => {
      this.handleTaildropSelectionFailure();
    });
  }

  private chooseTaildropPhotos(target: TaildropTargetSummary): void {
    if (this.taildropTextEditorVisible) {
      this.closeTaildropTextEditor();
    }
    if (!this.ensureTaildropSendAvailable(target)) {
      return;
    }
    this.selectTaildropMedia(target).catch(() => {
      this.handleTaildropSelectionFailure();
    });
  }

  private chooseTaildropText(target: TaildropTargetSummary): void {
    if (this.taildropTextEditorMatches(target)) {
      this.closeTaildropTextEditor();
      return;
    }
    if (this.taildropTextEditorVisible) {
      this.closeTaildropTextEditor();
    }
    if (!this.ensureTaildropSendAvailable(target)) {
      return;
    }
    this.taildropTextInput = '';
    this.taildropTextTarget = target;
    this.taildropPickerOpen = true;
    this.taildropTextEditorVisible = true;
  }

  private ensureTaildropSendAvailable(target: TaildropTargetSummary): boolean {
    if (!this.isConnected() || this.taildropState !== 'ready') {
      this.showToast($r('app.string.transfer_connect_first_title'));
      return false;
    }
    if (!target.online) {
      this.showToast($r('app.string.transfer_send_target_unavailable'));
      return false;
    }
    this.interruptTaildropMediaPrefetch();
    if (this.taildropSendActive()) {
      this.showToast($r('app.string.transfer_busy_message'));
      return false;
    }
    return true;
  }

  private handleTaildropSelectionFailure(): void {
    this.taildropPickerOpen = false;
    this.taildropPreparing = false;
    this.showToast($r('app.string.transfer_file_selection_failed'));
  }

  private async selectTaildropDocuments(target: TaildropTargetSummary): Promise<void> {
    if (!target.online || !this.isConnected() || this.taildropState !== 'ready' ||
      this.taildropSendActive()) {
      return;
    }
    this.taildropPickerOpen = true;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const documentPicker = new picker.DocumentViewPicker(context);
    const options = new picker.DocumentSelectOptions();
    options.maxSelectNumber = TAILDROP_MAX_FILE_SELECTION;
    let uris: string[] = [];
    try {
      uris = await documentPicker.select(options);
    } finally {
      this.taildropPickerOpen = false;
    }
    if (uris.length > 0) {
      await this.queueTaildropFiles(target, uris);
    }
  }

  private async selectTaildropMedia(target: TaildropTargetSummary): Promise<void> {
    if (!target.online || !this.isConnected() || this.taildropState !== 'ready' ||
      this.taildropSendActive()) {
      return;
    }
    this.taildropPickerOpen = true;
    const mediaPicker = new photoAccessHelper.PhotoViewPicker();
    const options = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_VIDEO_TYPE;
    options.maxSelectNumber = TAILDROP_MAX_MEDIA_SELECTION;
    options.isSearchSupported = true;
    options.isPhotoTakingSupported = true;
    let uris: string[] = [];
    try {
      const result: photoAccessHelper.PhotoSelectResult = await mediaPicker.select(options);
      uris = result.photoUris;
    } finally {
      this.taildropPickerOpen = false;
    }
    if (uris.length > 0) {
      await this.queueTaildropFiles(target, uris);
    }
  }

  private onTaildropTextEditorVisibilityChanged(): void {
    if (!this.taildropTextEditorVisible) {
      this.taildropPickerOpen = false;
      this.taildropTextTarget = undefined;
    }
  }

  private sendTaildropText(): void {
    const target: TaildropTargetSummary | undefined = this.taildropTextTarget;
    const text: string = this.taildropTextInput;
    if (target === undefined || text.trim().length === 0) {
      return;
    }
    this.taildropTextEditorVisible = false;
    this.taildropPickerOpen = false;
    this.queueTaildropText(target, text).catch(() => {
      this.handleTaildropSelectionFailure();
    });
  }

  private async queueTaildropText(target: TaildropTargetSummary, text: string): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const path: string = `${context.cacheDir}/taildrop-text-${Date.now()}.txt`;
    let file: fileIo.File | undefined = undefined;
    try {
      file = fileIo.openSync(path,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, text);
      fileIo.closeSync(file);
      file = undefined;
      await this.queueTaildropFiles(target, [fileUri.getUriFromPath(path)]);
    } finally {
      if (file !== undefined) {
        try {
          fileIo.closeSync(file);
        } catch (_closeError) {
        }
      }
      try {
        if (fileIo.accessSync(path)) {
          fileIo.unlinkSync(path);
        }
      } catch (_cleanupError) {
      }
    }
  }

  private async queueTaildropFiles(target: TaildropTargetSummary, uris: string[]): Promise<void> {
    if (!target.online || !this.isConnected() || this.taildropState !== 'ready' ||
      this.taildropPreparing || this.taildropTransfer.state === 'queued' ||
      this.taildropTransfer.state === 'sending' || this.taildropReceiveInProgress) {
      return;
    }
    this.taildropPreparing = true;
    const requestId: number = Date.now();
    let files: TaildropSendFile[] = [];
    try {
      files = await this.prepareTaildropFiles(uris.slice(0, TAILDROP_MAX_MEDIA_SELECTION), requestId);
      let totalBytes: number = 0;
      files.forEach((file: TaildropSendFile) => {
        totalBytes += file.size;
      });
      const request: TaildropSendRequest = {
        requestId: requestId,
        targetKey: target.key,
        outboxRoot: this.taildropOutboxRoot(),
        files: files
      };
      this.taildropTransfer = {
        requestId: requestId, state: 'queued', reason: '', targetKey: target.key,
        targetName: target.name, fileName: '', fileIndex: 0, fileCount: files.length,
        fileBytes: 0, fileSize: 0, bytesSent: 0, totalBytes: totalBytes,
        previewPath: files.length === 1 ? files[0].previewPath : '', completedAtMs: 0
      };
      this.resetTaildropProgressEstimate();
      this.taildropRequestSubmittedAtMs = Date.now();
      if (!this.writeTaildropSendRequest(request)) {
        this.cleanupPreparedTaildropFiles(files);
        const failed: TaildropTransferSummary = this.taildropTransferFailure(
          this.taildropTransfer, 'extension_error');
        this.taildropPreparing = false;
        this.applyTaildropTransfer(failed);
        return;
      }
      this.recordDiagnosticEvent('taildrop_send_queued', 'transfer');
      this.taildropPreparing = false;
    } catch (_error) {
      this.cleanupPreparedTaildropFiles(files);
      this.taildropPreparing = false;
      this.showToast($r('app.string.transfer_file_copy_failed'));
    }
  }

  private cancelTaildropSend(): void {
    if (this.taildropTransfer.requestId <= 0 ||
      (this.taildropTransfer.state !== 'queued' && this.taildropTransfer.state !== 'sending')) {
      return;
    }
    const request: TaildropCancelRequest = { requestId: this.taildropTransfer.requestId };
    if (!this.writeAtomicTaildropRequest(this.taildropCancelRequestPath(), request.requestId,
      JSON.stringify(request))) {
      this.showToast($r('app.string.transfer_cancel_failed'));
      return;
    }
    this.taildropCancelPending = true;
    this.recordDiagnosticEvent('taildrop_send_cancel_requested', 'transfer');
  }

  private retryTaildropSend(record: TaildropTransferRecord): void {
    if (record.direction !== 'send' || record.state !== 'failed' || this.taildropSendActive()) {
      return;
    }
    const target: TaildropTargetSummary | undefined = this.displayedTaildropTargets().find(
      (item: TaildropTargetSummary) => item.key === record.targetKey && item.online);
    if (target === undefined) {
      this.showToast($r('app.string.transfer_send_target_unavailable'));
      return;
    }
    this.transferScroller.scrollEdge(Edge.Top);
    this.showToast($r('app.string.transfer_retry_choose_content'));
  }

  private startTaildropReceive(file: TaildropWaitingFileSummary): void {
    if (this.taildropReceiveInProgress && this.taildropReceive.name !== file.name &&
      this.taildropReceive.state === 'awaiting_gallery_save') {
      this.resetTaildropReceiveOperation();
      this.taildropAutoPrefetchKey = '';
    }
    if (this.taildropState !== 'ready' || this.taildropSendActive() ||
      this.taildropReceiveInProgress) {
      return;
    }
    try {
      this.routeTaildropReceive(file);
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      this.recordDiagnosticEvent('taildrop_receive_submit_failed', 'transfer', businessError.code ?? -1);
      this.resetTaildropReceiveOperation();
      this.showToast($r('app.string.transfer_receive_failed'));
    }
  }

  private startTaildropTextPreview(file: TaildropWaitingFileSummary): void {
    if (this.taildropContentKind(file) !== 'text') {
      return;
    }
    if (this.taildropReceiveInProgress && this.taildropReceive.name !== file.name &&
      this.taildropReceive.state === 'awaiting_gallery_save') {
      this.resetTaildropReceiveOperation();
      this.taildropAutoPrefetchKey = '';
    }
    if (this.taildropReceiveInProgress) {
      if (this.taildropReceive.name === file.name &&
        this.taildropReceive.state === 'awaiting_text_preview') {
        return;
      }
      this.taildropPendingTextPreview = file;
      if (this.taildropReceive.state === 'awaiting_text_preview') {
        this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseInOut }, () => {
          this.resetTaildropReceiveOperation();
        });
        this.resumePendingTaildropAction();
      }
      return;
    }
    if (this.taildropSendActive()) {
      this.showToast($r('app.string.transfer_busy_message'));
      return;
    }
    const cached: TaildropCachedFile | undefined = this.findTaildropCachedFile(file);
    if (cached !== undefined) {
      this.showCachedTaildropTextPreview(cached);
      return;
    }
    if (this.taildropState !== 'ready') {
      this.showToast($r('app.string.transfer_connect_first_title'));
      return;
    }
    try {
      this.submitTaildropReceiveStage(file, undefined, 'text-preview', '');
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      this.recordDiagnosticEvent('taildrop_text_preview_submit_failed', 'transfer', businessError.code ?? -1);
      this.resetTaildropReceiveOperation();
      this.showToast($r('app.string.transfer_receive_failed'));
    }
  }

  private showCachedTaildropTextPreview(cached: TaildropCachedFile): void {
    const result: TaildropReceiveResult = {
      requestId: cached.requestId,
      action: 'stage',
      state: 'awaiting_text_preview',
      reason: '',
      name: cached.name,
      size: cached.size,
      path: cached.path
    };
    const content: string | undefined = this.readTaildropTextPreview(result);
    if (content === undefined) {
      this.removeTaildropCachedFile(cached.name, cached.size, true);
      this.persistTaildropInbox();
      this.showToast($r('app.string.transfer_receive_failed'));
      return;
    }
    this.taildropReceiveStrategy = 'text-preview';
    this.taildropReceiveExpectedSize = cached.size;
    this.taildropReceiveInProgress = true;
    this.taildropReceiveStateStartedAtMs = 0;
    this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.taildropReceive = result;
      this.taildropReceivedText = content;
    });
  }

  private resumePendingTaildropAction(): boolean {
    if (this.taildropReceiveInProgress) {
      return false;
    }
    const pendingMediaSave: TaildropWaitingFileSummary | undefined =
      this.taildropPendingMediaSave;
    this.taildropPendingMediaSave = undefined;
    if (pendingMediaSave !== undefined &&
      this.findTaildropMediaPreview(pendingMediaSave) !== undefined) {
      this.startPreparedTaildropMediaSave(pendingMediaSave);
      return true;
    }
    const pending: TaildropWaitingFileSummary | undefined = this.taildropPendingTextPreview;
    this.taildropPendingTextPreview = undefined;
    if (pending !== undefined) {
      this.startTaildropTextPreview(pending);
      return true;
    }
    return false;
  }

  private resolveTaildropMediaType(name: string): photoAccessHelper.PhotoType | undefined {
    const extension: string = this.taildropFileExtension(name);
    if (TAILDROP_IMAGE_EXTENSIONS.includes(extension)) {
      return photoAccessHelper.PhotoType.IMAGE;
    }
    if (TAILDROP_VIDEO_EXTENSIONS.includes(extension)) {
      return photoAccessHelper.PhotoType.VIDEO;
    }
    return undefined;
  }

  private routeTaildropReceive(file: TaildropWaitingFileSummary): void {
    if (this.taildropContentKind(file) === 'text') {
      this.submitTaildropReceiveStage(file, undefined, 'text', '');
      return;
    }
    const mediaType: photoAccessHelper.PhotoType | undefined = this.resolveTaildropMediaType(file.name);
    if (mediaType !== undefined) {
      this.submitTaildropReceiveStage(file, mediaType, 'media', '');
      return;
    }
    this.submitTaildropReceiveStage(file, undefined, 'file', '');
  }

  private async selectTaildropReceiveDestination(result: TaildropReceiveResult): Promise<string> {
    this.taildropPickerOpen = true;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const documentPicker = new picker.DocumentViewPicker(context);
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [this.sanitizeTaildropFileName(result.name, 0)];
    let uris: string[] = [];
    try {
      uris = await documentPicker.save(options);
    } catch (_error) {
      this.showToast($r('app.string.transfer_receive_picker_failed'));
    } finally {
      this.taildropPickerOpen = false;
    }
    return uris.length > 0 ? uris[0] : '';
  }

  private submitTaildropReceiveStage(
    file: TaildropWaitingFileSummary,
    mediaType?: photoAccessHelper.PhotoType,
    strategy: string = 'file',
    destinationUri: string = ''
  ): void {
    if (this.taildropState !== 'ready' || this.taildropSendActive()) {
      return;
    }
    const requestId: number = Date.now();
    const inboxRoot: string = this.taildropInboxRoot();
    if (!this.ensureTaildropDirectory(inboxRoot)) {
      this.recordDiagnosticEvent('taildrop_receive_inbox_unavailable', 'transfer');
      this.showToast($r('app.string.transfer_receive_failed'));
      return;
    }
    this.taildropReceiveInProgress = true;
    const request: TaildropReceiveRequest = {
      requestId: requestId,
      action: 'stage',
      name: file.name,
      inboxRoot: inboxRoot,
      path: `${inboxRoot}/${requestId}.taildrop`
    };
    this.taildropReceiveStrategy = strategy;
    this.taildropReceiveDestinationUri = destinationUri;
    this.taildropReceiveExpectedSize = file.size;
    this.taildropReceiveMediaType = mediaType;
    this.taildropReceive = {
      requestId: requestId, action: 'stage', state: 'requesting', reason: '', name: file.name,
      size: file.size, path: request.path
    };
    this.taildropReceiveStateStartedAtMs = Date.now();
    this.writePrivateTextFile(this.taildropReceiveResponsePath(), '');
    if (!this.writeAtomicTaildropRequest(this.taildropReceiveRequestPath(), requestId, JSON.stringify(request))) {
      this.failTaildropReceive('extension_error');
      return;
    }
    this.recordDiagnosticEvent(mediaType === undefined ? 'taildrop_receive_queued' :
      'taildrop_media_receive_queued', 'transfer');
  }

  private ensureTaildropDirectory(path: string): boolean {
    try {
      if (!fileIo.accessSync(path)) {
        fileIo.mkdirSync(path, true);
      }
      return fileIo.accessSync(path) && fileIo.statSync(path).isDirectory();
    } catch (_error) {
      try {
        // mkdirSync may report 13900015 when another operation already created
        // the directory. Treat an existing directory as a successful outcome.
        return fileIo.accessSync(path) && fileIo.statSync(path).isDirectory();
      } catch (_verificationError) {
        return false;
      }
    }
  }

  private confirmDiscardTaildropFile(file: TaildropWaitingFileSummary): void {
    if (this.taildropSendActive()) {
      this.showToast($r('app.string.transfer_busy_message'));
      return;
    }
    this.getUIContext().showAlertDialog({
      title: $r('app.string.transfer_discard_confirm_title'),
      message: $r('app.string.transfer_discard_confirm_message', file.name),
      autoCancel: true,
      primaryButton: {
        value: $r('app.string.cancel_action'),
        action: () => {
        }
      },
      secondaryButton: {
        value: $r('app.string.transfer_discard_action'),
        fontColor: $r('app.color.status_error'),
        action: () => this.discardTaildropFile(file)
      }
    });
  }

  private discardTaildropFile(file: TaildropWaitingFileSummary): void {
    if (this.taildropSendActive() || this.taildropReceiveInProgress) {
      return;
    }
    if (this.taildropState !== 'ready') {
      this.removeTaildropMediaPreview(file.name, file.size, true);
      this.removeTaildropCachedFile(file.name, file.size, true);
      this.taildropWaitingFiles = this.taildropWaitingFiles.filter(
        (waitingFile: TaildropWaitingFileSummary) => waitingFile.name !== file.name);
      this.persistTaildropInbox();
      this.notifyCacheContentsChanged();
      this.showToast($r('app.string.transfer_discard_completed'));
      return;
    }
    const requestId: number = Date.now();
    const request: TaildropReceiveRequest = {
      requestId: requestId, action: 'delete', name: file.name, inboxRoot: '', path: ''
    };
    this.taildropReceiveStrategy = 'discard';
    this.taildropReceiveDestinationUri = '';
    this.taildropReceiveExpectedSize = 0;
    this.taildropReceiveInProgress = true;
    this.taildropReceive = {
      requestId: requestId, action: 'delete', state: 'deleting', reason: '', name: file.name,
      size: file.size, path: ''
    };
    this.taildropReceiveStateStartedAtMs = Date.now();
    this.writePrivateTextFile(this.taildropReceiveResponsePath(), '');
    if (!this.writeAtomicTaildropRequest(this.taildropReceiveRequestPath(), requestId, JSON.stringify(request))) {
      this.failTaildropReceive('discard_failed');
      return;
    }
    this.recordDiagnosticEvent('taildrop_receive_discard_requested', 'transfer');
  }

  private confirmClearTaildropInboxCache(): void {
    if (this.taildropSendActive()) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: $r('app.string.transfer_clear_cache_confirm_title'),
      message: $r('app.string.transfer_clear_cache_confirm_message'),
      autoCancel: true,
      primaryButton: {
        value: $r('app.string.cancel_action'),
        action: () => {
        }
      },
      secondaryButton: {
        value: $r('app.string.transfer_clear_cache_action'),
        fontColor: $r('app.color.status_error'),
        action: () => this.clearTaildropInboxCache()
      }
    });
  }

  private clearTaildropInboxCache(): void {
    if (this.taildropSendActive() || this.taildropReceiveInProgress) {
      return;
    }
    if (this.taildropState !== 'ready') {
      const succeeded: boolean = this.clearLocalTaildropInboxCache();
      if (succeeded) {
        this.clearTaildropInboxViewState();
      }
      this.notifyCacheContentsChanged();
      this.showToast(succeeded ? $r('app.string.transfer_cache_cleared') :
        $r('app.string.transfer_clear_cache_failed'));
      return;
    }
    this.requestTaildropInboxCacheClear();
  }

  private requestTaildropInboxCacheClear(): boolean {
    const requestId: number = Date.now();
    const request: TaildropReceiveRequest = {
      requestId: requestId, action: 'clear', name: '', inboxRoot: '', path: ''
    };
    this.taildropReceiveStrategy = 'clear';
    this.taildropReceiveInProgress = true;
    this.taildropReceive = {
      requestId: requestId, action: 'clear', state: 'requesting', reason: '', name: '', size: 0, path: ''
    };
    this.taildropReceiveStateStartedAtMs = Date.now();
    this.writePrivateTextFile(this.taildropReceiveResponsePath(), '');
    if (!this.writeAtomicTaildropRequest(this.taildropReceiveRequestPath(), requestId, JSON.stringify(request))) {
      this.recordDiagnosticEvent('taildrop_receive_failed', 'clear_failed');
      this.resetTaildropReceiveOperation();
      if (!this.cacheClearRequestedFromSettings) {
        this.showToast($r('app.string.transfer_clear_cache_failed'));
      }
      return false;
    }
    this.recordDiagnosticEvent('taildrop_receive_cache_clear_requested', 'transfer');
    return true;
  }

  private checkTaildropReceiveTimeout(): void {
    if (!this.taildropReceiveInProgress) {
      return;
    }
    if (this.taildropReceive.requestId <= 0) {
      this.recordDiagnosticEvent('taildrop_receive_invalid_busy_state', 'timeout');
      this.resetTaildropReceiveOperation();
      this.showToast($r('app.string.transfer_save_timeout'));
      return;
    }
    if (this.taildropReceive.state === 'awaiting_gallery_save' ||
      this.taildropReceive.state === 'awaiting_text_preview') {
      return;
    }
    if (this.taildropReceiveStateStartedAtMs <= 0) {
      this.taildropReceiveStateStartedAtMs = Date.now();
      return;
    }
    const timeoutMs: number = this.taildropReceive.state === 'requesting' ||
      this.taildropReceive.state === 'deleting' ?
      TAILDROP_RECEIVE_BACKEND_TIMEOUT_MS : TAILDROP_SAVE_TIMEOUT_MS;
    if (Date.now() - this.taildropReceiveStateStartedAtMs < timeoutMs) {
      return;
    }
    this.recordDiagnosticEvent('taildrop_receive_timeout', this.taildropReceive.state);
    if (this.taildropReceiveStrategy === 'media-prefetch') {
      this.failTaildropMediaPrefetch('timeout');
      return;
    }
    if (this.taildropReceive.state === 'saving_gallery' &&
      this.taildropReceiveMediaType !== undefined && this.taildropReceive.path.length > 0) {
      this.taildropMediaSaveInProgress = false;
      this.taildropPickerOpen = false;
      this.taildropReceiveResponseInFlight = false;
      this.taildropReceive = {
        requestId: this.taildropReceive.requestId, action: 'stage', state: 'awaiting_gallery_save',
        reason: '', name: this.taildropReceive.name, size: this.taildropReceive.size,
        path: this.taildropReceive.path
      };
      this.taildropReceiveStateStartedAtMs = 0;
      this.showToast($r('app.string.transfer_save_timeout'));
      return;
    }
    if (this.taildropReceive.state === 'deleting' && this.taildropReceiveStrategy !== 'discard') {
      this.failTaildropReceive('delete_failed');
      return;
    }
    this.failTaildropReceive('timeout');
  }

  private processTaildropReceiveResponse(): void {
    if (!this.taildropReceiveInProgress || this.taildropReceiveResponseInFlight) {
      return;
    }
    try {
      const path: string = this.taildropReceiveResponsePath();
      if (!fileIo.accessSync(path)) {
        return;
      }
      const responseText: string = fileIo.readTextSync(path).trim();
      if (responseText.length === 0) {
        return;
      }
      const result: TaildropReceiveResult = JSON.parse(responseText) as TaildropReceiveResult;
      if (result.requestId !== this.taildropReceive.requestId || result.action !== this.taildropReceive.action) {
        this.writePrivateTextFile(path, '');
        return;
      }
      this.writePrivateTextFile(path, '');
      this.taildropReceiveResponseInFlight = true;
      this.handleTaildropReceiveResult(result)
        .catch(() => this.failTaildropReceive('export_failed'))
        .finally(() => {
          this.taildropReceiveResponseInFlight = false;
        });
    } catch (_error) {
      // The Extension may be atomically replacing the response. Retry next poll.
    }
  }

  private async handleTaildropReceiveResult(result: TaildropReceiveResult): Promise<void> {
    if (result.state === 'failed') {
      this.failTaildropReceive(result.reason);
      return;
    }
    if (result.action === 'stage' && result.state === 'staged') {
      if (this.taildropReceiveStrategy === 'media-prefetch') {
        const mediaType: photoAccessHelper.PhotoType | undefined = this.taildropReceiveMediaType;
        const mediaPath: string | undefined = this.prepareTaildropMediaForSave(result);
        if (mediaType === undefined || mediaPath === undefined) {
          this.failTaildropMediaPrefetch('export_failed');
          return;
        }
        const thumbnailPath: string = await this.createTaildropThumbnail(
          mediaPath, `${this.taildropInboxRoot()}/${result.requestId}-thumb.jpg`);
        if (thumbnailPath.length === 0) {
          try {
            if (fileIo.accessSync(mediaPath)) {
              fileIo.unlinkSync(mediaPath);
            }
          } catch (_error) {
          }
          this.failTaildropMediaPrefetch('thumbnail_failed');
          return;
        }
        this.removeTaildropMediaPreview(result.name, result.size, true);
        const preview: TaildropMediaPreview = {
          requestId: result.requestId,
          name: result.name,
          size: result.size,
          path: mediaPath,
          thumbnailPath: thumbnailPath,
          mediaType: mediaType
        };
        this.taildropMediaPreviews = this.taildropMediaPreviews.concat([preview]);
        this.taildropAutoPrefetchKey = '';
        this.persistTaildropInbox();
        this.notifyCacheContentsChanged();
        this.recordDiagnosticEvent('taildrop_media_preview_ready', result.name);
        this.resetTaildropReceiveOperation();
        if (!this.resumePendingTaildropAction()) {
          this.prefetchTaildropImage(this.taildropWaitingFiles);
        }
        return;
      }
      if (this.taildropReceiveStrategy === 'file-prefetch') {
        const cached: TaildropCachedFile = {
          requestId: result.requestId,
          name: result.name,
          size: result.size,
          path: result.path
        };
        if (!this.validTaildropCachedFile(cached)) {
          this.failTaildropMediaPrefetch('export_failed');
          return;
        }
        this.removeTaildropCachedFile(result.name, result.size, true);
        this.taildropCachedFiles = this.taildropCachedFiles.concat([cached]);
        this.taildropAutoPrefetchKey = '';
        this.persistTaildropInbox();
        this.notifyCacheContentsChanged();
        this.recordDiagnosticEvent('taildrop_file_cache_ready', result.name);
        this.resetTaildropReceiveOperation();
        if (!this.resumePendingTaildropAction()) {
          this.prefetchTaildropImage(this.taildropWaitingFiles);
        }
        return;
      }
      if (this.taildropReceiveMediaType !== undefined) {
        const mediaPath: string | undefined = this.prepareTaildropMediaForSave(result);
        if (mediaPath === undefined) {
          this.failTaildropReceive('export_failed');
          return;
        }
        this.taildropReceive = {
          requestId: result.requestId, action: 'stage', state: 'awaiting_gallery_save', reason: '',
          name: result.name, size: result.size, path: mediaPath
        };
        this.taildropReceiveStateStartedAtMs = 0;
        this.recordDiagnosticEvent('taildrop_media_ready_for_save', 'transfer');
        this.showToast($r('app.string.transfer_media_ready_to_save'));
        return;
      }
      if (this.taildropReceiveStrategy === 'text-preview') {
        const content: string | undefined = this.readTaildropTextPreview(result);
        if (content === undefined) {
          this.failTaildropReceive('export_failed');
          return;
        }
        this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
          this.taildropReceive = {
            requestId: result.requestId, action: 'stage', state: 'awaiting_text_preview', reason: '',
            name: result.name, size: result.size, path: result.path
          };
          this.taildropReceivedText = content;
        });
        this.taildropReceiveStateStartedAtMs = 0;
        this.taildropTextPreviewVisible = false;
        this.recordDiagnosticEvent('taildrop_text_preview_ready', 'transfer');
        return;
      }
      this.taildropReceive = {
        requestId: result.requestId, action: 'stage', state: 'exporting', reason: '', name: result.name,
        size: result.size, path: result.path
      };
      this.taildropReceiveStateStartedAtMs = Date.now();
      if (this.taildropReceiveStrategy === 'file') {
        const destinationUri: string = await this.selectTaildropReceiveDestination(result);
        if (!this.isCurrentTaildropReceive(result.requestId, 'stage', 'exporting')) {
          return;
        }
        if (destinationUri.length === 0) {
          this.resetTaildropReceiveOperation();
          return;
        }
        this.taildropReceiveDestinationUri = destinationUri;
      }
      const handled: boolean = await this.handleTaildropStagedFile(result);
      if (!this.isCurrentTaildropReceive(result.requestId, 'stage', 'exporting')) {
        return;
      }
      if (!handled) {
        this.failTaildropReceive('export_failed');
        return;
      }
      this.requestTaildropReceiveDelete(result.requestId, result.name, result.size);
      return;
    }
    if (result.action === 'delete' && result.state === 'completed') {
      if (this.taildropReceiveStrategy === 'discard') {
        this.completeTaildropDiscard();
      } else {
        this.completeTaildropReceive();
      }
      return;
    }
    if (result.action === 'clear' && result.state === 'completed') {
      if (!this.clearLocalTaildropInboxCache()) {
        this.failTaildropReceive('clear_failed');
        return;
      }
      const requestedFromSettings: boolean = this.cacheClearRequestedFromSettings;
      this.clearTaildropInboxViewState();
      this.recordDiagnosticEvent('taildrop_receive_cache_cleared', 'transfer');
      this.resetTaildropReceiveOperation();
      if (requestedFromSettings) {
        this.finishSettingsCacheClear(true);
      } else {
        this.notifyCacheContentsChanged();
        this.showToast($r('app.string.transfer_cache_cleared'));
      }
      return;
    }
    this.failTaildropReceive('invalid_result');
  }

  private isCurrentTaildropReceive(requestId: number, action: string, state: string): boolean {
    return this.taildropReceiveInProgress && this.taildropReceive.requestId === requestId &&
      this.taildropReceive.action === action && this.taildropReceive.state === state;
  }

  private prepareTaildropMediaForSave(result: TaildropReceiveResult): string | undefined {
    const safeName: string = this.sanitizeTaildropFileName(result.name, 0);
    const mediaPath: string = `${this.taildropInboxRoot()}/${result.requestId}-${safeName}`;
    try {
      if (fileIo.accessSync(mediaPath)) {
        fileIo.unlinkSync(mediaPath);
      }
      fileIo.renameSync(result.path, mediaPath);
      const stat: fileIo.Stat = fileIo.statSync(mediaPath);
      if (!stat.isFile() || stat.size !== result.size) {
        fileIo.unlinkSync(mediaPath);
        return undefined;
      }
      return mediaPath;
    } catch (_error) {
      return undefined;
    }
  }

  private requestTaildropReceiveDelete(requestId: number, name: string, size: number): void {
    const deleteRequest: TaildropReceiveRequest = {
      requestId: requestId, action: 'delete', name: name, inboxRoot: '', path: ''
    };
    this.taildropReceive = {
      requestId: requestId, action: 'delete', state: 'deleting', reason: '', name: name,
      size: size, path: ''
    };
    this.taildropReceiveStateStartedAtMs = Date.now();
    if (!this.writeAtomicTaildropRequest(this.taildropReceiveRequestPath(), requestId,
      JSON.stringify(deleteRequest))) {
      this.failTaildropReceive('delete_failed');
    }
  }

  private handleTaildropMediaSaveClick(result: SaveButtonOnClickResult): void {
    if (!this.validateTaildropMediaSaveAuthorization(result)) {
      return;
    }
    this.startTaildropMediaSave();
  }

  private handlePreparedTaildropMediaSaveClick(
    file: TaildropWaitingFileSummary,
    result: SaveButtonOnClickResult
  ): void {
    if (!this.validateTaildropMediaSaveAuthorization(result)) {
      return;
    }
    const preview: TaildropMediaPreview | undefined = this.findTaildropMediaPreview(file);
    if (preview === undefined) {
      return;
    }
    this.interruptTaildropMediaPrefetch();
    if (this.taildropReceiveInProgress) {
      if (this.taildropReceive.name === file.name &&
        this.taildropReceive.state === 'awaiting_gallery_save') {
        this.startTaildropMediaSave();
        return;
      }
      if (this.taildropReceive.state === 'awaiting_text_preview') {
        this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseInOut }, () => {
          this.resetTaildropReceiveOperation();
        });
        this.startPreparedTaildropMediaSave(file);
        return;
      }
      this.taildropPendingMediaSave = file;
      this.recordDiagnosticEvent('taildrop_media_save_queued', 'transfer');
      return;
    }
    this.startPreparedTaildropMediaSave(file);
  }

  private startPreparedTaildropFileSave(file: TaildropWaitingFileSummary): void {
    const cached: TaildropCachedFile | undefined = this.findTaildropCachedFile(file);
    if (cached === undefined) {
      if (this.taildropState !== 'ready') {
        this.showToast($r('app.string.transfer_connect_first_title'));
      } else {
        this.startTaildropReceive(file);
      }
      return;
    }
    if (this.taildropSendActive() || this.taildropReceiveInProgress) {
      this.showToast($r('app.string.transfer_busy_message'));
      return;
    }
    this.taildropReceiveStrategy = 'file';
    this.taildropReceiveExpectedSize = cached.size;
    this.taildropReceiveInProgress = true;
    this.taildropReceive = {
      requestId: cached.requestId,
      action: 'stage',
      state: 'selecting_destination',
      reason: '',
      name: cached.name,
      size: cached.size,
      path: cached.path
    };
    this.selectTaildropReceiveDestination(this.taildropReceive).then((destinationUri: string) => {
      if (!this.isCurrentTaildropReceive(cached.requestId, 'stage', 'selecting_destination')) {
        return;
      }
      if (destinationUri.length === 0) {
        this.resetTaildropReceiveOperation();
        return;
      }
      this.taildropReceiveDestinationUri = destinationUri;
      this.taildropReceive = {
        requestId: cached.requestId,
        action: 'stage',
        state: 'exporting',
        reason: '',
        name: cached.name,
        size: cached.size,
        path: cached.path
      };
      this.copyTaildropStagedFile(cached.path, destinationUri, cached.size).then((saved: boolean) => {
        if (!this.isCurrentTaildropReceive(cached.requestId, 'stage', 'exporting')) {
          return;
        }
        if (!saved) {
          this.failTaildropReceive('export_failed');
          return;
        }
        if (this.taildropState === 'ready') {
          this.requestTaildropReceiveDelete(cached.requestId, cached.name, cached.size);
        } else {
          this.completeTaildropReceive();
        }
      }).catch(() => this.failTaildropReceive('export_failed'));
    }).catch(() => this.failTaildropReceive('export_failed'));
  }

  private startPreparedTaildropMediaSave(file: TaildropWaitingFileSummary): void {
    const preview: TaildropMediaPreview | undefined = this.findTaildropMediaPreview(file);
    if (preview === undefined || this.taildropReceiveInProgress) {
      return;
    }
    this.taildropReceiveStrategy = 'media';
    this.taildropReceiveDestinationUri = '';
    this.taildropReceiveExpectedSize = preview.size;
    this.taildropReceiveMediaType = preview.mediaType;
    this.taildropReceiveInProgress = true;
    this.taildropReceive = {
      requestId: preview.requestId,
      action: 'stage',
      state: 'awaiting_gallery_save',
      reason: '',
      name: preview.name,
      size: preview.size,
      path: preview.path
    };
    this.taildropReceiveStateStartedAtMs = 0;
    this.startTaildropMediaSave();
  }

  private validateTaildropMediaSaveAuthorization(result: SaveButtonOnClickResult): boolean {
    if (result === SaveButtonOnClickResult.CANCELED_BY_USER) {
      return false;
    }
    if (result !== SaveButtonOnClickResult.SUCCESS) {
      this.recordDiagnosticEvent('taildrop_media_save_authorization_failed', `${result}`);
      this.showToast($r('app.string.transfer_media_save_authorization_failed'));
      return false;
    }
    return true;
  }

  private startTaildropMediaSave(): void {
    if (this.taildropMediaSaveInProgress || this.taildropReceive.state !== 'awaiting_gallery_save') {
      return;
    }
    this.taildropMediaSaveInProgress = true;
    this.saveTaildropMediaToGallery().then((saved: boolean) => {
      if (!saved) {
        this.restoreTaildropMediaSaveAfterFailure(false);
      }
    }).catch((error: BusinessError) => {
      this.recordDiagnosticEvent('taildrop_media_save_failed', 'gallery_dialog', error.code ?? -1);
      this.restoreTaildropMediaSaveAfterFailure(true);
    }).finally(() => {
      this.taildropMediaSaveInProgress = false;
    });
  }

  private cancelTaildropMediaSave(): void {
    if (this.taildropMediaSaveInProgress || this.taildropReceive.state !== 'awaiting_gallery_save') {
      return;
    }
    this.recordDiagnosticEvent('taildrop_media_save_cancelled', 'transfer');
    this.resetTaildropReceiveOperation();
    this.resumePendingTaildropAction();
  }

  private cancelTaildropReceiveOperation(): void {
    if (!this.taildropReceiveInProgress) {
      return;
    }
    this.recordDiagnosticEvent('taildrop_receive_cancelled', this.taildropReceive.state);
    this.resetTaildropReceiveOperation();
    this.resumePendingTaildropAction();
    this.showToast($r('app.string.transfer_receive_cancelled'));
  }

  private restoreTaildropMediaSaveAfterFailure(showFailure: boolean): void {
    if (!this.taildropMediaSaveInProgress || this.taildropReceive.state !== 'saving_gallery' ||
      this.taildropReceive.path.length === 0) {
      return;
    }
    this.taildropReceive = {
      requestId: this.taildropReceive.requestId,
      action: 'stage',
      state: 'awaiting_gallery_save',
      reason: '',
      name: this.taildropReceive.name,
      size: this.taildropReceive.size,
      path: this.taildropReceive.path
    };
    if (showFailure) {
      this.showToast($r('app.string.transfer_media_save_failed'));
    }
  }

  private async saveTaildropMediaToGallery(): Promise<boolean> {
    const mediaType: photoAccessHelper.PhotoType | undefined = this.taildropReceiveMediaType;
    const staged: TaildropReceiveResult = this.taildropReceive;
    const extension: string = this.taildropFileExtension(staged.name);
    if (mediaType === undefined || extension.length === 0 ||
      staged.state !== 'awaiting_gallery_save' || staged.path.length === 0) {
      return false;
    }
    const stat: fileIo.Stat = fileIo.statSync(staged.path);
    if (!stat.isFile() || stat.size !== staged.size) {
      this.failTaildropReceive('export_failed');
      return false;
    }
    this.taildropReceive = {
      requestId: staged.requestId, action: 'stage', state: 'saving_gallery', reason: '',
      name: staged.name, size: staged.size, path: staged.path
    };
    this.taildropReceiveStateStartedAtMs = Date.now();
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
    const sourceUri: string = fileUri.getUriFromPath(staged.path);
    const changeRequest: photoAccessHelper.MediaAssetChangeRequest =
      mediaType === photoAccessHelper.PhotoType.IMAGE ?
        photoAccessHelper.MediaAssetChangeRequest.createImageAssetRequest(context, sourceUri) :
        photoAccessHelper.MediaAssetChangeRequest.createVideoAssetRequest(context, sourceUri);
    await phAccessHelper.applyChanges(changeRequest);
    if (!this.isCurrentTaildropReceive(staged.requestId, 'stage', 'saving_gallery')) {
      return false;
    }
    if (mediaType === photoAccessHelper.PhotoType.IMAGE) {
      this.taildropReceivePreviewPath = await this.createTaildropHistoryPreview(
        staged.path, staged.name, staged.requestId);
    }
    this.removeTaildropMediaPreview(staged.name, staged.size, true);
    try {
      if (fileIo.accessSync(staged.path)) {
        fileIo.unlinkSync(staged.path);
      }
    } catch (_error) {
      // The receive operation reset retries cleanup after the remote inbox entry is deleted.
    }
    this.recordDiagnosticEvent('taildrop_media_saved_to_gallery', 'transfer');
    if (this.taildropState === 'ready') {
      this.requestTaildropReceiveDelete(staged.requestId, staged.name, staged.size);
    } else {
      this.completeTaildropReceive();
    }
    return true;
  }

  private clearLocalTaildropInboxCache(): boolean {
    const root: string = this.taildropInboxRoot();
    try {
      if (!fileIo.accessSync(root)) {
        return true;
      }
      let cleared: boolean = true;
      fileIo.listFileSync(root).forEach((name: string) => {
        const path: string = `${root}/${name}`;
        try {
          const stat: fileIo.Stat = fileIo.statSync(path);
          if (stat.isFile()) {
            fileIo.unlinkSync(path);
          } else {
            cleared = false;
          }
        } catch (_error) {
          cleared = false;
        }
      });
      this.notifyCacheContentsChanged();
      return cleared;
    } catch (_error) {
      return false;
    }
  }

  private async handleTaildropStagedFile(result: TaildropReceiveResult): Promise<boolean> {
    let handled: boolean = false;
    if (result.size === this.taildropReceiveExpectedSize) {
      if (this.taildropReceiveStrategy === 'image') {
        handled = await this.exportTaildropImageToGallery(result);
      } else if (this.taildropReceiveStrategy === 'text') {
        handled = await this.copyTaildropTextToClipboard(result);
      } else {
        handled = await this.exportTaildropReceivedFile(result);
      }
    }
    try {
      if (result.path.length > 0 && fileIo.accessSync(result.path)) {
        fileIo.unlinkSync(result.path);
      }
    } catch (_error) {
      // Extension startup cleanup removes any staged export left behind.
    }
    return handled;
  }

  private async exportTaildropImageToGallery(result: TaildropReceiveResult): Promise<boolean> {
    const extension: string = this.taildropFileExtension(result.name);
    if (!TAILDROP_IMAGE_EXTENSIONS.includes(extension)) {
      return false;
    }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const helper = photoAccessHelper.getPhotoAccessHelper(context);
      const configs: photoAccessHelper.PhotoCreationConfig[] = [{
        title: this.taildropGalleryAssetTitle(result.name),
        fileNameExtension: extension,
        photoType: photoAccessHelper.PhotoType.IMAGE
      }];
      const sourceUri: string = fileUri.getUriFromPath(result.path);
      const destinationUris: string[] = await helper.showAssetsCreationDialog([sourceUri], configs);
      if (destinationUris.length === 0) {
        return false;
      }
      this.taildropReceiveDestinationUri = destinationUris[0];
      return await this.copyTaildropStagedFile(result.path, destinationUris[0], result.size);
    } catch (_error) {
      return false;
    }
  }

  private async copyTaildropTextToClipboard(result: TaildropReceiveResult): Promise<boolean> {
    if (result.size > TAILDROP_TEXT_CLIPBOARD_MAX_BYTES) {
      return false;
    }
    try {
      const content: string = fileIo.readTextSync(result.path);
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, content);
      await pasteboard.getSystemPasteboard().setData(data);
      return true;
    } catch (_error) {
      return false;
    }
  }

  private async copyTaildropStagedFile(sourcePath: string, destinationUri: string,
    expectedSize: number): Promise<boolean> {
    let source: fileIo.File | undefined = undefined;
    let destination: fileIo.File | undefined = undefined;
    let verifier: fileIo.File | undefined = undefined;
    let copied: boolean = false;
    try {
      if (destinationUri.length === 0) {
        copied = false;
      } else {
        source = fileIo.openSync(sourcePath, fileIo.OpenMode.READ_ONLY);
        destination = fileIo.openSync(destinationUri,
          fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
        await fileIo.copyFile(source.fd, destination.fd);
        fileIo.closeSync(source);
        source = undefined;
        fileIo.closeSync(destination);
        destination = undefined;
        verifier = fileIo.openSync(destinationUri, fileIo.OpenMode.READ_ONLY);
        const stat: fileIo.Stat = fileIo.statSync(verifier.fd);
        copied = stat.isFile() && stat.size === expectedSize;
      }
    } catch (_error) {
      copied = false;
    }
    if (source !== undefined) {
      try {
        fileIo.closeSync(source);
      } catch (_error) {
        copied = false;
      }
    }
    if (destination !== undefined) {
      try {
        fileIo.closeSync(destination);
      } catch (_error) {
        copied = false;
      }
    }
    if (verifier !== undefined) {
      try {
        fileIo.closeSync(verifier);
      } catch (_error) {
        copied = false;
      }
    }
    if (!copied && destinationUri.length > 0) {
      try {
        fileIo.unlinkSync(destinationUri);
      } catch (_error) {
        // The system provider may not allow deleting a failed export URI.
      }
    }
    return copied;
  }

  private async exportTaildropReceivedFile(result: TaildropReceiveResult): Promise<boolean> {
    return await this.copyTaildropStagedFile(result.path, this.taildropReceiveDestinationUri, result.size);
  }

  private addTaildropReceiveRecord(state: string, reason: string): void {
    const record: TaildropTransferRecord = {
      requestId: this.taildropReceive.requestId,
      direction: 'receive',
      state: state,
      reason: reason,
      targetKey: '',
      targetName: '',
      fileName: this.taildropReceive.name,
      fileCount: 1,
      totalBytes: this.taildropReceive.size > 0 ? this.taildropReceive.size : this.taildropReceiveExpectedSize,
      previewPath: this.taildropReceivePreviewPath,
      completedAtMs: Date.now()
    };
    this.taildropHistory = [record].concat(this.taildropHistory).slice(0, TAILDROP_HISTORY_LIMIT);
    this.persistTaildropHistory();
  }

  private completeTaildropReceive(): void {
    const receivedName: string = this.taildropReceive.name;
    const receivedSize: number = this.taildropReceive.size;
    const receiveStrategy: string = this.taildropReceiveStrategy;
    this.addTaildropReceiveRecord('completed', '');
    this.removeTaildropMediaPreview(receivedName, receivedSize, true);
    this.removeTaildropCachedFile(receivedName, receivedSize, true);
    this.taildropWaitingFiles = this.taildropWaitingFiles.filter(
      (file: TaildropWaitingFileSummary) => file.name !== receivedName);
    this.persistTaildropInbox();
    this.recordDiagnosticEvent('taildrop_receive_completed', 'transfer');
    if (receiveStrategy === 'image' ||
      (receiveStrategy === 'media' && this.taildropReceiveMediaType === photoAccessHelper.PhotoType.IMAGE)) {
      this.showToast($r('app.string.transfer_image_saved'));
    } else if (receiveStrategy === 'text' || receiveStrategy === 'text-preview') {
      this.showToast($r('app.string.transfer_text_copied'));
    } else {
      this.showToast($r('app.string.transfer_receive_completed'));
    }
    this.resetTaildropReceiveOperation();
    this.resumePendingTaildropAction();
    this.notifyCacheContentsChanged();
  }

  private completeTaildropDiscard(): void {
    const discardedName: string = this.taildropReceive.name;
    this.removeTaildropMediaPreview(discardedName, this.taildropReceive.size, true);
    this.removeTaildropCachedFile(discardedName, this.taildropReceive.size, true);
    this.taildropWaitingFiles = this.taildropWaitingFiles.filter(
      (file: TaildropWaitingFileSummary) => file.name !== discardedName);
    this.persistTaildropInbox();
    this.recordDiagnosticEvent('taildrop_receive_discarded', 'transfer');
    this.showToast($r('app.string.transfer_discard_completed'));
    this.resetTaildropReceiveOperation();
    this.resumePendingTaildropAction();
    this.notifyCacheContentsChanged();
  }

  private failTaildropReceive(reason: string): void {
    if (this.taildropReceiveStrategy === 'media-prefetch' ||
      this.taildropReceiveStrategy === 'file-prefetch') {
      this.failTaildropMediaPrefetch(reason);
      return;
    }
    const settingsCacheClearFailed: boolean =
      this.cacheClearRequestedFromSettings && this.taildropReceive.action === 'clear';
    if (this.taildropReceive.requestId > 0 && this.taildropReceive.action !== 'clear') {
      this.addTaildropReceiveRecord('failed', reason);
    }
    this.recordDiagnosticEvent('taildrop_receive_failed', reason);
    if (!settingsCacheClearFailed) {
      this.showToast(this.taildropReceiveFailureMessage(reason));
    }
    this.resetTaildropReceiveOperation();
    this.resumePendingTaildropAction();
    if (settingsCacheClearFailed) {
      this.finishSettingsCacheClear(false);
    }
  }

  private failTaildropMediaPrefetch(reason: string): void {
    const key: string = this.taildropAutoPrefetchKey;
    if (key.length > 0 && !this.taildropAutoPrefetchFailedKeys.includes(key)) {
      this.taildropAutoPrefetchFailedKeys = this.taildropAutoPrefetchFailedKeys.concat([key]);
    }
    this.recordDiagnosticEvent('taildrop_media_preview_failed', reason);
    this.taildropAutoPrefetchKey = '';
    this.resetTaildropReceiveOperation();
    this.resumePendingTaildropAction();
  }

  private resetTaildropReceiveOperation(): void {
    const receivePath: string = this.taildropReceive.path;
    const pathIsCachedPreview: boolean = this.taildropMediaPreviews.some(
      (preview: TaildropMediaPreview) => preview.path === receivePath) ||
      this.taildropCachedFiles.some((cached: TaildropCachedFile) => cached.path === receivePath);
    if (receivePath.length > 0 && !pathIsCachedPreview) {
      try {
        if (fileIo.accessSync(receivePath)) {
          fileIo.unlinkSync(receivePath);
        }
      } catch (_error) {
        // Extension startup cleanup removes any staged export left behind.
      }
    }
    this.taildropReceiveInProgress = false;
    this.taildropReceiveRouting = false;
    this.taildropReceiveResponseInFlight = false;
    this.taildropMediaSaveInProgress = false;
    this.taildropPickerOpen = false;
    this.taildropReceiveStateStartedAtMs = 0;
    this.taildropReceiveDestinationUri = '';
    this.taildropReceiveExpectedSize = 0;
    this.taildropReceiveMediaType = undefined;
    this.taildropReceivePreviewPath = '';
    this.taildropReceiveStrategy = 'none';
    this.taildropReceive = emptyTaildropReceive();
    this.taildropReceivedText = '';
    this.taildropTextPreviewVisible = false;
  }

  private taildropReceiveFailureMessage(reason: string): ResourceStr {
    if (this.taildropReceive.action === 'clear' || reason === 'clear_failed') {
      return $r('app.string.transfer_clear_cache_failed');
    }
    if (reason === 'file_unavailable') {
      return $r('app.string.transfer_receive_unavailable');
    }
    if (reason === 'no_space') {
      return $r('app.string.transfer_receive_no_space');
    }
    if (reason === 'timeout') {
      return $r('app.string.transfer_save_timeout');
    }
    if (reason === 'delete_failed') {
      return this.taildropReceiveStrategy === 'discard' ?
        $r('app.string.transfer_discard_failed') : $r('app.string.transfer_receive_delete_failed');
    }
    if (reason === 'discard_failed') {
      return $r('app.string.transfer_discard_failed');
    }
    if (reason === 'export_failed' && this.taildropReceiveStrategy === 'image') {
      return $r('app.string.transfer_gallery_failed');
    }
    if (reason === 'export_failed' && this.taildropReceiveStrategy === 'text') {
      return $r('app.string.transfer_text_copy_failed');
    }
    return $r('app.string.transfer_receive_failed');
  }

  private emptyPeerConnectivityResult(reason: string = ''): PeerConnectivityResult {
    return {
      state: reason.length > 0 ? 'failed' : '', reason: reason,
      sent: 0, received: 0, lossPercent: 0,
      minLatencyMs: 0, avgLatencyMs: 0, maxLatencyMs: 0
    };
  }

  private parsePeerConnectivityResult(resultText: string): PeerConnectivityResult {
    try {
      const result: PeerConnectivityResult = JSON.parse(resultText) as PeerConnectivityResult;
      if (result.state === 'reachable' || result.state === 'degraded' ||
        result.state === 'failed' || result.state === 'skipped') {
        return result;
      }
    } catch (_error) {
      // Fall through to the sanitized invalid-result state.
    }
    return this.emptyPeerConnectivityResult('invalid_result');
  }

  private finishPeerConnectivity(result: PeerConnectivityResult): void {
    this.peerConnectivityResult = result;
    this.peerConnectivityInProgress = false;
    this.stopPeerConnectivityPolling();
    this.recordDiagnosticEvent('peer_connectivity_completed', result.state);
  }

  private startPeerConnectivity(peer: PeerSummary): void {
    if (this.peerConnectivityInProgress || !peer.online) {
      return;
    }
    this.stopPeerConnectivityPolling();
    this.peerConnectivityKey = peer.key;
    this.peerConnectivityResult = this.emptyPeerConnectivityResult();
    this.peerConnectivityInProgress = true;
    this.peerConnectivityRequestId = Date.now();
    this.recordDiagnosticEvent('peer_connectivity_requested', this.isConnected() ? 'vpn' : 'ui');
    if (!this.isConnected()) {
      nativeBridge.backendPeerConnectivityAsync(peer.key)
        .then((resultText: string) => {
          this.finishPeerConnectivity(this.parsePeerConnectivityResult(resultText));
        })
        .catch(() => {
          this.finishPeerConnectivity(this.emptyPeerConnectivityResult('backend_unavailable'));
        });
      return;
    }
    const responsePath: string = this.peerConnectivityFilePath(PEER_CONNECTIVITY_RESPONSE_FILE_NAME);
    this.writePrivateTextFile(responsePath, '');
    const request: PeerConnectivityRequest = {
      requestId: this.peerConnectivityRequestId,
      peerKey: peer.key
    };
    const requestPath: string = this.peerConnectivityFilePath(PEER_CONNECTIVITY_REQUEST_FILE_NAME);
    if (!this.writePrivateTextFile(requestPath, JSON.stringify(request))) {
      this.finishPeerConnectivity(this.emptyPeerConnectivityResult('extension_error'));
      return;
    }
    this.pollPeerConnectivityResponse(0);
  }

  private pollPeerConnectivityResponse(attempt: number): void {
    if (!this.peerConnectivityInProgress) {
      return;
    }
    if (attempt >= 50) {
      this.finishPeerConnectivity(this.emptyPeerConnectivityResult('timeout'));
      return;
    }
    const responsePath: string = this.peerConnectivityFilePath(PEER_CONNECTIVITY_RESPONSE_FILE_NAME);
    try {
      if (fileIo.accessSync(responsePath)) {
        const responseText: string = fileIo.readTextSync(responsePath).trim();
        if (responseText.length > 0) {
          const response: PeerConnectivityResponse = JSON.parse(responseText) as PeerConnectivityResponse;
          if (response.requestId === this.peerConnectivityRequestId) {
            this.writePrivateTextFile(responsePath, '');
            this.finishPeerConnectivity(this.parsePeerConnectivityResult(response.result));
            return;
          }
        }
      }
    } catch (_error) {
      // The extension may be replacing the response file; retry within the timeout.
    }
    this.peerConnectivityPollTimer = setTimeout(() => {
      this.pollPeerConnectivityResponse(attempt + 1);
    }, 300);
  }

  private stopPeerConnectivityPolling(): void {
    if (this.peerConnectivityPollTimer >= 0) {
      clearTimeout(this.peerConnectivityPollTimer);
      this.peerConnectivityPollTimer = -1;
    }
  }

  private peerConnectivityReason(reason: string): ResourceStr {
    if (reason === 'peer_offline') {
      return $r('app.string.peer_connectivity_offline');
    }
    if (reason === 'no_address') {
      return $r('app.string.peer_connectivity_no_address');
    }
    if (reason === 'no_response' || reason === 'timeout') {
      return $r('app.string.peer_connectivity_no_response');
    }
    return $r('app.string.peer_connectivity_unavailable');
  }

  private secondaryBackground(): ResourceColor {
    return $r('sys.color.comp_background_tertiary');
  }

  private accountInitial(): string {
    const source: string = this.accountSummary.displayName.length > 0 ?
      this.accountSummary.displayName : this.accountSummary.loginName;
    return source.length > 0 ? source.substring(0, 1).toUpperCase() : 'T';
  }

  @Builder
  private SectionHeader(title: ResourceStr, description?: ResourceStr) {
    Column({ space: 2 }) {
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
      if (description !== undefined) {
        Text(description)
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
          .lineHeight(18)
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private SettingsGroupHeader(title: ResourceStr) {
    Text(title)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_primary'))
      .width('100%')
      .padding({ top: 8, bottom: 2 })
  }

  @Builder
  private ButtonContent(label: ResourceStr, primary: boolean, loading: boolean) {
    Row({ space: 8 }) {
      if (loading) {
        LoadingProgress()
          .width(20)
          .height(20)
          .color(primary ? $r('sys.color.font_on_primary') : $r('sys.color.icon_primary'))
      }
      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(primary ? $r('sys.color.font_on_primary') : $r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
  }

  @Builder
  private ConnectButtonContent() {
    Stack({ alignContent: Alignment.Center }) {
      Text($r('app.string.action_connect'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_on_primary'))
        .opacity(this.connectInProgress || this.isConnecting() ? 0 : 1)
      if (this.connectInProgress || this.isConnecting()) {
        Row({ space: 8 }) {
          LoadingProgress()
            .id('vpn-start-loading')
            .width(20)
            .height(20)
            .color($r('sys.color.font_on_primary'))
          Text($r('app.string.action_connecting'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_on_primary'))
        }
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
  }

  @Builder
  private LoginButtonContent() {
    Stack({ alignContent: Alignment.Center }) {
      Text($r('app.string.action_login'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_on_primary'))
        .opacity(this.loginInProgress ? 0 : 1)
      if (this.loginInProgress) {
        Row({ space: 8 }) {
          LoadingProgress()
            .id('login-open-loading')
            .width(20)
            .height(20)
            .color($r('sys.color.font_on_primary'))
          Text($r('app.string.action_login'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_on_primary'))
        }
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
  }

  @Builder
  private ConnectButton() {
    Button({
      type: ButtonType.ROUNDED_RECTANGLE,
      stateEffect: true,
      buttonStyle: ButtonStyleMode.EMPHASIZED,
      controlSize: ControlSize.NORMAL
    }) {
      this.ConnectButtonContent()
    }
      .id('vpn-start')
      .width('100%')
      .height(52)
      .enabled(!this.connectInProgress && !this.isConnecting())
      .onClick(() => this.beginVpnConnection())
  }

  @Builder
  private LoginButton() {
    Button({
      type: ButtonType.ROUNDED_RECTANGLE,
      stateEffect: true,
      buttonStyle: ButtonStyleMode.EMPHASIZED,
      controlSize: ControlSize.NORMAL
    }) {
      this.LoginButtonContent()
    }
      .id('login-open')
      .width('100%')
      .height(52)
      .enabled(!this.loginInProgress)
      .onClick(() => this.openSecureLogin())
  }

  @Builder
  private ImmersiveButton(label: ResourceStr, nodeId: string, primary: boolean,
    enabled: boolean, action: () => void, loading: boolean = false) {
    if (this.glowLevel === 3) {
      Button({
        type: ButtonType.ROUNDED_RECTANGLE,
        stateEffect: true,
        buttonStyle: primary ? ButtonStyleMode.EMPHASIZED : ButtonStyleMode.NORMAL,
        controlSize: ControlSize.NORMAL
      }) {
        this.ButtonContent(label, primary, loading)
      }
        .id(nodeId)
        .width('100%')
        .height(52)
        .visualEffect(new hdsEffect.HdsEffectBuilder()
          .pressShadow(hdsEffect.PressShadowType.BLEND_WHITE)
          .buildEffect())
        .opacity(enabled ? 1 : 0.4)
        .enabled(enabled)
        .onClick(action)
    } else {
      Button({
        type: ButtonType.ROUNDED_RECTANGLE,
        stateEffect: true,
        buttonStyle: primary ? ButtonStyleMode.EMPHASIZED : ButtonStyleMode.NORMAL,
        controlSize: ControlSize.NORMAL
      }) {
        this.ButtonContent(label, primary, loading)
      }
        .id(nodeId)
        .width('100%')
        .height(52)
        .backgroundEffect({
          radius: this.glowRadius(),
          saturation: this.glowSaturation(),
          brightness: this.glowBrightness(),
          color: primary ? $r('sys.color.comp_background_emphasize') : this.glowSurface(),
          adaptiveColor: AdaptiveColor.DEFAULT
        }, { disableSystemAdaptation: false })
        .visualEffect(new hdsEffect.HdsEffectBuilder()
          .pressShadow(hdsEffect.PressShadowType.BLEND_WHITE)
          .buildEffect())
        .shadow({
          radius: this.glowLevel === 0 ? 12 : (this.glowLevel === 1 ? 8 : 4),
          color: this.glowColor(),
          offsetY: 3
        })
        .opacity(enabled ? 1 : 0.4)
        .enabled(enabled)
        .onClick(action)
    }
  }

  @Builder
  private StandardActionButton(label: ResourceStr, nodeId: string, primary: boolean,
    enabled: boolean, action: () => void, loading: boolean = false) {
    Button({
      type: ButtonType.ROUNDED_RECTANGLE,
      stateEffect: true,
      buttonStyle: primary ? ButtonStyleMode.EMPHASIZED : ButtonStyleMode.NORMAL,
      controlSize: ControlSize.NORMAL
    }) {
      this.ButtonContent(label, primary, loading)
    }
      .id(nodeId)
      .width('100%')
      .height(48)
      .opacity(enabled ? 1 : 0.4)
      .enabled(enabled)
      .onClick(action)
  }

  private connectionActionNodeId(): string {
    if (!this.controlServerConfirmed) {
      return 'control-server-setup';
    }
    if (this.isConnected()) {
      return 'vpn-stop';
    }
    if (this.isBackendLoading()) {
      return 'backend-starting';
    }
    if (this.needsLogin()) {
      return 'account-login';
    }
    return 'vpn-connect';
  }

  private connectionActionLoading(): boolean {
    return this.isBackendLoading() || this.isConnecting() || this.loginInProgress ||
      this.disconnectInProgress;
  }

  private connectionActionEnabled(): boolean {
    return !this.connectionActionLoading() && !this.deviceNeedsApproval();
  }

  private connectionActionBackground(): ResourceColor {
    return this.isConnected() ? $r('sys.color.comp_background_emphasize') : this.secondaryBackground();
  }

  private connectionActionForeground(): ResourceColor {
    if (this.isConnected()) {
      return $r('sys.color.font_on_primary');
    }
    if (this.connectionActionLoading()) {
      return $r('app.color.status_warning');
    }
    return $r('app.color.status_neutral');
  }

  private runConnectionAction(): void {
    if (!this.controlServerConfirmed) {
      this.openControlServerSettings();
    } else if (this.isConnected()) {
      this.stopVpnProbe();
    } else if (this.needsLogin()) {
      this.openSecureLogin();
    } else {
      this.beginVpnConnection();
    }
  }

  @Builder
  private ConnectionCircleButton() {
    Button({
      type: ButtonType.Circle,
      stateEffect: true,
      buttonStyle: ButtonStyleMode.NORMAL,
      controlSize: ControlSize.NORMAL
    }) {
      if (this.connectionActionLoading()) {
        LoadingProgress()
          .width(19)
          .height(19)
          .color(this.connectionActionForeground())
      } else {
        Image($r('app.media.connection_filled'))
          .width(19)
          .height(19)
          .fillColor(this.connectionActionForeground())
      }
    }
    .id(this.connectionActionNodeId())
    .width(42)
    .height(42)
    .backgroundColor(this.connectionActionBackground())
    .enabled(this.connectionActionEnabled())
    .opacity(this.connectionActionEnabled() ? 1 : 0.65)
    .accessibilityText(this.isConnected() ?
      $r('app.string.action_disconnect') : $r('app.string.action_connect'))
    .onClick(() => this.runConnectionAction())
  }

  @Builder
  private TrafficChart() {
    Stack({ alignContent: Alignment.Center }) {
      Divider()
        .width('100%')
        .color($r('sys.color.comp_divider'))
      Polyline({ width: this.trafficChartWidth(), height: 68 })
        .points(this.trafficChartPoints(true))
        .fill(Color.Transparent)
        .stroke($r('sys.color.icon_emphasize'))
        .strokeWidth(2)
        .strokeLineCap(LineCapStyle.Round)
        .strokeLineJoin(LineJoinStyle.Round)
      Polyline({ width: this.trafficChartWidth(), height: 68 })
        .points(this.trafficChartPoints(false))
        .fill(Color.Transparent)
        .stroke('#8B5CF6')
        .strokeWidth(2)
        .strokeLineCap(LineCapStyle.Round)
        .strokeLineJoin(LineJoinStyle.Round)
    }
    .id('traffic-chart')
    .width('100%')
    .height(68)
    .clip(true)
    .backgroundColor(this.secondaryBackground())
    .borderRadius(12)
  }

  @Builder
  private TrafficChartBackdrop() {
    Stack({ alignContent: Alignment.Center }) {
      Polyline({ width: this.trafficChartWidth(), height: 42 })
        .points(this.trafficChartPoints(true, 42))
        .fill(Color.Transparent)
        .stroke($r('sys.color.icon_emphasize'))
        .strokeWidth(2)
        .strokeLineCap(LineCapStyle.Round)
        .strokeLineJoin(LineJoinStyle.Round)
        .opacity(0.20)
      Polyline({ width: this.trafficChartWidth(), height: 42 })
        .points(this.trafficChartPoints(false, 42))
        .fill(Color.Transparent)
        .stroke('#8B5CF6')
        .strokeWidth(2)
        .strokeLineCap(LineCapStyle.Round)
        .strokeLineJoin(LineJoinStyle.Round)
        .opacity(0.18)
    }
    .width('100%')
    .height(42)
    .clip(true)
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private TrafficSummary() {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        Column({ space: 2 }) {
          Text($r('app.string.traffic_download'))
            .fontSize(11)
            .fontColor($r('sys.color.font_secondary'))
          Text(`↓ ${this.formatTrafficBytes(this.trafficDownloadBytes)}`)
            .id('traffic-download-total')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text(this.formatTrafficBytes(this.trafficDownloadRate, true))
            .fontSize(11)
            .fontColor($r('sys.color.icon_emphasize'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Column({ space: 2 }) {
          Text($r('app.string.traffic_upload'))
            .fontSize(11)
            .fontColor($r('sys.color.font_secondary'))
          Text(`↑ ${this.formatTrafficBytes(this.trafficUploadBytes)}`)
            .id('traffic-upload-total')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text(this.formatTrafficBytes(this.trafficUploadRate, true))
            .fontSize(11)
            .fontColor('#8B5CF6')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      this.TrafficChart()
    }
    .width('100%')
  }

  @Builder
  private AnimatedTrafficSummary() {
    Column() {
      this.TrafficSummary()
    }
    .width('100%')
    .height(this.isConnected() ? 132 : 0)
    .opacity(this.isConnected() ? 1 : 0)
    .translate({ y: this.isConnected() ? 0 : -10 })
    .clip(true)
    .animation({ duration: 500, curve: Curve.EaseInOut })
  }

  @Builder
  private ConnectionPanel() {
    Column() {
      Row({ space: 12 }) {
        Column({ space: 2 }) {
          Text(this.connectionTitle())
            .id('smoke-title')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .width('100%')
          Text(this.connectionDescription())
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .lineHeight(17)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        this.ConnectionCircleButton()
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.AnimatedTrafficSummary()
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.groupBackground())
    .borderRadius(16)
    .animation({ duration: 500, curve: Curve.EaseInOut })
  }

  @Builder
  private InactiveHomeHeader() {
    this.CompactHomeHeader(false)
  }

  @Builder
  private LegacyConnectedHeader() {
    LegacyConnectedHomeHeader({
      connectionPanel: (): void => { this.ConnectionPanel(); },
      exitNodePanel: (): void => { this.ExitNodePanel(); }
    })
  }

  @Builder
  private CompactConnectedHeader() {
    this.CompactHomeHeader(true)
  }

  private compactConnectionDescription(connected: boolean): ResourceStr {
    if (!connected) {
      return this.connectionDescription();
    }
    const tailnetName: string = this.accountSummary.tailnetName;
    const tailscaleAddress: string = this.primaryTailscaleAddress(this.accountSummary.addresses);
    if (tailnetName.length === 0) {
      return tailscaleAddress;
    }
    return tailscaleAddress.length === 0 ? tailnetName : `${tailnetName} \u00B7 ${tailscaleAddress}`;
  }

  private compactExitNodeLabel(connected: boolean): ResourceStr {
    const selectedName: string = this.selectedExitNodeName();
    if (!connected) {
      return this.selectedExitNodeLabel();
    }
    return selectedName.length > 0 ? selectedName :
      '\u672A\u4F7F\u7528 \u00B7 \u65AD\u5F00\u540E\u53EF\u66F4\u6539';
  }

  @Builder
  private CompactHomeHeader(connected: boolean) {
    CompactConnectedHomeHeader({
      statusTitle: this.connectionTitle(),
      statusDescription: this.compactConnectionDescription(connected),
      statusColor: this.connectionColor(),
      downloadRate: this.formatTrafficBytes(this.trafficDownloadRate, true),
      uploadRate: this.formatTrafficBytes(this.trafficUploadRate, true),
      showTraffic: connected,
      exitNodeLabel: this.compactExitNodeLabel(connected),
      exitNodeEditable: !connected,
      exitNodeEnabled: this.isAuthenticated() && this.exitNodes.length > 0 &&
        !this.isConnected() && !this.isConnecting() && !this.connectInProgress,
      exitNodeOptions: this.exitNodeSelectOptions(),
      exitNodeSelectedIndex: this.selectedExitNodeIndex(),
      onDetails: (): void => { this.openConnectionDetails(); },
      onExitNodeInfo: (): void => { this.showExitNodeConnectionHint(); },
      onExitNodeSelect: (index: number): void => { this.onExitNodeSelect(index); },
      connectionButton: (): void => { this.ConnectionCircleButton(); },
      trafficBackdrop: (): void => { this.TrafficChartBackdrop(); }
    })
  }

  @Builder
  private HomeConnectionHeader() {
    HomeConnectionSection({
      connected: this.connectedHomeLayoutActive(),
      layoutMode: this.connectedHomeLayoutMode,
      inactiveHeader: (): void => { this.InactiveHomeHeader(); },
      legacyHeader: (): void => { this.LegacyConnectedHeader(); },
      compactHeader: (): void => { this.CompactConnectedHeader(); }
    })
  }

  @Builder
  private ConnectionDetailsContent() {
    ConnectionDetailsSheet({
      tailnetName: this.accountSummary.tailnetName,
      deviceName: this.localDeviceName(),
      tailscaleAddress: this.primaryTailscaleAddress(this.accountSummary.addresses),
      duration: this.connectedDurationLabel(),
      downloadRate: this.formatTrafficBytes(this.trafficDownloadRate, true),
      uploadRate: this.formatTrafficBytes(this.trafficUploadRate, true),
      downloadTotal: this.formatTrafficBytes(this.trafficDownloadBytes),
      uploadTotal: this.formatTrafficBytes(this.trafficUploadBytes),
      exitNodeName: this.selectedExitNodeName()
    })
  }

  @Builder
  private NetworkSettingsPanel() {
    Column({ space: 0 }) {
      Row() {
        Column({ space: 2 }) {
          Text($r('app.string.setting_subnet_routes'))
            .fontSize(14)
            .fontColor($r('sys.color.font_primary'))
          Text($r('app.string.setting_subnet_routes_description'))
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.networkSettings.routeAll })
          .id('route-all-toggle')
          .enabled(!this.isConnected() && this.isAuthenticated())
          .opacity(!this.isConnected() && this.isAuthenticated() ? 1 : 0.4)
          .onChange((enabled: boolean) => this.setNetworkSetting('routeAll', enabled))
      }
      .width('100%')
      .constraintSize({ minHeight: 56 })
      .padding({ top: 6, bottom: 6 })

      Divider().color($r('sys.color.comp_divider'))

      Row() {
        Column({ space: 2 }) {
          Text($r('app.string.setting_exit_node_lan'))
            .fontSize(14)
            .fontColor($r('sys.color.font_primary'))
          Text($r('app.string.setting_exit_node_lan_description'))
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(2)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.networkSettings.exitNodeAllowLANAccess })
          .id('exit-node-lan-toggle')
          .enabled(!this.isConnected() && this.isAuthenticated())
          .opacity(!this.isConnected() && this.isAuthenticated() ? 1 : 0.4)
          .onChange((enabled: boolean) =>
            this.setNetworkSetting('exitNodeAllowLANAccess', enabled))
      }
      .width('100%')
      .constraintSize({ minHeight: 62 })
      .padding({ top: 6, bottom: 6 })

      if (this.networkSettingStatus.startsWith('FAILED')) {
        Text($r('app.string.network_setting_failed'))
          .id('network-setting-status')
          .fontSize(12)
          .fontColor($r('app.color.status_error'))
          .width('100%')
          .padding({ top: 8 })
      }
    }
    .id('network-settings-panel')
    .width('100%')
    .padding(14)
    .backgroundColor(this.groupBackground())
    .borderRadius(16)
    .animation({ duration: 260, curve: Curve.EaseInOut })
  }

  @Builder
  private ExitNodeChoiceButton(label: ResourceStr, nodeId: string, selected: boolean,
    enabled: boolean, action: () => void) {
    Button() {
      Row({ space: 12 }) {
        Text(label)
          .fontSize(14)
          .fontColor(enabled ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Start)
        if (selected) {
          SymbolGlyph($r('sys.symbol.checkmark_circle'))
            .fontSize(22)
            .fontColor([$r('sys.color.icon_emphasize')])
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
    .id(nodeId)
    .width('100%')
    .height(52)
    .type(ButtonType.Normal)
    .borderRadius(20)
    .backgroundColor(selected ? '#14126BFF' : this.secondaryBackground())
    .backgroundEffect({
      radius: this.glowRadius(),
      saturation: this.glowSaturation(),
      brightness: this.glowBrightness(),
      color: this.glowSurface(),
      adaptiveColor: AdaptiveColor.DEFAULT
    }, { disableSystemAdaptation: false })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pressShadow(hdsEffect.PressShadowType.BLEND_WHITE)
      .buildEffect())
    .enabled(enabled)
    .opacity(enabled ? 1 : 0.45)
    .stateEffect(true)
    .onClick(action)
  }

  private selectableExitNodes(): ExitNodeChoice[] {
    return this.exitNodes.filter((choice: ExitNodeChoice) => choice.online || choice.selected);
  }

  private exitNodeSelectOptions(): SelectOption[] {
    const options: SelectOption[] = [{ value: $r('app.string.exit_node_none') }];
    this.selectableExitNodes().forEach((choice: ExitNodeChoice) => {
      options.push({ value: choice.name });
    });
    return options;
  }

  private selectedExitNodeIndex(): number {
    const choices: ExitNodeChoice[] = this.selectableExitNodes();
    const selectedIndex: number = choices.findIndex((choice: ExitNodeChoice) => choice.selected);
    return selectedIndex < 0 ? 0 : selectedIndex + 1;
  }

  private selectedExitNodeLabel(): ResourceStr {
    if (!this.isAuthenticated()) {
      return $r('app.string.setting_unavailable');
    }
    if (this.exitNodes.length === 0) {
      return $r('app.string.exit_node_empty');
    }
    const selected: ExitNodeChoice | undefined = this.exitNodes.find(
      (choice: ExitNodeChoice) => choice.selected);
    return selected === undefined ? $r('app.string.exit_node_none') : selected.name;
  }

  private onExitNodeSelect(index: number): void {
    if (index === 0) {
      this.setExitNode('');
      return;
    }
    const choices: ExitNodeChoice[] = this.selectableExitNodes();
    if (index - 1 < choices.length) {
      this.setExitNode(choices[index - 1].id);
    }
  }

  @Builder
  private ExitNodePanel() {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text($r('app.string.exit_node_title'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(this.isConnected() ? $r('app.string.exit_node_disconnect_first') :
          $r('app.string.exit_node_description'))
          .fontSize(11)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Select(this.exitNodeSelectOptions())
        .id('legacy-exit-node-status')
        .selected(this.selectedExitNodeIndex())
        .value(this.selectedExitNodeLabel())
        .controlSize(ControlSize.NORMAL)
        .font({ size: 12 })
        .optionFont({ size: 12 })
        .selectedOptionFont({ size: 12 })
        .constraintSize({ minWidth: 104, maxWidth: this.layoutWidth >= 600 ? 240 : 144 })
        .enabled(this.isAuthenticated() && this.exitNodes.length > 0 &&
          !this.isConnected() && !this.isConnecting() && !this.connectInProgress)
        .opacity(this.isAuthenticated() && this.exitNodes.length > 0 &&
          !this.isConnected() && !this.isConnecting() && !this.connectInProgress ? 1 : 0.55)
        .onSelect((index: number) => this.onExitNodeSelect(index))
    }
    .width('100%')
    .constraintSize({ minHeight: 68 })
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor(this.groupBackground())
    .borderRadius(14)
    .animation({ duration: 260, curve: Curve.EaseInOut })
  }

  @Builder
  private DevicesLoadingPanel() {
    Column({ space: 12 }) {
      this.SectionHeader($r('app.string.devices_title'), $r('app.string.action_starting'))
      Column({ space: 10 }) {
        LoadingProgress()
          .id('devices-loading')
          .width(28)
          .height(28)
          .color($r('sys.color.icon_emphasize'))
        Text($r('app.string.action_starting'))
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .width('100%')
    }
    .width('100%')
    .layoutWeight(1)
    .constraintSize({ minHeight: 160 })
    .padding(16)
    .backgroundColor(this.groupBackground())
    .borderRadius(16)
  }

  @Builder
  private DevicesSignedOutPanel() {
    Column({ space: 12 }) {
      this.SectionHeader($r('app.string.devices_title'), '')
      Column() {
        Text($r('app.string.account_profile_unavailable'))
          .fontSize(14)
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .width('100%')
    }
    .width('100%')
    .layoutWeight(1)
    .constraintSize({ minHeight: 160 })
    .padding(16)
    .backgroundColor(this.groupBackground())
    .borderRadius(16)
  }

  @Builder
  private DeviceStatusNotice(label: ResourceStr, error: boolean) {
    Text(label)
      .fontSize(10)
      .fontWeight(FontWeight.Medium)
      .fontColor(error ? $r('app.color.status_error') : $r('app.color.status_warning'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .padding({ left: 7, right: 7, top: 2, bottom: 2 })
      .borderRadius(9)
      .backgroundColor(error ? '#14B42318' : '#14B54708')
  }

  @Builder
  private LocalDeviceRow() {
    Row({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        Image(this.localDeviceIcon())
          .width(19)
          .height(19)
          .objectFit(ImageFit.Contain)
          .fillColor($r('sys.color.icon_primary'))
        Row()
          .width(8)
          .height(8)
          .borderRadius(4)
          .border({ width: 2, color: this.groupBackground() })
          .backgroundColor(this.connectionColor())
          .align(Alignment.BottomEnd)
      }
      .width(36)
      .height(36)
      .padding(7)
      .borderRadius(11)
      .backgroundColor(this.secondaryBackground())

      Column({ space: 1 }) {
        Row({ space: 6 }) {
          Text(this.localDeviceName())
            .fontSize(14)
            .fontColor($r('sys.color.font_primary'))
            .fontWeight(FontWeight.Medium)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .wordBreak(WordBreak.BREAK_ALL)
            .layoutWeight(1)
          Text($r('app.string.local_device_badge'))
            .fontSize(9)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_secondary'))
            .padding({ left: 5, right: 5, top: 1, bottom: 1 })
            .borderRadius(7)
            .backgroundColor(this.secondaryBackground())
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        Row({ space: 5 }) {
          Text(this.connectionTitle())
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
          Text('· HarmonyOS ' + this.harmonyOSVersion())
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
        }
        .width('100%')
        if (this.accountSummary.addresses.length > 0) {
          Text(this.primaryTailscaleAddress(this.accountSummary.addresses))
            .fontSize(11)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .width('100%')
        }
        if (this.deviceNeedsApproval() || this.accountSummary.keyExpired ||
          this.keyExpiresSoon(this.accountSummary.keyExpiryUnixMs)) {
          Row({ space: 5 }) {
            if (this.deviceNeedsApproval()) {
              this.DeviceStatusNotice($r('app.string.device_approval_required'), false)
            }
            if (this.accountSummary.keyExpired ||
              this.keyExpiresSoon(this.accountSummary.keyExpiryUnixMs)) {
              this.DeviceStatusNotice(this.keyExpiryLabel(this.accountSummary.keyExpired,
                this.accountSummary.keyExpiryUnixMs), this.accountSummary.keyExpired)
            }
          }
          .width('100%')
          .margin({ top: 3 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .constraintSize({ minHeight: 52 })
    .padding({ top: 6, right: 12, bottom: 6 })
  }

  @Builder
  private PeerActionSegment(label: ResourceStr, nodeId: string, enabled: boolean,
    loading: boolean, action: () => void) {
    Button({
      type: ButtonType.Normal,
      stateEffect: true,
      buttonStyle: ButtonStyleMode.TEXTUAL,
      controlSize: ControlSize.SMALL
    }) {
      Row({ space: 4 }) {
        if (loading) {
          LoadingProgress()
            .width(14)
            .height(14)
            .color($r('app.color.status_warning'))
        }
        Text(label)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')
    }
    .id(nodeId)
    .layoutWeight(1)
    .height(36)
    .padding({ left: 6, right: 6 })
    .borderRadius(0)
    .backgroundColor(Color.Transparent)
    .enabled(enabled)
    .opacity(enabled ? 1 : 0.42)
    .onClick(action)
  }

  @Builder
  private PeerDeviceRow(peer: PeerSummary) {
    Column({ space: 0 }) {
      Divider().color($r('sys.color.comp_divider'))
      Row({ space: 10 }) {
        Stack({ alignContent: Alignment.Center }) {
          Image(this.peerDeviceIcon(peer.deviceType))
            .width(19)
            .height(19)
            .objectFit(ImageFit.Contain)
            .fillColor($r('sys.color.icon_primary'))
          Row()
            .width(8)
            .height(8)
            .borderRadius(4)
            .border({ width: 2, color: this.groupBackground() })
            .backgroundColor(peer.online ? $r('app.color.status_success') :
              $r('app.color.status_offline'))
            .align(Alignment.BottomEnd)
        }
        .width(36)
        .height(36)
        .padding(7)
        .borderRadius(11)
        .backgroundColor(this.secondaryBackground())
        Column({ space: 1 }) {
          Text(this.peerDisplayName(peer.name))
            .fontSize(14)
            .fontColor($r('sys.color.font_primary'))
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Row({ space: 5 }) {
            Text(peer.online ? $r('app.string.peer_online') : $r('app.string.peer_offline'))
              .fontSize(12)
              .fontColor($r('sys.color.font_secondary'))
            if (this.peerDeviceDescription(peer).length > 0) {
              Text('· ' + this.peerDeviceDescription(peer))
                .fontSize(12)
                .fontColor($r('sys.color.font_secondary'))
            }
            if (peer.exitNode) {
              Text($r('app.string.peer_exit_node'))
                .fontSize(12)
                .fontColor($r('sys.color.font_secondary'))
            }
          }
          .width('100%')
          if (peer.addresses.length > 0) {
            Text(this.primaryTailscaleAddress(peer.addresses))
              .fontSize(11)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .width('100%')
          }
          if (this.peerServiceBadgesVisible(peer)) {
            Row({ space: 5 }) {
              SunshineStatusBadge({ state: this.streamingState(peer.key).sunshine.state })
              MediaStatusBadge({
                state: this.mediaState(peer.key).result.state,
                serviceNames: this.mediaServiceNames(peer.key)
              })
            }
            .width('100%')
            .margin({ top: 3 })
          }
          if (peer.keyExpired || this.keyExpiresSoon(peer.keyExpiryUnixMs)) {
            Row() {
              this.DeviceStatusNotice(this.keyExpiryLabel(peer.keyExpired,
                peer.keyExpiryUnixMs), peer.keyExpired)
            }
            .width('100%')
            .margin({ top: 3 })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(18)
          .fontColor([$r('sys.color.icon_secondary')])
          .rotate({ angle: this.isPeerNameExpanded(peer.key) ? 180 : 0 })
          .animation({ duration: 260, curve: Curve.EaseInOut })
      }
      .width('100%')
      .constraintSize({ minHeight: 52 })
      .padding({ top: 6, right: 12, bottom: 6 })
      .onClick(() => this.togglePeer(peer))
      if (this.isPeerNameExpanded(peer.key)) {
        Column({ space: 8 }) {
          if (peer.online && peer.addresses.length > 0) {
            DeviceConnectionInfoPanel({
              path: this.streamingState(peer.key).path,
              sunshine: this.streamingState(peer.key).sunshine,
              media: this.mediaState(peer.key).result,
              checking: this.streamingState(peer.key).checking,
              onRefresh: () => this.refreshPeerServices(peer)
            })
            DeviceActionButtons({
              sunshineState: this.streamingState(peer.key).sunshine.state,
              reachable: this.streamReachable(this.streamingState(peer.key)),
              meshConnected: this.isConnected(),
              launching: this.streamingState(peer.key).launching,
              showStreaming: this.isSunshineCandidate(peer),
              mediaState: this.mediaState(peer.key).result.state,
              mediaCount: this.mediaState(peer.key).result.services.length,
              mediaChecking: this.mediaState(peer.key).checking,
              mediaLaunching: this.mediaState(peer.key).launching,
              onStream: () => this.launchRemoteStream(peer),
              onDetectMedia: () => this.detectMediaForPeer(peer, true),
              onMedia: () => this.launchMediaForPeer(peer),
              onCopyIp: () => this.copyDeviceValue(this.primaryTailscaleAddress(peer.addresses),
                $r('app.string.peer_ip_copied'))
            })
          } else {
            Row({ space: 0 }) {
              this.PeerActionSegment($r('app.string.peer_copy_ip'), 'peer-copy-ip-' + peer.key,
                peer.addresses.length > 0, false,
                () => this.copyDeviceValue(this.primaryTailscaleAddress(peer.addresses),
                  $r('app.string.peer_ip_copied')))
            }
            .width('100%').height(36).alignItems(VerticalAlign.Center)
            .backgroundColor(this.secondaryBackground()).borderRadius(18).clip(true)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 46, right: 12, bottom: 10 })
      }
    }
    .width('100%')
  }

  @Builder
  private DevicesPanel() {
    Column({ space: 0 }) {
      this.SectionHeader($r('app.string.devices_title'),
        $r('app.string.devices_count', this.onlinePeerCount() + (this.isConnected() ? 1 : 0),
          this.peers.length + 1))
      Text('')
        .id('peer-summary')
        .height(4)
        .fontSize(1)
        .accessibilityLevel('no')
      List() {
        ListItem() {
          this.LocalDeviceRow()
        }
        LazyForEach(this.peerDataSource, (peer: PeerSummary) => {
          ListItem() {
            this.PeerDeviceRow(peer)
          }
        // onDataReloaded reuses the original child whenever its key is unchanged.
        // Include the rendered peer snapshot so live online/key/route changes
        // replace only the affected row instead of leaving its old object cached.
        }, (peer: PeerSummary) => JSON.stringify(peer))
      }
      .width('100%')
      .layoutWeight(1)
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(this.peers.length + 1 > 3 ? BarState.Auto : BarState.Off)
      .scrollBarWidth(3)
      .cachedCount(5)
    }
    .width('100%')
    .layoutWeight(1)
    .constraintSize({ minHeight: 160 })
    .padding({ left: 16, right: 4, top: 14, bottom: 10 })
    .backgroundColor(this.groupBackground())
    .borderRadius(16)
    .clip(true)
    .animation({ duration: 260, curve: Curve.EaseInOut })
  }

  @Builder
  private HomeLayoutSettingsPanel() {
    Row({ space: 10 }) {
      Column({ space: 3 }) {
        Text('主页连接布局')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text('经典布局会恢复原有连接卡片、流量图和出口节点卡片。')
          .fontSize(11)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Select([{ value: '紧凑布局' }, { value: '经典布局' }])
        .id('connected-home-layout-select')
        .selected(this.connectedHomeLayoutMode === ConnectedHomeLayoutMode.COMPACT ? 0 : 1)
        .value(this.connectedHomeLayoutMode === ConnectedHomeLayoutMode.COMPACT ? '紧凑布局' : '经典布局')
        .font({ size: 12 })
        .optionFont({ size: 12 })
        .controlSize(ControlSize.SMALL)
        .constraintSize({ minWidth: 100, maxWidth: 116 })
        .onSelect((index: number) => this.setConnectedHomeLayoutMode(index === 0 ?
          ConnectedHomeLayoutMode.COMPACT : ConnectedHomeLayoutMode.LEGACY))
    }
    .id('connected-home-layout-settings')
    .width('100%')
    .constraintSize({ minHeight: 64 })
    .padding(12)
  }

  @Builder
  private GlowSettingsPanel() {
    Row({ space: 10 }) {
      Text($r('app.string.glow_title'))
        .id('settings-page-title')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Select([
        { value: $r('app.string.glow_exquisite') },
        { value: $r('app.string.glow_gentle') },
        { value: $r('app.string.glow_smooth') },
        { value: $r('app.string.glow_adaptive') }
      ])
        .id('glow-select')
        .selected(this.glowLevel)
        .value(this.glowLevelLabel())
        .font({ size: 12 })
        .optionFont({ size: 12 })
        .controlSize(ControlSize.SMALL)
        .constraintSize({ minWidth: 100, maxWidth: 144 })
        .onSelect((index: number, _value?: string) => this.setGlowLevel(index))
    }
    .id('glow-settings')
    .width('100%')
    .constraintSize({ minHeight: 50 })
    .padding(12)
  }

  @Builder
  private AppearanceSettingsPanel() {
    Column({ space: 0 }) {
      this.GlowSettingsPanel()
      Divider()
        .color($r('sys.color.comp_divider'))
        .margin({ left: 12, right: 12 })
      this.HomeLayoutSettingsPanel()
    }
    .id('appearance-settings')
    .width('100%')
    .backgroundColor(this.groupBackground())
    .borderRadius(12)
    .clip(true)
  }

  @Builder
  private CacheSettingsPanel() {
    Row({ space: 10 }) {
      Text($r('app.string.settings_cache_title'))
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.cacheSizeLabel())
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)

      Text($r('app.string.settings_clear_cache_action'))
        .id('settings-clear-cache')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_emphasize'))
        .opacity(this.cacheClearEnabled() ? 1 : 0.42)
        .onClick(() => this.confirmClearAppCache())
    }
    .id('cache-settings')
    .width('100%')
    .constraintSize({ minHeight: 50 })
    .padding(12)
    .backgroundColor(this.groupBackground())
    .borderRadius(12)
  }

  @Builder
  private AccountPanel() {
    Column({ space: 6 }) {
      Column({ space: 6 }) {
        Row({ space: 8 }) {
          Text($r('app.string.control_server_title'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .layoutWeight(1)
          Text(this.controlServerConfirmed ? $r('app.string.control_server_confirmed') :
            $r('app.string.control_server_not_confirmed'))
            .fontSize(11)
            .fontColor(this.controlServerConfirmed ? $r('app.color.status_success') :
              $r('app.color.status_warning'))
        }
        Text($r('app.string.control_server_description'))
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .lineHeight(17)
          .width('100%')
        TextInput({
          text: this.controlServerInput,
          placeholder: DEFAULT_CONTROL_SERVER_URL
        })
          .id('control-server-input')
          .width('100%')
          .height(42)
          .fontSize(13)
          .enabled(!this.isConnected() && !this.isConnecting())
          .onChange((value: string) => {
            this.controlServerInput = value;
            this.controlServerStatus = '';
          })
        Button($r('app.string.control_server_save'), {
          type: ButtonType.ROUNDED_RECTANGLE,
          stateEffect: true,
          buttonStyle: ButtonStyleMode.NORMAL,
          controlSize: ControlSize.NORMAL
        })
          .id('control-server-save')
          .width('100%')
          .enabled(!this.isConnected() && !this.isConnecting())
          .onClick(() => this.saveControlServer())
        if (this.controlServerStatus.length > 0) {
          Text(this.controlServerStatusText())
            .fontSize(12)
            .fontColor(this.controlServerStatus === 'saved' ? $r('app.color.status_success') :
              $r('app.color.status_error'))
            .width('100%')
        }
        Divider().color($r('sys.color.comp_divider'))
      }
      .width('100%')
      .constraintSize({ maxHeight: this.controlServerEditorVisible ? 360 : 0 })
      .opacity(this.controlServerEditorVisible ? 1 : 0)
      .clip(true)
      .animation({ duration: 320, curve: Curve.EaseInOut })

      if (!this.isAuthenticated()) {
        Row({ space: 12 }) {
          Stack() {
            Image($r('app.media.tab_home'))
              .width(28)
              .height(28)
              .fillColor($r('sys.color.icon_secondary'))
          }
          .width(48)
          .height(48)
          .borderRadius(24)
          .backgroundColor(this.secondaryBackground())
          Text($r('app.string.account_profile_unavailable'))
            .fontSize(13)
            .fontColor($r('sys.color.font_secondary'))
            .layoutWeight(1)
        }
        .width('100%')
        Row({ space: 8 }) {
          if (this.controlServerConfirmed) {
            Button({
              type: ButtonType.Capsule,
              stateEffect: true,
              buttonStyle: ButtonStyleMode.EMPHASIZED,
              controlSize: ControlSize.NORMAL
            }) {
              this.ButtonContent($r('app.string.action_login'), true, this.loginInProgress)
            }
              .id('account-login')
              .height(48)
              .layoutWeight(1)
              .enabled(!this.loginInProgress)
              .onClick(() => this.openSecureLogin())
          } else {
            Row() {
              Text($r('app.string.action_login'))
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
            }
            .id('account-login-disabled')
            .height(48)
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .borderRadius(24)
            .backgroundColor(this.secondaryBackground())
          }

          if (this.controlServerConfirmed) {
            Button({
              type: ButtonType.Circle,
              stateEffect: true,
              buttonStyle: ButtonStyleMode.NORMAL,
              controlSize: ControlSize.NORMAL
            }) {
              Image($r('app.media.edit'))
                .width(20)
                .height(20)
                .fillColor($r('sys.color.icon_primary'))
            }
              .id('control-server-edit')
              .width(48)
              .height(48)
              .visualEffect(new hdsEffect.HdsEffectBuilder()
                .pressShadow(hdsEffect.PressShadowType.BLEND_WHITE)
                .buildEffect())
              .onClick(() => this.toggleControlServerEditor())
          }
        }
        .width('100%')
      } else {
        Row({ space: 10 }) {
          Stack() {
            if (this.accountSummary.profilePicURL.length > 0 && !this.avatarLoadFailed) {
              Image(this.accountSummary.profilePicURL)
                .id('account-avatar')
                .width(40)
                .height(40)
                .borderRadius(20)
                .objectFit(ImageFit.Cover)
                .onError(() => {
                  this.avatarLoadFailed = true;
                })
            } else {
              Text(this.accountInitial())
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_emphasize'))
            }
          }
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor(this.secondaryBackground())

          Column({ space: 2 }) {
            Text(this.accountSummary.displayName)
              .id('account-display-name')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
            Text(this.accountSummary.loginName)
              .id('account-login-name')
              .fontSize(12)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')

        Divider().color($r('sys.color.comp_divider'))
        this.AccountDetailRow($r('app.string.account_tailnet'),
          this.accountSummary.tailnetName, 'account-tailnet')
        this.AccountDetailRow($r('app.string.account_device'),
          this.localDeviceName(), 'account-device')

        if (!this.isConnected()) {
          Text($r('app.string.logout_description'))
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
          Button($r('app.string.logout_action'), {
            type: ButtonType.ROUNDED_RECTANGLE,
            stateEffect: true,
            buttonStyle: ButtonStyleMode.NORMAL,
            controlSize: ControlSize.NORMAL,
            role: ButtonRole.ERROR
          })
            .id('logout-open')
            .width('100%')
            .height(40)
            .visualEffect(new hdsEffect.HdsEffectBuilder()
              .pressShadow(hdsEffect.PressShadowType.BLEND_WHITE)
              .buildEffect())
            .onClick(() => this.confirmLogout())
        }
      }

      if (this.logoutStatus.startsWith('FAILED')) {
        Text($r('app.string.logout_failed'))
          .id('logout-status')
          .fontSize(12)
          .fontColor($r('app.color.status_error'))
          .width('100%')
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.groupBackground())
    .borderRadius(14)
  }

  @Builder
  private AccountDetailRow(label: ResourceStr, value: string, nodeId: string,
    action?: () => void) {
    Row({ space: 12 }) {
      Text(label)
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
      Text(value.length > 0 ? value : '—')
        .id(nodeId)
        .fontSize(13)
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .constraintSize({ minHeight: 34 })
    .onClick(() => {
      if (action !== undefined) {
        action();
      }
    })
  }

  @Builder
  private AppVersionActionRow() {
    Button({
      type: ButtonType.Normal,
      stateEffect: true,
      buttonStyle: ButtonStyleMode.TEXTUAL,
      controlSize: ControlSize.NORMAL
    }) {
      Row({ space: 12 }) {
        Text($r('app.string.app_version_label'))
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
        Text(this.appVersion)
          .id('app-version')
          .fontSize(13)
          .fontColor($r('sys.color.font_primary'))
          .textAlign(TextAlign.End)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
    }
    .id('app-version-action')
    .width('100%')
    .height(40)
    .padding(0)
    .borderRadius(12)
    .onClick(() => this.onAppVersionTap())
  }

  @Builder
  private VersionPanel() {
    Column({ space: 0 }) {
      this.AppVersionActionRow()
      Divider().color($r('sys.color.comp_divider'))
      this.AccountDetailRow($r('app.string.tailscale_version_label'),
        this.tailscaleVersion, 'tailscale-version')
      Divider().color($r('sys.color.comp_divider'))
      this.AccountDetailRow($r('app.string.feedback_label'), FEEDBACK_EMAIL,
        'feedback-email', () => this.openFeedbackEmail())
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.groupBackground())
    .borderRadius(14)
  }

  @Builder
  private DiagnosticStatus(title: ResourceStr | string, value: string, nodeId: string) {
    Column({ space: 2 }) {
      Text(title)
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
      Text(value)
        .id(nodeId)
        .fontSize(13)
        .fontColor(value.startsWith('FAILED') ?
          $r('app.color.status_error') : $r('sys.color.font_primary'))
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  private DiagnosticsPanel() {
    Column({ space: 8 }) {
      this.DiagnosticStatus('Go Bridge', this.nativeStatus, 'smoke-go-status')
      Divider().color($r('sys.color.comp_divider'))
      this.DiagnosticStatus('Tailscale Engine', this.engineStatus, 'engine-status')
      Divider().color($r('sys.color.comp_divider'))
      this.DiagnosticStatus('Control Plane', this.backendStatus, 'backend-status')
      Divider().color($r('sys.color.comp_divider'))
      this.DiagnosticStatus('VPN Extension', this.vpnStatus, 'vpn-status')
      this.StandardActionButton('Refresh status', 'backend-refresh', false, true, () => {
        this.verifyNativeBridge();
        this.refreshBackendStatus();
        this.refreshVpnProbeStatus();
      })
      this.StandardActionButton('Probe engine', 'engine-probe', false, true,
        () => this.probeUserspaceEngine())
      this.StandardActionButton('Probe control TLS', 'control-probe', false,
        this.controlServerConfirmed && this.controlServerURL === DEFAULT_CONTROL_SERVER_URL,
        () => this.runControlProbe())
      Divider().color($r('sys.color.comp_divider'))
      Text($r('app.string.diagnostic_first_run_tools_description'))
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
        .lineHeight(18)
        .width('100%')
      this.StandardActionButton($r('app.string.diagnostic_reset_first_run_action'),
        'diagnostic-reset-first-run', false, !this.diagnosticActionInProgress,
        () => this.confirmResetFirstRun())
      this.StandardActionButton($r('app.string.diagnostic_force_vpn_stop_action'),
        'diagnostic-force-vpn-stop', false, !this.diagnosticActionInProgress,
        () => this.forceStopSystemVpn())
      this.StandardActionButton($r('app.string.diagnostic_simulate_crash_action'),
        'diagnostic-simulate-crash', false, !this.diagnosticActionInProgress,
        () => this.confirmSimulateAppCrash())
      if (this.diagnosticActionStatus.length > 0) {
        this.DiagnosticStatus($r('app.string.diagnostic_action_status'),
          this.diagnosticActionStatus, 'diagnostic-action-status')
      }
      Divider().color($r('sys.color.comp_divider'))
      Text('媒体服务联动验证')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
      Text('无需真实媒体服务器：使用内置响应样本验证 Jellyfin、Emby、Plex 识别，' +
        '并检查 HosPlayer 参数链接不会包含用户名、密码或访问令牌。')
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
        .lineHeight(18)
        .width('100%')
      Row({ space: 12 }) {
        Column({ space: 2 }) {
          Text('伪装媒体服务在线')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text('将在线设备临时显示为 Jellyfin 可用；仅本次启动有效。')
            .fontSize(11)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(2)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.fakeMediaServiceOnline })
          .id('diagnostic-fake-media-online')
          .onChange((enabled: boolean) => {
            this.fakeMediaServiceOnline = enabled;
          })
      }
      .width('100%')
      .padding({ top: 6, bottom: 6 })
      this.StandardActionButton('运行媒体服务离线自检',
        'diagnostic-media-self-test', false, !this.mediaSelfTestInProgress,
        () => this.runMediaIntegrationSelfTest(), this.mediaSelfTestInProgress)
      this.StandardActionButton('复制 HosPlayer 参数原型',
        'diagnostic-hosplayer-contract', false, !this.mediaSelfTestInProgress,
        () => this.copyHosPlayerPrototype())
      if (this.mediaSelfTestStatus.length > 0) {
        this.DiagnosticStatus('媒体联动自检',
          this.mediaSelfTestStatus, 'diagnostic-media-self-test-status')
      }
      Divider().color($r('sys.color.comp_divider'))
      Text($r('app.string.diagnostic_report_description'))
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
        .lineHeight(18)
        .width('100%')
      if (this.diagnosticReportStatus.length > 0) {
        this.DiagnosticStatus($r('app.string.diagnostic_report_title'),
          this.diagnosticReportStatus, 'diagnostic-report-status')
      }
      this.StandardActionButton($r('app.string.diagnostic_report_action'),
        'diagnostic-report-generate', true, !this.diagnosticReportInProgress,
        () => this.generateDiagnosticReport(), this.diagnosticReportInProgress)
    }
    .width('100%')
    .padding({ left: 14, right: 14, bottom: 14 })
  }

  @Builder
  private DiagnosticsDisclosure() {
    Column({ space: 0 }) {
      Button({
        type: ButtonType.Normal,
        stateEffect: true,
        buttonStyle: ButtonStyleMode.TEXTUAL,
        controlSize: ControlSize.NORMAL
      }) {
        Row({ space: 12 }) {
          Column({ space: 2 }) {
            Text($r('app.string.diagnostics_title'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
              .width('100%')
            Text($r('app.string.diagnostics_description'))
              .fontSize(12)
              .fontColor($r('sys.color.font_secondary'))
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(20)
            .fontColor([$r('sys.color.icon_secondary')])
            .rotate({ angle: this.diagnosticsExpanded ? 180 : 0 })
            .animation({ duration: 220, curve: Curve.EaseInOut })
        }
        .width('100%')
        .padding({ left: 4, right: 4 })
      }
      .id('diagnostics-disclosure')
      .width('100%')
      .height(56)
      .borderRadius(12)
      .onClick(() => {
        this.getUIContext().animateTo({ duration: 260, curve: Curve.EaseInOut }, () => {
          this.diagnosticsExpanded = !this.diagnosticsExpanded;
        });
      })

      if (this.diagnosticsExpanded) {
        Divider()
          .color($r('sys.color.comp_divider'))
          .margin({ left: 16, right: 16 })
        this.DiagnosticsPanel()
      }
    }
    .width('100%')
    .padding({ left: 10, right: 10 })
    .backgroundColor(this.groupBackground())
    .borderRadius(14)
    .margin({ top: 10 })
  }

  @Builder
  private HomeContent() {
    Column({ space: 12 }) {
      this.HomeConnectionHeader()
      if (this.isBackendLoading() || this.devicesLoading) {
        this.DevicesLoadingPanel()
      } else if (!this.isAuthenticated()) {
        this.DevicesSignedOutPanel()
      } else {
        this.DevicesPanel()
      }
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: 1200 })
    .padding({
      left: this.contentMargin(),
      right: this.contentMargin(),
      top: 8,
      bottom: this.pageBottomInset()
    })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private TransferOverviewPanel() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.paperplane'))
            .fontSize(26)
            .fontColor([$r('sys.color.icon_secondary')])
        }
        .width(44)
        .height(44)
        .borderRadius(14)
        .backgroundColor(this.secondaryBackground())

        Column({ space: 3 }) {
          Text($r('app.string.transfer_taildrop_title'))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .width('100%')
          Text($r('app.string.transfer_taildrop_description'))
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .lineHeight(18)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.groupBackground())
    .borderRadius(16)
  }

  @Builder
  private TaildropTargetRow(target: TaildropTargetSummary) {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Stack() {
          Image(this.peerDeviceIcon(target.deviceType))
            .width(22)
            .height(22)
            .fillColor(target.online ? $r('sys.color.icon_primary') :
              $r('sys.color.icon_secondary'))
        }
        .width(38)
        .height(38)
        .borderRadius(12)
        .backgroundColor(this.secondaryBackground())

        Column({ space: 2 }) {
          Text(target.name)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(this.taildropTargetDescription(target))
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (!target.online) {
          Text($r('app.string.peer_offline'))
            .fontSize(11)
            .fontColor($r('sys.color.font_secondary'))
        }
      }
      .width('100%')
      .constraintSize({ minHeight: 54 })
      .padding({ left: 12, right: 12 })
      if (target.online) {
        Row() {
          this.TaildropFileMediaCapsule(target)
        }
        .width('100%')
        .padding({ left: 12, right: 12, bottom: 8 })
      }
      if (this.taildropTextEditorVisible && this.taildropTextTarget !== undefined &&
        this.taildropTextTarget.key === target.key) {
        this.TaildropTextEditorSheet()
      }
    }
    .id('taildrop-target-' + target.key)
    .width('100%')
    .opacity(target.online ? 1 : 0.42)
    .animation({ duration: 260, curve: Curve.EaseInOut })
  }

  @Builder
  private TaildropFileMediaCapsule(target: TaildropTargetSummary) {
    Row({ space: 0 }) {
      this.PeerActionSegment($r('app.string.transfer_file_action'),
        'taildrop-file-' + target.key, target.online && this.taildropContentChoiceEnabled(), false,
        () => this.chooseTaildropDocuments(target))
      Divider()
        .vertical(true)
        .height(18)
        .color($r('sys.color.comp_divider'))
      this.PeerActionSegment($r('app.string.transfer_photo_action'),
        'taildrop-media-' + target.key, target.online && this.taildropContentChoiceEnabled(), false,
        () => this.chooseTaildropPhotos(target))
      Divider()
        .vertical(true)
        .height(18)
        .color($r('sys.color.comp_divider'))
      this.PeerActionSegment($r('app.string.transfer_text_action'),
        'taildrop-text-' + target.key, target.online && this.taildropContentChoiceEnabled(), false,
        () => this.chooseTaildropText(target))
    }
    .width('100%')
    .height(36)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.secondaryBackground())
    .borderRadius(18)
    .clip(true)
  }

  @Builder
  private TaildropTargetsPanel() {
    Column({ space: 0 }) {
      ForEach(this.displayedTaildropTargets(), (target: TaildropTargetSummary, index: number) => {
        if (index > 0) {
          Divider()
            .color($r('sys.color.comp_divider'))
            .margin({ left: 62 })
        }
        this.TaildropTargetRow(target)
      // ForEach also retains children with stable keys. A target's stable peer
      // key alone therefore cannot reflect a live online/offline transition.
      }, (target: TaildropTargetSummary) => JSON.stringify(target))
    }
    .id('taildrop-targets-panel')
    .width('100%')
    .padding({ top: 4, bottom: 4 })
    .backgroundColor(this.groupBackground())
    .borderRadius(16)
  }

  @Builder
  private TaildropTargetsEmptyPanel() {
    Text(!this.isConnected() ? $r('app.string.transfer_connect_first_description') :
      this.taildropState === 'disabled' ? $r('app.string.transfer_admin_disabled_description') :
        $r('app.string.transfer_no_targets_description'))
      .fontSize(12)
      .fontColor($r('sys.color.font_secondary'))
      .lineHeight(18)
      .textAlign(TextAlign.Center)
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 20 })
      .backgroundColor(this.groupBackground())
      .borderRadius(16)
  }

  @Builder
  private TaildropTextEditorSheet() {
    Column({ space: 14 }) {
      TextArea({
        text: this.taildropTextInput,
        placeholder: $r('app.string.transfer_text_placeholder')
      })
        .width('100%')
        .height(180)
        .padding(12)
        .fontSize(14)
        .fontColor($r('sys.color.font_primary'))
        .placeholderColor($r('sys.color.font_secondary'))
        .backgroundColor(this.secondaryBackground())
        .borderRadius(14)
        .onChange((value: string) => {
          this.taildropTextInput = value;
        })
      Row({ space: 10 }) {
        Button($r('app.string.cancel_action'))
          .layoutWeight(1)
          .height(40)
          .backgroundColor(this.secondaryBackground())
          .fontColor($r('sys.color.font_primary'))
          .onClick(() => {
            this.taildropTextEditorVisible = false;
          })
        Button($r('app.string.transfer_send_action'))
          .layoutWeight(1)
          .height(40)
          .enabled(this.taildropTextInput.trim().length > 0)
          .opacity(this.taildropTextInput.trim().length > 0 ? 1 : 0.45)
          .onClick(() => this.sendTaildropText())
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 24 })
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private TaildropTextPreviewSheet() {
    Column({ space: 12 }) {
      Text(this.taildropReceive.name)
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Scroll() {
        Text(this.taildropReceivedText)
          .fontSize(14)
          .fontColor($r('sys.color.font_primary'))
          .lineHeight(21)
          .width('100%')
          .padding(14)
          .backgroundColor(this.secondaryBackground())
          .borderRadius(14)
      }
      .width('100%')
      .height(260)
      .edgeEffect(EdgeEffect.Spring)
      Row({ space: 10 }) {
        Button($r('app.string.cancel_action'))
          .layoutWeight(1)
          .height(40)
          .backgroundColor(this.secondaryBackground())
          .fontColor($r('sys.color.font_primary'))
          .onClick(() => {
            this.taildropTextPreviewVisible = false;
          })
        Button($r('app.string.transfer_copy_text_action'))
          .layoutWeight(1)
          .height(40)
          .onClick(() => this.copyTaildropTextPreview())
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 24 })
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private TaildropActiveSendPanel() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        if (this.taildropPreparing || this.taildropTransfer.state === 'queued') {
          LoadingProgress()
            .width(20)
            .height(20)
            .color($r('sys.color.icon_emphasize'))
        } else {
          SymbolGlyph($r('sys.symbol.doc'))
            .fontSize(20)
            .fontColor([$r('sys.color.icon_emphasize')])
        }
        Column({ space: 2 }) {
          Text(this.taildropPreparing ? $r('app.string.transfer_preparing') :
            $r('app.string.transfer_sending_to', this.taildropTransfer.targetName))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .width('100%')
          if (this.taildropTransfer.fileName.length > 0) {
            Text(this.taildropTransfer.fileName)
              .fontSize(12)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        if (this.taildropTransfer.state === 'queued' || this.taildropTransfer.state === 'sending') {
          Button(this.taildropCancelPending ? $r('app.string.transfer_cancelling') :
            $r('app.string.cancel_action'))
            .fontSize(12)
            .height(32)
            .backgroundColor(this.secondaryBackground())
            .fontColor($r('sys.color.font_primary'))
            .enabled(!this.taildropCancelPending)
            .opacity(this.taildropCancelPending ? 0.6 : 1)
            .onClick(() => this.cancelTaildropSend())
        }
      }
      .width('100%')
      Progress({ value: this.taildropTransferProgress(), total: 100, type: ProgressType.Linear })
        .width('100%')
        .height(4)
        .color($r('sys.color.icon_emphasize'))
      Row() {
        Text(`${this.taildropTransferProgress()}%`)
          .fontSize(11)
          .fontColor($r('sys.color.font_secondary'))
        Blank()
        Text(`${this.formatTrafficBytes(this.taildropTransfer.bytesSent)} / ` +
          `${this.formatTrafficBytes(this.taildropTransfer.totalBytes)}`)
          .fontSize(11)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      Text(this.taildropTransferSpeedText())
        .fontSize(11)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.groupBackground())
    .borderRadius(16)
  }

  @Builder
  private TaildropActiveReceivePanel() {
    Row({ space: 10 }) {
      if (this.taildropActiveReceivePreviewUri().length > 0) {
        Image(this.taildropActiveReceivePreviewUri())
          .width(44)
          .height(44)
          .borderRadius(10)
          .objectFit(ImageFit.Cover)
      } else if (this.taildropReceive.state === 'awaiting_gallery_save') {
        SymbolGlyph($r('sys.symbol.doc'))
          .fontSize(22)
          .fontColor([$r('sys.color.icon_emphasize')])
      } else {
        LoadingProgress()
          .width(20)
          .height(20)
          .color($r('sys.color.icon_emphasize'))
      }
      Column({ space: 2 }) {
        Text(this.taildropActiveReceiveText())
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .width('100%')
        if (this.taildropReceive.name.length > 0) {
          Text(this.taildropReceive.name)
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (this.taildropReceive.state === 'awaiting_gallery_save') {
        Column({ space: 4 }) {
          SaveButton({
            icon: SaveIconStyle.FULL_FILLED,
            text: SaveDescription.SAVE_TO_GALLERY,
            buttonType: ButtonType.Capsule
          })
            .height(40)
            .enabled(!this.taildropMediaSaveInProgress)
            .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {
              this.handleTaildropMediaSaveClick(result);
            })
          Button($r('app.string.cancel_action'))
            .height(28)
            .fontSize(11)
            .fontColor($r('sys.color.font_secondary'))
            .backgroundColor(Color.Transparent)
            .enabled(!this.taildropMediaSaveInProgress)
            .onClick(() => this.cancelTaildropMediaSave())
        }
      } else {
        Button($r('app.string.cancel_action'))
          .height(36)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .backgroundColor(this.secondaryBackground())
          .onClick(() => this.cancelTaildropReceiveOperation())
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.groupBackground())
    .borderRadius(16)
  }

  @Builder
  private TaildropWaitingFileRow(file: TaildropWaitingFileSummary) {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.taildropWaitingFilePreviewUri(file).length > 0) {
          Image(this.taildropWaitingFilePreviewUri(file))
            .width(40)
            .height(40)
            .borderRadius(10)
            .objectFit(ImageFit.Cover)
        } else {
          SymbolGlyph(this.taildropFileSymbol(file.name))
            .fontSize(28)
            .fontColor([$r('sys.color.icon_emphasize')])
        }
      }
      .width(44)
      .height(44)
      Column({ space: 2 }) {
        Text(file.name)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .onClick(() => {
            if (this.taildropContentKind(file) === 'text') {
              this.startTaildropTextPreview(file);
            }
          })
        Row({ space: 6 }) {
          Text(this.taildropContentKindText(file))
            .fontSize(12)
            .fontColor($r('sys.color.icon_emphasize'))
          Text(this.formatTrafficBytes(file.size))
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (this.taildropReceiveRowLoading(file) && this.taildropContentKind(file) !== 'text') {
        LoadingProgress()
          .width(20)
          .height(20)
          .color($r('sys.color.icon_emphasize'))
      } else if (this.isTaildropImageName(file.name)) {
        Row({ space: 12 }) {
          SaveButton({
            icon: SaveIconStyle.LINES,
            buttonType: ButtonType.Circle
          })
            .width(32)
            .height(32)
            .fontColor($r('sys.color.icon_primary'))
            .backgroundColor(this.groupBackground())
            .borderWidth(0)
            .padding(0)
            .enabled(this.findTaildropMediaPreview(file) !== undefined &&
              !(this.taildropReceiveMatches(file) && this.taildropMediaSaveInProgress))
            .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {
              this.handlePreparedTaildropMediaSaveClick(file, result);
            })
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.trash'))
              .fontSize(18)
              .fontColor([$r('app.color.status_error')])
          }
            .width(32)
            .height(32)
            .padding(0)
            .backgroundColor(Color.Transparent)
            .accessibilityText($r('app.string.transfer_discard_action'))
            .enabled(!this.taildropReceiveInProgress)
            .onClick(() => {
              if (!this.taildropReceiveInProgress) {
                this.confirmDiscardTaildropFile(file);
              }
            })
        }
      } else {
        Row({ space: 12 }) {
          if (this.taildropContentKind(file) === 'text') {
            Button({ type: ButtonType.Circle, stateEffect: true }) {
              if (this.taildropTextPreviewLoading(file)) {
                LoadingProgress()
                  .width(18)
                  .height(18)
                  .color($r('sys.color.icon_primary'))
              } else {
                SymbolGlyph(this.taildropReceiveMatches(file) &&
                  this.taildropReceive.state === 'awaiting_text_preview' ?
                  $r('sys.symbol.eye_slash') : $r('sys.symbol.eye'))
                  .fontSize(18)
                  .fontColor([$r('sys.color.icon_primary')])
              }
            }
              .width(32)
              .height(32)
              .padding(0)
              .backgroundColor(Color.Transparent)
              .enabled(!this.taildropTextPreviewLoading(file))
              .accessibilityText(this.taildropReceiveMatches(file) &&
                this.taildropReceive.state === 'awaiting_text_preview' ?
                $r('app.string.transfer_collapse_action') :
                $r('app.string.transfer_preview_action'))
              .onClick(() => {
                if (this.taildropReceiveMatches(file) &&
                  this.taildropReceive.state === 'awaiting_text_preview') {
                  this.collapseTaildropTextPreview();
                } else {
                  this.startTaildropTextPreview(file);
                }
              })
          }
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph(this.taildropContentKind(file) === 'text' ?
              $r('sys.symbol.text_clipboard') : $r('sys.symbol.save'))
              .fontSize(18)
              .fontColor([$r('sys.color.icon_primary')])
          }
            .width(32)
            .height(32)
            .padding(0)
            .backgroundColor(Color.Transparent)
            .accessibilityText(this.taildropReceiveMatches(file) &&
              this.taildropReceive.state === 'awaiting_text_preview' ?
              $r('app.string.transfer_copy_text_action') :
              (this.taildropContentKind(file) === 'text' ?
                $r('app.string.transfer_copy_text_action') :
                $r('app.string.transfer_save_action')))
            .onClick(() => {
              if (this.taildropReceiveMatches(file) &&
                this.taildropReceive.state === 'awaiting_text_preview') {
                this.copyTaildropTextPreview();
                return;
              }
              if (this.taildropSendActive() || this.taildropReceiveInProgress) {
                this.showToast($r('app.string.transfer_busy_message'));
                return;
              }
              if (this.taildropContentKind(file) === 'text') {
                const cachedText: TaildropCachedFile | undefined =
                  this.findTaildropCachedFile(file);
                if (cachedText !== undefined) {
                  this.showCachedTaildropTextPreview(cachedText);
                  this.copyTaildropTextPreview();
                  return;
                }
              } else {
                const cachedFile: TaildropCachedFile | undefined =
                  this.findTaildropCachedFile(file);
                if (cachedFile !== undefined) {
                  this.startPreparedTaildropFileSave(file);
                  return;
                }
              }
              if (this.taildropState !== 'ready') {
                this.showToast($r('app.string.transfer_connect_first_title'));
                return;
              }
              this.startTaildropReceive(file);
            })
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.trash'))
              .fontSize(18)
              .fontColor([$r('app.color.status_error')])
          }
            .width(32)
            .height(32)
            .padding(0)
            .backgroundColor(Color.Transparent)
            .accessibilityText($r('app.string.transfer_discard_action'))
            .onClick(() => {
              this.confirmDiscardTaildropFile(file);
            })
        }
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 54 })
    .padding({ left: 12, right: 12 })
    .opacity(this.taildropSendActive() && !this.taildropReceiveMatches(file) ? 0.62 : 1)
  }

  @Builder
  private TaildropInboxPanel() {
    Column({ space: 0 }) {
      ForEach(this.taildropWaitingFiles, (file: TaildropWaitingFileSummary, index: number) => {
        if (index > 0) {
          Divider()
            .color($r('sys.color.comp_divider'))
            .margin({ left: 54 })
        }
        this.TaildropWaitingFileRow(file)
        if (this.taildropReceiveMatches(file) &&
          this.taildropReceive.state === 'awaiting_text_preview' &&
          this.taildropReceivedText.length > 0) {
          this.TaildropInlineTextPreview()
        }
      }, (file: TaildropWaitingFileSummary) => JSON.stringify(file))
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
    .backgroundColor(this.groupBackground())
    .borderRadius(16)
  }

  @Builder
  private TaildropHistoryThumbnail(record: TaildropTransferRecord) {
    Stack({ alignContent: Alignment.Center }) {
      if (this.taildropHistoryPreviewUri(record).length > 0) {
        Image(this.taildropHistoryPreviewUri(record))
          .width(40)
          .height(40)
          .borderRadius(10)
          .objectFit(ImageFit.Cover)
      } else {
        SymbolGlyph(this.taildropFileSymbol(record.fileName))
          .fontSize(28)
          .fontColor([record.state === 'completed' ? $r('sys.color.icon_emphasize') :
            $r('sys.color.icon_secondary')])
      }
    }
    .width(44)
    .height(44)
  }

  private readTaildropTextPreview(result: TaildropReceiveResult): string | undefined {
    if (result.size > TAILDROP_TEXT_CLIPBOARD_MAX_BYTES || result.path.length === 0) {
      return undefined;
    }
    try {
      const stat: fileIo.Stat = fileIo.statSync(result.path);
      if (!stat.isFile() || stat.size !== result.size) {
        return undefined;
      }
      return fileIo.readTextSync(result.path);
    } catch (_error) {
      return undefined;
    }
  }

  private collapseTaildropTextPreview(): void {
    if (this.taildropReceive.state !== 'awaiting_text_preview') {
      return;
    }
    this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseInOut }, () => {
      this.resetTaildropReceiveOperation();
    });
  }

  private copyTaildropTextPreview(): void {
    if (this.taildropReceive.state !== 'awaiting_text_preview' ||
      this.taildropReceivedText.length === 0) {
      return;
    }
    const staged: TaildropReceiveResult = this.taildropReceive;
    this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseIn }, () => {
      this.taildropReceive = {
        requestId: staged.requestId, action: 'stage', state: 'copying_text', reason: '',
        name: staged.name, size: staged.size, path: staged.path
      };
    });
    this.taildropReceiveStateStartedAtMs = Date.now();
    this.taildropTextPreviewVisible = false;
    const data: pasteboard.PasteData = pasteboard.createData(
      pasteboard.MIMETYPE_TEXT_PLAIN, this.taildropReceivedText);
    pasteboard.getSystemPasteboard().setData(data).then(() => {
      if (!this.isCurrentTaildropReceive(staged.requestId, 'stage', 'copying_text')) {
        return;
      }
      if (this.taildropState === 'ready') {
        this.requestTaildropReceiveDelete(staged.requestId, staged.name, staged.size);
      } else {
        this.completeTaildropReceive();
      }
    }).catch(() => {
      if (!this.isCurrentTaildropReceive(staged.requestId, 'stage', 'copying_text')) {
        return;
      }
      this.taildropReceive = {
        requestId: staged.requestId, action: 'stage', state: 'awaiting_text_preview', reason: '',
        name: staged.name, size: staged.size, path: staged.path
      };
      this.taildropReceiveStateStartedAtMs = 0;
      this.taildropTextPreviewVisible = true;
      this.showToast($r('app.string.transfer_text_copy_failed'));
    });
  }

  @Builder
  private TaildropHistoryRow(record: TaildropTransferRecord) {
    Row({ space: 12 }) {
      Stack() {
        this.TaildropHistoryThumbnail(record)
      }
      .width(44)
      .height(44)
      .borderRadius(10)
      .clip(true)
      Column({ space: 2 }) {
        Text(this.taildropTransferRecordTitle(record))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.taildropTransferRecordDescription(record))
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Column({ space: 2 }) {
        Text(this.taildropTransferStatusText(record))
          .fontSize(11)
          .fontColor(record.state === 'completed' ? $r('app.color.status_success') :
            $r('sys.color.font_secondary'))
        if (record.direction === 'send' && record.state === 'failed') {
          Text($r('app.string.transfer_retry_action'))
            .fontSize(11)
            .fontColor($r('sys.color.icon_emphasize'))
        }
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .constraintSize({ minHeight: 58 })
    .padding({ left: 12, right: 12 })
    .onClick(() => this.retryTaildropSend(record))
  }

  @Builder
  private TaildropHistoryPanel() {
    Column({ space: 0 }) {
      ForEach(this.taildropHistory, (record: TaildropTransferRecord, index: number) => {
        if (index > 0) {
          Divider()
            .color($r('sys.color.comp_divider'))
            .margin({ left: 54 })
        }
        this.TaildropHistoryRow(record)
      }, (record: TaildropTransferRecord) => `${record.direction}-${record.requestId}`)
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
    .backgroundColor(this.groupBackground())
    .borderRadius(16)
  }

  @Builder
  private TransferEmptyPanel() {
    Column({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.doc'))
        .fontSize(30)
        .fontColor([$r('sys.color.icon_secondary')])
      Text($r('app.string.transfer_empty_title'))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      Text($r('app.string.transfer_empty_description'))
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
        .lineHeight(18)
        .constraintSize({ maxWidth: 360 })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 28, bottom: 28 })
    .backgroundColor(this.groupBackground())
    .borderRadius(16)
  }

  @Builder
  private TaildropInlineTextPreview() {
    Column() {
      Scroll() {
        Text(this.taildropReceivedText)
          .fontSize(14)
          .fontColor($r('sys.color.font_primary'))
          .lineHeight(21)
          .width('100%')
      }
      .width('100%')
      .constraintSize({ maxHeight: 220 })
      .padding(12)
      .backgroundColor(this.secondaryBackground())
      .borderRadius(12)
    }
    .width('100%')
    .padding({ left: 56, right: 12, bottom: 12 })
    .transition(
      TransitionEffect.asymmetric(
        TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseOut })
          .combine(TransitionEffect.translate({ y: -6 })),
        TransitionEffect.OPACITY.animation({ duration: 160, curve: Curve.EaseIn })
          .combine(TransitionEffect.translate({ y: -4 }))
      )
    )
  }

  @Builder
  private TaildropConnectionNotice() {
    Column({ space: 4 }) {
      Text($r('app.string.transfer_connect_first_title'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
      Text($r('app.string.transfer_connect_first_description'))
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
        .lineHeight(18)
        .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.groupBackground())
    .border({
      width: 1,
      color: $r('sys.color.comp_divider')
    })
    .borderRadius(16)
  }

  @Builder
  private TransferContent() {
    Scroll(this.transferScroller) {
      Column({ space: 14 }) {
        if (!this.isConnected()) {
          this.TaildropConnectionNotice()
        }
        if (this.taildropPreparing || this.taildropTransfer.state === 'queued' ||
          this.taildropTransfer.state === 'sending') {
          this.TaildropActiveSendPanel()
        }
        Column({ space: 8 }) {
          Column({ space: 2 }) {
            Text($r('app.string.transfer_targets_title'))
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
              .width('100%')
            Text($r('app.string.transfer_targets_ready_title', this.taildropOnlineTargetCount()))
              .fontSize(12)
              .fontColor($r('sys.color.font_secondary'))
              .width('100%')
          }
          .id('transfer-page-title')
          .width('100%')
          .padding({ left: 4, top: 8, bottom: 2 })
          if (this.displayedTaildropTargets().length > 0) {
            this.TaildropTargetsPanel()
          } else {
            this.TaildropTargetsEmptyPanel()
          }
        }
        .width('100%')
        Column({ space: 8 }) {
          Row() {
            Text($r('app.string.transfer_inbox_title'))
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
            Blank()
            Text($r('app.string.transfer_clear_cache_action'))
              .fontSize(12)
              .fontColor($r('sys.color.icon_emphasize'))
              .opacity(!this.taildropSendActive() && !this.taildropReceiveInProgress ? 1 : 0.42)
              .onClick(() => {
                if (!this.taildropSendActive() && !this.taildropReceiveInProgress) {
                  this.confirmClearTaildropInboxCache();
                }
              })
          }
          .width('100%')
          .padding({ left: 4, right: 4, top: 8, bottom: 2 })
          .alignItems(VerticalAlign.Center)
          if (this.taildropWaitingFiles.length > 0) {
            this.TaildropInboxPanel()
          } else {
            Text(this.taildropInboxReason.length > 0 ?
              $r('app.string.transfer_inbox_unavailable') : $r('app.string.transfer_inbox_empty'))
              .fontSize(12)
              .fontColor($r('sys.color.font_secondary'))
              .textAlign(TextAlign.Center)
              .width('100%')
              .padding({ left: 20, right: 20, top: 18, bottom: 18 })
              .backgroundColor(this.groupBackground())
              .borderRadius(16)
        }
        }
        .width('100%')
        Column({ space: 8 }) {
          Row() {
            Text($r('app.string.transfer_history_title'))
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
            Blank()
            Text($r('app.string.transfer_clear_history_action'))
              .fontSize(12)
              .fontColor($r('sys.color.icon_emphasize'))
              .opacity(this.taildropHistory.length > 0 ? 1 : 0.45)
              .onClick(() => {
                if (this.taildropHistory.length > 0) {
                  this.clearTaildropHistory();
                }
              })
          }
          .width('100%')
          .padding({ left: 4, right: 4, top: 8, bottom: 2 })
          .alignItems(VerticalAlign.Center)
          if (this.taildropHistory.length > 0) {
            this.TaildropHistoryPanel()
          } else {
            this.TransferEmptyPanel()
          }
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ maxWidth: 1200 })
      .padding({
        left: this.contentMargin(),
        right: this.contentMargin(),
        top: 0,
        bottom: this.pageBottomInset()
      })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .edgeEffect(EdgeEffect.Spring)
    .scrollBar(BarState.Auto)
    .scrollBarWidth(4)
    .align(Alignment.TopStart)
  }

  @Builder
  private SettingsContent() {
    Scroll(this.settingsScroller) {
      Column() {
        GridRow({
          columns: { xs: 2, sm: 4, md: 8, lg: 12 },
          gutter: { x: 12, y: 5 }
        }) {
          GridCol({ span: { xs: 2, sm: 4, md: 8, lg: 12 } }) {
            this.SettingsGroupHeader($r('app.string.account_title'))
          }
          GridCol({ span: { xs: 2, sm: 4, md: 8, lg: 12 } }) {
            this.AccountPanel()
          }
          GridCol({ span: { xs: 2, sm: 4, md: 8, lg: 12 } }) {
            this.SettingsGroupHeader($r('app.string.settings_title'))
          }
          GridCol({ span: { xs: 2, sm: 4, md: 8, lg: 12 } }) {
            this.NetworkSettingsPanel()
          }
          GridCol({ span: { xs: 2, sm: 4, md: 8, lg: 12 } }) {
            this.SettingsGroupHeader($r('app.string.settings_appearance_title'))
          }
          GridCol({ span: { xs: 2, sm: 4, md: 8, lg: 12 } }) {
            this.AppearanceSettingsPanel()
          }
          GridCol({ span: { xs: 2, sm: 4, md: 8, lg: 12 } }) {
            this.SettingsGroupHeader($r('app.string.settings_storage_title'))
          }
          GridCol({ span: { xs: 2, sm: 4, md: 8, lg: 12 } }) {
            this.CacheSettingsPanel()
          }
          GridCol({ span: { xs: 2, sm: 4, md: 8, lg: 12 } }) {
            this.SettingsGroupHeader($r('app.string.about_title'))
          }
          GridCol({ span: { xs: 2, sm: 4, md: 8, lg: 12 } }) {
            this.VersionPanel()
          }
          if (this.diagnosticsUnlocked) {
            GridCol({ span: { xs: 2, sm: 4, md: 8, lg: 12 } }) {
              this.DiagnosticsDisclosure()
            }
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: 1200 })
      }
      .width('100%')
      .padding({
        left: this.contentMargin(),
        right: this.contentMargin(),
        top: 8,
        bottom: this.pageBottomInset()
      })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .edgeEffect(EdgeEffect.Spring)
    .scrollBar(BarState.Auto)
    .scrollBarWidth(4)
  }

  @Builder
  private HomeTitleTopInset() {
    Blank()
      .width('100%')
      .height(this.homeTitleCompact ? 12 : 0)
      .animation({ duration: 420, curve: Curve.EaseInOut })
  }

  @Builder
  private HomePage() {
    HdsNavigation() {
      this.HomeContent()
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      padding: {
        start: LengthMetrics.vp(this.contentMargin()),
        end: LengthMetrics.vp(this.contentMargin())
      },
      style: {
        blurStrategy: BlurStrategy.DISABLE,
        thermoCtrl: true,
        scrollEffectOpts: {
          enableScrollEffect: false,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20)
        },
        originalStyle: {
          backgroundStyle: {
            backgroundColor: $r('sys.color.background_secondary'),
            blurRadius: 0,
            maskExtraHeight: 0
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: $r('sys.color.background_secondary'),
            blurRadius: 0,
            maskExtraHeight: 0
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            }
          }
        }
      },
      content: {
        stackBuilder: (): void => this.HomeTitleTopInset(),
        title: {
          mainTitle: $r('app.string.app_title'),
          subTitle: this.homeTitleCompact ? '' : $r('app.string.app_tagline')
        }
      }
    })
    .titleMode(this.homeTitleCompact ? HdsNavigationTitleMode.MINI : HdsNavigationTitleMode.FULL)
    .hideBackButton(true)
    .mode(NavigationMode.Stack)
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private SettingsPage() {
    HdsNavigation() {
      this.SettingsContent()
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      padding: {
        start: LengthMetrics.vp(this.contentMargin()),
        end: LengthMetrics.vp(this.contentMargin())
      },
      style: {
        blurStrategy: BlurStrategy.ENABLE,
        thermoCtrl: true,
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20)
        },
        originalStyle: {
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: $r('sys.color.background_secondary'),
            blurRadius: 24,
            maskExtraHeight: 40.0
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            }
          }
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: this.glowMaterialLevel()
        }
      },
      content: {
        title: {
          mainTitle: $r('app.string.tab_settings'),
          subTitle: $r('app.string.settings_subtitle')
        }
      }
    })
    .titleMode(HdsNavigationTitleMode.FREE)
    .bindToScrollable([this.settingsScroller])
    .hideBackButton(true)
    .mode(NavigationMode.Stack)
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private TransferPage() {
    HdsNavigation() {
      this.TransferContent()
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      padding: {
        start: LengthMetrics.vp(this.contentMargin()),
        end: LengthMetrics.vp(this.contentMargin())
      },
      style: {
        blurStrategy: BlurStrategy.ENABLE,
        thermoCtrl: true,
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20)
        },
        originalStyle: {
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: $r('sys.color.background_secondary'),
            blurRadius: 24,
            maskExtraHeight: 40.0
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            }
          }
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: this.glowMaterialLevel()
        }
      },
      content: {
        title: {
          mainTitle: $r('app.string.tab_transfer'),
          subTitle: $r('app.string.transfer_subtitle')
        }
      }
    })
    .titleMode(HdsNavigationTitleMode.FREE)
    .bindToScrollable([this.transferScroller])
    .hideBackButton(true)
    .mode(NavigationMode.Stack)
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private HomeTabBar() {
    Column({ space: 2 }) {
      Image($r('app.media.tab_home'))
        .width(24)
        .height(24)
        .fillColor(this.activeTab === 0 ? $r('sys.color.icon_emphasize') :
          $r('sys.color.icon_secondary'))
      Text($r('app.string.tab_home'))
        .fontSize(10)
        .fontColor(this.activeTab === 0 ? $r('sys.color.font_emphasize') :
          $r('sys.color.font_secondary'))
        .maxLines(1)
    }
    .id('tab-home')
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private TransferTabBar() {
    Column({ space: 2 }) {
      Image($r('app.media.tab_transfer'))
        .width(24)
        .height(24)
        .fillColor(this.activeTab === 1 ? $r('sys.color.icon_emphasize') :
          $r('sys.color.icon_secondary'))
      Text($r('app.string.tab_transfer'))
        .fontSize(10)
        .fontColor(this.activeTab === 1 ? $r('sys.color.font_emphasize') :
          $r('sys.color.font_secondary'))
        .maxLines(1)
    }
    .id('tab-transfer')
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private SettingsTabBar() {
    Column({ space: 2 }) {
      Image($r('app.media.tab_settings'))
        .width(24)
        .height(24)
        .fillColor(this.activeTab === 2 ? $r('sys.color.icon_emphasize') :
          $r('sys.color.icon_secondary'))
      Text($r('app.string.tab_settings'))
        .fontSize(10)
        .fontColor(this.activeTab === 2 ? $r('sys.color.font_emphasize') :
          $r('sys.color.font_secondary'))
        .maxLines(1)
    }
    .id('tab-settings')
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .bindPopup(this.controlServerTipVisible, {
      message: this.controlServerTipMessage,
      placement: Placement.Top,
      enableArrow: true,
      autoCancel: true,
      mask: false,
      width: 252,
      popupColor: this.glowSurface(),
      backgroundBlurStyle: BlurStyle.COMPONENT_REGULAR,
      onStateChange: (event: ControlServerTipStateChange) => {
        if (!event.isVisible && this.controlServerTipVisible) {
          this.controlServerTipVisible = false;
          this.recordDiagnosticEvent('control_server_tip_dismissed', 'message');
        }
      }
    })
  }

  @Builder
  private MobileTabs() {
    HdsTabs({
      barPosition: BarPosition.End,
      index: this.currentTab,
      controller: this.tabsController
    }) {
      TabContent() {
        this.HomePage()
      }
      .tabBar(this.HomeTabBar())

      TabContent() {
        this.TransferPage()
      }
      .tabBar(this.TransferTabBar())

      TabContent() {
        this.SettingsPage()
      }
      .tabBar(this.SettingsTabBar())
    }
    .vertical(false)
    .scrollable(true)
    .animationDuration(320)
    .barMode(BarMode.Fixed)
    .barHeight(56)
    .barOverlap(true)
    .barBackgroundColor(Color.Transparent)
    .barFloatingStyle({
      barSideMargin: 16,
      barBottomMargin: 40,
      gradientMask: {
        maskColor: $r('sys.color.background_secondary'),
        maskHeight: 48
      },
      lightColor: this.glowLightColor(),
      barOpacity: 0.96,
      thermoCtrl: true,
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.ADAPTIVE,
        materialLevel: this.glowMaterialLevel()
      }
    })
    .divider({ mode: DividerMode.NONE })
    .onSelected((index: number) => {
      this.activeTab = index;
      this.updateCacheSizePolling(index);
      // HdsTabs emits onSelected when the swipe transition starts and
      // onChange after it completes. Writing the controlled index here makes
      // the component jump straight to the destination and cancels the
      // interactive page animation.
      if (index === 2 && this.controlServerTipVisible) {
        this.controlServerTipVisible = false;
        this.recordDiagnosticEvent('control_server_tip_dismissed', 'settings_opened');
      }
    })
    .onChange((index: number) => {
      this.currentTab = index;
      this.activeTab = index;
      this.updateCacheSizePolling(index);
    })
    .width('100%')
    .height('100%')
  }

  private confirmResetFirstRun(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.diagnostic_reset_first_run_confirm_title'),
      message: $r('app.string.diagnostic_reset_first_run_confirm_message'),
      autoCancel: true,
      primaryButton: {
        value: $r('app.string.cancel_action'),
        action: () => {
        }
      },
      secondaryButton: {
        value: $r('app.string.diagnostic_reset_first_run_action'),
        fontColor: $r('app.color.status_error'),
        action: () => this.resetFirstRunState()
      }
    });
  }

  private async resetFirstRunState(): Promise<void> {
    if (this.diagnosticActionInProgress) {
      return;
    }
    this.diagnosticActionInProgress = true;
    this.diagnosticActionStatus = '';
    this.recordDiagnosticEvent('diagnostic_first_run_reset_requested', 'diagnostics');
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      try {
        await vpnExtension.stopVpnExtensionAbility(this.vpnWant());
      } catch (_vpnError) {
        // A stopped extension is already in the desired state.
      }
      try {
        await nativeBridge.backendStopAsync();
      } catch (_backendError) {
        // Continue with cleanup when no in-process backend exists.
      }
      await new Promise<void>((resolve: () => void) => setTimeout(resolve, 300));
      if (!ControlServerConfig.reset(context.filesDir)) {
        throw new Error('first-run reset failed');
      }
      const welcomeMarkerPath: string = this.welcomeAcknowledgedPath();
      if (fileIo.accessSync(welcomeMarkerPath)) {
        fileIo.unlinkSync(welcomeMarkerPath);
      }
      this.controlServerURL = DEFAULT_CONTROL_SERVER_URL;
      this.controlServerInput = DEFAULT_CONTROL_SERVER_URL;
      this.controlServerConfirmed = false;
      this.controlServerStatus = '';
      this.controlServerEditorVisible = true;
      this.controlServerTipVisible = false;
      this.backendStatus = 'Tailscale Backend Stopped | control server not configured';
      this.vpnStatus = 'HarmonyOS VPN Extension stopped';
      this.backendReady = true;
      this.backendInitializationVisible = false;
      this.devicesLoading = false;
      this.hasAuthenticatedSession = false;
      this.applyPeers([]);
      this.exitNodes = [];
      this.applyAccountSummary({
        displayName: '', loginName: '', profilePicURL: '', tailnetName: '', deviceName: '', addresses: [],
        needsApproval: false, keyExpired: false, keyExpiryUnixMs: 0
      });
      this.diagnosticActionStatus = context.resourceManager.getStringSync(
        $r('app.string.diagnostic_reset_first_run_completed').id);
      this.recordDiagnosticEvent('diagnostic_first_run_reset_completed', 'diagnostics');
      this.navigateToTab(0);
      this.scheduleLifecycleTask(() => this.showWelcomeDialogIfNeeded(), 350);
      this.scheduleLifecycleTask(() => this.showControlServerTip(), 700);
    } catch (_error) {
      this.diagnosticActionStatus = context.resourceManager.getStringSync(
        $r('app.string.diagnostic_reset_first_run_failed').id);
      this.recordDiagnosticEvent('diagnostic_first_run_reset_failed', 'diagnostics');
    } finally {
      this.diagnosticActionInProgress = false;
    }
  }

  private async forceStopSystemVpn(): Promise<void> {
    if (this.diagnosticActionInProgress) {
      return;
    }
    this.diagnosticActionInProgress = true;
    this.diagnosticActionStatus = '';
    this.recordDiagnosticEvent('diagnostic_vpn_cut_requested', 'diagnostics');
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      await vpnExtension.stopVpnExtensionAbility(this.vpnWant());
      this.stopConnectionPolling();
      this.clearConnectionCompletionTimer();
      this.connectInProgress = false;
      this.disconnectInProgress = false;
      this.vpnStatus = 'HarmonyOS VPN Extension stopped manually';
      this.diagnosticActionStatus = context.resourceManager.getStringSync(
        $r('app.string.diagnostic_force_vpn_stop_completed').id);
      this.recordDiagnosticEvent('diagnostic_vpn_cut_completed', 'diagnostics');
      if (this.controlServerConfirmed) {
        this.scheduleLifecycleTask(() => {
          this.startBackend(false);
          this.scheduleLifecycleTask(() => this.refreshBackendStatus(), 1500);
        }, 500);
      }
    } catch (error) {
      const businessError = error as BusinessError;
      this.diagnosticActionStatus = context.resourceManager.getStringSync(
        $r('app.string.diagnostic_force_vpn_stop_failed').id);
      this.recordDiagnosticEvent('diagnostic_vpn_cut_failed', 'diagnostics', businessError.code ?? -1);
    } finally {
      this.diagnosticActionInProgress = false;
    }
  }

  private confirmSimulateAppCrash(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.diagnostic_simulate_crash_confirm_title'),
      message: $r('app.string.diagnostic_simulate_crash_confirm_message'),
      autoCancel: true,
      primaryButton: {
        value: $r('app.string.cancel_action'),
        action: () => {
        }
      },
      secondaryButton: {
        value: $r('app.string.diagnostic_simulate_crash_action'),
        fontColor: $r('app.color.status_error'),
        action: () => this.simulateAppCrash()
      }
    });
  }

  private async simulateAppCrash(): Promise<void> {
    if (this.diagnosticActionInProgress) {
      return;
    }
    this.diagnosticActionInProgress = true;
    this.diagnosticActionStatus = '';
    this.recordDiagnosticEvent('diagnostic_crash_simulation_requested', 'diagnostics');
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      await vpnExtension.stopVpnExtensionAbility(this.vpnWant());
      this.stopConnectionPolling();
      this.clearConnectionCompletionTimer();
      const staleStatus: string =
        'OK | state=Running | loginURLReady=false | tailscaleIPs=1 | tun=true | ' +
        'tunRead=1 | tunWrite=1 | tunReadErrors=0 | tunWriteErrors=0 | ' +
        `phase=diagnostic-crash-simulation | heartbeatMs=${Date.now()}`;
      if (!this.writePrivateTextFile(`${context.filesDir}/vpn-probe-status.txt`, staleStatus)) {
        throw new Error('could not stage stale VPN status');
      }
      this.recordDiagnosticEvent('diagnostic_crash_simulation_staged', 'abort');
      setTimeout(() => appProcess.abort(), 120);
    } catch (_error) {
      this.diagnosticActionStatus = context.resourceManager.getStringSync(
        $r('app.string.diagnostic_simulate_crash_failed').id);
      this.recordDiagnosticEvent('diagnostic_crash_simulation_failed', 'diagnostics');
      this.diagnosticActionInProgress = false;
    }
  }

  @Builder
  private WideTabs() {
    HdsTabs({
      barPosition: BarPosition.Start,
      index: this.currentTab,
      controller: this.tabsController
    }) {
      TabContent() {
        this.HomePage()
      }
      .tabBar(new BottomTabBarStyle($r('app.media.tab_home'), $r('app.string.tab_home'))
        .id('tab-home')
        .labelStyle({
          unselectedColor: $r('sys.color.font_secondary'),
          selectedColor: $r('sys.color.font_emphasize')
        })
        .iconStyle({
          unselectedColor: $r('sys.color.icon_secondary'),
          selectedColor: $r('sys.color.icon_emphasize')
        }))

      TabContent() {
        this.TransferPage()
      }
      .tabBar(new BottomTabBarStyle($r('app.media.tab_transfer'), $r('app.string.tab_transfer'))
        .id('tab-transfer')
        .labelStyle({
          unselectedColor: $r('sys.color.font_secondary'),
          selectedColor: $r('sys.color.font_emphasize')
        })
        .iconStyle({
          unselectedColor: $r('sys.color.icon_secondary'),
          selectedColor: $r('sys.color.icon_emphasize')
        }))

      TabContent() {
        this.SettingsPage()
      }
      .tabBar(new BottomTabBarStyle($r('app.media.tab_settings'), $r('app.string.tab_settings'))
        .id('tab-settings')
        .labelStyle({
          unselectedColor: $r('sys.color.font_secondary'),
          selectedColor: $r('sys.color.font_emphasize')
        })
        .iconStyle({
          unselectedColor: $r('sys.color.icon_secondary'),
          selectedColor: $r('sys.color.icon_emphasize')
        }))
    }
    .vertical(true)
    .scrollable(false)
    .animationDuration(280)
    .barMode(BarMode.Fixed)
    .barWidth(96)
    .barOverlap(false)
    .barBackgroundColor($r('sys.color.comp_background_primary'))
    .divider({ mode: DividerMode.NONE })
    .onChange((index: number) => {
      this.currentTab = index;
      this.activeTab = index;
      this.updateCacheSizePolling(index);
    })
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      if (this.isWideNavigation()) {
        this.WideTabs()
      } else {
        this.MobileTabs()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.layoutWidth = Number(newValue.width);
    })
    .bindSheet($$this.connectionDetailsVisible, this.ConnectionDetailsContent(), {
      height: '68%',
      detents: ['68%', SheetSize.LARGE],
      preferType: SheetType.BOTTOM,
      scrollSizeMode: ScrollSizeMode.CONTINUOUS,
      dragBar: true,
      showClose: true,
      title: { title: '连接详情' }
    })
  }
}
