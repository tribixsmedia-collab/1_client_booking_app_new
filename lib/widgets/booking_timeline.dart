import 'package:flutter/material.dart';
import '../theme.dart';

class BookingTimeline extends StatelessWidget {
  final String status;
  final String paymentStatus;
  final String? createdAt;
  final String? assignedAt;
  final String? completedAt;

  const BookingTimeline({
    super.key,
    required this.status,
    required this.paymentStatus,
    this.createdAt,
    this.assignedAt,
    this.completedAt,
  });

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();

    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isLast = index == steps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline indicator
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  // Circle
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: step.isCompleted
                          ? AppColors.primary
                          : step.isActive
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : Colors.grey.shade300,
                      border: step.isActive && !step.isCompleted
                          ? Border.all(color: AppColors.primary, width: 2)
                          : null,
                    ),
                    child: step.isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : step.isActive
                        ? Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : null,
                  ),
                  // Line
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 48,
                      color: step.isCompleted
                          ? AppColors.primary
                          : Colors.grey.shade300,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: step.isCompleted || step.isActive
                            ? Colors.black
                            : Colors.grey.shade500,
                      ),
                    ),
                    if (step.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        step.subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: step.isCompleted || step.isActive
                              ? AppColors.textGrey
                              : Colors.grey.shade400,
                        ),
                      ),
                    ],
                    if (step.timestamp != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        step.timestamp!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  List<_TimelineStep> _buildSteps() {
    final isCancelled = status == 'CANCELLED';

    if (isCancelled) {
      return [
        _TimelineStep(
          title: 'Booked',
          subtitle: 'Your booking has been placed',
          timestamp: _formatDateTime(createdAt),
          isCompleted: true,
          isActive: false,
        ),
        _TimelineStep(
          title: 'Cancelled',
          subtitle: 'This booking was cancelled',
          isCompleted: false,
          isActive: true,
        ),
      ];
    }

    final int currentIndex;
    switch (status) {
      case 'PENDING':
        currentIndex = 0;
        break;
      case 'ASSIGNED':
        currentIndex = 2;
        break;
      case 'IN_PROGRESS':
        currentIndex = 3;
        break;
      case 'COMPLETED':
        currentIndex = paymentStatus == 'PAID' ? 4 : 3;
        break;
      default:
        currentIndex = 0;
    }

    return [
      _TimelineStep(
        title: 'Booked',
        subtitle: 'Your booking has been placed',
        timestamp: _formatDateTime(createdAt),
        isCompleted: currentIndex >= 0,
        isActive: currentIndex == 0,
      ),
      _TimelineStep(
        title: 'Planning',
        subtitle: 'Finding the best professional for you',
        isCompleted: currentIndex >= 1,
        isActive: currentIndex == 1,
      ),
      _TimelineStep(
        title: 'Vendor Assigned',
        subtitle: 'A professional has been assigned',
        timestamp: _formatDateTime(assignedAt),
        isCompleted: currentIndex >= 2,
        isActive: currentIndex == 2,
      ),
      _TimelineStep(
        title: 'Work Started',
        subtitle: 'The professional is working on your service',
        isCompleted: currentIndex >= 3,
        isActive: currentIndex == 3,
      ),
      _TimelineStep(
        title: 'Payment Completed',
        subtitle: paymentStatus == 'PAID'
            ? 'Payment received — Thank you!'
            : 'Pending payment',
        timestamp: _formatDateTime(completedAt),
        isCompleted: currentIndex >= 4,
        isActive: currentIndex == 4,
      ),
    ];
  }

  String? _formatDateTime(String? dateStr) {
    if (dateStr == null) return null;
    try {
      final dt = DateTime.parse(dateStr);
      final months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${months[dt.month]} ${dt.day}, ${dt.year} at $hour:${dt.minute.toString().padLeft(2, '0')} $ampm';
    } catch (_) {
      return null;
    }
  }
}

class _TimelineStep {
  final String title;
  final String? subtitle;
  final String? timestamp;
  final bool isCompleted;
  final bool isActive;

  _TimelineStep({
    required this.title,
    this.subtitle,
    this.timestamp,
    required this.isCompleted,
    required this.isActive,
  });
}
