// @dart=3.12
import 'dart:async';
import 'dart:js_interop';

@JS('ellenaMountSupport')
external JSFunction? get _ellenaMountSupport;

@JS('document.createElement')
external JSObject _createElement(String tag);

@JS('document.getElementById')
external JSObject? _getElementById(String id);

@JS('document.body')
external JSObject get _documentBody;

extension type _DomElement._(JSObject _) implements JSObject {
  external set id(String value);
  external set textContent(String value);
  external void setAttribute(String name, String value);
  external void appendChild(JSObject child);
  external void remove();
  external set onclick(JSFunction? value);
}

/// Draws the support panel directly in the page, above the Flutter view.
void showSupportOverlay(String theme) {
  if (_getElementById('ellena-support-overlay') != null) return;

  final overlay = _DomElement._(_createElement('div'));
  overlay.id = 'ellena-support-overlay';
  overlay.setAttribute(
    'style',
    'position:fixed;inset:0;z-index:2147483646;background:rgba(0,0,0,.45);'
        'display:flex;align-items:center;justify-content:center;'
        'font-family:sans-serif;',
  );

  // Ell-ena surface colours; the panel itself inherits them.
  final colors = theme == 'dark'
      ? 'background:#2A2A2A;color:#E8E8E8;'
      : 'background:#FFFFFF;color:#1C1C1C;';
  final panel = _DomElement._(_createElement('div'));
  panel.setAttribute(
    'style',
    'width:min(960px,calc(100vw - 48px));height:min(860px,calc(100vh - 48px));'
        '${colors}border-radius:16px;overflow:hidden;display:flex;'
        'flex-direction:column;position:relative;',
  );

  final close = _DomElement._(_createElement('button'));
  close.textContent = '×';
  close.setAttribute('aria-label', 'Close');
  close.setAttribute(
    'style',
    'position:absolute;top:8px;right:8px;z-index:2;width:36px;height:36px;'
        'border:0;border-radius:8px;background:transparent;color:inherit;'
        'font-size:24px;'
        'line-height:36px;cursor:pointer;',
  );

  final root = _DomElement._(_createElement('div'));
  root.id = 'ellena-support-root';
  root.setAttribute('style', 'flex:1;overflow:auto;');

  panel.appendChild(close);
  panel.appendChild(root);
  overlay.appendChild(panel);
  _DomElement._(_documentBody).appendChild(overlay);

  JSFunction? unmount;
  Timer? poll;

  void dismiss() {
    poll?.cancel();
    unmount?.callAsFunction();
    overlay.remove();
  }

  close.onclick = dismiss.toJS;

  var attempts = 0;
  poll = Timer.periodic(const Duration(milliseconds: 100), (timer) {
    attempts++;
    final mount = _ellenaMountSupport;
    if (mount != null) {
      timer.cancel();
      final result = mount.callAsFunction(null, root, theme.toJS);
      if (result != null) unmount = result as JSFunction;
      return;
    }
    if (attempts >= 50) {
      timer.cancel();
      root.textContent = 'Could not load the support panel.';
    }
  });
}
