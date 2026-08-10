import 'package:flutter/material.dart';
import '../theme.dart';
import '../screens/curation_video_screen.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class CurationSectionWidget extends StatelessWidget {
  final List<dynamic> sections;

  const CurationSectionWidget({super.key, required this.sections});

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map((section) {
        final items = (section['items'] as List<dynamic>?) ?? [];
        if (items.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section['title'] ?? '',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if ((section['subtitle'] as String?)?.isNotEmpty ??
                        false) ...[
                      const SizedBox(height: 2),
                      Text(
                        section['subtitle'],
                        style: const TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 260,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _CurationCard(
                      title: item['title'] ?? '',
                      videoUrl: item['video'],
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CurationVideoScreen(
                              items: items,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CurationCard extends StatefulWidget {
  final String title;
  final String? videoUrl;
  final Future<void> Function() onTap;

  const _CurationCard({
    required this.title,
    required this.videoUrl,
    required this.onTap,
  });

  @override
  State<_CurationCard> createState() => _CurationCardState();
}

class _CurationCardState extends State<_CurationCard> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isVisible = false;

  Future<void> _initVideo() async {
    if (_initialized) return;
    if (widget.videoUrl == null || widget.videoUrl!.isEmpty) return;

    _initialized = true;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl!),
    );
    _controller = controller;

    try {
      await controller.initialize();
      controller.setLooping(false);
      controller.setVolume(0);

      // Loop only the first 10 seconds
      controller.addListener(() {
        if (controller.value.position.inSeconds >= 10) {
          controller.seekTo(Duration.zero);
          controller.play();
        }
      });

      // Only play if still visible after init
      if (_isVisible && mounted) {
        controller.play();
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Card video error: $e');
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final visible = info.visibleFraction > 0.3;

    if (visible && !_isVisible) {
      _isVisible = true;
      if (!_initialized) {
        _initVideo();
      } else {
        _controller?.play();
      }
    } else if (!visible && _isVisible) {
      _isVisible = false;
      _controller?.pause();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('curation_card_${widget.videoUrl}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: GestureDetector(
        onTap: () async {
          _controller?.pause();
          await widget.onTap();
          if (_isVisible) {
            _controller?.seekTo(Duration.zero);
            _controller?.play();
          }
        },
        child: Container(
          width: 170,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.grey.shade200,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video
              if (_controller != null && _controller!.value.isInitialized)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                )
              else
                Container(color: Colors.grey.shade300),

              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),

              // Title
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
