/// Standard API response envelope matching the backend format:
/// ```json
/// { "success": true, "data": { }, "message": null, "pagination": { } }
/// ```
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final Pagination? pagination;

  const ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.pagination,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json)? fromJsonT,
  ) {
    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'] as T?,
      message: json['message'] as String?,
      pagination: json['pagination'] != null
          ? Pagination.fromJson(json['pagination'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Standard error response:
/// ```json
/// { "success": false, "error": { "code": "...", "message": "...", "details": [] } }
/// ```
class ApiError {
  final String code;
  final String message;
  final List<ApiErrorDetail> details;

  const ApiError({
    required this.code,
    required this.message,
    this.details = const [],
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    final errorObj = json['error'] as Map<String, dynamic>? ?? json;
    return ApiError(
      code: errorObj['code'] as String? ?? 'UNKNOWN',
      message: errorObj['message'] as String? ?? 'An error occurred',
      details: (errorObj['details'] as List<dynamic>?)
              ?.map((d) => ApiErrorDetail.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ApiErrorDetail {
  final String field;
  final String message;
  final String? value;

  const ApiErrorDetail({
    required this.field,
    required this.message,
    this.value,
  });

  factory ApiErrorDetail.fromJson(Map<String, dynamic> json) {
    return ApiErrorDetail(
      field: json['field'] as String? ?? '',
      message: json['message'] as String? ?? '',
      value: json['value'] as String?,
    );
  }
}

class Pagination {
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  const Pagination({
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 20,
      totalCount: json['totalCount'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
    );
  }

  bool get hasNextPage => page < totalPages;
}
