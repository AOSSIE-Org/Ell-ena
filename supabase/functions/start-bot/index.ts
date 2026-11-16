import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflight } from "../_shared/cors.ts";

const VEXA_API_KEY = Deno.env.get("VEXA_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  console.log("Start-bot function called");
  
  // Handle GET requests for testing
  if (req.method === "GET") {
    return new Response(
      JSON.stringify({ 
        message: "This endpoint requires a POST request with meeting_url and meeting_id in the body" 
      }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
  
  try {
    // Check if environment variables are set
    if (!VEXA_API_KEY) {
      console.error("VEXA_API_KEY is not set");
      return new Response(
        JSON.stringify({ error: "VEXA_API_KEY is not set" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      console.error("SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is not set");
      return new Response(
        JSON.stringify({ error: "Database credentials are not set" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
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
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    
    const { meeting_url, meeting_id } = body;
    
    // Validate inputs
    if (!meeting_url) {
      console.error("Missing meeting_url in request");
      return new Response(
        JSON.stringify({ error: "Missing meeting_url in request" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    
    if (!meeting_id) {
      console.error("Missing meeting_id in request");
      return new Response(
        JSON.stringify({ error: "Missing meeting_id in request" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
  
    // Validate if URL is Google Meet
    if (!meeting_url.includes("meet.google.com")) {
      console.error("Only Google Meet URLs are supported");
      return new Response(
        JSON.stringify({ error: "Only Google Meet URLs are supported" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
  
    // Extract meeting ID from Google Meet URL
    const meetId = meeting_url.split('/').pop().split('?')[0];
    console.log("Extracted Google Meet ID:", meetId);
  
    // Start bot
    console.log("Calling Vexa API to start bot");
    const response = await fetch("https://gateway.dev.vexa.ai/bots", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-API-Key": VEXA_API_KEY
      },
      body: JSON.stringify({
        platform: "google_meet",
        native_meeting_id: meetId,
        bot_name: "EllenaTranscriber"
      })
    });
    
    const result = await response.json();
    console.log("Vexa API response:", JSON.stringify(result));
    
    // Update meeting record
    console.log("Updating meeting record in database");
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { error: updateError } = await supabase
    .from('meetings')
    .update({ bot_started_at: new Date().toISOString() })
    .eq('id', meeting_id);

    if (updateError) {
      console.error("Failed to update meeting record:", updateError);
      return new Response(
        JSON.stringify({ 
          error: "Bot started but failed to update meeting record",
          details: updateError.message 
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    
    console.log("Meeting record updated successfully");
    
    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Error in start-bot function:", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Unknown error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
}) 