import {CauseCode, PlantAnswers, PossibleCause} from "../types";
import {
  PlantCareEntry,
  plantCareKind,
  soilTriggerText,
  wateringIntervalText,
} from "./plant_care_library_service";

interface OrganLanguage {
  primary: string;
  focus: string;
  healthySignal: string;
  stressSignal: string;
  detailCheck: string;
  noTouch?: string;
}

interface ActionContext {
  plantName: string;
  cause: CauseCode;
  answers?: PlantAnswers;
  plantCare?: PlantCareEntry;
  visualFindings: string[];
  possibleCauses?: PossibleCause[];
}

interface PlanOutput {
  visualFindings: string[];
  symptoms: string[];
  quickActions: string[];
  sevenDayPlan: string[];
  safetyNote: string;
  confidenceNote?: string;
}

interface SymptomSignals {
  yellowing: boolean;
  brownTips: boolean;
  spots: boolean;
  wilting: boolean;
  mushy: boolean;
  pests: boolean;
  drySoil: boolean;
  wetSoil: boolean;
  primary: "yellowing" | "brownTips" | "spots" | "wilting" | "mushy" | "pests" | "drySoil" | "wetSoil" | "none";
}

const genericPhrases = [
  "bitkinin genel görünümü",
  "genel durumunu değerlendirin",
  "toprağın nem durumunu",
  "saksının altında drenaj deliği",
  "bitkinin bulunduğu ortamın hava akışını",
  "mevcut belirtileri not et",
  "gereksiz sulama veya yer değişimi",
  "gelişimi tekrar değerlendir ve gerekirse uzman desteği al",
];

export function buildPlantActionPlan(context: ActionContext): PlanOutput {
  const profile = plantProfile(context.plantName, context.plantCare);
  const findings = buildEvidenceFindings(context, profile);
  const signals = detectSymptomSignals(findings, context.possibleCauses);
  const cause = refineCauseFromEvidence(context.cause, findings, context.possibleCauses, signals);
  const symptoms = personalizeSymptoms(
    symptomsFromEvidence(cause, findings, profile, signals),
    context,
    profile,
  );
  const quickActions = personalizeQuickActions(
    buildQuickActions(context, profile, cause, findings, signals),
    context,
    profile,
    cause,
  );
  const sevenDayPlan = personalizeSevenDayPlan(
    buildSevenDayPlan(context, profile, cause, findings, signals),
    context,
    profile,
    cause,
  );
  const safetyNote = safetyNoteFor(context, profile);
  const confidenceNote = confidenceNoteFor(context, profile, findings);

  return {
    visualFindings: findings,
    symptoms,
    quickActions,
    sevenDayPlan,
    safetyNote,
    confidenceNote,
  };
}

export function looksRepeatedOrGeneric(items: string[], plantName = "", findings: string[] = []): boolean {
  const joined = items.join(" ").toLocaleLowerCase("tr");
  const plantWords = meaningfulWords(plantName).filter((word) => !plantNameStopWords.has(word));
  const hasPlantWord = plantWords.some((word) => joined.includes(word));
  const hasEvidenceWord = findings.some((finding) => {
    const words = meaningfulWords(finding);
    return words.slice(0, 4).some((word) => joined.includes(word));
  });
  const genericHits = genericPhrases.filter((phrase) => joined.includes(phrase)).length;
  return items.length === 0 ||
    hasNearDuplicate(items) ||
    genericHits >= 2 ||
    (plantWords.length > 0 && !hasPlantWord && !hasEvidenceWord);
}

export function personalizePlantActionPlan(plan: PlanOutput, context: ActionContext): PlanOutput {
  const profile = plantProfile(context.plantName, context.plantCare);
  return {
    ...plan,
    symptoms: personalizeSymptoms(plan.symptoms, context, profile),
    quickActions: personalizeQuickActions(plan.quickActions, context, profile, context.cause),
    sevenDayPlan: personalizeSevenDayPlan(plan.sevenDayPlan, context, profile, context.cause),
  };
}

function personalizeSymptoms(
  symptoms: string[],
  context: ActionContext,
  profile: ReturnType<typeof plantProfile>,
): string[] {
  const symptom = String(context.answers?.symptomType ?? "").trim();
  const duration = String(context.answers?.symptomDuration ?? "").trim();
  if (!symptom) {
    return symptoms;
  }
  const reported = symptom.toLocaleLowerCase("tr").includes("sadece kontrol") ?
    `Kullanıcı ${profile.displayName} için belirgin bir sorun bildirmedi; sonuç koruyucu kontrol olarak yorumlandı.` :
    `Kullanıcı ${profile.displayName} için “${symptom}” bildirdi${duration ? `; süresi “${duration}”` : ""}. Bu bilgi fotoğraf bulgularından ayrı, destekleyici geçmiş olarak değerlendirildi.`;
  return uniqueStrings([reported, ...symptoms]).slice(0, 6);
}

function personalizeQuickActions(
  actions: string[],
  context: ActionContext,
  profile: ReturnType<typeof plantProfile>,
  cause: CauseCode,
): string[] {
  const contextual = [
    symptomFollowUpAction(context, profile),
    wateringContextAction(context, profile, cause),
    environmentContextAction(context, profile),
    context.answers?.hasDrainage ? drainageAction(context, profile) : undefined,
  ].filter((item): item is string => Boolean(item));
  if (contextual.length === 0) {
    return actions;
  }
  return uniqueStrings([
    actions[0] ?? contextual[0],
    contextual[0],
    ...actions.slice(1),
    ...contextual.slice(1),
  ]).slice(0, 4);
}

