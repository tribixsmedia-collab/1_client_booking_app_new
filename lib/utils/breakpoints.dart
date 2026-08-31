import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

/// Width at which the web build stops being a phone layout stretched wide and
/// becomes a desktop one: a top navigation bar instead of the bottom tabs, a
/// two-column hero, and content centred in a readable column.
///
/// Below this — every phone, and a narrow browser window — nothing changes,
/// so the installed Android and iOS apps are untouched.
const double kDesktopBreakpoint = 900;

/// Content column width on desktop for browse and detail pages - grids,
/// lists, cards. Wider than this and rows start drifting apart from the
/// heading above them.
const double kDesktopContentWidth = 1240;

/// Narrower column for pages that are mostly a single stack of fields or
/// prose - booking, profile, reviews, support. A form stretched across 1240px
/// is hard to scan even though a grid of cards at that width is not.
const double kDesktopFormWidth = 760;

bool isDesktopLayout(BuildContext context) =>
    kIsWeb && MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

/// Centres [child] in the desktop content column. A no-op on narrow screens,
/// so the same widget tree serves both layouts.
class DesktopCentered extends StatelessWidget {
  const DesktopCentered({
    super.key,
    required this.child,
    this.maxWidth = kDesktopContentWidth,
    this.fillHeight = true,
  });

  final Widget child;
  final double maxWidth;

  /// Whether to take all the height on offer.
  ///
  /// True for a Scaffold body, which should cover the page. False for a
  /// bottomNavigationBar or bottom action bar: those are handed *loose*
  /// height constraints, so a widget that expands into them swallows the
  /// whole page and leaves the body with nothing.
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopLayout(context)) return child;
    return Align(
      alignment: Alignment.center,
      heightFactor: fillHeight ? null : 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
