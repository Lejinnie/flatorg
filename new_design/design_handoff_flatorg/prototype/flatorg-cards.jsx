// Three task-detail card variations.
// All share: title, due, assigned, subtasks list, close button.
// All preserve the existing teal/mint palette — refined, not redirected.

const FO_SUBTASKS = [
  'Clean toilet',
  'Clean sink (basin + drainage + mirror)',
  'Empty bin + replace toilet rolls',
  'Mopping / vacuuming',
];

// Shared scrim
function FOScrim({ children, align = 'center' }) {
  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 100,
      background: 'rgba(14,30,22,0.45)',
      backdropFilter: 'blur(2px)', WebkitBackdropFilter: 'blur(2px)',
      display: 'flex',
      alignItems: align === 'bottom' ? 'flex-end' : 'center',
      justifyContent: 'center',
      padding: align === 'bottom' ? '0' : '24px',
      fontFamily: FO_FONT,
    }}>
      {children}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// V1 — Refined modal (closest to the original)
// Centered card, mint surface, cleaned-up hierarchy, dividers,
// proper checkbox-style bullets, primary Close button.
// ─────────────────────────────────────────────────────────────
function FOCardV1() {
  return (
    <FOScrim>
      <div style={{
        width: 320, background: '#EDF6E2',
        borderRadius: 24, padding: '22px 22px 16px',
        boxShadow: '0 24px 60px rgba(0,0,0,0.18), 0 0 0 1px rgba(14,46,30,0.05)',
        color: FO_COLORS.ink, display: 'flex', flexDirection: 'column', gap: 14,
      }}>
        {/* Title row */}
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10 }}>
          <div style={{
            width: 4, alignSelf: 'stretch', borderRadius: 99,
            background: FO_COLORS.teal, marginTop: 6, marginBottom: 6,
          }} />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 24, fontWeight: 800, letterSpacing: -0.4, lineHeight: 1.15 }}>Toilet</div>
            <div style={{ fontSize: 12, fontWeight: 600, color: FO_COLORS.teal, marginTop: 4, letterSpacing: 0.4, textTransform: 'uppercase' }}>Weekly cleaning task</div>
          </div>
        </div>

        {/* Meta */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <FOMetaRow label="Due" value="Sun, 26 Apr · 23:59" />
          <FOMetaRow label="Assigned" value="Unassigned" muted />
        </div>

        <div style={{ height: 1, background: 'rgba(14,46,30,0.10)' }} />

        {/* Subtasks */}
        <div>
          <div style={{
            fontSize: 12, fontWeight: 700, color: FO_COLORS.teal,
            textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 10,
          }}>Subtasks · {FO_SUBTASKS.length}</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 11 }}>
            {FO_SUBTASKS.map((s, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'flex-start', gap: 10, fontSize: 15, lineHeight: 1.4 }}>
                <div style={{
                  width: 18, height: 18, borderRadius: 6, marginTop: 2,
                  border: `1.5px solid ${FO_COLORS.teal}`, opacity: 0.5, flexShrink: 0,
                }} />
                <div style={{ flex: 1 }}>{s}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Footer */}
        <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 4 }}>
          <div style={{
            padding: '10px 22px', borderRadius: 99,
            background: FO_COLORS.teal, color: '#fff',
            fontWeight: 700, fontSize: 15,
          }}>Close</div>
        </div>
      </div>
    </FOScrim>
  );
}

