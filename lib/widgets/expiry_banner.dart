import 'package:flutter/material.dart';

/// Sticky banner shown on dashboard when expired medicines exist
/// Part of the "Nag & Flag" pattern - shows after first modal dismissed
class ExpiryBanner extends StatelessWidget {
  final int expiredCount;
  final VoidCallback onTap;

  const ExpiryBanner({
    super.key,
    required this.expiredCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (expiredCount == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade600, Colors.red.shade700],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expiredCount == 1
                        ? '1 medicine has expired'
                        : '$expiredCount medicines have expired',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to view and remove',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

/// Yellow warning banner for medicines expiring soon
class ExpiringSoonBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const ExpiringSoonBanner({
    super.key,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time_filled_rounded,
              color: Colors.orange.shade700,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                count == 1
                    ? '1 medicine expiring soon'
                    : '$count medicines expiring soon',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.orange.shade700,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

/// Combined banner for dashboard showing both expired and expiring soon
class CabinetAlertBanner extends StatelessWidget {
  final int expiredCount;
  final int expiringSoonCount;
  final VoidCallback onTap;

  const CabinetAlertBanner({
    super.key,
    required this.expiredCount,
    required this.expiringSoonCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Priority: Show expired banner if any, otherwise expiring soon
    if (expiredCount > 0) {
      return ExpiryBanner(expiredCount: expiredCount, onTap: onTap);
    } else if (expiringSoonCount > 0) {
      return ExpiringSoonBanner(count: expiringSoonCount, onTap: onTap);
    }
    return const SizedBox.shrink();
  }
}

/// Badge indicator for navigation items showing expired count
class ExpiryBadge extends StatelessWidget {
  final int count;

  const ExpiryBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.4),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        count > 9 ? '9+' : count.toString(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
