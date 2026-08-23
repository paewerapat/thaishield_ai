/**
 * feature-qa — the gate a change passes before it counts as done.
 *
 * Written 2026-08-23 after the developer asked for QA that does not depend on
 * anyone remembering the checklist. The project already had good manual
 * checklists; what it lacked was something that runs the same way every time.
 *
 * Four independent reviewers look at the same change from angles that fail
 * differently — a green test suite says nothing about legal wording, and clean
 * wording says nothing about whether the client was told. Each finding is then
 * handed to two skeptics whose job is to kill it, because a QA report nobody
 * trusts gets skipped, and the fastest way to lose trust is one confident
 * finding that turns out to be wrong.
 *
 * 🚨 **Read this before editing.** The first run of this gate reported PASS
 * while all four reviewers had crashed: they were referenced by `agentType`,
 * the registry did not know those types, `pipeline` turned each throw into
 * `null`, and the reporting step read `null` as "found nothing". A gate that
 * says PASS without opening is worse than no gate, because someone trusts it.
 * Two things fix that and neither may be undone:
 *   1. the briefs are inlined here rather than resolved from the registry;
 *   2. an angle that fails to run makes the verdict INCONCLUSIVE, never PASS.
 *
 * Run it with the Workflow tool, passing what changed:
 *   { scriptPath: ".claude/workflows/feature-qa.js", args: { change: "…" } }
 */
export const meta = {
  name: 'feature-qa',
  description: 'Four-angle QA gate for a change: static, device, copy, scope — every finding adversarially verified',
  whenToUse: 'After any feature or fix lands in thaishield_ai or thaishield-ai-web-admin, before calling it done or invoicing it',
  phases: [
    { title: 'Review', detail: 'static · device · copy · scope, in parallel' },
    { title: 'Verify', detail: 'two skeptics per finding, either can kill it' },
    { title: 'Report', detail: 'ranked findings, what was refuted, what never ran' },
  ],
}

const change = (typeof args === 'string' ? args : args?.change) ??
  'the most recent commits in both repos'

const FINDING_SCHEMA = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          title: { type: 'string' },
          severity: { type: 'string', enum: ['critical', 'major', 'minor'] },
          where: { type: 'string', description: 'file:line, screen name, or doc section' },
          evidence: { type: 'string', description: 'the log line, assertion, quoted string, or command output that proves it' },
          userImpact: { type: 'string', description: 'what a real user or the client loses because of this' },
          fix: { type: 'string' },
        },
        required: ['title', 'severity', 'where', 'evidence', 'userImpact', 'fix'],
      },
    },
    untested: {
      type: 'array',
      items: { type: 'string' },
      description: 'what this angle could not cover, stated plainly so a green result never implies more than it proves',
    },
  },
  required: ['findings', 'untested'],
}

const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    stands: { type: 'boolean' },
    reason: { type: 'string' },
  },
  required: ['stands', 'reason'],
}

const SETUP = [
  'Working directory: C:\\Fastwork\\thaishield-ai\\thaishield_ai',
  'Flutter is NOT on PATH. Every command must begin with:',
  '  export PATH="/c/Users/werapat/flutter/bin:$PATH"',
  'App package id: com.thaishield.thaishield_ai',
  'Read thaishield_ai/CLAUDE.md before judging anything — it is the contract.',
].join('\n')

