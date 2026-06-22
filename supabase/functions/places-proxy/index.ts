// Deploy:  supabase functions deploy places-proxy --no-verify-jwt
// Secret required:
//   supabase secrets set GOOGLE_PLACES_API_KEY='<google-maps-platform-key>'
//
// Server-side proxy for Google Places (New) + Geocoding so the API key never
// ships in the app bundle for these calls. Deployed with --no-verify-jwt so the
// `photo` action can be loaded directly by an <img>/Image.network on web (which
// cannot send Authorization headers). The key itself is never exposed — the
// `photo` action streams the image bytes rather than redirecting to a keyed URL.
//
// Actions (via ?action=):
//   searchText        POST { textQuery, maxResultCount, includedType, locationBias? }
//   autocomplete      POST { input, languageCode }
//   placeDetails      GET  ?placeId=...            → formattedAddress, location, displayName
//   restaurantDetails GET  ?placeId=...            → rating, priceLevel, photos
//   geocode           GET  ?latlng=.. | ?address=.. [&result_type=..]
//   photo             GET  ?ref=places/X/photos/Y&maxWidth=400  → image bytes

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GOOGLE_KEY = Deno.env.get("GOOGLE_PLACES_API_KEY") ?? "";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

// Forwards a Google JSON response verbatim so existing client parsing is unchanged.
async function passthrough(r: Response): Promise<Response> {
  const text = await r.text();
  return new Response(text, {
    status: r.status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

async function searchText(req: Request): Promise<Response> {
  const body = await req.json();
  const r = await fetch("https://places.googleapis.com/v1/places:searchText", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": GOOGLE_KEY,
      "X-Goog-FieldMask":
        "places.id,places.displayName,places.formattedAddress,places.rating,places.priceLevel,places.photos,places.primaryType",
    },
    body: JSON.stringify(body),
  });
  return passthrough(r);
}

async function autocomplete(req: Request): Promise<Response> {
  const body = await req.json();
  const r = await fetch("https://places.googleapis.com/v1/places:autocomplete", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": GOOGLE_KEY,
    },
    body: JSON.stringify(body),
  });
  return passthrough(r);
}

async function placeDetails(url: URL): Promise<Response> {
  const placeId = url.searchParams.get("placeId") ?? "";
  if (!placeId) return json({ error: "Missing placeId" }, 400);
  const r = await fetch(
    `https://places.googleapis.com/v1/places/${encodeURIComponent(placeId)}`,
    {
      headers: {
        "X-Goog-Api-Key": GOOGLE_KEY,
        "X-Goog-FieldMask": "formattedAddress,location,displayName",
      },
    },
  );
  return passthrough(r);
}

async function restaurantDetails(url: URL): Promise<Response> {
  const placeId = url.searchParams.get("placeId") ?? "";
  if (!placeId) return json({ error: "Missing placeId" }, 400);
  const r = await fetch(
    `https://places.googleapis.com/v1/places/${encodeURIComponent(placeId)}`,
    {
      headers: {
        "X-Goog-Api-Key": GOOGLE_KEY,
        "X-Goog-FieldMask": "rating,priceLevel,photos",
      },
    },
  );
  return passthrough(r);
}

async function geocode(url: URL): Promise<Response> {
  const params = new URLSearchParams();
  for (const k of ["latlng", "address", "result_type"]) {
    const v = url.searchParams.get(k);
    if (v) params.set(k, v);
  }
  params.set("key", GOOGLE_KEY);
  const r = await fetch(
    `https://maps.googleapis.com/maps/api/geocode/json?${params.toString()}`,
  );
  return passthrough(r);
}

async function photo(url: URL): Promise<Response> {
  const ref = url.searchParams.get("ref") ?? "";
  const maxWidth = url.searchParams.get("maxWidth") ?? "400";
  if (!ref) return json({ error: "Missing ref" }, 400);
  // ref is "places/X/photos/Y"; fetch() follows Google's 302 to the image bytes.
  const r = await fetch(
    `https://places.googleapis.com/v1/${ref}/media` +
      `?maxWidthPx=${encodeURIComponent(maxWidth)}&key=${GOOGLE_KEY}`,
  );
  if (!r.ok) return json({ error: `Photo fetch failed (${r.status})` }, r.status);
  const buf = await r.arrayBuffer();
  return new Response(buf, {
    headers: {
      ...cors,
      "Content-Type": r.headers.get("Content-Type") ?? "image/jpeg",
      "Cache-Control": "public, max-age=86400",
    },
  });
}

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (!GOOGLE_KEY) {
    return json({ error: "Server missing GOOGLE_PLACES_API_KEY secret" }, 500);
  }

  const url = new URL(req.url);
  const action = url.searchParams.get("action") ?? "";

  try {
    switch (action) {
      case "searchText":
        return await searchText(req);
      case "autocomplete":
        return await autocomplete(req);
      case "placeDetails":
        return await placeDetails(url);
      case "restaurantDetails":
        return await restaurantDetails(url);
      case "geocode":
        return await geocode(url);
      case "photo":
        return await photo(url);
      default:
        return json({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (e) {
    return json({ error: `Proxy error: ${String(e)}` }, 502);
  }
});
