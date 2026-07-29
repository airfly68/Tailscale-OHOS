import { ConnectionPathType, PeerPathResult, StreamLaunchProfile } from './StreamingModels';

export const RELAY_SAFE_STREAM_DEFAULTS: StreamLaunchProfile = {
  profileName: 'relay_safe',
  recommendedBitrateKbps: 5000,
  recommendedWidth: 1280,
  recommendedHeight: 720,
  recommendedFps: 60,
  allowUserOverride: true
};

const PEER_RELAY_STREAM_DEFAULTS: StreamLaunchProfile = {
  profileName: 'peer_relay',
  recommendedBitrateKbps: 8000,
  allowUserOverride: true
};

export function buildStreamProfile(path: PeerPathResult): StreamLaunchProfile {
  if (path.type === 'derp') {
    return {
      profileName: RELAY_SAFE_STREAM_DEFAULTS.profileName,
      recommendedBitrateKbps: RELAY_SAFE_STREAM_DEFAULTS.recommendedBitrateKbps,
      recommendedWidth: RELAY_SAFE_STREAM_DEFAULTS.recommendedWidth,
      recommendedHeight: RELAY_SAFE_STREAM_DEFAULTS.recommendedHeight,
      recommendedFps: RELAY_SAFE_STREAM_DEFAULTS.recommendedFps,
      allowUserOverride: RELAY_SAFE_STREAM_DEFAULTS.allowUserOverride
    };
  }
  if (path.type === 'peerRelay') {
    return {
      profileName: PEER_RELAY_STREAM_DEFAULTS.profileName,
      recommendedBitrateKbps: PEER_RELAY_STREAM_DEFAULTS.recommendedBitrateKbps,
      allowUserOverride: PEER_RELAY_STREAM_DEFAULTS.allowUserOverride
    };
  }
  return { profileName: 'default', allowUserOverride: true };
}

export function isRelayPath(path: ConnectionPathType): boolean {
  return path === 'derp' || path === 'peerRelay';
}
