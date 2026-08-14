import 'package:flutter/material.dart';

import '../models/plant_archive_entry.dart';
import '../services/plant_archive_service.dart';
import '../services/plant_safety_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/botanical_background.dart';

class PlantArchiveScreen extends StatefulWidget {
  const PlantArchiveScreen({super.key});

  static const routeName = '/plant-archive';

  @override
  State<PlantArchiveScreen> createState() => _PlantArchiveScreenState();
}

class _PlantArchiveScreenState extends State<PlantArchiveScreen> {
  final _searchController = TextEditingController();
  late final Future<List<PlantArchiveEntry>> _entriesFuture;
  String _query = '';
  SafetyFilter _safetyFilter = SafetyFilter.all;

  @override
  void initState() {
    super.initState();
    _entriesFuture = PlantArchiveService.instance.loadEntries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bitki Rehberi')),
      body: BotanicalBackground(
        child: SafeArea(
          top: false,
          child: FutureBuilder<List<PlantArchiveEntry>>(
            future: _entriesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.green),
                );
              }
              final entries = snapshot.data ?? const <PlantArchiveEntry>[];
              final results = PlantArchiveService.instance
                  .search(entries, _query)
                  .where((entry) {
                    return PlantSafetyService.instance.matchesFilter(
                      entry.displayName,
                      _safetyFilter,
                    );
                  })
                  .toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 118),
                children: [
                  _ArchiveSearchBox(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 14),
                  _SafetyFilters(
                    selected: _safetyFilter,
                    onChanged: (value) => setState(() => _safetyFilter = value),
                  ),
                  const SizedBox(height: 14),
                  _ArchiveIntro(total: entries.length, shown: results.length),
                  const SizedBox(height: 14),
                  if (results.isEmpty)
                    const _ArchiveEmpty()
                  else
                    ...results.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ArchiveResultCard(
                          entry: entry,
                          onTap: () => _showEntryDetail(context, entry),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showEntryDetail(BuildContext context, PlantArchiveEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ArchiveDetailSheet(entry: entry),
    );
  }
}

class _ArchiveSearchBox extends StatelessWidget {
  const _ArchiveSearchBox({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Bitki, hastalık, ışık veya sulama ara',
        prefixIcon: const Icon(Icons.search, color: AppColors.green),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Aramayı temizle',
                icon: const Icon(Icons.close),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: .94),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: .8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppColors.green, width: 1.4),
        ),
      ),
    );
  }
}

class _ArchiveIntro extends StatelessWidget {
  const _ArchiveIntro({required this.total, required this.shown});

  final int total;
  final int shown;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.mint.withValues(alpha: .86),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.darkGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.menu_book_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$total bitki arşivi', style: AppTextStyles.section),
                const SizedBox(height: 3),
                Text(
                  shown == total || shown == 40
                      ? 'Aramaya başla; tür grubuna göre genel bakım özetini gör.'
                      : '$shown sonuç listeleniyor.',
                  style: AppTextStyles.muted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyFilters extends StatelessWidget {
  const _SafetyFilters({required this.selected, required this.onChanged});

  final SafetyFilter selected;
  final ValueChanged<SafetyFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: SafetyFilter.values.map((filter) {
          final active = filter == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: active,
              label: Text(filter.label),
              avatar: Icon(
                switch (filter) {
                  SafetyFilter.catFriendly => Icons.pets,
                  SafetyFilter.dogFriendly => Icons.pets_outlined,
                  SafetyFilter.childFriendly => Icons.child_care_outlined,
                  SafetyFilter.fullySafe => Icons.verified_user_outlined,
                  SafetyFilter.all => Icons.filter_list,
                },
                size: 17,
                color: active ? Colors.white : AppColors.green,
              ),
              selectedColor: AppColors.green,
              labelStyle: AppTextStyles.muted.copyWith(
                color: active ? Colors.white : AppColors.darkGreen,
                fontWeight: FontWeight.w900,
              ),
              onSelected: (_) => onChanged(filter),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ArchiveResultCard extends StatelessWidget {
  const _ArchiveResultCard({required this.entry, required this.onTap});

  final PlantArchiveEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(entry.displayName, style: AppTextStyles.section),
                ),
                const Icon(Icons.chevron_right, color: AppColors.green),
              ],
            ),
            if (entry.scientificName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(entry.scientificName, style: AppTextStyles.muted),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ArchiveChip(icon: Icons.eco_outlined, label: entry.group),
                if (entry.difficulty.isNotEmpty)
                  _ArchiveChip(
                    icon: Icons.speed_outlined,
                    label: entry.difficulty,
                  ),
                _SafetyChip(entry: entry),
              ],
            ),
            const SizedBox(height: 12),
            _MiniInfo(icon: Icons.water_drop_outlined, text: entry.water),
            const SizedBox(height: 6),
            _MiniInfo(icon: Icons.wb_sunny_outlined, text: entry.light),
          ],
        ),
      ),
    );
  }
}

