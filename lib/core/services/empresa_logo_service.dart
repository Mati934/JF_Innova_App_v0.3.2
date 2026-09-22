import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database_helper.dart';
import 'user_session.dart';

/// Resuelve y cachea el logo de una empresa para incrustarlo en los PDFs.
///
/// Estrategia:
/// 1. Lee `logo_url` desde la tabla local `empresas` (sincronizada con Supabase).
/// 2. Si hay URL: descarga (con caché en disco) y devuelve los bytes.
/// 3. Si no hay URL o la descarga falla: cae al asset por defecto del módulo.
///
/// El caché vive en `{appDocs}/empresa_logos/{empresa_id}` y se invalida
/// automáticamente cuando cambia la URL guardada en la BD.
class EmpresaLogoService {
  EmpresaLogoService._();
  static final EmpresaLogoService instance = EmpresaLogoService._();

  /// Caché en memoria por empresa (evita re-leer disco entre PDFs consecutivos).
  final Map<String, Uint8List> _memCache = {};

  /// Caché de bytes ya cargados de assets (para no releerlos en cada llamada).
  final Map<String, Uint8List> _assetCache = {};

  /// Devuelve los bytes del logo a usar para la empresa activa de la sesión.
  ///
  /// [fallbackAsset] es la ruta a un asset PNG del módulo a usar cuando no
  /// hay logo configurado o falla la descarga (ej: 'assets/images/logo.png').
  Future<Uint8List?> getLogoForActiveEmpresa({
    required String fallbackAsset,
  }) async {
    final session = UserSession();
    final empresaId = session.empresaId;
    final logoUrl = session.empresaLogoUrl;
    return _resolve(
      empresaId: empresaId,
      logoUrl: logoUrl,
      fallbackAsset: fallbackAsset,
    );
  }

  /// Versión explícita para módulos que conocen la empresa por contexto
  /// (ej: PDF diferido leyendo una actividad ya guardada).
  Future<Uint8List?> getLogoForEmpresa({
    required String? empresaId,
    required String fallbackAsset,
  }) async {
    String? logoUrl;
    if (empresaId != null) {
      try {
        final db = await DatabaseHelper.instance.database;
        final rows = await db.query(
          'empresas',
          columns: ['logo_url'],
          where: 'id = ?',
          whereArgs: [empresaId],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          logoUrl = rows.first['logo_url'] as String?;
        }
      } catch (e) {
        debugPrint('⚠️ EmpresaLogoService: error leyendo logo_url: $e');
      }
    }
    return _resolve(
      empresaId: empresaId,
      logoUrl: logoUrl,
      fallbackAsset: fallbackAsset,
    );
  }

  Future<Uint8List?> _resolve({
    required String? empresaId,
    required String? logoUrl,
    required String fallbackAsset,
  }) async {
    if (empresaId != null && logoUrl != null && logoUrl.trim().isNotEmpty) {
      final bytes = await _getOrDownload(empresaId, logoUrl.trim());
      if (bytes != null) return bytes;
    }
    return _loadAsset(fallbackAsset);
  }

  Future<Uint8List?> _getOrDownload(String empresaId, String url) async {
    // 1. Memoria
    final memKey = '$empresaId|$url';
    final cached = _memCache[memKey];
    if (cached != null) return cached;

    try {
      final dir = await _logoDir();
      final binFile = File(p.join(dir.path, empresaId));
      final urlFile = File(p.join(dir.path, '$empresaId.url'));

      // 2. Disco: usar caché si la URL no cambió
      if (await binFile.exists() && await urlFile.exists()) {
        final cachedUrl = (await urlFile.readAsString()).trim();
        if (cachedUrl == url) {
          final bytes = await binFile.readAsBytes();
          _memCache[memKey] = bytes;
          return bytes;
        }
      }

      // 3. Descargar
      final bytes = await _download(url);
      if (bytes == null) {
        // Si falla pero hay binario en disco, úsalo como fallback degradado.
        if (await binFile.exists()) {
          final stale = await binFile.readAsBytes();
          _memCache[memKey] = stale;
          return stale;
        }
        return null;
      }

      await binFile.writeAsBytes(bytes, flush: true);
      await urlFile.writeAsString(url, flush: true);
      _memCache[memKey] = bytes;
      return bytes;
    } catch (e) {
      debugPrint('⚠️ EmpresaLogoService: error obteniendo logo: $e');
      return null;
    }
  }

  Future<Uint8List?> _download(String url) async {
    HttpClient? client;
    try {
      final uri = Uri.parse(url);
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final req = await client.getUrl(uri);
      final resp = await req.close().timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        debugPrint(
          '⚠️ EmpresaLogoService: HTTP ${resp.statusCode} al descargar $url',
        );
        return null;
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in resp) {
        builder.add(chunk);
      }
      return builder.toBytes();
    } on TimeoutException {
      debugPrint('⚠️ EmpresaLogoService: timeout descargando $url');
      return null;
    } catch (e) {
      debugPrint('⚠️ EmpresaLogoService: error descargando $url: $e');
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  Future<Directory> _logoDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'empresa_logos'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Uint8List?> _loadAsset(String assetPath) async {
    final cached = _assetCache[assetPath];
    if (cached != null) return cached;
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      _assetCache[assetPath] = bytes;
      return bytes;
    } catch (e) {
      debugPrint(
        '⚠️ EmpresaLogoService: no se pudo cargar asset $assetPath: $e',
      );
      return null;
    }
  }

  /// Borra el caché en memoria (útil tras logout o cambio de empresa).
  void clearMemoryCache() {
    _memCache.clear();
  }
}
