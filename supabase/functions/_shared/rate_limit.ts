import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { HttpError } from "./errors.ts";

export interface RateLimitResult {
  allowed: boolean;
  remaining: number;
}

export async function consume(
  client: SupabaseClient,
  userId: string,
  bucket: string,
  windowSeconds: number,
  maxCount: number,
): Promise<RateLimitResult> {
  const nowMs = Date.now();
  const windowStartMs = Math.floor(nowMs / 1000 / windowSeconds) * windowSeconds * 1000;
  const windowStart = new Date(windowStartMs).toISOString();

  const { data, error } = await client.rpc("rate_limit_consume", {
    p_user_id: userId,
    p_bucket: bucket,
    p_window_start: windowStart,
    p_max_count: maxCount,
  });

  if (error) {
    console.error("rate_limit_consume error", error);
    throw new HttpError(500, "rate_limit_error");
  }
  const row = Array.isArray(data) ? data[0] : data;
  return {
    allowed: row?.allowed ?? false,
    remaining: row?.remaining ?? 0,
  };
}

export function enforce(result: RateLimitResult): void {
  if (!result.allowed) {
    throw new HttpError(429, "rate_limited", "Daily limit exceeded");
  }
}
