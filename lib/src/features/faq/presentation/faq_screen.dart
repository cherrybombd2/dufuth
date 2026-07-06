import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/faq_repository.dart';
import '../domain/faq_item.dart';

const _pageBg = Color(0xFFF4F8FF);
const _primaryBlue = Color(0xFF2C7DF7);
const _darkBlue = Color(0xFF153B74);
const _mutedText = Color(0xFF5D6B82);
const _dividerBlue = Color(0xFFDCE8FF);
const _errorText = Color(0xFFB42318);

class FaqScreen extends ConsumerStatefulWidget {
  const FaqScreen({super.key});

  @override
  ConsumerState<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends ConsumerState<FaqScreen> {
  List<FaqItem>? _items;
  String? _error;
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    final cached = ref.read(faqRepositoryProvider).cachedPatientItems;
    _items = cached;
    _loading = cached == null;
    _load(showRefresh: cached != null);
  }

  Future<void> _load({bool showRefresh = false}) async {
    setState(() {
      _error = null;
      _refreshing = showRefresh;
      _loading = _items == null;
    });

    try {
      final items = await ref.read(faqRepositoryProvider).fetchPatientItems();
      if (!mounted) return;
      setState(() => _items = items);
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
    final items = _items;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(title: const Text('FAQ')),
      body: SafeArea(
        top: false,
        child: Builder(
          builder: (context) {
            if (_loading && items == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_error != null && items == null) {
              return _FullErrorState(message: _error!, onRetry: () => _load());
            }

            return RefreshIndicator(
              onRefresh: () => _load(showRefresh: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  if (_refreshing) ...[
                    const LinearProgressIndicator(
                      minHeight: 3,
                      color: _primaryBlue,
                      backgroundColor: _dividerBlue,
                    ),
                    const SizedBox(height: 14),
                  ],
                  Text(
                    'Frequently Asked Questions',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: _darkBlue,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Common answers about appointments, timing, and visiting the hospital.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _mutedText,
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: 18),
                  if (items == null || items.isEmpty)
                    const _EmptyFaqState()
                  else
                    for (final item in items) ...[
                      _PatientFaqCard(item: item),
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

class _PatientFaqCard extends StatelessWidget {
  const _PatientFaqCard({required this.item});

  final FaqItem item;

  @override
  Widget build(BuildContext context) {
    final category = item.category?.trim();

    return Container(
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
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          iconColor: _primaryBlue,
          collapsedIconColor: _mutedText,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.question,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _darkBlue,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (category != null && category.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  category,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ],
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                item.answer,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _mutedText,
                      height: 1.5,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFaqState extends StatelessWidget {
  const _EmptyFaqState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
        children: [
          const Icon(Icons.help_outline_rounded, size: 46, color: _primaryBlue),
          const SizedBox(height: 16),
          Text(
            'No FAQ items yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _darkBlue,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Helpful patient answers will appear here once hospital content is configured.',
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
            const Icon(Icons.error_outline_rounded, size: 46, color: _errorText),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _mutedText,
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
