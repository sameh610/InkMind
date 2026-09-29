import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/ink.dart';
import 'repository.dart';

NotebookRepository createRepository() => FileNotebookRepository();

class FileNotebookRepository implements NotebookRepository {
  Future<Directory> get folder async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}/InkMind').create(recursive: true);
  }

  Future<void> write(String name, Map<String, dynamic> data) async {
    final path = '${(await folder).path}/$name.json';
    final temporary = File('$path.tmp');
    await temporary.writeAsString(jsonEncode(data), flush: true);
    await temporary.rename(path);
  }

  @override
  Future<List<Notebook>> load() async {
    final result = <Notebook>[];
    await for (final f in (await folder).list()) {
      if (f is File &&
          f.path.endsWith('.json') &&
          !f.path.endsWith('preferences.json')) {
        result.add(Notebook.fromJson(jsonDecode(await f.readAsString())));
      }
    }
    return result..sort((a, b) => b.edited.compareTo(a.edited));
  }

  @override
  Future<void> save(Notebook n) => write(n.id, n.toJson());
  @override
  Future<void> delete(String id) async {
    final f = File('${(await folder).path}/$id.json');
    if (await f.exists()) await f.delete();
  }

  @override
  Future<Map<String, dynamic>> settings() async {
    final f = File('${(await folder).path}/preferences.json');
    return await f.exists()
        ? Map<String, dynamic>.from(jsonDecode(await f.readAsString()))
        : {};
  }

  @override
  Future<void> saveSettings(Map<String, dynamic> data) =>
      write('preferences', data);
}
