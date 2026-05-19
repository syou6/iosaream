import { HttpError } from "../_shared/errors.ts";
import { buildPrompt, PromptInput } from "./prompt.ts";

export interface GeneratedTemplate {
  kind: string;
  difficulty: string;
  parameters: Record<string, unknown>;
  title: string;
  subtitle?: string;
  description?: string;
  encouragement?: string;
  estimatedDurationSec: number;
  locale: string;
  source: string;
}

const MISSION_SCHEMA = {
  type: "object",
  properties: {
    kind: {
      type: "string",
      enum: ["pushup", "squat", "math", "shake", "objectHunt", "barcode"],
    },
    difficulty: { type: "string", enum: ["easy", "medium", "hard"] },
    parameters: { type: "object" },
    title: { type: "string" },
    subtitle: { type: "string" },
    description: { type: "string" },
    encouragement: { type: "string" },
    estimatedDurationSec: { type: "integer", minimum: 10, maximum: 300 },
  },
  required: ["kind", "difficulty", "parameters", "title", "estimatedDurationSec"],
};

export async function generate(input: PromptInput): Promise<GeneratedTemplate> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    throw new HttpError(500, "config_error", "missing GEMINI_API_KEY");
  }

  const prompt = buildPrompt(input);
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`;

  const body = {
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: MISSION_SCHEMA,
      temperature: 0.7,
      maxOutputTokens: 512,
    },
  };

  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const errText = await response.text();
    console.error("gemini error", response.status, errText);
    throw new HttpError(502, "provider_unavailable", "Gemini API returned an error");
  }

  const json = await response.json();
  const text = json?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (typeof text !== "string") {
    throw new HttpError(502, "provider_unavailable", "Gemini response missing text");
  }

  let parsed: GeneratedTemplate;
  try {
    parsed = JSON.parse(text);
  } catch (err) {
    console.error("failed to parse gemini json", err, text);
    throw new HttpError(502, "provider_unavailable", "Gemini response not valid JSON");
  }

  parsed.locale = input.locale;
  parsed.source = "gemini-2.5-flash";
  return parsed;
}
