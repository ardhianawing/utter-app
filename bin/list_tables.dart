import 'package:supabase_flutter/supabase_flutter.dart';
import '../lib/core/constants/supabase_config.dart';

Future<void> main() async {
  // Initialize Supabase
  final supabase = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);

  // Fetch tables
  final response = await supabase
      .from('tables')
      .select('id, table_number')
      .order('table_number', ascending: true);

  print('JSON_DATA_START');
  print(response);
  print('JSON_DATA_END');
}
