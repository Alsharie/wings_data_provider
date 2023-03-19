import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:wings_data_provider/src/remote/request.wings.dart';

import '../errors/exceptions.enum.wings.dart';
import '../errors/exceptions.wings.dart';
import 'methods.enums.wings.dart';

class WingsRemoteProvider {
  factory WingsRemoteProvider() {
    _singleton ??= WingsRemoteProvider._();

    return _singleton!;
  }

  WingsRemoteProvider._();

  static WingsRemoteProvider? _singleton;

  Dio dio = Dio();

  Future<dynamic> send({
    required WingsRequest request,
    required WingsRemoteMethod method,
    List<int> successStates = const [200, 201, 202],
    Function(Response, int)? onSuccess,
    Function(Response, int)? onError,
    Function(int, int)? onSendProgress,
    Function(int, int)? onReceiveProgress,
    ResponseType? responseType,
  }) async {
    try {
      Response<dynamic> response = await dio
          .request(
        request.urlQueryString,
        data: request.body,
        options: Options(
          method: method.name,
          headers: request.header,
          responseType: responseType,
          receiveTimeout: Duration.zero,
          validateStatus: (status) {
            return status != null && status < 500;
          },
        ),
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      )
          .timeout(
        Duration(milliseconds: dio.options.sendTimeout!.inMilliseconds),
        onTimeout: () {
          throw WingsException.fromEnumeration(ExceptionTypes.timeout);
        },
      );

      var statusCode = response.statusCode!;

      if (successStates.contains(statusCode)) {
        if (onSuccess != null) onSuccess(response, statusCode);
      } else {
        log('Server response with status code $statusCode',
            name: 'Wings Remote');
        if (onError != null) {
          onError(response, statusCode);
        } else {
          throw WingsException.fromStatusCode(statusCode);
        }
      }
      return response;
    } catch (exception) {
      _catchExceptions(exception);
    }
  }

  Future<dynamic> download({
    required WingsRequest request,
    required String savePath,
    Function(int, int)? onProgress,
    VoidCallback? onComplete,
    List<int> successStates = const [200, 201, 202],
    Function(Response, int)? onSuccess,
    Function(Response, int)? onError,
    CancelToken? cancelToken,
    bool overrideIfExists = false,
  }) async {
    if (await File(savePath).exists() && !overrideIfExists) {
      if (onComplete != null) onComplete();
    } else {
      try {
        var response = await dio
            .download(
          request.url,
          savePath,
          cancelToken: cancelToken,
          options: Options(
            headers: request.header,
            receiveTimeout: Duration.zero,
            validateStatus: (status) {
              return status != null && status < 500;
            },
          ),
          onReceiveProgress: onProgress,
        )
            .timeout(
          Duration(milliseconds: dio.options.sendTimeout!.inMilliseconds),
          onTimeout: () {
            throw WingsException.fromEnumeration(ExceptionTypes.timeout);
          },
        ).whenComplete(() {
          if (onComplete != null) onComplete();
        });

        var statusCode = response.statusCode!;

        if (successStates.contains(statusCode)) {
          if (onSuccess != null) onSuccess(response, statusCode);
        } else {
          log('Server response with status code $statusCode',
              name: 'Wings Remote');
          if (onError != null) {
            onError(response, statusCode);
          } else {
            throw WingsException.fromStatusCode(statusCode);
          }
        }

        return jsonDecode(response.data);
      } catch (exception) {
        _catchExceptions(exception);
      }
    }
  }

  void _catchExceptions(Object exception) {
    var statusCode = 500;
    if (exception is DioError) {
      statusCode = exception.response?.statusCode ?? 500;
      log(exception.response?.data, name: 'dio error');
    }
    throw WingsException.fromStatusCode(statusCode);
  }
}
