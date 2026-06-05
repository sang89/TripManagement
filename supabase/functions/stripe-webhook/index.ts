// Deploy:  supabase functions deploy stripe-webhook
// Secrets required:
//   supabase secrets set STRIPE_SECRET_KEY='sk_live_...'
//   supabase secrets set STRIPE_WEBHOOK_SECRET='whsec_...'
//   supabase secrets set SUPABASE_SERVICE_ROLE_KEY='<key>'
//
// Register in Stripe Dashboard → Developers → Webhooks → Add endpoint:
//   URL:    https://qgeocaectbdfonrorwco.supabase.co/functions/v1/stripe-webhook
//   Events: checkout.session.completed
//           customer.subscription.updated
//           customer.subscription.deleted
//
// On each event, upserts the user_subscriptions row so the Flutter app's
// SubscriptionProvider always reflects the current entitlement state.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, stripe-signature",
};

// ─── Stripe signature verification ───────────────────────────────────────────
// Implements the HMAC-SHA256 verification that stripe.webhooks.constructEvent()
// does in the Node SDK — without needing the stripe npm package.

async function verifyStripeSignature(
  payload: string,
  sigHeader: string,
  secret: string,
): Promise<boolean> {
  const parts = sigHeader.split(",").reduce((acc, part) => {
    const [k, v] = part.split("=");
    acc[k] = v;
    return acc;
  }, {} as Record<string, string>);

  const timestamp = parts["t"];
  const signature = parts["v1"];
  if (!timestamp || !signature) return false;

  const signedPayload = `${timestamp}.${payload}`;
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(signedPayload),
  );
  const expected = Array.from(new Uint8Array(mac))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  return expected === signature;
}

// ─── Main handler ─────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!webhookSecret || !serviceRoleKey) {
    console.error("Missing required secrets");
    return new Response("Server misconfiguration", { status: 500 });
  }

  const payload = await req.text();
  const sigHeader = req.headers.get("stripe-signature") ?? "";

  const valid = await verifyStripeSignature(payload, sigHeader, webhookSecret);
  if (!valid) {
    return new Response("Invalid signature", { status: 400 });
  }

  const event = JSON.parse(payload);
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ??
    "https://qgeocaectbdfonrorwco.supabase.co";
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  try {
    switch (event.type) {
      case "checkout.session.completed": {
        // The subscription was created via Checkout. The subscription object
        // is on event.data.object.subscription (ID only at this point); the
        // full subscription details arrive via customer.subscription.updated.
        // We do a lightweight insert here so the user gains access immediately.
        const session = event.data.object;
        const subscriptionId: string = session.subscription;
        const customerId: string = session.customer;
        const customerEmail: string = session.customer_email ?? "";

        // Fetch the full subscription to get metadata + period end
        const stripeKey = Deno.env.get("STRIPE_SECRET_KEY")!;
        const subRes = await fetch(
          `https://api.stripe.com/v1/subscriptions/${subscriptionId}`,
          { headers: { Authorization: `Bearer ${stripeKey}` } },
        );
        const sub = await subRes.json();

        const userId: string = sub.metadata?.user_id ?? "";
        const app: string = sub.metadata?.app ?? "trip_management";
        if (!userId) {
          console.error("No user_id in subscription metadata", subscriptionId);
          break;
        }

        await supabase.from("user_subscriptions").upsert(
          {
            user_id: userId,
            app,
            platform: "web",
            stripe_customer_id: customerId,
            stripe_subscription_id: subscriptionId,
            stripe_price_id: sub.items?.data?.[0]?.price?.id ?? null,
            status: sub.status,
            current_period_end: sub.current_period_end
              ? new Date(sub.current_period_end * 1000).toISOString()
              : null,
            trial_end: sub.trial_end
              ? new Date(sub.trial_end * 1000).toISOString()
              : null,
            updated_at: new Date().toISOString(),
          },
          { onConflict: "stripe_subscription_id" },
        );

        console.log(
          `checkout.session.completed — user ${userId} subscribed (${app})`,
        );
        break;
      }

      case "customer.subscription.updated": {
        const sub = event.data.object;
        const userId: string = sub.metadata?.user_id ?? "";
        const app: string = sub.metadata?.app ?? "trip_management";
        if (!userId) break;

        await supabase.from("user_subscriptions").upsert(
          {
            user_id: userId,
            app,
            platform: "web",
            stripe_customer_id: sub.customer,
            stripe_subscription_id: sub.id,
            stripe_price_id: sub.items?.data?.[0]?.price?.id ?? null,
            status: sub.status,
            current_period_end: sub.current_period_end
              ? new Date(sub.current_period_end * 1000).toISOString()
              : null,
            trial_end: sub.trial_end
              ? new Date(sub.trial_end * 1000).toISOString()
              : null,
            updated_at: new Date().toISOString(),
          },
          { onConflict: "stripe_subscription_id" },
        );

        console.log(
          `customer.subscription.updated — user ${userId} status=${sub.status}`,
        );
        break;
      }

      case "customer.subscription.deleted": {
        const sub = event.data.object;
        // Mark as canceled — don't delete the row (preserve history)
        await supabase
          .from("user_subscriptions")
          .update({ status: "canceled", updated_at: new Date().toISOString() })
          .eq("stripe_subscription_id", sub.id);

        console.log(`customer.subscription.deleted — sub ${sub.id} canceled`);
        break;
      }

      default:
        console.log(`Unhandled Stripe event: ${event.type}`);
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("stripe-webhook error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
