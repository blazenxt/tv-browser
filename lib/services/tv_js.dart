import 'dart:convert';

/// JavaScript bridge injected into every page.
///
/// Flutter owns remote navigation while this bridge discovers targets in the
/// DOM. Actual cursor and jump-mode taps are sent as Android MotionEvents when
/// possible, because many video players reject synthetic JavaScript clicks.
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

  function rendered(el) {
    if (!el || !el.getBoundingClientRect) return false;
    if (el.disabled || el.getAttribute('aria-disabled') === 'true') return false;
    var r = el.getBoundingClientRect();
    if (r.width < 3 || r.height < 3) return false;
    var st;
    try { st = window.getComputedStyle(el); } catch (e) { return false; }
    if (!st || st.visibility === 'hidden' || st.display === 'none' || st.opacity === '0') {
      return false;
    }
    return true;
  }

  function inViewport(el) {
    if (!rendered(el)) return false;
    var r = el.getBoundingClientRect();
    return r.bottom > 0 && r.right > 0 &&
      r.top < window.innerHeight && r.left < window.innerWidth;
  }

  function candidates() {
    var q = document.querySelectorAll(
      'a[href],button,input:not([type="hidden"]),select,textarea,summary,' +
      '[contenteditable="true"],[role="button"],[role="link"],[role="menuitem"],' +
      '[role="option"],[role="tab"],[onclick],[tabindex],[aria-haspopup],video,audio');
    var out = [];
    for (var i = 0; i < q.length; i++) {
      var ti = q[i].getAttribute('tabindex');
      if (ti !== null && parseInt(ti, 10) < 0) continue;
      if (rendered(q[i])) out.push(q[i]);
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

  function closestActionable(el) {
    if (!el) return null;
    if (el.closest) {
      var found = el.closest(
        'a,button,input,select,textarea,summary,[contenteditable="true"],' +
        '[role="button"],[role="link"],[role="menuitem"],[role="option"],' +
        '[role="tab"],[onclick],[tabindex],[aria-haspopup],video,audio');
      if (found) return found;
    }
    return el;
  }

  function deepestElementAt(x, y) {
    var root = document;
    var localX = x;
    var localY = y;
    var el = null;
    for (var depth = 0; depth < 8; depth++) {
      try { el = root.elementFromPoint(localX, localY); } catch (e) { break; }
      if (!el) break;
      if (el.shadowRoot && el.shadowRoot.elementFromPoint) {
        root = el.shadowRoot;
        continue;
      }
      if (el.tagName && el.tagName.toUpperCase() === 'IFRAME') {
        try {
          var r = el.getBoundingClientRect();
          var doc = el.contentDocument;
          if (!doc) break;
          localX -= r.left;
          localY -= r.top;
          root = doc;
          continue;
        } catch (e2) {
          break;
        }
      }
      break;
    }
    return el;
  }

  function describeInput(el) {
    var multiline = el.tagName && el.tagName.toUpperCase() === 'TEXTAREA';
    return JSON.stringify({
      kind: 'input',
      value: ('value' in el) ? (el.value || '') : (el.innerText || ''),
      multiline: multiline
    });
  }

  function tapDescriptor(el, x, y) {
    var r = el && el.getBoundingClientRect ? el.getBoundingClientRect() : null;
    var px = typeof x === 'number' ? x : (r ? r.left + r.width / 2 : window.innerWidth / 2);
    var py = typeof y === 'number' ? y : (r ? r.top + r.height / 2 : window.innerHeight / 2);
    px = Math.max(1, Math.min(window.innerWidth - 1, px));
    py = Math.max(1, Math.min(window.innerHeight - 1, py));
    return JSON.stringify({
      kind: 'tap', x: px, y: py,
      width: window.innerWidth, height: window.innerHeight
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
      try { el.focus({ preventScroll: true }); } catch (focusError) { el.focus(); }
    } catch (e) {
      try { el.scrollIntoView(true); } catch (e2) {}
    }
  }

  function firstCandidate(els) {
    var best = null;
    var bestScore = Infinity;
    for (var i = 0; i < els.length; i++) {
      if (!inViewport(els[i])) continue;
      var r = els[i].getBoundingClientRect();
      var x = r.left + r.width / 2;
      var y = r.top + r.height / 2;
      var score = Math.abs(x - window.innerWidth / 2) + Math.max(0, y) * 0.35;
      if (score < bestScore) { bestScore = score; best = els[i]; }
    }
    return best || els[0] || null;
  }

  // Returns 'moved', 'edge' (nothing in that direction) or 'none'. Off-screen
  // candidates are included, so moving to the next link also scrolls the page.
  function move(dir) {
    var els = candidates();
    if (!els.length) return 'none';
    if (!curEl || els.indexOf(curEl) < 0) {
      highlight(firstCandidate(els));
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
      var score = primary * primary + 4 * secondary * secondary;
      if (score < bestScore) { bestScore = score; best = el; }
    }
    if (best) {
      highlight(best);
      return 'moved';
    }
    return 'edge';
  }

  // Returns an input descriptor or coordinates for a trusted native tap.
  function enter() {
    if (!curEl) {
      var els = candidates();
      if (!els.length) return null;
      highlight(firstCandidate(els));
      return null;
    }
    if (isEditable(curEl)) {
      pendingInput = curEl;
      return describeInput(curEl);
    }
    return tapDescriptor(curEl);
  }

  function clickCurrent() {
    if (!curEl) return false;
    try { curEl.click(); return true; } catch (e) { return false; }
  }

  // Inspects the target under the Flutter cursor without activating it.
  function inspectAt(fx, fy, fw, fh) {
    if (!fw || !fh) return null;
    var x = fx * window.innerWidth / fw;
    var y = fy * window.innerHeight / fh;
    var target = closestActionable(deepestElementAt(x, y));
    if (!target) return null;
    if (isEditable(target)) {
      pendingInput = target;
      return describeInput(target);
    }
    return tapDescriptor(target, x, y);
  }

  // JavaScript fallback for devices whose WebView cannot receive a native tap.
  function clickAt(fx, fy, fw, fh) {
    if (!fw || !fh) return null;
    var x = fx * window.innerWidth / fw;
    var y = fy * window.innerHeight / fh;
    var target = closestActionable(deepestElementAt(x, y));
    if (!target) return null;
    if (isEditable(target)) {
      pendingInput = target;
      return describeInput(target);
    }
    try { target.click(); } catch (e) {}
    return JSON.stringify({ kind: 'click' });
  }

  function setNativeValue(el, text) {
    if (!('value' in el)) {
      el.innerText = text;
      return;
    }
    var proto = el;
    var setter = null;
    while (proto && !setter) {
      var descriptor;
      try { descriptor = Object.getOwnPropertyDescriptor(proto, 'value'); } catch (e) {}
      if (descriptor && descriptor.set) setter = descriptor.set;
      proto = Object.getPrototypeOf(proto);
    }
    if (setter) setter.call(el, text); else el.value = text;
  }

  function setPendingValue(text) {
    if (!pendingInput) return false;
    var el = pendingInput;
    try { el.focus(); } catch (e) {}
    setNativeValue(el, text);
    try { el.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: text })); }
    catch (e) { try { el.dispatchEvent(new Event('input', { bubbles: true })); } catch (e2) {} }
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
    var width = Math.max(doc.scrollWidth || 0, body.scrollWidth || 0);
    return JSON.stringify({
      x: window.scrollX || window.pageXOffset || 0,
      y: window.scrollY || window.pageYOffset || 0,
      maxX: Math.max(0, width - window.innerWidth),
      max: Math.max(0, height - window.innerHeight),
      viewportWidth: window.innerWidth,
      viewportHeight: window.innerHeight
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
    clickCurrent: clickCurrent,
    inspectAt: inspectAt,
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
  static const String spatialClickFallback =
      'window.__tv ? window.__tv.clickCurrent() : false';

  static String inspectAt(double x, double y, double w, double h) =>
      'window.__tv ? window.__tv.inspectAt($x, $y, $w, $h) : null';

  static String clickAt(double x, double y, double w, double h) =>
      'window.__tv ? window.__tv.clickAt($x, $y, $w, $h) : null';

  static String scrollBy(int dx, int dy) => 'window.scrollBy($dx, $dy);';

  static const String pageInfo =
      'window.__tv ? window.__tv.pageInfo() : JSON.stringify({x: 0, y: 0, maxX: 0, max: 0})';

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
