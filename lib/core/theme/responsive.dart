import 'package:flutter/material.dart';

enum InkBreakpoint { phone, tablet, desktop }

/// Centralized responsive layout — prefer this over scattered MediaQuery checks.
class InkLayout {
  final Size size;
  final EdgeInsets padding;

  const InkLayout(this.size, this.padding);

  factory InkLayout.of(BuildContext context) {
    final mq = MediaQuery.of(context);
    return InkLayout(mq.size, mq.padding);
  }

  double get width => size.width;
  double get height => size.height;

  InkBreakpoint get breakpoint {
    if (width < 600) return InkBreakpoint.phone;
    if (width < 1024) return InkBreakpoint.tablet;
    return InkBreakpoint.desktop;
  }

  bool get isPhone => breakpoint == InkBreakpoint.phone;
  bool get isTablet => breakpoint == InkBreakpoint.tablet;
  bool get isDesktop => breakpoint == InkBreakpoint.desktop;
  bool get isCompact => width < 700;

  double get pageGutter {
    if (isPhone) return 12;
    if (isTablet) return 28;
    return 48;
  }

  double get contentMaxWidth {
    if (isPhone) return width;
    if (isTablet) return 920;
    return 1120;
  }

  int notebookColumns() {
    if (width < 420) return 2;
    if (width < 720) return 3;
    if (width < 1100) return 4;
    return 5;
  }

  EdgeInsets get libraryPadding => EdgeInsets.fromLTRB(
        isPhone ? 20 : 40,
        isPhone ? 16 : 28,
        isPhone ? 20 : 40,
        40,
      );
}

typedef InkLayoutBuilder = Widget Function(BuildContext context, InkLayout layout);

class InkResponsive extends StatelessWidget {
  final InkLayoutBuilder builder;
  const InkResponsive({super.key, required this.builder});

  @override
  Widget build(BuildContext context) => builder(context, InkLayout.of(context));
}
