import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { WebhookDeliveryStore } from "./delivery.ts";
import { handleGithubWebhook } from "./handler.ts";
import { extractClosingIssueNumbers } from "./pull_request.ts";
import { githubSignatureHex, sanitizeWebhookError } from "./signature.ts";

const SECRET = "test-webhook-secret";
const REPO = "acme/app";

function mergedPayload(body: string, overrides: Record<string, unknown> = {}) {
  return {
    action: "closed",
    repository: { full_name: REPO },
    pull_request: {
      merged: true,
      merged_at: "2026-09-28T12:00:00Z",
      html_url: "https://github.com/acme/app/pull/15",
      body,
    },
    ...overrides,
  };
}

async function signedRequest(
  payload: unknown,
  init: {
    method?: string;
    event?: string;
    delivery?: string;
    secret?: string;
    raw?: string;
    signature?: string | null;
  } = {},
): Promise<Request> {
  const raw = init.raw ?? JSON.stringify(payload);
  const secret = init.secret ?? SECRET;
  let signature = init.signature;
  if (signature === undefined) {
    signature = `sha256=${await githubSignatureHex(secret, raw)}`;
  }
  const headers = new Headers({
    "Content-Type": "application/json",
    "X-GitHub-Event": init.event ?? "pull_request",
    "X-GitHub-Delivery": init.delivery ?? crypto.randomUUID(),
  });
  if (signature !== null) headers.set("X-Hub-Signature-256", signature);
  return new Request("https://example.test/github-webhook", {
    method: init.method ?? "POST",
    headers,
    body: init.method === "GET" ? undefined : raw,
  });
}

function harness(store = new WebhookDeliveryStore()) {
  return {
    store,
    handle: (req: Request) =>
      handleGithubWebhook(req, {
        secret: SECRET,
        expectedRepo: REPO,
        openStore: () => store,
      }),
  };
}

Deno.test("valid HMAC signature accepts a merged pull request", async () => {
  const { store, handle } = harness();
  store.tickets.push({ id: "t1", ghRepo: REPO, ghIssueId: 123 });
  store.tasks.push({
    id: "task-1",
    ticketId: "t1",
    status: "todo",
    ghPrUrl: null,
    completedAt: null,
  });
  const response = await handle(await signedRequest(mergedPayload("Fixes #123"), {
    delivery: "delivery-valid",
  }));
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(body.tasks_completed, 1);
  assertEquals(store.tasks[0].status, "completed");
  assertEquals(store.tasks[0].ghPrUrl, "https://github.com/acme/app/pull/15");
  assertEquals(store.tasks[0].completedAt, "2026-09-28T12:00:00.000Z");
  assertEquals(store.deliveries.get("delivery-valid")?.status, "completed");
});

Deno.test("missing signature is rejected", async () => {
  const { handle } = harness();
  const response = await handle(await signedRequest(mergedPayload("Fixes #1"), {
    signature: null,
  }));
  assertEquals(response.status, 401);
  assertEquals((await response.json()).error, "Missing signature");
});

Deno.test("invalid signature is rejected", async () => {
  const { handle } = harness();
  const response = await handle(await signedRequest(mergedPayload("Fixes #1"), {
    signature: `sha256=${"ab".repeat(32)}`,
  }));
  assertEquals(response.status, 401);
  assertEquals((await response.json()).error, "Invalid signature");
});

Deno.test("modified request body fails verification", async () => {
  const payload = mergedPayload("Fixes #1");
  const raw = JSON.stringify(payload);
  const signature = `sha256=${await githubSignatureHex(SECRET, raw)}`;
  const { store, handle } = harness();
  const response = await handle(await signedRequest(payload, {
    raw: raw.replace("Fixes #1", "Fixes #2"),
    signature,
  }));
  assertEquals(response.status, 401);
  assertEquals(store.tasks.length, 0);
});

Deno.test("missing webhook secret is rejected before processing", async () => {
  const store = new WebhookDeliveryStore();
  const response = await handleGithubWebhook(
    await signedRequest(mergedPayload("Fixes #1")),
    { secret: "", expectedRepo: REPO, openStore: () => store },
  );
  assertEquals(response.status, 500);
  assertEquals((await response.json()).error, "GITHUB_WEBHOOK_SECRET is not configured");
  assertEquals(store.deliveries.size, 0);
});

Deno.test("unsupported HTTP method is rejected", async () => {
  const { handle } = harness();
  const response = await handle(await signedRequest(mergedPayload("Fixes #1"), {
    method: "GET",
  }));
  assertEquals(response.status, 405);
});

