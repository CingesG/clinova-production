import 'package:flutter/material.dart';

const String kMnGoogleCancelled = 'Google нэвтрэлт цуцлагдлаа.';
const String kMnClientIdMissing = 'Google Client ID тохируулагдаагүй байна.';
const String kMnConfigIncompleteShort = 'Google тохиргоо дутуу байна.';
const String kMnSignInFailed = 'Google нэвтрэлт амжилтгүй боллоо.';

void showClinovaGoogleSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
