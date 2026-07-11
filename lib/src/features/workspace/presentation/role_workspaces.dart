import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/app_session_provider.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_ui.dart';
import '../../appointments/data/patient_appointments_repository.dart';
import '../../appointments/presentation/patient_appointments_screen.dart';
import '../../booking/data/booking_repository.dart';
import '../../faq/presentation/faq_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../data/doctor_workspace_repository.dart';
import 'doctor_alerts_screen.dart';
import 'doctor_schedule_screen.dart';

class PatientWorkspaceScreen extends ConsumerStatefulWidget {
  const PatientWorkspaceScreen({super.key});

  @override
  ConsumerState<PatientWorkspaceScreen> createState() =>
      _PatientWorkspaceScreenState();
}

class _PatientWorkspaceScreenState
    extends ConsumerState<PatientWorkspaceScreen> {
  int _currentIndex = 0;
  int _appointmentRefreshToken = 0;
  int _appointmentsTabRefreshToken = 0;
  bool _isPrefetchingBookingData = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchBookingReferenceData();
    });
  }

  void _refreshAppointments() {
    setState(() {
      _appointmentRefreshToken++;
      _appointmentsTabRefreshToken++;
    });
  }

  void _openAppointmentsTab() {
    _prefetchBookingReferenceData();
    setState(() {
      _currentIndex = 1;
      _appointmentsTabRefreshToken++;
    });
  }

  void _prefetchBookingReferenceData() {
    if (_isPrefetchingBookingData) {
      return;
    }
    final repository = ref.read(bookingRepositoryProvider);
    if (repository.hasFreshCachedData) {
      return;
    }
    _isPrefetchingBookingData = true;
    unawaited(
      repository.fetchReferenceData().catchError((_) {
        return null;
      }).whenComplete(() {
        _isPrefetchingBookingData = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider).valueOrNull;
    final firstName = _firstName(session?.profile?.fullName);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _PatientHomeDashboard(
            key: ValueKey(_appointmentRefreshToken),
            firstName: firstName,
            refreshToken: _appointmentRefreshToken,
            onAppointmentsChanged: _refreshAppointments,
          ),
          PatientAppointmentsScreen(
            key: ValueKey(_appointmentsTabRefreshToken),
            refreshToken: _appointmentsTabRefreshToken,
            onAppointmentsChanged: _refreshAppointments,
          ),
          const FaqScreen(),
          if (session?.profile != null && session?.user != null)
            ProfileScreen(
              profile: session!.profile!,
              email: session.user!.email,
            )
          else
            const _PatientComingSoonPage(
              title: 'Profile',
              message: 'Your patient profile details will appear here.',
              icon: Icons.person_rounded,
            ),
        ],
      ),
      bottomNavigationBar: _PatientBottomNavigation(
        currentIndex: _currentIndex,
        onSelected: (index) {
          if (index == 1) {
            _openAppointmentsTab();
          } else {
            setState(() => _currentIndex = index);
          }
        },
      ),
    );
  }

  String _firstName(String? fullName) {
    final trimmed = fullName?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'kami sama';
    }
    return trimmed.split(RegExp(r'\s+')).first;
  }
}

class _PatientHomeDashboard extends ConsumerWidget {
  const _PatientHomeDashboard({
    super.key,
    required this.firstName,
    required this.refreshToken,
    required this.onAppointmentsChanged,
  });

