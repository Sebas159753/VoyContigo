import 'package:flutter/material.dart';
import 'package:voycontigo/core/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  Future<void> _approveUser(BuildContext context, String uid, String name) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isVerified': true,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name ha sido aprobado como conductor.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al aprobar: $e')),
        );
      }
    }
  }

  Future<void> _rejectUser(BuildContext context, String uid, String name) async {
    try {
      // For MVP, just clear the car details so they have to submit again
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isVerified': false,
        'carModel': FieldValue.delete(),
        'carPlate': FieldValue.delete(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Solicitud de $name rechazada.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al rechazar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Panel de Administración', style: AppTheme.bodyFont(color: Colors.black, letterSpacing: -0.5)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users')
            .where('isVerified', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          
          // Filtrar localmente los que tengan modelo de carro, indicando que enviaron solicitud
          final pendingUsers = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final carModel = data['carModel'] as String?;
            return carModel != null && carModel.isNotEmpty;
          }).toList();

          if (pendingUsers.isEmpty) {
            return Center(
              child: Text('No hay solicitudes pendientes.', style: AppTheme.bodyFont(color: Colors.black54, fontSize: 16)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pendingUsers.length,
            separatorBuilder: (context, index) => const Divider(height: 32),
            itemBuilder: (context, index) {
              final userDoc = pendingUsers[index];
              final userData = userDoc.data() as Map<String, dynamic>;
              
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[200]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userData['name'] ?? 'Sin Nombre',
                      style: AppTheme.bodyFont(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(userData['email'] ?? 'Sin Email', style: AppTheme.bodyFont(color: Colors.black54)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Detalles del Vehículo', style: AppTheme.bodyFont(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text('Modelo: ${userData['carModel']}', style: AppTheme.bodyFont(fontSize: 14)),
                          Text('Placa: ${userData['carPlate']}', style: AppTheme.bodyFont(fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _rejectUser(context, userDoc.id, userData['name'] ?? 'Usuario'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            child: const Text('Rechazar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _approveUser(context, userDoc.id, userData['name'] ?? 'Usuario'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Aprobar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