class _ArchiveChip extends StatelessWidget {
  const _ArchiveChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.green, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.muted.copyWith(
                color: AppColors.darkGreen,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyChip extends StatelessWidget {
  const _SafetyChip({required this.entry});

  final PlantArchiveEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = _safetyColor(entry.toxicity);
    final label = entry.toxicity == 'Yok'
        ? 'Güvenli'
        : entry.toxicity.isEmpty
        ? 'Kontrol et'
        : '${entry.toxicity} risk';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .34)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.muted.copyWith(
                color: AppColors.darkGreen,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.green, size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.muted.copyWith(color: AppColors.ink),
          ),
        ),
      ],
    );
  }
}

class _ArchiveDetailSheet extends StatelessWidget {
  const _ArchiveDetailSheet({required this.entry});

  final PlantArchiveEntry entry;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: .88,
      minChildSize: .55,
      maxChildSize: .96,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(entry.displayName, style: AppTextStyles.title),
              if (entry.scientificName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(entry.scientificName, style: AppTextStyles.muted),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ArchiveChip(icon: Icons.eco_outlined, label: entry.group),
                  _ArchiveChip(
                    icon: Icons.speed_outlined,
                    label: entry.difficulty,
                  ),
                  _SafetyChip(entry: entry),
                ],
              ),
              const SizedBox(height: 16),
              const AppCard(
                color: AppColors.warmCream,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: AppColors.warning),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bu bölüm genel bakım rehberidir. Sulama kararını takvime göre değil; toprağın nemi, saksı drenajı ve bitkinin güncel görünümüne göre ver.',
                        style: AppTextStyles.body,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SafetyDetailBlock(entry: entry),
              _DetailBlock(
                title: 'Sulama',
                icon: Icons.water_drop_outlined,
                text: entry.water,
              ),
              _DetailBlock(
                title: 'Işık',
                icon: Icons.wb_sunny_outlined,
                text: entry.light,
              ),
              _DetailBlock(
                title: 'Toprak',
                icon: Icons.terrain_outlined,
                text: entry.soil,
              ),
              _DetailBlock(
                title: 'Konum',
                icon: Icons.place_outlined,
                text: entry.idealLocation,
              ),
              _DetailBlock(
                title: 'Sevdiği koşullar',
                icon: Icons.favorite_border,
                text: entry.likes,
              ),
              _DetailBlock(
                title: 'Kaçın',
                icon: Icons.block_outlined,
                text: entry.dislikes,
              ),
              _DetailBlock(
                title: 'Hastalık ve zararlılar',
                icon: Icons.bug_report_outlined,
                text: entry.diseasesPests,
              ),
              _DetailBlock(
                title: 'Gelişim ipucu',
                icon: Icons.trending_up_outlined,
                text: entry.growthTips,
              ),
              _DetailBlock(
                title: 'Gübreleme',
                icon: Icons.science_outlined,
                text: entry.fertilizer,
              ),
              _DetailBlock(
                title: 'Saksı değişimi',
                icon: Icons.inventory_2_outlined,
                text: entry.repotting,
              ),
              _DetailBlock(
                title: 'Çoğaltma',
                icon: Icons.call_split_outlined,
                text: entry.propagation,
              ),
              if (entry.checklist.isNotEmpty)
                _ChecklistBlock(items: entry.checklist),
              _DetailBlock(
                title: 'Özel not',
                icon: Icons.info_outline,
                text: entry.specialNote,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({
    required this.title,
    required this.icon,
    required this.text,
  });

  final String title;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        showPattern: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.green),
                const SizedBox(width: 9),
                Expanded(child: Text(title, style: AppTextStyles.section)),
              ],
            ),
            const SizedBox(height: 8),
            Text(text, style: AppTextStyles.body),
          ],
        ),
      ),
    );
  }
}

