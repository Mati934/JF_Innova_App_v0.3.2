// Tests del cierre de turno (PLAN_TURNO.md §11).
//
// Reglas verificadas:
// 1. Folios: primer y último número por tipo, con cantidad (AST desde el
//    correlativo "AST-2026-0655").
// 2. Indicadores: centros distintos, inspecciones por tipo, observaciones =
//    ítems de tickets de las inspecciones del turno, faenas SUSPENDIDA.
// 3. Por centro y por informe: observaciones cerradas (ítem subsanado o
//    ticket cerrado) y pendientes; EPP y Cil. quedan en blanco.
// 4. Tickets del profesional: creó / cerró (envió a revisión y hoy está
//    cerrado) y estado actual, como el dashboard.
// 5. Hallazgos sin duplicar; directorio con contactos guardados o, si no hay,
//    supervisor y correo de las inspecciones.
// 6. Fila SQLite ↔ modelo y payload de Supabase (secciones como listas).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jf_innova_app/features/turno/domain/turno_cierre.dart';
import 'package:jf_innova_app/features/turno/domain/turno_cierre_calculo.dart';
import 'package:jf_innova_app/features/turno/services/turno_cierre_pdf_service.dart';
import 'package:jf_innova_app/features/turno/services/turno_cierre_service.dart';

DateTime d(int m, int day) => DateTime(2026, m, day);

ActividadFuente act(
  String id,
  String tipo,
  int n,
  DateTime f, {
  String centro = 'CANALAD 1',
  String? empresa,
  String? faena,
  String? supervisor,
  String? correo,
}) => ActividadFuente(
  id: id,
  tipo: tipo,
  numero: n,
  fecha: f,
  centro: centro,
  empresa: empresa,
  estadoFaena: faena,
  supervisor: supervisor,
  correo: correo,
);

TicketFuente tk(
  String id,
  String insp,
  String tipo,
  String estado, {
  int items = 1,
  int cerrados = 0,
}) => TicketFuente(
  id: id,
  inspeccionId: insp,
  tipoInspeccion: tipo,
  estado: estado,
  items: items,
  itemsCerrados: cerrados,
);

