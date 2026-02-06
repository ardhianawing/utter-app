import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import 'storage_dashboard_tab.dart';
import 'ingredient_list_page.dart';
import 'recipe_management_page.dart';
import 'stock_movement_page.dart';

/// Main entry point for Storage module with bottom navigation
class StorageMainPage extends ConsumerStatefulWidget {
  const StorageMainPage({super.key});

  @override
  ConsumerState<StorageMainPage> createState() => _StorageMainPageState();
}

class _StorageMainPageState extends ConsumerState<StorageMainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    StorageDashboardTab(),
    IngredientListPage(),
    RecipeManagementPage(),
    StockMovementPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFFF3F4F6), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primaryBlack,
          unselectedItemColor: AppColors.textSecondary.withOpacity(0.4),
          selectedFontSize: 10,
          unselectedFontSize: 10,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_rounded),
              label: 'Bahan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded),
              label: 'Resep',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              label: 'Riwayat',
            ),
          ],
        ),
      ),
    );
  }
}
