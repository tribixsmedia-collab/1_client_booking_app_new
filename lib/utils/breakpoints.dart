import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

/// Width at which the web build stops being a phone layout stretched wide and
/// becomes a desktop one: a top navigation bar instead of the bottom tabs, a
/// two-column hero, and content centred in a readable column.
///
/// Below this — every phone, and a narrow browser window — nothing changes,
/// so the installed Android and iOS apps are untouched.
const double kDesktopBreakpoint = 900;

/// Content column width on desktop. Wider than this and lines of service
/// cards start drifting apart from the heading above them.
const double kDesktopContentWidth = 1240;

bool isDesktopLayout(BuildContext context) =>
    kIsWeb && MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

/// Centres [child] in the desktop content column. A no-op on narrow screens,
/// so the same widget tree serves both layouts.
class DesktopCentered extends StatelessWidget {
  const DesktopCentered({
    super.key,
    required this.child,
    this.maxWidth = kDesktopContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopLayout(context)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
