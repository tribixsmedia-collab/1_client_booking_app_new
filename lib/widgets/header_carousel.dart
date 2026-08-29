import 'dart:async';
import 'package:flutter/material.dart';

import '../utils/image_decode.dart';

/// Auto-playing promo carousel that sits inside the home screen hero header.
/// Slides are fully admin-managed (Dashboard -> Header Carousel), so this
/// widget just renders whatever the API hands back and hides itself when
/// there is nothing active.
class HeaderCarousel extends StatefulWidget {
  final List<dynamic> banners;
  final void Function(Map<String, dynamic> banner) onTap;

  const HeaderCarousel({super.key, required this.banners, required this.onTap});

  @override
  State<HeaderCarousel> createState() => _HeaderCarouselState();
}

class _HeaderCarouselState extends State<HeaderCarousel> {
  final _controller = PageController();
  Timer? _autoPlayTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _restartAutoPlay();
  }

  @override
  void didUpdateWidget(covariant HeaderCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      _currentPage = 0;
      _restartAutoPlay();
    }
  }

  void _restartAutoPlay() {
    _autoPlayTimer?.cancel();
    if (widget.banners.length < 2) return;

    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_currentPage + 1) % widget.banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // 2.3 is the right shape on a phone. Left alone, a desktop window
            // turns that into an 800px-tall banner that buries the catalogue,
            // so the height stops growing and the banner just gets wider.
            // An AspectRatio cannot do this job here: the Column hands it a
            // loose width, so capping its height makes it narrow instead.
            final height = constraints.maxWidth / 2.3;
            return SizedBox(
              width: double.infinity,
              height: height > 280 ? 280 : height,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _controller,
                    itemCount: widget.banners.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, index) {
                      final banner = Map<String, dynamic>.from(
                        widget.banners[index],
                      );
                      return _HeaderSlide(
                        banner: banner,
                        onTap: () => widget.onTap(banner),
                      );
                    },
                  ),

                  // Page indicator — bottom right, like the reference design
                  if (widget.banners.length > 1)
                    Positioned(
                      right: 16,
                      bottom: 12,
                      child: Row(
                        children: List.generate(widget.banners.length, (i) {
                          final isActive = i == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(left: 5),
                            height: 4,
                            width: isActive ? 18 : 10,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                alpha: isActive ? 0.95 : 0.45,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HeaderSlide extends StatelessWidget {
  final Map<String, dynamic> banner;
  final VoidCallback onTap;

  const _HeaderSlide({required this.banner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = banner['image'] as String?;
    final title = (banner['title'] as String?) ?? '';
    final subtitle = (banner['subtitle'] as String?) ?? '';
    final hasText = title.isNotEmpty || subtitle.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                cacheWidth: decodeWidthFor(
                  context,
                  MediaQuery.sizeOf(context).width,
                ),
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),

            // Scrim only when there is text to keep readable
            if (hasText)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.05),
                    ],
                  ),
                ),
              ),

            if (hasText)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 100, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                        ),
                      ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
