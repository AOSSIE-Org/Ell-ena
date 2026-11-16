// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
// supabase/functions/generate-embeddings/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import "https://deno.land/std@0.192.0/dotenv/load.ts";
import { corsHeaders, handleCorsPreflight } from "../_shared/cors.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

console.log("GEMINI_API_KEY:", GEMINI_API_KEY ? "Loaded" : "Missing");
console.log("SUPABASE_URL:", SUPABASE_URL ? "Loaded" : "Missing");
console.log("SUPABASE_SERVICE_ROLE_KEY:", SUPABASE_SERVICE_ROLE_KEY ? "Loaded" : "Missing");

serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  try {
    const { meeting_id } = await req.json();
    
    // Initialize Supabase client with service role key
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // Fetch meeting data
    const { data: meeting, error: meetingError } = await supabaseClient
      .from("meetings")
      .select("meeting_summary_json")
      .eq("id", meeting_id)
      .single();

    if (meetingError || !meeting?.meeting_summary_json) {
      throw new Error(`Error fetching meeting: ${meetingError?.message || "No summary found"}`);
    }

    // Convert summary to string for embedding
    const summaryText = JSON.stringify(meeting.meeting_summary_json);

    // Generate embedding using Gemini
    const embeddingResponse = await fetch("https://generativelanguage.googleapis.com/v1/models/embedding-001:embedContent?key=" + GEMINI_API_KEY, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "embedding-001",
        content: {
          parts: [
            {
              text: summaryText
            }
          ]
        },
        taskType: "RETRIEVAL_DOCUMENT"
      }),
    });

    if (!embeddingResponse.ok) {
      const error = await embeddingResponse.json();
      throw new Error(`Error generating embedding: ${error.error?.message || "Unknown error"}`);
    }

    const embeddingData = await embeddingResponse.json();
    const embedding = embeddingData.embedding.values;

    // Update meeting with embedding
    const { error: updateError } = await supabaseClient
      .from("meetings")
      .update({ summary_embedding: embedding })
      .eq("id", meeting_id);

    if (updateError) {
      throw new Error(`Error updating meeting with embedding: ${updateError.message}`);
    }

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Unknown error" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
