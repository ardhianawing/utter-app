import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:utter_app/features/customer/data/providers/order_context_provider.dart';
import 'package:utter_app/features/customer/presentation/pages/menu_page.dart';

class QRScannerPage extends ConsumerStatefulWidget {
  const QRScannerPage({super.key});

  @override
  ConsumerState<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends ConsumerState<QRScannerPage> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code Meja'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController.torchState,
              builder: (context, state, child) {
                switch (state) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off);
                  case TorchState.on:
                    return const Icon(Icons.flash_on);
                  default:
                    return const Icon(Icons.flash_off);
                }
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),
          // Overlay with scan frame
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: const Text(
                'Arahkan kamera ke QR code di meja',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawValue = barcodes.first.rawValue;
    if (rawValue == null) return;

    setState(() => _isProcessing = true);

    try {
      // Parse URL
      final uri = Uri.parse(rawValue);

      // Validate format: https://utter.app/order?table_id=xxx&table_number=x
      if (uri.host != 'utter.app' || uri.path != '/order') {
        _showError('QR code tidak valid. Gunakan QR code dari meja.');
        return;
      }

      final tableId = uri.queryParameters['table_id'];
      final tableNumberStr = uri.queryParameters['table_number'];

      if (tableId == null || tableNumberStr == null) {
        _showError('QR code rusak atau tidak lengkap.');
        return;
      }

      final tableNumber = int.tryParse(tableNumberStr);
      if (tableNumber == null) {
        _showError('Nomor meja tidak valid.');
        return;
      }

      // TODO: Optionally validate table exists in database
      // final supabase = Supabase.instance.client;
      // final response = await supabase
      //     .from('tables')
      //     .select()
      //     .eq('id', tableId)
      //     .maybeSingle();
      //
      // if (response == null) {
      //   _showError('Meja tidak ditemukan. Hubungi staff.');
      //   return;
      // }

      // Set order context
      ref.read(orderContextProvider.notifier).setTableContext(tableId, tableNumber);

      // Navigate to menu page
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MenuPage(
            tableId: tableId,
            tableNumber: tableNumber,
          ),
        ),
      );
    } catch (e) {
      _showError('Gagal membaca QR code: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );

    setState(() => _isProcessing = false);
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}
