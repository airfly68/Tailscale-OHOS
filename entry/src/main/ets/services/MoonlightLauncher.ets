import { bundleManager, common, Want } from '@kit.AbilityKit';
import { MoonlightLaunchRequest } from './StreamingModels';
import { MOONLIGHT_INTEGRATION_CONFIG } from './MoonlightIntegrationConfig';

export class MoonlightLauncher {
  private readonly context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async isAvailable(): Promise<boolean> {
    if (MOONLIGHT_INTEGRATION_CONFIG.bundleName.length === 0 ||
      MOONLIGHT_INTEGRATION_CONFIG.abilityName.length === 0) {
      return false;
    }
    try {
      await bundleManager.getBundleInfo(MOONLIGHT_INTEGRATION_CONFIG.bundleName,
        bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      return true;
    } catch (_error) {
      return false;
    }
  }

  async launch(request: MoonlightLaunchRequest): Promise<void> {
    const want: Want = {
      bundleName: MOONLIGHT_INTEGRATION_CONFIG.bundleName,
      moduleName: MOONLIGHT_INTEGRATION_CONFIG.moduleName,
      abilityName: MOONLIGHT_INTEGRATION_CONFIG.abilityName,
      parameters: {
        protocolVersion: request.protocolVersion,
        action: request.action,
        source: request.source,
        host: request.host,
        displayName: request.displayName,
        dnsName: request.dnsName ?? '',
        pathType: request.pathType,
        relayRegion: request.relayRegion ?? '',
        latencyMs: request.latencyMs ?? 0,
        streamProfile: request.streamProfile.profileName,
        recommendedBitrateKbps: request.streamProfile.recommendedBitrateKbps ?? 0,
        recommendedWidth: request.streamProfile.recommendedWidth ?? 0,
        recommendedHeight: request.streamProfile.recommendedHeight ?? 0,
        recommendedFps: request.streamProfile.recommendedFps ?? 0,
        allowUserOverride: request.streamProfile.allowUserOverride
      }
    };
    await this.context.startAbility(want);
  }
}
