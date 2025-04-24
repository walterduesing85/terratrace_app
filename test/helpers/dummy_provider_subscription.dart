import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/src/framework.dart';

class DummyProviderSubscription<T> implements ProviderSubscription<T> {
  @override
  void close() {
    // No-op for testing
  }

  @override

  bool get closed => false;

  @override
  T read() {

    throw UnimplementedError(
        'DummyProviderSubscription.read is not used in tests');
  }

  @override

  Node get source => throw UnimplementedError(
      'DummyProviderSubscription.source() is not used in tests');
}
