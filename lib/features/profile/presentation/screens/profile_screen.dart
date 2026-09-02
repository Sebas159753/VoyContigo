import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voycontigo/core/theme/app_theme.dart';
import 'package:voycontigo/features/trips/presentation/providers/trip_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:voycontigo/core/config/app_config.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Perfil'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
              ]
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const CircleAvatar(
                    radius: 46,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 50, color: Colors.black26),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  appState.userName,
                  textAlign: TextAlign.center,
                  style: AppTheme.titleFont(fontSize: 26, color: Colors.white, letterSpacing: -0.3),
                ),
                const SizedBox(height: 4),
                Text(
                  appState.userEmail,
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyFont(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          if (AppConfig.isMonetizationEnabled) ...[
            Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Plan Actual', style: AppTheme.bodyFont(fontWeight: FontWeight.w700, color: Colors.black, fontSize: 16)),
                    const SizedBox(height: 4),
                    Builder(
                      builder: (context) {
                        int remaining = 3 - appState.freeUses;
                        if (remaining < 0) remaining = 0;
                        String text = appState.isPremium 
                            ? 'Premium (Ilimitado)' 
                            : (remaining > 0 ? 'Gratis ($remaining usos restantes)' : 'Gratis (Usos Agotados)');
                        return Text(text, style: AppTheme.bodyFont(color: Colors.black54, fontSize: 14));
                      }
                    ),
                  ],
                ),
                Icon(Icons.star, color: appState.isPremium ? Colors.amber : Colors.black26, size: 32),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ],
          _buildListTile(Icons.swap_horiz, 'Cambiar de Rol', () {
            context.go('/role');
          }),
          if (appState.role == 'ADMIN') ...[
            const Divider(),
            _buildListTile(Icons.admin_panel_settings, 'Panel de Administración', () {
              context.push('/admin');
            }),
          ],
          _buildListTile(Icons.medical_services_outlined, 'Contacto de Emergencia', () {
            _showEmergencyContactModal(context, ref, appState.emergencyPhone);
          }),
          _buildListTile(Icons.settings, 'Configuración', () {
            context.push('/settings');
          }),
          _buildListTile(Icons.support_agent, 'Soporte', () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) => Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Centro de Soporte', style: AppTheme.bodyFont(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                    const SizedBox(height: 16),
                    Text('¿Necesitas ayuda con un viaje o tu cuenta?', style: AppTheme.bodyFont(color: Colors.black54), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF25D366), // verde WhatsApp
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chat_rounded, color: Colors.white, size: 20),
                      ),
                      title: Text('Escríbenos por WhatsApp', style: AppTheme.bodyFont(color: Colors.black87, fontWeight: FontWeight.w600)),
                      subtitle: Text('Te respondemos lo antes posible', style: AppTheme.bodyFont(color: Colors.black45, fontSize: 12)),
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        context.pop();
                        final whatsappUri = Uri.https('wa.me', '/593999284698', {
                          'text': 'Hola, necesito ayuda con VoyContigo 👋',
                        });
                        bool opened = false;
                        try {
                          opened = await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
                        } catch (_) {
                          opened = false;
                        }
                        if (!opened) {
                          messenger.showSnackBar(const SnackBar(
                            content: Text('No se pudo abrir WhatsApp. Escríbenos al +593 99 928 4698'),
                          ));
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 32),
          _buildListTile(Icons.logout, 'Cerrar Sesión', () async {
            try {
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser != null) {
                await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
                  'fcmToken': FieldValue.delete(),
                });
              }
            } catch (e) {
              // Silently catch or log error if user is offline
            }
            ref.read(appStateProvider.notifier).logout();
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              context.go('/login');
            }
          }, iconColor: Colors.red, textColor: Colors.red),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, VoidCallback onTap, {Color iconColor = Colors.black87, Color textColor = Colors.black87}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))
        ]
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title, style: AppTheme.bodyFont(fontWeight: FontWeight.w600, color: textColor, fontSize: 15)),
        trailing: const Icon(Icons.chevron_right, color: Colors.black26),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showEmergencyContactModal(BuildContext context, WidgetRef ref, String currentPhone) {
    final TextEditingController controller = TextEditingController(text: currentPhone);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Contacto de Emergencia', style: AppTheme.bodyFont(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Este número recibirá un mensaje de texto con tu ubicación si presionas el botón SOS durante un viaje.', style: AppTheme.bodyFont(color: Colors.black54), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Número de WhatsApp o SMS',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final newPhone = controller.text.trim();
                Navigator.pop(ctx);
                await ref.read(appStateProvider.notifier).updateEmergencyPhone(newPhone);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contacto de emergencia actualizado')));
                }
              },
              child: Text('Guardar', style: AppTheme.bodyFont(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
