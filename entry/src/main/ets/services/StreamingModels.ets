export type SunshineState = 'unknown' | 'checking' | 'available' | 'unavailable' | 'timeout' | 'error';

export type ConnectionPathType = 'direct' | 'peerRelay' | 'derp' | 'unknown' | 'unreachable';

export interface SunshineProbeResult {
  state: SunshineState;
  checkedAt: number;
  latencyMs?: number;
  serverName?: string;
  serverVersion?: string;
  errorMessage?: string;
}

export interface PeerPathResult {
  type: ConnectionPathType;
  latencyMs?: number;
  relayRegion?: string;
  checkedAt: number;
  errorMessage?: string;
}

export interface StreamLaunchProfile {
  profileName: 'default' | 'peer_relay' | 'relay_safe';
  recommendedBitrateKbps?: number;
  recommendedWidth?: number;
  recommendedHeight?: number;
  recommendedFps?: number;
  allowUserOverride: boolean;
}

export interface MoonlightLaunchRequest {
  protocolVersion: number;
  action: 'openHost';
  source: 'MeshArc';
  host: string;
  displayName: string;
  dnsName?: string;
  pathType: ConnectionPathType;
  relayRegion?: string;
  latencyMs?: number;
  streamProfile: StreamLaunchProfile;
}
