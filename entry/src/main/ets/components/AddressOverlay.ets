import { Palette } from '../common/Theme';
import { SuggestionItem } from './Models';
import { ZIcon } from './ZIcon';

/** 地址栏编辑浮层：输入 + 本地历史/书签/搜索建议 */
@Component
export struct AddressOverlay {
  @Prop pal: Palette;
  @Prop text: string = '';
  @Prop suggestions: SuggestionItem[] = [];
  onTextChange: (value: string) => void = () => {
  };
  onSubmit: () => void = () => {
  };
  onCancel: () => void = () => {
  };
  onPick: (url: string) => void = () => {
  };

  aboutToAppear(): void {
    setTimeout(() => {
      focusControl.requestFocus('zorme_address_input');
    }, 150);
  }

  private iconOf(kind: string): string {
    if (kind === 'search') {
      return 'ic_search';
    }
    if (kind === 'history') {
      return 'ic_history';
    }
    if (kind === 'bookmark') {
      return 'ic_star';
    }
    return 'ic_globe';
  }

  build() {
    Column() {
      Row() {
        ZIcon({ path: 'ic_search', iconSize: 18, color: this.pal.iconMuted })
        TextInput({ text: this.text, placeholder: '搜索或输入网址' })
          .id('zorme_address_input')
          .layoutWeight(1)
          .height('100%')
          .margin({ left: 12 })
          .fontSize(16)
          .fontColor(this.pal.textPrimary)
          .placeholderColor(this.pal.textTertiary)
          .backgroundColor(Color.Transparent)
          .caretColor(this.pal.textPrimary)
          .enterKeyType(EnterKeyType.Go)
          .maxLines(1)
          .caretPosition(this.text.length)
          .onChange((value: string) => {
            this.onTextChange(value);
          })
          .onSubmit(() => {
            this.onSubmit();
          })

        Text('取消')
          .fontSize(14)
          .fontColor(this.pal.textSecondary)
          .height(40)
          .padding({ left: 10, right: 4 })
          .onClick(() => {
            this.onCancel();
          })
      }
      .width('100%')
      .height(58)
      .padding({ left: 14, right: 14 })

      Divider()
        .color(this.pal.divider)
        .strokeWidth(1)

      List() {
        ForEach(this.suggestions, (item: SuggestionItem) => {
          ListItem() {
            Row() {
              ZIcon({ path: this.iconOf(item.kind), iconSize: 18,
                color: item.kind === 'search' ? this.pal.textPrimary : this.pal.iconMuted })
              Column() {
                Text(item.title)
                  .fontSize(14)
                  .fontColor(this.pal.textPrimary)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(item.subtitle)
                  .fontSize(11)
                  .fontColor(this.pal.textTertiary)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              .margin({ left: 14 })

              Text(item.badge)
                .fontSize(10)
                .fontColor(this.pal.textSecondary)
                .backgroundColor(this.pal.surfaceAlt)
                .borderRadius(8)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            }
            .width('100%')
            .height(56)
            .padding({ left: 20, right: 16 })
          }
          .onClick(() => {
            this.onPick(item.url);
          })
        }, (item: SuggestionItem, index: number) => item.kind + index.toString() + item.url)
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
}
