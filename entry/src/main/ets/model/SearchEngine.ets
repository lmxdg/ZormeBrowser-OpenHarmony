import { Prefs } from './Prefs';

/** 内置搜索引擎。搜索词统一编码后拼接。 */
export class SearchEngine {
  id: string;
  name: string;
  searchUrl: string;
  homeUrl: string;

  constructor(id: string, name: string, searchUrl: string, homeUrl: string) {
    this.id = id;
    this.name = name;
    this.searchUrl = searchUrl;
    this.homeUrl = homeUrl;
  }

  static readonly ALL: SearchEngine[] = [
    new SearchEngine('baidu', '百度', 'https://www.baidu.com/s?wd=%s', 'https://m.baidu.com'),
    new SearchEngine('bing', '必应', 'https://cn.bing.com/search?q=%s', 'https://cn.bing.com'),
    new SearchEngine('google', 'Google', 'https://www.google.com/search?q=%s', 'https://www.google.com'),
    new SearchEngine('sogou', '搜狗', 'https://www.sogou.com/web?query=%s', 'https://m.sogou.com'),
    new SearchEngine('so360', '360 搜索', 'https://www.so.com/s?q=%s', 'https://m.so.com'),
    new SearchEngine('sm', '神马', 'https://m.sm.cn/s?q=%s', 'https://m.sm.cn'),
    new SearchEngine('duckduckgo', 'DuckDuckGo', 'https://duckduckgo.com/?q=%s', 'https://duckduckgo.com')
  ];

  static get(): SearchEngine {
    return SearchEngine.byId(Prefs.searchEngine());
  }

  static byId(id: string): SearchEngine {
    for (const e of SearchEngine.ALL) {
      if (e.id === id) {
        return e;
      }
    }
    return SearchEngine.ALL[0];
  }

  static indexOf(id: string): number {
    for (let i = 0; i < SearchEngine.ALL.length; i++) {
      if (SearchEngine.ALL[i].id === id) {
        return i;
      }
    }
    return 0;
  }

  searchUrlFor(query: string): string {
    return this.searchUrl.replace('%s', encodeURIComponent(query));
  }
}
