/** 油猴（userscript）脚本模型：元数据解析与 URL 匹配 */
export class Userscript {
  id: string = '';
  name: string = '';
  namespace: string = '';
  version: string = '';
  description: string = '';
  author: string = '';
  runAt: string = 'document-end';
  sourceUrl: string = '';
  code: string = '';
  enabled: boolean = true;
  created: number = 0;
  matches: string[] = [];
  includes: string[] = [];
  excludes: string[] = [];

  /** GM_* 数据的存储分区键 */
  gmKey(): string {
    const ns: string = this.namespace.length > 0 ? this.namespace : 'zorme';
    return ns + '|' + this.name;
  }

  static parse(code: string): Userscript {
    const s: Userscript = new Userscript();
    s.code = code ? code : '';
    const head: string | null = Userscript.metaBlock(s.code);
    if (head !== null) {
      const lines: string[] = head.split('\n');
      for (let i = 0; i < lines.length; i++) {
        const raw: string = lines[i].trim();
        if (!raw.startsWith('@')) {
          continue;
        }
        const sp: number = raw.indexOf(' ');
        if (sp < 0) {
          continue;
        }
        const key: string = raw.substring(1, sp);
        const value: string = raw.substring(sp + 1).trim();
        if (key === 'name') {
          s.name = value;
        } else if (key === 'namespace') {
          s.namespace = value;
        } else if (key === 'version') {
          s.version = value;
        } else if (key === 'description') {
          s.description = value;
        } else if (key === 'author') {
          s.author = value;
        } else if (key === 'run-at') {
          s.runAt = value;
        } else if (key === 'match') {
          s.matches.push(value);
        } else if (key === 'include') {
          s.includes.push(value);
        } else if (key === 'exclude') {
          s.excludes.push(value);
        }
      }
    }
    if (s.name.length === 0) {
      s.name = Userscript.guessName(s.code, s.sourceUrl);
    }
    if (s.runAt !== 'document-start' && s.runAt !== 'document-idle') {
      s.runAt = 'document-end';
    }
    return s;
  }

  private static metaBlock(code: string): string | null {
    const start: number = code.indexOf('==UserScript==');
    if (start < 0) {
      return null;
    }
    let end: number = code.indexOf('==/UserScript==', start);
    if (end < 0) {
      end = Math.min(code.length, start + 4000);
    }
    const block: string = code.substring(start, end);
    const lines: string[] = block.split('\n');
    const out: string[] = [];
    for (let i = 0; i < lines.length; i++) {
      const l: string = lines[i].replace(/^\s*(\/\/|\/\*|\*)\s?/, '');
      out.push(l);
    }
    return out.join('\n');
  }

  private static guessName(code: string, sourceUrl: string): string {
    if (sourceUrl.length > 0) {
      let u: string = sourceUrl;
      const slash: number = u.lastIndexOf('/');
      if (slash >= 0) {
        u = u.substring(slash + 1);
      }
      if (u.toLowerCase().endsWith('.user.js')) {
        u = u.substring(0, u.length - 8);
      }
      if (u.length > 0) {
        return u;
      }
    }
    return '未命名脚本';
  }

  /** 是否对该 URL 生效（@match + @include 命中且未被 @exclude 排除） */
  matchesUrl(url: string): boolean {
    if (url.length === 0 || !url.startsWith('http')) {
      return false;
    }
    for (let i = 0; i < this.excludes.length; i++) {
      if (Userscript.includeMatch(url, this.excludes[i])) {
        return false;
      }
    }
    for (let i = 0; i < this.matches.length; i++) {
      if (Userscript.matchPattern(url, this.matches[i])) {
        return true;
      }
    }
    for (let i = 0; i < this.includes.length; i++) {
      if (Userscript.includeMatch(url, this.includes[i])) {
        return true;
      }
    }
    return false;
  }

