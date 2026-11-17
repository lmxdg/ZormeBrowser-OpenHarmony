/*
 * Zorme 网页翻译注入脚本
 * 由 TranslateScript.ets 注入到页面；暴露 window.__zormeT 供后续调用。
 *
 * 策略：把同一块级容器内的相邻文本节点合并成"一段"再送去翻译，
 * 译文回填到第一个文本节点、其余置空。
 * 这样 <p>Visit <a>the site</a> now.</p> 不会翻成三段语义割裂的碎片，
 * 同时不重建 DOM，页面事件与样式都保持原样。
 */
(function () {
  if (window.__zormeT) {
    return;
  }

  var MAX_GROUPS = 400;
  var MAX_GROUP_LEN = 1200;

  // 这些标签内的文本不翻译（代码、表单、媒体等）
  var SKIP_TAG = {
    SCRIPT: 1, STYLE: 1, NOSCRIPT: 1, CODE: 1, PRE: 1, TEXTAREA: 1, INPUT: 1,
    SELECT: 1, OPTION: 1, IFRAME: 1, CANVAS: 1, SVG: 1, VIDEO: 1, AUDIO: 1,
    MATH: 1, KBD: 1, SAMP: 1, VAR: 1
  };
  var SKIP_SEL = 'script,style,noscript,code,pre,textarea,iframe,svg,canvas,video,audio,' +
    '[translate=no],.notranslate,#zorme-skip';

  // 块级容器：用来判断两段文本是否属于同一段落
  var BLOCK = {
    P: 1, DIV: 1, LI: 1, TD: 1, TH: 1, DD: 1, DT: 1, BLOCKQUOTE: 1, ARTICLE: 1,
    SECTION: 1, HEADER: 1, FOOTER: 1, MAIN: 1, ASIDE: 1, FIGCAPTION: 1, SUMMARY: 1,
    H1: 1, H2: 1, H3: 1, H4: 1, H5: 1, H6: 1, BODY: 1
  };

  // 含这些字符才认为需要翻译（纯中文段落直接跳过）
  var NEED = /[A-Za-z\u00C0-\u024F\u0370-\u03FF\u0400-\u052F\u0590-\u06FF\u0900-\u0DFF\u0E00-\u0E7F\u3040-\u30FF\uAC00-\uD7AF]/;

  function blockOf(el) {
    var n = el;
    while (n && n.nodeType === 1) {
      if (BLOCK[n.nodeName]) {
        return n;
      }
      n = n.parentNode;
    }
    return document.body || document.documentElement;
  }

  function collect() {
    try {
      var old = window.__zormeT_state;
      if (old && old.groups && old.groups.length > 0) {
        return JSON.stringify({
          ok: true, total: old.groups.length, items: old.items, cached: true
        });
      }
      var root = document.body || document.documentElement;
      if (!root) {
        return JSON.stringify({ ok: false, total: 0, items: [], error: 'empty document' });
      }

      var nodes = [];   // 所有参与翻译的文本节点
      var orig = [];    // 与 nodes 对应的原始 nodeValue
      var index = [];   // node -> nodes 下标
      var groups = [];  // { main: 主节点下标, extra: [其余节点下标] }
      var items = [];   // 每组待翻译文本

      var walker = document.createTreeWalker(root, 4, {
        acceptNode: function (n) {
          var p = n.parentNode;
          if (!p || p.nodeType !== 1) {
            return 2;
          }
          if (SKIP_TAG[p.nodeName]) {
            return 2;
          }
          if (p.closest && p.closest(SKIP_SEL)) {
            return 2;
          }
          var t = n.nodeValue;
          if (!t) {
            return 2;
          }
          t = t.replace(/\s+/g, ' ').trim();
          if (t.length < 2 || !NEED.test(t)) {
            return 2;
          }
          n.__zormeTxt = t;
          return 1;
        }
      });

      var node;
      var curBlock = null;
      var curGroup = null;
      while ((node = walker.nextNode())) {
        var text = node.__zormeTxt;
        var blk = blockOf(node.parentNode);
        var sameBlock = curGroup !== null && curBlock === blk
          && curGroup.len + text.length + 1 <= MAX_GROUP_LEN;

        var idx = nodes.length;
        nodes.push(node);
        orig.push(node.nodeValue);
        index.push(idx);
        node.__zormeIndex = idx;

        if (sameBlock) {
          curGroup.extra.push(idx);
          curGroup.len += text.length + 1;
          items[items.length - 1] = items[items.length - 1] + ' ' + text;
        } else {
          curGroup = { main: idx, extra: [], len: text.length };
          curBlock = blk;
          groups.push(curGroup);
          items.push(text);
          if (groups.length >= MAX_GROUPS) {
            break;
          }
        }
      }

      if (groups.length === 0) {
        return JSON.stringify({ ok: true, total: 0, items: [], cached: false });
      }

      window.__zormeT_state = {
        nodes: nodes,
        orig: orig,
        groups: groups,
        items: items
      };
      return JSON.stringify({ ok: true, total: groups.length, items: items, cached: false });
    } catch (e) {
      return JSON.stringify({ ok: false, total: 0, items: [], error: String(e) });
    }
  }

  function apply(start, arr) {
    try {
      var st = window.__zormeT_state;
      if (!st || !st.groups) {
        return '0';
      }
      var done = 0;
      for (var i = 0; i < arr.length; i++) {
        var g = st.groups[start + i];
        var v = arr[i];
        if (!g || typeof v !== 'string' || v.length === 0) {
          continue;
        }
        var main = st.nodes[g.main];
        if (main && main.nodeValue !== undefined) {
          main.nodeValue = v;
          done++;
        }
        for (var k = 0; k < g.extra.length; k++) {
          var ex = st.nodes[g.extra[k]];
          if (ex && ex.nodeValue !== undefined) {
            ex.nodeValue = '';
          }
        }
      }
      return String(done);
    } catch (e) {
      return '0';
    }
  }

  function restore() {
    try {
      var st = window.__zormeT_state;
      if (!st || !st.nodes) {
        return '0';
      }
      var done = 0;
      for (var i = 0; i < st.nodes.length; i++) {
        var n = st.nodes[i];
        var o = st.orig[i];
        if (n && o !== undefined && n.nodeValue !== undefined) {
          n.nodeValue = o;
          done++;
        }
      }
      window.__zormeT_state = null;
      return String(done);
    } catch (e) {
      return '0';
    }
  }

  window.__zormeT = {
    collect: collect,
    apply: apply,
    restore: restore,
    version: 2
  };
})();
