// =============================================================================
// GMI MindSpace · send-push (Supabase Edge Function) – PREPARED, NOT DEPLOYED
//
// Triggered by a Database Webhook on INSERT into public.notifications.
// Sends the row's generic title/body to the user's registered devices via
// Firebase Cloud Messaging HTTP v1.
//
// PRIVACY
//  * Only the generic text already stored in `notifications` is sent. Mood,
//    journal and appointment details are never part of a push payload.
//  * Android `visibility: PRIVATE` hides content on the lock screen.
//  * Students who switched push off (notification_preferences.push_enabled)
//    receive nothing.
//
// SECRETS (set with `supabase secrets set`, never in the app):
//   FCM_PROJECT_ID, FCM_CLIENT_EMAIL, FCM_PRIVATE_KEY, PUSH_WEBHOOK_SECRET
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by the platform
// to Edge Functions and stay on the server.
// =============================================================================
import { createClient } from "jsr:@supabase/supabase-js@2";

interface NotificationRow {
  id: string;
  user_id: string;
  title: string;
  body: string;
}

const encoder = new TextEncoder();

function base64url(input: ArrayBuffer | string): string {
  const bytes = typeof input === "string" ? encoder.encode(input) : new Uint8Array(input);
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** OAuth access token for FCM using the service-account key (RS256 JWT). */
async function fcmAccessToken(): Promise<string> {
  const email = Deno.env.get("FCM_CLIENT_EMAIL")!;
  const pem = Deno.env.get("FCM_PRIVATE_KEY")!.replace(/\\n/g, "\n");
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64url(JSON.stringify({
    iss: email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const der = Uint8Array.from(
    atob(pem.replace(/-----[^-]+-----/g, "").replace(/\s/g, "")),
    (c) => c.charCodeAt(0),
  );
  const key = await crypto.subtle.importKey(
    "pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, encoder.encode(`${header}.${claims}`));
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${header}.${claims}.${base64url(sig)}`,
    }),
  });
  if (!res.ok) throw new Error(`FCM auth failed: ${res.status}`);
  return (await res.json()).access_token as string;
}

Deno.serve(async (req) => {
  // Only the database webhook (which knows the shared secret) may call this.
  if (req.headers.get("x-webhook-secret") !== Deno.env.get("PUSH_WEBHOOK_SECRET")) {
    return new Response("Forbidden", { status: 403 });
  }

  const payload = await req.json();
  const row = payload?.record as NotificationRow | undefined;
  if (!row?.user_id) return new Response("Ignored", { status: 200 });

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const { data: prefs } = await admin
    .from("notification_preferences").select("push_enabled").eq("user_id", row.user_id).maybeSingle();
  if (prefs && prefs.push_enabled === false) return new Response("Push disabled", { status: 200 });

  const { data: tokens } = await admin.from("device_tokens").select("token").eq("user_id", row.user_id);
  if (!tokens?.length) return new Response("No devices", { status: 200 });

  const accessToken = await fcmAccessToken();
  const projectId = Deno.env.get("FCM_PROJECT_ID")!;
  let sent = 0;

  for (const { token } of tokens) {
    const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
      method: "POST",
      headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: row.title, body: row.body },
          data: { notification_id: row.id },
          android: { notification: { visibility: "PRIVATE" } },
          apns: { payload: { aps: { "thread-id": "mindspace" } } },
        },
      }),
    });
    if (res.ok) {
      sent++;
    } else if (res.status === 404 || res.status === 400) {
      // Token no longer valid – clean it up.
      await admin.from("device_tokens").delete().eq("token", token);
    }
  }

  return new Response(JSON.stringify({ sent }), { headers: { "Content-Type": "application/json" } });
});
