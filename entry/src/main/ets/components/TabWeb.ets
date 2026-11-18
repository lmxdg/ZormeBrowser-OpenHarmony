import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { picker } from '@kit.CoreFileKit';
import { Utils } from '../common/Utils';
import { GmBridge } from '../model/UserscriptStore';

/** Web 事件回调（全部可选，便于默认空实现） */
export interface TabCallbacks {
  onAttached?: (tabId: number) => void;
  onBegin?: (tabId: number, url: string) => void;
  onEnd?: (tabId: number, url: string, title: string) => void;
  onProgress?: (tabId: number, progress: number) => void;
  onTitle?: (tabId: number, title: string) => void;
  onError?: (tabId: number, code: string, desc: string) => void;
  onState?: (tabId: number) => void;
  onIntercept?: (url: string, method: string, main: boolean) => boolean;
  onSpecialUrl?: (url: string) => boolean;
  onDownloadStart?: (url: string, path: string, name: string, total: number) => void;
  onDownloadUpdate?: (url: string, state: number, received: number, total: number) => void;
  onJsAlert?: (message: string, url: string, result: JsResult) => void;
  onJsConfirm?: (message: string, url: string, result: JsResult) => void;
  onJsPrompt?: (message: string, url: string, def: string, result: JsResult) => void;
}

/**
 * 单个标签页的 Web 容器。
 * 每个标签持有独立的 WebviewController，切换标签时仅改变可见性，保留页面状态。
 */
@Component
export struct TabWeb {
  controller: webview.WebviewController = new webview.WebviewController();
  tabId: number = 0;
  @Prop active: boolean = true;
  @Prop night: boolean = false;
  @Prop noImage: boolean = false;
  @Prop textZoom: number = 100;
  @Prop jsEnabled: boolean = true;
  @Prop @Watch('onUaChanged') ua: string = '';
  callbacks: TabCallbacks = {};
  /** 油猴 GM 桥（由 Index 传入，跨标签页共享同一实例） */
  gmBridge: GmBridge = new GmBridge();
  private downloadDelegate: webview.WebDownloadDelegate = new webview.WebDownloadDelegate();
  private attached: boolean = false;

  aboutToAppear(): void {
    this.downloadDelegate.onBeforeDownload((item: webview.WebDownloadItem) => {
      this.handleBeforeDownload(item);
    });
    this.downloadDelegate.onDownloadUpdated((item: webview.WebDownloadItem) => {
      const state: number = TabWeb.mapState(item.getState());
      this.callbacks.onDownloadUpdate?.(item.getUrl(), state,
        item.getReceivedBytes(), item.getTotalBytes());
    });
  }

  private static mapState(state: webview.WebDownloadState): number {
    if (state === webview.WebDownloadState.COMPLETED) {
      return 1;
    }
    if (state === webview.WebDownloadState.CANCELED || state === webview.WebDownloadState.INTERRUPTED) {
      return 2;
    }
    return 0;
  }

