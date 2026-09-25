import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/handbook_photo.dart';
import '../../../data/models/handbook_reference.dart';
import '../../../domain/usecases/handbook_photo_resolution.dart';
import '../../../domain/usecases/handbook_search.dart';
import '../../providers/handbook_providers.dart';
import '../../widgets/cards/platform_card.dart';
import '../../widgets/cards/vehicle_card.dart';
import '../../widgets/common/attachment_detail_dialog.dart';
import '../../widgets/common/handbook_reference_chip.dart';
import '../../widgets/common/handbook_reference_detail_dialog.dart';
import '../../widgets/common/platform_detail_dialog.dart';
import '../../widgets/common/principle_card.dart';
import '../../widgets/common/rule_detail_dialog.dart';
import '../../widgets/common/vehicle_detail_dialog.dart';
import '../../widgets/photos/handbook_photo_thumbnail.dart';
import '../../widgets/common/instrument.dart';

const _tabTitles = [
  AppStrings.tabFigures,
  AppStrings.tabParagraphs,
  AppStrings.tabTables,
  AppStrings.tabRules,
  AppStrings.tabPrinciples,
  AppStrings.tabHardware,
  AppStrings.tabVehicles,
  AppStrings.tabPlatforms,
];

/// Browse every category of extracted handbook source material — figures,
/// paragraphs, tables, rules, principles, hardware, vehicles, platforms —
/// with a search box scoped to whichever category is open.
class ReferenceBrowserScreen extends StatefulWidget {
  const ReferenceBrowserScreen({super.key});

  @override
  State<ReferenceBrowserScreen> createState() => _ReferenceBrowserScreenState();
}

class _ReferenceBrowserScreenState extends State<ReferenceBrowserScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabTitles.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InstrumentScaffold(
      title: AppStrings.referenceBrowserTitle,
      // The handbook sits outside the loading operation: no stage index, and
      // the way out is back to wherever it was opened from.
      showRail: false,
      onBack: () => context.pop(),
      tabs: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.hairline)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxl),
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.transparent,
          indicatorColor: AppColors.instrument,
          indicatorWeight: AppStroke.lit,
          labelColor: AppColors.instrumentGlow,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: AppText.legend(size: AppText.caption, color: AppColors.instrumentGlow),
          unselectedLabelStyle:
              AppText.legend(size: AppText.caption, color: AppColors.textSecondary, weight: FontWeight.w400),
          tabs: _tabTitles.map((t) => Tab(text: t.toUpperCase())).toList(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: AppStrings.searchInCategoryHint,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _FiguresTab(query: _query),
                _ReferencesTab(query: _query, isTable: false),
                _ReferencesTab(query: _query, isTable: true),
                _RulesTab(query: _query),
                _PrinciplesTab(query: _query),
                _AttachmentsTab(query: _query),
                _VehiclesTab(query: _query),
                _PlatformsTab(query: _query),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _asyncBody<T>(AsyncValue<T> value, Widget Function(T data) builder) {
  return value.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (e, st) => Center(child: Text(AppStrings.errorPrefix(e))),
    data: builder,
  );
}

class _FiguresTab extends ConsumerWidget {
  final String query;
  const _FiguresTab({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _asyncBody(ref.watch(photosProvider), (photos) {
      final filtered = filterPhotos(photos, query);
      if (filtered.isEmpty) {
        return const Center(child: Text(AppStrings.noFiguresMatch));
      }
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 310,
          mainAxisExtent: 370,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: filtered.length,
        itemBuilder: (context, i) => _FigureTile(photo: filtered[i]),
      );
    });
  }
}

class _FigureTile extends StatelessWidget {
  final HandbookPhoto photo;
  const _FigureTile({required this.photo});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: HandbookPhotoThumbnail(photo: photo, size: 160)),
            const SizedBox(height: 8),
            Text(photo.figureNumber,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: AppText.label)),
            Text(
              photo.displayCaption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: AppText.bodySmall, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            HandbookReferenceChip(referenceId: photo.referenceId),
          ],
        ),
      ),
    );
  }
}

class _ReferencesTab extends ConsumerWidget {
  final String query;
  final bool isTable;
  const _ReferencesTab({required this.query, required this.isTable});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _asyncBody(ref.watch(referencesProvider), (refs) {
      final scoped = refs.where((r) => r.id.startsWith('table-') == isTable).toList();
      final filtered = filterReferences(scoped, query);
      if (filtered.isEmpty) {
        return Center(
            child: Text(isTable ? AppStrings.noTablesMatch : AppStrings.noParagraphsMatch));
      }
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _ReferenceTile(reference: filtered[i]),
      );
    });
  }
}

class _ReferenceTile extends StatelessWidget {
  final HandbookReference reference;
  const _ReferenceTile({required this.reference});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(reference.citationLabel,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: AppText.label)),
        subtitle: Text(
          reference.displaySummary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: AppText.bodySmall),
        ),
        onTap: () => showHandbookReferenceDetailDialog(context, reference.id),
      ),
    );
  }
}

