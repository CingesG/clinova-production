import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'patient_shell.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/admin/presentation/admin_dashboard_screen.dart';
import '../features/ai_agent/presentation/ai_agent_screen.dart';
import '../features/appointments/presentation/appointment_booking_landing_screen.dart';
import '../features/appointments/presentation/appointment_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/auth/presentation/verify_otp_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/chat/presentation/doctor_chat_landing_screen.dart';
import '../features/chat/presentation/doctor_chat_screen.dart';
import '../features/doctor/presentation/doctor_dashboard_screen.dart';
import '../features/doctor/presentation/doctor_notes_screen.dart';
import '../features/doctor/presentation/doctor_schedule_screen.dart';
import '../features/doctor/presentation/doctor_public_profile_screen.dart';
import '../features/emergency/presentation/emergency_screen.dart';
import '../features/branches/presentation/branches_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/profile/presentation/profile_change_password_screen.dart';
import '../features/profile/presentation/profile_edit_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/splash/presentation/splash_screen.dart';

/// Triggers [GoRouter.redirect] when [AuthState] changes **without** building a
/// new [GoRouter]. Watching [authControllerProvider] on the router provider
/// used to recreate GoRouter on every `isBusy` toggle and reset the stack to
/// [initialLocation] — users were kicked to splash/home while logging in.
final authRouterRefreshProvider = Provider<AuthRouterRefresh>((ref) {
  final notifier = AuthRouterRefresh();
  ref.listen<AuthState>(authControllerProvider, (prev, next) {
    notifier.notify();
  });
  ref.onDispose(notifier.dispose);
  return notifier;
});

class AuthRouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRefresh = ref.watch(authRouterRefreshProvider);

  String homeForRole(String role) {
    switch (role) {
      case 'ADMIN':
      case 'STAFF':
        return '/admin';
      case 'DOCTOR':
        return '/doctor';
      case 'PATIENT':
      default:
        return '/home';
    }
  }

  bool isRouteAllowed(String role, String location) {
    switch (role) {
      case 'ADMIN':
      case 'STAFF':
        return location.startsWith('/admin') ||
            location == '/settings' ||
            location == '/doctor-chat' ||
            location == '/appointments' ||
            location.startsWith('/appointments/') ||
            location == '/appointments-landing' ||
            location == '/chat-landing' ||
            location == '/branches' ||
            location == '/emergency' ||
            location == '/agent' ||
            location == '/profile' ||
            location.startsWith('/profile/') ||
            location.startsWith('/doctor-profile/');
      case 'DOCTOR':
        return location == '/doctor' ||
            location == '/doctor/schedule' ||
            location == '/doctor/notes' ||
            location == '/doctor-chat' ||
            location == '/settings' ||
            location == '/appointments' ||
            location.startsWith('/appointments/') ||
            location == '/appointments-landing' ||
            location == '/chat-landing' ||
            location == '/branches' ||
            location == '/emergency' ||
            location == '/profile' ||
            location.startsWith('/profile/') ||
            location.startsWith('/doctor-profile/');
      case 'PATIENT':
      default:
        return location == '/home' ||
            location == '/appointments' ||
            location.startsWith('/appointments/') ||
            location == '/appointments-landing' ||
            location == '/chat-landing' ||
            location == '/branches' ||
            location == '/emergency' ||
            location == '/agent' ||
            location == '/settings' ||
            location == '/doctor-chat' ||
            location == '/profile' ||
            location.startsWith('/profile/') ||
            location.startsWith('/doctor-profile/');
    }
  }

  bool isGuestAccessible(String location) {
    if (location == '/splash') return true;
    if (location == '/welcome') return true;
    if (location.startsWith('/auth')) return true;
    if (location == '/appointments-landing') return true;
    if (location == '/chat-landing') return true;
    if (location == '/branches') return true;
    if (location == '/agent') return true;
    if (location == '/emergency') return true;
    if (location.startsWith('/doctor-profile/')) return true;
    return false;
  }

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      if (auth.isBootstrapping) {
        return location == '/splash' ? null : '/splash';
      }

      if (location == '/splash') {
        if (auth.isAuthenticated && auth.user != null) {
          return homeForRole(auth.user!.role);
        }
        return '/welcome';
      }

      if (!auth.isAuthenticated) {
        if (location.startsWith('/admin') || location == '/doctor') {
          return '/welcome';
        }
        if (isGuestAccessible(location)) {
          return null;
        }
        return '/welcome';
      }

      final role = auth.user?.role ?? 'PATIENT';
      final roleHome = homeForRole(role);

      if (location == '/welcome') {
        return roleHome;
      }

      final inAuthRoute = location.startsWith('/auth');

      if (inAuthRoute) {
        return roleHome;
      }

      if (!isRouteAllowed(role, location)) {
        return roleHome;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/forgot',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/auth/verify',
        builder: (context, state) => const VerifyOtpScreen(),
      ),
      GoRoute(
        path: '/auth/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/appointments-landing',
        builder: (context, state) => const AppointmentBookingLandingScreen(),
      ),
      GoRoute(
        path: '/doctor-profile/:doctorId',
        builder: (context, state) => DoctorPublicProfileScreen(
          doctorProfileId: state.pathParameters['doctorId']!,
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => PatientShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/chat-landing',
            builder: (context, state) => const DoctorChatLandingScreen(),
          ),
          GoRoute(
            path: '/appointments',
            builder: (context, state) =>
                const AppointmentBookingLandingScreen(),
            routes: [
              GoRoute(
                path: 'book',
                builder: (context, state) {
                  final q = state.uri.queryParameters;
                  return AppointmentScreen(
                    initialBranchId: q['branchId'],
                    initialDepartmentId: q['departmentId'],
                    initialServiceId: q['serviceId'],
                    initialDoctorId: q['doctorId'],
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/doctor-chat',
            builder: (context, state) {
              final q = state.uri.queryParameters;
              return DoctorChatScreen(
                conversationId: q['conversationId'],
                doctorId: q['doctorId'],
                doctorName: q['doctorName'],
                doctorAvatarUrl: q['doctorAvatar'],
                doctorUserId: q['doctorUserId'],
              );
            },
          ),
          GoRoute(
            path: '/profile',
            routes: [
              GoRoute(
                path: 'change-password',
                builder: (context, state) => const ProfileChangePasswordScreen(),
              ),
              GoRoute(
                path: 'edit',
                builder: (context, state) => const ProfileEditScreen(),
              ),
            ],
            builder: (context, state) => const ProfileScreen(),
          ),
          // With /settings in the same ShellRoute, push('/profile') stays in one Navigator (fixes web keyReservation assert).
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/branches',
        builder: (context, state) => const BranchesScreen(),
      ),
      GoRoute(
        path: '/agent',
        builder: (context, state) => const AiAgentScreen(),
      ),
      GoRoute(
        path: '/emergency',
        builder: (context, state) => const EmergencyScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/doctor',
        builder: (context, state) => const DoctorDashboardScreen(),
      ),
      GoRoute(
        path: '/doctor/schedule',
        builder: (context, state) => const DoctorScheduleScreen(),
      ),
      GoRoute(
        path: '/doctor/notes',
        builder: (context, state) => const DoctorNotesScreen(),
      ),
    ],
  );
});