// Inlined rather than resolved by agentType. The matching definitions in
// .claude/agents/ are the human-facing versions for interactive use; these are
// what actually runs, and the two must stay in step.
const ANGLES = [
  {
    key: 'static',
    brief: [
      'You are the static gate. Run `flutter analyze` and `flutter test`, and do',
      'not stop at the first failure — the caller needs the whole picture in one',
      'pass. Note the test count; it must never go DOWN between runs, because a',
      'deleted test is a deleted safety net and is a finding even when green.',
      '',
      'Then hunt for what a green suite hides:',
      '- new public behaviour in lib/ that no test names',
      '- tests that pump and never assert',
      '- string keys: every appText(context, "X") must have X in appStrings.',
      '  These are not type-checked, so a rename slips past the analyzer.',
      '- copy keys carrying fewer than six languages',
    ].join('\n'),
  },
  {
    key: 'device',
    brief: [
      'You are the device gate and you produce EVIDENCE, not opinions. A claim',
      'with no log line, test result, or screenshot behind it is not a finding.',
      '',
      'ADB="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"',
      '',
      '1. `"$ADB" devices` — if nothing is attached, say so and stop. Do not pretend.',
      '2. `flutter test integration_test -d emulator-5554`',
      '3. Launch the app and confirm it is foreground:',
      '   `"$ADB" shell dumpsys window | grep mCurrentFocus`',
      '4. After each journey read logcat:',
      '   `"$ADB" logcat -d -t 500 | grep -iE "FATAL|AndroidRuntime|E/flutter"`',
      '   A silent exception behind a screen that looks fine is the finding',
      '   manual QA never catches — this project already had one.',
      '',
      'End with an explicit list of what a bare AVD could NOT test: camera,',
      'microphone and speech-to-text, a real GPS fix, the Google Maps deep link,',
      'real purchases, anything iOS. Those are untested, not passing.',
    ].join('\n'),
  },
  {
    key: 'copy',
    brief: [
      'You audit words, which on this project are a legal surface, not',
      'decoration. Read CLAUDE.md §10 first — the mandatory wording guide.',
      '',
      '1. Banned wording in ANY of the six languages, not English alone: scam,',
      '   fraud, cheat, overcharge, rip-off, dangerous, unsafe, blacklist,',
      '   avoid, guarantee, and their Thai equivalents. A translator softening',
      '   the English while the Thai still accuses is the failure mode that',
      '   gets past review.',
      '2. Six languages complete: th, en, zh, ko, ru, ja. A missing one falls',
      '   back to English mid-screen.',
      '3. Placeholders survive translation: {count} {date} {days} {radius}.',
      '4. Claims the app cannot honour. premium_platform_note deliberately says',
      '   something DIFFERENT per platform, because restore works on Android and',
      '   does not on iOS. Flag any attempt to collapse it into one promise.',
      '',
      'Quote the string, name the key and the language, cite the rule it breaks,',
      'and propose the replacement. A finding without a fix is half a finding.',
    ].join('\n'),
  },
  {
    key: 'scope',
    brief: [
      'You stop silent scope drift and undocumented work. Both cost real money',
      'here: unbilled work, or work the client cannot see.',
      '',
      'Read CLAUDE.md §4 (remaining scope) and §7 (strict out of scope) before',
      'judging. Hard rules broken by accident more than by intent: no Firebase',
      'Auth or login in the app, no background location or geofencing, no scan',
      'history or personal profile store.',
      '',
      'Then check the trail. Every finished piece of work owes three things, and',
      'the third is the one that gets skipped:',
      '  1. code and tests',
      '  2. CLAUDE.md of every repo touched',
      '  3. the client quotation + status doc in Google Docs',
      'You cannot read (3) yourself — look for the developer stating it was',
      'updated. No evidence is a finding: "doc not updated" is a defect, not a',
      'chore.',
      '',
      'Facts that must not drift: product ids thaishield_premium_2weeks and',
      'thaishield_premium_monthly, both Consumable; the _yearly and _lifetime',
      'ids are cancelled; prices are 7 USD and 10 USD, never THB.',
    ].join('\n'),
  },
]

phase('Review')
log(`QA gate for: ${change}`)

