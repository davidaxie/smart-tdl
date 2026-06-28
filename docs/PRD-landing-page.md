# Smart TDL — Marketing Landing Page PRD

**Status:** Draft v1 · **Owner:** David Xie · **Date:** 2026-06-28
**Surface:** Static marketing website (one page + thin legal/support pages) · **Not** a web app.
**Companion to:** the master PRD at `docs/PRD.md` (read it for the product itself; this doc is the front door to it).

> This is the platform-specific PRD for the **marketing landing page** — the public web property that explains Smart TDL and sends people to the App Store. It is a deep companion to the master `docs/PRD.md`, not a rehash. Where it cites shared facts (the thesis, the seven pains, the principles, the design languages), it points back to the master rather than re-deriving them, but it carries enough that a reader who only opens *this* file fully understands the product and how we sell it.

---

## 0. The one distinction that frames this whole document

A **web app** is a permanent non-goal for Smart TDL (master PRD §4.1: "No cross-platform Android/Windows/**web**"). We do not run task state in a browser, we do not hold user data on a server, and we will never ask anyone to "log in on the web." That refusal is load-bearing — it's part of the local-first, no-backend promise (master PRD P9).

A **marketing landing page is a different thing entirely, and it is fully in scope.** A static, read-only, no-account marketing site does not violate any principle:

| | Web *app* (permanent non-goal) | Marketing landing page (this PRD) |
|---|---|---|
| Holds user task data | Yes — violates P9 local-first | No — zero user data, ever |
| Requires an account / login | Yes | No |
| Is a place you "do your to-dos" | Yes — would split the product surface | No — it's a brochure that links to the App Store |
| Runs intelligence / API calls | Yes — would need a backend | No — pure static HTML/CSS, no key handling |
| In scope? | **No** | **Yes** |

The landing page is allowed to be *literary, calm, and persuasive*. It is not allowed to become an app. The single hardest discipline of this project is that the marketing site must **embody** the product's calm (fast, quiet, no dark patterns, no exit popups, no creepy trackers) — the medium is the message. A bloated, nagging, tracker-laden landing page would be a lie about a calm, private app. **The site's restraint is the first demo of the product.**

---

## 1. Goal & success in one paragraph

Build a single, beautiful, fast static page (plus thin Privacy / Support pages) that lands the "empty quadrant" story in five seconds, makes a non-technical visitor feel the calm, honestly explains the bring-your-own-key model without scaring anyone, and converts the right people to two actions: **download on the App Store** (primary) and **join the launch/TestFlight email list** (secondary). Success = a high visit→download rate from a small, well-qualified audience, measured with privacy-respecting analytics that match the product's privacy promise.

---

## 2. Audience for the site (who is reading this page)

Inherited from the master PRD's personas (§5), narrowed to *web-visitor* intent:

- **Primary — "The overwhelmed competent."** Has tried and abandoned Todoist / Notion / Apple Reminders. Arrives skeptical ("another to-do app"). Apple user. Will paste an API key once *if* we make it feel safe and optional. The page must defeat their skepticism in the hero and earn the download with the "what we left out" section.
- **Secondary — "The calm seeker."** A Things 3 lover. Aesthetics-first. Will bounce instantly if the page is loud, hypey, or cluttered. The page's *restraint and typography* are the pitch to this person as much as the copy.
- **Tertiary — "The privacy-minded."** Reads the privacy section before anything else. Needs to see "your data stays on your device, no servers, no account, no trackers" in plain language and believe it (the page itself must prove it — no Google Analytics, no Facebook pixel).
- **Anti-persona — "The system tinkerer."** We do **not** court them. The "what we left out, on purpose" section will actively repel them (no tags, no projects, no flags) — and that's correct. Repelling the wrong user is part of qualifying the right one.

**Visitor mindset we're designing against:** arrives mid-skeptical, gives us ~5 seconds, has seen a hundred to-do apps, is allergic to hype and subscriptions. The page wins by being unlike the category: quiet, confident, honest.

---

## 3. Positioning & message (the spine of the site)

### 3.1 The single story: the empty "simple + smart" quadrant

Everything on this page serves one idea from master PRD §3.2–3.3: there is an **empty quadrant** in the to-do market, and Smart TDL is the only thing in it.

