import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import 'storage_dashboard_tab.dart';
import 'storage_other_tab.dart';

/// Main entry point for Storage module with bottom navigation (2 tabs)
class StorageMainPage extends ConsumerStatefulWidget {
  const StorageMainPage({super.key});

  @override
  ConsumerState<StorageMainPage> createState() => _StorageMainPageState();
}

class _StorageMainPageState extends ConsumerState<StorageMainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    StorageDashboardTab(),
    StorageOtherTab(),
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
              icon: Icon(Icons.inventory_2_rounded),
              label: 'Stok',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz_rounded),
              label: 'Lainnya',
            ),
          ],
        ),
      ),
    );
  }
}
