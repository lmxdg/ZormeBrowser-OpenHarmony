import { http } from '@kit.NetworkKit';

interface GhAsset {
  name?: string;
  browser_download_url?: string;
}

interface GhRelease {
  tag_name?: string;
  body?: string;
  html_url?: string;
  assets?: GhAsset[];
}

/** 检测更新：拉取 GitHub Releases 最新版本，与本地版本语义化比较 */
export class UpdateChecker {
  static readonly REPO_OWNER: string = 'lmxdg';
  static readonly REPO_NAME: string = 'ZormeBrowser-OpenHarmony';
  static readonly RELEASES_URL: string =
    'https://github.com/lmxdg/ZormeBrowser-OpenHarmony/releases/latest';
  static readonly API_URL: string =
    'https://api.github.com/repos/lmxdg/ZormeBrowser-OpenHarmony/releases/latest';

  static readonly MIRROR_NAMES: string[] = [
    'GitHub 直连（github.com）',
    'ghfast.top 加速',
    'ghproxy.net 加速'
  ];

  static readonly MIRROR_PREFIXES: string[] = ['', 'https://ghfast.top/', 'https://ghproxy.net/'];

  static applyMirror(url: string, mirror: number): string {
    if (!url) {
      return url;
    }
    if (mirror <= 0 || mirror >= UpdateChecker.MIRROR_PREFIXES.length) {
      return url;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return url;
    }
    return UpdateChecker.MIRROR_PREFIXES[mirror] + url;
  }

  static normalize(tag: string): string {
    if (!tag) {
      return '';
    }
    let t: string = tag.trim();
    if (t.startsWith('v') || t.startsWith('V')) {
      t = t.substring(1);
    }
    return t.trim();
  }

  static parse(v: string): number[] {
    if (!v) {
      return [0];
    }
    const parts: string[] = v.split(new RegExp('[._-]'));
    const result: number[] = [];
    for (const p of parts) {
      let digits: string = '';
      for (let i = 0; i < p.length; i++) {
        const ch: string = p.charAt(i);
        if (ch >= '0' && ch <= '9') {
          digits += ch;
        } else {
          break;
        }
      }
      result.push(digits.length > 0 ? Number(digits) : 0);
    }
    return result;
  }

  static compareVersion(a: string, b: string): number {
    const pa: number[] = UpdateChecker.parse(a);
    const pb: number[] = UpdateChecker.parse(b);
    const n: number = Math.max(pa.length, pb.length);
    for (let i = 0; i < n; i++) {
      const x: number = i < pa.length ? pa[i] : 0;
      const y: number = i < pb.length ? pb[i] : 0;
      if (x !== y) {
        return x - y;
      }
    }
    return 0;
  }

  static check(localVersion: string,
    cb: (ok: boolean, hasUpdate: boolean, latest: string, notes: string,
      hapUrl: string, releaseUrl: string) => void): void {
    UpdateChecker.doCheck(localVersion, cb).catch(() => {
      cb(false, false, '', '', '', '');
    });
  }

  private static async doCheck(localVersion: string,
    cb: (ok: boolean, hasUpdate: boolean, latest: string, notes: string,
      hapUrl: string, releaseUrl: string) => void): Promise<void> {
    const req: http.HttpRequest = http.createHttp();
    try {
      const resp: http.HttpResponse = await req.request(UpdateChecker.API_URL, {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'ZormeBrowser-OpenHarmony/' + localVersion
        },
        connectTimeout: 10000,
        readTimeout: 10000,
        expectDataType: http.HttpDataType.STRING
      });
      if (resp.responseCode !== 200) {
        cb(false, false, '', '', '', '');
        return;
      }
      const body: string = resp.result as string;
      const obj: GhRelease = JSON.parse(body) as GhRelease;
      const latest: string = UpdateChecker.normalize(obj.tag_name ? obj.tag_name : '');
      const notes: string = obj.body ? obj.body : '';
      const releaseUrl: string = obj.html_url ? obj.html_url : UpdateChecker.RELEASES_URL;
      let hapUrl: string = '';
      if (obj.assets) {
        for (const a of obj.assets) {
          const name: string = a.name ? a.name : '';
          if (name.toLowerCase().endsWith('.hap')) {
            hapUrl = a.browser_download_url ? a.browser_download_url : '';
            break;
          }
        }
      }
      const hasUpdate: boolean = latest.length > 0 &&
        UpdateChecker.compareVersion(latest, localVersion) > 0;
      cb(true, hasUpdate, latest, notes, hapUrl, releaseUrl);
    } catch (e) {
      cb(false, false, '', '', '', '');
    } finally {
      try {
        req.destroy();
      } catch (e) {
      }
    }
  }
}
