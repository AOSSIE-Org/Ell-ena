// @dart=3.12
import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

@JS('SocialShareButton')
external JSAny? get _socialShareConstructor;

@JS('document.createElement')
external JSObject _createElement(String tag);

@JS('document.getElementById')
external JSObject? _getElementById(String id);

@JS('document.title')
external String get _documentTitle;

@JS('window.location.href')
external String get _locationHref;

extension type _DomElement._(JSObject _) implements JSObject {
  external set id(String value);
  external _CssStyle get style;
}

extension type _CssStyle._(JSObject _) implements JSObject {
  external set width(String value);
  external set height(String value);
  external set display(String value);
  external set alignItems(String value);
  external set justifyContent(String value);
}

@JS('SocialShareButton')
extension type _SocialShareButton._(JSObject _) implements JSObject {
  external _SocialShareButton(JSAny? options);
  external void destroy();
  external void updateOptions(JSAny? options);
}

/// Wide-web host for the AOSSIE Social Share Button.
class SocialShareHost extends StatefulWidget {
  final String theme;

  const SocialShareHost({super.key, required this.theme});

  @override
  State<SocialShareHost> createState() => _SocialShareHostState();
}

class _SocialShareHostState extends State<SocialShareHost> {
  static const _viewType = 'ellena-social-share-button';
  static var _registered = false;

  _SocialShareButton? _button;
  GoRouter? _router;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _registerView();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = GoRouter.maybeOf(context);
    if (!identical(next, _router)) {
      _router?.routerDelegate.removeListener(_syncShareTarget);
      _router = next;
      _router?.routerDelegate.addListener(_syncShareTarget);
    }
  }

  @override
  void didUpdateWidget(SocialShareHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.theme != widget.theme) {
      _disposeButton();
      _scheduleInit();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _router?.routerDelegate.removeListener(_syncShareTarget);
    _disposeButton();
    super.dispose();
  }

  void _registerView() {
    if (_registered) return;
    _registered = true;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (
      int viewId, {
      Object? params,
    }) {
      final div = _DomElement._(_createElement('div'));
      div.id = 'share-button';
      div.style
        ..width = '100%'
        ..height = '100%'
        ..display = 'flex'
        ..alignItems = 'center'
        ..justifyContent = 'center';
      return div;
    });
  }

  void _scheduleInit() {
    _poll?.cancel();
    var attempts = 0;
    _poll = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      attempts++;
      if (!mounted || _button != null) {
        timer.cancel();
        return;
      }
      if (_socialShareConstructor != null &&
          _getElementById('share-button') != null) {
        timer.cancel();
        _button = _SocialShareButton(_options());
        return;
      }
      if (attempts >= 50) timer.cancel();
    });
  }

  JSAny? _options() {
    return {
      'container': '#share-button',
      'url': _locationHref,
      'title': _documentTitle,
      'buttonText': 'Share',
      'buttonStyle': 'primary',
      'buttonColor': '#4CAF50',
      'buttonHoverColor': '#388E3C',
      'theme': widget.theme,
    }.jsify();
  }

  void _syncShareTarget() {
    final button = _button;
    if (button == null) return;
    button.updateOptions(
      {'url': _locationHref, 'title': _documentTitle}.jsify(),
    );
  }

  void _disposeButton() {
    final button = _button;
    _button = null;
    if (button == null) return;
    try {
      button.destroy();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      viewType: _viewType,
      onPlatformViewCreated: (_) => _scheduleInit(),
    );
  }
}
