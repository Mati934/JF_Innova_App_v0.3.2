# Preparacion iPhone: handoff a Mac

Este archivo deja el proyecto listo para el dia en que haya acceso a un Mac.

## Estado actual del repo

- El proyecto Flutter ya incluye carpeta iOS.
- El target minimo actual de iOS es 13.0.
- Firebase esta inicializado en la app y usa `firebase_options.dart`.
- El bundle identifier actual sigue generico: `com.example.jfInnovaApp`.
- Ya quedaron agregados permisos base de iOS para camara y galeria en `ios/Runner/Info.plist`.
- Falta incorporar el archivo `GoogleService-Info.plist` real para iOS.

## Lo que debes decidir antes de tocar Xcode

1. Bundle identifier definitivo.
2. Nombre comercial visible en App Store.
3. Si usaras el mismo proyecto Firebase actual para iOS.
4. Si el despliegue inicial sera interno por TestFlight o publicacion completa.

## Recomendacion de bundle identifier

Usar uno estable y no generico, por ejemplo:

- `cl.jfinnova.app`
- `com.jfinnova.app`
- `cl.tuempresa.jfinnova`

Una vez elegido, no conviene cambiarlo sin necesidad.

## Como pasar el proyecto de Windows al Mac

La forma correcta es usar Git. No copies carpetas `build/` ni dependencias temporales.

### En Windows

1. Confirmar que todo esta guardado y funcionando en la rama actual.
2. Subir cambios a GitHub.

Comandos tipicos:

```bash
git status
git add .
git commit -m "Preparacion iOS para handoff a Mac"
git push origin copilot/vscode-mn1xwz2a-sr6r
```

### En el Mac

1. Clonar el repo o hacer `git pull` sobre la rama correcta.
2. Instalar Flutter, Xcode y CocoaPods.
3. Ejecutar desde la raiz:

```bash
flutter clean
flutter pub get
cd ios
pod install
cd ..
flutter doctor
```

## Checklist exacto al abrir el proyecto en Mac

1. Abrir `ios/Runner.xcworkspace` en Xcode, no `Runner.xcodeproj`.
2. Iniciar sesion con el Apple ID developer en Xcode.
3. En `Signing & Capabilities`, seleccionar tu Team.
4. Cambiar el Bundle Identifier del target `Runner` al definitivo.
5. Repetir el cambio si corresponde en configuraciones Debug, Release y Profile.
6. Confirmar que el identificador coincide exactamente con Apple Developer y Firebase.

## Firebase iOS

Como el proyecto ya usa Firebase, al crear la app iOS se debe sincronizar esa configuracion.

1. Entrar a Firebase Console.
2. Registrar una app iOS en el proyecto `jf-innova-app`.
3. Usar el mismo bundle identifier definido en Xcode.
4. Descargar `GoogleService-Info.plist`.
5. Agregarlo en `ios/Runner/` mediante Xcode.
6. Verificar que quede incluido en el target `Runner`.

Si cambias el bundle identifier, tambien debes regenerar `lib/firebase_options.dart` con FlutterFire CLI para dejar Android/iOS alineados.

Comando esperado en el Mac si ya tienes FlutterFire CLI:

```bash
flutterfire configure
```

## Prueba minima obligatoria en iPhone fisico

Antes de pensar en publicar, validar esto en un iPhone real:

1. La app abre sin crash.
2. Login funciona.
3. Sincronizacion con Supabase funciona.
4. Camara toma fotos.
5. Galeria permite seleccionar imagenes.
6. Generacion o visualizacion de PDF no revienta en iOS.
7. Compartir archivos funciona.

## Riesgos conocidos a revisar en el Mac

1. `camera`, `wechat_assets_picker`, `wechat_camera_picker`, `printing`, `share_plus` y Firebase deben compilar bien con los pods de iOS.
2. Si aparece error de firma, normalmente es Team, Bundle ID o capability inconsistente.
3. Si Firebase no inicia, casi siempre falta o no coincide `GoogleService-Info.plist`.
4. Si camara o galeria no abren, revisar permisos en `Info.plist` y autorizaciones del dispositivo.

## Publicacion sin contratar nube

No necesitas contratar ningun servicio cloud extra para publicar en iPhone si ya tienes:

- Cuenta Apple Developer.
- Un Mac con Xcode.
- Acceso al repo.

El flujo es local en el Mac:

1. Build desde Xcode o Flutter.
2. Firma con tu cuenta Apple.
3. Archive en Xcode.
4. Envio a App Store Connect.
5. Distribucion por TestFlight o App Store.

## Pendientes tecnicos del repo

- Definir bundle identifier final.
- Agregar `GoogleService-Info.plist` real de iOS.
- Regenerar `lib/firebase_options.dart` si cambia el bundle identifier.
- Probar en iPhone fisico.

## Regla operativa recomendada

Usar GitHub como fuente de verdad entre Windows y Mac.

- Windows: desarrollo diario.
- Mac: compilacion iOS, firma, pruebas fisicas y publicacion.

Evita transferir el proyecto por pendrive o zip salvo emergencia. Git te evita perder cambios y deja trazabilidad clara.