import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/shift_provider.dart';
import '../../data/providers/repository_providers.dart';
import '../../data/providers/auth_provider.dart';

class OpenShiftDialog extends ConsumerStatefulWidget {
  final String cashierId;
  final String cashierName;

  const OpenShiftDialog({
    super.key,
    required this.cashierId,
    required this.cashierName,
  });

  @override
  ConsumerState<OpenShiftDialog> createState() => _OpenShiftDialogState();
}

class _OpenShiftDialogState extends ConsumerState<OpenShiftDialog> {
  final _formKey = GlobalKey<FormState>();
  final _startingCashController = TextEditingController();
  late final TextEditingController _cashierNameController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cashierNameController = TextEditingController(text: widget.cashierName);
  }

  @override
  void dispose() {
    _startingCashController.dispose();
    _cashierNameController.dispose();
    super.dispose();
  }

  Future<void> _openShift() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final startingCash = double.parse(_startingCashController.text);
    final cashierName = _cashierNameController.text.trim();
    
    // Update profile name if changed
    if (cashierName != widget.cashierName) {
      try {
        await ref.read(staffRepositoryProvider).updateStaffProfile(
          profileId: widget.cashierId,
          name: cashierName,
        );
        // Refresh auth state to update UI everywhere
        ref.read(authProvider.notifier).refreshProfile();
      } catch (e) {
        debugPrint('Failed to update cashier name: $e');
      }
    }

    final shiftNotifier = ref.read(shiftProvider(widget.cashierId).notifier);

    final success = await shiftNotifier.openShift(startingCash);

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shift opened successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to open shift'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.login, color: AppColors.successGreen),
          const SizedBox(width: 12),
          const Text('Open Shift'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cashier Info - Prominent Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.successGreen.withOpacity(0.15),
                    AppColors.successGreen.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.successGreen.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.successGreen,
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _cashierNameController,
                      builder: (context, value, child) {
                        final name = value.text.trim();
                        return Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'C',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Selamat Datang, Kasir!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Cashier Name Input
                  TextFormField(
                    controller: _cashierNameController,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'Nama Kasir',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Masukkan nama kasir';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // Date & Time
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('EEEE, dd MMM yyyy • HH:mm', 'id_ID').format(DateTime.now()),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Instructions
            const Text(
              'Enter the starting cash amount in the register:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // Starting Cash Input
            TextFormField(
              controller: _startingCashController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                labelText: 'Starting Cash',
                helperText: 'Modal awal untuk uang kembalian',
                prefixText: 'Rp ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter starting cash amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount < 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
              autofocus: true,
            ),
            const SizedBox(height: 16),

            // Info Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Count the cash in the drawer before starting.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _openShift,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.successGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Open Shift'),
        ),
      ],
    );
  }
}
