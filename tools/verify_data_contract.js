#!/usr/bin/env node
/**
 * ThaiShield AI — Firestore data-contract verifier.
 *
 * Reads the three CMS-managed collections exactly the way the Flutter app does
 * — anonymously, over the public Firestore REST API, with no credentials and
 * no Admin SDK — and checks every document against the contract in CLAUDE.md
 * §3. If a check here fails, the app either renders wrong data or silently
 * drops it; nothing in this script depends on the CMS being reachable, so it
 * also doubles as a "are the public read rules still open?" probe (CLAUDE.md
 * §9 — the expired test-mode rule failure mode).
 *
 * Usage:
 *   node tools/verify_data_contract.js
 *   node tools/verify_data_contract.js --check-images   # also HEAD every image_url
 *   node tools/verify_data_contract.js --json           # machine-readable output
 *   node tools/verify_data_contract.js --project=other-project-id
 *
 * Exit code 0 = every check passed, 1 = at least one ERROR (warnings alone
 * still exit 0).
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const DEFAULT_PROJECT = "thaishield-ai-790eb";
const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(HERE, "..");
const WEB_ADMIN_REPO = path.resolve(REPO_ROOT, "..", "thaishield-ai-web-admin");

const args = process.argv.slice(2);
const flag = (name) => args.includes(`--${name}`);
const opt = (name, fallback) => {
  const hit = args.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : fallback;
};

const PROJECT_ID = opt("project", DEFAULT_PROJECT);
const CHECK_IMAGES = flag("check-images");
const JSON_OUTPUT = flag("json");

// --- The contract (CLAUDE.md §3) -------------------------------------------

const PARTNER_TYPES = [
  "restaurant",
  "hotel",
  "transport",
  "hospital",
  "pharmacy",
  "police",
  "tourist_police",
  "atm_bank",
  "shopping",
  "attraction",
  "tourist_info",
];
const PRICE_TIERS = ["fair", "caution", "high"];
const PRICE_CATEGORIES = ["food", "transport", "attraction"];
const RISK_LEVELS = ["safe", "caution", "danger"];
const NAME_FIELDS = [
  "name_en",
  "name_th",
  "name_zh",
  "name_ko",
  "name_ru",
  "name_ja",
];
const ID_PATTERN = /^[a-z0-9_]+$/;
// Thailand bounding box, used only for a sanity warning.
const TH_BOUNDS = { minLat: 5.5, maxLat: 20.6, minLng: 97.3, maxLng: 105.7 };

// --- Findings ---------------------------------------------------------------

const findings = [];
const record = (level, check, target, message) =>
  findings.push({ level, check, target, message });
const error = (...a) => record("ERROR", ...a);
const warn = (...a) => record("WARN", ...a);

// --- Firestore REST helpers -------------------------------------------------

const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

async function fetchCollection(name) {
  const docs = [];
  let pageToken = "";
  do {
    const url = `${BASE}/${name}?pageSize=300${pageToken ? `&pageToken=${pageToken}` : ""}`;
    const res = await fetch(url);
    if (!res.ok) {
      throw new Error(
        `HTTP ${res.status} reading ${name}: ${(await res.text()).slice(0, 300)}`,
      );
    }
    const body = await res.json();
    docs.push(...(body.documents ?? []));
    pageToken = body.nextPageToken ?? "";
  } while (pageToken);
  return docs;
}

/** Firestore REST wraps every value in a type tag; unwrap to plain JS. */
function unwrap(value) {
  if (value == null) return undefined;
  if ("stringValue" in value) return value.stringValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return Number(value.doubleValue);
  if ("booleanValue" in value) return value.booleanValue;
  if ("nullValue" in value) return null;
  if ("timestampValue" in value)
    return { __type: "timestamp", value: value.timestampValue };
  if ("geoPointValue" in value)
    return {
      __type: "geopoint",
      lat: Number(value.geoPointValue.latitude ?? 0),
      lng: Number(value.geoPointValue.longitude ?? 0),
    };
  if ("arrayValue" in value)
    return (value.arrayValue.values ?? []).map(unwrap);
  if ("mapValue" in value) {
    const out = { __type: "map" };
    for (const [k, v] of Object.entries(value.mapValue.fields ?? {})) {
      out[k] = unwrap(v);
    }
    return out;
  }
  return { __type: "unknown", raw: value };
}

