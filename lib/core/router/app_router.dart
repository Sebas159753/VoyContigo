import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voycontigo/features/auth/presentation/screens/login_screen.dart';
import 'package:voycontigo/features/home/presentation/screens/home_screen.dart';
import 'package:voycontigo/features/home/presentation/screens/role_selection_screen.dart';
import 'package:voycontigo/features/trips/presentation/screens/publish_screen.dart';
import 'package:voycontigo/features/trips/presentation/screens/board_screen.dart';
import 'package:voycontigo/features/trips/presentation/screens/my_trips_screen.dart';
import 'package:voycontigo/features/profile/presentation/screens/profile_screen.dart';
import 'package:voycontigo/features/profile/presentation/screens/paywall_screen.dart';
import 'package:voycontigo/features/trips/presentation/screens/map_picker_screen.dart';
import 'package:voycontigo/features/chat/presentation/screens/chat_screen.dart';
import 'package:voycontigo/features/trips/presentation/screens/live_tracking_screen.dart';
import 'package:voycontigo/features/trips/presentation/screens/matches_screen.dart';
import 'package:voycontigo/features/profile/presentation/screens/settings_screen.dart';
import 'package:voycontigo/features/profile/presentation/screens/verification_screen.dart';
import 'package:voycontigo/features/subscription/presentation/screens/subscription_screen.dart';
import 'package:voycontigo/features/profile/presentation/screens/rewards_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final shellNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/role',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) => const PaywallScreen(),
      ),
      GoRoute(
        path: '/verify',
        builder: (context, state) => const VerificationScreen(),
      ),
      GoRoute(
        path: '/subscription',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: '/map-picker',
        builder: (context, state) => const MapPickerScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ChatScreen(dealId: id);
        },
      ),
      GoRoute(
        path: '/tracking/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return LiveTrackingScreen(tripId: id);
        },
      ),
      GoRoute(
        path: '/publish',
        builder: (context, state) {
          final type = state.uri.queryParameters['type'] ?? 'oferta';
          final tripId = state.uri.queryParameters['tripId'];
          return PublishScreen(type: type, tripId: tripId);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          return HomeScreen(child: child);
        },
        routes: [
          GoRoute(
            path: '/tablero',
            builder: (context, state) {
              return const BoardScreen();
            },
          ),
          GoRoute(
            path: '/matches',
            builder: (context, state) => const MatchesScreen(),
          ),
          GoRoute(
            path: '/my-trips',
            builder: (context, state) => const MyTripsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/rewards',
            builder: (context, state) => const RewardsScreen(),
          ),
        ],
      ),
    ],
  );
});
