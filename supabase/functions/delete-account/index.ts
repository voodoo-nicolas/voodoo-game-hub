// delete-account Edge Function entry point; the logic is in handler.ts.
// Deploy WITH JWT verification (the default): the gateway checks the token's
// signature, so the user id read from it here can be trusted even after the
// auth user is gone (that's what makes a second call answer ok).
//   supabase functions deploy delete-account
// deno-lint-ignore-file no-explicit-any
import { createClient } from "npm:@supabase/supabase-js@2";
import { json } from "../_shared/http.ts";
import { deleteAccount } from "./handler.ts";

/** The `sub` and `email` claims of a JWT the gateway already verified. */
function claims(jwt: string): { sub?: string; email?: string } {
  try {
    const part = jwt.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(atob(part.padEnd(part.length + (4 - part.length % 4) % 4, "=")));
  } catch {
    return {};
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return json("ok");
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  try {
    const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    const c = claims(jwt);
    if (!c.sub || !/^[0-9a-f-]{36}$/i.test(c.sub)) return json({ error: "unauthorized" }, 401);
    const { data } = await db.auth.getUser(jwt);
    // Gone already (a retry): the rows went with the first call; ok again.
    const email = data?.user?.email ?? c.email ?? null;
    return json(await deleteAccount(db, c.sub, email));
  } catch (e: any) {
    console.error(e);
    return json({ error: "internal" }, 500);
  }
});