function toDoc(raw) {
  const id = raw.name.split("/").pop();
  const data = {};
  for (const [k, v] of Object.entries(raw.fields ?? {})) data[k] = unwrap(v);
  return { id, data };
}

// --- Field assertions -------------------------------------------------------

const isNum = (v) => typeof v === "number" && Number.isFinite(v);
const isStr = (v) => typeof v === "string";

function checkString(ctx, data, field, { allowEmpty = false } = {}) {
  const v = data[field];
  if (v === undefined) {
    error("field-missing", ctx, `\`${field}\` is missing`);
    return null;
  }
  if (!isStr(v)) {
    error(
      "field-type",
      ctx,
      `\`${field}\` is ${describe(v)}, the app reads it as a String`,
    );
    return null;
  }
  if (!allowEmpty && v.trim() === "") {
    error("field-empty", ctx, `\`${field}\` is empty — the app renders a blank`);
  }
  return v;
}

function checkNumber(ctx, data, field, { min, max } = {}) {
  const v = data[field];
  if (v === undefined) {
    error("field-missing", ctx, `\`${field}\` is missing`);
    return null;
  }
  if (!isNum(v)) {
    error(
      "field-type",
      ctx,
      `\`${field}\` is ${describe(v)}, the app reads it as a num`,
    );
    return null;
  }
  if (min !== undefined && v < min)
    error("field-range", ctx, `\`${field}\` = ${v}, below the allowed ${min}`);
  if (max !== undefined && v > max)
    error("field-range", ctx, `\`${field}\` = ${v}, above the allowed ${max}`);
  return v;
}

function checkEnum(ctx, data, field, allowed, { fallback } = {}) {
  const v = data[field];
  if (v === undefined) {
    error("field-missing", ctx, `\`${field}\` is missing`);
    return null;
  }
  if (!allowed.includes(v)) {
    error(
      "field-enum",
      ctx,
      `\`${field}\` = ${JSON.stringify(v)} is not one of ${allowed.join(" | ")}` +
        (fallback ? ` — the app silently falls back to "${fallback}"` : ""),
    );
  }
  return v;
}

function describe(v) {
  if (v === null) return "null";
  if (v === undefined) return "missing";
  if (Array.isArray(v)) return `an array(${v.length})`;
  if (typeof v === "object" && v.__type) return `a Firestore ${v.__type}`;
  return `a ${typeof v} (${JSON.stringify(v)})`;
}

function checkDocId(ctx, doc) {
  if (!ID_PATTERN.test(doc.id)) {
    error(
      "doc-id-format",
      ctx,
      `document ID does not match ^[a-z0-9_]+$ — the CMS cannot recreate it`,
    );
  }
  if (doc.data.id === undefined) {
    // Downgraded to a warning on 2026-08-16: the CMS now takes `id` from the
    // document ID on every read (INTEGRATION_TEST.md §F1/§F3), so a missing
    // field no longer hides the row or blocks editing it. It still breaks the
    // contract in CLAUDE.md §3 and anything reading the field directly, so it
    // stays reported — just not as a failure.
    warn(
      "doc-id-field",
      ctx,
      "`id` field is missing — the CMS reads it from the document ID so the row " +
        "still lists and edits, but CLAUDE.md §3 requires the field itself",
    );
  } else if (doc.data.id !== doc.id) {
    error(
      "doc-id-mismatch",
      ctx,
      `\`id\` field = ${JSON.stringify(doc.data.id)} but the document ID is "${doc.id}"`,
    );
  }
}

/** Mirrors the CMS's orderBy field: a doc missing it never appears in the list. */
function checkOrderByField(ctx, doc, field) {
  if (doc.data[field] === undefined) {
    error(
      "cms-invisible",
      ctx,
      `\`${field}\` is missing — the CMS lists this collection with .orderBy("${field}"), ` +
        "which excludes documents lacking the field entirely",
    );
  }
}

