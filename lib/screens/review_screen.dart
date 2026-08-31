import '../utils/breakpoints.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';

class ReviewScreen extends StatefulWidget {
  final int bookingId;
  final String categoryName;
  final String? vendorName;

  const ReviewScreen({
    super.key,
    required this.bookingId,
    required this.categoryName,
    this.vendorName,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _errorMessage = 'Please select a rating.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ApiService.submitReview(
        bookingId: widget.bookingId,
        rating: _rating,
        comment: _commentController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(
        () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rate & Review')),
      body: DesktopCentered(
        maxWidth: kDesktopFormWidth,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Service info
            Text(
              widget.categoryName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (widget.vendorName != null) ...[
              const SizedBox(height: 4),
              Text(
                'Service by ${widget.vendorName}',
                style: const TextStyle(color: AppColors.textGrey, fontSize: 14),
              ),
            ],
            const SizedBox(height: 24),

            // Rating
            const Text(
              'How was the service?',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starNum = index + 1;
                return GestureDetector(
                  onTap: () => setState(() => _rating = starNum),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      starNum <= _rating ? Icons.star : Icons.star_border,
                      color: starNum <= _rating
                          ? Colors.amber
                          : Colors.grey.shade400,
                      size: 44,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _rating == 0
                    ? 'Tap a star to rate'
                    : _rating == 1
                    ? 'Poor'
                    : _rating == 2
                    ? 'Below Average'
                    : _rating == 3
                    ? 'Average'
                    : _rating == 4
                    ? 'Good'
                    : 'Excellent',
                style: TextStyle(
                  color: _rating == 0 ? AppColors.textGrey : AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Comment
            const Text(
              'Write a review (optional)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Tell us about your experience...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit Review'),
            ),
          ],
        ),
      ),
    );
  }
}
