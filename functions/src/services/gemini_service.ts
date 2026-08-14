import {GoogleGenerativeAI, SchemaType, type ResponseSchema} from "@google/generative-ai";
import {AnalyzePlantPhotoInput, DiagnosisJson} from "../types";
import {parseDiagnosisJson} from "../utils/validate_diagnosis_json";
import {buildPlantCarePromptBlock} from "./plant_care_library_service";

const defaultModelName = process.env.GEMINI_MODEL || "gemini-2.5-flash-lite";

export class GeminiService {
  private readonly client: GoogleGenerativeAI;
  private readonly modelName: string;

  constructor(apiKey = process.env.GEMINI_API_KEY, modelName = defaultModelName) {
    if (!apiKey) {
      throw new Error("GEMINI_API_KEY environment variable is missing.");
    }
    this.client = new GoogleGenerativeAI(apiKey);
    this.modelName = modelName;
  }

  async analyzePlantPhoto(input: AnalyzePlantPhotoInput): Promise<DiagnosisJson> {
    const images = await resolveImages(input);
    if (images.length === 0) {
      throw new Error("At least one image is required for Gemini analysis.");
    }

    const model = this.client.getGenerativeModel({
      model: this.modelName,
      generationConfig: {
        temperature: 0.15,
        maxOutputTokens: 1100,
        responseMimeType: "application/json",
        responseSchema: diagnosisResponseSchema,
      },
    });

    const result = await generateContentWithRetry(model, [
      buildPrompt(input),
      ...images.map((image) => ({
        inlineData: {
          data: image.data,
          mimeType: image.mimeType,
        },
      })),
    ]);

    return parseDiagnosisJson(result.response.text());
  }
}

async function generateContentWithRetry(
  model: ReturnType<GoogleGenerativeAI["getGenerativeModel"]>,
  parts: Parameters<ReturnType<GoogleGenerativeAI["getGenerativeModel"]>["generateContent"]>[0],
) {
  let lastError: unknown;
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      return await model.generateContent(parts);
    } catch (error) {
      lastError = error;
      if (attempt === 1 || !isRetryableGeminiError(error)) {
        throw error;
      }
      await new Promise((resolve) => setTimeout(resolve, 900));
    }
  }
  throw lastError;
}

function isRetryableGeminiError(error: unknown): boolean {
  const text = String(error instanceof Error ? error.message : error).toLowerCase();
  return text.includes("timeout") ||
    text.includes("deadline") ||
    text.includes("temporarily") ||
    text.includes("unavailable") ||
    text.includes("503") ||
    text.includes("500") ||
    text.includes("socket") ||
    text.includes("fetch failed");
}

const diagnosisResponseSchema: ResponseSchema = {
  type: SchemaType.OBJECT,
  properties: {
    isPlant: {type: SchemaType.BOOLEAN},
    plantGuess: {type: SchemaType.STRING},
    healthScore: {type: SchemaType.INTEGER},
    severity: {type: SchemaType.STRING, format: "enum", enum: ["low", "medium", "high"]},
    visualFindings: {
      type: SchemaType.ARRAY,
      items: {type: SchemaType.STRING},
      minItems: 2,
      maxItems: 5,
    },
    symptoms: {
      type: SchemaType.ARRAY,
      items: {type: SchemaType.STRING},
      maxItems: 6,
    },
    possibleCauses: {
      type: SchemaType.ARRAY,
      maxItems: 3,
      items: {
        type: SchemaType.OBJECT,
        properties: {
          code: {
            type: SchemaType.STRING,
            format: "enum",
            enum: [
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
            ],
          },
          label: {type: SchemaType.STRING},
          confidence: {type: SchemaType.NUMBER},
        },
        required: ["code", "label", "confidence"],
      },
    },
    needsCloseup: {type: SchemaType.BOOLEAN},
    quickActions: {
      type: SchemaType.ARRAY,
      items: {type: SchemaType.STRING},
      maxItems: 4,
    },
    sevenDayPlan: {
      type: SchemaType.ARRAY,
      items: {type: SchemaType.STRING},
      maxItems: 7,
    },
    safetyNote: {type: SchemaType.STRING},
    confidenceNote: {type: SchemaType.STRING},
  },
  required: [
    "isPlant",
    "plantGuess",
    "healthScore",
    "severity",
    "visualFindings",
    "symptoms",
    "possibleCauses",
    "needsCloseup",
    "quickActions",
    "sevenDayPlan",
    "safetyNote",
    "confidenceNote",
  ],
};

