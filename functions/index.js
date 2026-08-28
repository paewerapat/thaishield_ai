const {onSchedule} = require('firebase-functions/v2/scheduler');
const {onRequest} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const {setGlobalOptions} = require('firebase-functions/v2');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

setGlobalOptions({region: 'asia-southeast1'});

const NEWSDATA_API_KEY = defineSecret('NEWSDATA_API_KEY');
const ROUTES_API_KEY = defineSecret('ROUTES_API_KEY');

/**
 * Ways an actual fire gets described. Used instead of the bare word, which
 * appears far more often in "opened fire", "under fire" and "ready to fire".
 */
const FIRE_TERMS = [
  'wildfire', 'wildfires', 'bushfire', 'blaze', 'arson',
  'fire broke out', 'broke out fire', 'caught fire', 'set on fire',
  'house fire', 'forest fire', 'building fire', 'factory fire', 'market fire',
  'fire destroyed', 'fire damaged', 'fire swept', 'fire engulfed',
  'firefighters', 'put out the fire', 'extinguish the fire',
];

// Keep this list in sync with `_searchTerms` in
// lib/features/home/services/travel_alert_service.dart (Dart copy is now
// dead code for fetching, but TravelAlert.category on the client still
// matches against category keywords independently).
//
// This is the LOCAL gate. It is deliberately wider than the queries sent to
// newsdata.io, whose free plan caps `q` at 100 characters (see QUERIES) — a
// term dropped from the API query still works whenever the article surfaces
// through the other query or on its own merits.
const SEARCH_TERMS = [
  'flood', 'flooding', 'floods', 'storm', 'storms',
  'road closed', 'road closure', 'accident', 'crash', 'earthquake', 'quake',
  'tsunami', 'evacuation', 'evacuated', 'landslide', 'flight cancelled',
  'flights cancelled', 'airport closed', 'protest', 'protests',
  // "fire" on its own is not a usable signal, so it is absent here and the
  // real thing is matched by context instead. Bare 'fire' admitted, from the
  // live cache: three shootings whose descriptions read "a gunman opened
  // fire", and "Fit Patrik ready to fire War Elephants" — a football story
  // that reached the Home tab with a red ไฟไหม้ badge. Blacklisting each
  // idiom is whack-a-mole; requiring fire-shaped context is not.
  ...FIRE_TERMS,
];

/**
 * newsdata.io's `country=th` filters by the SOURCE's country, not by what the
 * article is about: Bangkok Post and Channel NewsAsia publish plenty of Kyiv,
 * Hawaii and Colombia stories that arrive under that flag. Without a place
 * gate the Home tab would present a Hawaiian storm as a Thailand travel alert.
 *
 * Matching only "thailand"/"bangkok" is too narrow the other way — a Phuket
 * landslide headline reads "Karon named model area for landslide prevention"
 * and names neither. Hence the province and destination list.
 */
const THAI_PLACES = [
  'thailand', 'thai', 'bangkok', 'phuket', 'chiang mai', 'chiang rai',
  'pattaya', 'krabi', 'samui', 'ko samui', 'koh samui', 'phangan',
  'phi phi', 'hua hin', 'ayutthaya', 'khon kaen', 'udon thani', 'hat yai',
  'songkhla', 'surat thani', 'phang nga', 'karon', 'patong', 'kata',
  'isaan', 'isan', 'nakhon', 'rayong', 'chonburi', 'kanchanaburi',
  'sukhothai', 'lampang', 'mae sot', 'mae hong son', 'trang', 'satun',
  'ubon', 'buriram', 'pai', 'don mueang', 'suvarnabhumi',
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
  // Shootings. Genuinely serious, but not the travel disruption this feature
  // reports (CLAUDE.md §2.1 scopes it to floods, storms, fires, road closures
  // and major accidents), and "opened fire" is what smuggled them in.
  'opened fire', 'open fire', 'opens fire', 'ready to fire', 'fire up',
];

/** Whole-word match, so 'fire' stops matching 'firearm' and 'misfire'. */
function hasTerm(text, term) {
  const escaped = term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  // Multi-word terms ("road closed") keep their internal spaces; the guards
  // only pin the outer edges.
  return new RegExp(`(?<![a-z])${escaped}(?![a-z])`).test(text);
}

