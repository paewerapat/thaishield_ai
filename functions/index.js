const {onSchedule} = require('firebase-functions/v2/scheduler');
const {defineSecret} = require('firebase-functions/params');
const {setGlobalOptions} = require('firebase-functions/v2');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();

setGlobalOptions({region: 'asia-southeast1'});

const GNEWS_API_KEY = defineSecret('GNEWS_API_KEY');

// Keep this list in sync with `_searchTerms` in
// lib/features/home/services/travel_alert_service.dart (Dart copy is now
// dead code for fetching, but TravelAlert.category on the client still
// matches against category keywords independently).
const SEARCH_TERMS = [
  'flood', 'storm', 'wildfire', 'fire', 'road closed', 'road closure',
  'accident', 'earthquake', 'tsunami', 'evacuation', 'landslide',
  'flight cancel', 'airport closed', 'protest',
];

const CACHE_COLLECTION = 'travel_alerts_cache';

/**
 * Idioms that contain a disruption word but describe no disruption.
 *
 * Substring matching on 'fire' let "Blackpink's Lisa under fire for…" into the
 * cache, where the Home tab then badged it ไฟไหม้ and counted it in the red
 * "N reports" banner — see INTEGRATION_TEST.md §F7. Keep in sync with
 * `_nonEventPhrases` in lib/features/home/models/travel_alert.dart.
 */
const NON_EVENT_PHRASES = [
  'under fire', 'fire back', 'fires back', 'fired back', 'firing back',
  'come under fire', 'draws fire', 'drew fire', 'fired up', 'crash course',
  'storm of criticism', 'social media storm', 'takes the internet by storm',
  'flood of comments', 'flood of criticism', 'flooded with',
];

/** Whole-word match, so 'fire' stops matching 'firearm' and 'misfire'. */
function hasTerm(text, term) {
  const escaped = term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  // Multi-word terms ("road closed") keep their internal spaces; the guards
  // only pin the outer edges.
  return new RegExp(`(?<![a-z])${escaped}(?![a-z])`).test(text);
}

function looksTravelRelevant(article) {
  const text = `${article.title ?? ''} ${article.description ?? ''}`.toLowerCase();
  if (!text.includes('thailand') && !text.includes('bangkok')) return false;
  if (NON_EVENT_PHRASES.some((phrase) => text.includes(phrase))) return false;
  return SEARCH_TERMS.some((term) => hasTerm(text, term.toLowerCase()));
}

const MAX_AGE_DAYS = 7;

function daysAgoISO(days) {
  const d = new Date();
  d.setDate(d.getDate() - days);
  return d.toISOString().replace(/\.\d{3}Z$/, 'Z');
}

function buildGNewsUrl(apiKey) {
  const keywords = SEARCH_TERMS.map((t) => (t.includes(' ') ? `"${t}"` : t)).join(' OR ');
  const query = `Thailand AND (${keywords})`;
  const url = new URL('https://gnews.io/api/v4/search');
  url.searchParams.set('q', query);
  url.searchParams.set('lang', 'en');
  url.searchParams.set('max', '10');
  url.searchParams.set('sortby', 'publishedAt');
  url.searchParams.set('from', daysAgoISO(MAX_AGE_DAYS));
  url.searchParams.set('apikey', apiKey);
  return url;
}

// Runs every 15 minutes (96 requests/day against GNews' 100/day free-tier
// quota), fetches Thailand travel-disruption news, and overwrites the
// `travel_alerts_cache` Firestore collection so every app install reads a
// single shared, server-refreshed result instead of each device hitting
// GNews on its own.
exports.syncTravelAlerts = onSchedule(
  {schedule: 'every 15 minutes', secrets: [GNEWS_API_KEY], timeoutSeconds: 60},
  async () => {
    const response = await fetch(buildGNewsUrl(GNEWS_API_KEY.value()));
    if (!response.ok) {
      throw new Error(`GNews request failed: ${response.status} ${await response.text()}`);
    }

    const body = await response.json();
    const articles = (body.articles ?? []).filter(looksTravelRelevant);

    const collection = db.collection(CACHE_COLLECTION);
    const existingDocs = await collection.listDocuments();
    const fetchedAt = admin.firestore.FieldValue.serverTimestamp();

    const keepIds = new Set();
    const batch = db.batch();
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - MAX_AGE_DAYS);

    for (const article of articles) {
      if (!article.url) continue;
      if (article.publishedAt && new Date(article.publishedAt) < cutoff) continue;
      const id = crypto.createHash('md5').update(article.url).digest('hex');
      keepIds.add(id);
      batch.set(collection.doc(id), {
        title: article.title ?? '',
        description: article.description ?? '',
        url: article.url,
        image: article.image ?? null,
        source_name: article.source?.name ?? '',
        published_at: article.publishedAt
          ? admin.firestore.Timestamp.fromDate(new Date(article.publishedAt))
          : fetchedAt,
        fetched_at: fetchedAt,
      });
    }

    for (const doc of existingDocs) {
      if (!keepIds.has(doc.id)) batch.delete(doc);
    }

    await batch.commit();
    logger.info(`syncTravelAlerts: wrote ${keepIds.size} articles, removed ${existingDocs.length - keepIds.size} stale.`);
  },
);
