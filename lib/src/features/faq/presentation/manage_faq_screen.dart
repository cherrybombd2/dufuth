import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/faq_repository.dart';
import '../domain/faq_item.dart';

const _pageBg = Color(0xFFF4F8FF);
const _primaryBlue = Color(0xFF2C7DF7);
const _darkBlue = Color(0xFF153B74);
const _mainText = Color(0xFF183153);
const _mutedText = Color(0xFF5D6B82);
const _softBorder = Color(0xFFD6E0EE);
const _dividerBlue = Color(0xFFDCE8FF);
const _successBg = Color(0xFFE8FBF4);
const _successText = Color(0xFF067647);
const _errorBg = Color(0xFFFEE4E2);
const _errorText = Color(0xFFB42318);

class ManageFaqScreen extends ConsumerStatefulWidget {
  const ManageFaqScreen({super.key});

  @override
  ConsumerState<ManageFaqScreen> createState() => _ManageFaqScreenState();
}

class _ManageFaqScreenState extends ConsumerState<ManageFaqScreen> {
  List<FaqItem>? _items;
  String? _loadError;
  String? _statusMessage;
  bool _statusIsSuccess = false;
  bool _loading = true;
  bool _refreshing = false;
  bool _saving = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    final cached = ref.read(faqRepositoryProvider).cachedAdminItems;
    _items = cached;
    _loading = cached == null;
    _load(showRefresh: cached != null);
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool showRefresh = false}) async {
    setState(() {
      _loadError = null;
      _refreshing = showRefresh;
      _loading = _items == null;
    });

    try {
      final items = await ref.read(faqRepositoryProvider).fetchAdminItems();
      if (!mounted) return;
      setState(() => _items = items);
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

  Future<void> _openCreateDialog() async {
    final draft = await showDialog<FaqDraft>(
      context: context,
      builder: (context) => const _FaqEditorDialog(),
    );
    if (draft == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(faqRepositoryProvider).create(draft);
      await _load(showRefresh: true);
      _showStatus('FAQ item created successfully.', isSuccess: true);
    } catch (error) {
      _showStatus(error.toString(), isSuccess: false);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openEditDialog(FaqItem item) async {
    final draft = await showDialog<FaqDraft>(
      context: context,
      builder: (context) => _FaqEditorDialog(item: item),
    );
    if (draft == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(faqRepositoryProvider).update(item.id, draft);
      await _load(showRefresh: true);
      _showStatus('FAQ item updated successfully.', isSuccess: true);
    } catch (error) {
      _showStatus(error.toString(), isSuccess: false);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _toggleActive(FaqItem item) async {
    final previousItems = _items;
    final nextActive = !item.isActive;
    final optimisticItem = item.copyWith(isActive: nextActive);

    setState(() {
      _saving = true;
      _items = _items
          ?.map((current) => current.id == item.id ? optimisticItem : current)
          .toList();
    });
    _showStatus(
      nextActive
          ? 'FAQ item activated successfully.'
          : 'FAQ item hidden successfully.',
      isSuccess: true,
    );
    try {
      await ref.read(faqRepositoryProvider).setActive(item.id, nextActive);
    } catch (error) {
      if (mounted) {
        setState(() => _items = previousItems);
      }
      _showStatus(error.toString(), isSuccess: false);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showStatus(String message, {required bool isSuccess}) {
    _statusTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _statusMessage = message.isEmpty
          ? 'We could not save FAQ information right now.'
          : message;
      _statusIsSuccess = isSuccess;
    });
    _statusTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _statusMessage = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(title: const Text('Manage FAQ')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _openCreateDialog,
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add FAQ'),
      ),
      body: SafeArea(
        top: false,
        child: Builder(
          builder: (context) {
            if (_loading && items == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_loadError != null && items == null) {
              return _AdminFullErrorState(
                message: _loadError!,
                onRetry: () => _load(),
              );
            }

            return RefreshIndicator(
              onRefresh: () => _load(showRefresh: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 90),
                children: [
                  if (_refreshing) ...[
                    const LinearProgressIndicator(
                      minHeight: 3,
                      color: _primaryBlue,
                      backgroundColor: _dividerBlue,
                    ),
                    const SizedBox(height: 14),
                  ],
                  const _AdminFaqHeaderCard(),
                  const SizedBox(height: 14),
                  if (_statusMessage != null) ...[
                    _StatusBanner(
                      message: _statusMessage!,
                      isSuccess: _statusIsSuccess,
                    ),
                    const SizedBox(height: 20),
                  ] else
                    const SizedBox(height: 6),
                  if (items == null || items.isEmpty)
                    const _AdminEmptyState()
                  else
                    for (final item in items) ...[
                      _AdminFaqCard(
                        item: item,
                        onEdit: () => _openEditDialog(item),
                        onToggleActive: () => _toggleActive(item),
                      ),
                      const SizedBox(height: 14),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AdminFaqHeaderCard extends StatelessWidget {
  const _AdminFaqHeaderCard();

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
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7EA),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Image.asset('assets/nav/faq_tryout.png', fit: BoxFit.contain),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Frequently Asked Questions',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: _darkBlue,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Create and maintain the patient help answers shown in the app.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _mutedText,
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

class _AdminFaqCard extends StatelessWidget {
  const _AdminFaqCard({
    required this.item,
    required this.onEdit,
    required this.onToggleActive,
  });

  final FaqItem item;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final category = item.category?.trim();

    return Container(
      padding: const EdgeInsets.all(18),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.question,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: _darkBlue,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(width: 12),
              _StatusPill(active: item.isActive),
            ],
          ),
          if (category != null && category.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              category,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _primaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            item.answer,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _mutedText,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sort order: ${item.sortOrder}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _mutedText,
                  fontSize: 12,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Edit',
                  onPressed: onEdit,
                  background: Colors.white,
                  border: _softBorder,
                  foreground: _darkBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  label: item.isActive ? 'Hide' : 'Activate',
                  onPressed: onToggleActive,
                  background: item.isActive
                      ? const Color(0xFFFFF0F0)
                      : _successBg,
                  border: item.isActive
                      ? const Color(0xFFFDB0AC)
                      : const Color(0xFFA6F4C5),
                  foreground: item.isActive ? _errorText : _successText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    required this.background,
    required this.border,
    required this.foreground,
  });

  final String label;
  final VoidCallback onPressed;
  final Color background;
  final Color border;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? _successBg : _errorBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'ACTIVE' : 'INACTIVE',
        style: TextStyle(
          color: active ? _successText : _errorText,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FaqEditorDialog extends StatefulWidget {
  const _FaqEditorDialog({this.item});

  final FaqItem? item;

  @override
  State<_FaqEditorDialog> createState() => _FaqEditorDialogState();
}

class _FaqEditorDialogState extends State<_FaqEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _questionController;
  late final TextEditingController _answerController;
  late final TextEditingController _categoryController;
  late final TextEditingController _sortOrderController;
  late bool _isActive;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _questionController = TextEditingController(text: item?.question ?? '');
    _answerController = TextEditingController(text: item?.answer ?? '');
    _categoryController = TextEditingController(text: item?.category ?? '');
    _sortOrderController = TextEditingController(
      text: (item?.sortOrder ?? 0).toString(),
    );
    _isActive = item?.isActive ?? true;
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    _categoryController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final category = _categoryController.text.trim();
    Navigator.of(context).pop(
      FaqDraft(
        question: _questionController.text.trim(),
        answer: _answerController.text.trim(),
        category: category.isEmpty ? null : category,
        sortOrder: int.tryParse(_sortOrderController.text.trim()) ?? 0,
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: const Color(0xFFF8FCFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isEditing ? 'Edit FAQ' : 'Create FAQ',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: _darkBlue,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Write the question and answer exactly as patients should see them.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _mutedText,
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: 20),
                  _DialogSection(
                    title: 'FAQ Content',
                    description: 'Write the exact question and answer patients should read.',
                    children: [
                      TextFormField(
                        controller: _questionController,
                        decoration: _inputDecoration('Question'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter a question.'
                                : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _answerController,
                        maxLines: 4,
                        decoration: _inputDecoration('Answer'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter an answer.'
                                : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _DialogSection(
                    title: 'Organization',
                    description: 'Group related questions together and control their order.',
                    children: [
                      TextFormField(
                        controller: _categoryController,
                        decoration: _inputDecoration('Category'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _sortOrderController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                        ],
                        decoration: _inputDecoration('Sort Order'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _DialogSection(
                    title: 'Visibility',
                    description: 'Control whether this answer is shown to patients.',
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Active',
                          style: TextStyle(
                            color: _mainText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: const Text(
                          'Inactive items stay hidden from patients.',
                          style: TextStyle(color: _mutedText),
                        ),
                        activeTrackColor: _primaryBlue,
                        inactiveTrackColor: _softBorder,
                        thumbColor: const WidgetStatePropertyAll(Colors.white),
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: _primaryBlue,
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: _primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: Text(_isEditing ? 'Save Changes' : 'Create FAQ'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogSection extends StatelessWidget {
  const _DialogSection({
    required this.title,
    required this.description,
    required this.children,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _darkBlue,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _mutedText,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
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
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: _errorText, width: 1.5),
    ),
  );
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, required this.isSuccess});

  final String message;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSuccess ? _successBg : _errorBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isSuccess ? _successText : _errorText,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _AdminEmptyState extends StatelessWidget {
  const _AdminEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.quiz_outlined, size: 42, color: _primaryBlue),
          const SizedBox(height: 14),
          Text(
            'No FAQ items yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _darkBlue,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create patient help answers so the support section becomes more useful.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _mutedText,
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}

class _AdminFullErrorState extends StatelessWidget {
  const _AdminFullErrorState({required this.message, required this.onRetry});

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
            const Icon(Icons.error_outline_rounded, size: 42, color: _errorText),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _mutedText,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
