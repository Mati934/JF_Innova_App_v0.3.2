import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/focus_utils.dart';
import '../../../../core/utils/safe_area_utils.dart';
import '../../services/email_template_service.dart';

class EmailPreviewScreen extends StatefulWidget {
  final String? initialSubject;
  final String? initialBody;
  final String? initialComments;
  final List<String> recipients;
  final List<String> suggestedRecipients;
  final String? attachmentName;
  final String? attachmentPath;

  const EmailPreviewScreen({
    super.key,
    this.initialSubject,
    this.initialBody,
    this.initialComments,
    this.recipients = const [],
    this.suggestedRecipients = const [],
    this.attachmentName,
    this.attachmentPath,
  });

  @override
  State<EmailPreviewScreen> createState() => _EmailPreviewScreenState();
}

class _EmailPreviewScreenState extends State<EmailPreviewScreen> {
  late TextEditingController _subjectController;
  late TextEditingController _bodyController;
  late TextEditingController _commentsController;
  late final List<String> _suggestedRecipients;
  late final List<String> _selectedRecipients;
  final TextEditingController _manualRecipientCtrl = TextEditingController();

  static const _cNavy = Color(0xFF10233F);
  static const _cNavy2 = Color(0xFF16305A);
  static const _cPaper = Color(0xFFF3F0E7);
  static const _cCard = Colors.white;
  static const _cInk = Color(0xFF1B2430);
  static const _cMuted = Color(0xFF6B7280);
  static const _cLine = Color(0xFFDFD9C8);
  static const _cAmber = Color(0xFFE8A33D);
  static const _cAmberInk = Color(0xFF7A4A08);
  static const _cGreen = Color(0xFF2F7A5C);
  static const _cGreenBg = Color(0xFFE4F0EA);

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController(
      text: widget.initialSubject ?? '',
    );
    _bodyController = TextEditingController(text: widget.initialBody ?? '');
    _commentsController = TextEditingController(
      text: widget.initialComments ?? '',
    );
    _suggestedRecipients =
        (widget.suggestedRecipients.isNotEmpty
                ? widget.suggestedRecipients
                : widget.recipients)
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();
    _selectedRecipients = widget.recipients
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    _commentsController.dispose();
    _manualRecipientCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return false;
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return regex.hasMatch(email);
  }

  void _removeRecipient(String email) {
    setState(() => _selectedRecipients.remove(email));
  }

  void _addRecipient(String email) {
    final normalized = email.trim();
    if (!_isValidEmail(normalized)) return;
    if (_selectedRecipients.contains(normalized)) return;
    setState(() {
      _selectedRecipients.add(normalized);
      if (!_suggestedRecipients.contains(normalized)) {
        _suggestedRecipients.add(normalized);
      }
    });
  }

  String _initialFromEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  void _reAddSuggested() {
    final available = _suggestedRecipients
        .where((e) => !_selectedRecipients.contains(e))
        .toList();
    if (available.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay correos sugeridos por agregar.')),
      );
      return;
    }
    _addRecipient(available.first);
  }

  Future<void> _showManualFallback(
    String recipients,
    String subject,
    String body,
  ) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No se pudo abrir la app de correo'),
        content: const Text(
          'No hay una app de correo disponible para abrir este enlace. '
          'Puedes copiar los datos y enviarlo manualmente desde Outlook.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: recipients));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Destinatarios copiados')),
              );
            },
            child: const Text('Copiar para'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: subject));
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Asunto copiado')));
            },
            child: const Text('Copiar asunto'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: body));
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Cuerpo copiado')));
            },
            child: const Text('Copiar cuerpo'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _openOutlook() async {
    final rawSubject = _subjectController.text;
    final rawBody = EmailTemplateService.composeBody(
      _bodyController.text,
      _commentsController.text,
    );
    if (_selectedRecipients.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un destinatario.')),
      );
      return;
    }

    final recipientsList = List<String>.from(_selectedRecipients);
    final recipients = recipientsList.join(',');

    final path = widget.attachmentPath;
    if (path != null && path.trim().isNotEmpty) {
      final file = File(path);
      if (await file.exists()) {
        try {
          await FlutterEmailSender.send(
            Email(
              recipients: recipientsList,
              subject: rawSubject,
              body: rawBody,
              attachmentPaths: [path],
            ),
          );
          if (mounted) {
            Navigator.of(context).pop(_buildDraftResult(sent: true));
          }
          return;
        } catch (e) {
          debugPrint('⚠️ Error abriendo correo con adjunto: $e');
          // Fall through to mailto
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se encontro el PDF local. Se abrira correo sin adjunto.',
            ),
          ),
        );
      }
    }

    // Fallback mailto robusto (ver EmailTemplateService.buildMailtoUri):
    // destinatarios en to + cc, y asunto/cuerpo acotados para que Outlook no
    // descarte los parámetros por URI demasiado larga.
    final uri = EmailTemplateService.buildMailtoUri(
      recipients: recipientsList,
      subject: rawSubject,
      body: rawBody,
    );

    final opened =
        await launchUrl(uri, mode: LaunchMode.externalApplication) ||
        await launchUrl(uri, mode: LaunchMode.platformDefault);

    if (!opened) {
      await _showManualFallback(recipients, rawSubject, rawBody);
      return;
    }

    if (mounted) {
      Navigator.of(context).pop(_buildDraftResult(sent: true));
    }
  }

  Map<String, dynamic> _buildDraftResult({required bool sent}) {
    return {
      'sent': sent,
      'subject': _subjectController.text.trim(),
      'body': _bodyController.text,
      'comments': _commentsController.text,
      'recipients': List<String>.from(_selectedRecipients),
      'attachment_path': widget.attachmentPath,
    };
  }

  void _closeWithPassiveSave() {
    Navigator.of(context).pop(_buildDraftResult(sent: false));
  }

  Future<void> _showMailAppHelp() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar por Outlook o Gmail'),
        content: const Text(
          'Si, Gmail funciona.\n\n'
          'Al enviar, se abrira el selector del sistema para que elijas '
          'la app de correo (por ejemplo Outlook o Gmail).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title, {Widget? trailing}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: _cMuted,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _paperCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      decoration: BoxDecoration(
        color: _cCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cLine),
      ),
      padding: padding ?? const EdgeInsets.all(14),
      child: child,
    );
  }

  InputDecoration _manualEmailDecoration() {
    return InputDecoration(
      hintText: 'nombre@empresa.com',
      hintStyle: const TextStyle(color: Color(0xFF9A9384), fontSize: 13.5),
      filled: true,
      fillColor: const Color(0xFFFBFAF6),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _cLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _cLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _cAmber, width: 1.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = SafeAreaUtils.safeBottomInset(context, extra: 8);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _closeWithPassiveSave();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEAE6DA),
        appBar: AppBar(
          backgroundColor: _cNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 72,
          leadingWidth: 56,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: IconButton(
              onPressed: _closeWithPassiveSave,
              icon: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.arrow_back, size: 18),
              ),
            ),
          ),
          titleSpacing: 0,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preparar correo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 1),
              Text(
                'Envio de registro · paso 3 de 3',
                style: TextStyle(fontSize: 11, color: Color(0xFFB9C6DC)),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Ayuda',
              onPressed: _showMailAppHelp,
              icon: const Icon(Icons.help_outline),
            ),
            const SizedBox(width: 6),
          ],
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_cNavy2, _cNavy],
              ),
            ),
          ),
        ),
        body: DismissKeyboardOnTap(
          child: Container(
            color: _cPaper,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _cAmber,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: Color(0x59FFFFFF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.forklift,
                          color: _cAmberInk,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LISTA DE VERIFICACION',
                              style: TextStyle(
                                fontSize: 10,
                                color: _cAmberInk,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.9,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Grua horquilla · patio',
                              style: TextStyle(
                                fontSize: 14.5,
                                color: Color(0xFF3A2503),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 8),
                            Wrap(
                              spacing: 14,
                              runSpacing: 4,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 12,
                                      color: Color(0xFF5B3A08),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Registro actual',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF5B3A08),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      size: 12,
                                      color: Color(0xFF5B3A08),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Supervisor',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF5B3A08),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                    children: [
                      _sectionLabel(
                        'DESTINATARIOS',
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _cLine,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_selectedRecipients.length}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: _cInk,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selectedRecipients
                                .map(
                                  (email) => Container(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      6,
                                      8,
                                      6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _cGreenBg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFC5E1D2),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 18,
                                          height: 18,
                                          decoration: const BoxDecoration(
                                            color: _cGreen,
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            _initialFromEmail(email),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 7),
                                        ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth:
                                                MediaQuery.sizeOf(
                                                  context,
                                                ).width *
                                                0.46,
                                          ),
                                          child: Text(
                                            email,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: _cGreen,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        InkWell(
                                          onTap: () => _removeRecipient(email),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: const Padding(
                                            padding: EdgeInsets.all(2),
                                            child: Icon(
                                              Icons.close,
                                              size: 14,
                                              color: _cGreen,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 10),
                          if (_selectedRecipients.isEmpty)
                            OutlinedButton.icon(
                              onPressed: _reAddSuggested,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: _cLine),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                foregroundColor: _cNavy2,
                              ),
                              icon: const Icon(
                                Icons.person_add_alt_1,
                                size: 16,
                              ),
                              label: const Text(
                                'Reagregar sugerido',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _manualRecipientCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.done,
                                  cursorColor: _cNavy2,
                                  onSubmitted: (_) {
                                    _addRecipient(_manualRecipientCtrl.text);
                                    _manualRecipientCtrl.clear();
                                  },
                                  decoration: _manualEmailDecoration(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 42,
                                child: ElevatedButton(
                                  onPressed: () {
                                    _addRecipient(_manualRecipientCtrl.text);
                                    _manualRecipientCtrl.clear();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _cNavy,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Agregar',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _paperCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ASUNTO',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                                color: _cMuted,
                              ),
                            ),
                            TextField(
                              controller: _subjectController,
                              minLines: 1,
                              maxLines: 3,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: _cInk,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.only(top: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _paperCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CUERPO',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                                color: _cMuted,
                              ),
                            ),
                            TextField(
                              controller: _bodyController,
                              maxLines: 9,
                              style: const TextStyle(
                                fontSize: 13.5,
                                height: 1.65,
                                color: _cInk,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.only(top: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _paperCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'OBSERVACIONES ADICIONALES',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                                color: _cMuted,
                              ),
                            ),
                            TextField(
                              controller: _commentsController,
                              maxLines: 3,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _cInk,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Agregar un comentario opcional...',
                                hintStyle: TextStyle(
                                  color: Color(0xFF9A9384),
                                  fontSize: 13,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.only(top: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (widget.attachmentName != null ||
                          (widget.attachmentPath ?? '').isNotEmpty)
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBFAF6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _cLine),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _cNavy,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.attach_file,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.attachmentName ?? 'adjunto.pdf',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: _cInk,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'PDF · adjunto',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _cMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.check, color: _cGreen, size: 18),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: _cPaper,
            border: Border(top: BorderSide(color: _cLine)),
          ),
          padding: EdgeInsets.fromLTRB(18, 14, 18, bottomInset + 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openOutlook,
                  icon: const Icon(Icons.mail_outline, size: 18),
                  label: const Text(
                    'Abrir en Outlook',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cNavy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Se abrira tu app de correo con todo listo para enviar',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: _cMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
