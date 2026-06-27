import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:voycontigo/features/trips/presentation/providers/trip_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:voycontigo/core/config/app_config.dart';

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
                  style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  appState.userEmail,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w500),
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
                    Text('Plan Actual', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.black, fontSize: 16)),
                    const SizedBox(height: 4),
                    Builder(
                      builder: (context) {
                        int remaining = 3 - appState.freeUses;
                        if (remaining < 0) remaining = 0;
                        String text = appState.isPremium 
                            ? 'Premium (Ilimitado)' 
                            : (remaining > 0 ? 'Gratis ($remaining usos restantes)' : 'Gratis (Usos Agotados)');
                        return Text(text, style: GoogleFonts.inter(color: Colors.black54, fontSize: 14));
                      }
                    ),
                  ],
                ),
                Icon(Icons.star, color: appState.isPremium ? Colors.amber : Colors.black26, size: 32),
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (!appState.isSubscribed)
            _buildListTile(Icons.workspace_premium, 'Mejorar a Premium', () {
              context.push('/subscription');
            })
          else
            _buildListTile(Icons.cancel, 'Cancelar Suscripción', () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Cancelar Suscripción'),
                  content: const Text('¿Estás seguro de que quieres cancelar tu suscripción Premium?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('No, mantener', style: TextStyle(color: Colors.black54)),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (c) => const Center(child: CircularProgressIndicator()),
                        );
                        
                        try {
                          final uid = ref.read(appStateProvider).uid;
                          final httpsCallable = FirebaseFunctions.instance.httpsCallable('cancelSubscription');
                          final result = await httpsCallable.call({'uid': uid});
                          
                          if (context.mounted) {
                            Navigator.pop(context); // close loader
                            if (result.data['success'] == true) {
                              ref.read(appStateProvider.notifier).cancelSubscription();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Suscripción cancelada exitosamente')),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.pop(context); // close loader
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al cancelar: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('Sí, cancelar', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            }),
          ],
          _buildListTile(Icons.swap_horiz, 'Cambiar de Rol', () {
            context.go('/role');
          }),
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
                    Text('Centro de Soporte', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                    const SizedBox(height: 16),
                    Text('¿Necesitas ayuda con un viaje o tu cuenta?', style: GoogleFonts.inter(color: Colors.black54), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ListTile(
                      leading: const Icon(Icons.email_outlined, color: Colors.black),
                      title: Text('ayuda@voycontigo.app', style: GoogleFonts.inter(color: Colors.black87, fontWeight: FontWeight.w600)),
                      onTap: () {
                        context.pop();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Abriendo correo...')));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.chat_bubble_outline, color: Colors.black),
                      title: Text('Chat en vivo (Próximamente)', style: GoogleFonts.inter(color: Colors.black87, fontWeight: FontWeight.w600)),
                      onTap: () => context.pop(),
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
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textColor, fontSize: 15)),
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
            Text('Contacto de Emergencia', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Este número recibirá un mensaje de texto con tu ubicación si presionas el botón SOS durante un viaje.', style: GoogleFonts.inter(color: Colors.black54), textAlign: TextAlign.center),
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
              child: Text('Guardar', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
