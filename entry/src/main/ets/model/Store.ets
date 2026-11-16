import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export class BookmarkItem {
  id: number = 0;
  title: string = '';
  url: string = '';
  created: number = 0;
}

export class HistoryItem {
  id: number = 0;
  title: string = '';
  url: string = '';
  visited: number = 0;
  visits: number = 1;
}

export class DownloadItem {
  id: number = 0;
  title: string = '';
  url: string = '';
  path: string = '';
  size: number = 0;
  total: number = 0;
  time: number = 0;
  state: number = 0; // 0 下载中 1 完成 2 失败
  percent: number = 0;
}

export class SessionItem {
  url: string = '';
  title: string = '';
}

/**
 * 本地数据存储：书签 / 历史 / 下载 / 会话。
 * 使用 preferences 持久化 JSON，数据仅保存在本机。
 */
export class Store {
  private static store: preferences.Preferences | null = null;
  private static bookmarks: BookmarkItem[] = [];
  private static historyItems: HistoryItem[] = [];
  private static downloadItems: DownloadItem[] = [];
  private static seq: number = 1;

  private static readonly KEY_BOOKMARKS: string = 'bookmarks_json';
  private static readonly KEY_HISTORY: string = 'history_json';
  private static readonly KEY_DOWNLOADS: string = 'downloads_json';
  private static readonly KEY_SEQ: string = 'seq';
  private static readonly KEY_SESSION: string = 'session_json';
  private static readonly KEY_SESSION_CUR: string = 'session_current';

  static async init(ctx: common.UIAbilityContext): Promise<void> {
    Store.store = await preferences.getPreferences(ctx, 'zorme_data');
    Store.seq = Store.store.getSync(Store.KEY_SEQ, 1) as number;
    Store.bookmarks = Store.readArray<BookmarkItem>(Store.KEY_BOOKMARKS);
    Store.historyItems = Store.readArray<HistoryItem>(Store.KEY_HISTORY);
    Store.downloadItems = Store.readArray<DownloadItem>(Store.KEY_DOWNLOADS);
  }

  private static readArray<T>(key: string): T[] {
    if (Store.store === null) {
      return [];
    }
    const text: string = Store.store.getSync(key, '[]') as string;
    if (!text) {
      return [];
    }
    try {
      return JSON.parse(text) as T[];
    } catch (e) {
      return [];
    }
  }

  private static write(key: string, value: string): void {
    if (Store.store === null) {
      return;
    }
    Store.store.putSync(key, value);
    Store.store.flush().then(() => {
    }).catch(() => {
    });
  }

  private static nextId(): number {
    Store.seq++;
    Store.write(Store.KEY_SEQ, Store.seq.toString());
    return Store.seq;
  }

  private static persistBookmarks(): void {
    Store.write(Store.KEY_BOOKMARKS, JSON.stringify(Store.bookmarks));
  }

  private static persistHistory(): void {
    Store.write(Store.KEY_HISTORY, JSON.stringify(Store.historyItems));
  }

  private static persistDownloads(): void {
    Store.write(Store.KEY_DOWNLOADS, JSON.stringify(Store.downloadItems));
  }

  // ---------------- bookmarks ----------------

  static allBookmarks(): BookmarkItem[] {
    const copy: BookmarkItem[] = Store.bookmarks.slice();
    copy.sort((a: BookmarkItem, b: BookmarkItem) => b.created - a.created);
    return copy;
  }

  static findBookmarks(keyword: string): BookmarkItem[] {
    const all: BookmarkItem[] = Store.allBookmarks();
    if (!keyword || keyword.trim().length === 0) {
      return all;
    }
    const k: string = keyword.trim().toLowerCase();
    return all.filter((b: BookmarkItem) =>
      b.title.toLowerCase().includes(k) || b.url.toLowerCase().includes(k));
  }

  static isBookmarked(url: string): boolean {
    return Store.bookmarks.some((b: BookmarkItem) => b.url === url);
  }

  static addBookmark(title: string, url: string): boolean {
    if (!url) {
      return false;
    }
    if (Store.isBookmarked(url)) {
      return false;
    }
    const item: BookmarkItem = new BookmarkItem();
    item.id = Store.nextId();
    item.title = title ? title : '';
    item.url = url;
    item.created = Date.now();
    Store.bookmarks.push(item);
    Store.persistBookmarks();
    return true;
  }

  static removeBookmark(id: number): void {
    Store.bookmarks = Store.bookmarks.filter((b: BookmarkItem) => b.id !== id);
    Store.persistBookmarks();
  }

