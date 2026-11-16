import { pasteboard } from '@kit.BasicServicesKit';
import { Palette } from '../common/Theme';
import { Prefs } from '../model/Prefs';
import { AiClient, AiMsg } from '../model/AiClient';
import { AiProvider } from '../model/AiProvider';
import { ZIcon } from './ZIcon';

class ChatBubble {
  id: number;
  role: string;
  text: string;
  failed: boolean;

  constructor(id: number, role: string, text: string, failed: boolean) {
    this.id = id;
    this.role = role;
    this.text = text;
    this.failed = failed;
  }
}

class QuickPrompt {
  label: string;
  text: string;

  constructor(label: string, text: string) {
    this.label = label;
    this.text = text;
  }
}

const SYSTEM_PROMPT: string = '你是 Zorme 浏览器内置的 AI 助手，回答简洁、准确，使用中文。';

/** AI 助手对话页（OpenAI 兼容接口，流式输出） */
@Component
export struct AiChatView {
  @Prop pal: Palette;
  onClose: () => void = () => {
  };
  toast: (text: string) => void = () => {
  };
  openSettings: () => void = () => {
  };

  @State msgs: ChatBubble[] = [];
  @State streamText: string = '';
  @State input: string = '';
  @State busy: boolean = false;
  @State configured: boolean = true;
  @State modelName: string = '';
  @State providerName: string = '';

  private scroller: Scroller = new Scroller();
  private seq: number = 0;

  aboutToAppear(): void {
    this.refreshConfig();
  }

  private refreshConfig(): void {
    const key: string = Prefs.aiKey();
    this.configured = key.length > 0;
    const base: string = Prefs.aiBase();
    this.modelName = Prefs.aiModel();
    this.providerName = AiProvider.currentName(base);
  }

  private scrollBottom(): void {
    setTimeout(() => {
      try {
        this.scroller.scrollEdge(Edge.Bottom);
      } catch (e) {
      }
    }, 40);
  }

  private history(): AiMsg[] {
    const list: AiMsg[] = [new AiMsg('system', SYSTEM_PROMPT)];
    for (const m of this.msgs) {
      if (!m.failed && m.text.length > 0) {
        list.push(new AiMsg(m.role, m.text));
      }
    }
    return list;
  }

  private send(text: string): void {
    const q: string = text.trim();
    if (q.length === 0) {
      return;
    }
    if (this.busy) {
      this.toast('正在回复中，请先停止');
      return;
    }
    this.refreshConfig();
    if (!this.configured) {
      this.toast('请先在设置中配置 AI');
      this.openSettings();
      return;
    }
    this.seq = this.seq + 1;
    this.msgs.push(new ChatBubble(this.seq, 'user', q, false));
    this.msgs = this.msgs.slice();
    this.input = '';
    this.streamText = '';
    this.busy = true;
    this.scrollBottom();

    const payload: AiMsg[] = this.history();
    AiClient.chat(Prefs.aiBase(), Prefs.aiKey(), Prefs.aiModel(), payload,
      (full: string) => {
        this.streamText = full;
        this.scrollBottom();
      },
      (full: string, error: string) => {
        const answer: string = full.length > 0 ? full : this.streamText;
        this.busy = false;
        this.streamText = '';
        if (error.length > 0) {
          this.seq = this.seq + 1;
          this.msgs.push(new ChatBubble(this.seq, 'assistant', error, true));
        } else if (answer.trim().length > 0) {
          this.seq = this.seq + 1;
          this.msgs.push(new ChatBubble(this.seq, 'assistant', answer, false));
        }
        this.msgs = this.msgs.slice();
        this.scrollBottom();
      });
  }

  private stop(): void {
    if (!this.busy) {
      return;
    }
    AiClient.cancel();
  }

  private clear(): void {
    if (this.busy) {
      AiClient.cancel();
    }
    this.msgs = [];
    this.streamText = '';
    this.busy = false;
  }

