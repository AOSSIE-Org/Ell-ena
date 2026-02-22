import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!GEMINI_API_KEY || GEMINI_API_KEY.trim() === "")
  throw new Error("GEMINI_API_KEY is not set");

if (!SUPABASE_URL || SUPABASE_URL.trim() === "")
  throw new Error("SUPABASE_URL is not set");

if (!SUPABASE_SERVICE_ROLE_KEY || SUPABASE_SERVICE_ROLE_KEY.trim() === "")
  throw new Error("SUPABASE_SERVICE_ROLE_KEY is not set");

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

function flattenObject(obj: unknown): string {
  if (obj == null) return "";
  if (typeof obj === "string") return obj;
  if (typeof obj === "number" || typeof obj === "boolean") return String(obj);
  if (Array.isArray(obj)) return obj.map(flattenObject).join(" ");
  if (typeof obj === "object")
    return Object.values(obj as Record<string, unknown>)
      .map(flattenObject)
      .join(" ");
  return "";
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ---------- Parse JSON Safely ----------
    let rawBody: unknown;
    try {
      rawBody = await req.json();
    } catch {
      throw new Error("Invalid JSON body");
    }

    if (!rawBody || typeof rawBody !== "object") {
      throw new Error("Body must be a JSON object");
    }

    const body = rawBody as Record<string, unknown>;

    let entity_type = body.entity_type as string | undefined;
    let entity_id = body.entity_id as string | number | undefined;

    if (body.meeting_id) {
      entity_type = "meeting";
      entity_id = body.meeting_id as string | number;
    }

    if (
      !entity_type ||
      !entity_id ||
      typeof entity_type !== "string" ||
      !Object.prototype.hasOwnProperty.call(ENTITY_CONFIG, entity_type)
    ) {
      throw new Error("Invalid entity_type or entity_id");
    }

    const config = ENTITY_CONFIG[entity_type];

    const supabaseClient = createClient(
      SUPABASE_URL,
      SUPABASE_SERVICE_ROLE_KEY
    );

    // Always convert ID to string for safety
    const safeId = String(entity_id);

    const { data, error } = await supabaseClient
      .from(config.table)
      .select(config.textField)
      .eq("id", safeId)
      .single();

    if (error) {
      throw new Error(`Database fetch error: ${error.message}`);
    }

    if (!data || !(config.textField in data)) {
      throw new Error("No content found for embedding");
    }

    const rawValue = data[config.textField];

    let textToEmbed =
      entity_type === "meeting"
        ? flattenObject(rawValue)
        : String(rawValue ?? "");

    if (!textToEmbed || textToEmbed.trim() === "") {
      throw new Error("Text content is empty");
    }

    if (textToEmbed.length > 8000) {
      textToEmbed = textToEmbed.substring(0, 8000);
    }

    // ---------- Gemini Call with Robust Timeout ----------
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15000);

    let embeddingResponse: Response;

    try {
      embeddingResponse = await fetch(
        `https://generativelanguage.googleapis.com/v1/models/embedding-001:embedContent?key=${GEMINI_API_KEY}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            model: "embedding-001",
            content: { parts: [{ text: textToEmbed }] },
            taskType: "RETRIEVAL_DOCUMENT",
          }),
          signal: controller.signal,
        }
      );
    } catch (err) {
      if (
        err instanceof DOMException &&
        err.name === "AbortError"
      ) {
        throw new Error("Embedding API request timed out");
      }
      throw err;
    } finally {
      clearTimeout(timeout);
    }

    if (!embeddingResponse.ok) {
      const errorText = await embeddingResponse.text();
      throw new Error(`Embedding API error: ${errorText}`);
    }

    let embeddingData: unknown;

    try {
      embeddingData = await embeddingResponse.json();
    } catch {
      throw new Error("Invalid embedding API JSON response");
    }

    if (
      !embeddingData ||
      typeof embeddingData !== "object" ||
      !("embedding" in embeddingData)
    ) {
      throw new Error("Invalid embedding response format");
    }

    const embeddingObj = (embeddingData as Record<string, unknown>).embedding;

    if (
      !embeddingObj ||
      typeof embeddingObj !== "object" ||
      !Array.isArray((embeddingObj as any).values)
    ) {
      throw new Error("Invalid embedding values format");
    }

    const embedding = (embeddingObj as any).values;

    const { error: updateError } = await supabaseClient
      .from(config.table)
      .update({ [config.embeddingField]: embedding })
      .eq("id", safeId);

    if (updateError) {
      throw new Error(`Database update error: ${updateError.message}`);
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({
        error:
          error instanceof Error ? error.message : "Unknown error",
      }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});