Deno.test("malformed JSON is rejected", async () => {
  const raw = "{not-json";
  const { handle } = harness();
  const response = await handle(await signedRequest({}, {
    raw,
    signature: `sha256=${await githubSignatureHex(SECRET, raw)}`,
  }));
  assertEquals(response.status, 400);
  assertEquals((await response.json()).error, "Malformed JSON body");
});

Deno.test("unrelated GitHub event is ignored", async () => {
  const { store, handle } = harness();
  const response = await handle(await signedRequest(
    { action: "opened", zen: "keep it logically awesome" },
    { event: "ping", delivery: "ping-1" },
  ));
  assertEquals(response.status, 200);
  assertEquals((await response.json()).ignored, true);
  assertEquals(store.deliveries.size, 0);
});

Deno.test("pull request closed without merging is ignored", async () => {
  const { store, handle } = harness();
  const response = await handle(await signedRequest({
    action: "closed",
    repository: { full_name: REPO },
    pull_request: { merged: false, body: "Fixes #123" },
  }, { delivery: "closed-1" }));
  assertEquals(response.status, 200);
  assertEquals((await response.json()).reason, "not_merged");
  assertEquals(store.deliveries.size, 0);
});

Deno.test("single and multiple issue references are extracted", () => {
  assertEquals(extractClosingIssueNumbers("Closes #123", REPO), [123]);
  assertEquals(
    extractClosingIssueNumbers("Fixes #8\nResolves #9", REPO).sort((a, b) => a - b),
    [8, 9],
  );
  assertEquals(
    extractClosingIssueNumbers("Fixes acme/app#5 and Closes other/repo#4", REPO),
    [5],
  );
});

Deno.test("multiple issue references complete each linked task", async () => {
  const { store, handle } = harness();
  store.tickets.push(
    { id: "t1", ghRepo: REPO, ghIssueId: 8 },
    { id: "t2", ghRepo: REPO, ghIssueId: 9 },
  );
  store.tasks.push(
    { id: "a", ticketId: "t1", status: "in_progress", ghPrUrl: null, completedAt: null },
    { id: "b", ticketId: "t2", status: "todo", ghPrUrl: null, completedAt: null },
  );
  const response = await handle(await signedRequest(
    mergedPayload("Fixes #8 and Resolves #9"),
    { delivery: "multi-1" },
  ));
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(body.tickets_matched, 2);
  assertEquals(body.tasks_completed, 2);
});

Deno.test("unauthorized repository does not complete tasks", async () => {
  const { store, handle } = harness();
  store.tickets.push({ id: "t1", ghRepo: "other/repo", ghIssueId: 3 });
  store.tasks.push({
    id: "a",
    ticketId: "t1",
    status: "todo",
    ghPrUrl: null,
    completedAt: null,
  });
  const response = await handle(await signedRequest({
    action: "closed",
    repository: { full_name: "other/repo" },
    pull_request: {
      merged: true,
      merged_at: "2026-09-28T12:00:00Z",
      html_url: "https://github.com/other/repo/pull/3",
      body: "Fixes #3",
    },
  }, { delivery: "bad-repo" }));
  assertEquals(response.status, 403);
  assertEquals(store.tasks[0].status, "todo");
  assertEquals(store.deliveries.size, 0);
});

Deno.test("missing matching ticket completes the delivery without task changes", async () => {
  const { store, handle } = harness();
  const response = await handle(await signedRequest(mergedPayload("Fixes #404"), {
    delivery: "no-ticket",
  }));
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(body.tickets_matched, 0);
  assertEquals(body.tasks_completed, 0);
  assertEquals(store.deliveries.get("no-ticket")?.status, "completed");
});

Deno.test("ticket without linked tasks is a successful no-op", async () => {
  const { store, handle } = harness();
  store.tickets.push({ id: "t1", ghRepo: REPO, ghIssueId: 123 });
  const response = await handle(await signedRequest(mergedPayload("Closes #123"), {
    delivery: "no-task",
  }));
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(body.tickets_matched, 1);
  assertEquals(body.tasks_completed, 0);
});

