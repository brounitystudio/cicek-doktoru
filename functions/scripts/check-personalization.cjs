const assert = require("node:assert/strict");
const {
  buildPlantActionPlan,
  looksRepeatedOrGeneric,
  personalizePlantActionPlan,
} = require("../lib/services/plant_action_plan_service.js");

const base = {
  plantName: "Muhtemelen Paşa kılıcı",
  cause: "overwatering",
  visualFindings: [
    "Paşa kılıcının iki yaprak ucunda sarı alan görülüyor.",
    "Yapraklar dik; yaprak dipleri fotoğrafta net seçilemiyor.",
  ],
  possibleCauses: [
    {code: "overwatering", label: "Fazla sulama riski", confidence: 0.68},
  ],
};

const indoor = buildPlantActionPlan({
  ...base,
  answers: {
    location: "indoor",
    lastWatered: "Bugün",
    sunlight: "Az ışık",
    hasDrainage: "Hayır",
    symptomType: "Sararma / solma",
    symptomDuration: "Birkaç gündür",
  },
});

const outdoor = buildPlantActionPlan({
  ...base,
  answers: {
    location: "outdoor",
    lastWatered: "4-7 gün önce",
    sunlight: "Direkt güneş",
    hasDrainage: "Evet",
    symptomType: "Leke / çürüme",
    symptomDuration: "1 haftadan fazla",
  },
});

const indirect = buildPlantActionPlan({
  ...base,
  cause: "healthy",
  answers: {
    location: "indoor",
    lastWatered: "Hatırlamıyorum",
    sunlight: "Aydınlık ama direkt değil",
    hasDrainage: "Bilmiyorum",
    symptomType: "Sadece kontrol",
    symptomDuration: "Bugün fark ettim",
  },
});

assert.notEqual(indoor.sevenDayPlan[1], outdoor.sevenDayPlan[1]);
assert.notEqual(indoor.sevenDayPlan[2], outdoor.sevenDayPlan[2]);
assert.notEqual(indoor.sevenDayPlan[4], outdoor.sevenDayPlan[4]);
assert.match(indoor.sevenDayPlan[1], /bugün suladığını/i);
assert.match(outdoor.sevenDayPlan[2], /dış mekânda direkt güneş/i);
assert.match(indirect.sevenDayPlan[2], /aydınlık ve dolaylı ışık/i);
assert.doesNotMatch(indirect.sevenDayPlan[2], /direkt güneş aldığını/i);
assert.doesNotMatch(indoor.quickActions.join(" "), /Muhtemelen Paşa/i);

const repetitivePlan = Array.from(
  {length: 7},
  (_, index) => `${index + 1}. Gün: Paşa kılıcının yapraklarını tekrar kontrol et.`,
);
assert.equal(
  looksRepeatedOrGeneric(repetitivePlan, base.plantName, base.visualFindings),
  true,
);

const aiPlan = {
  visualFindings: base.visualFindings,
  symptoms: ["İki yaprak ucunda sararma"],
  quickActions: [
    "Paşa kılıcının sarı yaprak uçlarını bugün aynı açıdan fotoğrafla.",
    "Toprak kuruysa kontrollü sulama yap.",
  ],
  sevenDayPlan: Array.from(
    {length: 7},
    (_, index) => `${index + 1}. Gün: Paşa kılıcının durumunu izle.`,
  ),
  safetyNote: "Kesin teşhis değildir.",
  confidenceNote: "Görüntü okunabilir.",
};
const personalized = personalizePlantActionPlan(aiPlan, {
  ...base,
  answers: {
    location: "indoor",
    lastWatered: "Bugün",
    sunlight: "Az ışık",
    hasDrainage: "Hayır",
    symptomType: "Sararma / solma",
    symptomDuration: "Birkaç gündür",
  },
});
assert.equal(personalized.quickActions[0], aiPlan.quickActions[0]);
assert.equal(personalized.sevenDayPlan[0], aiPlan.sevenDayPlan[0]);
assert.match(personalized.sevenDayPlan[1], /bugün suladığını/i);
assert.match(personalized.sevenDayPlan[4], /birkaç gündür izlenen sararma/i);

console.log("Personalization checks passed.");