- Simple + dumb → Apple Reminders, Google Tasks, Microsoft To Do.
- Complex + dumb → Notion, OmniFocus, maxed-out Todoist (they store more; they don't *decide* more).
- Complex + smart → Motion, Sunsama (the smartness is loud, busy, and expensive).
- **Simple + smart → Smart TDL.** The only one. The calm of Things 3, the brain of an AI planner, the price of a free app, zero organizing busywork.

The whole page is a guided walk to that empty corner.

### 3.2 The one-sentence thesis (must appear, near-verbatim, above the fold)

> **Every other app makes you do the deciding and the organizing. Smart TDL does both invisibly — so the only thing left for you is the doing.**

### 3.3 The 5-second hero promise (the "must land instantly")

The compressed value, the line a visitor should be able to repeat after a glance:

> **The calm of Things 3. The brain of an AI planner. The price of a free app. Zero organizing busywork.**

This four-part line is the page's load-bearing beam. It appears in the hero (as supporting text under the headline) and recurs as a rhythm device. It works because each clause names a *competitor's single best thing* and claims all four at once — which is literally the empty-quadrant argument compressed to a breath.

### 3.4 Brand voice (how everything is written)

Calm, confident, minimal, a touch literary — matching the Playfair Display / serif brand and the "Settle" design language (master PRD §8). Specifically:

- **Plain over clever-clever.** Short sentences. Concrete nouns. No "supercharge," no "10x," no "revolutionize," no exclamation marks in body copy.
- **Honest over hype.** We never claim the AI is magic; we say it "quietly sorts." We never hide the BYO-key trade; we explain it as pro-user.
- **A little literary.** One well-placed metaphor per section is allowed ("a monument to everything you're behind on"). Whitespace is part of the voice.
- **Confident restraint.** The strongest move is saying *no* — "what we left out, on purpose" is the most persuasive section, not an apology.

**Voice anti-patterns (banned):** countdown timers, "limited time," fake scarcity, "join 10,000+ users" before we have them, urgency badges, exit-intent popups, cookie-walls, autoplaying sound, anything that interrupts.

---

## 4. Headline options (real copy, choose one for launch, A/B the rest)

Four production-ready headline + subhead pairs in the brand voice. Recommended primary is **Option A**; the rest are live A/B candidates.

### Option A — "The doing" (recommended primary)
**Headline:** *Stop deciding. Start doing.*
**Subhead:** Smart TDL is a calm daily to-do list with a quiet intelligence that decides what matters and floats it to the top — so the only thing left for you is the doing. The calm of Things 3, the brain of an AI planner, the price of a free app, zero organizing busywork.

### Option B — "The empty quadrant" (the category-defining angle)
**Headline:** *A to-do list as calm as Things, as smart as it should have been all along.*
**Subhead:** Every other app makes you do the deciding and the organizing. Smart TDL does both — invisibly. No tags, no projects, no priority flags, no subscription. Just your day, with the right thing already on top.

### Option C — "The anti-busywork" (speaks to pain #6)
**Headline:** *Your to-do list shouldn't be another job.*
**Subhead:** No color-coding to maintain, no folders to tidy, no scores to read. Type a task, and an invisible intelligence sorts your day for you. Free, private, and yours — bring your own key, no subscription.

### Option D — "The quiet brain" (the literary one)
**Headline:** *It thinks, so you don't have to think about it.*
**Subhead:** A near-chromeless list of your days, with a quiet brain underneath that decides what matters most and lifts it to the top — never a badge, never a score, never a nag. On Mac and iPhone today.

**Selection note:** A leads with the *benefit* (lowest cognitive load, broadest appeal). B is the sharpest *positioning* but assumes the reader knows Things 3. C is best if early data shows "subscription fatigue" / "busywork" resonates most. D is the most on-brand voice but the least explicit — keep it as the about-page or OG-description variant. Ship A, A/B against C first.

---

## 5. Page structure (section-by-section wireframe)

A single long-scroll page. Each section is one idea, generous whitespace, one visual at most. Order is a deliberate narrative arc: **hook → name the pain → reveal the insight → show how → prove the discipline → remove the objections → invite the action.**

```
┌─────────────────────────────────────────────────────────┐
│ 0. Thin top bar: wordmark (Playfair) · "Download" button │  ← minimal, no nav menu
├─────────────────────────────────────────────────────────┤
│ 1. HERO                                                  │
│    Headline (Option A) · subhead · primary CTA           │
│    + the calm product loop (week board, #1 floating up)  │
├─────────────────────────────────────────────────────────┤
│ 2. "Your to-do list became a guilt machine"             │
│    the pains, tastefully — 3 short beats, not a list     │
├─────────────────────────────────────────────────────────┤
│ 3. THE INSIGHT — the 2x2 quadrant                        │
│    simple↔complex × dumb↔smart, Smart TDL alone in the   │
│    empty corner                                          │
├─────────────────────────────────────────────────────────┤
│ 4. HOW IT WORKS — three beats                            │
│    capture → it quietly sorts → you do                   │
├─────────────────────────────────────────────────────────┤
│ 5. "What we left out, on purpose"                        │
│    the non-goals AS the selling point                    │
├─────────────────────────────────────────────────────────┤
│ 6. PRICING & TRUST                                       │
│    free · bring your own key · no subscription           │
├─────────────────────────────────────────────────────────┤
│ 7. PRIVACY                                               │
│    local-first · your key · no servers · no trackers     │
├─────────────────────────────────────────────────────────┤
│ 8. PLATFORMS                                             │
│    Mac + iPhone now · Android "exploring"                │
├─────────────────────────────────────────────────────────┤
│ 9. FAQ                                                   │
├─────────────────────────────────────────────────────────┤
│ 10. FINAL CTA — download + email capture                 │
├─────────────────────────────────────────────────────────┤
│ 11. FOOTER — privacy · support · email list · ©          │
└─────────────────────────────────────────────────────────┘
```

### Section 0 — Top bar (chrome, kept to almost nothing)
- Left: **Smart TDL** wordmark in Playfair Display.
- Right: one calm **"Download"** button (terracotta only on hover/active — the accent rule from "Settle").
- **No nav menu, no hamburger, no login.** A single-screen product deserves a single-screen site. (Mobile: identical, the button stays.)
- Sticky but *barely* — translucent warm-paper background, hairline bottom border only after scroll. Never obtrusive.

### Section 1 — Hero (the 5-second job)
- **Layout:** headline + subhead left (or centered on mobile), product visual right/below.
- **Copy:** Option A headline + subhead. One primary CTA: **"Download for Mac & iPhone — free."** Secondary, smaller, beneath it: **"or join the launch list →"**.
- **The visual is the hero, literally:** a short, silent, looping screen capture of the **Mac week board** (`WeekBoardView`) where, after a beat of stillness, **the #1 task rises to the top of Today** — the gravity ramp settling, the small "NOW" treatment landing on the heaviest task, the single terracotta accent appearing at the commit moment. This *shows* the invisible intelligence without a single word about "AI." (See §6 Visual spec for loop rules: ≤6s, ≤1.5MB, respects reduced-motion with a static fallback frame.)
- **Acceptance:** a first-time visitor, muted, on a phone, understands "calm list + the right thing floats up + free" within 5 seconds, with the page interactive (LCP) under 1.5s on 4G.

### Section 2 — "Your to-do list became a guilt machine" (the pain, tastefully)
- Names the reader's lived experience without a feature dump. Pull from the master PRD's seven pains (§2.1) but render only the 3 that hit hardest emotionally: **guilt (the 150-item wall), busywork (organizing isn't doing), and decision fatigue (everything looks equally important)**.
- Format: three short, literary beats — not bullet jargon. (Copy in §7.2.)
- Tone: empathetic, never condescending. The reader should feel *seen*, then relieved that the next section has an answer.
- Visual: optional, restrained — a faded, over-stuffed list dissolving into a calm, short one. Subtle; no red, no alarm.

### Section 3 — The insight (the 2×2 quadrant — the intellectual core)
- This is the "aha." Render the positioning map from master PRD §3.2 as a clean 2×2.
- **Axes:** horizontal = **Simple ↔ Complex**; vertical = **Dumb storage ↔ Active intelligence**.
- **Plot:** Apple Reminders / Google Tasks / Microsoft To Do in *simple+dumb*; Notion / OmniFocus in *complex+dumb*; Motion / Sunsama in *complex+smart*; **Smart TDL alone, highlighted in terracotta, in the empty *simple+smart* corner.**
- **How to render it (design + a11y):** an inline SVG, warm-paper background, hairline axes, competitor names as muted dots/labels, Smart TDL as the one terracotta-accented mark with a soft glow. On mobile it collapses to a stacked, captioned version (four labeled quadrant cards, the fourth highlighted) so it never relies on a tiny scatter plot. Provide a text alternative / `aria-label` describing the four quadrants for screen readers (the quadrant is an argument, not decoration — it must be legible non-visually).
- Caption beneath: *"Three corners are crowded. One has been empty. We built for the empty one."*

### Section 4 — How it works (three beats: capture → it quietly sorts → you do)
- The product mechanic in three honest beats, each a short heading + one sentence + one tiny visual. (Copy in §7.3.)
  1. **Capture** — type a task in one gesture; "call Sam friday" files itself on Friday, silently.
  2. **It quietly sorts** — an invisible intelligence reads your day and floats the most important task to the top. No scores, no badges, nothing to configure. (Honest note: the AI re-ranks only at "safe moments," never under your hand — though the site phrases this as "it never rearranges your list while you're using it," not in jargon.)
  3. **You do** — open the app, the right thing is already on top, start there. At the end of the day, a quiet "all clear."
- **Critical brand constraint:** even here we **do not show a chat box, a score, an "AI" panel, or settings**. The visuals mirror the real app (which has no such surfaces — master PRD P1). Showing intelligence *as a feeling* (the float-up) not *as a UI* is the whole point.

### Section 5 — "What we left out, on purpose" (non-goals as the pitch)
- The most differentiated section. Turns the master PRD non-goals (§4.1) into the strongest selling point. (Copy in §7.4.)
- Format: a short, confident list of the things Smart TDL **refuses** — *no projects, no tags, no folders, no sub-tasks, no priority flags, no color-coding, no streaks, no badges, no subscription* — each with a one-line reason that reframes the absence as a gift ("Nothing to maintain. Productivity theater is structurally impossible here.").
- This is where we *intentionally repel the tinkerer* and *delight the calm-seeker*. The honesty ("we will never add these") is the trust play.

### Section 6 — Pricing & trust (free · BYO key · no subscription)
- Plain-language explanation of the model (master PRD P8). Must reassure non-technical readers that the app is **fully useful with no key at all**. (Copy in §7.5.)
- Three-card or three-line layout:
  - **Free.** The app costs nothing. No subscription, ever.
  - **Works out of the box.** With no setup, a built-in offline ranker still sorts your day sensibly. (This is the `HeuristicRanker` — master PRD P10/§7.3 — described in human terms.)
  - **Smarter with your own key (optional).** Paste an Anthropic API key once and the smarter ranker (Claude Haiku) takes over. You pay Anthropic directly — pennies a day — and we never see it.
- **The BYO-key explainer (de-scared):** a short, calm paragraph (not a wall) framing BYO-key as *pro-user*: no middleman markup, no subscription lock-in, your usage is your own, and — crucially — *you don't need it to start.* A single "How the key works" disclosure (collapsible) holds the 3-step detail for the technical reader without burdening the rest.

### Section 7 — Privacy (local-first · your key · no servers)
- The privacy promise in plain words (master PRD §7.9, P9). (Copy in §7.6.)
- Key claims, each one sentence: **Your tasks live on your device.** **No account, ever.** **No servers holding your data.** **When you use a key, only your task titles and a little context go to Anthropic on your own key — nothing else, and only then.** **This website has no creepy trackers** (we use privacy-respecting analytics that don't follow you).
- **The page proves it:** because we ship no Google Analytics / Meta pixel / session-recording, a privacy-minded reader who opens dev tools sees us telling the truth. This is the rare landing page where the *implementation* is part of the *claim*.

### Section 8 — Platforms (Mac + iPhone now; Android "exploring")
- Honest availability. **Mac and iPhone available now** (App Store badges). **Android: "We're exploring it."** — note the newly-in-scope-as-of-2026-06-28 status honestly; do not promise a date. Offer the email list as the "tell me when Android's ready" capture.
- This is the one place the site must be careful: the master product was historically "Apple-only" (master PRD §4.1) and Android is *newly* in scope. The site states current truth (Apple now), signals openness (Android exploring), and uses the gap as an email-capture reason — without overpromising. (Cross-doc dependency: keep this line consistent with the Android PRD's status.)

### Section 9 — FAQ
- 6–8 calm Q&As (full copy in §7.7) covering: Is it really free? Do I need an API key? What's an API key / is it safe? Does my data leave my device? Why no projects/tags? Is there sync? Is there Android? What's the catch?
- Format: accessible `<details>`/`<summary>` accordions (keyboard-navigable, no JS dependency for content visibility — content present in DOM for SEO and no-JS users).

### Section 10 — Final CTA (the close)
- Restate the thesis line, then both CTAs side by side: **"Download — free"** (primary, App Store) and a single-field **email capture** ("Get the launch note + Android news"). One email field, one button, no extra fields, GDPR-honest microcopy ("One email at launch. No spam, no list-selling, unsubscribe anytime.").
- A last calm visual: the "all clear" end-of-day moment — the peak-end note (master PRD §7.7) as the emotional close.

### Section 11 — Footer
- Wordmark · Privacy · Support/Contact · Email list · App Store links · © 2026 · a single line: *"Made calm, on purpose."*
- **No** social-media wall, no newsletter popup, no "we use cookies" banner shouting (because we don't set tracking cookies — see §9).

---

## 6. Visual & brand spec

Extends the **"Settle"** design language (master PRD §8) into web. Do not re-invent; translate the app's tokens to CSS.

### 6.1 Palette (warm paper, light + dark)
Mirror `Theme.swift`'s `Color(light:dark:)` philosophy as CSS custom properties with a `prefers-color-scheme` dark variant.

| Token | Light (warm paper) | Dark (warm ink) | Use |
|---|---|---|---|
| `--bg` | warm off-white (paper) | warm near-black | page background |
| `--ink` | warm near-black | warm off-white | body + headings |
| `--ink-muted` | warm grey | warm dim grey | captions, muted labels, competitor labels in quadrant |
| `--accent` (terracotta) | terracotta | terracotta (slightly lifted) | **only** the live CTA hover/active, the quadrant's Smart TDL mark, the #1 highlight in the loop, the commit-moment glow |
| `--hairline` | low-contrast warm line | low-contrast warm line | borders, axes, dividers |

**Accent discipline (non-negotiable, mirrors the app):** terracotta appears *only* on live interaction and on the single "this is the one" mark. The page is overwhelmingly warm-paper-and-ink; terracotta is a spark, never a field. A page drenched in accent color would betray the brand.

### 6.2 Type
- **Headings & mastheads:** **Playfair Display** (the app's bundled serif), self-hosted (woff2, subset to used glyphs) — *not* Google-Fonts-CDN-loaded (privacy + speed; see §9).
- **Body & UI:** a clean system sans stack (`-apple-system, "SF Pro", Segoe UI, system-ui, sans-serif`) so it's instant, native-feeling, zero-download, and visually consistent with SF on the actual Apple apps.
- Generous line-height and measure (~60–70ch max body width); large, airy headings; lots of vertical rhythm. Whitespace is a brand asset.

### 6.3 The hero product loop (the single most important asset)
- **What:** a silent, looping motion clip of the Mac week board with the #1 task floating to the top of Today (gravity ramp settling, "NOW" landing, single terracotta accent at commit). Captured from the real app (`screencapture`/screen recording per master PRD §7.10 build notes).
- **Format:** prefer an inline silent **`<video>`** (`muted autoplay loop playsinline`, AV1/H.265 + H.264 fallback) or a tightly-optimized animated asset; **budget ≤ 1.5 MB**, ≤ 6 seconds, seamless loop.
- **Reduced motion:** with `prefers-reduced-motion: reduce`, do **not** autoplay — show a single crisp static frame (the settled state, #1 on top) instead. This is both an a11y requirement and on-brand (calm, not flashy).
- **Calm motion rule:** all motion on the page is slow, eased, and purposeful. No parallax circus, no scroll-jacking, no confetti. Sections fade/rise gently on first view (and not at all under reduced-motion). Motion should feel like the app's safe-moment settle, not a sizzle reel.

### 6.4 Imagery
- Real app screenshots only (Mac week board, iPhone day list), shown in tasteful, minimal device frames or frameless on warm paper. No stock photos of smiling people, no abstract "AI brain" clip art (that would contradict "invisible AI").
- The iPhone day list (`TaskListView`) gets its own clean shot in the Platforms section.

### 6.5 OG / social share card
- A single, deliberate Open Graph image (1200×630): warm-paper background, Playfair "Smart TDL" wordmark, the thesis line, a hint of the week board with the terracotta #1. One card, on-brand, legible as a thumbnail. Set `og:title`, `og:description` (use Option D's subhead — the literary one reads well as a share snippet), `og:image`, and matching `twitter:card` (summary_large_image).

---

## 7. Copy deck (real, usable microcopy)

Drop-in copy for the key sections. Calm, confident, minimal, lightly literary. (Headlines are in §4.)

### 7.1 Hero (chosen: Option A)
> **Stop deciding. Start doing.**
>
> Smart TDL is a calm daily to-do list with a quiet intelligence that decides what matters and floats it to the top — so the only thing left for you is the doing.
>
> The calm of Things 3. The brain of an AI planner. The price of a free app. Zero organizing busywork.
>
> **[ Download for Mac & iPhone — free ]**   ·   *or join the launch list →*

### 7.2 The pain ("Your to-do list became a guilt machine")
> **Your to-do list became a guilt machine.**
>
> It started simple. Then it grew into a wall of a hundred items — a monument to everything you're behind on. You stopped opening it.
>
> So you tried a *powerful* app. Now you spend your time color-coding, tagging, and tidying — busywork that *feels* productive while the actual work waits.
>
> And through all of it, the app never once told you the one thing worth doing next. Everything looked equally urgent, which means nothing did.

### 7.3 How it works (three beats)
> **Three steps. You only do one of them.**
>
> **1 · Capture.** Type a task and move on. Write "call Sam friday" and it quietly files itself on Friday — no menus, no date picker, no fields to fill.
>
> **2 · It quietly sorts.** Behind the calm surface, an intelligence reads your day and lifts the most important task to the top. No scores. No badges. Nothing to set up. And it never rearranges your list while your hand is on it.
>
> **3 · You do.** Open the app and the right thing is already waiting at the top. Start there. When the day is done, a quiet *all clear.*

### 7.4 What we left out, on purpose
> **What we left out, on purpose.**
>
> The best feature of Smart TDL is everything it refuses to be.
>
> - **No projects, tags, folders, or sub-tasks.** Nothing to organize means nothing to procrastinate inside.
> - **No priority flags or color-coding.** The app does priority for you — invisibly. You'll never label a task again.
> - **No streaks, points, or badges.** No guilt counter following you around. No game to play instead of living.
> - **No subscription.** It's free. The intelligence runs on your own key, for pennies.
>
> Productivity theater is structurally impossible here. There's nothing to maintain — only your day, and the next right thing on top of it.

### 7.5 Pricing & BYO-key explainer
> **Free. No subscription. Yours.**
>
> Smart TDL costs nothing, and it never will charge a monthly fee. Here's the honest version of how the smart part works:
>
> **It's useful the moment you open it.** With zero setup, a built-in offline ranker already sorts your day sensibly. No key, no account, no internet required.
>
> **It gets smarter with your own key — if you want.** Paste an Anthropic API key once, and a sharper intelligence (Claude Haiku) takes over the sorting. You pay Anthropic directly — typically pennies a day — and the bill is yours, not ours.
>
> Why this way? Because it's the pro-user deal: no middleman markup, no subscription you forget to cancel, no company sitting between you and your own usage. And you never need a key to start.
>
> <details><summary>How the key works (for the curious)</summary>
> 1. Get an API key from Anthropic's console. 2. Paste it once into Settings — it's stored in your device's Keychain, never on a server. 3. That's it. Your task titles and a little context go straight from your device to Anthropic on your key. We're never in the loop.
> </details>

### 7.6 Privacy
> **Private by default. Not as a setting — as a design.**
>
> Your tasks live on your device. There's no account to create and no server holding your data, because we don't run one.
>
> When you add your own key, only your task titles and a small amount of context travel — straight from your device to Anthropic, on your key, only then. Nothing else leaves, and nothing leaves at all if you don't add a key.
>
> Even this website respects you: no ad trackers, no session recorders, no creepy pixels following you around the internet. We measure visits with privacy-respecting analytics that can't identify you. The calm is real, all the way down.

### 7.7 FAQ
> **Is it really free?** Yes. No subscription, no trial timer, no paywalled core. The optional smarter ranking runs on your own Anthropic key, billed to you for pennies.
>
> **Do I need an API key?** No. The app sorts your day out of the box with a built-in offline ranker. A key is a pure upgrade you can add anytime — or never.
>
> **What's an API key, and is it safe?** It's a personal access token from Anthropic that lets the app use Claude on your behalf, billed to you. It's stored only in your device's Keychain. We never see it.
>
> **Does my data leave my device?** Only your task titles and a little context, only if you've added a key, and only to Anthropic on that key. No key, nothing leaves. No account, no servers, ever.
>
> **Why no projects, tags, or priorities?** Because organizing isn't doing. The moment an app gives you a system to maintain, the maintenance becomes the work. We do the prioritizing invisibly so you don't have to.
>
> **Does it sync between my Mac and iPhone?** Sync is on the roadmap via Apple's own iCloud — local-first, private, no server of ours involved. *(Apple's iCloud covers Mac + iPhone only; an Android version, if it ships, would sync separately.)* Join the list and we'll tell you when it lands.
>
> **Is there an Android version?** Not yet — we're exploring it. Mac and iPhone are available now. Add your email and we'll tell you the moment Android happens.
>
> **What's the catch?** There isn't a hidden one. We don't sell your data (we don't have it), and we don't charge a subscription. The app is calm, private, and free; the intelligence is funded by your own key.

### 7.8 Final CTA
> **Your day, with the right thing already on top.**
>
> **[ Download — free ]**     **[ Get the launch note → ]**
>
> *One email at launch and when Android arrives. No spam, never sold, unsubscribe anytime.*

---

## 8. Funnel & CTAs (the conversion map)

### 8.1 Two actions, clearly ranked
- **Primary CTA — App Store download (Mac + iPhone).** Appears in: top bar, hero, final CTA. Links to the App Store product page (universal app; single link that resolves to Mac/iOS appropriately, with explicit "Mac" and "iPhone" affordances where useful). This is the conversion that matters most. **Gating:** until an actual App Store listing exists (master PRD §7.10 currently describes only a dev build/run loop), the download CTA is **not live** — the page ships in "coming soon" mode with **email capture as the primary action** (§11), and flips to the real download CTA the day the listing goes live.
- **Secondary CTA — email capture (launch / TestFlight / Android list).** Appears in: hero (as a quiet text link), and as a real one-field form in the final CTA and footer. This captures the not-yet-ready and the Android-waiters.

### 8.2 The conversion path
```
Visit (organic / PH / HN / word-of-mouth)
   │
   ├─ 5-sec hero lands → scroll → "what we left out" seals it → DOWNLOAD  ★ primary win
   │
   ├─ Convinced but not on a Mac/iPhone right now,
   │     or waiting for Android/sync → EMAIL CAPTURE         ★ secondary win
   │
   └─ Skeptical about the key → reads Pricing + Privacy + FAQ
         → reassured (no key needed) → DOWNLOAD
         → or still hesitant → EMAIL CAPTURE (nurtured to download at launch)
```

### 8.3 The BYO-key, de-scared, in the funnel
The single biggest conversion risk (master PRD §13: "BYO-key onboarding friction — High") is that "bring your own API key" scares a non-technical visitor into bouncing. Mitigations on the site:
- **Lead with "free + works with no key."** The key is *never* the headline. It appears only in Pricing/FAQ, always framed as optional and as an upgrade.
- **The collapsible "How the key works"** keeps technical detail out of the main flow.
- **Never gate the download CTA behind any key talk** — a visitor can decide to download before ever reading about keys.

### 8.4 No dark patterns (a hard rule)
- No exit-intent popups, no scroll-locked modals, no countdime timers, no "12 people are looking at this," no pre-checked email opt-ins, no cookie wall. The email field is plain, optional, and honest. Restraint *is* the conversion strategy for this audience — the calm-seeker converts *because* we didn't manipulate them.

---

## 9. Tech & ops

### 9.1 Stack recommendation
- **Build:** **Astro** (static output) is the recommended choice — it ships zero JS by default, supports component authoring, trivially produces a single fast HTML page, and lets the few interactive bits (FAQ accordions, email form, video) be tiny islands. *Alternatives, acceptable:* Next.js with `output: 'export'` (static export) if the team already lives in Next; or **hand-rolled HTML/CSS + a sprinkle of vanilla JS** for the absolute minimum footprint (entirely viable for a one-page site and the most on-brand for "calm/minimal"). **Avoid** anything that ships a heavy client runtime for a brochure (no SPA framework hydration for content that's static).
- **Why static:** the calm brand *demands* speed; a static page is the fastest, cheapest, most private option; there is no app logic to host (the product is native).
- **CSS:** hand-written CSS with custom properties for the "Settle" tokens (or a minimal utility layer). No heavy CSS framework.

### 9.2 Hosting
- **Recommended:** **Cloudflare Pages** or **Netlify** or **Vercel** (static) — all give global CDN, automatic HTTPS, atomic deploys, and a generous free tier. **GitHub Pages** is also fine for a pure static one-pager. Pick based on the team's existing accounts; Cloudflare Pages is marginally preferred for edge performance + privacy posture + the Plausible-friendly proxy option.
- Custom domain (e.g. `smarttdl.app` or `smarttdl.com`), HTTPS enforced, HSTS.

### 9.3 Performance budget (the calm brand made measurable)
| Metric | Budget |
|---|---|
| Total page weight (initial view) | **≤ 600 KB** excluding the hero loop; **≤ 2.1 MB** including the ≤1.5 MB loop |
| JS shipped | **≤ 30 KB** (ideally near-zero; accordions can be CSS/`<details>`) |
| Fonts | Playfair subset self-hosted woff2, ≤ ~40 KB; body uses system stack (0 download) |
| LCP (4G, mid mobile) | **< 1.5 s** |
| CLS | **< 0.05** |
| Lighthouse (all categories) | **≥ 95** |
- Self-host all assets (fonts, video) — no third-party CDNs in the critical path (speed + privacy). Lazy-load the hero loop's poster→video; below-fold images `loading="lazy"`. Preload the Playfair subset and the hero poster frame.

### 9.4 Responsive / mobile-first
- Design mobile-first (the calm-seeker and many PH/HN visitors arrive on a phone). Single column on mobile; the 2×2 quadrant degrades to stacked captioned cards (§5.3); the hero loop swaps to a lighter/shorter clip or the static frame on small screens / slow connections.

### 9.5 Accessibility (WCAG 2.1 AA)
- Color contrast AA for all text on warm paper (verify terracotta-on-paper and muted-grey-on-paper meet 4.5:1 for body, 3:1 for large text).
- **`prefers-reduced-motion: reduce`** disables autoplay/section animations and shows static frames (§6.3).
- Full keyboard navigation; visible focus rings (terracotta, the one sanctioned accent moment); logical heading order (one `<h1>`, sequential `<h2>`s).
- Alt text on every image; the 2×2 quadrant has a descriptive text alternative; the hero video has no essential audio (silent) and a text description nearby.
- Forms: labeled email input, error/success messaging announced via `aria-live`.

### 9.6 Privacy-respecting analytics (consistent with the promise)
- **Use Plausible or Fathom** (cookieless, no personal data, no cross-site tracking, EU-hosted options). **No Google Analytics, no Meta pixel, no session recording, no fingerprinting.**
- Because there are no tracking cookies and no personal data collected, **no cookie-consent banner is required** — which is itself on-brand (a calm page with no nag bar). State the analytics choice plainly in the privacy section.
- Track only: pageviews, the two CTA click events (download-click, email-submit), and traffic source — enough to compute the funnel, nothing that identifies a person.

### 9.7 Email capture backend
- A privacy-respecting list provider (e.g. Buttondown, EmailOctopus, or ConvertKit) with a single-field embed or a tiny serverless POST. GDPR-honest: explicit, single opt-in, no pre-check, easy unsubscribe, no list-selling. Store only the email; no behavioral profiling.

### 9.8 SEO
- **Target terms** (from the brief): *calm to-do app*, *AI to-do app no subscription*, *minimal task manager*, *to-do app that prioritizes for you*, plus long-tail: *to-do app no monthly fee*, *Things 3 alternative with AI*, *bring your own API key to-do app*, *private to-do app no account*.
- **On-page:** one `<h1>` carrying the primary term-laden promise; semantic `<h2>` section headings; descriptive `<title>` (~"Smart TDL — the calm AI to-do app that prioritizes for you. Free, no subscription.") and meta description; `JSON-LD` `SoftwareApplication` schema (name, OS = macOS/iOS, price = free, no subscription); descriptive image alt text; clean single canonical URL.
- **Off-page:** App Store listing copy aligned with the same terms (cross-link); the launch posts (HN/PH) drive initial backlinks. Sitemap.xml + robots.txt (allow all, no creepy disallows).
- **OG/social:** the single OG card (§6.5) so shares look intentional on iMessage/Slack/X/HN-preview.

---

## 10. Launch plan & success metrics

### 10.1 Pre-launch
- **Ship a "coming soon" hero + email capture first** (weeks before App Store approval): the same brand, the thesis line, and one email field. Goal: build a small warm list for launch day.
- Seed the list via the builder's own network, relevant Slack/Discord communities (productivity, indie Mac apps, Anthropic/Claude builders), and a short "I built the simple+smart quadrant" note.

### 10.2 Launch-day sequence
1. **App Store live** → flip the site from "coming soon" to full page; email the pre-launch list first (they convert best, and seed early reviews/ratings).
2. **Product Hunt** launch — assets ready (gallery = the week-board loop, the quadrant, the "what we left out" image). Lead comment tells the empty-quadrant story.
3. **Hacker News** — a "Show HN: Smart TDL — a calm to-do app with an invisible AI ranker (BYO Anthropic key, no subscription)" post. HN will scrutinize privacy + BYO-key — the site's honest privacy/pricing sections are pre-built rebuttals.
4. **Communities** — r/productivity, r/macapps, indie-Mac and Claude/Anthropic builder spaces. Same honest framing; no spammy cross-posting.
5. **Throughout:** respond calmly, point skeptics to the privacy and "what we left out" sections, collect objections to feed back into copy.

### 10.3 Success metrics (privacy-respecting)
North-star for the site is **visit→download conversion** from qualified traffic — not raw pageviews.

| Metric | Definition | Target (launch window) |
|---|---|---|
| **Visit → download** | unique visitors → App Store click-through | **≥ 8–12%** from qualified sources (PH/HN/communities) |
| **Visit → email** | visitors → email submit (for the not-yet-ready) | **≥ 4–6%** |
| **Combined conversion** | download OR email | **≥ 12–18%** |
| **Bounce / 5-sec hold** | fraction who scroll past the hero | high scroll-past = hero is landing |
| **CTA split** | download vs. email share | informs whether platform gaps (Android/sync) are blocking |
| **Source quality** | conversion by referrer | double down on the channels that convert, not the loudest |
| **Pre-launch list size** | emails captured before App Store live | a meaningful warm list for day-one reviews |

- **Measurement plan:** Plausible/Fathom goals on the two CTA events + referrer; no per-user funnels, no PII, no cross-site. We infer the funnel from aggregate event counts, honoring the same privacy bar we advertise.
- **Guardrail (anti-metric), inherited from master PRD §12:** we do **not** optimize for time-on-page or "engagement" — a marketing page that holds someone for ten minutes failed; the win is a fast, confident decision (download or email) and a calm exit. Long dwell without conversion = the page is confusing, not "engaging."

### 10.4 Post-launch iteration
- A/B the hero headline (A vs. C from §4) via the static host's split feature or a tiny edge function; change one thing at a time.
- Feed the top live objections (from HN/PH/support email) back into the FAQ and Pricing copy.
- Add an Android announcement banner only when the Android PRD reaches a shippable milestone (keep the platforms line honest until then).

---

## 11. Principle compliance & the temptations to resist

The site must honor the same constitution as the app (master PRD §4). The temptations unique to *marketing a calm product* and the ambient alternative:

| Temptation (web) | Why it's tempting | The on-brand alternative |
|---|---|---|
| Show an "AI" badge / "Powered by Claude" hero brain graphic | "AI" sells | Show the *float-up* loop — intelligence as a felt outcome, never a logo (P1) |
| Exit-intent popup / countdown to boost email signups | classic CRO lift | A single honest email field; trust converts the calm-seeker, manipulation repels them |
| Google Analytics + Meta pixel for "real" data | everyone does it | Plausible/Fathom; the absence of trackers *is* a privacy proof (P9) |
| Lead with "bring your own API key" as a differentiator | it's genuinely novel | Lead with "free + the right thing on top"; key is an optional footnote (P8, §8.3) |
| Add a feature-comparison mega-table vs. 10 competitors | converts comparison shoppers | The one 2×2 quadrant — the argument, not a spec war (P3 minimal) |
| Promise Android / sync dates to capture more emails | reduces bounce | State "exploring"/"on the roadmap" honestly; overpromising betrays the trust moat |
| Heavy scroll animations / parallax to feel "premium" | looks modern | Calm, eased, reduced-motion-respecting micro-motion; the app's "settle," not a sizzle reel |

If a proposed site element needs a new tracker, a manipulative pattern, or a loud "AI" surface, it's wrong by default — find the calm version, exactly as the app does.

---

## 12. Roadmap (phased, with done criteria)

Sequenced so a credible page exists early (for the pre-launch list) and deepens toward launch.

### Phase 0 — Skeleton + brand foundation
- [ ] Repo + static toolchain (Astro or hand-rolled) deployed to chosen host with custom domain + HTTPS.
- [ ] "Settle" tokens as CSS custom properties (light/dark via `prefers-color-scheme`); Playfair subset self-hosted; system-sans body.
- [ ] Hero (Option A) + one-field email capture wired to the list provider; privacy-respecting analytics installed.
- **Done when:** a real, on-brand "coming soon" hero is live, captures emails, scores Lighthouse ≥ 95, sets zero tracking cookies, and renders correctly in light/dark on mobile + desktop.

### Phase 1 — Full narrative page
- [ ] All sections built (pain, 2×2 quadrant, how-it-works, "what we left out", pricing, privacy, platforms, FAQ, final CTA, footer) with the §7 copy.
- [ ] 2×2 quadrant SVG + mobile stacked fallback + text alternative.
- [ ] Real app screenshots (Mac week board, iPhone day list) placed.
- [ ] OG/social card + JSON-LD + SEO meta complete.
- **Done when:** the page tells the full empty-quadrant story end-to-end, passes WCAG AA (contrast, keyboard, reduced-motion), holds the performance budget (§9.3), and a cold reader who only sees this page understands the product, the price, and the privacy model.

### Phase 2 — The hero loop + launch readiness
- [ ] Captured, optimized, seamless ≤1.5 MB silent week-board float-up loop with static reduced-motion fallback frame.
- [ ] App Store badges live (Mac + iPhone), download CTA links verified on both platforms.
- [ ] Plausible/Fathom goals defined for download-click + email-submit; funnel dashboard ready.
- [ ] PH/HN/community assets prepared (gallery, "Show HN" draft, lead comments).
- **Done when:** the hero loop autoplays silently (and degrades to a static frame under reduced motion), both store links resolve correctly, and the funnel events fire and report in analytics.

### Phase 3 — Launch + iterate
- [ ] Flip "coming soon" → full page; email the pre-launch list; execute the §10.2 sequence.
- [ ] A/B hero headline (A vs. C); feed live objections into FAQ/Pricing.
- [ ] Add Android announcement only when the Android PRD hits a shippable milestone.
- **Done when:** launch-window visit→download and visit→email hit the §10.3 targets from qualified sources, measured with privacy-respecting analytics, and the copy has absorbed at least one round of real objections.

---

## 13. Cross-document dependencies (keep consistent)

- **Thesis, seven pains, ten principles, non-goals, "Settle"/"Gravity Field" design languages** — all sourced from master `docs/PRD.md`; if those change there, this page's copy and the 2×2 must follow. The master is the source of truth.
- **Platform availability line (Mac + iPhone now; Android "exploring")** — must stay in lockstep with the **Android PRD's** stated status. The site states current truth and signals openness without a date; do not let the site get ahead of the Android PRD.
- **Sync messaging** — the FAQ says "sync is on the roadmap via iCloud, local-first." Keep aligned with master PRD §7.8 / Phase 1; don't claim sync is shipped until it is.
- **Sync story scope (Apple = iCloud; Android = separate/user-owned)** — any iCloud claim on the page must be scoped to **Mac + iPhone**; never imply iCloud syncs Android (master PRD §7.8, [`PRD-android.md`](PRD-android.md) §0.3). The FAQ's Android caveat must stay in place.
- **BYO-key mechanics** (Keychain storage, only titles + minimal context to Anthropic, only with a key) — must match master PRD §7.9 / P8 / P9 exactly; the privacy/pricing copy is a public promise and cannot drift from the implementation.
- **"Invisible AI" rule (P1)** — the site must never show a UI surface (chat/score/AI-panel) the app doesn't have; the marketing visuals and the app's actual surfaces stay in sync.

---

## 14. Open questions

1. **Domain:** `smarttdl.app` vs `smarttdl.com` vs other — pick before Phase 0 (affects branding, OG, App Store links).
2. **Hero headline for launch:** ship Option A and A/B against C, or lead with the positioning-forward B? (Decide with the first 1–2 weeks of A/B data.)
3. **One App Store link vs. separate Mac/iPhone CTAs:** does the universal-app single link resolve cleanly on both, or do we want explicit "Get it on the Mac App Store" + "Download on the App Store" badges? (Verify at Phase 2.)
4. **How prominent is BYO-key allowed to be** before it scares non-technical visitors vs. how much the indie/HN crowd *wants* to see it upfront? (Tune via launch objections; default keeps it in Pricing/FAQ only.)
5. **Android email capture framing:** a dedicated "notify me about Android" toggle on the form, or one combined launch list? (Lean combined for simplicity; revisit if Android demand is loud.)
6. **Static-host A/B mechanism:** Cloudflare/Netlify split testing vs. a tiny edge function vs. Plausible-driven manual rotation — pick the lightest one that doesn't add client JS or trackers.
7. **Do we publish a public roadmap page** (sync, time-layer, Android) or keep the site purely promotional and route roadmap interest to the email list? (Leaning email-list-only to avoid promising dates.)
