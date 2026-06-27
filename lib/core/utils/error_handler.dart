import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ErrorHandler {
  /// Devuelve un mensaje de error amigable para el usuario basado en la excepción técnica.
  static String getFriendlyErrorMessage(dynamic error) {
    final String errorStr = error.toString().toLowerCase();

    // Errores de Conexión y Base de Datos
    if (errorStr.contains('network') || errorStr.contains('offline') || errorStr.contains('socket')) {
      return 'Verifica tu conexión a internet e intenta nuevamente.';
    }
    if (errorStr.contains('permission-denied')) {
      return 'No tienes permisos para realizar esta acción.';
    }
    if (errorStr.contains('not-found')) {
      return 'El recurso solicitado ya no está disponible.';
    }
    if (errorStr.contains('unavailable')) {
      return 'El servicio no está disponible en este momento. Intenta más tarde.';
    }
    
    // Errores de Autenticación
    if (errorStr.contains('user-not-found') || errorStr.contains('wrong-password') || errorStr.contains('invalid-credential')) {
      return 'Credenciales inválidas. Verifica tu correo y contraseña.';
    }
    if (errorStr.contains('email-already-in-use')) {
      return 'Este correo ya está registrado. Intenta iniciar sesión.';
    }
    if (errorStr.contains('weak-password')) {
      return 'La contraseña es muy débil. Usa al menos 6 caracteres.';
    }

    // Errores de Negocio (Trips)
    if (errorStr.contains('asientos insuficientes') || errorStr.contains('alguien los tomó antes')) {
      return '¡Ups! Alguien acaba de reservar los últimos asientos.';
    }
    if (errorStr.contains('viaje ya no existe')) {
      return 'Lo sentimos, este viaje ha sido cancelado o eliminado.';
    }
    if (errorStr.contains('viaje ya fue aceptado')) {
      return 'Alguien más ya fue asignado a este viaje.';
    }

    // Pagos (Stripe)
    if (errorStr.contains('stripe') || errorStr.contains('payment_intent')) {
      return 'Hubo un problema procesando tu pago. Verifica tu tarjeta.';
    }

    // Fallback genérico para producción (no mostrar error crudo)
    // Se puede imprimir en consola para debug.
    debugPrint('Unhandled Error: $error');
    return 'Ocurrió un error inesperado. Por favor, intenta de nuevo.';
  }

  /// Muestra un SnackBar elegante y estandarizado para toda la aplicación
  static void showErrorSnackBar(BuildContext context, dynamic error) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                getFriendlyErrorMessage(error),
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        elevation: 6,
      ),
    );
  }

  static void showSuccessSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        elevation: 6,
      ),
    );
  }
}
