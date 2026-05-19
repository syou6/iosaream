import { authenticate, serviceClient } from "../_shared/auth.ts";
import { handle, HttpError, jsonResponse } from "../_shared/errors.ts";
import { corsHeaders, preflight } from "../_shared/cors.ts";

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
    const supabase = serviceClient();

    const { error: rpcErr } = await supabase.rpc("soft_delete_account");
    if (rpcErr) {
      console.error("soft_delete_account failed", rpcErr);
      throw new HttpError(500, "delete_failed");
    }

    const { error: deleteErr } = await supabase.auth.admin.deleteUser(user.id);
    if (deleteErr) {
      console.error("auth deleteUser failed", deleteErr);
      throw new HttpError(500, "delete_failed");
    }

    return withCors(jsonResponse({ ok: true }, { status: 200 }), req);
  });
});
