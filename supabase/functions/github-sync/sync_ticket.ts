/**
 * Core ticket → GitHub issue synchronization (Week 17).
 *
 * Ambiguous create failures (timeout / network after the request may have
 * reached GitHub) are recorded as failed with an [ambiguous_create] marker.
 * Subsequent sync attempts will NOT create another issue until gh_issue_id is
 * set manually or the marker is cleared — we do not invent unreliable
 * title-search reconciliation here.
 */

import {
  GitHubApiError,
  GitHubClient,
  type GitHubIssue,
} from "../_shared/github.ts";

export const AMBIGUOUS_CREATE_MARKER = "[ambiguous_create]";

export type TicketRow = {
  id: string;
  ticket_number: string | null;
  title: string;
  description: string | null;
  priority: string | null;
  category: string | null;
  sync_to_github: boolean;
  github_sync_status: string;
  github_sync_error: string | null;
  gh_issue_id: number | null;
  gh_issue_url: string | null;
  gh_repo: string | null;
};

export type SyncTicketResult = {
  ok: boolean;
  status: number;
  body: Record<string, unknown>;
};

export type TicketStore = {
  getTicket(ticketId: string): Promise<TicketRow | null>;
  updateTicket(
    ticketId: string,
    patch: Record<string, unknown>,
  ): Promise<void>;
};

export type SyncTicketDeps = {
  tickets: TicketStore;
  github: Pick<GitHubClient, "createIssue">;
  repo: string;
};

