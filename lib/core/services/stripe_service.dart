import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:voycontigo/core/utils/error_handler.dart';

class StripeService {
  static const String _cloudFunctionUrl = 'https://us-central1-voycontigo-1a327.cloudfunctions.net/createSubscription'; 

  static Future<void> init() async {
    Stripe.publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
    await Stripe.instance.applySettings();
  }

  static Future<bool> subscribeDriver(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Usuario no autenticado");

      // 1. Llamar a la Cloud Function para crear la suscripción
      final response = await http.post(
        Uri.parse(_cloudFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': user.uid,
          'email': user.email,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['error'] != null) {
        throw Exception(data['error']);
      }

      final clientSecret = data['clientSecret'];

      // 2. Inicializar el Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'VoyContigo',
          style: ThemeMode.light,
        ),
      );

      // 3. Presentar el Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      // Si llega aquí, el pago/configuración fue exitoso
      return true;

    } catch (e) {
      if (e is StripeException) {
        ErrorHandler.showErrorSnackBar(context, 'Pago cancelado o fallido: ${e.error.localizedMessage}');
      } else {
        ErrorHandler.showErrorSnackBar(context, e);
      }
      return false;
    }
  }
}