function personalizeSevenDayPlan(
  plan: string[],
  context: ActionContext,
  profile: ReturnType<typeof plantProfile>,
  cause: CauseCode,
): string[] {
  if (plan.length !== 7) {
    return plan;
  }
  const personalized = [...plan];
  const watering = wateringContextAction(context, profile, cause);
  const environment = environmentContextAction(context, profile);
  const symptom = symptomProgressCheckAction(context, profile);
  if (watering) {
    personalized[1] = `2. Gün: ${watering}`;
  }
  if (environment) {
    personalized[2] = `3. Gün: ${environment}`;
  }
  if (symptom) {
    personalized[4] = `5. Gün: ${symptom}`;
  }
  return personalized;
}

function wateringContextAction(
  context: ActionContext,
  profile: ReturnType<typeof plantProfile>,
  cause: CauseCode,
): string | undefined {
  const lastWatered = String(context.answers?.lastWatered ?? "").toLocaleLowerCase("tr");
  if (!lastWatered) {
    return undefined;
  }
  if (lastWatered.includes("bugün")) {
    return `${profile.displayName}: bugün suladığını belirttin; tekrar su verme. Fazla suyun akıp akmadığını ve ${profile.organ.focus} bölgesinde kötüleşme olup olmadığını izle.`;
  }
  if (lastWatered.includes("1-3")) {
    return `${profile.displayName}: son sulama 1-3 gün önceydi; takvime göre tekrar sulama yapma, ${profile.soilTrigger} ve ${profile.organ.stressSignal.toLocaleLowerCase("tr")} birlikte oluşursa karar ver.`;
  }
  if (lastWatered.includes("4-7")) {
    const caution = cause === "overwatering" || cause === "root_stress" ?
      "Fotoğraftaki fazla nem/kök stresi ihtimali nedeniyle yalnız geçen güne bakıp su verme." :
      "Toprağı ve bitki dokusunu birlikte kontrol et; yalnız geçen güne bakıp su verme.";
    return `${profile.displayName}: son sulama 4-7 gün önceydi. ${caution}`;
  }
  if (lastWatered.includes("hatırlam")) {
    return `${profile.displayName}: son sulama tarihi bilinmiyor; bugün saksı ağırlığını ve toprak durumunu not et, sonraki sulamayı ${profile.soilTrigger} planla.`;
  }
  return undefined;
}

function environmentContextAction(
  context: ActionContext,
  profile: ReturnType<typeof plantProfile>,
): string | undefined {
  const location = String(context.answers?.location ?? "").toLocaleLowerCase("tr");
  const sunlight = String(context.answers?.sunlight ?? "").toLocaleLowerCase("tr");
  if (!location && !sunlight) {
    return undefined;
  }
  const place = location.includes("outdoor") || location.includes("dış") ? "dış mekânda" : "iç mekânda";
  const indirect = sunlight.includes("direkt değil") || sunlight.includes("dolaylı");
  if (sunlight.includes("direkt") && !indirect) {
    return `${profile.displayName}: ${place} direkt güneş aldığını belirttin; yeni yanık/renk açılması oluşuyorsa öğle güneşini kademeli filtrele, aynı gün sık yer değiştirme.`;
  }
  if (sunlight.includes("az ışık")) {
    return `${profile.displayName}: ${place} az ışık aldığını belirttin; ${profile.organ.primary} formunu izleyerek daha aydınlık ama yakıcı olmayan konuma kademeli taşı.`;
  }
  if (sunlight.includes("aydınlık")) {
    return `${profile.displayName}: ${place} aydınlık ve dolaylı ışık düzenini 7 gün sabit tut; ${profile.organ.focus} değişimini aynı açıdan karşılaştır.`;
  }
  return `${profile.displayName}: ${place} bulunduğu koşulu fotoğraf takibinde sabit tut; ${profile.light}`;
}

function symptomFollowUpAction(
  context: ActionContext,
  profile: ReturnType<typeof plantProfile>,
): string | undefined {
  const symptom = String(context.answers?.symptomType ?? "").toLocaleLowerCase("tr");
  const duration = String(context.answers?.symptomDuration ?? "").trim();
  const durationText = duration ? ` (${duration})` : "";
  if (symptom.includes("sararma") || symptom.includes("solma")) {
    return `${profile.displayName}: bildirilen sararma/solmayı${durationText} aynı yaprak veya gövde üzerinde işaretleyip renk ve duruş değişimini karşılaştır.`;
  }
  if (symptom.includes("leke") || symptom.includes("çürüme")) {
    return `${profile.displayName}: bildirilen leke/çürümeyi${durationText} yakın çekimle kaydet; sınır büyümesi, yumuşama veya koku varsa sulamayı ertele ve bitkiyi ayrı gözlemle.`;
  }
  if (symptom.includes("böcek") || symptom.includes("yapışkan")) {
    return `${profile.displayName}: bildirilen böcek/yapışkanlık için${durationText} ${profile.organ.focus} bölgesini yakın çek; hareketli veya pamuksu iz görürsen diğer bitkilerden ayır.`;
  }
  if (symptom.includes("sadece kontrol")) {
    return `${profile.displayName}: belirgin sorun bildirmediğin için yeni müdahale yapma; ${profile.organ.healthySignal.toLocaleLowerCase("tr")}; aynı görünüm devam ediyor mu izle.`;
  }
  return undefined;
}

