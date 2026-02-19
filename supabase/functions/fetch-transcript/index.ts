import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const VEXA_API_KEY = Deno.env.get("VEXA_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

serve(async (req) => {
  console.log("Fetch-transcript function called with Security Layer");

  // 1. JWT Verification (Security Hardening)
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(
      JSON.stringify({ error: 'Missing Authorization Header' }), 
      { status: 401, headers: { "Content-Type": "application/json" } }
    );
  }

  // Initialize Supabase Client
  const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!);
  const token = authHeader.replace('Bearer ', '');
  
  // Verify the user's token
  const { data: { user }, error: authError } = await supabase.auth.getUser(token);

  if (authError || !user) {
    console.error("Unauthorized attempt to access Edge Function");
    return new Response(
      JSON.stringify({ error: 'Invalid or expired token' }), 
      { status: 401, headers: { "Content-Type": "application/json" } }
    );
  }

  // 2. Request Method Validation
  if (req.method === "GET") {
    return new Response(
      JSON.stringify({ message: "This endpoint requires a POST request" }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }
  
  try {
    // 3. Environment Variable Check
    if (!VEXA_API_KEY || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return new Response(
        JSON.stringify({ error: "Server configuration missing (API Keys)" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }
    
    // 4. Parse Request Body
    let body;
    try {
      body = await req.json();
    } catch (e) {
      return new Response(
        JSON.stringify({ error: "Invalid JSON body" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }
    
    const { meeting_url, meeting_id } = body;
    
    if (!meeting_url || !meeting_id) {
      return new Response(
        JSON.stringify({ error: "Missing meeting_url or meeting_id" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }
  
    // 5. External API Logic (Vexa)
    const meetId = meeting_url.split('/').pop().split('?')[0];
    let transcript: string | null = null;

    try {
      console.log(`Fetching transcript for Meeting: ${meetId}`);
      const transcriptRes = await fetch(
        `https://gateway.dev.vexa.ai/transcripts/google_meet/${meetId}`,
        { headers: { "X-API-Key": VEXA_API_KEY } }
      );
      
      if (!transcriptRes.ok) {
        throw new Error(`Vexa API error: ${transcriptRes.status}`);
      }
      
      transcript = await transcriptRes.text();

      // Stop the bot session
      await fetch(
        `https://gateway.dev.vexa.ai/bots/google_meet/${meetId}`,
        { method: "DELETE", headers: { "X-API-Key": VEXA_API_KEY } }
      );

      // 6. Secure Database Update
      const { error: updateError } = await supabase
        .from('meetings')
        .update({ 
          transcription: transcript,
          transcription_attempted_at: new Date().toISOString(),
          transcription_error: null 
        })
        .eq('id', meeting_id);
      
      if (updateError) throw new Error(`DB update failed: ${updateError.message}`);
      
      return new Response(JSON.stringify({ 
        success: true, 
        message: "Transcript saved securely" 
      }), { headers: { "Content-Type": "application/json" } });

    } catch (error) {
      // Error handling with database logging
      await supabase
        .from('meetings')
        .update({
          transcription_attempted_at: new Date().toISOString(),
          transcription_error: error.message,
          ...(transcript && { transcription: transcript })
        })
        .eq('id', meeting_id);
        
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }
  } catch (error) {
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});