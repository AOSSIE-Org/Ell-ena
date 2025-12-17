// supabase/functions/generate-ticket-embeddings/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import "https://deno.land/std@0.192.0/dotenv/load.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

console.log("GEMINI_API_KEY:", GEMINI_API_KEY ? "Loaded" : "Missing");
console.log("SUPABASE_URL:", SUPABASE_URL ? "Loaded" : "Missing");
console.log("SUPABASE_SERVICE_ROLE_KEY:", SUPABASE_SERVICE_ROLE_KEY ? "Loaded" : "Missing");

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { ticket_id } = await req.json();
    
    if (!ticket_id) {
      throw new Error("No ticket_id provided");
    }
    
    // Initialize Supabase client with service role key
    const supabaseClient = createClient(
      SUPABASE_URL ?? "",
      SUPABASE_SERVICE_ROLE_KEY ?? "",
    );

    // Fetch ticket data
    const { data: ticket, error: ticketError } = await supabaseClient
      .from("tickets")
      .select("title, description, category, priority")
      .eq("id", ticket_id)
      .single();

    if (ticketError || !ticket) {
      throw new Error(`Error fetching ticket: ${ticketError?.message || "Ticket not found"}`);
    }

    // Combine title, description, category and priority for better semantic representation
    const combinedText = `${ticket.title}. ${ticket.description || ""}. Category: ${ticket.category}. Priority: ${ticket.priority}.`;

    console.log(`Generating embedding for ticket ${ticket_id}: ${combinedText.substring(0, 100)}...`);

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
                text: combinedText
              }
            ]
          },
          taskType: "RETRIEVAL_DOCUMENT"
        }),
      }
    );

    if (!embeddingResponse.ok) {
      const error = await embeddingResponse.json();
      throw new Error(`Error generating embedding: ${error.error?.message || "Unknown error"}`);
    }

    const embeddingData = await embeddingResponse.json();
    const embedding = embeddingData.embedding.values;

    console.log(`Embedding generated for ticket ${ticket_id}, dimension: ${embedding.length}`);

    // Update ticket with embedding
    const { error: updateError } = await supabaseClient
      .from("tickets")
      .update({ description_embedding: embedding })
      .eq("id", ticket_id);

    if (updateError) {
      throw new Error(`Error updating ticket with embedding: ${updateError.message}`);
    }

    console.log(`Successfully updated ticket ${ticket_id} with embedding`);

    return new Response(
      JSON.stringify({ success: true, ticket_id, embedding_dimension: embedding.length }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error in generate-ticket-embeddings:", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Unknown error" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
