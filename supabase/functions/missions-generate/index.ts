import { authenticate, serviceClient } from "../_shared/auth.ts";
import { consume, enforce } from "../_shared/rate_limit.ts";
import { handle, HttpError, jsonResponse } from "../_shared/errors.ts";
import { corsHeaders, preflight } from "../_shared/cors.ts";
import { generate, GeneratedTemplate } from "./gemini.ts";

interface RequestBody {
  targetDate: string;
  difficultyHint: "easy" | "medium" | "hard";
  recentKinds?: string[];
  preferredKinds?: string[];
  disabledKinds?: string[];
  locale?: string;
}

function withCors(res: Response, req: Request): Response {
  const cors = corsHeaders(req.headers.get("Origin"));
  for (const [key, value] of Object.entries(cors)) {
    res.headers.set(key, value);
  }
  return res;
}

Deno.serve((req) => {
  const pre = preflight(req);
  if (pre) return pre;
  return handle(req, async (req) => {
    if (req.method !== "POST") {
      throw new HttpError(405, "method_not_allowed");
    }
    const user = await authenticate(req);

    let body: RequestBody;
    try {
      body = await req.json();
    } catch {
      throw new HttpError(400, "invalid_body");
    }

    if (!body.targetDate || !body.difficultyHint) {
      throw new HttpError(400, "missing_fields");
    }

    const supabase = serviceClient();

    // 5 generations per user per day.
    enforce(await consume(supabase, user.id, "mission_generate", 86400, 5));

    // Cache lookup.
    const { data: cached, error: cacheErr } = await supabase
      .from("mission_generations")
      .select("template, generated_at")
      .eq("user_id", user.id)
      .eq("target_date", body.targetDate)
      .eq("difficulty_hint", body.difficultyHint)
      .maybeSingle();
    if (cacheErr) {
      console.error("cache lookup failed", cacheErr);
    }
    if (cached?.template) {
      return withCors(jsonResponse({
        template: cached.template,
        ttlSec: 86400,
        cached: true,
      }), req);
    }

    let template: GeneratedTemplate;
    try {
      template = await generate({
        targetDate: body.targetDate,
        difficultyHint: body.difficultyHint,
        recentKinds: body.recentKinds ?? [],
        preferredKinds: body.preferredKinds,
        disabledKinds: body.disabledKinds,
        locale: body.locale ?? "ja-JP",
      });
    } catch (err) {
      if (err instanceof HttpError) throw err;
      console.error("generate error", err);
      throw new HttpError(502, "provider_unavailable");
    }

    const { error: insertErr } = await supabase
      .from("mission_generations")
      .insert({
        user_id: user.id,
        target_date: body.targetDate,
        difficulty_hint: body.difficultyHint,
        template,
      });
    if (insertErr) {
      console.error("cache insert failed", insertErr);
    }

    return withCors(jsonResponse({
      template,
      ttlSec: 86400,
      cached: false,
    }), req);
  });
});
