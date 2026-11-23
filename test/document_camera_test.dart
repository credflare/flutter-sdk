import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:credflare_sdk/credflare_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'support/backend.dart';
import 'support/fixtures.dart';

class FakeCameras extends CameraPlatform {
  List<CameraDescription> cameras = [];
  @override
  Future<List<CameraDescription>> availableCameras() async => cameras;
}

class FakePicker extends ImagePickerPlatform {
  final sources = <ImageSource>[];
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    sources.add(source);
    return null;
  }
}

void main() {
  late FakeCameras cameras;
  late FakePicker picker;
  setUp(() {
    cameras = FakeCameras();
    picker = FakePicker();
    CameraPlatform.instance = cameras;
    ImagePickerPlatform.instance = picker;
  });

  Future<void> openDocument(WidgetTester tester, String method) async {
    final raw = captureSession(method);
    raw['data']['profile']['form_schema'] = null;
    final backend = Backend()..sessions.add(raw);
    await tester.pumpWidget(
      MaterialApp(
        home: CredflareVerification(
          autoStart: true,
          onClose: () {},
          httpClient: backend.client,
          sessionProvider: () async => descriptor(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final document =
        raw['data']['profile']['document_requirements'][0]['document_type']['name']
            as String;
    await tester.tap(find.text(document));
    await tester.pumpAndSettle();
  }

  Future<void> takePhoto(WidgetTester tester) async {
    final button = find.text(copy(SpecCopyKey.captureTakePhoto));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('camera photos without a camera show the camera message', (
    tester,
  ) async {
    await openDocument(tester, 'snapshot');
    await takePhoto(tester);
    expect(
      find.text(copy(SpecCopyKey.errorsCameraUnavailable)),
      findsOneWidget,
    );
    expect(picker.sources, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('photo or file without a camera keeps the file option', (
    tester,
  ) async {
    await openDocument(tester, 'snapshot_or_upload');
    await takePhoto(tester);
    expect(
      find.text(copy(SpecCopyKey.errorsCameraUnavailable)),
      findsOneWidget,
    );
    expect(find.text(copy(SpecCopyKey.captureChooseFile)), findsOneWidget);
    expect(picker.sources, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a device with a camera opens it', (tester) async {
    cameras.cameras = [
      const CameraDescription(
        name: '0',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      ),
    ];
    await openDocument(tester, 'snapshot');
    await takePhoto(tester);
    expect(picker.sources, [ImageSource.camera]);
    expect(find.text(copy(SpecCopyKey.errorsCameraUnavailable)), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
