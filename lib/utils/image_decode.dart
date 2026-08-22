import 'package:flutter/material.dart';

/// Pixel width an image should be decoded at to fill [logicalWidth] on screen.
///
/// Without this, `Image.network` decodes at the file's full resolution — an
/// admin-uploaded 2000px banner becomes a 2000x2000 bitmap for a 350pt card.
/// That decode lands on the frame where the widget first scrolls into range,
/// which is exactly when it can cost a dropped frame.
int decodeWidthFor(BuildContext context, double logicalWidth) {
  final ratio = MediaQuery.devicePixelRatioOf(context);
  return (logicalWidth * ratio).round();
}