  private handleBeforeDownload(item: webview.WebDownloadItem): void {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const dir: string = ctx.filesDir + '/downloads';
      try {
        fs.mkdirSync(dir);
      } catch (e) {
      }
      let name: string = item.getSuggestedFileName();
      if (!name || name.length === 0) {
        name = Utils.guessFileName(item.getUrl(), '', '');
      }
      name = name.replace(/[\\/:*?"<>|]/g, '_');
      const path: string = dir + '/' + name;
      item.start(path);
      this.callbacks.onDownloadStart?.(item.getUrl(), path, name, item.getTotalBytes());
    } catch (e) {
    }
  }

  private onUaChanged(): void {
    if (this.attached && this.ua.length > 0) {
      try {
        this.controller.setCustomUserAgent(this.ua);
      } catch (e) {
      }
    }
  }

  private isInternal(url: string): boolean {
    return url.startsWith('http://') || url.startsWith('https://') || url.startsWith('file:')
      || url.startsWith('about:') || url.startsWith('data:') || url.startsWith('javascript:')
      || url.startsWith('blob:');
  }

  build() {
    Web({ src: 'about:blank', controller: this.controller })
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .userAgent(this.ua)
      .javaScriptAccess(this.jsEnabled)
      .domStorageAccess(true)
      .fileAccess(true)
      .imageAccess(!this.noImage)
      .mixedMode(MixedMode.All)
      .zoomAccess(true)
      .textZoomRatio(this.textZoom)
      .darkMode(this.night ? WebDarkMode.On : WebDarkMode.Off)
      .forceDarkAccess(this.night)
      .horizontalScrollBarAccess(false)
      .verticalScrollBarAccess(false)
      .visibility(this.active ? Visibility.Visible : Visibility.Hidden)
      .javaScriptProxy({
        name: 'ZormeGm',
        methodList: ['gmSet', 'gmDelete', 'clipboard', 'notify', 'openInTab',
          'download', 'xhr'],
        controller: this.controller,
        object: this.gmBridge
      })
      .onControllerAttached(() => {
        this.attached = true;
        this.gmBridge.setController(this.controller);
        if (this.ua.length > 0) {
          try {
            this.controller.setCustomUserAgent(this.ua);
          } catch (e) {
          }
        }
        try {
          this.controller.setDownloadDelegate(this.downloadDelegate);
        } catch (e) {
        }
        this.callbacks.onAttached?.(this.tabId);
      })
      .onPageBegin((event: OnPageBeginEvent) => {
        this.callbacks.onBegin?.(this.tabId, event.url);
      })
      .onPageEnd((event: OnPageEndEvent) => {
        let title: string = '';
        try {
          title = this.controller.getTitle();
        } catch (e) {
        }
        this.callbacks.onEnd?.(this.tabId, event.url, title);
      })
      .onProgressChange((event: OnProgressChangeEvent) => {
        this.callbacks.onProgress?.(this.tabId, event.newProgress);
      })
      .onTitleReceive((event: OnTitleReceiveEvent) => {
        this.callbacks.onTitle?.(this.tabId, event.title);
      })
      .onErrorReceive((event: OnErrorReceiveEvent) => {
        const main: boolean = event.request.isMainFrame();
        const code: number = event.error.getErrorCode();
        const info: string = event.error.getErrorInfo();
        if (!main) {
          return;
        }
        if (code === -3 || code === -10 || info.includes('ERR_ABORTED')
          || info.includes('ERR_UNKNOWN_URL_SCHEME')) {
          return;
        }
        this.callbacks.onError?.(this.tabId, code.toString(), info);
      })
      .onLoadIntercept((event: OnLoadInterceptEvent) => {
        const url: string = event.data.getRequestUrl();
        if (this.isInternal(url)) {
          return false;
        }
        return this.callbacks.onSpecialUrl?.(url) ?? false;
      })
      .onInterceptRequest((event: OnInterceptRequestEvent) => {
        const url: string = event.request.getRequestUrl();
        const blocked: boolean = this.callbacks.onIntercept?.(url,
          event.request.getRequestMethod(), event.request.isMainFrame()) ?? false;
        if (blocked) {
          const resp: WebResourceResponse = new WebResourceResponse();
          resp.setResponseMimeType('text/plain');
          resp.setResponseEncoding('utf-8');
          resp.setResponseData('');
          resp.setResponseCode(200);
          return resp;
        }
        return null;
      })
      .onAlert((event: OnAlertEvent) => {
        this.callbacks.onJsAlert?.(event.message, event.url, event.result);
        return true;
      })
      .onConfirm((event: OnConfirmEvent) => {
        this.callbacks.onJsConfirm?.(event.message, event.url, event.result);
        return true;
      })
      .onPrompt((event: OnPromptEvent) => {
        this.callbacks.onJsPrompt?.(event.message, event.url, event.value, event.result);
        return true;
      })
      .onShowFileSelector((event: OnShowFileSelectorEvent) => {
        try {
          const docPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(getContext(this));
          const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
          options.maxSelectNumber = 5;
          docPicker.select(options).then((uris: string[]) => {
            event.result.handleFileList(uris);
          }).catch(() => {
            event.result.handleFileList([]);
          });
        } catch (e) {
          event.result.handleFileList([]);
        }
        return true;
      })
      .onPermissionRequest((event: OnPermissionRequestEvent) => {
        event.request.deny();
      })
      .onRefreshAccessedHistory((event: OnRefreshAccessedHistoryEvent) => {
        this.callbacks.onState?.(this.tabId);
      })
  }
}
