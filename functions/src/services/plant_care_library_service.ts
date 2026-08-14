import {readFileSync} from "fs";
import {join} from "path";

type WateringStyle = "dry" | "moderate" | "moist" | "aquatic" | "rosette";

interface WateringProfile {
  style: WateringStyle;
  soilDryCm: [number, number];
  summerDays: [number, number];
  winterDays: [number, number];
  note: string;
}

export interface PlantCareEntry {
  id: string;
  commonNames: string[];
  latinName: string;
  category: string;
  watering: WateringProfile;
  light: string;
  specialTips: string[];
  avoid: string[];
}

interface PlantCareLibrary {
  version: string;
  locale: string;
  wateringPrinciples: string[];
  entries: PlantCareEntry[];
}

let libraryCache: PlantCareLibrary | undefined;
let promptBlockCache: string | undefined;

export function getPlantCareLibrary(): PlantCareLibrary {
  if (!libraryCache) {
    const filePath = join(__dirname, "..", "data", "plant_care_library.tr.json");
    libraryCache = JSON.parse(readFileSync(filePath, "utf8")) as PlantCareLibrary;
  }
  return libraryCache;
}

export function findPlantCareEntry(plantName: string): PlantCareEntry | undefined {
  const normalizedName = normalizeForMatch(plantName);
  if (!normalizedName) {
    return undefined;
  }

  let best: {entry: PlantCareEntry; score: number} | undefined;
  for (const entry of getPlantCareLibrary().entries) {
    const candidates = [entry.id, entry.latinName, ...entry.commonNames].map(normalizeForMatch);
    const score = Math.max(...candidates.map((candidate) => matchScore(normalizedName, candidate)));
    if (score > 0 && (!best || score > best.score)) {
      best = {entry, score};
    }
  }

  return best && best.score >= 55 ? best.entry : undefined;
}

export function buildPlantCarePromptBlock(): string {
  if (promptBlockCache) {
    return promptBlockCache;
  }

  const library = getPlantCareLibrary();
  const principles = library.wateringPrinciples.map((item) => `- ${item}`).join("\n");

  promptBlockCache = [
    "Çiçek Doktoru bakım arşivi sulama kuralları:",
    principles,
    "",
    "Türkiye'de yaygın saksı/balkon bitkilerinde türü fotoğraftan olabildiğince doğru tahmin et. Tam 100 bitkilik bakım arşivi backend tarafında eşleşmeden sonra uygulanır; bu yüzden gereksiz uzun bitki listesi yazma.",
    "Kaktüs/sukulent/paşa kılıcı gibi kuru seven türlerde tamamen kuruluk; barış çiçeği/calathea/eğrelti gibi nem seven türlerde üst toprak kuruluğu ve yaprak formu üzerinden öneri ver.",
    "Sulama gün aralığını kesin emir gibi değil, fotoğraf ve kullanıcı cevabıyla birlikte kontrol hatırlatması gibi yaz.",
  ].join("\n");

  return promptBlockCache;
}

export function plantCareSummary(entry: PlantCareEntry): Record<string, unknown> {
  return {
    id: entry.id,
    commonNames: entry.commonNames,
    latinName: entry.latinName,
    category: entry.category,
    watering: entry.watering,
    light: entry.light,
    specialTips: entry.specialTips,
    avoid: entry.avoid,
  };
}

export function plantCareKind(entry: PlantCareEntry | undefined): "dry" | "moist" | "default" {
  if (!entry) {
    return "default";
  }
  if (entry.watering.style === "dry") {
    return "dry";
  }
  if (entry.watering.style === "moist" || entry.watering.style === "aquatic" || entry.watering.style === "rosette") {
    return "moist";
  }
  return "default";
}

