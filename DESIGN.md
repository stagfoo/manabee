---
name: Neo-Manga Cyberpunk
colors:
  surface: '#131317'
  surface-dim: '#131317'
  surface-bright: '#39393d'
  surface-container-lowest: '#0e0e12'
  surface-container-low: '#1b1b1f'
  surface-container: '#1f1f23'
  surface-container-high: '#2a292e'
  surface-container-highest: '#353439'
  on-surface: '#e4e1e7'
  on-surface-variant: '#c7c9ad'
  inverse-surface: '#e4e1e7'
  inverse-on-surface: '#303034'
  outline: '#909379'
  outline-variant: '#464833'
  surface-tint: '#bad200'
  primary: '#ffffff'
  on-primary: '#2d3400'
  primary-container: '#d6ef28'
  on-primary-container: '#5e6b00'
  inverse-primary: '#586400'
  secondary: '#ccbdff'
  on-secondary: '#360096'
  secondary-container: '#4e0fcb'
  on-secondary-container: '#bca9ff'
  tertiary: '#ffffff'
  on-tertiary: '#003824'
  tertiary-container: '#4ffeb9'
  on-tertiary-container: '#00734f'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#d6ef28'
  primary-fixed-dim: '#bad200'
  on-primary-fixed: '#191e00'
  on-primary-fixed-variant: '#424b00'
  secondary-fixed: '#e7deff'
  secondary-fixed-dim: '#ccbdff'
  on-secondary-fixed: '#1f005f'
  on-secondary-fixed-variant: '#4e0fcb'
  tertiary-fixed: '#4ffeb9'
  tertiary-fixed-dim: '#1ce19f'
  on-tertiary-fixed: '#002114'
  on-tertiary-fixed-variant: '#005237'
  background: '#131317'
  on-background: '#e4e1e7'
  surface-variant: '#353439'
typography:
  headline-xl:
    fontFamily: Outfit
    fontSize: 40px
    fontWeight: '800'
    lineHeight: 48px
    letterSpacing: -0.02em
  headline-xl-mobile:
    fontFamily: Outfit
    fontSize: 30px
    fontWeight: '800'
    lineHeight: 38px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Outfit
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Outfit
    fontSize: 20px
    fontWeight: '700'
    lineHeight: 28px
  body-lg:
    fontFamily: Outfit
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
  body-md:
    fontFamily: Outfit
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-mono-bold:
    fontFamily: Space Mono
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.06em
  label-mono-sm:
    fontFamily: Space Mono
    fontSize: 10px
    fontWeight: '700'
    lineHeight: 14px
    letterSpacing: 0.08em
  label-pill:
    fontFamily: Outfit
    fontSize: 13px
    fontWeight: '700'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-mobile: 0.75rem
  margin: 1.5rem
  margin-mobile: 1.25rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
  space-2xl: 3rem
---

## Brand & Style

This design system channels an electric cyberpunk otaku aesthetic tailored for immersive Japanese manga learning. It bridges high-energy Japanese street culture, classic manga panels, and neon-lit retro-futuristic arcade interfaces. The emotional experience balances the thrill of late-night Shinjuku gaming with the razor-sharp clarity required for deep language acquisition.

