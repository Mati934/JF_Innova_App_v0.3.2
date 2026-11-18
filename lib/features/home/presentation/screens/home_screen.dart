import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:jf_innova_app/core/theme/app_theme.dart';
import 'package:jf_innova_app/core/services/user_session.dart';
import 'package:jf_innova_app/core/modules/module_registry.dart';
import 'package:jf_innova_app/core/errors/app_error_utils.dart';
import 'package:jf_innova_app/shared/branding/app_logo.dart';
import 'package:jf_innova_app/features/tickets/presentation/widgets/ticket_header_badge_button.dart';
import '../controllers/home_controller.dart';
import '../widgets/draft_list_widget.dart';
import '../widgets/module_selector_grid.dart';
import '../../../sync/presentation/screens/sync_pending_screen.dart';
import '../../../auth/presentation/screens/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HomeController _controller = HomeController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<String> _getVersion() async {
    final info = await PackageInfo.fromPlatform();
    return "v${info.version} (b${info.buildNumber})";
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        final empresaNombre = UserSession().empresaNombre;
        final cantidadBorradores = _controller.borradores.length;
        final pendientesSync = _controller.pendingSyncCount;

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6F8),
          body: RefreshIndicator(
            color: AppTheme.primaryBlue,
            onRefresh: () async {
              await _controller.cargarBorradores();
              await _controller.recargarPendientesSync();
              await _controller.recargarModulos();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _buildHeader(empresaNombre, cantidadBorradores),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_controller.isSyncing) _buildSyncBanner(),
                        _SectionHeader(
                          title: 'Operaciones',
                          subtitle: 'Selecciona el módulo a utilizar',
                          icon: Icons.dashboard_rounded,
                        ),
                        const SizedBox(height: 14),
                        ModuleSelectorGrid(
                          // Tickets no se muestra como tarjeta cuadrada: tiene su
                          // propia viñeta de notificación en el header (ver
                          // TicketHeaderBadgeButton) aunque siga siendo un módulo
                          // más para efectos de permisos/activación por empresa.
                          modules: _controller.enabledModules
                              .where((m) => m.moduleKey != 'TICKETS')
                              .toList(),
                          onModuleTap: _onModuleTap,
                        ),
                        const SizedBox(height: 32),
                        _SectionHeader(
                          title: 'Pendientes',
                          subtitle: cantidadBorradores == 0
                              ? 'Sin borradores en curso'
                              : '$cantidadBorradores ${cantidadBorradores == 1 ? "borrador" : "borradores"} por completar',
                          icon: Icons.assignment_outlined,
                          trailing: cantidadBorradores > 0
                              ? _CountBadge(count: cantidadBorradores)
                              : null,
                        ),
                        const SizedBox(height: 8),
                        _SyncPendingQuickAction(
                          pendientesSync: pendientesSync,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SyncPendingScreen(),
                              ),
                            );
                            await _controller.recargarPendientesSync();
                            await _controller.cargarBorradores();
                          },
                        ),
                        const SizedBox(height: 10),
                        DraftListWidget(controller: _controller),
                        const SizedBox(height: 24),
                        Center(
                          child: FutureBuilder<String>(
                            future: _getVersion(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return const SizedBox();
                              return Text(
                                snapshot.data!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onModuleTap(ModuleDefinition mod) {
    if (mod.isPlaceholder) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Próximamente...")));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: mod.screenBuilder)).then(
      (_) {
        _controller.cargarBorradores();
        _controller.recargarModulos();
      },
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER (Sliver con gradiente + saludo + acciones)
  // ---------------------------------------------------------------------------
  Widget _buildHeader(String? empresaNombre, int cantidadBorradores) {
    final correoHabilitado = _controller.enabledModules.any(
      (m) => m.moduleKey == 'EMAIL_OUTBOX',
    );
    final pillCount = 2 + (correoHabilitado ? 1 : 0);
    final anchoPantalla = MediaQuery.of(context).size.width;
    final pillsPorFilaEstimado = anchoPantalla < 380 ? 2 : 3;
    final pillRows = (pillCount / pillsPorFilaEstimado).ceil().clamp(1, 3);
    final expandedHeight = 220.0 + ((pillRows - 1) * 34.0);

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      stretch: true,
      backgroundColor: AppTheme.primaryBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryBlue,
                const Color(0xFF002244),
                AppTheme.logoGrey.withValues(alpha: 0.85),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Hero(
                        tag: 'logo_app',
                        child: Image.asset(
                          AppLogo.pathForCurrentEmpresa(),
                          height: 40,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.verified_user,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Panel de Control',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      _buildActionButtons(),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'Hola,',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _controller.nombreUsuario,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (empresaNombre != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.business,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            empresaNombre,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoPill(
                        icon: _controller.isOnline
                            ? Icons.cloud_done
                            : Icons.cloud_off,
                        label: _controller.isOnline ? 'Online' : 'Offline',
                        tone: _controller.isOnline
                            ? Colors.green.shade600
                            : Colors.orange.shade700,
                      ),
                      if (correoHabilitado)
                        _InfoPill(
                          icon: Icons.assignment_late_outlined,
                          label: cantidadBorradores == 1
                              ? '1 borrador'
                              : '$cantidadBorradores borradores',
                          tone: Colors.blue.shade700,
                        ),
                      _InfoPill(
                        icon: Icons.cloud_upload_outlined,
                        label: _controller.pendingSyncCount == 1
                            ? '1 por subir'
                            : '${_controller.pendingSyncCount} por subir',
                        tone: _controller.pendingSyncCount > 0
                            ? Colors.orange.shade700
                            : Colors.green.shade700,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final ticketsHabilitado = _controller.enabledModules.any(
      (m) => m.moduleKey == 'TICKETS',
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ticketsHabilitado) ...[
          const TicketHeaderBadgeButton(),
          const SizedBox(width: 6),
        ],
        if (!_controller.isOnline)
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'Offline',
                  style: TextStyle(fontSize: 11, color: Colors.white),
                ),
              ],
            ),
          ),
        _HeaderIconButton(
          icon: _controller.isSyncing ? null : Icons.sync,
          loading: _controller.isSyncing,
          tooltip: 'Sincronizar ahora',
          onPressed: _controller.isSyncing
              ? null
              : () async {
                  await _controller.ejecutarSincronizacion();
                  if (mounted && _controller.syncMessage != null) {
                    if (_controller.isError) {
                      final code =
                          _controller.syncErrorCode ??
                          AppErrorUtils.newCode(scope: 'SNC');
                      ScaffoldMessenger.of(context).showSnackBar(
                        AppErrorUtils.buildErrorSnackBar(
                          message: _controller.syncMessage!,
                          code: code,
                        ),
                      );
                    } else {
                      final esAdvertencia = _controller.syncMessage!.startsWith(
                        '⚠️',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_controller.syncMessage!),
                          backgroundColor: esAdvertencia
                              ? Colors.orange.shade700
                              : Colors.green.shade700,
                        ),
                      );
                    }
                  }
                },
        ),
        const SizedBox(width: 6),
        _HeaderIconButton(
          icon: Icons.logout,
          tooltip: 'Cerrar sesión',
          onPressed: () => _cerrarSesion(context),
        ),
      ],
    );
  }

  Widget _buildSyncBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            "Sincronizando datos...",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.orange.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('¿Cerrar Sesión?'),
          ],
        ),
        content: const Text(
          'Si cierras sesión, necesitarás internet para volver a entrar.\n\n'
          '⚠️ Si vas a terreno sin señal, NO cierres sesión, solo cierra la app.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      await _controller.cerrarSesion(context);
      if (!mounted) return;
      Navigator.pushReplacement(
        // ignore: use_build_context_synchronously
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }
}

class _SyncPendingQuickAction extends StatelessWidget {
  final int pendientesSync;
  final VoidCallback onTap;

  const _SyncPendingQuickAction({
    required this.pendientesSync,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  color: pendientesSync > 0
                      ? Colors.orange.shade700
                      : Colors.green.shade700,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    pendientesSync > 0
                        ? 'Ver pendientes de sincronización ($pendientesSync)'
                        : 'Ver estado de sincronización',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tone;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(color: tone.withValues(alpha: 0.45), blurRadius: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Helpers visuales (separación de responsabilidades — solo presentación)
// -----------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primaryBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.logoYellow.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.logoYellow.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.orange.shade900,
        ),
      ),
    );
  }
}

/// Botón de acción en el header con fondo translúcido para alto contraste
/// sobre el gradiente azul.
class _HeaderIconButton extends StatelessWidget {
  final IconData? icon;
  final bool loading;
  final String tooltip;
  final VoidCallback? onPressed;

  const _HeaderIconButton({
    required this.tooltip,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
