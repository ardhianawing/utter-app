#!/bin/bash
# ================================================
# JALANKAN DARI ROOT PROJECT utter-app/
# Copy-paste semua command ini ke terminal
# ================================================

# 1. Cek kamu di folder yang benar
echo "📍 Current directory: $(pwd)"
if [ ! -f "lib/main.dart" ]; then
  echo "❌ SALAH FOLDER! cd ke folder utter-app dulu"
  exit 1
fi
echo "✅ Folder benar"

# 2. Update main.dart — ganti import & route
echo ""
echo "🔧 Updating main.dart..."

# Ganti import
sed -i "s|import 'features/storage/presentation/pages/storage_dashboard_page.dart';|import 'features/storage/presentation/pages/storage_main_page.dart';|g" lib/main.dart

# Ganti route
sed -i "s|StorageDashboardPage()|StorageMainPage()|g" lib/main.dart

echo "✅ main.dart updated"

# 3. Verifikasi perubahan
echo ""
echo "📋 Verifikasi main.dart:"
grep -n "StorageMainPage\|storage_main_page" lib/main.dart

# 4. Cek file baru sudah ada
echo ""
echo "📋 Cek file baru:"
for f in \
  "lib/features/storage/presentation/pages/storage_main_page.dart" \
  "lib/features/storage/presentation/pages/storage_dashboard_tab.dart" \
  "lib/features/storage/presentation/widgets/stock_in_sheet.dart" \
  "lib/features/storage/presentation/widgets/recipe_editor_sheet.dart" \
  "lib/features/storage/presentation/widgets/simulation_sheet.dart"; do
  if [ -f "$f" ]; then
    echo "  ✅ $f"
  else
    echo "  ❌ MISSING: $f"
  fi
done

# 5. Cek file yang di-replace
echo ""
echo "📋 Cek file replaced:"
for f in \
  "lib/features/storage/presentation/pages/ingredient_list_page.dart" \
  "lib/features/storage/presentation/pages/recipe_management_page.dart"; do
  if [ -f "$f" ]; then
    # Cek apakah file baru (ada StorageMainPage atau StockInSheet reference)
    if grep -q "StockInSheet\|StorageDashboardTab\|SimulationSheet" "$f" 2>/dev/null; then
      echo "  ✅ $f (UPDATED)"
    else
      echo "  ⚠️  $f (MASIH FILE LAMA!)"
    fi
  else
    echo "  ❌ MISSING: $f"
  fi
done

echo ""
echo "================================================"
echo "🚀 Sekarang restart app (JANGAN hot reload):"
echo "   flutter run --release"
echo "   atau tekan Shift+R di terminal flutter"
echo "================================================"
