import { createHmac, timingSafeEqual } from "node:crypto";
import { serviceClient } from "../_shared/auth.ts";
import { handle, HttpError, jsonResponse } from "../_shared/errors.ts";

interface RCEvent {
  event: {
    id: string;
    type: string;
    app_user_id: string;
    product_id?: string;
    expiration_at_ms?: number;
    purchased_at_ms?: number;
    period_type?: string;
  };
}

function mapToTier(eventType: string, periodType?: string): "free" | "pro" {
  switch (eventType) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "PRODUCT_CHANGE":
    case "UNCANCELLATION":
    case "SUBSCRIPTION_EXTENDED":
      return "pro";
    case "TRIAL_STARTED":
      return periodType === "TRIAL" ? "pro" : "pro";
    case "CANCELLATION":
    case "EXPIRATION":
    case "BILLING_ISSUE":
      return "free";
    default:
      return "free";
  }
}

function verifySignature(body: string, signature: string | null, secret: string): boolean {
  if (!signature) return false;
  const expected = createHmac("sha256", secret).update(body).digest("hex");
  const a = Buffer.from(signature, "hex");
  const b = Buffer.from(expected, "hex");
  if (a.length !== b.length) return false;
  return timingSafeEqual(a, b);
}

Deno.serve((req) => handle(req, async (req) => {
  if (req.method !== "POST") {
    throw new HttpError(405, "method_not_allowed");
  }

  const secret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
  if (!secret) {
    throw new HttpError(500, "config_error", "missing webhook secret");
  }

  const signature = req.headers.get("X-RevenueCat-Signature");
  const body = await req.text();
  if (!verifySignature(body, signature, secret)) {
    throw new HttpError(401, "invalid_signature");
  }

  let event: RCEvent;
  try {
    event = JSON.parse(body);
  } catch {
    throw new HttpError(400, "invalid_body");
  }

  const supabase = serviceClient();

  const { error: insertErr } = await supabase
    .from("billing_events")
    .upsert({
      rc_event_id: event.event.id,
      rc_app_user_id: event.event.app_user_id,
      event_type: event.event.type,
      product_id: event.event.product_id ?? null,
      raw_payload: event,
    }, { onConflict: "rc_event_id", ignoreDuplicates: true });
  if (insertErr) {
    console.error("billing_event upsert failed", insertErr);
    throw new HttpError(500, "store_failed");
  }

  const tier = mapToTier(event.event.type, event.event.period_type);
  const expiresAt = event.event.expiration_at_ms
    ? new Date(event.event.expiration_at_ms).toISOString()
    : null;

  const { error: updateErr } = await supabase
    .from("profiles")
    .update({
      subscription_tier: tier,
      subscription_expires_at: expiresAt,
    })
    .eq("id", event.event.app_user_id);
  if (updateErr) {
    console.error("profile update failed", updateErr);
    throw new HttpError(500, "store_failed");
  }

  await supabase
    .from("billing_events")
    .update({ processed_at: new Date().toISOString() })
    .eq("rc_event_id", event.event.id);

  return jsonResponse({ ok: true });
}));
