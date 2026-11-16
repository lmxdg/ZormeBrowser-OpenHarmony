import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';

export class AiMsg {
  role: string;
  content: string;

  constructor(role: string, content: string) {
    this.role = role;
    this.content = content ? content : '';
  }
}

interface ChatMessageJson {
  role: string;
  content: string;
}

interface ChatBodyJson {
  model: string;
  stream: boolean;
  messages: ChatMessageJson[];
}

interface ChatChoiceJson {
  message?: ChatMessageJson;
  delta?: ChatMessageJson;
}

interface ChatResponseJson {
  choices?: ChatChoiceJson[];
  error?: ChatErrorJson;
  message?: string;
}

interface ChatErrorJson {
  message?: string;
}

/**
 * OpenAI 兼容 Chat Completions 客户端（POST {base}/chat/completions）。
 * 使用 requestInStream 读取 SSE 增量，实现流式输出。
 */
export class AiClient {
  private static busyFlag: boolean = false;
  private static current: http.HttpRequest | null = null;
  private static cancelHandler: (() => void) | null = null;

  static busy(): boolean {
    return AiClient.busyFlag;
  }

  static endpoint(base: string): string {
    if (!base) {
      return '';
    }
    let b: string = base.trim();
    if (b.length === 0) {
      return '';
    }
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    if (b.endsWith('/chat/completions')) {
      return b;
    }
    return b + '/chat/completions';
  }

  static requestBody(model: string, messages: AiMsg[], stream: boolean): string {
    const list: ChatMessageJson[] = [];
    for (const m of messages) {
      const item: ChatMessageJson = { role: m.role, content: m.content };
      list.push(item);
    }
    const body: ChatBodyJson = { model: model ? model.trim() : '', stream: stream, messages: list };
    return JSON.stringify(body);
  }

  /** 解析 SSE 一行，返回增量文本；[DONE] 返回标记；无关行返回 null */
  static parseSseLine(line: string): string | null {
    if (!line) {
      return null;
    }
    const t: string = line.trim();
    if (t.length === 0 || !t.startsWith('data:')) {
      return null;
    }
    const payload: string = t.substring(5).trim();
    if (payload.length === 0) {
      return null;
    }
    if (payload === '[DONE]') {
      return '[DONE]';
    }
    try {
      const obj: ChatResponseJson = JSON.parse(payload) as ChatResponseJson;
      const choices: ChatChoiceJson[] | undefined = obj.choices;
      if (!choices || choices.length === 0) {
        return null;
      }
      let part: ChatMessageJson | undefined = choices[0].delta;
      if (!part) {
        part = choices[0].message;
      }
      if (!part) {
        return null;
      }
      return part.content ? part.content : null;
    } catch (e) {
      return null;
    }
  }

  static friendlyError(code: number, body: string): string {
    let detail: string = '';
    try {
      const obj: ChatResponseJson = JSON.parse(body) as ChatResponseJson;
      if (obj.error && obj.error.message) {
        detail = obj.error.message;
      } else if (obj.message) {
        detail = obj.message;
      }
    } catch (e) {
    }
    if (!detail) {
      detail = body ? body : '';
    }
    if (detail.length > 300) {
      detail = detail.substring(0, 300) + '…';
    }
    let hint: string = 'HTTP ' + code.toString();
    if (code === 401) {
      hint = 'API Key 无效或未授权';
    } else if (code === 429) {
      hint = '请求过于频繁或额度不足';
    } else if (code === 404) {
      hint = '接口地址或模型不存在';
    }
    return detail.length > 0 ? hint + '：' + detail : hint;
  }

  static cancel(): void {
    if (AiClient.cancelHandler !== null) {
      AiClient.cancelHandler();
    }
  }

  /** 发起对话请求（流式）；onDelta 收到累计全文，onDone 结束 */
  static chat(base: string, key: string, model: string, messages: AiMsg[],
    onDelta: (full: string) => void, onDone: (full: string, error: string) => void): void {
    const url: string = AiClient.endpoint(base);
    if (url.length === 0) {
      onDone('', '请先在设置中配置 API 地址');
      return;
    }
    if (!key || key.trim().length === 0) {
      onDone('', '请先在设置中填写 API Key');
      return;
    }
    if (!model || model.trim().length === 0) {
      onDone('', '请先在设置中填写模型名称');
      return;
    }
    if (AiClient.busyFlag) {
      onDone('', '正在回复中，请先停止或等待完成');
      return;
    }
    AiClient.busyFlag = true;

    const req: http.HttpRequest = http.createHttp();
    AiClient.current = req;
    const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
    let full: string = '';
    let raw: string = '';
    let buffer: string = '';
    let finished: boolean = false;
    let httpCode: number = 0;

    const finish = (error: string): void => {
      if (finished) {
        return;
      }
      finished = true;
      AiClient.busyFlag = false;
      AiClient.current = null;
      AiClient.cancelHandler = null;
      try {
        req.destroy();
      } catch (e) {
      }
      onDone(full, error);
    };

    AiClient.cancelHandler = (): void => {
      finish('');
    };

    req.on('dataReceive', (data: ArrayBuffer) => {
      if (finished) {
        return;
      }
      const chunk: string = decoder.decodeWithStream(new Uint8Array(data), { stream: true });
      raw += chunk;
      if (httpCode >= 400) {
        return;
      }
      buffer += chunk;
      let idx: number = buffer.indexOf('\n');
      while (idx >= 0) {
        const line: string = buffer.substring(0, idx);
        buffer = buffer.substring(idx + 1);
        const delta: string | null = AiClient.parseSseLine(line);
        if (delta === '[DONE]') {
          finish('');
          return;
        }
        if (delta !== null && delta.length > 0) {
          full += delta;
          onDelta(full);
        }
        idx = buffer.indexOf('\n');
      }
    });

    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + key.trim(),
        'Accept': 'text/event-stream'
      },
      extraData: AiClient.requestBody(model, messages, true),
      connectTimeout: 20000,
      readTimeout: 120000,
      expectDataType: http.HttpDataType.STRING
    };

    req.requestInStream(url, options, (err: Error, code: number) => {
      httpCode = code;
      if (err) {
        finish(err.message ? err.message : '网络请求失败');
        return;
      }
      if (code >= 400) {
        finish(AiClient.friendlyError(code, raw));
        return;
      }
      if (full.length === 0 && raw.length > 0) {
        // 服务端未按 SSE 返回时的兜底解析
        try {
          const obj: ChatResponseJson = JSON.parse(raw) as ChatResponseJson;
          if (obj.choices && obj.choices.length > 0 && obj.choices[0].message) {
            const text: string | undefined = obj.choices[0].message?.content;
            if (text) {
              full = text;
            }
          }
        } catch (e) {
        }
      }
      finish('');
    });
  }
}