function symptomProgressCheckAction(
  context: ActionContext,
  profile: ReturnType<typeof plantProfile>,
): string | undefined {
  const symptom = String(context.answers?.symptomType ?? "").toLocaleLowerCase("tr");
  const duration = String(context.answers?.symptomDuration ?? "").trim();
  const history = durationPhrase(duration);
  if (symptom.includes("sararma") || symptom.includes("solma")) {
    return `${profile.displayName}: ${history} sararma/solmayı ilk fotoğrafla karşılaştır; renk alanı genişliyor veya duruş kötüleşiyorsa yeni yakın çekim al.`;
  }
  if (symptom.includes("leke") || symptom.includes("çürüme")) {
    return `${profile.displayName}: ${history} lekenin sınırını ilk fotoğrafla karşılaştır; büyüme, yumuşama veya koku varsa kök/saksı çevresini de görüntüle.`;
  }
  if (symptom.includes("böcek") || symptom.includes("yapışkan")) {
    return `${profile.displayName}: ${history} böcek/yapışkanlık bölgesini yeniden yakın çek; iz sayısı artıyorsa bitkiyi ayrı tutup uzman doğrulaması al.`;
  }
  if (symptom.includes("sadece kontrol")) {
    return `${profile.displayName}: ilk fotoğrafla karşılaştır; ${profile.organ.healthySignal.toLocaleLowerCase("tr")}; yeni belirti yoksa mevcut düzeni koru.`;
  }
  return undefined;
}

function durationPhrase(value: string): string {
  const duration = value.toLocaleLowerCase("tr");
  if (duration.includes("bugün")) {
    return "bugün fark edilen";
  }
  if (duration.includes("birkaç")) {
    return "birkaç gündür izlenen";
  }
  if (duration.includes("1 hafta") || duration.includes("haftadan fazla")) {
    return "bir haftadan uzun süredir izlenen";
  }
  if (duration.includes("bilmi")) {
    return "süresi bilinmeyen";
  }
  return "bildirilen";
}

const plantNameStopWords = new Set([
  "muhtemelen",
  "olabilir",
  "bitkisi",
  "bitki",
  "belirsiz",
  "türü",
]);

const similarityStopWords = new Set([
  ...plantNameStopWords,
  "bugün",
  "gün",
  "için",
  "olan",
  "olarak",
  "kontrol",
  "tekrar",
  "görünüm",
  "bitkinin",
  "yapma",
  "varsa",
]);

function meaningfulWords(value: string): string[] {
  return value.toLocaleLowerCase("tr")
    .split(/[^a-zçğıöşü]+/)
    .filter((word) => word.length >= 4);
}

function hasNearDuplicate(items: string[]): boolean {
  const tokenSets = items.map((item) => new Set(
    meaningfulWords(item).filter((word) => !similarityStopWords.has(word)),
  ));
  for (let left = 0; left < tokenSets.length; left += 1) {
    for (let right = left + 1; right < tokenSets.length; right += 1) {
      const smaller = Math.min(tokenSets[left].size, tokenSets[right].size);
      if (smaller < 3) {
        continue;
      }
      const overlap = [...tokenSets[left]].filter((word) => tokenSets[right].has(word)).length;
      if (overlap / smaller >= 0.75) {
        return true;
      }
    }
  }
  return false;
}

function buildEvidenceFindings(context: ActionContext, profile: ReturnType<typeof plantProfile>): string[] {
  const cleaned = uniqueStrings(context.visualFindings)
    .map(rewriteGenericSubject(context.plantName, profile.displayName))
    .filter((item) => !isWeakFinding(item))
    .slice(0, 5);

  if (cleaned.length >= 3) {
    return cleaned;
  }

  const generated = [
    `${profile.displayName} için ${profile.organ.primary} fotoğraftan okunabilir ana bölge olarak değerlendirildi.`,
    `${profile.organ.focus} görünümü kontrol edildi; görünmeyen kök/drenaj bilgisi kesin bulgu sayılmadı.`,
  ];

  if (context.cause === "healthy") {
    generated.push(`${profile.organ.healthySignal}; bakım planı müdahale değil koruma odaklı hazırlandı.`);
  } else if (context.cause === "underwatering") {
    generated.push(`${profile.organ.stressSignal}; sulama önerisi tek seferde aşırı su vermeyecek şekilde sınırlandı.`);
  } else {
    generated.push(`${profile.organ.detailCheck}; öneriler bu görsel kanıta göre özelleştirildi.`);
  }

  return uniqueStrings([...cleaned, ...generated]).slice(0, 5);
}

function symptomsFromEvidence(
  cause: CauseCode,
  findings: string[],
  profile: ReturnType<typeof plantProfile>,
  signals: SymptomSignals,
): string[] {
  const directSymptoms = directSymptomLines(profile, signals);
  if (directSymptoms.length > 0) {
    return uniqueStrings([...directSymptoms, ...findings.slice(0, 3)]).slice(0, 5);
  }
  if (cause === "healthy") {
    return [
      `${profile.displayName} için belirgin hastalık izi seçilmiyor.`,
      ...findings.slice(0, 2),
    ].slice(0, 4);
  }
  return findings.slice(0, 4);
}

