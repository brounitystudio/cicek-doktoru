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
  static const _privacyUrl =
      'https://brounitystudio-d59af.web.app/privacy.html';
  static const _termsUrl =
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
  static const _supportUrl =
      'https://brounitystudio-d59af.web.app/support.html';

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
                _SubscriptionDisclosure(
                  monthlyPrice: monthly?.price,
                  yearlyPrice: yearly?.price,
                  onOpenPrivacy: () => _openLegalLink(_privacyUrl),
                  onOpenTerms: () => _openLegalLink(_termsUrl),
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
                    onRetry: _refreshCatalog,
                  )
                else if (catalog?.storeAvailable != true)
                  _StatusCard(
                    icon: Icons.storefront_outlined,
                    text: context.tr(
                      '$_storeName satın alma servisi bu cihazda hazır değil.',
                      '$_storeName billing is not ready on this device.',
                    ),
                    onRetry: _refreshCatalog,
                  )
                else if (catalog!.notFoundIds.isNotEmpty)
                  _StatusCard(
                    icon: Icons.info_outline,
                    text: context.tr(
                      'App Store abonelik bilgileri yüklenemedi. Satın almadan önce fiyatı görmek için tekrar dene.',
                      'App Store subscription information could not be loaded. Try again to view the price before purchasing.',
                    ),
                    onRetry: _refreshCatalog,
                  ),
                const SizedBox(height: 16),
                _PlanCard(
                  title: context.tr('Aylık Premium', 'Monthly Premium'),
                  price: monthly?.price,
                  cadence: context.tr('ay', 'month'),
                  durationLabel: context.tr('1 ay', '1 month'),
                  renewalText: context.tr(
                    'Aylık abonelik; iptal edilene kadar her ay otomatik yenilenir.',
                    'Monthly subscription; renews every month until cancelled.',
                  ),
                  purchaseLabel: context.tr(
                    'Aylık Premium’u Satın Al',
                    'Buy Monthly Premium',
                  ),
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
                      'Bitkiye özel ayrıntılı bakım profili',
                      'Detailed plant-specific care profile',
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
                  durationLabel: context.tr('1 yıl', '1 year'),
                  renewalText: context.tr(
                    'Yıllık abonelik; iptal edilene kadar her yıl otomatik yenilenir.',
                    'Yearly subscription; renews every year until cancelled.',
                  ),
                  purchaseLabel: context.tr(
                    'Yıllık Premium’u Satın Al',
                    'Buy Yearly Premium',
                  ),
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
                      'Karşılaştırmalı gelişim takibi ve özel bakım profili',
                      'Comparative progress tracking and a tailored care profile',
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
                      onPressed: () => _openLegalLink(_privacyUrl),
                      child: Text(
                        context.tr('Gizlilik Politikası', 'Privacy Policy'),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openLegalLink(_termsUrl),
                      child: Text(
                        context.tr(
                          'Kullanım Şartları (EULA)',
                          'Terms of Use (EULA)',
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openLegalLink(_supportUrl),
                      child: Text(context.tr('Destek', 'Support')),
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
    required this.durationLabel,
    required this.renewalText,
    required this.purchaseLabel,
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
  final String durationLabel;
  final String renewalText;
  final String purchaseLabel;
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
          Text(
            context.tr(
              'Abonelik süresi: $durationLabel',
              'Subscription length: $durationLabel',
            ),
            style: AppTextStyles.body.copyWith(
              color: foreground,
              fontWeight: FontWeight.w900,
            ),
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
          Text(
            renewalText,
            style: AppTextStyles.muted.copyWith(color: muted, height: 1.35),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: busy
                ? context.tr('İşlem sürüyor...', 'Processing...')
                : purchaseLabel,
            icon: Icons.workspace_premium,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

class _SubscriptionDisclosure extends StatelessWidget {
  const _SubscriptionDisclosure({
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.onOpenPrivacy,
    required this.onOpenTerms,
  });

  final String? monthlyPrice;
  final String? yearlyPrice;
  final VoidCallback onOpenPrivacy;
  final VoidCallback onOpenTerms;

  @override
  Widget build(BuildContext context) {
    final monthly = monthlyPrice == null
        ? context.tr(
            'Fiyat App Store’dan yükleniyor',
            'Price is loading from the App Store',
          )
        : '$monthlyPrice / ${context.tr('ay', 'month')}';
    final yearly = yearlyPrice == null
        ? context.tr(
            'Fiyat App Store’dan yükleniyor',
            'Price is loading from the App Store',
          )
        : '$yearlyPrice / ${context.tr('yıl', 'year')}';

    return AppCard(
      color: AppColors.warmCream.withValues(alpha: .92),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Abonelik bilgileri', 'Subscription information'),
            style: AppTextStyles.title,
          ),
          const SizedBox(height: 10),
          _DisclosureLine(
            title: context.tr('Aylık Premium', 'Monthly Premium'),
            detail: '${context.tr('Süre: 1 ay', 'Length: 1 month')} • $monthly',
          ),
          const SizedBox(height: 8),
          _DisclosureLine(
            title: context.tr('Yıllık Premium', 'Yearly Premium'),
            detail: '${context.tr('Süre: 1 yıl', 'Length: 1 year')} • $yearly',
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              'Ödeme App Store hesabından alınır. Abonelik, mevcut dönemin bitiminden en az 24 saat önce iptal edilmezse aynı süre ve geçerli fiyat üzerinden otomatik yenilenir. Abonelik App Store hesap ayarlarından yönetilebilir ve iptal edilebilir.',
              'Payment is charged to your App Store account. The subscription renews automatically for the same duration at the then-current price unless cancelled at least 24 hours before the end of the current period. You can manage or cancel it in your App Store account settings.',
            ),
            style: AppTextStyles.muted.copyWith(height: 1.4),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 0,
            children: [
              TextButton(
                onPressed: onOpenPrivacy,
                child: Text(
                  context.tr('Gizlilik Politikası', 'Privacy Policy'),
                ),
              ),
              TextButton(
                onPressed: onOpenTerms,
                child: Text(
                  context.tr('Kullanım Şartları (EULA)', 'Terms of Use (EULA)'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DisclosureLine extends StatelessWidget {
  const _DisclosureLine({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(detail, style: AppTextStyles.muted),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final Future<void> Function()? onRetry;

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
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => onRetry!(),
              child: Text(context.tr('Tekrar Dene', 'Try Again')),
            ),
          ],
        ],
      ),
    );
  }
}
