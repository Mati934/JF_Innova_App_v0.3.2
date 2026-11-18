import 'package:flutter/material.dart';
import '../presentation/screens/email_preview_screen.dart';

class EmailFlowService {
  static Future<Map<String, dynamic>?> openPreview({
    required BuildContext context,
    required String subject,
    required String body,
    required List<String> recipients,
    List<String>? suggestedRecipients,
    String? attachmentName,
    String? attachmentPath,
    String? initialComments,
    String? title,
  }) async {
    return await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EmailPreviewScreen(
          initialSubject: subject,
          initialBody: body,
          initialComments: initialComments,
          recipients: recipients,
          suggestedRecipients: suggestedRecipients ?? recipients,
          attachmentName: attachmentName,
          attachmentPath: attachmentPath,
        ),
      ),
    );
  }
}
