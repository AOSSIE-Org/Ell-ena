/**
 * Classify pull_request webhook payloads and extract closing issue references.
 * A reference counts only when the repository matches the configured repository.
 */

export type ClosingIssueRef = {
  repo: string;
  number: number;
};

export type PullRequestClassification =
  | { kind: "ignore"; reason: string }
  | {
    kind: "merged";
    repo: string;
    prUrl: string;
    mergedAt: string;
    issueNumbers: number[];
  }
  | { kind: "reject"; status: number; error: string };

const CLOSING_KEYWORD =
  /(?:^|[\s:(])(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+(?:https?:\/\/github\.com\/([\w.-]+)\/([\w.-]+)\/issues\/(\d+)|([\w.-]+)\/([\w.-]+)#(\d+)|#(\d+))/gi;

export function parseConfiguredRepo(raw: string | undefined | null): string | null {
  const value = (raw ?? "").trim();
  if (!value) return null;
  const parts = value.split("/").filter(Boolean);
  if (parts.length !== 2) return null;
  if (!/^[\w.-]+$/.test(parts[0]) || !/^[\w.-]+$/.test(parts[1])) return null;
  return `${parts[0]}/${parts[1]}`;
}

export function reposEqual(left: string, right: string): boolean {
  return left.trim().toLowerCase() === right.trim().toLowerCase();
}

/**
 * Extract issue numbers closed by a pull request body.
 * Bare `#123` belongs to `defaultRepo`. Qualified refs must name that same repository.
 */
export function extractClosingIssueNumbers(
  body: string | null | undefined,
  defaultRepo: string,
): number[] {
  if (!body) return [];
  const numbers = new Set<number>();
  const pattern = new RegExp(CLOSING_KEYWORD.source, "gi");
  let match: RegExpExecArray | null;
  while ((match = pattern.exec(body)) !== null) {
    const urlOwner = match[1];
    const urlName = match[2];
    const urlNumber = match[3];
    const qualOwner = match[4];
    const qualName = match[5];
    const qualNumber = match[6];
    const bareNumber = match[7];

    if (urlOwner && urlName && urlNumber) {
      if (reposEqual(`${urlOwner}/${urlName}`, defaultRepo)) {
        numbers.add(Number(urlNumber));
      }
      continue;
    }
    if (qualOwner && qualName && qualNumber) {
      if (reposEqual(`${qualOwner}/${qualName}`, defaultRepo)) {
        numbers.add(Number(qualNumber));
      }
      continue;
    }
    if (bareNumber) {
      numbers.add(Number(bareNumber));
    }
  }
  return [...numbers].filter((n) => Number.isInteger(n) && n > 0);
}

export function classifyPullRequestEvent(
  eventName: string | null,
  payload: Record<string, unknown>,
  expectedRepo: string,
): PullRequestClassification {
  if ((eventName ?? "").trim().toLowerCase() !== "pull_request") {
    return { kind: "ignore", reason: "unsupported_event" };
  }

  const action = typeof payload.action === "string" ? payload.action : "";
  const pullRequest = payload.pull_request;
  if (!pullRequest || typeof pullRequest !== "object") {
    return { kind: "reject", status: 400, error: "Missing pull_request object" };
  }
  const pr = pullRequest as Record<string, unknown>;

  if (action !== "closed" || pr.merged !== true) {
    return { kind: "ignore", reason: "not_merged" };
  }

  const repository = payload.repository;
  const fullName = repository && typeof repository === "object"
    ? (repository as Record<string, unknown>).full_name
    : null;
  if (typeof fullName !== "string" || !parseConfiguredRepo(fullName)) {
    return { kind: "reject", status: 400, error: "Missing repository" };
  }
  if (!reposEqual(fullName, expectedRepo)) {
    return { kind: "reject", status: 403, error: "Repository is not authorized" };
  }

  const htmlUrl = pr.html_url;
  if (typeof htmlUrl !== "string" || !isPullRequestUrl(htmlUrl, expectedRepo)) {
    return { kind: "reject", status: 400, error: "Invalid pull request URL" };
  }

  const mergedAt = pr.merged_at;
  if (typeof mergedAt !== "string" || Number.isNaN(Date.parse(mergedAt))) {
    return { kind: "reject", status: 400, error: "Missing merged timestamp" };
  }

  const body = typeof pr.body === "string" ? pr.body : "";
  const issueNumbers = extractClosingIssueNumbers(body, expectedRepo);

  return {
    kind: "merged",
    repo: expectedRepo,
    prUrl: htmlUrl,
    mergedAt: new Date(mergedAt).toISOString(),
    issueNumbers,
  };
}

function isPullRequestUrl(url: string, repo: string): boolean {
  try {
    const parsed = new URL(url);
    if (parsed.protocol !== "https:" || parsed.hostname !== "github.com") {
      return false;
    }
    const [owner, name, kind] = parsed.pathname.split("/").filter(Boolean);
    return reposEqual(`${owner}/${name}`, repo) && kind === "pull";
  } catch {
    return false;
  }
}
