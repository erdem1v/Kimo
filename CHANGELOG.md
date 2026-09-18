# Değişiklik günlüğü

Biçim: [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/). Sürüm
numarası `pubspec.yaml`daki `version:` alanıdır; mağazaya çıkan ilk sürüm
1.0.0'dır.

## [1.0.0+1] — yayın adayı (2026-09-18)

İlk mağaza sürümü. Ayrıntılı gerekçeler ve bulgular `docs/task-*-raporu.md`
altında; yayın öncesi bütünsel denetim `docs/task-18-yayin-denetim-raporu.md`.

### Ürün
- Fotoğraftan soru kaydı: yapay zekâ analizi (OpenAI, kullanıcı onayıyla),
  çevrimdışı kuyruk, elle giriş yolu her durumda açık.
- Aralıklı tekrar: 1→3→7→30 gün merdiveni, hâkimiyet, sınav tarihine göre
  emeklilik; XP, seri, günlük hedef; oturum sonu ekranı.
- Sosyal: arkadaş kodu, arkadaşa soru gönderme, gelen kutusu, ortak seri,
  altı kademeli haftalık lig; engelleme ve şikâyet.
- Kimo maskotu ve dört ses tonu; kişiselleştirilmemiş yerel bildirimler ve
  push, sessiz saatler sunucuda.
- Analiz hakları: kayan pencere + aylık tavan; ödüllü reklamla ek hak
  (sunucu doğrulamalı); Kimo Plus aboneliği (mağaza ürünleri tanımlanınca
  açılacak — `ff_iap`).
- 13 yaş kapısı, koşul onayı defteri, uygulama içinden hesap silme.

### Güvenlik ve veri
- Bütün yazma yolları sunucu fonksiyonlarında; tablolar sütun düzeyinde
  kilitli (852 pgTAP iddiası, 61 mutasyon kontrolü).
- Çökme raporlarında kişisel veri temizleniyor; reklam kimliği hiç
  toplanmıyor (ATT istenmiyor, `AD_ID` izni kaldırıldı).
- `cleanup-anonymous` edge fonksiyonu servis rolü dışına kapatıldı (Task 18).

### Yayın hazırlığı
- Gerçek uygulama ikonu ve açılış ekranı (maskottan üretiliyor),
  `PrivacyInfo.xcprivacy`, tam SKAdNetwork listesi, `app-ads.txt`.
- Android: PKCS12 yükleme anahtarı, R8 kuralları, `.aab` üretimi;
  `ADMOB_APP_ID` olmadan yayın yapısı derlenmiyor; CI release artifact'ının
  imzasını `jarsigner` ile doğrulayıp sertifika parmak izini yükleme
  anahtarıyla karşılaştırıyor.
- Sentry: `environment` etiketi; `release`/`dist` otomatik.

### Yayın öncesi bütünsel denetimde düzeltilenler (Task 18)
- Satın alma yolunun üç edge fonksiyonu üretime hiç dağıtılmamıştı; dağıtıldı,
  IAP sırları tanımlandı (`ff_iap` mağaza kimlikleri gelene kadar kapalı).
- Çekim ekranı, çoklu çekim bayrağı + Kimo Plus birlikteyken boş çiziliyordu.
- Çoklu çekim özeti, yalnız doğru şıkkı eksik kalan soruyu "okunamadı"
  sayıyordu; artık "şık bekliyor".
- Gelen arkadaşlık isteğinde "Kabul et" iki satıra kırılıyordu; düğmeler iki
  sıraya alındı.
- Cevap paneli, tekrar planı yazılamadığında hem gün sözü hem hata veriyordu.
- Bildirimden gelen dokunuş, kabuk boştayken bir sonraki dokunuşa kadar
  bekliyordu.

### Bilinen sınırlar
- Apple ücretli geliştirici hesabı yok: iOS imzasız derleniyor; push için
  Push capability, arşiv için takım kimliği gerekiyor.
- Android AdMob uygulama kimliği henüz yok; `ADMOB_APP_ID` sırrı girilene
  kadar yayın yapısı üretilmiyor.
- Mağaza abonelik ürünleri ve doğrulama sırları (Apple/Google) hesap
  gerektiriyor; `ff_iap` o güne kadar kapalı.
- `legal_version` üretimde 1.3; metin 1.4'e mağaza metinleriyle birlikte
  geçecek.
