import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:voycontigo/features/trips/presentation/providers/trip_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkMode = false;
  String _selectedLanguage = 'Español';

  void _showEditProfileDialog() {
    final appState = ref.read(appStateProvider);
    final nameCtrl = TextEditingController(text: appState.userName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Editar Perfil', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre Completo',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.black54)),
          ),
          FilledButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isNotEmpty) {
                await ref.read(appStateProvider.notifier).updateName(newName);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.black),
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
        backgroundColor: Colors.white,
        title: Text('Mi Vehículo', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: modelCtrl,
              decoration: const InputDecoration(
                labelText: 'Modelo y color (ej. Kia Picanto Rojo)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: plateCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Placa (Ecuador)',
                helperText: 'Ejemplo: PBA-1234 o ABC-123',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.black54)),
          ),
          FilledButton(
            onPressed: () async {
              final newModel = modelCtrl.text.trim();
              final rawPlate = plateCtrl.text.trim().toUpperCase();
              
              if (newModel.isEmpty || newModel.length < 3) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Por favor, describe el modelo y color del vehículo')),
                );
                return;
              }

              // Auto-formatear y validar placa ecuatoriana (ej: PBA-1234 o ABC-123)
              String cleanPlate = rawPlate.replaceAll(RegExp(r'[^A-Z0-9]'), '');
              String formattedPlate = rawPlate;
              
              if (cleanPlate.length >= 6 && cleanPlate.length <= 7) {
                final letters = cleanPlate.substring(0, 3);
                final numbers = cleanPlate.substring(3);
                if (RegExp(r'^[A-Z]{3}$').hasMatch(letters) && RegExp(r'^\d{3,4}$').hasMatch(numbers)) {
                  formattedPlate = '$letters-$numbers';
                }
              }

              final plateRegex = RegExp(r'^[A-Z]{3}-\d{3,4}$');
              if (!plateRegex.hasMatch(formattedPlate)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Placa inválida. Debe tener el formato ecuatoriano (ej: PBA-1234 o ABC-123)')),
                );
                return;
              }

              await ref.read(appStateProvider.notifier).updateVehicle(newModel, formattedPlate);
              
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vehículo actualizado')));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.black),
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
        backgroundColor: Colors.white,
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(content, style: GoogleFonts.inter(color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Idioma', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Español', 'English'].map((lang) {
            return RadioListTile<String>(
              title: Text(lang),
              value: lang,
              groupValue: _selectedLanguage,
              activeColor: Colors.black,
              onChanged: (val) {
                setState(() => _selectedLanguage = val!);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Idioma cambiado a $val')));
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Configuración', style: GoogleFonts.inter(letterSpacing: -0.5)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionTitle('Cuenta'),
          _buildSettingsTile(Icons.person_outline, 'Editar Perfil', onTap: _showEditProfileDialog),
          _buildSettingsTile(Icons.directions_car_outlined, 'Mi Vehículo', onTap: _showEditVehicleDialog),
          _buildSettingsTile(Icons.lock_outline, 'Privacidad y Seguridad', onTap: () => _showSimpleDialog('Privacidad', 'Aquí podrás configurar quién puede ver tus viajes y tus datos personales (Próximamente).')),
          const SizedBox(height: 24),
          _buildSectionTitle('Preferencias'),
          _buildSettingsTile(Icons.notifications_none, 'Notificaciones', trailing: Switch(
            value: _notificationsEnabled, 
            activeColor: Colors.black,
            onChanged: (val) {
              setState(() => _notificationsEnabled = val);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(val ? 'Notificaciones activadas' : 'Notificaciones silenciadas')));
            }
          )),
          _buildSettingsTile(Icons.language, 'Idioma ($_selectedLanguage)', onTap: _showLanguageDialog),
          _buildSettingsTile(Icons.dark_mode_outlined, 'Modo Oscuro', trailing: Switch(
            value: _darkMode, 
            activeColor: Colors.black,
            onChanged: (val) {
              setState(() => _darkMode = val);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tema oscuro en desarrollo')));
            }
          )),
          const SizedBox(height: 24),
          _buildSectionTitle('Legal'),
          _buildSettingsTile(Icons.description_outlined, 'Términos de Servicio', onTap: () => _showSimpleDialog('Términos de Servicio', 'Al usar VoyContigo aceptas compartir tus rutas y datos básicos con otros usuarios de la comunidad para facilitar el carpooling.')),
          _buildSettingsTile(Icons.privacy_tip_outlined, 'Política de Privacidad', onTap: () => _showSimpleDialog('Política de Privacidad', 'Tus datos están seguros. No compartiremos tu ubicación en tiempo real excepto durante un viaje activo con un usuario confirmado.')),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.black54, fontSize: 12, letterSpacing: 1.0),
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, {Widget? trailing, VoidCallback? onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.black87),
      title: Text(title, style: GoogleFonts.inter(color: Colors.black87, fontSize: 16)),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.black38),
      onTap: trailing != null ? null : onTap,
    );
  }
}
