import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/cart_service.dart';
import '../theme.dart';
import 'service_detail_screen.dart';

class CurationVideoScreen extends StatefulWidget {
  final List<dynamic> items;
  final int initialIndex;

  const CurationVideoScreen({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  @override
  State<CurationVideoScreen> createState() => _CurationVideoScreenState();
}

class _CurationVideoScreenState extends State<CurationVideoScreen> {
  late PageController _pageController;
  late List<VideoPlayerController?> _controllers;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _controllers = List.filled(widget.items.length, null);
    _initVideo(_currentIndex);
  }

  Future<void> _initVideo(int index) async {
    if (_controllers[index] != null) return;

    final url = widget.items[index]['video'] as String?;
    if (url == null || url.isEmpty) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controllers[index] = controller;

    try {
      await controller.initialize();
      controller.setLooping(true);
      controller.setVolume(0);
      if (index == _currentIndex) {
        controller.play();
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _onPageChanged(int index) {
    // Pause previous
    _controllers[_currentIndex]?.pause();

    _currentIndex = index;

    // Init and play current
    _initVideo(index);
    _controllers[index]?.play();

    // Pre-load next
    if (index + 1 < widget.items.length) {
      _initVideo(index + 1);
    }

    setState(() {});
  }

  void _toggleMute() {
    final c = _controllers[_currentIndex];
    if (c == null) return;
    c.setVolume(c.value.volume > 0 ? 0 : 1);
    setState(() {});
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c?.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.horizontal,
        itemCount: widget.items.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          final controller = _controllers[index];
          final isMuted = controller == null || controller.value.volume == 0;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Video
              if (controller != null && controller.value.isInitialized)
                Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                )
              else
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),

              // Close button
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),

              // Mute button
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 16,
                child: GestureDetector(
                  onTap: _toggleMute,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),

              // Progress indicators
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 60,
                right: 60,
                child: Row(
                  children: List.generate(widget.items.length, (i) {
                    return Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i == _currentIndex
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Bottom service card
              if (item['service_id'] != null)
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  left: 16,
                  right: 16,
                  child: _ServiceInfoCard(item: item),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ServiceInfoCard extends StatelessWidget {
  final dynamic item;

  const _ServiceInfoCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = item['service_name'] ?? item['title'] ?? '';
    final price = double.tryParse('${item['service_price']}') ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${price.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 2),
                const Text(
                  '★ OUR FINEST EXPERIENCES',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ServiceDetailScreen(
                    serviceId: item['service_id'],
                    name: item['service_name'] ?? '',
                    description: item['service_description'] ?? '',
                    price: price,
                    imageUrl: item['service_image'],
                    categoryId: item['category_id'] ?? 0,
                    subcategoryId: item['subcategory_id'],
                    categoryName: item['category_name'] ?? '',
                  ),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'View more',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
