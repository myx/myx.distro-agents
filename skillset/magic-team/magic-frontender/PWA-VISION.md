# PWA Vision — magic-frontender

A running, cumulative statement of what an ideal PWA architecture looks like,
built one facet at a time across daily iteration passes. Per the skill's
`pwa-vision-iteration` section, each pass picks ONE facet, reasons through it with
systems rigor, and appends a new dated section here. **Do not rewrite or
"clean up" prior sections in a later pass** — if a later facet changes the
conclusion of an earlier one, add a note in the new section that supersedes
or amends it, and leave the original in place with a pointer. This file is a
log of reasoning over time, not a polished spec.

Any point where the reasoning tips from "how do we build this" into
"should this be one app or several" is flagged inline and left for
magic-architect — this skill does not decide macro-architecture questions.

---

## 2026-07-15 — Facet: Offline-First Architecture & Service Worker Caching Strategy

This is the opening facet because almost everything else in the PWA vision
(installability, auth-flow resilience, performance budget) ends up deferring
to decisions made here: what's precached, what's cacheable at runtime, and
how staleness is handled shapes the rest of the app's contract with the
network.

**Stack choice: hand-rolled Cache API, not Workbox, by default.** The caching
strategies below (cache-first, network-first, stale-while-revalidate) are
each under ~15 lines of native `fetch`/`caches` code. Workbox's value is
route-based declarative config and background-sync recipes at scale; for a
single-app SW that's maybe 150 lines of straight code, pulling in a
dependency (and its own versioning/update semantics layered on top of the
browser's own SW update lifecycle) is a cost without a matching benefit.
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
  When offline, queue via the Background Sync API (or an IndexedDB-backed
  outbox with manual retry if Background Sync isn't available) rather than
  silently failing or — worse — writing optimistically to a cache that
  looks like a real response.
- **Images/media:** cache-first with a size-capped eviction policy. The
  Cache API has no built-in LRU/size limits, so this requires manual
  bookkeeping (`cache.keys()` + a timestamp index, trimmed on write) —
  budget for this explicitly rather than letting the media cache grow
  unbounded.

**Cache versioning is a single source of truth, not per-strategy ad hoc
naming.** Embed a build hash into one `CACHE_VERSION` constant at build
time; every cache name for that build derives from it (`shell-${V}`,
`assets-${V}`, `images-${V}`). On `activate`, enumerate all caches and
delete anything not matching current `CACHE_VERSION`. This is the fix for
the extremely common orphaned-cache bug where an old SW's caches are never
cleaned up because cleanup logic lived in the *old* SW's activate handler
and never ran again after that SW was superseded.

**SW takeover should be visible, not silent.** `skipWaiting()` +
`clients.claim()` are useful, but firing them unconditionally on every
install means a long-lived tab can have its SW swapped mid-session while
JS modules already loaded into memory reference an app version that no
longer matches what the SW now serves for new requests — version skew
within a single running session. Prefer: detect `updatefound` /
`controllerchange`, surface an "update available" toast, and let the
update apply on next navigation or explicit user action. Auto-apply is
acceptable for content-only sites where version skew has no functional
consequence; not for a stateful SPA.

**The offline fallback is a real route, not a static "you're offline"
page.** It should be the actual cached app shell, mounting real UI against
last-known data pulled from IndexedDB, with write actions visibly disabled
or queued rather than the app pretending to be online. Treat "offline" as
a degraded application state to design for, not an error page to redirect
to.

**Architecture-boundary flag:** reasoning about per-route SW scoping
surfaced a question this facet can't resolve on its own — if a product has
genuinely distinct sub-applications (e.g., a public-facing app and an
admin console) with different caching/offline needs, does that argue for
separate PWAs (separate manifest, separate SW scope, separate install
prompts) rather than one SW with branching runtime logic? That's a
"one app or several" call — magic-architect's territory, not decided here.
Noting it so a future facet pass (or an architect review) can pick it up.

**Open threads for future passes:** installability/manifest design, auth
flow under an offline-capable SW (token refresh when the network request
itself may be intercepted/queued), CSP posture for a SW-heavy app,
performance budget for precached shell size.

---

## 2026-07-16 — Facet: Installability & Web App Manifest

Builds on 2026-07-15. The manifest and the SW are configured independently
(`<link rel="manifest">` vs. `navigator.serviceWorker.register(url, {scope})`)
but they describe overlapping territory — both carry a notion of "scope" —
and a mismatch between the two is a common source of bugs, so this pass
treats manifest `scope` and SW scope as one coupled decision, not two.

**Manifest baseline, native platform first.** A shippable `manifest.json`
needs, at minimum: `name` + `short_name` (the latter for home-screen label
truncation), `start_url` (should include an analytics query param to
distinguish installed-app launches from browser visits in server logs —
this is the only reliable signal of install-driven traffic), `display`
(`standalone` for an app-like chrome-free shell; `minimal-ui` only if a back
button from the OS chrome is load-bearing; avoid `browser`, which forfeits
installability's main visual benefit), `theme_color` + `background_color`
(background_color paints the flash-of-blank-white window before first
paint/splash, so it should match the shell's actual background, not just
brand color), `icons` (see below), and `scope` (the URL-path boundary
within which navigations stay "inside" the installed app rather than
kicking out to browser chrome).

**The `id` field is not cosmetic — it's the app's durable identity.**
Per current spec, `id` is what the platform uses to recognize "this is the
same app" across manifest edits; if omitted it defaults to `start_url`,
which means changing `start_url` later (a common refactor) silently
creates what the OS treats as a *second* app, orphaning the original
install. Set `id` explicitly and treat it as immutable infrastructure, the
same discipline as the `CACHE_VERSION` reasoning from the prior pass —
both are "this constant, once shipped, can never casually change."

**Icons: ship `maskable` purpose, not just `any`.** Android's adaptive-icon
system crops icons to platform-specific shapes (circle, squircle, etc.);
an icon authored only for `purpose: "any"` gets naively cropped and can
clip a logo. A `maskable` variant needs the safe content inside the inner
~80% "safe zone" of the canvas, full-bleed background to the edge. Ship
both purposes (or one icon entry with `"purpose": "any maskable"` if the
art safely satisfies both) rather than one-size-fits-all. iOS ignores the
manifest `icons` array for the home-screen glyph entirely — it wants a
separate `<link rel="apple-touch-icon">` — so a cross-platform install
target needs both declarations, not just a spec-compliant manifest.

**Splash screens are now mostly automatic, but not uniformly.** Chromium
platforms synthesize a splash screen from `name` + the largest `icons`
entry + `background_color` — no separate asset needed. iOS historically
required hand-authored `apple-touch-startup-image` per device resolution
(a real maintenance burden — a matrix of iPhone/iPad screen sizes); iOS
26 improved this by computing a splash screen from the existing icon and
`theme-color` meta tag in most cases, but the explicit per-resolution
images remain the fallback for pixel-exact control. Net effect: budget for
one shared icon/background pair that works across both, and only add the
iOS resolution matrix if a specific launch appearance is a hard
requirement, not by default.

**`beforeinstallprompt` is a Chromium-only enhancement, not a universal
API — design the install affordance to degrade, don't gate on the event.**
Safari/iOS has never implemented it and there's no signal it will;
installation there is manual ("Share → Add to Home Screen"), full stop.
The correct pattern is progressive enhancement applied to installability
itself: render a persistent, low-friction "Install" affordance in the UI
by default; on Chromium, intercept `beforeinstallprompt` (`preventDefault()`
+ stash the event) and wire that affordance to call `.prompt()`; on
Safari/other browsers where the event never fires, the same affordance
falls back to an in-app instructional overlay ("tap Share, then Add to
Home Screen"). Never build a UI whose only path to installation is
`beforeinstallprompt` firing — that silently loses the entire iOS
audience. This mirrors the offline-fallback principle from the prior
pass: the degraded path is a real, designed UI state, not an omission.

**Scope alignment with the SW design.** Manifest `scope` and SW
registration `scope` should normally be identical and both rooted at the
app's actual boundary — a narrower manifest `scope` than the SW's means
some SW-controlled URLs render as "escaped from the app" (browser chrome
reappears), which undermines the installed-app illusion the prior pass's
offline/caching work is building toward. Practical rule: pick the SW
scope first (driven by the caching-strategy boundaries from 2026-07-15),
then set manifest `scope` to match, not the other way around — the SW's
functional boundary is the one with real behavioral consequences
(what's cached, what's queued offline), so it should lead.

**Sharpening the open magic-architect question (separate PWAs vs. one SW
with branching logic).** This pass found a concrete, load-bearing fact
that bears directly on that question: a single origin *can* serve
multiple manifests at different path scopes (e.g., `/app/manifest.json`
scoped to `/app/` and `/admin/manifest.json` scoped to `/admin/`), so
separate installability is technically available without a separate
origin. But the browser does not treat same-origin, different-scope
manifests as truly separate apps: they still share cookies, localStorage,
IndexedDB, and Cache Storage (the exact storage this vision's offline
design relies on), and link-capturing between the two scopes is
unreliable (a link from the installed public app into the admin path
won't reliably "capture" into the admin app if only the public one is
installed). The practical consequence: if public vs. admin genuinely need
independent installs, independent storage, and independent SW lifecycles
(which the 2026-07-15 pass's offline-needs question was really asking),
same-origin path-scoped manifests do not actually deliver that
independence — a separate origin (e.g., a subdomain) is what actually
isolates them, per current platform guidance. This doesn't resolve the
one-app-or-several call — that's still architect's to make — but it
removes one candidate middle ground: "same origin, two manifests" looks
like a split but functionally still behaves like one app's storage/SW
domain. If magic-architect wants true separation, the decision is
effectively "separate origins" (or accept the shared-storage/link-capture
compromise), not "separate manifests" alone. Flagging this refinement for
architect rather than deciding it here.

**Open threads for future passes:** auth flow under an offline-capable SW
(carried over from 2026-07-15, still open), CSP posture for a SW-heavy
app, performance budget for precached shell size, `related_applications`/
`prefer_related_applications` for products with a native-app counterpart,
`launch_handler` (`client-mode`) for controlling whether a relaunch
focuses an existing window vs. opens a new one — relevant once the
separate-origins-for-sub-apps question above is settled, since it affects
how many installed windows a user juggles.

---

## 2026-07-16 — Architect response: separate origins vs. shared-storage
compromise for sub-app isolation

Answering the question this vision flagged for magic-architect on
2026-07-15 and sharpened on 2026-07-16: same-origin, multi-manifest
setups don't give public and admin sub-apps true separation, so the real
fork is separate origins (hard isolation, lost single-origin
conveniences) versus accepting that they share storage and SW lifecycle.
This is decidable, but not as a PWA question — the PWA layer should
inherit an answer that already has to be given at the HTTP/session
layer, independent of manifests or service workers.

**The decision axis is trust differential, not caching convenience.**
The question to ask is not "would separate origins be cleaner" (it always
would) but "does an attacker or bug executing arbitrary code in one
sub-app's context need to be walled off from the other's storage and
session." Public-facing surfaces carry the larger, less-trusted attack
surface — third-party scripts, marketing tags, user-generated content,
broader unauthenticated input — while "admin" is, definitionally, the
side holding more privileged capability. That asymmetry is exactly the
scenario same-origin isolation cannot provide, because storage
namespacing (prefixing cache names, using separate IndexedDB database
names per section, scoping SW registrations narrowly) is a *soft*
boundary: it's a code convention, enforced only by every future
change respecting it. An XSS payload or a careless refactor does not
respect naming conventions — it executes with the full privileges of
the origin, full stop. A separate origin is a *hard* boundary: the
browser's same-origin policy enforces it, not developer discipline, and
it survives bugs that a naming convention does not.

**Recommendation: when the sub-apps have a genuine privilege/trust
differential (public customers vs. internal/admin operators being the
textbook case), use separate origins — full stop, not "it depends."**
The lost conveniences (single sign-on without extra plumbing,
same-origin API calls without CORS, one SW codebase instead of two, one
install identity instead of two icons) are engineering and UX overhead.
The failure mode from *not* isolating — a public-surface compromise
reaching admin session data, cached admin API responses, or admin SW
state — is a security compromise. Those two costs are not symmetric:
over-isolating costs development time and a slightly less seamless UX;
under-isolating costs the thing the isolation was supposed to protect.
Default to paying the engineering cost. The conveniences lost are also
each independently solvable with known patterns (federated SSO via a
central auth service issuing origin-scoped session tokens rather than a
shared cookie; a thin shared library imported into two separately
bundled SW scripts rather than one shared SW; two install prompts, which
is arguably correct UX anyway if the two audiences are genuinely
different people who should not casually stumble into each other's
app).

**When the split is not a trust boundary, don't fork origins at all —
and don't reach for "shared-storage compromise" either.** If "public vs.
admin" in a given product actually means "logged-out view vs. a
role-gated section for the same user population with no meaningful
blast-radius difference" (e.g., an internal tool where every user is
already equally trusted, or a "seller admin" panel a customer toggles
into for their own store with no elevated systemic privilege), there is
no adversarial boundary to enforce, and separate origins would be pure
overhead — SSO plumbing and CORS bought for zero isolation benefit
against a threat that doesn't exist in that case. There the right fix
is the cheaper one already implied by this vision's SW/cache design:
disciplined per-section cache-name and IndexedDB-name namespacing, and
narrowly-scoped SW registrations, within one origin. That is the
"shared-storage compromise" option, and it's the *correct* choice here —
not a fallback settled for because separate origins were too expensive.

**So this is not genuinely context-dependent in the sense of "reasonable
architects could disagree either way" — it's a lookup on one prior
question.** The fork the caching/manifest work keeps bumping into isn't
a PWA-specific tradeoff at all; it's the same public/admin trust-boundary
question any web architecture has to answer with or without a service
worker in the picture (would this product put admin behind
`admin.example.com` and public on `www.example.com` if neither had a
manifest or SW?). Answer that question first, on its own security
merits. If yes, separate origins, and the PWA layer (separate manifest,
separate SW scope, separate install identity per origin) just falls out
of a boundary that already had to exist. If no — same trust level, no
differential blast radius — one origin, one SW, with careful storage
namespacing, and the "separation" impulse should be redirected at
namespacing discipline, not origin-splitting.

**Concrete note for the "separate origins" branch:** origin means
scheme+host+port. A path-scoped split on one host (what 2026-07-16's
manifest pass already found doesn't isolate) is not an origin split; a
subdomain (`admin.example.com` vs. `app.example.com`) is the minimum
structural change that qualifies, and a fully separate registrable
domain is stronger still (defends against cookie/document.domain-era
tricks and against a subdomain-takeover class of issue). Pick subdomain
vs. separate domain based on the same trust-differential reasoning:
subdomain is normally sufficient once cookies are scoped without a
shared parent-domain `Domain=` attribute; reach for a fully separate
domain only if the admin surface's compliance/security posture demands
not sharing even a registrable domain with the public surface.

**Consequence for `launch_handler` and the install-identity open
thread:** this resolves it conditionally rather than leaving it fully
open — if the trust-differential test says "separate origins," then two
installed apps with two independent identities is correct and expected
(the open thread's "how many installed windows a user juggles" concern
is then just normal multi-app UX, not a defect to design away). If the
test says "one origin," `launch_handler` stays a single-app question
answered under the existing 2026-07-15/2026-07-16 facets, not a
sub-app-boundary one.

---

## 2026-07-16 — Facet: Auth Flow Under an Offline-Capable Service Worker

Picking up the thread both prior passes carried forward unresolved. This
facet is where the mechanisms already committed to — the mutating-request
outbox, `CACHE_VERSION`-style versioning discipline, SW/manifest scope
matching — get stress-tested against auth, which is the one concern that
cuts across all of them: an auth-bearing request can be a navigation, a
read, or a mutation, and it can be replayed by the SW long after the code
that originally issued it has stopped running.

**The core conflict: two independently "best practice" patterns don't
compose.** SPA security guidance generally recommends keeping bearer
tokens in memory only (not localStorage/IndexedDB) to limit XSS
exfiltration blast radius. Separately, 2026-07-15 committed to replaying
queued mutations via Background Sync so offline writes survive and fire
later. These collide: Background Sync's `sync` event can fire in the SW
with **zero open clients** — the tab may be closed, the in-memory token
gone with it. A SW that owns no token cannot attach `Authorization:
Bearer …` to a replayed request no matter how the outbox is designed.
This isn't a bug to code around; it's a real structural tradeoff between
"tokens never touch persistent storage" and "writes survive the tab
closing," and a vision that just said "queue it and replay it" without
naming this would be silently assuming the conflict away.

**Recommendation: keep the SW deliberately ignorant of long-lived
secrets; let the client thread own refresh.** Default pattern: the SW's
job is queue + relay, not auth. On reconnect, the *page* (not the SW)
performs its normal refresh flow (rotating refresh token, silent
re-auth, whatever the app already does), then hands the SW a fresh
credential via `postMessage` immediately before triggering (or
alongside) a drain of the outbox. This keeps the refresh logic in the
one place that already has to implement it correctly for the interactive
app, rather than duplicating a second, SW-side refresh implementation
that now has to be kept in sync with the first. It also means the SW
never needs a refresh token in IndexedDB at all for the common case
where a client is open at reconnect time — which is the large majority
of real offline episodes (brief subway/elevator drops, not multi-day
disconnects).

**The no-open-client case forces a real choice, not a workaround.** When
`sync` fires with `self.clients.matchAll()` returning empty, the SW has
two honest options, and the right one depends on the app's threat model
rather than being a universal default:

1. **Defer.** Don't attempt replay; re-register the sync request (or
   wait for the next `sync`/next client open) so it fires once a client
   *is* present to supply a fresh token via the postMessage handoff
   above. Safest, simplest, and correct when queued writes are not
   time-critical — the cost is writes sit un-synced until the user
   reopens the app, which for most "offline note-taking" style use
   cases is an acceptable, even expected, wait.
2. **Use an httpOnly session cookie as the replay path's trust anchor,
   layered alongside — not instead of — in-memory bearer tokens for
   interactive calls.** The browser attaches cookies automatically to
   SW-initiated `fetch()`s (with `credentials: 'include'`/`'same-origin'`)
   with no token-storage problem at all, because the cookie jar is
   browser-owned state, not page-JS-owned state — it survives the tab
   closing by construction. This is not a downgrade versus the bearer
   pattern: httpOnly cookies already resist the exact XSS-exfiltration
   risk the bearer-in-memory pattern was chosen to mitigate. The
   remaining exposure is CSRF, which is solved territory
   (`SameSite=Lax`/`Strict` plus a synchronizer token, or a custom
   header value captured into the queued request at enqueue time and
   replayed verbatim) — not a reason to avoid this path, just a
   checklist item it adds.

   Choose option 2 only when "writes must survive the tab being closed
   for an extended period" is an actual product requirement; otherwise
   option 1 is strictly simpler and has one fewer credential type in
   play. Don't default to shipping a session cookie "just in case" —
   that's the same discipline as not adding Workbox until route count
   justifies it (2026-07-15): added mechanism should track an added
   requirement, not get bundled in preemptively.

**Auth endpoints are their own resource class — always network-only,
never queued.** 2026-07-15's resource-class table (navigation / static
assets / read API / mutating API / images) has no clean slot for
login/refresh/logout: they're POST-shaped like mutations, but the
outbox's "queue when offline, replay later" semantic is actively wrong
for them. Silently queuing a login attempt or replaying a stale refresh
call later is a correctness and security bug (refresh-token rotation
schemes explicitly detect and reject reuse of a stale refresh token —
a "helpfully" replayed queued refresh can trip that detection and kill
the session). Auth endpoints get an explicit fifth rule: bypass the SW's
caching and queuing logic entirely, fail fast and visibly when offline,
full stop.

**Orphaned outbox entries are the same bug shape as orphaned caches, for
a different store.** 2026-07-15 named the failure mode where stale
caches never get cleaned up because cleanup logic lived in a superseded
SW's `activate` handler. The outbox has a direct analog: a mutation
queued under user A's session sits in IndexedDB; the user logs out (or
is force-expired) before it replays; the entry now silently outlives the
session it was authorized under. Apply the same fix pattern that
`CACHE_VERSION` used for caches: tag every outbox entry with the
session/user id active at enqueue time, and on every login/logout
transition, prune entries that don't match the newly-current session
— rather than discovering months later that a replay is firing an old
user's write under a new user's now-active session on a shared device.
On a *voluntary* logout while entries are still pending and the client
is online, prefer attempting a flush before completing the logout, or
surfacing "N pending changes will be discarded" — don't silently drop
user-visible work.

**Tie-in to the architect's origin-separation answer (2026-07-16,
above): this facet's design is per-origin, not a thing to solve once and
namespace within one origin.** Cookies, IndexedDB databases, and Cache
Storage are all origin-partitioned already, so if the trust-differential
test came back "separate origins" for a public/admin split, each
sub-app gets its own session cookie, its own SW, its own outbox, and
this whole facet's reasoning just applies independently and in full to
each — with no coupling between them to design, because the platform's
partition already gives structural (not disciplined) isolation between
the two auth flows. That's actually a second, independent point in favor
of splitting origins when a genuine trust differential exists: it's not
only that public-surface XSS can't reach admin storage (the security
argument already made above), it's that a public-app background-sync
task cannot even *address* the admin session's cookie jar to attempt a
replay against it — the isolation is free, not something this facet's
session-tagging discipline has to manufacture. Conversely, if a team
finds itself trying to keep an admin refresh token "out of reach" of a
public SW's outbox through cache-name/IndexedDB-name namespacing
*within one origin*, that is precisely the soft-boundary-only-code-
convention trap the architect response warned about — a sign the
trust-differential test already answered "split the origin," and no
amount of careful auth-flow namespacing here substitutes for that.
When the test instead comes back "one origin, no differential," this
facet's design applies exactly once, unified, which is the common case.

