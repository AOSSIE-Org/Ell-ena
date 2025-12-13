import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'vector_database_interface.dart';
import 'pgvector_database.dart';
import 'couchbase_vector_database.dart';

/// Enum for available vector database providers
enum VectorDbProvider {
  pgvector('PostgreSQL (pgvector)'),
  couchbase('Couchbase Server');

  final String displayName;
  const VectorDbProvider(this.displayName);
}

/// Factory and configuration service for vector databases
/// 
/// Manages:
/// - Provider selection (pgvector or Couchbase)
/// - Connection configuration
/// - Provider switching
/// - Persistent settings
class VectorDatabaseFactory extends ChangeNotifier {
  static const String _prefKey = 'vector_db_provider';
  static const String _couchbaseUrlKey = 'couchbase_url';
  static const String _couchbaseUsernameKey = 'couchbase_username';
  static const String _couchbasePasswordKey = 'couchbase_password';
  static const String _couchbaseBucketKey = 'couchbase_bucket';

  VectorDbProvider _currentProvider = VectorDbProvider.pgvector;
  VectorDatabase? _currentDatabase;

  // Couchbase configuration
  String _couchbaseUrl = '';
  String _couchbaseUsername = '';
  String _couchbasePassword = '';
  String _couchbaseBucket = 'ell-ena';

  VectorDbProvider get currentProvider => _currentProvider;
  VectorDatabase? get database => _currentDatabase;

  // Couchbase config getters
  String get couchbaseUrl => _couchbaseUrl;
  String get couchbaseUsername => _couchbaseUsername;
  String get couchbaseBucket => _couchbaseBucket;

  /// Initialize the factory and load saved preferences
  Future<void> initialize() async {
    await _loadPreferences();
    debugPrint('✅ VectorDatabaseFactory initialized with provider: ${_currentProvider.displayName}');
  }

  /// Create a vector database instance based on the current provider
  Future<VectorDatabase> createDatabase(SupabaseClient supabaseClient) async {
    switch (_currentProvider) {
      case VectorDbProvider.pgvector:
        final db = PgVectorDatabase(supabaseClient);
        await db.initialize();
        _currentDatabase = db;
        return db;

      case VectorDbProvider.couchbase:
        if (_couchbaseUrl.isEmpty || _couchbaseUsername.isEmpty) {
          throw Exception('Couchbase configuration incomplete. Please configure in settings.');
        }

        final db = CouchbaseVectorDatabase(
          clusterUrl: _couchbaseUrl,
          username: _couchbaseUsername,
          password: _couchbasePassword,
          bucketName: _couchbaseBucket,
        );
        await db.initialize();
        _currentDatabase = db;
        return db;
    }
  }

  /// Switch to a different vector database provider
  Future<void> switchProvider(VectorDbProvider provider, SupabaseClient supabaseClient) async {
    if (provider == _currentProvider) {
      debugPrint('⚠️  Already using ${provider.displayName}');
      return;
    }

    // Save original state for rollback
    final originalProvider = _currentProvider;
    final originalDatabase = _currentDatabase;

    // Close current connection
    await _currentDatabase?.close();
    _currentDatabase = null;

    // Switch provider
    _currentProvider = provider;
    await _savePreferences();

    // Initialize new provider
    try {
      await createDatabase(supabaseClient);
      debugPrint('✅ Switched to ${provider.displayName}');
      notifyListeners();
    } catch (originalError) {
      debugPrint('❌ Failed to switch to ${provider.displayName}: $originalError');
      
      // Rollback to original provider on failure
      try {
        debugPrint('🔄 Attempting rollback to ${originalProvider.displayName}...');
        _currentProvider = originalProvider;
        _currentDatabase = null;
        await _savePreferences();
        
        await createDatabase(supabaseClient);
        debugPrint('✅ Rollback to ${originalProvider.displayName} successful');
        notifyListeners();
      } catch (rollbackError) {
        debugPrint('❌ Rollback failed: $rollbackError');
        // Restore previous database instance if rollback failed completely
        _currentDatabase = originalDatabase;
        debugPrint('⚠️  Restored previous database connection');
        notifyListeners();
      }
      
      // Always rethrow the original error
      rethrow;
    }
  }

  /// Update Couchbase configuration
  Future<void> updateCouchbaseConfig({
    required String url,
    required String username,
    required String password,
    required String bucket,
  }) async {
    _couchbaseUrl = url;
    _couchbaseUsername = username;
    _couchbasePassword = password;
    _couchbaseBucket = bucket;

    await _savePreferences();
    debugPrint('✅ Couchbase configuration updated');
    notifyListeners();
  }

  /// Test Couchbase connection with provided credentials
  Future<bool> testCouchbaseConnection({
    required String url,
    required String username,
    required String password,
    required String bucket,
  }) async {
    try {
      final testDb = CouchbaseVectorDatabase(
        clusterUrl: url,
        username: username,
        password: password,
        bucketName: bucket,
      );

      await testDb.initialize();
      final isHealthy = await testDb.isHealthy();
      await testDb.close();

      return isHealthy;
    } catch (e) {
      debugPrint('❌ Couchbase connection test failed: $e');
      return false;
    }
  }

  /// Load preferences from SharedPreferences
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Load provider
    final providerIndex = prefs.getInt(_prefKey);
    if (providerIndex != null && providerIndex < VectorDbProvider.values.length) {
      _currentProvider = VectorDbProvider.values[providerIndex];
    }

    // Load Couchbase config
    _couchbaseUrl = prefs.getString(_couchbaseUrlKey) ?? '';
    _couchbaseUsername = prefs.getString(_couchbaseUsernameKey) ?? '';
    _couchbasePassword = prefs.getString(_couchbasePasswordKey) ?? '';
    _couchbaseBucket = prefs.getString(_couchbaseBucketKey) ?? 'ell-ena';

    debugPrint('📱 Loaded vector DB provider: ${_currentProvider.displayName}');
  }

  /// Save preferences to SharedPreferences
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(_prefKey, _currentProvider.index);
    await prefs.setString(_couchbaseUrlKey, _couchbaseUrl);
    await prefs.setString(_couchbaseUsernameKey, _couchbaseUsername);
    await prefs.setString(_couchbasePasswordKey, _couchbasePassword);
    await prefs.setString(_couchbaseBucketKey, _couchbaseBucket);

    debugPrint('💾 Saved vector DB preferences');
  }

  /// Check if current provider is healthy
  Future<bool> checkHealth() async {
    if (_currentDatabase == null) return false;
    return await _currentDatabase!.isHealthy();
  }

  /// Close current database connection
  Future<void> close() async {
    await _currentDatabase?.close();
    _currentDatabase = null;
  }
}
