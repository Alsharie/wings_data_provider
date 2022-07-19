import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:wings_data_provider/src/remote/request.wings.dart';

import '../errors/exceptions.enum.wings.dart';
import '../errors/exceptions.wings.dart';
import 'methods.enums.wings.dart';

class WingRemoteProvider {
  factory WingRemoteProvider() {
    _singleton ??= WingRemoteProvider._();

    return _singleton!;
  }

  WingRemoteProvider._();

  static WingRemoteProvider? _singleton;

  Dio dio = Dio();

  int statusCode = 0;

  bool get success =>
      statusCode == 200 || statusCode == 201 || statusCode == 202;

  Future<dynamic> send({
    required WingsRequest request,
    required WingsRemoteMethod method,
    Function(int, int)? onSendProgress,
    Function(int, int)? onReceiveProgress,
  }) async {
    try {
      var response = await dio
          .request(
        request.urlQueryString,
        data: request.body,
        options: Options(
          method: method.name,
          headers: request.header,
          receiveTimeout: 0,
          validateStatus: (status) {
            return status != null && status < 500;
          },
        ),
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      )
          .timeout(
        Duration(milliseconds: dio.options.sendTimeout),
        onTimeout: () {
          throw WingsException.fromEnumeration(ExceptionTypes.timeout);
        },
      );

      statusCode = response.statusCode!;

      if (!success) {
        log('Server response with status code $statusCode',
            name: 'Wings Remote');
        throw WingsException.fromStatusCode(statusCode);
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
          options: Options(
            headers: request.header,
            receiveTimeout: 0,
            validateStatus: (status) {
              return status != null && status < 500;
            },
          ),
          onReceiveProgress: onProgress,
        )
            .timeout(
          Duration(milliseconds: dio.options.sendTimeout),
          onTimeout: () {
            throw WingsException.fromEnumeration(ExceptionTypes.timeout);
          },
        ).whenComplete(() {
          if (onComplete != null) onComplete();
        });
        statusCode = response.statusCode!;

        if (!success) {
          log('Server response with status code $statusCode',
              name: 'Wings download');
          throw WingsException.fromStatusCode(statusCode);
        }
        return jsonDecode(response.data);
      } catch (exception) {
        _catchExceptions(exception);
      }
    }
  }

  void _catchExceptions(Object exception) {
    if (exception is DioError) {
      statusCode = exception.response?.statusCode ?? 500;
    }
    throw WingsException.fromStatusCode(statusCode);
  }
}
