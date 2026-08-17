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
const {looksTravelRelevant, parsePubDate, queryForRun, QUERIES} = _internals;

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

test('queries alternate between runs and cover every query', () => {
  const interval = 15 * 60 * 1000;
  const seen = new Set();
  for (let run = 0; run < QUERIES.length * 2; run++) {
    seen.add(queryForRun(run * interval));
  }
  assert.equal(seen.size, QUERIES.length);
  assert.notEqual(queryForRun(0), queryForRun(interval));
  assert.equal(queryForRun(0), queryForRun(QUERIES.length * interval));
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
