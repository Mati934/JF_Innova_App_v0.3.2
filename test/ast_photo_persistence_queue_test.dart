import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/ast/presentation/controllers/ast_photo_persistence_queue.dart';

void main() {
  test('finalizacion espera el procesamiento de fotos en curso', () async {
    final queue = AstPhotoPersistenceQueue();
    final photoReady = Completer<void>();
    var pdfGenerated = false;

    queue.track(photoReady.future);
    final finalize = queue.waitUntilIdle().then((_) => pdfGenerated = true);

    await Future<void>.delayed(Duration.zero);
    expect(pdfGenerated, isFalse);

    photoReady.complete();
    await finalize;

    expect(pdfGenerated, isTrue);
    expect(queue.isProcessing, isFalse);
  });

  test('espera también una operación iniciada mientras otra termina', () async {
    final queue = AstPhotoPersistenceQueue();
    final first = Completer<void>();
    final second = Completer<void>();

    queue.track(first.future);
    final waiting = queue.waitUntilIdle();
    queue.track(second.future);

    first.complete();
    await Future<void>.delayed(Duration.zero);

    var finished = false;
    waiting.then((_) => finished = true);
    await Future<void>.delayed(Duration.zero);
    expect(finished, isFalse);

    second.complete();
    await waiting;
    expect(queue.isProcessing, isFalse);
  });
}
