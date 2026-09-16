#!/usr/bin/env node
/**
 * Confirms CURSOR_API_KEY works with Cursor API (same auth as Agent.create).
 * Usage: export CURSOR_API_KEY="..." && npm run verify:cursor
 */
import { Cursor, CursorSdkError } from "@cursor/sdk";
import { normalizeCursorApiKey } from "./cursor_auth_util.mjs";

const raw = process.env.CURSOR_API_KEY;
const key = normalizeCursorApiKey(raw);

function keyHint(k) {
  if (!k) return "(empty)";
  const n = k.length;
  const head = k.slice(0, 6);
  return `length=${n} prefix=${JSON.stringify(head)}…`;
}

if (!key) {
  console.error("CURSOR_API_KEY is empty or not set (after stripping smart quotes / non-ASCII).");
  console.error("Use straight ASCII quotes: export CURSOR_API_KEY='crsr_...'");
  console.error("Create a User API key in the Cursor dashboard (see RUN_INSTRUCTIONS.md).");
  process.exit(1);
}

if (raw !== key && typeof raw === "string") {
  console.warn("Note: Key was normalized (removed non-ASCII / smart quotes). Raw length", raw.length, "→", key.length);
}

console.log("Checking key:", keyHint(key));

try {
  const me = await Cursor.me({ apiKey: key });
  console.log("OK: Cursor API accepted your key (GET /me).");
  console.log("  apiKeyName:", me.apiKeyName);
  if (me.userEmail) console.log("  userEmail:", me.userEmail);
  console.log("Listing models…");
  const models = await Cursor.models.list({ apiKey: key });
  console.log("OK: models.list succeeded.", Array.isArray(models) ? `${models.length} models` : "");
  process.exit(0);
} catch (err) {
  if (err instanceof CursorSdkError) {
    console.error("Cursor API error:", err.message || "(no message)");
    try {
      console.error("Details:", JSON.stringify(err.toJSON(), null, 2));
    } catch {
      /* ignore */
    }
    console.error("Fields:", {
      status: err.status,
      code: err.code,
      endpoint: err.endpoint,
      operation: err.operation,
      requestId: err.requestId,
      isRetryable: err.isRetryable,
    });
    if (err.cause) {
      console.error("Cause:", err.cause);
    }
  } else {
    console.error(err);
  }
  console.error("");
  console.error("401 / auth failures usually mean:");
  console.error("  • The value is not a Cursor User API key for this account.");
  console.error("  • Wrong dashboard secret (Admin/team vs user agent key) or revoked key.");
  console.error("  • Typo or bad paste — try creating a new key and export again.");
  console.error("");
  console.error("ByteString / character 8216 errors mean curly quotes or non-ASCII in the key.");
  console.error("Re-export with: export CURSOR_API_KEY='paste_key_with_straight_quotes'");
  console.error("");
  console.error("Where to create keys:");
  console.error("  • https://cursor.com/dashboard/cloud-agents");
  console.error("  • If User API keys moved: https://cursor.com/dashboard/integrations");
  process.exit(1);
}
