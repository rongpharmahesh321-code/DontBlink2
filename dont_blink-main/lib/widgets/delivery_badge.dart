import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class DeliveryBadge extends StatelessWidget {
  final int minutes;

  const DeliveryBadge({super.key, required this.minutes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tintGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flash_on, color: AppColors.primary, size: 18),
          const SizedBox(width: 4),
          Text(
            "$minutes mins",
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
