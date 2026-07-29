import { ConnectionPathType } from './StreamingModels';

export type MediaServiceType = 'jellyfin' | 'emby' | 'plex' | 'webdav' | 'smb';
export type MediaProbeState = 'unknown' | 'checking' | 'available' | 'unavailable' | 'timeout' | 'error';

export interface DiscoveredMediaService {
  type: MediaServiceType;
  name: string;
  url: string;
  version?: string;
  latencyMs?: number;
}

export interface MediaProbeResult {
  state: MediaProbeState;
  checkedAt: number;
  services: DiscoveredMediaService[];
  errorMessage?: string;
}

export interface HosPlayerLaunchRequest {
  protocolVersion: number;
  action: 'add' | 'open';
  type: MediaServiceType;
  url: string;
  name: string;
  network: 'tailnet';
  route: ConnectionPathType;
  source: 'mesharc';
}
