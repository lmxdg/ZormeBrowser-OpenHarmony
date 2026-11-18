import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { webview } from '@kit.ArkWeb';
import { Userscript } from './Userscript';

/**
 * 油猴脚本存储与注入器：
 * 脚本列表持久化到 preferences（userscripts_json），GM_* 数据持久化到 userscript_data_json。
 */
export class UserscriptStore {
  private static store: preferences.Preferences | null = null;
  private static scripts: Userscript[] = [];
  private static gmData: Map<string, Map<string, string>> = new Map();

  private static readonly KEY_SCRIPTS: string = 'userscripts_json';
  private static readonly KEY_GM: string = 'userscript_data_json';

  static async init(ctx: common.UIAbilityContext): Promise<void> {
    UserscriptStore.store = await preferences.getPreferences(ctx, 'zorme_data');
    UserscriptStore.scripts = UserscriptStore.readScripts();
    const text: string = (StoreGm.get(UserscriptStore.store, UserscriptStore.KEY_GM)) as string;
    try {
      const obj: Record<string, Record<string, string>> =
        JSON.parse(text.length > 0 ? text : '{}') as Record<string, Record<string, string>>;
      UserscriptStore.gmData = new Map();
      const keys: string[] = Object.keys(obj);
      for (const k of keys) {
        const inner: Record<string, string> = obj[k];
        const m: Map<string, string> = new Map();
        const ikeys: string[] = Object.keys(inner);
        for (const ik of ikeys) {
          m.set(ik, inner[ik]);
        }
        UserscriptStore.gmData.set(k, m);
      }
    } catch (e) {
      UserscriptStore.gmData = new Map();
    }
  }

  private static readScripts(): Userscript[] {
    if (UserscriptStore.store === null) {
      return [];
    }
    const text: string = UserscriptStore.store.getSync(UserscriptStore.KEY_SCRIPTS, '[]') as string;
    try {
      const arr: Record<string, Object>[] = JSON.parse(text) as Record<string, Object>[];
      const out: Userscript[] = [];
      for (const o of arr) {
        const s: Userscript = new Userscript();
        s.id = o['id'] as string;
        s.name = o['name'] as string;
        s.namespace = o['namespace'] as string;
        s.version = o['version'] as string;
        s.description = o['description'] as string;
        s.author = o['author'] as string;
        s.runAt = o['runAt'] as string;
        s.sourceUrl = o['sourceUrl'] as string;
        s.code = o['code'] as string;
        s.enabled = o['enabled'] as boolean;
        s.created = o['created'] as number;
        s.matches = o['matches'] as string[];
        s.includes = o['includes'] as string[];
        s.excludes = o['excludes'] as string[];
        if (s.runAt !== 'document-start' && s.runAt !== 'document-idle') {
          s.runAt = 'document-end';
        }
        out.push(s);
      }
      return out;
    } catch (e) {
      return [];
    }
  }

  private static persist(): void {
    if (UserscriptStore.store === null) {
      return;
    }
    const arr: Record<string, Object>[] = [];
    for (const s of UserscriptStore.scripts) {
      const o: Record<string, Object> = {
        'id': s.id,
        'name': s.name,
        'namespace': s.namespace,
        'version': s.version,
        'description': s.description,
        'author': s.author,
        'runAt': s.runAt,
        'sourceUrl': s.sourceUrl,
        'code': s.code,
        'enabled': s.enabled,
        'created': s.created,
        'matches': s.matches,
        'includes': s.includes,
        'excludes': s.excludes
      } as Record<string, Object>;
      arr.push(o);
    }
    UserscriptStore.store.putSync(UserscriptStore.KEY_SCRIPTS, JSON.stringify(arr));
    UserscriptStore.store.flush().then(() => {
    }).catch(() => {
    });
  }

  static all(): Userscript[] {
    return UserscriptStore.scripts.slice();
  }

  static enabledCount(): number {
    let n: number = 0;
    for (const s of UserscriptStore.scripts) {
      if (s.enabled) {
        n++;
      }
    }
    return n;
  }

  static add(code: string, sourceUrl: string): Userscript {
    const s: Userscript = Userscript.parse(code);
    s.id = 'u' + Date.now().toString() + Math.floor(Math.random() * 10000).toString();
    s.sourceUrl = sourceUrl;
    s.enabled = true;
    s.created = Date.now();
    UserscriptStore.scripts.push(s);
    UserscriptStore.persist();
    return s;
  }

