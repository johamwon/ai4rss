import 'package:river_commerce/river_commerce.dart';
import 'package:test/test.dart';

void main() {
  test('retries with the same key are charged once', () {
    final meter = UsageMeter(<String, int>{'summary': 20});
    final first = meter.consume(
      idempotencyKey: 'request-1',
      capability: 'summary',
      amount: 1,
      producedUsableResult: true,
    );
    final retry = meter.consume(
      idempotencyKey: 'request-1',
      capability: 'summary',
      amount: 1,
      producedUsableResult: true,
    );

    expect(first.remaining, 19);
    expect(retry.remaining, 19);
    expect(meter.remaining('summary'), 19);
  });

  test('failed AI output does not consume quota', () {
    final meter = UsageMeter(<String, int>{'summary': 20});
    meter.consume(
      idempotencyKey: 'request-2',
      capability: 'summary',
      amount: 1,
      producedUsableResult: false,
    );

    expect(meter.remaining('summary'), 20);
  });
}
