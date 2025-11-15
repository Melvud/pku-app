import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Local database service for caching Firebase data
class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  static Database? _database;

  factory LocalDatabaseService() {
    return _instance;
  }

  LocalDatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'pku_tracker.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Articles table
    await db.execute('''
      CREATE TABLE articles (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        pdfUrl TEXT NOT NULL,
        createdBy TEXT,
        createdByName TEXT,
        createdAt INTEGER NOT NULL,
        lastUpdated INTEGER NOT NULL
      )
    ''');

    // Recipes table
    await db.execute('''
      CREATE TABLE recipes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        ingredients TEXT NOT NULL,
        instructions TEXT NOT NULL,
        steps TEXT,
        servings INTEGER,
        status TEXT NOT NULL,
        authorId TEXT NOT NULL,
        authorName TEXT NOT NULL,
        phePer100g REAL NOT NULL,
        proteinPer100g REAL NOT NULL,
        fatPer100g REAL,
        carbsPer100g REAL,
        caloriesPer100g REAL,
        defaultServingSize REAL,
        cookingTime INTEGER,
        difficulty TEXT,
        imageUrl TEXT,
        isOfficial INTEGER DEFAULT 0,
        likesCount INTEGER DEFAULT 0,
        likedBy TEXT,
        createdAt INTEGER NOT NULL,
        approvedAt INTEGER,
        rejectionReason TEXT,
        lastUpdated INTEGER NOT NULL
      )
    ''');

    // Products cache table
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phePer100g REAL NOT NULL,
        proteinPer100g REAL NOT NULL,
        fatPer100g REAL NOT NULL,
        carbsPer100g REAL NOT NULL,
        caloriesPer100g REAL NOT NULL,
        category TEXT,
        lastUpdated INTEGER NOT NULL
      )
    ''');

    // User profile cache
    await db.execute('''
      CREATE TABLE user_profile (
        userId TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        dateOfBirth INTEGER,
        weight REAL NOT NULL,
        dailyTolerancePhe REAL NOT NULL,
        medicalFormula TEXT,
        isAdmin INTEGER NOT NULL DEFAULT 0,
        lastUpdated INTEGER NOT NULL
      )
    ''');

    // Sync metadata table
    await db.execute('''
      CREATE TABLE sync_metadata (
        key TEXT PRIMARY KEY,
        lastSyncTimestamp INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns for version 2
      await db.execute('ALTER TABLE recipes ADD COLUMN steps TEXT');
      await db.execute('ALTER TABLE recipes ADD COLUMN servings INTEGER');
      await db.execute('ALTER TABLE recipes ADD COLUMN isOfficial INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE recipes ADD COLUMN likesCount INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE recipes ADD COLUMN likedBy TEXT');
      await db.execute('ALTER TABLE recipes ADD COLUMN approvedAt INTEGER');
      await db.execute('ALTER TABLE recipes ADD COLUMN rejectionReason TEXT');
    }
  }

  // Helper method to convert Timestamp/DateTime/int to milliseconds
  int _timestampToMillis(dynamic value) {
    if (value == null) return DateTime.now().millisecondsSinceEpoch;
    if (value is int) return value;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    return DateTime.now().millisecondsSinceEpoch;
  }

  // ARTICLES METHODS

  Future<void> cacheArticles(List<Map<String, dynamic>> articles) async {
    final db = await database;
    final batch = db.batch();

    for (var article in articles) {
      batch.insert(
        'articles',
        {
          'id': article['id'],
          'title': article['title'],
          'description': article['description'],
          'pdfUrl': article['pdfUrl'],
          'createdBy': article['createdBy'],
          'createdByName': article['createdByName'],
          'createdAt': _timestampToMillis(article['createdAt']),
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    await _updateSyncTime('articles');
  }

  Future<List<Map<String, dynamic>>> getCachedArticles() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('articles');
    return maps;
  }

  // RECIPES METHODS

  Future<void> cacheRecipes(List<Map<String, dynamic>> recipes) async {
    final db = await database;
    final batch = db.batch();

    for (var recipe in recipes) {
      batch.insert(
        'recipes',
        {
          'id': recipe['id'],
          'name': recipe['name'],
          'description': recipe['description'],
          'category': recipe['category'],
          'ingredients': jsonEncode(recipe['ingredients']),
          'instructions': jsonEncode(recipe['instructions']),
          'steps': recipe['steps'] != null ? jsonEncode(recipe['steps']) : null,
          'servings': recipe['servings'],
          'status': recipe['status'],
          'authorId': recipe['authorId'],
          'authorName': recipe['authorName'],
          'phePer100g': recipe['phePer100g'],
          'proteinPer100g': recipe['proteinPer100g'],
          'fatPer100g': recipe['fatPer100g'],
          'carbsPer100g': recipe['carbsPer100g'],
          'caloriesPer100g': recipe['caloriesPer100g'],
          'defaultServingSize': recipe['defaultServingSize'],
          'cookingTime': recipe['cookingTime'] ?? recipe['cookingTimeMinutes'],
          'difficulty': recipe['difficulty'],
          'imageUrl': recipe['imageUrl'],
          'isOfficial': (recipe['isOfficial'] ?? false) ? 1 : 0,
          'likesCount': recipe['likesCount'] ?? 0,
          'likedBy': recipe['likedBy'] != null ? jsonEncode(recipe['likedBy']) : null,
          'createdAt': _timestampToMillis(recipe['createdAt']),
          'approvedAt': recipe['approvedAt'] != null ? _timestampToMillis(recipe['approvedAt']) : null,
          'rejectionReason': recipe['rejectionReason'],
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    await _updateSyncTime('recipes');
  }

  Future<List<Map<String, dynamic>>> getCachedRecipes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('recipes');
    
    // Decode JSON fields
    return maps.map((map) {
      final decoded = Map<String, dynamic>.from(map);
      decoded['ingredients'] = jsonDecode(map['ingredients'] as String);
      decoded['instructions'] = jsonDecode(map['instructions'] as String);
      if (map['steps'] != null) {
        decoded['steps'] = jsonDecode(map['steps'] as String);
      }
      decoded['isOfficial'] = map['isOfficial'] == 1;
      if (map['likedBy'] != null) {
        decoded['likedBy'] = jsonDecode(map['likedBy'] as String);
      } else {
        decoded['likedBy'] = <String>[];
      }
      return decoded;
    }).toList();
  }

  // PRODUCTS METHODS

  Future<void> cacheProducts(List<Map<String, dynamic>> products) async {
    final db = await database;
    final batch = db.batch();

    for (var product in products) {
      batch.insert(
        'products',
        {
          'id': product['id'],
          'name': product['name'],
          'phePer100g': product['phePer100g'],
          'proteinPer100g': product['proteinPer100g'],
          'fatPer100g': product['fatPer100g'],
          'carbsPer100g': product['carbsPer100g'],
          'caloriesPer100g': product['caloriesPer100g'],
          'category': product['category'],
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    await _updateSyncTime('products');
  }

  Future<List<Map<String, dynamic>>> getCachedProducts() async {
    final db = await database;
    return await db.query('products');
  }

  // USER PROFILE METHODS

  Future<void> cacheUserProfile(Map<String, dynamic> profile) async {
    final db = await database;
    await db.insert(
      'user_profile',
      {
        'userId': profile['userId'],
        'name': profile['name'],
        'email': profile['email'],
        'dateOfBirth': profile['dateOfBirth'] != null
            ? _timestampToMillis(profile['dateOfBirth'])
            : null,
        'weight': profile['weight'],
        'dailyTolerancePhe': profile['dailyTolerancePhe'],
        'medicalFormula': profile['medicalFormula'],
        'isAdmin': (profile['isAdmin'] ?? false) ? 1 : 0,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _updateSyncTime('user_profile');
  }

  Future<Map<String, dynamic>?> getCachedUserProfile(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_profile',
      where: 'userId = ?',
      whereArgs: [userId],
    );

    if (maps.isEmpty) return null;
    
    final profile = Map<String, dynamic>.from(maps.first);
    profile['isAdmin'] = profile['isAdmin'] == 1;
    return profile;
  }

  // SYNC METADATA METHODS

  Future<void> _updateSyncTime(String key) async {
    final db = await database;
    await db.insert(
      'sync_metadata',
      {
        'key': key,
        'lastSyncTimestamp': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DateTime?> getLastSyncTime(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sync_metadata',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (maps.isEmpty) return null;
    
    return DateTime.fromMillisecondsSinceEpoch(
      maps.first['lastSyncTimestamp'] as int,
    );
  }

  Future<bool> shouldSyncWithFirebase(String key, {Duration maxAge = const Duration(hours: 1)}) async {
    final lastSync = await getLastSyncTime(key);
    if (lastSync == null) return true;
    
    final age = DateTime.now().difference(lastSync);
    return age > maxAge;
  }

  Future<bool> hasCache(String tableName) async {
    final db = await database;
    final result = await db.query(tableName, limit: 1);
    return result.isNotEmpty;
  }

  // CLEANUP METHODS

  Future<void> clearCache() async {
    final db = await database;
    await db.delete('articles');
    await db.delete('recipes');
    await db.delete('products');
    await db.delete('user_profile');
    await db.delete('sync_metadata');
  }

  Future<void> clearTable(String tableName) async {
    final db = await database;
    await db.delete(tableName);
    await db.delete('sync_metadata', where: 'key = ?', whereArgs: [tableName]);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