  static remove(id: string): void {
    const target: Userscript | undefined =
      UserscriptStore.scripts.find((s: Userscript) => s.id === id);
    UserscriptStore.scripts = UserscriptStore.scripts.filter((s: Userscript) => s.id !== id);
    if (target) {
      UserscriptStore.gmData.delete(target.gmKey());
      UserscriptStore.persistGm();
    }
    UserscriptStore.persist();
  }

  static setEnabled(id: string, enabled: boolean): void {
    const idx: number = UserscriptStore.scripts.findIndex((s: Userscript) => s.id === id);
    if (idx >= 0) {
      UserscriptStore.scripts[idx].enabled = enabled;
      UserscriptStore.persist();
    }
  }

  /** 命中 URL 且启用的脚本（按安装顺序） */
  static enabledFor(url: string): Userscript[] {
    const out: Userscript[] = [];
    if (url.length === 0 || !url.startsWith('http')) {
      return out;
    }
    for (const s of UserscriptStore.scripts) {
      if (s.enabled && s.matchesUrl(url)) {
        out.push(s);
      }
    }
    return out;
  }

  // ---------------- GM_* 数据 ----------------

  static gmSet(ns: string, key: string, value: string): void {
    let m: Map<string, string> | undefined = UserscriptStore.gmData.get(ns);
    if (!m) {
      m = new Map();
      UserscriptStore.gmData.set(ns, m);
    }
    m.set(key, value);
    UserscriptStore.persistGm();
  }

  static gmDelete(ns: string, key: string): void {
    const m: Map<string, string> | undefined = UserscriptStore.gmData.get(ns);
    if (m) {
      m.delete(key);
      UserscriptStore.persistGm();
    }
  }

  static gmDataJson(ns: string): string {
    const m: Map<string, string> | undefined = UserscriptStore.gmData.get(ns);
    const obj: Record<string, string> = {};
    if (m) {
      m.forEach((v: string, k: string) => {
        obj[k] = v;
      });
    }
    return JSON.stringify(obj);
  }

  private static persistGm(): void {
    if (UserscriptStore.store === null) {
      return;
    }
    const obj: Record<string, Record<string, string>> = {};
    UserscriptStore.gmData.forEach((m: Map<string, string>, k: string) => {
      const inner: Record<string, string> = {};
      m.forEach((v: string, ik: string) => {
        inner[ik] = v;
      });
      obj[k] = inner;
    });
    UserscriptStore.store.putSync(UserscriptStore.KEY_GM, JSON.stringify(obj));
    UserscriptStore.store.flush().then(() => {
    }).catch(() => {
    });
  }
}

/** preferences 读取的局部辅助（避免与 Store 类耦合） */
class StoreGm {
  static get(store: preferences.Preferences, key: string): string {
    return store.getSync(key, '{}') as string;
  }
}

/**
 * 注入器：把启用且匹配的脚本包装 GM 垫片后通过 runJavaScript 注入。
 * 同时提供 GM_xmlhttpRequest 的原生 http 实现（供 GmBridge 调用）。
 */
export class UserscriptInjector {
  /** JS 字符串转义（用于单引号字面量） */
  static escapeJs(s: string): string {
    if (s === null || s === undefined) {
      return '';
    }
    let out: string = '';
    for (let i = 0; i < s.length; i++) {
      const c: string = s.charAt(i);
      if (c === '\\') {
        out += '\\\\';
      } else if (c === '\'') {
        out += '\\\'';
      } else if (c === '"') {
        out += '\\"';
      } else if (c === '\n') {
        out += '\\n';
      } else if (c === '\r') {
        out += '\\r';
      } else if (c === '\t') {
        out += '\\t';
      } else if (c === '<') {
        out += '\\u003c';
      } else {
        out += c;
      }
    }
    return out;
  }

