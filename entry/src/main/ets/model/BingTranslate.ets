import { http } from '@kit.NetworkKit';

interface TransText {
  text: string;
  to: string;
}

interface DetectedLang {
  language: string;
}

interface TransBlock {
  translations?: TransText[];
  detectedLanguage?: DetectedLang;
}

/** 一批翻译的结果 */
export class TransResult {
  ok: boolean = false;
  /** 与输入等长的译文数组；失败项为空串 */
  texts: string[] = [];
  /** 必应识别出的源语言，如 en / ja */
  detected: string = '';
  error: string = '';
}

/**
 * 必应翻译（Bing Translator）客户端。
 *
 * 流程与必应翻译网页一致：
 *   1. GET https://cn.bing.com/translator 取页面内的 IG 与 abuse-prevention token/key
 *   2. POST https://cn.bing.com/ttranslatev3?isVertical=1&&IG=…&IID=translator.5023&SFX=2
 *      body: fromLang=auto-detect&to=…&tone=Casual&text=…&token=…&key=…
 *
 * token 有效期约 1 小时，这里缓存 30 分钟后主动刷新；遇到 400/205 会强制刷新重试一次。
 * 不需要 AppKey，也不需要 Cookie。
 */
export class BingTranslate {
  /** 可选的翻译目标语言 */
  static readonly LANGS: string[] = ['简体中文', '繁体中文', '英语', '日语', '韩语',
    '法语', '德语', '俄语', '西班牙语', '葡萄牙语', '意大利语', '阿拉伯语'];
  /** 与 LANGS 一一对应的必应语言代码 */
  static readonly CODES: string[] = ['zh-Hans', 'zh-Hant', 'en', 'ja', 'ko',
    'fr', 'de', 'ru', 'es', 'pt', 'it', 'ar'];

  private static readonly UA: string = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    + 'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
  private static readonly HOME: string = 'https://cn.bing.com/translator';
  private static readonly API: string = 'https://cn.bing.com/ttranslatev3';

  private static ig: string = '';
  private static token: string = '';
  private static key: string = '';
  private static stamp: number = 0;
  private static lastError: string = '';

  static indexOf(code: string): number {
    const i: number = BingTranslate.CODES.indexOf(code);
    return i < 0 ? 0 : i;
  }

  static nameOf(code: string): string {
    return BingTranslate.LANGS[BingTranslate.indexOf(code)];
  }

  static codeOf(index: number): string {
    if (index < 0 || index >= BingTranslate.CODES.length) {
      return 'zh-Hans';
    }
    return BingTranslate.CODES[index];
  }

  /** 最近一次失败原因 */
  static error(): string {
    return BingTranslate.lastError;
  }

  /**
   * 翻译一批文本（建议 ≤ 40 段）。
   * 先按换行拼接成一次请求；若返回行数与输入不一致（长句被合并/拆分），
   * 就把这一批二分后递归重试，直到对齐或降到单条，避免逐条请求带来的大量往返。
   */
  static async translateBatch(texts: string[], to: string): Promise<TransResult> {
    const out: TransResult = new TransResult();
    if (texts.length === 0) {
      out.ok = true;
      return out;
    }
    if (!(await BingTranslate.ensure(false))) {
      out.error = BingTranslate.lastError.length > 0 ? BingTranslate.lastError : '无法连接必应翻译';
      return out;
    }
    const parts: string[] = await BingTranslate.pieces(texts, to);
    if (parts.length !== texts.length) {
      out.error = '翻译结果未对齐';
      return out;
    }
    out.texts = parts;
    out.ok = true;
    return out;
  }

  /** 把一组文本翻译并对齐到相同长度 */
  private static async pieces(texts: string[], to: string): Promise<string[]> {
    let text: string | null = await BingTranslate.post(texts.join('\n'), to);
    if (text === null) {
      // token 可能过期，强制刷新后重试一次
      if (await BingTranslate.ensure(true)) {
        text = await BingTranslate.post(texts.join('\n'), to);
      }
    }
    // 请求本身失败：不再二分放大请求量，直接保留原文
    if (text === null || text.length === 0) {
      const blank: string[] = [];
      for (let i = 0; i < texts.length; i++) {
        blank.push('');
      }
      return blank;
    }
    const parts: string[] = text.split('\n');
    if (parts.length === texts.length) {
      const out: string[] = [];
      for (let i = 0; i < parts.length; i++) {
        out.push(parts[i].trim());
      }
      return out;
    }
    if (texts.length === 1) {
      const one: string[] = [];
      one.push(text.split('\n').join(' ').trim());
      return one;
    }
    const mid: number = Math.floor(texts.length / 2);
    const left: string[] = await BingTranslate.pieces(texts.slice(0, mid), to);
    const right: string[] = await BingTranslate.pieces(texts.slice(mid), to);
    const merged: string[] = [];
    for (let i = 0; i < left.length; i++) {
      merged.push(left[i]);
    }
    for (let i = 0; i < right.length; i++) {
      merged.push(right[i]);
    }
    return merged;
  }

