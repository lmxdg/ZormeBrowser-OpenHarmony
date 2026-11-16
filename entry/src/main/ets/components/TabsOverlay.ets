import { Palette } from '../common/Theme';
import { Utils } from '../common/Utils';
import { TabMeta } from '../model/TabMeta';
import { ZIcon } from './ZIcon';

/** 标签页管理：卡片式预览 + 新建 / 关闭 */
@Component
export struct TabsOverlay {
  @Prop pal: Palette;
  @Prop tabs: TabMeta[] = [];
  @Prop current: number = 0;
  onSelect: (index: number) => void = () => {
  };
  onClose: (index: number) => void = () => {
  };
  onNew: (incognito: boolean) => void = () => {
  };
  onDismiss: () => void = () => {
  };

  build() {
    Column() {
      Row() {
        Text('标签页 · ' + this.tabs.length.toString())
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.pal.textPrimary)
          .layoutWeight(1)

        Row() {
          ZIcon({ path: 'ic_close', iconSize: 22, color: this.pal.icon })
        }
        .width(44)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.onDismiss();
        })
      }
      .width('100%')
      .height(60)
      .padding({ left: 20, right: 10 })

      Grid() {
        ForEach(this.tabs, (tab: TabMeta, index: number) => {
          GridItem() {
            Column() {
              Row() {
                Text(tab.displayTitle())
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.pal.textPrimary)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)

                Row() {
                  ZIcon({ path: 'ic_close', iconSize: 14, color: this.pal.iconMuted })
                }
                .width(28)
                .height(28)
                .justifyContent(FlexAlign.Center)
                .onClick(() => {
                  this.onClose(index);
                })
              }
              .width('100%')

              Text(tab.showingHome ? '新标签页' : Utils.displayUrl(tab.url))
                .fontSize(9)
                .fontColor(this.pal.textTertiary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
                .margin({ top: 1 })

              Stack({ alignContent: Alignment.Center }) {
                Row()
                  .width('100%')
                  .height('100%')
                  .backgroundColor(Utils.colorFor(tab.url ? tab.url : 'Zorme'))
                Text(Utils.letterOf(tab.url ? Utils.domainOf(tab.url) : 'Z'))
                  .fontSize(30)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#F2FFFFFF')
              }
              .width('100%')
              .height(74)
              .borderRadius(10)
              .clip(true)
              .margin({ top: 9 })

              if (tab.incognito) {
                Text('无痕')
                  .fontSize(9)
                  .fontColor(this.pal.textSecondary)
                  .backgroundColor(this.pal.surfaceAlt)
                  .borderRadius(8)
                  .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                  .margin({ top: 8 })
              }
            }
            .width('100%')
            .padding({ left: 12, right: 8, top: 10, bottom: 12 })
            .backgroundColor(this.pal.surface)
            .borderRadius(16)
            .border({ width: index === this.current ? 1.5 : 1,
              color: index === this.current ? this.pal.textPrimary : this.pal.divider })
            .alignItems(HorizontalAlign.Start)
            .onClick(() => {
              this.onSelect(index);
            })
          }
          .margin(5)
        }, (tab: TabMeta) => tab.id.toString())
      }
      .columnsTemplate('1fr 1fr')
      .columnsGap(0)
      .rowsGap(0)
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 7, right: 7 })
      .scrollBar(BarState.Off)

      Row({ space: 12 }) {
        Text('新建标签页')
          .fontSize(14)
          .fontColor(this.pal.textPrimary)
          .height(46)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.pal.surfaceAlt)
          .borderRadius(14)
          .onClick(() => {
            this.onNew(false);
          })
        Text('新建无痕标签页')
          .fontSize(14)
          .fontColor(this.pal.textPrimary)
          .height(46)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.pal.surfaceAlt)
          .borderRadius(14)
          .onClick(() => {
            this.onNew(true);
          })
      }
      .width('100%')
      .height(64)
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pal.bg)
  }
}
