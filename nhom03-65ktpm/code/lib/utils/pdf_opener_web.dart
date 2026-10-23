import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

bool openPdfBytes(Uint8List bytes) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  final opened = web.window.open(url, '_blank') != null;
  if (!opened) web.URL.revokeObjectURL(url);
  if (opened) {
    unawaited(
      Future<void>.delayed(
        const Duration(minutes: 2),
        () => web.URL.revokeObjectURL(url),
      ),
    );
  }
  return opened;
}
