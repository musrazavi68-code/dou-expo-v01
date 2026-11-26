import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'project_document.dart';

/// Stores editable projects and their source assets in app-private storage.
/// Reads never create directories; writes use temporary files before publish.
class ProjectStore {
  static const _folder = 'dou_expo_projects';
  static final _safeId = RegExp(r'^[A-Za-z0-9_-]{1,80}$');
  static final _safeFileName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,119}$');

  Future<Directory> _root({required bool create}) async {
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}/$_folder');
    if (create) await root.create(recursive: true);
    return root;
  }

  void _validateId(String id) {
    if (!_safeId.hasMatch(id) || id == '.' || id == '..') {
      throw ArgumentError.value(id, 'id', 'Invalid project identifier');
    }
  }

  void _validateFileName(String fileName) {
    if (!_safeFileName.hasMatch(fileName) ||
        fileName == '.' ||
        fileName == '..' ||
        fileName.endsWith('.tmp')) {
      throw ArgumentError.value(fileName, 'fileName', 'Invalid asset name');
    }
  }

  Future<Directory> _projectDirectory(String id, {required bool create}) async {
    _validateId(id);
    final root = await _root(create: create);
    final dir = Directory('${root.path}/$id');
    if (create) {
      await dir.create(recursive: true);
    } else if (!await dir.exists()) {
      throw FileSystemException('Project directory does not exist', dir.path);
    }
    return dir;
  }

  Future<String> saveAsset(String projectId, String fileName, List<int> bytes) async {
    _validateFileName(fileName);
    final dir = await _projectDirectory(projectId, create: true);
    final assets = Directory('${dir.path}/assets');
    await assets.create(recursive: true);
    final target = File('${assets.path}/$fileName');
    final temporary = File('${assets.path}/$fileName.tmp');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(target.path);
    } on FileSystemException {
      // On filesystems that cannot replace an existing file with rename,
      // remove the old asset only after the new bytes are fully written.
      if (!await temporary.exists()) rethrow;
      if (await target.exists()) await target.delete();
      await temporary.rename(target.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
    return 'assets/$fileName';
  }

  Future<File> resolveAsset(String projectId, String relativePath) async {
    if (!relativePath.startsWith('assets/')) {
      throw ArgumentError.value(relativePath, 'relativePath', 'Invalid project asset path');
    }
    final fileName = relativePath.substring('assets/'.length);
    _validateFileName(fileName);
    final dir = await _projectDirectory(projectId, create: false);
    final file = File('${dir.path}/assets/$fileName');
    if (!await file.exists()) throw FileSystemException('Project asset missing', file.path);
    return file;
  }

  Future<void> save(ProjectDocument document) async {
    final dir = await _projectDirectory(document.id, create: true);
    final target = File('${dir.path}/project.json');
    final temporary = File('${dir.path}/project.json.tmp');
    await temporary.writeAsString(document.encode(), flush: true);
    try {
      await temporary.rename(target.path);
    } on FileSystemException {
      final backup = File('${dir.path}/project.json.bak');
      if (await backup.exists()) await backup.delete();
      if (await target.exists()) await target.rename(backup.path);
      try {
        await temporary.rename(target.path);
        if (await backup.exists()) await backup.delete();
      } catch (_) {
        if (await backup.exists() && !await target.exists()) {
          await backup.rename(target.path);
        }
        rethrow;
      }
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<ProjectDocument?> load(String id) async {
    _validateId(id);
    final root = await _root(create: false);
    final dir = Directory('${root.path}/$id');
    if (!await dir.exists()) return null;
    final file = File('${dir.path}/project.json');
    final backup = File('${dir.path}/project.json.bak');
    if (!await file.exists() && !await backup.exists()) return null;
    ProjectDocument project;
    if (await file.exists()) {
      try {
        project = ProjectDocument.decode(await file.readAsString());
      } on FormatException {
        if (!await backup.exists()) rethrow;
        project = ProjectDocument.decode(await backup.readAsString());
      } on TypeError {
        if (!await backup.exists()) rethrow;
        project = ProjectDocument.decode(await backup.readAsString());
      } on ArgumentError {
        if (!await backup.exists()) rethrow;
        project = ProjectDocument.decode(await backup.readAsString());
      }
    } else {
      project = ProjectDocument.decode(await backup.readAsString());
    }
    if (project.id != id) {
      throw FormatException('Project manifest identifier does not match its directory');
    }
    return project;
  }

  Future<List<ProjectDocument>> list() async {
    final root = await _root(create: false);
    if (!await root.exists()) return const [];
    final projects = <ProjectDocument>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final id = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
      try {
        // Use load() so a valid backup manifest remains discoverable when the
        // primary project.json is missing or damaged.
        final project = await load(id);
        if (project != null) projects.add(project);
      } on FormatException {
        // Keep damaged projects on disk; omit them from the browser.
      } on TypeError {
        // Keep incompatible metadata on disk; omit it from the browser.
      } on ArgumentError {
        // Invalid directory identifiers or fields are not valid projects.
      } on FileSystemException {
        // A project may be concurrently removed or become temporarily unreadable.
      }
    }
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  Future<void> delete(String id) async {
    _validateId(id);
    final root = await _root(create: false);
    final dir = Directory('${root.path}/$id');
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
