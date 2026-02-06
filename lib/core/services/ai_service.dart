import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:utter_app/core/constants/ai_config.dart';
import 'package:utter_app/features/shared/models/models.dart';
import 'package:utter_app/features/customer/data/repositories/product_repository.dart';
import 'package:utter_app/features/cashier/data/repositories/order_repository.dart';
import 'package:utter_app/features/cashier/data/repositories/shift_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiService {
  final ProductRepository _productRepo;
  final OrderRepository _orderRepo;
  final ShiftRepository _shiftRepo;

  AiService(this._productRepo, this._orderRepo, this._shiftRepo);

  Future<String> chat(String message, List<Map<String, dynamic>> history) async {
    final url = Uri.parse('${AiConfig.geminiBaseUrl}/models/${AiConfig.geminiModel}:generateContent?key=${AiConfig.geminiApiKey}');

    final systemPrompt = """
You are 'Utter AI Manager', a digital CEO assistant and system expert for the Utter F&B Ecosystem.

RULES:
1. BE CONCISE: Jawaban harus to-the-point, singkat, dan padat.
2. ACTION-ORIENTED: Fokus pada data dan eksekusi perintah.
3. PRIMARY LANGUAGE: Bahasa Indonesia yang profesional dan lugas.
4. SYSTEM EXPERT: Anda memahami seluruh alur aplikasi Utter F&B dan bisa bertindak sebagai User Manual bagi admin/staff.

KNOWLEDGE BASE (STRUKTUR APLIKASI):
1. DASHBOARD & SALES:
   - Dashboard menampilkan ringkasan penjualan hari ini (Total Sales, Orders, breakdown via App/POS/Online).
   - Real-time notifications muncul setiap ada order baru masuk.
2. ALUR ORDER (POS):
   - Kolom Kiri: 'Pesanan Masuk' (Incoming Orders) - Kelola status pesanan dari PENDING_PAYMENT -> PAID -> PREPARING -> READY -> COMPLETED.
   - Kolom Tengah: 'Menu & Pesanan Manual' - Cari produk, filter kategori, klik produk untuk masuk ke Keranjang.
   - Kolom Kanan: 'Keranjang' - Atur jumlah, tambah catatan (notes), pilih tipe order (Dine-in/Takeaway), pilih meja (jika Dine-in), dan pilih metode pembayaran (Cash/QRIS/Debit).
3. MANAJEMEN SHIFT:
   - Kasir WAJIB 'Buka Shift' sebelum transaksi dengan menginput modal awal.
   - Akhiri hari dengan 'Tutup Shift' untuk rekonsiliasi kas (Input uang fisik vs sistem).
   - 'Riwayat Shift' dapat diakses dari menu profil.
4. ONLINE & MANUAL ENTRY:
   - Mendukung input manual untuk GoFood, GrabFood, ShopeeFood.
   - Gunakan fitur 'Manual Entry' untuk input order bulk atau dari platform luar.
5. ADMIN TOOLS:
   - 'Manage Menu': Tambah produk baru, ubah harga, stok (habis/ada), status promo, atau hapus menu.
   - 'Laporan Produk': Analisis produk mana yang paling laris.
   - 'Monthly Analytics': Laporan performa bulanan (Admin Only).
6. KITCHEN DISPLAY (KDS):
   - Tampilan khusus dapur untuk memantau pesanan yang sedang diproses.

CAPABILITIES:
- MENU: Create, Update (Price/Stock), Delete.
- SALES: Real-time Today's Sales, Top Products, Monthly Analytics.
- HELP: Jelaskan cara pakai fitur tertentu jika user bertanya.

Current Date: ${DateTime.now().toString()}
Note: Selalu konfirmasi singkat sebelum melakukan aksi hapus/tambah/ubah data.
""";

    // Convert history from OpenAI format to Gemini format
    final geminiContents = <Map<String, dynamic>>[];

    // Add system prompt as first user message
    geminiContents.add({
      'role': 'user',
      'parts': [{'text': systemPrompt}]
    });
    geminiContents.add({
      'role': 'model',
      'parts': [{'text': 'Understood. I am Utter AI Manager, ready to assist.'}]
    });

    // Convert history
    for (var msg in history) {
      if (msg['role'] == 'user') {
        geminiContents.add({
          'role': 'user',
          'parts': [{'text': msg['content']}]
        });
      } else if (msg['role'] == 'assistant') {
        geminiContents.add({
          'role': 'model',
          'parts': [{'text': msg['content']}]
        });
      }
    }

    // Add current message
    geminiContents.add({
      'role': 'user',
      'parts': [{'text': message}]
    });

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': geminiContents,
          'tools': [
            {
              'functionDeclarations': _getGeminiFunctionDeclarations(),
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 2048,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'];

        if (candidates == null || candidates.isEmpty) {
          return "Error: No response from AI";
        }

        final content = candidates[0]['content'];
        final parts = content['parts'];

        // Check for function calls
        if (parts != null && parts.isNotEmpty) {
          for (var part in parts) {
            if (part['functionCall'] != null) {
              // Handle function call
              final functionCall = part['functionCall'];
              final functionName = functionCall['name'];
              final arguments = functionCall['args'] ?? {};

              final result = await _executeFunctionCall(functionName, arguments);

              // Return result directly for now (simplified)
              return result;
            } else if (part['text'] != null) {
              return part['text'];
            }
          }
        }

        return "No valid response from AI";
      } else {
        return "Error: ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      return "Exception: $e";
    }
  }

  List<Map<String, dynamic>> _getGeminiFunctionDeclarations() {
    return [
      {
        'name': 'get_products',
        'description': 'Mendapatkan daftar semua produk dan harganya.',
        'parameters': {
          'type': 'object',
          'properties': {},
        },
      },
      {
        'name': 'update_product',
        'description': 'Mengupdate informasi produk seperti nama, deskripsi, harga, kategori, atau status promo.',
        'parameters': {
          'type': 'object',
          'properties': {
            'productId': {'type': 'string', 'description': 'ID produk'},
            'name': {'type': 'string', 'description': 'Nama produk'},
            'description': {'type': 'string', 'description': 'Deskripsi produk'},
            'price': {'type': 'number', 'description': 'Harga produk'},
            'category': {'type': 'string', 'description': 'BEVERAGE_COFFEE, BEVERAGE_NON_COFFEE, FOOD, SNACK, OTHER'},
            'isPromo': {'type': 'boolean', 'description': 'Status promo'},
            'promoDiscountPercent': {'type': 'number', 'description': 'Persentase diskon'},
            'isFeatured': {'type': 'boolean', 'description': 'Status featured'},
          },
          'required': ['productId'],
        },
      },
      {
        'name': 'update_stock_status',
        'description': 'Mengubah status ketersediaan stok produk (Tersedia/Habis).',
        'parameters': {
          'type': 'object',
          'properties': {
            'productId': {'type': 'string', 'description': 'ID produk'},
            'isActive': {'type': 'boolean', 'description': 'Set true untuk tersedia, false untuk habis'},
          },
          'required': ['productId', 'isActive'],
        },
      },
      {
        'name': 'update_stock_quantity',
        'description': 'Mengupdate jumlah stok (quantity) produk secara spesifik.',
        'parameters': {
          'type': 'object',
          'properties': {
            'productId': {'type': 'string', 'description': 'ID produk'},
            'stockQty': {'type': 'integer', 'description': 'Jumlah stok baru'},
          },
          'required': ['productId', 'stockQty'],
        },
      },
      {
        'name': 'create_product',
        'description': 'Menambah menu baru ke dalam sistem.',
        'parameters': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'description': 'Nama menu'},
            'description': {'type': 'string', 'description': 'Deskripsi menu'},
            'price': {'type': 'number', 'description': 'Harga dasar'},
            'category': {
              'type': 'string',
              'description': 'Kategori: BEVERAGE_COFFEE, BEVERAGE_NON_COFFEE, FOOD, SNACK, OTHER'
            },
          },
          'required': ['name', 'price', 'category'],
        },
      },
      {
        'name': 'delete_product',
        'description': 'Menghapus atau menonaktifkan menu dari daftar.',
        'parameters': {
          'type': 'object',
          'properties': {
            'productId': {'type': 'string', 'description': 'ID produk yang akan dihapus'},
          },
          'required': ['productId'],
        },
      },
      {
        'name': 'get_today_sales',
        'description': 'Mendapatkan ringkasan penjualan hari ini secara real-time.',
        'parameters': {
          'type': 'object',
          'properties': {},
        },
      },
      {
        'name': 'get_top_products',
        'description': 'Mendapatkan daftar produk terlaris berdasarkan kuantitas dan pendapatan.',
        'parameters': {
          'type': 'object',
          'properties': {
            'year': {'type': 'integer', 'description': 'Tahun (opsional, default tahun ini)'},
            'month': {'type': 'integer', 'description': 'Bulan 1-12 (opsional, default bulan ini)'},
            'limit': {'type': 'integer', 'description': 'Jumlah produk (default 5)'},
          },
        },
      },
      {
        'name': 'get_shift_analytics',
        'description': 'Mendapatkan data analitik shift kerja (durasi, rata-rata pendapatan per shift, rekonsiliasi kas).',
        'parameters': {
          'type': 'object',
          'properties': {
            'year': {'type': 'integer', 'description': 'Tahun'},
            'month': {'type': 'integer', 'description': 'Bulan'},
          },
          'required': ['year', 'month'],
        },
      },
      {
        'name': 'get_monthly_analytics',
        'description': 'Mendapatkan laporan performa bisnis bulanan lengkap.',
        'parameters': {
          'type': 'object',
          'properties': {
            'year': {'type': 'integer', 'description': 'Tahun'},
            'month': {'type': 'integer', 'description': 'Bulan'},
          },
          'required': ['year', 'month'],
        },
      },
    ];
  }

  Future<String> _executeFunctionCall(String functionName, Map<String, dynamic> arguments) async {
    try {
      dynamic functionResponse;

      if (functionName == 'get_products') {
        final products = await _productRepo.getProducts();
        functionResponse = products.map((p) => {
          'id': p.id,
          'name': p.name,
          'price': p.price,
          'is_active': p.isActive,
          'category': p.category.name,
        }).toList();
        return 'Daftar Produk:\n${products.map((p) => '- ${p.name}: Rp ${p.price.toStringAsFixed(0)} (${p.isActive ? "Tersedia" : "Habis"})').join('\n')}';
      } else if (functionName == 'update_product') {
        final categoryStr = arguments['category'];
        ProductCategory? category;
        if (categoryStr != null) {
          category = ProductCategory.values.firstWhere(
            (e) => e.name == categoryStr,
            orElse: () => ProductCategory.OTHER,
          );
        }

        await _productRepo.updateProduct(
          id: arguments['productId'],
          name: arguments['name'],
          description: arguments['description'],
          price: arguments['price']?.toDouble(),
          category: category,
          isPromo: arguments['isPromo'],
          promoDiscountPercent: arguments['promoDiscountPercent']?.toDouble(),
          isFeatured: arguments['isFeatured'],
        );
        return '✅ Produk berhasil diperbarui';
      } else if (functionName == 'update_stock_status') {
        await _productRepo.updateProduct(
          id: arguments['productId'],
          isActive: arguments['isActive'],
        );
        return '✅ Status stok berhasil diperbarui';
      } else if (functionName == 'update_stock_quantity') {
        await _productRepo.updateProduct(
          id: arguments['productId'],
          stockQty: arguments['stockQty'],
        );
        return '✅ Jumlah stok berhasil diperbarui';
      } else if (functionName == 'create_product') {
        final categoryStr = arguments['category'];
        final category = ProductCategory.values.firstWhere(
          (e) => e.name == categoryStr,
          orElse: () => ProductCategory.OTHER,
        );

        await _productRepo.createProduct(
          name: arguments['name'],
          description: arguments['description'] ?? '',
          price: arguments['price'].toDouble(),
          category: category,
        );
        return '✅ Produk "${arguments['name']}" berhasil ditambahkan';
      } else if (functionName == 'delete_product') {
        await _productRepo.deleteProduct(arguments['productId']);
        return '✅ Produk berhasil dihapus';
      } else if (functionName == 'get_today_sales') {
        final summary = await _orderRepo.getTodaySalesSummary();
        return '''
📊 Ringkasan Penjualan Hari Ini:
- Total Penjualan: Rp ${(summary['totalSales'] ?? 0).toStringAsFixed(0)}
- Total Order: ${summary['totalOrders'] ?? 0}
- Order via App: ${summary['appOrders'] ?? 0}
- Order via POS: ${summary['posOrders'] ?? 0}
''';
      } else if (functionName == 'get_top_products') {
        final now = DateTime.now();
        final year = arguments['year'] ?? now.year;
        final month = arguments['month'] ?? now.month;
        final limit = arguments['limit'] ?? 5;

        final topProducts = await _orderRepo.getTopProducts(year, month, limit: limit);
        topProducts.sort((a, b) => (b['total_quantity'] as num).compareTo(a['total_quantity'] as num));

        final result = topProducts.take(limit).map((p) =>
          '${p['product_name']}: ${p['total_quantity']} terjual, Rp ${(p['total_revenue'] as num).toStringAsFixed(0)}'
        ).join('\n');

        return '🏆 Top $limit Produk Terlaris:\n$result';
      } else if (functionName == 'get_shift_analytics') {
        final analytics = await _shiftRepo.getMonthlyShiftAnalytics(
          arguments['year'],
          arguments['month'],
        );
        return '''
📅 Analitik Shift:
- Total Shift: ${analytics['totalShifts'] ?? 0}
- Durasi Rata-rata: ${analytics['avgDuration'] ?? 0} jam
- Pendapatan per Shift: Rp ${(analytics['avgRevenue'] ?? 0).toStringAsFixed(0)}
''';
      } else if (functionName == 'get_monthly_analytics') {
        final year = arguments['year'];
        final month = arguments['month'];

        final analytics = await _orderRepo.getMonthlyAnalytics(year, month);
        return '''
📈 Laporan Bulanan:
- Total Pendapatan: Rp ${(analytics['totalRevenue'] ?? 0).toStringAsFixed(0)}
- Total Order: ${analytics['totalOrders'] ?? 0}
- AOV: Rp ${(analytics['avgOrderValue'] ?? 0).toStringAsFixed(0)}
''';
      }

      return 'Function executed but no response generated';
    } catch (e) {
      return '❌ Error: $e';
    }
  }
}
