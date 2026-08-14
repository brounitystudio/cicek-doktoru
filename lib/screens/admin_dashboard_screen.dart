import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/admin_user.dart';
import '../services/admin_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/botanical_background.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  static const routeName = '/admin-dashboard';
  static const ownerEmail = 'brounitystudio@gmail.com';

  static bool canOpen() {
    final email = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
    return email == ownerEmail;
  }

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _service = AdminService();
  final _searchController = TextEditingController();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _creditsController = TextEditingController(text: '10');
  final _pushTitleController = TextEditingController(text: 'Çiçek Doktoru');
  final _pushBodyController = TextEditingController(
    text: 'Bitkilerin için yeni bir bakım notu var.',
  );

  late Future<List<AdminUser>> _usersFuture;
  AdminUser? _selectedUser;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _usersFuture = _service.listUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    _creditsController.dispose();
    _pushTitleController.dispose();
    _pushBodyController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers([String query = '']) async {
    final future = _service.listUsers(query: query);
    setState(() => _usersFuture = future);
    await future;
  }

  void _selectUser(AdminUser user) {
    setState(() {
      _selectedUser = user;
      _emailController.text = user.email;
      _nameController.text = user.displayName ?? '';
      _creditsController.text = user.rewardCredits.toString();
    });
  }

  Future<void> _runAdminAction(
    String successMessage,
    Future<void> Function() action,
  ) async {
    if (_busy) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      _showNotice(successMessage);
      await _loadUsers(_searchController.text.trim());
    } catch (error) {
      if (!mounted) return;
      _showNotice(_cleanError(error), isError: true);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _giveStandardPremium() {
    final email = _emailController.text.trim();
    return _runAdminAction(
      '$email premium yapıldı.',
      () => _service.setPremium(
        email: email,
        plan: 'premium_monthly',
        subscriptionActive: true,
        premiumMonthlyLimit: 100,
        maxSavedPlants: 9999,
      ),
    );
  }

  Future<void> _giveUnlimitedPremium() {
    final email = _emailController.text.trim();
    return _runAdminAction(
      '$email sınırsız premium yapıldı.',
      () => _service.setPremium(
        email: email,
        plan: 'premium_yearly',
        subscriptionActive: true,
        premiumMonthlyLimit: 999999,
        maxSavedPlants: 999999,
      ),
    );
  }

  Future<void> _makeFree() {
    final email = _emailController.text.trim();
    return _runAdminAction(
      '$email free plana alındı.',
      () => _service.setPremium(
        email: email,
        plan: 'free',
        subscriptionActive: false,
      ),
    );
  }

  Future<void> _saveCredits() {
    final email = _emailController.text.trim();
    final credits = int.tryParse(_creditsController.text.trim()) ?? 0;
    return _runAdminAction(
      '$email için ek hak güncellendi.',
      () => _service.setDiagnosisCredits(email: email, credits: credits),
    );
  }

  Future<void> _saveDisplayName() {
    final email = _emailController.text.trim();
    final displayName = _nameController.text.trim();
    return _runAdminAction(
      '$email ismi güncellendi.',
      () => _service.updateDisplayName(email: email, displayName: displayName),
    );
  }

  Future<void> _sendPush() {
    final email = _emailController.text.trim();
    return _runAdminAction(
      '$email için push gönderildi.',
      () => _service.sendPush(
        email: email,
        title: _pushTitleController.text.trim(),
        body: _pushBodyController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AdminDashboardScreen.canOpen()) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: const Center(child: Text('Bu ekran için admin hesabı gerekli.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _busy
                ? null
                : () => _loadUsers(_searchController.text.trim()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: BotanicalBackground(
        child: SafeArea(
          top: false,
          child: FutureBuilder<List<AdminUser>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              final users = snapshot.data ?? const <AdminUser>[];
              return RefreshIndicator(
                onRefresh: () => _loadUsers(_searchController.text.trim()),
                color: AppColors.green,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
                  children: [
                    _SearchCard(
                      controller: _searchController,
                      loading:
                          snapshot.connectionState == ConnectionState.waiting ||
                          _busy,
                      onSearch: () => _loadUsers(_searchController.text.trim()),
                    ),
                    const SizedBox(height: 12),
                    _SummaryCard(users: users),
                    const SizedBox(height: 12),
                    _ActionCard(
                      emailController: _emailController,
                      nameController: _nameController,
                      creditsController: _creditsController,
                      pushTitleController: _pushTitleController,
                      pushBodyController: _pushBodyController,
                      busy: _busy,
                      selectedUser: _selectedUser,
                      onStandardPremium: _giveStandardPremium,
                      onUnlimitedPremium: _giveUnlimitedPremium,
                      onFree: _makeFree,
                      onSaveCredits: _saveCredits,
                      onSaveName: _saveDisplayName,
                      onSendPush: _sendPush,
                    ),
                    const SizedBox(height: 12),
                    Text('Kullanıcılar', style: AppTextStyles.section),
                    const SizedBox(height: 10),
                    if (snapshot.hasError)
                      _ErrorCard(message: _cleanError(snapshot.error)),
                    if (!snapshot.hasError && users.isEmpty) const _EmptyCard(),
                    ...users.map(
                      (user) => _AdminUserCard(
                        user: user,
                        selected: user.email == _selectedUser?.email,
                        onTap: () => _selectUser(user),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showNotice(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? AppColors.critical : AppColors.darkGreen,
          content: Text(message),
        ),
      );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.controller,
    required this.loading,
    required this.onSearch,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      showPattern: false,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearch(),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Mail, isim veya uid ara',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            tooltip: 'Ara',
            onPressed: loading ? null : onSearch,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_rounded),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.users});

  final List<AdminUser> users;

  @override
  Widget build(BuildContext context) {
    final premium = users.where((user) => user.isPremium).length;
    final dailyUsed = users.fold<int>(
      0,
      (sum, user) => sum + user.dailyFreeUsed + user.premiumUsedThisMonth,
    );
    final totalDiagnosis = users.fold<int>(
      0,
      (sum, user) => sum + user.diagnosisCount,
    );
    final pushUsers = users.where((user) => user.hasPushToken).length;

    return AppCard(
      color: AppColors.darkGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Günlük kontrol',
            style: AppTextStyles.section.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryChip(label: 'Kullanıcı', value: '${users.length}'),
              _SummaryChip(label: 'Premium', value: '$premium'),
              _SummaryChip(label: 'Bugün hak', value: '$dailyUsed'),
              _SummaryChip(label: 'Toplam analiz', value: '$totalDiagnosis'),
              _SummaryChip(label: 'Push', value: '$pushUsers'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTextStyles.section.copyWith(color: Colors.white),
            ),
            Text(
              label,
              style: AppTextStyles.muted.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.emailController,
    required this.nameController,
    required this.creditsController,
    required this.pushTitleController,
    required this.pushBodyController,
    required this.busy,
    required this.selectedUser,
    required this.onStandardPremium,
    required this.onUnlimitedPremium,
    required this.onFree,
    required this.onSaveCredits,
    required this.onSaveName,
    required this.onSendPush,
  });

  final TextEditingController emailController;
  final TextEditingController nameController;
  final TextEditingController creditsController;
  final TextEditingController pushTitleController;
  final TextEditingController pushBodyController;
  final bool busy;
  final AdminUser? selectedUser;
  final VoidCallback onStandardPremium;
  final VoidCallback onUnlimitedPremium;
  final VoidCallback onFree;
  final VoidCallback onSaveCredits;
  final VoidCallback onSaveName;
  final VoidCallback onSendPush;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      showPattern: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Yetki işlemleri', style: AppTextStyles.section),
          const SizedBox(height: 4),
          Text(
            selectedUser == null
                ? 'Listeden kullanıcı seç veya mail yaz.'
                : '${selectedUser!.email} seçildi.',
            style: AppTextStyles.muted,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Kullanıcı maili',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: busy ? null : onStandardPremium,
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('Premium ver'),
              ),
              FilledButton.icon(
                onPressed: busy ? null : onUnlimitedPremium,
                icon: const Icon(Icons.all_inclusive_rounded),
                label: const Text('Sınırsız ver'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onFree,
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Free yap'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: creditsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ek teşhis hakkı',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Hak kaydet',
                onPressed: busy ? null : onSaveCredits,
                icon: const Icon(Icons.save_outlined),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Görünen isim',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'İsim kaydet',
                onPressed: busy ? null : onSaveName,
                icon: const Icon(Icons.badge_outlined),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: pushTitleController,
            decoration: const InputDecoration(
              labelText: 'Push başlığı',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: pushBodyController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Push mesajı',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onSendPush,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Push gönder'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminUserCard extends StatelessWidget {
  const _AdminUserCard({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final AdminUser user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AppCard(
          showPattern: false,
          color: selected ? AppColors.mint : AppColors.card,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      user.email,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _PlanBadge(user: user),
                ],
              ),
              if (user.displayName?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(user.displayName!, style: AppTextStyles.muted),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniStat(
                    'AI',
                    '${user.premiumUsedThisMonth}/${user.premiumMonthlyLimit}',
                  ),
                  _MiniStat('Ek hak', '${user.rewardCredits}'),
                  _MiniStat('Bugün', '${user.dailyFreeUsed}'),
                  _MiniStat('Analiz', '${user.diagnosisCount}'),
                  _MiniStat('Bitki', '${user.plantCount}'),
                  _MiniStat('Push', user.hasPushToken ? 'var' : 'yok'),
                ],
              ),
              if (user.lastSeenAt != null || user.lastDiagnosisAt != null) ...[
                const SizedBox(height: 10),
                Text(
                  [
                    if (user.lastSeenAt != null)
                      'Son giriş: ${user.lastSeenAt}',
                    if (user.lastDiagnosisAt != null)
                      'Son analiz: ${user.lastDiagnosisAt}',
                  ].join(' · '),
                  style: AppTextStyles.muted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final active = user.isPremium;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? AppColors.green : AppColors.warning,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          active ? 'Premium' : 'Free',
          style: AppTextStyles.muted.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: .75),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text('$label: $value', style: AppTextStyles.muted),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.warmCream,
      child: Text(message, style: AppTextStyles.body),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      showPattern: false,
      child: Text('Kullanıcı bulunamadı.'),
    );
  }
}

String _cleanError(Object? error) {
  final text = error?.toString() ?? 'İşlem tamamlanamadı.';
  return text
      .replaceFirst('Exception: ', '')
      .replaceFirst('[firebase_functions/permission-denied] ', '')
      .replaceFirst('[firebase_functions/invalid-argument] ', '');
}
