import { Palette } from '../common/Theme';
import { ZIcon } from './ZIcon';

export class MenuTile {
  icon: string = '';
  label: string = '';
  action: string = '';

  constructor(icon: string, label: string, action: string) {
    this.icon = icon;
    this.label = label;
    this.action = action;
  }
}

/** 底部菜单面板：16 个功能入口 */
@Component
export struct MenuSheet {
  @Prop pal: Palette;
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop bookmarked: boolean = false;
  @Prop night: boolean = false;
  @Prop noImage: boolean = false;
  @Prop desktop: boolean = false;
  onAction: (action: string) => void = () => {
  };
  onClose: () => void = () => {
  };

  private tiles(): MenuTile[] {
    const list: MenuTile[] = [];
    list.push(new MenuTile('ic_ai', 'AI 助手', 'ai'));
    list.push(new MenuTile('ic_refresh', '刷新', 'refresh'));
    list.push(new MenuTile('ic_home', '主页', 'home'));
    list.push(new MenuTile(this.bookmarked ? 'ic_star_filled' : 'ic_star',
      this.bookmarked ? '已收藏' : '书签', 'bookmark'));
    list.push(new MenuTile('ic_history', '历史', 'history'));
    list.push(new MenuTile('ic_download', '下载', 'downloads'));
    list.push(new MenuTile('ic_moon', this.night ? '日间' : '夜间', 'night'));
    list.push(new MenuTile('ic_no_image', this.noImage ? '显示图片' : '无图', 'noimage'));
    list.push(new MenuTile('ic_desktop', this.desktop ? '手机版' : '桌面版', 'desktop'));
    list.push(new MenuTile('ic_search', '页内查找', 'find'));
    list.push(new MenuTile('ic_reader', '阅读模式', 'reader'));
    list.push(new MenuTile('ic_translate', '翻译网页', 'translate'));
    list.push(new MenuTile('ic_code', '网页源码', 'source'));
    list.push(new MenuTile('ic_lock', '网站证书', 'ssl'));
    list.push(new MenuTile('ic_share', '分享', 'share'));
    list.push(new MenuTile('ic_settings', '设置', 'settings'));
    return list;
  }

  build() {
    Column() {
      Row()
        .width(36)
        .height(4)
        .borderRadius(2)
        .backgroundColor(this.pal.divider)
        .margin({ bottom: 12 })

      Row() {
        Column() {
          Text(this.title)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.pal.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.subtitle)
            .fontSize(11)
            .fontColor(this.pal.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Row() {
          ZIcon({ path: 'ic_close', iconSize: 18, color: this.pal.iconMuted })
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.onClose();
        })
      }
      .width('100%')
      .padding({ bottom: 10 })

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(this.tiles(), (tile: MenuTile) => {
          Column() {
            ZIcon({ path: tile.icon, iconSize: 22, color: this.pal.icon })
            Text(tile.label)
              .fontSize(10)
              .fontColor(this.pal.textSecondary)
              .maxLines(1)
              .margin({ top: 7 })
          }
          .width('25%')
          .height(62)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .padding({ left: 3, right: 3 })
          .onClick(() => {
            this.onAction(tile.action);
          })
        }, (tile: MenuTile) => tile.action)
      }
      .width('100%')

      Row({ space: 10 }) {
        Text('新建标签页')
          .fontSize(13)
          .fontColor(this.pal.textPrimary)
          .layoutWeight(1)
          .height(44)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.pal.surfaceAlt)
          .borderRadius(12)
          .onClick(() => {
            this.onAction('newtab');
          })
        Text('新建无痕标签页')
          .fontSize(13)
          .fontColor(this.pal.textPrimary)
          .layoutWeight(1)
          .height(44)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.pal.surfaceAlt)
          .borderRadius(12)
          .onClick(() => {
            this.onAction('newincognito');
          })
      }
      .width('100%')
      .margin({ top: 10 })
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 10, bottom: 18 })
    .backgroundColor(this.pal.sheet)
    .borderRadius({ topLeft: 22, topRight: 22 })
  }
}
