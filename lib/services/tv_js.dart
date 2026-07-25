import 'dart:convert';

/// JavaScript bridge injected into every page. It powers both navigation
/// modes without relying on key events reaching the web page:
///
///  * Cursor mode: Flutter moves a drawn pointer; clicks are simulated with
///    `document.elementFromPoint`.
///  * Spatial mode: Flutter asks the page to highlight the nearest clickable
///    element in a direction, and "click" calls `el.click()`.
///
/// Web text fields are handled through a native dialog: the page remembers
/// the pending input, and the typed text is written back with proper input
/// events afterwards.
class TvJs {
  TvJs._();

  /// Injected at document end on every page load.
  static const String script = r'''
(function () {
  if (window.__tv) return;
  var curEl = null;
  var prevOutline = '';
  var prevOutlineOffset = '';
  var pendingInput = null;

  function visible(el) {
    if (!el || !el.getBoundingClientRect) return false;
    var r = el.getBoundingClientRect();
    if (r.width < 3 || r.height < 3) return false;
    var st;
    try { st = window.getComputedStyle(el); } catch (e) { return false; }
    if (!st || st.visibility === 'hidden' || st.display === 'none') return false;
    return r.bottom > 0 && r.right > 0 && r.top < window.innerHeight && r.left < window.innerWidth;
  }

  function candidates() {
    var q = document.querySelectorAll(
      'a[href],button,input:not([type="hidden"]),select,textarea,[role="button"],summary,[onclick],[tabindex]');
    var out = [];
    for (var i = 0; i < q.length; i++) {
      var ti = q[i].getAttribute('tabindex');
      if (ti !== null && parseInt(ti, 10) < 0) continue;
      if (visible(q[i])) out.push(q[i]);
    }
    return out;
  }

  function isEditable(el) {
    if (!el || !el.tagName) return false;
    var t = el.tagName.toUpperCase();
    if (t === 'TEXTAREA') return true;
    if (t === 'INPUT') {
      var ty = (el.type || 'text').toLowerCase();
      return ['text', 'search', 'email', 'url', 'password', 'number', 'tel'].indexOf(ty) >= 0;
    }
    return !!el.isContentEditable;
  }

  function describe(el) {
    var multiline = el.tagName && el.tagName.toUpperCase() === 'TEXTAREA';
    return JSON.stringify({
      kind: 'input',
      value: ('value' in el) ? (el.value || '') : (el.innerText || ''),
      multiline: multiline
    });
  }

  function clearHighlight() {
    if (curEl) {
      try {
        curEl.style.outline = prevOutline;
        curEl.style.outlineOffset = prevOutlineOffset;
      } catch (e) {}
    }
    curEl = null;
  }

  function highlight(el) {
    clearHighlight();
    if (!el) return;
    curEl = el;
    try {
      prevOutline = el.style.outline || '';
      prevOutlineOffset = el.style.outlineOffset || '';
      el.style.setProperty('outline', '3px solid #FFD740', 'important');
      el.style.setProperty('outline-offset', '2px', 'important');
      el.scrollIntoView({ block: 'center', inline: 'center', behavior: 'smooth' });
    } catch (e) {
      try { el.scrollIntoView(true); } catch (e2) {}
    }
  }

  // Returns 'moved', 'edge' (nothing in that direction) or 'none' (no candidates).
  function move(dir) {
    var els = candidates();
    if (!els.length) return 'none';
    if (!curEl || els.indexOf(curEl) < 0) {
      highlight(els[0]);
      return 'moved';
    }
    var cr = curEl.getBoundingClientRect();
    var cx = cr.left + cr.width / 2;
    var cy = cr.top + cr.height / 2;
    var best = null;
    var bestScore = Infinity;
    for (var i = 0; i < els.length; i++) {
      var el = els[i];
      if (el === curEl) continue;
      var r = el.getBoundingClientRect();
      var x = r.left + r.width / 2;
      var y = r.top + r.height / 2;
      var dx = x - cx;
      var dy = y - cy;
      var primary, secondary;
      if (dir === 'right') { if (dx <= 8) continue; primary = dx; secondary = dy; }
      else if (dir === 'left') { if (dx >= -8) continue; primary = -dx; secondary = dy; }
      else if (dir === 'down') { if (dy <= 8) continue; primary = dy; secondary = dx; }
      else { if (dy >= -8) continue; primary = -dy; secondary = dx; }
      var score = primary * primary + 16 * secondary * secondary;
      if (score < bestScore) { bestScore = score; best = el; }
    }
    if (best) {
      highlight(best);
      return 'moved';
    }
    return 'edge';
  }

  // Activates the highlighted element. Returns a JSON descriptor string or null.
  function enter() {
    if (!curEl) {
      var els = candidates();
      if (!els.length) return null;
      highlight(els[0]);
      return null;
    }
    if (isEditable(curEl)) {
      pendingInput = curEl;
      try { curEl.focus(); } catch (e) {}
      return describe(curEl);
    }
    try { curEl.click(); } catch (e) {}
    return JSON.stringify({ kind: 'click' });
  }

  // Simulates a pointer click. (fx, fy) are Flutter logical coords inside the
  // webview widget; (fw, fh) is the widget size. Returns JSON or null.
  function clickAt(fx, fy, fw, fh) {
    if (!fw || !fh) return null;
    var x = fx * window.innerWidth / fw;
    var y = fy * window.innerHeight / fh;
    var el = document.elementFromPoint(x, y);
    if (!el) return null;
    var target = el;
    if (el.closest) {
      var t = el.closest('a,button,input,select,textarea,summary,[role="button"],[onclick]');
      if (t) target = t;
    }
    curEl = null;
    if (isEditable(target)) {
      pendingInput = target;
      try { target.focus(); } catch (e) {}
      return describe(target);
    }
    try { target.click(); } catch (e) {}
    return JSON.stringify({ kind: 'click' });
  }

  function setPendingValue(text) {
    if (!pendingInput) return false;
    var el = pendingInput;
    try { el.focus(); } catch (e) {}
    if ('value' in el) {
      el.value = text;
    } else {
      el.innerText = text;
    }
    try { el.dispatchEvent(new Event('input', { bubbles: true })); } catch (e) {}
    try { el.dispatchEvent(new Event('change', { bubbles: true })); } catch (e) {}
    return true;
  }

  function submitPending() {
    if (!pendingInput) return false;
    var el = pendingInput;
    var types = ['keydown', 'keypress', 'keyup'];
    for (var i = 0; i < types.length; i++) {
      try {
        el.dispatchEvent(new KeyboardEvent(types[i], {
          key: 'Enter', code: 'Enter', keyCode: 13, which: 13,
          bubbles: true, cancelable: true
        }));
      } catch (e) {}
    }
    var f = el.form;
    if (f) {
      try {
        if (f.requestSubmit) f.requestSubmit(); else f.submit();
      } catch (e) {
        try { f.submit(); } catch (e2) {}
      }
    }
    return true;
  }

  function pageInfo() {
    var doc = document.documentElement || {};
    var body = document.body || {};
    var height = Math.max(doc.scrollHeight || 0, body.scrollHeight || 0);
    return JSON.stringify({
      y: window.scrollY || window.pageYOffset || 0,
      max: Math.max(0, height - window.innerHeight)
    });
  }

  function setMode(m) {
    if (m !== 'spatial') clearHighlight();
  }

  function deselect() {
    clearHighlight();
    pendingInput = null;
  }

  window.__tv = {
    move: move,
    enter: enter,
    clickAt: clickAt,
    setPendingValue: setPendingValue,
    submitPending: submitPending,
    pageInfo: pageInfo,
    setMode: setMode,
    deselect: deselect
  };
})();
''';

