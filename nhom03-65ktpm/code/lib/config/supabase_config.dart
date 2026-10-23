// Supabase Configuration
// Project ID: lwebnjcszbldlqwjrcan
class SupabaseConfig {
  static const String supabaseUrl = 'https://lwebnjcszbldlqwjrcan.supabase.co';
  // Anon/public key from Supabase Dashboard → Settings → API
  static const String supabaseAnonKey =
      'sb_publishable_2tJzWH1c8Z1Lm9Vud2hJyw_9f99nrwM';

  // Table names
  static const String documentsTable = 'documents';
  static const String categoriesTable = 'categories';
  static const String usersTable = 'users';
  static const String permissionsTable = 'permissions';
  static const String notificationsTable = 'notifications';
  static const String borrowRequestsTable = 'borrow_requests';
}
