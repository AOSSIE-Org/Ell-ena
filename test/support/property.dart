import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

/// Builds a random value of type [T].
typedef Gen<T> = T Function(Random random);

/// Registers a property test: [body] must hold for [runs] values drawn from
/// [gen]. Runs are seeded, so a failure names the seed and input that
/// reproduce it.
void property<T>(
  String description,
  Gen<T> gen,
  void Function(T value) body, {
  int runs = 200,
  int seed = 20261022,
}) {
  test('property: $description', () {
    final random = Random(seed);
    for (var run = 0; run < runs; run++) {
      final value = gen(random);
      try {
        body(value);
      } catch (e) {
        fail('Failed on run $run (seed $seed) for input:\n$value\n\n$e');
      }
    }
  });
}

/// Small generator library for [property].
class Gens {
  Gens._();

  static Gen<int> intIn(int min, int max) =>
      (r) => min + r.nextInt(max - min + 1);

  static Gen<bool> boolean() => (r) => r.nextBool();

  static Gen<T> oneOf<T>(List<T> values) =>
      (r) => values[r.nextInt(values.length)];

  static Gen<T?> nullable<T>(Gen<T> gen, {double nullChance = 0.2}) =>
      (r) => r.nextDouble() < nullChance ? null : gen(r);

  static const _alphabet =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_.,!?';

  /// Strings from [alphabet], including the empty string.
  static Gen<String> string({
    int maxLength = 24,
    String alphabet = _alphabet,
  }) =>
      (r) => String.fromCharCodes(List.generate(
            r.nextInt(maxLength + 1),
            (_) => alphabet.codeUnitAt(r.nextInt(alphabet.length)),
          ));

  /// Non-empty words of lowercase letters.
  static Gen<String> word({int maxLength = 10}) => (r) => String.fromCharCodes(
        List.generate(
          1 + r.nextInt(maxLength),
          (_) => 97 + r.nextInt(26),
        ),
      );

  static Gen<List<T>> listOf<T>(Gen<T> gen, {int maxLength = 8}) =>
      (r) => List.generate(r.nextInt(maxLength + 1), (_) => gen(r));

  /// Dates between 2020 and 2030, at minute precision, in UTC.
  static Gen<DateTime> dateTime() => (r) =>
      DateTime.utc(2020).add(Duration(minutes: r.nextInt(60 * 24 * 365 * 10)));
}