  /** Chrome 扩展风格的 @match 规则 */
  static matchPattern(url: string, pattern: string): boolean {
    const p: string = pattern.trim();
    if (p === '<all_urls>') {
      return url.startsWith('http://') || url.startsWith('https://')
        || url.startsWith('file://') || url.startsWith('ftp://');
    }
    const schemeEnd: number = p.indexOf('://');
    if (schemeEnd < 0) {
      return false;
    }
    const scheme: string = Userscript.urlScheme(url);
    const host: string = Userscript.urlHost(url);
    const full: string = Userscript.urlPathFull(url);

    const pScheme: string = p.substring(0, schemeEnd).toLowerCase();
    let rest: string = p.substring(schemeEnd + 3);
    if (!Userscript.schemeMatches(pScheme, scheme)) {
      return false;
    }
    const pathStart: number = rest.indexOf('/');
    const pHost: string = pathStart < 0 ? rest : rest.substring(0, pathStart);
    const pPath: string = pathStart < 0 ? '/' : rest.substring(pathStart);
    return Userscript.hostMatches(pHost.toLowerCase(), host)
      && Userscript.globMatches(pPath, full);
  }

  private static urlScheme(url: string): string {
    const idx: number = url.indexOf('://');
    return idx < 0 ? '' : url.substring(0, idx).toLowerCase();
  }

  private static urlHost(url: string): string {
    let rest: string = url;
    const idx: number = url.indexOf('://');
    if (idx >= 0) {
      rest = url.substring(idx + 3);
    }
    const slash: number = rest.indexOf('/');
    let host: string = slash < 0 ? rest : rest.substring(0, slash);
    const at: number = host.indexOf('@');
    if (at >= 0) {
      host = host.substring(at + 1);
    }
    const colon: number = host.indexOf(':');
    if (colon >= 0) {
      host = host.substring(0, colon);
    }
    return host.toLowerCase();
  }

  private static urlPathFull(url: string): string {
    const idx: number = url.indexOf('://');
    const rest: string = idx >= 0 ? url.substring(idx + 3) : url;
    const slash: number = rest.indexOf('/');
    if (slash < 0) {
      return '/';
    }
    const tail: string = rest.substring(slash);
    const hash: number = tail.indexOf('#');
    return hash < 0 ? tail : tail.substring(0, hash);
  }

  private static schemeMatches(pattern: string, scheme: string): boolean {
    if (pattern === '*') {
      return scheme === 'http' || scheme === 'https' || scheme === 'ws'
        || scheme === 'wss' || scheme === 'ftp' || scheme === 'file';
    }
    return pattern === scheme;
  }

  private static hostMatches(pattern: string, host: string): boolean {
    if (pattern === '*') {
      return true;
    }
    if (pattern.startsWith('*.')) {
      const suffix: string = pattern.substring(2);
      return host === suffix || host.endsWith('.' + suffix);
    }
    return pattern === host;
  }

  /** @include / @exclude：支持 /regex/ 与 glob */
  static includeMatch(url: string, rule: string): boolean {
    const r: string = rule.trim();
    if (r.length > 2 && r.startsWith('/') && r.endsWith('/')) {
      try {
        const re: RegExp = new RegExp(r.substring(1, r.length - 1));
        return re.test(url);
      } catch (e) {
        return false;
      }
    }
    let glob: string = r;
    if (glob.startsWith('*://')) {
      glob = '*' + glob.substring(4);
    }
    return Userscript.globMatches(glob, url);
  }

  /** glob 匹配：* 任意字符、? 单字符 */
  static globMatches(pattern: string, text: string): boolean {
    let reStr: string = '';
    for (let i = 0; i < pattern.length; i++) {
      const c: string = pattern.charAt(i);
      if (c === '*') {
        reStr += '.*';
      } else if (c === '?') {
        reStr += '.';
      } else if ('.()[]{}+^$|\\'.indexOf(c) >= 0) {
        reStr += '\\' + c;
      } else {
        reStr += c;
      }
    }
    try {
      const re: RegExp = new RegExp('^' + reStr + '$', 'i');
      return re.test(text);
    } catch (e) {
      return false;
    }
  }
}
