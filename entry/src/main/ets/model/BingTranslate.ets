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
  /** 备用站点：部分地区 cn.bing.com 会跳转或返回不完整页面 */
  private static readonly HOSTS: string[] = ['https://cn.bing.com', 'https://www.bing.com'];

  private static host: string = 'https://cn.bing.com';
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
    let filled: number = 0;
    for (let i = 0; i < parts.length; i++) {
      if (parts[i].length > 0) {
        filled++;
      }
    }
    if (filled === 0) {
      out.error = BingTranslate.lastError.length > 0 ? BingTranslate.lastError : '必应翻译没有返回结果';
      return out;
    }
    out.texts = parts;
    out.ok = true;
    return out;
  }

  /** 把一组文本翻译并对齐到相同长度 */
  private static async pieces(texts: string[], to: string): Promise<string[]> {
    if (texts.length === 1) {
      return await BingTranslate.each(texts, to);
    }
    // 必应会把换行合并成一段，导致按 \n 对齐失败；
    // 改用不会被翻译改写的分隔标记 @@@，实测 20 段仍能一一对应。
    let joiner: string = '\n@@@\n';
    for (let i = 0; i < texts.length; i++) {
      if (texts[i].indexOf('@@@') >= 0) {
        joiner = '';
        break;
      }
    }
    if (joiner.length === 0) {
      return await BingTranslate.each(texts, to);
    }
    let text: string | null = await BingTranslate.post(texts.join(joiner), to);
    if (text === null) {
      // token 可能过期，强制刷新后重试一次
      if (await BingTranslate.ensure(true)) {
        text = await BingTranslate.post(texts.join(joiner), to);
      }
    }
    if (text !== null && text.length > 0) {
      const parts: string[] = text.split('@@@');
      if (parts.length === texts.length) {
        const out: string[] = [];
        for (let i = 0; i < parts.length; i++) {
          out.push(parts[i].split('\n').join(' ').trim());
        }
        return out;
      }
      // 个别模型会把标记吃掉但保留换行，再按行试一次
      const lines: string[] = text.split('\n');
      if (lines.length === texts.length) {
        const out2: string[] = [];
        for (let i = 0; i < lines.length; i++) {
          out2.push(lines[i].trim());
        }
        return out2;
      }
    }
    // 仍对不上：退化为逐条翻译，并发 3 条，
    // 避免旧版“二分递归”在整批合并时把请求量翻倍放大。
    return await BingTranslate.each(texts, to);
  }

  /** 逐条翻译，最多 3 条并发；连续失败 6 次即熔断，避免被限流后空转 */
  private static async each(texts: string[], to: string): Promise<string[]> {
    const total: number = texts.length;
    const out: string[] = [];
    for (let i = 0; i < total; i++) {
      out.push('');
    }
    let cursor: number = 0;
    let fails: number = 0;
    const worker = async (): Promise<void> => {
      while (cursor < total) {
        if (fails >= 6) {
          return;
        }
        const i: number = cursor;
        cursor++;
        let t: string | null = await BingTranslate.post(texts[i], to);
        if (t === null) {
          await BingTranslate.wait(260);
          if (await BingTranslate.ensure(true)) {
            t = await BingTranslate.post(texts[i], to);
          }
        }
        if (t === null) {
          fails++;
          continue;
        }
        out[i] = t.split('\n').join(' ').trim();
      }
    };
    const jobs: Promise<void>[] = [];
    const n: number = total < 3 ? total : 3;
    for (let k = 0; k < n; k++) {
      jobs.push(worker());
    }
    await Promise.all(jobs);
    return out;
  }

  private static wait(ms: number): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(() => {
        resolve();
      }, ms);
    });
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
    return BingTranslate.host + '/ttranslatev3?isVertical=1&&IG=' + BingTranslate.ig
      + '&IID=translator.5023&SFX=2';
  }

  private static homeUrl(): string {
    return BingTranslate.host + '/translator';
  }

  private static headers(): Record<string, string> {
    const h: Record<string, string> = {};
    h['Content-Type'] = 'application/x-www-form-urlencoded';
    h['User-Agent'] = BingTranslate.UA;
    h['Referer'] = BingTranslate.homeUrl();
    h['Origin'] = BingTranslate.host;
    h['Accept'] = '*/*';
    h['Accept-Language'] = 'zh-CN,zh;q=0.9';
    return h;
  }

  /** 取 IG 与 token（缓存 30 分钟）；主站失败时自动切到备用站点 */
  private static async ensure(force: boolean): Promise<boolean> {
    const now: number = Date.now();
    if (!force && BingTranslate.ig.length > 0 && BingTranslate.token.length > 0
      && now - BingTranslate.stamp < 1800000) {
      return true;
    }
    const start: number = BingTranslate.indexOfHost(BingTranslate.host);
    for (let i = 0; i < BingTranslate.HOSTS.length; i++) {
      const candidate: string = BingTranslate.HOSTS[(start + i) % BingTranslate.HOSTS.length];
      if (await BingTranslate.fetchToken(candidate, now)) {
        BingTranslate.host = candidate;
        return true;
      }
    }
    return false;
  }

  private static indexOfHost(host: string): number {
    const i: number = BingTranslate.HOSTS.indexOf(host);
    return i < 0 ? 0 : i;
  }

  /** 从指定站点的翻译页里抠出 IG 与 abuse-prevention token/key */
  private static async fetchToken(host: string, now: number): Promise<boolean> {
    const req: http.HttpRequest = http.createHttp();
    try {
      const resp: http.HttpResponse = await req.request(host + '/translator', {
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
        BingTranslate.lastError = '必应翻译页面无法访问（HTTP ' + resp.responseCode.toString() + '）';
        return false;
      }
      const html: string = resp.result as string;
      if (html === undefined || html === null || html.length === 0) {
        BingTranslate.lastError = '必应翻译页面返回为空';
        return false;
      }
      // IG 在不同站点/灰度版本里格式略有差异，放宽匹配
      const igm: RegExpExecArray | null = /IG\s*:\s*"([0-9A-Za-z_\-]{6,80})"/.exec(html);
      const pm: RegExpExecArray | null =
        /params_AbusePreventionHelper\s*=\s*\[\s*(\d+)\s*,\s*"([^"]+)"/.exec(html);
      if (igm === null || pm === null) {
        BingTranslate.lastError = '必应翻译接口已变更（未找到 IG/token）';
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
      // token 过期/被限流时返回 400/403/429，交给上层刷新 token 重试
      if (resp.responseCode === 400 || resp.responseCode === 403
        || resp.responseCode === 429 || resp.responseCode === 205) {
        BingTranslate.lastError = '必应翻译拒绝请求（HTTP ' + resp.responseCode.toString() + '）';
        return null;
      }
      if (resp.responseCode !== 200) {
        BingTranslate.lastError = '必应翻译请求失败（HTTP ' + resp.responseCode.toString() + '）';
        return null;
      }
      const raw: string = resp.result as string;
      if (raw === undefined || raw === null || raw.length === 0) {
        return '';
      }
      const blocks: TransBlock[] = JSON.parse(raw) as TransBlock[];
      if (!Array.isArray(blocks) || blocks.length === 0) {
        // 返回的是错误对象而不是数组：多半是 token 失效
        BingTranslate.lastError = '必应翻译返回了错误信息';
        return null;
      }
      const tr: TransText[] | undefined = blocks[0].translations;
      if (tr === undefined || tr.length === 0) {
        return '';
      }
      const val: string = tr[0].text;
      return val !== undefined && val !== null ? val : '';
    } catch (e) {
      BingTranslate.lastError = '必应翻译请求异常';
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
