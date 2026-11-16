import { Palette } from '../common/Theme';
import { Utils } from '../common/Utils';
import { Store, BookmarkItem, HistoryItem, DownloadItem } from '../model/Store';
import { ZIcon } from './ZIcon';

/** 列表行（书签 / 历史 / 下载统一结构） */
class RowItem {
  id: number = 0;
  title: string = '';
  url: string = '';
  sub: string = '';
  letter: string = '';
  color: string = '#3A3A44';
  header: string = '';
  state: number = 1;
  percent: number = 0;
  time: number = 0;
}

/** 书签 / 历史 / 下载 列表页 */
@Component
export struct ListView {
  @Prop pal: Palette;
  @Prop mode: string = 'bookmarks';
  onClose: () => void = () => {
  };
  onOpen: (url: string) => void = () => {
  };
  toast: (text: string) => void = () => {
  };
  confirm: (title: string, message: string, positive: string, cb: () => void) => void = () => {
  };

  @State rows: RowItem[] = [];
  @State keyword: string = '';

  aboutToAppear(): void {
    this.reload();
  }

  private titleOfMode(): string {
    if (this.mode === 'history') {
      return '历史记录';
    }
    if (this.mode === 'downloads') {
      return '下载内容';
    }
    return '书签';
  }

  private emptyText(): string {
    if (this.keyword.trim().length > 0) {
      return '没有匹配的结果';
    }
    if (this.mode === 'history') {
      return '还没有浏览记录';
    }
    if (this.mode === 'downloads') {
      return '还没有下载文件';
    }
    return '还没有添加书签';
  }

  private reload(): void {
    const list: RowItem[] = [];
    const k: string = this.keyword.trim().toLowerCase();
    if (this.mode === 'downloads') {
      const all: DownloadItem[] = Store.allDownloads();
      for (const d of all) {
        if (k.length > 0 &&
          !d.title.toLowerCase().includes(k) && !d.url.toLowerCase().includes(k)) {
          continue;
        }
        const r: RowItem = new RowItem();
        r.id = d.id;
        r.title = d.title.length > 0 ? d.title : Utils.guessFileName(d.url, '', '');
        r.url = d.url;
        r.sub = this.downloadSub(d);
        r.letter = 'D';
        r.color = Utils.colorFor(d.url);
        r.state = d.state;
        r.percent = d.percent;
        r.time = d.time;
        r.header = '';
        list.push(r);
      }
      this.rows = list;
      return;
    }

    if (this.mode === 'history') {
      const all: HistoryItem[] = Store.findHistory(this.keyword, 400);
      let lastDate: string = '';
      for (const h of all) {
        const r: RowItem = new RowItem();
        r.id = h.id;
        r.title = h.title.length > 0 ? h.title : Utils.titleOf(h.url);
        r.url = h.url;
        r.sub = Utils.displayUrl(h.url) + ' · ' + Utils.formatTime(h.visited);
        r.letter = Utils.letterOf(r.title);
        r.color = Utils.colorFor(h.url);
        r.time = h.visited;
        const day: string = Utils.formatDate(h.visited);
        if (day !== lastDate) {
          r.header = day;
          lastDate = day;
        }
        list.push(r);
      }
      this.rows = list;
      return;
    }

    const marks: BookmarkItem[] = Store.findBookmarks(this.keyword);
    for (const b of marks) {
      const r: RowItem = new RowItem();
      r.id = b.id;
      r.title = b.title.length > 0 ? b.title : Utils.titleOf(b.url);
      r.url = b.url;
      r.sub = Utils.displayUrl(b.url);
      r.letter = Utils.letterOf(r.title);
      r.color = Utils.colorFor(b.url);
      r.time = b.created;
      r.header = '';
      list.push(r);
    }
    this.rows = list;
  }

  private downloadSub(d: DownloadItem): string {
    if (d.state === 0) {
      const total: string = d.total > 0 ? ' / ' + Utils.formatSize(d.total) : '';
      return '下载中 ' + d.percent.toString() + '% · ' + Utils.formatSize(d.size) + total;
    }
    if (d.state === 2) {
      return '下载失败';
    }
    const size: string = d.total > 0 ? Utils.formatSize(d.total) : Utils.formatSize(d.size);
    return size + ' · ' + Utils.formatTime(d.time);
  }

  private removeOne(item: RowItem): void {
    if (this.mode === 'downloads') {
      this.confirm('删除记录', '确定从列表中删除「' + item.title + '」？', '删除', () => {
        Store.removeDownload(item.id);
        this.reload();
      });
      return;
    }
    if (this.mode === 'history') {
      Store.removeHistory(item.id);
      this.reload();
      this.toast('已删除该记录');
      return;
    }
    this.confirm('删除书签', '确定删除「' + item.title + '」？', '删除', () => {
      Store.removeBookmark(item.id);
      this.reload();
      this.toast('已删除书签');
    });
  }

