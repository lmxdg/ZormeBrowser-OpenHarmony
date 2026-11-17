import { common, ConfigurationConstant, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { request } from '@kit.BasicServicesKit';
import { webview } from '@kit.ArkWeb';
import { Palette } from '../common/Theme';
import { Utils } from '../common/Utils';
import { Prefs } from '../model/Prefs';
import { Store, BookmarkItem, HistoryItem, DownloadItem, SessionItem } from '../model/Store';
import { SearchEngine } from '../model/SearchEngine';
import { AdBlocker } from '../model/AdBlocker';
import { NetLog } from '../model/NetLog';
import { Agreement } from '../model/Agreement';
import { TabMeta } from '../model/TabMeta';
import { SslInfo } from '../model/SslInfo';
import { BingTranslate, TransResult } from '../model/BingTranslate';
import { TranslateScript } from '../model/TranslateScript';
import { UpdateChecker } from '../model/UpdateChecker';
import { TabWeb, TabCallbacks } from '../components/TabWeb';
import { SettingsView } from '../components/SettingsView';
import { AiChatView } from '../components/AiChatView';
import { ListView } from '../components/ListView';
import { SourceView } from '../components/SourceView';
import { NetLogView } from '../components/NetLogView';
import { HomeView } from '../components/HomeView';
import { MenuSheet } from '../components/MenuSheet';
import { AddressOverlay } from '../components/AddressOverlay';
import { TabsOverlay } from '../components/TabsOverlay';
import { ZIcon } from '../components/ZIcon';
import { SuggestionItem, DialogOption } from '../components/Models';

/** 翻译注入脚本 collect() 的返回结构 */
interface PageTexts {
  ok: boolean;
  total: number;
  items: string[];
  cached?: boolean;
  error?: string;
}

@Entry
@Component
struct Index {
  @State pal: Palette = new Palette(true);
  @State dark: boolean = true;
  @State ready: boolean = false;
  @State tabs: TabMeta[] = [];
  @State current: number = 0;
  @State screen: string = 'browser';
  @State menuShown: boolean = false;
  @State tabsShown: boolean = false;
  @State addressShown: boolean = false;
  @State addressText: string = '';
  @State suggestions: SuggestionItem[] = [];
  @State findShown: boolean = false;
  @State findText: string = '';
  @State findInfo: string = '';
  @State toastShown: boolean = false;
  @State toastText: string = '';
  @State dialogShown: boolean = false;
  @State dlgTitle: string = '';
  @State dlgMessage: string = '';
  @State dlgKind: string = 'alert';
  @State dlgInput: string = '';
  @State dlgHint: string = '';
  @State dlgPositive: string = '知道了';
  @State dlgNegative: string = '取消';
  @State dlgDanger: boolean = false;
  @State dlgOptions: DialogOption[] = [];
  @State dlgChecked: number = -1;
  @State dlgInputVisible: boolean = false;
  @State dlgButtons: boolean = true;
  @State listMode: string = 'bookmarks';
  @State sourceTitle: string = '';
  @State sourceText: string = '';
  @State transShown: boolean = false;
  @State transBusy: boolean = false;
  @State transDone: number = 0;
  @State transTotal: number = 0;
  @State transLang: string = '简体中文';
  @State transTranslated: boolean = false;

  private controllers: Map<number, webview.WebviewController> = new Map<number, webview.WebviewController>();
  private nextTabId: number = 1;
  private dlgOnPositive: (text: string) => void = () => {
  };
  private dlgOnNegative: () => void = () => {
  };
  private dlgOnOption: (index: number) => void = () => {
  };
  private lastBack: number = 0;
  private toastTimer: number = -1;
  private pendingJs: JsResult | null = null;
  /** 翻译任务代号，自增即取消 */
  private transToken: number = 0;
  private netLogBack: string = 'browser';

  private webCallbacks: TabCallbacks = {
    onAttached: (id: number) => {
      this.onTabAttached(id);
    },
    onBegin: (id: number, url: string) => {
      this.onTabBegin(id, url);
    },
    onEnd: (id: number, url: string, title: string) => {
      this.onTabEnd(id, url, title);
    },
    onProgress: (id: number, progress: number) => {
      this.onTabProgress(id, progress);
    },
    onTitle: (id: number, title: string) => {
      this.onTabTitle(id, title);
    },
    onError: (id: number, code: string, desc: string) => {
      this.onTabError(id, code, desc);
    },
    onState: (id: number) => {
      this.refreshTabState(id);
    },
    onIntercept: (url: string, method: string, main: boolean) => {
      return this.onInterceptRequest(url, method, main);
    },
    onSpecialUrl: (url: string) => {
      return this.handleSpecialUrl(url);
    },
    onDownloadStart: (url: string, path: string, name: string, total: number) => {
      this.onDownloadStart(url, path, name, total);
    },
    onDownloadUpdate: (url: string, state: number, received: number, total: number) => {
      this.onDownloadUpdate(url, state, received, total);
    },
    onJsAlert: (message: string, url: string, result: JsResult) => {
      this.pendingJs = result;
      this.showAlert(this.jsTitle(url), message, '知道了', () => {
        result.handleConfirm();
        this.pendingJs = null;
      });
    },
    onJsConfirm: (message: string, url: string, result: JsResult) => {
      this.pendingJs = result;
      this.showConfirm(this.jsTitle(url), message, '确定', () => {
        result.handleConfirm();
        this.pendingJs = null;
      }, () => {
        result.handleCancel();
        this.pendingJs = null;
      });
    },
    onJsPrompt: (message: string, url: string, def: string, result: JsResult) => {
      this.pendingJs = result;
      this.showInput(this.jsTitle(url), message, def, '确定', (text: string) => {
        result.handlePromptConfirm(text);
        this.pendingJs = null;
      }, () => {
        result.handleCancel();
        this.pendingJs = null;
      });
    }
  };

  aboutToAppear(): void {
    this.initApp();
  }

  private async initApp(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    try {
      await Prefs.init(ctx);
      await Store.init(ctx);
      AdBlocker.init(ctx);
    } catch (e) {
    }
    this.applyTheme();
    this.restoreOrCreateTabs();
    this.ready = true;
    if (!Prefs.agreed()) {
      this.showAgreement();
    }
  }

  // ---------------------------------------------------------------
  // 主题与系统栏
  // ---------------------------------------------------------------

  private applyTheme(): void {
    const mode: number = Prefs.theme();
    let sysDark: boolean = true;
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      sysDark = ctx.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    } catch (e) {
      sysDark = true;
    }
    this.dark = mode === 0 || (mode === 2 && sysDark);
    this.pal = new Palette(this.dark);
    this.applySystemBars();
  }

  private applySystemBars(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    window.getLastWindow(ctx).then((w: window.Window) => {
      w.setWindowSystemBarProperties({
        statusBarColor: this.pal.bg,
        statusBarContentColor: this.dark ? '#FFFFFF' : '#000000',
        navigationBarColor: this.pal.bg,
        navigationBarContentColor: this.dark ? '#FFFFFF' : '#000000'
      }).catch(() => {
      });
    }).catch(() => {
    });
  }

  // ---------------------------------------------------------------
  // 标签页
  // ---------------------------------------------------------------

  private cur(): TabMeta | null {
    if (this.current >= 0 && this.current < this.tabs.length) {
      return this.tabs[this.current];
    }
    return null;
  }

  private controllerOf(id: number): webview.WebviewController {
    return this.controllers.get(id) as webview.WebviewController;
  }

  private createTab(incognito: boolean, url: string): TabMeta {
    const id: number = this.nextTabId;
    this.nextTabId++;
    const meta: TabMeta = new TabMeta(id, incognito, url);
    this.controllers.set(id, new webview.WebviewController());
    const list: TabMeta[] = this.tabs.slice();
    list.push(meta);
    this.tabs = list;
    this.current = this.tabs.length - 1;
    return meta;
  }

  private restoreOrCreateTabs(): void {
    if (Prefs.openHome()) {
      this.createTab(false, '');
      return;
    }
    if (Prefs.restoreTabs()) {
      const items: SessionItem[] = Store.restoreSession();
      if (items.length > 0) {
        for (const item of items) {
          this.createTab(false, item.url);
        }
        let idx: number = Store.restoredCurrent();
        if (idx >= this.tabs.length) {
          idx = this.tabs.length - 1;
        }
        if (idx < 0) {
          idx = 0;
        }
        this.current = idx;
        return;
      }
    }
    this.createTab(false, '');
  }

  private saveSession(): void {
    const list: SessionItem[] = [];
    let cur: number = 0;
    let real: number = 0;
    for (let i = 0; i < this.tabs.length; i++) {
      const t: TabMeta = this.tabs[i];
      if (t.incognito) {
        continue;
      }
      if (i === this.current) {
        cur = real;
      }
      const item: SessionItem = new SessionItem();
      item.url = t.showingHome ? '' : t.url;
      item.title = t.title;
      list.push(item);
      real++;
    }
    Store.saveSession(list, cur);
  }

  private attachTab(id: number): void {
    const meta: TabMeta | null = this.findTab(id);
    if (meta === null) {
      return;
    }
    if (meta.pendingUrl && meta.pendingUrl.length > 0) {
      const url: string = meta.pendingUrl;
      meta.pendingUrl = '';
      this.loadInTab(meta, url);
    }
  }

  private onTabAttached(id: number): void {
    this.attachTab(id);
    const meta: TabMeta | null = this.findTab(id);
    if (meta !== null) {
      meta.attached = true;
      this.refreshTabState(id);
    }
  }

  private findTab(id: number): TabMeta | null {
    for (const t of this.tabs) {
      if (t.id === id) {
        return t;
      }
    }
    return null;
  }

  private onTabBegin(id: number, url: string): void {
    const meta: TabMeta | null = this.findTab(id);
    if (meta === null) {
      return;
    }
    meta.error = false;
    meta.loading = true;
    meta.progress = 8;
    if (url && !url.startsWith('about:')) {
      meta.url = url;
      meta.showingHome = false;
    }
    const cur: TabMeta | null = this.cur();
    if (cur !== null && cur.id === id) {
      meta.translated = false;
      this.resetTrans();
    }
    this.touchTabs();
  }

  private onTabEnd(id: number, url: string, title: string): void {
    const meta: TabMeta | null = this.findTab(id);
    if (meta === null) {
      return;
    }
    meta.loading = false;
    meta.progress = 100;
    if (title && title.length > 0) {
      meta.title = title;
    }
    if (url && !url.startsWith('about:') && !url.startsWith('data:')) {
      meta.url = url;
      meta.showingHome = false;
    }
    if (!meta.error && !meta.incognito && Prefs.recordHistory()
      && meta.url && meta.url.startsWith('http')) {
      Store.addHistory(meta.title, meta.url);
    }
    this.refreshTabState(id);
    this.saveSession();
    this.touchTabs();
  }

  private onTabProgress(id: number, progress: number): void {
    const meta: TabMeta | null = this.findTab(id);
    if (meta === null) {
      return;
    }
    meta.progress = progress;
    meta.loading = progress < 100;
    this.touchTabs();
  }

  private onTabTitle(id: number, title: string): void {
    const meta: TabMeta | null = this.findTab(id);
    if (meta !== null && title && title.length > 0) {
      meta.title = title;
      this.touchTabs();
    }
  }

  private onTabError(id: number, code: string, desc: string): void {
    const meta: TabMeta | null = this.findTab(id);
    if (meta === null) {
      return;
    }
    meta.error = true;
    meta.loading = false;
    let text: string = '请检查网络连接，或稍后重试\n' + Utils.displayUrl(meta.url);
    if (desc && desc.length > 0) {
      text += '\n' + desc;
    } else if (code && code.length > 0) {
      text += '\nERR ' + code;
    }
    meta.errorDesc = text;
    this.touchTabs();
  }

  private refreshTabState(id: number): void {
    const meta: TabMeta | null = this.findTab(id);
    if (meta === null) {
      return;
    }
    const c: webview.WebviewController | undefined = this.controllers.get(id);
    if (c) {
      try {
        meta.canBack = c.accessBackward();
        meta.canForward = c.accessForward();
      } catch (e) {
      }
    }
    this.touchTabs();
  }

  private touchTabs(): void {
    this.tabs = this.tabs.slice();
  }

  private selectTab(index: number): void {
    if (index < 0 || index >= this.tabs.length) {
      return;
    }
    this.current = index;
    this.tabsShown = false;
    this.resetTrans();
    const meta: TabMeta = this.tabs[index];
    if (meta.translated) {
      this.transShown = true;
      this.transTranslated = true;
      this.transLang = BingTranslate.nameOf(Prefs.transLang());
    }
    this.refreshTabState(meta.id);
    this.saveSession();
  }

  private closeTab(index: number): void {
    if (index < 0 || index >= this.tabs.length) {
      return;
    }
    const meta: TabMeta = this.tabs[index];
    const c: webview.WebviewController | undefined = this.controllers.get(meta.id);
    if (c && meta.incognito) {
      try {
        c.removeCache(true);
        c.clearHistory();
      } catch (e) {
      }
    }
    this.controllers.delete(meta.id);
    const list: TabMeta[] = this.tabs.slice();
    list.splice(index, 1);
    this.tabs = list;
    if (this.tabs.length === 0) {
      this.createTab(false, '');
    } else if (this.current >= this.tabs.length) {
      this.current = this.tabs.length - 1;
    } else if (index < this.current) {
      this.current = this.current - 1;
    }
    this.saveSession();
  }

  // ---------------------------------------------------------------
  // 地址栏
  // ---------------------------------------------------------------

  private openAddressEditor(): void {
    const t: TabMeta | null = this.cur();
    this.addressText = (t === null || t.showingHome) ? '' : t.url;
    this.addressShown = true;
    this.menuShown = false;
    this.refreshSuggestions(this.addressText);
    setTimeout(() => {
      this.refreshSuggestions(this.addressText);
    }, 200);
  }

  private closeAddressEditor(): void {
    this.addressShown = false;
  }

  private refreshSuggestions(query: string): void {
    const list: SuggestionItem[] = [];
    const seen: Set<string> = new Set<string>();
    const engine: SearchEngine = SearchEngine.get();
    const q: string = query ? query.trim() : '';

    if (q.length > 0) {
      if (Utils.looksLikeUrl(q)) {
        list.push(new SuggestionItem('url', q, '访问网站', Utils.normalizeUrl(q), '打开'));
      } else {
        list.push(new SuggestionItem('search', '搜索 “' + q + '”', engine.name,
          engine.searchUrlFor(q), '搜索'));
      }
    }
    const history: HistoryItem[] = Store.findHistory(q, q.length === 0 ? 8 : 6);
    for (const h of history) {
      if (Utils.isHome(h.url) || seen.has(h.url)) {
        continue;
      }
      seen.add(h.url);
      const title: string = h.title && h.title.trim().length > 0 ? h.title : Utils.displayUrl(h.url);
      list.push(new SuggestionItem('history', title, Utils.displayUrl(h.url), h.url, '历史'));
    }
    const marks: BookmarkItem[] = Store.findBookmarks(q);
    for (const b of marks) {
      if (seen.has(b.url)) {
        continue;
      }
      seen.add(b.url);
      if (list.length > 12) {
        break;
      }
      const title: string = b.title && b.title.trim().length > 0 ? b.title : Utils.displayUrl(b.url);
      list.push(new SuggestionItem('bookmark', title, Utils.displayUrl(b.url), b.url, '书签'));
    }
    this.suggestions = list;
  }

  private commitAddress(): void {
    const input: string = this.addressText.trim();
    this.addressShown = false;
    if (input.length === 0) {
      return;
    }
    this.loadUrlOrSearch(input);
  }

  private loadUrlOrSearch(input: string): void {
    let url: string = '';
    if (Utils.looksLikeUrl(input)) {
      url = Utils.normalizeUrl(input);
    } else {
      url = SearchEngine.get().searchUrlFor(input);
    }
    const t: TabMeta | null = this.cur();
    if (t === null) {
      this.createTab(false, url);
    } else {
      this.loadInTab(t, url);
    }
  }

  private loadInTab(tab: TabMeta, url: string): void {
    if (!url) {
      return;
    }
    if (url.startsWith('javascript:')) {
      return;
    }
    if (!this.isInternalUrl(url)) {
      this.handleSpecialUrl(url);
      return;
    }
    tab.showingHome = false;
    tab.error = false;
    tab.url = url;
    const c: webview.WebviewController | undefined = this.controllers.get(tab.id);
    if (c && tab.attached) {
      try {
        c.loadUrl(url);
      } catch (e) {
      }
    } else {
      tab.pendingUrl = url;
    }
    this.touchTabs();
  }

  private isInternalUrl(url: string): boolean {
    return url.startsWith('http://') || url.startsWith('https://') || url.startsWith('file:')
      || url.startsWith('about:') || url.startsWith('data:') || url.startsWith('blob:');
  }

  private handleSpecialUrl(url: string): boolean {
    if (!url) {
      return false;
    }
    if (url.startsWith('intent:') || url.includes('#Intent;')) {
      const fallback: string = this.extractFallbackUrl(url);
      if (fallback) {
        const t: TabMeta | null = this.cur();
        if (t !== null) {
          this.loadInTab(t, fallback);
        }
      }
      return true;
    }
    const ctx = getContext(this) as common.UIAbilityContext;
    const want: Want = { action: 'ohos.want.action.viewData', uri: url };
    ctx.startAbility(want).catch(() => {
    });
    return true;
  }

  private extractFallbackUrl(intentUrl: string): string {
    const key: string = 'S.browser_fallback_url=';
    const idx: number = intentUrl.indexOf(key);
    if (idx < 0) {
      return '';
    }
    let rest: string = intentUrl.substring(idx + key.length);
    const end: number = rest.indexOf(';');
    if (end >= 0) {
      rest = rest.substring(0, end);
    }
    try {
      return decodeURIComponent(rest);
    } catch (e) {
      return rest;
    }
  }

  private jsTitle(url: string): string {
    const d: string = Utils.domainOf(url);
    return d && d.length > 0 ? d : '网页提示';
  }

  // ---------------------------------------------------------------
  // 网络拦截、下载
  // ---------------------------------------------------------------

  private onInterceptRequest(url: string, method: string, main: boolean): boolean {
    let blocked: boolean = false;
    try {
      if (Prefs.adblock() && AdBlocker.isBlocked(url)) {
        blocked = true;
      }
    } catch (e) {
    }
    if (Prefs.netLog() && url
      && !url.startsWith('about:') && !url.startsWith('data:')
      && !url.startsWith('blob:') && !url.startsWith('javascript:')) {
      NetLog.record(method, url, main, blocked);
    }
    return blocked;
  }

  private onDownloadStart(url: string, path: string, name: string, total: number): void {
    let existed: DownloadItem | null = null;
    for (const d of Store.allDownloads()) {
      if (d.url === url && d.path === path) {
        existed = d;
      }
    }
    if (existed === null) {
      Store.addDownload(name, url, path, total);
    }
    this.toast('已开始下载 · ' + name);
  }

  private onDownloadUpdate(url: string, state: number, received: number, total: number): void {
    for (const d of Store.allDownloads()) {
      if (d.url === url) {
        Store.updateDownload(d.id, state, received, total);
        break;
      }
    }
  }

  // ---------------------------------------------------------------
  // 菜单动作
  // ---------------------------------------------------------------

  private onMenuAction(action: string): void {
    this.menuShown = false;
    const t: TabMeta | null = this.cur();
    if (action === 'ai') {
      this.screen = 'ai';
    } else if (action === 'refresh') {
      if (t !== null && !t.showingHome) {
        try {
          this.controllerOf(t.id).refresh();
        } catch (e) {
        }
      }
    } else if (action === 'home') {
      this.goHome(t);
    } else if (action === 'bookmark') {
      this.toggleBookmark();
    } else if (action === 'history') {
      this.openList('history');
    } else if (action === 'downloads') {
      this.openList('downloads');
    } else if (action === 'night') {
      Prefs.setNight(!Prefs.night());
      this.applyTheme();
      this.toast(Prefs.night() ? '夜间模式已开启' : '夜间模式已关闭');
    } else if (action === 'noimage') {
      Prefs.setNoImage(!Prefs.noImage());
      this.touchTabs();
      this.toast(Prefs.noImage() ? '无图模式已开启' : '已恢复图片');
    } else if (action === 'desktop') {
      Prefs.setDesktop(!Prefs.desktop());
      this.touchTabs();
      if (t !== null && !t.showingHome) {
        try {
          this.controllerOf(t.id).refresh();
        } catch (e) {
        }
      }
      this.toast(Prefs.desktop() ? '已切换为桌面版网站' : '已切换为手机版网站');
    } else if (action === 'find') {
      this.showFind();
    } else if (action === 'reader') {
      this.readerMode();
    } else if (action === 'translate') {
      this.translatePage();
    } else if (action === 'source') {
      this.viewSource();
    } else if (action === 'netlog') {
      this.netLogBack = 'browser';
      this.screen = 'netlog';
    } else if (action === 'ssl') {
      this.showSslInfo();
    } else if (action === 'share') {
      this.sharePage();
    } else if (action === 'settings') {
      this.screen = 'settings';
    } else if (action === 'newtab') {
      this.createTab(false, '');
    } else if (action === 'newincognito') {
      this.createTab(true, '');
    }
  }

  private goHome(tab: TabMeta | null): void {
    if (tab === null) {
      return;
    }
    const home: string = Prefs.homepage();
    if (!home || home.trim().length === 0) {
      tab.showingHome = true;
      this.touchTabs();
      return;
    }
    this.loadInTab(tab, Utils.normalizeUrl(home));
  }

  private toggleBookmark(): void {
    const t: TabMeta | null = this.cur();
    if (t === null || t.showingHome || !t.url) {
      this.toast('当前没有可收藏的页面');
      return;
    }
    if (Store.isBookmarked(t.url)) {
      Store.removeBookmarkByUrl(t.url);
      this.toast('已移除书签');
      this.touchTabs();
      return;
    }
    const title: string = t.displayTitle();
    this.showInput('添加书签', '书签名称', title, '保存', (name: string) => {
      const n: string = name && name.trim().length > 0 ? name.trim() : Utils.titleOf(t.url);
      Store.addBookmark(n, t.url);
      this.toast('已添加书签');
      this.touchTabs();
    });
  }

  private sharePage(): void {
    const t: TabMeta | null = this.cur();
    if (t === null || t.showingHome) {
      this.toast('当前没有可分享的页面');
      return;
    }
    this.copyText(t.displayTitle() + '\n' + t.url);
    this.toast('链接已复制到剪贴板');
  }

  /** 在页面里执行一段 JS，返回值转成字符串 */
  private jsRun(ctrl: webview.WebviewController, js: string, timeout: number = 3500): Promise<string> {
    return new Promise<string>((resolve) => {
      let done: boolean = false;
      const timer: number = setTimeout(() => {
        if (!done) {
          done = true;
          resolve('');
        }
      }, timeout);
      const finish = (value: string): void => {
        if (done) {
          return;
        }
        done = true;
        clearTimeout(timer);
        resolve(value);
      };
      try {
        ctrl.runJavaScript(js, (err: Error, value: string) => {
          finish(value !== undefined && value !== null ? value : '');
        });
      } catch (e) {
        finish('');
      }
    });
  }

  private parsePageTexts(raw: string): PageTexts {
    const empty: PageTexts = { ok: false, total: 0, items: [] };
    if (raw === undefined || raw === null) {
      return empty;
    }
    let text: string = raw.trim();
    if (text.length === 0 || text === 'null' || text === 'undefined') {
      return empty;
    }
    // runJavaScript 在不同 ArkWeb 版本上可能把字符串结果再包一层引号（双重编码），
    // 这里最多解两层，避免整页翻译因为一个引号而判失败。
    for (let pass = 0; pass < 2; pass++) {
      if (text.length >= 2 && text.charAt(0) === '"' && text.charAt(text.length - 1) === '"') {
        try {
          const inner: string = JSON.parse(text) as string;
          if (typeof inner === 'string' && inner.length > 0) {
            text = inner;
            continue;
          }
        } catch (e) {
        }
      }
      break;
    }
    try {
      const obj: PageTexts = JSON.parse(text) as PageTexts;
      if (obj === null || obj === undefined) {
        return empty;
      }
      if (obj.items === undefined || obj.items === null) {
        obj.items = [];
      }
      if (obj.total === undefined || obj.total === null || obj.total === 0) {
        obj.total = obj.items.length;
      }
      // 个别版本返回里没有 ok 字段，只要拿到了文本就继续
      if (!obj.ok && obj.items.length > 0) {
        obj.ok = true;
      }
      return obj;
    } catch (e) {
      return empty;
    }
  }

  private wait(ms: number): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(() => {
        resolve();
      }, ms);
    });
  }

  /** 用必应翻译整页：抽取文本节点 → 分批翻译 → 回填 */
  private async translatePage(): Promise<void> {
    const tab: TabMeta | null = this.cur();
    if (tab === null || tab.showingHome || !tab.url) {
      this.toast('请先打开一个网页');
      return;
    }
    if (this.transBusy) {
      this.toast('正在翻译，请稍候');
      return;
    }
    if (!Prefs.javaScript()) {
      this.toast('请先在设置中开启 JavaScript');
      return;
    }
    const ctx = getContext(this) as common.UIAbilityContext;
    const lib: string = TranslateScript.libScript(ctx);
    if (lib.length === 0) {
      this.toast('翻译脚本缺失，请重新安装应用');
      return;
    }
    const ctrl: webview.WebviewController = this.controllerOf(tab.id);
    const code: string = Prefs.transLang();
    this.transLang = BingTranslate.nameOf(code);
    this.transShown = true;
    this.transBusy = true;
    this.transDone = 0;
    this.transTotal = 0;
    this.transTranslated = false;
    const token: number = ++this.transToken;

    // 清掉上次的译文，再注入脚本；注入后确认 __zormeT 真的挂上了，
    // 避免页面还在加载时 runJavaScript 静默失败，表现为“所有页面都翻不了”。
    await this.jsRun(ctrl, TranslateScript.restore());
    let injected: boolean = false;
    for (let i = 0; i < 3 && !injected; i++) {
      await this.jsRun(ctrl, lib);
      const probe: string = await this.jsRun(ctrl, TranslateScript.probe(), 1500);
      injected = probe.indexOf('object') >= 0;
      if (!injected) {
        await this.wait(180);
      }
    }
    if (token !== this.transToken) {
      return;
    }
    if (!injected) {
      this.endTranslate(false);
      this.toast('无法在当前页面注入翻译脚本，请刷新后重试');
      return;
    }
    let raw: string = await this.jsRun(ctrl, TranslateScript.collect());
    let page: PageTexts = this.parsePageTexts(raw);
    if (!page.ok) {
      // 页面较大时首次执行可能来不及返回，稍等再取一次
      await this.wait(150);
      raw = await this.jsRun(ctrl, TranslateScript.collect());
      page = this.parsePageTexts(raw);
    }
    if (token !== this.transToken) {
      return;
    }
    if (!page.ok) {
      this.endTranslate(false);
      this.toast(raw.length === 0 ? '页面无响应，请刷新后重试' : '当前页面无法翻译');
      return;
    }
    if (page.total <= 0) {
      this.endTranslate(false);
      this.toast('页面没有需要翻译的内容');
      return;
    }
    this.transTotal = page.total;
    const items: string[] = page.items;
    let index: number = 0;
    let okCount: number = 0;
    let detected: string = '';
    while (index < items.length) {
      if (token !== this.transToken) {
        return;
      }
      // 按累计字符数切批：单次请求不超过 3000 字，最多 40 段
      let end: number = index;
      let chars: number = 0;
      while (end < items.length && end - index < 40 && chars < 3000) {
        chars += items[end].length + 1;
        end++;
      }
      if (end === index) {
        end = index + 1;
      }
      const slice: string[] = items.slice(index, end);
      const res: TransResult = await BingTranslate.translateBatch(slice, code);
      if (token !== this.transToken) {
        return;
      }
      if (!res.ok) {
        this.endTranslate(false);
        this.toast(res.error.length > 0 ? res.error : '翻译失败，请稍后重试');
        return;
      }
      if (detected.length === 0 && res.detected.length > 0) {
        detected = res.detected;
      }
      if (res.texts.length === slice.length) {
        await this.jsRun(ctrl, TranslateScript.apply(index, res.texts));
        okCount += res.texts.length;
      }
      index = end;
      this.transDone = okCount;
    }
    if (token !== this.transToken) {
      return;
    }
    if (okCount === 0) {
      this.endTranslate(false);
      this.toast('翻译失败，请稍后重试');
      return;
    }
    this.transBusy = false;
    this.transTranslated = true;
    tab.translated = true;
    if (detected === code) {
      this.toast('页面本身已是' + this.transLang);
    } else {
      this.toast('已翻译 ' + okCount.toString() + ' 段');
    }
  }

  private endTranslate(translated: boolean): void {
    this.transBusy = false;
    this.transTranslated = translated;
    if (!translated) {
      this.transShown = false;
    }
  }

  /** 停止翻译：作废当前任务，已翻部分保留 */
  private stopTranslate(): void {
    this.transToken++;
    this.transBusy = false;
    const has: boolean = this.transDone > 0;
    this.transTranslated = has;
    this.transShown = has;
    const tab: TabMeta | null = this.cur();
    if (has && tab !== null) {
      tab.translated = true;
    }
    this.toast(has ? '已停止翻译' : '已取消翻译');
  }

  /** 还原为原文 */
  private restoreTranslate(): void {
    this.transToken++;
    const tab: TabMeta | null = this.cur();
    this.transBusy = false;
    this.transTranslated = false;
    this.transShown = false;
    if (tab !== null) {
      tab.translated = false;
      this.jsRun(this.controllerOf(tab.id), TranslateScript.restore());
    }
    this.toast('已恢复原文');
  }

  /** 换页 / 换标签时丢掉翻译条 */
  private resetTrans(): void {
    if (this.transShown || this.transBusy) {
      this.transToken++;
      this.transShown = false;
      this.transBusy = false;
      this.transTranslated = false;
      this.transDone = 0;
      this.transTotal = 0;
    }
  }

  private readerMode(): void {    const t: TabMeta | null = this.cur();
    if (t === null || t.showingHome) {
      this.toast('请先打开一个网页');
      return;
    }
    const dark: boolean = Prefs.night();
    const textColor: string = dark ? '#EDEDF0' : '#141418';
    const bgColor: string = dark ? '#0B0B0E' : '#FAFAFC';
    const js: string = '(function(){try{'
      + 'var src=document.querySelector("article")||document.querySelector("main")||'
      + 'document.querySelector("[role=main]")||document.querySelector(".post-content")||'
      + 'document.querySelector("#content")||document.body;'
      + 'var c=src.cloneNode(true);'
      + 'var junk=c.querySelectorAll("script,style,nav,aside,footer,header,form,iframe,noscript,button,input,select,textarea,svg,video,audio");'
      + 'for(var i=junk.length-1;i>=0;i--){if(junk[i].parentNode)junk[i].parentNode.removeChild(junk[i]);}'
      + 'var title=(document.title||"").replace(/[<>&]/g,"");'
      + 'var html="<!DOCTYPE html><html><head><meta name=\\"viewport\\" content=\\"width=device-width,initial-scale=1\\">'
      + '<style>body{margin:0 auto;padding:26px 22px 70px;max-width:720px;background:' + bgColor + ';color:' + textColor + ';'
      + 'font:17px/1.9 -apple-system,system-ui,\\"PingFang SC\\",\\"Noto Sans SC\\",sans-serif;word-wrap:break-word}'
      + 'h1{font-size:25px;line-height:1.45;margin:0 0 10px;font-weight:700}'
      + 'h2,h3{line-height:1.5;margin:28px 0 10px}p{margin:0 0 19px}'
      + 'img{max-width:100%;height:auto;border-radius:10px;display:block;margin:16px 0}'
      + 'a{color:#4C8DFF;text-decoration:none}blockquote{margin:0 0 20px;padding:4px 0 4px 16px;border-left:3px solid #7A7A88;opacity:.85}'
      + 'pre{overflow:auto;background:' + (dark ? '#17171C' : '#F0F0F4') + ';padding:14px;border-radius:10px;font-size:14px}'
      + 'figure{margin:16px 0}figcaption{font-size:12px;opacity:.6}hr{border:0;border-top:1px solid ' + (dark ? '#2A2A32' : '#E3E3EA') + ';margin:28px 0}'
      + '</style></head><body><h1>"+title+"</h1>"+c.innerHTML+"</body></html>";'
      + 'return html;}catch(e){return null;}})()';
    try {
      this.controllerOf(t.id).runJavaScript(js, (err: Error, value: string) => {
        if (!value || value === 'null') {
          this.toast('未能提取到正文');
          return;
        }
        let html: string = value;
        try {
          html = JSON.parse(value) as string;
        } catch (e) {
          html = value;
        }
        if (!html || html.length < 10) {
          this.toast('未能提取到正文');
          return;
        }
        try {
          this.controllerOf(t.id).loadData(html, 'text/html', 'utf-8', t.url, t.url);
        } catch (e) {
          this.toast('阅读模式加载失败');
        }
      });
    } catch (e) {
      this.toast('未能提取到正文');
    }
  }

  private viewSource(): void {
    const t: TabMeta | null = this.cur();
    if (t === null || t.showingHome || !t.url || t.url.startsWith('about:')) {
      this.toast('请先打开一个网页');
      return;
    }
    this.toast('正在获取源码…');
    const js: string = '(function(){try{return document.documentElement.outerHTML;}catch(e){return null;}})()';
    try {
      this.controllerOf(t.id).runJavaScript(js, (err: Error, value: string) => {
        if (!value || value === 'null' || value.length <= 4) {
          this.showAlert('网页源码', '未能获取到源码：页面尚未加载完成或内容为空。');
          return;
        }
        let html: string = value;
        try {
          html = JSON.parse(value) as string;
        } catch (e) {
          html = value;
        }
        this.sourceText = html;
        this.sourceTitle = t.url;
        this.screen = 'source';
      });
    } catch (e) {
      this.showAlert('网页源码', '未能获取到源码。');
    }
  }

  private showSslInfo(): void {
    const t: TabMeta | null = this.cur();
    if (t === null || t.showingHome || !t.url) {
      this.showAlert('网站证书', '当前页面没有证书信息。');
      return;
    }
    if (!t.url.startsWith('https://')) {
      this.showAlert('网站证书', '此网站未使用加密连接（HTTP）\n\n' + Utils.displayUrl(t.url)
        + '\n\n数据将以明文传输，可能被第三方窃取或篡改，请谨慎输入账号、密码等敏感信息。');
      return;
    }
    this.toast('正在获取证书…');
    SslInfo.fetch(this.controllerOf(t.id)).then((info) => {
      if (!info.ok) {
        this.showAlert('网站证书', '无法获取 ' + Utils.displayUrl(t.url) + ' 的证书：\n\n' + info.error);
        return;
      }
      this.showAlert((info.daysLeft >= 0 ? '连接安全' : '证书已过期') + ' · TLS 证书', info.summary());
    }).catch(() => {
      this.showAlert('网站证书', '无法获取证书信息。');
    });
  }

  private showFind(): void {
    const t: TabMeta | null = this.cur();
    if (t === null || t.showingHome) {
      this.toast('请先打开一个网页');
      return;
    }
    this.findShown = true;
    this.findText = '';
    this.findInfo = '';
  }

  private applyFind(text: string): void {
    this.findText = text;
    const t: TabMeta | null = this.cur();
    if (t === null) {
      return;
    }
    try {
      if (!text || text.length === 0) {
        this.controllerOf(t.id).clearMatches();
        this.findInfo = '';
      } else {
        this.controllerOf(t.id).searchAllAsync(text);
        this.findInfo = '查找中';
      }
    } catch (e) {
    }
  }

  private findNext(forward: boolean): void {
    const t: TabMeta | null = this.cur();
    if (t === null) {
      return;
    }
    try {
      this.controllerOf(t.id).searchNext(forward);
    } catch (e) {
    }
  }

  private openList(mode: string): void {
    this.listMode = mode;
    this.screen = 'list';
  }

  // ---------------------------------------------------------------
  // 弹窗 / 提示
  // ---------------------------------------------------------------

  private showAlert(title: string, message: string, positive: string = '知道了',
    onPositive: () => void = () => {
    }): void {
    this.dlgTitle = title;
    this.dlgMessage = message;
    this.dlgKind = 'alert';
    this.dlgPositive = positive;
    this.dlgNegative = '';
    this.dlgDanger = false;
    this.dlgOptions = [];
    this.dlgInputVisible = false;
    this.dlgButtons = true;
    this.dlgOnPositive = onPositive;
    this.dlgOnNegative = () => {
    };
    this.dialogShown = true;
  }

  private showConfirm(title: string, message: string, positive: string,
    onPositive: () => void, onNegative: () => void = () => {
    }, danger: boolean = false): void {
    this.dlgTitle = title;
    this.dlgMessage = message;
    this.dlgKind = 'confirm';
    this.dlgPositive = positive;
    this.dlgNegative = '取消';
    this.dlgDanger = danger;
    this.dlgOptions = [];
    this.dlgInputVisible = false;
    this.dlgButtons = true;
    this.dlgOnPositive = onPositive;
    this.dlgOnNegative = onNegative;
    this.dialogShown = true;
  }

  private showInput(title: string, hint: string, initial: string, positive: string,
    onPositive: (text: string) => void, onNegative: () => void = () => {
    }): void {
    this.dlgTitle = title;
    this.dlgMessage = '';
    this.dlgKind = 'input';
    this.dlgPositive = positive;
    this.dlgNegative = '取消';
    this.dlgDanger = false;
    this.dlgHint = hint;
    this.dlgInput = initial;
    this.dlgInputVisible = true;
    this.dlgButtons = true;
    this.dlgOnPositive = onPositive;
    this.dlgOnNegative = onNegative;
    this.dialogShown = true;
  }

  private showChoice(title: string, options: string[], checked: number,
    onPick: (index: number) => void): void {
    const list: DialogOption[] = [];
    for (let i = 0; i < options.length; i++) {
      list.push(new DialogOption(options[i], i, false));
    }
    this.dlgTitle = title;
    this.dlgMessage = '';
    this.dlgKind = 'choice';
    this.dlgOptions = list;
    this.dlgChecked = checked;
    this.dlgInputVisible = false;
    this.dlgButtons = false;
    this.dlgOnOption = onPick;
    this.dialogShown = true;
  }

  private showOptions(title: string, options: string[], onPick: (index: number) => void,
    danger: boolean = false): void {
    const list: DialogOption[] = [];
    for (let i = 0; i < options.length; i++) {
      list.push(new DialogOption(options[i], i, danger && i === options.length - 1));
    }
    this.dlgTitle = title;
    this.dlgMessage = '';
    this.dlgKind = 'options';
    this.dlgOptions = list;
    this.dlgChecked = -1;
    this.dlgInputVisible = false;
    this.dlgButtons = false;
    this.dlgOnOption = onPick;
    this.dialogShown = true;
  }

  private closeDialog(): void {
    this.dialogShown = false;
    this.dlgInputVisible = false;
    this.dlgOnNegative();
    this.dlgOnNegative = () => {
    };
  }

  private showAgreement(): void {
    this.dlgTitle = Agreement.title();
    this.dlgMessage = Agreement.fullText();
    this.dlgKind = 'agreement';
    this.dlgPositive = '同意并继续';
    this.dlgNegative = '不同意';
    this.dlgDanger = false;
    this.dlgOptions = [];
    this.dlgInputVisible = false;
    this.dlgButtons = true;
    this.dlgOnPositive = () => {
      Prefs.setAgreed(true);
    };
    this.dlgOnNegative = () => {
      const ctx = getContext(this) as common.UIAbilityContext;
      ctx.terminateSelf();
    };
    this.dialogShown = true;
  }

  private toast(text: string): void {
    this.toastText = text;
    this.toastShown = true;
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer);
    }
    this.toastTimer = setTimeout(() => {
      this.toastShown = false;
    }, 1800);
  }

  private copyText(text: string): void {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      pasteboard.getSystemPasteboard().setData(data).catch(() => {
      });
    } catch (e) {
    }
  }

  // ---------------------------------------------------------------
  // 返回键
  // ---------------------------------------------------------------

  onBackPress(): boolean {
    if (this.dialogShown) {
      this.closeDialog();
      return true;
    }
    if (this.addressShown) {
      this.addressShown = false;
      return true;
    }
    if (this.menuShown) {
      this.menuShown = false;
      return true;
    }
    if (this.tabsShown) {
      this.tabsShown = false;
      return true;
    }
    if (this.screen !== 'browser') {
      this.screen = 'browser';
      return true;
    }
    if (this.findShown) {
      this.findShown = false;
      const t: TabMeta | null = this.cur();
      if (t !== null) {
        try {
          this.controllerOf(t.id).clearMatches();
        } catch (e) {
        }
      }
      return true;
    }
    const t: TabMeta | null = this.cur();
    if (t !== null) {
      if (t.showingHome) {
        if (t.url && t.url.length > 0 && !t.url.startsWith('about:')) {
          t.showingHome = false;
          this.touchTabs();
          return true;
        }
      } else {
        if (t.canBack) {
          try {
            this.controllerOf(t.id).backward();
          } catch (e) {
          }
          return true;
        }
        t.showingHome = true;
        this.touchTabs();
        return true;
      }
    }
    const now: number = Date.now();
    if (now - this.lastBack < 2000) {
      const ctx = getContext(this) as common.UIAbilityContext;
      ctx.terminateSelf();
      return true;
    }
    this.lastBack = now;
    this.toast('再按一次退出');
    return true;
  }

  onPageHide(): void {
    this.saveSession();
  }

  onPageShow(): void {
    this.applyTheme();
  }

  // ---------------------------------------------------------------
  // 界面
  // ---------------------------------------------------------------

  @Builder
  bottomBar() {
    Column() {
      Divider().color(this.pal.divider).strokeWidth(1)
      Row() {
        Row() {
          ZIcon({ path: 'ic_back', iconSize: 22, color: this.pal.icon })
        }
        .width(42)
        .height(42)
        .justifyContent(FlexAlign.Center)
        .opacity(this.cur() !== null && this.cur()?.canBack ? 1 : 0.3)
        .onClick(() => {
          const t: TabMeta | null = this.cur();
          if (t !== null && !t.showingHome && t.canBack) {
            try {
              this.controllerOf(t.id).backward();
            } catch (e) {
            }
          }
        })

        Row() {
          ZIcon({ path: 'ic_forward', iconSize: 22, color: this.pal.icon })
        }
        .width(38)
        .height(42)
        .justifyContent(FlexAlign.Center)
        .opacity(this.cur() !== null && this.cur()?.canForward ? 1 : 0.3)
        .onClick(() => {
          const t: TabMeta | null = this.cur();
          if (t !== null && !t.showingHome && t.canForward) {
            try {
              this.controllerOf(t.id).forward();
            } catch (e) {
            }
          }
        })

        Row() {
          ZIcon({
            path: this.addressIcon(),
            iconSize: 14,
            color: this.pal.iconMuted
          })
          Text(this.addressTitle())
            .fontSize(13)
            .fontColor(this.cur() === null || this.cur()?.showingHome
              ? this.pal.textTertiary : this.pal.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .margin({ left: 8 })

          if (this.cur() !== null && !this.cur()?.showingHome) {
            Row() {
              ZIcon({
                path: this.cur()?.loading ? 'ic_close' : 'ic_refresh',
                iconSize: 16,
                color: this.pal.iconMuted
              })
            }
            .width(32)
            .height(32)
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              const t: TabMeta | null = this.cur();
              if (t === null) {
                return;
              }
              try {
                if (t.loading) {
                  this.controllerOf(t.id).stop();
                } else {
                  this.controllerOf(t.id).refresh();
                }
              } catch (e) {
              }
            })
          }
        }
        .layoutWeight(1)
        .height(40)
        .margin({ left: 4, right: 4 })
        .padding({ left: 12, right: 4 })
        .backgroundColor(this.pal.pill)
        .borderRadius(20)
        .onClick(() => {
          this.openAddressEditor();
        })
        .gesture(LongPressGesture().onAction(() => {
          this.showPageActions();
        }))

        Stack({ alignContent: Alignment.TopEnd }) {
          ZIcon({ path: 'ic_tabs', iconSize: 20, color: this.pal.icon })
            .margin({ top: 11, right: 11 })
          Text(this.tabs.length.toString())
            .fontSize(9)
            .fontColor(this.pal.textPrimary)
            .backgroundColor(this.pal.surfaceAlt)
            .borderRadius(8)
            .constraintSize({ minWidth: 16 })
            .height(16)
            .textAlign(TextAlign.Center)
            .padding({ left: 3, right: 3 })
            .margin({ top: 4, right: 2 })
        }
        .width(42)
        .height(42)
        .onClick(() => {
          this.tabsShown = true;
        })

        Row() {
          ZIcon({ path: 'ic_more', iconSize: 22, color: this.pal.icon })
        }
        .width(42)
        .height(42)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.menuShown = true;
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: 4, right: 4 })
      .backgroundColor(this.pal.bg)
    }
    .width('100%')
  }

  private addressIcon(): string {
    const t: TabMeta | null = this.cur();
    if (t === null || t.showingHome) {
      return 'ic_search';
    }
    return t.url.startsWith('https://') ? 'ic_lock' : 'ic_globe';
  }

  private addressTitle(): string {
    const t: TabMeta | null = this.cur();
    if (t === null || t.showingHome) {
      return '搜索或输入网址';
    }
    return Utils.displayUrl(t.url);
  }

  private showPageActions(): void {
    const t: TabMeta | null = this.cur();
    if (t === null || t.showingHome) {
      this.toast('当前没有页面链接');
      return;
    }
    this.showOptions('页面操作', ['复制链接', '翻译网页', '用其他浏览器打开', '保存离线网页'], (which: number) => {
      if (which === 0) {
        this.copyText(t.url);
        this.toast('已复制到剪贴板');
      } else if (which === 1) {
        this.translatePage();
      } else if (which === 2) {
        this.handleSpecialUrlExternal(t.url);
      } else {
        this.downloadPage(t.url);
      }
    });
  }

  private handleSpecialUrlExternal(url: string): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    ctx.startAbility({ action: 'ohos.want.action.viewData', uri: url }).catch(() => {
      this.toast('没有找到可用的浏览器');
    });
  }

  private downloadPage(url: string): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    const dir: string = ctx.filesDir + '/downloads';
    const name: string = Utils.guessFileName(url, '', 'text/html');
    try {
      try {
        fs.mkdirSync(dir);
      } catch (e) {
      }
      const path: string = dir + '/' + name;
      request.downloadFile(ctx, { url: url, filePath: path, background: false })
        .then(() => {
          Store.addDownload(name, url, path, 0);
          this.toast('已开始下载 · ' + name);
        })
        .catch(() => {
          this.toast('下载失败');
        });
    } catch (e) {
      this.toast('下载失败');
    }
  }

  @Builder
  pageLayer() {
    Column() {
      Stack({ alignContent: Alignment.TopStart }) {
        ForEach(this.tabs, (tab: TabMeta, index: number) => {
          TabWeb({
            controller: this.controllerOf(tab.id),
            tabId: tab.id,
            active: index === this.current,
            night: Prefs.night(),
            noImage: Prefs.noImage(),
            textZoom: Prefs.textZoom(),
            jsEnabled: Prefs.javaScript(),
            ua: Prefs.uaString(''),
            callbacks: this.webCallbacks
          })
        }, (tab: TabMeta) => tab.id.toString())

        if (this.cur() !== null && this.cur()?.showingHome) {
          HomeView({
            pal: this.pal,
            incognito: this.cur()?.incognito ?? false,
            onSearch: () => {
              this.openAddressEditor();
            },
            onAi: () => {
              this.screen = 'ai';
            },
            onShortcut: (url: string) => {
              const t: TabMeta | null = this.cur();
              if (t === null) {
                this.createTab(false, url);
              } else {
                this.loadInTab(t, url);
              }
            },
            onList: (mode: string) => {
              this.openList(mode);
            }
          })
        }

        if (this.cur() !== null && this.cur()?.error) {
          Column() {
            Text('无法打开此页面')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.pal.textPrimary)
            Text(this.cur()?.errorDesc)
              .fontSize(12)
              .fontColor(this.pal.textTertiary)
              .textAlign(TextAlign.Center)
              .lineHeight(19)
              .margin({ top: 10, left: 32, right: 32 })
            Text('重试')
              .fontSize(14)
              .fontColor(this.pal.onAccent)
              .backgroundColor(this.pal.accent)
              .borderRadius(20)
              .padding({ left: 26, right: 26, top: 10, bottom: 10 })
              .margin({ top: 20 })
              .onClick(() => {
                const t: TabMeta | null = this.cur();
                if (t !== null && t.url) {
                  t.error = false;
                  this.touchTabs();
                  try {
                    this.controllerOf(t.id).loadUrl(t.url);
                  } catch (e) {
                  }
                }
              })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.pal.bg)
        }

        if (this.cur() !== null && this.cur()?.loading && !this.cur()?.showingHome) {
          Row()
            .width((this.cur()?.progress ?? 0).toString() + '%')
            .height(2)
            .backgroundColor(this.pal.progress)
        }

        if (this.findShown) {
          Row() {
            TextInput({ text: this.findText, placeholder: '页内查找' })
              .layoutWeight(1)
              .height(52)
              .fontSize(15)
              .fontColor(this.pal.textPrimary)
              .placeholderColor(this.pal.textTertiary)
              .backgroundColor(Color.Transparent)
              .onChange((value: string) => {
                this.applyFind(value);
              })
              .onSubmit(() => {
                this.findNext(true);
              })
            Text(this.findInfo)
              .fontSize(11)
              .fontColor(this.pal.textSecondary)
              .margin({ right: 6 })
            Row() {
              ZIcon({ path: 'ic_arrow_up', iconSize: 18, color: this.pal.iconMuted })
            }
            .width(40)
            .height(40)
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.findNext(false);
            })
            Row() {
              ZIcon({ path: 'ic_arrow_down', iconSize: 18, color: this.pal.iconMuted })
            }
            .width(40)
            .height(40)
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.findNext(true);
            })
            Row() {
              ZIcon({ path: 'ic_close', iconSize: 18, color: this.pal.iconMuted })
            }
            .width(40)
            .height(40)
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.findShown = false;
            })
          }
          .width('100%')
          .height(52)
          .padding({ left: 12, right: 4 })
          .backgroundColor(this.pal.surface)
        }

        if (this.transShown) {
          Column() {
            Row() {
              Row() {
                ZIcon({ path: 'ic_translate', iconSize: 16, color: this.pal.accent })
              }
              .width(24)
              .justifyContent(FlexAlign.Start)

              Text(this.transBusy
                ? ('必应翻译 · ' + this.transDone.toString() + '/' + this.transTotal.toString() + ' 段')
                : (this.transDone >= this.transTotal && this.transTotal > 0
                  ? ('已翻译为' + this.transLang)
                  : ('已翻译 ' + this.transDone.toString() + ' 段')))
                .fontSize(12)
                .fontColor(this.pal.textPrimary)
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              if (this.transBusy) {
                Text('停止')
                  .fontSize(12)
                  .fontColor(this.pal.textSecondary)
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .onClick(() => {
                    this.stopTranslate();
                  })
              } else {
                Text('原文')
                  .fontSize(12)
                  .fontColor(this.pal.accent)
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .onClick(() => {
                    this.restoreTranslate();
                  })
              }

              Row() {
                ZIcon({ path: 'ic_close', iconSize: 14, color: this.pal.iconMuted })
              }
              .width(34)
              .height(34)
              .justifyContent(FlexAlign.Center)
              .onClick(() => {
                if (this.transBusy) {
                  this.stopTranslate();
                }
                this.transShown = false;
              })
            }
            .width('100%')

            if (this.transBusy) {
              Row() {
                Row()
                  .width((this.transTotal > 0
                    ? Math.round(this.transDone * 100 / this.transTotal)
                    : 0).toString() + '%')
                  .height(2)
                  .backgroundColor(this.pal.accent)
              }
              .width('100%')
              .height(2)
              .backgroundColor(this.pal.surfaceAlt)
            }
          }
          .width('100%')
          .padding({ left: 14, right: 4, top: 6, bottom: 2 })
          .backgroundColor(this.pal.surface)
          .border({ width: { top: 1 }, color: this.pal.divider })
        }
      }
      .layoutWeight(1)
      .width('100%')

      this.bottomBar()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  menuLayer() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.pal.scrim)
        .onClick(() => {
          this.menuShown = false;
        })

      MenuSheet({
        pal: this.pal,
        title: this.menuTitle(),
        subtitle: this.menuSubtitle(),
        bookmarked: this.isBookmarked(),
        night: Prefs.night(),
        noImage: Prefs.noImage(),
        desktop: Prefs.desktop(),
        onAction: (action: string) => {
          this.onMenuAction(action);
        },
        onClose: () => {
          this.menuShown = false;
        }
      })
        .transition(TransitionEffect.translate({ y: 320 }).animation({ duration: 200, curve: Curve.EaseOut }))
    }
    .width('100%')
    .height('100%')
  }

  private menuTitle(): string {
    const t: TabMeta | null = this.cur();
    return t !== null && !t.showingHome ? t.displayTitle() : 'Zorme';
  }

  private menuSubtitle(): string {
    const t: TabMeta | null = this.cur();
    if (t === null || t.showingHome) {
      return '新标签页';
    }
    return (t.url.startsWith('https://') ? '安全连接 · ' : '') + Utils.displayUrl(t.url);
  }

  private isBookmarked(): boolean {
    const t: TabMeta | null = this.cur();
    return t !== null && !t.showingHome && Store.isBookmarked(t.url);
  }

  @Builder
  dialogLayer() {
    if (this.dialogShown) {
      Stack({ alignContent: Alignment.Bottom }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.pal.scrim)

        Column() {
          Row()
            .width(36)
            .height(4)
            .borderRadius(2)
            .backgroundColor(this.pal.divider)
            .margin({ bottom: 16 })

          Text(this.dlgTitle)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.pal.textPrimary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          if (this.dlgMessage.length > 0) {
            Scroll() {
              Text(this.dlgMessage)
                .fontSize(13)
                .fontColor(this.pal.textSecondary)
                .lineHeight(20)
                .width('100%')
            }
            .constraintSize({ maxHeight: 320 })
            .width('100%')
            .margin({ top: 8 })
            .scrollBar(BarState.Auto)
            .edgeEffect(EdgeEffect.None)
          }

          if (this.dlgInputVisible) {
            TextInput({ text: this.dlgInput, placeholder: this.dlgHint })
              .width('100%')
              .height(50)
              .margin({ top: 14 })
              .fontSize(15)
              .fontColor(this.pal.textPrimary)
              .placeholderColor(this.pal.textTertiary)
              .backgroundColor(this.pal.surfaceAlt)
              .borderRadius(12)
              .padding({ left: 16, right: 16 })
              .onChange((value: string) => {
                this.dlgInput = value;
              })
          }

          if (this.dlgOptions.length > 0) {
            Scroll() {
              Column() {
                ForEach(this.dlgOptions, (opt: DialogOption) => {
                  Row() {
                    Text(opt.text)
                      .fontSize(15)
                      .fontColor(opt.danger ? this.pal.danger : this.pal.textPrimary)
                      .layoutWeight(1)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    if (this.dlgKind === 'choice' && this.dlgChecked === opt.value) {
                      ZIcon({ path: 'ic_check', iconSize: 18, color: this.pal.textPrimary })
                    }
                  }
                  .width('100%')
                  .height(52)
                  .onClick(() => {
                    const idx: number = opt.value;
                    this.dialogShown = false;
                    this.dlgOptions = [];
                    this.dlgOnOption(idx);
                  })
                }, (opt: DialogOption) => opt.value.toString() + opt.text)
              }
              .width('100%')
            }
            .constraintSize({ maxHeight: 300 })
            .width('100%')
            .margin({ top: 6 })
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.None)
          }

          if (this.dlgButtons) {
            Row({ space: 10 }) {
              if (this.dlgNegative.length > 0) {
                Text(this.dlgNegative)
                  .fontSize(14)
                  .fontColor(this.pal.textPrimary)
                  .height(46)
                  .layoutWeight(1)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(this.pal.surfaceAlt)
                  .borderRadius(12)
                  .onClick(() => {
                    this.dialogShown = false;
                    const cb = this.dlgOnNegative;
                    this.dlgOnNegative = () => {
                    };
                    cb();
                  })
              }
              Text(this.dlgPositive)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.dlgDanger ? '#FFFFFF' : this.pal.onAccent)
                .height(46)
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
                .backgroundColor(this.dlgDanger ? this.pal.danger : this.pal.accent)
                .borderRadius(12)
                .onClick(() => {
                  const text: string = this.dlgInput;
                  this.dialogShown = false;
                  this.dlgInputVisible = false;
                  const cb = this.dlgOnPositive;
                  this.dlgOnPositive = () => {
                  };
                  cb(text);
                })
            }
            .width('100%')
            .margin({ top: 18 })
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 10, bottom: 16 })
        .backgroundColor(this.pal.sheet)
        .borderRadius({ topLeft: 22, topRight: 22 })
        .transition(TransitionEffect.translate({ y: 360 }).animation({ duration: 200, curve: Curve.EaseOut }))
      }
      .width('100%')
      .height('100%')
    }
  }

  @Builder
  toastLayer() {
    if (this.toastShown) {
      Column() {
        Text(this.toastText)
          .fontSize(13)
          .fontColor('#FFFFFF')
          .maxLines(3)
          .textAlign(TextAlign.Center)
          .backgroundColor('#E6111114')
          .borderRadius(20)
          .padding({ left: 18, right: 18, top: 10, bottom: 10 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
      .padding({ bottom: 110 })
      .hitTestBehavior(HitTestMode.None)
    }
  }

  private checkUpdate(): void {
    this.toast('正在检查更新…');
    UpdateChecker.check('1.0.0', (ok: boolean, hasUpdate: boolean, latest: string,
      notes: string, hapUrl: string, releaseUrl: string) => {
      if (!ok) {
        this.showAlert('检查更新', '检查失败，请确认网络可以访问 github.com 后重试。');
        return;
      }
      if (!hasUpdate) {
        this.showAlert('检查更新', '当前已是最新版本 1.0.0。');
        return;
      }
      let brief: string = notes ? notes.trim() : '';
      if (brief.length > 240) {
        brief = brief.substring(0, 240) + '…';
      }
      if (brief.length === 0) {
        brief = '已发布新版本，建议更新以获得更好的体验。';
      }
      this.showConfirm('发现新版本 ' + latest, brief + '\n\n当前版本：1.0.0', '查看发布页',
        () => {
          const ctx = getContext(this) as common.UIAbilityContext;
          ctx.startAbility({ action: 'ohos.want.action.viewData', uri: releaseUrl }).catch(() => {
            this.toast('无法打开发布页');
          });
        });
    });
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.ready) {
        this.pageLayer()
      } else {
        Column() {
          Text('Zorme')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.pal.textPrimary)
            .letterSpacing(4)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.pal.bg)
      }

      if (this.screen === 'settings') {
        SettingsView({
          pal: this.pal,
          dark: this.dark,
          onClose: () => {
            this.screen = 'browser';
            this.applyTheme();
          },
          onChanged: () => {
            this.applyTheme();
            this.touchTabs();
          },
          toast: (text: string) => {
            this.toast(text);
          },
          dialogChoice: (title: string, options: string[], checked: number,
            onPick: (index: number) => void) => {
            this.showChoice(title, options, checked, onPick);
          },
          dialogInput: (title: string, hint: string, initial: string, positive: string,
            onPositive: (text: string) => void) => {
            this.showInput(title, hint, initial, positive, onPositive);
          },
          dialogConfirm: (title: string, message: string, positive: string,
            onPositive: () => void, danger: boolean) => {
            this.showConfirm(title, message, positive, onPositive, () => {
            }, danger);
          },
          dialogAlert: (title: string, message: string) => {
            this.showAlert(title, message);
          },
          onNetLog: () => {
            this.netLogBack = 'settings';
            this.screen = 'netlog';
          },
          checkUpdate: () => {
            this.checkUpdate();
          }
        })
      } else if (this.screen === 'ai') {
        AiChatView({
          pal: this.pal,
          onClose: () => {
            this.screen = 'browser';
          },
          toast: (text: string) => {
            this.toast(text);
          },
          openSettings: () => {
            this.screen = 'settings';
          }
        })
      } else if (this.screen === 'list') {
        ListView({
          pal: this.pal,
          mode: this.listMode,
          onClose: () => {
            this.screen = 'browser';
          },
          onOpen: (url: string) => {
            this.screen = 'browser';
            const t: TabMeta | null = this.cur();
            if (t === null) {
              this.createTab(false, url);
            } else {
              this.loadInTab(t, url);
            }
          },
          toast: (text: string) => {
            this.toast(text);
          },
          confirm: (title: string, message: string, positive: string, cb: () => void) => {
            this.showConfirm(title, message, positive, cb);
          }
        })
      } else if (this.screen === 'source') {
        SourceView({
          pal: this.pal,
          title: this.sourceTitle,
          content: this.sourceText,
          onClose: () => {
            this.screen = 'browser';
          },
          toast: (text: string) => {
            this.toast(text);
          }
        })
      } else if (this.screen === 'netlog') {
        NetLogView({
          pal: this.pal,
          onClose: () => {
            this.screen = this.netLogBack;
          },
          toast: (text: string) => {
            this.toast(text);
          }
        })
      }

      if (this.tabsShown) {
        TabsOverlay({
          pal: this.pal,
          tabs: this.tabs,
          current: this.current,
          onSelect: (index: number) => {
            this.selectTab(index);
          },
          onClose: (index: number) => {
            this.closeTab(index);
          },
          onNew: (incognito: boolean) => {
            this.createTab(incognito, '');
            this.tabsShown = false;
          },
          onDismiss: () => {
            this.tabsShown = false;
          }
        })
      }

      if (this.addressShown) {
        AddressOverlay({
          pal: this.pal,
          text: this.addressText,
          suggestions: this.suggestions,
          onTextChange: (value: string) => {
            this.addressText = value;
            this.refreshSuggestions(value);
          },
          onSubmit: () => {
            this.commitAddress();
          },
          onCancel: () => {
            this.closeAddressEditor();
          },
          onPick: (url: string) => {
            this.addressShown = false;
            this.addressText = url;
            this.loadUrlOrSearch(url);
          }
        })
      }

      if (this.menuShown) {
        this.menuLayer()
      }

      this.dialogLayer()
      this.toastLayer()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pal.bg)
  }
}
