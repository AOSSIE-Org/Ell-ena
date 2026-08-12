import 'package:flutter/material.dart';

/// Allows screens to refresh when their route regains focus.
class AppRouteObserver extends RouteObserver<ModalRoute<void>> {
  AppRouteObserver._();

  static final AppRouteObserver instance = AppRouteObserver._();
}
