import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflight } from "../_shared/cors.ts";

// Hosted Vexa API. https://api.vexa.ai does not resolve; gateway.dev.vexa.ai returns 502.
const VEXA_API_BASE = (
  Deno.env.get("VEXA_API_URL") ?? "https://api.cloud.vexa.ai"
).replace(/\/$/, "");

function jsonResponse(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/** Trim a Google Meet link down to https://meet.google.com/{id}. */
function normalizeGoogleMeet(
  raw: string,
): { url: string; meetId: string } | null {
  const trimmed = raw.trim();
  let parsed: URL;
  try {
    parsed = new URL(trimmed);
  } catch {
    return null;
  }
  if (!parsed.hostname.endsWith("meet.google.com")) return null;
  const meetId = parsed.pathname.split("/").filter(Boolean).pop()?.trim() ?? "";
  if (!meetId) return null;
  return { url: `https://meet.google.com/${meetId}`, meetId };
}

serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  console.log("Start-bot function called");

  // Handle GET requests for testing
  if (req.method === "GET") {
    return jsonResponse(400, {
      message:
        "This endpoint requires a POST request with meeting_url and meeting_id in the body",
    });
  }

  try {
    // Check if environment variables are set
    const vexaApiKey = Deno.env.get("VEXA_BOT_API_KEY") ??
      Deno.env.get("VEXA_API_KEY") ??
      "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!vexaApiKey) {
      console.error("VEXA_BOT_API_KEY / VEXA_API_KEY is not set");
      return jsonResponse(500, {
        error: "VEXA_BOT_API_KEY or VEXA_API_KEY is not set",
      });
    }

    if (!supabaseUrl || !serviceRoleKey) {
      console.error("SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is not set");
      return jsonResponse(500, { error: "Database credentials are not set" });
    }

    // Parse request body
    let body: Record<string, unknown>;
    try {
      body = await req.json();
      console.log("Request body:", JSON.stringify(body));
    } catch (e) {
      console.error("Error parsing request body:", e);
      return jsonResponse(400, { error: "Invalid JSON body" });
    }

    const meetingUrlRaw = typeof body.meeting_url === "string"
      ? body.meeting_url
      : "";
    const meetingId = typeof body.meeting_id === "string" ? body.meeting_id : "";

    // Validate inputs
    if (!meetingUrlRaw.trim()) {
      console.error("Missing meeting_url in request");
      return jsonResponse(400, { error: "Missing meeting_url in request" });
    }

    if (!meetingId) {
      console.error("Missing meeting_id in request");
      return jsonResponse(400, { error: "Missing meeting_id in request" });
    }

    // Validate if URL is Google Meet
    const meeting = normalizeGoogleMeet(meetingUrlRaw);
    if (!meeting) {
      console.error("Only Google Meet URLs are supported");
      return jsonResponse(400, { error: "Only Google Meet URLs are supported" });
    }

    console.log("Normalized Google Meet URL:", meeting.url);
    // Extract meeting ID from Google Meet URL
    console.log("Extracted Google Meet ID:", meeting.meetId);

    const vexaUrl = `${VEXA_API_BASE}/bots`;
    const vexaPayload = {
      platform: "google_meet",
      native_meeting_id: meeting.meetId,
      meeting_url: meeting.url,
      bot_name: "EllenaTranscriber",
    };

    // Start bot
    console.log("Calling Vexa API to start bot", { url: vexaUrl, meetId: meeting.meetId });

    let response: Response;
    try {
      response = await fetch(vexaUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-API-Key": vexaApiKey,
        },
        body: JSON.stringify(vexaPayload),
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error("Vexa fetch failed:", message);
      return jsonResponse(502, {
        error: "Failed to reach Vexa",
        details: message,
      });
    }

    const responseText = await response.text();
    console.log("Vexa API status:", response.status);
    console.log("Vexa API body:", responseText);

    if (!response.ok) {
      console.error(
        `Vexa API error: HTTP ${response.status} ${responseText}`,
      );
      return jsonResponse(response.status, {
        error: "Vexa API request failed",
        vexa_status: response.status,
        vexa_body: responseText,
      });
    }

    let result: unknown = {};
    if (responseText) {
      try {
        result = JSON.parse(responseText);
      } catch {
        result = { raw: responseText };
      }
    }

    // Update meeting record
    console.log("Updating meeting record in database");
    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const { error: updateError } = await supabase
      .from("meetings")
      .update({ bot_started_at: new Date().toISOString() })
      .eq("id", meetingId);

    if (updateError) {
      console.error("Failed to update meeting record:", updateError);
      return jsonResponse(500, {
        error: "Bot started but failed to update meeting record",
        details: updateError.message,
        vexa: result,
      });
    }

    console.log("Meeting record updated successfully");

    return jsonResponse(200, {
      success: true,
      vexa: result,
    });
  } catch (error) {
    console.error("Error in start-bot function:", error);
    return jsonResponse(500, {
      error: error instanceof Error ? error.message : "Unknown error",
    });
  }
});
