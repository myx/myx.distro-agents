# PWA Vision — magic-frontender

A running, cumulative statement of what an ideal PWA architecture looks like,
built one facet at a time. Each `pwa-vision-iteration` pass picks ONE facet and reasons through it with
systems rigor. The pass proposes a new dated section, which lands here by the
skillset change rule. **Do not rewrite or "clean up" prior sections in a later
pass.** If a later facet changes the conclusion of an earlier one, add a note
in the new section that supersedes or amends it. Leave the original in place
with a pointer. This file is a log of reasoning over time, not a polished spec.

The reasoning can tip from "how do we build this" into "should this be one
app or several". Any such point is flagged inline and left for
magic-architect. This skill does not decide macro-architecture questions.

---

## Contents

- 2026-07-15 — Facet: Offline-First Architecture & Service Worker Caching Strategy
- 2026-07-16 — Facet: Installability & Web App Manifest
- 2026-07-16 — Architect response: separate origins vs. shared-storage
- 2026-07-16 — Facet: Auth Flow Under an Offline-Capable Service Worker
- 2026-07-17 — Facet: CSP Posture for a SW-Heavy, Installable Shell
- 2026-07-20 — Facet: Trusted Types Policy for the App Shell
- 2026-11-06 — Facet: The Precache Budget — Shell Size, Quota and Install Integrity
- 2026-11-06 — Amendment to the Trusted Types facet: the backstop is Baseline now
- 2026-11-09 — Facet: Step-Up and Re-Authentication on a 401 During Outbox Replay
- 2026-11-10 — Facet: The Sanitizer Behind renderTrustedRichText()
- 2026-11-11 — Facet: The Native-Standards-First Stack, Its Real Costs, and Where It Stops
- 2026-11-11 — Facet: The Launch Surface — `launch_handler` and `related_applications`
- 2026-11-12 — Facet: Resource Hints for the Shell's Own Critical Path

## 2026-07-15 — Facet: Offline-First Architecture & Service Worker Caching Strategy

This is the opening facet, because almost everything else in the PWA vision
defers to decisions made here: installability, auth-flow resilience and the
performance budget. What's precached, what's cacheable at runtime, and how
staleness is handled shape the rest of the app's contract with the network.

**Stack choice: hand-rolled Cache API, not Workbox, by default.** The caching
strategies below (cache-first, network-first, stale-while-revalidate) are
each under ~15 lines of native `fetch`/`caches` code. Workbox's value is
route-based declarative config and background-sync recipes at scale. For a
single-app SW of maybe 150 lines of straight code, it is a cost without a
matching benefit. That cost is the dependency itself, plus its own versioning
and update semantics. Those semantics layer on top of the browser's own SW
update lifecycle.
Revisit per-project if the number of distinct route patterns grows past
what's comfortably hand-maintained — that's a size threshold, not a rule
against Workbox categorically.

**Runtime strategy is split by resource class, not applied uniformly:**

- **Navigation requests (HTML):** network-first with a short timeout
  (~3s), falling back to a cached app-shell page. HTML is the
  freshest-critical resource — a stale nav response can serve an old shell
  that references assets no longer in cache. Never cache-first for
  navigations.
- **Static assets (JS/CSS/fonts) with content-hashed filenames:**
  cache-first, treated as immutable. The hash *is* the cache-invalidation
  mechanism — a cache-first policy is safe and fast precisely because the
  filename changes whenever the content does. No cache-first policy should
  ever be applied to an un-hashed filename; that's the classic bug where a
  bad deploy is permanently stuck in users' caches.
- **Read API/data (JSON GET):** stale-while-revalidate for endpoints that
  tolerate a beat of staleness (most list/read views). Serve cached
  immediately, refetch in background, update via a reactive store so the UI
  patches in fresh data rather than requiring a reload.
- **Mutating requests (POST/PUT/PATCH/DELETE):** network-only, never cached.
  When offline, queue via the Background Sync API, or an IndexedDB-backed
  outbox with manual retry if Background Sync isn't available. Do not fail
  silently. Worse still, do not write optimistically to a cache that looks
  like a real response.
- **Images/media:** cache-first with a size-capped eviction policy. The
  Cache API has no built-in LRU/size limits, so this requires manual
  bookkeeping: `cache.keys()` plus a timestamp index, trimmed on write. Budget
  for this explicitly rather than letting the media cache grow unbounded.

**Cache versioning is a single source of truth, not per-strategy ad hoc
naming.** Embed a build hash into one `CACHE_VERSION` constant at build
time; every cache name for that build derives from it (`shell-${V}`,
`assets-${V}`, `images-${V}`). On `activate`, enumerate all caches and
delete anything not matching current `CACHE_VERSION`. This is the fix for
the extremely common orphaned-cache bug. An old SW's caches are never
cleaned up, because cleanup logic lived in the *old* SW's activate handler.
That handler never ran again after the SW was superseded.

**SW takeover should be visible, not silent.** `skipWaiting()` +
`clients.claim()` are useful, but firing them unconditionally on every
install has a cost. A long-lived tab can have its SW swapped mid-session.
JS modules already loaded into memory then reference an app version that no
longer matches what the SW now serves for new requests. That is version skew
within a single running session. Prefer: detect `updatefound` /
`controllerchange`, surface an "update available" toast, and let the
update apply on next navigation or explicit user action. Auto-apply is
acceptable for content-only sites where version skew has no functional
consequence; not for a stateful SPA.

**The offline fallback is a real route, not a static "you're offline"
page.** It should be the actual cached app shell, mounting real UI against
last-known data pulled from IndexedDB. Write actions are visibly disabled or
queued, rather than the app pretending to be online. Treat "offline" as
a degraded application state to design for, not an error page to redirect
to.

**Architecture-boundary flag:** reasoning about per-route SW scoping
surfaced a question this facet can't resolve on its own. Suppose a product has
genuinely distinct sub-applications, such as a public-facing app and an
admin console, with different caching and offline needs. Does that argue for
separate PWAs rather than one SW with branching runtime logic? Separate PWAs
means a separate manifest, a separate SW scope and separate install prompts.
That's a "one app or several" call — magic-architect's territory, not decided
here. Noting it so a future facet pass, or an architect review, can pick it
up.

**Open threads for future passes:** installability and manifest design, auth
flow under an offline-capable SW, and CSP posture for a SW-heavy app. The
performance budget for precached shell size is the fourth. The auth thread
covers token refresh when the network request itself may be intercepted or
queued.

---

## 2026-07-16 — Facet: Installability & Web App Manifest

