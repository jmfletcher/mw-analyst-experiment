/**
 * Cursor API uses HTTP headers; values must be ASCII (ByteString). Smart quotes
 * (U+2018, etc.) in CURSOR_API_KEY or CURSOR_MODEL cause:
 * "Cannot convert argument to a ByteString ... value of 8216"
 */

const SMART_QUOTES = /[\u2018\u2019\u201C\u201D\u00AB\u00BB\uFF07\uFEFF]/g;

export function normalizeCursorApiKey(raw) {
  if (raw == null || typeof raw !== "string") {
    return undefined;
  }
  let k = raw.replace(/^\uFEFF/, "").trim().replace(SMART_QUOTES, "");
  k = k.replace(/[^\x20-\x7E]/g, "");
  k = k.trim();
  return k || undefined;
}

/** Model ids should be ASCII (e.g. composer-2). */
export function normalizeCursorModelId(raw, fallback = "composer-2") {
  const s = String(raw ?? fallback)
    .replace(/^\uFEFF/, "")
    .trim()
    .replace(SMART_QUOTES, "");
  const ascii = s.replace(/[^\x20-\x7E]/g, "").trim();
  return ascii || fallback;
}
