import { Palette } from './Theme';

/** URL 识别、展示与通用格式化工具 */
export class Utils {
  static readonly HOME_URL: string = 'zorme://home';

  private static readonly PALETTE: string[] = [
    '#2E7CF6', '#E5484D', '#12A594', '#F5A524',
    '#8E4EC6', '#E93D82', '#3E63DD', '#30A46C',
    '#E8730C', '#5B5BD6', '#0E7490', '#B45309'
  ];

  static isEmpty(s: string | null | undefined): boolean {
    return s === null || s === undefined || s.length === 0;
  }

  static looksLikeUrl(input: string): boolean {
    if (!input) {
      return false;
    }
    const s: string = input.trim();
    if (s.length === 0 || s.includes(' ')) {
      return false;
    }
    if (s.startsWith('http://') || s.startsWith('https://') || s.startsWith('file:')) {
      return true;
    }
    if (s.startsWith('about:') || s.startsWith('javascript:')) {
      return false;
    }
    let host: string = s;
    const slash: number = host.indexOf('/');
    if (slash >= 0) {
      host = host.substring(0, slash);
    }
    const colon: number = host.indexOf(':');
    if (colon >= 0) {
      host = host.substring(0, colon);
    }
    const dot: number = host.lastIndexOf('.');
    if (dot <= 0 || dot === host.length - 1) {
      return false;
    }
    const tld: string = host.substring(dot + 1);
    return tld.length >= 2 && new RegExp('^[a-zA-Z]{2,10}$').test(tld);
  }

  static normalizeUrl(input: string): string {
    const s: string = input.trim();
    if (s.startsWith('http://') || s.startsWith('https://') || s.startsWith('file:')
      || s.startsWith('about:') || s.startsWith('data:') || s.startsWith('javascript:')) {
      return s;
    }
    return 'https://' + s;
  }

  static hostOf(url: string): string {
    if (!url) {
      return '';
    }
    let s: string = url;
    const scheme: number = s.indexOf('://');
    if (scheme >= 0) {
      s = s.substring(scheme + 3);
    }
    const slash: number = s.indexOf('/');
    if (slash >= 0) {
      s = s.substring(0, slash);
    }
    const at: number = s.lastIndexOf('@');
    if (at >= 0) {
      s = s.substring(at + 1);
    }
    const colon: number = s.indexOf(':');
    if (colon >= 0) {
      s = s.substring(0, colon);
    }
    return s.toLowerCase();
  }

  static domainOf(url: string): string {
    const host: string = Utils.hostOf(url);
    if (host.startsWith('www.')) {
      return host.substring(4);
    }
    return host.length > 0 ? host : url;
  }

