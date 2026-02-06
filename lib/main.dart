import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/date_symbol_data_local.dart';
import 'core/constants/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'features/cashier/presentation/pages/staff_login_page.dart';
import 'features/cashier/presentation/pages/dashboard_page.dart';
import 'features/cashier/data/providers/auth_provider.dart';
import 'features/customer/presentation/pages/menu_page.dart';
import 'features/customer/presentation/pages/qr_scanner_page.dart';
import 'features/cashier/presentation/pages/kitchen_display_page.dart';
import 'features/storage/presentation/pages/storage_main_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to landscape orientation for POS (cashier) app
  // But for web (customer), allow portrait mode
  // We'll detect platform and set orientation accordingly
  // For now, allow all orientations to support customer web app
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Initialize locale data for Indonesian
  await initializeDateFormatting('id_ID', null);

  runApp(
    const ProviderScope(
      child: UtterApp(),
    ),
  );
}

class UtterApp extends ConsumerWidget {
  const UtterApp({super.key});

  Widget _getInitialPage(WidgetRef ref) {
    // Check if running on web and has URL parameters
    if (kIsWeb) {
      try {
        final uri = Uri.base;

        // Check for customer order URL: /order?table_id=xxx&table_number=x
        if (uri.path.contains('/order') || uri.queryParameters.containsKey('table_id')) {
          final tableId = uri.queryParameters['table_id'];
          final tableNumberStr = uri.queryParameters['table_number'];

          if (tableId != null && tableNumberStr != null) {
            final tableNumber = int.tryParse(tableNumberStr);
            if (tableNumber != null) {
              // Direct to menu page with table context
              return MenuPage(
                tableId: tableId,
                tableNumber: tableNumber,
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Error parsing URL: $e');
      }
    }

    // Check Auth State for Staff/Admin
    final authState = ref.watch(authProvider);

    // Show loading while checking initial session
    if (authState.isInitialCheck) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.green),
        ),
      );
    }

    if (authState.isAuthenticated) {
      if (authState.isKitchen) {
        return const KitchenDisplayPage();
      }
      return const DashboardPage();
    }

    // Default: Staff Login (for cashier/POS)
    return const StaffLoginPage();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Utter F&B',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      home: _getInitialPage(ref),
      // Add routes for navigation
      routes: {
        '/order': (context) => const QRScannerPage(),
        '/menu': (context) => const MenuPage(),
        '/login': (context) => const StaffLoginPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/storage': (context) => const StorageMainPage(),
      },
    );
  }
}
