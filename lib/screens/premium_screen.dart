import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/language_service.dart';
import '../services/purchase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  static const routeName = '/premium';

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  late Future<PurchaseCatalog> _catalogFuture;
  bool _busy = false;

  String get _storeName => PurchaseService.storeName;

  @override
  void initState() {
    super.initState();
    _catalogFuture = PurchaseService().loadCatalog();
  }

  Future<void> _refreshCatalog() async {
    setState(() => _catalogFuture = PurchaseService().loadCatalog());
    await _catalogFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Premium', 'Premium'))),
      body: FutureBuilder<PurchaseCatalog>(
        future: _catalogFuture,
        builder: (context, snapshot) {
          final catalog = snapshot.data;
          final monthly = catalog?.monthly;
          final yearly = catalog?.yearly;
          final loading = snapshot.connectionState != ConnectionState.done;

          return RefreshIndicator(
            onRefresh: _refreshCatalog,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  context.tr('Çiçek Doktoru Premium', 'Plant Doctor Premium'),
                  style: AppTextStyles.display.copyWith(fontSize: 30),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    'Bitkine özel ek nedenleri, bakım sırlarını ve 7 günlük kurtarma planını aç.',
                    'Unlock additional plant-specific causes, care insights and the full 7-day recovery plan.',
                  ),
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 16),
                if (loading)
                  _StatusCard(
                    icon: Icons.sync,
                    text: context.tr(
                      '$_storeName ürünleri kontrol ediliyor...',
                      'Checking $_storeName products...',
                    ),
                  )
                else if (snapshot.hasError)
                  _StatusCard(
                    icon: Icons.error_outline,
                    text: snapshot.error.toString(),
                  )
                else if (catalog?.storeAvailable != true)
                  _StatusCard(
                    icon: Icons.storefront_outlined,
                    text: context.tr(
                      '$_storeName satın alma servisi bu cihazda hazır değil.',
                      '$_storeName billing is not ready on this device.',
                    ),
                  )
                else if (catalog!.notFoundIds.isNotEmpty)
                  _StatusCard(
                    icon: Icons.info_outline,
                    text: context.tr(
                      'Premium satın alma kısa süre içinde aktif olacak.',
                      'Premium purchase will be available soon.',
                    ),
                  ),
                const SizedBox(height: 16),
                _PlanCard(
                  title: context.tr('Aylık Premium', 'Monthly Premium'),
                  price: monthly?.price,
                  cadence: context.tr('ay', 'month'),
                  highlighted: true,
                  product: monthly,
                  busy: _busy,
                  benefits: [
                    context.tr(
                      'Ayda 100 detaylı AI teşhis',
                      '100 detailed AI diagnoses per month',
                    ),
                    context.tr('Reklamsız kullanım', 'Ad-free use'),
                    context.tr(
                      'Sınırsız bitki kaydetme',
                      'Unlimited saved plants',
                    ),
                    context.tr(
                      'Analizdeki ek olası nedenler ve ayrıntılı öneriler',
                      'Additional possible causes and detailed guidance',
                    ),
                    context.tr(
                      '7 günlük plan ve Premium bakım sırları',
                      '7-day plan and Premium care insights',
                    ),
                    context.tr(
                      'Bakım takvimi ve hatırlatıcılar',
                      'Care calendar and reminders',
                    ),
                  ],
                  onPressed: monthly == null || _busy
                      ? null
                      : () => _runPurchase(PurchaseService().buyMonthlyPremium),
                ),
                const SizedBox(height: 14),
                _PlanCard(
                  title: context.tr('Yıllık Premium', 'Yearly Premium'),
                  price: yearly?.price,
                  cadence: context.tr('yıl', 'year'),
                  product: yearly,
                  busy: _busy,
                  badge: context.tr('En avantajlı', 'Best value'),
                  benefits: [
                    context.tr(
                      'Ayda 120 detaylı AI teşhis',
                      '120 detailed AI diagnoses per month',
                    ),
                    context.tr('12 ay reklamsız kullanım', '12 months ad-free'),
                    context.tr(
                      'Sınırsız bitki arşivi',
                      'Unlimited plant archive',
                    ),
                    context.tr(
                      'Ek olası nedenler, bakım sırları ve 7 günlük plan',
                      'Additional possible causes, care insights and the 7-day plan',
                    ),
                    context.tr(
                      'Karşılaştırmalı gelişim takibi ve hatırlatmalar',
                      'Comparative progress tracking and reminders',
                    ),
                    context.tr(
                      '12 aylık abonelik; iptal edilene kadar yıllık yenilenir',
                      '12-month subscription; renews yearly until cancelled',
                    ),
                  ],
                  onPressed: yearly == null || _busy
                      ? null
                      : () => _runPurchase(PurchaseService().buyYearlyPremium),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _runPurchase(PurchaseService().restorePurchases),
                  icon: const Icon(Icons.restore),
                  label: Text(
                    context.tr('Satın alımı geri yükle', 'Restore purchase'),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  context.tr(
                    'Abonelikler $_storeName hesabından yönetilir ve iptal edilene kadar otomatik yenilenir. İptal edersen Premium erişimin ödenmiş dönem sonuna kadar sürer. Aylık adil kullanım limiti uygulanır.',
                    'Subscriptions are managed through $_storeName and renew automatically until cancelled. If you cancel, Premium remains active until the end of the paid period. A monthly fair-use limit applies.',
                  ),
                  style: AppTextStyles.muted.copyWith(height: 1.35),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    TextButton(
                      onPressed: () => _openLegalLink(
                        'https://brounitystudio.github.io/cicek-doktoru/privacy.html',
                      ),
                      child: Text(
                        context.tr('Gizlilik Politikası', 'Privacy Policy'),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openLegalLink(
                        'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
                      ),
                      child: Text(
                        context.tr(
                          'Kullanım Şartları (EULA)',
                          'Terms of Use (EULA)',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _runPurchase(Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Premium hesabına tanımlandı.',
              'Premium has been added to your account.',
            ),
          ),
        ),
      );
      await _refreshCatalog();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openLegalLink(String value) async {
    final opened = await launchUrl(
      Uri.parse(value),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Bağlantı açılamadı.', 'The link could not be opened.'),
          ),
        ),
      );
    }
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.cadence,
    required this.benefits,
    required this.onPressed,
    required this.busy,
    this.product,
    this.highlighted = false,
    this.badge,
  });

  final String title;
  final String? price;
  final String cadence;
  final List<String> benefits;
  final VoidCallback? onPressed;
  final ProductDetails? product;
  final bool highlighted;
  final bool busy;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final background = highlighted ? AppColors.darkGreen : AppColors.card;
    final foreground = highlighted ? Colors.white : AppColors.ink;
    final muted = highlighted ? Colors.white70 : AppColors.muted;

    return AppCard(
      color: background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.title.copyWith(color: foreground),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: highlighted ? Colors.white24 : AppColors.mint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: AppTextStyles.muted.copyWith(
                      color: highlighted ? Colors.white : AppColors.darkGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (price != null)
            Text(
              '$price / $cadence',
              style: AppTextStyles.display.copyWith(
                fontSize: 32,
                color: foreground,
              ),
            )
          else
            Text(
              context.tr(
                'Fiyat mağaza bağlantısı kurulunca gösterilir.',
                'The price appears after connecting to the store.',
              ),
              style: AppTextStyles.body.copyWith(
                color: muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (product == null) ...[
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Bu ürün mağazada aktif olunca satın alınabilir.',
                'This product can be purchased once it is active in the store.',
              ),
              style: AppTextStyles.muted.copyWith(color: muted),
            ),
          ],
          const SizedBox(height: 16),
          ...benefits.map(
            (benefit) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: highlighted ? AppColors.lightGreen : AppColors.green,
                    size: 21,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      benefit,
                      style: AppTextStyles.body.copyWith(color: foreground),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: busy
                ? context.tr('İşlem sürüyor...', 'Processing...')
                : context.tr('Satın Al', 'Buy'),
            icon: Icons.workspace_premium,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: AppColors.warmCream.withValues(alpha: .86),
      child: Row(
        children: [
          Icon(icon, color: AppColors.darkGreen, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.muted.copyWith(
                color: AppColors.darkGreen,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
