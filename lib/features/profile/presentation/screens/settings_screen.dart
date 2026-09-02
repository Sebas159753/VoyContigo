import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voycontigo/core/theme/app_theme.dart';
import 'package:voycontigo/features/trips/presentation/providers/trip_provider.dart';

/// Configuración: solo opciones reales y funcionales.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  void _showEditProfileDialog() {
    final appState = ref.read(appStateProvider);
    final nameCtrl = TextEditingController(text: appState.userName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Perfil'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Nombre Completo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isNotEmpty) {
                await ref.read(appStateProvider.notifier).updateName(newName);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Perfil actualizado')));
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showEditVehicleDialog() {
    final appState = ref.read(appStateProvider);
    final modelCtrl = TextEditingController(text: appState.carModel);
    final plateCtrl = TextEditingController(text: appState.carPlate);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mi Vehículo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: modelCtrl,
              decoration: const InputDecoration(
                labelText: 'Modelo y color (ej. Kia Picanto Rojo)',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: plateCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Placa (Ecuador)',
                helperText: 'Ejemplo: PBA-1234 o ABC-123',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final newModel = modelCtrl.text.trim();
              final rawPlate = plateCtrl.text.trim().toUpperCase();

              if (newModel.isEmpty || newModel.length < 3) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Por favor, describe el modelo y color del vehículo')),
                );
                return;
              }

              // Auto-formatear y validar placa ecuatoriana (ej: PBA-1234 o ABC-123)
              String cleanPlate = rawPlate.replaceAll(RegExp(r'[^A-Z0-9]'), '');
              String formattedPlate = rawPlate;

              if (cleanPlate.length >= 6 && cleanPlate.length <= 7) {
                final letters = cleanPlate.substring(0, 3);
                final numbers = cleanPlate.substring(3);
                if (RegExp(r'^[A-Z]{3}$').hasMatch(letters) &&
                    RegExp(r'^\d{3,4}$').hasMatch(numbers)) {
                  formattedPlate = '$letters-$numbers';
                }
              }

              final plateRegex = RegExp(r'^[A-Z]{3}-\d{3,4}$');
              if (!plateRegex.hasMatch(formattedPlate)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Placa inválida. Debe tener el formato ecuatoriano (ej: PBA-1234 o ABC-123)')),
                );
                return;
              }

              await ref
                  .read(appStateProvider.notifier)
                  .updateVehicle(newModel, formattedPlate);

              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vehículo actualizado')));
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showSimpleDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(content,
              style: AppTheme.bodyFont(
                  color: AppTheme.ink, fontSize: 14, height: 1.45)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationsEnabled =
        ref.watch(appStateProvider.select((s) => s.notificationsEnabled));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionTitle('Cuenta'),
          _buildSettingsTile(Icons.person_outline, 'Editar Perfil',
              onTap: _showEditProfileDialog),
          _buildSettingsTile(Icons.directions_car_outlined, 'Mi Vehículo',
              onTap: _showEditVehicleDialog),
          const SizedBox(height: 24),
          _buildSectionTitle('Preferencias'),
          _buildSettingsTile(
            Icons.notifications_none,
            'Notificaciones',
            subtitle: notificationsEnabled
                ? 'Recordatorios de viaje, coincidencias y premios'
                : 'Silenciadas: no recibirás avisos de la app',
            trailing: Switch(
              value: notificationsEnabled,
              onChanged: (val) async {
                await ref
                    .read(appStateProvider.notifier)
                    .updateNotificationsEnabled(val);
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                        content: Text(val
                            ? 'Notificaciones activadas'
                            : 'Notificaciones silenciadas')));
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Legal'),
          _buildSettingsTile(
            Icons.description_outlined,
            'Términos de Servicio',
            onTap: () => _showSimpleDialog(
              'Términos de Servicio',
              'VoyContigo es una comunidad de viajes compartidos.\n\n'
                  '• Al publicar o aceptar un viaje, compartes tu ruta, horario y datos básicos (nombre y vehículo) con los usuarios involucrados.\n\n'
                  '• Los acuerdos de aporte económico entre conductor y pasajeros son entre particulares; VoyContigo no procesa pagos ni actúa como transportista.\n\n'
                  '• Debes brindar información veraz sobre tu identidad y tu vehículo. Las cuentas con conductas inseguras o fraudulentas pueden ser suspendidas.\n\n'
                  '• Los cupones del Club de Beneficios los entregan los locales adheridos y pueden cambiar sin previo aviso.',
            ),
          ),
          _buildSettingsTile(
            Icons.privacy_tip_outlined,
            'Política de Privacidad',
            onTap: () => _showSimpleDialog(
              'Política de Privacidad',
              'Tu privacidad es importante para nosotros.\n\n'
                  '• Guardamos tu nombre, correo, vehículo y viajes para que la app funcione.\n\n'
                  '• Tu ubicación en tiempo real solo se comparte durante un viaje activo y únicamente con los usuarios confirmados de ese viaje.\n\n'
                  '• Tu contacto de emergencia solo se usa si presionas el botón SOS.\n\n'
                  '• No vendemos tus datos a terceros. Puedes solicitar la eliminación de tu cuenta escribiendo a ayuda@voycontigo.app.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: AppTheme.subtitleFont(
            fontWeight: FontWeight.w600,
            color: AppTheme.inkMuted,
            fontSize: 12,
            letterSpacing: 1.0),
      ),
    );
  }

  Widget _buildSettingsTile(
    IconData icon,
    String title, {
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppTheme.ink),
      title: Text(title,
          style: AppTheme.bodyFont(color: AppTheme.ink, fontSize: 16)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: AppTheme.bodyFont(color: AppTheme.inkMuted, fontSize: 12))
          : null,
      trailing: trailing ??
          const Icon(Icons.chevron_right, color: AppTheme.inkMuted),
      onTap: trailing != null ? null : onTap,
    );
  }
}
