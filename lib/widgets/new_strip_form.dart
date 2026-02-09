import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'expiry_date_picker.dart';

/// Bottom sheet form for adding a new medicine strip
/// Updates both expiry date AND quantity
class NewStripForm extends StatefulWidget {
  final String medicineName;
  final Function(DateTime expiryDate, int quantity) onSubmit;

  const NewStripForm({
    super.key,
    required this.medicineName,
    required this.onSubmit,
  });

  /// Show the form as a bottom sheet
  static Future<void> show(
    BuildContext context, {
    required String medicineName,
    required Function(DateTime expiryDate, int quantity) onSubmit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          NewStripForm(medicineName: medicineName, onSubmit: onSubmit),
    );
  }

  @override
  State<NewStripForm> createState() => _NewStripFormState();
}

class _NewStripFormState extends State<NewStripForm> {
  late DateTime _selectedDate;
  int _selectedQuantity = 10;
  final TextEditingController _customQuantityController =
      TextEditingController();
  bool _showCustomInput = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month + 6, 1); // Default 6 months
  }

  @override
  void dispose() {
    _customQuantityController.dispose();
    super.dispose();
  }

  void _submit() {
    int quantity = _selectedQuantity;
    if (_showCustomInput) {
      quantity = int.tryParse(_customQuantityController.text) ?? 10;
    }
    Navigator.of(context).pop();
    widget.onSubmit(_selectedDate, quantity);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      color: AppColors.primaryTeal,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add New Strip',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkText,
                          ),
                        ),
                        Text(
                          widget.medicineName,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.grayText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Expiry Date Section
              const Text(
                'New Expiry Date',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 10),
              ExpiryDatePickerCompact(
                initialDate: _selectedDate,
                onDateSelected: (date) {
                  setState(() => _selectedDate = date);
                },
              ),
              const SizedBox(height: 24),

              // Quantity Section
              const Text(
                'Tablets in New Strip',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 12),

              // Quick quantity buttons
              if (!_showCustomInput)
                Row(
                  children: [
                    _buildQuantityButton(10),
                    const SizedBox(width: 12),
                    _buildQuantityButton(15),
                    const SizedBox(width: 12),
                    _buildCustomButton(),
                  ],
                ),

              // Custom quantity input
              if (_showCustomInput) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customQuantityController,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Enter quantity',
                          filled: true,
                          fillColor: AppColors.inputBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.lightBorderColor,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.lightBorderColor,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primaryTeal,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showCustomInput = false;
                          _selectedQuantity = 10;
                        });
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Update Strip',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityButton(int quantity) {
    final isSelected = _selectedQuantity == quantity && !_showCustomInput;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedQuantity = quantity;
            _showCustomInput = false;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryTeal.withValues(alpha: 0.1)
                : AppColors.inputBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryTeal
                  : AppColors.lightBorderColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '+$quantity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? AppColors.primaryTeal
                      : AppColors.darkText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'tablets',
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? AppColors.primaryTeal
                      : AppColors.grayText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomButton() {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _showCustomInput = true);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.inputBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.lightBorderColor),
          ),
          child: Column(
            children: [
              Icon(Icons.edit_rounded, size: 20, color: AppColors.grayText),
              const SizedBox(height: 4),
              Text(
                'Custom',
                style: TextStyle(fontSize: 11, color: AppColors.grayText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quantity selector used when adding medicine to cabinet
class QuantitySelector extends StatefulWidget {
  final int initialValue;
  final ValueChanged<int> onChanged;

  const QuantitySelector({
    super.key,
    this.initialValue = 10,
    required this.onChanged,
  });

  @override
  State<QuantitySelector> createState() => _QuantitySelectorState();
}

class _QuantitySelectorState extends State<QuantitySelector> {
  late int _quantity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialValue;
  }

  void _updateQuantity(int delta) {
    final newValue = _quantity + delta;
    if (newValue >= 1 && newValue <= 100) {
      setState(() => _quantity = newValue);
      widget.onChanged(_quantity);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _updateQuantity(-1),
            icon: const Icon(Icons.remove_rounded),
            iconSize: 20,
            color: AppColors.grayText,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          Container(
            width: 50,
            alignment: Alignment.center,
            child: Text(
              '$_quantity',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _updateQuantity(1),
            icon: const Icon(Icons.add_rounded),
            iconSize: 20,
            color: AppColors.primaryTeal,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }
}
