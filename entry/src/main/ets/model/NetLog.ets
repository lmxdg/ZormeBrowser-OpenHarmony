/** 网络日志（仅内存，退出即清空） */
export class NetLogItem {
  time: number = 0;
  method: string = '';
  url: string = '';
  mainFrame: boolean = false;
  blocked: boolean = false;
}

export class NetLog {
  private static items: NetLogItem[] = [];
  private static readonly MAX: number = 500;

  static record(method: string, url: string, mainFrame: boolean, blocked: boolean): void {
    const item: NetLogItem = new NetLogItem();
    item.time = Date.now();
    item.method = method ? method : 'GET';
    item.url = url;
    item.mainFrame = mainFrame;
    item.blocked = blocked;
    NetLog.items.push(item);
    if (NetLog.items.length > NetLog.MAX) {
      NetLog.items = NetLog.items.slice(NetLog.items.length - NetLog.MAX);
    }
  }

  static all(): NetLogItem[] {
    return NetLog.items.slice();
  }

  static clear(): void {
    NetLog.items = [];
  }

  static count(): number {
    return NetLog.items.length;
  }

  static blockedCount(): number {
    return NetLog.items.filter((i: NetLogItem) => i.blocked).length;
  }
}
