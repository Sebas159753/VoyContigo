class AppConfig {
  /// Interruptor Maestro de Monetización.
  /// Si está en 'false', la app entra en modo 100% gratuito:
  /// - Desaparecen los límites de 3 usos para conductores.
  /// - Se ocultan los botones y banners de suscripción Premium.
  /// 
  /// Para activar el cobro en el futuro, simplemente cambia esto a 'true'.
  static const bool isMonetizationEnabled = false;
}