Builds on 2026-07-15. The manifest and the SW are configured independently, by
(`<link rel="manifest">` and by `navigator.serviceWorker.register(url, {scope})`.
They describe overlapping territory, since both carry a notion of "scope".
A mismatch between the two is a common source of bugs. So this pass treats
manifest `scope` and SW scope as one coupled decision, not two.

**Manifest baseline, native platform first.** A shippable `manifest.json`
needs, at minimum, the fields below.

- `name` + `short_name` — the latter for home-screen label truncation.
- `start_url` — include an analytics query param, to distinguish installed-app
  launches from browser visits in server logs. It is the only reliable signal
  of install-driven traffic.
- `display` — `standalone` for an app-like chrome-free shell. Use `minimal-ui`
  only if a back button from the OS chrome is load-bearing. Avoid `browser`,
  which forfeits installability's main visual benefit.
- `theme_color` + `background_color` — background_color paints the
  flash-of-blank-white window before first paint and splash. It should match
  the shell's actual background, not just brand color.
- `icons` — see below.
- `scope` — the URL-path boundary within which navigations stay "inside" the
  installed app, rather than kicking out to browser chrome.

**The `id` field is not cosmetic — it's the app's durable identity.**
Per current spec, `id` is what the platform uses to recognize "this is the
same app" across manifest edits. If omitted it defaults to `start_url`.
Changing `start_url` later (a common refactor) then silently creates what
the OS treats as a *second* app, orphaning the original install. Set `id`
explicitly and treat it as immutable infrastructure. That is the same
discipline as the `CACHE_VERSION` reasoning from the prior pass: both are
"this constant, once shipped, can never casually change."

**Icons: ship `maskable` purpose, not just `any`.** Android's adaptive-icon
system crops icons to platform-specific shapes (circle, squircle, etc.).
An icon authored only for `purpose: "any"` gets naively cropped and can
clip a logo. A `maskable` variant needs the safe content inside the inner
~80% "safe zone" of the canvas, full-bleed background to the edge. Ship
both purposes (or one icon entry with `"purpose": "any maskable"` if the
art safely satisfies both) rather than one-size-fits-all. iOS ignores the
manifest `icons` array for the home-screen glyph entirely. It wants a
separate `<link rel="apple-touch-icon">` instead. So a cross-platform
install target needs both declarations, not just a spec-compliant manifest.

**Splash screens are now mostly automatic, but not uniformly.** Chromium
platforms synthesize a splash screen from `name` + the largest `icons`
entry + `background_color` — no separate asset needed. iOS historically
required hand-authored `apple-touch-startup-image` per device resolution,
a real maintenance burden across a matrix of iPhone/iPad screen sizes.
iOS 26 improved this, by computing a splash screen from the existing icon
and `theme-color` meta tag in most cases. The explicit per-resolution
images remain the fallback for pixel-exact control. Net effect: budget for
one shared icon/background pair that works across both. Add the iOS
resolution matrix only if a specific launch appearance is a hard
requirement, not by default.

**`beforeinstallprompt` is a Chromium-only enhancement, not a universal
API — design the install affordance to degrade, don't gate on the event.**
Safari/iOS has never implemented it and there's no signal it will.
Installation there is manual ("Share → Add to Home Screen"), full stop.
The correct pattern is progressive enhancement applied to installability
itself. Render a persistent, low-friction "Install" affordance in the UI by
default. On Chromium, intercept `beforeinstallprompt` (`preventDefault()`
+ stash the event) and wire that affordance to call `.prompt()`. On
Safari and other browsers where the event never fires, the same affordance
falls back to an in-app instructional overlay. It reads "tap Share, then
Add to Home Screen". Never build a UI whose only path to installation is
`beforeinstallprompt` firing; that silently loses the entire iOS audience.
This mirrors the offline-fallback principle from the prior pass: the
degraded path is a real, designed UI state, not an omission.

**Scope alignment with the SW design.** Manifest `scope` and SW registration
`scope` should normally be identical, and both rooted at the app's actual
boundary. A narrower manifest `scope` than the SW's makes some SW-controlled
URLs render as "escaped from the app": browser chrome reappears. That
undermines the installed-app illusion the prior pass's offline and caching
work is building toward. Practical rule: pick the SW scope first, driven by
the caching-strategy boundaries from 2026-07-15. Then set manifest `scope`
to match, not the other way around. The SW's functional boundary is the one
with real behavioral consequences (what's cached, what's queued offline), so
it should lead.

**Installability is read from the manifest's own fields, never from its status code.** `start_url` must be same-origin with the page that links to the manifest, and `scope` resolves against the manifest's URL. Read both before calling an install surface healthy.

**Sharpening the open magic-architect question (separate PWAs vs. one SW
with branching logic).** This pass found a concrete, load-bearing fact that
bears directly on that question. A single origin *can* serve multiple
manifests at different path scopes: `/app/manifest.json` scoped to `/app/`
and `/admin/manifest.json` scoped to `/admin/`. So separate installability
is technically available without a separate origin. But the browser does
not treat same-origin, different-scope manifests as truly separate apps.
They still share cookies, localStorage, IndexedDB and Cache Storage — the
exact storage this vision's offline design relies on. Link-capturing
between the two scopes is also unreliable. A link from the installed public
app into the admin path won't reliably "capture" into the admin app, if only
the public one is installed. The practical consequence follows. If public
and admin genuinely need independent installs, independent storage and
independent SW lifecycles, same-origin path-scoped manifests do not deliver
that independence. That question is what the 2026-07-15 pass's offline-needs
thread was really asking. A separate origin, such as a subdomain, is what
actually isolates them, per current platform guidance. This doesn't resolve
the one-app-or-several call; that's still architect's to make. It does
remove one candidate middle ground. "Same origin, two manifests" looks like
a split, but functionally it still behaves like one app's storage and SW
domain. If magic-architect wants true separation, the decision is
effectively "separate origins", or accepting the shared-storage and
link-capture compromise — not "separate manifests" alone. Flagging this
refinement for architect rather than deciding it here.

**Open threads for future passes:**

- Auth flow under an offline-capable SW (carried over from 2026-07-15, still
  open).
- CSP posture for a SW-heavy app.
- Performance budget for precached shell size.
- `related_applications`/`prefer_related_applications`, for products with a
  native-app counterpart.
- `launch_handler` (`client-mode`), which controls whether a relaunch focuses
  an existing window or opens a new one. It matters once the
  separate-origins-for-sub-apps question above is settled, since it affects
  how many installed windows a user juggles.

---

## 2026-07-16 — Architect response: separate origins vs. shared-storage
compromise for sub-app isolation

Answering the question this vision flagged for magic-architect on 2026-07-15
and sharpened on 2026-07-16. Same-origin, multi-manifest setups don't give
public and admin sub-apps true separation. So the real fork is separate
origins (hard isolation, lost single-origin conveniences) versus accepting
that they share storage and SW lifecycle. This is decidable, but not as a
PWA question. The PWA layer should inherit an answer that already has to be
given at the HTTP/session layer, independent of manifests or service
workers.

**The decision axis is trust differential, not caching convenience.**
The question to ask is not "would separate origins be cleaner" (it always
would). It is "does an attacker or bug executing arbitrary code in one
sub-app's context need to be walled off from the other's storage and
session". Public-facing surfaces carry the larger, less-trusted attack
surface: third-party scripts, marketing tags, user-generated content and
broader unauthenticated input. "Admin" is, definitionally, the side holding
more privileged capability. That asymmetry is exactly the scenario
same-origin isolation cannot provide. Storage namespacing — prefixing cache
names, using separate IndexedDB database names per section, scoping SW
registrations narrowly — is a *soft* boundary. It is a code convention,
enforced only by every future change respecting it. An XSS payload or a
careless refactor does not respect naming conventions. It executes with the
full privileges of the origin, full stop. A separate origin is a *hard*
boundary: the browser's same-origin policy enforces it, not developer
discipline. It also survives bugs that a naming convention does not.

**Recommendation: use separate origins — full stop, not "it depends".** That
holds whenever the sub-apps have a genuine privilege/trust differential. The
textbook case is a public-customer base against internal or admin operators. The
lost conveniences are engineering and UX overhead. They are single sign-on without extra plumbing, and same-origin API calls
without CORS. They are one SW codebase instead of two, and one install
identity instead of two icons. The failure mode from
*not* isolating is a security compromise. That covers a public-surface
compromise reaching admin session data, cached admin API responses, or
admin SW state. Those two costs are not symmetric. Over-isolating costs
development time and a slightly less seamless UX. Under-isolating costs the
thing the isolation was supposed to protect. Default to paying the
engineering cost. The conveniences lost are each independently solvable
with known patterns. Use federated SSO via a central auth service issuing
origin-scoped session tokens, rather than a shared cookie. Use a thin
shared library imported into two separately bundled SW scripts, rather than
one shared SW. Offer two install prompts. That is arguably correct UX anyway, if the two
audiences are genuinely different people who should not casually stumble
into each other's app.

**When the split is not a trust boundary, don't fork origins at all —
and don't reach for "shared-storage compromise" either.** Sometimes
"public vs. admin" in a product actually means "logged-out view vs. a
role-gated section for the same user population", with no meaningful
blast-radius difference. Examples are an internal tool where every user is already equally trusted. A
second is a "seller admin" panel a customer toggles into for their own store,
with no elevated systemic privilege. There is then no
adversarial boundary to enforce. Separate origins would be pure overhead:
SSO plumbing and CORS bought for zero isolation benefit, against a threat
that doesn't exist in that case. There the right fix is the cheaper one
already implied by this vision's SW and cache design. Use disciplined
per-section cache-name and IndexedDB-name namespacing, plus narrowly-scoped
SW registrations, within one origin. That is the "shared-storage
compromise" option, and it is the *correct* choice here. It is not a
fallback settled for because separate origins were too expensive.

**So this is not genuinely context-dependent in the sense of "reasonable
architects could disagree either way" — it's a lookup on one prior
question.** The fork the caching and manifest work keeps bumping into isn't
a PWA-specific tradeoff at all. It is the same public/admin trust-boundary
question any web architecture has to answer, with or without a service
worker in the picture. Would this product put admin behind
`admin.example.com` and public on `www.example.com` if neither had a
manifest or SW? Answer that question first, on its own security merits. If
yes, separate origins. The PWA layer then just falls out of a boundary that
already had to exist: separate manifest, separate SW scope, separate install
identity per origin. If no — same trust level, no differential blast radius
— one origin, one SW, with careful storage namespacing. The "separation"
impulse then belongs on namespacing discipline, not origin-splitting.

**Concrete note for the "separate origins" branch:** origin means
scheme+host+port. A path-scoped split on one host is not an origin split;
2026-07-16's manifest pass already found it doesn't isolate. A subdomain
(`admin.example.com` vs. `app.example.com`) is the minimum structural change
that qualifies. A fully separate registrable domain is stronger still: it
defends against cookie and `document.domain`-era tricks, and against a
subdomain-takeover class of issue. Pick subdomain vs. separate domain based
on the same trust-differential reasoning. A subdomain is normally sufficient
once cookies are scoped without a shared parent-domain `Domain=` attribute.
Reach for a fully separate domain only if the admin surface's compliance and
security posture demands it. That means not sharing even a registrable domain
with the public surface.

**Consequence for `launch_handler` and the install-identity open
thread:** this resolves it conditionally rather than leaving it fully
open. If the trust-differential test says "separate origins", then two
installed apps with two independent identities is correct and expected.
The open thread's "how many installed windows a user juggles" concern is
then just normal multi-app UX, not a defect to design away. If the test
says "one origin", `launch_handler` stays a single-app question. It is
answered under the existing 2026-07-15 and 2026-07-16 facets, not a
sub-app-boundary one.

---

## 2026-07-16 — Facet: Auth Flow Under an Offline-Capable Service Worker

Picking up the thread both prior passes carried forward unresolved. This
facet stress-tests the mechanisms already committed to against auth: the
mutating-request outbox, `CACHE_VERSION`-style versioning discipline, and
SW/manifest scope matching. Auth is the one concern that cuts across all of
them. An auth-bearing request can be a navigation, a read, or a mutation.
The SW can also replay it long after the code that originally issued it has
stopped running.

**The core conflict: two independently "best practice" patterns don't
compose.** SPA security guidance generally recommends keeping bearer tokens
in memory only, not in localStorage or IndexedDB, to limit XSS exfiltration
blast radius. Separately, 2026-07-15 committed to replaying queued
mutations via Background Sync, so offline writes survive and fire later.
These collide. Background Sync's `sync` event can fire in the SW with
**zero open clients**: the tab may be closed, and the in-memory token gone
with it. A SW that owns no token cannot attach `Authorization: Bearer …` to
a replayed request, no matter how the outbox is designed. This isn't a bug
to code around. It's a real structural tradeoff between "tokens never touch
persistent storage" and "writes survive the tab closing". A vision that
just said "queue it and replay it" without naming this would be silently
assuming the conflict away.

**Recommendation: keep the SW deliberately ignorant of long-lived
secrets; let the client thread own refresh.** Default pattern: the SW's job
is queue + relay, not auth. On reconnect, the *page* performs its normal
refresh flow: rotating refresh token, silent re-auth, whatever the app
already does. It then hands the SW a fresh credential via `postMessage`,
immediately before triggering a drain of the outbox, or alongside one. This
keeps the refresh logic in the one place that already has to implement it
correctly for the interactive app. It does not duplicate a second, SW-side
refresh implementation that would have to be kept in sync with the first.
It also means the SW needs no refresh token in IndexedDB at all, for the
common case where a client is open at reconnect time. That case is the
large majority of real offline episodes: brief subway or elevator drops,
not multi-day disconnects.

**The no-open-client case forces a real choice, not a workaround.** When
`sync` fires with `self.clients.matchAll()` returning empty, the SW has
two honest options. The right one depends on the app's threat model, not on
a universal default:

1. **Defer.** Don't attempt replay. Re-register the sync request, or wait for the next `sync` or next client open.
That way it fires once a client *is* present to supply a fresh token via the
postMessage handoff above. Safest, simplest, and correct when queued writes are not
   time-critical. The cost is writes sit un-synced until the user reopens
   the app. For most "offline note-taking" style use cases that is an
   acceptable, even expected, wait.
2. **Use an httpOnly session cookie as the replay path's trust anchor,
   layered alongside — not instead of — in-memory bearer tokens for
   interactive calls.** The browser attaches cookies automatically to
   SW-initiated `fetch()`s, with `credentials: 'include'` or `'same-origin'`,
   so there is no token-storage problem at all. The cookie jar is
   browser-owned state, not page-JS-owned state, so it survives the tab
   closing by construction. This is not a downgrade versus the bearer
   pattern. httpOnly cookies already resist the exact XSS-exfiltration risk
   the bearer-in-memory pattern was chosen to mitigate. The remaining
   exposure is CSRF, which is solved territory. `SameSite=Lax`/`Strict` plus
   a synchronizer token does it, or a custom header value captured into the
   queued request at enqueue time and replayed verbatim. That is a checklist item
   this path adds, not a reason to avoid it.

   Choose option 2 only when "writes must survive the tab being closed
   for an extended period" is an actual product requirement. Otherwise
   option 1 is strictly simpler and has one fewer credential type in play.
   Don't default to shipping a session cookie "just in case". That's the
   same discipline as not adding Workbox until route count justifies it
   (2026-07-15). Added mechanism should track an added requirement, not get
   bundled in preemptively.

**Auth endpoints are their own resource class — always network-only,
never queued.** 2026-07-15's resource-class table (navigation / static
assets / read API / mutating API / images) has no clean slot for
login/refresh/logout. They are POST-shaped like mutations, but the outbox's
"queue when offline, replay later" semantic is actively wrong for them.
Silently queuing a login attempt, or replaying a stale refresh call later,
is a correctness and security bug. Refresh-token rotation schemes
explicitly detect and reject reuse of a stale refresh token. A "helpfully"
replayed queued refresh can trip that detection and kill the session. Auth endpoints get an explicit fifth rule: bypass the SW's caching
and queuing logic entirely, and fail fast and visibly when offline. Full
stop.

**Orphaned outbox entries are the same bug shape as orphaned caches, for
a different store.** 2026-07-15 named the failure mode where stale caches
never get cleaned up, because cleanup logic lived in a superseded SW's
`activate` handler. The outbox has a direct analog. A mutation queued under
user A's session sits in IndexedDB. The user logs out, or is force-expired,
before it replays. The entry now silently outlives the session it was
authorized under. Apply the same fix pattern that `CACHE_VERSION` used for
caches. Tag every outbox entry with the session or user id active at
enqueue time. On every login/logout transition, prune entries that don't
match the newly-current session. That beats discovering months later that a
replay is firing an old user's write under a new user's now-active session
on a shared device. On a *voluntary* logout while entries are still pending
and the client is online, prefer attempting a flush before completing the
logout. Otherwise surface "N pending changes will be discarded"; don't
silently drop user-visible work.

**Tie-in to the architect's origin-separation answer (2026-07-16,
above): this facet's design is per-origin, not a thing to solve once and
namespace within one origin.** Cookies, IndexedDB databases and Cache
Storage are all origin-partitioned already. Suppose the trust-differential
test came back "separate origins" for a public/admin split. Each sub-app
then gets its own session cookie, its own SW, its own outbox. This whole
facet's reasoning applies independently and in full to each, with no
coupling between them to design. The platform's partition already gives
structural, not disciplined, isolation between the two auth flows. That is
a second, independent point in favor of splitting origins when a genuine
trust differential exists. It is not only that public-surface XSS can't
reach admin storage, the security argument already made above. A
public-app background-sync task cannot even *address* the admin session's
cookie jar to attempt a replay against it. The isolation is free, not
something this facet's session-tagging discipline has to manufacture.
Conversely, a team may find itself trying to keep an admin refresh token
"out of reach" of a public SW's outbox. The route would be cache-name or
IndexedDB-name namespacing *within one origin*. That is precisely the
soft-boundary-only-code-convention trap the architect response warned
about. It is a sign the trust-differential test already answered "split
the origin", and no amount of careful auth-flow namespacing here
substitutes for that. When the test instead comes back "one origin, no
differential", this facet's design applies exactly once, unified, which is
the common case.

