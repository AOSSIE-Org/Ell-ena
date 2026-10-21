import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { GitHubApiError, type GitHubIssue } from "../_shared/github.ts";
import {
  AMBIGUOUS_CREATE_MARKER,
  buildIssueBody,
  parseConfiguredRepo,
  sanitizeSyncError,
  syncTicketToGithub,
  type TicketRow,
  type TicketStore,
} from "./sync_ticket.ts";

function baseTicket(overrides: Partial<TicketRow> = {}): TicketRow {
  return {
    id: "ticket-1",
    ticket_number: "T-100",
    title: "Broken login",
    description: "Users cannot sign in",
    priority: "high",
    category: "Bug",
    sync_to_github: true,
    github_sync_status: "not_requested",
    github_sync_error: null,
    gh_issue_id: null,
    gh_issue_url: null,
    gh_repo: null,
    ...overrides,
  };
}

class MemoryTicketStore implements TicketStore {
  ticket: TicketRow | null;
  updates: Array<Record<string, unknown>> = [];

  constructor(ticket: TicketRow | null) {
    this.ticket = ticket ? { ...ticket } : null;
  }

  async getTicket(ticketId: string): Promise<TicketRow | null> {
    if (!this.ticket || this.ticket.id !== ticketId) return null;
    return { ...this.ticket };
  }

  async updateTicket(
    ticketId: string,
    patch: Record<string, unknown>,
  ): Promise<void> {
    if (!this.ticket || this.ticket.id !== ticketId) {
      throw new Error("missing ticket");
    }
    this.updates.push({ ...patch });
    this.ticket = { ...this.ticket, ...patch } as TicketRow;
  }
}

function fakeIssue(overrides: Partial<GitHubIssue> = {}): GitHubIssue {
  return {
    id: 999,
    number: 42,
    title: "Broken login",
    body: "body",
    html_url: "https://github.com/acme/app/issues/42",
    state: "open",
    ...overrides,
  };
}

Deno.test("parseConfiguredRepo accepts owner/name", () => {
  assertEquals(parseConfiguredRepo("acme/app"), "acme/app");
});

Deno.test("parseConfiguredRepo rejects missing or invalid values", () => {
  try {
    parseConfiguredRepo("");
    throw new Error("expected throw for empty");
  } catch (error) {
    assertEquals(error instanceof GitHubApiError, true);
  }
  try {
    parseConfiguredRepo("only-owner");
    throw new Error("expected throw for only-owner");
  } catch (error) {
    assertEquals(error instanceof GitHubApiError, true);
  }
  try {
    parseConfiguredRepo("acme/app/extra");
    throw new Error("expected throw for extra segment");
  } catch (error) {
    assertEquals(error instanceof GitHubApiError, true);
  }
});

Deno.test("buildIssueBody includes ticket context without UUID", () => {
  const body = buildIssueBody(baseTicket({ id: "uuid-should-not-appear" }));
  assertStringIncludes(body, "T-100");
  assertStringIncludes(body, "high");
  assertStringIncludes(body, "Bug");
  assertStringIncludes(body, "Users cannot sign in");
  assertEquals(body.includes("uuid-should-not-appear"), false);
});

Deno.test("sanitizeSyncError redacts token-like strings", () => {
  const cleaned = sanitizeSyncError(
    new Error("auth failed ghp_ABCDEFG1234567890 Bearer tokensecret"),
  );
  assertEquals(cleaned.includes("ghp_"), false);
  assertStringIncludes(cleaned, "[redacted]");
});

Deno.test("syncTicketToGithub returns 404 when ticket missing", async () => {
  const store = new MemoryTicketStore(null);
  let createCalls = 0;
  const result = await syncTicketToGithub("missing", {
    tickets: store,
    repo: "acme/app",
    github: {
      createIssue: async () => {
        createCalls++;
        return fakeIssue();
      },
    },
  });
  assertEquals(result.status, 404);
  assertEquals(createCalls, 0);
  assertEquals(
    JSON.stringify(result.body).toLowerCase().includes("token"),
    false,
  );
});

Deno.test("syncTicketToGithub skips when sync_to_github is false", async () => {
  const store = new MemoryTicketStore(
    baseTicket({ sync_to_github: false }),
  );
  let createCalls = 0;
  const result = await syncTicketToGithub("ticket-1", {
    tickets: store,
    repo: "acme/app",
    github: {
      createIssue: async () => {
        createCalls++;
        return fakeIssue();
      },
    },
  });
  assertEquals(result.status, 200);
  assertEquals(result.body.skipped, true);
  assertEquals(createCalls, 0);
  assertEquals(store.updates.length, 0);
});

Deno.test("syncTicketToGithub is idempotent when gh_issue_id exists", async () => {
  const store = new MemoryTicketStore(
    baseTicket({
      gh_issue_id: 7,
      gh_issue_url: "https://github.com/acme/app/issues/7",
      gh_repo: "acme/app",
      github_sync_status: "synced",
    }),
  );
  let createCalls = 0;
  const result = await syncTicketToGithub("ticket-1", {
    tickets: store,
    repo: "acme/app",
    github: {
      createIssue: async () => {
        createCalls++;
        return fakeIssue();
      },
    },
  });
  assertEquals(result.status, 200);
  assertEquals(result.body.already_synced, true);
  assertEquals(result.body.gh_issue_id, 7);
  assertEquals(createCalls, 0);
});

