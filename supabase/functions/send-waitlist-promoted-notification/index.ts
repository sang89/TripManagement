// Deploy:  supabase functions deploy send-waitlist-promoted-notification
// Secrets required (same as send-invite-notification):
//   supabase secrets set FCM_SERVICE_ACCOUNT_JSON='<service-account-json>'
//   supabase secrets set SUPABASE_SERVICE_ROLE_KEY='<service-role-key>'
//
// Called by the on_waitlist_promoted DB trigger via pg_net whenever an
// event_session_roster row transitions from status='waitlisted' to 'going'.
//
// Request body:
//   { roster_id: string, session_id: string, user_id: string }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ─── FCM helpers (identical to send-invite-notification) ─────────────────────

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

async function signJwt(
  payload: Record<string, unknown>,
  privateKeyPem: string,
): Promise<string> {
  const header = { alg: "RS256", typ: "JWT" };
  const encoder = new TextEncoder();
  const toB64 = (obj: unknown) =>
    btoa(JSON.stringify(obj))
      .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

  const signingInput = `${toB64(header)}.${toB64(payload)}`;
  const pemContents = privateKeyPem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const keyBuffer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8", keyBuffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5", cryptoKey, encoder.encode(signingInput),
  );
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  return `${signingInput}.${sigB64}`;
}

async function getFcmAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const jwt = await signJwt({
    iss: sa.client_email, sub: sa.client_email,
    aud: "https://oauth2.googleapis.com/token",
    iat: now, exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  }, sa.private_key);

  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!resp.ok) throw new Error(`OAuth2 failed: ${await resp.text()}`);
  return (await resp.json()).access_token as string;
}

async function sendFcmMessage(
  projectId: string, accessToken: string, token: string,
  title: string, body: string, data: Record<string, string>,
): Promise<{ success: boolean; stale: boolean }> {
  const resp = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data,
          android: { priority: "high" },
          apns: { headers: { "apns-priority": "10" }, payload: { aps: { sound: "default" } } },
        },
      }),
    },
  );
  if (resp.ok) return { success: true, stale: false };
  const err = await resp.json().catch(() => ({}));
  const code: string = err?.error?.details?.[0]?.errorCode ?? "";
  const stale = resp.status === 404 || code === "UNREGISTERED" || code === "INVALID_ARGUMENT";
  return { success: false, stale };
}

// ─── Main handler ─────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const expectedKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const auth = req.headers.get("Authorization") ?? "";
  if (!expectedKey || auth !== `Bearer ${expectedKey}`) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const { roster_id, session_id, user_id } = await req.json() as {
      roster_id: string; session_id: string; user_id: string;
    };
    if (!roster_id || !session_id || !user_id) {
      return new Response(JSON.stringify({ error: "Missing fields" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "https://qgeocaectbdfonrorwco.supabase.co";
    const supabase = createClient(supabaseUrl, expectedKey);

    // Device tokens for promoted user
    const { data: tokens, error: tokErr } = await supabase
      .from("device_tokens").select("id, token").eq("user_id", user_id);
    if (tokErr) throw tokErr;
    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ sent: 0, reason: "no_device_tokens" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Session + event info for the notification body
    const { data: session, error: sessErr } = await supabase
      .from("event_sessions")
      .select("start_at, session_number, events(title)")
      .eq("id", session_id)
      .single();
    if (sessErr) throw sessErr;

    // deno-lint-ignore no-explicit-any
    const eventTitle: string = (session as any)?.events?.title ?? "your event";
    const startAt: string = session?.start_at ?? "";
    const dateStr = startAt
      ? new Date(startAt).toLocaleDateString("en-US", {
          weekday: "short", month: "short", day: "numeric",
        })
      : "";

    const fcmJsonRaw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
    if (!fcmJsonRaw) throw new Error("FCM_SERVICE_ACCOUNT_JSON not set");
    const sa: ServiceAccount = JSON.parse(fcmJsonRaw);
    const accessToken = await getFcmAccessToken(sa);

    const title = "🎉 You're in!";
    const body = dateStr
      ? `Your spot for "${eventTitle}" on ${dateStr} is confirmed.`
      : `Your spot for "${eventTitle}" is confirmed.`;
    const data: Record<string, string> = {
      type: "waitlist_promoted",
      roster_id,
      session_id,
    };

    const results = await Promise.all(
      tokens.map((row: { id: string; token: string }) =>
        sendFcmMessage(sa.project_id, accessToken, row.token, title, body, data)
          .then((r) => ({ ...r, id: row.id }))
      ),
    );

    const staleIds = results.filter((r) => r.stale).map((r) => r.id);
    if (staleIds.length > 0) {
      await supabase.from("device_tokens").delete().in("id", staleIds);
    }

    const sent = results.filter((r) => r.success).length;
    console.log(`Waitlist promotion notification sent to ${sent}/${tokens.length} device(s)`);

    return new Response(JSON.stringify({ sent, total: tokens.length }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("send-waitlist-promoted-notification error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
