import { Palette } from '../common/Theme';
import { pasteboard } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import { Userscript } from '../model/Userscript';
import { UserscriptStore } from '../model/UserscriptStore';
import { ZIcon } from './ZIcon';
import { ZSwitch } from './ZSwitch';

/** 复制文本到系统剪贴板 */
function copyToClipboard(text: string): void {
  try {
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    pasteboard.getSystemPasteboard().setData(data).catch(() => {
    });
  } catch (e) {
  }
}

/** 油猴脚本管理页：列表（启用开关 / 删除 / 查看代码）+ 从 URL 或粘贴代码安装 */
@Component
export struct UserscriptView {
  @Prop pal: Palette;
  onClose: () => void = () => {
  };
  toast: (text: string) => void = () => {
  };
  confirm: (title: string, message: string, positive: string, cb: () => void) => void = () => {
  };
  options: (title: string, items: string[], danger: boolean, cb: (index: number) => void) => void =
    () => {
    };
  input: (title: string, hint: string, initial: string, cb: (text: string) => void) => void =
    () => {
    };

  @State rows: Userscript[] = [];
  @State keyword: string = '';

  aboutToAppear(): void {
    this.reload();
  }

  private reload(): void {
    const k: string = this.keyword.trim().toLowerCase();
    const all: Userscript[] = UserscriptStore.all();
    const list: Userscript[] = [];
    for (const s of all) {
      if (k.length === 0 || s.name.toLowerCase().includes(k)
        || s.description.toLowerCase().includes(k)) {
        list.push(s);
      }
    }
    this.rows = list;
  }

  private metaOf(s: Userscript): string {
    let out: string = '';
    if (s.version.length > 0) {
      out += 'v' + s.version + ' · ';
    }
    out += s.enabled ? '已启用' : '已停用';
    if (s.matches.length > 0) {
      out += ' · ' + s.matches[0];
    } else if (s.includes.length > 0) {
      out += ' · ' + s.includes[0];
    }
    return out;
  }

  private showAddDialog(): void {
    this.input('添加油猴脚本', '输入 .user.js 脚本地址或直接粘贴脚本代码', '',
      (text: string) => {
        const t: string = text.trim();
        if (t.length === 0) {
          return;
        }
        if (t.startsWith('http://') || t.startsWith('https://')) {
          this.installFromUrl(t);
        } else if (t.includes('==UserScript==') || t.includes('function')) {
          this.installCode(t, '');
        } else {
          this.toast('内容不是有效的脚本或链接');
        }
      });
  }

