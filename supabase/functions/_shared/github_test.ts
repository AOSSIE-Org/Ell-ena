import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  classifyHttpFailure,
  computeBackoffDelayMs,
  GitHubApiError,
  GitHubClient,
  parseRateLimitDelayMs,
  withRetry,
} from "./github.ts";

function jsonResponse(
  status: number,
  body: unknown,
  headers: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...headers,
    },
  });
}

Deno.test("computeBackoffDelayMs grows exponentially and caps", () => {
  assertEquals(computeBackoffDelayMs(0, 500, 8000), 500);
  assertEquals(computeBackoffDelayMs(1, 500, 8000), 1000);
  assertEquals(computeBackoffDelayMs(2, 500, 8000), 2000);
  assertEquals(computeBackoffDelayMs(10, 500, 8000), 8000);
});

Deno.test("parseRateLimitDelayMs prefers Retry-After seconds", () => {
  const headers = new Headers({ "Retry-After": "2" });
  assertEquals(parseRateLimitDelayMs(headers, 0), 2000);
});

Deno.test("parseRateLimitDelayMs uses X-RateLimit-Reset epoch", () => {
  const now = 1_000_000;
  const headers = new Headers({
    "X-RateLimit-Reset": String(Math.floor((now + 3500) / 1000)),
  });
  const delay = parseRateLimitDelayMs(headers, now);
  assertEquals(delay !== undefined && delay >= 3000 && delay <= 4000, true);
});

Deno.test("classifyHttpFailure marks 429 as rate_limit/retryable", () => {
  const error = classifyHttpFailure(
    429,
    new Headers({ "Retry-After": "1" }),
    "rate limit",
  );
  assertEquals(error.kind, "rate_limit");
  assertEquals(error.retryable, true);
  assertEquals(error.retryAfterMs, 1000);
});

Deno.test("classifyHttpFailure marks 404 as permanent", () => {
  const error = classifyHttpFailure(404, new Headers(), "Not Found");
  assertEquals(error.kind, "permanent");
  assertEquals(error.retryable, false);
});

Deno.test("withRetry succeeds after temporary failure", async () => {
  let attempts = 0;
  const sleeps: number[] = [];

  const result = await withRetry(
    async () => {
      attempts += 1;
      if (attempts === 1) {
        throw new GitHubApiError("temporary", {
          kind: "retryable",
          status: 503,
          retryable: true,
        });
      }
      return "ok";
    },
    {
      maxAttempts: 3,
      baseDelayMs: 10,
      maxDelayMs: 100,
      sleep: async (ms) => {
        sleeps.push(ms);
      },
    },
  );

  assertEquals(result, "ok");
  assertEquals(attempts, 2);
  assertEquals(sleeps.length, 1);
  assertEquals(sleeps[0], 10);
});

Deno.test("withRetry stops after maxAttempts on temporary errors", async () => {
  let attempts = 0;

  await assertRejects(
    () =>
      withRetry(
        async () => {
          attempts += 1;
          throw new GitHubApiError("still down", {
            kind: "retryable",
            status: 502,
            retryable: true,
          });
        },
        {
          maxAttempts: 3,
          baseDelayMs: 1,
          sleep: async () => {},
        },
      ),
    GitHubApiError,
  );

  assertEquals(attempts, 3);
});

Deno.test("withRetry does not retry permanent errors", async () => {
  let attempts = 0;

  await assertRejects(
    () =>
      withRetry(
        async () => {
          attempts += 1;
          throw new GitHubApiError("bad credentials", {
            kind: "permanent",
            status: 401,
            retryable: false,
          });
        },
        {
          maxAttempts: 5,
          sleep: async () => {
            throw new Error("should not sleep");
          },
        },
      ),
    GitHubApiError,
  );

  assertEquals(attempts, 1);
});

Deno.test("withRetry respects Retry-After over base backoff", async () => {
  const sleeps: number[] = [];
  let attempts = 0;

  await withRetry(
    async () => {
      attempts += 1;
      if (attempts === 1) {
        throw new GitHubApiError("slow down", {
          kind: "rate_limit",
          status: 429,
          retryAfterMs: 2500,
          retryable: true,
        });
      }
      return true;
    },
    {
      maxAttempts: 3,
      baseDelayMs: 100,
      maxDelayMs: 10_000,
      sleep: async (ms) => {
        sleeps.push(ms);
      },
    },
  );

  assertEquals(sleeps[0], 2500);
});

Deno.test("GitHubClient.createIssue succeeds on HTTP 201", async () => {
  const client = new GitHubClient({
    token: "test-token",
    fetch: async () =>
      jsonResponse(201, {
        id: 99,
        number: 42,
        title: "Auth bug",
        body: "details",
        html_url: "https://github.com/acme/app/issues/42",
        state: "open",
      }),
    retry: { maxAttempts: 1 },
  });

  const issue = await client.createIssue("acme/app", {
    title: "Auth bug",
    body: "details",
  });

  assertEquals(issue.number, 42);
  assertEquals(issue.html_url, "https://github.com/acme/app/issues/42");
});

Deno.test("GitHubClient.getIssue maps permanent 404 without retry loop", async () => {
  let attempts = 0;
  const client = new GitHubClient({
    token: "test-token",
    fetch: async () => {
      attempts += 1;
      return jsonResponse(404, { message: "Not Found" });
    },
    retry: {
      maxAttempts: 4,
      sleep: async () => {
        throw new Error("should not retry permanent failures");
      },
    },
  });

  await assertRejects(
    () => client.getIssue("acme/app", 999),
    GitHubApiError,
  );
  assertEquals(attempts, 1);
});

Deno.test("GitHubClient retries 503 then succeeds", async () => {
  let attempts = 0;
  const client = new GitHubClient({
    token: "test-token",
    fetch: async () => {
      attempts += 1;
      if (attempts === 1) {
        return jsonResponse(503, { message: "unavailable" });
      }
      return jsonResponse(200, {
        id: 1,
        number: 7,
        title: "Recovered",
        body: null,
        html_url: "https://github.com/acme/app/issues/7",
        state: "open",
      });
    },
    retry: {
      maxAttempts: 3,
      baseDelayMs: 1,
      sleep: async () => {},
    },
  });

  const issue = await client.getIssue("acme/app", 7);
  assertEquals(issue.number, 7);
  assertEquals(attempts, 2);
});

Deno.test("GitHubClient.fromEnv requires token", () => {
  try {
    GitHubClient.fromEnv({ get: () => undefined });
    throw new Error("expected throw");
  } catch (error) {
    assertEquals(error instanceof GitHubApiError, true);
    assertEquals((error as GitHubApiError).kind, "permanent");
  }
});
