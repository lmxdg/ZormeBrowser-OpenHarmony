/** 基于 rawfile SVG 的单色图标 */
@Component
export struct ZIcon {
  @Prop path: string;
  @Prop iconSize: number = 22;
  @Prop color: string = '#000000';

  build() {
    Image($rawfile('icons/' + this.path + '.svg'))
      .width(this.iconSize)
      .height(this.iconSize)
      .fillColor(this.color)
      .objectFit(ImageFit.Contain)
      .draggable(false)
      .hitTestBehavior(HitTestMode.None)
  }
}