  private clearAll(): void {
    if (this.mode === 'history') {
      this.confirm('清空历史记录', '将删除全部浏览记录，操作不可恢复。', '清空', () => {
        Store.clearHistory();
        this.reload();
        this.toast('历史记录已清空');
      });
      return;
    }
    if (this.mode === 'downloads') {
      this.confirm('清空下载记录', '仅清除列表记录，已下载的文件不会被删除。', '清空', () => {
        Store.clearDownloads();
        this.reload();
        this.toast('下载记录已清空');
      });
    }
  }

  private open(item: RowItem): void {
    if (this.mode === 'downloads') {
      if (item.state === 2) {
        this.toast('该文件下载失败');
        return;
      }
      this.toast('文件已保存：' + (item.url.length > 0 ? Utils.guessFileName(item.url, '', '') : item.title));
      return;
    }
    this.onOpen(item.url);
  }

  @Builder
  rowView(item: RowItem) {
    Column() {
      if (item.header.length > 0) {
        Text(item.header)
          .fontSize(11)
          .fontColor(this.pal.textTertiary)
          .width('100%')
          .padding({ left: 20, right: 20, top: 14, bottom: 6 })
      }
      Row() {
        if (this.mode === 'downloads') {
          Column() {
            ZIcon({ path: 'ic_download', iconSize: 17, color: this.pal.iconMuted })
          }
          .width(36)
          .height(36)
          .borderRadius(10)
          .backgroundColor(this.pal.surfaceAlt)
          .justifyContent(FlexAlign.Center)
          .margin({ right: 12 })
        } else {
          Text(item.letter)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .width(36)
            .height(36)
            .borderRadius(10)
            .backgroundColor(item.color)
            .textAlign(TextAlign.Center)
            .margin({ right: 12 })
        }

        Column() {
          Text(item.title)
            .fontSize(14)
            .fontColor(this.pal.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(item.sub)
            .fontSize(11)
            .fontColor(this.pal.textTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 3 })
            .width('100%')
          if (this.mode === 'downloads' && item.state === 0) {
            Progress({ value: item.percent, total: 100, type: ProgressType.Linear })
              .width('100%')
              .height(2)
              .color(this.pal.textPrimary)
              .backgroundColor(this.pal.surfaceAlt)
              .margin({ top: 6 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Row() {
          ZIcon({ path: 'ic_close', iconSize: 14, color: this.pal.iconMuted })
        }
        .width(32)
        .height(32)
        .justifyContent(FlexAlign.Center)
        .margin({ left: 4 })
        .onClick(() => {
          this.removeOne(item);
        })
      }
      .width('100%')
      .padding({ left: 20, right: 12, top: 10, bottom: 10 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .onClick(() => {
      this.open(item);
    })
    .gesture(LongPressGesture().onAction(() => {
      this.removeOne(item);
    }))
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

        Text(this.titleOfMode())
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.pal.textPrimary)
          .layoutWeight(1)

        if (this.rows.length > 0 && this.mode !== 'bookmarks') {
          Text('清空')
            .fontSize(13)
            .fontColor(this.pal.textSecondary)
            .padding({ left: 10, right: 16, top: 12, bottom: 12 })
            .onClick(() => {
              this.clearAll();
            })
        }
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)

      Row() {
        ZIcon({ path: 'ic_search', iconSize: 15, color: this.pal.iconMuted })
          .margin({ left: 12, right: 8 })
        TextInput({ text: this.keyword, placeholder: '搜索' })
          .placeholderColor(this.pal.textTertiary)
          .placeholderFont({ size: 13 })
          .fontSize(13)
          .fontColor(this.pal.textPrimary)
          .backgroundColor(Color.Transparent)
          .padding({ left: 0, right: 0 })
          .height(36)
          .layoutWeight(1)
          .onChange((value: string) => {
            this.keyword = value;
            this.reload();
          })
        if (this.keyword.length > 0) {
          Row() {
            ZIcon({ path: 'ic_close', iconSize: 12, color: this.pal.iconMuted })
          }
          .width(30)
          .height(30)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.keyword = '';
            this.reload();
          })
        }
      }
      .width('100%')
      .height(38)
      .backgroundColor(this.pal.surfaceAlt)
      .borderRadius(19)
      .margin({ left: 16, right: 16, bottom: 8 })
      .padding({ right: 4 })

      Divider().color(this.pal.divider).strokeWidth(0.5)

      if (this.rows.length === 0) {
        Column() {
          ZIcon({
            path: this.mode === 'downloads' ? 'ic_download' :
              (this.mode === 'history' ? 'ic_history' : 'ic_star'),
            iconSize: 30,
            color: this.pal.textTertiary
          })
          Text(this.emptyText())
            .fontSize(13)
            .fontColor(this.pal.textTertiary)
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.rows, (item: RowItem) => {
            ListItem() {
              this.rowView(item)
            }
          }, (item: RowItem) => this.mode + '_' + item.id.toString())
        }
        .layoutWeight(1)
        .width('100%')
        .divider({ strokeWidth: 0.5, color: this.pal.divider, startMargin: 68, endMargin: 16 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .padding({ bottom: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pal.bg)
  }
}
