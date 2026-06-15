// Deploy:  supabase functions deploy send-invite-notification
// Secrets required:
//   supabase secrets set FCM_SERVICE_ACCOUNT_JSON='<service-account-json>'
//   supabase secrets set SUPABASE_SERVICE_ROLE_KEY='<service-role-key>'
//
// Called by the on_invite_inserted DB trigger via pg_net whenever a new
// trip_members row is inserted with status='pending' and a non-null user_id.
//
// Request body (from trigger):
//   { member_id: string, trip_id: string, invitee_user_id: string }
//
// Sends one FCM notification per device token registered for the invitee.
// Stale tokens (FCM 404 / NOT_FOUND) are deleted automatically.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ─── CORS ────────────────────────────────────────────────────────────────────

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ─── FCM OAuth2 (service account JWT → access token) ─────────────────────────

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

/** Sign a RS256 JWT using the Web Crypto API (no external deps). */
async function signJwt(
  payload: Record<string, unknown>,
  privateKeyPem: string,
): Promise<string> {
  const header = { alg: "RS256", typ: "JWT" };
  const encoder = new TextEncoder();

  const toB64 = (obj: unknown) =>
    btoa(JSON.stringify(obj))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");

  const headerB64 = toB64(header);
  const payloadB64 = toB64(payload);
  const signingInput = `${headerB64}.${payloadB64}`;

  // Strip PEM wrapper
  const pemContents = privateKeyPem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const keyBuffer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyBuffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signatureBuffer = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    encoder.encode(signingInput),
  );
  const signatureB64 = btoa(
    String.fromCharCode(...new Uint8Array(signatureBuffer)),
  )
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  return `${signingInput}.${signatureB64}`;
}

/** Exchange a service-account JWT for a short-lived OAuth2 access token. */
async function getFcmAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const jwt = await signJwt(
    {
      iss: sa.client_email,
      sub: sa.client_email,
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
    },
    sa.private_key,
  );

  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!resp.ok) {
    throw new Error(`OAuth2 token exchange failed: ${await resp.text()}`);
  }
  const data = await resp.json();
  return data.access_token as string;
}

// ─── Send a single FCM message ────────────────────────────────────────────────

interface FcmSendResult {
  token: string;
  success: boolean;
  stale: boolean;   // token should be deleted (FCM returned NOT_FOUND / INVALID_ARGUMENT)
}

async function sendFcmMessage(
  projectId: string,
  accessToken: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<FcmSendResult> {
  const url =
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

  const resp = await fetch(url, {
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
        apns: {
          headers: { "apns-priority": "10" },
          payload: { aps: { sound: "default" } },
        },
      },
    }),
  });

  if (resp.ok) return { token, success: true, stale: false };

  const errBody = await resp.json().catch(() => ({}));
  const errCode: string = errBody?.error?.details?.[0]?.errorCode ?? "";
  // FCM returns these codes for tokens that are no longer valid
  const stale =
    resp.status === 404 ||
    errCode === "UNREGISTERED" ||
    errCode === "INVALID_ARGUMENT";

  console.error(`FCM send failed for token ...${token.slice(-8)}:`, errBody);
  return { token, success: false, stale };
}

// ─── Main handler ─────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // 1. Verify caller is our service role (trigger passes Bearer <service_role_key>)
  const expectedKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!expectedKey || authHeader !== `Bearer ${expectedKey}`) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    // 2. Parse request body
    const { member_id, trip_id, invitee_user_id } = await req.json() as {
      member_id: string;
      trip_id: string;
      invitee_user_id: string;
    };

    if (!member_id || !trip_id || !invitee_user_id) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 3. Create Supabase admin client
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ??
      "https://qgeocaectbdfonrorwco.supabase.co";
    const supabase = createClient(supabaseUrl, expectedKey);

    // 4. Fetch device tokens for the invitee
    const { data: tokenRows, error: tokenErr } = await supabase
      .from("device_tokens")
      .select("id, token")
      .eq("user_id", invitee_user_id)
      .eq("app", "trip_management");

    if (tokenErr) throw tokenErr;
    if (!tokenRows || tokenRows.length === 0) {
      // No tokens — nothing to send, but it's not an error
      return new Response(
        JSON.stringify({ sent: 0, reason: "no_device_tokens" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // 5. Fetch trip title + organiser name
    const { data: tripRow, error: tripErr } = await supabase
      .from("trips")
      .select(
        "title, user_profiles!trips_created_by_fkey(full_name)",
      )
      .eq("id", trip_id)
      .single();

    if (tripErr) throw tripErr;

    const tripTitle: string = tripRow?.title ?? "a trip";
    const organiserName: string =
      // deno-lint-ignore no-explicit-any
      (tripRow as any)?.user_profiles?.full_name ?? "Someone";

    // 6. Get FCM access token via service-account JWT exchange
    const fcmJsonRaw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
    if (!fcmJsonRaw) {
      throw new Error("FCM_SERVICE_ACCOUNT_JSON secret is not set");
    }
    const serviceAccount: ServiceAccount = JSON.parse(fcmJsonRaw);
    const accessToken = await getFcmAccessToken(serviceAccount);

    // 7. Send to each device token
    const title = "Trip invitation";
    const body = `${organiserName} invited you to "${tripTitle}"`;
    const data: Record<string, string> = {
      type: "trip_invite",
      trip_id,
      member_id,
    };

    const results = await Promise.all(
      tokenRows.map((row: { id: string; token: string }) =>
        sendFcmMessage(
          serviceAccount.project_id,
          accessToken,
          row.token,
          title,
          body,
          data,
        ).then((r) => ({ ...r, rowId: row.id }))
      ),
    );

    // 8. Remove stale tokens
    const staleIds = results
      .filter((r) => r.stale)
      // deno-lint-ignore no-explicit-any
      .map((r) => (r as any).rowId as string);

    if (staleIds.length > 0) {
      await supabase.from("device_tokens").delete().in("id", staleIds);
      console.log(`Removed ${staleIds.length} stale device token(s)`);
    }

    const sent = results.filter((r) => r.success).length;
    console.log(`Invite notification sent to ${sent}/${tokenRows.length} device(s)`);

    try {
      await fetch(`${supabaseUrl}/realtime/v1/api/broadcast`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "apikey": expectedKey,
          "Authorization": `Bearer ${expectedKey}`,
        },
        body: JSON.stringify({
          messages: [{
            topic: `realtime:trip_notifications_${invitee_user_id}`,
            event: "new_notification",
            payload: { type: "event_invite" },
          }],
        }),
      });
    } catch (_) { /* non-fatal */ }

    return new Response(
      JSON.stringify({ sent, total: tokenRows.length }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("send-invite-notification error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
