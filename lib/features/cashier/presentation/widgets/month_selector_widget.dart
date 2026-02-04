import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class MonthSelectorWidget extends StatelessWidget {
  final int selectedYear;
  final int selectedMonth;
  final Function(int year, int month) onMonthChanged;

  const MonthSelectorWidget({
    super.key,
    required this.selectedYear,
    required this.selectedMonth,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _goToPreviousMonth,
              tooltip: 'Previous Month',
              color: AppColors.infoBlue,
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _showMonthYearPicker(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.infoBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_month,
                        size: 20,
                        color: AppColors.infoBlue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getMonthYearText(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_drop_down,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _isNextMonthDisabled() ? null : _goToNextMonth,
              tooltip: 'Next Month',
              color: _isNextMonthDisabled() ? Colors.grey : AppColors.infoBlue,
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthYearText() {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[selectedMonth]} $selectedYear';
  }

  bool _isNextMonthDisabled() {
    final now = DateTime.now();
    return selectedYear > now.year ||
           (selectedYear == now.year && selectedMonth >= now.month);
  }

  void _goToPreviousMonth() {
    if (selectedMonth == 1) {
      onMonthChanged(selectedYear - 1, 12);
    } else {
      onMonthChanged(selectedYear, selectedMonth - 1);
    }
  }

  void _goToNextMonth() {
    if (_isNextMonthDisabled()) return;

    if (selectedMonth == 12) {
      onMonthChanged(selectedYear + 1, 1);
    } else {
      onMonthChanged(selectedYear, selectedMonth + 1);
    }
  }

  Future<void> _showMonthYearPicker(BuildContext context) async {
    final now = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => _MonthYearPickerDialog(
        initialYear: selectedYear,
        initialMonth: selectedMonth,
        minYear: 2020,
        maxYear: now.year,
        onSelected: (year, month) {
          onMonthChanged(year, month);
        },
      ),
    );
  }
}

class _MonthYearPickerDialog extends StatefulWidget {
  final int initialYear;
  final int initialMonth;
  final int minYear;
  final int maxYear;
  final Function(int year, int month) onSelected;

  const _MonthYearPickerDialog({
    required this.initialYear,
    required this.initialMonth,
    required this.minYear,
    required this.maxYear,
    required this.onSelected,
  });

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int selectedYear;
  late int selectedMonth;

  @override
  void initState() {
    super.initState();
    selectedYear = widget.initialYear;
    selectedMonth = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    final years = List.generate(
      widget.maxYear - widget.minYear + 1,
      (index) => widget.maxYear - index,
    );

    return AlertDialog(
      title: const Text('Select Month'),
      content: SizedBox(
        width: 300,
        height: 400,
        child: Column(
          children: [
            DropdownButtonFormField<int>(
              value: selectedYear,
              decoration: const InputDecoration(
                labelText: 'Year',
                border: OutlineInputBorder(),
              ),
              items: years.map((year) {
                return DropdownMenuItem(
                  value: year,
                  child: Text(year.toString()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedYear = value);
                }
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final month = index + 1;
                  final now = DateTime.now();
                  final isDisabled = selectedYear == now.year && month > now.month;
                  final isSelected = selectedMonth == month;

                  return InkWell(
                    onTap: isDisabled ? null : () {
                      setState(() => selectedMonth = month);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.infoBlue
                            : (isDisabled ? Colors.grey.shade200 : Colors.transparent),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.infoBlue
                              : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        months[index].substring(0, 3),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDisabled ? Colors.grey : AppColors.textPrimary),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSelected(selectedYear, selectedMonth);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.infoBlue,
            foregroundColor: Colors.white,
          ),
          child: const Text('Select'),
        ),
      ],
    );
  }
}
