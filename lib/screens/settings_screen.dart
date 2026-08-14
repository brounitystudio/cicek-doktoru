import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/user_plan.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/language_selection_screen.dart';
import '../screens/legal_screen.dart';
import '../screens/premium_screen.dart';
import '../screens/sign_in_screen.dart';
import '../services/auth_service.dart';
import '../services/entitlement_service.dart';
import '../services/language_service.dart';
import '../services/notification_service.dart';
import '../services/plant_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/botanical_background.dart';
import '../widgets/branded_header.dart';
import '../widgets/premium_badge.dart';
import '../widgets/safety_profile_sheet.dart';
import '../widgets/upgrade_banner.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<UserPlan> _planFuture;

  @override
  void initState() {
    super.initState();
    _planFuture = EntitlementService().getCurrentPlan();
  }

  Future<void> _refreshPlan() async {
    final future = EntitlementService().getCurrentPlan();
    setState(() {
      _planFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BotanicalBackground(
        child: SafeArea(
          child: FutureBuilder<UserPlan>(
            future: _planFuture,
            builder: (context, snapshot) {
              final plan = snapshot.data ?? UserPlan.freeMock();
              return RefreshIndicator(
                onRefresh: _refreshPlan,
                color: AppColors.green,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 118),
                  children: [
                    BrandedHeader(
                      eyebrow: context.tr(
                        'Hesap ve ayarlar',
                        'Account and settings',
                      ),
                      title: context.tr('Profil', 'Profile'),
                      subtitle: context.tr(
                        'Teşhis hakların ve bakım tercihlerin.',
                        'Your diagnosis credits and care preferences.',
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: _UserCard(plan: plan),
                    ),
                    const SizedBox(height: 14),
                    if (!plan.isPremium)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: UpgradeBanner(),
                      ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          _SettingsTile(
                            icon: Icons.workspace_premium_outlined,
                            title: context.tr('Premium', 'Premium'),
                            subtitle: context.tr(
                              'Ayda 100 detaylı AI teşhis',
                              '100 detailed AI diagnoses per month',
                            ),
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed(PremiumScreen.routeName),
                          ),
                          _SettingsTile(
                            icon: Icons.notifications_outlined,
                            title: context.tr('Hatırlatıcılar', 'Reminders'),
                            subtitle: context.tr(
                              'Bakım günlerini kaçırma',
                              'Do not miss care days',
                            ),
                            onTap: () async {
                              final tasks = await PlantRepository()
                                  .getCareTasks();
                              await NotificationService.instance
                                  .scheduleCareReminders(tasks);
                              if (!context.mounted) return;
                              _showStatusNotice(
                                context,
                                icon: Icons.notifications_active_outlined,
                                title: context.tr(
                                  'Hatırlatıcılar hazır',
                                  'Reminders ready',
                                ),
                                message: context.tr(
                                  'Bakım günlerin için bildirimler yeniden planlandı.',
                                  'Notifications for your care days were rescheduled.',
                                ),
                              );
                            },
                          ),
                          _SettingsTile(
                            icon: Icons.language_rounded,
                            title: context.tr('Dil', 'Language'),
                            subtitle: context.tr(
                              'Türkçe / İngilizce',
                              'Turkish / English',
                            ),
                            onTap: () async {
                              await showLanguagePicker(context);
                              if (context.mounted) {
                                setState(() {});
                              }
                            },
                          ),
                          _SettingsTile(
                            icon: Icons.health_and_safety_outlined,
                            title: context.tr(
                              'Evcil ve Çocuk Güvenliği',
                              'Pet and Child Safety',
                            ),
                            subtitle: context.tr(
                              'Kedi, köpek ve çocuk tercihlerini yönet',
                              'Manage cat, dog and child preferences',
                            ),
                            onTap: () => showSafetyProfileSheet(context),
                          ),
                          _SettingsTile(
                            icon: Icons.privacy_tip_outlined,
                            title: context.tr(
                              'Gizlilik ve Kullanım',
                              'Privacy and Usage',
                            ),
                            subtitle: context.tr(
                              'Veri ve izin tercihleri',
                              'Data and permission preferences',
                            ),
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed(LegalScreen.routeName),
                          ),
                          _SettingsTile(
                            icon: Icons.support_agent_outlined,
                            title: context.tr(
                              'Yardım / Destek',
                              'Help / Support',
                            ),
                            subtitle: context.tr(
                              'Bize mail gönder',
                              'Email us',
                            ),
                            onTap: () => _openSupportMail(context),
                          ),
                          if (AdminDashboardScreen.canOpen())
                            _SettingsTile(
                              icon: Icons.admin_panel_settings_outlined,
                              title: context.tr('Admin Paneli', 'Admin Panel'),
                              subtitle: context.tr(
                                'Kullanıcı ve hak yönetimi',
                                'User and access management',
                              ),
                              onTap: () => Navigator.of(
                                context,
                              ).pushNamed(AdminDashboardScreen.routeName),
                            ),
                          _SettingsTile(
                            icon: Icons.logout_rounded,
                            title: context.tr('Çıkış yap', 'Sign out'),
                            subtitle: context.tr(
                              'Google hesabından ayrıl',
                              'Leave your Google account',
                            ),
                            onTap: () async {
                              await AuthService().signOut();
                              if (!context.mounted) return;
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                SignInScreen.routeName,
                                (_) => false,
                              );
                            },
                          ),
                          _SettingsTile(
                            icon: Icons.star_rate_outlined,
                            title: context.tr(
                              'Uygulamayı Değerlendir',
                              'Rate the App',
                            ),
                            subtitle: context.tr(
                              'Çiçek Doktoru’na destek ol',
                              'Support Plant Doctor',
                            ),
                            onTap: () => _openStoreListing(context),
                          ),
                        ],
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
}

Future<void> _openSupportMail(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  final subject = Uri.encodeComponent('Çiçek Doktoru Destek');
  final body = Uri.encodeComponent(
    'Merhaba Çiçek Doktoru ekibi,\n\n'
    'Sorunum / geri bildirimim:\n\n\n'
    '---\n'
    'Kullanıcı: ${user?.email ?? 'Bilinmiyor'}\n'
    'Uygulama: Çiçek Doktoru',
  );
  final uri = Uri.parse(
    'mailto:brounitystudio@gmail.com?subject=$subject&body=$body',
  );

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }

  if (!context.mounted) {
    return;
  }
  _showStatusNotice(
    context,
    icon: Icons.mail_outline_rounded,
    title: context.tr('Mail uygulaması açılamadı', 'Mail app could not open'),
    message: context.tr(
      'Bize brounitystudio@gmail.com adresinden ulaşabilirsin.',
      'You can reach us at brounitystudio@gmail.com.',
    ),
  );
}

Future<void> _openStoreListing(BuildContext context) async {
  const packageName = 'com.brounitystudio.cicek_doktoru';
  final marketUri = Uri.parse('market://details?id=$packageName');
  final webUri = Uri.parse(
    'https://play.google.com/store/apps/details?id=$packageName',
  );

  if (await launchUrl(marketUri, mode: LaunchMode.externalApplication) ||
      await launchUrl(webUri, mode: LaunchMode.externalApplication)) {
    return;
  }
  if (!context.mounted) {
    return;
  }
  _showStatusNotice(
    context,
    icon: Icons.storefront_outlined,
    title: context.tr('Google Play açılamadı', 'Google Play could not open'),
    message: context.tr(
      'Uygulamayı Play Store içinden Çiçek Doktoru adıyla bulabilirsin.',
      'You can find the app in Play Store as Plant Doctor.',
    ),
  );
}

void _showStatusNotice(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 112),
        duration: const Duration(seconds: 3),
        content: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.green.withValues(alpha: .12)),
            boxShadow: [
              BoxShadow(
                color: AppColors.darkGreen.withValues(alpha: .14),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.mint,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: AppColors.darkGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(message, style: AppTextStyles.muted),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.plan});

  final UserPlan plan;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = plan.displayName?.trim().isNotEmpty == true
        ? plan.displayName!.trim()
        : user?.displayName?.trim();
    final email = plan.email?.trim().isNotEmpty == true
        ? plan.email!.trim()
        : user?.email?.trim();
    final photoURL = plan.photoURL?.trim().isNotEmpty == true
        ? plan.photoURL!.trim()
        : user?.photoURL;

    return AppCard(
      color: AppColors.darkGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: photoURL == null
                    ? const Icon(Icons.person, color: Colors.white, size: 32)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.network(photoURL, fit: BoxFit.cover),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName?.isNotEmpty == true
                          ? displayName!
                          : context.tr('Google kullanıcısı', 'Google user'),
                      style: AppTextStyles.section.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email?.isNotEmpty == true
                          ? email!
                          : plan.isPremium
                          ? context.tr(
                              'Premium bakım planı aktif',
                              'Premium care plan active',
                            )
                          : context.tr('Free plan', 'Free plan'),
                      style: AppTextStyles.muted.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              PremiumBadge(
                label: plan.isPremium
                    ? context.tr('Premium', 'Premium')
                    : context.tr('Free', 'Free'),
                tone: plan.isPremium ? AppColors.lightGreen : AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _Stat(
                label: context.tr('Kalan teşhis', 'Diagnoses left'),
                value: '${plan.remainingDiagnosisCount}',
              ),
              const SizedBox(width: 10),
              _Stat(
                label: context.tr('Bitki limiti', 'Plant limit'),
                value: plan.isPremium ? '∞' : '${plan.maxSavedPlants}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTextStyles.title.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.muted.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppColors.darkGreen),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle, style: AppTextStyles.muted),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