Deno.test("already completed tasks keep their completion metadata", async () => {
  const { store, handle } = harness();
  store.tickets.push({ id: "t1", ghRepo: REPO, ghIssueId: 123 });
  store.tasks.push({
    id: "done",
    ticketId: "t1",
    status: "completed",
    ghPrUrl: "https://github.com/acme/app/pull/1",
    completedAt: "2026-01-01T00:00:00.000Z",
  });
  const response = await handle(await signedRequest(mergedPayload("Fixes #123"), {
    delivery: "already",
  }));
  const body = await response.json();
  assertEquals(body.tasks_completed, 0);
  assertEquals(body.tasks_already_completed, 1);
  assertEquals(store.tasks[0].ghPrUrl, "https://github.com/acme/app/pull/1");
  assertEquals(store.tasks[0].completedAt, "2026-01-01T00:00:00.000Z");
});

Deno.test("duplicate delivery does not repeat task updates", async () => {
  const { store, handle } = harness();
  store.tickets.push({ id: "t1", ghRepo: REPO, ghIssueId: 123 });
  store.tasks.push({
    id: "a",
    ticketId: "t1",
    status: "todo",
    ghPrUrl: null,
    completedAt: null,
  });
  const first = await handle(await signedRequest(mergedPayload("Fixes #123"), {
    delivery: "dup-1",
  }));
  assertEquals(first.status, 200);
  store.tasks[0].status = "todo";
  const second = await handle(await signedRequest(mergedPayload("Fixes #123"), {
    delivery: "dup-1",
  }));
  const body = await second.json();
  assertEquals(second.status, 200);
  assertEquals(body.duplicate, true);
  assertEquals(store.tasks[0].status, "todo");
});

Deno.test("concurrent claims allow only one processor", async () => {
  const store = new WebhookDeliveryStore();
  const [first, second] = await Promise.all([
    store.claim("concurrent-1"),
    store.claim("concurrent-1"),
  ]);
  const claimed = [first, second].filter((result) => result.claimed);
  assertEquals(claimed.length, 1);
  assertEquals([first, second].some((result) => result.concurrent), true);
});

Deno.test("database failure marks the delivery failed and a retry can recover", async () => {
  const { store, handle } = harness();
  store.tickets.push({ id: "t1", ghRepo: REPO, ghIssueId: 123 });
  store.tasks.push({
    id: "a",
    ticketId: "t1",
    status: "todo",
    ghPrUrl: null,
    completedAt: null,
  });
  store.failNextComplete = true;
  const failed = await handle(await signedRequest(mergedPayload("Fixes #123"), {
    delivery: "retry-1",
  }));
  assertEquals(failed.status, 500);
  assertEquals(store.deliveries.get("retry-1")?.status, "failed");
  assertEquals(store.tasks[0].status, "todo");

  const recovered = await handle(await signedRequest(mergedPayload("Fixes #123"), {
    delivery: "retry-1",
  }));
  assertEquals(recovered.status, 200);
  assertEquals(store.tasks[0].status, "completed");
  assertEquals(store.deliveries.get("retry-1")?.status, "completed");
});

Deno.test("stale processing claim can be taken over", async () => {
  let now = new Date("2026-09-28T12:00:00.000Z");
  const store = new WebhookDeliveryStore(() => now, 1_000);
  const first = await store.claim("stale-1");
  assertEquals(first.claimed, true);
  now = new Date("2026-09-28T12:00:05.000Z");
  const second = await store.claim("stale-1");
  assertEquals(second.claimed, true);
  assertEquals(second.recovered, true);
  const late = await store.complete({
    deliveryId: "stale-1",
    claimToken: first.claimToken!,
    repo: REPO,
    prUrl: "https://github.com/acme/app/pull/15",
    completedAt: "2026-09-28T12:00:00.000Z",
    issueNumbers: [123],
  });
  assertEquals(late.applied, false);
  assertEquals(store.deliveries.get("stale-1")?.status, "processing");
});

Deno.test("responses do not leak the webhook secret", async () => {
  const store = new WebhookDeliveryStore();
  store.failNextComplete = true;
  store.tickets.push({ id: "t1", ghRepo: REPO, ghIssueId: 1 });
  const response = await handleGithubWebhook(
    await signedRequest(mergedPayload("Fixes #1"), { delivery: "leak" }),
    {
      secret: SECRET,
      expectedRepo: REPO,
      openStore: () => store,
    },
  );
  const text = await response.text();
  assertEquals(text.includes(SECRET), false);
  const redacted = sanitizeWebhookError(
    new Error(`GITHUB_WEBHOOK_SECRET=${SECRET} Bearer abc`),
    SECRET,
  );
  assertEquals(redacted.includes(SECRET), false);
  assertStringIncludes(redacted, "[redacted]");
});
