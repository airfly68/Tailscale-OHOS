import { common } from '@kit.AbilityKit';
import { HosPlayerLaunchRequest } from './MediaIntegrationModels';

export interface HosPlayerContractConfig {
  baseUri: string;
  enabled: boolean;
}

// Prototype contract for discussion with the HosPlayer author. Keep launch
// disabled until the receiving application publishes and registers this URI.
export const HOSPLAYER_CONTRACT: HosPlayerContractConfig = {
  baseUri: 'hosplayer://server',
  enabled: false
};

export class HosPlayerLauncher {
  private readonly context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  isEnabled(): boolean {
    return HOSPLAYER_CONTRACT.enabled;
  }

  buildUri(request: HosPlayerLaunchRequest): string {
    this.validate(request);
    const fields: string[] = [
      `protocolVersion=${request.protocolVersion}`,
      `type=${encodeURIComponent(request.type)}`,
      `url=${encodeURIComponent(request.url)}`,
      `name=${encodeURIComponent(request.name)}`,
      `network=${request.network}`,
      `route=${encodeURIComponent(request.route)}`,
      `source=${request.source}`
    ];
    return `${HOSPLAYER_CONTRACT.baseUri}/${request.action}?${fields.join('&')}`;
  }

  async launch(request: HosPlayerLaunchRequest): Promise<void> {
    if (!this.isEnabled()) {
      throw new Error('hosplayer_contract_not_enabled');
    }
    await this.context.openLink(this.buildUri(request), { appLinkingOnly: false });
  }

  runOfflineSelfTest(): string {
    const uri: string = this.buildUri({
      protocolVersion: 1,
      action: 'add',
      type: 'jellyfin',
      url: 'http://100.64.0.10:8096',
      name: '家庭 NAS',
      network: 'tailnet',
      route: 'direct',
      source: 'mesharc'
    });
    const passed: boolean = uri.startsWith('hosplayer://server/add?') &&
      uri.includes('type=jellyfin') &&
      uri.includes('url=http%3A%2F%2F100.64.0.10%3A8096') &&
      uri.includes('name=%E5%AE%B6%E5%BA%AD%20NAS') &&
      !uri.toLowerCase().includes('password') &&
      !uri.toLowerCase().includes('token');
    return passed ? `PASS | ${uri}` : 'FAILED | HosPlayer parameter contract';
  }

  private validate(request: HosPlayerLaunchRequest): void {
    if (request.protocolVersion !== 1 || (request.action !== 'add' && request.action !== 'open')) {
      throw new Error('invalid_contract_version_or_action');
    }
    const normalizedUrl: string = request.url.trim();
    if ((!normalizedUrl.startsWith('http://') && !normalizedUrl.startsWith('https://')) ||
      /^https?:\/\/[^/]*@/i.test(normalizedUrl) || normalizedUrl.length > 2048 ||
      normalizedUrl.includes('#')) {
      throw new Error('unsafe_server_url');
    }
    if (request.name.trim().length === 0 || request.name.length > 96) {
      throw new Error('invalid_server_name');
    }
  }
}
