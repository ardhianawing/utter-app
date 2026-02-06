import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:utter_app/core/constants/ai_config.dart';
import 'package:utter_app/features/shared/models/models.dart';
import 'package:utter_app/features/customer/data/repositories/product_repository.dart';
import 'package:utter_app/features/cashier/data/repositories/order_repository.dart';
import 'package:utter_app/features/cashier/data/repositories/shift_repository.dart';
import 'package:utter_app/features/storage/data/repositories/storage_repository.dart';
import 'package:utter_app/features/storage/domain/models/storage_models.dart';
import 'package:utter_app/features/finance/data/repositories/expense_repository.dart';
import 'package:utter_app/features/finance/domain/models/expense_models.dart';

class AiService {
  final ProductRepository _productRepo;
  final OrderRepository _orderRepo;
  final ShiftRepository _shiftRepo;
  final StorageRepository _storageRepo;
  final ExpenseRepository _expenseRepo;

  AiService(this._productRepo, this._orderRepo, this._shiftRepo, this._storageRepo, this._expenseRepo);

  Future<String> chat(String message, List<Map<String, dynamic>> history) async {
    final url = Uri.parse('${AiConfig.baseUrl}/chat/completions');

    final systemPrompt = """
You are 'Utter AI Manager', the intelligent brain and digital assistant for the Utter F&B POS System.

════════════════════════════════════════════════════════════════════════════════
CORE IDENTITY & RULES
════════════════════════════════════════════════════════════════════════════════
1. BE CONCISE: Jawaban singkat, padat, to-the-point. Tidak bertele-tele.
2. ACTION-ORIENTED: Fokus pada data faktual dan eksekusi perintah.
3. PRIMARY LANGUAGE: Bahasa Indonesia profesional dan lugas.
4. COMPLETE MASTERY: Anda tahu SEMUA tentang cara mengoperasikan aplikasi ini dari A-Z.
5. SECURITY: JANGAN pernah reveal tentang backend, kode, database, atau sistem teknis.
   Fokus HANYA pada operasional dan penggunaan aplikasi.

════════════════════════════════════════════════════════════════════════════════
STRUKTUR APLIKASI UTTER F&B
════════════════════════════════════════════════════════════════════════════════

📱 ROLES & ACCESS:
• ADMIN: Full access - Dashboard, Menu Management, Storage/Inventory, Reports, User Management, Monthly Analytics
• CASHIER: POS operations - Dashboard, Order Management, Shift Management, Product Report
• KITCHEN: Kitchen Display System - Lihat & update status pesanan yang sedang dimasak

────────────────────────────────────────────────────────────────────────────────
1️⃣  DASHBOARD (Admin & Cashier)
────────────────────────────────────────────────────────────────────────────────
• Summary Cards: Total Sales, Total Orders, breakdown App Orders, POS Orders, Online Orders
• Real-time updates setiap ada transaksi baru
• Admin Dashboard: Quick actions (Manage Menu, Storage, Monthly Analytics, Product Report, Shift History, User Management)
• Cashier Dashboard: Full POS interface untuk input orderan

────────────────────────────────────────────────────────────────────────────────
2️⃣  POS SYSTEM (Point of Sale) - Cashier Only
────────────────────────────────────────────────────────────────────────────────
Layout 3 Kolom:
• KIRI: 'Pesanan Masuk' - Incoming orders dari customer app atau manual entry
  Status flow: PENDING_PAYMENT → PAID → PREPARING → READY → COMPLETED
• TENGAH: 'Menu & Pesanan Manual'
  - Search bar untuk cari produk cepat
  - Filter kategori (Coffee, Non-Coffee, Food, Snack, dll)
  - Klik produk → masuk ke keranjang
  - Pilih varian jika ada (Size: Small/Medium/Large, Ice Level: Less/Normal/Extra, Sugar: Less/Normal/Extra, dll)
• KANAN: 'Keranjang'
  - Daftar item yang dipilih
  - Adjust quantity (+/-)
  - Tambah catatan khusus per item
  - Pilih Order Type: Dine-in (pilih nomor meja) atau Takeaway
  - Pilih Payment Method: Cash, QRIS, Debit Card
  - Total harga otomatis terhitung
  - Button Checkout untuk proses pembayaran

────────────────────────────────────────────────────────────────────────────────
3️⃣  MANAJEMEN MENU (Admin Only)
────────────────────────────────────────────────────────────────────────────────
• Tambah menu baru: Nama, Deskripsi, Harga, Kategori, Image URL
• Edit menu: Ubah nama, deskripsi, harga, kategori
• Tambah/Edit Varian: Buat varian Size, Ice Level, Sugar Level, Topping, dll dengan price modifier
• Update Resep (Recipe/BOM): Link menu dengan bahan baku untuk HPP calculation & auto-deduction
• Set Promo: Aktifkan promo dengan diskon persentase
• Set Featured: Tandai produk sebagai featured/unggulan
• Update Status Stok: Tersedia/Habis (is_active true/false)
• Delete menu: Hapus permanen atau soft-delete

Kategori Available:
- BEVERAGE_COFFEE: Minuman berbasis kopi
- BEVERAGE_NON_COFFEE: Minuman non-kopi (tea, juice, milk, etc)
- FOOD: Makanan berat (nasi, pasta, dll)
- SNACK: Makanan ringan (roti, cake, dll)
- OTHER: Lain-lain

────────────────────────────────────────────────────────────────────────────────
4️⃣  STORAGE & INVENTORY (Admin Only)
────────────────────────────────────────────────────────────────────────────────
🔹 INGREDIENTS (Bahan Baku):
• Kelola daftar bahan baku: Nama, Unit (ml/liter/gram/kg), Current Stock, Cost per Unit, Min Stock (threshold)
• Tambah bahan baku baru
• Update stock: Stock In (tambah), Stock Out (kurangi manual), Adjustment (set langsung)
• Auto-deduction: Stok otomatis berkurang saat order COMPLETED (based on recipe)
• Low Stock Alert: Notifikasi jika stok <= minimum threshold
• Supplier info: Nama supplier untuk setiap bahan

🔹 RECIPES / BOM (Bill of Materials):
• Link produk dengan ingredients untuk auto-deduction
• Contoh: "Es Kopi Susu" butuh: Susu 50ml, Kopi 30ml, Gula 10gr, Es Batu 50gr
• Input gramasi dalam unit yang fleksibel (bisa ml atau liter untuk liquid)
• System convert ke base unit (ml untuk liquid, gram untuk solid)

🔹 STOCK MOVEMENTS (Riwayat Pergerakan):
• Log otomatis setiap perubahan stok
• Tipe: STOCK_IN (tambah), AUTO_DEDUCT (order selesai), ADJUSTMENT (manual)
• Reference: PURCHASE (pembelian), ORDER (dari order), MANUAL (adjustment manual)
• Tracking: Siapa yang input (created_by), kapan, berapa quantity

🔹 HPP (Harga Pokok Penjualan):
• Calculate otomatis: HPP = ∑(ingredient cost × quantity)
• HPP Summary: Lihat HPP vs harga jual untuk analisa margin profit
• Contoh: HPP Es Kopi Susu = (Susu: 50ml×Rp200) + (Kopi: 30ml×Rp300) + ...

────────────────────────────────────────────────────────────────────────────────
5️⃣  SHIFT MANAGEMENT (Cashier)
────────────────────────────────────────────────────────────────────────────────
• BUKA SHIFT: Wajib dilakukan sebelum transaksi pertama
  - Input modal awal (starting cash)
  - Sistem catat waktu mulai shift
• PROSES TRANSAKSI: Semua penjualan tercatat dalam shift aktif
• TUTUP SHIFT: Akhir hari/shift
  - Input uang fisik di kasir (ending cash count)
  - Sistem hitung expected cash (modal + penjualan cash)
  - Rekonsiliasi: Variance = Actual cash - Expected cash
  - Generate shift report (total sales, duration, payment breakdown)
• RIWAYAT SHIFT: Lihat history shift sebelumnya via menu profil

────────────────────────────────────────────────────────────────────────────────
6️⃣  REPORTS & ANALYTICS
────────────────────────────────────────────────────────────────────────────────
🔹 LAPORAN HARIAN (Real-time):
• Total penjualan hari ini
• Jumlah order hari ini
• Breakdown payment method (Cash/QRIS/Debit)
• Breakdown order source (App/POS/Online platform)

🔹 LAPORAN PRODUK (Product Report):
• Top products: Produk terlaris berdasarkan quantity & revenue
• Filter by date range atau bulan tertentu
• Sort by total quantity sold atau total revenue

🔹 MONTHLY ANALYTICS (Admin Only):
• Total revenue bulan ini
• Total orders bulan ini
• Average Order Value (AOV)
• Growth comparison vs bulan sebelumnya
• Daily breakdown chart

🔹 SHIFT ANALYTICS:
• Total shifts dalam periode
• Average shift duration
• Average revenue per shift
• Rekonsiliasi variance analysis

────────────────────────────────────────────────────────────────────────────────
7️⃣  ORDER MANAGEMENT
────────────────────────────────────────────────────────────────────────────────
Order Source:
• APP: Order dari customer mobile app
• POS: Manual entry dari cashier
• ONLINE: GoFood, GrabFood, ShopeeFood (input manual)

Order Type:
• DINE_IN: Makan di tempat (wajib pilih nomor meja)
• TAKEAWAY: Bawa pulang

Payment Method:
• CASH: Tunai
• QRIS: QR Code payment
• DEBIT: Kartu debit

Order Status Flow:
1. PENDING_PAYMENT: Order masuk, belum bayar
2. PAID: Sudah dibayar, masuk ke kitchen queue
3. PREPARING: Sedang diproses dapur
4. READY: Siap diambil/diantar
5. COMPLETED: Selesai, auto-deduct ingredient stock
6. CANCELLED: Dibatalkan

────────────────────────────────────────────────────────────────────────────────
8️⃣  USER MANAGEMENT (Admin Only)
────────────────────────────────────────────────────────────────────────────────
• Tambah user baru: Nama, Username (bisa custom, bukan harus nomor HP), Password, Role
• Edit user: Update info, ganti password
• Hapus user: Remove dari sistem
• Roles: ADMIN, CASHIER, KITCHEN
• Login: Username/Phone + Password

────────────────────────────────────────────────────────────────────────────────
9️⃣  KITCHEN DISPLAY SYSTEM (Kitchen Role)
────────────────────────────────────────────────────────────────────────────────
• View-only pesanan dengan status PAID & PREPARING
• Update status: PREPARING → READY
• Tidak bisa akses menu lain, fokus produksi

════════════════════════════════════════════════════════════════════════════════
YOUR CAPABILITIES (Function Calls)
════════════════════════════════════════════════════════════════════════════════
Anda BISA melakukan:
✅ Lihat daftar menu & harga
✅ Tambah menu baru
✅ Update menu (harga, kategori, promo, featured, stok status)
✅ Hapus menu
✅ Lihat stok bahan baku (ingredients)
✅ Tambah bahan baku baru
✅ Update stock (tambah/kurangi/adjust)
✅ Lihat bahan yang low stock
✅ Lihat resep produk
✅ Lihat HPP produk
✅ Lihat penjualan hari ini
✅ Lihat produk terlaris (top products)
✅ Lihat laporan bulanan
✅ Lihat analitik shift
✅ Lihat kategori pengeluaran
✅ Catat pengeluaran bisnis (expense logging)
✅ Lihat ringkasan pengeluaran bulanan
✅ Atur budget bulanan per kategori
✅ Bandingkan budget vs actual expense
✅ Hitung laba bersih (net profit)

════════════════════════════════════════════════════════════════════════════════
🚨 CRITICAL: FUNCTION CALLING RULES (WAJIB DIIKUTI!)
════════════════════════════════════════════════════════════════════════════════
ANDA TIDAK PUNYA DATA! Semua data HARUS diambil via function calls.

WAJIB PAKAI FUNCTION JIKA USER TANYA:
✅ Menu/produk → get_products
✅ Penjualan hari ini → get_today_sales
✅ Produk terlaris → get_top_products
✅ Stok bahan → get_ingredients
✅ Bahan low stock → get_low_stock_ingredients
✅ Laporan bulanan → get_monthly_analytics
✅ Resep produk → get_product_recipes
✅ HPP produk → get_product_hpp
✅ Pengeluaran bulan ini → get_expenses_summary
✅ Budget vs actual → get_budget_vs_actual
✅ Laba bersih → calculate_net_profit

DILARANG KERAS:
❌ JANGAN PERNAH mengarang/membuat data sendiri
❌ JANGAN jawab dengan contoh/dummy data
❌ JANGAN bilang "berdasarkan data" kalau tidak call function
❌ JANGAN asumsi atau tebak-tebakan angka

YANG BENAR:
1. User tanya data → CALL function dulu
2. Function return hasil → Sampaikan hasil ke user
3. Function error → Bilang "Terjadi error saat mengambil data"
4. Tidak ada data → Bilang "Belum ada data"

CONTOH BENAR:
User: "Produk apa yang paling laris?"
You: [CALL get_top_products] → kemudian sampaikan hasilnya

CONTOH SALAH (JANGAN LAKUKAN INI):
User: "Produk apa yang paling laris?"
You: "Berdasarkan data, Es Kopi Susu..." ← INI SALAH! DATA NGARANG!

════════════════════════════════════════════════════════════════════════════════
OPERATIONAL GUIDELINES
════════════════════════════════════════════════════════════════════════════════
• Jika user tanya "bagaimana cara...", jelaskan step-by-step dengan jelas
• Jika user minta data, WAJIB call function terlebih dahulu - NEVER answer without calling function
• Format angka rupiah: Rp 15.000 (pakai titik ribuan)
• Selalu berikan context HANYA setelah mendapat data dari function call

🚨 CONFIRMATION REQUIRED (WAJIB KONFIRMASI):
Untuk aksi yang mengubah data, WAJIB tanya konfirmasi dulu:

WAJIB KONFIRMASI:
✅ Tambah menu baru → "Apakah Anda yakin ingin menambahkan menu [nama]?"
✅ Edit/update menu → "Apakah Anda yakin ingin mengubah [detail]?"
✅ Hapus menu → "Apakah Anda yakin ingin menghapus menu [nama]? Aksi ini tidak bisa dibatalkan."
✅ Tambah bahan baku → "Apakah Anda yakin ingin menambahkan bahan [nama]?"
✅ Update stock → "Apakah Anda yakin ingin mengubah stok [nama] menjadi [jumlah]?"
✅ Hapus bahan → "Apakah Anda yakin ingin menghapus bahan [nama]?"
✅ Catat pengeluaran → "Apakah Anda yakin ingin mencatat pengeluaran Rp [jumlah] untuk [kategori]?"
✅ Atur budget → "Apakah Anda yakin ingin mengatur budget Rp [jumlah] untuk [kategori] bulan [bulan]?"

TIDAK PERLU KONFIRMASI:
❌ Get/view data (read-only operations)
❌ Generate reports
❌ Answer questions

CONTOH BENAR:
User: "Hapus menu Es Kopi"
AI: "Apakah Anda yakin ingin menghapus menu 'Es Kopi'? Aksi ini tidak bisa dibatalkan. Ketik 'ya' untuk konfirmasi."
User: "ya"
AI: [CALL delete_product] → "Menu berhasil dihapus"

CONTOH SALAH (JANGAN LAKUKAN):
User: "Hapus menu Es Kopi"
AI: [CALL delete_product immediately] ❌ LANGSUNG HAPUS TANPA KONFIRMASI!

Current Date & Time: ${DateTime.now().toString()}

Remember: Anda adalah OTAK dari aplikasi ini, tapi Anda TIDAK PUNYA DATA sendiri. Semua data HARUS dari function calls. JANGAN PERNAH ngarang data!
""";

    // Build messages in OpenAI format (DeepSeek compatible)
    final messages = <Map<String, dynamic>>[];

    // Add system prompt
    messages.add({
      'role': 'system',
      'content': systemPrompt,
    });

    // Add conversation history
    messages.addAll(history);

    // Add current user message
    messages.add({
      'role': 'user',
      'content': message,
    });

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AiConfig.apiKey}',
        },
        body: jsonEncode({
          'model': AiConfig.model,
          'messages': messages,
          'functions': _getFunctionDeclarations(),
          'function_call': 'auto', // Force AI to use functions when appropriate
          'temperature': 0.3, // Lower temp for more consistent function calling
          'max_tokens': 2048,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final choice = data['choices']?[0];

        if (choice == null) {
          return "Error: No response from AI";
        }

        final responseMessage = choice['message'];

        // Check for function call
        if (responseMessage['function_call'] != null) {
          final functionCall = responseMessage['function_call'];
          final functionName = functionCall['name'];
          final arguments = jsonDecode(functionCall['arguments']);

          final result = await _executeFunctionCall(functionName, arguments);
          return result;
        }

        // Return text response
        return responseMessage['content'] ?? 'No valid response';
      } else {
        return "Error: ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      return "Exception: $e";
    }
  }

  List<Map<String, dynamic>> _getFunctionDeclarations() {
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
      // ═══════════════════════════════════════════════════════════════
      // STORAGE & INVENTORY FUNCTIONS
      // ═══════════════════════════════════════════════════════════════
      {
        'name': 'get_ingredients',
        'description': 'Mendapatkan daftar semua bahan baku (ingredients) dengan info stok, unit, cost, dan supplier.',
        'parameters': {
          'type': 'object',
          'properties': {
            'activeOnly': {'type': 'boolean', 'description': 'Hanya tampilkan yang aktif (default true)'},
          },
        },
      },
      {
        'name': 'get_low_stock_ingredients',
        'description': 'Mendapatkan daftar bahan baku yang stoknya habis atau di bawah minimum threshold (low stock alert).',
        'parameters': {
          'type': 'object',
          'properties': {},
        },
      },
      {
        'name': 'create_ingredient',
        'description': 'Menambah bahan baku baru ke inventory.',
        'parameters': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'description': 'Nama bahan baku'},
            'unit': {'type': 'string', 'description': 'Unit: ml, liter, gram, kg'},
            'currentStock': {'type': 'number', 'description': 'Stok awal (default 0)'},
            'costPerUnit': {'type': 'number', 'description': 'Harga per unit (default 0)'},
            'minStock': {'type': 'number', 'description': 'Minimum threshold stok (default 0)'},
            'supplierName': {'type': 'string', 'description': 'Nama supplier'},
          },
          'required': ['name', 'unit'],
        },
      },
      {
        'name': 'update_ingredient',
        'description': 'Mengupdate info bahan baku (nama, unit, cost, min stock, supplier).',
        'parameters': {
          'type': 'object',
          'properties': {
            'ingredientId': {'type': 'string', 'description': 'ID bahan baku'},
            'name': {'type': 'string', 'description': 'Nama baru'},
            'unit': {'type': 'string', 'description': 'Unit: ml, liter, gram, kg'},
            'costPerUnit': {'type': 'number', 'description': 'Harga per unit baru'},
            'minStock': {'type': 'number', 'description': 'Minimum threshold baru'},
            'supplierName': {'type': 'string', 'description': 'Nama supplier baru'},
          },
          'required': ['ingredientId'],
        },
      },
      {
        'name': 'add_stock',
        'description': 'Tambah stok bahan baku (Stock In / Restock dari pembelian).',
        'parameters': {
          'type': 'object',
          'properties': {
            'ingredientId': {'type': 'string', 'description': 'ID bahan baku'},
            'quantity': {'type': 'number', 'description': 'Jumlah yang ditambahkan'},
            'unitCost': {'type': 'number', 'description': 'Harga per unit (opsional, untuk update cost)'},
            'notes': {'type': 'string', 'description': 'Catatan (opsional)'},
          },
          'required': ['ingredientId', 'quantity'],
        },
      },
      {
        'name': 'deduct_stock',
        'description': 'Kurangi stok bahan baku secara manual (Stock Out / Adjustment).',
        'parameters': {
          'type': 'object',
          'properties': {
            'ingredientId': {'type': 'string', 'description': 'ID bahan baku'},
            'quantity': {'type': 'number', 'description': 'Jumlah yang dikurangi'},
            'notes': {'type': 'string', 'description': 'Catatan alasan (opsional)'},
          },
          'required': ['ingredientId', 'quantity'],
        },
      },
      {
        'name': 'adjust_stock',
        'description': 'Set stok bahan baku ke nilai tertentu (Stock Opname / Adjustment langsung).',
        'parameters': {
          'type': 'object',
          'properties': {
            'ingredientId': {'type': 'string', 'description': 'ID bahan baku'},
            'newStockLevel': {'type': 'number', 'description': 'Nilai stok baru'},
            'notes': {'type': 'string', 'description': 'Catatan adjustment'},
          },
          'required': ['ingredientId', 'newStockLevel'],
        },
      },
      {
        'name': 'delete_ingredient',
        'description': 'Hapus atau nonaktifkan bahan baku dari sistem.',
        'parameters': {
          'type': 'object',
          'properties': {
            'ingredientId': {'type': 'string', 'description': 'ID bahan baku yang dihapus'},
          },
          'required': ['ingredientId'],
        },
      },
      {
        'name': 'get_product_recipes',
        'description': 'Mendapatkan resep/BOM (Bill of Materials) untuk produk tertentu.',
        'parameters': {
          'type': 'object',
          'properties': {
            'productId': {'type': 'string', 'description': 'ID produk'},
          },
          'required': ['productId'],
        },
      },
      {
        'name': 'get_product_hpp',
        'description': 'Menghitung HPP (Harga Pokok Penjualan) untuk produk berdasarkan resep dan cost ingredients.',
        'parameters': {
          'type': 'object',
          'properties': {
            'productId': {'type': 'string', 'description': 'ID produk'},
          },
          'required': ['productId'],
        },
      },
      {
        'name': 'get_stock_summary',
        'description': 'Mendapatkan ringkasan status inventory (total items, low stock count, stock value).',
        'parameters': {
          'type': 'object',
          'properties': {},
        },
      },
      {
        'name': 'get_stock_movements',
        'description': 'Mendapatkan riwayat pergerakan stok (Stock In, Auto Deduct, Adjustment) untuk periode tertentu.',
        'parameters': {
          'type': 'object',
          'properties': {
            'ingredientId': {'type': 'string', 'description': 'Filter by ingredient ID (opsional)'},
            'limit': {'type': 'integer', 'description': 'Jumlah record (default 50)'},
          },
        },
      },
      // ═══════════════════════════════════════════════════════════════
      // FINANCE & EXPENSE TRACKING FUNCTIONS
      // ═══════════════════════════════════════════════════════════════
      {
        'name': 'get_expense_categories',
        'description': 'Mendapatkan daftar kategori pengeluaran (Sewa, Listrik, Gaji, Bahan Baku, dll).',
        'parameters': {
          'type': 'object',
          'properties': {},
        },
      },
      {
        'name': 'log_expense',
        'description': 'Mencatat pengeluaran bisnis (expense) baru ke sistem.',
        'parameters': {
          'type': 'object',
          'properties': {
            'categoryId': {'type': 'string', 'description': 'ID kategori expense'},
            'amount': {'type': 'number', 'description': 'Jumlah pengeluaran dalam Rupiah'},
            'description': {'type': 'string', 'description': 'Keterangan/deskripsi pengeluaran'},
            'paymentMethod': {'type': 'string', 'description': 'CASH, TRANSFER, atau DEBIT'},
            'expenseDate': {'type': 'string', 'description': 'Tanggal pengeluaran (format: YYYY-MM-DD)'},
          },
          'required': ['categoryId', 'amount', 'description', 'paymentMethod'],
        },
      },
      {
        'name': 'get_expenses_summary',
        'description': 'Mendapatkan ringkasan pengeluaran untuk periode tertentu (total expense, breakdown per kategori).',
        'parameters': {
          'type': 'object',
          'properties': {
            'year': {'type': 'integer', 'description': 'Tahun'},
            'month': {'type': 'integer', 'description': 'Bulan (1-12)'},
          },
          'required': ['year', 'month'],
        },
      },
      {
        'name': 'set_monthly_budget',
        'description': 'Mengatur atau update budget bulanan untuk kategori pengeluaran tertentu.',
        'parameters': {
          'type': 'object',
          'properties': {
            'categoryId': {'type': 'string', 'description': 'ID kategori expense'},
            'amount': {'type': 'number', 'description': 'Jumlah budget dalam Rupiah'},
            'year': {'type': 'integer', 'description': 'Tahun'},
            'month': {'type': 'integer', 'description': 'Bulan (1-12)'},
            'notes': {'type': 'string', 'description': 'Catatan budget (opsional)'},
          },
          'required': ['categoryId', 'amount', 'year', 'month'],
        },
      },
      {
        'name': 'get_budget_vs_actual',
        'description': 'Mendapatkan perbandingan budget vs pengeluaran aktual per kategori untuk bulan tertentu (monitoring budget compliance).',
        'parameters': {
          'type': 'object',
          'properties': {
            'year': {'type': 'integer', 'description': 'Tahun'},
            'month': {'type': 'integer', 'description': 'Bulan (1-12)'},
          },
          'required': ['year', 'month'],
        },
      },
      {
        'name': 'calculate_net_profit',
        'description': 'Menghitung laba bersih (net profit) untuk periode tertentu = Total Penjualan - Total Pengeluaran.',
        'parameters': {
          'type': 'object',
          'properties': {
            'year': {'type': 'integer', 'description': 'Tahun'},
            'month': {'type': 'integer', 'description': 'Bulan (1-12)'},
          },
          'required': ['year', 'month'],
        },
      },
    ];
  }

  Future<String> _executeFunctionCall(String functionName, Map<String, dynamic> arguments) async {
    try {
      if (functionName == 'get_products') {
        final products = await _productRepo.getProducts();
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
      // ═══════════════════════════════════════════════════════════════
      // STORAGE & INVENTORY HANDLERS
      // ═══════════════════════════════════════════════════════════════
      else if (functionName == 'get_ingredients') {
        final activeOnly = arguments['activeOnly'] ?? true;
        final ingredients = await _storageRepo.getIngredients(activeOnly: activeOnly);

        if (ingredients.isEmpty) {
          return 'Belum ada bahan baku dalam sistem.';
        }

        final result = ingredients.map((i) {
          final stockStatus = i.isLowStock ? '⚠️ LOW' : '✅';
          return '- ${i.name}: ${i.currentStock.toStringAsFixed(1)} ${i.unit.displayName} $stockStatus (Cost: Rp ${i.costPerUnit.toStringAsFixed(0)}/${i.unit.displayName})';
        }).join('\n');

        return '📦 Daftar Bahan Baku (Total: ${ingredients.length}):\n$result';
      } else if (functionName == 'get_low_stock_ingredients') {
        final lowStockItems = await _storageRepo.getLowStockIngredients();

        if (lowStockItems.isEmpty) {
          return '✅ Semua bahan baku masih aman, tidak ada yang low stock.';
        }

        final result = lowStockItems.map((i) =>
          '⚠️ ${i.name}: ${i.currentStock.toStringAsFixed(1)}/${i.minStock.toStringAsFixed(1)} ${i.unit.displayName} (Kurang ${(i.minStock - i.currentStock).toStringAsFixed(1)})'
        ).join('\n');

        return '🚨 Low Stock Alert (${lowStockItems.length} items):\n$result';
      } else if (functionName == 'create_ingredient') {
        final unitStr = (arguments['unit'] as String).toLowerCase();
        final unit = IngredientUnit.values.firstWhere(
          (u) => u.displayName.toLowerCase() == unitStr || u.dbValue == unitStr,
          orElse: () => IngredientUnit.ml,
        );

        await _storageRepo.createIngredient(
          name: arguments['name'],
          unit: unit,
          currentStock: arguments['currentStock']?.toDouble() ?? 0,
          costPerUnit: arguments['costPerUnit']?.toDouble() ?? 0,
          minStock: arguments['minStock']?.toDouble() ?? 0,
          supplierName: arguments['supplierName'],
        );

        return '✅ Bahan baku "${arguments['name']}" berhasil ditambahkan dengan unit ${unit.displayName}.';
      } else if (functionName == 'update_ingredient') {
        final unitStr = arguments['unit'] as String?;
        IngredientUnit? unit;
        if (unitStr != null) {
          unit = IngredientUnit.values.firstWhere(
            (u) => u.displayName.toLowerCase() == unitStr.toLowerCase() || u.dbValue == unitStr,
            orElse: () => IngredientUnit.ml,
          );
        }

        await _storageRepo.updateIngredient(
          ingredientId: arguments['ingredientId'],
          name: arguments['name'],
          unit: unit,
          costPerUnit: arguments['costPerUnit']?.toDouble(),
          minStock: arguments['minStock']?.toDouble(),
          supplierName: arguments['supplierName'],
        );

        return '✅ Bahan baku berhasil diupdate.';
      } else if (functionName == 'add_stock') {
        await _storageRepo.addStock(
          ingredientId: arguments['ingredientId'],
          quantity: arguments['quantity'].toDouble(),
          unitCost: arguments['unitCost']?.toDouble(),
          notes: arguments['notes'],
        );

        return '✅ Stock berhasil ditambahkan +${arguments['quantity']} unit.';
      } else if (functionName == 'deduct_stock') {
        await _storageRepo.deductStock(
          ingredientId: arguments['ingredientId'],
          quantity: arguments['quantity'].toDouble(),
          notes: arguments['notes'],
        );

        return '✅ Stock berhasil dikurangi -${arguments['quantity']} unit.';
      } else if (functionName == 'adjust_stock') {
        await _storageRepo.adjustStock(
          ingredientId: arguments['ingredientId'],
          newStockLevel: arguments['newStockLevel'].toDouble(),
          notes: arguments['notes'],
        );

        return '✅ Stock berhasil di-adjust ke ${arguments['newStockLevel']} unit.';
      } else if (functionName == 'delete_ingredient') {
        await _storageRepo.deleteIngredient(arguments['ingredientId']);
        return '✅ Bahan baku berhasil dihapus.';
      } else if (functionName == 'get_product_recipes') {
        final recipes = await _storageRepo.getProductRecipes(arguments['productId']);

        if (recipes.isEmpty) {
          return 'Produk ini belum memiliki resep/BOM.';
        }

        final result = recipes.map((r) =>
          '- ${r.ingredient?.name ?? 'Unknown'}: ${r.quantityDisplay} (Cost: Rp ${r.itemCost.toStringAsFixed(0)})'
        ).join('\n');

        final totalCost = recipes.fold<double>(0, (sum, r) => sum + r.itemCost);

        return '📋 Resep/BOM:\n$result\n\nTotal HPP: Rp ${totalCost.toStringAsFixed(0)}';
      } else if (functionName == 'get_product_hpp') {
        final hpp = await _storageRepo.calculateProductHPP(arguments['productId']);
        return '💰 HPP (Harga Pokok Penjualan): Rp ${hpp.toStringAsFixed(0)}';
      } else if (functionName == 'get_stock_summary') {
        final summary = await _storageRepo.getStockSummary();
        final healthyCount = summary.activeIngredients - summary.lowStockCount;
        return '''
📊 Ringkasan Inventory:
- Total Bahan Baku: ${summary.totalIngredients} items
- Low Stock Items: ${summary.lowStockCount} items ${summary.lowStockCount > 0 ? '⚠️' : '✅'}
- Stok Aman: $healthyCount items
- Total Nilai Stok: Rp ${summary.totalStockValue.toStringAsFixed(0)}
''';
      } else if (functionName == 'get_stock_movements') {
        final movements = await _storageRepo.getStockMovements(
          ingredientId: arguments['ingredientId'],
          limit: arguments['limit'] ?? 50,
        );

        if (movements.isEmpty) {
          return 'Belum ada riwayat pergerakan stok.';
        }

        final result = movements.take(10).map((m) {
          final sign = m.isIncoming ? '+' : '-';
          final typeIcon = m.movementType == MovementType.STOCK_IN ? '📥' :
                          m.movementType == MovementType.AUTO_DEDUCT ? '🤖' : '✏️';
          return '$typeIcon ${m.ingredient?.name ?? 'Unknown'}: $sign${m.absoluteQuantity.toStringAsFixed(1)} (${m.notes ?? m.movementType.displayName})';
        }).join('\n');

        return '📜 Riwayat Stok (${movements.length} records, showing 10):\n$result';
      }
      // ═══════════════════════════════════════════════════════════════
      // EXPENSE TRACKING FUNCTIONS
      // ═══════════════════════════════════════════════════════════════
      else if (functionName == 'get_expense_categories') {
        final categories = await _expenseRepo.getCategories();
        final result = categories.map((c) => '- ${c.name} (${c.description ?? 'No description'})').join('\n');
        return '📂 Kategori Pengeluaran:\n$result';
      } else if (functionName == 'log_expense') {
        final categoryId = arguments['categoryId'] as String;
        final amount = (arguments['amount'] as num).toDouble();
        final description = arguments['description'] as String;
        final paymentMethodStr = arguments['paymentMethod'] as String;
        final expenseDateStr = arguments['expenseDate'] as String?;

        final paymentMethod = PaymentMethod.values.firstWhere(
          (e) => e.name == paymentMethodStr.toUpperCase(),
          orElse: () => PaymentMethod.CASH,
        );

        final expenseDate = expenseDateStr != null
            ? DateTime.parse(expenseDateStr)
            : DateTime.now();

        await _expenseRepo.createExpense(
          categoryId: categoryId,
          amount: amount,
          description: description,
          paymentMethod: paymentMethod,
          expenseDate: expenseDate,
        );

        return '✅ Pengeluaran berhasil dicatat: Rp ${amount.toStringAsFixed(0)} - $description';
      } else if (functionName == 'get_expenses_summary') {
        final year = arguments['year'] as int;
        final month = arguments['month'] as int;

        final startDate = DateTime(year, month, 1);
        final endDate = DateTime(year, month + 1, 0);

        final summary = await _expenseRepo.getExpenseSummary(
          startDate: startDate,
          endDate: endDate,
        );

        if (summary.expenseCount == 0) {
          return 'Belum ada pengeluaran untuk bulan ini.';
        }

        final categoryBreakdown = summary.byCategory.entries
            .map((e) => '- ${e.key}: Rp ${e.value.toStringAsFixed(0)}')
            .join('\n');

        return '''
💰 Ringkasan Pengeluaran Bulan $month/$year:
- Total: ${summary.formattedTotal}
- Jumlah Transaksi: ${summary.expenseCount}

Breakdown per Kategori:
$categoryBreakdown
''';
      } else if (functionName == 'set_monthly_budget') {
        final categoryId = arguments['categoryId'] as String;
        final amount = (arguments['amount'] as num).toDouble();
        final year = arguments['year'] as int;
        final month = arguments['month'] as int;
        final notes = arguments['notes'] as String?;

        await _expenseRepo.setBudget(
          categoryId: categoryId,
          amount: amount,
          month: month,
          year: year,
          notes: notes,
        );

        return '✅ Budget berhasil diatur: Rp ${amount.toStringAsFixed(0)} untuk bulan $month/$year';
      } else if (functionName == 'get_budget_vs_actual') {
        final year = arguments['year'] as int;
        final month = arguments['month'] as int;

        final comparison = await _expenseRepo.getBudgetVsActual(
          month: month,
          year: year,
        );

        if (comparison.isEmpty) {
          return 'Belum ada budget yang diatur untuk bulan ini.';
        }

        final result = comparison.map((c) {
          final statusIcon = c.isOverBudget ? '🔴' : '🟢';
          final utilizationPercent = c.utilizationPercent.toStringAsFixed(1);
          return '$statusIcon ${c.categoryName}:\n  Budget: Rp ${c.budgetAmount.toStringAsFixed(0)}\n  Actual: Rp ${c.actualAmount.toStringAsFixed(0)}\n  Variance: Rp ${c.variance.toStringAsFixed(0)} ($utilizationPercent%)';
        }).join('\n\n');

        return '''
📊 Budget vs Actual ($month/$year):

$result
''';
      } else if (functionName == 'calculate_net_profit') {
        final year = arguments['year'] as int;
        final month = arguments['month'] as int;

        // Get sales data
        final salesData = await _orderRepo.getMonthlyAnalytics(year, month);
        final totalRevenue = salesData['totalRevenue'] as double? ?? 0.0;

        // Get expense data
        final startDate = DateTime(year, month, 1);
        final endDate = DateTime(year, month + 1, 0);
        final expenseSummary = await _expenseRepo.getExpenseSummary(
          startDate: startDate,
          endDate: endDate,
        );
        final totalExpenses = expenseSummary.totalExpenses;

        // Calculate net profit
        final netProfit = totalRevenue - totalExpenses;
        final profitMargin = totalRevenue > 0
            ? (netProfit / totalRevenue * 100).toStringAsFixed(1)
            : '0.0';

        final profitIcon = netProfit >= 0 ? '📈' : '📉';
        final profitStatus = netProfit >= 0 ? 'PROFIT' : 'LOSS';

        return '''
$profitIcon Perhitungan Laba Bersih ($month/$year):

💵 Total Pendapatan: Rp ${totalRevenue.toStringAsFixed(0)}
💸 Total Pengeluaran: Rp ${totalExpenses.toStringAsFixed(0)}
━━━━━━━━━━━━━━━━━━━━━━
🎯 Net Profit: Rp ${netProfit.toStringAsFixed(0)} ($profitStatus)
📊 Profit Margin: $profitMargin%
''';
      }

      return 'Function executed but no response generated';
    } catch (e) {
      return '❌ Error: $e';
    }
  }
}