  private installFromUrl(url: string): void {
    this.toast('正在下载脚本…');
    const req: http.HttpRequest = http.createHttp();
    req.request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (ZormeBrowser)' } as Record<string, string>,
      connectTimeout: 15000,
      readTimeout: 15000,
      expectDataType: http.HttpDataType.STRING
    }).then((resp: http.HttpResponse) => {
      const body: string = typeof resp.result === 'string' ? resp.result : String(resp.result);
      req.destroy();
      this.installCode(body, url);
    }).catch((err: Error) => {
      req.destroy();
      this.toast('下载失败：' + (err.message || String(err)));
    });
  }

  private installCode(code: string, sourceUrl: string): void {
    if (code.trim().length < 10) {
      this.toast('脚本内容为空');
      return;
    }
    const s: Userscript = UserscriptStore.add(code, sourceUrl);
    this.reload();
    this.toast('已安装：' + s.name);
  }

  private showScriptMenu(s: Userscript): void {
    this.options(s.name, ['查看代码', '复制代码', '删除脚本'], true, (which: number) => {
      if (which === 0) {
        this.viewCode(s);
      } else if (which === 1) {
        copyToClipboard(s.code);
        this.toast('代码已复制');
      } else {
        this.confirm('删除脚本', '确定删除「' + s.name + '」及其保存的数据？', '删除', () => {
          UserscriptStore.remove(s.id);
          this.reload();
          this.toast('脚本已删除');
        });
      }
    });
  }

  private viewCode(s: Userscript): void {
    this.codeShown = s;
    this.codeShownFlag = !this.codeShownFlag;
  }

  @State private codeShown: Userscript | null = null;
  @State private codeShownFlag: boolean = false;

  build() {
    Column() {
      // 顶部栏
      Row() {
        Row() {
          ZIcon({ path: 'ic_back', iconSize: 20, color: this.pal.icon })
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.onClose();
        })

        Text('油猴脚本')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.pal.textPrimary)
          .layoutWeight(1)
          .margin({ left: 4 })

        Row() {
          ZIcon({ path: 'ic_add', iconSize: 20, color: this.pal.icon })
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showAddDialog();
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 })
      .alignItems(VerticalAlign.Center)

      Divider()
        .color(this.pal.divider)
        .strokeWidth(1)

      // 搜索
      Row() {
        ZIcon({ path: 'ic_search', iconSize: 15, color: this.pal.iconMuted })
        TextInput({ text: this.keyword, placeholder: '搜索脚本' })
          .placeholderColor(this.pal.textTertiary)
          .placeholderFont({ size: 13 })
          .fontColor(this.pal.textPrimary)
          .fontSize(13)
          .backgroundColor(Color.Transparent)
          .height(42)
          .layoutWeight(1)
          .onChange((v: string) => {
            this.keyword = v;
            this.reload();
          })
      }
      .width('100%')
      .height(42)
      .margin({ top: 12 })
      .padding({ left: 14, right: 14 })
      .backgroundColor(this.pal.surfaceAlt)
      .borderRadius(21)

      if (this.rows.length === 0) {
        Column() {
          ZIcon({ path: 'ic_code', iconSize: 46, color: this.pal.iconMuted })
          Text('还没有安装脚本，点右上角 + 添加')
            .fontSize(13)
            .fontColor(this.pal.textTertiary)
            .margin({ top: 14 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 2 }) {
          ForEach(this.rows, (s: Userscript) => {
            ListItem() {
              Column() {
                Row() {
                  Column() {
                    Text(s.name)
                      .fontSize(15)
                      .fontColor(this.pal.textPrimary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')
                    Text(this.metaOf(s))
                      .fontSize(11)
                      .fontColor(this.pal.textTertiary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')
                      .margin({ top: 3 })
                    if (s.description.length > 0) {
                      Text(s.description)
                        .fontSize(12)
                        .fontColor(this.pal.textSecondary)
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('100%')
                        .margin({ top: 3 })
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  ZSwitch({
                    checked: s.enabled,
                    trackOn: this.pal.accent,
                    trackOff: this.pal.surfaceAlt,
                    thumbOn: this.pal.onAccent,
                    thumbOff: this.pal.textTertiary,
                    onToggle: () => {
                      UserscriptStore.setEnabled(s.id, !s.enabled);
                      this.reload();
                    }
                  })
                    .margin({ left: 10 })
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)
              }
              .width('100%')
              .padding({ left: 16, right: 12, top: 12, bottom: 12 })
              .onClick(() => {
                this.showScriptMenu(s);
              })
            }
          }, (s: Userscript) => s.id + '|' + s.enabled.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }

      // 脚本代码预览
      if (this.codeShown !== null && this.codeShownFlag) {
        Column() {
          Row() {
            Text(this.codeShown.name)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.pal.textPrimary)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Row() {
              ZIcon({ path: 'ic_close', iconSize: 16, color: this.pal.iconMuted })
            }
            .width(32)
            .height(32)
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.codeShown = null;
            })
          }
          .width('100%')
          .padding({ bottom: 8 })

          Scroll() {
            Text(this.codeShown.code)
              .fontSize(11)
              .fontColor(this.pal.textSecondary)
              .fontFamily('monospace')
          }
          .width('100%')
          .layoutWeight(1)
          .align(Alignment.TopStart)
          .backgroundColor(this.pal.surfaceAlt)
          .borderRadius(12)
          .padding(10)
        }
        .width('92%')
        .height('62%')
        .backgroundColor(this.pal.sheet)
        .borderRadius(16)
        .padding(14)
        .position({ x: '4%', y: '15%' })
        .shadow({ radius: 24, color: 'rgba(0,0,0,0.35)' })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pal.bg)
    .padding({ left: 0, right: 0 })
  }
}
