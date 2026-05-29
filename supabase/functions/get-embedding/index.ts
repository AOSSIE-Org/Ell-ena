// supabase/functions/get-embedding/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import "https://deno.land/std@0.192.0/dotenv/load.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");

console.log("GEMINI_API_KEY:", GEMINI_API_KEY ? "Loaded" : "Missing");

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { text } = await req.json();
    
    if (!text) {
      throw new Error("No text provided for embedding");
    }

    // Generate embedding using Gemini embedding model
    const embeddingResponse = await fetch("https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=" + GEMINI_API_KEY, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        content: {
          parts: [
            {
              text: text
            }
          ]
        }
      }),
    });

    if (!embeddingResponse.ok) {
      const error = await embeddingResponse.json();
      throw new Error(`Error generating embedding: ${error.error?.message || "Unknown error"}`);
    }

    const embeddingData = await embeddingResponse.json();
    const embedding = embeddingData.embedding.values;

    return new Response(
      JSON.stringify({ embedding }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Unknown error" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

