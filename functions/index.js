const {onSchedule} = require('firebase-functions/v2/scheduler');
const {onRequest} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const {setGlobalOptions} = require('firebase-functions/v2');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const {GoogleAuth} = require('google-auth-library');

admin.initializeApp();
const db = admin.firestore();

setGlobalOptions({region: 'asia-southeast1'});

const NEWSDATA_API_KEY = defineSecret('NEWSDATA_API_KEY');
const ROUTES_API_KEY = defineSecret('ROUTES_API_KEY');

/**
 * App Store shared secret, for `verifyReceipt`.
 *
 * Set it with `firebase functions:secrets:set APPLE_SHARED_SECRET`, from
 * App Store Connect > ThaiShield AI > App Information > App-Specific Shared
 * Secret. While it is unset, validatePurchase answers `unavailable` for iOS and
 * the app falls back to trusting the store SDK — the posture it had before this
 * function existed.
 */
const APPLE_SHARED_SECRET = defineSecret('APPLE_SHARED_SECRET');

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
    // 🚨 Stated here rather than left to the deploy.
    //
    // Firebase makes an HTTPS function public only when it *creates* it, never
    // when it updates one — it says so in the deploy output and it is easy to
    // read past. This function was created on 2026-08-31 by a deploy whose
    // IAM step failed for lack of a role, so it existed and answered 403 to
    // everyone, including the app. Two later deploys reported "Successful
    // update operation" and changed nothing about that, because updates do not
    // touch the invoker policy. Declaring it in code is what makes the
    // permission survive a redeploy and be visible in review.
    //
    // Public is deliberate: the app has no accounts (CLAUDE.md §7), so there
    // is no caller identity to check. What bounds the damage is the API
    // restriction on the key, `maxInstances` below, and the daily quota cap in
    // Cloud Console. **Firebase App Check is the real fix** and is still not
    // done — it attests the app binary rather than a user, so it works under
    // the no-accounts rule.
    invoker: 'public',

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

/** The package name Play knows this app by. A typo here reads as "purchase not
 * found" rather than as a configuration error, which is why it is a named
 * constant a test can assert on. */
const ANDROID_PACKAGE = 'com.thaishield.thaishield_ai';

/**
 * The only products this function will vouch for.
 *
 * An allowlist, not a passthrough: the token decides *whose* purchase is
 * checked, but the product id decides what the app is about to unlock, and an
 * open validator would confirm a token for a product this app does not sell.
 * Keep in sync with `PremiumPlan` in the app.
 */
const PRODUCTS = {
  thaishield_premium_monthly: {subscription: true, durationDays: 30},
  thaishield_premium_14days: {subscription: false, durationDays: 14},
};

/** Play's `purchaseState` for a one-time product: 0 = purchased. */
const ANDROID_PURCHASED = 0;

const DAY_MILLIS = 24 * 60 * 60 * 1000;

/**
 * Reads Play's `subscriptionsv2` answer.
 *
 * v2 keeps the expiry on the line item rather than on the subscription, because
 * one purchase can carry several. This app sells one base plan, so the furthest
 * expiry is both the right answer and the safe one — a shorter sibling must
 * never cut short what the user paid for.
 *
 * `subscriptionState` says whether it is still worth anything. ACTIVE and
 * IN_GRACE_PERIOD are access. CANCELED is **also** access: on Play it means
 * "will not renew", and the period already paid for runs to its expiry, which
 * is exactly what the store itself honours. ON_HOLD, PAUSED, EXPIRED and
 * PENDING are not.
 */
function readAndroidSubscription(body) {
  const state = body?.subscriptionState;
  const lineItems = Array.isArray(body?.lineItems) ? body.lineItems : [];
  const expiries = lineItems
    .map((item) => Date.parse(item?.expiryTime ?? ''))
    .filter((millis) => Number.isFinite(millis));
  if (expiries.length === 0) return {valid: false, reason: 'no_expiry'};

  const expiresAtMillis = Math.max(...expiries);
  const live =
    state === 'SUBSCRIPTION_STATE_ACTIVE' ||
    state === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD' ||
    state === 'SUBSCRIPTION_STATE_CANCELED';
  if (!live) return {valid: false, reason: 'not_active', expiresAtMillis};
  if (expiresAtMillis <= Date.now()) {
    return {valid: false, reason: 'expired', expiresAtMillis};
  }
  return {
    valid: true,
    expiresAtMillis,
    autoRenewing: state !== 'SUBSCRIPTION_STATE_CANCELED',
  };
}

