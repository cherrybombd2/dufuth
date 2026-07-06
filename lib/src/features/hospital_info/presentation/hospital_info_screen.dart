import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hospital_info_repository.dart';
import '../domain/hospital_info.dart';

class HospitalInfoScreen extends ConsumerStatefulWidget {
  const HospitalInfoScreen({super.key});

  @override
  ConsumerState<HospitalInfoScreen> createState() => _HospitalInfoScreenState();
}

class _HospitalInfoScreenState extends ConsumerState<HospitalInfoScreen> {
  HospitalInfo? _info;
  String? _error;
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    final cached = ref.read(hospitalInfoRepositoryProvider).cachedInfo;
    _info = cached;
    _loading = cached == null;
    _load(showRefresh: cached != null);
  }

  Future<void> _load({bool showRefresh = false}) async {
    setState(() {
      _error = null;
      _refreshing = showRefresh;
      _loading = _info == null;
    });

    try {
      final info = await ref.read(hospitalInfoRepositoryProvider).fetch();
      if (!mounted) return;
      setState(() => _info = info);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(title: const Text('Hospital Info')),
      body: SafeArea(
        top: false,
        child: Builder(
          builder: (context) {
            if (_loading && info == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_error != null && info == null) {
              return _FullErrorState(message: _error!, onRetry: () => _load());
            }

            return RefreshIndicator(
              onRefresh: () => _load(showRefresh: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                children: [
                  if (_refreshing) ...[
                    const LinearProgressIndicator(
                      minHeight: 3,
                      color: Color(0xFF2C7DF7),
                      backgroundColor: Color(0xFFDCE8FF),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _HospitalHeroCard(info: info!),
                  const SizedBox(height: 18),
                  _ContentCard(
                    title: 'About',
                    iconPath: 'assets/nav/file_icon.png',
                    child: Text(
                      _valueOrFallback(
                        info.about,
                        'Hospital background and patient-facing information will appear here.',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5D6B82),
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ContentCard(
                    title: 'Contact',
                    iconPath: 'assets/hospital_info/phone.png',
                    child: Column(
                      children: [
                        _InfoLine(label: 'Phone: ', value: info.phone),
                        _InfoLine(label: 'Email: ', value: info.email),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ContentCard(
                    title: 'Hours',
                    iconPath: 'assets/hospital_info/clock.png',
                    child: Column(
                      children: [
                        _InfoLine(
                          label: 'Working Hours: ',
                          value: info.workingHours,
                        ),
                        _InfoLine(
                          label: 'Visiting Hours: ',
                          value: info.visitingHours,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ContentCard(
                    title: 'Location',
                    iconPath: 'assets/hospital_info/map_pin.png',
                    child: Column(
                      children: [
                        _InfoLine(label: 'Address: ', value: info.address),
                        _InfoLine(label: 'Website: ', value: info.website),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HospitalHeroCard extends StatelessWidget {
  const _HospitalHeroCard({required this.info});

  final HospitalInfo info;

  @override
  Widget build(BuildContext context) {
    final tagline = info.tagline?.trim();
    final notice = info.patientNotice?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C7DF7), Color(0xFF89B9FF)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info.hospitalName,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (tagline != null && tagline.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              tagline,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (notice != null && notice.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                notice,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({
    required this.title,
    required this.iconPath,
    required this.child,
  });

  final String title;
  final String iconPath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: Center(
                  child: Image.asset(
                    iconPath,
                    width: 34,
                    height: 34,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF153B74),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF5D6B82),
            fontSize: 14,
            height: 1.45,
          ),
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(
                color: Color(0xFF153B74),
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: _valueOrFallback(value, 'Not provided yet')),
          ],
        ),
      ),
    );
  }
}

class _FullErrorState extends StatelessWidget {
  const _FullErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFB42318),
              size: 46,
            ),
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
          ],
        ),
      ),
    );
  }
}

String _valueOrFallback(String? value, String fallback) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return fallback;
  }
  return trimmed;
}
