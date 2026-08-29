// Unit tests for the parts of syncTravelAlerts that decide what a tourist
// ends up seeing. Run with `npm test` inside functions/ — node:test only, no
// network, no Firestore, no emulator.
//
// The filter is where this function earns its keep. newsdata.io hands back
// mostly international wire copy, so a change that quietly loosens
// looksTravelRelevant would put Hawaiian storms on a Thailand travel-alert
// screen without anything failing to build.

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'thaishield-ai-790eb';

const test = require('node:test');
const assert = require('node:assert/strict');

const {_internals} = require('./index');
const {
  looksTravelRelevant,
  parsePubDate,
  queryForRun,
  QUERIES,
  readLatLng,
  ALLOWED_TRAVEL_MODES,
  RUN_INTERVAL_MS,
  RUN_INTERVAL_MINUTES,
} = _internals;

const article = (title, description = '', extra = {}) => ({
  title,
  description,
  ...extra,
});

test('keeps a Thai disruption story', () => {
  assert.equal(
    looksTravelRelevant(
      article('Flash flood warning issued for 39 Thai provinces from August 18-21'),
    ),
    true,
  );
});

test('keeps a story whose only Thai marker is a province or resort name', () => {
  // Real headline that the previous thailand/bangkok-only check dropped.
  assert.equal(
    looksTravelRelevant(article('Karon named model area for landslide prevention')),
    true,
  );
  assert.equal(
    looksTravelRelevant(article('Road closed after landslide near Chiang Mai')),
    true,
  );
});

test('drops foreign disasters carried by Thai outlets', () => {
  // country=th would have let all of these through — they are why the place
  // gate exists at all.
  for (const title of [
    'Russian attack on Kyiv sets book market on fire',
    'More than 180,000 without power in Hawaii as Lala weakens to tropical storm',
    'Rescuers search for survivors as Indonesia quake death toll rises to 47',
    'More than 10 killed in Polish bus crash in Hungary',
  ]) {
    assert.equal(looksTravelRelevant(article(title)), false, title);
  }
});

test('ignores publisher keywords when judging location', () => {
  // Bangkok Post tags most of its output "thailand". Trusting that tag put
  // Kyiv and Hungary stories on the Home tab.
  assert.equal(
    looksTravelRelevant(
      article('Russian attack on Kyiv sets book market on fire', '', {
        keywords: ['thailand', 'bangkok', 'world'],
      }),
    ),
    false,
  );
});

test('drops Thai stories that describe no disruption', () => {
  for (const title of [
    'Thailand Digital Nomad Tax Rules: What DTV Holders Need to Know',
    'Chiang Rai Coworking Spaces and Work-Friendly Cafes',
    'The woman giving Dubai a fighting chance: Creating a Muay Thai community',
  ]) {
    assert.equal(looksTravelRelevant(article(title)), false, title);
  }
});

test('drops figurative disaster words (shared with the Flutter client)', () => {
  assert.equal(
    looksTravelRelevant(
      article("Thailand's finance minister under fire over budget delay"),
    ),
    false,
  );
  assert.equal(
    looksTravelRelevant(article('Bangkok cafe owner signed up for a crash course')),
    false,
  );
});

test('reads the description when the title alone is not enough', () => {
  assert.equal(
    looksTravelRelevant(
      article('Travel advisory issued', 'Heavy flooding has closed roads in Krabi.'),
    ),
    true,
  );
});

test('every query fits the free plan 100-character limit', () => {
  // newsdata.io answers 422 UnsupportedQueryLength above 100, which would
  // silently stop the sync until someone read the logs.
  for (const query of QUERIES) {
    assert.ok(query.length <= 100, `${query.length} chars: ${query}`);
  }
});

test('every query gets used, and the cycle closes', () => {
  // Deliberately uses the module's own interval, not a copy. A literal here
  // would keep passing after someone changed the schedule, which is the one
  // failure this test exists to catch.
  const seen = new Set();
  for (let run = 0; run < QUERIES.length * 2; run++) {
    seen.add(queryForRun(run * RUN_INTERVAL_MS));
  }
  assert.equal(seen.size, QUERIES.length);
  assert.equal(queryForRun(0), queryForRun(QUERIES.length * RUN_INTERVAL_MS));

  // Since 2026-08-29 there is a single query, so consecutive runs *should*
  // repeat — that is what returning the cadence to 10 minutes means. The
  // alternation guard is kept behind this branch rather than deleted, so it
  // comes back on its own the day a second set is added. Deleting it would
  // mean rediscovering the A, A, B, A desync the hard way.
  if (QUERIES.length === 1) {
    assert.equal(queryForRun(0), queryForRun(RUN_INTERVAL_MS));
  } else {
    assert.notEqual(queryForRun(0), queryForRun(RUN_INTERVAL_MS));
  }
});

test('the rotation bucket matches the deployed schedule', () => {
  // queryForRun buckets the clock by RUN_INTERVAL_MS while Cloud Scheduler
  // fires on RUN_INTERVAL_MINUTES. If those drift apart the rotation desyncs
  // from the runs — a 10-minute schedule read through a 15-minute bucket
  // gives A, A, B, A, so one query set runs twice as often as the other.
  assert.equal(RUN_INTERVAL_MS, RUN_INTERVAL_MINUTES * 60 * 1000);

  const fired = [];
  for (let run = 0; run < 6; run++) {
    fired.push(queryForRun(run * RUN_INTERVAL_MINUTES * 60 * 1000));
  }
  // With one query every run is the same query and there is nothing to
  // desync; with more than one, a repeat between consecutive runs is exactly
  // the bug this test was written for.
  if (QUERIES.length > 1) {
    for (let i = 1; i < fired.length; i++) {
      assert.notEqual(fired[i], fired[i - 1], `run ${i} repeated the query`);
    }
  }
  assert.equal(fired.length, 6);
});

