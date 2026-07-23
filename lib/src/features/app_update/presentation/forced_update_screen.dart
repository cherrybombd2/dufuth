import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/presentation/auth_ui.dart';
import '../data/app_update_repository.dart';

class ForcedUpdateScreen extends StatelessWidget {
  const ForcedUpdateScreen({
    required this.result,
    super.key,
  });

  final AppUpdateGateResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final policy = result.policy;

    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFDCE7F6)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x100A67D8),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF4FF),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.system_update_alt_rounded,
                          color: AuthColors.blue,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Update required',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: AuthColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        policy?.message ??
                            'Please update DUFUTH SmartCare to continue.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AuthColors.textMuted,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Installed: ${result.installedVersion}'
                        '  -  Required: ${policy?.minimumRequiredVersion ?? '-'}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AuthColors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: () => _openDownload(policy?.downloadUrl),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Update App'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AuthColors.button,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDownload(String? downloadUrl) async {
    final uri = Uri.tryParse(
      downloadUrl ?? 'https://dufuth-smartcare-download.netlify.app/',
    );
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