Deno.test("syncTicketToGithub creates issue and stores fields", async () => {
  const store = new MemoryTicketStore(baseTicket());
  let createCalls = 0;
  let seenTitle = "";
  let seenBody = "";

  const result = await syncTicketToGithub("ticket-1", {
    tickets: store,
    repo: "acme/app",
    github: {
      createIssue: async (_repo, input) => {
        createCalls++;
        seenTitle = input.title;
        seenBody = input.body ?? "";
        return fakeIssue();
      },
    },
  });

  assertEquals(result.status, 200);
  assertEquals(result.body.success, true);
  assertEquals(result.body.gh_issue_id, 42);
  assertEquals(result.body.gh_issue_url, "https://github.com/acme/app/issues/42");
  assertEquals(result.body.gh_repo, "acme/app");
  assertEquals(result.body.github_sync_status, "synced");
  assertEquals(result.body.sync_to_github, true);
  assertEquals(createCalls, 1);
  assertEquals(seenTitle, "Broken login");
  assertStringIncludes(seenBody, "T-100");

  // pending then synced
  assertEquals(store.updates[0].github_sync_status, "pending");
  assertEquals(store.updates[0].github_sync_error, null);
  assertEquals(store.updates[1].github_sync_status, "synced");
  assertEquals(store.updates[1].gh_issue_id, 42);
  assertEquals(store.updates[1].sync_to_github, true);
  assertEquals(store.ticket?.sync_to_github, true);
  assertEquals(store.ticket?.github_sync_status, "synced");

  // No credentials in response
  const serialized = JSON.stringify(result.body);
  assertEquals(serialized.includes("GITHUB_TOKEN"), false);
  assertEquals(serialized.includes("ghp_"), false);
});

Deno.test("syncTicketToGithub sets failed on permanent GitHub error", async () => {
  const store = new MemoryTicketStore(baseTicket());
  const result = await syncTicketToGithub("ticket-1", {
    tickets: store,
    repo: "acme/app",
    github: {
      createIssue: async () => {
        throw new GitHubApiError("GitHub API error (HTTP 401)", {
          kind: "permanent",
          status: 401,
          retryable: false,
        });
      },
    },
  });

  assertEquals(result.status, 502);
  assertEquals(result.body.github_sync_status, "failed");
  assertEquals(result.body.sync_to_github, true);
  assertEquals(store.ticket?.github_sync_status, "failed");
  assertEquals(store.ticket?.sync_to_github, true);
  assertEquals(typeof store.ticket?.github_sync_error, "string");
  assertEquals(store.ticket?.gh_issue_id, null);
  assertEquals(result.body.ambiguous_create, false);
});

Deno.test("syncTicketToGithub marks ambiguous create and blocks retry", async () => {
  const store = new MemoryTicketStore(baseTicket());
  const result = await syncTicketToGithub("ticket-1", {
    tickets: store,
    repo: "acme/app",
    github: {
      createIssue: async () => {
        throw new GitHubApiError("timeout talking to GitHub", {
          kind: "timeout",
          retryable: true,
        });
      },
    },
  });

  assertEquals(result.status, 502);
  assertEquals(result.body.ambiguous_create, true);
  assertStringIncludes(
    String(result.body.error),
    AMBIGUOUS_CREATE_MARKER,
  );
  assertEquals(store.ticket?.github_sync_status, "failed");
  assertEquals(store.ticket?.gh_issue_id, null);

  let createCalls = 0;
  const retry = await syncTicketToGithub("ticket-1", {
    tickets: store,
    repo: "acme/app",
    github: {
      createIssue: async () => {
        createCalls++;
        return fakeIssue();
      },
    },
  });
  assertEquals(retry.status, 409);
  assertEquals(createCalls, 0);
});

Deno.test("repeated sync after success does not create another issue", async () => {
  const store = new MemoryTicketStore(baseTicket());
  let createCalls = 0;
  const github = {
    createIssue: async () => {
      createCalls++;
      return fakeIssue();
    },
  };

  const first = await syncTicketToGithub("ticket-1", {
    tickets: store,
    repo: "acme/app",
    github,
  });
  assertEquals(first.status, 200);
  assertEquals(createCalls, 1);

  const second = await syncTicketToGithub("ticket-1", {
    tickets: store,
    repo: "acme/app",
    github,
  });
  assertEquals(second.status, 200);
  assertEquals(second.body.already_synced, true);
  assertEquals(createCalls, 1);
});

Deno.test("responses never include GitHub credentials", async () => {
  const store = new MemoryTicketStore(baseTicket());
  const result = await syncTicketToGithub("ticket-1", {
    tickets: store,
    repo: "acme/app",
    github: {
      createIssue: async () => {
        throw new GitHubApiError(
          "bad token ghp_SECRETOKEN123 Bearer SECRETBEARER",
          { kind: "permanent", status: 401, retryable: false },
        );
      },
    },
  });
  const serialized = JSON.stringify(result.body);
  assertEquals(serialized.includes("ghp_SECRETOKEN"), false);
  assertEquals(serialized.includes("SECRETBEARER"), false);
  assertEquals(serialized.includes("GITHUB_TOKEN"), false);
});
