import {CareTemplate, CauseCode} from "../types";

const defaultWarning = "Kesin teşhis değildir. Sorun yayılıyorsa uzman/çiçekçi desteği alın.";

const templates: Record<CauseCode, CareTemplate> = {
  overwatering: {
    title: "Fazla sulama ihtimali",
    description: "Yaprak sararması ve nemli toprak görüntüsü fazla sulama/kök stresi ihtimalini artırıyor.",
    immediateActions: [
      "Toprağın üst 3-4 cm kısmını kontrol et.",
      "Toprak ıslaksa birkaç gün sulama yapma.",
      "Saksı tabağında su varsa boşalt.",
      "Bitkiyi direkt güneş değil, aydınlık bir alana al.",
    ],
    sevenDayPlan: [
      "1. Gün: Sulama yapma, toprak nemini kontrol et.",
      "2. Gün: Saksı tabağını ve drenajı kontrol et.",
      "3. Gün: Sararmış/çürümüş yaprakları temiz makasla al.",
      "4. Gün: Bitkiyi sabit ve aydınlık bir yerde tut.",
      "5. Gün: Türün kuruluk eşiği oluştuysa kök bölgesini eşit ıslat; fazla suyun saksıdan akmasına izin ver.",
      "6. Gün: Yeni sararma olup olmadığını kontrol et.",
      "7. Gün: Aynı açıdan tekrar fotoğraf çekerek gelişimi kontrol et.",
    ],
    warning: "Kötü koku, yumuşamış gövde veya hızla yayılan sararma varsa uzman/çiçekçi desteği alın.",
  },
  underwatering: template("Az sulama ihtimali", "Kuruma ve cansız yaprak görünümü su eksikliği ihtimalini artırıyor."),
  low_light: template("Işık eksikliği ihtimali", "Solgun gelişim ve zayıf yaprak görünümü ışık eksikliğine işaret edebilir."),
  sunburn: template("Güneş yanığı ihtimali", "Yapraklarda açık renkli yanık benzeri alanlar direkt güneş stresini düşündürebilir."),
  low_humidity: template("Düşük nem ihtimali", "Yaprak ucu kuruması ve kıvrılma düşük nemle ilişkili olabilir."),
  nutrient_deficiency: template("Besin eksikliği ihtimali", "Renk açılması ve yavaş gelişim besin eksikliğini düşündürebilir."),
  fungal_risk: template("Mantar riski", "Lekelenme ve yayılma eğilimi mantar riskini düşündürebilir; kimyasal öneri verilmez."),
  pests_risk: template("Zararlı riski", "Benekler veya yaprak hasarı zararlı riskini düşündürebilir; yaprak altlarını kontrol et."),
  root_stress: template("Kök stresi ihtimali", "Genel solgunluk ve sararma kök stresine bağlı olabilir."),
  pot_drainage_issue: template("Saksı drenaj sorunu", "Suyun saksıda birikmesi kök bölgesinde strese yol açabilir."),
  healthy: template("Sağlıklı görünüm", "Görüntüye göre belirgin bir stres işareti az görünüyor."),
  unknown: template("Belirsiz durum", "Fotoğraf net teşhis için yeterli olmayabilir; yakın çekim yardımcı olur."),
};

export function getCareTemplate(primaryCode: CauseCode): CareTemplate {
  return templates[primaryCode] ?? templates.unknown;
}

function template(title: string, description: string): CareTemplate {
  return {
    title,
    description,
    immediateActions: [
      "Bitkiyi görüntüye göre gözlemlemeye devam et.",
      "Toprak nemini parmağınla kontrol et.",
      "Bitkiyi ani yer değişimlerinden koru.",
      "Yakın çekim yaprak ve toprak fotoğrafı ile tekrar kontrol et.",
    ],
    sevenDayPlan: [
      "1. Gün: Mevcut belirtileri not et ve aynı açıdan fotoğraf çek.",
      "2. Gün: Toprak nemini ve ışık konumunu kontrol et.",
      "3. Gün: Yaprak altlarını ve yeni lekeleri gözlemle.",
      "4. Gün: Gereksiz sulama veya yer değişimi yapma.",
      "5. Gün: Belirtilerde artış varsa yakın çekim fotoğraf ekle.",
      "6. Gün: Kuruyan yaprakları temiz makasla ayır.",
      "7. Gün: Gelişimi tekrar değerlendir ve gerekirse uzman desteği al.",
    ],
    warning: defaultWarning,
  };
}
