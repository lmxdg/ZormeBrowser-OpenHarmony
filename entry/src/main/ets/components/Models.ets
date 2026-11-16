export class DialogOption {
  text: string = '';
  value: number = 0;
  danger: boolean = false;

  constructor(text: string, value: number, danger: boolean = false) {
    this.text = text;
    this.value = value;
    this.danger = danger;
  }
}

export class SuggestionItem {
  kind: string = '';
  title: string = '';
  subtitle: string = '';
  url: string = '';
  badge: string = '';

  constructor(kind: string, title: string, subtitle: string, url: string, badge: string) {
    this.kind = kind;
    this.title = title;
    this.subtitle = subtitle;
    this.url = url;
    this.badge = badge;
  }
}
