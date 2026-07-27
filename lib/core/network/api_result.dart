/// A sealed result type for handling API responses.
/// Forces callers to handle both success and failure cases.
sealed class ApiResult<T> {
  const ApiResult();

  /// Creates a successful result.
  factory ApiResult.success(T data) = ApiSuccess<T>;

  /// Creates a failure result.
  factory ApiResult.failure(String message, {int? statusCode}) = ApiFailure<T>;

  /// Map over the result.
  R when<R>({
    required R Function(T data) success,
    required R Function(String message, int? statusCode) failure,
  }) {
    return switch (this) {
      ApiSuccess<T>(data: final data) => success(data),
      ApiFailure<T>(message: final msg, statusCode: final code) => failure(
        msg,
        code,
      ),
    };
  }

  /// Whether this result is successful.
  bool get isSuccess => this is ApiSuccess<T>;

  /// Get the data or null.
  T? get dataOrNull => switch (this) {
    ApiSuccess<T>(data: final data) => data,
    _ => null,
  };
}

class ApiSuccess<T> extends ApiResult<T> {
  final T data;
  const ApiSuccess(this.data);
}

class ApiFailure<T> extends ApiResult<T> {
  final String message;
  final int? statusCode;
  const ApiFailure(this.message, {this.statusCode});
}