**Open threads for future passes:** CSP posture for a SW-heavy app,
performance budget for precached shell size, `related_applications`/
`prefer_related_applications`, `launch_handler` (now unblocked per the
architect response above — worth a pass once this vision wants to get
concrete about it), and a newly surfaced one from this pass: step-up
/ re-authentication UX when a queued mutation's replay comes back 401
from a genuinely expired (not just stale) session — does the outbox
entry get held pending a fresh login, surfaced to the user for
re-auth-and-retry, or dropped after some bound? Not resolved here.

---

## 2026-07-17 — Facet: CSP Posture for a SW-Heavy, Installable Shell

Picking up the first item of 2026-07-16's open-threads list. CSP looks at
first glance like an orthogonal, page-level concern — a header the server
attaches to responses — but every prior facet turns out to touch it: the
navigation-caching strategy from 2026-07-15 determines *which* CSP a
client is actually enforcing at any given moment, the manifest/shell-perf
pressure from 2026-07-16 pushes toward inline bootstrap code that CSP
exists to restrict, and the auth facet's postMessage credential handoff
raises the question of whether CSP governs that channel at all.

**Deliver CSP via header, not `<meta http-equiv>` — the meta form is a
degraded fallback, not an equivalent.** A `<meta>`-tag CSP cannot set
`frame-ancestors` or `sandbox`, and cannot use `report-to`/`report-uri` —
the two directives most relevant to detecting exactly the kind of
injection this vision's vanilla-JS-first, no-framework-auto-escaping
stack is most exposed to. Reach for the meta form only when deploying to
a static host with no response-header control at all, and treat that as
a known, named gap (no clickjacking protection, no violation telemetry),
not a silent equivalent to the header.

