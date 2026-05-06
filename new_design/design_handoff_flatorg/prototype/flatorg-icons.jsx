// Three app-icon concepts for Flatorg, rendered to iOS + Android specs.
//
// SHAPES:
//   iOS:     squircle / rounded square (1024×1024, ~22.37% radius)
//   Android: adaptive icon — design fills a 108dp safe zone inside a 108dp+ canvas
//            shown as Circle, Squircle, and RoundedSquare so we can verify masks don't crop key marks.
//
// CONCEPTS:
//   Icon 1 — Refined original: house + broom + sparkles, stronger geometry, single weight.
//   Icon 2 — Monogram "F" built from a chevron-roof + checklist (new direction).
//   Icon 3 — Stacked rooms: overlapping doorway shapes representing the shared flat (new direction).

// ─────────────────────────────────────────────────────────────
// Icon artwork (each renders into a 100×100 viewBox so we can scale)
// ─────────────────────────────────────────────────────────────

// Concept 1 — Refined house + broom (improved version of the original)
function FOIcon1Art({ fg = '#FFFFFF' }) {
  return (
    <svg viewBox="0 0 100 100" width="100%" height="100%">
      {/* House silhouette — a simple, confident geometric house */}
      <g fill="none" stroke={fg} strokeWidth="5" strokeLinejoin="round" strokeLinecap="round">
        {/* roof + walls in one stroke */}
        <path d="M22 50 L50 26 L78 50 L78 74 L22 74 Z" />
        {/* chimney bar (omitted for cleanliness) */}
      </g>
      {/* Door inset — solid */}
      <rect x="44" y="56" width="12" height="18" rx="1.5" fill={fg} />
      {/* Broom — clearly a broom: angled handle + fanned trapezoidal bristles with vertical lines */}
      <g transform="rotate(-20 30 60)">
        {/* handle */}
        <rect x="28" y="30" width="4" height="32" rx="2" fill={fg}/>
        {/* binding at top of bristles */}
        <rect x="24" y="60" width="12" height="4" rx="1" fill={fg}/>
        {/* bristle fan (trapezoid, wider at bottom) */}
        <path d="M22 64 L38 64 L44 80 L16 80 Z" fill={fg}/>
        {/* bristle striations (slightly darker tone via opacity) */}
        <g stroke="rgba(228,142,92,0.55)" strokeWidth="1.2" strokeLinecap="round">
          <line x1="22" y1="66" x2="20" y2="79"/>
          <line x1="26" y1="66" x2="25.5" y2="79"/>
          <line x1="30" y1="66" x2="30" y2="79"/>
          <line x1="34" y1="66" x2="34.5" y2="79"/>
          <line x1="38" y1="66" x2="40" y2="79"/>
        </g>
      </g>
      {/* Sparkles — confident, bigger */}
      <g fill={fg}>
        <path d="M76 28 l1.5 4.5 4.5 1.5 -4.5 1.5 -1.5 4.5 -1.5 -4.5 -4.5 -1.5 4.5 -1.5z" />
        <circle cx="68" cy="42" r="1.6" />
      </g>
    </svg>
  );
}

// Concept 2 — Monogram F formed by roof + checklist tick
function FOIcon2Art({ fg = '#FFFFFF' }) {
  return (
    <svg viewBox="0 0 100 100" width="100%" height="100%">
      {/* Big confident "F" in a slab/geometric weight */}
      <g fill={fg}>
        <rect x="28" y="22" width="10" height="56" rx="2" />
        <rect x="28" y="22" width="44" height="10" rx="2" />
        <rect x="28" y="46" width="32" height="10" rx="2" />
      </g>
      {/* A check-mark planted in the F's lower opening — task-done DNA */}
      <path d="M62 64 L70 72 L84 56" stroke={fg} strokeWidth="6" strokeLinecap="round" strokeLinejoin="round" fill="none"/>
    </svg>
  );
}

// Concept 3 — Stacked / overlapping rooms (shared flat metaphor)
function FOIcon3Art({ fg = '#FFFFFF', accent = 'rgba(255,255,255,0.55)' }) {
  return (
    <svg viewBox="0 0 100 100" width="100%" height="100%">
      {/* Back room — soft fill */}
      <path d="M20 44 L42 26 L64 44 L64 74 L20 74 Z" fill={accent} />
      {/* Front room — bold outline */}
      <g fill="none" stroke={fg} strokeWidth="5" strokeLinejoin="round" strokeLinecap="round">
        <path d="M36 54 L58 36 L80 54 L80 78 L36 78 Z" />
      </g>
      {/* Front door */}
      <rect x="52" y="60" width="12" height="18" rx="1.5" fill={fg} />
      {/* Tiny chimney/window dot on back room */}
      <circle cx="32" cy="58" r="3" fill={fg}/>
    </svg>
  );
}

// ─────────────────────────────────────────────────────────────
// Backgrounds for each concept
// ─────────────────────────────────────────────────────────────
const FO_ICON_VARIANTS = {
  // 1 = refined original (warm orange — keeps DNA of original)
  1: {
    name: 'Refined classic',
    sub: 'House + broom · keeps original DNA',
    bg: '#E48E5C',
    bgGradient: 'linear-gradient(140deg, #F0A06B 0%, #D87740 100%)',
    Art: FOIcon1Art,
  },
  // 2 = monogram on Flatorg deep teal
  2: {
    name: 'Monogram',
    sub: '"F" + checklist · brand-forward mark',
    bg: '#0E5648',
    bgGradient: 'linear-gradient(140deg, #1A7763 0%, #0A4537 100%)',
    Art: FOIcon2Art,
  },
  // 3 = stacked rooms on mint→teal gradient
  3: {
    name: 'Shared flat',
    sub: 'Stacked rooms · communal living',
    bg: '#2F9E7E',
    bgGradient: 'linear-gradient(160deg, #5BC4A4 0%, #1F7A60 100%)',
    Art: FOIcon3Art,
  },
};