**Open threads for future passes:**

- CSP posture for a SW-heavy app, and the performance budget for precached
  shell size.
- `related_applications`/`prefer_related_applications`.
- `launch_handler`, now unblocked per the architect response above. It is
  worth a pass once this vision wants to get concrete about it.
- Newly surfaced by this pass: step-up or re-authentication UX, when a queued
  mutation's replay comes back 401 from a genuinely expired (not just stale)
  session. Does the outbox entry get held pending a fresh login, surfaced to
  the user for re-auth-and-retry, or dropped after some bound? Not resolved
  here.

---

## 2026-07-17 — Facet: CSP Posture for a SW-Heavy, Installable Shell

Picking up the first item of 2026-07-16's open-threads list. CSP looks at
first glance like an orthogonal, page-level concern: a header the server
attaches to responses. But every prior facet turns out to touch it. The
navigation-caching strategy from 2026-07-15 determines *which* CSP a client
is actually enforcing at any given moment. The manifest and shell-perf
pressure from 2026-07-16 pushes toward inline bootstrap code that CSP exists
to restrict. The auth facet's postMessage credential handoff raises the
question of whether CSP governs that channel at all.

**Deliver CSP via header, not `<meta http-equiv>` — the meta form is a
degraded fallback, not an equivalent.** A `<meta>`-tag CSP cannot set
`frame-ancestors` or `sandbox`, and cannot use `report-to`/`report-uri`.
Those are the two directives most relevant to detecting the kind of
injection this vision's vanilla-JS-first, no-framework-auto-escaping stack
is most exposed to. Reach for the meta form only when deploying to a static
host with no response-header control at all. Treat that as a known, named
gap: no clickjacking protection, no violation telemetry. It is not a silent
equivalent to the header.

**A cached navigation response carries its own CSP header — this is a
direct, previously-unnamed consequence of 2026-07-15's cache-versioning
discipline.** The Cache API stores response headers alongside the body.
So when the network-first navigation strategy times out, it falls back to the
cached app shell. That page load enforces whatever policy was attached to the
shell *at the time it was cached*. It does not enforce whatever the
server is sending today. Tightening a CSP server-side does not retroactively apply to a shell response
already sitting in Cache Storage. That covers dropping a previously-allowed
script host and adding `require-trusted-types-for`. This is the exact orphaned-state bug shape 2026-07-15 named for
stale caches, and 2026-07-16's auth facet named again for stale outbox
entries. It is a third instance of the same root cause: state cached under
an old policy, outliving the policy. The fix is the same. A CSP change that
matters for security, not just convenience, should bump `CACHE_VERSION`.
The old shell response, old headers included, then gets evicted on
`activate`. It does not linger for whatever fraction of sessions are
currently in the offline-fallback path. The blast radius is bounded by the
same fact that bounds it elsewhere in this vision. Navigation is
network-first, with only a ~3s timeout before falling back. So a stale-CSP
shell should only actually be *in use* for sessions that are genuinely
offline-degraded at that moment, not for every returning visitor.

**Inline bootstrap script or critical CSS is in real tension with CSP. Resolve
it by the same discipline 2026-07-15 applied to Workbox, and that 2026-07-16's
auth facet applied to session cookies. Don't add the exception until a
concrete requirement earns it.** Default policy
should ship with no `'unsafe-inline'` and no inline `<script>`/`<style>` at
all. Everything is external and content-hashed, which is already this
vision's baseline for static assets. Sometimes a real first-paint budget
genuinely requires an inlined bootstrap script or critical-CSS block.
There, prefer a **hash-based** source expression (`'sha256-…'`) over a
nonce for that content specifically. A nonce is only meaningful if it is
unpredictable and freshly generated per response. The content triggering
the inline need here is build-time-static: the same shell HTML the
cache-versioning discipline above already treats as an immutable, hashed
unit. Reusing one fixed nonce value across every cached serving of that
shell provides none of a nonce's actual guarantee. It is worse than just
hashing the content once at build time. Reserve nonces for content a server
genuinely re-renders per request. A cached-and-replayed shell response, by
construction, is not that.

