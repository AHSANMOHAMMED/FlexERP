import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/lk_formatters.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../data/repositories/partner_repository.dart';

class CustomerDirectoryScreen extends ConsumerStatefulWidget {
  const CustomerDirectoryScreen({super.key});

  @override
  ConsumerState<CustomerDirectoryScreen> createState() => _CustomerDirectoryScreenState();
}

class _CustomerDirectoryScreenState extends ConsumerState<CustomerDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCity = 'All';

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await ref.read(partnersProvider.notifier).syncFromOdoo();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Partner sync failed: $e'), backgroundColor: FlexColors.danger),
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final partners = ref.watch(partnersProvider);
    final query = _searchController.text.toLowerCase();

    final filteredPartners = partners.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(query) ||
          p.phone.contains(query) ||
          p.vatOrTin.toLowerCase().contains(query);
      final matchesCity = _selectedCity == 'All' || p.city.contains(_selectedCity);
      return matchesSearch && matchesCity;
    }).toList();

    return Scaffold(
      backgroundColor: FlexColors.background,
      appBar: FlexAppBar(
        title: 'Customer Directory',
        subtitle: 'res.partner CRM & Credit Profiles',
        showCompanySwitcher: false,
        onSync: () => ref.read(partnersProvider.notifier).syncFromOdoo(),
      ),
      body: RefreshIndicator(
        color: FlexColors.primary,
        backgroundColor: FlexColors.surface,
        onRefresh: () => ref.read(partnersProvider.notifier).syncFromOdoo(),
        child: Column(
          children: [
            // Search and Filter Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: FlexColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search by client name, TIN or phone...',
                      hintStyle: const TextStyle(color: FlexColors.textSecondary, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: FlexColors.primary, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: FlexColors.textSecondary, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: FlexColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: FlexColors.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: FlexColors.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: FlexColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // City chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Colombo', 'Horana', 'Peliyagoda'].map((city) {
                        final isSelected = _selectedCity == city;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(city),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedCity = city);
                            },
                            selectedColor: FlexColors.primary.withValues(alpha: 0.25),
                            backgroundColor: FlexColors.surface,
                            labelStyle: TextStyle(
                              color: isSelected ? FlexColors.primaryLight : FlexColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            side: BorderSide(
                              color: isSelected ? FlexColors.primary : FlexColors.cardBorder,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // List of Customers
            Expanded(
              child: filteredPartners.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.person_off_outlined, color: FlexColors.textSecondary, size: 48),
                          SizedBox(height: 12),
                          Text('No customers match your search', style: TextStyle(color: FlexColors.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredPartners.length,
                      itemBuilder: (context, index) {
                        final p = filteredPartners[index];
                        final utilization = p.creditLimit > 0
                            ? (p.totalReceivable / p.creditLimit).clamp(0.0, 1.0)
                            : 0.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: FlexColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: p.isOverCreditLimit
                                  ? FlexColors.error.withValues(alpha: 0.5)
                                  : FlexColors.cardBorder,
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: FlexColors.primary.withValues(alpha: 0.15),
                                    foregroundColor: FlexColors.primaryLight,
                                    child: Text(
                                      p.name.substring(0, 1).toUpperCase(),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.name,
                                          style: const TextStyle(
                                            color: FlexColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${p.city} • ${p.address}',
                                          style: const TextStyle(color: FlexColors.textSecondary, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (p.isOverCreditLimit)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: FlexColors.error.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: FlexColors.error),
                                      ),
                                      child: const Text(
                                        'OVER LIMIT',
                                        style: TextStyle(
                                          color: FlexColors.error,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              // Tax & terms metadata
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: FlexColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('TIN / VAT Number', style: TextStyle(color: FlexColors.textSecondary, fontSize: 10)),
                                        Text(p.vatOrTin, style: const TextStyle(color: FlexColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text('Payment Terms', style: TextStyle(color: FlexColors.textSecondary, fontSize: 10)),
                                        Text(p.paymentTerms, style: const TextStyle(color: FlexColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Credit progress
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Receivable: ${LkFormatters.formatLkr(p.totalReceivable)}',
                                    style: TextStyle(
                                      color: p.isOverCreditLimit ? FlexColors.error : FlexColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Limit: ${LkFormatters.formatLkr(p.creditLimit)}',
                                    style: const TextStyle(color: FlexColors.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: utilization,
                                  minHeight: 6,
                                  backgroundColor: FlexColors.cardBorder,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    p.isOverCreditLimit
                                        ? FlexColors.error
                                        : (utilization > 0.8 ? FlexColors.warning : FlexColors.success),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Action Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: FlexColors.textPrimary,
                                        side: const BorderSide(color: FlexColors.cardBorder),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Dialing ${LkFormatters.formatLkPhone(p.phone)}...'),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.phone, size: 16, color: FlexColors.primaryLight),
                                      label: Text(
                                        LkFormatters.formatLkPhone(p.phone),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'Email',
                                    style: IconButton.styleFrom(
                                      backgroundColor: FlexColors.background,
                                      side: const BorderSide(color: FlexColors.cardBorder),
                                    ),
                                    icon: const Icon(Icons.email_outlined, color: FlexColors.primaryLight, size: 18),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Email to ${p.email}')),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
