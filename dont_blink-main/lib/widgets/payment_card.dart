import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PaymentCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const PaymentCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? AppColors.primary : Colors.grey.shade400;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: enabled ? onTap : null,
      child: Card(
        elevation: enabled && selected ? 3 : 1,
        color: enabled ? Colors.white : const Color(0xFFF9FAF9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: enabled
                ? (selected ? AppColors.primary : AppColors.border)
                : Colors.grey.shade200,
            width: selected && enabled ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    enabled ? AppColors.tintGreen : Colors.grey.shade200,
                child: Icon(icon, color: effectiveColor),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: enabled
                                  ? Colors.black87
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        if (!enabled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Unavailable',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitle,
                      style: TextStyle(
                        color: enabled ? Colors.grey : Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                enabled
                    ? (selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off)
                    : Icons.block,
                color: enabled
                    ? (selected ? AppColors.primary : Colors.grey.shade400)
                    : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
