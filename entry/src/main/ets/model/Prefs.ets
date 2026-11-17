import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

/**
 * 全局偏好设置。键名与原 Android 版保持一致，便于对照。
 */
export class Prefs {
  private static store: preferences.Preferences | null = null;

  static readonly KEY_SEARCH_ENGINE: string = 'search_engine';
  static readonly KEY_HOMEPAGE: string = 'homepage';
  static readonly KEY_ADBLOCK: string = 'adblock';
  static readonly KEY_NIGHT: string = 'night';
  static readonly KEY_NO_IMAGE: string = 'no_image';
  static readonly KEY_DESKTOP: string = 'desktop';
  static readonly KEY_JS: string = 'javascript';
  static readonly KEY_GESTURE: string = 'gesture';
  static readonly KEY_RESTORE: string = 'restore_tabs';
  static readonly KEY_THEME: string = 'theme';
  static readonly KEY_RECORD_HISTORY: string = 'record_history';
  static readonly KEY_TEXT_ZOOM: string = 'text_zoom';
  static readonly KEY_OPEN_HOME: string = 'open_home';
  static readonly KEY_AI_BASE: string = 'ai_base';
  static readonly KEY_AI_KEY: string = 'ai_key';
  static readonly KEY_AI_MODEL: string = 'ai_model';
  static readonly KEY_AGREED: string = 'agreement_agreed';
  static readonly KEY_UPDATE_MIRROR: string = 'update_mirror';
  static readonly KEY_NET_LOG: string = 'net_log';
  static readonly KEY_UA_MODE: string = 'ua_mode';
  static readonly KEY_UA_CUSTOM: string = 'ua_custom';
  static readonly KEY_TRANS_LANG: string = 'trans_lang';

  static readonly UA_DEFAULT: number = 0;
  static readonly UA_DESKTOP: number = 1;
  static readonly UA_IPHONE: number = 2;
  static readonly UA_IPAD: number = 3;
  static readonly UA_CUSTOM: number = 4;

  static async init(ctx: common.UIAbilityContext): Promise<void> {
    Prefs.store = await preferences.getPreferences(ctx, 'zorme_prefs');
  }

  private static ensure(): preferences.Preferences | null {
    return Prefs.store;
  }

  private static getString(key: string, def: string): string {
    const p = Prefs.ensure();
    if (p === null) {
      return def;
    }
    const v = p.getSync(key, def);
    return typeof v === 'string' ? v : def;
  }

  private static putString(key: string, value: string): void {
    const p = Prefs.ensure();
    if (p === null) {
      return;
    }
    p.putSync(key, value);
    p.flush().then(() => {
    }).catch(() => {
    });
  }

  private static getBool(key: string, def: boolean): boolean {
    const p = Prefs.ensure();
    if (p === null) {
      return def;
    }
    const v = p.getSync(key, def);
    return typeof v === 'boolean' ? v : def;
  }

  private static putBool(key: string, value: boolean): void {
    const p = Prefs.ensure();
    if (p === null) {
      return;
    }
    p.putSync(key, value);
    p.flush().then(() => {
    }).catch(() => {
    });
  }

  private static getNumber(key: string, def: number): number {
    const p = Prefs.ensure();
    if (p === null) {
      return def;
    }
    const v = p.getSync(key, def);
    return typeof v === 'number' ? v : def;
  }

  private static putNumber(key: string, value: number): void {
    const p = Prefs.ensure();
    if (p === null) {
      return;
    }
    p.putSync(key, value);
    p.flush().then(() => {
    }).catch(() => {
    });
  }

  static searchEngine(): string {
    return Prefs.getString(Prefs.KEY_SEARCH_ENGINE, 'baidu');
  }

  static setSearchEngine(id: string): void {
    Prefs.putString(Prefs.KEY_SEARCH_ENGINE, id);
  }

  static homepage(): string {
    return Prefs.getString(Prefs.KEY_HOMEPAGE, '');
  }

  static setHomepage(url: string): void {
    Prefs.putString(Prefs.KEY_HOMEPAGE, url ? url.trim() : '');
  }

  static adblock(): boolean {
    return Prefs.getBool(Prefs.KEY_ADBLOCK, true);
  }

  static setAdblock(v: boolean): void {
    Prefs.putBool(Prefs.KEY_ADBLOCK, v);
  }

  static night(): boolean {
    return Prefs.getBool(Prefs.KEY_NIGHT, false);
  }

  static setNight(v: boolean): void {
    Prefs.putBool(Prefs.KEY_NIGHT, v);
  }

  static noImage(): boolean {
    return Prefs.getBool(Prefs.KEY_NO_IMAGE, false);
  }

  static setNoImage(v: boolean): void {
    Prefs.putBool(Prefs.KEY_NO_IMAGE, v);
  }

  static desktop(): boolean {
    return Prefs.uaMode() === Prefs.UA_DESKTOP;
  }

  static setDesktop(v: boolean): void {
    Prefs.putBool(Prefs.KEY_DESKTOP, v);
    if (v && Prefs.uaMode() !== Prefs.UA_DESKTOP) {
      Prefs.setUaMode(Prefs.UA_DESKTOP);
    }
    if (!v && Prefs.uaMode() === Prefs.UA_DESKTOP) {
      Prefs.setUaMode(Prefs.UA_DEFAULT);
    }
  }

