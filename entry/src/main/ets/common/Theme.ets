/**
 * Zorme 主题色板。与原 Android 版配色保持一致，深色为默认。
 */
export class Palette {
  bg: string;
  bgElevated: string;
  surface: string;
  surfaceAlt: string;
  textPrimary: string;
  textSecondary: string;
  textTertiary: string;
  divider: string;
  icon: string;
  iconMuted: string;
  accent: string;
  pill: string;
  scrim: string;
  sheet: string;
  progress: string;
  danger: string;
  onAccent: string;

  constructor(dark: boolean) {
    if (dark) {
      this.bg = '#0B0B0E';
      this.bgElevated = '#17171C';
      this.surface = '#17171C';
      this.surfaceAlt = '#1F1F25';
      this.textPrimary = '#EDEDF0';
      this.textSecondary = '#A0A0AA';
      this.textTertiary = '#7A7A88';
      this.divider = '#26262E';
      this.icon = '#EDEDF0';
      this.iconMuted = '#8A8A94';
      this.accent = '#EDEDF0';
      this.pill = '#1C1C22';
      this.scrim = '#A6000000';
      this.sheet = '#17171C';
      this.progress = '#EDEDF0';
      this.danger = '#FF6B6B';
      this.onAccent = '#0B0B0E';
    } else {
      this.bg = '#F7F7F9';
      this.bgElevated = '#FFFFFF';
      this.surface = '#FFFFFF';
      this.surfaceAlt = '#F1F1F5';
      this.textPrimary = '#111114';
      this.textSecondary = '#6E6E78';
      this.textTertiary = '#9A9AA4';
      this.divider = '#E4E4EB';
      this.icon = '#17171C';
      this.iconMuted = '#8A8A94';
      this.accent = '#111114';
      this.pill = '#F0F0F4';
      this.scrim = '#8A000000';
      this.sheet = '#FFFFFF';
      this.progress = '#111114';
      this.danger = '#D93B3B';
      this.onAccent = '#FFFFFF';
    }
  }
}

export class ThemeMode {
  static readonly DARK: number = 0;
  static readonly LIGHT: number = 1;
  static readonly SYSTEM: number = 2;
}
