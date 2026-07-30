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

function looksTravelRelevant(article) {
  const text = `${article.title ?? ''} ${article.description ?? ''}`.toLowerCase();
  if (!text.includes('thailand') && !text.includes('bangkok')) return false;
  return SEARCH_TERMS.some((term) => text.includes(term.toLowerCase()));
}

function buildGNewsUrl(apiKey) {
  const keywords = SEARCH_TERMS.map((t) => (t.includes(' ') ? `"${t}"` : t)).join(' OR ');
  const query = `Thailand AND (${keywords})`;
  const url = new URL('https://gnews.io/api/v4/search');
  url.searchParams.set('q', query);
  url.searchParams.set('lang', 'en');
  url.searchParams.set('max', '10');
  url.searchParams.set('sortby', 'publishedAt');
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

    for (const article of articles) {
      if (!article.url) continue;
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
