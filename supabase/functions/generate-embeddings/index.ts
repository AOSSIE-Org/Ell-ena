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

async function generateEmbedding(text: string): Promise<number[]> {
  // Generate embedding using Gemini
  const embeddingResponse = await fetch("https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=" + GEMINI_API_KEY, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "models/gemini-embedding-001",
      content: {
        parts: [
          {
            text: text
          }
        ]
      },
      taskType: "RETRIEVAL_DOCUMENT",
      outputDimensionality: 768,
    }),
  });

  if (!embeddingResponse.ok) {
    const error = await embeddingResponse.json();
    throw new Error(`Error generating embedding: ${error.error?.message || "Unknown error"}`);
  }

  const embeddingData = await embeddingResponse.json();
  return embeddingData.embedding.values;
}

function buildSearchableText(title: unknown, description: unknown): string {
  const parts: string[] = [];
  if (typeof title === "string" && title.trim()) parts.push(title.trim());
  if (typeof description === "string" && description.trim()) parts.push(description.trim());
  return parts.join("\n\n");
}

serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  try {
    const body = await req.json();
    const meeting_id = body.meeting_id as string | undefined;
    const entity_type = body.entity_type as string | undefined;
    const id = body.id as string | undefined;

    // Initialize Supabase client with service role key
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    if (meeting_id) {
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

      const embedding = await generateEmbedding(summaryText);

      // Update meeting with embedding
      const { error: updateError } = await supabaseClient
        .from("meetings")
        .update({ summary_embedding: embedding })
        .eq("id", meeting_id);

      if (updateError) {
        throw new Error(`Error updating meeting with embedding: ${updateError.message}`);
      }
    } else if ((entity_type === "task" || entity_type === "ticket") && id) {
      const table = entity_type === "task" ? "tasks" : "tickets";
      const { data: row, error: fetchError } = await supabaseClient
        .from(table)
        .select("title, description")
        .eq("id", id)
        .single();

      if (fetchError) {
        throw new Error(`Error fetching ${entity_type}: ${fetchError.message}`);
      }

      const searchableText = buildSearchableText(row?.title, row?.description);
      if (!searchableText) {
        throw new Error(`No searchable text found for ${entity_type} ${id}`);
      }

      const embedding = await generateEmbedding(searchableText);

      const { error: updateError } = await supabaseClient
        .from(table)
        .update({ description_embedding: embedding })
        .eq("id", id);

      if (updateError) {
        throw new Error(`Error updating ${entity_type} with embedding: ${updateError.message}`);
      }
    } else {
      throw new Error('Provide meeting_id or { entity_type: "task"|"ticket", id }');
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
