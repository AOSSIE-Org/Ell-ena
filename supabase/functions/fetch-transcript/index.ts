import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const VEXA_API_KEY = Deno.env.get("VEXA_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

serve(async (req) => {
  console.log("Fetch-transcript function called");
  
  // Handle GET requests for testing
  if (req.method === "GET") {
    return new Response(
      JSON.stringify({ 
        message: "This endpoint requires a POST request with meeting_url and meeting_id in the body" 
      }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }
  
  try {
    // Check if environment variables are set
    if (!VEXA_API_KEY) {
      console.error("VEXA_API_KEY is not set");
      return new Response(
        JSON.stringify({ error: "VEXA_API_KEY is not set" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }
    
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      console.error("SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is not set");
      return new Response(
        JSON.stringify({ error: "Database credentials are not set" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }
    
    // Parse request body
    let body;
    try {
      body = await req.json();
      console.log("Request body:", JSON.stringify(body));
    } catch (e) {
      console.error("Error parsing request body:", e);
      return new Response(
        JSON.stringify({ error: "Invalid JSON body" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }
    
    const { meeting_url, meeting_id } = body;
    
    // Validate inputs
    if (!meeting_url) {
      console.error("Missing meeting_url in request");
      return new Response(
        JSON.stringify({ error: "Missing meeting_url in request" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }
    
    if (!meeting_id) {
      console.error("Missing meeting_id in request");
      return new Response(
        JSON.stringify({ error: "Missing meeting_id in request" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }
  
    // Extract meeting ID from Google Meet URL
    const meetId = meeting_url.split('/').pop().split('?')[0];
    console.log("Extracted Google Meet ID:", meetId);
    
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    try {
      // Fetch transcript
      console.log("Fetching transcript from Vexa API");
      const transcriptRes = await fetch(
        `https://gateway.dev.vexa.ai/transcripts/google_meet/${meetId}`,
        { headers: { "X-API-Key": VEXA_API_KEY } }
      );
      
      if (!transcriptRes.ok) {
        const errorText = await transcriptRes.text();
        console.error(`Vexa API error: ${transcriptRes.status} - ${errorText}`);
        throw new Error(`Vexa API error: ${transcriptRes.status}`);
      }
      
      const transcript = await transcriptRes.text();
      console.log("Transcript fetched successfully, length:", transcript.length);

      // Stop bot
      console.log("Stopping bot");
      const stopBotRes = await fetch(
        `https://gateway.dev.vexa.ai/bots/google_meet/${meetId}`,
        {
          method: "DELETE",
          headers: { "X-API-Key": VEXA_API_KEY }
        }
      );
      
      if (!stopBotRes.ok) {
        console.warn(`Failed to stop bot: ${stopBotRes.status}`);
        // Don't throw here as we still want to save the transcript
      } else {
        console.log("Bot stopped successfully");
      }

      // Update meeting record with transcript - WITH PROPER ERROR HANDLING
      console.log("Updating meeting record with transcript");
      const { data: updateData, error: updateError } = await supabase
        .from('meetings')
        .update({ 
          transcription: transcript,
          transcription_attempted_at: new Date().toISOString() 
        })
        .eq('id', meeting_id);
      
      // Check if the update actually succeeded
      if (updateError) {
        console.error("Database update failed:", updateError);
        throw new Error(`Database update failed: ${updateError.message}`);
      }
      
      console.log("Meeting record updated successfully");

      return new Response(JSON.stringify({ 
        success: true, 
        transcript,
        message: "Transcript successfully fetched and saved" 
      }), {
        headers: { "Content-Type": "application/json" },
      });
    } catch (error) {
      console.error("Error in transcript process:", error);
      
      // Only mark as attempted if we haven't already updated transcription_attempted_at
      // This prevents overwriting a successful transcript with an error timestamp
      console.log("Marking transcription as attempted (failed)");
      const { error: attemptError } = await supabase
        .from('meetings')
        .update({ 
          transcription_attempted_at: new Date().toISOString(),
          transcription_error: error.message 
        })
        .eq('id', meeting_id);
        
      // Log if the attempt marking also fails
      if (attemptError) {
        console.error("Failed to mark transcription as attempted:", attemptError);
      }
        
      return new Response(
        JSON.stringify({ 
          error: error.message,
          details: "Failed to fetch or save transcript" 
        }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }
  } catch (error) {
    console.error("Error in fetch-transcript function:", error);
    return new Response(
      JSON.stringify({ 
        error: error.message,
        details: "Internal server error" 
      }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});