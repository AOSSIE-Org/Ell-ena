import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflight } from "../_shared/cors.ts";

const VEXA_API_BASE = (
  Deno.env.get("VEXA_API_URL") ?? "https://api.cloud.vexa.ai"
).replace(/\/$/, "");

function jsonResponse(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

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

function transcriptSegments(bodyText: string): unknown[] | null {
  try {
    const parsed = JSON.parse(bodyText);
    if (Array.isArray(parsed)) return parsed;
    if (parsed && typeof parsed === "object" && Array.isArray(parsed.segments)) {
      return parsed.segments;
    }
  } catch {
    return null;
  }
  return null;
}

function isTranscriptNotReady(status: number, bodyText: string): boolean {
  if (status === 404) return true;
  const segments = transcriptSegments(bodyText);
  return segments !== null && segments.length === 0;
}

async function markTranscriptionAttempt(
  supabase: SupabaseClient,
  meetingId: string,
  fields: Record<string, unknown>,
): Promise<void> {
  // Build update payload conditionally to preserve transcript if it exists.
  // Only include transcription_error when the caller provided it.
  const payload = {
    transcription_attempted_at: new Date().toISOString(),
    ...fields,
  };

  const { error } = await supabase
    .from("meetings")
    .update(payload)
    .eq("id", meetingId);

  if (!error) return;

  const message = error.message ?? "";
  console.error("Meeting update failed:", message);

  if (!/transcription_error/i.test(message)) return;

  const { transcription_error: _ignored, ...withoutErrorColumn } = payload;
  const retry = await supabase
    .from("meetings")
    .update(withoutErrorColumn)
    .eq("id", meetingId);

  // Log if the attempt marking also fails
  if (retry.error) {
    console.error(
      "Meeting update without transcription_error also failed:",
      retry.error.message,
    );
  } else {
    console.log("Meeting updated without transcription_error column");
  }
}

serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  console.log("Fetch-transcript function called");

  // Handle GET requests for testing
  if (req.method === "GET") {
    return jsonResponse(400, {
      message:
        "This endpoint requires a POST request with meeting_url and meeting_id in the body",
    });
  }

  try {
    // Check if environment variables are set
    const vexaApiKey = Deno.env.get("VEXA_TX_API_KEY") ??
      Deno.env.get("VEXA_API_KEY") ??
      "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!vexaApiKey) {
      console.error("VEXA_TX_API_KEY / VEXA_API_KEY is not set");
      return jsonResponse(500, {
        error: "VEXA_TX_API_KEY or VEXA_API_KEY is not set",
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
      return jsonResponse(400, { error: "Missing meeting_url in request" });
    }
    if (!meetingId) {
      return jsonResponse(400, { error: "Missing meeting_id in request" });
    }

    const meeting = normalizeGoogleMeet(meetingUrlRaw);
    if (!meeting) {
      return jsonResponse(400, { error: "Only Google Meet URLs are supported" });
    }

    console.log("Normalized Google Meet URL:", meeting.url);
    // Extract meeting ID from Google Meet URL
    console.log("Extracted Google Meet ID:", meeting.meetId);

    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const transcriptUrl =
      `${VEXA_API_BASE}/transcripts/google_meet/${encodeURIComponent(meeting.meetId)}`;

    // Fetch transcript
    console.log("Fetching transcript from Vexa API", { url: transcriptUrl });

    let transcriptRes: Response;
    try {
      transcriptRes = await fetch(transcriptUrl, {
        headers: {
          "Content-Type": "application/json",
          "X-API-Key": vexaApiKey,
        },
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error("Vexa transcript fetch failed:", message);
      // Mark as attempted and store error (and transcript if available)
      await markTranscriptionAttempt(supabase, meetingId, {
        transcription_error: message,
      });
      return jsonResponse(502, {
        error: "Failed to reach Vexa",
        details: message,
      });
    }

    const responseText = await transcriptRes.text();
    console.log("Vexa transcript status:", transcriptRes.status);
    console.log("Vexa transcript body:", responseText.slice(0, 2000));

    if (isTranscriptNotReady(transcriptRes.status, responseText)) {
      const message =
        "Transcript is not ready yet. The meeting may still be in progress or has not been transcribed.";
      console.log(message, { status: transcriptRes.status });
      await markTranscriptionAttempt(supabase, meetingId, {
        transcription_error: message,
      });
      return jsonResponse(409, {
        pending: true,
        error: message,
        vexa_status: transcriptRes.status,
        vexa_body: responseText,
      });
    }

    if (!transcriptRes.ok) {
      console.error(
        `Vexa API error: HTTP ${transcriptRes.status} ${responseText}`,
      );
      await markTranscriptionAttempt(supabase, meetingId, {
        transcription_error: `Vexa API error: HTTP ${transcriptRes.status}`,
      });
      return jsonResponse(transcriptRes.status, {
        error: "Vexa API request failed",
        vexa_status: transcriptRes.status,
        vexa_body: responseText,
      });
    }

    // Declare transcript variable in outer scope to access in catch block
    const segments = transcriptSegments(responseText);
    const transcript = segments
      ? JSON.stringify({ segments })
      : responseText;

    console.log("Transcript fetched successfully, length:", transcript.length);

    const stopUrl =
      `${VEXA_API_BASE}/bots/google_meet/${encodeURIComponent(meeting.meetId)}`;
    // Stop bot
    console.log("Stopping bot", { url: stopUrl });
    try {
      const stopBotRes = await fetch(stopUrl, {
        method: "DELETE",
        headers: {
          "Content-Type": "application/json",
          "X-API-Key": vexaApiKey,
        },
      });
      const stopBody = await stopBotRes.text();
      if (!stopBotRes.ok) {
        // Don't throw here as we still want to save the transcript
        console.warn(
          `Failed to stop bot: HTTP ${stopBotRes.status} ${stopBody}`,
        );
      } else {
        console.log("Bot stopped successfully");
      }
    } catch (error) {
      console.warn(
        "Failed to stop bot:",
        error instanceof Error ? error.message : error,
      );
    }

    // Update meeting record with transcript - WITH PROPER ERROR HANDLING
    console.log("Updating meeting record with transcript");
    const { error: updateError } = await supabase
      .from("meetings")
      .update({
        transcription: transcript,
        transcription_attempted_at: new Date().toISOString(),
        transcription_error: null, // Clear any previous errors on success
      })
      .eq("id", meetingId);

    // Check if the update actually succeeded
    if (updateError) {
      console.error("Database update failed:", updateError.message);
      if (/transcription_error/i.test(updateError.message)) {
        const retry = await supabase
          .from("meetings")
          .update({
            transcription: transcript,
            transcription_attempted_at: new Date().toISOString(),
          })
          .eq("id", meetingId);
        if (!retry.error) {
          return jsonResponse(200, {
            success: true,
            transcript,
            message: "Transcript successfully fetched and saved",
          });
        }
        console.error("Retry without transcription_error failed:", retry.error.message);
      }
      return jsonResponse(500, {
        error: `Database update failed: ${updateError.message}`,
        transcript, // Include transcript in response if available
      });
    }

    console.log("Meeting record updated successfully");
    return jsonResponse(200, {
      success: true,
      transcript,
      message: "Transcript successfully fetched and saved",
    });
  } catch (error) {
    console.error("Error in fetch-transcript function:", error);
    return jsonResponse(500, {
      error: error instanceof Error ? error.message : "Unknown error",
      details: "Internal server error",
    });
  }
});
