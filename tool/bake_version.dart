import 'dart:io';

import 'package:dart_style/dart_style.dart';

void main(_) {
  Directory.current = Platform.script.resolve(".").toFilePath();
  final version =
      RegExp(r"^version: ?(.*)$", multiLine: true)
          .firstMatch(File("../pubspec.yaml").readAsStringSync())!
          .group(1)!
          .trim();

  File("../lib/src/version.dart").writeAsStringSync(
    DartFormatter(languageVersion: DartFormatter.latestLanguageVersion).format(
      "// This is an automatically generated file. Do not modify manually.\n// To regenerate this file, run the command 'dart run bake_version.dart'\n\n"
      "const String version = '$version';\n",
    ),
  );
}
