import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voycontigo/core/theme/app_theme.dart';
import 'package:voycontigo/features/trips/presentation/providers/trip_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:voycontigo/core/services/notification_service.dart';
import 'package:voycontigo/core/utils/error_handler.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController(); 
  bool _isLoading = false;
  bool _isLogin = true; 
  bool _obscurePassword = true;
  bool _acceptedTerms = false;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final fetchedName = doc.data()?['name'] ?? 'Usuario';
        final freeUses = doc.data()?['freeUses'] ?? 0;
        final isPremium = doc.data()?['isPremium'] ?? false;
        final isSubscribed = doc.data()?['isSubscribed'] ?? false;
        final lastResetMonth = doc.data()?['lastResetMonth'] ?? '';
        final carModel = doc.data()?['carModel'] ?? '';
        final carPlate = doc.data()?['carPlate'] ?? '';
        final isVerified = doc.data()?['isVerified'] ?? false;
        final emergencyPhone = doc.data()?['emergencyPhone'] ?? '';
        final completedTrips = doc.data()?['completedTrips'] ?? 0;
        
        ref.read(appStateProvider.notifier).login(
          user.uid, 
          fetchedName, 
          user.email ?? '', 
          freeUses: freeUses, 
          isPremium: isPremium,
          isSubscribed: isSubscribed,
          lastResetMonth: lastResetMonth,
          carModel: carModel,
          carPlate: carPlate,
          isVerified: isVerified,
          emergencyPhone: emergencyPhone,
          completedTrips: completedTrips,
        );
        
        if (mounted) {
          context.go('/role');
        }
      } catch (e) {
        // Fallback to manual login
      }
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty || (!_isLogin && name.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, llena todos los campos')),
      );
      return;
    }

    if (!_isLogin && !_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes aceptar los términos y condiciones')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential;
      if (_isLogin) {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        final doc = await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).get();
        final fetchedName = doc.data()?['name'] ?? 'Usuario';
        final freeUses = doc.data()?['freeUses'] ?? 0;
        final isPremium = doc.data()?['isPremium'] ?? false;
        final isSubscribed = doc.data()?['isSubscribed'] ?? false;
        final lastResetMonth = doc.data()?['lastResetMonth'] ?? '';
        final carModel = doc.data()?['carModel'] ?? '';
        final carPlate = doc.data()?['carPlate'] ?? '';
        final isVerified = doc.data()?['isVerified'] ?? false;
        final emergencyPhone = doc.data()?['emergencyPhone'] ?? '';
        final completedTrips = doc.data()?['completedTrips'] ?? 0;
        
        ref.read(appStateProvider.notifier).login(
          userCredential.user!.uid, 
          fetchedName, 
          email, 
          freeUses: freeUses, 
          isPremium: isPremium,
          isSubscribed: isSubscribed,
          lastResetMonth: lastResetMonth,
          carModel: carModel,
          carPlate: carPlate,
          isVerified: isVerified,
          emergencyPhone: emergencyPhone,
          completedTrips: completedTrips,
        );
        
      } else {
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        final currentYearMonth = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'name': name,
          'email': email,
          'rating': 5.0,
          'totalRatings': 1,
          'freeUses': 0,
          // isPremium/isSubscribed no se escriben: las reglas los tratan
          // como false cuando faltan y así no chocan con la validación.
          'lastResetMonth': currentYearMonth,
          'createdAt': FieldValue.serverTimestamp(),
          'completedTrips': 0,
          'role': 'USER',
        });
        
        ref.read(appStateProvider.notifier).login(
          userCredential.user!.uid, 
          name, 
          email,
          lastResetMonth: currentYearMonth,
        );
      }

      if (mounted) {
        // Update FCM token after login/register
        await NotificationService().updateToken();
        context.go('/role');
      }
    } on FirebaseAuthException catch (e) {
      ErrorHandler.showErrorSnackBar(context, e);
    } catch (e) {
      ErrorHandler.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa tu correo primero')),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ErrorHandler.showSuccessSnackBar(context, 'Correo de recuperación enviado');
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // En la web, Firebase maneja el popup directamente sin necesidad de Client ID
        final provider = GoogleAuthProvider();
        userCredential = await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        // En móvil, usamos el flujo nativo
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          setState(() => _isLoading = false);
          return; // El usuario canceló
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final user = userCredential.user;

      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        String fetchedName = user.displayName ?? 'Usuario';
        int freeUses = 0;
        bool isPremium = false;
        bool isSubscribed = false;
        String lastResetMonth = '';

        final currentYearMonth = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";

        String carModel = '';
        String carPlate = '';
        bool isVerified = false;
        String emergencyPhone = '';
        int completedTrips = 0;

        if (doc.exists) {
          fetchedName = doc.data()?['name'] ?? fetchedName;
          freeUses = doc.data()?['freeUses'] ?? 0;
          isPremium = doc.data()?['isPremium'] ?? false;
          isSubscribed = doc.data()?['isSubscribed'] ?? false;
          lastResetMonth = doc.data()?['lastResetMonth'] ?? '';
          carModel = doc.data()?['carModel'] ?? '';
          carPlate = doc.data()?['carPlate'] ?? '';
          isVerified = doc.data()?['isVerified'] ?? false;
          emergencyPhone = doc.data()?['emergencyPhone'] ?? '';
          completedTrips = doc.data()?['completedTrips'] ?? 0;
        } else {
          lastResetMonth = currentYearMonth;
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'name': fetchedName,
            'email': user.email,
            'rating': 5.0,
            'totalRatings': 1,
            'freeUses': 0,
            // isPremium/isSubscribed no se escriben: las reglas los tratan
            // como false cuando faltan y así no chocan con la validación.
            'isVerified': false,
            'lastResetMonth': currentYearMonth,
            'createdAt': FieldValue.serverTimestamp(),
            'role': 'USER',
          });
        }

        ref.read(appStateProvider.notifier).login(
          user.uid, 
          fetchedName, 
          user.email ?? '', 
          freeUses: freeUses, 
          isPremium: isPremium,
          isSubscribed: isSubscribed,
          lastResetMonth: lastResetMonth,
          carModel: carModel,
          carPlate: carPlate,
          isVerified: isVerified,
          emergencyPhone: emergencyPhone,
          completedTrips: completedTrips,
        );

        if (mounted) {
          await NotificationService().updateToken();
          context.go('/role');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de Google: $e')),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              const Icon(
                Icons.directions_car, 
                size: 64,
                color: Colors.black,
              ),
              const SizedBox(height: 32),
              Text(
                'VoyContigo.',
                style: AppTheme.titleFont(
                  fontSize: 50,
                  color: AppTheme.purpleDarkest,
                  letterSpacing: -1.0,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                'Tu viaje. Tus reglas.',
                style: AppTheme.bodyFont(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: Colors.black54,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 64),
              if (!_isLogin) ...[
                TextFormField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    labelText: 'Tu Nombre (Para el Perfil)',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.black),
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _resetPassword,
                    child: Text('¿Olvidaste tu contraseña?', style: AppTheme.bodyFont(color: Colors.black54, fontSize: 13)),
                  ),
                )
              else ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _acceptedTerms,
                        activeColor: Colors.black,
                        onChanged: (val) => setState(() => _acceptedTerms = val ?? false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Acepto los términos y condiciones de servicio y políticas de privacidad.',
                        style: AppTheme.bodyFont(fontSize: 12, color: Colors.black54),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleAuth,
                child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isLogin ? 'Iniciar Sesión' : 'Crear Cuenta'),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Container(height: 1, color: Colors.black12)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('O', style: AppTheme.bodyFont(color: Colors.black54, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(child: Container(height: 1, color: Colors.black12)),
                ],
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                icon: Image.network('https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png', height: 20, errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, color: Colors.black)),
                label: Text('Continuar con Google', style: AppTheme.bodyFont(color: Colors.black, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Colors.black26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin ? '¿No tienes cuenta?' : '¿Ya tienes cuenta?',
                    style: AppTheme.bodyFont(color: Colors.black54),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _nameCtrl.clear();
                        _passwordCtrl.clear();
                        _acceptedTerms = false;
                      });
                    },
                    child: Text(
                      _isLogin ? 'Regístrate aquí' : 'Inicia Sesión',
                      style: AppTheme.bodyFont(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
