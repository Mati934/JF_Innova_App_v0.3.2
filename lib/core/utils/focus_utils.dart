import 'package:flutter/material.dart';

class DismissKeyboardOnTap extends StatelessWidget {
  const DismissKeyboardOnTap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}

/// Suelta la caja de texto activa en toda la app (va en `MaterialApp.builder`).
///
/// - Al tocar fuera de la caja: en Android/iOS Flutter no la suelta por defecto
///   (solo en web y escritorio), así que había que cerrar la observación para salir.
/// - Al desplazar la pantalla con el dedo: si la caja sigue activa, al volver el
///   teclado (tras un diálogo, lista, cámara o fecha) Flutter desplaza la pantalla
///   de vuelta hasta ella.
class TextFieldFocusGuard extends StatelessWidget {
  const TextFieldFocusGuard({super.key, required this.child});

  final Widget child;

  bool _onScrollStart(ScrollStartNotification n) {
    // Solo arrastres del usuario; los desplazamientos automáticos (p. ej. para
    // mostrar la caja al abrir el teclado) no traen dragDetails.
    if (n.dragDetails == null) return false;
    // Scroll dentro de la caja (varias líneas) o de su lista de opciones
    // (Autocomplete): ambos están en un TextFieldTapRegion y no deben soltarla.
    if (n.context?.findAncestorWidgetOfExactType<TextFieldTapRegion>() !=
        null) {
      return false;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        EditableTextTapOutsideIntent:
            CallbackAction<EditableTextTapOutsideIntent>(
              onInvoke: (intent) {
                intent.focusNode.unfocus();
                return null;
              },
            ),
      },
      child: NotificationListener<ScrollStartNotification>(
        onNotification: _onScrollStart,
        child: child,
      ),
    );
  }
}
