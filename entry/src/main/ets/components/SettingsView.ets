import { common } from '@kit.AbilityKit';
import { Palette } from '../common/Theme';
import { Utils } from '../common/Utils';
import { Prefs } from '../model/Prefs';
import { SearchEngine } from '../model/SearchEngine';
import { Store } from '../model/Store';
import { AdBlocker } from '../model/AdBlocker';
import { NetLog } from '../model/NetLog';
import { Agreement } from '../model/Agreement';
import { AiProvider } from '../model/AiProvider';
import { BingTranslate } from '../model/BingTranslate';
import { ZIcon } from './ZIcon';
import { ZSwitch } from './ZSwitch';

@Component
struct SettingTextRow {
  @Prop pal: Palette;
  @Prop title: string = '';
  @Prop desc: string = '';
  @Prop value: string = '';
  onTap: () => void = () => {
  };

  build() {
    Row() {
      Column() {
        Text(this.title)
          .fontSize(14)
          .fontColor(this.pal.textPrimary)
        if (this.desc.length > 0) {
          Text(this.desc)
            .fontSize(11)
            .fontColor(this.pal.textTertiary)
            .lineHeight(15)
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.value.length > 0) {
        Text(this.value)
          .fontSize(12)
          .fontColor(this.pal.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: 150 })
          .margin({ left: 12 })
      }
      ZIcon({ path: 'ic_chevron_right', iconSize: 16, color: this.pal.iconMuted })
        .margin({ left: 4 })
    }
    .width('100%')
    .constraintSize({ minHeight: 62 })
    .padding({ left: 20, right: 16, top: 10, bottom: 10 })
    .onClick(() => {
      this.onTap();
    })
  }
}

@Component
struct SettingSwitchRow {
  @Prop pal: Palette;
  @Prop title: string = '';
  @Prop desc: string = '';
  @Prop checked: boolean = false;
  onToggle: (value: boolean) => void = () => {
  };

