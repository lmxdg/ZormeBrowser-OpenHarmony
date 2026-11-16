import { pasteboard } from '@kit.BasicServicesKit';
import { Palette } from '../common/Theme';
import { Utils } from '../common/Utils';
import { ZIcon } from './ZIcon';

/** 网页源码查看 */
@Component
export struct SourceView {
  @Prop pal: Palette;
  @Prop title: string = '';
  @Prop content: string = '';
  onClose: () => void = () => {
  };
  toast: (text: string) => void = () => {
  };

  private copyAll(): void {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.content);
      pasteboard.getSystemPasteboard().setData(data).then(() => {
        this.toast('源码已复制到剪贴板');
      }).catch(() => {
        this.toast('复制失败');
      });
    } catch (e) {
      this.toast('复制失败');
    }
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
          Text('网页源码')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.pal.textPrimary)
          Text(Utils.displayUrl(this.title))
            .fontSize(10)
            .fontColor(this.pal.textTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('复制')
          .fontSize(13)
          .fontColor(this.pal.textPrimary)
          .padding({ left: 12, right: 16 })
          .onClick(() => {
            this.copyAll();
          })
      }
      .width('100%')
      .height(56)

      Divider().color(this.pal.divider).strokeWidth(1)

      Scroll() {
        Text(this.content)
          .fontSize(12)
          .fontFamily('monospace')
          .fontColor(this.pal.textSecondary)
          .lineHeight(18)
          .width('100%')
          .padding({ left: 16, right: 16, top: 14, bottom: 30 })
          .copyOption(CopyOptions.LocalDevice)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.None)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pal.bg)
  }
}
