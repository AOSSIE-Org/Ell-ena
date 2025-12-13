import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  // SharedPreferences keys (non-sensitive)
  static const String _prefKey = 'vector_db_provider';
  static const String _couchbaseUrlKey = 'couchbase_url';
  static const String _couchbaseBucketKey = 'couchbase_bucket';
  
  // FlutterSecureStorage keys (sensitive)
  static const String _secureUsernameKey = 'secure_couchbase_username';
  static const String _securePasswordKey = 'secure_couchbase_password';
  
  // Legacy keys for migration
  static const String _legacyUsernameKey = 'couchbase_username';
  static const String _legacyPasswordKey = 'couchbase_password';

  // Secure storage with platform-specific options
  late final FlutterSecureStorage _secureStorage;

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
    // Initialize secure storage with platform-specific options
    _secureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      ),
    );
    
    await _loadPreferences();
    await _migrateCredentials();
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

  /// Load preferences from SharedPreferences and secure storage
  Future<void> _loadPreferences() async {
    // Load non-sensitive config from SharedPreferences with granular error handling
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load provider (non-sensitive)
      final providerIndex = prefs.getInt(_prefKey);
      if (providerIndex != null && providerIndex < VectorDbProvider.values.length) {
        _currentProvider = VectorDbProvider.values[providerIndex];
      }

      // Load non-sensitive Couchbase config
      _couchbaseUrl = prefs.getString(_couchbaseUrlKey) ?? '';
      _couchbaseBucket = prefs.getString(_couchbaseBucketKey) ?? 'ell-ena';

      debugPrint('📱 Loaded non-sensitive config - Provider: ${_currentProvider.displayName}');
    } catch (e) {
      debugPrint('⚠️  Error loading SharedPreferences: $e');
      // Only reset non-sensitive config on SharedPreferences error
      _couchbaseUrl = '';
      _couchbaseBucket = 'ell-ena';
      // Keep current provider as-is (don't reset to default)
    }

    // Load sensitive credentials from secure storage with separate error handling
    try {
      _couchbaseUsername = await _secureStorage.read(key: _secureUsernameKey) ?? '';
      _couchbasePassword = await _secureStorage.read(key: _securePasswordKey) ?? '';

      debugPrint('🔐 Loaded secure credentials from encrypted storage');
    } catch (e) {
      debugPrint('⚠️  Error loading secure storage credentials: $e');
      // Only reset credentials on secure storage error
      _couchbaseUsername = '';
      _couchbasePassword = '';
      // Non-sensitive config remains intact
    }
  }

  /// Migrate credentials from plain SharedPreferences to secure storage
  Future<void> _migrateCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if legacy credentials exist in SharedPreferences
      final legacyUsername = prefs.getString(_legacyUsernameKey);
      final legacyPassword = prefs.getString(_legacyPasswordKey);

      if (legacyUsername != null || legacyPassword != null) {
        debugPrint('🔄 Migrating credentials to secure storage...');

        // Migrate username
        if (legacyUsername != null && legacyUsername.isNotEmpty) {
          await _secureStorage.write(
            key: _secureUsernameKey,
            value: legacyUsername,
          );
          _couchbaseUsername = legacyUsername;
          await prefs.remove(_legacyUsernameKey);
          debugPrint('✅ Migrated username to secure storage');
        }

        // Migrate password
        if (legacyPassword != null && legacyPassword.isNotEmpty) {
          await _secureStorage.write(
            key: _securePasswordKey,
            value: legacyPassword,
          );
          _couchbasePassword = legacyPassword;
          await prefs.remove(_legacyPasswordKey);
          debugPrint('✅ Migrated password to secure storage');
        }

        debugPrint('✅ Credential migration completed');
      }
    } catch (e) {
      debugPrint('⚠️  Error during credential migration: $e');
      // Non-fatal error, continue with existing credentials
    }
  }

  /// Save preferences to SharedPreferences and secure storage
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save non-sensitive config to SharedPreferences
      await prefs.setInt(_prefKey, _currentProvider.index);
      await prefs.setString(_couchbaseUrlKey, _couchbaseUrl);
      await prefs.setString(_couchbaseBucketKey, _couchbaseBucket);

      // Save or delete sensitive credentials in secure storage
      // Use explicit deletion when empty to properly clear credentials
      if (_couchbaseUsername.isNotEmpty) {
        await _secureStorage.write(
          key: _secureUsernameKey,
          value: _couchbaseUsername,
        );
      } else {
        await _secureStorage.delete(key: _secureUsernameKey);
      }

      if (_couchbasePassword.isNotEmpty) {
        await _secureStorage.write(
          key: _securePasswordKey,
          value: _couchbasePassword,
        );
      } else {
        await _secureStorage.delete(key: _securePasswordKey);
      }

      debugPrint('💾 Saved vector DB preferences securely');
    } catch (e) {
      debugPrint('❌ Error saving preferences: $e');
      rethrow;
    }
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

  /// Clear stored Couchbase credentials securely
  Future<void> clearCouchbaseCredentials() async {
    try {
      await _secureStorage.delete(key: _secureUsernameKey);
      await _secureStorage.delete(key: _securePasswordKey);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_couchbaseUrlKey);
      await prefs.remove(_couchbaseBucketKey);
      
      // Also remove any legacy keys if they exist
      await prefs.remove(_legacyUsernameKey);
      await prefs.remove(_legacyPasswordKey);
      
      _couchbaseUrl = '';
      _couchbaseUsername = '';
      _couchbasePassword = '';
      _couchbaseBucket = 'ell-ena';
      
      debugPrint('✅ Cleared Couchbase credentials securely');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error clearing credentials: $e');
      rethrow;
    }
  }
}