  static const String spatialMoveUp =
      "window.__tv ? window.__tv.move('up') : 'none'";
  static const String spatialMoveDown =
      "window.__tv ? window.__tv.move('down') : 'none'";
  static const String spatialMoveLeft =
      "window.__tv ? window.__tv.move('left') : 'none'";
  static const String spatialMoveRight =
      "window.__tv ? window.__tv.move('right') : 'none'";
  static const String spatialEnter = 'window.__tv ? window.__tv.enter() : null';

  static String clickAt(double x, double y, double w, double h) =>
      'window.__tv ? window.__tv.clickAt($x, $y, $w, $h) : null';

  static String scrollBy(int dx, int dy) => 'window.scrollBy($dx, $dy);';

  static const String pageInfo =
      'window.__tv ? window.__tv.pageInfo() : JSON.stringify({y: 0, max: 0})';

  static String setMode(NavModeLike mode) =>
      "window.__tv && window.__tv.setMode('${mode == NavModeLike.spatial ? 'spatial' : 'cursor'}');";

  static const String deselect = 'window.__tv && window.__tv.deselect();';

  static String setPendingValue(String text) =>
      'window.__tv && window.__tv.setPendingValue(${jsonEncode(text)});';

  static const String submitPending =
      'window.__tv && window.__tv.submitPending();';
}

/// Local mirror of the settings enum so this service stays dependency-free.
enum NavModeLike { cursor, spatial }
