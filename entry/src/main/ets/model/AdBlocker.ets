import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { Utils } from '../common/Utils';

/** 轻量广告拦截：按域名后缀匹配，规则来自 rawfile/ad_hosts.txt */
export class AdBlocker {
  private static hosts: Set<string> = new Set<string>();
  private static whitelist: Set<string> = new Set<string>();
  private static loaded: boolean = false;

  static init(ctx: common.UIAbilityContext): void {
    if (AdBlocker.loaded) {
      return;
    }
    try {
      const bytes: Uint8Array = ctx.resourceManager.getRawFileContentSync('ad_hosts.txt');
      const text: string = util.TextDecoder.create('utf-8').decodeToString(bytes);
      const lines: string[] = text.split('\n');
      for (const raw of lines) {
        const line: string = raw.trim();
        if (line.length === 0 || line.startsWith('#')) {
          continue;
        }
        if (line.startsWith('@@')) {
          AdBlocker.whitelist.add(line.substring(2).toLowerCase());
        } else {
          AdBlocker.hosts.add(line.toLowerCase());
        }
      }
    } catch (e) {
      AdBlocker.hosts.clear();
    }
    if (AdBlocker.hosts.size === 0) {
      const core: string[] = [
        'doubleclick.net', 'googlesyndication.com', 'googleadservices.com',
        'google-analytics.com', 'googletagmanager.com', 'adservice.google.com',
        'umeng.com', 'cnzz.com', 'hm.baidu.com', 'pos.baidu.com', 'cpro.baidu.com'
      ];
      for (const s of core) {
        AdBlocker.hosts.add(s);
      }
    }
    AdBlocker.loaded = true;
  }

  static reload(ctx: common.UIAbilityContext): void {
    AdBlocker.hosts.clear();
    AdBlocker.whitelist.clear();
    AdBlocker.loaded = false;
    AdBlocker.init(ctx);
  }

  static isBlocked(url: string): boolean {
    if (!url || AdBlocker.hosts.size === 0) {
      return false;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return false;
    }
    const host: string = Utils.hostOf(url);
    if (!host) {
      return false;
    }
    for (const w of AdBlocker.whitelist) {
      if (host === w || host.endsWith('.' + w)) {
        return false;
      }
    }
    const parts: string[] = host.split('.');
    for (let i = 0; i < parts.length - 1; i++) {
      let suffix: string = '';
      for (let j = i; j < parts.length; j++) {
        if (j > i) {
          suffix += '.';
        }
        suffix += parts[j];
      }
      if (AdBlocker.hosts.has(suffix)) {
        return true;
      }
    }
    return false;
  }

  static ruleCount(): number {
    return AdBlocker.hosts.size;
  }
}