// --- Geometry (mirrors lib/geo/polygon.ts in the web-admin repo) ------------

const EARTH_RADIUS_KM = 6371;
const toRad = (d) => (d * Math.PI) / 180;

function haversineKm(a, b) {
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.sqrt(h));
}

function averagePoints(points) {
  const sum = points.reduce(
    (acc, p) => ({ lat: acc.lat + p.lat, lng: acc.lng + p.lng }),
    { lat: 0, lng: 0 },
  );
  return { lat: sum.lat / points.length, lng: sum.lng / points.length };
}

function centroid(points) {
  if (points.length < 3) return averagePoints(points);
  let area = 0;
  let cx = 0;
  let cy = 0;
  for (let i = 0; i < points.length; i++) {
    const p0 = points[i];
    const p1 = points[(i + 1) % points.length];
    const cross = p0.lng * p1.lat - p1.lng * p0.lat;
    area += cross;
    cx += (p0.lng + p1.lng) * cross;
    cy += (p0.lat + p1.lat) * cross;
  }
  area /= 2;
  if (Math.abs(area) < 1e-12) return averagePoints(points);
  return { lat: cy / (6 * area), lng: cx / (6 * area) };
}

const boundingRadiusKm = (center, points) =>
  points.reduce((max, p) => Math.max(max, haversineKm(center, p)), 0);

// --- Legal wording (loaded from the web-admin repo so it stays in sync) -----

