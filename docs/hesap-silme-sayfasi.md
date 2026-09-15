# Hesap silme sayfası — yayınlanacak metin

**Bu dosya iç kullanım içindir; aşağıdaki "YAYINLANACAK METİN" bölümü olduğu
gibi bir web sayfasına konur.**

## Neden gerekli

Google Play, hesap oluşturmaya izin veren uygulamalardan **uygulama dışından
erişilebilen** bir hesap silme bağlantısı istiyor: kullanıcı uygulamayı silmiş
olsa bile hesabının ve verisinin silinmesini talep edebilmeli
(Play Console → Uygulama içeriği → Veri güvenliği). Bu, §2'deki **A-11**
bayrağının karşılığıdır.

## Nasıl yayınlanır

1. Sayfa, Gizlilik Politikası'nın yayınlandığı **aynı alan adında** durmalı.
2. Adres iki yere girilir: **Play Console'un hesap silme alanı** ve
   `supabase.json` içindeki **`LEGAL_DELETE_URL`** anahtarı (uygulama içindeki
   Ayarlar → Veri ve Gizlilik ekranı bu adresi kullanır).
3. Sayfa **oturum açmayı gerektirmemeli** ve tarayıcıdan doğrudan açılmalı.

## ⚠️ Sayfa neden bir form değil, bir talep yolu

`delete-account` edge fonksiyonunda **CORS bilinçli olarak yok** ("yalnızca
mobil istemci çağırıyor, tarayıcı origin'i yok" — `delete-account/index.ts:24`)
ve fonksiyon `uid`'yi **gövdeden değil JWT'den** okuyor. Yani bir web sayfası
tarayıcıdan silme çağrısı yapamaz; yapabilseydi, servis rolüyle çalışan bu uç
nokta "herkesi sil" primitifine dönerdi. Sayfayı bir form gibi göstermek
çalışmayan bir düğme koymak olurdu; bu yüzden metin **uygulama içi yolu
anlatıyor ve dışarıdan talep için e-posta adresi veriyor**. Gizlilik
Politikası §8 zaten bu ikili yapıyı varsayıyor.

## Doğruluk notu

Aşağıdaki metindeki her cümlenin kodda karşılığı var:
silme sırası ve "hepsi silinmezse hesap DURUR" davranışı
(`delete-account/index.ts:8-16, 111-134`), cascade listesi
(`20260902001000_cascade_audit.sql:20-56` + göç 0062'nin iki yeni defteri),
bekleme süresi olmaması (`account_repository.dart:9-18`), anonim hesapların
7 günde silinmesi (`20260902000800_anonymous.sql`).

---

# YAYINLANACAK METİN

## Kimo — Hesabımı sil

**Son güncelleme:** [tarih]

Hesabınızı ve verilerinizi istediğiniz zaman kalıcı olarak silebilirsiniz.
İki yol var.

### 1. Uygulama içinden (en hızlısı)

**Ayarlar → Hesabımı sil**

Onaylamak için takma adınızı yazmanız istenir. Bekleme süresi ve geri alma
penceresi yoktur; işlem tamamlandığında hesabınız gerçekten silinmiş olur.

### 2. Uygulamayı sildiyseniz veya erişemiyorsanız

**[iletişim e-postası]** adresine, hesabınıza kayıtlı e-posta adresinden bir
ileti gönderin ve konuya *"Hesap silme talebi"* yazın. Talebinizi **en geç 30
gün içinde** sonuçlandırırız. Kimliğinizi doğrulamak için sizden ek bilgi
isteyebiliriz — bu, başkasının sizin hesabınızı sildirmesini önlemek içindir.

---

### Silindiğinde ne oluyor?

**Önce dosyalarınız, sonra hesabınız siliniyor.** Fotoğraflarınız ve profil
görseliniz depolama alanından kaldırılmadan hesap silinmez; dosyaların tamamı
silinemezse **işlem durur ve hesabınız olduğu gibi kalır.** Yarım bir silmeyi
"silindi" diye göstermeyiz.

**Silinen veriler:**

- Arşivinizdeki tüm sorular ve **soru fotoğraflarınız**
- Profil fotoğrafınız
- Profiliniz: takma adınız, maskotunuz, doğum yılınız, arkadaş kodunuz
- XP'niz, seriniz, uygulama içi ödül bakiyeleriniz, lig geçmişiniz
- Abonelik kaydınız (varsa) — mağazadaki aboneliğinizi İPTAL ETMEZ;
  onu App Store / Google Play ayarlarından yapmanız gerekir
- Çalışma ve tekrar geçmişiniz, cevap kayıtlarınız
- Arkadaşlıklarınız ve arkadaşlık istekleriniz
- Gönderdiğiniz ve size gönderilen sorular
- Engellemeleriniz ve yaptığınız şikâyetler
- Onay kayıtlarınız
- Bildirim kaydınız (cihaz jetonunuz)
- Uygulama kurallarına uyum kayıtlarınız (varsa ihlal ve kısıtlama kayıtları)
- E-posta adresiniz ve hesabınızın kendisi

### Silmeden sonra geri getiremediklerimiz

Dürüst olmak adına bunları da yazıyoruz:

- **Daha önce yapay zekâ servisine gönderilmiş fotoğraflar.** Soru fotoğrafları
  okunmak ve içerik güvenliği taramasından geçmek üzere OpenAI'a gönderiliyor;
  gönderilmiş bir kopyayı geri çağıramayız.
- **Daha önce gönderilmiş bildirimler.**
- **Bir arkadaşınıza gönderdiğiniz sorunun onun tarafında kalan kaydı.**
- **Kimliğinizle ilişkilendirilmemiş teknik hata kayıtları** (hata izleme
  servisimizin saklama süresi boyunca). Bu kayıtlarda kullanıcı kimliğiniz ve
  e-posta adresiniz gönderilmeden önce silinir.

### Kayıt olmadan denediyseniz

Hesap açmadan uygulamayı denediyseniz hiçbir şey yapmanıza gerek yok:
kayıt olunmamış hesaplar **7 gün sonra otomatik olarak** silinir.

> Cihazınızda gönderilmeyi bekleyen fotoğraflar varsa onlar telefonunuzun
> kendi hafızasındadır; uygulamayı kaldırdığınızda onlar da gider.

### Tek bir soruyu silmek

**Uygulama içinde mevcut.** Sorunun kartındaki sil eylemi soruyu ve fotoğrafını
birlikte kaldırır; fotoğraf depolamadan da gerçekten silinir.

İstemezseniz **[iletişim e-postası]** adresine de yazabilirsiniz.

> *(Task 13 notu: bu bölüm "tek tek silme özelliği yok" diyordu ve AYNI
> depodaki Gizlilik Politikası §8 ile §1.9 "mevcut" diyordu — özellik Task
> 08'de eklenmişti. Bu sayfa Play Console'a giriliyor ve mağaza beyan-gerçek
> karşılaştırması tam olarak bu tür çelişkiyi arıyor.)*

### Diğer talepleriniz

Verilerinize erişmek, düzeltilmesini istemek, bir kopyasını almak veya
işlenmesine itiraz etmek için de aynı adrese yazabilirsiniz. Haklarınızın tam
listesi ve başvuru usulü için: [KVKK aydınlatma metni URL'i]

---

**[şirket unvanı]**
[açık adres]
[iletişim e-postası]

Gizlilik Politikası: [gizlilik politikası URL'i]
Kullanım Koşulları: [kullanım koşulları URL'i]
