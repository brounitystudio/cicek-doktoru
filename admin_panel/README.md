# Çiçek Doktoru Admin Panel

Bu panel kullanıcı uygulamasına dahil değildir. Localhost üzerinde çalıştırılır.

## Çalıştırma

Proje kökünde:

```powershell
npx http-server admin_panel -p 5174
```

Sonra tarayıcıda:

```text
http://localhost:5174
```

Google ile `brounitystudio@gmail.com` hesabıyla giriş yap.

## Özellikler

- Kullanıcıları mail, isim veya UID ile arama
- Kullanıcıya aylık/yıllık premium verme
- Kullanıcıyı tekrar free plana alma
- FCM token varsa kullanıcıya test push gönderme

Backend tarafında admin erişimi sadece `admin=true` custom claim olan hesaplara veya `brounitystudio@gmail.com` owner mailine açıktır.
