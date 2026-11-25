import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/sync/services/sync_execution_gate.dart';

void main() {
  test('llamadas simultaneas comparten una sola sincronizacion', () async {
    final gate = SyncExecutionGate<int>();
    final operation = Completer<int>();
    var executions = 0;

    Future<int> synchronize() => gate.run(() {
      executions++;
      return operation.future;
    });

    final first = synchronize();
    final second = synchronize();

    expect(executions, 1);
    expect(identical(first, second), isTrue);

    operation.complete(7);
    expect(await first, 7);
    expect(await second, 7);
  });

  test('permite una nueva sincronizacion despues de completar', () async {
    final gate = SyncExecutionGate<int>();
    var executions = 0;

    await gate.run(() async => ++executions);
    await gate.run(() async => ++executions);

    expect(executions, 2);
  });
}