function buildQuickActions(
  context: ActionContext,
  profile: ReturnType<typeof plantProfile>,
  cause: CauseCode,
  findings: string[],
  signals: SymptomSignals,
): string[] {
  const water = wateringAction(profile, cause);
  const light = lightAction(context, profile);
  const visual = `${profile.organ.focus} için aynı açıdan bugün referans fotoğrafı al; 3 gün sonra ${profile.organ.stressSignal.toLocaleLowerCase("tr")} var mı karşılaştır.`;
  const safety = profile.safetyAction;
  const symptomAction = symptomActionFor(context, profile, cause, signals);

  if (cause === "healthy") {
    return [
      `${profile.displayName}: bugün yeni müdahale yapma; ${profile.organ.healthySignal.toLocaleLowerCase("tr")} korunuyor mu izle.`,
      water,
      light,
      visual,
    ];
  }

  if (cause === "underwatering") {
    return uniqueStrings([
      symptomAction,
      `${profile.displayName} için ${profile.organ.stressSignal.toLocaleLowerCase("tr")} varsa tek seferde boğmadan kontrollü sulama yap.`,
      water,
      visual,
    ]).slice(0, 4);
  }

  if (cause === "overwatering" || cause === "root_stress" || cause === "pot_drainage_issue") {
    return uniqueStrings([
      symptomAction,
      drainageAction(context, profile),
      water,
      `${profile.organ.focus} çevresinde yumuşama, koku veya koyulaşma varsa sulamayı ertele ve yakın çekim al.`,
      safety,
    ]).slice(0, 4);
  }

  if (cause === "sunburn" || cause === "low_light") {
    return uniqueStrings([
      symptomAction,
      light,
      water,
      `${profile.organ.primary} üzerinde renk açılması, leke veya eğilme aynı yönde artıyor mu kontrol et.`,
    ]).slice(0, 4);
  }

  return uniqueStrings([
    symptomAction,
    findings[0] ? `${profile.displayName}: ${findings[0]}` : `${profile.displayName}: görünen bölgeyi aynı açıdan takip et.`,
    light,
    safety,
  ]).slice(0, 4);
}

function buildSevenDayPlan(
  context: ActionContext,
  profile: ReturnType<typeof plantProfile>,
  cause: CauseCode,
  findings: string[],
  signals: SymptomSignals,
): string[] {
  const water = wateringAction(profile, cause);
  const light = lightAction(context, profile);
  const drainage = drainageAction(context, profile);
  const findingLead = findings[0] ?? `${profile.organ.focus} görünümü referans alındı.`;
  const symptomAction = symptomActionFor(context, profile, cause, signals);

  if (cause === "healthy") {
    return [
      `1. Gün: ${profile.displayName} için ${profile.organ.focus} görünümünü aynı açıdan fotoğrafla; bugün yeni sulama veya gübre ekleme.`,
      `2. Gün: ${water}`,
      `3. Gün: ${light}`,
      `4. Gün: ${profile.organ.primary} üzerinde yeni leke, yumuşama veya form kaybı yoksa konumu değiştirme.`,
      `5. Gün: ${drainage}`,
      `6. Gün: ${profile.cleaningAction}`,
      `7. Gün: İlk fotoğrafla karşılaştır; ${profile.organ.healthySignal.toLocaleLowerCase("tr")} devam ediyorsa mevcut bakım ritmini koru.`,
    ];
  }

  if (cause === "underwatering") {
    return [
      `1. Gün: ${symptomAction}`,
      `2. Gün: ${profile.organ.stressSignal} azaldı mı bak; tekrar sulama yapma.`,
      `3. Gün: ${light}`,
      `4. Gün: Saksı ağırlığını ve ${profile.organ.focus} görünümünü not et; ani toparlanma yoksa panik sulaması yapma.`,
      `5. Gün: ${findingLead} Bu bulguyu aynı açıyla tekrar kontrol et.`,
      `6. Gün: ${profile.cleaningAction}`,
      `7. Gün: ${profile.displayName} için yeni sulama aralığını ${profile.interval} olacak şekilde takvime işle.`,
    ];
  }

  if (cause === "overwatering" || cause === "root_stress" || cause === "pot_drainage_issue") {
    return [
      `1. Gün: ${symptomAction}`,
      `2. Gün: ${drainage}`,
      `3. Gün: ${light}`,
      `4. Gün: Toprak hâlâ nemliyse sulama yapma; ${profile.organ.primary} üzerindeki değişimi not et.`,
      `5. Gün: ${findingLead} Bulgu büyüyorsa yakın çekimle tekrar analiz al.`,
      `6. Gün: ${profile.organ.noTouch ?? profile.cleaningAction}`,
      `7. Gün: ${profile.soilTrigger} sağlanmadan sulama planlama; kötü koku/yumuşama varsa saksı-kök kontrolü için uzman desteği al.`,
    ];
  }

  if (cause === "sunburn") {
    return [
      `1. Gün: ${symptomAction}`,
      `2. Gün: ${profile.organ.primary} üzerinde leke sınırı büyüyor mu aynı açıdan kontrol et.`,
      `3. Gün: ${water}`,
      `4. Gün: ${profile.displayName} konumunu sabit tut; yeni ışığa alışması için yer değiştirmeyi azalt.`,
      `5. Gün: ${profile.cleaningAction}`,
      `6. Gün: ${profile.organ.focus} bölgesinde yeni açık renkli alan oluşursa yakın çekim al.`,
      `7. Gün: Leke ilerlemiyorsa filtreli ışık düzenini koru; yeni sürgünler sağlıklıysa müdahale etme.`,
    ];
  }

  if (cause === "low_light") {
    return [
      `1. Gün: ${symptomAction}`,
      `2. Gün: ${profile.organ.primary} yönünü ve eğilmesini kontrol et; saksıyı çok az çevir.`,
      `3. Gün: ${water}`,
      `4. Gün: ${profile.organ.healthySignal} belirginleşiyor mu fotoğrafla takip et.`,
      `5. Gün: ${drainage}`,
      `6. Gün: ${profile.cleaningAction}`,
      `7. Gün: Işık değişimi sonrası yeni gelişim yoksa daha aydınlık pencere yakınına kademeli taşı.`,
    ];
  }

  return [
    `1. Gün: ${symptomAction}`,
    `2. Gün: ${water}`,
    `3. Gün: ${light}`,
    `4. Gün: ${drainage}`,
    `5. Gün: ${profile.organ.detailCheck}`,
    `6. Gün: ${profile.cleaningAction}`,
    `7. Gün: Aynı açıdan tekrar fotoğraf çek; bulgular değiştiyse yeni analiz al.`,
  ];
}

