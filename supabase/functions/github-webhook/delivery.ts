/**
 * In-memory rules that match claim_github_webhook_delivery /
 * complete_github_webhook_delivery / fail_github_webhook_delivery.
 * Production writes go through those SQL functions. Tests use this store.
 */

export type DeliveryStatus = "processing" | "completed" | "failed";

export type DeliveryRow = {
  deliveryId: string;
  status: DeliveryStatus;
  error: string | null;
  processedAt: string | null;
  claimedAt: string;
};

export type TaskRow = {
  id: string;
  ticketId: string | null;
  status: string;
  ghPrUrl: string | null;
  completedAt: string | null;
};

export type TicketRow = {
  id: string;
  ghRepo: string | null;
  ghIssueId: number | null;
};

export type WebhookStore = {
  claim(deliveryId: string): Promise<ClaimResult>;
  complete(input: {
    deliveryId: string;
    claimToken: string;
    repo: string;
    prUrl: string;
    completedAt: string;
    issueNumbers: number[];
  }): Promise<Record<string, unknown>>;
  fail(deliveryId: string, claimToken: string, error: string): Promise<void>;
};

export type ClaimResult = {
  claimed: boolean;
  status: DeliveryStatus | null;
  claimToken?: string;
  duplicate?: boolean;
  concurrent?: boolean;
  recovered?: boolean;
};

export function decideClaim(
  row: Pick<DeliveryRow, "status" | "claimedAt"> | null,
  nowMs: number,
  staleMs: number,
): "insert" | "skip_completed" | "skip_in_progress" | "takeover_failed" | "takeover_stale" {
  if (!row) return "insert";
  if (row.status === "completed") return "skip_completed";
  if (row.status === "failed") return "takeover_failed";
  const age = nowMs - Date.parse(row.claimedAt);
  if (row.status === "processing" && age >= staleMs) return "takeover_stale";
  return "skip_in_progress";
}

export class WebhookDeliveryStore {
  readonly deliveries = new Map<string, DeliveryRow>();
  readonly tickets: TicketRow[] = [];
  readonly tasks: TaskRow[] = [];
  private queue: Promise<void> = Promise.resolve();
  failNextComplete = false;

  constructor(
    private readonly now: () => Date = () => new Date(),
    private readonly staleMs = 300_000,
  ) {}

  /** Serialize claims so overlapping calls cannot both win. */
  private lock<T>(fn: () => T): Promise<T> {
    const run = this.queue.then(() => fn());
    this.queue = run.then(() => undefined, () => undefined);
    return run;
  }

  claim(deliveryId: string): Promise<ClaimResult> {
    return this.lock(() => {
      const decision = decideClaim(
        this.deliveries.get(deliveryId) ?? null,
        this.now().getTime(),
        this.staleMs,
      );
      if (decision === "insert" || decision === "takeover_failed" || decision === "takeover_stale") {
        const claimedAt = this.now().toISOString();
        this.deliveries.set(deliveryId, {
          deliveryId,
          status: "processing",
          error: null,
          processedAt: null,
          claimedAt,
        });
        return {
          claimed: true,
          status: "processing" as const,
          claimToken: claimedAt,
          recovered: decision !== "insert",
        };
      }
      const existing = this.deliveries.get(deliveryId)!;
      if (decision === "skip_completed") {
        return { claimed: false, status: existing.status, duplicate: true };
      }
      return { claimed: false, status: existing.status, concurrent: true };
    });
  }

  complete(input: {
    deliveryId: string;
    claimToken: string;
    repo: string;
    prUrl: string;
    completedAt: string;
    issueNumbers: number[];
  }): Promise<Record<string, unknown>> {
    return this.lock(() => {
      if (this.failNextComplete) {
        this.failNextComplete = false;
        throw new Error("database unavailable");
      }
      const delivery = this.deliveries.get(input.deliveryId);
      if (
        !delivery ||
        delivery.status !== "processing" ||
        delivery.claimedAt !== input.claimToken
      ) {
        return { applied: false, reason: "stale_claim" };
      }

      const ticketIds = new Set(
        this.tickets
          .filter((ticket) =>
            ticket.ghRepo === input.repo &&
            ticket.ghIssueId != null &&
            input.issueNumbers.includes(ticket.ghIssueId)
          )
          .map((ticket) => ticket.id),
      );

      let tasksCompleted = 0;
      let tasksAlreadyCompleted = 0;
      for (const task of this.tasks) {
        if (!task.ticketId || !ticketIds.has(task.ticketId)) continue;
        if (task.status === "completed") {
          tasksAlreadyCompleted++;
          continue;
        }
        task.status = "completed";
        task.ghPrUrl = input.prUrl;
        task.completedAt = input.completedAt;
        tasksCompleted++;
      }

      delivery.status = "completed";
      delivery.error = null;
      delivery.processedAt = this.now().toISOString();

      return {
        applied: true,
        status: "completed",
        tickets_matched: ticketIds.size,
        tasks_completed: tasksCompleted,
        tasks_already_completed: tasksAlreadyCompleted,
      };
    });
  }

  fail(deliveryId: string, claimToken: string, error: string): Promise<void> {
    return this.lock(() => {
      const delivery = this.deliveries.get(deliveryId);
      if (
        !delivery ||
        delivery.status !== "processing" ||
        delivery.claimedAt !== claimToken
      ) {
        return;
      }
      delivery.status = "failed";
      delivery.error = error.slice(0, 500);
      delivery.processedAt = null;
    });
  }
}
