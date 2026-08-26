// domain 레이어의 순수성을 강제한다 (기획서 §7.2).
//
// "domain은 Flutter를 모른다"는 규칙은 사람이 지키려고 하면 반드시 샌다.
// import 한 줄이면 깨지고, 깨진 뒤에는 되돌리기가 비싸다.
// 그래서 규칙 자체를 테스트로 만들어 CI가 막게 한다.
//
// 이 규칙이 지켜지는 동안에만 밸런스 시뮬레이터(§8.2)를 CLI에서 돌릴 수 있다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// domain이 의존해서는 안 되는 것들.
const _forbiddenUris = <String>[
  'package:flutter/',
  'package:flutter_test/',
  'package:flutter_riverpod/',
  'dart:ui',
  'dart:io',
  'dart:html',
];

final _importPattern = RegExp(r'''^(?:import|export)\s+['"]([^'"]+)['"]''');

void main() {
  test('domain 레이어는 Flutter·IO에 의존하지 않는다', () {
    final violations = _scan(
      (uri) => _forbiddenUris.any(uri.startsWith),
      '금지된 의존성',
    );

    expect(
      violations,
      isEmpty,
      reason:
          'domain/은 순수 Dart여야 한다 (기획서 §7.2).\n'
          'Flutter가 필요하면 그 코드는 ui/ 또는 app/에 있어야 한다.\n'
          '${violations.join('\n')}',
    );
  });

  test('domain 레이어는 다른 레이어를 상대 경로로 참조하지 않는다', () {
    final violations = _scan(
      (uri) => false,
      '레이어 이탈',
      checkRelative: true,
    );

    expect(
      violations,
      isEmpty,
      reason:
          'domain/은 data/·app/·ui/를 알지 못한다. 의존 방향은 항상 바깥→domain이다.\n'
          '${violations.join('\n')}',
    );
  });
}

List<String> _scan(
  bool Function(String uri) isForbidden,
  String label, {
  bool checkRelative = false,
}) {
  final root = Directory('lib/domain');
  expect(
    root.existsSync(),
    isTrue,
    reason: 'lib/domain 이 없다. 이 테스트가 지킬 대상이 사라졌다.',
  );

  final violations = <String>[];

  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;

    final path = entity.path.replaceAll(r'\', '/');
    final lines = entity.readAsLinesSync();

    for (var i = 0; i < lines.length; i++) {
      final match = _importPattern.firstMatch(lines[i].trim());
      if (match == null) continue;

      final uri = match.group(1)!;

      if (isForbidden(uri)) {
        violations.add('  $label — $path:${i + 1} → $uri');
        continue;
      }

      if (checkRelative &&
          !uri.startsWith('dart:') &&
          !uri.startsWith('package:')) {
        final resolved = _resolve(_dirname(path), uri);
        if (!resolved.startsWith('lib/domain/')) {
          violations.add('  $label — $path:${i + 1} → $uri ($resolved)');
        }
      }
    }
  }

  return violations;
}

String _dirname(String path) {
  final i = path.lastIndexOf('/');
  return i < 0 ? '' : path.substring(0, i);
}

/// `package:path` 없이 상대 경로를 정규화한다.
/// 테스트 하나 때문에 의존성을 늘리지 않기 위해서다.
String _resolve(String fromDir, String relative) {
  final parts = <String>[];
  for (final segment in [...fromDir.split('/'), ...relative.split('/')]) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (parts.isNotEmpty) parts.removeLast();
      continue;
    }
    parts.add(segment);
  }
  return parts.join('/');
}
