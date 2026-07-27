import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../constants/app_constants.dart';

/// Configured Dio HTTP client for Spotify API calls.
/// Includes timeout settings and an auth interceptor slot.
class DioClient {
  late final Dio _dio;

  DioClient({String? baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? ApiConstants.spotifyBaseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  Dio get dio => _dio;

  /// Set the Bearer authorization token on all future requests.
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Remove the authorization token (on sign-out).
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  /// Add a custom interceptor (auth refresh, retry, logging, etc.).
  void addInterceptor(Interceptor interceptor) {
    _dio.interceptors.add(interceptor);
  }
}

/// Dio interceptor that injects the Spotify Bearer token automatically.
/// Provide a [getToken] callback that returns the current valid token.
/// If [onUnauthorized] is set, it will be called on 401 responses.
class AuthInterceptor extends Interceptor {
  final Future<String?> Function() getToken;
  final Future<void> Function()? onUnauthorized;

  AuthInterceptor({required this.getToken, this.onUnauthorized});

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      onUnauthorized?.call();
    }
    handler.next(err);
  }
}