void main() {
  const buceo = TipoActividad.buceo;
  const emb = TipoActividad.embarcacion;
  const form = TipoActividad.formativa;

  // Turno 28/10–09/11 en Cisnes (como el PDF de muestra).
  final fuentes = FuentesCierre(
    actividades: [
      act(
        'e77',
        emb,
        77,
        d(10, 28),
        empresa: 'MARIANA ARENAS CORTES',
        correo: 'contacto@ejemplo.cl',
      ),
      act('f3', form, 3, d(10, 29)),
      act(
        'b721',
        buceo,
        721,
        d(10, 30),
        empresa: 'REDMAR',
        supervisor: 'Sup A',
      ),
      act(
        'b723',
        buceo,
        723,
        d(10, 31),
        empresa: 'REDMAR',
        faena: 'SUSPENDIDA',
      ),
      act('f5', form, 5, d(11, 3)),
      act(
        'b745',
        buceo,
        745,
        d(11, 6),
        centro: 'CANALAD 4',
        empresa: 'PUERTO RED',
      ),
    ],
    asts: [
      AstFuente(
        id: 'a1',
        numero: 655,
        fecha: d(10, 29),
        centro: 'CANALAD 1',
        empresa: 'MARIANA ARENAS CORTES',
      ),
      AstFuente(
        id: 'a2',
        numero: 664,
        fecha: d(11, 2),
        centro: 'CANALAD 1',
        empresa: 'REDMAR',
      ),
    ],
    ticketsInformes: [
      tk('t1', 'e77', emb, 'ABIERTO', items: 11),
      tk('t2', 'b721', buceo, 'CERRADO'),
      tk('t3', 'b721', buceo, 'ABIERTO'),
      tk('t4', 'b745', buceo, 'PARCIAL', items: 4, cerrados: 3),
    ],
    ticketsCreados: [
      const TicketFuente(id: 'x1', estado: 'ABIERTO'),
      const TicketFuente(id: 'x2', estado: 'CERRADO'),
    ],
    ticketsFinalizados: [
      const TicketFuente(id: 'x2', estado: 'CERRADO'),
      const TicketFuente(id: 'x3', estado: 'CERRADO'),
      // Enviado a revisión pero rechazado/aún no cerrado: no cuenta como cerrado.
      const TicketFuente(id: 'x4', estado: 'FINALIZADO_PENDIENTE_REVISION'),
    ],
    aCargo: 2,
    hallazgos: const [
      HallazgoFuente(
        id: 'h1',
        descripcion: 'Sin protección respiratoria',
        criticidad: 'Intolerable',
        categoria: 'AST',
        estado: 'ABIERTO',
      ),
      HallazgoFuente(
        id: 'h1',
        descripcion: 'duplicado',
        criticidad: 'Intolerable',
      ),
    ],
    contactos: const [
      ContactoFuente(
        empresa: 'redmar',
        actividad: 'Apertura de centro',
        supervisor: 'Guardado',
        fono: '+56 9 1111 1111',
      ),
    ],
  );

  final r = CierreCalculo.calcular(fuentes);

  test('folios por tipo con cantidad', () {
    final f = r.filas['folios']!;
    expect(f.map((e) => e['tipo']), [
      'Reportes de buceo',
      'Insp. embarcaciones',
      'Reportes AST',
      'Act. formativas',
    ]);
    expect(f[0], containsPair('inicial', '721'));
    expect(f[0], containsPair('final', '745'));
    expect(f[0], containsPair('cantidad', '3'));
    expect(f[2]['inicial'], '655');
    expect(f[2]['final'], '664');
    expect(f[3]['cantidad'], '2');
  });

  test('indicadores', () {
    final n = r.numeros;
    expect(n['n_centros'], 2);
    expect(n['n_insp_buceo'], 3);
    expect(n['n_ast'], 2);
    expect(n['n_insp_emb'], 1);
    expect(n['n_reg_act'], 2);
    expect(n['n_obs_buceo'], 6);
    expect(n['n_obs_emb'], 11);
    expect(n['n_faenas_suspendidas'], 1);
  });

  test('por centro, por informe y suspensiones', () {
    final c = r.filas['centros']!;
    expect(c.map((e) => e['centro']), ['CANALAD 1', 'CANALAD 4']);
    // Canalad 1: emb 11 abiertas + buceo 721 (1 cerrada por ticket + 1 abierta).
    expect(c[0], containsPair('buceo', '2'));
    expect(c[0], containsPair('reg', '2'));
    expect(c[0], containsPair('ast', '2'));
    expect(c[0], containsPair('obs_tot', '13'));
    expect(c[0], containsPair('obs_cerr', '1'));
    expect(c[0], containsPair('obs_pen', '12'));
    expect(c[0]['epp'], '');
    expect(c[1], containsPair('obs_cerr', '3'));

    final inf = r.filas['informes_pendientes']!;
    expect(inf.map((e) => e['numero']), ['77', '721', '745']);
    expect(inf.first['tipo'], 'Embarcación (MARIANA ARENAS CORTES)');
    expect(inf[1], containsPair('pendientes', '1'));

    final s = r.filas['suspensiones']!.single;
    expect(s['empresa'], 'REDMAR');
    expect(s['fecha'], '31/10/2026');
    expect(r.filas['puertos_cerrados'], isEmpty);
  });

  test('tickets del profesional como el dashboard', () {
    final n = r.numeros;
    expect(n['tk_creados'], 2);
    expect(n['tk_cerrados'], 2); // x2 y x3 (x4 no está cerrado)
    expect(n['tk_solo_creo'], 1);
    expect(n['tk_creo_y_cerro'], 1);
    expect(n['tk_solo_cerro'], 1);
    expect(n['tk_abiertos'], 1);
    expect(n['tk_estado_cerrados'], 2);
    expect(n['tk_a_cargo'], 2);
  });

  test('hallazgos sin duplicar y directorio', () {
    final h = r.filas['hallazgos']!.single;
    expect(h['estado'], 'Pendiente');
    final s = r.filas['servicios']!;
    expect(s.map((e) => e['empresa']), [
      'MARIANA ARENAS CORTES',
      'PUERTO RED',
      'REDMAR',
    ]);
    expect(s[0]['correo'], 'contacto@ejemplo.cl');
    // El contacto guardado manda sobre el supervisor de la inspección.
    expect(s[2]['supervisor'], 'Guardado');
    expect(s[2]['fono'], '+56 9 1111 1111');
  });

  test('fila SQLite y payload de Supabase', () {
    final c = TurnoCierre(
      id: 'c1',
      turnoId: 't1',
      usuarioId: 'u1',
      empresaId: 'e1',
      areaId: 'a1',
      desde: d(10, 28),
      hasta: d(11, 9),
      estado: CierreEstado.borrador,
      numeros: r.numeros,
      filas: r.filas,
      bitacora: 'Nota',
      pdfUrl: null,
      pdfVersion: null,
      pdfGeneradoAt: null,
      pdfPathLocal: '/x.pdf',
      appVersion: 'v1',
      createdAt: DateTime(2026, 11, 9),
      updatedAt: DateTime(2026, 11, 9),
    );
    final row = {...c.toRow(), 'subido': 0, 'eliminado': 0};
    final back = TurnoCierre.fromRow(row);
    expect(back.desde, d(10, 28));
    expect(back.numeros['n_obs_emb'], 11);
    expect(back.filasDe('folios').length, 4);
    expect(back.bitacora, 'Nota');

    final p = cierrePayloadSupabase(row);
    expect(p.containsKey('subido'), isFalse);
    expect(p.containsKey('pdf_path_local'), isFalse);
    expect(p['folios'], isA<List>());
    expect((p['folios'] as List).first['inicial'], '721');

    final local = cierreRowDesdeSupabase(p);
    expect(local['subido'], 1);
    expect(TurnoCierre.filasDesde(local['centros']).length, 2);
  });

  test('genera el PDF (y lo guarda si TURNO_PDF_OUT está definido)', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final c = TurnoCierre(
      id: 'c1',
      turnoId: 't1',
      usuarioId: 'u1',
      empresaId: 'e1',
      areaId: 'a1',
      desde: d(10, 28),
      hasta: d(11, 9),
      estado: CierreEstado.borrador,
      numeros: r.numeros,
      filas: {
        ...r.filas,
        'puertos_cerrados': [
          {
            'area': 'Cisnes',
            'centro': 'Canalad 1',
            'fecha': '01/11/2026 al 04/11/2026',
            'motivo': 'Puerto cerrado',
          },
        ],
      },
      bitacora:
          'Programación de ingreso según indicaciones de operaciones.\n'
          'OOPP de turno: contacto por correo de entrega de turno.',
      pdfUrl: null,
      pdfVersion: null,
      pdfGeneradoAt: null,
      pdfPathLocal: null,
      appVersion: 'v1',
      createdAt: DateTime(2026, 11, 9),
      updatedAt: DateTime(2026, 11, 9),
    );
    final bytes = await const TurnoCierrePdfService().generar(
      TurnoCierrePdfData(
        cierre: c,
        profesional: 'Profesional de prueba',
        area: 'Puerto Cisnes',
      ),
    );
    expect(bytes.length, greaterThan(1000));
    final out = Platform.environment['TURNO_PDF_OUT'];
    if (out != null) await File(out).writeAsBytes(bytes);
  });
}
