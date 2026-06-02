// Deploy:  supabase functions deploy send-mention-notification
// Secrets required (shared with send-invite-notification):
//   supabase secrets set FCM_SERVICE_ACCOUNT_JSON='<service-account-json>'
//   supabase secrets set SUPABASE_SERVICE_ROLE_KEY='<service-role-key>'
//
// Called by the Flutter client after a message containing @mentions is sent.
// The client passes the list of mentioned user IDs; this function validates
// they are accepted trip members, respects their opt-out setting, and sends
// FCM push notifications.
//
// Request body:
//   { trip_id: string, mentioned_user_ids: string[], message_preview: string }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ─── CORS ────────────────────────────────────────────────────────────────────

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ─── FCM OAuth2 helpers (same as send-invite-notification) ───────────────────

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
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");
  const headerB64 = toB64(header);
  const payloadB64 = toB64(payload);
  const signingInput = `${headerB64}.${payloadB64}`;
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
  if (!resp.ok) throw new Error(`OAuth2 token exchange failed: ${await resp.text()}`);
  return (await resp.json()).access_token as string;
}

interface FcmSendResult {
  token: string;
  success: boolean;
  stale: boolean;
}

async function sendFcmMessage(
  projectId: string,
  accessToken: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<FcmSendResult> {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
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

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ??
    "https://qgeocaectbdfonrorwco.supabase.co";
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

  try {
    // 1. Verify caller is an authenticated user.
    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authErr } = await userClient.auth.getUser();
    if (authErr || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Parse body.
    const { trip_id, mentioned_user_ids, message_preview } = await req.json() as {
      trip_id: string;
      mentioned_user_ids: string[];
      message_preview: string;
    };

    if (!trip_id || !Array.isArray(mentioned_user_ids) || mentioned_user_ids.length === 0) {
      return new Response(JSON.stringify({ sent: 0, reason: "no_mentions" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. Admin client for privileged reads.
    const admin = createClient(supabaseUrl, serviceRoleKey);

    // 4. Verify sender is an accepted member of the trip.
    const { data: senderMember } = await admin
      .from("trip_members")
      .select("id")
      .eq("trip_id", trip_id)
      .eq("user_id", user.id)
      .eq("status", "accepted")
      .maybeSingle();

    if (!senderMember) {
      return new Response(JSON.stringify({ error: "Forbidden" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 5. Fetch sender's display name.
    const { data: senderProfile } = await admin
      .from("user_profiles")
      .select("full_name")
      .eq("user_id", user.id)
      .maybeSingle();
    const senderName: string = senderProfile?.full_name || "Someone";

    // 6. Fetch trip title.
    const { data: trip } = await admin
      .from("trips")
      .select("title")
      .eq("id", trip_id)
      .maybeSingle();
    const tripTitle: string = trip?.title || "a trip";

    // 7. Validate mentioned users: must be accepted trip members who have
    //    opted in to mention notifications (and are not the sender).
    const mentionedWithoutSelf = mentioned_user_ids.filter((id) => id !== user.id);
    if (mentionedWithoutSelf.length === 0) {
      return new Response(JSON.stringify({ sent: 0, reason: "self_mention_only" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: validMembers } = await admin
      .from("trip_members")
      .select("user_id")
      .eq("trip_id", trip_id)
      .eq("status", "accepted")
      .in("user_id", mentionedWithoutSelf);

    const validMemberIds = (validMembers ?? []).map((m: { user_id: string }) => m.user_id);
    if (validMemberIds.length === 0) {
      return new Response(JSON.stringify({ sent: 0, reason: "no_valid_members" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Filter to users who have mention notifications enabled.
    const { data: optedInProfiles } = await admin
      .from("user_profiles")
      .select("user_id")
      .in("user_id", validMemberIds)
      .eq("mention_notifications_enabled", true);

    const optedInIds = (optedInProfiles ?? []).map((p: { user_id: string }) => p.user_id);
    if (optedInIds.length === 0) {
      return new Response(JSON.stringify({ sent: 0, reason: "all_opted_out" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 8. Fetch device tokens for opted-in users.
    const { data: tokenRows, error: tokenErr } = await admin
      .from("device_tokens")
      .select("id, token, user_id")
      .in("user_id", optedInIds);

    if (tokenErr) throw tokenErr;
    if (!tokenRows || tokenRows.length === 0) {
      return new Response(JSON.stringify({ sent: 0, reason: "no_device_tokens" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 9. Get FCM access token.
    const fcmJsonRaw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
    if (!fcmJsonRaw) throw new Error("FCM_SERVICE_ACCOUNT_JSON secret is not set");
    const serviceAccount: ServiceAccount = JSON.parse(fcmJsonRaw);
    const accessToken = await getFcmAccessToken(serviceAccount);

    // 10. Send notifications.
    const preview = message_preview.length > 80
      ? `${message_preview.substring(0, 80)}…`
      : message_preview;
    const title = `${senderName} mentioned you in ${tripTitle}`;

    const results = await Promise.all(
      tokenRows.map((row: { id: string; token: string }) =>
        sendFcmMessage(
          serviceAccount.project_id,
          accessToken,
          row.token,
          title,
          preview,
          { type: "chat_mention", trip_id },
        ).then((r) => ({ ...r, rowId: row.id }))
      ),
    );

    // 11. Remove stale tokens.
    const staleIds = results
      .filter((r) => r.stale)
      .map((r) => (r as { rowId: string }).rowId);

    if (staleIds.length > 0) {
      await admin.from("device_tokens").delete().in("id", staleIds);
    }

    const sent = results.filter((r) => r.success).length;
    console.log(`Mention notification sent to ${sent}/${tokenRows.length} device(s)`);

    return new Response(
      JSON.stringify({ sent, total: tokenRows.length }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("send-mention-notification error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
