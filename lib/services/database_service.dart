import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/visitor.dart';
import '../models/host.dart';
import '../models/visit_record.dart';
import '../models/queued_action.dart';
import 'dart:convert';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'visitors.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await _executeSchema(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      await db.execute('DROP TABLE IF EXISTS visitors');
      await db.execute('DROP TABLE IF EXISTS visit_records');
      await db.execute('DROP TABLE IF EXISTS queued_actions');
      await db.execute('DROP TABLE IF EXISTS cached_verifications');
      await db.execute('DROP TABLE IF EXISTS hosts');
      await db.execute('DROP TABLE IF EXISTS destinations');
      await db.execute('DROP TABLE IF EXISTS visitor_tags');
      await _executeSchema(db);
    }
  }

  Future<void> _executeSchema(Database db) async {
    await db.execute('''
    CREATE TABLE visitors (
      id TEXT PRIMARY KEY,
      name TEXT,
      email TEXT,
      phone_number TEXT,
      id_number TEXT,
      identification_type TEXT,
      host TEXT,
      office TEXT,
      vehicle_registration TEXT,
      vehicle_type TEXT,
      country TEXT,
      is_minor INTEGER,
      guardian_phone TEXT,
      destination_id TEXT,
      visitor_tag_id TEXT,
      gate_id TEXT,
      visit_type TEXT,
      appointment_details TEXT,
      photo_path TEXT,
      action TEXT,
      gate TEXT,
      time TEXT,
      created_at TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE hosts (
      id TEXT PRIMARY KEY,
      name TEXT,
      phone TEXT,
      email TEXT,
      department TEXT,
      position TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE destinations (
      id TEXT PRIMARY KEY,
      name TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE visitor_tags (
      id TEXT PRIMARY KEY,
      name TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE visit_records (
      id TEXT PRIMARY KEY,
      visitor_id TEXT,
      visitor_tag_id TEXT,
      gate_id TEXT,
      check_in_time TEXT,
      check_out_time TEXT,
      status TEXT,
      created_at TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE queued_actions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      visitor_id TEXT,
      type TEXT,
      data TEXT,
      created_at TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE cached_verifications (
      identifier TEXT PRIMARY KEY,
      data TEXT,
      created_at TEXT
    )
    ''');
  }

  // VISITOR METHODS
  Future<void> insertVisitor(Visitor visitor) async {
    final db = await database;
    try {
      final map = visitor.toMap();
      map['name'] ??= 'Unknown';
      map['phone_number'] ??= 'N/A';
      map['id_number'] ??= 'N/A';
      map['created_at'] ??= DateTime.now().toIso8601String();

      if (map['host'] is Map) map['host'] = jsonEncode(map['host']);
      if (map['office'] is Map) map['office'] = jsonEncode(map['office']);

      await db.insert('visitors', map, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      print('❌ Error inserting visitor: $e');
      rethrow;
    }
  }

  Future<void> updateVisitor(Visitor visitor) async {
    final db = await database;
    try {
      final map = visitor.toMap();
      map['created_at'] ??= DateTime.now().toIso8601String();

      if (map['host'] is Map) map['host'] = jsonEncode(map['host']);
      if (map['office'] is Map) map['office'] = jsonEncode(map['office']);

      await db.update(
        'visitors',
        map,
        where: 'id = ?',
        whereArgs: [visitor.id],
      );
    } catch (e) {
      print('❌ Error updating visitor: $e');
      rethrow;
    }
  }

  Future<List<Visitor>> getVisitors({required int page, required int limit}) async {
    final db = await database;
    final offset = (page - 1) * limit;
    final maps = await db.query('visitors', limit: limit, offset: offset);
    return maps.map((e) => Visitor.fromMap(e)).toList();
  }

  Future<Visitor?> getVisitorById(String idType, String idNumber) async {
    final db = await database;
    final maps = await db.query(
      'visitors',
      where: 'identification_type = ? AND id_number = ?',
      whereArgs: [idType, idNumber],
    );
    if (maps.isEmpty) return null;
    return Visitor.fromMap(maps.first);
  }

  Future<Visitor?> getVisitorByQR(String qrCode) async {
    final db = await database;
    final maps = await db.query(
      'visitors',
      where: 'id = ? OR id_number = ?',
      whereArgs: [qrCode, qrCode],
    );
    if (maps.isEmpty) return null;
    return Visitor.fromMap(maps.first);
  }

  Future<List<Visitor>> searchVisitors(String query) async {
    final db = await database;
    final maps = await db.query(
      'visitors',
      where: 'name LIKE ? OR id_number LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );
    return maps.map((e) => Visitor.fromMap(e)).toList();
  }

  Future<List<Visitor>> getCheckedInVisitors() async {
    final db = await database;
    final maps = await db.query(
      'visitors',
      where: 'action = ?',
      whereArgs: ['checked in'],
    );
    return maps.map((e) => Visitor.fromMap(e)).toList();
  }

  // HOSTS
  Future<void> insertHost(Host host) async {
    final db = await database;
    final map = host.toMap();
    await db.insert('hosts', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Host>> getHosts() async {
    final db = await database;
    final maps = await db.query('hosts');
    return maps.map((e) => Host.fromMap(e)).toList();
  }

  // DESTINATIONS / TAGS
  Future<void> saveDestinations(List<Map<String, dynamic>> destinations) async {
    final db = await database;
    final batch = db.batch();
    for (var dest in destinations) {
      batch.insert('destinations', dest, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> getDestinations() async {
    final db = await database;
    final maps = await db.query('destinations');
    return maps.map((e) => {'id': e['id'], 'name': e['name']}).toList();
  }

  Future<void> saveVisitorTags(List<Map<String, dynamic>> tags) async {
    final db = await database;
    final batch = db.batch();
    for (var tag in tags) {
      batch.insert('visitor_tags', tag, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> getVisitorTags() async {
    final db = await database;
    final maps = await db.query('visitor_tags');
    return maps.map((e) => {'id': e['id'], 'name': e['name']}).toList();
  }

  // VISIT RECORDS
  Future<void> insertVisitRecord(VisitRecord visitRecord) async {
    final db = await database;
    await db.insert(
      'visit_records',
      visitRecord.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<VisitRecord?> getActiveVisitRecord(String id) async {
    final db = await database;
    final maps = await db.query(
      'visit_records',
      where: 'visitor_id = ? AND status = ?',
      whereArgs: [id, 'active'],
    );
    if (maps.isEmpty) return null;
    return VisitRecord.fromMap(maps.first);
  }

  Future<void> syncVisitRecords(List<VisitRecord> visitRecords) async {
    final db = await database;
    final batch = db.batch();
    for (var record in visitRecords) {
      batch.insert('visit_records', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit();
  }

  Future<int> getTotalVisitCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM visit_records');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTodaysVisitCount() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM visit_records WHERE created_at LIKE ?',
      ['$today%'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getCheckedInCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM visit_records WHERE status = ?',
      ['active'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getCheckedOutCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM visit_records WHERE status = ?',
      ['checked_out'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // QUEUED ACTIONS
  Future<void> queueAction(Visitor visitor, String type) async {
    final db = await database;
    final map = visitor.toMap();
    if (map['host'] is Map) map['host'] = jsonEncode(map['host']);
    if (map['office'] is Map) map['office'] = jsonEncode(map['office']);

    await db.insert(
      'queued_actions',
      {
        'visitor_id': visitor.id,
        'type': type,
        'data': jsonEncode(map),
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<QueuedAction>> getQueuedActions() async {
    final db = await database;
    final maps = await db.query('queued_actions');
    return maps.map((map) {
      return QueuedAction(
        id: map['id'] as int,
        type: map['type'] as String,
        data: map['data'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
    }).toList();
  }

  Future<void> removeQueuedAction(int id) async {
    final db = await database;
    await db.delete('queued_actions', where: 'id = ?', whereArgs: [id]);
  }

  // VERIFICATIONS
  Future<Map<String, dynamic>?> getCachedVerification(String identifier) async {
    final db = await database;
    final maps = await db.query(
      'cached_verifications',
      where: 'identifier = ?',
      whereArgs: [identifier],
    );
    if (maps.isEmpty) return null;
    return jsonDecode(maps.first['data'] as String);
  }

  Future<void> cacheVerification(String identifier, Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'cached_verifications',
      {
        'identifier': identifier,
        'data': jsonEncode(data),
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

class QueuedAction {
  final int id;
  final String type; // This is the actual action, like 'register' or 'checkout'
  final String data;
  final DateTime createdAt;

  QueuedAction({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
  });

  String get action => type; // Alias getter
}
