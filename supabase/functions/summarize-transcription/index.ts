import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflight } from "../_shared/cors.ts";


// import "https://deno.land/std@0.192.0/dotenv/load.ts";


const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");


console.log("GEMINI_API_KEY:", GEMINI_API_KEY ? "Loaded" : "Missing");
console.log("SUPABASE_URL:", SUPABASE_URL ? "Loaded" : "Missing");
console.log("SUPABASE_SERVICE_ROLE_KEY:", SUPABASE_SERVICE_ROLE_KEY ? "Loaded" : "Missing");

const meetingSummarySchema = {
  type: "OBJECT",
  properties: {
    key_discussion_points: {
      type: "ARRAY",
      items: { type: "STRING" },
      description: "A list of the key topics that were discussed in the meeting."
    },
    important_decisions: {
      type: "ARRAY",
      items: { type: "STRING" },
      description: "A list of the important decisions that were officially made."
    },
    action_items: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          item: { type: "STRING", description: "The specific action item or task to be completed." },
          owner: { type: "STRING", description: "The person or team assigned to the action item." },
          deadline: { type: "STRING", description: "The deadline for the task, e.g., 'YYYY-MM-DD' or 'N/A' if not specified." }
        },
        required: ["item", "owner", "deadline"]
      },
      description: "A list of all actionable tasks assigned during the meeting."
    },
    meeting_highlights: {
        type: "ARRAY",
        items: { type: "STRING" },
        description: "A list of notable moments, positive outcomes, or key achievements from the meeting."
    },
    follow_up_tasks: {
        type: "ARRAY",
        items: {
            type: "OBJECT",
            properties: {
                task: { type: "STRING", description: "The follow-up task to be completed." },
                deadline: { type: "STRING", description: "The deadline for the task, or 'N/A'." }
            },
            required: ["task", "deadline"]
        },
        description: "A list of follow-up tasks discussed that are not formal action items."
    },
    overall_summary: {
      type: "STRING",
      description: "A comprehensive, professional analysis of the entire meeting, written in a narrative format (minimum 200 words)."
    }
  },
  required: ["key_discussion_points", "important_decisions", "action_items", "meeting_highlights", "follow_up_tasks", "overall_summary"]
};


serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  try {
    if (!GEMINI_API_KEY || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      throw new Error("Missing environment variables");
    }

    const { meeting_id } = await req.json();
    if (!meeting_id) throw new Error("Missing meeting_id");

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: meeting, error } = await supabase
      .from("meetings")
      .select("id, final_transcription")
      .eq("id", meeting_id)
      .single();

    if (error || !meeting) throw new Error("Meeting not found");
    if (!meeting.final_transcription) throw new Error("No transcription available");

    const segments = meeting.final_transcription;
    const transcript = segments.map((seg: any) => 
      `${seg.speaker || "Unknown"}: ${seg.text}`
    ).join("\n\n");

    const systemPrompt = `
      You're an expert meeting analyst. Analyze the meeting transcript and generate a comprehensive summary in strict JSON format with these keys:
      - "key_discussion_points": array of key topics discussed (minimum 5 items)
      - "important_decisions": array of important decisions made
      - "action_items": array of objects with "item", "owner", and "deadline" properties
      - "meeting_highlights": array of notable moments/achievements
      - "follow_up_tasks": array of objects with "task" and "deadline" properties
      - "overall_summary": string (minimum 200 words) providing comprehensive analysis
      
      Requirements:
      1. Use detailed, professional language
      2. Include all important technical details
      3. Extract deadlines where mentioned
      4. Identify action owners from speaker names
      5. Maintain strict JSON format - no additional text
      
      Meeting transcript:
    `;

    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{
            parts: [{ text: systemPrompt + transcript }]
          }],
          generationConfig: {
            temperature: 0.2,
            maxOutputTokens: 4096,
            responseMimeType: "application/json",
            responseSchema: meetingSummarySchema
          }
        })
      }
    );

    if (!geminiResponse.ok) {
      const error = await geminiResponse.text();
      throw new Error(`Gemini API error: ${error}`);
    }

    const geminiData = await geminiResponse.json();
    const responseText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text || "{}";
    
    let structuredSummary;
    try {
      structuredSummary = JSON.parse(responseText);
    } catch (e) {
      throw new Error(`Failed to parse JSON: ${e.message}`);
    }

    const requiredKeys = [
      "key_discussion_points", 
      "important_decisions", 
      "action_items",
      "meeting_highlights",
      "follow_up_tasks",
      "overall_summary"
    ];
    
    for (const key of requiredKeys) {
      if (!structuredSummary.hasOwnProperty(key)) {
        throw new Error(`Missing required key in response: ${key}`);
      }
    }

    await supabase
      .from("meetings")
      .update({ 
        meeting_summary_json: structuredSummary
      })
      .eq("id", meeting_id);

    return new Response(JSON.stringify({ 
      success: true, 
      summary: structuredSummary 
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});