  build() {
    Row() {
      Column() {
        Text(this.title)
          .fontSize(14)
          .fontColor(this.pal.textPrimary)
        if (this.desc.length > 0) {
          Text(this.desc)
            .fontSize(11)
            .fontColor(this.pal.textTertiary)
            .lineHeight(15)
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      ZSwitch({
        checked: this.checked,
        trackOn: this.pal.accent,
        trackOff: this.pal.surfaceAlt,
        thumbOn: this.pal.onAccent,
        thumbOff: this.pal.textTertiary,
        onToggle: () => {
          this.onToggle(!this.checked);
        }
      })
        .margin({ left: 14 })
    }
    .width('100%')
    .constraintSize({ minHeight: 62 })
    .padding({ left: 20, right: 18, top: 10, bottom: 10 })
  }
}

/** 设置页：外观、浏览、AI 助手、隐私、关于 */
@Component
export struct SettingsView {
  @Prop pal: Palette;
  @Prop dark: boolean = true;
  @State tick: number = 0;
  onClose: () => void = () => {
  };
  onChanged: () => void = () => {
  };
  toast: (text: string) => void = () => {
  };
  dialogChoice: (title: string, options: string[], checked: number,
    onPick: (index: number) => void) => void = () => {
  };
  dialogInput: (title: string, hint: string, initial: string, positive: string,
    onPositive: (text: string) => void) => void = () => {
  };
  dialogConfirm: (title: string, message: string, positive: string,
    onPositive: () => void, danger: boolean) => void = () => {
  };
  dialogAlert: (title: string, message: string) => void = () => {
  };
  onNetLog: () => void = () => {
  };
  checkUpdate: () => void = () => {
  };
  clearCache: () => void = () => {
  };
  clearCookies: () => void = () => {
  };

  private refresh(): void {
    this.tick++;
    this.onChanged();
  }

  private themeLabel(): string {
    const mode: number = Prefs.theme();
    return mode === 1 ? '浅色' : (mode === 2 ? '跟随系统' : '深色');
  }

  private uaLabel(): string {
    const mode: number = Prefs.uaMode();
    if (mode === Prefs.UA_DESKTOP) {
      return '桌面版 Chrome';
    }
    if (mode === Prefs.UA_IPHONE) {
      return 'iPhone';
    }
    if (mode === Prefs.UA_IPAD) {
      return 'iPad';
    }
    if (mode === Prefs.UA_CUSTOM) {
      return '自定义';
    }
    return '默认（OpenHarmony）';
  }

  private chooseTheme(): void {
    const items: string[] = ['深色', '浅色', '跟随系统'];
    this.dialogChoice('主题', items, Prefs.theme(), (which: number) => {
      Prefs.setTheme(which);
      this.refresh();
      this.toast('主题已切换为' + items[which]);
    });
  }

  private chooseTextZoom(): void {
    const values: number[] = [80, 90, 100, 110, 120, 130, 150];
    const labels: string[] = ['小 · 80%', '较小 · 90%', '标准 · 100%', '较大 · 110%',
      '大 · 120%', '很大 · 130%', '特大 · 150%'];
    let checked: number = 2;
    for (let i = 0; i < values.length; i++) {
      if (values[i] === Prefs.textZoom()) {
        checked = i;
      }
    }
    this.dialogChoice('网页字体大小', labels, checked, (which: number) => {
      Prefs.setTextZoom(values[which]);
      this.refresh();
      this.toast('字体大小已设为 ' + values[which].toString() + '%');
    });
  }

  private chooseEngine(): void {
    const names: string[] = [];
    for (const e of SearchEngine.ALL) {
      names.push(e.name);
    }
    this.dialogChoice('选择搜索引擎', names,
      SearchEngine.indexOf(Prefs.searchEngine()), (which: number) => {
        Prefs.setSearchEngine(SearchEngine.ALL[which].id);
        this.refresh();
        this.toast('搜索引擎已切换为 ' + SearchEngine.ALL[which].name);
      });
  }

  private chooseTransLang(): void {
    this.dialogChoice('网页翻译为', BingTranslate.LANGS,
      BingTranslate.indexOf(Prefs.transLang()), (which: number) => {
        Prefs.setTransLang(BingTranslate.codeOf(which));
        this.refresh();
        this.toast('网页将翻译为' + BingTranslate.LANGS[which]);
      });
  }

  private editHomepage(): void {
    this.dialogInput('主页', '留空则使用 Zorme 起始页', Prefs.homepage(), '保存', (text: string) => {
      Prefs.setHomepage(text);
      this.refresh();
      this.toast(Prefs.homepage().length === 0 ? '已恢复默认主页' : '主页已保存');
    });
  }

  private chooseUa(): void {
    const items: string[] = ['默认（OpenHarmony）', '桌面版 Chrome', 'iPhone', 'iPad', '自定义…'];
    this.dialogChoice('浏览器标识 (UA)', items, Prefs.uaMode(), (which: number) => {
      if (which === Prefs.UA_CUSTOM) {
        this.dialogInput('自定义 User-Agent', '输入完整的 UA 字符串，留空恢复默认',
          Prefs.uaCustom(), '保存', (text: string) => {
            if (!text || text.trim().length === 0) {
              Prefs.setUaMode(Prefs.UA_DEFAULT);
              Prefs.setUaCustom('');
            } else {
              Prefs.setUaMode(Prefs.UA_CUSTOM);
              Prefs.setUaCustom(text);
            }
            this.refresh();
            this.toast('浏览器标识已更新');
          });
      } else {
        Prefs.setUaMode(which);
        this.refresh();
        this.toast('浏览器标识已切换为 ' + items[which]);
      }
    });
  }

  private chooseAiProvider(): void {
    const names: string[] = [];
    for (const p of AiProvider.PRESETS) {
      names.push(p.name);
    }
    let checked: number = AiProvider.CUSTOM;
    for (let i = 0; i < AiProvider.PRESETS.length; i++) {
      if (AiProvider.PRESETS[i].baseUrl === Prefs.aiBase()) {
        checked = i;
      }
    }
    this.dialogChoice('AI 服务商', names, checked, (which: number) => {
      const p: AiProvider = AiProvider.PRESETS[which];
      Prefs.setAiBase(p.baseUrl);
      Prefs.setAiModel(p.model);
      this.refresh();
      if (which === AiProvider.CUSTOM) {
        this.dialogInput('API 地址', 'https://api.example.com/v1', Prefs.aiBase(), '保存',
          (text: string) => {
            if (text && text.trim().length > 0) {
              Prefs.setAiBase(text);
            }
            this.refresh();
          });
      } else {
        this.dialogAlert(p.name, '已填入默认接口地址与模型。\n\n地址：' + p.baseUrl
          + '\n模型：' + p.model + '\n\n' + p.note + '\n\n接下来请填写 API Key。');
      }
    });
  }

  build() {
    Column() {
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
        Text('设置')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.pal.textPrimary)
      }
      .width('100%')
      .height(56)
      .padding({ left: 4 })

      Divider().color(this.pal.divider).strokeWidth(1)

      Scroll() {
        Column() {
          this.section('外观')
          SettingTextRow({
            pal: this.pal, title: '主题', desc: '深色 / 浅色 / 跟随系统', value: this.themeLabel(),
            onTap: () => {
              this.chooseTheme();
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })
          SettingTextRow({
            pal: this.pal, title: '网页字体大小', desc: '调整网页正文的缩放比例',
            value: Prefs.textZoom().toString() + '%',
            onTap: () => {
              this.chooseTextZoom();
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })

          this.section('浏览')
          SettingTextRow({
            pal: this.pal, title: '搜索引擎', desc: '地址栏搜索时使用', value: SearchEngine.get().name,
            onTap: () => {
              this.chooseEngine();
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })
          SettingTextRow({
            pal: this.pal, title: '网页翻译', desc: '使用必应翻译，译为目标语言',
            value: BingTranslate.nameOf(Prefs.transLang()),
            onTap: () => {
              this.chooseTransLang();
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })
          SettingTextRow({
            pal: this.pal, title: '主页', desc: '主页按钮和启动页指向的地址',
            value: Prefs.homepage().length === 0 ? '默认主页' : Utils.displayUrl(Prefs.homepage()),
            onTap: () => {
              this.editHomepage();
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })
          SettingSwitchRow({
            pal: this.pal, title: '启动时打开主页', desc: '每次启动浏览器直接进入主页',
            checked: Prefs.openHome(),
            onToggle: (v: boolean) => {
              Prefs.setOpenHome(v);
              this.refresh();
              this.toast(v ? '启动时将打开主页' : '启动时将恢复上次的标签页');
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })
          SettingSwitchRow({
            pal: this.pal, title: '夜间模式', desc: '强制网页使用深色配色',
            checked: Prefs.night(),
            onToggle: (v: boolean) => {
              Prefs.setNight(v);
              this.refresh();
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })
          SettingSwitchRow({
            pal: this.pal, title: '广告拦截', desc: '拦截常见广告与追踪域名',
            checked: Prefs.adblock(),
            onToggle: (v: boolean) => {
              Prefs.setAdblock(v);
              AdBlocker.reload(getContext(this) as common.UIAbilityContext);
              this.refresh();
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })
          SettingSwitchRow({
            pal: this.pal, title: '无图模式', desc: '仅加载文字，节省流量',
            checked: Prefs.noImage(),
            onToggle: (v: boolean) => {
              Prefs.setNoImage(v);
              this.refresh();
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })
          SettingSwitchRow({
            pal: this.pal, title: '桌面版网站', desc: '默认以电脑版 UA 加载网页',
            checked: Prefs.desktop(),
            onToggle: (v: boolean) => {
              Prefs.setDesktop(v);
              this.refresh();
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })
          SettingTextRow({
            pal: this.pal, title: '浏览器标识 (UA)', desc: '网站识别到的浏览器标识',
            value: this.uaLabel(),
            onTap: () => {
              this.chooseUa();
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })
          SettingSwitchRow({
            pal: this.pal, title: 'JavaScript', desc: '关闭后部分网页可能无法正常显示',
            checked: Prefs.javaScript(),
            onToggle: (v: boolean) => {
              Prefs.setJavaScript(v);
              this.refresh();
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })
          SettingSwitchRow({
            pal: this.pal, title: '边缘滑动导航', desc: '在屏幕左右边缘滑动以前进或后退',
            checked: Prefs.gesture(),
            onToggle: (v: boolean) => {
              Prefs.setGesture(v);
              this.refresh();
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })
          SettingSwitchRow({
            pal: this.pal, title: '记录浏览历史', desc: '关闭后不再保存新的历史记录',
            checked: Prefs.recordHistory(),
            onToggle: (v: boolean) => {
              Prefs.setRecordHistory(v);
              this.refresh();
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })
          SettingSwitchRow({
            pal: this.pal, title: '网络日志', desc: '记录网页加载的资源请求（仅保存在内存）',
            checked: Prefs.netLog(),
            onToggle: (v: boolean) => {
              Prefs.setNetLog(v);
              if (!v) {
                NetLog.clear();
              }
              this.refresh();
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })

          this.section('AI 助手')
          SettingTextRow({
            pal: this.pal, title: 'AI 服务商', desc: '内置配置 + 自定义，OpenAI 兼容协议',
            value: AiProvider.currentName(Prefs.aiBase()),
            onTap: () => {
              this.chooseAiProvider();
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })
          SettingTextRow({
            pal: this.pal, title: 'API 地址', desc: 'OpenAI 兼容接口地址，可填根地址或 /v1',
            value: Prefs.aiBase(),
            onTap: () => {
              this.dialogInput('API 地址', '例如 https://open.bigmodel.cn/api/paas/v4',
                Prefs.aiBase(), '保存', (text: string) => {
                  Prefs.setAiBase(text);
                  this.refresh();
                });
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })
          SettingTextRow({
            pal: this.pal, title: 'API Key', desc: '保存在本机，不会上传到任何服务器',
            value: Prefs.aiKey().length === 0 ? '未设置' : '已设置',
            onTap: () => {
              this.dialogInput('API Key', '输入服务商颁发的 API Key', Prefs.aiKey(), '保存',
                (text: string) => {
                  Prefs.setAiKey(text);
                  this.refresh();
                });
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })
          SettingTextRow({
            pal: this.pal, title: '模型', desc: '服务商支持的模型名称', value: Prefs.aiModel(),
            onTap: () => {
              this.dialogInput('模型', '例如 glm-4-flash、deepseek-chat', Prefs.aiModel(), '保存',
                (text: string) => {
                  Prefs.setAiModel(text);
                  this.refresh();
                });
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })

          this.section('隐私与数据')
          SettingTextRow({
            pal: this.pal, title: '用户协议与隐私政策', desc: '开源项目 · 无云服务 · 数据仅存本机',
            value: '',
            onTap: () => {
              this.dialogAlert(Agreement.title(), Agreement.fullText());
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })
          SettingTextRow({
            pal: this.pal, title: '清除缓存', desc: '清除网页缓存文件（不影响书签）', value: '',
            onTap: () => {
              this.dialogConfirm('清除缓存', '将删除网页缓存，不影响书签和登录状态。', '清除', () => {
                this.clearCache();
                this.toast('缓存已清除');
              }, true);
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })
          SettingTextRow({
            pal: this.pal, title: '清除 Cookie', desc: '退出所有网站的登录状态', value: '',
            onTap: () => {
              this.dialogConfirm('清除 Cookie', '将退出所有网站的登录状态。', '清除', () => {
                this.clearCookies();
                this.toast('Cookie 已清除');
              }, true);
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })
          SettingTextRow({
            pal: this.pal, title: '清除历史记录', desc: '删除全部浏览记录', value: '',
            onTap: () => {
              this.dialogConfirm('清除历史记录', '将删除全部浏览历史，无法恢复。', '清除', () => {
                Store.clearHistory();
                this.toast('历史记录已清除');
              }, true);
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })
          SettingTextRow({
            pal: this.pal, title: '清除全部数据', desc: '缓存、Cookie、本地存储与历史记录', value: '',
            onTap: () => {
              this.dialogConfirm('清除全部浏览数据',
                '将清除缓存、Cookie、本地存储和历史记录，书签会保留。', '清除', () => {
                  this.clearCache();
                  this.clearCookies();
                  Store.clearHistory();
                  this.toast('所有数据已清除');
                }, true);
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })

          this.section('关于')
          SettingTextRow({
            pal: this.pal, title: '网络日志', desc: '查看当前标签页的网络请求记录', value: '',
            onTap: () => {
              this.onNetLog();
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })
          SettingTextRow({
            pal: this.pal, title: '检查更新', desc: '拉取 GitHub 最新发布版本对比', value: '1.1.0',
            onTap: () => {
              this.checkUpdate();
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })
          SettingTextRow({
            pal: this.pal, title: '关于 Zorme', desc: '基于 OpenHarmony ArkWeb 的轻量浏览器', value: '',
            onTap: () => {
              this.dialogAlert('Zorme 浏览器', '版本 1.1.0\n\n'
                + '基于 OpenHarmony ArkWeb 构建的轻量浏览器。\n\n'
                + '· 多标签浏览与标签恢复\n· 广告与追踪域名拦截\n'
                + '· 夜间模式 / 无图模式 / 浏览器标识(UA)\n'
                + '· 阅读模式与页内查找\n· 网页源码查看、网络日志抓取\n'
                + '· 无痕浏览、书签、历史、下载管理\n· 底部地址栏与自绘弹窗体系\n'
                + '· 应用内检测更新\n\n'
                + '本项目为开源软件，无云服务、无账号体系，所有数据仅保存在本机。\n'
                + '源码：github.com/lmxdg/ZormeBrowser-OpenHarmony');
            }
          })
          Divider().color(this.pal.divider).strokeWidth(1).margin({ left: 20 })

          Text('Zorme 浏览器 · OpenHarmony ArkWeb\n轻量、干净、不打扰')
            .fontSize(10)
            .fontColor(this.pal.textTertiary)
            .textAlign(TextAlign.Center)
            .lineHeight(16)
            .width('100%')
            .margin({ top: 36, bottom: 24 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pal.bg)
  }

  @Builder
  section(title: string) {
    Text(title)
      .fontSize(11)
      .fontColor(this.pal.textTertiary)
      .letterSpacing(1)
      .width('100%')
      .padding({ left: 20, right: 20, top: 24, bottom: 6 })
  }
}
