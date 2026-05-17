export interface PromptInput {
  difficultyHint: "easy" | "medium" | "hard";
  recentKinds: string[];
  preferredKinds?: string[];
  disabledKinds?: string[];
  locale: string;
  targetDate: string;
}

export function buildPrompt(input: PromptInput): string {
  const recent = input.recentKinds.length === 0 ? "(none)" : input.recentKinds.join(", ");
  const preferred = input.preferredKinds && input.preferredKinds.length > 0
    ? input.preferredKinds.join(", ")
    : "any of pushup, squat, math, shake, objectHunt, barcode";
  const disabled = input.disabledKinds && input.disabledKinds.length > 0
    ? input.disabledKinds.join(", ")
    : "(none)";

  return `You are designing the next mission for an iOS wake-up alarm app called OkiMission.

User context:
- target date: ${input.targetDate}
- preferred locale: ${input.locale}
- recent mission kinds (most recent first): ${recent}
- preferred kinds: ${preferred}
- disabled kinds (do not pick): ${disabled}
- difficulty hint: ${input.difficultyHint}

Mission kinds & their parameter shapes:
- pushup:     { "reps": int, "formStrictness": "lenient"|"moderate"|"strict", "maxDurationSeconds": number }
- squat:      { "reps": int, "formStrictness": "lenient"|"moderate"|"strict", "maxDurationSeconds": number }
- math:       { "problemCount": int, "operatorTypes": ["add"|"subtract"|"multiply"], "minOperand": int, "maxOperand": int, "maxDurationSeconds": number }
- shake:      { "requiredShakes": int, "minMagnitude": number, "maxDurationSeconds": number }
- objectHunt: { "targetClasses": [string], "requiredCount": int, "maxDurationSeconds": number }
- barcode:    { "targetCount": int, "maxDurationSeconds": number }

Rules:
1. Do not pick a kind that has appeared in the last two entries of "recent mission kinds" if there are other valid choices.
2. Honor the difficulty hint by scaling reps / problem count / requiredCount accordingly.
3. For locales starting with "ja", write title / subtitle / encouragement in natural Japanese; otherwise English.
4. estimatedDurationSec should be a realistic upper bound (10-300 seconds).
5. Reply with valid JSON that conforms to the response schema. No prose outside the JSON.`;
}