  final String firstName;
  final int refreshToken;
  final VoidCallback onAppointmentsChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: const Color(0xFFF4F8FF),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Stack(
            children: [
              const Positioned(
                top: 0,
                left: -96,
                right: -96,
                child: _TopBlueBackdrop(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CompactPatientBrand(),
                    const SizedBox(height: 18),
                    _HeroAppointmentCard(
                      firstName: firstName,
                      onAppointmentsChanged: onAppointmentsChanged,
                    ),
                    const SizedBox(height: 20),
                    const _DashboardActionGrid(),
                    const SizedBox(height: 20),
                    Text(
                      'Upcoming Appointment',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF1B2A46),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _UpcomingAppointmentCard(key: ValueKey(refreshToken)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBlueBackdrop extends StatelessWidget {
  const _TopBlueBackdrop();

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _BottomEllipseClipper(),
      child: Container(height: 244, color: const Color(0xFF5E9DFF)),
    );
  }
}

class _BottomEllipseClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - 104)
      ..quadraticBezierTo(
        size.width / 2,
        size.height + 118,
        size.width,
        size.height - 104,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _CompactPatientBrand extends StatelessWidget {
  const _CompactPatientBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFBFD9FF), Color(0xFFEAF3FF)],
            ),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Image.asset(
            'assets/branding/dufuth_logo.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'DUFUTH ',
                style: TextStyle(
                  color: Color(0xFF153B74),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(
                text: 'SmartCare',
                style: TextStyle(
                  color: Color(0xFF4D6FA4),
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroAppointmentCard extends StatelessWidget {
  const _HeroAppointmentCard({
    required this.firstName,
    required this.onAppointmentsChanged,
  });

  final String firstName;
  final VoidCallback onAppointmentsChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F3FE),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -22,
            top: -24,
            width: 132,
            height: 132,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF7FB0FF).withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -18,
            bottom: -26,
            width: 116,
            height: 116,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 31,
            width: 118,
            height: 156,
            child: Image.asset(
              'assets/home/female_doctor.png',
              fit: BoxFit.contain,
              alignment: Alignment.centerRight,
            ),
          ),
          Positioned.fill(
            right: 126,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to DUFUTH SmartCare',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF4F6D93),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Welcome!\n$firstName',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF183153),
                    fontWeight: FontWeight.w900,
                    height: 1.02,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () async {
                    final result = await context.push('/book-appointment');
                    if (result != null) {
                      onAppointmentsChanged();
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2C7DF7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    shape: const StadiumBorder(),
                    textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Book Now'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardActionGrid extends StatelessWidget {
  const _DashboardActionGrid();

  @override
  Widget build(BuildContext context) {
    const items = [
      _DashboardActionData(
        title: 'Appointments',
        body: 'Book and manage visits',
        iconPath: 'assets/nav/dashboard_calendar.png',
        color: Color(0xFFEAF2FF),
        route: '/appointments',
      ),
      _DashboardActionData(
        title: 'Reminders',
        body: 'Medication and alerts',
        iconPath: 'assets/nav/dashboard_bell.png',
        color: Color(0xFFEAF9F3),
        route: '/reminders',
      ),
      _DashboardActionData(
        title: 'FAQ & Help',
        body: 'Common questions and support',
        iconPath: 'assets/nav/faq_tryout.png',
        color: Color(0xFFFFF4E7),
        route: '/faq',
      ),
      _DashboardActionData(
        title: 'Hospital Info',
        body: 'FAQ, contacts, details',
        iconPath: 'assets/nav/file_icon.png',
        color: Color(0xFFF2EEFF),
        route: '/hospital-info',
      ),
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.25,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
      ),
      itemBuilder: (context, index) => _DashboardActionCard(data: items[index]),
    );
  }
}

class _DashboardActionCard extends StatelessWidget {
  const _DashboardActionCard({required this.data});

  final _DashboardActionData data;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: data.route == null ? null : () => context.push(data.route!),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: data.color,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Image.asset(
                  data.iconPath,
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const Spacer(),
            Text(
              data.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF1D2E4A),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF68768D),
                fontSize: 12,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingAppointmentCard extends ConsumerStatefulWidget {
  const _UpcomingAppointmentCard({super.key});

  @override
  ConsumerState<_UpcomingAppointmentCard> createState() =>
      _UpcomingAppointmentCardState();
}

class _UpcomingAppointmentCardState
    extends ConsumerState<_UpcomingAppointmentCard> {
  List<PatientAppointment>? _appointments;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final cached = ref.read(patientAppointmentsRepositoryProvider).cachedAppointments;
    _appointments = cached;
    _loading = cached == null;
    _load();
  }

  Future<void> _load() async {
    try {
      final appointments =
          await ref.read(patientAppointmentsRepositoryProvider).fetchAppointments();
      if (!mounted) return;
      setState(() {
        _appointments = appointments;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointment = _nextAppointment(_appointments ?? const []);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/appointments'),
        borderRadius: BorderRadius.circular(24),
        child: _loading
            ? const SizedBox(
                height: 56,
                child: Center(child: CircularProgressIndicator()),
              )
            : appointment == null
                ? const _EmptyUpcomingAppointment()
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const _DoctorIconAvatar(size: 56),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appointment.doctorName,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: const Color(0xFF1D2E4A),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              appointment.departmentName,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: const Color(0xFF68768D),
                                    fontSize: 14,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_friendlyDate(appointment.startAt)} - ${_time(appointment.startAt)}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: const Color(0xFF2C7DF7),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF8B97AA),
                        size: 28,
                      ),
                    ],
                  ),
      ),
    );
  }

  PatientAppointment? _nextAppointment(List<PatientAppointment> appointments) {
    final now = DateTime.now();
    final upcoming = appointments.where((item) => item.isUpcoming && item.endAt.isAfter(now)).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return upcoming.isEmpty ? null : upcoming.first;
  }
}