function detectSymptomSignals(findings: string[], possibleCauses?: PossibleCause[]): SymptomSignals {
  const text = `${findings.join(" ")} ${possibleCauses?.map((item) => `${item.label} ${item.code}`).join(" ") ?? ""}`.toLocaleLowerCase("tr");
  const signals = {
    yellowing: /sar(ar|ı|i)|sarı|yellow/.test(text),
    brownTips: /kahverengi|uç.*kur|kuruyan uç|yanık uç|brown/.test(text),
    spots: /leke|benek|nokta|spot|siyahlaş|kararma/.test(text),
    wilting: /solgun|pörs|sark|buruş|cansız|wilting/.test(text),
    mushy: /yumuşa|çürü|koku|mushy|soft/.test(text),
    pests: /pamuksu|böcek|zararlı|bit |akar|kabuklu|pest/.test(text),
    drySoil: /toprak.*kuru|kuru.*toprak|çatlak|susuz|underwatering/.test(text),
    wetSoil: /ıslak|nemli|su birik|fazla su|overwatering|root_stress|drainage/.test(text),
    primary: "none" as SymptomSignals["primary"],
  };
  signals.primary =
    signals.mushy ? "mushy" :
      signals.pests ? "pests" :
        signals.yellowing ? "yellowing" :
          signals.spots ? "spots" :
            signals.brownTips ? "brownTips" :
              signals.wilting ? "wilting" :
                signals.wetSoil ? "wetSoil" :
                  signals.drySoil ? "drySoil" : "none";
  return signals;
}

function directSymptomLines(profile: ReturnType<typeof plantProfile>, signals: SymptomSignals): string[] {
  const lines: string[] = [];
  if (signals.yellowing) {
    lines.push(`${profile.displayName} üzerinde sararma belirtisi var; bu sadece "az su" demek değildir, ışık-nem-drenaj birlikte kontrol edilmeli.`);
  }
  if (signals.mushy) {
    lines.push(`${profile.displayName} için yumuşama/çürüme sinyali kritik; fazla nem veya kök stresi öncelikli risk kabul edilmeli.`);
  }
  if (signals.spots) {
    lines.push(`${profile.displayName} üzerinde leke/kararma sinyali var; lekenin büyüyüp büyümediği aynı açıdan takip edilmeli.`);
  }
  if (signals.brownTips) {
    lines.push(`${profile.displayName} yaprak/gövde uçlarında kuruma sinyali var; kuru hava, düzensiz sulama veya ışık stresi ayrılmalı.`);
  }
  if (signals.pests) {
    lines.push(`${profile.displayName} için zararlı izi ihtimali var; yaprak altı/diken dipleri yakın çekim kontrol edilmeli.`);
  }
  return lines;
}

