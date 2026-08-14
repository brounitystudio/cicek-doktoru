import {CauseCode, DiagnosisJson, PossibleCause, Severity} from "../types";

const causeCodes: CauseCode[] = [
  "overwatering",
  "underwatering",
  "low_light",
  "sunburn",
  "low_humidity",
  "nutrient_deficiency",
  "fungal_risk",
  "pests_risk",
  "root_stress",
  "pot_drainage_issue",
  "healthy",
  "unknown",
];

const severities: Severity[] = ["low", "medium", "high"];

export function fallbackDiagnosis(): DiagnosisJson {
  return {
    isPlant: true,
    plantGuess: "Belirsiz",
    healthScore: 60,
    severity: "medium",
    visualFindings: ["Fotoğraf üzerinden net görsel bulgu çıkarılamadı; yakın çekim önerilir."],
    symptoms: ["Fotoğraf üzerinden güvenli analiz tamamlanamadı."],
    possibleCauses: [{code: "unknown", label: "Görüntü yetersiz", confidence: 0.25}],
    needsCloseup: true,
    quickActions: ["Emin olmak için yaprak ve toprağın yakın çekimini ekleyin."],
    sevenDayPlan: [],
    safetyNote: "Sorun yayılıyorsa uzman/çiçekçi desteği alın.",
    confidenceNote: "Fotoğraf netliği veya açı nedeniyle sonuç düşük güvenle oluşturuldu.",
  };
}

export function validateDiagnosisJson(value: unknown): DiagnosisJson {
  if (!isRecord(value)) {
    return fallbackDiagnosis();
  }

  const isPlant = typeof value.isPlant === "boolean" ? value.isPlant : true;
  const visualFindings = normalizeStringList(value.visualFindings, 5);
  const plantGuess = safeString(value.plantGuess, "Belirsiz");
  const needsCloseup = !isPlant ||
    value.needsCloseup === true ||
    visualFindings.length < 2 ||
    plantGuess.toLocaleLowerCase("tr").includes("belirsiz");
  const possibleCauses = normalizeCauses(value.possibleCauses).map((cause) => ({
    ...cause,
    confidence: needsCloseup ? Math.min(cause.confidence, 0.59) : cause.confidence,
  }));
  const healthScore = isPlant ? clampNumber(value.healthScore, 0, 100, 60) : 0;

  return {
    isPlant,
    plantGuess: isPlant ? plantGuess : "Bitki algılanamadı",
    healthScore,
    severity: severities.includes(value.severity as Severity) ? value.severity as Severity : severityFromScore(healthScore),
    visualFindings,
    symptoms: normalizeStringList(value.symptoms, 6),
    possibleCauses: isPlant && possibleCauses.length > 0 ?
      possibleCauses :
      [{code: "unknown", label: "Görüntü yetersiz", confidence: 0.25}],
    needsCloseup,
    quickActions: normalizeStringList(value.quickActions, 4),
    sevenDayPlan: normalizeStringList(value.sevenDayPlan, 7),
    safetyNote: safeString(value.safetyNote, "Kesin teşhis değildir. Sorun yayılıyorsa uzman/çiçekçi desteği alın."),
    confidenceNote: safeString(
      value.confidenceNote,
      needsCloseup ? "Fotoğraf açısı veya ayrıntı düzeyi sınırlı; yeni fotoğraf sonucu güçlendirir." : "",
    ),
  };
}

export function parseDiagnosisJson(rawText: string): DiagnosisJson {
  try {
    const cleaned = rawText.trim().replace(/^```json/i, "").replace(/^```/i, "").replace(/```$/i, "").trim();
    return validateDiagnosisJson(JSON.parse(cleaned));
  } catch {
    return fallbackDiagnosis();
  }
}

function normalizeCauses(value: unknown): PossibleCause[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.slice(0, 3).map((item) => {
    if (!isRecord(item)) {
      return {code: "unknown" as CauseCode, label: "Belirsiz", confidence: 0.5};
    }
    const code = causeCodes.includes(item.code as CauseCode) ? item.code as CauseCode : "unknown";
    return {
      code,
      label: safeString(item.label, "Belirsiz"),
      confidence: clampNumber(item.confidence, 0, 1, 0.5),
    };
  });
}

function normalizeStringList(value: unknown, maxItems: number): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.map((item) => safeString(item, "")).filter((item) => item.length > 0).slice(0, maxItems);
}

function safeString(value: unknown, fallback: string): string {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : fallback;
}

function clampNumber(value: unknown, min: number, max: number, fallback: number): number {
  const numberValue = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(numberValue)) {
    return fallback;
  }
  return Math.min(max, Math.max(min, numberValue));
}

function severityFromScore(score: number): Severity {
  if (score >= 80) {
    return "low";
  }
  if (score >= 50) {
    return "medium";
  }
  return "high";
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
