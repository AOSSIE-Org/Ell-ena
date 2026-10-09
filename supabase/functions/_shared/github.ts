/**
 * Server-side GitHub REST API helpers for Supabase Edge Functions.
 *
 * Auth: GITHUB_TOKEN must come from Edge Function secrets / Deno.env.
 * Never embed tokens in client apps, migrations, or committed source.
 *
 * Idempotency note for issue creation:
 * If a create-issue request succeeds on GitHub but the HTTP response is lost
 * (timeout / network drop), a blind retry may create a duplicate issue.
 * Callers must treat ambiguous failures (timeouts, network errors after send)
 * carefully — e.g. check gh_issue_id on the ticket, and/or reconcile by
 * searching the repo before creating again. That reconciliation belongs in
 * the sync Edge Function, not in this transport layer.
 */

export type GitHubRepo = {
  owner: string;
  name: string;
};

export type GitHubIssue = {
  id: number;
  number: number;
  title: string;
  body: string | null;
  html_url: string;
  state: string;
};

export type CreateIssueInput = {
  title: string;
  body?: string;
  labels?: string[];
};

export type GitHubErrorKind =
  | "retryable"
  | "permanent"
  | "timeout"
  | "rate_limit"
  | "network"
  | "http";

export class GitHubApiError extends Error {
  readonly kind: GitHubErrorKind;
  readonly status?: number;
  readonly retryAfterMs?: number;
  readonly body?: string;
  readonly retryable: boolean;

  constructor(
    message: string,
    options: {
      kind: GitHubErrorKind;
      status?: number;
      retryAfterMs?: number;
      body?: string;
      retryable?: boolean;
      cause?: unknown;
    },
  ) {
    super(message, options.cause !== undefined ? { cause: options.cause } : undefined);
    this.name = "GitHubApiError";
    this.kind = options.kind;
    this.status = options.status;
    this.retryAfterMs = options.retryAfterMs;
    this.body = options.body;
    this.retryable = options.retryable ??
      (options.kind === "retryable" ||
        options.kind === "timeout" ||
        options.kind === "rate_limit" ||
        options.kind === "network");
  }
}

export type RetryOptions = {
  /** Maximum attempts including the first try. Default 3. */
  maxAttempts?: number;
  /** Base delay in ms for exponential backoff. Default 500. */
  baseDelayMs?: number;
  /** Cap for backoff delay in ms. Default 8000. */
  maxDelayMs?: number;
  /** Injected sleep for tests. */
  sleep?: (ms: number) => Promise<void>;
  /** Injected clock for tests. */
  now?: () => number;
};

export type GitHubClientOptions = {
  token: string;
  baseUrl?: string;
  userAgent?: string;
  fetch?: typeof fetch;
  retry?: RetryOptions;
};

const DEFAULT_BASE_URL = "https://api.github.com";
const DEFAULT_USER_AGENT = "Ell-ena-GitHub-Integration";

function defaultSleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Exponential backoff: base * 2^(attemptIndex), capped at maxDelayMs.
 * attemptIndex is 0-based after the first failed attempt.
 */
export function computeBackoffDelayMs(
  attemptIndex: number,
  baseDelayMs: number,
  maxDelayMs: number,
): number {
  const delay = baseDelayMs * Math.pow(2, attemptIndex);
  return Math.min(delay, maxDelayMs);
}

/**
 * Prefer Retry-After (seconds or HTTP-date), then X-RateLimit-Reset (epoch seconds).
 */
export function parseRateLimitDelayMs(
  headers: Headers,
  nowMs: number = Date.now(),
): number | undefined {
  const retryAfter = headers.get("Retry-After");
  if (retryAfter) {
    const asSeconds = Number(retryAfter);
    if (!Number.isNaN(asSeconds)) {
      return Math.max(0, asSeconds * 1000);
    }
    const asDate = Date.parse(retryAfter);
    if (!Number.isNaN(asDate)) {
      return Math.max(0, asDate - nowMs);
    }
  }

  const reset = headers.get("X-RateLimit-Reset");
  if (reset) {
    const resetEpochSec = Number(reset);
    if (!Number.isNaN(resetEpochSec)) {
      return Math.max(0, resetEpochSec * 1000 - nowMs);
    }
  }

  return undefined;
}

export function isRetryableStatus(status: number): boolean {
  return status === 429 || status === 502 || status === 503 || status === 504;
}

export function classifyHttpFailure(
  status: number,
  headers: Headers,
  bodyText: string,
): GitHubApiError {
  if (status === 429) {
    return new GitHubApiError(
      `GitHub rate limited (HTTP ${status})`,
      {
        kind: "rate_limit",
        status,
        body: bodyText,
        retryAfterMs: parseRateLimitDelayMs(headers),
        retryable: true,
      },
    );
  }

  if (isRetryableStatus(status)) {
    return new GitHubApiError(
      `GitHub transient error (HTTP ${status})`,
      {
        kind: "retryable",
        status,
        body: bodyText,
        retryAfterMs: parseRateLimitDelayMs(headers),
        retryable: true,
      },
    );
  }

  // Secondary rate limit sometimes returns 403 with a retry-after style header.
  if (
    status === 403 &&
    (bodyText.toLowerCase().includes("rate limit") ||
      headers.has("Retry-After") ||
      headers.get("X-RateLimit-Remaining") === "0")
  ) {
    return new GitHubApiError(
      `GitHub secondary rate limit or quota exhausted (HTTP ${status})`,
      {
        kind: "rate_limit",
        status,
        body: bodyText,
        retryAfterMs: parseRateLimitDelayMs(headers),
        retryable: true,
      },
    );
  }

  return new GitHubApiError(
    `GitHub API error (HTTP ${status})`,
    {
      kind: status >= 500 ? "http" : "permanent",
      status,
      body: bodyText,
      retryable: false,
    },
  );
}

