import 'package:idb_shim/idb_browser.dart';
import '../models/ink.dart';
import 'repository.dart';

NotebookRepository createRepository() => IndexedDbRepository();

class IndexedDbRepository implements NotebookRepository {
  Database? _db;
  Future<Database> get db async => _db ??= await getIdbFactory()!.open(
    'inkmind-v1',
    version: 1,
    onUpgradeNeeded: (e) {
      e.database.createObjectStore('notebooks', keyPath: 'id');
      e.database.createObjectStore('settings');
    },
  );
  @override
  Future<List<Notebook>> load() async {
    final t = (await db).transaction('notebooks', idbModeReadOnly);
    final rows = await t.objectStore('notebooks').getAll();
    await t.completed;
    return rows
        .map((r) => Notebook.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList()
      ..sort((a, b) => b.edited.compareTo(a.edited));
  }

  @override
  Future<void> save(Notebook notebook) async {
    final t = (await db).transaction('notebooks', idbModeReadWrite);
    await t.objectStore('notebooks').put(notebook.toJson());
    await t.completed;
  }

  @override
  Future<void> delete(String id) async {
    final t = (await db).transaction('notebooks', idbModeReadWrite);
    await t.objectStore('notebooks').delete(id);
    await t.completed;
  }

  @override
  Future<Map<String, dynamic>> settings() async {
    final t = (await db).transaction('settings', idbModeReadOnly);
    final value = await t.objectStore('settings').getObject('preferences');
    await t.completed;
    return value == null ? {} : Map<String, dynamic>.from(value as Map);
  }

  @override
  Future<void> saveSettings(Map<String, dynamic> data) async {
    final t = (await db).transaction('settings', idbModeReadWrite);
    await t.objectStore('settings').put(data, 'preferences');
    await t.completed;
  }
}