/**
 * Judges title and description only. `keywords` is deliberately excluded: it
 * is the publisher's taxonomy, not the story. Bangkok Post tags most of its
 * output "thailand", so including it let "Russian attack on Kyiv sets book
 * market on fire" and "More than 10 killed in Polish bus crash in Hungary"
 * through the place gate.
 */
function looksTravelRelevant(article) {
  const text = [article.title, article.description]
    .filter(Boolean)
    .join(' ')
    .toLowerCase();
  if (!THAI_PLACES.some((place) => hasTerm(text, place))) return false;
  if (NON_EVENT_PHRASES.some((phrase) => text.includes(phrase))) return false;
  return SEARCH_TERMS.some((term) => hasTerm(text, term));
}

const MAX_AGE_DAYS = 7;

/**
 * newsdata.io's free plan rejects any `q` longer than 100 characters
 * (`UnsupportedQueryLength`), and the old single GNews query was 183. The
 * rotation machinery below exists because of that cap: several sets can
 * alternate between runs, derived from the clock so no state is stored.
 *
 * 🚨 **There is one set now, and that is the point — dropped 2026-08-29.**
 *
 * A second set ran until then:
 *
 *     'Thailand AND (accident OR protest OR evacuation OR "airport closed")'
 *
 * It was written on the theory that disruption news is what tourists actually
 * act on, and that burying "airport closed" among weather words is how it got
 * missed. Measured against three days of real cache on 2026-08-20, that theory
 * did not survive. Of the 9 articles only that set could reach, **7 were
 * junk**: a hotel chocolate boutique and a TikTok payments story (both matched
 * a stray literal "accident"), three bungee-streamer stories, and two
 * diplomatic "no protest letter was received" denials. The 2 survivors were
 * single-incident local road news, not travel disruption. **`evacuation` and
 * `"airport closed"` never matched anything at all** — the two terms the set
 * was justified by.
 *
 * Dropping it does two good things at once: the largest source of cache junk
 * goes, and the remaining query's cadence halves from 20 minutes back to 10,
 * because it now runs every time instead of every other time. Request volume
 * is unchanged at one per run.
 *
 * If disruption news is ever wanted back, measure it the same way before
 * trusting it — see the "how to re-run the check" note that came with the
 * 2026-08-20 measurement. Adding terms to *this* set is the cheaper move,
 * since it costs no cadence.
 */
const QUERIES = [
  'Thailand AND (flood OR storm OR earthquake OR tsunami OR landslide OR fire)',
];

/**
 * How often the sync runs. Chosen against newsdata.io's free allowance of 200
 * credits/day at one credit per request: 10 minutes is 144/day, leaving room
 * for redeploys and manual checks. 5 minutes would be 288 and blow it.
 *
 * The schedule string is derived from this constant rather than written out
 * separately, because `queryForRun` buckets the clock by the same number. Set
 * them independently and the rotation silently desyncs from the actual runs —
 * a 10-minute schedule against a 15-minute bucket yields A, A, B, A instead of
 * A, B, A, B, so one query set runs twice as often as the other.
 */
const RUN_INTERVAL_MINUTES = 10;
const RUN_INTERVAL_MS = RUN_INTERVAL_MINUTES * 60 * 1000;

function queryForRun(now = Date.now()) {
  return QUERIES[Math.floor(now / RUN_INTERVAL_MS) % QUERIES.length];
}

function buildNewsdataUrl(apiKey, query) {
  const url = new URL('https://newsdata.io/api/1/latest');
  url.searchParams.set('apikey', apiKey);
  // Deliberately NOT `country=th`. That parameter filters by the SOURCE's
  // country, so it returns Bangkok Post's Kyiv and Hawaii wire copy while
  // missing "Flash flood warning issued for 39 Thai provinces" carried by an
  // outlet registered elsewhere. Anchoring the query on "Thailand" instead
  // searches what the article is actually about, and looksTravelRelevant
  // still checks the place names afterwards.
  url.searchParams.set('language', 'en');
  url.searchParams.set('q', query);
  // 10 is the free plan's ceiling and costs the same one credit as any
  // smaller page.
  url.searchParams.set('size', '10');
  return url;
}

/** newsdata.io returns `pubDate` as "YYYY-MM-DD HH:mm:ss" with pubDateTZ=UTC. */
function parsePubDate(value) {
  if (typeof value !== 'string' || !value.trim()) return null;
  const iso = `${value.trim().replace(' ', 'T')}Z`;
  const date = new Date(iso);
  return Number.isNaN(date.getTime()) ? null : date;
}

