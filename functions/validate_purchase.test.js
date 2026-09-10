// Unit tests for validatePurchase's readers — the three functions that turn a
// store's answer into "does this user have access, and until when".
//
// 🚨 Why these are worth more than they look. Everything else in the purchase
// path fails loudly: a broken product id shows an empty paywall, a broken buy
// call throws. These fail *quietly and in the user's favour or against it* —
// read a cancelled Play subscription as dead and a paying customer loses the
// weeks they already paid for; miss Apple's cancellation_date_ms and a refunded
// user keeps premium for a fortnight. Neither shows up in a screenshot.
//
// node:test only: no network, no Firestore, no emulator.

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'thaishield-ai-790eb';

const test = require('node:test');
const assert = require('node:assert/strict');

const {_internals} = require('./index');
const {
  readAndroidSubscription,
  readAndroidProduct,
  readAppleReceipt,
  PRODUCTS,
  ANDROID_PACKAGE,
} = _internals;

const DAY = 24 * 60 * 60 * 1000;
const inDays = (n) => new Date(Date.now() + n * DAY);

test('the product allowlist matches the two plans the app sells', () => {
  assert.deepEqual(Object.keys(PRODUCTS).sort(), [
    'thaishield_premium_14days',
    'thaishield_premium_monthly',
  ]);
  assert.equal(PRODUCTS.thaishield_premium_monthly.subscription, true);
  assert.equal(PRODUCTS.thaishield_premium_14days.subscription, false);
  // The pass keeps its own clock, so the length lives here as well as in the
  // app. They have to agree or the server and the device disagree about the
  // day access ends.
  assert.equal(PRODUCTS.thaishield_premium_14days.durationDays, 14);
});

test('the package name is the one Play registered', () => {
  // Play showed it as "com.thaishield.thaishield_ai (unreviewed)" on the
  // closed-testing track. A wrong package here answers 404 for every purchase.
  assert.equal(ANDROID_PACKAGE, 'com.thaishield.thaishield_ai');
});

test('an active Play subscription is valid until its expiry', () => {
  const expiry = inDays(12);
  const answer = readAndroidSubscription({
    subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
    lineItems: [{expiryTime: expiry.toISOString()}],
  });
  assert.equal(answer.valid, true);
  assert.equal(answer.expiresAtMillis, expiry.getTime());
  assert.equal(answer.autoRenewing, true);
});

test('a cancelled Play subscription keeps the period already paid for', () => {
  // CANCELED on Play means "will not renew", not "over". Reading it as dead
  // would cut a paying user off on the day they turned auto-renew off.
  const expiry = inDays(9);
  const answer = readAndroidSubscription({
    subscriptionState: 'SUBSCRIPTION_STATE_CANCELED',
    lineItems: [{expiryTime: expiry.toISOString()}],
  });
  assert.equal(answer.valid, true);
  assert.equal(answer.autoRenewing, false);
});

test('a grace-period subscription still grants access', () => {
  const answer = readAndroidSubscription({
    subscriptionState: 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
    lineItems: [{expiryTime: inDays(2).toISOString()}],
  });
  assert.equal(answer.valid, true);
});

test('on hold, paused and expired subscriptions grant nothing', () => {
  for (const state of [
    'SUBSCRIPTION_STATE_ON_HOLD',
    'SUBSCRIPTION_STATE_PAUSED',
    'SUBSCRIPTION_STATE_EXPIRED',
    'SUBSCRIPTION_STATE_PENDING',
  ]) {
    const answer = readAndroidSubscription({
      subscriptionState: state,
      lineItems: [{expiryTime: inDays(5).toISOString()}],
    });
    assert.equal(answer.valid, false, state);
    assert.equal(answer.reason, 'not_active', state);
  }
});

test('an active subscription whose expiry has passed is not valid', () => {
  const answer = readAndroidSubscription({
    subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
    lineItems: [{expiryTime: inDays(-1).toISOString()}],
  });
  assert.equal(answer.valid, false);
  assert.equal(answer.reason, 'expired');
});

test('several line items resolve to the furthest expiry', () => {
  const near = inDays(3);
  const far = inDays(20);
  const answer = readAndroidSubscription({
    subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
    lineItems: [{expiryTime: near.toISOString()}, {expiryTime: far.toISOString()}],
  });
  assert.equal(answer.expiresAtMillis, far.getTime());
});