**The service worker's own outbound fetches are a distinct CSP enforcement
surface from the document's — don't assume the page's `connect-src`
protects background-sync replay traffic.** A CSP is delivered with a
particular response, and governs the behavior of the context that response
constitutes. The SW script has its own response and its own scope, separate
from any one document's. Does a browser's SW execution context inherit the CSP of the page that
registered it, or is it bound by that CSP? That is a subtler question, more
implementation-dependent than most CSP writeups treat it as. It is worth verifying against current engine behavior directly before
relying on it, rather than assuming symmetry with ordinary page fetches.
The actionable, durable rule regardless of that detail: set an explicit,
equally strict CSP header on the service-worker script's own response.
Don't treat `connect-src` written for the document as if it were also a
review of what hosts the outbox-replay code (2026-07-16's auth facet) may
reach. Of all the pieces of this architecture, the SW is the one most likely to run
unattended. It can hold no open client, and no page-level CSP is visibly "in
effect" to a reviewer eyeballing the page source. That is exactly the code path
that most wants its own explicit review.

**CSP does not govern the postMessage credential handoff — that channel's
protection is origin-checking, a different control entirely.** 2026-07-16's
auth facet established that the page hands the SW a fresh credential via
`postMessage` before an outbox drain. `postMessage` is not a CSP-restricted
sink, since no directive names it. A reviewer auditing this facet by CSP
alone would wrongly conclude the handoff is covered. The actual defense is
in the `message` event handler itself: verifying `event.origin`, and where
applicable `event.source`, before trusting the payload. It belongs in that
handler's code review, not in the CSP policy. Worth stating explicitly,
precisely because it is easy to assume CSP is "the" security layer for
everything crossing a same-origin boundary. It isn't, and this is the one
place in the vision so far where that gap would otherwise go unnoticed.

**CSP violation reports are telemetry, not a user-authored write — they
explicitly do not belong in the outbox.** `report-to`/`report-uri`
naturally raises the question of what happens to a violation report
generated while offline. The right answer follows directly from
2026-07-15's resource-class table and the auth facet's session-tagged
outbox. Reports are diagnostic and best-effort, and carry no user intent to
preserve. So they should be fire-and-forget, and simply dropped if offline,
not queued for replay. The outbox carries survive-a-closed-tab guarantees. Extending them to CSP
reports would misapply machinery built to protect a user's work, so that it
protects a security team's dashboard completeness instead.
That is a category error the outbox's session-tagging design should not be
stretched to cover.

**Cross-reference to the architect's origin-separation answer
(2026-07-16, above): shared CSP is a fourth, previously unstated cost of
staying same-origin across a real trust differential.** The architect
response reasoned from storage and session partitioning. CSP adds an
independent data point pointing the same direction. One origin can only
carry one CSP per response class. So a public-facing surface's genuine needs end up as the *ceiling* on what the
admin section of the same origin is permitted to run too. Those needs are
third-party analytics and tag-manager hosts, embedded widgets, a looser
`script-src`. There is no way to give admin a
materially stricter `script-src`/`frame-ancestors` while public pages on
the same origin need a looser one. CSP is a per-origin resource-serving
decision, more coarsely grained than the admin/public route split within
the app. Separate origins let each sub-app's CSP track its own actual risk
surface. Admin can plausibly ship close to `script-src 'self'` with no
third-party hosts at all, which the public marketing surface likely never
can. This doesn't reopen the one-app-or-several question. It is one more
concrete reason the trust-differential answer, once given, is worth acting
on rather than absorbing as shared-origin overhead.

**Trusted Types as a natural complement, flagged rather than adopted by
default.** `require-trusted-types-for 'script'` closes the DOM-XSS gap
CSP's `script-src` alone doesn't cover. A compromised or careless
`innerHTML`/`insertAdjacentHTML` call with attacker-controlled content is a
same-origin, same-nonce, fully "CSP-legal" write. Trusted Types is a
particularly good fit for this vision's stack specifically. The
native-standards-first, no-framework stance (`magic-frontender.armed.md`'s
default stance) means there's no framework-level auto-escaping quietly
doing this job already. A Web-Components-and-vanilla-JS codebase that
touches `innerHTML` by hand is exactly the shape of codebase Trusted Types
was designed to backstop. Flagging it as a strong candidate for a future
pass to get concrete about: policy naming, and which sinks the shell's own
bootstrap code touches. It is not folded in fully here. That is consistent with this vision's running
discipline: never bundle a mechanism in ahead of a pass that actually works
out its specifics.

**Open threads for future passes:**

- Performance budget for precached shell size, and step-up or
  re-authentication UX for a queued mutation's replay coming back 401 from a
  genuinely expired session. Both carried from 2026-07-16.
- `related_applications`/`prefer_related_applications` and `launch_handler`
  client-mode. Carried from 2026-07-16, unblocked per the architect response.
- New from this pass: working out a concrete Trusted Types policy for the app
  shell's own bootstrap code.

---

## 2026-07-20 — Facet: Trusted Types Policy for the App Shell

Picking up the thread flagged at the end of 2026-07-17's CSP pass. It is next
in the queued order (Trusted-Types → shell-size performance budget → step-up
re-auth UX). `require-trusted-types-for 'script'` was named there as a
strong fit for this vision's stack. The native-standards-first,
no-framework stance means there's no framework auto-escaping quietly
absorbing DOM-XSS risk. A Web-Components-and-vanilla-JS codebase touching
`innerHTML` by hand is exactly the shape Trusted Types exists to backstop.
This pass gets concrete: which sinks, which policies, what enforcement path.

**Mechanism, precisely, since the CSP facet only gestured at it.** Once
`require-trusted-types-for 'script'` is set, the browser refuses to hand a
raw string to a fixed set of DOM-XSS-prone sinks. The set covers
`innerHTML`/`outerHTML` setters, `insertAdjacentHTML`,
`Document.write`/`writeln`, `DOMParser.parseFromString`,
`Range.createContextualFragment`, `<script>` `src`/`text`/`textContent`,
`<iframe srcdoc>`, `eval`/`Function`, and
`importScripts`/Worker-family constructor URLs. The string is accepted only
if a registered `TrustedTypesPolicy` produced it, through `createHTML`,
`createScript` or `createScriptURL`. A raw string hitting any of these
sinks throws a `TypeError` instead of executing. This is what makes it a
real backstop rather than a lint rule. The enforcement is in the sink
itself, at the platform level, not in code review catching a bad
`innerHTML` call before merge.

**Don't register a `'default'` policy — that's the one footgun this
mechanism has, and it's easy to reach for by accident.** If a policy named
`'default'` exists, *any* unmarked string hitting a guarded sink silently
routes through it instead of throwing. That includes strings written by a
third-party script this app didn't author. It looks attractive as a quick
way to "make TT errors go away" during rollout. In practice it quietly
converts a hard platform-enforced boundary back into "whatever the default
policy's callback decides to allow". That is the exact soft-boundary failure mode 2026-07-16's architect response
warned about for storage namespacing. It is a convention-shaped safety net
instead of one the platform itself enforces.
It is also a supply-chain risk specific to this pattern. A compromised or
careless dependency's `innerHTML` write gets silently "fixed", or worse,
silently passed through if the default policy is permissive. It does not
fail loudly where it can be caught. Default policy has a legitimate narrow use: hardening a vendored or legacy
script this app can't rewrite. There the callback actually sanitizes, rather
than passing through. Even then it
should be a deliberate, named exception at one call site, never the
standing shape of the rollout.

**Design: small number of named, purpose-scoped policies, not one
catch-all.** `trustedTypes.createPolicy('shell-render', { createHTML: … })`,
scoped to the module that owns Web Component re-renders, is the pattern.
Only code that imports that specific policy object can call it. A security
review can then enumerate "everywhere HTML can be constructed from a string
in this app" by grep-ing policy names. It does not have to audit every
`innerHTML` call site for whether it's safe. A second, separate policy
covers anything genuinely constructing a script URL, such as a dynamic
`import()` of a build-time-known chunk path. That keeps the narrower, rarer
capability unreachable through the policy object that renders user-visible
markup.

**Where this app's own sinks actually are, tracing through the prior
facets rather than guessing generically:**
- **Static shell HTML / the inline bootstrap script (2026-07-17):**
  build-time-static, hash-listed in CSP, never assembled from a runtime
  string. No TT sink is touched here at all. That confirms 2026-07-17's
  framing of this content as an immutable build artifact. It is not
  something this facet needs to add machinery for.
- **Web Component render paths (this vision's default stack per
  `magic-frontender.armed.md`):** the real, load-bearing sink. Vanilla Web
  Components re-rendering on data change is the idiomatic no-framework
  pattern for "update the DOM to match new state". The common hand-rolled
  way to do that is a template-literal string assigned to
  `shadowRoot.innerHTML` — exactly the sink TT guards. This is the one that
  needs a policy and a wrapper, not an occasional exception.
- **Stale-while-revalidate list/read views (2026-07-15):** the actual
  dangerous data flow. API JSON can carry attacker-controlled content on any
  endpoint rendering user-generated text, and it flows into a component's
  re-render. This is the textbook stored-XSS path TT exists
  to close. This vision's own caching strategy puts fresh
  untrusted data on the render path continuously. That holds on every SWR background
  refresh, not just on initial load.
- **The SW "update available" toast (2026-07-15):** dynamically inserted
  DOM, but its content is app-authored (a fixed string plus maybe a version
  number), not data-derived. Low risk, yet it still goes through the same
  wrapper for consistency. Better that than a special case that later
  drifts to accept real data.
- **The postMessage credential handoff (2026-07-16):** not a TT sink at
  all. The payload is consumed as data, a token value, and never written to a
  DOM sink or executed. This mirrors 2026-07-17's finding that CSP doesn't
  govern this channel either. Both facets land on the same boundary from
  different angles. That is a useful cross-check that the boundary is real,
  not an artifact of either analysis alone.

**The wrapper, not raw `createHTML`, is what call sites should use.**
Expose one tagged-template helper, an `html` tag function, built on top of
the `shell-render` policy. It follows the spirit of `lit-html`'s approach
but stays hand-rolled and dependency-free. Static template strings are
trusted by construction, since they're source code and not data. Only the
interpolated `${...}` values need handling. The safest version of this
wrapper never lets an interpolated value contribute *structural* HTML at
all. It escapes every interpolation into a text node, with
`&amp;`/`&lt;`-style encoding. A component that genuinely needs to render
pre-sanitized rich HTML calls a separate, explicitly-named
`renderTrustedRichText()` path. That path runs an actual sanitizer before
`createHTML`. Such a need is rare; a markdown-rendered comment body is the
realistic case. Do not collapse both into one "just sanitize everything" helper. A sanitizer
bug in the common case, plain text interpolation, then shares blast radius
with the rare case that actually needs one. Keep
them visibly distinct at the call site.

**Rollout path: Report-Only first, and expect it to be noisy in a
no-framework codebase.** `Content-Security-Policy-Report-Only:
require-trusted-types-for 'script'`, paired with `report-to`, surfaces every
unmarked sink write without breaking anything. `report-to` is already this
app's telemetry channel, per 2026-07-17's pass. Noise is the point here.
This stack has no framework absorbing `innerHTML` calls into a single
reviewed code path. Expect the first Report-Only pass to surface call sites
scattered across every hand-rolled component, not a tidy handful. Flip to
enforcing only once that report stream is empty for a sustained period. A
remaining hit is acceptable only as a deliberately-accepted, named exception
routed through the rich-text path above. The exit criterion is the signal,
not a fixed calendar date.

**SW-side scope: narrower than it first appears.** A service worker has
no DOM, so the `innerHTML`-class sinks don't exist inside it at all.
`require-trusted-types-for 'script'` on the SW's own response mainly matters
there for the `eval`/`Function`/`importScripts` sinks. 2026-07-17's "SW gets
its own explicit CSP" finding already mandates that directive. This
vision's stack already avoids dynamic `eval` and string-based
`importScripts`: no bundler-injected dynamic eval, no runtime dependency
loading. So it satisfies this without new work. Keep the directive on
regardless, as a structural guarantee against a future dependency quietly
introducing one of those patterns. It is not there because today's SW code
needs fixing.

**Progressive enhancement applies here too, same principle as
`beforeinstallprompt` (2026-07-16) and the offline-fallback UI
(2026-07-15).** Trusted Types is not universally shipped; Safari has not
implemented it as of this pass. The sanitizing and escaping behavior inside
the `html` wrapper must hold on every browser regardless of TT support.
Feature-detect `window.trustedTypes` and register the policy only when
present. Never make the wrapper's actual escaping logic conditional on that
detection. TT is the enforcement backstop that upgrades "we wrote the
escaping correctly" into "the platform refuses to let us ship it wrong".
It is not itself the source of the safety property. The design should not
degrade silently on browsers where the backstop is unavailable.

**Open threads for future passes:**

- Shell-size performance budget, next in the queued order.
- Step-up or re-authentication UX for a 401 on outbox replay, carried from
  2026-07-16.
- `related_applications`/`prefer_related_applications` and `launch_handler`
  client-mode, carried and still unaddressed.
- New from this pass: which concrete sanitizer implementation backs the rare
  `renderTrustedRichText()` path. Hand-rolling HTML sanitization is its own
  well-known trap. This vision's dependency-minimalism default, 2026-07-15's
  Workbox reasoning, shouldn't be applied reflexively here. A sanitizer is
  one of the few dependency classes where a small, battle-tested library is
  likely the more defensible choice than hand-rolled code. Not resolved
  here; flagged for the pass that gets concrete about it.

---

## 2026-11-06 — Facet: The Precache Budget — Shell Size, Quota and Install Integrity

The shell-size performance budget was the last unworked open thread from
2026-07-15. This pass finds it is not mainly a speed budget. The precache list is
one all-or-nothing install transaction, and it draws on the same origin quota as
the outbox. Size gates correctness and durability before it gates speed.

**The install transaction is the real gate, and it fails silently.**
`cache.addAll` is transactional: if any request fails, nothing is committed and
the promise rejects. A 2016 spec change made a non-`ok` response fail the whole
call with the cache unmodified, and Chromium commit `d8a95558a04` implements it.
The lifecycle consequence below is reasoned from the spec, not measured here. A
rejected install marks the installing worker `redundant`, and the previously
active worker keeps serving. So an oversized or partly unreachable precache does
not degrade the app. It freezes it at the last version that installed, silently,
for every user who hits it. On a first install there is no previous worker, so
the user gets no offline route at all.

Two failure inputs are ordinary rather than exotic. One precache URL returning 404
or 500 does it, such as a renamed chunk file the manifest generator missed. Quota
exhaustion during the install write does it too, and the spec throws
`QuotaExceededError` there. A budget controls the first. The second is a quota
question, handled below.

**Two budgets run on two clocks, and one number cannot serve both.** The vision's
"lazy-load what isn't needed immediately" rule governs runtime chunks, not the
precache list. The precache is fetched eagerly at install. Every user pays it on
every `CACHE_VERSION` bump, in the background after first paint. Launch cost is
paid on every launch. Navigation is network-first with a ~3 s timeout
(2026-07-15). On the happy path fresh HTML comes from the network and hashed
assets come from cache. The install payload then sits off the critical path of
first paint almost always. An oversized precache barely touches perceived launch
speed, while it does cost install success rate and quota. That inversion is the
argument for a low ceiling.

**The offline route puts a floor under the same number.** 2026-07-15 made the
offline fallback a real route: the cached shell mounted against last-known data,
with writes queued. Trim the shell until it cannot mount real UI and that route
becomes the static "you're offline" page the same facet forbade. The floor is the
shell's own critical path: its HTML, its CSS, and the JS its first render needs. A
budget below the floor is a correctness defect, not a fast build.

**What belongs in the install transaction is a product decision, stated as one.**

- **In.** Shell HTML, its CSS, the JS for the shell's first render, the offline
  route's own dependencies, the logo, and the manifest.
- **Out, cached on first use instead.** Every route chunk the offline route does
  not need. Each becomes offline-available only after one online visit, through
  the runtime cache.
- **Out, and separate.** Images and media, which go to the size-capped media cache
  from 2026-07-15.
- **Out, by default.** Web fonts. The native-first stance makes a system stack the
  default, and a webfont is often the largest single item in a shell precache.
  Where a brand font is required, subset it, precache one weight, and use
  `font-display: swap`.

A route left out is not available to a user who has never been online in that
route. For most apps that is correct. For an app whose whole promise is offline
use it is not. Those routes then belong in the transaction, with the cost accepted
knowingly.

**The quota is shared with the outbox, so the budget reserves from the user's own
work.** Cache Storage and IndexedDB draw on one per-origin quota. In this vision it
holds the shell precache, the runtime asset cache, and the media cache with its
bookkept eviction. It also holds the 2026-07-16 outbox of unsaved writes. An
unbounded precache can starve that outbox on a full device. The failure is not a
slow app. It is a write that cannot be queued, or an install that cannot complete.
Two rules follow. Read the real quota with `navigator.storage.estimate()` and never
assume a figure. Catch `QuotaExceededError` on every cache write, the install write
included.

**Safari makes installation part of the budget, which links back to facet two.**
WebKit's ITP deletes all script-writable storage for an origin after seven days of
Safari use without user interaction (WebKit, ITP 2.3). A home-screen web app's
first-party domain is exempt (WebKit, CNAME cloaking, `webkit.org/blog/11338`). An
uninstalled app can lose its precache and its pending outbox entries to that
timer. An installed one does not. Installation is therefore a durability
requirement for anything this vision queues offline.

**Version bump cost, and an amendment to 2026-07-15's single-version rule.** Every
`CACHE_VERSION` bump re-downloads the whole precache for every user. That is the
direct cost of the ceiling, and it argues for a small list rather than a cleverer
bump. It also wastes work. Fonts, a vendor script and the logo rarely change, yet
they re-download on every release. Their cache name derives from a constant that
changes with app code. 2026-07-15 said every cache name derives from
`CACHE_VERSION`, and that `activate` deletes anything else. Split the precache
into two tags, both derived from one build.

- `app-${CACHE_VERSION}` holds shell HTML, app JS and app CSS, and bumps every
  release.
- `static-${STATIC_VERSION}` holds fonts, vendor files and the logo, and bumps
  only when the contents of that set change.

The `activate` prune keeps a cache matching either current tag. The 2026-07-15
reasoning is otherwise intact. A CSP change still bumps `CACHE_VERSION`, and the
CSP-bearing navigation response stays in the `app-` cache. The original paragraph
stays as written, with this section as the pointer.

**The instrument measures the build, not the runtime.** Resource Timing is the
obvious choice and the wrong one. A response served by the service worker from
Cache Storage is not a network transfer. Its `transferSize` reads 0, so the
instrument reports nothing for exactly the resources the budget is about. The same
three fields read 0 for a cross-origin resource without a `Timing-Allow-Origin`
header (Resource Timing, "Cross-origin Resources"). A third-party asset then
counts as zero bytes. Measure the build output instead, from the exact URL list
the `install` handler will fetch. Sum `encodedBodySize` as served, compressed.
Report compressed and uncompressed separately, because raw bytes under-report by
roughly five times. Resource Timing still serves the launch clock: navigation
start to first render on the cached path.

**A starting envelope, each figure a default rather than a measurement.**

- **Shell JS, compressed: at most 170 KB.** Osmani's *Cost of JavaScript in 2018*
  puts a mobile budget under 170 KB minified and compressed, about 0.7 MB raw. The
  figure and the hardware behind it are old. Treat it as an order-of-magnitude
  anchor for parse cost, and re-derive it from the project's device tier. JS is the
  expensive part per byte, so it gets the tight number.
- **Whole precache, compressed: at most 300 KB.** That is 2.4 Mbit, about 6 s of
  install wire time on a 400 kbit/s link inside a background task.
- **Precache floor: the shell's render critical path.**
- **Media cache: a share of measured `quota`,** sized from `estimate()` after the
  precache and outbox reservations.
- **Outbox: reserved and never negotiated.** Unsaved writes outrank every cache.

**The gate, and the check that would refute this.** The budget is enforced in CI
against the built precache manifest, because a budget without a gate is a wish.
Before trusting the gate, show it failing. Add a 50 KB asset to the list and watch
the build refuse. A gate never seen to fail is not evidence. The central claim is
that precache size drives install integrity and quota pressure far more than
perceived speed. The experiment that would refute it doubles the precache and
measures both clocks on a throttled profile. First render on an installed app
should barely move. Install completion time and failure rate should roughly
double. If first render moves as much as install time, the framing is wrong and
the budget belongs on the launch clock.

**Open threads for future passes:**

- Step-up or re-authentication UX for a 401 on outbox replay, carried from
  2026-07-16.
- `related_applications`/`prefer_related_applications` and `launch_handler`
  client-mode, carried from 2026-07-16.
- The concrete sanitizer behind `renderTrustedRichText()`, carried from 2026-07-20.
- New: how prefetching a not-yet-precached route interacts with the outbox drain.
  Both are background network work, and neither is prioritised against the other.
- New: whether `STATIC_VERSION` should also anchor the media cache's eviction
  bookkeeping.

---

## 2026-11-06 — Amendment to the Trusted Types facet: the backstop is Baseline now

The 2026-07-20 facet closed on a premise that has since changed. Its
progressive-enhancement paragraph said Safari had not implemented Trusted Types,
and built three conclusions on that footing. The design in that section stands
unchanged. What changes is the scope of its guarantee and one exit criterion.
This section therefore amends in place and leaves the 2026-07-20 text untouched,
as the file's own header requires.

**The stale premise, stated once.** The 2026-07-20 section says:
"Trusted Types is not universally shipped; Safari has not implemented it as of this pass."
That was true when it ran. It is false now. Safari 26 shipped the API, Firefox 148
shipped it on 2026-02-24, and Chrome and Edge have had it since 83.
web-platform-dx lists Trusted Types as Newly Available from 2026-02-24. The only
engines still without it are older releases of each.

The evidence behind those versions came from search results rather than from the
compatibility tables themselves. MDN and caniuse sit outside this session's URL
allowlist. Several independent sources agree on each figure, and the reader of
this note has the browser matrix in front of them. Treat the clause as a
secondary-source finding until one of those tables confirms it directly.

**The Report-Only exit criterion was measuring a narrower audience than it
claimed.** The 2026-07-20 rollout says to flip from Report-Only to enforcing once
the violation stream empties. On an engine with no Trusted Types support,
`window.trustedTypes` is undefined, no policy is registered, and a guarded sink
never throws and never reports. Those browsers were silent because they were
unenforced, not because they were clean. Under the old premise the stream could
empty while Safari and Firefox passed every unmarked `innerHTML` write. The
criterion is sound only once the audience is covered, and now it is. Re-read the
stream before flipping: an empty stream found before 2026-02-24 is unproven, and
carries no weight toward the decision.

**The feature-detect stays, and its reason narrows.** The 2026-07-20 section says
to feature-detect `window.trustedTypes` and register the named policies only where
it exists. Keep that rule. It now covers older engines rather than a whole major
engine, which is a smaller job than it looked. The half of the rule that must not
move is the other one: the `html` wrapper's own escaping never becomes conditional
on the detection. The safety property is the wrapper's escaping. The platform
backstop is what upgrades "we wrote the escaping correctly" into "the engine
refuses to let us ship it wrong".

**Enforcing is now worth reaching for, not merely safe to defer.** The section
called Trusted Types the enforcement backstop on that same upgrade. On a
Chromium-only footing the upgrade applied to one engine. The enforcing policy was
then one browser's belt on top of braces the code already wore everywhere else.
It now applies to every engine this app targets. That moves an enforcing policy
from polish to a structural guarantee the stack can rely on. It is also what
makes the effort of clearing the Report-Only stream worth spending.

**What this note does not change.** The `renderTrustedRichText()` sanitizer
question stays open. The ban on a `'default'` policy stands, and the reason given
for it now covers more engines rather than fewer. The service worker's own CSP
requirement from 2026-07-17 stands, since Trusted Types inside a worker still
reaches only the `eval`, `Function` and `importScripts` sinks.

---

## 2026-11-09 — Facet: Step-Up and Re-Authentication on a 401 During Outbox Replay

Picking up the second thread 2026-07-20 carried. 2026-07-16 opened it when it found
that a replayed mutation can come back 401. That facet settled who holds the
credential and how a drain gets one. It did not settle what the app does with the
entry when the answer is "not this credential". This pass works that half, because
the wrong answer deletes a user's unsaved work or, worse, replays it under someone
else's session.

**A 401 is a family, not one event, and the right move differs by member of it.**
The outbox sees four statuses that all look like "the write did not land". They are
not interchangeable.

- **401 with `invalid_token`.** The credential is stale or expired. A refresh may
  fix it, with no user involved.
- **401 with `insufficient_user_authentication`.** The credential is valid, and the
  authentication event behind it is too old or too weak for this resource. RFC 9470
  defines this challenge, carrying `acr_values` and `max_age`.
- **403.** The server knows who the caller is and refuses. Neither a retry nor a
  fresh login changes that.
- **409 from an idempotency key.** The key was seen before with a different body.
  The entry is stale against a newer edit, and replaying it harder cannot help.

RFC 9110 requires a 401 to carry `WWW-Authenticate`. So an app that cannot tell which
401 it has is looking at a server that broke its half of the contract. It may also be
looking at a header a proxy stripped. Neither is an auth failure the app should paper
over, and both are worth a distinct metric.

**The entry enters a held state, and held is not deleted.** A 401 on replay moves the
entry from `pending` to `needs-auth`. Its payload, its idempotency key and its
enqueue timestamp stay. The index keeps it and the UI can count it. Deleting on 401
is the same fault 2026-07-16 already named for a voluntary logout. The reason is
identical: the write was the user's, and the app owes them a decision rather than a
silent loss. The reverse error is just as bad. Leaving it `pending` means the drain
retries it on every reconnect. One refusal then becomes a loop that costs the user
battery and the server traffic.

**A `needs-auth` entry blocks its own line, and nothing else.** Replay order matters
within one resource and does not matter across resources. A create followed by an
update on the same record must land in that order, or the result is a record with the
wrong fields. An unrelated record's write can drain happily meanwhile. So the queue
is ordered per entity key, and one blocked entry stalls exactly its own line. A
global FIFO would freeze the whole outbox behind one 401, which is how a small auth
blip becomes "nothing syncs".

**A step-up is not a re-login, and the challenge says which one is wanted.** The
reflex on any 401 is to throw the user at a login screen. That discards a working
session to satisfy a narrower requirement. On a shared device it may also hand the
pending entries to a different person. RFC 9470 exists because a resource can ask for
a higher assurance level or a fresher authentication without demanding a new
identity. So the rule is to read the challenge the server sent. Pass `acr_values` and
`max_age` through to the authorization request unchanged, and let the authorization
server decide what satisfies them. An app that invents its own policy for when a
step-up is needed duplicates a decision the server already owns. It will disagree
with the server eventually.

The one case that is genuinely a re-login is `invalid_token` that a refresh cannot
fix. Then the session is gone, and the entry needs a full sign-in before it can
replay.

**Who can act, and therefore who must be interrupted.** The service worker holds no
long-lived secret (2026-07-16), so it cannot perform a refresh or a step-up by
itself. A `needs-auth` entry can only drain while a client is present to run the flow
and hand back a fresh credential over `postMessage`. That constraint fixes the UX. A
401 arriving in a background drain at 03:00 is not a user action. It must not raise a
modal into a tab nobody is looking at. A 401 answering a write the user just
performed is a user action, and deserves an inline error at the control that produced
it. The discriminator is whether a synchronous request is waiting. Both paths end at
the same surface: a persistent affordance that says how many writes wait, and one
explicit action that opens the flow.

That affordance follows the `beforeinstallprompt` reasoning from 2026-07-16. Render
it from state the app already knows, never gate it on an event that may never fire.
Never make it dismissible into invisibility while entries remain held.

**Order the discard decision in favour of the user, and make it explicit.** Three
outcomes end a `needs-auth` entry.

- **Replay after a fresh credential.** The normal case. Send the entry with its
  original idempotency key, so a duplicate is the server's job to reject.
- **Discard, on the user's own instruction.** The user is told what will be lost and
  says so. Never on a timer, and never because the payload looks stale.
- **Supersede.** A 409 whose body mismatched says the server has a newer version.
  Show the user both versions and let them choose. An outbox that silently picks one
  turns a merge into data loss.

**The idempotency key is minted at enqueue, not at replay.** This is the load-bearing
detail of the whole retry path. A key created at replay time protects nothing,
because the duplicate was created by the first replay. Mint it when the entry is
queued, store it with the entry, and reuse it across every attempt including the one
after a step-up. A server that expires its key window, commonly after a day, forces
one more rule. An entry older than that window is not safe to blind-replay as a
mutation. Surface its payload to the user for a fresh submit instead, and say why.

**The 401 path must not become a hiding place for a protocol bug.** A 401 during
replay has at least one cause that is not authentication at all. If a reverse proxy
behind a TLS terminator rewrites the scheme to its own listening scheme, the app
publishes `http://` self-URLs. The redirect to `https://` is then cross-origin, which
drops the `Authorization` header and turns a POST into a bodyless GET. The observable
symptom is an authentication failure. The cause is a scheme. An outbox that logs only
"401 on replay" will point every reader at tokens, and the real fault will survive a
token rotation. So the replay's failure record carries scheme, host and status code
together. A cluster of 401s that begins at the same minute as a deploy is a protocol
or routing finding, not an auth one. It should be reported that way.

**Observability, with the payload kept out of it.** Three numbers make this operable.
Count held entries per state. Report the age of the oldest `needs-auth` entry, since
an entry held for days is a user who does not know their work is stuck. Count 401s on
replay by challenge `error` code, because the four members of the family want
different fixes. Log the entry id, the entity key and the timestamp. Never log the
payload or the credential. A violation report and a replay failure are both
telemetry: fire and forget, dropped when offline, never queued into the outbox they
describe.

**What would refute this facet.** The claim is that a held entry blocks only its own
entity line. With an explicit user decision, that keeps the user's work and their
session. The experiment that would refute it replays a create-then-update pair on a
throttled profile. The 401 hits the create. One unrelated entity writes at the same
time. The expected result is the pair landing in order after the step-up, and the
unrelated entity never stalling. If the unrelated entity stalls, the per-entity
ordering is not doing what this facet claims.

**Open threads for future passes:**

- The shared-device case. 2026-07-16 prunes entries on a login or logout transition.
  It does not settle what the UI shows when a different person signs in and the
  pruned entries belonged to someone else. Is a discarded-writes notice owed to the
  person whose work it was, and how does an app deliver it?
- A non-interactive client. A server-side or headless caller of the same API has no
  step-up surface, so it needs the challenge answered out of band. Not resolved here.
- The proof a given authorization server honours `acr_values`. RFC 9470 says the
  server advertises `acr_values_supported` in its metadata. Whether this app should
  refuse to configure a step-up without that signal is open.

---

## 2026-11-10 — Facet: The Sanitizer Behind renderTrustedRichText()

Picking up the thread 2026-07-20 left open at its own end: which concrete
implementation backs the rare rich-text path. That facet expected a small,
battle-tested sanitizer library over hand-rolled code. The platform has since
moved the question. `Element.setHTML()` is now part of the HTML specification as
a sanitizing sink, and it removes XSS-unsafe markup by default.

Twenty-four measures of engine source and test-suite runs sit behind this
section, taken between 2026-11-09 06:45Z and 2026-11-10 00:20Z. Each version
below was read from an engine tag, a release record or a run report. No support
table was quoted as evidence. Where a claim rests on two mechanisms rather than
a run, the text says so.

**The plain-text wrapper stays the only default path.** 2026-07-20 settled that,
and nothing here moves it. The `html` tagged template escapes every
interpolation into a text node. A component that renders ordinary content never
reaches a sanitizer at all, at any engine version.

**This pass runs last, and its security floor is dated.** The dependency answer
inverted, so the safe sink replaces the library on two engines. The shell-size
budget landed on 2026-11-06 and the step-up facet on 2026-11-09, so neither is
open here.

**On two engines the safe sink replaces the library, and that inverts the
dependency argument.** 2026-07-20 argued that a library beats hand-rolled code
on this surface. That argument now cuts the other way for the API's first year,
because the engine's sanitizer is the newest code in the stack.

Two published bypasses make the point concrete. CVE-2026-7939 covers Chrome
before `148.0.7778.96`. Its record names no mechanism, and the reading that
matches Chromium's own fix is a custom element callback running during the
sanitizing parse. CVE-2026-16394 covers Firefox before 153, and it needed a
configuration that re-allowed `<base>`. So this facet states a floor, and not a
capability check.

**The configuration is a closed constant in the module, never a parameter.** That
one rule is what lets the Chrome floor stay at its CVE build.

- No `<base>` in the configuration, and no caller supplies one. Chrome only
  started stripping `<base>` at `152.0.7977.42`, so at 148 the engine would keep
  an element a configuration allows.
- The configuration is frozen beside the policy name, and a call site chooses
  the path, never the config.
- A richer list is a dated measure and a review, per the section below.

**Three floors, one per engine, because a single number is wrong on two of
them.**

- Chrome desktop: `148.0.7778.96`, the first stable 148 build, May 2026.
- Chrome on Android: `148.0.7778.168`, a later patch of the same milestone.
- Firefox: 153, which strips `<base>` whatever a configuration asks.
- Safari: no floor, because there is no sink to floor. Safari 27.2 fails 72 of
  72 subtests of `sanitizer-config.html` with `Can't find variable: Sanitizer`,
  and answers `div.setHTML is not a function` in `sethtml-tree-construction.html`.

A capability test on `setHTML` alone is the mistake this list prevents. Firefox
148 to 152 ships the method and carries a vulnerable configuration path.

**Safari degrades to the escalated path, and that escalation now exists there.**
2026-07-20 recorded that Safari had no Trusted Types, so a `setHTMLUnsafe()`
fallback had nothing to stand on. That premise is stale: Safari 26 shipped it on
2025-09-15, and Firefox 148 finished it on 2026-02-24. The 2026-11-06 amendment
records the same correction and states what it changes.

It still gives Safari no rich-text path. `setHTMLUnsafe` there takes one
parameter, so neither a sanitizer nor `runScripts` can be passed. A named policy
with `createParserOptions` has no argument to vet. Safari stays on escaped plain
text.

**The safe sink is not a Trusted Types sink, so the common deployment needs no
policy at all.** `setHTML` and `parseHTML` are absent from the sink set that
`require-trusted-types-for 'script'` guards. That is read in the HTML
specification's IDL, in Blink's `element.idl` at 157 and in Gecko's
`Element.webidl`. So the `'default'` policy ban from 2026-07-20 costs nothing
here. Only `setHTMLUnsafe` needs a policy, and that path is unavailable today.

**The facet states its own element and attribute list, and does not inherit the
specification's default.** The default is a real allow-list, and the two engines'
vendored copies were diffed row by row and attribute by attribute. They agree
completely, because Gecko's generator fetches its input from the specification's
own source. Adopting it wholesale is still wrong for this app, for three
reasons.

- It leads with a MathML `a` row that no shipped engine carries, so the
  specification and both engines disagree at the first row.
- Seven of its admitted attribute names are CSS properties, and each takes a
  `<url>` in its value grammar. `img-src` governs each fetch, so none of them is
  a CORS control. A kept `cursor` is a no-cors GET that may carry the page's
  cookies, and no script can read it back.
- It drops `class`, `id`, `style`, every `aria-*` name and every form control.
  So styling and accessibility have to live on the wrapper.

So the facet carries a closed list of its own, and each addition to it is a
dated measure rather than an edit in passing.

**The element list keeps no element that fetches, and no custom element name.**

- No `link`, `base`, `img`, `iframe`, `video`, `audio`, `source`, `picture`,
  `object`, `embed`, `script` or `template`.
- No custom element name at all. That removes the registry-preservation floor,
  which is Chrome `158.0.8127.18` on Mac and Windows, with no Firefox or Safari
  answer.
- No `<a>` carrying `target`. Navigation stays in the tab it started in, and a
  rich-text path is where a `target="_blank"` would otherwise arrive from data.
- A closed declarative-shadow-root list of two names. Gecko's `setHTML()` never
  attaches a root, so one configuration is a shadow tree on Chromium and none on
  Firefox.

**A sanitizer is a markup policy, not a URL policy, so the scheme list is the
facet's own.** The engine strips `javascript:` over five element-attribute pairs
and a MathML `href`. It reads nothing else. The test suite asserts that a
`data:` URL in an SVG `xlink:href` survives sanitizing, in a group named
`allowed`. So no engine at any version stops one.

The facet carries a closed scheme allowlist on every link target at render time:
`https:` and `mailto:` only. Nothing else resolves, and nothing else is written
into generated markup. A public URL in rich text carries `https://`, the same
rule the rest of this vision applies to a self-URL or a redirect target.

**`cite` is the attribute to watch, because no engine inspects it.** It is
default-allowed on `blockquote`, `del` and `ins`, it holds a URL, and it sits in
neither the navigating nor the animating list. Page code that turns `cite` into
a link is the script path. So the facet keeps `cite` out of the rich-text
attribute list.

**The parse runs once, and the sanitizer is the parse.** Mutation XSS survives a
correct first sanitization when the DOM changes afterwards. So the path builds
its DOM from the sanitizer's own output and never re-serializes it through
`innerHTML`. A later write of already-rendered markup is a new sink and a new
review.

**The floor is checked by behaviour, and the check fails closed.** Capability
comes first: no `Element.prototype.setHTML` means no rich-text path, whatever the
user agent says. The floor comparison follows, and it is the weak half.

- Chromium exposes `navigator.userAgentData`, so its floors compare against the
  platform and the full version, not the reduced one.
- Where no such structured API answers, the floor reads the frozen user-agent
  string. That is a shape check, and the weaker of the two.
- An unparsable or absent version is below the floor, and is never assumed above
  it.

An engine below its floor gets escaped plain text, and the caller is told. A
rich-text caller that cannot run does not fall back to `innerHTML`, and it does
not silently strip its way to plain text.

**Rollout is Report-Only first, and the exit criterion is the report stream.**
2026-07-20 already set that for Trusted Types enforcement, and it carries over.
This facet adds one gate. The rich-text path ships behind an explicit
per-call-site opt-in. So an empty report stream means only that the path is
sound, and not that data reaches it.

**What this facet changes in an earlier one**, stated here because that section
stays as it was:

- 2026-07-20 called Trusted Types not universally shipped, and Safari short of
  it. Both became false in 2025 and 2026, and Safari needs no sink either. The
  2026-11-06 amendment amends that premise and leaves the 2026-07-20 text as it
  stands.
- Its expectation of a small sanitizer library as the likely answer is
  superseded by the floors above. A library is still the answer where a floor
  cannot be met.

**Open threads for future passes:**

- `related_applications`/`prefer_related_applications` and `launch_handler`
  client-mode, carried and still unaddressed.
- New from this pass: whether a rich-text caller may ever keep an image, and
  under which attribution and caching rules. An image needs `src`, a scheme
  entry and a media cache policy, so it is its own pass.
- New from this pass: what the wrapper does with a large interpolated document.
  The escaping path is linear in content, and 2026-07-15's refresh sets how often
  a component re-renders it.
---

## 2026-11-11 — Facet: The Native-Standards-First Stack, Its Real Costs, and Where It Stops

The last uniterated facet in this vision's own list. Every prior pass
assumed the stack without arguing for it. 2026-07-20 built the whole Trusted
Types argument on the absence of framework auto-escaping, and the precache
budget treats the shell's JS as hand-written. This pass states what the
native-first default is a bet on, what it costs, and the four places where
hand-rolling is the wrong call.

It decides no framework and no library. It gives the procedure that decides,
and the evidence each decision needs.

**What the default is a bet on.**

Native-first is not minimalism for its own sake. It is a bet on three things,
and it fails if any of them is false.

- **The platform's guarantees are stronger than a library's conventions.**
  A browser refuses to run a script that violates SRI. A Trusted Types policy
  is enforced at the sink. A CSP is enforced by the engine. A framework's
  escaping is enforced by the framework's own code being correct and being
  used. This is the same soft-boundary-versus-hard-boundary distinction
  2026-07-16's architect response drew for origins, and 2026-07-20 drew for
  the `'default'` Trusted Types policy.
- **The primitives already exist.** A component model, a reactive surface, a
  router, a form control and a scoped style system all ship in the platform
  now. Reaching for a dependency to get one of those is buying something
  already present.
- **The bug surface you own is smaller than the bug surface you inherit.**
  The cost of a dependency is not its bytes. It is its update treadmill, its
  own security advisories, and its own rendering model layered over the
  browser's.

The last two are falsifiable per feature, and the sections below falsify them
where they fail.

**The primitives, with their real floors.**

These are the load-bearing native features this stack assumes. The version
figures are reported first-shipped figures, read from caniuse and MDN
summaries on 2026-11-11. They were not measured in a browser in this pass.
The project's own browser floor decides, not this table.

| Primitive | What it replaces | Reported first ship |
|---|---|---|
| Custom elements v1 | a component model | long settled, all engines |
| Shadow DOM and slots | style encapsulation | long settled, all engines |
| Declarative shadow DOM (`shadowrootmode`) | SSR of a shadow root, no JS | Chrome 111, Safari 16.4, Firefox 123 |
| ES modules and import maps | a bundler's module resolution | Chrome 89, Firefox 108, Safari 16.4 |
| `modulepreload` | a bundler's preload manifest | Firefox 115, Safari 17, Chromium figure not recorded in this pass |
| Constructable stylesheets | per-instance `<style>` duplication | Chrome 73, Firefox 101, Safari 16.4 |
| Form-associated custom elements | a form-control shim | Chrome 77, Firefox 98, Safari 16.4 |
| `:has()`, container queries | class-toggling JS, resize observers | `:has()` Safari 15.4 and Firefox 121, container queries Safari 16.0 and Firefox 110, Chromium figure not recorded in this pass |
| `structuredClone` | a deep-clone dependency | Firefox 94, Safari 15.4, Chrome 98 |
| `AbortSignal` in `addEventListener` | `removeEventListener` bookkeeping | contested, see below |
| `AbortSignal.timeout` | a timeout helper | Firefox 100, Safari 16, Chromium figure contested |

The last two rows carry a warning worth stating rather than glossing. The
secondary sources read on 2026-11-11 disagree on the `addEventListener`
`signal` option's Safari floor, and on `AbortSignal.timeout`'s Chromium floor.
One source calls the `signal` option still in development in Safari, and
another lists it implemented in all three engines. Neither was checked in a
browser here. So those rows are marked contested, and the shell feature-detects
both rather than assuming a floor. A support figure two sources dispute is not
a support figure.

**The module graph is the real architectural object.**

With no bundler deciding the load order, three costs appear that a bundler had
been absorbing. All three are load-time correctness problems, not performance
polish.

**Module discovery is a fetch waterfall.** A browser cannot know a module's
imports until it has fetched and parsed that module. A shell whose entry module
imports three modules which each import four costs one round trip per graph
level before any of it executes. That is the classic waterfall, and it is why
a build step was ever wanted.

The native fix is `modulepreload` on the shell's own critical edges, emitted
from the build's module graph. Without it, the shell's cold-start cost is set
by connection latency, not by bytes. That is also the strongest argument
against a very deep component tree in this stack.

**An import map is a hard runtime dependency of the shell, not build
configuration.** A bare specifier the map does not resolve is an immediate,
unrecoverable module load failure. So the map must be present before the first
module script parses. Two consequences follow.

- The import map belongs in the shell HTML, which 2026-07-17 already treats as
  a build-time-static, hash-listed artifact. That is consistent. It also means
  a wrong map is a blank shell until a new `CACHE_VERSION` reaches the client,
  exactly like a stale CSP.
- An inline `<script type="importmap">` collides with 2026-07-17's
  no-inline-script rule. Resolve it as that pass resolved the bootstrap
  script: a content hash in `script-src`, generated at build time. Not a
  nonce, because the shell is cached and replayed.

**Subresource integrity does not cover an imported module by default.** SRI
applies to a `<script src>`, a stylesheet link and a preload. A module reached
through `import` inside another module carries no integrity check unless the
platform is told its hash. `require-sri-for` was never part of CSP3, so CSP
cannot demand it either. Two honest options exist.

- Emit `integrity` metadata in the import map and rely on the browser's
  import-map integrity support. That support shipped in Chromium and Safari per
  the engineering post cited below, with Firefox lagging at the time of
  writing. Verify per project floor before relying on it.
- Otherwise treat graph integrity as a build-time property: content-hashed
  filenames, a checked-in lockfile, and a build that fails when a hash changes
  without a lockfile change.

Neither option is a runtime guarantee on every browser. That gap is worth
naming, because 2026-07-20's Trusted Types argument assumed the platform
enforces its own boundaries. On module integrity it does not do so uniformly,
and the build has to cover the difference.

**What vanilla Web Components actually cost you.**

This is the honest ledger. A framework absorbs each of these. Hand-written
components get them wrong in the same four ways, and every one is a
correctness bug rather than a style preference.

**`connectedCallback` runs more than once.** It fires on every insertion into
the document, and a node can be moved. Setup done there runs again. Any
listener, timer, observer or subscription registered there is duplicated, and
the component now leaks one copy per move.

The rule has two halves. Setup that must run once belongs in the constructor.
Anything that depends on being in the document belongs in a guarded pair with
teardown.

**`disconnectedCallback` is the only teardown hook, and it must be complete.**
Every listener, `ResizeObserver`, `IntersectionObserver`, timer,
`AbortController`, fetch and `postMessage` channel the component opened must be
released there. The cheapest discipline that makes this auditable is one
`AbortController` per component instance. Every listener takes its `signal`,
and `disconnectedCallback` calls `abort()` once. That turns teardown from a
checklist into a single line a reviewer can check.

The `signal` option's support is one of the contested rows above. So a
component keeps one small internal `listen(target, type, fn)` helper. It takes
the signal where the engine honours it, and falls back to `removeEventListener`
where it does not. One helper, one call site per listener, and the teardown
stays one line either way.

**Declarative shadow DOM is a parser feature, so `innerHTML` will not create
one.** Setting `innerHTML` to markup containing `<template shadowrootmode>`
leaves an inert template, not a live shadow root. Only the HTML parser,
`setHTMLUnsafe` and `parseHTMLUnsafe` honour it.

This collides directly with two prior facets. The stale-while-revalidate
re-render path (2026-07-15) patches a component from fresh data, and the `html`
wrapper (2026-07-20) builds strings. Neither may be the mechanism that creates
a shadow root. A shadow root is created once, by `attachShadow` or by the
parser on first load, and then its contents are updated. Naming this prevents
a whole class of "it renders on load and not after a refresh" bug.

**An attribute is the declaration and a property is the reader.** This is this
member's "a declaration is not a reader" rule in a third shape. A component
that reads only its property, and never reflects to an attribute, cannot be
serialised into the server-rendered shell. It cannot be restored from a
form-state snapshot either, and cannot be styled with `[attr]` selectors. A
component that reads only the attribute loses type information, and round-trips
every value through a string.

The rule has two halves. Attributes are the public, serialisable interface.
Properties are the runtime interface. The pair is kept in sync deliberately, by
code a reader can find.

**Styling, and the two rules people get wrong.**

- **Constructable stylesheets are the default over per-instance `<style>`.**
  A `<style>` block inside each shadow root is a separate parse and a separate
  retained ruleset per instance. One `CSSStyleSheet` adopted by every instance
  is parsed once. At a few hundred rows in a list, that is the difference
  between one parse and a few hundred. This is a claim about retained memory
  per instance, so it is also easy to verify with the browser's own memory
  tooling before believing it.
- **The reset does not cross the shadow boundary.** Inheritable properties
  inherit in, and nothing else does. This member's warning against a universal
  `padding: 0` reset is therefore narrower than it looks. Inside a shadow root
  the reset reaches only that root's own elements, which is correct and
  harmless. Outside, the same reset still flattens nested-list indentation in
  light DOM. A shared constructable reset is safe only when it excludes `ul`
  and `ol`, and it must be adopted explicitly by each root.

**Forms are the progressive-enhancement test that actually fails.**

This vision's progressive-enhancement default has a concrete, checkable form.
With no JavaScript, the shell's primary form still submits, as a real HTML
form, with a real `action` and `method` and a real server response.
2026-07-15's offline route depends on this, because the degraded path is the
same page.

A hand-written component that renders a `<div>` with a click handler breaks
that test silently. The native answer is a form-associated custom element,
registered with `formAssociated`. It then joins `FormData`, native validation,
`:invalid` and the browser's own submit path. A component that skips it is
invisible to all four. The test costs one line in review: open the shell with
JavaScript disabled and press submit.

That is the sharpest progressive-enhancement check in this whole vision, and
it needs no browser automation to run.

**Where hand-rolling is the wrong default.**

Dependency minimalism applied reflexively is the failure mode on the other
side. Four things are a trap to hand-write. For each, the reason is the same:
the correct behaviour is a long list of cases nobody remembers.

- **An HTML sanitizer.** The allowlist, the parser differentials and the mutation-XSS cases are years of adversarial work. 2026-11-10's facet already rules on this.
- **ARIA widget behaviour (combobox, dialog, menu, focus trap).** Focus management, keyboard maps and screen-reader quirks are specified behaviour, not preference. A mistake is an accessibility defect.
- **Large-list virtualisation.** Scroll anchoring, dynamic row heights, focus retention across recycling and accessibility-tree consistency are all load-bearing.
- **A rich text editor.** Composition events, IME, undo history and clipboard formats across platforms is the deepest rabbit hole in frontend.

The first row is settled by a prior facet. The other three are candidates, not
rulings, and each is one dependency rather than a framework.

Note what is not on that list, because the platform took it. The platform now
covers date and number formatting (`Intl`), URL parsing, form encoding, deep
clone and clipboard. It also covers HTML sanitising once the Sanitizer API
reaches the whole floor. The `setHTML` gap is why the sanitizer row still
exists today, and it is a gap with an announced end.

**The procedure that decides, and the evidence it needs.**

A framework needs an explicit justification against this default. It is not
banned, and this vision calls no framework good or bad. The justification names
which of these holds, and a proposal without one is not a proposal.

- **A rendering model the team cannot build.** A deep, frequently recomputed
  state graph whose reconciliation is the product's core difficulty. If the
  team would write a diffing engine anyway, use one.
- **A team-scale constraint.** Many contributors, a shared component contract,
  and a review capacity that cannot audit every hand-rolled component's
  teardown. The framework's convention is then worth more than the platform's
  guarantee is.
- **An existing investment** whose migration cost exceeds the lifetime saving.
  Rewriting a working app to remove a framework is its own large change, and
  this vision's `no-regress` default applies to it.

Each justification needs evidence, and the evidence is the same for every stack
question in this vision. Take one real browser run at a named viewport and a
named network profile. Measure the four stages of the budget pass in it:
install, cold-start, first interaction and steady state. A comparison between
two stacks that was never run is not a comparison.

This pass runs no browser. Every figure in it is a reported version or a
reasoned claim, and it says so where it says it.

**Open threads for future passes.**

- `related_applications`/`prefer_related_applications` and `launch_handler`
  client-mode. Carried since 2026-07-16, still unaddressed.
- A concrete ARIA widget and focus-management default for this stack. New from
  this pass, and it is the largest remaining craft gap the vision has named.
- Whether the shell ships a shared constructable stylesheet, and the exact
  reset it carries. New from this pass. It decides the nested-list question for
  every component at once.
- What the shell's own before-first-interaction component set actually is.
  Carried from the budget facet, and it is the input both the JS ceiling and
  the `modulepreload` manifest need.

**Sources used in this pass.**

- Support figures: caniuse and MDN summaries for each row of the primitives
  table, read 2026-11-11. Reported first-ship versions, not measured here.
- Import-map integrity shipping in Chromium and Safari, and the pre-existing gap
  where SRI did not cover imported modules:
  `shopify.engineering/shipping-support-for-module-script-integrity-in-chrome-safari`,
  and the TAG review of import-map integrity at
  `github.com/w3ctag/design-reviews/issues/944`.
- Declarative shadow DOM honoured only by the parser, and not by `innerHTML`:
  the WHATWG HTML parser behaviour as described in the `template-shadowroot`
  polyfill's own feature-detection issue, and the `setHTMLUnsafe` and
  `parseHTMLUnsafe` notes alongside it.
- Sanitizer API shipping status:
  `web-platform-dx.github.io/web-features-explorer/features/sanitizer/`, read
  2026-11-11, showing Chromium and Firefox shipped and Safari blocking
  Baseline.
---

## 2026-11-11 — Facet: The Launch Surface — `launch_handler` and `related_applications`

This closes the thread carried open since 2026-07-16 and named again in every section
after it. The 2026-07-16 architect response already unblocked it. Where the trust test
says one origin, a launch is a single-app question. So it is decided here, and no new
question goes to magic-architect.

**A launch is not a navigation request, and 2026-07-15's resource-class table has no row
for it.** The five classes sort requests the app itself makes. A launch is an entry into
the app from outside its own boundary. It comes from the home screen, another app's
link, a chat client or the OS share sheet.

A launch is also the one entry where no app code is running yet. The offline question is
therefore asked at cold start, with no page state to fall back on. That is what makes it
a facet rather than a corner of the caching work.

**Source and its limit, stated once.** The launch facts below came from search-result
summaries of three pages. They are the Chrome for Developers launch-handler guide, the
WICG proposal and MDN. Those pages and the compatibility tables sit outside this
session's URL allowlist. Treat every version figure and every support claim here as a
secondary-source finding. The 2026-11-06 amendment labelled its own findings the same
way.

**The member holds one field, and that field's value may be a list.** `launch_handler`
currently carries a single sub-field, `client_mode`. Its value is a string or a list of
strings. The WICG proposal's own words are that the first valid value is used. That list
form is the whole degradation mechanism. The recommendation below uses it.

**Three values, three different failure modes.** These are not three settings of one
behaviour. They are three different contracts with the platform, and each fails
differently.

| `client_mode` | What the browser does | What the app owes | Failure when unwired |
|---|---|---|---|
| `navigate-new` | creates a new app window at the launch target URL | nothing | a second app window the user did not ask for |
| `navigate-existing` | navigates the most recently used app window to the target URL | an in-progress-state guard | work in progress is destroyed with no interception |
| `focus-existing` | focuses the most recently used app window and enqueues a `LaunchParams` carrying `targetURL` | a `launchQueue` consumer that routes it | the launch silently does nothing |

**`focus-existing` creates an obligation in the app's own code, and that obligation is a
reader.** The manifest declares the mode. Its reader is
`window.launchQueue.setConsumer`. Nothing else in the platform supplies the navigation.
With no consumer registered, a `focus-existing` launch focuses a window and moves
nothing. The user clicked a link and the app did not move.

That outcome is legal at every layer. It throws nothing, and it reports nothing. It is
the exact fault the armed rule names. A declaration is not a reader, and a declared
value with no reader is a defect rather than a default.

**`auto` is the default when the member is absent, which makes this member safe to
ship.** The Chrome guide gives `{"client_mode": "auto"}` as the unspecified default.
`auto` is the user agent's own choice. An engine that ignores `launch_handler` therefore
behaves as it would with no manifest member at all. This member cannot break a browser
that does not implement it.

That is a stronger degradation guarantee than `beforeinstallprompt` (2026-07-16) or
Trusted Types (2026-07-20) had. Ship it without a support gate.

**Recommendation: `focus-existing` first, `navigate-existing` second, and no
`navigate-new` at all.** The list form makes the ladder explicit as `["focus-existing",
"navigate-existing"]`. The first choice keeps the app's own router in charge and
preserves the user's in-progress state. The second is the honest fallback where a
platform will not hand the URL to script. The user then reaches the target, at the cost
of whatever was in that window.

Leaving `navigate-new` out is a judgement, and this is its criterion. The value opens a
second app window. The vision has already settled on one install identity per origin. An
app that opens its own second window is the one new-window case the navigation rule
would otherwise have to argue about.

Leaving the value out keeps that argument from ever being needed. It also leaves no
ambiguity about which side of the rule this member falls on.

**`navigate-new` is not itself a violation of the navigation rule, and the distinction
matters.** That rule binds the app's own markup and handlers. It covers
`target="_blank"`, `window.open()` and generated links. A browser's launch decision is
not the app opening a tab. The rationale that makes the rule right also makes this
distinction right.

Opening a second window is the user's own gesture, and an operating-system launch is
that gesture. What the app must never do is select `navigate-new` to avoid the consumer
obligation.

**The launch URL is untrusted input, because it arrives from outside the app.** Every
path into the app so far has been the app's own fetch or its own router. A `targetURL`
comes from a chat client, a QR code or another site's link capture. It is
attacker-controllable in exactly the way a query string is. It also reaches the one
moment where no state has been established to compare it against.

**So the consumer parses it and never follows it.** Three controls apply, in order.

- Resolve it with `new URL()` against the app's own origin, and drop a target whose
  origin differs. A cross-origin target is not a route.
- Apply the 2026-11-10 scheme rule here, narrowed to `https:`: a route is never a
  `mailto:` target. Keep a separate constant, because that allowlist also admits
  `mailto:`.
- Route the resolved path through the app's own router. Never assign the string to
  `location`, `location.href` or `location.assign()`.

**That third control has no CSP backstop behind it, which is a third instance of one
pattern.** A navigation assigned from data is not a Trusted Types sink. The guarded set
is the script and markup sinks, not the location setters. It is also not a `connect-src`
question. So the scheme check is the only control on that path.

That check must live in the consumer. 2026-07-17 found the same shape for the
`postMessage` credential handoff. Not every boundary is a CSP boundary. The boundary the
policy does not cover is the one to review by hand.

**The consumer registers once, at shell bootstrap, before the router exists.**
`setConsumer` takes one callback for the window's whole life. So registration belongs to
bootstrap and not to a component. The queue holds an enqueued `LaunchParams` until a
consumer is present. That is what makes early registration safe.

The callback can hand the parsed URL to the router when the router is ready. The router
then need not exist before the launch arrives. One ordering rule follows: handle the
launch, then drain the outbox. The user asked to be somewhere, and 2026-07-16's
credential handoff does not require the drain first.

**The offline launch is where the precache floor and the outbox meet, and it needs a
designed fourth state.** 2026-11-06 put only the shell's render critical path inside the
install transaction. Every other route becomes offline available only after one online
visit. So an installed app can launch offline at a route the user has never opened
online.

The shell then has a view to mount and nothing to mount in it. The answer follows from
two earlier findings. 2026-07-15 made the offline fallback a real route. 2026-07-16 said
never to gate on an event that may not fire.

- The shell mounts, and the requested URL is kept as the pending route.
- The route renders an explicit state that names the destination. It says the
  destination is not available offline yet. It is a page about that destination, not the
  home screen.
- Nothing redirects to the home route, because that loses where the user was going.
  There is no way to recover it.
- The pending route is retried on the next successful navigation or the next `online`
  event. An explicit user dismissal drops it.

**`related_applications` is a listing, and `prefer_related_applications` is its
switch.** The switch must stay off. On Chromium the two behave very differently, and
three independent sources agree. The install prompt offers the web app while
`prefer_related_applications` is absent or `false`. It steers to the store listing when
the value is `true`.

That single boolean reaches back into the durability design. 2026-11-06 found that
WebKit's ITP deletes script-writable storage after seven days of Safari use without
interaction. An installed home-screen app is exempt. So installation is what makes a
queued offline write survive, on that engine.

Turning the switch on trades that durability for a store prompt. The engine that already
guaranteed the least pays that trade. So the rule here is unconditional rather than
per-project. `prefer_related_applications` is `false` or omitted, always.

**A listing with no reader does nothing, and its reader is
`getInstalledRelatedApps()`.** Populating `related_applications` carries no install
redirection of its own. It exists so the page can ask whether a counterpart app is
already installed. That call needs both halves of the relationship. One half is the
manifest entry on this site. The other is a declaration on the other app pointing back.

An Android counterpart declares it through Digital Asset Links. A related PWA declares
it through its own `related_applications` entry. One point stays unchecked, and a later
pass must not assume it. Which key does that pairing match on for a web-app counterpart?
Read the manifest specification before relying on it. This session's allowlist did not
permit that read.

**`related_applications` also carries a product decision this facet does not make.**
Whether the product has a native counterpart is not an architecture question and not a
frontend one. Where there is none, both members stay out of the manifest entirely. An
empty array is a declaration with no reader of its own.

**Telemetry: the install-versus-browser signal from 2026-07-16 covers launcher starts
only.** A captured link is invisible in it. That facet put an analytics parameter on
`start_url`, as the only reliable marker of install-driven traffic. A launch from a
captured link carries the link's own URL instead. The request therefore reaches the
server with no marker, and reads as an ordinary browser visit.

That is reasoned from how `start_url` is used, and not measured. The fix is in the
reader, not the manifest. The launch consumer adds the same marker when it routes a
captured target. Both launch paths then report through one parameter.

**The check that would refute this.** The central claim is that an unwired
`focus-existing` fails silently rather than loudly. Install the app and set
`client_mode` to `focus-existing`. Register no consumer. Launch an in-scope link from a
different app on the same device.

If the window navigates on its own, that platform is supplying the fallback. The
obligation paragraph above is then overstated for it. Run the check on desktop Chromium
and on an Android device. The proposal allows a user agent to support only a subset of
the client modes.

**Open threads for future passes:**

- Whether a rich-text caller may ever keep an image, and under which attribution and
  caching rules. Carried from 2026-11-10.
- What the wrapper does with a large interpolated document, since the escaping path is
  linear in content. Carried from 2026-11-10.
- Whether the launch surface should accept a share-target payload, and under the same
  parse-and-never-follow rule or a stricter one.
- New from this pass: which key matches a web-app counterpart in the
  `related_applications` pairing, to be read from the manifest specification.
---

## 2026-11-12 — Facet: Resource Hints for the Shell's Own Critical Path

The precache budget (2026-11-06) settled what the install transaction holds. It
did not settle how the document announces that same set on the visit that comes
first, before any install has happened. That visit is the only one where a
resource hint can win anything, and it is also the one the vision had not
described. This pass works the shell's own resource hints, from the finding note
filed for it on 2026-11-11.

**A hint is a claim made before the document knows what it needs, and two of the
three mechanisms are unverifiable.** `rel=preload` names one URL and one
destination. `rel=modulepreload` names one module and may or may not pull its
imports. `rel=preconnect` names an origin and asserts nothing at all about a
resource. Each earns a rule about what may make the claim and what a wrong claim
costs.

**The preload map's key omits mode and credentials, so the attribute is part of
the hint's identity.** This paragraph and the next are read from Chromium source
at tag `159.0.8151.0`, through the finding note filed for this pass. No browser
was driven.

The map holds one entry per URL-plus-type key, with the fragment stripped. A
second preload over that URL attaches to the existing entry as an observer and
inserts nothing. What goes out is the first inserted entry's request, never the
consumer's. A mismatch between them is silent, because the mismatch printer sits
past two early returns. So a different `crossorigin` on the same URL costs two
requests at two moments, and timing decides which.

**Fonts are the standing instance, and they are not a cross-origin problem.** A
font is always fetched in anonymous-mode CORS mode. So `<link rel=preload
as=font>` without `crossorigin` announces a request the font loader will never
reuse. The result is a wasted preload and a second fetch of the same file. The
same shape applies to a same-origin font, which is what makes it easy to miss.

The rule follows: a hint is generated from the same build record as the element
that consumes the asset, never hand-written beside it. A hand-written hint
carries its own copy of the mode, and the copy can drift.

**A preload is a fetch directive, so it is governed by the policy of its own
destination.** A preload with `as=script` is checked against `script-src`,
`as=style` against `style-src`, `as=font` against `font-src`, `as=image`
against `img-src`. This is reasoned from the CSP model and not measured here.
Two consequences follow whether or not the detail holds exactly.

- The build's hint list and the build's CSP are one decision, not two. A
tightened directive silently converts a preload into a blocked request.
- This is the concrete reason 2026-11-10 keeps `link` out of the rich-text
element list. An admitted `link rel=preload` buys a fetch its author chose,
before any reader acts on the fragment.

**`modulepreload` carries a module graph the specification only promises to
consider.** The dependency fetch is a "may additionally choose" in the HTML
specification's own wording, not a guaranteed behaviour. A shell that lists its own
`type="module"` script and expects the graph to follow is relying on an option.
The rule is one hint per module the first render needs, enumerated from the
build's module graph. That is the difference between a hint and a hope, and the build already
holds the graph.

**The first visit is uncontrolled, and that is exactly the visit the hint list
is for.** On a controlled page every subresource request passes through the
service worker's fetch handler. A cache-first asset is then answered from Cache
Storage, and the hint's network win collapses to nothing. So the shell's hint
list is built for the uncontrolled first visit, and it is close to harmless on
every later one. That is the opposite trade from the precache, whose bytes every
user pays on every `CACHE_VERSION` bump (2026-11-06).

**An asset in the install set may also be hinted, and the two lists overlap by
design.** On a visit where the install runs, the file is fetched twice for one
render: once by the document's hint, once by `cache.addAll`. The second may come
from the HTTP cache, and this pass did not measure that. On a repeat visit the
install does not re-run, and a cache-first asset is answered from Cache Storage,
so the hint costs nothing.

**`103 Early Hints` moves the claim from the document to the server, and that
moves who owns it.** The hints arrive in an informational response to the
navigation, before the HTML exists. Three things follow.

- The hint list is emitted by two places, unless the build generates the header
snippet too. So it becomes a generated artifact, like the precache manifest.
- A CSP change must reach the early-hints set as well. Otherwise the preloaded
request is refused while the same asset loads later without trouble.
- The offline fallback path has no early hints at all, because the shell comes
from Cache Storage.

So the document's own `link` elements are the floor, and early hints are an
accelerator that may never be the only place a hint appears.

**`preconnect` is the hint that can only cost.** A preloaded resource that never
arrives is a wasted request. A preconnected origin that is never used is an open
socket and a DNS answer nobody reads. So cap it at the origins the critical path
genuinely touches, which in this architecture is the app's own origin plus one
API host. A preconnect to an origin no directive admits buys an idle socket and
nothing more.

**The hint list is the part of the install set the parser cannot find early, and
it is named by membership rather than by a tier.** `PWA-VISION.md` states that set
at its "What belongs in the install transaction" list: shell HTML, its CSS, the JS
for the shell's first render, the offline route's own dependencies, the logo and
the manifest. A hint for a route chunk outside that set is a claim that a lazy
route is needed now, which contradicts the set. So the generator reads that list
and emits one hint per member. A hint naming a file outside it fails the build.
That gives one source and two emitters, and it means the two ceilings cannot
drift apart.

The members that pay are the ones the parser cannot find on its own. The shell's
own `type="module"` script is found by the preload scanner, so a hint on it adds
nothing. What follows needs a hint: the modules the shell's first render imports
beyond that script, and one font subset only where a brand font is precached.

**`fetchpriority` is a one-place claim, and two highs are no priority.** Marking
both the largest-paint image and the shell's `type="module"` script high tells
the browser nothing it can act on. Mark the single resource the largest paint waits for, and let the
rest keep the default. This pass read the attribute's support from secondary
sources and did not measure it. Treat the arithmetic as unfinished, and the
one-place rule as the part that holds.

**What would refute this facet.** The claim is that a generated hint list,
shaped exactly like its consumers, improves the first visit and costs nearly
nothing later. The experiment runs three visits on the named throttling profile.

- A first visit with the list, and one without it.
- A repeat visit through the service worker.
- A visit whose font preload deliberately omits `crossorigin`.

Expect the first visit's largest paint to improve, the repeat visit to stay
flat, and the mismatched font to fetch twice. If the first visit does not move,
the hint
list is paying for nothing. If the repeat visit regresses, the service worker
answers a preload differently from the consumer's own request. That is the
silent-mismatch shape this facet warns about.

**Open threads for future passes:**

- How prefetching a not-yet-precached route interacts with the outbox drain,
  carried from 2026-11-06. Both are background network work.
- Whether `STATIC_VERSION` should also anchor the media cache's eviction
  bookkeeping, carried from 2026-11-06.
- Whether a rich-text caller may ever keep an image, carried from 2026-11-10. A
  kept image needs a scheme entry and a media cache policy of its own.
- What the wrapper does with a large interpolated document, carried from
  2026-11-10. The escaping path is linear in content.
- New: `prefetch` for the next navigation, which is the one hint that has no
  budget line anywhere in this vision. It competes with the install for the same
  connection on the same visit.
- Two rows the finding note left to a browser rather than a source. Whether a
  second preload fires `load` off a no-cors resource whose own CORS request would
  have failed. Which request wins when both arrive in the same parser pass.
