import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_knowledge/river_knowledge.dart';
import 'package:river_platform/river_platform.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  test('shares one bounded in-memory file with its safe override', () async {
    ShareParams? captured;
    final gateway = PlatformImaPortableTransferGateway(
      share: (params) async {
        captured = params;
        return const ShareResult('ima', ShareResultStatus.success);
      },
    );
    final package = _package();

    final outcome = await gateway.share(
      package,
      anchor: const ShareAnchor(left: 1, top: 2, width: 3, height: 4),
    );

    expect(outcome, ImaPortableOutcome.completed);
    expect(captured!.files, hasLength(1));
    expect(captured!.fileNameOverrides, <String>['river.md']);
    expect(await captured!.files!.single.readAsBytes(), package.bytes);
    expect(captured!.sharePositionOrigin!.height, 4);
  });

  test('maps share dismissal, unavailability, and exception', () async {
    final dismissed = PlatformImaPortableTransferGateway(
      share: (_) async => const ShareResult('', ShareResultStatus.dismissed),
    );
    final unavailable = PlatformImaPortableTransferGateway(
      share: (_) async => ShareResult.unavailable,
    );
    final failing = PlatformImaPortableTransferGateway(
      share: (_) => throw StateError('plugin detail'),
    );

    expect(await dismissed.share(_package()), ImaPortableOutcome.dismissed);
    expect(
      await unavailable.share(_package()),
      ImaPortableOutcome.unavailable,
    );
    expect(await failing.share(_package()), ImaPortableOutcome.unavailable);
  });

  test('save uses matching extension and preserves cancellation', () async {
    String? capturedExtension;
    Uint8List? capturedBytes;
    final gateway = PlatformImaPortableTransferGateway(
      share: (_) async => ShareResult.unavailable,
      saveFile: ({
        required String fileName,
        required String dialogTitle,
        required String extension,
        required Uint8List bytes,
      }) async {
        capturedExtension = extension;
        capturedBytes = bytes;
        return null;
      },
    );

    final outcome = await gateway.save(_package());

    expect(outcome, ImaPortableOutcome.dismissed);
    expect(capturedExtension, 'md');
    expect(capturedBytes, _package().bytes);
  });
}

ImaPortablePackage _package() => ImaPortablePackage(
      fileName: 'river.md',
      mediaType: 'text/markdown',
      bytes: Uint8List.fromList(<int>[82, 105, 118, 101, 114]),
      knowledgeItemCount: 1,
    );
