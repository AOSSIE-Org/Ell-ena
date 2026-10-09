/**
 * HMAC-SHA256 verification for GitHub webhook bodies.
 * The secret stays in memory only long enough to compute the digest.
 */

const textEncoder = new TextEncoder();

export async function githubSignatureHex(
  secret: string,
  rawBody: string,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    textEncoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign(
    "HMAC",
    key,
    textEncoder.encode(rawBody),
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * Compare `sha256=<hex>` header to the digest of the raw body.
 * Length mismatches fail closed. Equal-length digests use a timing-safe compare.
 */
export async function verifyGithubSignature(
  secret: string,
  rawBody: string,
  header: string | null,
): Promise<boolean> {
  if (!secret || !header) return false;
  const presented = header.trim();
  if (!presented.toLowerCase().startsWith("sha256=")) return false;
  const presentedHex = presented.slice("sha256=".length).trim().toLowerCase();
  const expectedHex = await githubSignatureHex(secret, rawBody);
  if (presentedHex.length !== expectedHex.length) return false;
  return timingSafeEqualHex(expectedHex, presentedHex);
}

function timingSafeEqualHex(a: string, b: string): boolean {
  const left = textEncoder.encode(a);
  const right = textEncoder.encode(b);
  if (left.length !== right.length) return false;
  let mismatch = 0;
  for (let i = 0; i < left.length; i++) {
    mismatch |= left[i] ^ right[i];
  }
  return mismatch === 0;
}

/** Drop token-like fragments before storing or returning an error. */
export function sanitizeWebhookError(error: unknown, secret?: string): string {
  let message = error instanceof Error
    ? error.message
    : typeof error === "string"
    ? error
    : "Webhook processing failed";
  if (secret) message = message.split(secret).join("[redacted]");
  message = message
    .replace(/ghp_[A-Za-z0-9_]+/g, "[redacted]")
    .replace(/github_pat_[A-Za-z0-9_]+/g, "[redacted]")
    .replace(/Bearer\s+\S+/gi, "Bearer [redacted]")
    .replace(/GITHUB_WEBHOOK_SECRET[=:]\s*\S+/gi, "GITHUB_WEBHOOK_SECRET=[redacted]")
    .replace(/GITHUB_TOKEN[=:]\s*\S+/gi, "GITHUB_TOKEN=[redacted]")
    .replace(/service_role[=:]\s*\S+/gi, "service_role=[redacted]");
  return message.slice(0, 500);
}