function symptomActionFor(
  context: ActionContext,
  profile: ReturnType<typeof plantProfile>,
  cause: CauseCode,
  signals: SymptomSignals,
): string {
  if (signals.mushy || cause === "overwatering" || cause === "root_stress" || cause === "pot_drainage_issue") {
    if (signals.yellowing) {
      return `${profile.displayName}: sararma fazla nemle birlikteyse bugün sulama yapma; tabağı boşalt, sararan yaprağı temiz makasla al ve dipte yumuşama/koku varsa kök kontrolü planla.`;
    }
    return `${profile.displayName}: fazla nem/kök stresi ihtimalinde bugün sulama yapma; saksı tabağını boşalt, dipte yumuşama-koku-kararma var mı yakın kontrol et.`;
  }

  if (signals.yellowing) {
    if (cause === "underwatering" || signals.drySoil) {
      return `${profile.displayName}: sararma kuru toprakla birlikteyse tek seferde boğmadan derin sulama yap; 24 saat sonra yaprak/gövde toparlanmasını kontrol et, üst üste su verme.`;
    }
    if (cause === "low_light") {
      return `${profile.displayName}: sararma ışık azlığından şüpheliyse 7 gün boyunca daha aydınlık ama yakıcı olmayan konuma al; aynı gün gübre ve aşırı sulama yapma.`;
    }
    return `${profile.displayName}: sararma için bugün üçlü kontrol yap: toprak nemi, drenaj ve ışık. Nemliyse sulama yok; kuruysa ölçülü sulama; sararan dokuyu koparmadan temiz makasla al.`;
  }

  if (signals.pests || cause === "pests_risk") {
    return `${profile.displayName}: zararlı şüphesinde yaprak altı/diken diplerini yakın çek; pamuksu veya hareketli iz varsa bitkiyi diğerlerinden ayır ve kimyasal ilaç kullanmadan önce doğrula.`;
  }

  if (signals.spots || cause === "fungal_risk") {
    return `${profile.displayName}: leke/kararma için yaprak veya gövdeyi ıslatma; hava akışını artır, leke sınırını fotoğrafta işaretle ve büyürse yakın çekim tekrar analiz al.`;
  }

  if (signals.brownTips || cause === "sunburn") {
    return `${profile.displayName}: uç kuruması/yanıkta hasarlı alanı hemen kesme; yakıcı güneşi filtrele, sulamayı sadece toprak gerçekten uygunsa yap.`;
  }

  if (signals.wilting) {
    return `${profile.displayName}: solgunlukta önce toprağı parmakla kontrol et; ıslaksa sulama durur, kuruysa yavaş sulama yapılır. İki ihtimali aynı anda tedavi etme.`;
  }

  if (cause === "low_light") {
    return `${profile.displayName}: aydınlık ama yakıcı olmayan bir nokta seç; 7 gün aynı konumda takip et ve ani direkt güneşe çıkarma.`;
  }

  if (cause === "underwatering" || signals.drySoil) {
    return `${profile.displayName}: kuru toprak tek başına alarm değildir; ${profile.organ.stressSignal.toLocaleLowerCase("tr")} varsa ölçülü sulayıp fazla suyu uzaklaştır.`;
  }

  return `${profile.displayName}: bugün asıl hedef ${profile.organ.focus} bölgesini takip etmek; belirsiz belirti için aynı anda sulama, gübre ve yer değişimi yapma.`;
}

