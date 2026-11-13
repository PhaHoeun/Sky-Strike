# Design System: Apex Avionics HUD (Sky Strike)
**Project ID:** 3612790780372566216
**Design System Asset:** `assets/e638dd014a504b22a4402afb91e2c202`

## 1. Visual Theme & Atmosphere
**Sky Strike (Apex Avionics HUD)** channels clinical military-sci-fi flight avionics balanced with sleek modern cockpit glassmorphism in a 9:16 mobile portrait view. Deep slate navy and carbon-fiber surfaces frame razor-sharp beveled HUD cards, glowing electric cyan telemetry wireframes, CRT grid subtleties, and high-impact tactile action capsules.

## 2. Color Palette & Roles
* **Deep Slate Navy (`#0C1320` / `#070E1B`):** Primary viewport background and carrier hangar/blueprint void.
* **Gunmetal Carbon Surface (`#151C29` / `#19202D` / `#232A38`):** Beveled HUD pods, chassis cards, carousel tiles, and navigation docks.
* **Frosted Cockpit Glass (`rgba(21, 28, 41, 0.78)` with `backdrop-filter: blur(14px)`):** Semi-transparent HUD overlays over 3D battle clouds and hangar bays.
* **Electric Cyan (`#00E5FF` / `#00DAF3`):** Primary HUD wireframes, L-bracket corner reticles, Speed bars, blueprint schematic lines, active nav states, and the Victory "Next Mission" capsule CTA.
* **Warning Orange (`#FE6B00` / `#FF6B00`):** Bold glowing "TO BATTLE!" capsule CTA, Overdrive heat gauges, enemy lock-on alerts, and Firepower bars.
* **Tactical Emerald Green (`#22EF7E` / `#00E676`):** Bright green "UPGRADE" pill CTA, positive stat boost deltas, Shield/Armor meters, and LIVE indicators.
* **Achievement Gold (`#FFB800` / `#FFD700`):** Player rank insignia, credits badges, gleaming victory stars, and "MISSION ACCOMPLISHED!" banner ribbon.
* **Crisp White (`#DCE2F5` / `#F8FAFC`) & Steel Gray (`#849396` / `#BAC9CC`):** Primary cockpit headings and muted technical labels.

## 3. Typography Rules
* **Headlines & Callsigns (`Space Grotesk`):** Uppercase geometric sans-serif with bold weights (600–800) and wide tracking (`0.05em`–`0.12em`) for aircraft titles, banners, and primary CTA buttons.
* **Telemetry & Labels (`JetBrains Mono` / `Plus Jakarta Sans`):** Tabular monospaced numerals for scores, percentages (`40%`), credit/gem counts, energy gauges, and stat readouts without layout jitter.

## 4. Component Stylings
* **Cards & Telemetry Pods:** Sharp beveled gunmetal cards (`rounded-sm` / chamfered corners) with `1px` electric cyan or steel borders (`#3B494C`), `hud-bracket` L-corner ticks, and inner photonic glow.
* **Primary Capsule & Pill CTAs:** Bold glowing capsule/pill buttons (`rounded-full`) for key flow transitions ("TO BATTLE!", "Next Mission", "UPGRADE") with gradient fill, subtle specular border, and neon underglow.
* **HUD Controls & Meters:** Segmented 10-block progress bars, circular radial/joystick flight rings, and tactile circular military weapon trigger pads.

## 5. Layout Principles
* **9:16 Mobile Portrait (`390x844` / `390x884`):** Single-frame vertical layout with zero horizontal overflow.
* Top perimeter hosts compact telemetry/status pods; center canvas showcases the 3D aircraft/combat/modal/blueprint focal stage; bottom perimeter anchors ergonomic thumb controls and docked navigation.

## 6. Design System Notes for Stitch Generation
Use this block verbatim in `.stitch/next-prompt.md` for every screen iteration:

```text
**DESIGN SYSTEM (REQUIRED):**
- Platform: Mobile, 9:16 portrait smartphone frame (390x844)
- Design System: Apex Avionics HUD — military sci-fi cockpit aesthetic, sleek modern glassmorphism, sharp beveled tactical HUD cards with cyan L-bracket corner reticles, carbon-fiber and gunmetal surfaces, glowing neon telemetry lines
- Color Palette:
  - Background: Deep Slate Navy (#0C1320 / #070E1B) with subtle HUD grid overlay
  - Surfaces: Gunmetal Gray (#151C29, #19202D, #232A38) with frosted glassmorphic overlays and 1px hairline borders (#3B494C / rgba(0,229,255,0.3))
  - Primary Accent: Electric Cyan (#00E5FF) for HUD wireframes, targeting reticles, schematic lines, active states, and primary cyan Victory CTA
  - Battle / Heat Accent: Warning Orange (#FE6B00 / #FF6B00) for battle triggers, overdrive boost, and hostile missile locks
  - Upgrade / Shield Accent: Tactical Emerald Green (#22EF7E / #00E676) for upgrade pill CTAs, positive stat deltas, and shield/armor integrity
  - Reward / Rank Accent: Achievement Gold (#FFB800) for stars, victory banners, rank badges, and credit icons
  - Text: Crisp White (#DCE2F5 / #F8FAFC) primary, Steel Gray (#849396 / #BAC9CC) secondary
- Typography: Space Grotesk bold uppercase headers + JetBrains Mono crisp tabular telemetry numerals and technical micro-tags
- Controls & Geometry: Sharp beveled gunmetal cards paired with glowing full-pill/capsule primary CTA buttons and tactile circular military-grade HUD controls
```