export async function withRetry<T>(
  operation: () => Promise<T>,
  options: RetryOptions = {},
): Promise<T> {
  const maxAttempts = options.maxAttempts ?? 3;
  const baseDelayMs = options.baseDelayMs ?? 500;
  const maxDelayMs = options.maxDelayMs ?? 8000;
  const sleep = options.sleep ?? defaultSleep;

  let lastError: unknown;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;
      const apiError = error instanceof GitHubApiError
        ? error
        : new GitHubApiError(
          error instanceof Error ? error.message : "Unknown GitHub request failure",
          { kind: "network", retryable: true, cause: error },
        );

      const attemptsLeft = attempt < maxAttempts;
      if (!apiError.retryable || !attemptsLeft) {
        throw apiError;
      }

      const backoff = computeBackoffDelayMs(
        attempt - 1,
        baseDelayMs,
        maxDelayMs,
      );
      const delayMs = Math.max(backoff, apiError.retryAfterMs ?? 0);
      await sleep(delayMs);
    }
  }

  throw lastError instanceof GitHubApiError
    ? lastError
    : new GitHubApiError("GitHub request failed after retries", {
      kind: "retryable",
      cause: lastError,
    });
}

function parseRepo(repo: string | GitHubRepo): GitHubRepo {
  if (typeof repo !== "string") return repo;
  const trimmed = repo.trim().replace(/^https?:\/\/github\.com\//i, "");
  const [owner, name] = trimmed.split("/").filter(Boolean);
  if (!owner || !name) {
    throw new GitHubApiError(
      `Invalid repository "${repo}". Expected "owner/name".`,
      { kind: "permanent", retryable: false },
    );
  }
  return { owner, name };
}

export class GitHubClient {
  private readonly token: string;
  private readonly baseUrl: string;
  private readonly userAgent: string;
  private readonly fetchImpl: typeof fetch;
  private readonly retryOptions: RetryOptions;

  constructor(options: GitHubClientOptions) {
    if (!options.token?.trim()) {
      throw new GitHubApiError("GITHUB_TOKEN is not configured", {
        kind: "permanent",
        retryable: false,
      });
    }
    this.token = options.token;
    this.baseUrl = (options.baseUrl ?? DEFAULT_BASE_URL).replace(/\/$/, "");
    this.userAgent = options.userAgent ?? DEFAULT_USER_AGENT;
    this.fetchImpl = options.fetch ?? fetch;
    this.retryOptions = options.retry ?? {};
  }

  /**
   * Create a GitHubClient from Deno.env.
   * Expects GITHUB_TOKEN (required). Optional GITHUB_API_BASE_URL for tests/proxies.
   */
  static fromEnv(
    env: { get(key: string): string | undefined } = Deno.env,
    overrides: Omit<GitHubClientOptions, "token"> = {},
  ): GitHubClient {
    const token = env.get("GITHUB_TOKEN") ?? "";
    return new GitHubClient({
      token,
      baseUrl: env.get("GITHUB_API_BASE_URL") ?? overrides.baseUrl,
      ...overrides,
    });
  }

  async createIssue(
    repo: string | GitHubRepo,
    input: CreateIssueInput,
  ): Promise<GitHubIssue> {
    const { owner, name } = parseRepo(repo);
    return await this.requestJson<GitHubIssue>(
      "POST",
      `/repos/${owner}/${name}/issues`,
      {
        title: input.title,
        body: input.body ?? undefined,
        labels: input.labels,
      },
    );
  }

  async getIssue(
    repo: string | GitHubRepo,
    issueNumber: number,
  ): Promise<GitHubIssue> {
    const { owner, name } = parseRepo(repo);
    return await this.requestJson<GitHubIssue>(
      "GET",
      `/repos/${owner}/${name}/issues/${issueNumber}`,
    );
  }

  private async requestJson<T>(
    method: string,
    path: string,
    body?: unknown,
  ): Promise<T> {
    return await withRetry(async () => {
      let response: Response;
      try {
        response = await this.fetchImpl(`${this.baseUrl}${path}`, {
          method,
          headers: {
            Accept: "application/vnd.github+json",
            Authorization: `Bearer ${this.token}`,
            "Content-Type": "application/json",
            "User-Agent": this.userAgent,
            "X-GitHub-Api-Version": "2022-11-28",
          },
          body: body === undefined ? undefined : JSON.stringify(body),
        });
      } catch (error) {
        const message = error instanceof Error
          ? error.message
          : "Network error talking to GitHub";
        const isTimeout = /timeout|aborted|AbortError/i.test(message);
        throw new GitHubApiError(message, {
          kind: isTimeout ? "timeout" : "network",
          retryable: true,
          cause: error,
        });
      }

      const text = await response.text();
      if (!response.ok) {
        throw classifyHttpFailure(response.status, response.headers, text);
      }

      if (!text) {
        return {} as T;
      }

      try {
        return JSON.parse(text) as T;
      } catch (error) {
        throw new GitHubApiError("GitHub returned invalid JSON", {
          kind: "http",
          status: response.status,
          body: text.slice(0, 500),
          retryable: false,
          cause: error,
        });
      }
    }, this.retryOptions);
  }
}