  private copy(text: string): void {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      pasteboard.getSystemPasteboard().setData(data).then(() => {
        this.toast('已复制');
      }).catch(() => {
        this.toast('复制失败');
      });
    } catch (e) {
      this.toast('复制失败');
    }
  }

  @Builder
  quickChip(item: QuickPrompt) {
    Text(item.label)
      .fontSize(12)
      .fontColor(this.pal.textSecondary)
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .borderRadius(16)
      .backgroundColor(this.pal.surfaceAlt)
      .margin({ right: 8, bottom: 8 })
      .onClick(() => {
        this.send(item.text);
      })
  }

  @Builder
  bubbleView(m: ChatBubble) {
    Row() {
      if (m.role === 'user') {
        Blank()
      }
      Column() {
        if (m.failed) {
          Row() {
            ZIcon({ path: 'ic_info', iconSize: 14, color: this.pal.danger })
              .margin({ right: 6 })
            Text('发送失败')
              .fontSize(12)
              .fontColor(this.pal.danger)
          }
          .margin({ bottom: 4 })
        }
        Text(m.text)
          .fontSize(14)
          .lineHeight(22)
          .fontColor(m.failed ? this.pal.danger : (m.role === 'user' ? this.pal.onAccent : this.pal.textPrimary))
          .textAlign(TextAlign.Start)
          .copyOption(CopyOptions.LocalDevice)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .constraintSize({ maxWidth: '86%' })
      .padding({ left: 14, right: 14, top: 11, bottom: 11 })
      .borderRadius(m.role === 'user' ?
        { topLeft: 16, topRight: 16, bottomLeft: 16, bottomRight: 4 } :
        { topLeft: 16, topRight: 16, bottomLeft: 4, bottomRight: 16 })
      .backgroundColor(m.role === 'user' ? this.pal.accent :
        (m.failed ? this.pal.surfaceAlt : this.pal.surfaceAlt))
      .gesture(LongPressGesture().onAction(() => {
        this.copy(m.text);
      }))

      if (m.role !== 'user') {
        Blank()
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 6, bottom: 6 })
  }

  @Builder
  streamingBubble() {
    Row() {
      Column() {
        Text(this.streamText.length > 0 ? this.streamText : '正在思考…')
          .fontSize(14)
          .lineHeight(22)
          .fontColor(this.streamText.length > 0 ? this.pal.textPrimary : this.pal.textTertiary)
          .width('100%')
          .copyOption(CopyOptions.LocalDevice)
      }
      .alignItems(HorizontalAlign.Start)
      .constraintSize({ maxWidth: '86%' })
      .padding({ left: 14, right: 14, top: 11, bottom: 11 })
      .borderRadius({ topLeft: 16, topRight: 16, bottomLeft: 4, bottomRight: 16 })
      .backgroundColor(this.pal.surfaceAlt)
      Blank()
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 6, bottom: 6 })
  }

  @Builder
  emptyState() {
    Column() {
      Column() {
        ZIcon({ path: 'ic_ai', iconSize: 34, color: this.pal.textPrimary })
      }
      .width(64)
      .height(64)
      .borderRadius(20)
      .backgroundColor(this.pal.surfaceAlt)
      .justifyContent(FlexAlign.Center)

      Text('Zorme AI')
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.pal.textPrimary)
        .margin({ top: 14 })
      Text(this.configured ? '随时提问，支持流式回答' : '尚未配置 AI 服务，请先完成设置')
        .fontSize(12)
        .fontColor(this.pal.textTertiary)
        .margin({ top: 6 })

      if (!this.configured) {
        Row() {
          ZIcon({ path: 'ic_settings', iconSize: 16, color: this.pal.iconMuted })
            .margin({ right: 6 })
          Text('前往设置')
            .fontSize(13)
            .fontColor(this.pal.textPrimary)
        }
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .borderRadius(20)
        .backgroundColor(this.pal.surfaceAlt)
        .margin({ top: 16 })
        .onClick(() => {
          this.openSettings();
        })
      }

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
        ForEach([
          new QuickPrompt('解释一个概念', '用通俗的语言解释一下什么是 HTTP/3'),
          new QuickPrompt('写一段代码', '用 ArkTS 写一个带防抖的搜索输入框'),
          new QuickPrompt('润色文字', '帮我把这段话润色得更正式一些：'),
          new QuickPrompt('翻译成英文', '请把下面这句话翻译成英文：')
        ], (item: QuickPrompt) => {
          this.quickChip(item)
        }, (item: QuickPrompt) => item.label)
      }
      .width('100%')
      .constraintSize({ maxWidth: 340 })
      .margin({ top: 22 })
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 40 })
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Row() {
          ZIcon({ path: 'ic_back', iconSize: 22, color: this.pal.icon })
        }
        .width(44)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.onClose();
        })

        Column() {
          Text('Zorme AI')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.pal.textPrimary)
          Text(this.configured ?
            (this.providerName + ' · ' + (this.modelName.length > 0 ? this.modelName : '默认模型')) :
            '未配置服务')
            .fontSize(10)
            .fontColor(this.pal.textTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.msgs.length > 0 || this.busy) {
          Row() {
            ZIcon({ path: 'ic_delete', iconSize: 19, color: this.pal.iconMuted })
          }
          .width(40)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.clear();
            this.toast('已清空对话');
          })
        }

        Row() {
          ZIcon({ path: 'ic_settings', iconSize: 20, color: this.pal.iconMuted })
        }
        .width(44)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.refreshConfig();
          this.openSettings();
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: 4, right: 4 })

      Divider().color(this.pal.divider).strokeWidth(0.5)

      // 消息区
      List({ scroller: this.scroller, space: 0 }) {
        if (this.msgs.length === 0 && !this.busy) {
          ListItem() {
            this.emptyState()
          }
        }
        ForEach(this.msgs, (item: ChatBubble) => {
          ListItem() {
            this.bubbleView(item)
          }
        }, (item: ChatBubble) => item.id.toString())
        if (this.busy) {
          ListItem() {
            this.streamingBubble()
          }
        }
        ListItem() {
          Row().height(12)
        }
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .nestedScroll({
        scrollForward: NestedScrollMode.SELF_FIRST,
        scrollBackward: NestedScrollMode.SELF_FIRST
      })

      // 输入区
      Column() {
        Row() {
          TextArea({ text: this.input, placeholder: '询问 AI…' })
            .placeholderColor(this.pal.textTertiary)
            .placeholderFont({ size: 14 })
            .fontSize(14)
            .fontColor(this.pal.textPrimary)
            .backgroundColor(Color.Transparent)
            .borderRadius(0)
            .padding({ left: 0, right: 0, top: 0, bottom: 0 })
            .constraintSize({ minHeight: 24, maxHeight: 96 })
            .maxLength(4000)
            .layoutWeight(1)
            .onChange((value: string) => {
              this.input = value;
            })

          if (this.busy) {
            Row() {
              Row()
                .width(10)
                .height(10)
                .borderRadius(2)
                .backgroundColor(this.pal.onAccent)
            }
            .width(34)
            .height(34)
            .borderRadius(17)
            .backgroundColor(this.pal.accent)
            .justifyContent(FlexAlign.Center)
            .margin({ left: 10 })
            .onClick(() => {
              this.stop();
            })
          } else {
            Row() {
              ZIcon({
                path: 'ic_arrow_up',
                iconSize: 18,
                color: this.input.trim().length > 0 ? this.pal.onAccent : this.pal.textTertiary
              })
            }
            .width(34)
            .height(34)
            .borderRadius(17)
            .backgroundColor(this.input.trim().length > 0 ? this.pal.accent : this.pal.surfaceAlt)
            .justifyContent(FlexAlign.Center)
            .margin({ left: 10 })
            .onClick(() => {
              this.send(this.input);
            })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)
        .padding({ left: 14, right: 10, top: 10, bottom: 10 })
        .borderRadius(22)
        .backgroundColor(this.pal.surfaceAlt)

        Text(this.busy ? '生成中，点击方块可停止' : 'AI 生成内容仅供参考')
          .fontSize(10)
          .fontColor(this.pal.textTertiary)
          .margin({ top: 6 })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 10 })
      .backgroundColor(this.pal.bg)
      .border({ width: { top: 0.5 }, color: this.pal.divider })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pal.bg)
  }
}
