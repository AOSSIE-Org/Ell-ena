import { sanitizeWebhookError, verifyGithubSignature } from "./signature.ts";
import { classifyPullRequestEvent, parseConfiguredRepo } from "./pull_request.ts";
import type { WebhookStore } from "./delivery.ts";

export type WebhookHandlerDeps = {
  secret: string | undefined;
  expectedRepo: string | undefined;
  /** Called only after the signature check succeeds. */
  openStore: () => WebhookStore;
};

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/**
 * Verify the GitHub signature before any delivery claim or task update.
 */
export async function handleGithubWebhook(
  req: Request,
  deps: WebhookHandlerDeps,
): Promise<Response> {
  if (req.method !== "POST") {
    return json(405, { error: "Method not allowed" });
  }

  const secret = deps.secret ?? "";
  if (!secret) {
    return json(500, { error: "GITHUB_WEBHOOK_SECRET is not configured" });
  }

  const expectedRepo = parseConfiguredRepo(deps.expectedRepo);
  if (!expectedRepo) {
    return json(500, { error: "GITHUB_REPO is not configured" });
  }

  const rawBody = await req.text();
  const signature = req.headers.get("X-Hub-Signature-256");
  const valid = await verifyGithubSignature(secret, rawBody, signature);
  if (!valid) {
    return json(401, {
      error: signature ? "Invalid signature" : "Missing signature",
    });
  }

  let payload: Record<string, unknown>;
  try {
    const parsed = JSON.parse(rawBody);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return json(400, { error: "Malformed JSON body" });
    }
    payload = parsed as Record<string, unknown>;
  } catch {
    return json(400, { error: "Malformed JSON body" });
  }

  const classified = classifyPullRequestEvent(
    req.headers.get("X-GitHub-Event"),
    payload,
    expectedRepo,
  );

  if (classified.kind === "ignore") {
    return json(200, { ignored: true, reason: classified.reason });
  }
  if (classified.kind === "reject") {
    return json(classified.status, { error: classified.error });
  }

  const deliveryId = req.headers.get("X-GitHub-Delivery")?.trim() ?? "";
  if (!deliveryId) {
    return json(400, { error: "Missing delivery id" });
  }

  let store: WebhookStore;
  try {
    store = deps.openStore();
  } catch {
    return json(500, { error: "Database credentials are not set" });
  }
  const claim = await store.claim(deliveryId);
  if (!claim.claimed || !claim.claimToken) {
    return json(200, {
      duplicate: claim.duplicate === true,
      concurrent: claim.concurrent === true,
      status: claim.status,
    });
  }

  try {
    const result = await store.complete({
      deliveryId,
      claimToken: claim.claimToken,
      repo: classified.repo,
      prUrl: classified.prUrl,
      completedAt: classified.mergedAt,
      issueNumbers: classified.issueNumbers,
    });
    if (result.applied === false) {
      return json(409, { error: "Delivery claim is no longer current" });
    }
    return json(200, result);
  } catch (error) {
    const message = sanitizeWebhookError(error, deps.secret);
    await store.fail(deliveryId, claim.claimToken, message);
    return json(500, { error: message });
  }
}
