/** 单个标签页的界面状态（Web 控制器单独保存在页面中，避免被状态代理包装） */
export class TabMeta {
  id: number = 0;
  title: string = '';
  url: string = '';
  showingHome: boolean = true;
  incognito: boolean = false;
  loading: boolean = false;
  progress: number = 0;
  canBack: boolean = false;
  canForward: boolean = false;
  error: boolean = false;
  errorDesc: string = '';
  attached: boolean = false;
  pendingUrl: string = '';

  constructor(id: number, incognito: boolean, url: string) {
    this.id = id;
    this.incognito = incognito;
    this.url = url ? url : '';
    this.showingHome = !url;
    this.pendingUrl = url ? url : '';
  }

  displayTitle(): string {
    if (this.showingHome) {
      return '新标签页';
    }
    if (this.title && this.title.trim().length > 0) {
      return this.title;
    }
    return this.url ? this.url : '新标签页';
  }
}
