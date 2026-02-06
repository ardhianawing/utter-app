# Fitur Tracking Produk untuk Online Order

## 📋 Deskripsi
Fitur ini memungkinkan Anda untuk melacak produk mana yang laku terjual, termasuk dari pesanan online (GoFood, GrabFood, ShopeeFood). Sekarang ketika Anda input pemasukan manual dari aplikasi ojek online, produk yang ada di cart akan tetap tersimpan untuk keperluan tracking dan analisis penjualan.

## ✨ Fitur yang Ditambahkan

### 1. **Indikator Visual di Cart (Online Order Mode)**
- Ketika menggunakan mode GoFood/GrabFood/ShopeeFood, sekarang ada notifikasi hijau yang menjelaskan bahwa produk di cart akan tersimpan untuk tracking
- Lokasi: Dashboard Cashier → Cart Section (saat mode online order aktif)

### 2. **Halaman Laporan Penjualan Produk**
- Halaman baru untuk melihat statistik penjualan produk
- Fitur:
  - Filter periode: Hari Ini, Kemarin, Minggu Ini, Bulan Ini, atau Custom Date Range
  - Ringkasan total: Total Terjual, POS, Online
  - Daftar produk dengan ranking (berdasarkan jumlah terjual)
  - Breakdown per produk: Jumlah POS vs Online, Revenue, Harga
  - Produk diurutkan dari yang paling laku

### 3. **Menu Akses Laporan**
- Menu baru "Laporan Produk" di Dashboard
- Lokasi: Dashboard → Menu (icon profil di kanan atas) → Laporan Produk
- Tersedia untuk semua role (Admin dan Cashier)

## 🔧 Perubahan Teknis

### File yang Dimodifikasi:
1. **dashboard_page.dart**
   - Tambah import `product_sales_report_page.dart`
   - Tambah menu item "Laporan Produk"
   - Tambah handler navigasi ke halaman laporan
   - Tambah indikator visual di online order mode

2. **order_repository.dart**
   - Tambah method `getProductSalesReport()` untuk mengambil data penjualan produk
   - Method ini mengambil data dari `order_items` dengan join ke `orders` dan `products`
   - Mengelompokkan data per produk dan menghitung total quantity, revenue, dan breakdown POS vs Online

### File Baru:
1. **product_sales_report_page.dart**
   - Halaman laporan penjualan produk lengkap dengan UI yang informatif
   - Menggunakan `OrderRepository.getProductSalesReport()` untuk mengambil data

## 📊 Cara Menggunakan

### Input Order Online dengan Tracking Produk:
1. Buka Dashboard Cashier
2. Pilih mode order: GoFood / GrabFood / ShopeeFood
3. **UI akan otomatis disederhanakan:**
   - ✅ Hanya tampil: Input Produk + Input Total Revenue
   - ❌ Tidak tampil: Customer Name, Table, Order Type, Payment Method
   - 🔄 Otomatis: Payment = QRIS, Order Type = TAKEAWAY
4. Tambahkan produk ke cart seperti biasa
5. Perhatikan notifikasi hijau: "Produk di cart akan tersimpan untuk tracking penjualan"
6. Input total revenue dari aplikasi ojek online
7. Checkout → Produk akan tersimpan dengan harga 0 (untuk tracking saja)

### Melihat Laporan Produk:
1. Buka Dashboard Cashier
2. Klik icon profil di kanan atas
3. Pilih "Laporan Produk"
4. Pilih periode yang diinginkan (Hari Ini, Minggu Ini, dll)
5. Lihat produk mana yang paling laku!

## 💡 Catatan Penting

### Mengapa Harga 0 untuk Online Order?
- Untuk online order, harga produk disimpan sebagai 0 di `order_items`
- Total revenue disimpan di level `order` (dari input manual)
- Ini mencegah double counting revenue (karena revenue sudah dicatat di order level)
- Produk tetap tercatat untuk tracking quantity yang terjual

### Data yang Dilacak:
- ✅ Jumlah produk terjual (total, POS, online)
- ✅ Revenue dari POS (harga × quantity)
- ✅ Ranking produk berdasarkan popularitas
- ✅ Kategori produk
- ✅ Harga dasar produk

## 🎯 Manfaat

1. **Analisis Penjualan**: Tahu produk mana yang paling laku
2. **Inventory Planning**: Bisa stok produk yang laku lebih banyak
3. **Strategi Marketing**: Fokus promosi pada produk yang kurang laku
4. **Laporan Lengkap**: Data POS dan Online dalam satu tempat
5. **Fleksibel**: Filter berdasarkan periode yang diinginkan

## 🔍 Contoh Use Case

**Skenario**: Anda menerima order GoFood dengan 2 Katsu Ramen dan 1 Milko Creamy

**Proses**:
1. Pilih mode "GoFood"
2. Tambah 2x Katsu Ramen ke cart
3. Tambah 1x Milko Creamy ke cart
4. Input total revenue: Rp 150.000 (dari aplikasi GoFood)
5. Checkout

**Hasil di Database**:
- Order: Total Rp 150.000, Source: GOFOOD
- Order Items:
  - Katsu Ramen: qty 2, unit_price 0, subtotal 0
  - Milko Creamy: qty 1, unit_price 0, subtotal 0

**Hasil di Laporan Produk**:
- Katsu Ramen: +2 pcs (online)
- Milko Creamy: +1 pcs (online)

Sekarang Anda bisa lihat bahwa Katsu Ramen laku 2 pcs hari ini dari GoFood! 🎉