// ─────────────────────────────────────────────────────────────
// Shape masks
// ─────────────────────────────────────────────────────────────
function FOIconShape({ variant, shape = 'ios', size = 180 }) {
  const v = FO_ICON_VARIANTS[variant];
  const Art = v.Art;
  // shape → border-radius / clip
  let radius;
  if (shape === 'circle') radius = '50%';
  else if (shape === 'squircle') radius = `${size * 0.28}px`;
  else if (shape === 'ios') radius = `${size * 0.2237}px`; // Apple superellipse approx
  else radius = `${size * 0.18}px`; // android rounded-square

  // Inner safe-zone padding for the artwork. Apple icons fill more; Android adaptive needs ~33% safe zone.
  const padding = shape === 'circle' || shape === 'squircle' ? size * 0.18 : size * 0.14;

  return (
    <div style={{
      width: size, height: size, borderRadius: radius,
      background: v.bgGradient, position: 'relative',
      boxShadow: '0 14px 28px rgba(0,0,0,0.18), inset 0 1px 0 rgba(255,255,255,0.25)',
      overflow: 'hidden',
    }}>
      {/* subtle inner glow for richness */}
      <div style={{
        position: 'absolute', inset: 0, borderRadius: radius,
        background: 'radial-gradient(120% 80% at 30% 20%, rgba(255,255,255,0.18), rgba(255,255,255,0) 60%)',
        pointerEvents: 'none',
      }} />
      <div style={{ position: 'absolute', inset: padding }}>
        <Art />
      </div>
    </div>
  );
}

// A nicely-labelled triplet showing one concept across iOS + Android masks
function FOIconTriplet({ variant }) {
  const v = FO_ICON_VARIANTS[variant];
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 18, fontFamily: FO_FONT, color: FO_COLORS.ink }}>
      <div>
        <div style={{ fontSize: 11, fontWeight: 800, letterSpacing: 0.8, textTransform: 'uppercase', color: FO_COLORS.teal }}>
          Concept {variant}
        </div>
        <div style={{ fontSize: 22, fontWeight: 800, letterSpacing: -0.4, marginTop: 2 }}>{v.name}</div>
        <div style={{ fontSize: 13, color: 'rgba(14,46,30,0.65)', marginTop: 2 }}>{v.sub}</div>
      </div>

      <div style={{ display: 'flex', gap: 28, alignItems: 'flex-start' }}>
        {/* iOS column */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, alignItems: 'center' }}>
          <FOIconShape variant={variant} shape="ios" size={140} />
          <FOIconLabel platform="iOS" detail="Squircle · 22.37% r" />
        </div>

        {/* Android — three masks side by side */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <div style={{ display: 'flex', gap: 14 }}>
            <FOIconShape variant={variant} shape="circle" size={88} />
            <FOIconShape variant={variant} shape="squircle" size={88} />
            <FOIconShape variant={variant} shape="rounded" size={88} />
          </div>
          <FOIconLabel platform="Android" detail="Adaptive · circle · squircle · rounded" />
        </div>
      </div>
    </div>
  );
}

function FOIconLabel({ platform, detail }) {
  return (
    <div style={{ textAlign: 'center', display: 'flex', flexDirection: 'column', gap: 1 }}>
      <div style={{ fontSize: 12, fontWeight: 700, color: FO_COLORS.ink }}>{platform}</div>
      <div style={{ fontSize: 11, color: 'rgba(14,46,30,0.55)' }}>{detail}</div>
    </div>
  );
}

// Phone "home screen" tile — shows what the icon looks like next to other apps (iOS-ish row)
function FOHomeRowPreview({ variant }) {
  const placeholder = (label, color) => (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
      <div style={{
        width: 60, height: 60, borderRadius: 14, background: color,
        boxShadow: '0 4px 10px rgba(0,0,0,0.15)',
      }} />
      <div style={{ fontSize: 11, color: '#fff', fontWeight: 500, letterSpacing: 0.1 }}>{label}</div>
    </div>
  );
  return (
    <div style={{
      padding: 18, borderRadius: 22,
      background: 'linear-gradient(160deg, #2C3E55 0%, #1A2438 100%)',
      display: 'flex', gap: 18, alignItems: 'center', justifyContent: 'center',
      fontFamily: FO_FONT,
    }}>
      {placeholder('Photos', '#F1B543')}
      {placeholder('Mail',   '#3A8AE6')}
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
        <FOIconShape variant={variant} shape="ios" size={60} />
        <div style={{ fontSize: 11, color: '#fff', fontWeight: 500 }}>Flatorg</div>
      </div>
      {placeholder('Maps',   '#7CC36B')}
      {placeholder('Music',  '#E84B6C')}
    </div>
  );
}

Object.assign(window, {
  FOIcon1Art, FOIcon2Art, FOIcon3Art,
  FOIconShape, FOIconTriplet, FOHomeRowPreview, FO_ICON_VARIANTS,
});
