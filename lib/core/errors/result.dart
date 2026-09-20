sealed class Result<T, F> {
  const Result();

  const factory Result.success(T value) = Success<T, F>;
  const factory Result.failure(F failure) = Failure<T, F>;
  const factory Result.error(F failure) = Failure<T, F>;
}

class Success<T, F> extends Result<T, F> {
  const Success(this.value) : super();
  final T value;
}

class Failure<T, F> extends Result<T, F> {
  const Failure(this.failure) : super();
  final F failure;
}

extension ResultAccessors<T, F> on Result<T, F> {
  bool get isSuccess => this is Success<T, F>;
  bool get isError => this is Failure<T, F>;
  bool get isFailure => isError;

  T? get value => switch (this) {
        Success<T, F> success => success.value,
        Failure<T, F> _ => null,
      };

  F? get error => switch (this) {
        Success<T, F> _ => null,
        Failure<T, F> failure => failure.failure,
      };

  W when<W>({
    required W Function(T value) success,
    required W Function(F failure) failure,
  }) {
    return switch (this) {
      Success<T, F> s => success(s.value),
      Failure<T, F> f => failure(f.failure),
    };
  }

  W fold<W>({
    required W Function(T value) onSuccess,
    required W Function(F failure) onFailure,
  }) {
    return switch (this) {
      Success<T, F> s => onSuccess(s.value),
      Failure<T, F> f => onFailure(f.failure),
    };
  }

  T getOrElse(T Function() orElse) {
    return switch (this) {
      Success<T, F> s => s.value,
      Failure<T, F> _ => orElse(),
    };
  }
}