function plantProfile(plantName: string, plantCare?: PlantCareEntry) {
  const name = plantCare?.commonNames[0] ?? cleanPlantDisplayName(plantName);
  const id = plantCare?.id ?? "";
  const latin = plantCare?.latinName.toLocaleLowerCase("tr") ?? "";
  const category = plantCare?.category.toLocaleLowerCase("tr") ?? "";
  const displayKey = name.toLocaleLowerCase("tr");
  const kind = plantCareKind(plantCare);

  const base = {
    displayName: name,
    kind,
    soilTrigger: plantCare ? soilTriggerText(plantCare) : "üst 2-3 cm toprak kuruduğunda",
    interval: plantCare ? wateringIntervalText(plantCare) : "toprak kuruluğuna göre kontrol",
    light: plantCare?.light ?? "Aydınlık, direkt yakıcı olmayan konum.",
    organ: defaultOrgan(name),
    safetyAction: `${name} için görünmeyen kök/drenaj durumunu kesin hastalık sayma; yakın çekim gerekirse tekrar analiz al.`,
    cleaningAction: `${name} yaprak/gövde yüzeyindeki tozu nazikçe al; sağlıklı dokuyu kesme.`,
  };

  if (id === "euphorbia-trigona" || latin.includes("euphorbia") || displayKey.includes("süt ağacı")) {
    return {
      ...base,
      organ: {
        primary: "kolon gövde, kaburga hatları, tepe sürgünleri ve küçük yapraklar",
        focus: "gövde dipleri, kaburga araları ve tepe yaprakları",
        healthySignal: "kolon gövdeler dik, yeşil ve tepe sürgünleri formunu koruyor",
        stressSignal: "dipte yumuşama, sütlü özsu sızıntısı, kaburgada çökme veya tepe yapraklarında ani dökülme",
        detailCheck: "tepe sürgünleri ile gövde diplerini ayrı ayrı kontrol et",
        noTouch: "Sütlü özsu tahriş edicidir; kesim/kırık varsa eldivensiz dokunma.",
      },
      safetyAction: "Sütlü özsu tahriş edicidir; kırık/kesik varsa eldiven kullan ve çocuk/evcil hayvandan uzak tut.",
      cleaningAction: "Gövde kaburgaları arasındaki tozu kuru yumuşak fırçayla al; dikenli/yumuşak bölgeyi zorlamadan bırak.",
    };
  }

  if (id === "opuntia" || displayKey.includes("opuntia") || displayKey.includes("tavşan kulağı")) {
    return {
      ...base,
      organ: {
        primary: "yassı kulak gövdeler, ince dikenler ve dip bağlantıları",
        focus: "yassı gövde yüzeyi, dip bağlantıları ve diken kümeleri",
        healthySignal: "yassı gövdeler dik ve dolgun, diken kümeleri yerinde",
        stressSignal: "kulaklarda buruşma, dipte koyulaşma veya pamuksu zararlı izi",
        detailCheck: "yassı gövde kenarları ve dip birleşimlerini yakın kontrol et",
        noTouch: "İnce dikenler cilde kolay batar; çıplak elle temas etme.",
      },
      safetyAction: "İnce dikenler cilde kolay batar; bakımda kalın eldiven kullan.",
      cleaningAction: "Diken kümelerine dokunmadan saksı çevresindeki tozu temizle.",
    };
  }

  if (category.includes("cactus") || displayKey.includes("kaktüs")) {
    return {
      ...base,
      organ: {
        primary: "gövde, diken dizilimi, oluklar ve dip bölgesi",
        focus: "gövde yüzeyi, diken dipleri ve toprakla birleşen dip",
        healthySignal: "gövde dik, renk dengeli ve diken formu korunuyor",
        stressSignal: "gövde buruşması, dip yumuşaması, koyu leke veya diken diplerinde pamuksu iz",
        detailCheck: "diken dipleri ve gövde oluklarını yakın açıyla kontrol et",
        noTouch: "Dikenlere zarar vermeden sadece saksı çevresini temizle.",
      },
      safetyAction: "Dikenler batabilir; bakımda eldiven kullan ve gövdeyi sıkma.",
      cleaningAction: "Gövdeye bastırmadan saksı çevresindeki tozu temizle; dikenleri zorlamadan bırak.",
    };
  }

  if (id === "pasa-kilici" || latin.includes("trifasciata") ||
    displayKey.includes("paşa kılıcı") || displayKey.includes("kayınvalide dili")) {
    return {
      ...base,
      organ: {
        primary: "dik kılıç yapraklar, rozet araları ve yaprak dipleri",
        focus: "rozet içi, yaprak dipleri ve yaprak uçları",
        healthySignal: "yapraklar dik, sert ve desenini koruyor",
        stressSignal: "yaprak diplerinde yumuşama, sararma veya rozet içinde su birikimi",
        detailCheck: "rozet arasına su kaçıp kaçmadığını ve dip yumuşamasını kontrol et",
        noTouch: "Rozet içine su dökme; yaprak diplerini kuru bırak.",
      },
      safetyAction: "Rozet arasına su kaçırma; fazla nem dip çürümesini hızlandırabilir.",
      cleaningAction: "Yaprakları nemli bezle sil ama rozet içine su bırakma.",
    };
  }

  if (id.includes("orkide") || latin.includes("phalaenopsis") || displayKey.includes("orkide")) {
    return {
      ...base,
      organ: {
        primary: "hava kökleri, yapraklar, taç bölgesi ve çiçek sapı",
        focus: "kök rengi, taç kısmı ve yaprak dipleri",
        healthySignal: "kökler gri-yeşil, yapraklar dolgun ve taç kısmı temiz",
        stressSignal: "taçta su, kökte siyahlaşma, yaprakta pörsüme veya çiçek sapında kuruma",
        detailCheck: "şeffaf saksıdan kök rengini ve taç kısmını ayrı kontrol et",
        noTouch: "Taç kısmında su bırakma; çürüme riski oluşturabilir.",
      },
      safetyAction: "Taç kısmında su bırakma; kök rengi net değilse yakın çekimle kontrol et.",
      cleaningAction: "Yaprakları silerken taç kısmına su kaçırma; kuru çiçek dalını zorla koparma.",
    };
  }

  if (id === "baris-cicegi" || latin.includes("spathiphyllum") || displayKey.includes("barış çiçeği")) {
    return {
      ...base,
      organ: {
        primary: "geniş yapraklar, yaprak sapları ve çiçek/yelken formu",
        focus: "yaprak sarkması, yaprak ucu ve toprak yüzeyi",
        healthySignal: "yapraklar parlak, saplar diri ve form dengeli",
        stressSignal: "yaprak sarkması, uç yanığı, sararma veya toprakta uzun süreli ıslaklık",
        detailCheck: "sarkmanın susuzluk mu fazla su mu olduğunu toprakla birlikte kontrol et",
      },
      safetyAction: "Yaprak sarkmasında hemen sulama yapmadan önce toprağı kontrol et.",
      cleaningAction: "Geniş yaprakları nemli bezle sil; çiçek saplarını zorlamadan bırak.",
    };
  }

  if (kind === "dry") {
    return {
      ...base,
      organ: {
        primary: "etli yaprak/gövde, dip bölgesi ve toprak yüzeyi",
        focus: "yaprak dipleri, gövde sertliği ve toprak yüzeyi",
        healthySignal: "etli dokular dolgun, renk dengeli ve dip bölgesi kuru",
        stressSignal: "yumuşama, buruşma, dipte kararma veya yaprak dökülmesi",
        detailCheck: "etli doku sertliğini ve dipte renk değişimini kontrol et",
      },
      safetyAction: `${name} için sık sulama yapma; etli doku yumuşuyorsa fazla nem ihtimalini düşün.`,
      cleaningAction: "Etli yaprak/gövde üzerindeki tozu kuru yumuşak bezle al; kopan parçayı ıslak bırakma.",
    };
  }

  return base;
}

function defaultOrgan(name: string): OrganLanguage {
  return {
    primary: "yaprak rengi, yaprak ucu, gövde formu ve toprak yüzeyi",
    focus: "yaprak altı, yaprak ucu ve toprak yüzeyi",
    healthySignal: `${name} yaprakları formunu ve rengini koruyor`,
    stressSignal: "yeni sararma, leke, yaprak ucu kuruması veya gövde yumuşaması",
    detailCheck: "yaprak altı ve toprak yüzeyini yakın açıyla kontrol et",
  };
}

