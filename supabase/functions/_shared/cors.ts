const allowedOrigins = new Set<string>([
  // tighten this list once the production app is shipped
  "https://oki-mission.app",
  "https://www.oki-mission.app",
]);

export function corsHeaders(origin: string | null): Record<string, string> {
  const headers: Record<string, string> = {
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Authorization, Content-Type, apikey, X-Client-Info",
    "Access-Control-Max-Age": "86400",
  };
  if (origin && allowedOrigins.has(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  } else {
    headers["Access-Control-Allow-Origin"] = "https://oki-mission.app";
  }
  return headers;
}

export function preflight(req: Request): Response | null {
  if (req.method !== "OPTIONS") return null;
  return new Response(null, {
    status: 204,
    headers: corsHeaders(req.headers.get("Origin")),
  });
}
