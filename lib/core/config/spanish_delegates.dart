// lib/config/spanish_delegates.dart
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:wechat_camera_picker/wechat_camera_picker.dart';

/// Traducciones forzadas al Español para la CÁMARA
class SpanishCameraPickerTextDelegate extends CameraPickerTextDelegate {
  const SpanishCameraPickerTextDelegate();

  @override
  String get languageCode => 'es';

  @override
  String get confirm => 'Confirmar';

  @override
  String get shootingTips => 'Toca para foto';

  @override
  String get loadFailed => 'Error';

  // --- AQUÍ ESTÁ LA SOLUCIÓN DEL TEXTO CHINO ---
  @override
  String get loading => 'Guardando...';

  @override
  String get saving => 'Guardando...';
  // ---------------------------------------------
}

/// Traducciones forzadas al Español para la GALERÍA
class SpanishAssetPickerTextDelegate extends AssetPickerTextDelegate {
  const SpanishAssetPickerTextDelegate();

  @override
  String get languageCode => 'es';

  @override
  String get confirm => 'Confirmar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get edit => 'Editar';

  @override
  String get gifIndicator => 'GIF';

  @override
  String get loadFailed => 'Error al cargar';

  @override
  String get original => 'Original';

  @override
  String get preview => 'Vista previa';

  @override
  String get select => 'Seleccionar';

  @override
  String get emptyList => 'Lista vacía';

  @override
  String get unSupportedAssetType => 'Tipo no soportado';

  @override
  String get unableToAccessAll => 'Sin acceso a todo';

  @override
  String get viewingLimitedAssetsTip => 'Vista limitada';
}