class _SafetyDetailBlock extends StatelessWidget {
  const _SafetyDetailBlock({required this.entry});

  final PlantArchiveEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = _safetyColor(entry.toxicity);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: .34)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.health_and_safety_outlined, color: color),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Evcil Hayvan ve Çocuk Güvenliği',
                      style: AppTextStyles.section,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SafetyLine(
                icon: '🐱',
                label: 'Kedi dostu',
                value: entry.catFriendly,
              ),
              _SafetyLine(
                icon: '🐶',
                label: 'Köpek dostu',
                value: entry.dogFriendly,
              ),
              _SafetyLine(
                icon: '👶',
                label: 'Çocuk dostu',
                value: entry.childFriendly,
              ),
              _SafetyLine(
                icon: '☠️',
                label: 'Zehirlilik seviyesi',
                value: entry.toxicity,
              ),
              if (entry.riskTypes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Risk tipi: ${entry.riskTypes.join(', ')}',
                  style: AppTextStyles.body,
                ),
              ],
              const SizedBox(height: 10),
              Text(entry.safetyWarning, style: AppTextStyles.body),
              const SizedBox(height: 8),
              Text(
                entry.safetyRecommendation,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                'Bu bilgiler bilgilendirme amaçlıdır. Bitki tüketimi veya temas sonrası ciddi belirti oluşursa veteriner veya sağlık kuruluşuna başvurulmalıdır. Uygulama kesin tıbbi veya veteriner tavsiyesi yerine geçmez.',
                style: AppTextStyles.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafetyLine extends StatelessWidget {
  const _SafetyLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Text(icon),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: AppTextStyles.body)),
          Text(
            value.isEmpty ? 'Kısmen' : value,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ChecklistBlock extends StatelessWidget {
  const _ChecklistBlock({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        color: AppColors.mint.withValues(alpha: .86),
        showPattern: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checklist_outlined, color: AppColors.green),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Pratik kontrol listesi',
                    style: AppTextStyles.section,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Icon(
                        Icons.circle,
                        size: 7,
                        color: AppColors.green,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: Text(item, style: AppTextStyles.body)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveEmpty extends StatelessWidget {
  const _ArchiveEmpty();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        children: [
          Icon(Icons.search_off_outlined, color: AppColors.green, size: 44),
          SizedBox(height: 10),
          Text('Sonuç bulunamadı', style: AppTextStyles.section),
          SizedBox(height: 6),
          Text(
            'Bitki adı, bilimsel ad, bakım sorunu veya grup adıyla tekrar ara.',
            style: AppTextStyles.muted,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

Color _safetyColor(String toxicity) {
  return switch (toxicity) {
    'Yok' => AppColors.green,
    'Düşük' => AppColors.warning,
    'Orta' => AppColors.warning,
    'Yüksek' => AppColors.critical,
    _ => AppColors.warning,
  };
}
