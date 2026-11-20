// 2 Cars: chat push notifications.
// Deploy in Supabase: Edge Functions -> Deploy a new function -> Via Editor, name it "chat-push",
// paste this file, Deploy, then turn OFF "Verify JWT" in the function's settings.
//
// GET  -> { publicKey }   the key phones use to subscribe (created on first run, stored in push_config)
// POST { id }             sends message #id to every subscribed phone except the sender's.
//                         Each message can only be pushed once, and only within 2 minutes of being posted.
import postgres from "npm:postgres@3.4.5";
import { generateRequestDetails, generateVAPIDKeys } from "npm:web-push-neo@0.1.2";

const sql = postgres(Deno.env.get("SUPABASE_DB_URL")!, { prepare: false, max: 3 });
const SUBJECT = "https://github.com/jesseli972/2_cars";
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "apikey, authorization, content-type, x-client-info",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};
const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: { ...CORS, "Content-Type": "application/json" } });

let cached: { publicKey: string; privateKey: string } | null = null;
async function vapidKeys() {
  if (cached) return cached;
  let rows = await sql`select public_key, private_key from public.push_config where id = 1`;
  if (!rows.length) {
    const k = await generateVAPIDKeys();
    await sql`insert into public.push_config (id, public_key, private_key)
              values (1, ${k.publicKey}, ${k.privateKey}) on conflict (id) do nothing`;
    rows = await sql`select public_key, private_key from public.push_config where id = 1`;
  }
  cached = { publicKey: rows[0].public_key, privateKey: rows[0].private_key };
  return cached;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const keys = await vapidKeys();
    if (req.method === "GET") return json({ publicKey: keys.publicKey });

    const { id } = await req.json().catch(() => ({}));
    if (!Number.isSafeInteger(Number(id))) return json({ error: "bad id" }, 400);

    const claimed = await sql`
      update public.chat_messages set pushed = true
      where id = ${Number(id)} and not pushed and created_at > now() - interval '2 minutes'
      returning name, device, body`;
    if (!claimed.length) return json({ sent: 0 });
    const msg = claimed[0];

    const subs = await sql`select endpoint, p256dh, auth from public.push_subscriptions where device <> ${msg.device}`;
    const body = msg.body.length > 140 ? msg.body.slice(0, 139) + "…" : msg.body;
    const payload = JSON.stringify({ title: msg.name, body, url: "./#chat" });

    let sent = 0, removed = 0;
    await Promise.all(subs.map(async (s) => {
      try {
        const d = await generateRequestDetails(
          { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
          payload,
          { TTL: 12 * 60 * 60, urgency: "high", vapidDetails: { subject: SUBJECT, ...keys } },
        );
        const res = await fetch(d.endpoint, { method: d.method, headers: d.headers, body: d.body });
        if (res.status === 404 || res.status === 410) {
          // the phone turned notifications off or uninstalled the app
          await sql`delete from public.push_subscriptions where endpoint = ${s.endpoint}`;
          removed++;
        } else if (res.ok) sent++;
        else console.log("push rejected", res.status, await res.text());
      } catch (e) {
        console.log("push error", String(e));
      }
    }));
    return json({ sent, removed });
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 500);
  }
});
