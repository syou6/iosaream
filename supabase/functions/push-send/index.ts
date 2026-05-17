import jwt from "https://esm.sh/jsonwebtoken@9";
import { serviceClient } from "../_shared/auth.ts";
import { handle, HttpError, jsonResponse } from "../_shared/errors.ts";

interface SendBody {
  userId: string;
  category: string;
  title: string;
  body: string;
  data?: Record<string, unknown>;
  interruptionLevel?: "passive" | "active" | "timeSensitive" | "critical";
}

Deno.serve((req) => handle(req, async (req) => {
  const internalKey = Deno.env.get("INTERNAL_RPC_KEY");
  const expected = `Bearer ${internalKey}`;
  if (!internalKey || req.headers.get("Authorization") !== expected) {
    throw new HttpError(403, "forbidden");
  }
  if (req.method !== "POST") {
    throw new HttpError(405, "method_not_allowed");
  }

  let payload: SendBody;
  try {
    payload = await req.json();
  } catch {
    throw new HttpError(400, "invalid_body");
  }

  const supabase = serviceClient();
  const { data: profile, error: profileErr } = await supabase
    .from("profiles")
    .select("apns_token, apns_env")
    .eq("id", payload.userId)
    .single();
  if (profileErr || !profile?.apns_token) {
    throw new HttpError(404, "no_device_token");
  }

  const apnsTeamId = Deno.env.get("APNS_TEAM_ID");
  const apnsKeyId = Deno.env.get("APNS_KEY_ID");
  const apnsKey = Deno.env.get("APNS_KEY_P8");
  const bundleId = Deno.env.get("APP_BUNDLE_ID");
  if (!apnsTeamId || !apnsKeyId || !apnsKey || !bundleId) {
    throw new HttpError(500, "config_error", "APNs env vars missing");
  }

  const token = jwt.sign(
    { iss: apnsTeamId, iat: Math.floor(Date.now() / 1000) },
    apnsKey,
    { algorithm: "ES256", header: { alg: "ES256", kid: apnsKeyId } as Record<string, string> }
  );

  const apnsHost = profile.apns_env === "sandbox"
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com";

  const url = `${apnsHost}/3/device/${profile.apns_token}`;
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "authorization": `bearer ${token}`,
      "apns-topic": bundleId,
      "apns-push-type": "alert",
      "apns-priority": payload.interruptionLevel === "timeSensitive" ? "10" : "5",
    },
    body: JSON.stringify({
      aps: {
        alert: { title: payload.title, body: payload.body },
        category: payload.category,
        "interruption-level": payload.interruptionLevel ?? "active",
        sound: "default",
      },
      ...(payload.data ?? {}),
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    console.error("APNs send failed", response.status, text);
    throw new HttpError(502, "apns_failed");
  }

  return jsonResponse({ ok: true });
}));
