// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
// supabase/functions/generate-embeddings/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import "https://deno.land/std@0.192.0/dotenv/load.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const ENTITY_CONFIG: Record<
  string,
  { table: string; textField: string; embeddingField: string }
> = {
  meeting: {
    table: "meetings",
    textField: "meeting_summary_json",
    embeddingField: "summary_embedding",
  },
  task: {
    table: "tasks",
    textField: "description",
    embeddingField: "description_embedding",
  },
  ticket: {
    table: "tickets",
    textField: "description",
    embeddingField: "description_embedding",
  },
};

// Recursively flatten nested objects into a single text string
function flattenObject(obj: any): string {
  if (obj === null || obj === undefined) return "";
  if (typeof obj === "string") return obj;
  if (typeof obj === "number" || typeof obj === "boolean")
    return String(obj);
  if (Array.isArray(obj)) return obj.map(flattenObject).join(" ");
  if (typeof obj === "object")
    return Object.values(obj).map(flattenObject).join(" ");
  return "";
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();

    // Support both legacy meeting_id and new entity_type/entity_id format
    let entity_type = body.entity_type;
    let entity_id = body.entity_id;

    if (body.meeting_id) {
      entity_type = "meeting";
      entity_id = body.meeting_id;
    }

    if (!entity_type || !entity_id || !ENTITY_CONFIG[entity_type]) {
      throw new Error("Invalid entity_type or entity_id");
    }

    const config = ENTITY_CONFIG[entity_type];

    // Initialize Supabase client with service role key
    const supabaseClient = createClient(
      SUPABASE_URL ?? "",
      SUPABASE_SERVICE_ROLE_KEY ?? ""
    );

    // Fetch entity data
    const { data, error } = await supabaseClient
      .from(config.table)
      .select(config.textField)
      .eq("id", entity_id)
      .single();

    if (error || !data?.[config.textField]) {
      throw new Error(
        `Error fetching ${entity_type}: ${
          error?.message || "No content found"
        }`
      );
    }

    // Prepare text for embedding
    let textToEmbed: string;
    const rawValue = data[config.textField];

    if (entity_type === "meeting") {
      textToEmbed = flattenObject(rawValue);
    } else {
      textToEmbed = String(rawValue);
    }

    // Truncate text to reduce risk of exceeding embedding model token limits
    if (textToEmbed.length > 8000) {
      textToEmbed = textToEmbed.substring(0, 8000);
    }

    // Generate embedding using Gemini
    const embeddingResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1/models/embedding-001:embedContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "embedding-001",
          content: {
            parts: [
              {
                text: textToEmbed,
              },
            ],
          },
          taskType: "RETRIEVAL_DOCUMENT",
        }),
      }
    );

    if (!embeddingResponse.ok) {
      let errorMessage = "Unknown error";
      try {
        const errorJson = await embeddingResponse.json();
        errorMessage = errorJson?.error?.message || errorMessage;
      } catch {
        errorMessage = await embeddingResponse.text();
      }
      throw new Error(`Error generating embedding: ${errorMessage}`);
    }

    const embeddingData = await embeddingResponse.json();
    const embedding = embeddingData?.embedding?.values;

    if (!embedding) {
      throw new Error("Invalid embedding response format");
    }

    // Update entity with embedding
    const { error: updateError } = await supabaseClient
      .from(config.table)
      .update({ [config.embeddingField]: embedding })
      .eq("id", entity_id);

    if (updateError) {
      throw new Error(
        `Error updating ${entity_type} with embedding: ${updateError.message}`
      );
    }

    return new Response(
      JSON.stringify({ success: true }),
      {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : "Unknown error",
      }),
      {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  }
});