class _EmptyUpcomingAppointment extends StatelessWidget {
  const _EmptyUpcomingAppointment();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: Color(0xFFEAF2FF),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.event_note_rounded, color: Color(0xFF2C7DF7)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'No upcoming appointment yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF1D2E4A),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFF8B97AA),
          size: 28,
        ),
      ],
    );
  }
}

class _DoctorIconAvatar extends StatelessWidget {
  const _DoctorIconAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFEAF4FF),
        shape: BoxShape.circle,
      ),
      padding: EdgeInsets.all(size * 0.16),
      child: Image.asset(
        'assets/admin/doctor_icon.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

String _friendlyDate(DateTime value) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(value.year, value.month, value.day);
  final monthDay = '${_month(value.month)} ${value.day}';
  if (target == today) {
    return 'Today, $monthDay';
  }
  if (target == today.add(const Duration(days: 1))) {
    return 'Tomorrow, $monthDay';
  }
  return '$monthDay, ${value.year}';
}

String _time(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _month(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[month - 1];
}

String _doctorValueOrFallback(String? value, String fallback) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return fallback;
  }
  return trimmed;
}

class _PatientBottomNavigation extends StatelessWidget {
  const _PatientBottomNavigation({
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = [
      _PatientNavData('Home', 'assets/nav/home_tryout.png', 1.15),
      _PatientNavData(
        'Appointments',
        'assets/nav/appointments_tryout.png',
        1.28,
      ),
      _PatientNavData('FAQ', 'assets/nav/faq_tryout.png', 1.22),
      _PatientNavData('Profile', 'assets/nav/profile_boy_tryout.png', 1),
    ];

    return NavigationBarTheme(
      data: NavigationBarThemeData(
        height: 74,
        backgroundColor: Colors.white,
        elevation: 0,
        indicatorColor: const Color(0xFFE8F3FF),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? const Color(0xFF153B74) : const Color(0xFF5D6B82),
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onSelected,
        destinations: [
          for (final item in items)
            NavigationDestination(
              icon: _PatientNavIcon(data: item),
              selectedIcon: _PatientNavIcon(data: item, selected: true),
              label: item.label,
            ),
        ],
      ),
    );
  }
}

class _PatientNavIcon extends StatelessWidget {
  const _PatientNavIcon({required this.data, this.selected = false});

  final _PatientNavData data;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final size = data.label == 'Profile' ? 28.8 : 26.0 * data.scale;

