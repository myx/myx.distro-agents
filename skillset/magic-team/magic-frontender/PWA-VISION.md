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
