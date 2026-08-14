export type CauseCode =
  | "overwatering"
  | "underwatering"
  | "low_light"
  | "sunburn"
  | "low_humidity"
  | "nutrient_deficiency"
  | "fungal_risk"
  | "pests_risk"
  | "root_stress"
  | "pot_drainage_issue"
  | "healthy"
  | "unknown";

export type Severity = "low" | "medium" | "high";

export interface PlantAnswers {
  location?: "indoor" | "outdoor" | string;
  lastWatered?: string;
  sunlight?: string;
  hasDrainage?: string;
  symptomType?: string;
  symptomDuration?: string;
  language?: "tr" | "en" | string;
}

export interface AnalyzePlantPhotoInput {
  imageBase64?: string;
  imageBase64List?: string[];
  imageUrl?: string;
  imageUrls?: string[];
  mimeType?: string;
  answers?: PlantAnswers;
}

export interface PossibleCause {
  code: CauseCode;
  label: string;
  confidence: number;
}

export interface DiagnosisJson {
  isPlant: boolean;
  plantGuess: string;
  healthScore: number;
  severity: Severity;
  visualFindings: string[];
  symptoms: string[];
  possibleCauses: PossibleCause[];
  needsCloseup: boolean;
  quickActions: string[];
  sevenDayPlan: string[];
  safetyNote: string;
  confidenceNote?: string;
}

export interface CareTemplate {
  title: string;
  description: string;
  immediateActions: string[];
  sevenDayPlan: string[];
  warning: string;
}
