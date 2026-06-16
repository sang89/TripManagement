// Deploy:  supabase functions deploy send-mention-notification
// Secrets required (shared with send-invite-notification):
//   supabase secrets set FCM_SERVICE_ACCOUNT_JSON='<service-account-json>'
//   supabase secrets set SUPABASE_SERVICE_ROLE_KEY='<service-role-key>'
//
// Called by the Flutter client after a message containing @mentions is sent.
// The client passes the list of mentioned user IDs; this function validates
// they are active event members, respects their opt-out setting, sends
// FCM push notifications, and writes in-app notifications to trip_notifications.
//
// Request body:
//   { event_id: string, mentioned_user_ids: string[], message_preview: string }
//
// Backward-compat: also accepts trip_id in place of event_id.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ─── CORS ────────────────────────────────────────────────────────────────────

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ─── FCM OAuth2 helpers ───────────────────────────────────────────────────────

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
  rowId: string;
  success: boolean;
  stale: boolean;
}

async function sendFcmMessage(
  projectId: string,
  accessToken: string,
  rowId: string,
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
  if (resp.ok) return { token, rowId, success: true, stale: false };
  const errBody = await resp.json().catch(() => ({}));
  const errCode: string = errBody?.error?.details?.[0]?.errorCode ?? "";
  const stale =
    resp.status === 404 ||
    errCode === "UNREGISTERED" ||
    errCode === "INVALID_ARGUMENT";
  console.error(`FCM send failed for token ...${token.slice(-8)}:`, errBody);
  return { token, rowId, success: false, stale };
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

    // 2. Parse body — accept event_id or legacy trip_id.
    const body = await req.json() as {
      event_id?: string;
      trip_id?: string;
      mentioned_user_ids: string[];
      message_preview: string;
    };
    const eventId = body.event_id ?? body.trip_id;
    const { mentioned_user_ids, message_preview } = body;

    if (!eventId || !Array.isArray(mentioned_user_ids) || mentioned_user_ids.length === 0) {
      return new Response(JSON.stringify({ sent: 0, reason: "no_mentions" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. Admin client for privileged reads/writes.
    const admin = createClient(supabaseUrl, serviceRoleKey);

    // 4. Verify sender is an active member of the event.
    const { data: senderMember } = await admin
      .from("event_guests")
      .select("id")
      .eq("event_id", eventId)
      .eq("user_id", user.id)
      .in("status", ["going", "maybe", "accepted", "pending"])
      .maybeSingle();

    // Also allow the event creator (who may not have a guest row).
    let senderIsOrganizer = false;
    if (!senderMember) {
      const { data: evt } = await admin
        .from("events")
        .select("created_by")
        .eq("id", eventId)
        .maybeSingle();
      senderIsOrganizer = evt?.created_by === user.id;
    }

    if (!senderMember && !senderIsOrganizer) {
      return new Response(JSON.stringify({ error: "Forbidden" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 5. Fetch sender's display name and event title in parallel.
    const [senderProfileResult, eventResult] = await Promise.all([
      admin.from("user_profiles").select("full_name").eq("user_id", user.id).maybeSingle(),
      admin.from("events").select("title").eq("id", eventId).maybeSingle(),
    ]);
    const senderName: string = senderProfileResult.data?.full_name || "Someone";
    const eventTitle: string = eventResult.data?.title || "an event";

    // 6. Validate mentioned users: active event members who have opted in and
    //    are not the sender.
    const mentionedWithoutSelf = mentioned_user_ids.filter((id) => id !== user.id);
    if (mentionedWithoutSelf.length === 0) {
      return new Response(JSON.stringify({ sent: 0, reason: "self_mention_only" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check event_guests for active membership.
    const { data: validGuestRows } = await admin
      .from("event_guests")
      .select("user_id")
      .eq("event_id", eventId)
      .in("status", ["going", "maybe", "accepted", "pending"])
      .in("user_id", mentionedWithoutSelf);

    // Also include the event creator if they are mentioned (they may lack a guest row).
    const { data: evtCreator } = await admin
      .from("events")
      .select("created_by")
      .eq("id", eventId)
      .maybeSingle();
    const creatorId: string | null = evtCreator?.created_by ?? null;

    const validMemberIds = new Set<string>(
      (validGuestRows ?? []).map((g: { user_id: string }) => g.user_id)
    );
    if (creatorId && mentionedWithoutSelf.includes(creatorId)) {
      validMemberIds.add(creatorId);
    }

    if (validMemberIds.size === 0) {
      return new Response(JSON.stringify({ sent: 0, reason: "no_valid_members" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Filter to users who have mention notifications enabled.
    const { data: optedInProfiles } = await admin
      .from("user_profiles")
      .select("user_id")
      .in("user_id", Array.from(validMemberIds))
      .eq("mention_notifications_enabled", true);

    const optedInIds = (optedInProfiles ?? []).map((p: { user_id: string }) => p.user_id);
    if (optedInIds.length === 0) {
      return new Response(JSON.stringify({ sent: 0, reason: "all_opted_out" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const preview = message_preview.length > 80
      ? `${message_preview.substring(0, 80)}…`
      : message_preview;
    const title = `${senderName} mentioned you`;
    const notifBody = `In ${eventTitle}: ${preview}`;

    // 7. Write in-app notifications to trip_notifications for opted-in users.
    //    The broadcast_trip_notification DB trigger fires on INSERT and delivers
    //    via Realtime to each user's NotificationsProvider.
    await Promise.all(
      optedInIds.map((uid: string) =>
        admin.from("trip_notifications").insert({
          user_id: uid,
          type: "chat_mention",
          title,
          body: notifBody,
          reference_id: eventId,
          is_read: false,
          metadata: { sender_id: user.id, event_id: eventId },
        })
      )
    );

    // 8. Fetch device tokens and send FCM push.
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

    // 10. Send FCM notifications.
    const results = await Promise.all(
      tokenRows.map((row: { id: string; token: string }) =>
        sendFcmMessage(
          serviceAccount.project_id,
          accessToken,
          row.id,
          row.token,
          title,
          notifBody,
          { type: "chat_mention", event_id: eventId },
        )
      ),
    );

    // 11. Remove stale tokens.
    const staleIds = results.filter((r) => r.stale).map((r) => r.rowId);
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