  static removeBookmarkByUrl(url: string): void {
    Store.bookmarks = Store.bookmarks.filter((b: BookmarkItem) => b.url !== url);
    Store.persistBookmarks();
  }

  // ---------------- history ----------------

  static allHistory(): HistoryItem[] {
    const copy: HistoryItem[] = Store.historyItems.slice();
    copy.sort((a: HistoryItem, b: HistoryItem) => b.visited - a.visited);
    return copy;
  }

  static findHistory(keyword: string, limit: number): HistoryItem[] {
    const all: HistoryItem[] = Store.allHistory();
    let list: HistoryItem[] = all;
    if (keyword && keyword.trim().length > 0) {
      const k: string = keyword.trim().toLowerCase();
      list = all.filter((h: HistoryItem) =>
        h.title.toLowerCase().includes(k) || h.url.toLowerCase().includes(k));
    }
    return list.slice(0, limit);
  }

  static addHistory(title: string, url: string): void {
    if (!url || url.startsWith('about:') || url.startsWith('data:') || url.startsWith('zorme://')) {
      return;
    }
    const now: number = Date.now();
    const idx: number = Store.historyItems.findIndex((h: HistoryItem) => h.url === url);
    if (idx >= 0 && now - Store.historyItems[idx].visited < 30 * 60 * 1000) {
      Store.historyItems[idx].visited = now;
      Store.historyItems[idx].title = title ? title : '';
      Store.historyItems[idx].visits = Store.historyItems[idx].visits + 1;
      Store.persistHistory();
      return;
    }
    const item: HistoryItem = new HistoryItem();
    item.id = Store.nextId();
    item.title = title ? title : '';
    item.url = url;
    item.visited = now;
    item.visits = 1;
    Store.historyItems.push(item);
    if (Store.historyItems.length > 1500) {
      Store.historyItems.sort((a: HistoryItem, b: HistoryItem) => b.visited - a.visited);
      Store.historyItems = Store.historyItems.slice(0, 1500);
    }
    Store.persistHistory();
  }

  static removeHistory(id: number): void {
    Store.historyItems = Store.historyItems.filter((h: HistoryItem) => h.id !== id);
    Store.persistHistory();
  }

  static clearHistory(): void {
    Store.historyItems = [];
    Store.persistHistory();
  }

  // ---------------- downloads ----------------

  static allDownloads(): DownloadItem[] {
    const copy: DownloadItem[] = Store.downloadItems.slice();
    copy.sort((a: DownloadItem, b: DownloadItem) => b.time - a.time);
    return copy;
  }

  static addDownload(title: string, url: string, path: string, total: number): DownloadItem {
    const item: DownloadItem = new DownloadItem();
    item.id = Store.nextId();
    item.title = title;
    item.url = url;
    item.path = path;
    item.total = total;
    item.time = Date.now();
    item.state = 0;
    item.percent = 0;
    Store.downloadItems.push(item);
    Store.persistDownloads();
    return item;
  }

  static updateDownload(id: number, state: number, received: number, total: number): void {
    const idx: number = Store.downloadItems.findIndex((d: DownloadItem) => d.id === id);
    if (idx < 0) {
      return;
    }
    Store.downloadItems[idx].state = state;
    Store.downloadItems[idx].size = received;
    if (total > 0) {
      Store.downloadItems[idx].total = total;
      Store.downloadItems[idx].percent = Math.min(100, Math.floor(received * 100 / total));
    }
    Store.persistDownloads();
  }

  static removeDownload(id: number): void {
    Store.downloadItems = Store.downloadItems.filter((d: DownloadItem) => d.id !== id);
    Store.persistDownloads();
  }

  static clearDownloads(): void {
    Store.downloadItems = [];
    Store.persistDownloads();
  }

  // ---------------- session ----------------

  static saveSession(items: SessionItem[], current: number): void {
    Store.write(Store.KEY_SESSION, JSON.stringify(items));
    Store.write(Store.KEY_SESSION_CUR, current.toString());
  }

  static restoreSession(): SessionItem[] {
    return Store.readArray<SessionItem>(Store.KEY_SESSION);
  }

  static restoredCurrent(): number {
    if (Store.store === null) {
      return 0;
    }
    return Store.store.getSync(Store.KEY_SESSION_CUR, 0) as number;
  }

  static clearSession(): void {
    Store.write(Store.KEY_SESSION, '[]');
    Store.write(Store.KEY_SESSION_CUR, '0');
  }
}