  static uaMode(): number {
    return Prefs.getNumber(Prefs.KEY_UA_MODE, Prefs.UA_DEFAULT);
  }

  static setUaMode(mode: number): void {
    Prefs.putNumber(Prefs.KEY_UA_MODE, mode);
  }

  static uaCustom(): string {
    return Prefs.getString(Prefs.KEY_UA_CUSTOM, '');
  }

  static setUaCustom(ua: string): void {
    Prefs.putString(Prefs.KEY_UA_CUSTOM, ua ? ua.trim() : '');
  }

  static javaScript(): boolean {
    return Prefs.getBool(Prefs.KEY_JS, true);
  }

  static setJavaScript(v: boolean): void {
    Prefs.putBool(Prefs.KEY_JS, v);
  }

  static gesture(): boolean {
    return Prefs.getBool(Prefs.KEY_GESTURE, true);
  }

  static setGesture(v: boolean): void {
    Prefs.putBool(Prefs.KEY_GESTURE, v);
  }

  static restoreTabs(): boolean {
    return Prefs.getBool(Prefs.KEY_RESTORE, true);
  }

  static setRestoreTabs(v: boolean): void {
    Prefs.putBool(Prefs.KEY_RESTORE, v);
  }

  static openHome(): boolean {
    return Prefs.getBool(Prefs.KEY_OPEN_HOME, true);
  }

  static setOpenHome(v: boolean): void {
    Prefs.putBool(Prefs.KEY_OPEN_HOME, v);
  }

  static recordHistory(): boolean {
    return Prefs.getBool(Prefs.KEY_RECORD_HISTORY, true);
  }

  static setRecordHistory(v: boolean): void {
    Prefs.putBool(Prefs.KEY_RECORD_HISTORY, v);
  }

  static theme(): number {
    return Prefs.getNumber(Prefs.KEY_THEME, 0);
  }

  static setTheme(mode: number): void {
    Prefs.putNumber(Prefs.KEY_THEME, mode);
  }

  static textZoom(): number {
    return Prefs.getNumber(Prefs.KEY_TEXT_ZOOM, 100);
  }

  static setTextZoom(v: number): void {
    Prefs.putNumber(Prefs.KEY_TEXT_ZOOM, v);
  }

  static agreed(): boolean {
    return Prefs.getBool(Prefs.KEY_AGREED, false);
  }

  static setAgreed(v: boolean): void {
    Prefs.putBool(Prefs.KEY_AGREED, v);
  }

  static updateMirror(): number {
    return Prefs.getNumber(Prefs.KEY_UPDATE_MIRROR, 0);
  }

  static setUpdateMirror(v: number): void {
    Prefs.putNumber(Prefs.KEY_UPDATE_MIRROR, v);
  }

  static netLog(): boolean {
    return Prefs.getBool(Prefs.KEY_NET_LOG, true);
  }

  static setNetLog(v: boolean): void {
    Prefs.putBool(Prefs.KEY_NET_LOG, v);
  }

  static aiBase(): string {
    return Prefs.getString(Prefs.KEY_AI_BASE, 'https://open.bigmodel.cn/api/paas/v4');
  }

  static setAiBase(v: string): void {
    Prefs.putString(Prefs.KEY_AI_BASE, v ? v.trim() : '');
  }

  static aiKey(): string {
    return Prefs.getString(Prefs.KEY_AI_KEY, '');
  }

  static setAiKey(v: string): void {
    Prefs.putString(Prefs.KEY_AI_KEY, v ? v.trim() : '');
  }

  static aiModel(): string {
    return Prefs.getString(Prefs.KEY_AI_MODEL, 'glm-4-flash');
  }

  static setAiModel(v: string): void {
    Prefs.putString(Prefs.KEY_AI_MODEL, v ? v.trim() : '');
  }

  /** 默认 UA（与 ArkWeb 内核默认值接近，避免空 UA 被站点拒绝） */
  static readonly UA_FALLBACK: string = 'Mozilla/5.0 (Phone; OpenHarmony 7.0) '
    + 'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 ArkWeb/4.1.6.1 Mobile';

  /** 当前生效的 UA 字符串 */
  static uaString(defaultUa: string): string {
    const fallback: string = defaultUa.length > 0 ? defaultUa : Prefs.UA_FALLBACK;
    const mode: number = Prefs.uaMode();
    if (mode === Prefs.UA_DESKTOP) {
      return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        + '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
    }
    if (mode === Prefs.UA_IPHONE) {
      return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 '
        + '(KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1';
    }
    if (mode === Prefs.UA_IPAD) {
      return 'Mozilla/5.0 (iPad; CPU OS 17_4 like Mac OS X) AppleWebKit/605.1.15 '
        + '(KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1';
    }
    if (mode === Prefs.UA_CUSTOM) {
      const c: string = Prefs.uaCustom();
      return c.length > 0 ? c : fallback;
    }
    return fallback;
  }

  /** 网页翻译的目标语言（必应语言代码） */
  static transLang(): string {
    const v: string = Prefs.getString(Prefs.KEY_TRANS_LANG, 'zh-Hans');
    return v.length > 0 ? v : 'zh-Hans';
  }

  static setTransLang(code: string): void {
    Prefs.putString(Prefs.KEY_TRANS_LANG, code ? code : 'zh-Hans');
  }
}