// Runs every RUN_INTERVAL_MINUTES, fetches Thailand travel-disruption news,
// and refreshes the `travel_alerts_cache` Firestore collection so every app
// install reads a single shared, server-refreshed result instead of each
// device calling the news API on its own.
exports.syncTravelAlerts = onSchedule(
  {
    schedule: `every ${RUN_INTERVAL_MINUTES} minutes`,
    secrets: [NEWSDATA_API_KEY],
    timeoutSeconds: 60,
  },
  async () => {
    const query = queryForRun();
    const response = await fetch(buildNewsdataUrl(NEWSDATA_API_KEY.value(), query));
    if (!response.ok) {
      throw new Error(
        `newsdata.io request failed: ${response.status} ${await response.text()}`,
      );
    }

    const body = await response.json();
    if (body.status !== 'success') {
      // newsdata.io can answer 200 with an error envelope, which would
      // otherwise read as "zero articles today" and quietly empty the cache.
      throw new Error(`newsdata.io returned ${JSON.stringify(body.results ?? body)}`);
    }
    const articles = (body.results ?? []).filter(looksTravelRelevant);

    const collection = db.collection(CACHE_COLLECTION);
    const existingDocs = await collection.listDocuments();
    const fetchedAt = admin.firestore.FieldValue.serverTimestamp();

    const keepIds = new Set();
    const batch = db.batch();
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - MAX_AGE_DAYS);

    for (const article of articles) {
      if (!article.link || !article.article_id) continue;
      // Syndicated copies carry their own article_id, so the same wire story
      // arrives three times over from three outlets. newsdata.io flags the
      // repeats; the Home tab should not show them as three separate alerts.
      if (article.duplicate === true) continue;
      const publishedAt = parsePubDate(article.pubDate);
      if (publishedAt && publishedAt < cutoff) continue;
      // newsdata.io hands out a stable per-article id, so there is no need to
      // hash the URL the way the GNews integration did.
      const id = article.article_id;
      keepIds.add(id);
      batch.set(collection.doc(id), {
        title: article.title ?? '',
        description: article.description ?? '',
        url: article.link,
        image: article.image_url ?? null,
        source_name: article.source_name ?? article.source_id ?? '',
        published_at: publishedAt
          ? admin.firestore.Timestamp.fromDate(publishedAt)
          : fetchedAt,
        fetched_at: fetchedAt,
      });
    }

    // Prune on two grounds only. Deleting everything the current run did not
    // return — what the GNews version did, back when one query covered the
    // whole vocabulary — would throw away half the cache every 15 minutes now
    // that two queries alternate, and make the Home tab flicker between two
    // sets of stories.
    //
    // 1. Aged out past MAX_AGE_DAYS.
    // 2. No longer passes the current filter. Without this the cache keeps
    //    serving whatever an older, looser rule admitted: the substring match
    //    this function used before 2026-08-17 read "gunfire" as "fire", so
    //    shootings sat on a travel-alert screen, and an age-only prune would
    //    have left them there for a week after the fix shipped.
    let removedAged = 0;
    let removedFiltered = 0;
    for (const doc of existingDocs) {
      if (keepIds.has(doc.id)) continue;
      const snapshot = await doc.get();
      const publishedAt = snapshot.get('published_at');
      if (!publishedAt || publishedAt.toDate() < cutoff) {
        batch.delete(doc);
        removedAged += 1;
        continue;
      }
      const stored = {
        title: snapshot.get('title'),
        description: snapshot.get('description'),
      };
      if (!looksTravelRelevant(stored)) {
        batch.delete(doc);
        removedFiltered += 1;
      }
    }
    const removed = removedAged + removedFiltered;

    await batch.commit();
    logger.info(
      `syncTravelAlerts: query="${query}" fetched ${body.results?.length ?? 0}, ` +
        `kept ${keepIds.size}, removed ${removed} ` +
        `(${removedAged} aged out, ${removedFiltered} no longer pass the filter).`,
    );
  },
);