**A cached navigation response carries its own CSP header — this is a
direct, previously-unnamed consequence of 2026-07-15's cache-versioning
discipline.** The Cache API stores response headers alongside the body,
so when the network-first navigation strategy times out and falls back
to the cached app shell, the CSP actually enforced for that page load is
whatever policy was attached to the shell *at the time it was cached*,
not whatever the server is sending today. Tightening a CSP server-side
(dropping a previously-allowed script host, adding `require-trusted-
types-for`) does not retroactively apply to a shell response already
sitting in Cache Storage. This is the exact orphaned-state bug shape
2026-07-15 named for stale caches and 2026-07-16's auth facet named
again for stale outbox entries — a third instance of the same root
cause (state cached under an old policy outliving the policy) — and the
fix is the same: a CSP change that matters for security, not just
convenience, should bump `CACHE_VERSION` so the old shell response (old
headers included) gets evicted on `activate` rather than lingering for
whatever fraction of sessions are currently in the offline-fallback
path. The blast radius is bounded by the same fact that bounds it
elsewhere in this vision: navigation is network-first with only a ~3s
timeout before falling back, so a stale-CSP shell should only actually
be *in use* for sessions that are genuinely offline-degraded at that
moment, not for every returning visitor.

**Inline bootstrap script/critical CSS is in real tension with CSP, and
the resolution should follow the same discipline 2026-07-15 applied to
Workbox and 2026-07-16's auth facet applied to session cookies: don't
add the exception until a concrete requirement earns it.** Default
policy should ship with no `'unsafe-inline'` and no inline `<script>`/
`<style>` at all — everything external and content-hashed, which is
already this vision's baseline for static assets. When a real
first-paint budget genuinely requires an inlined bootstrap script or
critical-CSS block, prefer a **hash-based** source expression
(`'sha256-…'`) over a nonce for that content specifically: a nonce is
only meaningful if it's unpredictable and freshly generated per
response, but the content triggering the inline need here is
build-time-static (the same shell HTML the cache-versioning discipline
above already treats as an immutable, hashed unit) — reusing one fixed
nonce value across every cached serving of that shell provides none of
a nonce's actual guarantee and is worse than just hashing the content
once at build time. Reserve nonces for content a server genuinely
re-renders per-request, which a cached-and-replayed shell response, by
construction, does not have.

