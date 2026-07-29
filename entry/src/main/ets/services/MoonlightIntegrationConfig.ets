export interface MoonlightIntegrationConfig {
  bundleName: string;
  abilityName: string;
  moduleName: string;
  protocolVersion: number;
}

// MoonlightOH must publish its stable Want contract before these values are enabled.
// Do not substitute a guessed bundle name, Ability name, or URI scheme here.
export const MOONLIGHT_INTEGRATION_CONFIG: MoonlightIntegrationConfig = {
  bundleName: '',
  abilityName: '',
  moduleName: '',
  protocolVersion: 1
};