test('stays inside the free plan of 200 credits a day', () => {
  // One request per run, one credit per request.
  const runsPerDay = (24 * 60) / RUN_INTERVAL_MINUTES;
  assert.ok(runsPerDay <= 200, `${runsPerDay} runs/day exceeds the allowance`);
});

test('rejects what the older, looser filters let through', () => {
  // All four were really in the live cache on 2026-08-17, with the exact
  // descriptions reproduced here. Every one of them got in through the word
  // "fire": three shootings that "opened fire", and a football preview.
  const cases = [
    [
      'Thai government vows tougher gun controls after 2 deadly shootings near Bangkok',
      'A student opened fire at his high school and family home, killing at least eight people.',
    ],
    [
      'Six injured in shooting at Thai shopping event',
      'BANGKOK: Six people were injured after a gunman opened fire at a shopping event in Nakhon Ratchasima province.',
    ],
    [
      'Motorcycle theft row ends in gunfire at Thailand shopping fair, six hurt, one in coma',
      'Six people were injured after a gunman opened fire at a shopping event in north-eastern Thailand.',
    ],
    [
      'Fit Patrik ready to fire War Elephants',
      'Thailand head coach Anthony Hudson welcomed the addition of striker Patrik Gustavsson.',
    ],
  ];
  for (const [title, description] of cases) {
    assert.equal(looksTravelRelevant(article(title, description)), false, title);
  }
});

test('still recognises an actual fire', () => {
  for (const [title, description] of [
    ['Fire broke out at a Bangkok market overnight', ''],
    ['Wildfire smoke blankets Chiang Mai', ''],
    ['Blaze destroys Phuket beachfront restaurant', ''],
    ['Firefighters battle blaze', 'A building fire in Pattaya displaced 20 residents.'],
  ]) {
    assert.equal(looksTravelRelevant(article(title, description)), true, title);
  }
});

test('parses pubDate as UTC, not local time', () => {
  // "2026-08-17 03:23:00" with pubDateTZ=UTC. Feeding that string straight to
  // new Date() is parsed as LOCAL time by V8, which in Bangkok would date
  // every article seven hours early.
  assert.equal(
    parsePubDate('2026-08-17 03:23:00').toISOString(),
    '2026-08-17T03:23:00.000Z',
  );
});

test('parsePubDate returns null rather than an Invalid Date', () => {
  for (const value of [undefined, null, '', '   ', 'not a date']) {
    assert.equal(parsePubDate(value), null, String(value));
  }
});

// ---------------------------------------------------------------------------
// computeRoute input validation
//
// The proxy is an unauthenticated endpoint, so what it refuses to forward is
// the only thing standing between a stranger and this project's Routes bill.
// Every case below is a shape someone could post at it.
// ---------------------------------------------------------------------------

test('readLatLng accepts a well-formed pair', () => {
  assert.deepEqual(readLatLng({latitude: 13.7466, longitude: 100.5347}), {
    latitude: 13.7466,
    longitude: 100.5347,
  });
  // The corners are legal coordinates and must not be rejected.
  assert.ok(readLatLng({latitude: 90, longitude: 180}));
  assert.ok(readLatLng({latitude: -90, longitude: -180}));
  assert.ok(readLatLng({latitude: 0, longitude: 0}));
});

test('readLatLng rejects everything that is not a coordinate', () => {
  for (const bad of [
    undefined,
    null,
    'somewhere',
    42,
    [],
    {},
    {latitude: 13.7},
    {longitude: 100.5},
    // Strings are the interesting case: JSON from an attacker is not typed,
    // and "13.7" would sail through a truthiness check.
    {latitude: '13.7', longitude: '100.5'},
    {latitude: NaN, longitude: 100.5},
    {latitude: Infinity, longitude: 100.5},
    {latitude: 91, longitude: 100.5},
    {latitude: -91, longitude: 100.5},
    {latitude: 13.7, longitude: 181},
    {latitude: 13.7, longitude: -181},
  ]) {
    assert.equal(readLatLng(bad), null, `accepted ${JSON.stringify(bad)}`);
  }
});

test('only the three travel modes the app offers are allowed', () => {
  assert.deepEqual(ALLOWED_TRAVEL_MODES, ['DRIVE', 'TRANSIT', 'WALK']);

  // TWO_WHEELER is the one to watch. The Routes API accepts it, and it is a
  // reasonable thing to want in Thailand — but the Google Maps deep link has
  // no equivalent and silently downgrades to driving, so the preview and the
  // hand-off would disagree with no error anywhere. CLAUDE.md §4 records the
  // decision to leave it out; this keeps it out.
  for (const mode of ['TWO_WHEELER', 'BICYCLE', 'drive', '', null, undefined]) {
    assert.equal(ALLOWED_TRAVEL_MODES.includes(mode), false, `allowed ${mode}`);
  }
});
