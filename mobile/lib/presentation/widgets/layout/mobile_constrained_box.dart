import 'package:flutter/material.dart';

/// A wrapper that constrains the content width to a mobile-friendly size (max 430px)
/// when the screen is wide (e.g., Web or Tablet).
class MobileConstrainedBox extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final Color? backgroundColor;

  const MobileConstrainedBox({
    super.key,
    required this.child,
    this.maxWidth = 430.0,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
