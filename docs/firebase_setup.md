# Çiçek Doktoru Firebase Kurulum Notları

## 1. FlutterFire config

Firebase projesi oluşturulduktan sonra proje kökünde çalıştır:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Bu işlem `lib/firebase_options.dart`, Android için `google-services.json` ve iOS için `GoogleService-Info.plist` dosyalarını üretir. Paketler projeye eklendi:

- `firebase_core`
- `firebase_auth`
- `cloud_functions`

Uygulama açılışında Firebase best-effort initialize edilir. Config yoksa uygulama açılır, fakat gerçek AI analizi çağrısı yapılmaz.

## 2. Backend env / secret

Gemini API key Flutter içine koyulmayacak. Cloud Functions secret olarak ekle:

```bash
firebase functions:secrets:set GEMINI_API_KEY
```

Kod varsayılan olarak `gemini-2.0-flash-lite` kullanır. İstersen Functions deploy ortamında `GEMINI_MODEL` env değeri verilebilir.

## 3. Functions kurulumu ve deploy

Makinede Node.js, npm ve Firebase CLI hazır olduğunda:

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

Callable function:

```text
analyzePlantPhoto
```

Region:

```text
europe-west1
```

## 4. Firestore/Auth

Firebase Console üzerinde etkinleştir:

- Authentication: Anonymous sign-in
- Firestore Database
- Cloud Functions

Kullanıcı hakları `users/{userId}` dokümanında tutulur. AI teşhis geçmişi `users/{userId}/diagnoses/{diagnosisId}` altına yazılır.

## 5. Client mock modu

Firebase config tamamlanmadan UI akışını denemek için:

```bash
flutter run --dart-define=USE_MOCK_DIAGNOSIS=true
```

Gerçek AI moduna geçmek için mock define kullanmadan çalıştır:

```bash
flutter run
```

## 5.1. Tek komutla gerçek AI kurulum script'i

Önce Firebase CLI ile giriş yap:

```bash
firebase login
```

Sonra proje kökünde:

```powershell
.\tools\enable_real_ai.ps1 -ProjectId "FIREBASE_PROJECT_ID"
```

Script şunları yapar:

- `flutterfire configure`
- `GEMINI_API_KEY` secret kaydı
- Functions dependency kurulumu
- Functions TypeScript build
- `firebase deploy --only functions`
- `flutter analyze`
- `flutter test`

## 6. Gelir modeli callable function isimleri

Backend tarafında hazırlanmış callable function isimleri:

- `analyzePlantPhoto`
- `getUserEntitlements`
- `grantRewardCredit`
- `updatePremiumStatus`

`updatePremiumStatus` doğrudan client satın alma sonrası açık kullanılmaz; güvenilir backend/admin claim üzerinden plan güncellemek için placeholder olarak durur.

## 7. AdMob ve Google Play placeholderları

Flutter tarafında Google Mobile Ads paketi eklendi. Şimdilik Android manifest ve rewarded ad için Google test ID kullanılıyor:

- Android test app ID: `ca-app-pub-3940256099942544~3347511713`
- Rewarded test ad unit ID: `ca-app-pub-3940256099942544/5224354917`

Gerçek AdMob ID'leri gelince:

- Android app ID: `android/app/src/main/AndroidManifest.xml`
- Rewarded ad unit ID: `lib/services/ad_service.dart`

Google Play ürün ID placeholderları:

- Aylık Premium: `premium_monthly_6999`
- Yıllık Premium: `premium_yearly_59999`

Gerçek ürünler Google Play Console'da açılınca `lib/services/purchase_service.dart` içindeki servis katmanı gerçek billing akışına bağlanacak.
