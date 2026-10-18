import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_card.dart';
import '../../core/widgets/flex_badge.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../core/widgets/flex_button.dart';
import '../../core/localization/lk_formatters.dart';
import '../../data/models/crm_lead.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/sales_repository.dart';

class PipelineKanbanScreen extends ConsumerStatefulWidget {
  final VoidCallback? onNewQuotation;

  const PipelineKanbanScreen({super.key, this.onNewQuotation});

  @override
  ConsumerState<PipelineKanbanScreen> createState() => _PipelineKanbanScreenState();
}

class _PipelineKanbanScreenState extends ConsumerState<PipelineKanbanScreen> {
  String _selectedStage = 'New';
  String _searchQuery = '';
  String? _syncError;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await ref.read(crmLeadsProvider.notifier).syncFromOdoo();
        if (!mounted) return;
        final stages = ref.read(crmLeadsProvider.notifier).stageNames;
        if (stages.isNotEmpty) setState(() => _selectedStage = stages.first);
      } catch (e) {
        if (!mounted) return;
        setState(() => _syncError = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CRM sync failed: $e'), backgroundColor: FlexColors.danger),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentBranch = ref.watch(currentBranchProvider);
    final allLeads = ref.watch(crmLeadsProvider);
    final stages = ref.read(crmLeadsProvider.notifier).stageNames;
    if (!stages.contains(_selectedStage) && stages.isNotEmpty) {
      _selectedStage = stages.first;
    }

    final filteredLeads = allLeads.where((lead) {
      final matchesStage = lead.stage == _selectedStage;
      final matchesSearch = _searchQuery.isEmpty ||
          lead.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          lead.partnerName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesStage && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: FlexColors.canvasDark,
      appBar: FlexAppBar(
        title: 'CRM Sales Pipeline',
        subtitle: 'Field Sales Opportunities',
        currentBranch: currentBranch,
        onSync: () async {
          try {
            await ref.read(crmLeadsProvider.notifier).syncFromOdoo();
            if (!mounted) return;
            setState(() => _syncError = null);
          } catch (e) {
            if (!mounted) return;
            setState(() => _syncError = e.toString());
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('CRM sync failed: $e'), backgroundColor: FlexColors.danger),
            );
          }
        },
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: FlexColors.primaryLight),
            onPressed: () => _showAddLeadDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: 'Search leads, clients, or tags...',
              ),
            ),
          ),

          if (_syncError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_syncError!, style: const TextStyle(color: FlexColors.danger, fontSize: 11)),
            ),
          // Stage Selector Pills
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: stages.length,
              itemBuilder: (context, index) {
                final stage = stages[index];
                final isSelected = stage == _selectedStage;
                final count = allLeads.where((l) => l.stage == stage).length;
                final stageTotal = allLeads
                    .where((l) => l.stage == stage)
                    .fold(0.0, (prev, l) => prev + l.expectedRevenue);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      '$stage ($count) • ${LkFormatters.formatLkrCompact(stageTotal)}',
                      style: FlexTypography.labelSm.copyWith(
                        color: isSelected ? Colors.white : FlexColors.textSecondaryDark,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: FlexColors.primary,
                    backgroundColor: FlexColors.surfaceRaisedDark,
                    side: BorderSide(
                      color: isSelected ? FlexColors.primary : FlexColors.borderDark,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedStage = stage);
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Stage List View
          Expanded(
            child: filteredLeads.isEmpty
                ? Center(
                    child: Text(
                      'No leads in $_selectedStage stage',
                      style: FlexTypography.bodyMd.copyWith(color: FlexColors.textSecondaryDark),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredLeads.length,
                    itemBuilder: (context, index) {
                      final lead = filteredLeads[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: _LeadCard(
                          lead: lead,
                          onStageChanged: (newStage) {
                            ref.read(crmLeadsProvider.notifier).updateLeadStage(lead.id, newStage);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: FlexColors.primary,
        icon: const Icon(Icons.request_quote),
        label: const Text('New Quotation'),
        onPressed: widget.onNewQuotation,
      ),
    );
  }

  void _showAddLeadDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final clientCtrl = TextEditingController();
    final revCtrl = TextEditingController(text: '1500000');
    final phoneCtrl = TextEditingController(text: '+94 77 123 4567');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: FlexColors.surfaceDark,
          title: Text('New Sales Lead', style: FlexTypography.headlineSm),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Lead Title / Project')),
                const SizedBox(height: 10),
                TextField(controller: clientCtrl, decoration: const InputDecoration(labelText: 'Client Company Name')),
                const SizedBox(height: 10),
                TextField(controller: revCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Expected Revenue (LKR)')),
                const SizedBox(height: 10),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Contact Phone (+94)')),
              ],
            ),
          ),
          actions: [
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
            FlexButton(
              label: 'Create Lead',
              onPressed: () {
                if (titleCtrl.text.isNotEmpty && clientCtrl.text.isNotEmpty) {
                  ref.read(crmLeadsProvider.notifier).addLead(
                    CrmLead(
                      id: DateTime.now().millisecondsSinceEpoch,
                      name: titleCtrl.text,
                      partnerName: clientCtrl.text,
                      expectedRevenue: double.tryParse(revCtrl.text) ?? 1000000.0,
                      stage: _selectedStage,
                      priority: 2,
                      tags: ['Field Sales', 'Direct'],
                      phone: phoneCtrl.text,
                      expectedClosing: '2026-11-15',
                    ),
                  );
                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class _LeadCard extends StatelessWidget {
  final CrmLead lead;
  final ValueChanged<String> onStageChanged;

  const _LeadCard({
    required this.lead,
    required this.onStageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FlexCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(lead.partnerName, style: FlexTypography.labelSm.copyWith(color: FlexColors.textSecondaryDark)),
              Row(
                children: List.generate(
                  3,
                  (star) => Icon(
                    Icons.star,
                    size: 14,
                    color: star < lead.priority ? FlexColors.warning : FlexColors.borderDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(lead.name, style: FlexTypography.headlineSm),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                LkFormatters.formatLkr(lead.expectedRevenue),
                style: FlexTypography.codeNum.copyWith(
                  color: FlexColors.primaryLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              FlexBadge(
                text: 'CLOSING ${lead.expectedClosing}',
                variant: FlexBadgeVariant.info,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Wrap(
                spacing: 6,
                children: lead.tags.map((t) => FlexBadge(text: t, variant: FlexBadgeVariant.neutral)).toList(),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.arrow_circle_right_outlined, color: FlexColors.primaryLight),
                color: FlexColors.surfaceRaisedDark,
                onSelected: onStageChanged,
                itemBuilder: (context) => ['New', 'Qualified', 'Proposition', 'Won']
                    .map((s) => PopupMenuItem(value: s, child: Text('Move to $s')))
                    .toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