function FOMetaRow({ label, value, muted }) {
  return (
    <div style={{ display: 'flex', fontSize: 14 }}>
      <div style={{ width: 76, color: 'rgba(14,46,30,0.55)', fontWeight: 500 }}>{label}</div>
      <div style={{ flex: 1, color: muted ? 'rgba(14,46,30,0.55)' : FO_COLORS.ink, fontWeight: 600 }}>{value}</div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// V2 — Header strip (status-colored)
// Card uses the matching status color band at top to tie back to
// the source task card, then white surface with subtasks below.
// ─────────────────────────────────────────────────────────────
function FOCardV2({ statusColor = FO_COLORS.cardBlue, statusInk = FO_COLORS.cardBlueAccent }) {
  return (
    <FOScrim>
      <div style={{
        width: 328, borderRadius: 24, overflow: 'hidden',
        boxShadow: '0 30px 70px rgba(0,0,0,0.22), 0 0 0 1px rgba(14,46,30,0.05)',
        background: '#FFFFFF', color: FO_COLORS.ink,
      }}>
        {/* Colored header */}
        <div style={{
          background: statusColor, padding: '20px 22px 18px',
          display: 'flex', flexDirection: 'column', gap: 10,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <div style={{
              fontSize: 11, fontWeight: 800, letterSpacing: 0.8, textTransform: 'uppercase',
              color: statusInk, background: 'rgba(255,255,255,0.55)',
              padding: '4px 8px', borderRadius: 99,
            }}>Pending</div>
            <div style={{ flex: 1 }} />
            <div style={{
              width: 28, height: 28, borderRadius: 99,
              background: 'rgba(255,255,255,0.6)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <svg width="12" height="12" viewBox="0 0 12 12">
                <path d="M2 2l8 8M10 2l-8 8" stroke={statusInk} strokeWidth="1.8" strokeLinecap="round"/>
              </svg>
            </div>
          </div>
          <div style={{ fontSize: 28, fontWeight: 800, letterSpacing: -0.6, color: FO_COLORS.ink, lineHeight: 1.1 }}>Toilet</div>
          <div style={{ display: 'flex', gap: 16, fontSize: 13, color: FO_COLORS.ink, opacity: 0.8 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
              <svg width="13" height="13" viewBox="0 0 13 13" fill="none">
                <rect x="1.5" y="2.5" width="10" height="9" rx="1.5" stroke={FO_COLORS.ink} strokeWidth="1.3"/>
                <path d="M1.5 5h10M4 1v3M9 1v3" stroke={FO_COLORS.ink} strokeWidth="1.3" strokeLinecap="round"/>
              </svg>
              Sun 26 Apr · 23:59
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
              <svg width="13" height="13" viewBox="0 0 13 13" fill="none">
                <circle cx="6.5" cy="4.5" r="2.4" stroke={FO_COLORS.ink} strokeWidth="1.3"/>
                <path d="M2 11.5c.7-2 2.4-3 4.5-3s3.8 1 4.5 3" stroke={FO_COLORS.ink} strokeWidth="1.3" strokeLinecap="round"/>
              </svg>
              Unassigned
            </div>
          </div>
        </div>

        {/* Subtasks */}
        <div style={{ padding: '18px 22px 8px' }}>
          <div style={{
            fontSize: 12, fontWeight: 700, color: FO_COLORS.teal,
            textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 12,
          }}>Subtasks</div>
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            {FO_SUBTASKS.map((s, i) => (
              <div key={i} style={{
                display: 'flex', alignItems: 'flex-start', gap: 12, fontSize: 15,
                padding: '11px 0',
                borderBottom: i === FO_SUBTASKS.length - 1 ? 'none' : '1px solid rgba(14,46,30,0.06)',
                lineHeight: 1.4,
              }}>
                <div style={{
                  width: 20, height: 20, borderRadius: 99, flexShrink: 0,
                  background: '#EDF6E2', color: FO_COLORS.teal, marginTop: 1,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 11, fontWeight: 700,
                }}>{i + 1}</div>
                <div style={{ flex: 1 }}>{s}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Footer */}
        <div style={{ padding: '8px 18px 18px' }}>
          <div style={{
            height: 46, borderRadius: 14,
            background: FO_COLORS.teal, color: '#fff',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontWeight: 700, fontSize: 15,
          }}>Close</div>
        </div>
      </div>
    </FOScrim>
  );
}

// ─────────────────────────────────────────────────────────────
// V3 — Bottom sheet (most native on both platforms)
// Drag handle, generous spacing, list-style subtasks with leading dot.
// ─────────────────────────────────────────────────────────────
function FOCardV3() {
  return (
    <FOScrim align="bottom">
      <div style={{
        width: '100%', background: '#EDF6E2',
        borderTopLeftRadius: 28, borderTopRightRadius: 28,
        padding: '10px 22px 28px', color: FO_COLORS.ink,
        boxShadow: '0 -10px 40px rgba(0,0,0,0.18)',
        display: 'flex', flexDirection: 'column', gap: 14,
      }}>
        {/* Drag handle */}
        <div style={{ display: 'flex', justifyContent: 'center' }}>
          <div style={{ width: 40, height: 4, borderRadius: 99, background: 'rgba(14,46,30,0.25)' }} />
        </div>

        {/* Title + close */}
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10 }}>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 28, fontWeight: 800, letterSpacing: -0.5, lineHeight: 1.1 }}>Toilet</div>
            <div style={{ fontSize: 13, color: 'rgba(14,46,30,0.6)', marginTop: 4, fontWeight: 500 }}>
              Sun, 26 Apr · 23:59  ·  Unassigned
            </div>
          </div>
          <div style={{
            width: 32, height: 32, borderRadius: 99,
            background: 'rgba(14,46,30,0.06)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <svg width="12" height="12" viewBox="0 0 12 12">
              <path d="M2 2l8 8M10 2l-8 8" stroke={FO_COLORS.ink} strokeWidth="1.8" strokeLinecap="round"/>
            </svg>
          </div>
        </div>

        {/* Status chip row */}
        <div style={{ display: 'flex', gap: 8 }}>
          <FOChip label="Weekly" />
          <FOChip label="Pending" tone="blue" />
        </div>

        <div style={{ height: 1, background: 'rgba(14,46,30,0.10)' }} />

        {/* Subtasks */}
        <div>
          <div style={{
            fontSize: 12, fontWeight: 700, color: FO_COLORS.teal,
            textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 8,
          }}>Subtasks · {FO_SUBTASKS.length}</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            {FO_SUBTASKS.map((s, i) => (
              <div key={i} style={{
                display: 'flex', alignItems: 'center', gap: 14, fontSize: 15,
                padding: '12px 4px', lineHeight: 1.35,
              }}>
                <div style={{
                  width: 6, height: 6, borderRadius: 99,
                  background: FO_COLORS.teal, flexShrink: 0,
                }} />
                <div style={{ flex: 1 }}>{s}</div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </FOScrim>
  );
}

function FOChip({ label, tone = 'neutral' }) {
  const styles = tone === 'blue'
    ? { bg: 'rgba(30,79,182,0.12)', fg: FO_COLORS.cardBlueAccent }
    : { bg: 'rgba(14,86,72,0.10)', fg: FO_COLORS.teal };
  return (
    <div style={{
      padding: '5px 12px', borderRadius: 99,
      background: styles.bg, color: styles.fg,
      fontSize: 12, fontWeight: 700, letterSpacing: 0.3,
    }}>{label}</div>
  );
}

Object.assign(window, { FOCardV1, FOCardV2, FOCardV3, FOScrim });
