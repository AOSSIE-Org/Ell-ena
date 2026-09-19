import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflight } from "../_shared/cors.ts";
import { GitHubApiError, GitHubClient } from "../_shared/github.ts";
import {
  parseConfiguredRepo,
  syncTicketToGithub,
  type TicketRow,
  type TicketStore,
} from "./sync_ticket.ts";

function jsonResponse(
  status: number,
  body: Record<string, unknown>,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function createTicketStore(supabase: SupabaseClient): TicketStore {
  return {
    async getTicket(ticketId: string): Promise<TicketRow | null> {
      const { data, error } = await supabase
        .from("tickets")
        .select(
          "id, ticket_number, title, description, priority, category, sync_to_github, github_sync_status, github_sync_error, gh_issue_id, gh_issue_url, gh_repo",
        )
        .eq("id", ticketId)
        .maybeSingle();

      if (error) {
        console.error("Failed to load ticket:", error.message);
        throw new Error("Failed to load ticket");
      }
      return data as TicketRow | null;
    },

    async updateTicket(
      ticketId: string,
      patch: Record<string, unknown>,
    ): Promise<void> {
      const { error } = await supabase
        .from("tickets")
        .update(patch)
        .eq("id", ticketId);

      if (error) {
        console.error("Failed to update ticket:", error.message);
        throw new Error("Failed to update ticket");
      }
    },
  };
}

serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  if (req.method === "GET") {
    return jsonResponse(400, {
      error: "This endpoint requires a POST request with { ticket_id }",
    });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed" });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse(500, { error: "Database credentials are not set" });
    }

    let repo: string;
    try {
      repo = parseConfiguredRepo(Deno.env.get("GITHUB_REPO"));
    } catch (error) {
      const message = error instanceof Error
        ? error.message
        : "GITHUB_REPO is not configured";
      return jsonResponse(500, { error: message });
    }

    let github: GitHubClient;
    try {
      github = GitHubClient.fromEnv();
    } catch (error) {
      const message = error instanceof GitHubApiError
        ? error.message
        : "GITHUB_TOKEN is not configured";
      return jsonResponse(500, { error: message });
    }

    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return jsonResponse(400, { error: "Invalid JSON body" });
    }

    const ticketId = typeof body.ticket_id === "string"
      ? body.ticket_id
      : "";

    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const result = await syncTicketToGithub(ticketId, {
      tickets: createTicketStore(supabase),
      github,
      repo,
    });

    // Never echo secrets — response body is already sanitized in sync logic.
    return jsonResponse(result.status, result.body);
  } catch (error) {
    console.error("github-sync unhandled error:", error);
    return jsonResponse(500, {
      error: "GitHub synchronization failed",
    });
  }
});
