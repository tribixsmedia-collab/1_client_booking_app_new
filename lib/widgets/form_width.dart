import 'package:flutter/material.dart';

/// Caps a column of form fields at a comfortable width and centres it.
///
/// The web build fills the browser window, which is what you want for the
/// catalogue but wrong for a form: a phone-number field stretched across a
/// 1920px monitor is awkward to use and reads as broken. Any window narrower
/// than [maxWidth] — every phone — is passed through untouched, so this
/// changes nothing on Android or iOS.
class FormWidth extends StatelessWidget {
  const FormWidth({super.key, required this.child, this.maxWidth = 460});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
