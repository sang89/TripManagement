// Public session signup page — serves plain HTML so guests WITHOUT the app
// can sign up by scanning the session QR code.
//
//   GET  /session-signup?code=<invite_code>   → renders signup form
//   POST /session-signup?code=<invite_code>   → submits rsvp_session, renders result
//
// Deploy with: supabase functions deploy session-signup --no-verify-jwt

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_ANON_KEY")!,
);

const esc = (s: unknown): string =>
  String(s ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");

const page = (title: string, body: string): Response =>
  new Response(
    `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
<style>
  :root { color-scheme: light; }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    background: linear-gradient(160deg, #E8F5E9 0%, #F1F8E9 60%, #FFFDE7 100%);
    min-height: 100vh; display: flex; justify-content: center; padding: 24px 16px;
  }
  .card {
    background: #fff; border-radius: 24px; padding: 28px 24px; max-width: 420px;
    width: 100%; height: fit-content;
    box-shadow: 0 8px 32px rgba(46,125,50,.18);
  }
  .badge {
    display: inline-block; background: linear-gradient(135deg,#1B5E20,#43A047);
    color: #fff; font-weight: 700; font-size: 13px; padding: 6px 14px;
    border-radius: 20px; margin-bottom: 12px;
  }
  h1 { font-size: 24px; color: #1B5E20; margin-bottom: 16px; }
  .info { display: flex; gap: 8px; align-items: center; color: #555;
          font-size: 14px; margin-bottom: 8px; }
  .bar-wrap { background: #E8F5E9; border-radius: 8px; height: 10px;
              margin: 14px 0 6px; overflow: hidden; }
  .bar { background: linear-gradient(90deg,#2E7D32,#66BB6A); height: 100%;
         border-radius: 8px; }
  .bar.full { background: linear-gradient(90deg,#E53935,#FF7043); }
  .spots { font-size: 13px; color: #777; margin-bottom: 18px; }
  label { display: block; font-size: 13px; font-weight: 600; color: #444;
          margin: 14px 0 4px; }
  input {
    width: 100%; padding: 12px 14px; font-size: 16px; border: 1.5px solid #C8E6C9;
    border-radius: 12px; outline: none;
  }
  input:focus { border-color: #43A047; }
  button {
    width: 100%; margin-top: 22px; padding: 15px; font-size: 16px; font-weight: 700;
    color: #fff; background: linear-gradient(135deg,#1B5E20,#43A047);
    border: none; border-radius: 14px; cursor: pointer;
  }
  button:active { opacity: .85; }
  .banner { border-radius: 14px; padding: 14px 16px; font-size: 14px;
            margin-top: 18px; }
  .warn { background: #FFF3E0; color: #E65100; border: 1px solid #FFCC80; }
  .danger { background: #FFEBEE; color: #C62828; border: 1px solid #EF9A9A; }
  .success-icon { font-size: 64px; text-align: center; margin: 16px 0; }
  .center { text-align: center; }
  .pos { font-size: 20px; font-weight: 800; color: #1B5E20; }
</style>
</head>
<body><div class="card">${body}</div></body>
</html>`,
    { headers: { "Content-Type": "text/html; charset=utf-8" } },
  );

async function fetchSession(code: string) {
  const { data, error } = await supabase.rpc("get_session_by_invite_code", {
    p_invite_code: code,
  });
  if (error || !data || data.length === 0) return null;
  return data[0];
}

function sessionHeader(s: Record<string, unknown>): string {
  const start = new Date(s.start_at as string);
  const when = start.toLocaleString("en-US", {
    weekday: "short", month: "short", day: "numeric",
    hour: "numeric", minute: "2-digit",
  });
  const going = Number(s.going_count ?? 0);
  const cap = s.capacity as number | null;
  const pct = cap ? Math.min(100, Math.round((going / cap) * 100)) : 0;
  return `
    <div class="badge">Session #${esc(s.session_number)}</div>
    <h1>${esc(s.title)}</h1>
    <div class="info">🗓️ ${esc(when)}</div>
    ${s.location ? `<div class="info">📍 ${esc(s.location)}</div>` : ""}
    ${s.organizer_name ? `<div class="info">👤 Organized by ${esc(s.organizer_name)}</div>` : ""}
    ${
      cap
        ? `<div class="bar-wrap"><div class="bar ${pct >= 100 ? "full" : ""}" style="width:${pct}%"></div></div>
           <div class="spots">${going} / ${cap} spots filled${
             Number(s.waitlist_count) > 0 ? ` · ⏳ ${esc(s.waitlist_count)} waiting` : ""
           }</div>`
        : `<div class="spots">${going} signed up</div>`
    }`;
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const code = url.searchParams.get("code");
  if (!code) return page("Not found", `<h1>Invalid link</h1>`);

  const s = await fetchSession(code);
  if (!s) {
    return page("Not found",
      `<div class="success-icon">🤔</div>
       <h1 class="center">Session not found</h1>
       <p class="center" style="color:#777">This signup link is invalid or the session was removed.</p>`);
  }

  const cap = s.capacity as number | null;
  const going = Number(s.going_count ?? 0);
  const isFull = cap !== null && going >= cap;
  const lockHours = s.signup_lock_hours as number | null;
  const isLocked = lockHours !== null &&
    Date.now() >= new Date(s.start_at as string).getTime() - lockHours * 3600_000;

  if (req.method === "POST") {
    const form = await req.formData();
    const name = String(form.get("name") ?? "").trim();
    const email = String(form.get("email") ?? "").trim();
    const phone = String(form.get("phone") ?? "").trim();
    if (!name) {
      return page("Sign up", sessionHeader(s) +
        `<div class="banner danger">Please enter your name.</div>`);
    }
    const { data, error } = await supabase.rpc("rsvp_session", {
      p_invite_code: code,
      p_display_name: name,
      p_email: email || null,
      p_phone: phone || null,
    });
    if (error) {
      const msg = error.message.includes("session_full")
        ? "This session is full and the waitlist is closed."
        : error.message.includes("signup_locked")
        ? "Signups are locked for this session."
        : "Something went wrong. Please try again.";
      return page("Sign up", sessionHeader(s) +
        `<div class="banner danger">${esc(msg)}</div>`);
    }
    const r = data[0];
    const waitlisted = r.rsvp_status === "waitlisted";
    return page("You're in!",
      `<div class="success-icon">${waitlisted ? "⏳" : "🎉"}</div>
       <h1 class="center">${waitlisted ? "You're on the waitlist" : "You're in!"}</h1>
       <p class="center" style="color:#555;margin-top:8px">
         ${esc(s.title)} · Session #${esc(s.session_number)}
       </p>
       <p class="center" style="margin-top:14px">
         ${waitlisted ? "Waitlist position" : "Your spot"}:
         <span class="pos">#${esc(r.signup_position)}</span>
       </p>`);
  }

  // GET — render the signup form (or lock/full banners).
  if (isLocked) {
    return page("Signups locked", sessionHeader(s) +
      `<div class="banner warn">🔒 Signups are locked for this session.</div>`);
  }
  const waitlistEnabled = s.waitlist_enabled !== false;
  if (isFull && !waitlistEnabled) {
    return page("Session full", sessionHeader(s) +
      `<div class="banner danger">This session is full.</div>`);
  }

  return page("Sign up", sessionHeader(s) + `
    <form method="POST" action="?code=${encodeURIComponent(code)}">
      ${isFull ? `<div class="banner warn">Session is full — you'll join the waitlist.</div>` : ""}
      <label for="name">Your name *</label>
      <input id="name" name="name" required autocomplete="name" placeholder="Jane Doe">
      <label for="email">Email (optional)</label>
      <input id="email" name="email" type="email" autocomplete="email" placeholder="jane@example.com">
      <label for="phone">Phone (optional)</label>
      <input id="phone" name="phone" type="tel" autocomplete="tel" placeholder="+1 555 123 4567">
      <button type="submit">${isFull ? "⏳ Join waitlist" : "🎟️ Claim my spot"}</button>
    </form>`);
});