  /** 构建单个脚本的完整注入代码（GM 垫片 + 用户代码） */
  static build(s: Userscript): string {
    let sb: string = '(function(){\ntry{\n';
    sb += 'var __gmData=' + UserscriptStore.gmDataJson(s.gmKey()) + ';\n';
    sb += 'var __gmNs=\'' + UserscriptInjector.escapeJs(s.gmKey()) + '\';\n';
    sb += 'var GM_info={script:{name:\'' + UserscriptInjector.escapeJs(s.name)
      + '\',version:\'' + UserscriptInjector.escapeJs(s.version)
      + '\',namespace:\'' + UserscriptInjector.escapeJs(s.namespace)
      + '\',description:\'' + UserscriptInjector.escapeJs(s.description)
      + '\'},version:\'1.0\',scriptHandler:\'Zorme Browser\'};\n';
    sb += 'function GM_getValue(k,d){var v=__gmData[String(k)];return v===undefined?d:v;}\n';
    sb += 'function GM_setValue(k,v){__gmData[String(k)]=String(v);try{ZormeGm.gmSet(__gmNs,String(k),String(v))}catch(e){}}\n';
    sb += 'function GM_deleteValue(k){delete __gmData[String(k)];try{ZormeGm.gmDelete(__gmNs,String(k))}catch(e){}}\n';
    sb += 'function GM_listValues(){return Object.keys(__gmData);}\n';
    sb += 'function GM_addStyle(css){try{var st=document.createElement("style");st.textContent=css;(document.head||document.documentElement).appendChild(st)}catch(e){}}\n';
    sb += 'function GM_setClipboard(t){try{ZormeGm.clipboard(String(t))}catch(e){}}\n';
    sb += 'function GM_notification(t){try{ZormeGm.notify(typeof t==="string"?t:(t&&t.text)||"油猴通知")}catch(e){}}\n';
    sb += 'function GM_xmlhttpRequest(d){var cb="c"+Date.now()+Math.floor(Math.random()*1e6);'
      + 'if(!window.__zormeGmCbs)window.__zormeGmCbs={};window.__zormeGmCbs[cb]=d||{};'
      + 'var p={method:(d&&d.method)||"GET",url:(d&&d.url)||"",headers:(d&&d.headers)||{},'
      + 'data:(d&&d.data)?String(d.data):"",timeout:(d&&d.timeout)||30000};'
      + 'try{ZormeGm.xhr(cb,JSON.stringify(p))}catch(e){if(d&&d.onerror)setTimeout(function(){d.onerror({error:String(e),details:{}})},0)}'
      + 'return{abort:function(){}};}\n';
    sb += 'window.__zormeGmXhrDone=function(cb,ok,payload){var d=window.__zormeGmCbs&&window.__zormeGmCbs[cb];'
      + 'if(!d)return;delete window.__zormeGmCbs[cb];'
      + 'try{var r=JSON.parse(payload);if(ok&&d.onload)d.onload(r);else if(!ok&&d.onerror)d.onerror(r);}catch(e){}};\n';
    sb += 'var unsafeWindow=window;\n';
    sb += 'var GM={info:GM_info,getValue:GM_getValue,setValue:GM_setValue,deleteValue:GM_deleteValue,'
      + 'listValues:GM_listValues,addStyle:GM_addStyle,setClipboard:GM_setClipboard,'
      + 'notification:GM_notification,openInTab:GM_openInTab,download:GM_download,'
      + 'xmlHttpRequest:GM_xmlhttpRequest};\n';
    sb += 'function GM_openInTab(u){try{ZormeGm.openInTab(String(u))}catch(e){}}\n';
    sb += 'function GM_download(u){try{ZormeGm.download(String(u))}catch(e){}}\n';
    sb += 'window.GM_info=GM_info;window.GM_getValue=GM_getValue;window.GM_setValue=GM_setValue;'
      + 'window.GM_deleteValue=GM_deleteValue;window.GM_listValues=GM_listValues;'
      + 'window.GM_addStyle=GM_addStyle;window.GM_setClipboard=GM_setClipboard;'
      + 'window.GM_notification=GM_notification;window.GM_openInTab=GM_openInTab;'
      + 'window.GM_download=GM_download;window.GM_xmlhttpRequest=GM_xmlhttpRequest;'
      + 'window.unsafeWindow=window;window.GM=GM;\n';
    sb += s.code;
    sb += '\n}catch(e){console.error(\'[Zorme油猴] ' + UserscriptInjector.escapeJs(s.name) + ":',e)}\n})();\n";
    return sb;
  }

  /** 按时机注入匹配当前 URL 的脚本 */
  static inject(ctrl: webview.WebviewController, url: string, atStart: boolean): void {
    if (url.length === 0 || !url.startsWith('http')) {
      return;
    }
    const list: Userscript[] = UserscriptStore.enabledFor(url);
    if (list.length === 0) {
      return;
    }
    let js: string = '';
    for (const s of list) {
      const isStart: boolean = s.runAt === 'document-start';
      if (atStart !== isStart) {
        continue;
      }
      js += UserscriptInjector.build(s);
    }
    if (js.trim().length === 0) {
      return;
    }
    try {
      ctrl.runJavaScript(js);
    } catch (e) {
    }
  }

