// Deploy:  supabase functions deploy stripe-create-checkout
// Secrets required:
//   supabase secrets set STRIPE_SECRET_KEY='sk_live_...'
//   supabase secrets set SUPABASE_SERVICE_ROLE_KEY='<key>'
//
// Called by the Flutter web app (authenticated via Supabase JWT) to create a
// Stripe Checkout Session for a subscription.
//
// Request body (JSON, authenticated):
//   {
//     price_id:    string,   // Stripe Price ID (monthly or annual)
//     success_url: string,   // where Stripe redirects on success
//     cancel_url:  string,   // where Stripe redirects on cancel
//     app:         string    // 'trip_management' | 'property_management'
//   }
//
// Response:
//   { url: string }  — the Stripe-hosted Checkout page URL

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Authenticate the caller via Supabase JWT
    const authHeader = req.headers.get("Authorization") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ??
      "https://qgeocaectbdfonrorwco.supabase.co";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Parse request body
    const { price_id, success_url, cancel_url, app } = await req.json() as {
      price_id: string;
      success_url: string;
      cancel_url: string;
      app: string;
    };

    if (!price_id || !success_url || !cancel_url || !app) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 3. Create Stripe Checkout Session
    const stripeKey = Deno.env.get("STRIPE_SECRET_KEY");
    if (!stripeKey) throw new Error("STRIPE_SECRET_KEY secret is not set");

    const params = new URLSearchParams({
      "mode": "subscription",
      "line_items[0][price]": price_id,
      "line_items[0][quantity]": "1",
      "success_url": success_url,
      "cancel_url": cancel_url,
      "customer_email": user.email ?? "",
      // Pass user_id + app in metadata so the webhook can identify the user
      "subscription_data[metadata][user_id]": user.id,
      "subscription_data[metadata][app]": app,
      // 14-day free trial
      "subscription_data[trial_period_days]": "14",
    });

    const stripeRes = await fetch(
      "https://api.stripe.com/v1/checkout/sessions",
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${stripeKey}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: params.toString(),
      },
    );

    if (!stripeRes.ok) {
      const err = await stripeRes.json();
      console.error("Stripe error:", err);
      throw new Error(err?.error?.message ?? "Stripe checkout creation failed");
    }

    const session = await stripeRes.json();

    return new Response(
      JSON.stringify({ url: session.url }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("stripe-create-checkout error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
