# Recordatorio: iPhone y acceso por navegador

## 1) Objetivo inmediato
Tener la app disponible para usuarios de iPhone de la forma mas simple posible.

## 2) Recordatorio importante
Si queremos experiencia nativa en iPhone, el camino formal es:
- Build iOS
- Publicar con TestFlight/App Store

Como alternativa rapida para uso inmediato, se puede abrir en navegador (Safari/Chrome) usando Flutter Web.

## 3) Plan MVP recomendado (web para iPhone)
1. Levantar la app en web localmente.
2. Corregir detalles visuales o de flujo que cambien en navegador.
3. Publicar la version web (por ejemplo en Firebase Hosting).
4. Compartir URL al equipo de iPhone.
5. Opcional: agregar al inicio de iPhone desde Safari ("Agregar a pantalla de inicio").

## 4) Comandos utiles
Desde la raiz del proyecto:

```bash
flutter devices
flutter run -d chrome
```

Para build web:

```bash
flutter build web --release
```

## 5) Publicacion rapida en Firebase Hosting (si aplica)
Si ya esta configurado en este repo:

```bash
firebase deploy --only hosting
```

## 6) Checklist antes de compartir URL
- Login funciona en Safari iPhone.
- Formularios principales funcionan en movil.
- Archivos/camara: validar comportamiento en iOS web.
- Rendimiento aceptable en red movil.

## 7) Decision de producto
- Corto plazo: web para adopcion rapida en iPhone.
- Mediano plazo: version iOS nativa para mejor UX y capacidades del dispositivo.