  /** 探测源语言（翻译一小段即可），返回语言代码；失败返回空串 */
  static async detect(text: string, to: string): Promise<string> {
    if (!(await BingTranslate.ensure(false))) {
      return '';
    }
    const req: http.HttpRequest = http.createHttp();
    try {
      const body: string = 'fromLang=auto-detect&to=' + BingTranslate.enc(to)
        + '&tone=Casual&text=' + BingTranslate.enc(text)
        + '&token=' + BingTranslate.enc(BingTranslate.token) + '&key=' + BingTranslate.key;
      const resp: http.HttpResponse = await req.request(BingTranslate.apiUrl(), {
        method: http.RequestMethod.POST,
        header: BingTranslate.headers(),
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 30000
      });
      if (resp.responseCode !== 200) {
        return '';
      }
      const blocks: TransBlock[] = JSON.parse(resp.result as string) as TransBlock[];
      if (blocks.length === 0) {
        return '';
      }
      const d: DetectedLang | undefined = blocks[0].detectedLanguage;
      return d !== undefined && d.language !== undefined ? d.language : '';
    } catch (e) {
      return '';
    } finally {
      req.destroy();
    }
  }

  private static apiUrl(): string {
    return BingTranslate.API + '?isVertical=1&&IG=' + BingTranslate.ig
      + '&IID=translator.5023&SFX=2';
  }

  private static headers(): Record<string, string> {
    const h: Record<string, string> = {};
    h['Content-Type'] = 'application/x-www-form-urlencoded';
    h['User-Agent'] = BingTranslate.UA;
    h['Referer'] = BingTranslate.HOME;
    h['Origin'] = 'https://cn.bing.com';
    h['Accept'] = '*/*';
    h['Accept-Language'] = 'zh-CN,zh;q=0.9';
    return h;
  }

  /** 取 IG 与 token（缓存 30 分钟） */
  private static async ensure(force: boolean): Promise<boolean> {
    const now: number = Date.now();
    if (!force && BingTranslate.ig.length > 0 && BingTranslate.token.length > 0
      && now - BingTranslate.stamp < 1800000) {
      return true;
    }
    const req: http.HttpRequest = http.createHttp();
    try {
      const resp: http.HttpResponse = await req.request(BingTranslate.HOME, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': BingTranslate.UA,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8'
        },
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 25000
      });
      if (resp.responseCode !== 200) {
        BingTranslate.lastError = '必应翻译页面无法访问';
        return false;
      }
      const html: string = resp.result as string;
      const igm: RegExpExecArray | null = /IG:"([0-9A-Fa-f]{16,40})"/.exec(html);
      const pm: RegExpExecArray | null =
        /params_AbusePreventionHelper\s*=\s*\[(\d+),\s*"([^"]+)"/.exec(html);
      if (igm === null || pm === null) {
        BingTranslate.lastError = '必应翻译接口已变更';
        return false;
      }
      BingTranslate.ig = igm[1];
      BingTranslate.key = pm[1];
      BingTranslate.token = pm[2];
      BingTranslate.stamp = now;
      BingTranslate.lastError = '';
      return true;
    } catch (e) {
      BingTranslate.lastError = '网络不可用，无法连接必应翻译';
      return false;
    } finally {
      req.destroy();
    }
  }

  /** 发送一次翻译请求；成功返回译文（可能为空串），请求失败返回 null */
  private static async post(text: string, to: string): Promise<string | null> {
    if (BingTranslate.ig.length === 0 || BingTranslate.token.length === 0) {
      return null;
    }
    const req: http.HttpRequest = http.createHttp();
    try {
      const body: string = 'fromLang=auto-detect&to=' + BingTranslate.enc(to)
        + '&tone=Casual&text=' + BingTranslate.enc(text)
        + '&token=' + BingTranslate.enc(BingTranslate.token) + '&key=' + BingTranslate.key;
      const resp: http.HttpResponse = await req.request(BingTranslate.apiUrl(), {
        method: http.RequestMethod.POST,
        header: BingTranslate.headers(),
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 40000
      });
      if (resp.responseCode !== 200) {
        return null;
      }
      const raw: string = resp.result as string;
      const blocks: TransBlock[] = JSON.parse(raw) as TransBlock[];
      if (blocks.length === 0) {
        return '';
      }
      const tr: TransText[] | undefined = blocks[0].translations;
      if (tr === undefined || tr.length === 0) {
        return '';
      }
      const val: string = tr[0].text;
      return val !== undefined && val !== null ? val : '';
    } catch (e) {
      return null;
    } finally {
      req.destroy();
    }
  }

  /** form-urlencoded 编码（encodeURIComponent 不处理 !*'() ） */
  private static enc(s: string): string {
    return encodeURIComponent(s).replace(/[!*'()]/g, (c: string): string => {
      return '%' + c.charCodeAt(0).toString(16).toUpperCase();
    });
  }
}
