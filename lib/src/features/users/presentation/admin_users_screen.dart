import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_users_repository.dart';

const _pageBg = Color(0xFFF4F8FF);
const _primaryBlue = Color(0xFF2C7DF7);
const _darkBlue = Color(0xFF153B74);
const _mutedText = Color(0xFF5D6B82);
const _softBorder = Color(0xFFD6E0EE);
const _progressBg = Color(0xFFDCE8FF);
const _successBg = Color(0xFFE8FBF4);
const _successText = Color(0xFF067647);
const _errorBg = Color(0xFFFEE4E2);
const _errorText = Color(0xFFB42318);

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _searchController = TextEditingController();

  AdminUsersData? _data;
  String? _loadError;
  String? _selectedRole;
  String? _selectedStatus;
  String? _message;
  bool _messageIsSuccess = true;
  bool _loading = true;
  bool _refreshing = false;
  String? _savingUserId;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    final cached = ref.read(adminUsersRepositoryProvider).cachedData;
    _data = cached;
    _loading = cached == null;
    _load(showRefresh: cached != null);
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  AdminUserFilters get _filters => AdminUserFilters(
    role: _selectedRole,
    status: _selectedStatus,
    query: _searchController.text,
  );

  Future<void> _load({bool showRefresh = false}) async {
    setState(() {
      _loadError = null;
      _refreshing = showRefresh;
      _loading = _data == null;
    });

    try {
      final data = await ref.read(adminUsersRepositoryProvider).fetch(_filters);
      if (!mounted) return;
      setState(() => _data = data);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  void _showMessage(String message, {required bool success}) {
    _messageTimer?.cancel();
    setState(() {
      _message = message;
      _messageIsSuccess = success;
    });
    _messageTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _message = null);
      }
    });
  }

  Future<void> _confirmStatusChange(
    AdminUserAccount user,
    String nextStatus,
  ) async {
    final activating = nextStatus == 'active';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(activating ? 'Activate User?' : 'Deactivate User?'),
        content: Text(
          activating
              ? '${user.displayName} will regain access to DUFUTH SmartCare.'
              : '${user.displayName} will no longer be able to access DUFUTH SmartCare until reactivated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: activating ? _primaryBlue : _errorText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(activating ? 'Activate' : 'Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _setStatus(user, nextStatus);
  }

  Future<void> _setStatus(AdminUserAccount user, String nextStatus) async {
    setState(() {
      _savingUserId = user.uid;
      _message = null;
    });

    try {
      await ref.read(adminUsersRepositoryProvider).updateStatus(
        userId: user.uid,
        status: nextStatus,
      );
      await _load(showRefresh: true);
      _showMessage(
        nextStatus == 'active'
            ? 'User activated successfully.'
            : 'User deactivated successfully.',
        success: true,
      );
    } catch (error) {
      _showMessage(error.toString(), success: false);
    } finally {
      if (mounted) {
        setState(() => _savingUserId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(title: const Text('Manage Users')),
      body: SafeArea(
        child: data == null && _loading
            ? const Center(child: CircularProgressIndicator())
            : data == null && _loadError != null
                ? _FullErrorState(
                    message: _loadError ?? 'We could not load users right now.',
                    onRetry: () => _load(),
                  )
                : RefreshIndicator(
                    onRefresh: () => _load(showRefresh: _data != null),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
                      children: [
                        if (_refreshing) ...[
                          const LinearProgressIndicator(
                            minHeight: 3,
                            color: _primaryBlue,
                            backgroundColor: _progressBg,
                          ),
                          const SizedBox(height: 14),
                        ],
                        const _HeaderCard(),
                        const SizedBox(height: 14),
                        _FiltersCard(
                          searchController: _searchController,
                          role: _selectedRole,
                          status: _selectedStatus,
                          onSearch: () => _load(showRefresh: _data != null),
                          onRoleChanged: (value) {
                            setState(() => _selectedRole = value);
                            _load(showRefresh: _data != null);
                          },
                          onStatusChanged: (value) {
                            setState(() => _selectedStatus = value);
                            _load(showRefresh: _data != null);
                          },
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 14),
                          _StatusBanner(
                            message: _message!,
                            success: _messageIsSuccess,
                          ),
                        ],
                        const SizedBox(height: 20),
                        if ((data?.users ?? []).isEmpty)
                          const _EmptyState()
                        else
                          ...data!.users.map(
                            (user) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _UserCard(
                                user: user,
                                isCurrentAdmin: user.uid == data.currentUserId,
                                isSaving: _savingUserId == user.uid,
                                onActivate: () =>
                                    _confirmStatusChange(user, 'active'),
                                onDeactivate: () =>
                                    _confirmStatusChange(user, 'inactive'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Image.asset(
              'assets/admin/manage_users_icon.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Users',
                  style: TextStyle(
                    color: _darkBlue,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Review patient, doctor, and admin accounts. Activate or deactivate access where appropriate.',
                  style: TextStyle(
                    color: _mutedText,
                    fontSize: 14,
                    height: 1.45,
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

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.searchController,
    required this.role,
    required this.status,
    required this.onSearch,
    required this.onRoleChanged,
    required this.onStatusChanged,
  });

  final TextEditingController searchController;
  final String? role;
  final String? status;
  final VoidCallback onSearch;
  final ValueChanged<String?> onRoleChanged;
  final ValueChanged<String?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters',
            style: TextStyle(
              color: _darkBlue,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearch(),
            decoration: _inputDecoration(
              'Search by name, email, or phone',
              suffixIcon: IconButton(
                tooltip: 'Search users',
                onPressed: onSearch,
                icon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _DropdownField(
            label: 'Role',
            value: role ?? '',
            items: const [
              DropdownMenuItem(value: '', child: Text('All Roles')),
              DropdownMenuItem(value: 'patient', child: Text('Patient')),
              DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
            ],
            onChanged: (value) => onRoleChanged(value?.isEmpty == true ? null : value),
          ),
          const SizedBox(height: 14),
          _DropdownField(
            label: 'Status',
            value: status ?? '',
            items: const [
              DropdownMenuItem(value: '', child: Text('All Statuses')),
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
            ],
            onChanged: (value) =>
                onStatusChanged(value?.isEmpty == true ? null : value),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.isCurrentAdmin,
    required this.isSaving,
    required this.onActivate,
    required this.onDeactivate,
  });

  final AdminUserAccount user;
  final bool isCurrentAdmin;
  final bool isSaving;
  final VoidCallback onActivate;
  final VoidCallback onDeactivate;

  bool get _isAdmin => user.role == 'admin';

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(
                        color: _darkBlue,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if ((user.email ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        user.email!,
                        style: const TextStyle(color: _mutedText, fontSize: 14),
                      ),
                    ],
                    if ((user.phone ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        user.phone!,
                        style: const TextStyle(color: _mutedText, fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusPill(status: user.status),
                  const SizedBox(height: 8),
                  _RolePill(role: user.role),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isCurrentAdmin)
            const _HelperLine('This is the admin account currently in use.')
          else if (_isAdmin)
            const _HelperLine('Admin accounts stay managed outside this screen.')
          else
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: isSaving ? 'Saving...' : 'Activate',
                    enabled: !isSaving && !user.isActive,
                    positive: true,
                    onPressed: onActivate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    label: isSaving ? 'Saving...' : 'Deactivate',
                    enabled: !isSaving && user.isActive,
                    positive: false,
                    onPressed: onDeactivate,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final active = status == 'active';
    return _Pill(
      label: active ? 'ACTIVE' : 'INACTIVE',
      background: active ? _successBg : _errorBg,
      foreground: active ? _successText : _errorText,
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final colors = switch (role) {
      'doctor' => (const Color(0xFFEAF2FF), _primaryBlue),
      'admin' => (const Color(0xFFF1EDFF), const Color(0xFF6941C6)),
      _ => (const Color(0xFFFFF3E7), const Color(0xFFB54708)),
    };
    return _Pill(
      label: role.toUpperCase(),
      background: colors.$1,
      foreground: colors.$2,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.enabled,
    required this.positive,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final bool positive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: positive ? _successBg : const Color(0xFFFFF0F0),
        foregroundColor: positive ? _successText : _errorText,
        disabledForegroundColor: _mutedText,
        side: BorderSide(
          color: positive ? const Color(0xFFA6F4C5) : const Color(0xFFFDB0AC),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _HelperLine extends StatelessWidget {
  const _HelperLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: _mutedText, fontSize: 13, height: 1.35),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, required this.success});

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: success ? _successBg : _errorBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: success ? _successText : _errorText,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(22),
      child: const Column(
        children: [
          Icon(Icons.people_outline_rounded, color: _primaryBlue, size: 42),
          SizedBox(height: 12),
          Text(
            'No matching users',
            style: TextStyle(
              color: _darkBlue,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Try changing the search, role, or status filters to find accounts.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _mutedText, fontSize: 14, height: 1.4),
          ),
        ],
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: _errorText, size: 42),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _mutedText, fontSize: 14),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
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
      child: child,
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      decoration: _inputDecoration(label),
    );
  }
}

InputDecoration _inputDecoration(String label, {Widget? suffixIcon}) {
  return InputDecoration(
    labelText: label,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: _softBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: _errorText),
    ),
  );
}
