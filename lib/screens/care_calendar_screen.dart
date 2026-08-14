import 'package:flutter/material.dart';

import '../models/care_task.dart';
import '../services/notification_service.dart';
import '../services/plant_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/botanical_background.dart';
import '../widgets/branded_header.dart';

class CareCalendarScreen extends StatefulWidget {
  const CareCalendarScreen({super.key, this.focusTaskId, this.focusPlantId});

  final String? focusTaskId;
  final String? focusPlantId;

  @override
  State<CareCalendarScreen> createState() => _CareCalendarScreenState();
}

class _CareCalendarScreenState extends State<CareCalendarScreen> {
  late Future<List<CareTask>> _tasksFuture;
  DateTime _selectedDate = _dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _tasksFuture = _loadTasks();
    PlantRepository.plantsRevision.addListener(_reloadTasks);
  }

  @override
  void dispose() {
    PlantRepository.plantsRevision.removeListener(_reloadTasks);
    super.dispose();
  }

  void _reloadTasks() {
    if (!mounted) {
      return;
    }
    setState(() => _tasksFuture = _loadTasks());
  }

  Future<List<CareTask>> _loadTasks() async {
    final tasks = await PlantRepository().getCareTasks();
    await NotificationService.instance.scheduleCareReminders(tasks);
    CareTask? focusedTask;
    for (final task in tasks) {
      if ((widget.focusTaskId != null && task.id == widget.focusTaskId) ||
          (widget.focusTaskId == null &&
              widget.focusPlantId != null &&
              task.plantId == widget.focusPlantId)) {
        focusedTask = task;
        break;
      }
    }
    if (focusedTask != null) {
      _selectedDate = _dateOnly(focusedTask.dueDate);
    }
    return tasks;
  }

  Future<void> _completeTask(CareTask task) async {
    final id = task.id;
    if (id == null) {
      return;
    }
    await PlantRepository().completeCareTask(id);
    if (!mounted) {
      return;
    }
    setState(() => _tasksFuture = _loadTasks());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BotanicalBackground(
        child: SafeArea(
          child: FutureBuilder<List<CareTask>>(
            future: _tasksFuture,
            builder: (context, snapshot) {
              final tasks = snapshot.data ?? const <CareTask>[];
              final selectedTasks =
                  tasks
                      .where((task) => _isSameDay(task.dueDate, _selectedDate))
                      .toList()
                    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
              final upcomingTasks =
                  tasks
                      .where(
                        (task) =>
                            _dateOnly(task.dueDate).isAfter(_selectedDate),
                      )
                      .toList()
                    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

              return ListView(
                padding: const EdgeInsets.only(bottom: 118),
                children: [
                  const BrandedHeader(
                    eyebrow: 'Bakım ritmi',
                    title: 'Bakım Takvimi',
                    subtitle:
                        'Sulama, kontrol ve temizlik görevlerini kaçırma.',
                  ),
                  _CalendarStrip(
                    selectedDate: _selectedDate,
                    tasks: tasks,
                    onSelected: (date) {
                      setState(() => _selectedDate = _dateOnly(date));
                    },
                  ),
                  const SizedBox(height: 18),
                  if (snapshot.connectionState != ConnectionState.done)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (tasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Henüz bakım görevi yok.',
                              style: AppTextStyles.section,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Bir teşhis sonucunu Bitkilerime kaydedince bakım görevleri burada oluşur.',
                              style: AppTextStyles.muted,
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _CareInsightCard(tasks: tasks),
                    ),
                    const SizedBox(height: 18),
                    _SectionTitle(title: _selectedDayTitle()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _TaskList(
                        tasks: selectedTasks,
                        emptyText: _selectedEmptyText(),
                        highlight: _isSameDay(_selectedDate, DateTime.now()),
                        focusTaskId: widget.focusTaskId,
                        focusPlantId: widget.focusPlantId,
                        onComplete: _completeTask,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _SectionTitle(title: 'Yaklaşanlar'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _TaskList(
                        tasks: upcomingTasks,
                        emptyText: 'Yaklaşan görev yok.',
                        focusTaskId: widget.focusTaskId,
                        focusPlantId: widget.focusPlantId,
                        onComplete: _completeTask,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _selectedDayTitle() {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    if (_isSameDay(_selectedDate, now)) {
      return 'Bugün';
    }
    if (_isSameDay(_selectedDate, tomorrow)) {
      return 'Yarın';
    }
    return '${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}';
  }

  String _selectedEmptyText() {
    if (_isSameDay(_selectedDate, DateTime.now())) {
      return 'Bugün için bakım görevi yok.';
    }
    return '${_selectedDayTitle()} için planlı bakım görevi yok.';
  }
}

DateTime _dateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

bool _isSameDay(DateTime first, DateTime second) {
  final a = _dateOnly(first);
  final b = _dateOnly(second);
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class _CareInsightCard extends StatelessWidget {
  const _CareInsightCard({required this.tasks});

  final List<CareTask> tasks;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayCount = tasks
        .where((task) => _isSameDay(task.dueDate, now))
        .length;
    final wateringCount = tasks
        .where(
          (task) =>
              task.type == CareTaskType.watering &&
              task.dueDate.difference(now).inDays <= 2,
        )
        .length;
    final controlCount = tasks
        .where(
          (task) =>
              task.type == CareTaskType.diseaseCheck ||
              task.type == CareTaskType.potCheck,
        )
        .length;
    final nextTask = [...tasks]..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return AppCard(
      color: AppColors.mint.withValues(alpha: .9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .74),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.eco_outlined, color: AppColors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bakım özeti',
                  style: AppTextStyles.section.copyWith(
                    color: AppColors.darkGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InsightPill(
                  value: '$todayCount',
                  label: 'bugün',
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InsightPill(
                  value: '$wateringCount',
                  label: 'sulama',
                  color: AppColors.leaf,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InsightPill(
                  value: '$controlCount',
                  label: 'kontrol',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _insightText(
              todayCount,
              wateringCount,
              nextTask.isEmpty ? null : nextTask.first,
            ),
            style: AppTextStyles.body.copyWith(color: AppColors.darkGreen),
          ),
        ],
      ),
    );
  }

  String _insightText(int todayCount, int wateringCount, CareTask? nextTask) {
    if (todayCount == 0) {
      return wateringCount == 0
          ? 'Bugün planlı görev yok. Toprak nemini kontrol etmeden ekstra sulama yapma.'
          : 'Bugün zorunlu görev yok ama yakın sulama planı var. Saksı tabağında su bırakmamaya dikkat et.';
    }
    final plant = nextTask?.plantName ?? 'bitkin';
    return 'Öncelik: $plant için ${nextTask?.title.toLowerCase() ?? 'bakım kontrolü'}. İşaretledikçe takvim güncellenir.';
  }
}

class _InsightPill extends StatelessWidget {
  const _InsightPill({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.title.copyWith(color: color, fontSize: 24),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.muted.copyWith(
              color: AppColors.darkGreen,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarStrip extends StatelessWidget {
  const _CalendarStrip({
    required this.selectedDate,
    required this.tasks,
    required this.onSelected,
  });

  final DateTime selectedDate;
  final List<CareTask> tasks;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final now = _dateOnly(DateTime.now());
    return SizedBox(
      height: 104,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, index) {
          final date = now.add(Duration(days: index));
          final selected = _isSameDay(date, selectedDate);
          final taskCount = tasks
              .where((task) => _isSameDay(task.dueDate, date))
              .length;
          return Semantics(
            button: true,
            selected: selected,
            label: '${_weekday(index)}, ${date.day}, $taskCount bakım görevi',
            child: InkWell(
              onTap: () => onSelected(date),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 64,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.darkGreen
                      : Colors.white.withValues(alpha: .86),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: taskCount > 0 && !selected
                        ? AppColors.green.withValues(alpha: .24)
                        : Colors.white.withValues(alpha: .72),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.darkGreen.withValues(alpha: .08),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _weekday(index),
                      style: TextStyle(
                        color: selected ? Colors.white70 : AppColors.muted,
                        fontWeight: FontWeight.w900,
                        fontSize: index < 2 ? 12 : 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.darkGreen,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: taskCount > 0 ? 24 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: taskCount > 0
                            ? (selected
                                  ? AppColors.lightGreen
                                  : AppColors.green)
                            : (selected ? Colors.white38 : AppColors.mint),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: taskCount > 0
                          ? Text(
                              '$taskCount',
                              style: TextStyle(
                                color: selected
                                    ? AppColors.darkGreen
                                    : Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _weekday(int index) {
    if (index == 0) {
      return 'Bugün';
    }
    if (index == 1) {
      return 'Yarın';
    }
    final weekday = _dateOnly(
      DateTime.now(),
    ).add(Duration(days: index)).weekday;
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return days[weekday - 1];
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Text(
        title,
        style: AppTextStyles.section.copyWith(color: AppColors.darkGreen),
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.tasks,
    required this.emptyText,
    required this.onComplete,
    this.highlight = false,
    this.focusTaskId,
    this.focusPlantId,
  });

  final List<CareTask> tasks;
  final String emptyText;
  final bool highlight;
  final String? focusTaskId;
  final String? focusPlantId;
  final ValueChanged<CareTask> onComplete;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(16),
        child: Text(emptyText, style: AppTextStyles.muted),
      );
    }

    return Column(
      children: tasks
          .map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TaskTile(
                task: task,
                highlight: highlight,
                focused:
                    (focusTaskId != null && task.id == focusTaskId) ||
                    (focusTaskId == null &&
                        focusPlantId != null &&
                        task.plantId == focusPlantId),
                onComplete: () => onComplete(task),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onComplete,
    this.highlight = false,
    this.focused = false,
  });

  final CareTask task;
  final bool highlight;
  final bool focused;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final tone = _colorFor(task.type);
    final emphasized = highlight || focused;
    return AppCard(
      color: emphasized ? AppColors.darkGreen : AppColors.card,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: emphasized
                  ? Colors.white.withValues(alpha: .16)
                  : tone.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              _iconFor(task.type),
              color: emphasized ? Colors.white : tone,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: AppTextStyles.section.copyWith(
                    color: emphasized ? Colors.white : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _dateLabel(task.dueDate),
                  style: AppTextStyles.muted.copyWith(
                    color: emphasized ? Colors.white70 : AppColors.muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _taskHint(task),
                  style: AppTextStyles.muted.copyWith(
                    color: emphasized ? Colors.white70 : AppColors.muted,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onComplete,
            child: Text(
              'Tamamla',
              style: TextStyle(
                color: emphasized ? AppColors.lightGreen : tone,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(CareTaskType type) {
    return switch (type) {
      CareTaskType.watering => Icons.water_drop_outlined,
      CareTaskType.fertilizing => Icons.grass_outlined,
      CareTaskType.leafCleaning => Icons.cleaning_services_outlined,
      CareTaskType.potCheck => Icons.inventory_2_outlined,
      CareTaskType.diseaseCheck => Icons.health_and_safety_outlined,
    };
  }

  Color _colorFor(CareTaskType type) {
    return switch (type) {
      CareTaskType.watering => AppColors.green,
      CareTaskType.fertilizing => AppColors.leaf,
      CareTaskType.leafCleaning => AppColors.soil,
      CareTaskType.potCheck => AppColors.warning,
      CareTaskType.diseaseCheck => AppColors.critical,
    };
  }

  String _dateLabel(DateTime date) {
    final now = _dateOnly(DateTime.now());
    final tomorrow = now.add(const Duration(days: 1));
    if (_sameDay(date, now)) {
      return 'Bugün';
    }
    if (_sameDay(date, tomorrow)) {
      return 'Yarın';
    }
    return '${date.day}.${date.month}.${date.year}';
  }

  bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String _taskHint(CareTask task) {
    final plantName = task.plantName ?? 'bitki';
    return switch (task.type) {
      CareTaskType.watering =>
        '$plantName için önce toprağın üst 2-3 cm nemini kontrol et.',
      CareTaskType.fertilizing =>
        '$plantName için gübreyi sadece aktif büyüme varsa uygula.',
      CareTaskType.leafCleaning =>
        '$plantName yapraklarını nemli yumuşak bezle nazikçe sil.',
      CareTaskType.potCheck =>
        '$plantName saksısında drenaj ve tabakta su birikimi var mı bak.',
      CareTaskType.diseaseCheck =>
        '$plantName yaprak altlarını, yeni lekeleri ve zararlı izlerini incele.',
    };
  }
}
