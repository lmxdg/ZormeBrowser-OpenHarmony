import { Palette } from '../common/Theme';
import { Utils } from '../common/Utils';
import { NetLog, NetLogItem } from '../model/NetLog';
import { ZIcon } from './ZIcon';

/** 网络日志（仅内存） */
@Component
export struct NetLogView {
  @Prop pal: Palette;
  @State items: NetLogItem[] = [];
  onClose: () => void = () => {
  };
  toast: (text: string) => void = () => {
  };

  aboutToAppear(): void {
    this.items = NetLog.all();
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

        Column() {
          Text('网络日志')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.pal.textPrimary)
          Text('共 ' + this.items.length.toString() + ' 条 · 仅存内存')
            .fontSize(10)
            .fontColor(this.pal.textTertiary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('清空')
          .fontSize(13)
          .fontColor(this.pal.textSecondary)
          .padding({ left: 12, right: 16 })
          .onClick(() => {
            NetLog.clear();
            this.items = [];
            this.toast('网络日志已清空');
          })
      }
      .width('100%')
      .height(56)

      Divider().color(this.pal.divider).strokeWidth(1)

      if (this.items.length === 0) {
        Column() {
          Text('暂无网络请求记录')
            .fontSize(13)
            .fontColor(this.pal.textTertiary)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.items, (item: NetLogItem) => {
            ListItem() {
              Column() {
                Row() {
                  Text(item.method)
                    .fontSize(9)
                    .fontColor(item.blocked ? this.pal.danger : this.pal.textSecondary)
                    .backgroundColor(this.pal.surfaceAlt)
                    .borderRadius(4)
                    .padding({ left: 5, right: 5, top: 2, bottom: 2 })
                  Text(item.mainFrame ? '主文档' : '子资源')
                    .fontSize(9)
                    .fontColor(this.pal.textTertiary)
                    .margin({ left: 6 })
                  Text(Utils.formatTime(item.time))
                    .fontSize(9)
                    .fontColor(this.pal.textTertiary)
                    .margin({ left: 6 })
                  if (item.blocked) {
                    Text('已拦截')
                      .fontSize(9)
                      .fontColor(this.pal.danger)
                      .margin({ left: 6 })
                  }
                }
                .width('100%')

                Text(item.url)
                  .fontSize(11)
                  .fontColor(this.pal.textSecondary)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                  .margin({ top: 4 })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .alignItems(HorizontalAlign.Start)
            }
          }, (item: NetLogItem, index: number) => index.toString() + item.time.toString())
        }
        .layoutWeight(1)
        .width('100%')
        .divider({ strokeWidth: 1, color: this.pal.divider })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pal.bg)
  }
}
