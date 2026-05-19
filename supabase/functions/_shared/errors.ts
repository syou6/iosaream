export class HttpError extends Error {
  constructor(public status: number, public code: string, message?: string) {
    super(message ?? code);
    this.name = "HttpError";
  }

  toResponse(): Response {
    return new Response(
      JSON.stringify({ error: this.code, message: this.message }),
      { status: this.status, headers: { "Content-Type": "application/json" } }
    );
  }
}

export function jsonResponse(body: unknown, init: ResponseInit = {}): Response {
  const headers = new Headers(init.headers);
  headers.set("Content-Type", "application/json");
  return new Response(JSON.stringify(body), { ...init, headers });
}

export async function handle(req: Request, fn: (req: Request) => Promise<Response>): Promise<Response> {
  try {
    return await fn(req);
  } catch (err) {
    if (err instanceof HttpError) {
      return err.toResponse();
    }
    console.error("unhandled error", err);
    return new Response(
      JSON.stringify({ error: "internal", message: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
}