  static displayUrl(url: string): string {
    if (!url) {
      return '';
    }
    let s: string = url;
    if (s.startsWith('https://')) {
      s = s.substring(8);
    } else if (s.startsWith('http://')) {
      s = s.substring(7);
    }
    if (s.startsWith('www.')) {
      s = s.substring(4);
    }
    if (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  static titleOf(url: string): string {
    const d: string = Utils.domainOf(url);
    return d.length === 0 ? '新标签页' : d;
  }

  static isHome(url: string): boolean {
    return !url || url.length === 0 || url.startsWith(Utils.HOME_URL);
  }

  static colorFor(key: string): string {
    const k: string = key ? key : '';
    let h: number = 0;
    for (let i = 0; i < k.length; i++) {
      h = h * 31 + k.charCodeAt(i);
    }
    let idx: number = Math.abs(h) % Utils.PALETTE.length;
    return Utils.PALETTE[idx];
  }

  static letterOf(text: string): string {
    if (!text || text.trim().length === 0) {
      return '?';
    }
    const t: string = text.trim();
    const c: string = t.charAt(0);
    if (new RegExp('[0-9A-Za-z\\u4e00-\\u9fa5]').test(c)) {
      return c.toUpperCase();
    }
    return '·';
  }

  static pad2(n: number): string {
    return n < 10 ? '0' + n.toString() : n.toString();
  }

  static formatTime(time: number): string {
    const now: Date = new Date();
    const then: Date = new Date(time);
    const sameDay: boolean = now.getFullYear() === then.getFullYear()
      && now.getMonth() === then.getMonth() && now.getDate() === then.getDate();
    if (sameDay) {
      return Utils.pad2(then.getHours()) + ':' + Utils.pad2(then.getMinutes());
    }
    if (now.getFullYear() === then.getFullYear()) {
      return (then.getMonth() + 1).toString() + '月' + then.getDate().toString() + '日';
    }
    return then.getFullYear().toString() + '/' + (then.getMonth() + 1).toString()
      + '/' + then.getDate().toString();
  }

  static formatSize(bytes: number): string {
    if (bytes <= 0) {
      return '';
    }
    if (bytes < 1024) {
      return bytes.toString() + ' B';
    }
    if (bytes < 1024 * 1024) {
      return (bytes / 1024).toFixed(1) + ' KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return (bytes / 1024 / 1024).toFixed(1) + ' MB';
    }
    return (bytes / 1024 / 1024 / 1024).toFixed(2) + ' GB';
  }

  /** 从 Content-Disposition / URL 推测文件名 */
  static guessFileName(url: string, disposition: string, mime: string): string {
    let name: string = '';
    if (disposition) {
      const star: number = disposition.indexOf("filename*=");
      if (star >= 0) {
        const rest: string = disposition.substring(star + 10);
        const semi: number = rest.indexOf(';');
        let raw: string = semi >= 0 ? rest.substring(0, semi) : rest;
        raw = raw.trim().replace('"', '').replace("'", '');
        const idx: number = raw.indexOf("''");
        if (idx >= 0) {
          raw = raw.substring(idx + 2);
        }
        try {
          name = decodeURIComponent(raw);
        } catch (e) {
          name = raw;
        }
      }
      if (!name) {
        const plain: number = disposition.indexOf('filename=');
        if (plain >= 0) {
          let rest: string = disposition.substring(plain + 9);
          const semi: number = rest.indexOf(';');
          if (semi >= 0) {
            rest = rest.substring(0, semi);
          }
          name = rest.trim().replace(/^"|"$/g, '');
        }
      }
    }
    if (!name && url) {
      let path: string = url;
      const q: number = path.indexOf('?');
      if (q >= 0) {
        path = path.substring(0, q);
      }
      const hash: number = path.indexOf('#');
      if (hash >= 0) {
        path = path.substring(0, hash);
      }
      const slash: number = path.lastIndexOf('/');
      if (slash >= 0) {
        path = path.substring(slash + 1);
      }
      try {
        path = decodeURIComponent(path);
      } catch (e) {
      }
      name = path;
    }
    if (!name) {
      name = 'zorme_' + Date.now().toString();
      if (mime) {
        if (mime.indexOf('html') >= 0) {
          name += '.html';
        } else if (mime.indexOf('image') >= 0) {
          name += '.jpg';
        } else if (mime.indexOf('pdf') >= 0) {
          name += '.pdf';
        }
      }
    }
    return name.replace(/[\\/:*?"<>|]/g, '_');
  }

  static truncate(s: string, max: number): string {
    return s.length > max ? s.substring(0, max) + '…' : s;
  }

  static parseDateToMillis(s: string): number {
    // 支持 20250101000000Z / 2025-01-01 00:00:00 两种格式
    const digits: string = s.replace(/[^0-9]/g, '');
    if (digits.length >= 8) {
      const y: number = Number(digits.substring(0, 4));
      const mo: number = Number(digits.substring(4, 6)) - 1;
      const d: number = Number(digits.substring(6, 8));
      const h: number = digits.length >= 10 ? Number(digits.substring(8, 10)) : 0;
      const mi: number = digits.length >= 12 ? Number(digits.substring(10, 12)) : 0;
      const se: number = digits.length >= 14 ? Number(digits.substring(12, 14)) : 0;
      return new Date(y, mo, d, h, mi, se).getTime();
    }
    return 0;
  }

  static formatDate(millis: number): string {
    if (millis <= 0) {
      return '—';
    }
    const d: Date = new Date(millis);
    return d.getFullYear().toString() + '-' + Utils.pad2(d.getMonth() + 1) + '-' + Utils.pad2(d.getDate());
  }

  static paletteColor(p: Palette, key: string): string {
    return key === 'bg' ? p.bg : p.textPrimary;
  }
}
