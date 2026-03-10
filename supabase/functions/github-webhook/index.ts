import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request) => {
  try {
    if (req.headers.get("content-type") !== "application/json") {
        return new Response(
            JSON.stringify({ message: "Invalid content type" }),
            { status: 400 }
        );
    }

    const payload = await req.json();

    const action = payload?.action;
    const pr = payload?.pull_request;

    if (!action || !pr) {
      return new Response(
        JSON.stringify({ message: "Not a pull request event" }),
        { status: 200 }
      );
    }

    const issueUrl = pr?.issue_url;

    if (!issueUrl || typeof issueUrl !== "string") {
      return new Response(
        JSON.stringify({ message: "No issue URL found" }),
        { status: 200 }
      );
    }

    const issueNumberStr = issueUrl.split("/").pop();

    if (!issueNumberStr) {
      return new Response(
        JSON.stringify({ message: "Issue number not found" }),
        { status: 200 }
      );
    }

    const issueNumber = Number(issueNumberStr);

    if (Number.isNaN(issueNumber)) {
      return new Response(
        JSON.stringify({ message: "Invalid issue number" }),
        { status: 200 }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceKey) {
      return new Response(
        JSON.stringify({ error: "Supabase configuration missing" }),
        { status: 500 }
      );
    }

    const supabase = createClient(supabaseUrl, serviceKey);

    let newStatus: string | null = null;

    if (action === "opened") {
      newStatus = "in_progress";
    }

    if (action === "closed" && pr?.merged === true) {
      newStatus = "resolved";
    }

    if (!newStatus) {
      return new Response(
        JSON.stringify({ message: "Event ignored" }),
        { status: 200 }
      );
    }

    const { error } = await supabase
      .from("tickets")
      .update({ status: newStatus })
      .eq("github_issue_number", issueNumber);

    if (error) {
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500 }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        issue_number: issueNumber,
        updated_status: newStatus
      }),
      { headers: { "Content-Type": "application/json" } }
    );

  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500 }
    );
  }
});