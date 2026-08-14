import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/botanical_background.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  static const routeName = '/legal';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gizlilik ve Kullanım')),
      body: BotanicalBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: const [
              _LegalIntro(),
              SizedBox(height: 14),
              _LegalSection(
                title: 'Gizlilik Politikası',
                body: [
                  'Çiçek Doktoru; Apple veya Google hesabınla giriş yaptığında ad, e-posta, profil fotoğrafı, uygulama kullanım bilgileri, teşhis sonuçları, kaydettiğin bitkiler, bakım görevleri ve yüklediğin bitki fotoğraflarını saklayabilir.',
                  'Bitki fotoğrafları ve teşhis sonuçları Firebase altyapısında hesabınla ilişkilendirilir. Bu veriler uygulama deneyimini sürdürmek, bitki geçmişini göstermek, bakım hatırlatıcıları oluşturmak ve premium haklarını yönetmek için kullanılır.',
                  'Yapay zekâ analizleri için fotoğraf ve bakım cevapları güvenli backend üzerinden AI analiz servisine gönderilebilir. Analiz sonuçları kesin teşhis değildir.',
                  'Reklam gösterimi ve ödüllü reklam hakları için AdMob gibi üçüncü taraf servisler kullanılabilir. Premium kullanıcılar için reklam gösterimi kapatılabilir.',
                  'Satın alma ve abonelik bilgileri, premium haklarını doğrulamak ve yönetmek amacıyla App Store veya Google Play ile güvenli biçimde doğrulanabilir.',
                  'Hesabını ve uygulamayla ilişkilendirilmiş verilerini Profil > Hesabı ve Verileri Sil adımından kalıcı olarak silebilirsin. Gizlilik hakkında bilgi almak için brounitystudio@gmail.com adresinden Brounity Studio ile iletişime geçebilirsin.',
                ],
              ),
              _LegalSection(
                title: 'Kullanım Şartları',
                body: [
                  'Çiçek Doktoru bitki bakımına yardımcı olmak için tasarlanmıştır. Uygulama, profesyonel ziraat mühendisi, botanik uzmanı veya veteriner/sağlık danışmanı yerine geçmez.',
                  'Uygulamadaki öneriler ev tipi bitki bakımı için genel bilgilendirme niteliğindedir. Kimyasal ilaç, pestisit veya riskli müdahaleler için uzman görüşü alınmalıdır.',
                  'Ücretsiz kullanıcılar belirli analiz, reklam ödülü ve kayıt limitleriyle uygulamayı kullanabilir. Premium haklar satın alma koşullarına ve platform kurallarına göre değişebilir.',
                  'Kullanıcı; yüklediği fotoğrafların kendisine ait veya kullanmaya yetkili olduğu içerikler olduğunu kabul eder.',
                  'Hizmet; teknik bakım, üçüncü taraf servis kesintisi, faturalandırma veya bağlantı sorunları nedeniyle geçici olarak aksayabilir.',
                ],
              ),
              _LegalSection(
                title: 'İletişim ve Veri Talepleri',
                body: [
                  'Veri sorumlusu ve uygulama geliştiricisi: Brounity Studio.',
                  'İletişim: brounitystudio@gmail.com',
                  'Erişim ve düzeltme taleplerinde hesabında kullandığın e-posta adresini belirtmen istenebilir. Hesap silme işlemini uygulamadaki Profil ekranından doğrudan başlatabilirsin.',
                ],
              ),
              _LegalSection(
                title: 'AI Teşhis Uyarısı',
                body: [
                  'Yapay zekâ analizi fotoğraf kalitesi, ışık, açı, yaprak/toprak görünürlüğü ve kullanıcının verdiği bilgilere göre değişebilir.',
                  'Sonuçlar olasılıklı bakım yorumu olarak değerlendirilmelidir. Bitki hızla kötüleşiyorsa veya hastalık yayılıyorsa uzman desteği alınmalıdır.',
                  'Uygulama, kesin hastalık tanısı veya kimyasal tedavi talimatı vermez.',
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalIntro extends StatelessWidget {
  const _LegalIntro();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.darkGreen,
      child: Text(
        'Çiçek Doktoru, bitki bakım kararlarını desteklemek için fotoğraf ve verdiğin bakım bilgilerini kullanır. Verilerin ve kullanım seçeneklerin hakkında özet bilgileri aşağıda bulabilirsin.',
        style: AppTextStyles.body.copyWith(color: Colors.white),
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  const _LegalSection({required this.title, required this.body});

  final String title;
  final List<String> body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.section),
            const SizedBox(height: 10),
            ...body.map(
              (text) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(text, style: AppTextStyles.body),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
