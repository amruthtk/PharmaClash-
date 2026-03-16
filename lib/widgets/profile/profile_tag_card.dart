import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'profile_info_card.dart';
import 'profile_edit_button.dart';

class ProfileTagCard extends StatelessWidget {
  final List<String> tags;
  final String emptyMessage;
  final String countLabelSingular;
  final String countLabelPlural;
  final IconData tagIcon;
  final Color tagColor;
  final VoidCallback onEdit;

  const ProfileTagCard({
    super.key,
    required this.tags,
    required this.emptyMessage,
    required this.countLabelSingular,
    required this.countLabelPlural,
    required this.tagIcon,
    required this.tagColor,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tags.isEmpty
                    ? emptyMessage
                    : '${tags.length} ${tags.length == 1 ? countLabelSingular : countLabelPlural}',
                style: const TextStyle(fontSize: 14, color: AppColors.grayText),
              ),
              ProfileEditButton(onTap: onEdit),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: tagColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: tagColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tagIcon, size: 14, color: tagColor),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 13,
                            color: tagColor,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
