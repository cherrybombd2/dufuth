import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/profile_completion_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/availability_slots/presentation/manage_availability_slots_screen.dart';
import '../features/appointments/presentation/admin_appointments_screen.dart';
import '../features/appointments/presentation/patient_appointments_screen.dart';
import '../features/booking/data/booking_repository.dart';
import '../features/booking/presentation/booking_screen.dart';
import '../features/departments/presentation/manage_departments_screen.dart';
import '../features/doctors/presentation/manage_doctors_screen.dart';
import '../features/faq/presentation/faq_screen.dart';
import '../features/faq/presentation/manage_faq_screen.dart';
import '../features/hospital_info/presentation/hospital_info_screen.dart';
import '../features/hospital_info/presentation/manage_hospital_info_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/reminders/presentation/patient_reminders_screen.dart';
import '../features/users/presentation/admin_users_screen.dart';
import '../features/workspace/data/doctor_workspace_repository.dart';
import '../features/workspace/presentation/doctor_appointment_detail_screen.dart';
import '../features/workspace/presentation/role_workspaces.dart';
import 'launch_flow.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => const AppLaunchGateScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/complete-profile',
        builder: (context, state) => const ProfileCompletionScreen(),
      ),
      GoRoute(
        path: '/patient',
        builder: (context, state) => const RoleProtectedScreen(
          requiredRole: 'patient',
          child: PatientWorkspaceScreen(),
        ),
      ),
      GoRoute(
        path: '/book-appointment',
        builder: (context, state) => const RoleProtectedScreen(
          requiredRole: 'patient',
          child: BookingScreen(),
        ),
      ),
      GoRoute(
        path: '/appointments',
        builder: (context, state) => const RoleProtectedScreen(
          requiredRole: 'patient',
          child: PatientAppointmentsScreen(),
        ),
      ),
      GoRoute(
        path: '/reschedule-appointment',
        builder: (context, state) => RoleProtectedScreen(
          requiredRole: 'patient',
          child: BookingScreen(
            currentAppointment: state.extra is BookingAppointment
                ? state.extra! as BookingAppointment
                : null,
          ),
        ),
      ),
      GoRoute(
        path: '/faq',
        builder: (context, state) => const MultiRoleProtectedScreen(
          allowedRoles: {'patient', 'doctor'},
          child: FaqScreen(),
        ),
      ),
      GoRoute(
        path: '/reminders',
        builder: (context, state) => const RoleProtectedScreen(
          requiredRole: 'patient',
          child: PatientRemindersScreen(),
        ),
      ),
      GoRoute(
        path: '/hospital-info',
        builder: (context, state) => const MultiRoleProtectedScreen(
          allowedRoles: {'patient', 'doctor'},
          child: HospitalInfoScreen(),
        ),
      ),
      GoRoute(
        path: '/doctor',
        builder: (context, state) => const RoleProtectedScreen(
          requiredRole: 'doctor',
          child: DoctorWorkspaceScreen(),
        ),
      ),
      GoRoute(
        path: '/doctor/appointments/:appointmentId',
        builder: (context, state) => RoleProtectedScreen(
          requiredRole: 'doctor',
          child: DoctorAppointmentDetailScreen(
            appointmentId: state.pathParameters['appointmentId'] ?? '',
            initialAppointment: state.extra is DoctorWorkspaceAppointment
                ? state.extra! as DoctorWorkspaceAppointment
                : null,
          ),
        ),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const RoleProtectedScreen(
          requiredRole: 'admin',
          child: AdminWorkspaceScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/departments',
        builder: (context, state) => const RoleProtectedScreen(
          requiredRole: 'admin',
          child: ManageDepartmentsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/doctors',
        builder: (context, state) => const RoleProtectedScreen(
          requiredRole: 'admin',
          child: ManageDoctorsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const RoleProtectedScreen(
          requiredRole: 'admin',
          child: AdminUsersScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/availability-slots',
        builder: (context, state) => const RoleProtectedScreen(
          requiredRole: 'admin',
          child: ManageAvailabilitySlotsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/appointments',
        builder: (context, state) => const RoleProtectedScreen(
          requiredRole: 'admin',
          child: AdminAppointmentsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/faq',
        builder: (context, state) => const RoleProtectedScreen(
          requiredRole: 'admin',
          child: ManageFaqScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/hospital-info',
        builder: (context, state) => const RoleProtectedScreen(
          requiredRole: 'admin',
          child: ManageHospitalInfoScreen(),
        ),
      ),
    ],
  );
});