function loadWordingRules() {
  const file = path.join(WEB_ADMIN_REPO, "lib", "legal-wording.ts");
  if (!fs.existsSync(file)) return null;
  const src = fs.readFileSync(file, "utf8");
  const block = src.match(/WORDING_RULES[^=]*=\s*\[([\s\S]*?)\n\];/);
  if (!block) return null;
  const rules = [];
  const re = /avoid:\s*"([^"]+)"\s*,\s*useInstead:\s*"([^"]+)"/g;
  let m;
  while ((m = re.exec(block[1])) !== null)
    rules.push({ avoid: m[1], useInstead: m[2] });
  return rules.length ? rules : null;
}

const escapeRe = (v) => v.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

function findWordingViolations(text, rules) {
  if (!text || !rules) return [];
  const covered = [];
  const out = [];
  for (const rule of [...rules].sort((a, b) => b.avoid.length - a.avoid.length)) {
    const re = new RegExp(`\\b${escapeRe(rule.avoid)}\\b`, "gi");
    let m;
    while ((m = re.exec(text)) !== null) {
      const start = m.index;
      const end = start + m[0].length;
      if (covered.some(([s, e]) => start < e && end > s)) continue;
      covered.push([start, end]);
      out.push({ match: m[0], suggestion: rule.useInstead });
    }
  }
  return out;
}

// --- Cross-repo enum sync ---------------------------------------------------

function checkCategoryListsInSync() {
  const dartFile = path.join(
    REPO_ROOT,
    "lib",
    "core",
    "models",
    "partner_category.dart",
  );
  const tsFile = path.join(
    WEB_ADMIN_REPO,
    "lib",
    "schemas",
    "partner-locations.ts",
  );

  let dartValues = null;
  if (fs.existsSync(dartFile)) {
    const src = fs.readFileSync(dartFile, "utf8");
    const body = src.match(/enum PartnerCategory\s*\{([\s\S]*?)\n\}/);
    if (body) {
      dartValues = [...body[1].matchAll(/\w+\('([a-z0-9_]+)'\)/g)].map(
        (m) => m[1],
      );
    }
  }

  let tsValues = null;
  if (fs.existsSync(tsFile)) {
    const src = fs.readFileSync(tsFile, "utf8");
    const body = src.match(/PARTNER_LOCATION_TYPES\s*=\s*\[([\s\S]*?)\]\s*as const/);
    if (body) {
      tsValues = [...body[1].matchAll(/"([a-z0-9_]+)"/g)].map((m) => m[1]);
    }
  }

  const ctx = "PartnerCategory ↔ PARTNER_LOCATION_TYPES";
  if (!dartValues) {
    warn("enum-sync", ctx, "could not parse PartnerCategory from the Flutter repo");
    return;
  }
  if (!tsValues) {
    warn(
      "enum-sync",
      ctx,
      `web-admin repo not found at ${WEB_ADMIN_REPO} — skipped the cross-repo check`,
    );
    return;
  }
  if (dartValues.join(",") !== tsValues.join(",")) {
    error(
      "enum-sync",
      ctx,
      `the two lists disagree.\n    Flutter: ${dartValues.join(", ")}\n    CMS:     ${tsValues.join(", ")}`,
    );
  }
  if (dartValues.join(",") !== PARTNER_TYPES.join(",")) {
    error(
      "enum-sync",
      ctx,
      `both repos disagree with the list documented in CLAUDE.md §3 / this script.\n    code:  ${dartValues.join(", ")}\n    doc:   ${PARTNER_TYPES.join(", ")}`,
    );
  }
}

// --- Collection checks ------------------------------------------------------

function checkPriceStandards(docs) {
  for (const doc of docs) {
    const ctx = `price_standards/${doc.id}`;
    checkDocId(ctx, doc);
    // No checkOrderByField here any more: listPriceStandards() now orders by
    // FieldPath.documentId(), which every document has by definition, so there
    // is no field whose absence can hide a row (INTEGRATION_TEST.md §F1).
    for (const f of NAME_FIELDS) checkString(ctx, doc.data, f);
    const min = checkNumber(ctx, doc.data, "min_price", { min: 0 });
    const max = checkNumber(ctx, doc.data, "max_price", { min: 0 });
    if (isNum(min) && isNum(max) && max < min) {
      error(
        "price-range",
        ctx,
        `max_price (${max}) < min_price (${min}) — the scanner's variance maths inverts`,
      );
    }
    checkEnum(ctx, doc.data, "category", PRICE_CATEGORIES, { fallback: "food" });

    const updated = doc.data.updated_at;
    if (updated === undefined) {
      error(
        "field-missing",
        ctx,
        "`updated_at` is missing — the app substitutes DateTime.now(), so the row looks freshly edited",
      );
    } else if (!(updated && updated.__type === "timestamp")) {
      error(
        "field-type",
        ctx,
        `\`updated_at\` is ${describe(updated)}, not a Firestore timestamp`,
      );
    }

    if (doc.data.image_url !== undefined && !isStr(doc.data.image_url)) {
      error("field-type", ctx, `\`image_url\` is ${describe(doc.data.image_url)}`);
    }
  }
}

function checkPartnerLocations(docs) {
  for (const doc of docs) {
    const ctx = `partner_locations/${doc.id}`;
    checkDocId(ctx, doc);
    checkOrderByField(ctx, doc, "name");
    checkString(ctx, doc.data, "name");
    const lat = checkNumber(ctx, doc.data, "lat", { min: -90, max: 90 });
    const lng = checkNumber(ctx, doc.data, "lng", { min: -180, max: 180 });
    if (
      isNum(lat) &&
      isNum(lng) &&
      (lat < TH_BOUNDS.minLat ||
        lat > TH_BOUNDS.maxLat ||
        lng < TH_BOUNDS.minLng ||
        lng > TH_BOUNDS.maxLng)
    ) {
      warn(
        "coords-outside-thailand",
        ctx,
        `lat/lng ${lat}, ${lng} falls outside Thailand — the pin lands off-map`,
      );
    }
    checkEnum(ctx, doc.data, "type", PARTNER_TYPES, { fallback: "restaurant" });
    checkNumber(ctx, doc.data, "rating", { min: 0, max: 5 });
    checkEnum(ctx, doc.data, "price_tier", PRICE_TIERS, { fallback: "fair" });

    if (typeof doc.data.is_verified !== "boolean") {
      error(
        "field-type",
        ctx,
        `\`is_verified\` is ${describe(doc.data.is_verified)}, the app reads it as a bool`,
      );
    }

    const url = checkString(ctx, doc.data, "image_url", { allowEmpty: true });
    if (isStr(url) && url !== "") {
      if (url.startsWith("https://storage.googleapis.com/")) {
        error(
          "image-url-legacy",
          ctx,
          "`image_url` uses the raw storage.googleapis.com form, which cannot load — " +
            "the bucket enforces uniform access + public-access prevention (CLAUDE.md §3)",
        );
      } else if (!url.startsWith("https://")) {
        error("image-url-scheme", ctx, `\`image_url\` is not an https URL: ${url}`);
      }
    }
  }
}

function checkAlertZones(docs, wordingRules) {
  for (const doc of docs) {
    const ctx = `alert_zones/${doc.id}`;
    checkDocId(ctx, doc);
    checkOrderByField(ctx, doc, "name");
    checkString(ctx, doc.data, "name");
    checkEnum(ctx, doc.data, "risk_level", RISK_LEVELS, { fallback: "safe" });
    const descEn = checkString(ctx, doc.data, "description_en");
    checkString(ctx, doc.data, "description_th");

    const raw = doc.data.polygon;
    let points = [];
    if (raw === undefined) {
      error("field-missing", ctx, "`polygon` is missing");
    } else if (!Array.isArray(raw)) {
      error("field-type", ctx, `\`polygon\` is ${describe(raw)}, expected an array`);
    } else {
      const geo = raw.filter((p) => p && p.__type === "geopoint");
      if (geo.length !== raw.length) {
        error(
          "polygon-not-geopoint",
          ctx,
          `${raw.length - geo.length} of ${raw.length} polygon entries are not GeoPoints — ` +
            "the app's `.whereType<GeoPoint>()` DROPS them silently and the overlay is wrong",
        );
      }
      points = geo.map((p) => ({ lat: p.lat, lng: p.lng }));
      if (points.length < 3) {
        error(
          "polygon-degenerate",
          ctx,
          `only ${points.length} usable vertices — the app falls back to a plain circle ` +
            "and isPointInPolygon always returns false",
        );
      }
    }

    const cLat = checkNumber(ctx, doc.data, "center_lat", { min: -90, max: 90 });
    const cLng = checkNumber(ctx, doc.data, "center_lng", { min: -180, max: 180 });
    const radius = checkNumber(ctx, doc.data, "radius_km", { min: 0 });

    // The derived fields drive the Radar's cheap bounding-circle rejection
    // (geo_utils.isInsideZone). If they drift from the polygon, the Radar
    // rejects zones the user is actually standing in.
    if (points.length >= 3 && isNum(cLat) && isNum(cLng) && isNum(radius)) {
      const expected = centroid(points);
      const drift = haversineKm(expected, { lat: cLat, lng: cLng });
      if (drift > 0.05) {
        error(
          "derived-centroid-stale",
          ctx,
          `center_lat/center_lng sits ${drift.toFixed(3)} km from the polygon centroid — ` +
            "derived fields are stale relative to the polygon",
        );
      }
      const expectedRadius = boundingRadiusKm({ lat: cLat, lng: cLng }, points);
      if (radius + 1e-6 < expectedRadius) {
        error(
          "derived-radius-too-small",
          ctx,
          `radius_km = ${radius.toFixed(4)} but the farthest vertex is ` +
            `${expectedRadius.toFixed(4)} km away — isInsideZone rejects points inside the polygon`,
        );
      }
    }

    if (wordingRules && isStr(descEn)) {
      for (const v of findWordingViolations(descEn, wordingRules)) {
        error(
          "legal-wording",
          ctx,
          `description_en contains "${v.match}" — CLAUDE.md §10 requires "${v.suggestion}"`,
        );
      }
    }
    if (isStr(doc.data.description_th) && /[฀-๿]/.test(doc.data.description_th)) {
      // The CMS linter is English-only by design; flag Thai copy for human review.
      warn(
        "legal-wording-th-unchecked",
        ctx,
        "description_th is Thai free text — the CMS linter cannot check it, needs human review (CLAUDE.md §10)",
      );
    }
  }
}

async function checkImages(docs) {
  const urls = docs
    .map((d) => ({ ctx: `partner_locations/${d.id}`, url: d.data.image_url }))
    .filter((x) => isStr(x.url) && x.url !== "");
  for (const { ctx, url } of urls) {
    try {
      const res = await fetch(url, { method: "GET", headers: { Range: "bytes=0-0" } });
      if (!res.ok) {
        error("image-unreachable", ctx, `image_url returned HTTP ${res.status}`);
      }
    } catch (e) {
      error("image-unreachable", ctx, `image_url request failed: ${e.message}`);
    }
  }
  return urls.length;
}

// --- Main -------------------------------------------------------------------

async function main() {
  const started = Date.now();
  const wordingRules = loadWordingRules();
  if (!wordingRules) {
    warn(
      "legal-wording",
      "lib/legal-wording.ts",
      `could not load the wording table from ${WEB_ADMIN_REPO} — skipped the copy lint`,
    );
  }

  checkCategoryListsInSync();

  const counts = {};
  let priceDocs = [];
  let partnerDocs = [];
  let zoneDocs = [];

  try {
    priceDocs = (await fetchCollection("price_standards")).map(toDoc);
    partnerDocs = (await fetchCollection("partner_locations")).map(toDoc);
    zoneDocs = (await fetchCollection("alert_zones")).map(toDoc);
  } catch (e) {
    error(
      "firestore-read",
      "public read access",
      `${e.message}\n    The app reads these collections anonymously. A 403 here means the ` +
        "public read rule is gone or expired (CLAUDE.md §9) and Map/Scanner/Radar are dead for every user.",
    );
    report(counts, started);
    process.exit(1);
  }

  counts.price_standards = priceDocs.length;
  counts.partner_locations = partnerDocs.length;
  counts.alert_zones = zoneDocs.length;

  if (priceDocs.length === 0)
    error("collection-empty", "price_standards", "no documents — the Scanner can never match");
  if (partnerDocs.length === 0)
    error("collection-empty", "partner_locations", "no documents — the Map shows no pins");
  if (zoneDocs.length === 0)
    warn("collection-empty", "alert_zones", "no documents — the Map shows no advisory overlays");

  checkPriceStandards(priceDocs);
  checkPartnerLocations(partnerDocs);
  checkAlertZones(zoneDocs, wordingRules);

  if (CHECK_IMAGES) {
    counts.images_checked = await checkImages(partnerDocs);
  }

  report(counts, started);
  process.exit(findings.some((f) => f.level === "ERROR") ? 1 : 0);
}

function report(counts, started) {
  const errors = findings.filter((f) => f.level === "ERROR");
  const warns = findings.filter((f) => f.level === "WARN");

  if (JSON_OUTPUT) {
    console.log(
      JSON.stringify(
        { project: PROJECT_ID, counts, errors: errors.length, warnings: warns.length, findings },
        null,
        2,
      ),
    );
    return;
  }

  console.log(`\nThaiShield AI — data contract check (project ${PROJECT_ID})`);
  console.log(
    "Read anonymously over the public Firestore REST API — the same access level as the app.\n",
  );
  for (const [k, v] of Object.entries(counts)) console.log(`  ${k.padEnd(20)} ${v}`);
  console.log();

  const print = (list, label) => {
    if (!list.length) return;
    console.log(`${label} (${list.length}):`);
    for (const f of list) {
      console.log(`  [${f.check}] ${f.target}`);
      console.log(`    ${f.message}`);
    }
    console.log();
  };
  print(errors, "ERRORS");
  print(warns, "WARNINGS");

  const secs = ((Date.now() - started) / 1000).toFixed(1);
  console.log(
    errors.length === 0
      ? `PASS — no contract violations (${warns.length} warning(s), ${secs}s)`
      : `FAIL — ${errors.length} contract violation(s), ${warns.length} warning(s) (${secs}s)`,
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
