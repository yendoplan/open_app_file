import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:open_app_file/src/common/open_result.dart';
import 'macos.dart' as mac;
import 'windows.dart' as windows;
import 'linux.dart' as linux;

class OpenAppFile {
  static const MethodChannel _channel = const MethodChannel('open_app_file');

  OpenAppFile._();

  /// Attempt to open the file with system default viewer application.
  /// In most cases there's no need to manually provide any type specification.
  /// However, for some edge cases there's a way to affect how the system
  /// builds the list of apps that can handle viewing/editing of the provided
  /// file:
  /// - [mimeType] overrides the type inferred from the file extension on
  /// Android, has no effect on any other platform. This parameter is passed
  /// directly to the [Intent.type] property of the produced Intent.
  /// To learn more about how Android system treats MIME types in intents,
  /// check official documentation
  /// https://developer.android.com/guide/components/intents-filters
  /// - [uti] to provide UTI on iOS, no effect on any other platform
  static Future<OpenResult> open(
    String filePath, {
    String? mimeType,
    String? uti,
    bool locate = false,
  }) async {
    if (Platform.isIOS || Platform.isAndroid) {
      if (!await File(filePath).exists()) {
        return OpenResult(ResultType.fileNotFound,
            message: 'File $filePath does not exist');
      }

      Map<String, String?> map = {
        "file_path": filePath,
        "mime_type": mimeType,
        "uti": uti,
      };
      final result = await _channel.invokeMethod('open_app_file', map);
      final resultMap = json.decode(result) as Map<String, dynamic>;
      return OpenResult.fromJson(resultMap);
    }

    int result;
    String? errorExtra;
    if (Platform.isMacOS) {
      result = mac.system(['open', if (locate) '-R', '$filePath']);
    } else if (Platform.isLinux) {
      var filePathLinux = Uri.file(filePath);
      result = linux.system(['xdg-open', '"${filePathLinux.toString()}"']);
    } else if (Platform.isWindows) {
      final windowsResult = windows.shellExecute('open', filePath);
      errorExtra = ': HINSTANCE=$windowsResult';
      result = windowsResult <= 32 ? 1 : 0;
    } else {
      result = -1;
    }
    return OpenResult(result == 0 ? ResultType.done : ResultType.error,
        message: result == 0
            ? 'done'
            : result == -1
                ? 'This operating system is not currently supported'
                : 'Error while opening $filePath${errorExtra ?? ''}');
  }
}