    return SizedBox(
      width: 32,
      height: 32,
      child: Center(
        child: Image.asset(
          data.iconPath,
          width: selected ? size : size * 0.96,
          height: selected ? size : size * 0.96,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _PatientComingSoonPage extends StatelessWidget {
  const _PatientComingSoonPage({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF5FAFF), Color(0xFFEAF4FF), Color(0xFFFDFEFF)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AuthLogoMark(size: 62, padding: EdgeInsets.all(10)),
              const Spacer(),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AuthColors.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: AuthColors.blue, size: 46),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AuthColors.navy,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AuthColors.textMuted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardActionData {
  const _DashboardActionData({
    required this.title,
    required this.body,
    required this.iconPath,
    required this.color,
    this.route,
  });

  final String title;
  final String body;
  final String iconPath;
  final Color color;
  final String? route;
}

class _PatientNavData {
  const _PatientNavData(this.label, this.iconPath, this.scale);

  final String label;
  final String iconPath;
  final double scale;
}

class DoctorWorkspaceScreen extends ConsumerStatefulWidget {
  const DoctorWorkspaceScreen({super.key});

  @override
  ConsumerState<DoctorWorkspaceScreen> createState() =>
      _DoctorWorkspaceScreenState();
}

class _DoctorWorkspaceScreenState extends ConsumerState<DoctorWorkspaceScreen> {
  int _currentIndex = 0;
  int _dashboardRefreshSeed = 0;
  int _scheduleRefreshSeed = 0;
  int _alertsRefreshSeed = 0;

  void _openDashboard() {
    setState(() {
      _currentIndex = 0;
      _dashboardRefreshSeed++;
    });
  }

  void _openSchedule() {
    setState(() {
      _currentIndex = 1;
      _scheduleRefreshSeed++;
    });
  }

  void _openAlerts() {
    setState(() {
      _currentIndex = 2;
      _alertsRefreshSeed++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(appSessionProvider);

    return sessionAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFFF4F8FF),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => _DoctorWorkspaceErrorState(
        message: 'We could not load the doctor workspace right now.',
        onRetry: () => ref.invalidate(appSessionProvider),
        onSignOut: () => ref.read(authRepositoryProvider).signOut(),
      ),
      data: (session) {
        if (session.status != AppSessionStatus.authenticated ||
            session.profile == null) {
          return _DoctorWorkspaceErrorState(
            message:
                session.message ?? 'We could not load the doctor workspace right now.',
            onRetry: () => ref.invalidate(appSessionProvider),
            onSignOut: () => ref.read(authRepositoryProvider).signOut(),
          );
        }

        final profile = session.profile!;

        return Scaffold(
          backgroundColor: const Color(0xFFF4F8FF),
          body: IndexedStack(
            index: _currentIndex,
            children: [
              _DoctorDashboardTab(
                key: ValueKey(_dashboardRefreshSeed),
                doctorId: profile.userId,
                doctorName: profile.fullName,
                doctorGender: profile.gender,
                departmentName: profile.departmentId ?? 'Department',
                specialty: profile.specialization ?? profile.title ?? 'Doctor',
                onOpenSchedule: _openSchedule,
                onDashboardRefresh: _openDashboard,
              ),
              DoctorScheduleScreen(
                doctorId: profile.userId,
                refreshSeed: _scheduleRefreshSeed,
              ),
              DoctorAlertsScreen(
                key: ValueKey(_alertsRefreshSeed),
                refreshSeed: _alertsRefreshSeed,
              ),
              _DoctorProfileTab(
                profile: profile,
                email: session.user?.email,
                onSignOut: () => ref.read(authRepositoryProvider).signOut(),
              ),
            ],
          ),
          bottomNavigationBar: _DoctorBottomNavigation(
            currentIndex: _currentIndex,
            gender: profile.gender,
            onSelected: (index) {
              if (index == 0) {
                _openDashboard();
              } else if (index == 1) {
                _openSchedule();
              } else if (index == 2) {
                _openAlerts();
              } else {
                setState(() => _currentIndex = 3);
              }
            },
          ),
        );
      },
    );
  }
}

class _DoctorDashboardTab extends ConsumerStatefulWidget {
  const _DoctorDashboardTab({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.doctorGender,
    required this.departmentName,
    required this.specialty,
    required this.onOpenSchedule,
    required this.onDashboardRefresh,
  });

  final String doctorId;
  final String doctorName;
  final String? doctorGender;
  final String departmentName;
  final String specialty;
  final VoidCallback onOpenSchedule;
  final VoidCallback onDashboardRefresh;

  @override
  ConsumerState<_DoctorDashboardTab> createState() => _DoctorDashboardTabState();
}

class _DoctorDashboardTabState extends ConsumerState<_DoctorDashboardTab> {
  List<DoctorWorkspaceAppointment>? _appointments;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final cached = ref.read(doctorWorkspaceRepositoryProvider).cachedData;
    _appointments = cached?.appointments;
    _loading = cached == null;
    _load(showRefresh: cached != null);
  }

  @override
  void didUpdateWidget(covariant _DoctorDashboardTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.key != widget.key) {
      _load(showRefresh: _appointments != null);
    }
  }

  Future<void> _load({bool showRefresh = false}) async {
    setState(() {
      _error = null;
      _refreshing = showRefresh;
      _loading = _appointments == null;
    });
    try {
      final data =
          await ref.read(doctorWorkspaceRepositoryProvider).fetchSchedule(widget.doctorId);
      if (!mounted) return;
      setState(() => _appointments = data.appointments);
    } catch (error) {
      if (!mounted) return;
      if (_appointments == null) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  List<DoctorWorkspaceAppointment> get _todayAppointments {
    final now = DateTime.now();
    final appointments = _appointments ?? const [];
    return appointments
        .where((item) =>
            item.scheduledFor.year == now.year &&
            item.scheduledFor.month == now.month &&
            item.scheduledFor.day == now.day)
        .toList();
  }

  List<DoctorWorkspaceAppointment> get _upcomingAppointments {
    final appointments = _appointments ?? const [];
    final visible = appointments
        .where((item) => item.isUpcoming && !item.isCancelled)
        .toList()
      ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    return visible;
  }

  @override
  Widget build(BuildContext context) {
    final appointments = _appointments;
    final todayAppointments = _todayAppointments;
    final upcoming = _upcomingAppointments;
    final bookedToday = todayAppointments.where((item) => item.status == 'booked').length;
    final cancelledToday =
        todayAppointments.where((item) => item.status == 'cancelled').length;
    final nextAppointment = upcoming.isEmpty ? null : upcoming.first;

    return Container(
      color: const Color(0xFFF4F8FF),
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _load(showRefresh: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            children: [
              if (_refreshing && appointments != null) ...[
                const LinearProgressIndicator(
                  minHeight: 3,
                  color: Color(0xFF2C7DF7),
                  backgroundColor: Color(0xFFDCE8FF),
                ),
                const SizedBox(height: 14),
              ],
              if (_loading && appointments == null)
                const SizedBox(
                  height: 320,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null && appointments == null)
                _DoctorWorkspaceErrorState(
                  message: _error ?? 'We could not load the doctor workspace right now.',
                  onRetry: () => _load(),
                  onSignOut: () => ref.read(authRepositoryProvider).signOut(),
                  compact: true,
                )
              else ...[
                SizedBox(
                  height: 332,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Positioned(
                        top: 0,
                        left: -96,
                        right: -96,
                        child: _DoctorTopBlueBackdrop(),
                      ),
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _DoctorCompactBrand(),
                              const SizedBox(height: 18),
                              _DoctorHeroCard(
                                doctorName: widget.doctorName,
                                doctorGender: widget.doctorGender,
                                departmentName: widget.departmentName,
                                specialty: widget.specialty,
                                onOpenSchedule: widget.onOpenSchedule,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _DoctorMetricCard(
                        tint: const Color(0xFFEAF2FF),
                        iconPath: 'assets/nav/dashboard_calendar.png',
                        value: bookedToday.toString(),
                        label: 'Booked Today',
                        accent: const Color(0xFF2C7DF7),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _DoctorMetricCard(
                        tint: const Color(0xFFFFF4E7),
                        iconPath: 'assets/doctor_nav/cancelled_calendar.png',
                        value: cancelledToday.toString(),
                        label: 'Cancelled',
                        accent: const Color(0xFFB54708),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Next Appointment',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF1B2A46),
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                _NextDoctorAppointmentCard(appointment: nextAppointment),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorTopBlueBackdrop extends StatelessWidget {
  const _DoctorTopBlueBackdrop();

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _DoctorBottomEllipseClipper(),
      child: Container(height: 244, color: const Color(0xFF5E9DFF)),
    );
  }
}

class _DoctorBottomEllipseClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - 104)
      ..quadraticBezierTo(
        size.width / 2,
        size.height + 118,
        size.width,
        size.height - 104,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _DoctorCompactBrand extends StatelessWidget {
  const _DoctorCompactBrand();

  @override
  Widget build(BuildContext context) {
    return const AuthLogoMark(size: 62, padding: EdgeInsets.all(10));
  }
}

class _DoctorHeroCard extends StatelessWidget {
  const _DoctorHeroCard({
    required this.doctorName,
    required this.doctorGender,
    required this.departmentName,
    required this.specialty,
    required this.onOpenSchedule,
  });

  final String doctorName;
  final String? doctorGender;
  final String departmentName;
  final String specialty;
  final VoidCallback onOpenSchedule;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F3FE),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -22,
              top: -24,
              width: 132,
              height: 132,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF7FB0FF).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -18,
              bottom: -26,
              width: 116,
              height: 116,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Doctor Workspace',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: const Color(0xFF4F6D93),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Welcome!\n$doctorName',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: const Color(0xFF183153),
                              fontWeight: FontWeight.w900,
                              height: 1.02,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$specialty | $departmentName',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF4F6D93),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: onOpenSchedule,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2C7DF7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 12,
                          ),
                          shape: const StadiumBorder(),
                          textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        child: const Text('Open My Schedule'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Align(
                  alignment: Alignment.topRight,
                  child: SizedBox(
                    width: 118,
                    height: 156,
                    child: Image.asset(
                      'assets/home/female_doctor.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.centerRight,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorMetricCard extends StatelessWidget {
  const _DoctorMetricCard({
    required this.tint,
    required this.iconPath,
    required this.value,
    required this.label,
    required this.accent,
  });

  final Color tint;
  final String iconPath;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: Image.asset(
                iconPath,
                width: 34,
                height: 34,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5D6B82),
                ),
          ),
        ],
      ),
    );
  }
}

class _NextDoctorAppointmentCard extends StatelessWidget {
  const _NextDoctorAppointmentCard({required this.appointment});

  final DoctorWorkspaceAppointment? appointment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: appointment == null
          ? Text(
              'No active upcoming appointments yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5D6B82),
                  ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                RepaintBoundary(
                  child: _PortraitImage(
                    gender: appointment!.patientGender,
                    width: 56,
                    height: 56,
                    fallbackBackground: const Color(0xFFD7E7FF),
                    fallbackColor: const Color(0xFF2C7DF7),
                    fallbackIconSize: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _doctorValueOrFallback(
                          appointment!.patientName,
                          'Patient',
                        ),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: const Color(0xFF153B74),
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appointment!.departmentName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF5D6B82),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_friendlyDate(appointment!.scheduledFor)} | ${_time(appointment!.scheduledFor)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF183153),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _PortraitImage extends StatelessWidget {
  const _PortraitImage({
    required this.gender,
    required this.width,
    required this.height,
    required this.fallbackBackground,
    required this.fallbackColor,
    required this.fallbackIconSize,
  });

  final String? gender;
  final double width;
  final double height;
  final Color fallbackBackground;
  final Color fallbackColor;
  final double fallbackIconSize;

  @override
  Widget build(BuildContext context) {
    final normalized = gender?.trim().toLowerCase();
    final asset = switch (normalized) {
      'male' => 'assets/nav/profile_boy_tryout.png',
      'female' => 'assets/nav/profile_girl_tryout.png',
      _ => null,
    };

    if (asset == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: fallbackBackground,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person_rounded,
          color: fallbackColor,
          size: fallbackIconSize,
        ),
      );
    }

    return ClipOval(
      child: Image.asset(
        asset,
        width: width,
        height: height,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _DoctorBottomNavigation extends StatelessWidget {
  const _DoctorBottomNavigation({
    required this.currentIndex,
    required this.gender,
    required this.onSelected,
  });

  final int currentIndex;
  final String? gender;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        height: 74,
        backgroundColor: Colors.white,
        elevation: 0,
        indicatorColor: const Color(0xFFE7F1FF),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color:
                selected ? const Color(0xFF153B74) : const Color(0xFF5D6B82),
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onSelected,
        destinations: [
          _DoctorNavDestination(
            label: 'Dashboard',
            iconBuilder: () => Image.asset(
              'assets/doctor_nav/dashboard.png',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
            ),
          ),
          _DoctorNavDestination(
            label: 'Schedule',
            iconBuilder: () => Image.asset(
              'assets/doctor_nav/schedule.png',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
            ),
          ),
          _DoctorNavDestination(
            label: 'Alerts',
            iconBuilder: () => Image.asset(
              'assets/doctor_nav/alerts.png',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
            ),
          ),
          _DoctorNavDestination(
            label: 'Profile',
            iconBuilder: () => _DoctorProfileNavIcon(gender: gender),
          ),
        ],
      ),
    );
  }
}

class _DoctorNavDestination extends NavigationDestination {
  _DoctorNavDestination({
    required super.label,
    required Widget Function() iconBuilder,
  }) : super(
          icon: _DoctorNavIconWrapper(builder: iconBuilder),
          selectedIcon: _DoctorNavIconWrapper(builder: iconBuilder),
        );
}

class _DoctorNavIconWrapper extends StatelessWidget {
  const _DoctorNavIconWrapper({required this.builder});

  final Widget Function() builder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 32, height: 32, child: Center(child: builder()));
  }
}

class _DoctorProfileNavIcon extends StatelessWidget {
  const _DoctorProfileNavIcon({required this.gender});

  final String? gender;

  @override
  Widget build(BuildContext context) {
    final normalized = gender?.trim().toLowerCase();
    final asset = switch (normalized) {
      'male' => 'assets/nav/profile_boy_tryout.png',
      'female' => 'assets/nav/profile_girl_tryout.png',
      _ => null,
    };
    if (asset == null) {
      return const Icon(Icons.person_rounded, size: 24, color: Color(0xFF5D6B82));
    }
    return Image.asset(asset, width: 28.8, height: 28.8, fit: BoxFit.contain);
  }
}

class _DoctorProfileTab extends StatelessWidget {
  const _DoctorProfileTab({
    required this.profile,
    required this.onSignOut,
    this.email,
  });

  final SessionProfile profile;
  final String? email;
  final VoidCallback onSignOut;

  String _profileValue(String? value, String fallback) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final specialty = _profileValue(profile.specialization, 'Doctor');
    final bio = profile.bio?.trim();

    return SafeArea(
      child: ListView(
        key: const PageStorageKey<String>('doctor-profile-tab-view'),
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: _DoctorProfilePortrait(gender: profile.gender),
                ),
                const SizedBox(height: 16),
                Text(
                  _profileValue(profile.fullName, 'Doctor'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: const Color(0xFF153B74),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  specialty,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5D6B82),
                      ),
                ),
                const SizedBox(height: 24),
                _DoctorProfileLine(
                  label: 'Department',
                  value: _profileValue(profile.departmentId, 'Not set'),
                ),
                _DoctorProfileLine(
                  label: 'Email',
                  value: _profileValue(email, 'Not provided'),
                ),
                _DoctorProfileLine(
                  label: 'Phone',
                  value: _profileValue(profile.phoneNumber, 'Not provided'),
                ),
                _DoctorProfileLine(
                  label: 'Consultation Mode',
                  value: _profileValue(profile.consultationMode, 'Not set'),
                ),
                _DoctorProfileLine(
                  label: 'Experience',
                  value: profile.yearsOfExperience == null
                      ? 'Not set'
                      : '${profile.yearsOfExperience} years',
                ),
                if (bio != null && bio.isNotEmpty)
                  _DoctorProfileLine(label: 'Bio', value: bio),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF153B74),
                    side: const BorderSide(color: Color(0xFFD6E0EE)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorProfilePortrait extends StatelessWidget {
  const _DoctorProfilePortrait({required this.gender});

  final String? gender;

  @override
  Widget build(BuildContext context) {
    final normalized = gender?.trim().toLowerCase();
    final asset = switch (normalized) {
      'male' => 'assets/profile/boy_3d.png',
      'female' => 'assets/profile/girl_3d.png',
      _ => null,
    };

    if (asset == null) {
      return const SizedBox(
        width: 90,
        height: 90,
        child: Icon(
          Icons.person_rounded,
          color: Color(0xFF2C7DF7),
          size: 56,
        ),
      );
    }

    return Image.asset(
      asset,
      width: 90,
      height: 90,
      fit: BoxFit.contain,
    );
  }
}

class _DoctorProfileLine extends StatelessWidget {
  const _DoctorProfileLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5D6B82),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF183153),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _DoctorWorkspaceErrorState extends StatelessWidget {
  const _DoctorWorkspaceErrorState({
    required this.message,
    required this.onRetry,
    required this.onSignOut,
    this.compact = false,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline_rounded, size: 46, color: Color(0xFFB42318)),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5D6B82),
                height: 1.45,
              ),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
        const SizedBox(height: 10),
        TextButton(
          onPressed: onSignOut,
          child: const Text('Sign out'),
        ),
      ],
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: content),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: content,
          ),
        ),
      ),
    );
  }
}

