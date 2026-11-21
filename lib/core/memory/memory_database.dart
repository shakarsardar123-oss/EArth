import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Database name and version.
const _dbName = 'aura_memory.db';
const _dbVersion = 1;

/// Provides the sqflite [Database] for conversation persistence.
class MemoryDatabase {
  MemoryDatabase();

  Database? _db;

  /// Opens or creates the database.
  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    final db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await _ensureSummaryTable(db);
    return db;
  }

  /// Creates tables for first-time initialization.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        agent_id TEXT NOT NULL,
        title TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        parent_message_id TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
      )
    ''');

    // Index for faster message queries by conversation.
    await db.execute('''
      CREATE INDEX idx_messages_conversation ON messages(conversation_id)
    ''');

    // Index for faster conversation listing by updated_at.
    await db.execute('''
      CREATE INDEX idx_conversations_updated ON conversations(updated_at)
    ''');
  }

  /// Handles database upgrades.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future schema migrations go here.
  }

  /// Creates the daily-summary table if missing (runs on every start, safe).
  Future<void> _ensureSummaryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_summaries (
        day TEXT PRIMARY KEY,
        summary TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  /// Saves or replaces the summary for [day] (format yyyy-MM-dd).
  Future<void> saveDailySummary(String day, String summary) async {
    final db = await database;
    await db.insert(
      'daily_summaries',
      {
        'day': day,
        'summary': summary,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Latest stored summary, or null when none exists.
  Future<String?> getLastSummary() async {
    final db = await database;
    final rows = await db.query('daily_summaries', orderBy: 'day DESC', limit: 1);
    return rows.isEmpty ? null : rows.first['summary'] as String;
  }

  /// Closes the database.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