const reviewed = await pipeline(
  ANGLES,

  // Each angle reviews independently. No angle is told what the others found —
  // shared context here would produce four versions of the same finding and
  // hide the three nobody else was looking for.
  (angle) => agent(
    `${SETUP}\n\nYou are reviewing this change:\n${change}\n\n${angle.brief}\n\n` +
    `Report only what you can prove. An unproven suspicion costs more than it ` +
    `is worth: it trains the developer to skim the report.`,
    {
      label: `review:${angle.key}`,
      phase: 'Review',
      schema: FINDING_SCHEMA,
    },
  ),

  // Verification starts the moment an angle finishes rather than waiting for
  // the slowest — the device pass takes minutes, the copy pass seconds.
  (result, angle) => {
    // A reviewer that died is NOT a reviewer that found nothing. See the
    // warning at the top of this file.
    if (!result) {
      return { angle: angle.key, failed: true, findings: [], untested: [] }
    }
    return parallel(
      result.findings.map((finding) => () =>
        parallel([
          () => agent(
            `${SETUP}\n\nTry to refute this QA finding. It came from the ` +
            `${angle.key} angle on the change:\n${change}\n\n` +
            `Title: ${finding.title}\nWhere: ${finding.where}\n` +
            `Evidence: ${finding.evidence}\nClaimed impact: ${finding.userImpact}\n\n` +
            `Read the actual code, test, or document before answering. Refute it ` +
            `if the evidence does not support it, if it is already handled ` +
            `elsewhere, or if it describes intended behaviour. Default to ` +
            `stands=false when unsure — a wrong finding is worse than a missed ` +
            `one here, because the whole report then gets ignored.`,
            { label: `refute:${finding.title.slice(0, 28)}`, phase: 'Verify', schema: VERDICT_SCHEMA },
          ),
          () => agent(
            `Judge whether this QA finding matters to a real user or to the ` +
            `client, on the change:\n${change}\n\n` +
            `Title: ${finding.title}\nSeverity claimed: ${finding.severity}\n` +
            `Claimed impact: ${finding.userImpact}\n\n` +
            `stands=true only if a tourist using the app, or the client reading ` +
            `the status doc, would actually be worse off. Internal tidiness is ` +
            `not a QA finding.`,
            { label: `impact:${finding.title.slice(0, 28)}`, phase: 'Verify', schema: VERDICT_SCHEMA },
          ),
        ]).then((votes) => {
          const cast = votes.filter(Boolean)
          return {
            ...finding,
            angle: angle.key,
            // Both skeptics must let it through, and a skeptic that failed to
            // answer is not a vote in favour.
            survived: cast.length === 2 && cast.every((v) => v.stands),
            rejectedFor: cast.find((v) => !v.stands)?.reason ??
              (cast.length < 2 ? 'a verifier did not return a verdict' : null),
          }
        }),
      ),
    ).then((verified) => ({
      angle: angle.key,
      failed: false,
      findings: verified.filter(Boolean),
      untested: result.untested,
    }))
  },
)

phase('Report')

const angles = reviewed.filter(Boolean)
// An angle that threw, or vanished from the results entirely, never ran.
const crashed = ANGLES
  .filter((a) => !angles.some((r) => r.angle === a.key && !r.failed))
  .map((a) => a.key)

const all = angles.flatMap((a) => a.findings)
const confirmed = all.filter((f) => f.survived)
const dropped = all.filter((f) => !f.survived)
const untested = angles.flatMap((a) => a.untested.map((u) => `${a.angle}: ${u}`))

const rank = { critical: 0, major: 1, minor: 2 }
confirmed.sort((a, b) => rank[a.severity] - rank[b.severity])

log(`${confirmed.length} confirmed · ${dropped.length} refuted · ${crashed.length} angles did not run`)

return {
  change,
  verdict: crashed.length > 0
    ? `INCONCLUSIVE — these angles did not run: ${crashed.join(', ')}. This is NOT a pass.`
    : confirmed.some((f) => f.severity === 'critical')
      ? 'BLOCKED — a critical finding must be fixed before this ships'
      : confirmed.length > 0
        ? 'PASS WITH FINDINGS — safe to ship once the list below is triaged'
        : 'PASS',
  anglesThatDidNotRun: crashed,
  confirmed,
  // Kept rather than discarded: seeing what was refuted, and why, is how the
  // developer learns whether to trust the gate.
  refuted: dropped.map((f) => ({ title: f.title, angle: f.angle, reason: f.rejectedFor })),
  untested,
}
