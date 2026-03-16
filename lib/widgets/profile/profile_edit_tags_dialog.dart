import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class ProfileEditTagsDialog extends StatefulWidget {
  final String title;
  final List<String> initialTags;
  final List<String> Function(String query) searchFunction;
  final String searchHint;
  final Color activeColor;
  final Function(List<String>) onSave;

  const ProfileEditTagsDialog({
    super.key,
    required this.title,
    required this.initialTags,
    required this.searchFunction,
    required this.searchHint,
    required this.activeColor,
    required this.onSave,
  });

  @override
  State<ProfileEditTagsDialog> createState() => _ProfileEditTagsDialogState();
}

class _ProfileEditTagsDialogState extends State<ProfileEditTagsDialog> {
  late List<String> selectedTags;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedTags = List<String>.from(widget.initialTags);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredTags = widget.searchFunction(searchController.text);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.lightBorderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onSave(selectedTags);
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: AppColors.primaryTeal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: searchController,
              style: const TextStyle(color: AppColors.darkText),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: widget.searchHint,
                hintStyle: TextStyle(
                  color: AppColors.grayText.withValues(alpha: 0.7),
                ),
                prefixIcon: const Icon(Icons.search, color: AppColors.grayText),
                filled: true,
                fillColor: AppColors.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.lightBorderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.lightBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primaryTeal,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Selected chips
          if (selectedTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: selectedTags.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final tag = selectedTags[index];
                    return Chip(
                      label: Text(
                        tag,
                        style: TextStyle(
                          color: widget.activeColor,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: widget.activeColor.withValues(
                        alpha: 0.1,
                      ),
                      deleteIcon: Icon(
                        Icons.close,
                        size: 16,
                        color: widget.activeColor,
                      ),
                      onDeleted: () {
                        setState(() {
                          selectedTags.remove(tag);
                        });
                      },
                      side: BorderSide.none,
                    );
                  },
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Tag list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: filteredTags.length,
              itemBuilder: (context, index) {
                final tag = filteredTags[index];
                final isSelected = selectedTags.contains(tag);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          selectedTags.remove(tag);
                        } else {
                          selectedTags.add(tag);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? widget.activeColor.withValues(alpha: 0.1)
                            : AppColors.inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? widget.activeColor.withValues(alpha: 0.3)
                              : AppColors.lightBorderColor,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? widget.activeColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected
                                    ? widget.activeColor
                                    : AppColors.lightBorderColor,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 14,
                                color: isSelected
                                    ? widget.activeColor
                                    : AppColors.darkText,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
