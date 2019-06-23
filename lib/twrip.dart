import 'dart:convert';
import 'package:http/http.dart' as http;

TwirpException errorFromResponse(http.Response res) {
  if (res.isRedirect) {
    final location = res.headers['Location'];
    return _twirpErrorFromIntermediary(
        res.statusCode,
        "unexpected HTTP status code ${res.statusCode} received, Location=$location",
        location);
  }

  Map err = json.decode(res.body);

  if (!(err.containsKey('code') &&
      err.containsKey('msg') &&
      err['code'] is String &&
      err['msg'] is String)) {
    return _twirpErrorFromIntermediary(
      res.statusCode,
      'Error from intermediary with HTTP status code ${res.statusCode}',
      res.body,
    );
  }
  Map<String, String> meta = {};
  if (err.containsKey('meta') && err['meta'] is Map<String, String>) {
    meta = err['meta'] as Map<String, String>;
  }

  return TwirpException(erroCodeFromTwirpString(err['code']), err['msg'], meta);
}

class TwirpException implements Exception {
  final ErrorCode errorCode;
  final String message;
  final Map<String, String> meta;

  const TwirpException(
      [this.errorCode = ErrorCode.Unknown, this.message, this.meta]);
}

enum ErrorCode {
  Cancelled,
  Unknown,
  InvalidArgument,
  DeadlineExceeded,
  NotFound,
  BadRoute,
  AlreadyExists,
  PermissionDenied,
  Unauthenticated,
  ResourceExhausted,
  FailedPrecondition,
  Aborted,
  OutOfRange,
  Unimplemented,
  Internal,
  Unavailable,
  Dataloss,
}

ErrorCode erroCodeFromTwirpString(String code) {
  switch (code) {
    case "canceled":
      return ErrorCode.Cancelled;
    case "unknown":
      return ErrorCode.Unknown;
    case "invalid_argument":
      return ErrorCode.InvalidArgument;
    case "deadline_exceeded":
      return ErrorCode.DeadlineExceeded;
    case "not_found":
      return ErrorCode.NotFound;
    case "bad_route":
      return ErrorCode.BadRoute;
    case "already_exists":
      return ErrorCode.AlreadyExists;
    case "permission_denied":
      return ErrorCode.PermissionDenied;
    case "unauthenticated":
      return ErrorCode.Unauthenticated;
    case "resource_exhausted":
      return ErrorCode.ResourceExhausted;
    case "failed_precondition":
      return ErrorCode.FailedPrecondition;
    case "aborted":
      return ErrorCode.Aborted;
    case "out_of_range":
      return ErrorCode.OutOfRange;
    case "unimplemented":
      return ErrorCode.Unimplemented;
    case "internal":
      return ErrorCode.Internal;
    case "unavailable":
      return ErrorCode.Unavailable;
    case "dataloss":
      return ErrorCode.Dataloss;
    default:
      return ErrorCode.Unknown;
  }
}

TwirpException _twirpErrorFromIntermediary(
  int status,
  String msg,
  String bodyOrLocation,
) {
  var code = ErrorCode.Unknown;
  if (status >= 300 && status <= 399) {
    code = ErrorCode.Internal;
  } else {
    switch (status) {
      case 400:
        code = ErrorCode.Internal;
        break;
      case 401: // Unauthorized
        code = ErrorCode.Unauthenticated;
        break;
      case 403: // Forbidden
        code = ErrorCode.PermissionDenied;
        break;
      case 404: // Not Found
        code = ErrorCode.BadRoute;
        break;
      case 429: // Too Many Requests, Bad Gateway, Service Unavailable, Gateway Timeout
        code = ErrorCode.Unavailable;
        break;
      case 502:
        code = ErrorCode.Unavailable;
        break;
      case 503:
        code = ErrorCode.Unavailable;
        break;
      case 504:
        code = ErrorCode.Unavailable;
        break;
      default: // All other codes
        code = ErrorCode.Unknown;
    }
  }

  return TwirpException(
    code,
    msg,
    {
      'http_error_from_intermediary': 'true',
      'status_code': status.toString(),
      if (status >= 300 && status <= 399)
        'location': bodyOrLocation
      else
        'body': bodyOrLocation
    },
  );
}