  /** GM_xmlhttpRequest 原生实现：http 请求 + runJavaScript 回调 */
  static handleXhr(ctrl: webview.WebviewController, cbId: string, detailsJson: string): void {
    let method: string = 'GET';
    let url: string = '';
    let data: string = '';
    let extraHeaders: Record<string, string> = {};
    try {
      const d: Record<string, Object> = JSON.parse(detailsJson) as Record<string, Object>;
      method = (d['method'] as string) || 'GET';
      url = (d['url'] as string) || '';
      data = (d['data'] as string) || '';
      const h: Record<string, string> = (d['headers'] as Record<string, string>) || {};
      extraHeaders = h;
    } catch (e) {
    }
    const req: http.HttpRequest = http.createHttp();
    req.request(url, {
      method: method === 'POST' ? http.RequestMethod.POST
        : method === 'PUT' ? http.RequestMethod.PUT
          : method === 'HEAD' ? http.RequestMethod.HEAD
            : http.RequestMethod.GET,
      header: extraHeaders,
      extraData: (method !== 'GET' && method !== 'HEAD' && data.length > 0) ? data : undefined,
      connectTimeout: 30000,
      readTimeout: 30000,
      expectDataType: http.HttpDataType.STRING
    }).then((resp: http.HttpResponse) => {
      const ok: boolean = resp.responseCode >= 200 && resp.responseCode < 400;
      const payload: Record<string, Object> = {
        'status': resp.responseCode,
        'statusText': ok ? 'OK' : 'Error',
        'responseText': typeof resp.result === 'string' ? resp.result : String(resp.result),
        'response': typeof resp.result === 'string' ? resp.result : String(resp.result),
        'responseHeaders': JSON.stringify(resp.header),
        'finalUrl': url,
        'readyState': 4
      } as Record<string, Object>;
      const js: string = 'window.__zormeGmXhrDone&&window.__zormeGmXhrDone(\''
        + UserscriptInjector.escapeJs(cbId) + '\',' + ok + ',\''
        + UserscriptInjector.escapeJs(JSON.stringify(payload)) + '\');';
      try {
        ctrl.runJavaScript(js);
      } catch (e) {
      }
      req.destroy();
    }).catch((err: Error) => {
      const payload: Record<string, Object> = {
        'error': String(err.message || err),
        'details': '' as Object
      } as Record<string, Object>;
      const js: string = 'window.__zormeGmXhrDone&&window.__zormeGmXhrDone(\''
        + UserscriptInjector.escapeJs(cbId) + '\',false,\''
        + UserscriptInjector.escapeJs(JSON.stringify(payload)) + '\');';
      try {
        ctrl.runJavaScript(js);
      } catch (e) {
      }
      req.destroy();
    });
  }
}

/**
 * 注册到 Web 的 GM 桥（javaScriptProxy 名 ZormeGm）：
 * GM_setValue/GM_deleteValue 的持久化、剪贴板、通知、跨标签页打开、GM_xmlhttpRequest。
 * UI 侧通过静态回调接管剪贴板/通知/新标签页动作。
 */
export class GmBridge {
  static onClipboard: (text: string) => void = (_t: string) => {
  };
  static onNotify: (text: string) => void = (_t: string) => {
  };
  static onOpenUrl: (url: string) => void = (_u: string) => {
  };

  private ctrl: webview.WebviewController | null = null;

  setController(c: webview.WebviewController): void {
    this.ctrl = c;
  }

  controller(): webview.WebviewController | null {
    return this.ctrl;
  }

  gmSet(ns: string, key: string, value: string): void {
    UserscriptStore.gmSet(ns, key, value);
  }

  gmDelete(ns: string, key: string): void {
    UserscriptStore.gmDelete(ns, key);
  }

  clipboard(text: string): void {
    GmBridge.onClipboard(text);
  }

  notify(text: string): void {
    GmBridge.onNotify(text);
  }

  openInTab(url: string): void {
    GmBridge.onOpenUrl(url);
  }

  download(url: string): void {
    GmBridge.onOpenUrl(url);
  }

  xhr(cbId: string, detailsJson: string): void {
    if (this.ctrl !== null) {
      UserscriptInjector.handleXhr(this.ctrl, cbId, detailsJson);
    }
  }
}
