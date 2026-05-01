import 'package:file_picker/file_picker.dart';

/// Non-web: default [FilePicker] behavior.
Future<FilePickerResult?> pickDoctorChatFilesRaw({
  required bool allowMultiple,
  required bool withData,
  required FileType type,
  List<String>? allowedExtensions,
}) {
  return FilePicker.platform.pickFiles(
    allowMultiple: allowMultiple,
    withData: withData,
    type: type,
    allowedExtensions: allowedExtensions,
  );
}
