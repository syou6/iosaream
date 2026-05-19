import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { HttpError } from "./errors.ts";

export interface AuthenticatedUser {
  id: string;
  email?: string;
  raw: Record<string, unknown>;
}

export function serviceClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) {
    throw new HttpError(500, "config_error", "missing Supabase env vars");
  }
  return createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

export async function authenticate(req: Request): Promise<AuthenticatedUser> {
  const header = req.headers.get("Authorization");
  if (!header || !header.startsWith("Bearer ")) {
    throw new HttpError(401, "missing_token");
  }
  const token = header.slice("Bearer ".length).trim();
  if (!token) throw new HttpError(401, "missing_token");

  const client = serviceClient();
  const { data, error } = await client.auth.getUser(token);
  if (error || !data.user) {
    throw new HttpError(401, "invalid_token");
  }
  return {
    id: data.user.id,
    email: data.user.email ?? undefined,
    raw: data.user as unknown as Record<string, unknown>,
  };
}