/**
 * Reads Play's `purchases.products` answer for the 14-day pass.
 *
 * 🚨 The fortnight is arithmetic, and doing it **here** is the point:
 * `purchaseTimeMillis` is Play's own clock, so a handset with its date pushed
 * forward cannot lengthen a pass and one pushed back cannot revive an expired
 * one. The device-side calculation in `PremiumProvider` is the fallback for
 * when this function has no opinion, not the authority.
 *
 * A consumed purchase (`consumptionState === 1`) is still read rather than
 * rejected: the app consumes the pass when the fortnight ends, so "consumed"
 * means the time is up, and returning the real expiry is what tells the app it
 * has nothing left to grant.
 */
function readAndroidProduct(body, durationMillis) {
  if (body?.purchaseState !== ANDROID_PURCHASED) {
    return {valid: false, reason: 'not_purchased'};
  }
  const purchasedAtMillis = Number(body?.purchaseTimeMillis);
  if (!Number.isFinite(purchasedAtMillis) || purchasedAtMillis <= 0) {
    return {valid: false, reason: 'no_purchase_time'};
  }
  const expiresAtMillis = purchasedAtMillis + durationMillis;
  const live = expiresAtMillis > Date.now();
  return {
    valid: live,
    reason: live ? undefined : 'expired',
    purchasedAtMillis,
    expiresAtMillis,
  };
}

/**
 * Picks this app's transaction out of an Apple `verifyReceipt` answer.
 *
 * `latest_receipt_info` carries every transaction the receipt knows about, for
 * every product, oldest first — so the last matching entry is the current one.
 * A subscription has `expires_date_ms`; the 14-day pass does not, and its
 * fortnight is measured from `purchase_date_ms`, the same way Android measures
 * it from `purchaseTimeMillis`.
 *
 * A `cancellation_date_ms` is a refund or a family-sharing revocation. Apple
 * keeps the transaction in the receipt either way, so ignoring that field
 * would keep access alive for someone whose money was given back.
 */
function readAppleReceipt(body, productId, durationMillis) {
  if (body?.status !== 0) {
    return {valid: false, reason: `apple_status_${body?.status ?? 'unknown'}`};
  }
  const all = [
    ...(Array.isArray(body?.latest_receipt_info) ? body.latest_receipt_info : []),
    ...(Array.isArray(body?.receipt?.in_app) ? body.receipt.in_app : []),
  ].filter((item) => item?.product_id === productId);
  if (all.length === 0) return {valid: false, reason: 'product_not_in_receipt'};

  const latest = all[all.length - 1];
  if (latest?.cancellation_date_ms) return {valid: false, reason: 'refunded'};

  const expiryRaw = Number(latest?.expires_date_ms);
  const purchasedAtMillis = Number(latest?.purchase_date_ms);
  const expiresAtMillis =
    Number.isFinite(expiryRaw) && expiryRaw > 0
      ? expiryRaw
      : Number.isFinite(purchasedAtMillis)
        ? purchasedAtMillis + durationMillis
        : NaN;
  if (!Number.isFinite(expiresAtMillis)) return {valid: false, reason: 'no_expiry'};

  const live = expiresAtMillis > Date.now();
  return {
    valid: live,
    reason: live ? undefined : 'expired',
    purchasedAtMillis: Number.isFinite(purchasedAtMillis) ? purchasedAtMillis : undefined,
    expiresAtMillis,
  };
}