export function wateringQuickAction(entry: PlantCareEntry | undefined, cause: string): string | undefined {
  if (!entry) {
    return undefined;
  }

  const name = entry.commonNames[0] ?? entry.latinName;
  const interval = wateringIntervalText(entry);
  const trigger = soilTriggerText(entry);
  if (cause === "overwatering" || cause === "pot_drainage_issue" || cause === "root_stress") {
    return `${name}: ${trigger}; nemliyse sulama yapma. Ortalama kontrol aralığı ${interval}.`;
  }
  if (entry.watering.style === "dry") {
    return `${name}: toprak tamamen kurumadan sulama yapma. Ortalama kontrol aralığı ${interval}.`;
  }
  if (entry.watering.style === "aquatic") {
    return `${name}: su seviyesini/ıslaklığı kontrol et; kirli suyu tazele. Ortalama kontrol aralığı ${interval}.`;
  }
  if (entry.watering.style === "rosette") {
    return `${name}: rozet ve toprağı ayrı kontrol et; bayat su bırakma. Ortalama kontrol aralığı ${interval}.`;
  }
  return `${name}: ${trigger}; kuruysa derin sulayıp fazla suyu boşalt. Ortalama kontrol aralığı ${interval}.`;
}

export function wateringTaskOffsetDays(entry: PlantCareEntry | undefined, now = new Date()): number {
  if (!entry) {
    return 7;
  }

  const range = isWarmSeason(now) ? entry.watering.summerDays : entry.watering.winterDays;
  return Math.max(1, range[0]);
}

export function wateringReminderTitle(entry: PlantCareEntry | undefined, plantName: string): string {
  if (!entry) {
    return `${plantName}: yaprak ve toprak kontrolü`;
  }

  const name = entry.commonNames[0] ?? plantName;
  if (entry.watering.style === "dry") {
    return `${name}: sulamadan önce tam kuruluk kontrolü`;
  }
  if (entry.watering.style === "aquatic") {
    return `${name}: su seviyesi ve temizlik kontrolü`;
  }
  if (entry.watering.style === "rosette") {
    return `${name}: rozet suyu ve toprak kontrolü`;
  }
  return `${name}: ${soilTriggerText(entry)} kontrolü`;
}

export function wateringIntervalText(entry: PlantCareEntry): string {
  return `yazın ${formatDays(entry.watering.summerDays)}, kışın ${formatDays(entry.watering.winterDays)}`;
}

export function soilTriggerText(entry: PlantCareEntry): string {
  const [min, max] = entry.watering.soilDryCm;
  if (entry.watering.style === "aquatic") {
    return "su seviyesi/toprak ıslaklığı";
  }
  if (entry.watering.style === "dry" && max >= 10) {
    return "toprak tamamen kuruduğunda";
  }
  if (min === 0 && max <= 1) {
    return "toprak yüzeyi kurumaya başlamadan";
  }
  return `üst ${min}-${max} cm toprak kuruduğunda`;
}

function formatDays(days: [number, number]): string {
  return `${days[0]}-${days[1]} günde bir kontrol`;
}

function isWarmSeason(date: Date): boolean {
  const month = date.getMonth() + 1;
  return month >= 4 && month <= 10;
}

function matchScore(input: string, candidate: string): number {
  if (!candidate) {
    return 0;
  }
  if (input === candidate) {
    return 100;
  }
  if (input.includes(candidate) || candidate.includes(input)) {
    return 82;
  }

  const inputTokens = new Set(input.split(" ").filter((token) => token.length >= 3));
  const candidateTokens = candidate.split(" ").filter((token) => token.length >= 3);
  if (candidateTokens.length === 0) {
    return 0;
  }

  const hits = candidateTokens.filter((token) => inputTokens.has(token)).length;
  return Math.round((hits / candidateTokens.length) * 70);
}

function normalizeForMatch(value: string): string {
  return value
    .toLocaleLowerCase("tr")
    .replace(/ı/g, "i")
    .replace(/ğ/g, "g")
    .replace(/ü/g, "u")
    .replace(/ş/g, "s")
    .replace(/ö/g, "o")
    .replace(/ç/g, "c")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}
