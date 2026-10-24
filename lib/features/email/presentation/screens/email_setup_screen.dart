import 'package:flutter/material.dart';
import '../../services/email_config_service.dart';
import '../../services/email_template_service.dart';
import 'email_preview_screen.dart';

class EmailSetupScreen extends StatefulWidget {
  const EmailSetupScreen({super.key});

  @override
  State<EmailSetupScreen> createState() => _EmailSetupScreenState();
}

class _EmailSetupScreenState extends State<EmailSetupScreen> {
  bool _isLoading = false;

  Future<void> _seedAndOpenPreview() async {
    setState(() => _isLoading = true);
    try {
      final seeded = await EmailConfigService().seedCaseBase();
      if (!mounted) return;

      if (!seeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ya existen configuraciones de correo. No se cargo el caso demo para evitar sobrescrituras.',
            ),
          ),
        );
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EmailPreviewScreen(
            initialSubject:
                'Lista de verificación de grúa horquilla patio fiordo austra - 2026-07-29',
            initialBody: EmailTemplateService.renderTemplate(
              '''Buenos días / buenas tardes,\n\nSe adjunta la lista de verificación correspondiente al registro realizado el día {{fecha_inspeccion}} a las {{hora_inspeccion}}.\nRealizado por: {{supervisor_nombre}}\n\nSaludos cordiales,\n{{supervisor_nombre}}''',
              {
                'fecha_inspeccion': '2026-07-29',
                'hora_inspeccion': '08:30',
                'supervisor_nombre': 'Supervisor',
              },
            ),
            recipients: const ['matipro934@gmail.com'],
            attachmentName: 'lista_verificacion_grua_horquilla.pdf',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Caso de prueba correo')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preparación del caso base de correo',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Este flujo crea una plantilla base, una lista de prueba y la configuración inicial para el módulo Hidroser.',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isLoading ? null : _seedAndOpenPreview,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(
                _isLoading ? 'Preparando...' : 'Crear caso de prueba',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
