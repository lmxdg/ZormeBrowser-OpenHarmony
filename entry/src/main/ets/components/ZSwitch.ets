/** 自绘开关，替代系统 Switch，保持与整体界面一致 */
@Component
export struct ZSwitch {
  @Prop checked: boolean;
  @Prop trackOn: string = '#EDEDF0';
  @Prop trackOff: string = '#3A3A44';
  @Prop thumbOn: string = '#0B0B0E';
  @Prop thumbOff: string = '#FFFFFF';
  onToggle: () => void = () => {
  };

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Row()
        .width(46)
        .height(28)
        .borderRadius(14)
        .backgroundColor(this.checked ? this.trackOn : this.trackOff)

      Row()
        .width(22)
        .height(22)
        .borderRadius(11)
        .backgroundColor(this.checked ? this.thumbOn : this.thumbOff)
        .margin({ left: this.checked ? 21 : 3 })
        .shadow({ radius: 3, color: '#33000000', offsetY: 1 })
        .animation({ duration: 170, curve: Curve.EaseOut })
    }
    .width(46)
    .height(28)
    .onClick(() => {
      this.onToggle();
    })
  }
}
