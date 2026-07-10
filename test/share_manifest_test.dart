import 'package:aws_os/features/sharing/data/wire/share_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ShareManifest JSON round-trip preserves files + routing', () {
    const m = ShareManifest(
      token: 'tok',
      senderId: 'id1',
      senderName: 'A',
      files: [
        ManifestFile(
          id: 'f1',
          name: 'a.jpg',
          size: 1234,
          mime: 'image/jpeg',
          kind: 'photo',
        ),
        ManifestFile(
          id: 'f2',
          name: 'base.apk',
          size: 999,
          mime: 'application/vnd.android.package-archive',
          kind: 'apk',
          relPath: 'apk/com.x/base.apk',
          packageId: 'com.x',
        ),
      ],
    );

    final back = ShareManifest.fromJson(m.toJson());
    expect(back.token, 'tok');
    expect(back.senderName, 'A');
    expect(back.files.length, 2);
    expect(back.totalBytes, 1234 + 999);
    expect(back.files[0].itemKind.name, 'photo');
    expect(back.files[1].relPath, 'apk/com.x/base.apk');
    expect(back.files[1].packageId, 'com.x');
  });
}