function wateringAction(profile: ReturnType<typeof plantProfile>, cause: CauseCode): string {
  if (profile.kind === "dry") {
    if (cause === "underwatering") {
      return `${profile.displayName}: sulama kararını takvimle değil doku + toprak kontrolüyle ver; buruşma/çökme varsa ölçülü sulayıp fazla suyu uzaklaştır. Ortalama ritim ${profile.interval}.`;
    }
    return `${profile.displayName}: etli doku sert ve dip bölgesi normalse sulama yapma; kuruluk ve form kaybı birlikte görülürse sulamayı planla. Ortalama ritim ${profile.interval}.`;
  }
  if (cause === "overwatering" || cause === "root_stress" || cause === "pot_drainage_issue") {
    return `${profile.displayName}: toprak nemliyse bugün sulama yapma; sararma/yumuşama artıyorsa fazla nem ihtimalini önceliklendir. Ortalama ritim ${profile.interval}.`;
  }
  return `${profile.displayName}: toprak gerçekten kuruduysa derin sulayıp fazla suyu uzaklaştır; sadece takvime bakarak sulama yapma. Ortalama ritim ${profile.interval}.`;
}

function lightAction(context: ActionContext, profile: ReturnType<typeof plantProfile>): string {
  const sunlight = String(context.answers?.sunlight ?? "").toLocaleLowerCase("tr");
  const indirect = sunlight.includes("direkt değil") || sunlight.includes("dolaylı");
  if (sunlight.includes("direkt") && !indirect && profile.kind === "dry") {
    return `${profile.displayName}: yakıcı öğle güneşi yerine çok aydınlık, filtreli ışıkta sabit tut.`;
  }
  return `${profile.displayName}: ${profile.light}`;
}

function drainageAction(context: ActionContext, profile: ReturnType<typeof plantProfile>): string {
  const drainage = String(context.answers?.hasDrainage ?? "").toLocaleLowerCase("tr");
  if (drainage.includes("hay")) {
    return `${profile.displayName}: drenaj deliği yoksa su biriktirme; ilk fırsatta delikli saksı veya iç-dış saksı düzeni planla.`;
  }
  return `${profile.displayName}: saksı tabağında su bekletme; drenaj görünmüyorsa bunu kesin sorun değil kontrol maddesi say.`;
}

function safetyNoteFor(context: ActionContext, profile: ReturnType<typeof plantProfile>): string {
  if (profile.safetyAction) {
    return profile.safetyAction;
  }
  if (context.cause === "pests_risk") {
    return "Zararlı şüphesinde kimyasal ilaç kullanmadan önce yaprak altlarını yakın çekimle doğrula.";
  }
  return "Kesin teşhis değildir; belirti hızla yayılırsa uzman/çiçekçi desteği alın.";
}

function confidenceNoteFor(context: ActionContext, profile: ReturnType<typeof plantProfile>, findings: string[]): string {
  const hasCloseupConcern = context.visualFindings.join(" ").toLocaleLowerCase("tr").includes("görünmüyor") ||
    context.visualFindings.join(" ").toLocaleLowerCase("tr").includes("net değil");
  if (hasCloseupConcern) {
    return `${profile.displayName} için görünen kısımlar değerlendirildi; kök/drenaj gibi seçilemeyen alanlarda yakın çekim sonucu güçlendirir.`;
  }
  return `${profile.displayName} için sonuç ${findings.length} görsel kanıt ve bakım arşivi eşleşmesiyle hazırlandı.`;
}

function refineCauseFromEvidence(
  cause: CauseCode,
  findings: string[],
  possibleCauses: PossibleCause[] | undefined,
  signals: SymptomSignals,
): CauseCode {
  if (cause !== "healthy") {
    return cause;
  }
  const meaningfulRisk = possibleCauses
    ?.filter((item) => item.code !== "healthy" && item.code !== "unknown")
    .sort((a, b) => b.confidence - a.confidence)[0];
  const evidenceText = findings.join(" ").toLocaleLowerCase("tr");
  if (meaningfulRisk && meaningfulRisk.confidence >= 0.62 && /buruş|yumuşa|sararma|leke|kuru|çök|sol/.test(evidenceText)) {
    return meaningfulRisk.code;
  }
  if (signals.mushy || signals.wetSoil) {
    return "root_stress";
  }
  if (signals.yellowing || signals.spots || signals.brownTips || signals.wilting || signals.pests) {
    return "unknown";
  }
  return cause;
}

function cleanPlantDisplayName(value: string): string {
  const cleaned = value.trim()
    .replace(/^(muhtemelen|büyük olasılıkla|olası)\s*[:\-]?\s*/i, "")
    .trim();
  return cleaned || "Bitkin";
}

function rewriteGenericSubject(plantName: string, displayName: string) {
  return (value: string) => {
    const text = value.trim();
    if (!text) {
      return text;
    }
    return text
      .replace(/^Bitkinin\b/i, `${displayName} bitkisinin`)
      .replace(/^Bitki\b/i, displayName)
      .replace(/^Kaktüsün\b/i, `${displayName} bitkisinin`)
      .replace(/^Kaktüs\b/i, displayName)
      .replace(plantName && plantName !== displayName ? plantName : "__NO_REPLACE__", displayName);
  };
}

function isWeakFinding(value: string): boolean {
  const text = value.toLocaleLowerCase("tr");
  return text.length < 14 ||
    text === "sağlıklı" ||
    text === "belirsiz" ||
    text.includes("genel değerlendirme") ||
    text.includes("fotoğraf yeterli") ||
    text.includes("kontrol edin") ||
    text.includes("gözlemleyin");
}

function uniqueStrings(items: string[]): string[] {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const item of items) {
    const clean = item.trim();
    if (!clean) {
      continue;
    }
    const key = clean.toLocaleLowerCase("tr");
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    result.push(clean);
  }
  return result;
}