test('a subscription with no readable expiry is refused rather than guessed', () => {
  assert.equal(readAndroidSubscription({subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE'}).reason, 'no_expiry');
  assert.equal(
    readAndroidSubscription({
      subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
      lineItems: [{expiryTime: 'not a date'}],
    }).reason,
    'no_expiry',
  );
});

test('the 14-day pass expires 14 days after Play says it was bought', () => {
  const boughtAt = Date.now() - 2 * DAY;
  const answer = readAndroidProduct(
    {purchaseState: 0, purchaseTimeMillis: String(boughtAt)},
    14 * DAY,
  );
  assert.equal(answer.valid, true);
  assert.equal(answer.purchasedAtMillis, boughtAt);
  assert.equal(answer.expiresAtMillis, boughtAt + 14 * DAY);
});

test('a pass bought more than a fortnight ago is expired, with its real dates', () => {
  const boughtAt = Date.now() - 15 * DAY;
  const answer = readAndroidProduct(
    {purchaseState: 0, purchaseTimeMillis: String(boughtAt), consumptionState: 1},
    14 * DAY,
  );
  // Consumed is not refused: the app consumes the pass *when the fortnight
  // ends*, so this is the normal shape of a finished pass and the app needs
  // the dates back to know there is nothing to grant.
  assert.equal(answer.valid, false);
  assert.equal(answer.reason, 'expired');
  assert.equal(answer.expiresAtMillis, boughtAt + 14 * DAY);
});

test('a pending or cancelled Play purchase grants nothing', () => {
  assert.equal(
    readAndroidProduct({purchaseState: 2, purchaseTimeMillis: String(Date.now())}, 14 * DAY).reason,
    'not_purchased',
  );
  assert.equal(
    readAndroidProduct({purchaseState: 1, purchaseTimeMillis: String(Date.now())}, 14 * DAY).reason,
    'not_purchased',
  );
});

test('a purchase with no time from Play is refused, not dated from now', () => {
  // Dating it from "now" is the reinstall exploit the whole server-side check
  // exists to close.
  assert.equal(readAndroidProduct({purchaseState: 0}, 14 * DAY).reason, 'no_purchase_time');
  assert.equal(
    readAndroidProduct({purchaseState: 0, purchaseTimeMillis: '0'}, 14 * DAY).reason,
    'no_purchase_time',
  );
});

test('Apple: the newest transaction for the product decides', () => {
  const older = Date.now() - 40 * DAY;
  const newer = Date.now() + 10 * DAY;
  const answer = readAppleReceipt(
    {
      status: 0,
      latest_receipt_info: [
        {product_id: 'thaishield_premium_monthly', expires_date_ms: String(older)},
        {product_id: 'thaishield_premium_monthly', expires_date_ms: String(newer)},
      ],
    },
    'thaishield_premium_monthly',
    30 * DAY,
  );
  assert.equal(answer.valid, true);
  assert.equal(answer.expiresAtMillis, newer);
});

test('Apple: a refunded transaction grants nothing even while in date', () => {
  const answer = readAppleReceipt(
    {
      status: 0,
      latest_receipt_info: [
        {
          product_id: 'thaishield_premium_monthly',
          expires_date_ms: String(Date.now() + 10 * DAY),
          cancellation_date_ms: String(Date.now() - DAY),
        },
      ],
    },
    'thaishield_premium_monthly',
    30 * DAY,
  );
  assert.equal(answer.valid, false);
  assert.equal(answer.reason, 'refunded');
});

test('Apple: the pass has no expires_date_ms, so it is measured from purchase', () => {
  const boughtAt = Date.now() - 3 * DAY;
  const answer = readAppleReceipt(
    {
      status: 0,
      receipt: {in_app: [{product_id: 'thaishield_premium_14days', purchase_date_ms: String(boughtAt)}]},
    },
    'thaishield_premium_14days',
    14 * DAY,
  );
  assert.equal(answer.valid, true);
  assert.equal(answer.expiresAtMillis, boughtAt + 14 * DAY);
});

test('Apple: another app’s product in the same receipt is ignored', () => {
  const answer = readAppleReceipt(
    {
      status: 0,
      latest_receipt_info: [
        {product_id: 'some_other_product', expires_date_ms: String(Date.now() + 30 * DAY)},
      ],
    },
    'thaishield_premium_monthly',
    30 * DAY,
  );
  assert.equal(answer.valid, false);
  assert.equal(answer.reason, 'product_not_in_receipt');
});

test('Apple: a non-zero status is no opinion, never a denial', () => {
  // 21004 is a wrong shared secret. It is a console field nobody filled in, so
  // it must reach the app as `unavailable` — the one reason PurchaseVerifier
  // reads as "fall back to the store SDK". Any other reason string denies, and
  // a paying customer loses what they bought. The status is kept in `detail`
  // so a misconfiguration is still diagnosable from the logs.
  const wrongSecret = readAppleReceipt({status: 21004}, 'thaishield_premium_monthly', 30 * DAY);
  assert.equal(wrongSecret.reason, 'unavailable');
  assert.equal(wrongSecret.detail, 'apple_status_21004');

  // Apple down, an unreadable receipt, the wrong endpoint, a deleted account:
  // none of them is evidence about payment either.
  for (const status of [21000, 21002, 21003, 21005, 21008, 21009, 21010]) {
    assert.equal(
      readAppleReceipt({status}, 'thaishield_premium_monthly', 30 * DAY).reason,
      'unavailable',
      `status ${status} must not deny`,
    );
  }

  const noStatus = readAppleReceipt({}, 'thaishield_premium_monthly', 30 * DAY);
  assert.equal(noStatus.reason, 'unavailable');
  assert.equal(noStatus.detail, 'apple_status_unknown');
});

test('Apple: status 0 still carries the real evidence of non-payment', () => {
  // The counterweight to the test above: making config errors silent must not
  // make anything silent. A receipt Apple vouched for is still read strictly.
  const refunded = readAppleReceipt(
    {
      status: 0,
      latest_receipt_info: [
        {
          product_id: 'thaishield_premium_monthly',
          expires_date_ms: String(Date.now() + 30 * DAY),
          cancellation_date_ms: String(Date.now() - DAY),
        },
      ],
    },
    'thaishield_premium_monthly',
    30 * DAY,
  );
  assert.equal(refunded.valid, false);
  assert.equal(refunded.reason, 'refunded');
  assert.notEqual(refunded.reason, 'unavailable');

  const expired = readAppleReceipt(
    {
      status: 0,
      latest_receipt_info: [
        {
          product_id: 'thaishield_premium_monthly',
          expires_date_ms: String(Date.now() - DAY),
        },
      ],
    },
    'thaishield_premium_monthly',
    30 * DAY,
  );
  assert.equal(expired.valid, false);
  assert.equal(expired.reason, 'expired');
});