**The service worker's own outbound fetches are a distinct CSP
enforcement surface from the document's — don't assume the page's
`connect-src` protects background-sync replay traffic.** A CSP is
delivered with a particular response and governs the behavior of the
context that response constitutes; the SW script has its own response
and its own scope, separate from any one document's. Whether a
browser's SW execution context inherits or is bound by the CSP of the
page that registered it is a subtler, more implementation-dependent
question than most CSP writeups treat it as, and it's worth verifying
against current engine behavior directly before relying on it rather
than assuming symmetry with ordinary page fetches. The actionable,
durable rule regardless of that detail: set an explicit, equally strict
CSP header on the service-worker script's own response, and don't treat
`connect-src` written for the document as if it were also a review of
what hosts the outbox-replay code (2026-07-16's auth facet) is allowed
to reach. The SW is the piece of this architecture most likely to run
unattended, with no open client and no page-level CSP visibly "in
effect" to a reviewer eyeballing the page source — exactly the code path
that most wants its own explicit review.

**CSP does not govern the postMessage credential handoff — that
channel's protection is origin-checking, a different control
entirely.** 2026-07-16's auth facet established that the page hands the
SW a fresh credential via `postMessage` before an outbox drain. `postMessage`
is not a CSP-restricted sink (no directive names it), so a reviewer
auditing this facet by CSP alone would wrongly conclude the handoff is
covered. The actual defense is in the `message` event handler itself —
verifying `event.origin` (and, where applicable, `event.source`) before
trusting the payload — and belongs in that handler's code review, not
in the CSP policy. Worth stating explicitly precisely because it's easy
to assume CSP is "the" security layer for everything crossing a
same-origin boundary; it isn't, and this is the one place in the vision
so far where that gap would otherwise go unnoticed.

**CSP violation reports are telemetry, not a user-authored write — they
explicitly do not belong in the outbox.** `report-to`/`report-uri`
naturally raises the question of what happens to a violation report
generated while offline. The right answer follows directly from
2026-07-15's resource-class table and the auth facet's session-tagged
outbox: reports are diagnostic, best-effort, and carry no user intent to
preserve, so they should be fire-and-forget and simply dropped if
offline rather than queued for replay. Extending the outbox's
survive-a-closed-tab guarantees to CSP reports would misapply
machinery built to protect a user's work to protect a security team's
dashboard completeness instead — a category error the outbox's
session-tagging design should not be stretched to cover.

**Cross-reference to the architect's origin-separation answer
(2026-07-16, above): shared CSP is a fourth, previously unstated cost of
staying same-origin across a real trust differential.** The architect
response reasoned from storage/session partitioning; CSP adds an
independent data point pointing the same direction. One origin can only
carry one CSP per response class, so a public-facing surface's genuine
needs (third-party analytics/tag-manager hosts, embedded widgets, a
looser `script-src`) end up as the *ceiling* on what the admin section
of the same origin is permitted to run too — there is no way to give
admin a materially stricter `script-src`/`frame-ancestors` while public
pages on the same origin need a looser one, because CSP is a per-origin
resource-serving decision more coarsely grained than the admin/public
route split within the app. Separate origins let each sub-app's CSP
track its own actual risk surface — admin can plausibly ship close to
`script-src 'self'` with no third-party hosts at all, which the public
marketing surface likely never can. This doesn't reopen the
one-app-or-several question; it's one more concrete reason the
trust-differential answer, once given, is worth acting on rather than
absorbing as shared-origin overhead.

**Trusted Types as a natural complement, flagged rather than adopted
by default.** `require-trusted-types-for 'script'` closes the DOM-XSS
gap CSP's `script-src` alone doesn't cover (a compromised or careless
`innerHTML`/`insertAdjacentHTML` call with attacker-controlled content
is a same-origin, same-nonce, fully "CSP-legal" write). It's a
particularly good fit for this vision's stack specifically because the
native-standards-first, no-framework stance (`magic-frontender.armed.md`'s
default stance) means there's no framework-level auto-escaping quietly doing
this job already — a Web-Components-and-vanilla-JS codebase that
touches `innerHTML` by hand is exactly the shape of codebase Trusted
Types was designed to backstop. Flagging as a strong candidate for a
future pass to get concrete about (policy naming, which sinks the
shell's own bootstrap code touches) rather than folding in fully here,
consistent with this vision's running discipline of not bundling a
mechanism in ahead of a pass that actually works out its specifics.

**Open threads for future passes:** performance budget for precached
shell size, step-up/re-authentication UX for a queued mutation's replay
coming back 401 from a genuinely expired session (both carried from
2026-07-16), `related_applications`/`prefer_related_applications` and
`launch_handler` client-mode (carried from 2026-07-16, unblocked per the
architect response), and a new one from this pass: working out a
concrete Trusted Types policy for the app shell's own bootstrap code.

---

## 2026-07-20 — Facet: Trusted Types Policy for the App Shell

Picking up the thread flagged at the end of 2026-07-17's CSP pass, next in
the queued order (Trusted-Types → shell-size performance budget → step-up
re-auth UX). `require-trusted-types-for 'script'` was named there as a
strong fit for this vision's stack specifically because the native-
standards-first, no-framework stance means there's no framework auto-
escaping quietly absorbing DOM-XSS risk — a Web-Components-and-vanilla-JS
codebase touching `innerHTML` by hand is exactly the shape Trusted Types
exists to backstop. This pass gets concrete: which sinks, which policies,
what enforcement path.

**Mechanism, precisely, since the CSP facet only gestured at it.** Once
`require-trusted-types-for 'script'` is set, the browser refuses to hand a
raw string to a fixed set of DOM-XSS-prone sinks — `innerHTML`/`outerHTML`
setters, `insertAdjacentHTML`, `Document.write`/`writeln`,
`DOMParser.parseFromString`, `Range.createContextualFragment`, `<script>`
`src`/`text`/`textContent`, `<iframe srcdoc>`, `eval`/`Function`, and
`importScripts`/Worker-family constructor URLs — unless that string was
produced by a registered `TrustedTypesPolicy`'s `createHTML`/`createScript`/
`createScriptURL` method. A raw string hitting any of these sinks throws
a `TypeError` instead of executing. This is what makes it a real backstop
rather than a lint rule: the enforcement is in the sink itself, at the
platform level, not in code review catching a bad `innerHTML` call before
merge.

**Don't register a `'default'` policy — that's the one footgun this
mechanism has, and it's easy to reach for by accident.** If a policy named
`'default'` exists, *any* unmarked string hitting a guarded sink —
including one written by a third-party script this app didn't author —
silently routes through it instead of throwing. That't attractive as a
quick way to "make TT errors go away" during rollout, but it quietly
converts a hard platform-enforced boundary back into "whatever the default
policy's callback decides to allow," which is the exact soft-boundary
failure mode 2026-07-16's architect response warned about for storage
namespacing — a convention-shaped safety net instead of one the platform
itself enforces. It's also a supply-chain risk specific to this pattern: a
compromised or careless dependency's `innerHTML` write gets silently
"fixed" (or worse, silently passed through if the default policy is
permissive) rather than failing loudly where it can be caught. Default
policy has a legitimate narrow use — hardening a vendored/legacy script
this app can't rewrite, with the callback actually sanitizing rather than
passing through — but it should be a deliberate, named exception at one
call site, never the standing shape of the rollout.

**Design: small number of named, purpose-scoped policies, not one
catch-all.** `trustedTypes.createPolicy('shell-render', { createHTML: … })`
scoped to the module that owns Web Component re-renders is the pattern —
callable only by code that imports that specific policy object, which
means a security review can enumerate "everywhere HTML can be constructed
from a string in this app" by grep-ing policy names instead of auditing
every `innerHTML` call site for whether it's safe. A second, separate
policy for anything genuinely constructing a script URL (dynamic `import()`
of a build-time-known chunk path, if any) keeps that narrower, rarer
capability from being reachable through the same policy object that
renders user-visible markup.

**Where this app's own sinks actually are, tracing through the prior
facets rather than guessing generically:**
- **Static shell HTML / the inline bootstrap script (2026-07-17):**
  build-time-static, hash-listed in CSP, never assembled from a runtime
  string — no TT sink touched here at all. Confirms 2026-07-17's framing
  of this content as an immutable build artifact, not something this
  facet needs to add machinery for.
- **Web Component render paths (this vision's default stack per
  `magic-frontender.armed.md`):** the real, load-bearing sink. Vanilla Web Components
  re-rendering on data change is the idiomatic no-framework pattern for
  "update the DOM to match new state," and the common hand-rolled way to
  do it is a template-literal string assigned to `shadowRoot.innerHTML`
  — exactly the sink TT guards. This is the one that needs a policy and
  a wrapper, not an occasional exception.
- **Stale-while-revalidate list/read views (2026-07-15):** the actual
  dangerous data flow — API JSON, which can carry attacker-controlled
  content on any endpoint rendering user-generated text, flowing into a
  component's re-render. This is the textbook stored-XSS path TT exists
  to close, and it's this vision's own caching strategy that puts fresh
  untrusted data on the render path continuously (every SWR background
  refresh), not just on initial load.
- **The SW "update available" toast (2026-07-15):** dynamically inserted
  DOM, but its content is app-authored (a fixed string + maybe a version
  number), not data-derived — low risk, but still goes through the same
  wrapper for consistency rather than being carved out as a special case
  that later drifts to accept real data.
- **The postMessage credential handoff (2026-07-16):** not a TT sink at
  all — the payload is consumed as data (a token value), never written to
  a DOM sink or executed. Mirrors 2026-07-17's finding that CSP doesn't
  govern this channel either; both facets land on the same boundary from
  different angles, which is a useful cross-check that the boundary is
  real and not an artifact of either analysis alone.

**The wrapper, not raw `createHTML`, is what call sites should use.**
Expose one tagged-template helper (e.g. an `html` tag function) built on
top of the `shell-render` policy, in the same spirit as `lit-html`'s
approach but hand-rolled to stay dependency-free: static template
strings are trusted by construction (they're source code, not data), and
only the interpolated `${...}` values need handling. The safest version
of this wrapper never lets an interpolated value contribute *structural*
HTML at all — it escapes every interpolation into a text node
(`&amp;`/`&lt;`-style encoding), and any component that genuinely needs to
render pre-sanitized rich HTML (rare — a markdown-rendered comment body is
the realistic case) calls a separate, explicitly-named
`renderTrustedRichText()` path that runs an actual sanitizer before
`createHTML`. Collapsing these into one "just sanitize everything" helper
is how a sanitizer bug in the common case (plain text interpolation) ends
up sharing blast radius with the rare case (rich HTML) that actually needs
one — keep them visibly distinct at the call site.

**Rollout path: Report-Only first, and expect it to be noisy in a
no-framework codebase.** `Content-Security-Policy-Report-Only:
require-trusted-types-for 'script'` (paired with `report-to`, already
established as this app's telemetry channel in 2026-07-17's pass) surfaces
every unmarked sink write without breaking anything, which matters
specifically *because* this stack has no framework absorbing `innerHTML`
calls into a single reviewed code path — expect the first Report-Only pass
to surface call sites scattered across every hand-rolled component, not a
tidy handful. Flip to enforcing only once that report stream is empty (or
every remaining hit is a deliberately-accepted, named exception routed
through the rich-text path above) for a sustained period, not on a fixed
calendar date — the exit criterion is the signal, not the clock.

**SW-side scope: narrower than it first appears.** A service worker has
no DOM, so the `innerHTML`-class sinks don't exist inside it at all —
`require-trusted-types-for 'script'` on the SW's own response (already
mandated by 2026-07-17's "SW gets its own explicit CSP" finding) mainly
matters there for the `eval`/`Function`/`importScripts` sinks. A SW that
already avoids dynamic `eval` and string-based `importScripts` (which this
vision's stack does by default — no bundler-injected dynamic eval, no
runtime dependency loading) satisfies this without new work; it's worth
keeping the directive on regardless, as a structural guarantee against a
future dependency quietly introducing one of those patterns, not because
today's SW code needs fixing.

**Progressive enhancement applies here too, same principle as
`beforeinstallprompt` (2026-07-16) and the offline-fallback UI
(2026-07-15).** Trusted Types is not universally shipped (Safari has not
implemented it as of this pass). The sanitizing/escaping behavior inside
the `html` wrapper must hold on every browser regardless of TT support —
feature-detect `window.trustedTypes` and register the policy only when
present, but never make the wrapper's actual escaping logic conditional on
that detection. TT is the enforcement backstop that upgrades "we wrote the
escaping correctly" into "the platform refuses to let us ship it wrong";
it is not itself the source of the safety property, and the design should
not degrade silently on browsers where the backstop is unavailable.

**Open threads for future passes:** shell-size performance budget (next
in the queued order), step-up/re-authentication UX for a 401 on outbox
replay (carried from 2026-07-16), `related_applications`/
`prefer_related_applications` and `launch_handler` client-mode (carried,
still unaddressed), and a new one from this pass: which concrete
sanitizer implementation backs the rare `renderTrustedRichText()` path —
hand-rolling HTML sanitization is its own well-known trap, and this
vision's dependency-minimalism default (2026-07-15's Workbox reasoning)
shouldn't be applied reflexively here without weighing that a sanitizer
is one of the few dependency classes where a small, battle-tested library
is likely to be the more defensible choice than hand-rolled code — not
resolved here, flagged for the pass that gets concrete about it.
