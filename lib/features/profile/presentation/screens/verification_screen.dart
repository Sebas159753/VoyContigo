import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:voycontigo/features/trips/presentation/providers/trip_provider.dart';
import 'package:voycontigo/core/theme/app_theme.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  final _licenseCtrl = TextEditingController();
  final _carPlateCtrl = TextEditingController();
  final _carModelCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _licenseCtrl.dispose();
    _carPlateCtrl.dispose();
    _carModelCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final license = _licenseCtrl.text.trim();
    final rawPlate = _carPlateCtrl.text.trim().toUpperCase();
    final carModel = _carModelCtrl.text.trim();

    final licenseRegex = RegExp(r'^\d{10}$');
    if (!licenseRegex.hasMatch(license)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa los 10 dígitos de tu licencia/cédula')),
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
        _carPlateCtrl.text = formattedPlate;
      }
    }

    final plateRegex = RegExp(r'^[A-Z]{3}-\d{3,4}$');
    if (!plateRegex.hasMatch(formattedPlate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Placa inválida. Debe tener el formato ecuatoriano (ej: PBA-1234 o ABC-123)')),
      );
      return;
    }

    if (carModel.isEmpty || carModel.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, describe el modelo y color (ej: Kia Picanto Rojo)')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(appStateProvider.notifier).submitVerification(
        licenseNumber: license,
        carPlate: formattedPlate,
        carModel: carModel,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Verificación exitosa! Eres un Conductor Verificado.'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/role');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al verificar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Verificación de Conductor', style: AppTheme.bodyFont(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.verified_user, size: 80, color: AppTheme.tommyNavy),
              const SizedBox(height: 24),
              Text(
                'Confianza y Seguridad',
                style: AppTheme.titleFont(
                  fontSize: 26,
                  color: AppTheme.ink,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Para ofrecer viajes en nuestra comunidad, necesitamos validar los datos de tu vehículo y licencia. Esto garantiza la seguridad de todos.',
                style: AppTheme.bodyFont(fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              TextFormField(
                controller: _licenseCtrl,
                keyboardType: TextInputType.number,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Número de Licencia de Conducir',
                  helperText: '10 dígitos numéricos (Cédula ecuatoriana)',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

               TextFormField(
                controller: _carPlateCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Placa del Vehículo (Ecuador)',
                  helperText: 'Formatos válidos: ABC-1234 o ABC-123',
                  prefixIcon: const Icon(Icons.credit_card_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _carModelCtrl,
                textCapitalization: TextCapitalization.words,
                maxLength: 50,
                decoration: InputDecoration(
                  labelText: 'Marca, Modelo y Color del Vehículo',
                  helperText: 'Ej: Chevrolet Aveo Azul',
                  prefixIcon: const Icon(Icons.directions_car_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.tommyNavy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Validar Identidad', style: AppTheme.bodyFont(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