/** Validate GITHUB_REPO as owner/name (no URL, no extra segments). */
export function parseConfiguredRepo(raw: string | undefined | null): string {
  const value = (raw ?? "").trim();
  if (!value) {
    throw new GitHubApiError(
      "GITHUB_REPO is not configured. Expected owner/repository.",
      { kind: "permanent", retryable: false },
    );
  }

  const cleaned = value
    .replace(/^https?:\/\/github\.com\//i, "")
    .replace(/\.git$/i, "")
    .replace(/\/$/, "");

  const parts = cleaned.split("/").filter(Boolean);
  if (parts.length !== 2) {
    throw new GitHubApiError(
      `GITHUB_REPO is invalid ("${value}"). Expected owner/repository.`,
      { kind: "permanent", retryable: false },
    );
  }

  const [owner, name] = parts;
  if (!/^[\w.-]+$/.test(owner) || !/^[\w.-]+$/.test(name)) {
    throw new GitHubApiError(
      `GITHUB_REPO is invalid ("${value}"). Expected owner/repository.`,
      { kind: "permanent", retryable: false },
    );
  }

  return `${owner}/${name}`;
}

export function buildIssueBody(ticket: TicketRow): string {
  const ticketNumber = ticket.ticket_number?.trim() || "unknown";
  const priority = ticket.priority?.trim() || "unspecified";
  const category = ticket.category?.trim() || "unspecified";
  const description = ticket.description?.trim() ||
    "_No description provided._";

  return [
    `## Ell-ena Ticket`,
    ``,
    `**Ticket:** ${ticketNumber}`,
    `**Priority:** ${priority}`,
    `**Category:** ${category}`,
    ``,
    `### Description`,
    ``,
    description,
  ].join("\n");
}

/** Strip secrets and truncate for safe storage / client responses. */
export function sanitizeSyncError(error: unknown): string {
  let message = error instanceof Error
    ? error.message
    : typeof error === "string"
    ? error
    : "GitHub synchronization failed";

  message = message
    .replace(/ghp_[A-Za-z0-9_]+/g, "[redacted]")
    .replace(/github_pat_[A-Za-z0-9_]+/g, "[redacted]")
    .replace(/Bearer\s+[A-Za-z0-9._\-]+/gi, "Bearer [redacted]")
    .replace(/GITHUB_TOKEN[=:]\s*\S+/gi, "GITHUB_TOKEN=[redacted]");

  // Drop raw GitHub response bodies that may contain tokens or private data.
  if (error instanceof GitHubApiError && error.body) {
    // Prefer the high-level message only.
  }

  const maxLen = 500;
  if (message.length > maxLen) {
    message = `${message.slice(0, maxLen)}…`;
  }
  return message;
}

function isAmbiguousCreateFailure(error: unknown): boolean {
  if (!(error instanceof GitHubApiError)) return false;
  return error.kind === "timeout" || error.kind === "network";
}

function jsonResult(
  status: number,
  body: Record<string, unknown>,
): SyncTicketResult {
  return { ok: status >= 200 && status < 300, status, body };
}

/**
 * Synchronize one ticket to GitHub. Idempotent when gh_issue_id is set.
 */
export async function syncTicketToGithub(
  ticketId: string,
  deps: SyncTicketDeps,
): Promise<SyncTicketResult> {
  if (!ticketId?.trim()) {
    return jsonResult(400, { error: "Missing ticket_id" });
  }

  const ticket = await deps.tickets.getTicket(ticketId);
  if (!ticket) {
    return jsonResult(404, { error: "Ticket not found" });
  }

  if (!ticket.sync_to_github) {
    return jsonResult(200, {
      skipped: true,
      reason: "sync_to_github_false",
      ticket_id: ticket.id,
      github_sync_status: ticket.github_sync_status,
    });
  }

  if (ticket.gh_issue_id != null) {
    return jsonResult(200, {
      already_synced: true,
      ticket_id: ticket.id,
      gh_issue_id: ticket.gh_issue_id,
      gh_issue_url: ticket.gh_issue_url,
      gh_repo: ticket.gh_repo,
      github_sync_status: "synced",
      sync_to_github: true,
    });
  }

  // Do not create again after an ambiguous create — issue may already exist.
  if (
    ticket.github_sync_status === "failed" &&
    typeof ticket.github_sync_error === "string" &&
    ticket.github_sync_error.includes(AMBIGUOUS_CREATE_MARKER)
  ) {
    return jsonResult(409, {
      error:
        "Previous GitHub issue creation was ambiguous (the issue may already exist). Automatic retry is blocked to avoid duplicates.",
      ticket_id: ticket.id,
      github_sync_status: "failed",
      github_sync_error: ticket.github_sync_error,
      sync_to_github: true,
    });
  }

  await deps.tickets.updateTicket(ticket.id, {
    github_sync_status: "pending",
    github_sync_error: null,
  });

  try {
    const issue: GitHubIssue = await deps.github.createIssue(deps.repo, {
      title: ticket.title,
      body: buildIssueBody(ticket),
    });

    await deps.tickets.updateTicket(ticket.id, {
      github_sync_status: "synced",
      github_sync_error: null,
      gh_issue_id: issue.number,
      gh_issue_url: issue.html_url,
      gh_repo: deps.repo,
      // Intent must remain true after success.
      sync_to_github: true,
    });

    return jsonResult(200, {
      success: true,
      ticket_id: ticket.id,
      gh_issue_id: issue.number,
      gh_issue_url: issue.html_url,
      gh_repo: deps.repo,
      github_sync_status: "synced",
      sync_to_github: true,
    });
  } catch (error) {
    const ambiguous = isAmbiguousCreateFailure(error);
    const base = sanitizeSyncError(error);
    const message = ambiguous
      ? `${AMBIGUOUS_CREATE_MARKER} ${base}. A GitHub issue may already have been created; do not assume it was not.`
      : base;

    await deps.tickets.updateTicket(ticket.id, {
      github_sync_status: "failed",
      github_sync_error: message,
      sync_to_github: true,
    });

    return jsonResult(502, {
      error: message,
      ticket_id: ticket.id,
      github_sync_status: "failed",
      sync_to_github: true,
      ambiguous_create: ambiguous,
    });
  }
}