/**
 * Google Routes proxy — added 2026-08-29 so the Routes key stops shipping
 * inside the APK.
 *
 * Routes is a web service, so Google honours no Android/iOS application
 * restriction on its key: the only protections available to a key embedded in
 * an app were "restrict to Routes API" plus a daily quota cap. Anyone who
 * unzips the APK gets the key. Moving the call here removes it from the
 * binary entirely.
 *
 * 🚨 **This alone does not stop abuse, and pretending otherwise would be
 * worse than leaving the key in the app.** An unauthenticated HTTPS endpoint
 * is a URL anyone can find in a proxy log and call, and the bill is the same.
 * What closes it is **Firebase App Check**, which attests that the caller is a
 * genuine build of this app — and does so without user accounts, which §7 of
 * CLAUDE.md forbids. Until App Check is enabled the daily quota cap in Cloud
 * Console is still the only thing bounding the damage. Keep it set.
 *
 * The field mask stays server-side and narrow for the same reason it was
 * narrow in the client: a wider mask moves the call to a pricier SKU for data
 * nothing renders.
 */
const ROUTES_ENDPOINT =
  'https://routes.googleapis.com/directions/v2:computeRoutes';
const ROUTES_FIELD_MASK =
  'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline';
const ALLOWED_TRAVEL_MODES = ['DRIVE', 'TRANSIT', 'WALK'];

/** A latitude/longitude pair, or null if the shape is not exactly right. */
function readLatLng(value) {
  if (!value || typeof value !== 'object') return null;
  const {latitude, longitude} = value;
  if (typeof latitude !== 'number' || typeof longitude !== 'number') {
    return null;
  }
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
  if (latitude < -90 || latitude > 90) return null;
  if (longitude < -180 || longitude > 180) return null;
  return {latitude, longitude};
}

exports.computeRoute = onRequest(
  {
    secrets: [ROUTES_API_KEY],
    timeoutSeconds: 30,
    cors: true,
    // A route request is cheap to serve and expensive to buy. Capping
    // instances bounds what a burst can cost before anyone notices.
    maxInstances: 10,
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({error: 'method_not_allowed'});
      return;
    }

    const body = req.body ?? {};
    const origin = readLatLng(body.origin);
    const destination = readLatLng(body.destination);
    const travelMode = body.travelMode;

    // Validate rather than forward. An open proxy that passes whatever it is
    // given is a way to spend the project's quota on someone else's routes.
    if (!origin || !destination) {
      res.status(400).json({error: 'bad_coordinates'});
      return;
    }
    if (!ALLOWED_TRAVEL_MODES.includes(travelMode)) {
      res.status(400).json({error: 'bad_travel_mode'});
      return;
    }

    const languageCode =
      typeof body.languageCode === 'string' &&
      /^[a-z]{2}(-[A-Za-z0-9]{2,8})?$/.test(body.languageCode)
        ? body.languageCode
        : 'en';

    const upstreamBody = {
      origin: {location: {latLng: origin}},
      destination: {location: {latLng: destination}},
      travelMode,
      // Only legal for road vehicles; sending it for WALK or TRANSIT is a 400.
      ...(travelMode === 'DRIVE' ? {routingPreference: 'TRAFFIC_AWARE'} : {}),
      languageCode,
      units: 'METRIC',
    };

    let upstream;
    try {
      upstream = await fetch(ROUTES_ENDPOINT, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': ROUTES_API_KEY.value(),
          'X-Goog-FieldMask': ROUTES_FIELD_MASK,
        },
        body: JSON.stringify(upstreamBody),
        signal: AbortSignal.timeout(15000),
      });
    } catch (error) {
      logger.error('computeRoute: upstream request failed', error);
      res.status(502).json({error: 'upstream_unreachable'});
      return;
    }

    if (!upstream.ok) {
      // Deliberately not forwarding Google's body: it can name the project and
      // quota state, which the client has no use for and an attacker does.
      logger.error(`computeRoute: upstream returned ${upstream.status}`);
      res.status(502).json({error: 'upstream_failed'});
      return;
    }

    res.status(200).json(await upstream.json());
  },
);

// Exported for the unit tests in functions/index.test.js — none of these touch
// Firestore or the network.
exports._internals = {
  looksTravelRelevant,
  parsePubDate,
  queryForRun,
  QUERIES,
  SEARCH_TERMS,
  THAI_PLACES,
  RUN_INTERVAL_MS,
  RUN_INTERVAL_MINUTES,
  readLatLng,
  ALLOWED_TRAVEL_MODES,
};