class AdminWorkspaceScreen extends ConsumerWidget {
  const AdminWorkspaceScreen({super.key});

  static const _operations = <_AdminOperationData>[
    _AdminOperationData(
      title: 'Departments',
      description: 'Create and update care units',
      background: Color(0xFFEAF2FF),
      icon: Icons.apartment_rounded,
      route: '/admin/departments',
    ),
    _AdminOperationData(
      title: 'Doctors',
      description: 'Manage doctors and linked accounts',
      background: Color(0xFFFFF3E7),
      assetPath: 'assets/admin/doctor_icon.png',
      route: '/admin/doctors',
    ),
    _AdminOperationData(
      title: 'Users',
      description: 'Review and manage app accounts',
      background: Color(0xFFEAF4FF),
      assetPath: 'assets/admin/manage_users_icon.png',
      route: '/admin/users',
    ),
    _AdminOperationData(
      title: 'Availability',
      description: 'Create and update doctor slots',
      background: Color(0xFFE9F9F1),
      assetPath: 'assets/admin/availability_icon.png',
      route: '/admin/availability-slots',
    ),
    _AdminOperationData(
      title: 'Appointments',
      description: 'Monitor bookings and schedules',
      background: Color(0xFFF1EDFF),
      assetPath: 'assets/nav/dashboard_calendar.png',
      route: '/admin/appointments',
    ),
    _AdminOperationData(
      title: 'Hospital Info',
      description: 'Update contacts and hospital details',
      background: Color(0xFFEAF4FF),
      assetPath: 'assets/nav/file_icon.png',
      route: '/admin/hospital-info',
    ),
    _AdminOperationData(
      title: 'FAQ',
      description: 'Manage common patient questions',
      background: Color(0xFFFFF7EA),
      assetPath: 'assets/nav/faq_tryout.png',
      route: '/admin/faq',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider).valueOrNull;
    final displayName = _adminDisplayName(session);
    final accountEmail = _adminAccountEmail(session);
    final mediaQuery = MediaQuery.of(context);

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: TextScaler.linear(1)),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FF),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Positioned(
                    left: -36,
                    right: -36,
                    top: -14,
                    child: _AdminSwirlBand(),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AuthLogoMark(size: 62, padding: EdgeInsets.all(10)),
                      const SizedBox(height: 18),
                      _AdminHeroCard(displayName: displayName),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Core Operations',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF153B74),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose the area you want to manage.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5D6B82),
                    ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final singleColumn = constraints.maxWidth < 300;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _operations.length,
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: singleColumn ? 420 : 210,
                      mainAxisExtent: singleColumn ? 158 : 176,
                      mainAxisSpacing: singleColumn ? 12 : 14,
                      crossAxisSpacing: 14,
                    ),
                    itemBuilder: (context, index) {
                      final operation = _operations[index];
                      return _AdminOperationCard(operation: operation);
                    },
                  );
                },
              ),
              const SizedBox(height: 22),
              _AdminAccountCard(
                email: accountEmail,
                onSignOut: () => ref.read(authRepositoryProvider).signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _adminDisplayName(AppSession? session) {
    final fullName = session?.profile?.fullName.trim();
    if (fullName != null && fullName.isNotEmpty) return fullName;
    final email = session?.user?.email.trim();
    if (email != null && email.isNotEmpty) return email;
    return 'Admin';
  }

  String _adminAccountEmail(AppSession? session) {
    final email = session?.user?.email.trim();
    if (email != null && email.isNotEmpty) return email;
    return 'Admin account';
  }
}

