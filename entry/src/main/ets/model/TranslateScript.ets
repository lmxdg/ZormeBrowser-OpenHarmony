import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';

/**
 * 网页翻译的注入脚本封装。
 * 脚本本体放在 resources/rawfile/inject/translate.js，首次使用时同步读取并缓存，
 * 避免把大段 JS 转义后写进 ArkTS 字面量。
 */
export class TranslateScript {
  private static lib: string = '';

  /** 注入库脚本（幂等：脚本内部会判断是否已注入） */
  static libScript(ctx: common.UIAbilityContext): string {
    if (TranslateScript.lib.length > 0) {
      return TranslateScript.lib;
    }
    try {
      const bytes: Uint8Array = ctx.resourceManager.getRawFileContentSync('inject/translate.js');
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      TranslateScript.lib = decoder.decodeToString(bytes);
    } catch (e) {
      TranslateScript.lib = '';
    }
    return TranslateScript.lib;
  }

  /** 探测注入是否成功：返回 "object" 表示脚本已挂到 window 上 */
  static probe(): string {
    return 'typeof window.__zormeT';
  }

  /** 收集页面文本节点，返回 JSON 字符串 */
  static collect(): string {
    return 'window.__zormeT?__zormeT.collect():"{\\"ok\\":false}"';
  }

  /** 回填第 start 段起的译文 */
  static apply(start: number, texts: string[]): string {
    let json: string = JSON.stringify(texts);
    json = json.split('\u2028').join('\\u2028').split('\u2029').join('\\u2029');
    return '(function(s,a){return window.__zormeT?__zormeT.apply(s,a):"0";})('
      + start.toString() + ',' + json + ')';
  }

  /** 还原为原文 */
  static restore(): string {
    return 'window.__zormeT?__zormeT.restore():"0"';
  }
}