The visual mood pairs an ultra-deep obsidian space (#0D0D11) with a subtle technical blueprint grid. High-voltage accents—hyper-saturated neon lime and electric violet—energize the experience, turning repetitive vocabulary flashcards and JLPT drill sessions into tactile, game-like quests. Elements feature soft-curved pills, bold border definitions, and stark typography contrast, delivering a playful yet sophisticated UI optimized for manga artwork, furigana annotations, and rapid micro-interactions.

## Colors

The palette is engineered specifically for deep dark mode, ensuring zero eye strain during prolonged reading while making interactive elements snap to life:

- **Primary (`#E3FD38`):** Electric Neon Lime. Used for primary CTAs, completion rates, current chapter progress bars, and critical grammar callouts. When placed on pitch black, it offers extreme contrast. Text on top of this color must be pure pitch black (`#0D0D11`) at heavy weights.
- **Secondary (`#7B52F8`):** Electric Violet / Neon Amethyst. Used for vocabulary flashcards, secondary tags, completed states, and interactive pills. Provides a vibrant balance against the neon lime.
- **Tertiary (`#2EE9A6`):** Cyber Cyan-Mint. Reserved for positive reinforcement, correct review streaks, JLPT milestone badges, and secondary learning highlights.
- **Neutral Palette:** 
  - Canvas background: `#0D0D11` (Obsidian Pitch Black).
  - Surface cards & modals: `#16161F` (Charcoal Tint) and `#1E1E2A` (Elevated Surface).
  - Outlines & tech grids: `#282838` (Grid border lines at 24%–40% opacity).
  - Typography: `#FFFFFF` for primary headings, `#A0A0B5` for secondary subtitles/furigana notes, and `#6C6C82` for inactive elements and grid patterns.

## Typography

The typography unites **Outfit**—a modern, geometric sans-serif with rounded apexes and punchy character—with **Space Mono** for metadata, JLPT tags, Romaji/Kanji column headers, and technical counter stats.

- **Headlines & Titles:** Use Outfit at weights 700 and 800. Headers command immediate focus against the pitch-black backdrop.
- **Japanese Kanji & Reading Text:** Japanese glyphs should pair cleanly with Outfit's geometric structure, maintaining ample line-height (`1.5` to `1.7`) to give furigana annotations room above Kanji glyphs.
- **Labels, Badges, and Stats:** Space Mono at bold weight brings an authentic anime tech HUD feel to dictionary keys (`ENGLISH`, `ROMAJI`, `FURAGANA`, `KANJI`), flashcard indexes (`3/50`), and chapter counters (`01# Chapter`).

## Layout & Spacing

The layout utilizes a structured fluid grid overlaid on a fixed background grid (16px by 16px technical line pattern rendered with `rgba(255, 255, 255, 0.04)`).

- **Mobile Viewports (< 640px):** 4-column layout with `1.25rem` outer canvas padding. Manga thumbnail carousels and multi-column vocabulary panels stack or use horizontal momentum scrolling.
- **Tablet / Desktop (≥ 768px):** 8 to 12 columns with centered app containers (maximum 480px width for standard reading phone mode, or 1080px for dual-page split reader screens).
- **Rhythm & Stacking:** Micro component spacing relies on strict multiples of 4px/8px. Card content maintains `space-md` (`1rem`) internal padding. Critical action buttons use `space-lg` (`1.5rem`) touch clearances to guarantee thumb accessibility.

## Elevation & Depth

Rather than relying on soft realistic drop shadows, this design system establishes depth through **luminous glow highlights, tonal stacking, and high-contrast structural borders**:

1. **Backdrop Base:** Pure obsidian (`#0D0D11`) embossed with the faint technical grid.
2. **Elevated Card Deck (Tier 1):** Solid `#16161F` with a crisp `1px` stroke in `#2E2E42`. Hover or active states introduce a subtle `0px 0px 16px rgba(123, 82, 248, 0.25)` violet aura.
3. **Active Interactive Cards (Flashcards & Vocabulary Blocks):** Solid saturated fills (`#E3FD38` or `#7B52F8`) that visually pop ahead of the background plane. They feature razor-sharp inner borders or slight bottom extrusion accents (`2px solid rgba(0, 0, 0, 0.3)`).
4. **Floating HUD / Bottom Navigation:** Floating pill docks elevated above the page with frosted glass backing (`backdrop-filter: blur(20px); background: rgba(18, 18, 24, 0.85);`) encircled by a `1px` border of `rgba(255, 255, 255, 0.12)`.

## Shapes

The shape system adopts a hybrid "curved pill and game console" aesthetic. Standard components leverage `roundedness: 2` (base 8px radius, 16px on `rounded-lg`, and 24px on `rounded-xl`), creating tactile, approachable forms that contrast with the technical backdrop:

- **Buttons & Chips:** Fully rounded pills (`border-radius: 9999px`) for quick-action pills, navigation switches, and comment counters.
- **Flashcards & Manga Covers:** `1.5rem` (`rounded-xl` / 24px) corners, giving learning cards a toy-like, collectible feel.
- **Chapter Rows & Input Fields:** High-durability capsule rows with `1rem` (`rounded-lg` / 16px) corners and defined 1.5px outlines.

## Components

### Buttons & Interactive Controls
- **Primary Buttons:** High-voltage neon lime (`#E3FD38`) fill with pitch-black (`#0D0D11`) bold Outfit typography. Pill-shaped or `rounded-xl`. Active state compresses slightly (`transform: scale(0.97)`).
- **Secondary Buttons & Directional Arrows:** Electric violet (`#7B52F8`) circular or pill containers with crisp white icons or text.
- **Ghost / Outlined Actions:** `#16161F` background, `1.5px` border in `#3E3E56`, and bright white text.

### Segmented Vocabulary Chips & Grid Blocks
- Segmented vocabulary chips group reading attributes horizontally (`ENGLISH | ROMAJI | FURAGANA | KANJI`).
- Each unit uses rounded block pills (`12px` corner radius) nested seamlessly or connected in segmented bands.
- Column headers are displayed in `label-mono-sm` using monospaced Space Mono in muted tone or black.
- Card values (e.g., words, Kanji) use bold Outfit typography.

### Chapter & Progress Rows
- Enclosed in `#16161F` pill-shaped bounding rows with a `1.5px` stroke (`#2A2A3B`).
- Indicator nodes on the left display progress status (solid neon yellow circle = complete; half-filled circle = in-progress; hollow ring = unread).
- Trailing badges feature an electric neon background with a speech bubble icon and count.

### Flashcard Carousel
- Large focal cards (`min-height: 320px`, `rounded-xl` 24px) draped in saturated electric violet (`#7B52F8`) or deep obsidian with an active neon glow.
- Central Kanji displays at `headline-xl` (40px+) with furigana centered precisely above.
- Floating helper icon in the top right corner for audio pronunciation and card flips.
- Directional nav pills below card (`←` / index counter `3/50` / `→`).

### Progress Bars
- High-contrast two-stage bars: unfilled track in dark slate (`#262636`), active track filled with electric neon lime (`#E3FD38`) or electric violet (`#7B52F8`). Rounded cap ends.

### Bottom Navigation Bar
- Anchored floating dock with deep charcoal glassmorphism background.
- Active tab indicated by a bright circular pill highlight (pure white icon on neon circle or stark white pill container). Inactive tabs render as crisp geometric line icons in `#6C6C82`.