class AdminPlaceholderScreen extends StatelessWidget {
  const AdminPlaceholderScreen({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5D6B82),
                      height: 1.45,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminSwirlBand extends StatelessWidget {
  const _AdminSwirlBand();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipPath(
            clipper: const _AdminEllipseClipper(radius: 70),
            child: Container(height: 250, color: const Color(0xFF5E95F5)),
          ),
          Positioned(
            left: -34,
            right: -34,
            bottom: 26,
            child: ClipPath(
              clipper: const _AdminEllipseClipper(radius: 74),
              child: Container(
                height: 104,
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminEllipseClipper extends CustomClipper<Path> {
  const _AdminEllipseClipper({required this.radius});

  final double radius;

  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - radius)
      ..quadraticBezierTo(
        size.width / 2,
        size.height + radius,
        size.width,
        size.height - radius,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant _AdminEllipseClipper oldClipper) {
    return oldClipper.radius != radius;
  }
}

class _AdminHeroCard extends StatelessWidget {
  const _AdminHeroCard({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 360;
        final titleSize = stacked ? 24.0 : 30.0;
        final textBlock = _AdminHeroText(
          displayName: displayName,
          titleSize: titleSize,
        );
        final illustration = _AdminHeroIllustration(
          compact: stacked,
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            color: const Color(0xFFE5F3FE),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    textBlock,
                    const SizedBox(height: 14),
                    Align(alignment: Alignment.centerRight, child: illustration),
                  ],
                )
              : SizedBox(
                  height: 210,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: illustration,
                      ),
                      Positioned.fill(
                        right: 126,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: textBlock,
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _AdminHeroText extends StatelessWidget {
  const _AdminHeroText({
    required this.displayName,
    required this.titleSize,
  });

  final String displayName;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Admin Workspace',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: const Color(0xFF153B74),
                fontSize: titleSize,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          'Manage hospital operations, staff, schedules, appointments, and patient-facing content.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5D6B82),
                height: 1.45,
              ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Signed in as $displayName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF153B74),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _AdminHeroIllustration extends StatelessWidget {
  const _AdminHeroIllustration({
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 106 : 116,
      height: compact ? 130 : 142,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Image.asset(
        'assets/home/female_doctor.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

class _AdminOperationCard extends StatelessWidget {
  const _AdminOperationCard({required this.operation});

  final _AdminOperationData operation;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: operation.background,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => context.push(operation.route),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: operation.assetPath == null
                      ? Icon(
                          operation.icon!,
                          size: 32,
                          color: const Color(0xFF2C7DF7),
                        )
                      : Image.asset(
                          operation.assetPath!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
              const Spacer(),
              Text(
                operation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF153B74),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                operation.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF5D6B82),
                      height: 1.35,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminAccountCard extends StatelessWidget {
  const _AdminAccountCard({
    required this.email,
    required this.onSignOut,
  });

  final String email;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 340;
          final info = _AdminAccountInfo(email: email, stacked: stacked);
          final button = FilledButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign Out'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 50),
              backgroundColor: const Color(0xFFE8EEF8),
              foregroundColor: const Color(0xFF153B74),
              elevation: 0,
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: 16),
                button,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 14),
              button,
            ],
          );
        },
      ),
    );
  }
}

class _AdminAccountInfo extends StatelessWidget {
  const _AdminAccountInfo({
    required this.email,
    required this.stacked,
  });

  final String email;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.admin_panel_settings_rounded,
            color: Color(0xFF2C7DF7),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF153B74),
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                email,
                maxLines: stacked ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5D6B82),
                      height: 1.35,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminOperationData {
  const _AdminOperationData({
    required this.title,
    required this.description,
    required this.background,
    required this.route,
    this.icon,
    this.assetPath,
  });

  final String title;
  final String description;
  final Color background;
  final String route;
  final IconData? icon;
  final String? assetPath;
}
