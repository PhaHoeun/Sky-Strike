# Sky Strike — Aerial Combat Mobile UI Flow

## 1. Core Identity
- **Project Name**: Sky Strike (3D Modern Aerial Combat Fighter Jet Game)
- **Stitch Project ID**: `3612790780372566216`
- **Mission**: Deliver a cohesive, high-impact 4-screen mobile portrait (9:16) UI/UX flow for a modern 3D stealth fighter jet combat game, spanning pre-sortie hangar selection, live aerial dogfight HUD, post-mission victory debrief, and tactical blueprint engineering upgrades.
- **Target Audience**: Mobile action and military flight-combat gamers on iOS and Android seeking crisp cockpit telemetry, tactile thumb controls, and satisfying aircraft progression.
- **Voice**: Tactical, high-precision, adrenaline-charged, military sci-fi command.

## 2. Visual Language
- **Primary Vibe**: Military Sci-Fi Cockpit — deep slate navy and carbon-fiber plating framed by razor-sharp beveled HUD cards and glowing electric cyan telemetry wireframes.
- **Secondary Vibe**: Sleek Modern Glassmorphism — translucent frosted cockpit overlays (`rgba(21, 28, 41, 0.78)` with blur) allowing 3D cloudscapes and hangar lighting to breathe behind HUD controls.
- **Tertiary Vibe**: Tactile Arcade Urgency — high-contrast warning orange battle triggers, gleaming gold victory awards, and emerald green engineering upgrade confirmations.

## 3. Architecture & File Structure
- **Output Root**: `site/public/`
- **Staging Area**: `.stitch/designs/` (`{page}.html` and `{page}.png`)
- **Target Viewport**: Mobile 9:16 portrait (`390x844` / `390x884` smartphone frame)
- **Navigation Flow Strategy**:
  - `index.html` (Hangar / Jet Select) → "TO BATTLE!" button links to `gameplay-hud.html`; "Upgrades" bottom nav & "UPGRADE STATS" link to `hangar-upgrade.html`.
  - `gameplay-hud.html` (Active 3D Dogfight HUD) → Objective card / Pause complete option links to `victory-modal.html`; Pause return links to `index.html`.
  - `victory-modal.html` (Mission Accomplished Modal) → "Next Mission" and "Replay" buttons link to `gameplay-hud.html`; hangar/close exit links to `index.html`; bottom nav "Upgrades" links to `hangar-upgrade.html`.
  - `hangar-upgrade.html` (Hangar Upgrade & Engineering) → Back arrow and bottom navigation "Home" link to `index.html`; interactive schematic nodes switch between Engine, Shield, Wing Cannon, and Missiles stats.
  - `showcase.html` → Side-by-side 4-smartphone-frame 9:16 portrait presentation view embedding all 4 screens.

## 4. Live Sitemap
- [x] `index.html` — Hangar / Jet Select Screen
- [x] `gameplay-hud.html` — Active 3D Dogfight Gameplay HUD
- [x] `victory-modal.html` — Mission Accomplished / Victory Modal
- [x] `hangar-upgrade.html` — Hangar Upgrade & Engineering Screen
- [x] `showcase.html` — 4-Frame 9:16 Portrait Flow Showcase

## 5. The Roadmap (Backlog)
- **High Priority**
  - [x] Generate Screen 1 (`index`): Hangar / Jet Select Screen with top status bar, 3D F-22 Raptor stealth fighter on illuminated hexagonal sci-fi platform, Speed/Armor/Firepower stat bars, bottom jet carousel, glowing orange "TO BATTLE!" capsule CTA, and 4-tab bottom navigation.
  - [x] Generate Screen 2 (`gameplay-hud`): Active 3D Dogfight Gameplay HUD over realistic cloudscape with top objective tracker ("Destroy Base: 40%"), stage gauge, pause button, allied vs enemy jets with missile trails, left circular flight joystick, center Overdrive boost, and right missile/shield triggers.
  - [x] Generate Screen 3 (`victory-modal`): Mission Accomplished / Victory Modal overlaid on softly blurred aerial battle backdrop, 3 gleaming gold stars, gold "MISSION ACCOMPLISHED!" banner, stats box ("Boss Destroyed", "Enemies Shot Down", "+450 Credits", "+50 Scrap Metal"), cyan "Next Mission" capsule button, and replay icon button.
  - [x] Generate Screen 4 (`hangar-upgrade`): Hangar Upgrade & Engineering Screen with dark blueprint grid, top-down fighter jet wireframe schematic with Engine/Shield/Wing Cannon/Missiles nodes, stat delta cards (Speed, Armor, Firepower), and bottom credit cost + bright green "UPGRADE" pill button.
- **Medium Priority**
  - [x] Wire full interactive navigation links across all 4 `site/public/*.html` screens and add a cohesive 4-frame 9:16 portrait preview showcase page (`site/public/showcase.html`) so all 4 smartphone frames can be inspected side-by-side.
- **Low Priority**
  - [ ] Alliance Squadron Hub (`alliance.html`)
  - [ ] Armory & Ordinance Shop (`shop.html`)
  - [ ] Campaign Radar Briefing (`campaign-map.html`)

## 6. Creative Freedom Guidelines
- **Alliance Squadron Hub**: Wingman roster, co-op boss raid alerts, and squadron leaderboard.
- **Armory & Ordinance Shop**: Paint liveries, plasma warhead crates, and premium gem bundles.
- **Campaign Radar Briefing**: Satellite tactical map with mission threat ratings and target lock telemetry.

## 7. Technical & Consistency Notes
- Keep all screens strictly mobile portrait 9:16 (`390px` viewport width, no horizontal overflow).
- Enforce shared `.stitch/DESIGN.md` (`assets/e638dd014a504b22a4402afb91e2c202`) palette, beveled card chamfer details, cyan hairline borders, and typography across every iteration.
