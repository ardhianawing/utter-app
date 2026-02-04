import 'package:flutter/services.dart' as flutter_services;
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../domain/models/monthly_analytics_model.dart';

class AnalyticsPdfService {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static Future<void> exportMonthlyReport({
    required MonthlyAnalyticsModel analytics,
  }) async {
    final pdf = pw.Document();

    // Load logo
    pw.MemoryImage? logo;
    try {
      final logoData = await flutter_services.rootBundle.load('assets/images/logo_collab.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error loading logo for PDF: $e');
    }

    // 1. Cover Page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => _buildCoverPage(analytics, logo),
      ),
    );

    // 2. Executive Summary (Insights)
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => _buildInsightsPage(analytics),
      ),
    );

    // 3. Performance Metrics Section
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => _buildOverviewSection(analytics),
      ),
    );

    // 4. Products & Category Section
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => _buildProductsSection(analytics),
      ),
    );

    // 5. Operations & Shift Section
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => _buildOperationsSection(analytics),
      ),
    );

    // 6. AI Context Page (Raw data for Copying)
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => _buildAiContextPage(analytics),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Utter_Report_${analytics.monthName}_${analytics.year}.pdf',
    );
  }

  static pw.Widget _buildCoverPage(MonthlyAnalyticsModel analytics, pw.MemoryImage? logo) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        color: PdfColors.blue900,
      ),
      child: pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            if (logo != null)
              pw.Container(
                height: 120,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(15),
                ),
                child: pw.Image(logo),
              ),
            pw.SizedBox(height: 50),
            pw.Text(
              'MONTHLY BUSINESS REPORT',
              style: pw.TextStyle(
                fontSize: 34,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
            pw.SizedBox(height: 15),
            pw.Container(
              height: 3,
              width: 100,
              color: PdfColors.amber,
            ),
            pw.SizedBox(height: 25),
            pw.Text(
              '${analytics.monthName.toUpperCase()} ${analytics.year}',
              style: pw.TextStyle(
                fontSize: 22,
                color: PdfColors.blue100,
              ),
            ),
            pw.SizedBox(height: 80),
            pw.Text(
              'UTTER F&B ECOSYSTEM',
              style: pw.TextStyle(
                fontSize: 14,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Generated on ${DateFormat('dd MMMM yyyy').format(DateTime.now())}',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.blue200,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildInsightsPage(MonthlyAnalyticsModel analytics) {
    final insights = _generateInsights(analytics);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Management Summary & Insights'),
        pw.SizedBox(height: 30),
        pw.Text(
          'Key Observations',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
        ),
        pw.SizedBox(height: 15),
        ...insights.map((insight) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 5, right: 10),
                width: 6,
                height: 6,
                decoration: const pw.BoxDecoration(color: PdfColors.amber, shape: pw.BoxShape.circle),
              ),
              pw.Expanded(
                child: pw.Text(insight, style: const pw.TextStyle(fontSize: 12)),
              ),
            ],
          ),
        )),
        pw.Spacer(),
        pw.Container(
          padding: const pw.EdgeInsets.all(15),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'AI Analysis Tip:',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Copy the text from the "AI Context Data" page (last page) and paste it into ChatGPT or Gemini to get deeper strategic advice for next month.',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static List<String> _generateInsights(MonthlyAnalyticsModel analytics) {
    final list = <String>[];
    if (analytics.revenueGrowth != null) {
      final growth = analytics.revenueGrowth!;
      if (growth > 5) {
        list.add('Revenue grew by ${growth.toStringAsFixed(1)}% this month. This indicates a strong upward trend.');
      } else if (growth < -5) {
        list.add('Revenue declined by ${growth.abs().toStringAsFixed(1)}%. Review pricing or launch a promo.');
      } else {
        list.add('Revenue remained stable compared to ${analytics.previousMonthName}.');
      }
    }
    if (analytics.qrisPercentage > 60) {
      list.add('QRIS is highly preferred (${analytics.qrisPercentage.toStringAsFixed(0)}% of sales).');
    }
    if (analytics.peakHour != null) {
      list.add('Peak operational load occurs around ${_formatHour(analytics.peakHour!)}.');
    }
    if (analytics.topProductsByRevenue.isNotEmpty) {
      list.add('"${analytics.topProductsByRevenue.first.productName}" is your star performer.');
    }
    if (analytics.cashDiscrepancies > 2) {
      list.add('Noted ${analytics.cashDiscrepancies} shifts with cash discrepancies.');
    }
    if (list.isEmpty) list.add('Started tracking analytics. Next month will provide comparative data.');
    return list;
  }

  static pw.Widget _buildOverviewSection(MonthlyAnalyticsModel analytics) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Performance Overview'),
        pw.SizedBox(height: 25),
        pw.GridView(
          crossAxisCount: 2,
          childAspectRatio: 2.5,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          children: [
            _buildMetricBox('TOTAL REVENUE', _currencyFormat.format(analytics.totalRevenue), analytics.revenueGrowth, PdfColors.blue900),
            _buildMetricBox('TOTAL ORDERS', analytics.totalOrders.toString(), analytics.ordersGrowth, PdfColors.green700),
            _buildMetricBox('AVG ORDER VALUE', _currencyFormat.format(analytics.averageOrderValue), analytics.aovGrowth, PdfColors.blue700),
            _buildMetricBox('PRODUCTS SOLD', analytics.totalProductsSold.toString(), null, PdfColors.orange800),
          ],
        ),
        pw.SizedBox(height: 35),
        pw.Text('Revenue Distribution', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        pw.SizedBox(height: 15),
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildSimpleBar('Payment Method', [
                _BarItem('Cash', analytics.cashPercentage, PdfColors.green),
                _BarItem('QRIS', analytics.qrisPercentage, PdfColors.blue),
                _BarItem('Debit', analytics.debitPercentage, PdfColors.orange),
              ]),
            ),
            pw.SizedBox(width: 20),
            pw.Expanded(
              child: _buildSimpleBar('Order Source', [
                ...analytics.revenueBySource.entries.map((e) {
                   final total = analytics.totalRevenue > 0 ? analytics.totalRevenue : 1;
                   return _BarItem(e.key, (e.value / total) * 100, PdfColors.indigo900);
                }),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildMetricBox(String label, String value, double? growth, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
              if (growth != null)
                pw.Text(
                  '${growth > 0 ? '+' : ''}${growth.toStringAsFixed(1)}%',
                  style: pw.TextStyle(fontSize: 10, color: growth > 0 ? PdfColors.green700 : PdfColors.red700, fontWeight: pw.FontWeight.bold),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSimpleBar(String title, List<_BarItem> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
        pw.SizedBox(height: 10),
        ...items.where((i) => i.percent > 0).map((item) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(item.label, style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('${item.percent.toStringAsFixed(1)}%', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Container(
                height: 4,
                width: 150,
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                child: pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Container(
                    width: (item.percent / 100) * 150,
                    height: 4,
                    decoration: pw.BoxDecoration(color: item.color),
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  static pw.Widget _buildProductsSection(MonthlyAnalyticsModel analytics) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Product Performance'),
        pw.SizedBox(height: 25),
        pw.Text('Star Performers (Top 10)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        pw.SizedBox(height: 15),
        pw.Table(
          border: const pw.TableBorder(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
          columnWidths: {
            0: const pw.FixedColumnWidth(30),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildTableHeader('#'),
                _buildTableHeaderCenter('Menu Item'),
                _buildTableHeaderCenter('Qty Sold'),
                _buildTableHeaderCenter('Revenue'),
              ],
            ),
            ...analytics.topProductsByRevenue.take(10).toList().asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              return pw.TableRow(
                children: [
                  _buildTableCell('${index + 1}'),
                  _buildTableCellItem(product.productName),
                  _buildTableCell(product.totalQuantity.toString()),
                  _buildTableCell(_currencyFormat.format(product.totalRevenue)),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildOperationsSection(MonthlyAnalyticsModel analytics) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Operational Efficiency'),
        pw.SizedBox(height: 25),
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildOpCard('Avg Prep Time', 
                analytics.averagePreparationTime != null ? '${analytics.averagePreparationTime!.toStringAsFixed(1)}m' : 'N/A'),
            ),
             pw.SizedBox(width: 15),
            pw.Expanded(
              child: _buildOpCard('Peak Hour', 
                analytics.peakHour != null ? _formatHour(analytics.peakHour!) : 'N/A'),
            ),
             pw.SizedBox(width: 15),
            pw.Expanded(
              child: _buildOpCard('Loyalty Net', 
                '+${analytics.netPoints} pts'),
            ),
          ],
        ),
        pw.SizedBox(height: 30),
        pw.Text('Sustainability & Risks', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        pw.SizedBox(height: 15),
        pw.Table(
          children: [
            _buildInfoRow('Cancellation Revenue Lost', _currencyFormat.format(analytics.cancelledRevenue)),
            _buildInfoRow('Cancellation Rate', '${analytics.cancelRate.toStringAsFixed(1)}%'),
            _buildInfoRow('Cash Reconciliation Discrepancies', '${analytics.cashDiscrepancies} shifts'),
            _buildInfoRow('Reconciliation Success Rate', '${analytics.cashReconciliationRate.toStringAsFixed(1)}%'),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildAiContextPage(MonthlyAnalyticsModel analytics) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('AI Analysis Context Data'),
        pw.SizedBox(height: 20),
        pw.Text(
          'INSTRUCTIONS:',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Copy the structured text below and paste it into ChatGPT, Gemini, or Claude.',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 20),
        pw.Container(
          padding: const pw.EdgeInsets.all(15),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey50,
            borderRadius: pw.BorderRadius.circular(5),
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Text(
            analytics.toAiContext(),
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSectionHeader(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.amber800,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Container(height: 1, width: double.infinity, color: PdfColors.grey300),
      ],
    );
  }

  static pw.Widget _buildTableHeader(String text) {
     return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
    );
  }
  static pw.Widget _buildTableHeaderCenter(String text) {
     return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
    );
  }

  static pw.Widget _buildTableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center),
    );
  }
  static pw.Widget _buildTableCellItem(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
    );
  }

  static pw.TableRow _buildInfoRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900), textAlign: pw.TextAlign.right),
        ),
      ],
    );
  }

  static pw.Widget _buildOpCard(String label, String value) {
     return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.blue200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.blue700, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        ],
      ),
    );
  }

  static String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }
}

class _BarItem {
  final String label;
  final double percent;
  final PdfColor color;
  _BarItem(this.label, this.percent, this.color);
}
