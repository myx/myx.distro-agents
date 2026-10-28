# CSS `linear()` as a physics-animation data container

The body of the section of the same name in this member's armed content.

`linear()` normally controls *how smoothly* a transition moves from A to B. Repurposed instead as a pure-CSS way to bake an arbitrary simulated motion into a native, main-thread-free animation. That is a spring, a pendulum, a bounce, any physics sim, with no JS driving it at runtime:

1. Run the physics simulation once, offline, sampling the animated property at regular time intervals.
2. For each animated dimension, find its min/max across all samples.
3. Declare a `@keyframes` for that dimension spanning `from { property: <min> }` to `to { property: <max> }`.
4. Normalize every sample to `[0,1]` via `(sample - min) / (max - min)`.
5. Pack the normalized values as the comma-separated number list inside `linear(...)`, driving that `@keyframes` animation's timing function.

Two simultaneous axes (e.g. x/y) can't share one property's timing function — split them across two different CSS properties (e.g. `translate: x 0` for X, `transform: translateY(y)` for Y) so each gets its own `linear()`.

Real limits:
  - interpolation between samples is linear only: no curvature, unless the sample rate is high enough to approximate one.
  - rotation/scale stacked with translation needs a wrapper element to avoid compounding.
  - skipped/irregular sample intervals need explicit progress-percentage stops in the `linear()` list, not just the raw value sequence.

Motion/visual-styling knowledge, not a systems-depth topic. Reach for it when a task genuinely needs custom spring/physics-feel easing, not as a default lens on unrelated styling work.
