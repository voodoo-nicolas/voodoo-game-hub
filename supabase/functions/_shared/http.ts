// Edge Function plumbing: POST + JSON, the caller's identity from their access token,
// and a service-role client (the only writer of the IQ tables; it bypasses RLS).
// Errors go back as { error: "<code>", message, ...extra } with an HTTP status.
// deno-lint-ignore-file no-explicit-any

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

export type Db = SupabaseClient;

export class HttpError extends Error {
  constructor(readonly status: number, readonly code: string, message?: string, readonly extra: Record<string, unknown> = {}) {
    super(message ?? code);
  }
}

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}

/** Throws a Postgrest error, returns the data otherwise. */
export function must<T>(res: { data: T; error: any }): T {
  if (res.error) throw res.error;
  return res.data;
}

export interface Call { body: Record<string, any>; uid: string; db: Db }

/** Serve one Edge Function: signed-in callers only, JSON object body in, JSON out. */
export function serve(fn: (call: Call) => Promise<unknown>) {
  Deno.serve(async (req) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
    if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
    try {
      const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
        auth: { persistSession: false, autoRefreshToken: false },
      });
      const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
      const { data, error } = await db.auth.getUser(jwt);
      if (error || !data.user) throw new HttpError(401, "unauthorized");
      let body: unknown;
      try { body = await req.json(); } catch { throw new HttpError(400, "bad_json"); }
      if (!body || typeof body !== "object" || Array.isArray(body)) throw new HttpError(400, "bad_json");
      return json(await fn({ body: body as Record<string, any>, uid: data.user.id, db }));
    } catch (e) {
      if (e instanceof HttpError) return json({ error: e.code, message: e.message, ...e.extra }, e.status);
      console.error(e);
      return json({ error: "internal" }, 500);
    }
  });
}
