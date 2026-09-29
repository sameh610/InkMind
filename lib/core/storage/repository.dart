import '../models/ink.dart';

abstract class NotebookRepository {
  Future<List<Notebook>> load();
  Future<void> save(Notebook notebook);
  Future<void> delete(String id);
  Future<Map<String, dynamic>> settings();
  Future<void> saveSettings(Map<String, dynamic> data);
}

class MemoryRepository implements NotebookRepository {
  final Map<String, Map<String, dynamic>> _books = {};
  Map<String, dynamic> prefs = {};
  @override
  Future<List<Notebook>> load() async =>
      _books.values.map(Notebook.fromJson).toList();
  @override
  Future<void> save(Notebook notebook) async {
    _books[notebook.id] = notebook.toJson();
  }

  @override
  Future<void> delete(String id) async {
    _books.remove(id);
  }

  @override
  Future<Map<String, dynamic>> settings() async => Map.of(prefs);
  @override
  Future<void> saveSettings(Map<String, dynamic> data) async {
    prefs = Map.of(data);
  }
}
