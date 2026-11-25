import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'project_document.dart';

/// Stores editable projects and their source assets in app-private storage.
class ProjectStore {
  static const _folder = 'dou_expo_projects';

  Future<Directory> _root() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}/$_folder');
    await root.create(recursive: true);
    return root;
  }

  Future<Directory> _projectDirectory(String id) async {
    if (id.isEmpty || id.contains('/') || id.contains('..')) {
      throw ArgumentError.value(id, 'id', 'Invalid project identifier');
    }
    final dir = Directory('${(await _root()).path}/$id');
    await dir.create(recursive: true);
    return dir;
  }

  Future<String> saveAsset(String projectId, String fileName, List<int> bytes) async {
    if (fileName.isEmpty || fileName.contains('/') || fileName.contains('..')) {
      throw ArgumentError.value(fileName, 'fileName', 'Invalid asset name');
    }
    final dir = await _projectDirectory(projectId);
    final assets = Directory('${dir.path}/assets');
    await assets.create(recursive: true);
    final file = File('${assets.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return 'assets/$fileName';
  }

  Future<File> resolveAsset(String projectId, String relativePath) async {
    if (!relativePath.startsWith('assets/') || relativePath.contains('..')) {
      throw ArgumentError.value(relativePath, 'relativePath', 'Invalid project asset path');
    }
    final dir = await _projectDirectory(projectId);
    final file = File('${dir.path}/$relativePath');
    if (!await file.exists()) throw FileSystemException('Project asset missing', file.path);
    return file;
  }

  Future<void> save(ProjectDocument document) async {
    final dir = await _projectDirectory(document.id);
    final target = File('${dir.path}/project.json');
    final temporary = File('${dir.path}/project.json.tmp');
    await temporary.writeAsString(document.encode(), flush: true);
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
  }

  Future<ProjectDocument?> load(String id) async {
    final dir = await _projectDirectory(id);
    final file = File('${dir.path}/project.json');
    if (!await file.exists()) return null;
    return ProjectDocument.decode(await file.readAsString());
  }

  Future<List<ProjectDocument>> list() async {
    final root = await _root();
    final projects = <ProjectDocument>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final file = File('${entity.path}/project.json');
      if (!await file.exists()) continue;
      try {
        projects.add(ProjectDocument.decode(await file.readAsString()));
      } on FormatException {
        // Ignore a damaged project index entry; never crash the project browser.
      } on TypeError {
        // Ignore incompatible metadata and leave the original files untouched.
      }
    }
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  Future<void> delete(String id) async {
    final dir = await _projectDirectory(id);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
