import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

/**
 * Constant-time string comparison to avoid timing attacks
 */
function safeCompare(a: string, b: string): boolean {
  if (a.length !== b.length) return false;

  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }

  return result === 0;
}

/**
 * Verify GitHub webhook signature
 */
async function verifySignature(req: Request, secret: string, rawBody: string) {
  const signature = req.headers.get("x-hub-signature-256");
  if (!signature) return false;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const mac = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(rawBody)
  );

  const hash = Array.from(new Uint8Array(mac))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  const expected = `sha256=${hash}`;

  return safeCompare(signature, expected);
}

serve(async (req: Request) => {
  try {
    const event = req.headers.get("x-github-event");

    // Only process pull request events
    if (event !== "pull_request") {
      return new Response(
        JSON.stringify({ message: "Event ignored" }),
        { status: 200 }
      );
    }

    const secret = Deno.env.get("GITHUB_WEBHOOK_SECRET");
    const rawBody = await req.text();

    if (!secret) {
    return new Response(
        JSON.stringify({ error: "Webhook secret not configured" }),
        { status: 500 }
    );
    }

    const valid = await verifySignature(req, secret, rawBody);

    if (!valid) {
    return new Response(
        JSON.stringify({ error: "Invalid webhook signature" }),
        { status: 401 }
    );
    }

    const payload = JSON.parse(rawBody);

    const action = payload?.action;
    const pr = payload?.pull_request;

    if (!action || !pr) {
      return new Response(
        JSON.stringify({ message: "Not a pull request event" }),
        { status: 200 }
      );
    }

    const issueUrl = pr?.issue_url;

    if (!issueUrl || typeof issueUrl !== "string") {
      return new Response(
        JSON.stringify({ message: "No issue URL found" }),
        { status: 200 }
      );
    }

    const issueNumberStr = issueUrl.split("/").pop();
    const issueNumber = Number(issueNumberStr);

    if (!issueNumber || Number.isNaN(issueNumber)) {
      return new Response(
        JSON.stringify({ message: "Invalid issue number" }),
        { status: 200 }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceKey) {
      return new Response(
        JSON.stringify({ error: "Supabase configuration missing" }),
        { status: 500 }
      );
    }

    const supabase = createClient(supabaseUrl, serviceKey);

    let newStatus: string | null = null;

    if (action === "opened") {
      newStatus = "in_progress";
    }

    if (action === "closed" && pr?.merged === true) {
      newStatus = "resolved";
    }

    if (!newStatus) {
      return new Response(
        JSON.stringify({ message: "Event ignored" }),
        { status: 200 }
      );
    }

    const { error, count } = await supabase
      .from("tickets")
      .update({ status: newStatus })
      .eq("github_issue_number", issueNumber)
      .select("id", { count: "exact" });

    if (error) {
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500 }
      );
    }

    if (!count || count === 0) {
      return new Response(
        JSON.stringify({ message: "No matching ticket found" }),
        { status: 200 }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        issue_number: issueNumber,
        updated_status: newStatus
      }),
      {
        headers: { "Content-Type": "application/json" }
      }
    );

  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500 }
    );
  }
});