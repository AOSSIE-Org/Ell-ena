import 'package:flutter/widgets.dart';

/// Android and iOS build this. The web host is a separate library.
class SocialShareHost extends StatelessWidget {
  final String theme;

  const SocialShareHost({super.key, required this.theme});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
