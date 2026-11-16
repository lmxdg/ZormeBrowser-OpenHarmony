import { Palette } from '../common/Theme';
import { Utils } from '../common/Utils';
import { ZIcon } from './ZIcon';

/** 起始页：徽标、搜索、AI 入口、常用网站 */
@Component
export struct HomeView {
  @Prop pal: Palette;
  @Prop incognito: boolean = false;
  onSearch: () => void = () => {
  };
  onAi: () => void = () => {
  };
  onShortcut: (url: string) => void = () => {
  };
  onList: (mode: string) => void = () => {
  };

  private shortcuts: string[][] = [
    ['百度', 'https://m.baidu.com'],
    ['知乎', 'https://www.zhihu.com'],
    ['哔哩哔哩', 'https://m.bilibili.com'],
    ['微博', 'https://m.weibo.cn'],
    ['GitHub', 'https://github.com'],
    ['淘宝', 'https://m.taobao.com'],
    ['豆瓣', 'https://m.douban.com'],
    ['维基百科', 'https://zh.m.wikipedia.org']
  ];

  @Builder
  listEntry(icon: string, label: string, mode: string) {
    Column() {
      ZIcon({ path: icon, iconSize: 19, color: this.pal.icon })
      Text(label)
        .fontSize(11)
        .fontColor(this.pal.textSecondary)
        .margin({ top: 6 })
    }
    .layoutWeight(1)
    .padding({ top: 8, bottom: 8 })
    .onClick(() => {
      this.onList(mode);
    })
  }

  build() {
    Scroll() {
      Column() {
        ZIcon({ path: 'ic_zorme_mark', iconSize: 58, color: this.pal.textPrimary })
          .margin({ top: 8 })

        Text('Zorme')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.pal.textPrimary)
          .letterSpacing(5)
          .margin({ top: 14 })

        Text('轻快 · 干净 · 属于你的浏览器')
          .fontSize(11)
          .fontColor(this.pal.textTertiary)
          .letterSpacing(1)
          .margin({ top: 6 })

        Row() {
          ZIcon({ path: 'ic_search', iconSize: 18, color: this.pal.textSecondary })
          Text('搜索或输入网址')
            .fontSize(14)
            .fontColor(this.pal.textTertiary)
            .margin({ left: 12 })
            .layoutWeight(1)
        }
        .width('100%')
        .height(52)
        .padding({ left: 18, right: 18 })
        .backgroundColor(this.pal.surface)
        .borderRadius(20)
        .border({ width: 1, color: this.pal.divider })
        .margin({ top: 34 })
        .onClick(() => {
          this.onSearch();
        })

        Row() {
          ZIcon({ path: 'ic_ai', iconSize: 18, color: this.pal.textPrimary })
          Text('AI 助手')
            .fontSize(14)
            .fontColor(this.pal.textPrimary)
            .margin({ left: 12 })
            .layoutWeight(1)
          Text('OpenAI 兼容 · 可配置')
            .fontSize(11)
            .fontColor(this.pal.textTertiary)
        }
        .width('100%')
        .height(52)
        .padding({ left: 18, right: 18 })
        .backgroundColor(this.pal.surface)
        .borderRadius(20)
        .border({ width: 1, color: this.pal.divider })
        .margin({ top: 12 })
        .onClick(() => {
          this.onAi();
        })

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach(this.shortcuts, (site: string[]) => {
            Column() {
              Stack({ alignContent: Alignment.Center }) {
                Row()
                  .width(50)
                  .height(50)
                  .borderRadius(16)
                  .backgroundColor(Utils.colorFor(site[0]))
                Text(Utils.letterOf(site[0]))
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFFFF')
              }

              Text(site[0])
                .fontSize(11)
                .fontColor(this.pal.textSecondary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 7 })
            }
            .width('25%')
            .padding({ top: 8, bottom: 8 })
            .onClick(() => {
              this.onShortcut(site[1]);
            })
          }, (site: string[]) => site[0])
        }
        .width('100%')
        .margin({ top: 26 })

        Row() {
          this.listEntry('ic_star', '书签', 'bookmarks')
          this.listEntry('ic_history', '历史', 'history')
          this.listEntry('ic_download', '下载', 'downloads')
        }
        .width('100%')
        .margin({ top: 18 })
        .padding({ top: 6, bottom: 6 })
        .backgroundColor(this.pal.surface)
        .borderRadius(18)
        .border({ width: 1, color: this.pal.divider })

        Text(this.incognito ? '无痕浏览中 · 不记录历史与 Cookie' : '广告拦截已开启 · 不追踪你的浏览')
          .fontSize(10)
          .fontColor(this.pal.textTertiary)
          .textAlign(TextAlign.Center)
          .lineHeight(16)
          .margin({ top: 30 })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 28, bottom: 28 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .backgroundColor(this.pal.bg)
  }
}
