import 'package:flutter/material.dart';
import '../controllers/tickets_controller.dart';

class CrearTicketScreen extends StatefulWidget {
  final TicketsController controller;

  const CrearTicketScreen({super.key, required this.controller});

  @override
  State<CrearTicketScreen> createState() => _CrearTicketScreenState();
}

class _CrearTicketScreenState extends State<CrearTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _prioridad = 'Media';
  bool _guardando = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Ticket')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Título
              TextFormField(
                controller: _tituloCtrl,
                decoration: const InputDecoration(
                  labelText: 'Título *',
                  hintText: 'Describe brevemente el problema',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                maxLength: 100,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'El título es obligatorio' : null,
              ),

              const SizedBox(height: 16),

              // Descripción
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Detalla el problema o solicitud',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                maxLength: 500,
              ),

              const SizedBox(height: 16),

              // Prioridad
              DropdownButtonFormField<String>(
                value: _prioridad,
                decoration: const InputDecoration(
                  labelText: 'Prioridad',
                  prefixIcon: Icon(Icons.flag),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Baja', child: Text('🟢  Baja')),
                  DropdownMenuItem(value: 'Media', child: Text('🟡  Media')),
                  DropdownMenuItem(value: 'Alta', child: Text('🔴  Alta')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _prioridad = v);
                },
              ),

              const SizedBox(height: 32),

              // Botón Guardar
              ElevatedButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
                label: const Text('Enviar Ticket'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    final ok = await widget.controller.crearTicket(
      titulo: _tituloCtrl.text.trim(),
      descripcion: _descCtrl.text.trim(),
      prioridad: _prioridad,
    );

    if (!mounted) return;

    setState(() => _guardando = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Ticket creado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              widget.controller.errorMessage ?? 'Error al crear el ticket'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