async function resolveImages(input: AnalyzePlantPhotoInput): Promise<Array<{data: string; mimeType: string}>> {
  const mimeType = input.mimeType || "image/jpeg";
  const inlineImages = input.imageBase64List?.length ? input.imageBase64List : input.imageBase64 ? [input.imageBase64] : [];
  if (inlineImages.length > 0) {
    return inlineImages.slice(0, 3).map((data) => ({data, mimeType}));
  }

  const imageUrls = input.imageUrls?.length ? input.imageUrls : input.imageUrl ? [input.imageUrl] : [];
  if (imageUrls.length === 0) {
    return [];
  }

  return Promise.all(imageUrls.slice(0, 3).map(async (imageUrl) => {
    const response = await fetch(imageUrl);
    if (!response.ok) {
      throw new Error(`Image fetch failed with status ${response.status}`);
    }

    const fetchedMimeType = response.headers.get("content-type") || mimeType;
    const buffer = Buffer.from(await response.arrayBuffer());
    return {data: buffer.toString("base64"), mimeType: fetchedMimeType};
  }));
}

function buildPrompt(input: AnalyzePlantPhotoInput): string {
  const language = input.answers?.language === "en" ? "English" : "Turkish";
  const languageRule = input.answers?.language === "en" ?
    "Write every user-facing JSON string in natural English. Keep plant Latin names unchanged. Do not mix Turkish into the response." :
    "Dil Türkçe olsun.";
  return `
Sen "Çiçek Doktoru" uygulamasında çalışan deneyimli bir bitki bakım analiz asistanısın.
Kullanıcının gönderdiği bitki fotoğrafını ve bakım cevaplarını birlikte değerlendir.
Amaç: bitkinin muhtemel türünü, fotoğrafta gerçekten görünen kanıtları ve olası bakım risklerini çıkarmak. Bakım planı backend arşiviyle ayrıca özelleştirileceği için en kritik işin görsel kanıtları doğru yazmaktır.
Yanıt dili: ${language}. ${languageRule}

Kesin teşhis iddiasında bulunma; görüntüye dayalı olasılıklı bakım yorumu yap.
Zirai/medikal kesinlik iddiası kurma. Kimyasal ilaç, pestisit, doz veya marka önerme.
Ev kullanıcılarının uygulayabileceği sade, güvenli ve ölçülü bakım adımları öner.
Cevabı yalnızca geçerli JSON olarak döndür; JSON dışında açıklama yazma.
Bitki türü adlandırırken Türkçe yaygın ad ile bilimsel/Latin adı uyumlu olsun; farklı bitkilerin adlarını birleştirme.
Özellikle Sansevieria / Dracaena trifasciata görülüyorsa Türkçe adı "Paşa kılıcı" veya "Kayınvalide dili" olarak yaz; "Sarmaşık" deme.
Fotoğrafı gerçekten analiz ettiğini hissettirmek için her yanıtta görüntüden seçilen somut kanıtlar ver: yaprak/gövde/çiçek/diken rengi, formu, leke, sararma, buruşma, saksı-toprak görünümü, ışık veya kadraj kalitesi gibi gözlenebilir detaylar.
Görselde seçemediğin şeyi uydurma. "Saksı tabağı", "drenaj deliği" veya "kök" görünmüyorsa bunları kesin gözlem gibi yazma; yalnızca kontrol önerisi olarak yaz.
Farklı bitkilerde aynı genel cümleyi tekrar etme. Kaktüs, Euphorbia/Afrika süt ağacı, sukulent, barış çiçeği, orkide, paşa kılıcı gibi türlerde türün organ dilini kullan: kaktüste gövde/diken/dip; Euphorbia'da kolon gövde/kaburga/tepe yaprakları/sütlü özsu riski; yapraklı bitkide yaprak ucu/damar/yaprak altı; çiçeklide tomurcuk/çiçek sapı.
visualFindings, symptoms, quickActions ve sevenDayPlan alanlarında aynı cümleyi veya aynı anlamı tekrar etme. Her alan farklı bir işe yarasın: visualFindings sadece görülen kanıt, symptoms görülen belirti etiketi, quickActions bugün yapılacak kısa işlem, sevenDayPlan gün gün takip planı olsun.

Kullanıcı cevapları:
${JSON.stringify(input.answers ?? {})}

Fotoğraf sayısı: ${input.imageBase64List?.length ?? input.imageUrls?.length ?? (input.imageBase64 || input.imageUrl ? 1 : 0)}
Birden fazla fotoğraf varsa hepsini birlikte değerlendir:
- 1. fotoğraf genel bitki formu ve tür tahmini için kullanılır.
- 2. fotoğraf yaprak/gövde/çiçek/diken üzerindeki belirti yakın kontrolü için kullanılır.
- 3. fotoğraf toprak, saksı dibi, drenaj ve kök boğazı çevresi için kullanılır.
Fotoğraflar birbiriyle çelişirse bunu confidenceNote alanında belirt; her fotoğraftan somut ve görülebilir kanıt çıkarmaya çalış. Birinci fotoğraf için genel form, ikinci fotoğraf için belirti detayı, üçüncü fotoğraf için toprak/saksı detayını ayrı ayrı yazmaya öncelik ver.

${buildPlantCarePromptBlock()}

Zorunlu JSON formatı:
{
  "isPlant": true,
  "plantGuess": "Türden emin değilsen en olası bitki adı veya Belirsiz",
  "healthScore": 0,
  "severity": "low | medium | high",
  "visualFindings": [
    "Fotoğrafta doğrudan görülen, bitkiye özel somut bulgu. Örn: Kaktüs gövdesi dik ve genel formunu koruyor; belirgin yumuşama seçilmiyor."
  ],
  "symptoms": ["Görselde gerçekten seçilebilen belirti"],
  "possibleCauses": [
    {
      "code": "overwatering | underwatering | low_light | sunburn | low_humidity | nutrient_deficiency | fungal_risk | pests_risk | root_stress | pot_drainage_issue | healthy | unknown",
      "label": "Kullanıcı dostu Türkçe neden başlığı",
      "confidence": 0.0
    }
  ],
  "needsCloseup": false,
  "quickActions": ["Bugün uygulanabilecek, fotoğraftaki kanıta bağlı net ve güvenli adım"],
  "sevenDayPlan": [
    "1. Gün: Bitki türüne, görünen belirtiye ve kullanıcı cevaplarına özel bakım adımı",
    "2. Gün: Türün sulama/ışık hassasiyetine göre kontrol adımı",
    "3. Gün: Yaprak, gövde, saksı veya toprak için spesifik gözlem",
    "4. Gün: Gereksiz müdahaleden kaçınma veya konumu sabitleme adımı",
    "5. Gün: Belirtinin seyrine göre net kontrol",
    "6. Gün: Bitkiye uygun temizlik, nem veya destek adımı",
    "7. Gün: Gelişim değerlendirme ve tekrar fotoğraf önerisi"
  ],
  "safetyNote": "Kısa güvenli not",
  "confidenceNote": "Tahmin güveni ve fotoğraf kalitesi hakkında kısa not"
}

Kurallar:
- healthScore 0-100 arasında olsun.
- confidence 0-1 arasında olsun.
- possibleCauses en fazla 3 madde olsun.
- visualFindings 2-5 madde olsun; her madde fotoğraftan görülebilen somut bir kanıt içersin ve bitki/tür dilini kullansın.
- visualFindings maddeleri birbirinin tekrarı olmasın; her madde farklı organ, fotoğraf açısı veya bakım kanıtına değinsin.
- quickActions en fazla 4 madde olsun; her madde fotoğraftaki bir bulguya veya bitki türüne bağlansın.
- sevenDayPlan tam 7 madde olsun ve her madde "1. Gün:" biçiminde başlasın. Backend bu planı arşivle yeniden zenginleştirecek; yine de jenerik plan yazma.
- symptoms en fazla 6 madde olsun; fotoğrafta görünmeyen belirti uydurma.
- symptoms boş kalmasın; hastalık belirtisi yoksa "Belirgin hastalık izi seçilmiyor" gibi gözleme dayalı bir madde yaz.
- possibleCauses içinde "healthy" ile aynı anda yüksek güvenli sorun verme. Sağlıklı görünüyorsa diğer nedenleri düşük güvenli "kontrol edilmesi gereken risk" olarak yaz veya hiç ekleme.
- "Saksı drenaj sorunu" yalnızca drenaj deliği/saksı tipi gerçekten görünüyorsa yüksek güvenli yaz; görünmüyorsa güveni düşük tut veya quickActions içinde kontrol önerisi yap.
- Eğer bitki sağlıklı görünüyorsa code olarak "healthy" kullan ve gereksiz sorun üretme.
- Eğer türden emin değilsen plantGuess alanında "Belirsiz" veya "Muhtemelen ..." kullan.
- Eğer fotoğraf bulanık, uzak veya yaprak/toprak detayı yetersizse needsCloseup true yap.
- Görselde bitki yoksa isPlant false döndür, healthScore 0 yap, kısa ve nazik tekrar fotoğraf öner.
- Kimyasal ilaç ismi verme.
- Sulama önerilerinde "hemen bol su ver" gibi riskli ve aşırı talimatlardan kaçın.
- Sulama adımlarını bitki türüne göre özelleştir: sukulent/Paşa kılıcı gibi türlerde toprak tamamen kurumadan sulama deme; nem seven türlerde üst 2-3 cm kuruluk kontrolü öner.
- Bakım planında aynı genel cümleleri tekrar etme. Tür adı, yaprak tipi, ışık ihtiyacı, saksı drenajı ve kullanıcının cevaplarını dikkate al.
- 7 günlük planın her maddesinde en az bir kez tür adı, görünen organ veya fotoğraftaki bulguyla bağlantı kur. "Bitkinin genel görünümü" gibi genel ifadeleri tek başına kullanma.
- Mümkünse "üst 2-3 cm toprak", "aydınlık ama direkt güneşsiz", "yaprak altı", "gövde dibi", "tepe sürgünü", "diken dibi" gibi bitkiye uygun ölçülü ve uygulanabilir detaylar ver.
- Kullanıcının cevapları görüntüyle çelişirse bunu düşük güven olarak değerlendir.
- ${languageRule}
`;
}
