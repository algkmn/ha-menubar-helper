# HA Menubar Helper

Home Assistant sıcaklık/nem sensörlerini macOS menü çubuğunda gösteren native Swift uygulaması. Dock ikonu yok, varsayılan olarak 15 saniyede bir günceller.

Her sensör bir grup olarak tanımlanır (ad + ikon + sıcaklık entity + nem entity). Menü çubuğunda seçili her grup kendi öğesini alır: solda ikon, sağında üstte sıcaklık altta nem. Öğeler Cmd ile sürüklenerek menü çubuğunda istenen sıraya dizilebilir, sıralama kalıcıdır.

## Ana pencere

Menü çubuğundaki değerlere tıklamak ana pencereyi açar; açılır menü yoktur. Pencereden:

- sunucu adresi, uzun ömürlü erişim anahtarı ve yenileme aralığı düzenlenir
- sensör grupları eklenir, silinir, adı, ikonu ve entity'leri değiştirilir
- ikon, satırdaki ikon düğmesinden açılan sistem sembolü listesinden seçilir
- her grubun menü çubuğunda görünüp görünmeyeceği kutucukla seçilir
- grupların o anki sıcaklık/nem değerleri ve son güncelleme zamanı görünür
- "Açılışta Başlat" açılıp kapatılır, "Çıkış" uygulamayı kapatır

"Kaydet" ayarları `~/.config/ha-menubar/config.json` dosyasına yazar ve uygulamayı anında yeniler.

## Yapılandırma dosyası

```json
{
  "baseURL": "http://homeassistant.local:8123",
  "token": "LONG_LIVED_ACCESS_TOKEN",
  "pollInterval": 15,
  "sensors": [
    {
      "name": "Salon",
      "icon": "sofa",
      "temperatureEntity": "sensor.sonoff_xxx_temperature",
      "humidityEntity": "sensor.sonoff_xxx_humidity",
      "showInMenuBar": true
    }
  ]
}
```

Token: Home Assistant > Profil > Güvenlik > Uzun Ömürlü Erişim Anahtarları.

`icon` bir SF Symbols adıdır; boş veya tanınmayan bir ad verilirse `thermometer.medium` kullanılır.

Tek sensörlü eski biçim (`temperatureEntity` / `humidityEntity` en üst düzeyde) okunmaya devam eder; ilk kaydetmede `sensors` dizisine dönüştürülür.

## Derleme

```bash
./build.sh
```

`"HA Menubar Helper.app"` paketini üretir. /Applications içine kurmak için:

```bash
./build.sh --install
```

## Çalıştırma

```bash
open "HA Menubar Helper.app"
```

İlk açılışta yerel ağ erişimi izni istenir; izin verilmelidir. Pencere kapalıyken Dock ikonu görünmez; pencere açıldığında geçici olarak belirir.
