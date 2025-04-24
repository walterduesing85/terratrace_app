import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dummy_provider_subscription.dart';

class FakeWidgetRef implements WidgetRef {
  final ProviderContainer container;

  FakeWidgetRef(this.container);

  @override
  T read<T>(ProviderListenable<T> provider) => container.read(provider);

  @override
  T watch<T>(ProviderListenable<T> provider) => container.read(provider);

  @override
  void listen<T>(
    ProviderListenable<T> provider,
    void Function(T? previous, T next) listener, {
    bool? fireImmediately,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    // no-op for test
  }

  @override
  ProviderSubscription<T> listenManual<T>(
    ProviderListenable<T> provider,
    void Function(T? previous, T next) listener, {
    bool fireImmediately = true,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    return DummyProviderSubscription<T>();
  }

  @override
  void invalidate(ProviderOrFamily provider) {
    // Optional — not used in tests unless explicitly needed
  }

  @override
  State refresh<State>(Refreshable<State> provider) {
    throw UnimplementedError(
        'FakeWidgetRef.refresh is not implemented in tests');
  }

  @override
  bool exists(ProviderBase<Object?> provider) {
    return container
        .getAllProviderElements()
        .any((e) => e.provider == provider);
  }

  @override
  BuildContext get context =>
      throw UnimplementedError('FakeWidgetRef has no BuildContext');
}