class _RulesTab extends ConsumerWidget {
  final String query;
  const _RulesTab({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _asyncBody(ref.watch(ruleEntriesProvider), (rules) {
      final linkerAsync = ref.watch(referenceLinkerProvider);
      final filtered = filterRules(rules, query);
      if (filtered.isEmpty) {
        return const Center(child: Text(AppStrings.noRulesMatch));
      }
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final rule = filtered[i];
          return Card(
            child: ListTile(
              title: Text(rule.displayTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: AppText.label)),
              subtitle: Text(
                rule.appliesTo == null
                    ? rule.displayDescription
                    : '${AppStrings.appliesToLabelFor(rule.appliesTo!)}: ${rule.displayDescription}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: AppText.bodySmall),
              ),
              onTap: () {
                final linker = linkerAsync.valueOrNull;
                showRuleDetailDialog(
                  context,
                  rule: rule,
                  relatedPhotos: linker?.photosFor(rule.referenceId) ?? const [],
                );
              },
            ),
          );
        },
      );
    });
  }
}

class _PrinciplesTab extends ConsumerWidget {
  final String query;
  const _PrinciplesTab({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _asyncBody(ref.watch(principlesProvider), (principles) {
      final linkerAsync = ref.watch(referenceLinkerProvider);
      final linker = linkerAsync.valueOrNull;
      final filtered = filterPrinciples(principles, query);
      if (filtered.isEmpty) {
        return const Center(child: Text(AppStrings.noPrinciplesMatch));
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: filtered
            .map((p) => PrincipleCard(
                  principle: p,
                  relatedPhotos: linker?.photosFor(p.handbookReferenceId) ?? const [],
                ))
            .toList(),
      );
    });
  }
}

class _AttachmentsTab extends ConsumerWidget {
  final String query;
  const _AttachmentsTab({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _asyncBody(ref.watch(attachmentTypesProvider), (attachments) {
      final linkerAsync = ref.watch(referenceLinkerProvider);
      final filtered = filterAttachments(attachments, query);
      if (filtered.isEmpty) {
        return const Center(child: Text(AppStrings.noHardwareMatch));
      }
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final attachment = filtered[i];
          return Card(
            child: ListTile(
              title: Text(attachment.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: AppText.label)),
              subtitle: Text(AppStrings.attachmentCategoryLabel(attachment.category),
                  style: const TextStyle(fontSize: AppText.bodySmall)),
              onTap: () {
                final linker = linkerAsync.valueOrNull;
                showAttachmentDetailDialog(
                  context,
                  attachment: attachment,
                  relatedPhotos: linker?.photosFor(attachment.referenceId) ?? const [],
                );
              },
            ),
          );
        },
      );
    });
  }
}

class _VehiclesTab extends ConsumerWidget {
  final String query;
  const _VehiclesTab({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _asyncBody(ref.watch(vehiclesProvider), (vehicles) {
      final attachmentsAsync = ref.watch(attachmentTypesProvider);
      final linkerAsync = ref.watch(referenceLinkerProvider);
      final vehiclePhotosAsync = ref.watch(vehiclePhotosProvider);
      final filtered = filterVehicles(vehicles, query);
      if (filtered.isEmpty) {
        return const Center(child: Text(AppStrings.noVehiclesMatch));
      }
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 420,
          mainAxisExtent: 360,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: filtered.length,
        itemBuilder: (context, i) {
          final vehicle = filtered[i];
          return VehicleCard(
            vehicle: vehicle,
            illustrativePhoto: vehiclePhotosAsync.valueOrNull?[vehicle.id],
            onTap: () {
              final attachments = attachmentsAsync.valueOrNull ?? const [];
              final linker = linkerAsync.valueOrNull;
              showVehicleDetailDialog(
                context,
                vehicle: vehicle,
                allAttachments: attachments,
                relatedPhotos: linker?.photosFor(vehicle.referenceId) ?? const [],
                identificationPhoto: linker == null ? null : vehicleIdentificationPhotoFor(vehicle, linker),
                illustrativePhoto: vehiclePhotosAsync.valueOrNull?[vehicle.id],
              );
            },
          );
        },
      );
    });
  }
}

class _PlatformsTab extends ConsumerWidget {
  final String query;
  const _PlatformsTab({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _asyncBody(ref.watch(platformsProvider), (platforms) {
      final linkerAsync = ref.watch(referenceLinkerProvider);
      final filtered = filterPlatforms(platforms, query);
      if (filtered.isEmpty) {
        return const Center(child: Text(AppStrings.noPlatformsMatch));
      }
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final platform = filtered[i];
          return PlatformCard(
            platform: platform,
            onTap: () {
              final linker = linkerAsync.valueOrNull;
              showPlatformDetailDialog(
                context,
                platform: platform,
                relatedPhotos: linker?.photosFor(platform.referenceId) ?? const [],
              );
            },
          );
        },
      );
    });
  }
}
