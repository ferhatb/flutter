// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:pool/pool.dart';

import '../../asset.dart';
import '../../base/file_system.dart';
import '../../devfs.dart';
import '../../plugins.dart';
import '../../project.dart';
import '../build_system.dart';

/// The copying logic for flutter assets.
class AssetBehavior extends SourceBehavior {
  const AssetBehavior();

  @override
  List<File> inputs(Environment environment) {
    final AssetBundle assetBundle = AssetBundleFactory.instance.createBundle();
    assetBundle.build(
      manifestPath: environment.projectDir.childFile('pubspec.yaml').path,
      packagesPath: environment.projectDir.childFile('.packages').path,
    );
    // Filter the file type to remove the files that are generated by this
    // command as inputs.
    final List<File> results = <File>[];
    final Iterable<DevFSFileContent> files = assetBundle.entries.values.whereType<DevFSFileContent>();
    for (DevFSFileContent devFsContent in files) {
      results.add(fs.file(devFsContent.file.path));
    }
    return results;
  }

  @override
  List<File> outputs(Environment environment) {
    final AssetBundle assetBundle = AssetBundleFactory.instance.createBundle();
    assetBundle.build(
      manifestPath: environment.projectDir.childFile('pubspec.yaml').path,
      packagesPath: environment.projectDir.childFile('.packages').path,
    );
    final List<File> results = <File>[];
    for (String key in assetBundle.entries.keys) {
      final File file = fs.file(fs.path.join(environment.buildDir.path, 'flutter_assets', key));
      results.add(file);
    }
    return results;
  }
}

/// A specific asset behavior for building bundles.
class AssetOutputBehavior extends SourceBehavior {
  const AssetOutputBehavior();

  @override
  List<File> inputs(Environment environment) {
    final AssetBundle assetBundle = AssetBundleFactory.instance.createBundle();
    assetBundle.build(
      manifestPath: environment.projectDir.childFile('pubspec.yaml').path,
      packagesPath: environment.projectDir.childFile('.packages').path,
    );
    // Filter the file type to remove the files that are generated by this
    // command as inputs.
    final List<File> results = <File>[];
    final Iterable<DevFSFileContent> files = assetBundle.entries.values.whereType<DevFSFileContent>();
    for (DevFSFileContent devFsContent in files) {
      results.add(fs.file(devFsContent.file.path));
    }
    return results;
  }

  @override
  List<File> outputs(Environment environment) {
    final AssetBundle assetBundle = AssetBundleFactory.instance.createBundle();
    assetBundle.build(
      manifestPath: environment.projectDir.childFile('pubspec.yaml').path,
      packagesPath: environment.projectDir.childFile('.packages').path,
    );
    final List<File> results = <File>[];
    for (String key in assetBundle.entries.keys) {
      final File file = fs.file(fs.path.join(environment.outputDir.path, key));
      results.add(file);
    }
    return results;
  }
}

/// Copy the assets defined in the flutter manifest into a build directory.
class CopyAssets extends Target {
  const CopyAssets();

  @override
  String get name => 'copy_assets';

  @override
  List<Target> get dependencies => const <Target>[];

  @override
  List<Source> get inputs => const <Source>[
    Source.pattern('{FLUTTER_ROOT}/packages/flutter_tools/lib/src/build_system/targets/assets.dart'),
    Source.pattern('{PROJECT_DIR}/pubspec.yaml'),
    Source.behavior(AssetBehavior()),
  ];

  @override
  List<Source> get outputs => const <Source>[
    Source.pattern('{BUILD_DIR}/flutter_assets/AssetManifest.json'),
    Source.pattern('{BUILD_DIR}/flutter_assets/FontManifest.json'),
    Source.pattern('{BUILD_DIR}/flutter_assets/LICENSE'),
    Source.behavior(AssetBehavior()), // <- everything in this subdirectory.
  ];

  @override
  Future<void> build(Environment environment) async {
    final Directory output = environment
      .buildDir
      .childDirectory('flutter_assets');
    if (output.existsSync()) {
      output.deleteSync(recursive: true);
    }
    output.createSync(recursive: true);
    final AssetBundle assetBundle = AssetBundleFactory.instance.createBundle();
    await assetBundle.build(
      manifestPath: environment.projectDir.childFile('pubspec.yaml').path,
      packagesPath: environment.projectDir.childFile('.packages').path,
    );
    // Limit number of open files to avoid running out of file descriptors.
    final Pool pool = Pool(64);
    await Future.wait<void>(
      assetBundle.entries.entries.map<Future<void>>((MapEntry<String, DevFSContent> entry) async {
        final PoolResource resource = await pool.request();
        try {
          final File file = fs.file(fs.path.join(output.path, entry.key));
          file.parent.createSync(recursive: true);
          await file.writeAsBytes(await entry.value.contentsAsBytes());
        } finally {
          resource.release();
        }
      }));
  }
}

/// Rewrites the `.flutter-plugins` file of [project] based on the plugin
/// dependencies declared in `pubspec.yaml`.
// TODO(jonahwiliams): this should be per platform and located in build
// outputs.
class FlutterPlugins extends Target {
  const FlutterPlugins();

  @override
  String get name => 'flutter_plugins';

  @override
  List<Target> get dependencies => const <Target>[];

  @override
  List<Source> get inputs => const <Source>[
    Source.pattern('{FLUTTER_ROOT}/packages/flutter_tools/lib/src/build_system/targets/assets.dart'),
    Source.pattern('{PROJECT_DIR}/pubspec.yaml'),
  ];

  @override
  List<Source> get outputs => const <Source>[
    Source.pattern('{PROJECT_DIR}/.flutter-plugins'),
  ];

  @override
  Future<void> build(Environment environment) async {
    // The pubspec may change for reasons other than plugins changing, so we compare
    // the manifest before writing. Some hosting build systems use timestamps
    // so we need to be careful to avoid tricking them into doing more work than
    // necessary.
    final FlutterProject project = FlutterProject.fromDirectory(environment.projectDir);
    final List<Plugin> plugins = findPlugins(project);
    final String pluginManifest = plugins
        .map<String>((Plugin p) => '${p.name}=${escapePath(p.path)}')
        .join('\n');
    final File flutterPluginsFile = environment.projectDir.childFile('.flutter-plugins');
    if (!flutterPluginsFile.existsSync() || flutterPluginsFile.readAsStringSync() != pluginManifest) {
      flutterPluginsFile.writeAsStringSync(pluginManifest);
    }
  }
}
