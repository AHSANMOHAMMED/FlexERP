import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/lk_formatters.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../data/repositories/hr_repository.dart';

class EmployeeDirectoryScreen extends ConsumerStatefulWidget {
  const EmployeeDirectoryScreen({super.key});

  @override
  ConsumerState<EmployeeDirectoryScreen> createState() => _EmployeeDirectoryScreenState();
}

class _EmployeeDirectoryScreenState extends ConsumerState<EmployeeDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedDept = 'All';

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await ref.read(employeeDirectoryProvider.notifier).syncFromOdoo();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('HR sync failed: $e'), backgroundColor: FlexColors.danger),
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
    final employees = ref.watch(employeeDirectoryProvider);
    final query = _searchController.text.toLowerCase();

    final filteredEmployees = employees.where((emp) {
      final matchesQuery = emp.name.toLowerCase().contains(query) ||
          emp.jobTitle.toLowerCase().contains(query) ||
          emp.department.toLowerCase().contains(query) ||
          emp.epfNumber.toLowerCase().contains(query);
      final matchesDept = _selectedDept == 'All' || emp.department.contains(_selectedDept);
      return matchesQuery && matchesDept;
    }).toList();

    return Scaffold(
      backgroundColor: FlexColors.background,
      appBar: FlexAppBar(
        title: 'Staff Directory',
        subtitle: 'hr.employee Corporate Colleagues',
        showCompanySwitcher: false,
        onSync: () => ref.read(employeeDirectoryProvider.notifier).syncFromOdoo(),
      ),
      body: RefreshIndicator(
        color: FlexColors.primary,
        backgroundColor: FlexColors.surface,
        onRefresh: () => ref.read(employeeDirectoryProvider.notifier).syncFromOdoo(),
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: FlexColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search by employee name, role or EPF...',
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
                  // Dept chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Executive', 'Sales', 'Supply Chain', 'Finance', 'Retail', 'Technical'].map((dept) {
                        final isSelected = _selectedDept == dept;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(dept),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedDept = dept);
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

            // Employee List
            Expanded(
              child: filteredEmployees.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.badge_outlined, color: FlexColors.textSecondary, size: 48),
                          SizedBox(height: 12),
                          Text('No staff members found', style: TextStyle(color: FlexColors.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredEmployees.length,
                      itemBuilder: (context, index) {
                        final emp = filteredEmployees[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: FlexColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: FlexColors.cardBorder),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: FlexColors.primary.withValues(alpha: 0.2),
                                    foregroundColor: FlexColors.primaryLight,
                                    child: Text(
                                      emp.name.substring(0, 1).toUpperCase(),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          emp.name,
                                          style: const TextStyle(
                                            color: FlexColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          emp.jobTitle,
                                          style: const TextStyle(
                                            color: FlexColors.primaryLight,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '${emp.department} • ${emp.location}',
                                          style: const TextStyle(color: FlexColors.textSecondary, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: FlexColors.background,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: FlexColors.cardBorder),
                                    ),
                                    child: Text(
                                      emp.epfNumber,
                                      style: const TextStyle(
                                        color: FlexColors.textSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
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
                                            content: Text(
                                              'Calling ${LkFormatters.formatLkPhone(emp.workPhone)}...',
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.phone, size: 14, color: FlexColors.primaryLight),
                                      label: Text(
                                        LkFormatters.formatLkPhone(emp.workPhone),
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
                                        SnackBar(content: Text('Email to ${emp.workEmail}')),
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
