import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { ClaimResult, WebhookStore } from "./delivery.ts";
import { handleGithubWebhook } from "./handler.ts";

/**
 * Deploy this function with JWT verification disabled. GitHub does not send a
 * Supabase user JWT. HMAC verification in handleGithubWebhook is required
 * before the service-role client is used.
 *
 * supabase functions deploy github-webhook --no-verify-jwt
 */

function supabaseStore(supabase: SupabaseClient): WebhookStore {
  return {
    async claim(deliveryId: string): Promise<ClaimResult> {
      const { data, error } = await supabase.rpc(
        "claim_github_webhook_delivery",
        { p_delivery_id: deliveryId, p_stale_seconds: 300 },
      );
      if (error) throw new Error("Failed to claim webhook delivery");
      const row = (data ?? {}) as Record<string, unknown>;
      return {
        claimed: row.claimed === true,
        status: row.status as ClaimResult["status"],
        claimToken: typeof row.claim_token === "string"
          ? row.claim_token
          : undefined,
        duplicate: row.duplicate === true,
        concurrent: row.concurrent === true,
        recovered: row.recovered === true,
      };
    },

    async complete(input) {
      const { data, error } = await supabase.rpc(
        "complete_github_webhook_delivery",
        {
          p_delivery_id: input.deliveryId,
          p_claim_token: input.claimToken,
          p_repo: input.repo,
          p_pr_url: input.prUrl,
          p_completed_at: input.completedAt,
          p_issue_numbers: input.issueNumbers,
        },
      );
      if (error) throw new Error("Failed to complete webhook delivery");
      return (data ?? {}) as Record<string, unknown>;
    },

    async fail(deliveryId, claimToken, message) {
      const { error } = await supabase.rpc("fail_github_webhook_delivery", {
        p_delivery_id: deliveryId,
        p_claim_token: claimToken,
        p_error: message,
      });
      if (error) {
        console.error("Failed to record webhook failure");
      }
    },
  };
}

serve((req) =>
  handleGithubWebhook(req, {
    secret: Deno.env.get("GITHUB_WEBHOOK_SECRET"),
    expectedRepo: Deno.env.get("GITHUB_REPO"),
    openStore: () => {
      const supabaseUrl = Deno.env.get("SUPABASE_URL");
      const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
      if (!supabaseUrl || !serviceRoleKey) {
        throw new Error("Database credentials are not set");
      }
      return supabaseStore(createClient(supabaseUrl, serviceRoleKey));
    },
  })
);
