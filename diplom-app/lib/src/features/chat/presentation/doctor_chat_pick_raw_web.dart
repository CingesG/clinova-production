import 'package:file_picker/_internal/file_picker_web.dart';
import 'package:file_picker/file_picker.dart';

/// Web: disable focus-based cancellation heuristics that can return `null`
/// even after the user selected a file (see file_picker issue #1202 / #1833).
Future<FilePickerResult?> pickDoctorChatFilesRaw({
  required bool allowMultiple,
  required bool withData,
  required FileType type,
  List<String>? allowedExtensions,
}) {
  final platform = FilePicker.platform;
  if (platform is FilePickerWeb) {
    return platform.pickFiles(
      allowMultiple: allowMultiple,
      withData: withData,
      type: type,
      allowedExtensions: allowedExtensions,
      cancelUploadOnWindowBlur: false,
    );
  }
  return FilePicker.platform.pickFiles(
    allowMultiple: allowMultiple,
    withData: withData,
    type: type,
    allowedExtensions: allowedExtensions,
  );
}
