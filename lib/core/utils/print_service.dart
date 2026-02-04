import 'package:flutter/services.dart' as flutter_services;
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../features/shared/models/models.dart';

class PrintService {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static Future<void> printReceipt({
    required Order order,
    required List<Map<String, dynamic>> items,
    int? tableNumber,
  }) async {
    final pdf = pw.Document();
    
    // Load logo (Partnership Logo)
    pw.MemoryImage? logo;
    try {
      final logoData = await flutter_services.rootBundle.load('assets/images/logo_collab.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error loading logo for print: $e');
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    if (logo != null) 
                      pw.Container(
                        height: 50,
                        child: pw.Image(logo),
                      ),
                    pw.SizedBox(height: 10),
                  ],
                ),
              ),
              pw.Divider(),
              pw.Text('Order: #${order.displayId ?? order.id.substring(0, 8)}'),
              pw.Text('Date: ${DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt)}'),
              pw.Text('Customer: ${order.customerName ?? 'Guest'}'),
              if (tableNumber != null) pw.Text('Table: #$tableNumber'),
              pw.Text('Order Type: ${order.type.name}'),
              pw.Divider(),
              pw.SizedBox(height: 5),
              ...items.map((item) {
                final productName = item['products']?['name'] ?? 'Unknown';
                final qty = item['quantity'] as int;
                final price = (item['unit_price'] as num).toDouble();
                final subtotal = price * qty;
                final notes = item['notes'] as String?;

                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(child: pw.Text('$productName x$qty')),
                        pw.Text(_currencyFormat.format(subtotal)),
                      ],
                    ),
                    if (item['selected_modifiers'] != null && (item['selected_modifiers'] as List).isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 10),
                        child: pw.Text(
                          'Detail: ' + (item['selected_modifiers'] as List)
                              .map((m) => m['name'] ?? m['id'] ?? '')
                              .join(', '), 
                          style: pw.TextStyle(fontSize: 8, color: PdfColors.blue)
                        ),
                      ),
                    if (notes != null && notes.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 10),
                        child: pw.Text('Note: $notes', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
                      ),
                    pw.SizedBox(height: 2),
                  ],
                );
              }),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(_currencyFormat.format(order.totalAmount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Text('Payment: ${order.paymentMethod.name}'),
              if (order.paymentMethod == PaymentMethod.CASH && order.cashReceived != null) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Tunai Diterima'),
                    pw.Text(_currencyFormat.format(order.cashReceived)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Kembalian'),
                    pw.Text(_currencyFormat.format(order.cashChange ?? 0)),
                  ],
                ),
              ],
              pw.Divider(),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.SizedBox(height: 10),
                    pw.Text('Thank You!', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Please come again'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> printShiftReport({
    required Shift shift,
    required ShiftSummary summary,
    required String cashierName,
  }) async {
    final pdf = pw.Document();
    
    // Load logo (Partnership Logo)
    pw.MemoryImage? logo;
    try {
      final logoData = await flutter_services.rootBundle.load('assets/images/logo_collab.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error loading logo for shift print: $e');
    }

    final s = summary.shift;
    final expectedCash = s.expectedCash ?? (s.startingCash + s.totalCashReceived);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    if (logo != null) 
                      pw.Container(
                        height: 50,
                        child: pw.Image(logo),
                      ),
                    pw.Text('LAPORAN AKHIR SHIFT', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text('UTTER F&B POS', style: pw.TextStyle(fontSize: 8)),
                    pw.SizedBox(height: 8),
                  ],
                ),
              ),
              pw.Divider(),

              // Shift Info
              pw.Text('Kasir: $cashierName', style: pw.TextStyle(fontSize: 9)),
              pw.Text('Mulai: ${DateFormat('dd/MM/yyyy HH:mm').format(shift.startTime)}', style: pw.TextStyle(fontSize: 9)),
              pw.Text('Selesai: ${shift.endTime != null ? DateFormat('dd/MM/yyyy HH:mm').format(shift.endTime!) : '-'}', style: pw.TextStyle(fontSize: 9)),
              pw.Text('Durasi: ${shift.durationFormatted}', style: pw.TextStyle(fontSize: 9)),
              pw.Text('Total Order: ${summary.orderCount}', style: pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 8),

              // Revenue Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PENDAPATAN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.SizedBox(height: 4),
                    _buildPdfRow('Tunai', s.totalCashReceived),
                    _buildPdfRow('QRIS', s.totalQrisReceived),
                    _buildPdfRow('Debit', s.totalDebitReceived),
                    pw.Divider(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text(_currencyFormat.format(s.totalSales), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),

              // Cash Reconciliation
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('REKONSILIASI KAS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.SizedBox(height: 4),
                    _buildPdfRow('Modal Awal', s.startingCash),
                    _buildPdfRow('+ Uang Diterima', s.totalCashReceived),
                    pw.Divider(),
                    _buildPdfRow('Seharusnya', expectedCash, bold: true),
                    if (shift.endingCash != null) ...[
                      _buildPdfRow('Hasil Hitung', shift.endingCash!),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Selisih', style: pw.TextStyle(fontSize: 9)),
                          pw.Text(
                            summary.cashDifferenceFormatted,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                              color: (shift.cashDifference ?? 0) < 0 ? PdfColors.red : PdfColors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 8),

              // Deposit & Leave
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('SETOR & TINGGAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.SizedBox(height: 4),
                    _buildPdfRow('Setor ke Owner', s.totalCashReceived, bold: true),
                    pw.Text('(Pendapatan tunai)', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
                    pw.SizedBox(height: 4),
                    _buildPdfRow('Tinggal di Laci', s.startingCash, bold: true),
                    pw.Text('(Modal shift berikut)', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),

              // Top Products
              if (summary.topProducts.isNotEmpty) ...[
                pw.Text('PRODUK TERLARIS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.SizedBox(height: 4),
                ...summary.topProducts.take(5).map((product) {
                  return pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(child: pw.Text(product.productName, style: pw.TextStyle(fontSize: 8))),
                      pw.Text('${product.totalQuantity}x', style: pw.TextStyle(fontSize: 8)),
                      pw.SizedBox(width: 4),
                      pw.Text(_currencyFormat.format(product.totalRevenue), style: pw.TextStyle(fontSize: 8)),
                    ],
                  );
                }),
                pw.SizedBox(height: 8),
              ],

              // Notes
              if (shift.notes != null && shift.notes!.isNotEmpty) ...[
                pw.Divider(),
                pw.Text('Catatan: ${shift.notes}', style: pw.TextStyle(fontSize: 8)),
              ],

              pw.Divider(),
              pw.Center(
                child: pw.Text('*** Akhir Laporan ***', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static pw.Widget _buildPdfRow(String label, double amount, {bool bold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text(_currencyFormat.format(amount), style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ],
    );
  }
}
