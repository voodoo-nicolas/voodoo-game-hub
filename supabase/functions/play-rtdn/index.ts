// play-rtdn Edge Function entry point; the logic is in handler.ts.
//
// Called by Google Pub/Sub, not by a player, so there is no user token: deploy
// it with --no-verify-jwt and give the Pub/Sub push subscription the URL
//   https://<project>.supabase.co/functions/v1/play-rtdn?token=<PLAY_RTDN_TOKEN>
// where PLAY_RTDN_TOKEN is a long random function secret. Anything without it
// gets a 403.

import { createClient } from "npm:@supabase/supabase-js@2";
import { json } from "../_shared/http.ts";
import handler from "./handler.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const secret = Deno.env.get("PLAY_RTDN_TOKEN") ?? "";
  if (secret.length < 16 || new URL(req.url).searchParams.get("token") !== secret) {
    return json({ error: "forbidden" }, 403);
  }
  try {
    const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    let body: unknown = null;
    try { body = await req.json(); } catch { /* handler reports it */ }
    return json(await handler(body, db));
  } catch (e) {
    console.error(e);
    return json({ error: "internal" }, 500);
  }
});