/**
 * Checks a purchase with the store that sold it.
 *
 * ## Why this exists
 *
 * Everything the app knew about a purchase came from the store SDK on the
 * user's own device, and `EntitlementRepository` says out loud that it is not a
 * security boundary: the rules have to let an unauthenticated client write
 * there, so a determined user could file themselves a pass. This is the check
 * that cannot be forged, and the dates it returns replace the app's estimates —
 * including the rolling "cache horizon" the subscription had to use because a
 * client cannot see a real renewal date.
 *
 * ## What it needs before it can answer
 *
 * - **Android** — Play Console > Users & permissions must grant this project's
 *   service account (`<project>@appspot.gserviceaccount.com`) "View financial
 *   data" and "Manage orders and subscriptions", and the Google Play Android
 *   Developer API must be enabled in the GCP project. Both are console steps.
 * - **iOS** — `APPLE_SHARED_SECRET` set as a Functions secret.
 *
 * 🚨 **Missing either one answers `unavailable`, never `invalid`.** The app
 * treats "no opinion" as permission to fall back to the store SDK. Answering
 * invalid would lock paying users out the moment a console permission lapsed,
 * which is the failure mode worth being paranoid about here — a receipt check
 * that is down must not become a refund queue.
 */
exports.validatePurchase = onRequest(
  {
    secrets: [APPLE_SHARED_SECRET],
    timeoutSeconds: 30,
    cors: true,
    // Same reasoning as computeRoute: no accounts, so no caller identity to
    // check, and the invoker policy has to be in code to survive a redeploy.
    // A token is only useful to whoever already owns the purchase, and this
    // endpoint says nothing about a token it was not given.
    invoker: 'public',
    maxInstances: 10,
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({error: 'method_not_allowed'});
      return;
    }

    const body = req.body ?? {};
    const {platform, productId, token} = body;

    const product = PRODUCTS[productId];
    if (!product) {
      res.status(400).json({error: 'unknown_product'});
      return;
    }
    if (typeof token !== 'string' || token.length < 8 || token.length > 20000) {
      res.status(400).json({error: 'bad_token'});
      return;
    }
    const durationMillis = product.durationDays * DAY_MILLIS;

    try {
      if (platform === 'android') {
        const auth = new GoogleAuth({
          scopes: ['https://www.googleapis.com/auth/androidpublisher'],
        });
        const client = await auth.getClient();
        const base =
          'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/' +
          ANDROID_PACKAGE;
        const url = product.subscription
          ? `${base}/purchases/subscriptionsv2/tokens/${encodeURIComponent(token)}`
          : `${base}/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(token)}`;

        const upstream = await client.request({url, retry: false});
        res.status(200).json(
          product.subscription
            ? readAndroidSubscription(upstream.data)
            : readAndroidProduct(upstream.data, durationMillis),
        );
        return;
      }

      if (platform === 'ios') {
        const secret = APPLE_SHARED_SECRET.value();
        if (!secret) {
          res.status(200).json({valid: false, reason: 'unavailable'});
          return;
        }
        res.status(200).json(
          await verifyWithApple(token, secret, productId, durationMillis),
        );
        return;
      }

      res.status(400).json({error: 'bad_platform'});
    } catch (error) {
      // A 401/403 is the console permission nobody has granted yet; a 404 is a
      // token for another package. Neither is evidence that the user did not
      // pay, so neither is answered as invalid.
      logger.error(
        `validatePurchase: ${platform} check failed`,
        error?.message ?? error,
      );
      res.status(200).json({valid: false, reason: 'unavailable'});
    }
  },
);

/**
 * Apple's production endpoint first, sandbox second.
 *
 * 🚨 Status 21007 means "sandbox receipt sent to production", and retrying
 * against sandbox is Apple's documented answer, not a workaround: their own
 * reviewers test the production URL with sandbox receipts, so an app that skips
 * the retry fails review. Never the other way round — a production receipt must
 * not be sent to the sandbox endpoint.
 */
async function verifyWithApple(receipt, secret, productId, durationMillis) {
  const payload = {
    'receipt-data': receipt,
    password: secret,
    'exclude-old-transactions': false,
  };
  const call = (url) =>
    fetch(url, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(payload),
    }).then((r) => r.json());

  let answer = await call('https://buy.itunes.apple.com/verifyReceipt');
  if (answer?.status === 21007) {
    answer = await call('https://sandbox.itunes.apple.com/verifyReceipt');
  }
  return readAppleReceipt(answer, productId, durationMillis);
}

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
  readAndroidSubscription,
  readAndroidProduct,
  readAppleReceipt,
  PRODUCTS,
  ANDROID_PACKAGE,
};
