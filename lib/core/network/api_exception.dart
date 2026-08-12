import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException({required this.message, this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final Object? details;

  factory ApiException.fromDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;
    final responseMessage = responseData is Map<String, dynamic>
        ? responseData['message']?.toString()
        : null;

    return ApiException(
      statusCode: statusCode,
      details: responseData,
      message: responseMessage ?? _messageFor(error, statusCode),
    );
  }

  static ApiException? maybeFrom(Object error) {
    if (error is ApiException) {
      return error;
    }
    if (error is DioException && error.error is ApiException) {
      return error.error! as ApiException;
    }
    return null;
  }

  /// Short message safe to show in banners/snackbars (no DioException dump).
  static String userMessage(
    Object error, {
    String fallback = 'Đã có lỗi xảy ra. Vui lòng thử lại.',
  }) {
    final api = maybeFrom(error);
    if (api != null) {
      final message = api.message.trim();
      if (message.isNotEmpty) return message;
    }

    if (error is DioException) {
      return ApiException.fromDioException(error).message;
    }

    final raw = error.toString().trim();
    if (raw.isEmpty) return fallback;

    final cleaned = raw
        .replaceFirst(RegExp(r'^DioException\s*\[[^\]]*\]:\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*Error:\s*.*$', caseSensitive: false), '')
        .trim();
    if (cleaned.isEmpty ||
        cleaned.toLowerCase().contains('dioexception') ||
        cleaned.toLowerCase().startsWith('exception:')) {
      return fallback;
    }
    return cleaned;
  }

  static String _messageFor(DioException error, int? statusCode) {
    if (statusCode == 400) {
      return 'Thông tin gửi lên không hợp lệ. Vui lòng kiểm tra lại.';
    }

    if (statusCode == 401) {
      return 'Tài khoản hoặc mật khẩu không đúng.';
    }

    if (statusCode == 403) {
      return 'Bạn không có quyền thực hiện thao tác này.';
    }

    if (statusCode == 500) {
      return 'Máy chủ đang bận. Vui lòng thử lại sau.';
    }

    if (statusCode != null) {
      return 'Không thể xử lý yêu cầu. Mã lỗi: $statusCode.';
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Kết nối quá thời gian chờ. Vui lòng thử lại.';
    }

    return 'Không kết nối được máy chủ. Vui lòng kiểm tra mạng hoặc API.';
  }

  @override
  String toString() => message;
}
