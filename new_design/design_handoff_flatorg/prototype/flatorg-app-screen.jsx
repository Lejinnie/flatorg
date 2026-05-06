// The Flatorg "Tasks" home screen — dimmed background that sits behind each task-detail card.
// Pulled directly from the user's screenshots so the redesigned card has its real context.

const FO_COLORS = {
  bg: '#DCEEC8',           // mint background
  bgSoft: '#E8F2D9',
  ink: '#0E2E1E',          // forest near-black
  inkSoft: '#264035',
  teal: '#0E5648',         // primary deep teal-green
  tealSoft: '#1F6B5A',
  green: '#36B373',         // success / Resolved
  cardBlue: '#9DBEE8',      // status: pending blue
  cardBlueAccent: '#1E4FB6',
  cardYellow: '#F4D58A',
  cardRed: '#E8A39D',
  cardGreen: '#A6D9A6',
  divider: 'rgba(14,46,30,0.10)',
  white: '#FFFFFF',
};

const FO_FONT = `'Sora', 'Inter', -apple-system, system-ui, sans-serif`;

// One task card on the home screen
function FOHomeTaskCard({ name, status = 'pending', due = 'Sun 26 Apr, 23:59', dimmed = true }) {
  const bgByStatus = {
    pending: FO_COLORS.cardBlue,
    overdue: FO_COLORS.cardRed,
    done:    FO_COLORS.cardGreen,
    soon:    FO_COLORS.cardYellow,
  };
  const accentByStatus = {
    pending: FO_COLORS.cardBlueAccent,
    overdue: '#B53A30',
    done:    '#2F7A3D',
    soon:    '#B58820',
  };
  return (
    <div style={{
      background: bgByStatus[status],
      borderRadius: 22, padding: '14px 18px 16px',
      display: 'flex', flexDirection: 'column', gap: 4,
      border: `1px solid rgba(14,46,30,0.06)`,
      opacity: dimmed ? 0.95 : 1,
    }}>
      <div style={{
        height: 5, background: accentByStatus[status],
        borderRadius: 99, marginBottom: 8, opacity: 0.85,
      }} />
      <div style={{ fontSize: 22, fontWeight: 700, color: FO_COLORS.ink, letterSpacing: -0.3 }}>{name}</div>
      <div style={{ fontSize: 13, color: FO_COLORS.inkSoft, opacity: 0.85 }}>Due: {due}</div>
      <div style={{ fontSize: 13, color: FO_COLORS.inkSoft, opacity: 0.85 }}>Assigned to: Unassigned</div>
      <div style={{
        marginTop: 10, height: 38, borderRadius: 12,
        border: '1px solid rgba(14,46,30,0.18)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        gap: 8, color: FO_COLORS.ink, fontWeight: 600, fontSize: 14,
      }}>
        <svg width="16" height="14" viewBox="0 0 16 14" fill="none">
          <path d="M2 4h11l-2-2M14 10H3l2 2" stroke={FO_COLORS.ink} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
        Swap
      </div>
    </div>
  );
}

// The full "Welcome to HWB 33!" tasks screen
function FOHomeScreen({ dimmed = true, platform = 'ios' }) {
  const headerPaddingTop = platform === 'ios' ? 8 : 4;
  return (
    <div style={{
      width: '100%', height: '100%',
      background: FO_COLORS.bg, fontFamily: FO_FONT,
      display: 'flex', flexDirection: 'column',
      filter: dimmed ? 'saturate(0.7) brightness(0.92)' : 'none',
    }}>
      {/* Top header */}
      <div style={{
        padding: `${headerPaddingTop}px 20px 6px`,
        display: 'flex', alignItems: 'center', gap: 12,
      }}>
        <div style={{
          flex: 1, fontSize: 26, fontWeight: 800, color: FO_COLORS.ink, letterSpacing: -0.6,
        }}>Welcome to HWB 33!</div>
        <FOIconBtn>
          <svg width="22" height="22" viewBox="0 0 22 22" fill="none">
            <path d="M11 3v2M5 9a6 6 0 0112 0v4l1.5 2.5h-15L5 13V9z" stroke={FO_COLORS.ink} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"/>
            <path d="M9 18a2 2 0 004 0" stroke={FO_COLORS.ink} strokeWidth="1.7" strokeLinecap="round"/>
          </svg>
        </FOIconBtn>
        <FOIconBtn>
          <svg width="22" height="22" viewBox="0 0 22 22" fill="none">
            <circle cx="11" cy="11" r="3" stroke={FO_COLORS.ink} strokeWidth="1.7"/>
            <path d="M11 1.5v3M11 17.5v3M20.5 11h-3M4.5 11h-3M17.7 4.3l-2.1 2.1M6.4 15.6l-2.1 2.1M17.7 17.7l-2.1-2.1M6.4 6.4L4.3 4.3" stroke={FO_COLORS.ink} strokeWidth="1.7" strokeLinecap="round"/>
          </svg>
        </FOIconBtn>
      </div>

      {/* Cards */}
      <div style={{
        flex: 1, padding: '8px 16px 0',
        display: 'flex', flexDirection: 'column', gap: 14,
        overflow: 'hidden',
      }}>
        <FOHomeTaskCard name="Toilet" status="pending" />
        <FOHomeTaskCard name="Kitchen" status="pending" />
        <FOHomeTaskCard name="Recycling" status="pending" />
        <FOHomeTaskCard name="Shower" status="pending" />
      </div>

      {/* Bottom tab bar */}
      <FOTabBar />
    </div>
  );
}

function FOIconBtn({ children }) {
  return (
    <div style={{
      width: 40, height: 40, borderRadius: 12,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
    }}>{children}</div>
  );
}

function FOTabBar({ active = 'tasks' }) {
  const tab = (key, label, icon) => {
    const isOn = active === key;
    const c = isOn ? FO_COLORS.teal : 'rgba(14,46,30,0.55)';
    return (
      <div style={{
        flex: 1, display: 'flex', flexDirection: 'column',
        alignItems: 'center', justifyContent: 'center', gap: 4,
        paddingTop: 8, paddingBottom: 6,
      }}>
        {icon(c, isOn)}
        <div style={{ fontSize: 12, color: c, fontWeight: isOn ? 700 : 500 }}>{label}</div>
      </div>
    );
  };
  return (
    <div style={{
      display: 'flex', borderTop: `1px solid ${FO_COLORS.divider}`,
      background: FO_COLORS.bg, paddingBottom: 4,
    }}>
      {tab('tasks', 'Tasks', (c, on) => (
        <svg width="22" height="22" viewBox="0 0 22 22" fill={on ? c : 'none'}>
          <rect x="5" y="3" width="12" height="16" rx="2" stroke={c} strokeWidth="1.7" fill={on ? c : 'none'} fillOpacity={on ? 0.15 : 0}/>
          <rect x="8" y="2" width="6" height="3" rx="1" stroke={c} strokeWidth="1.7" fill={on ? c : 'none'}/>
          <path d="M8 10h6M8 14h4" stroke={on ? '#fff' : c} strokeWidth="1.7" strokeLinecap="round"/>
        </svg>
      ))}
      {tab('shopping', 'Shopping', (c) => (
        <svg width="22" height="22" viewBox="0 0 22 22" fill="none">
          <rect x="3.5" y="4.5" width="15" height="14" rx="2" stroke={c} strokeWidth="1.7"/>
          <path d="M7 9h8M7 12h8M7 15h5" stroke={c} strokeWidth="1.7" strokeLinecap="round"/>
        </svg>
      ))}
      {tab('issues', 'Issues', (c) => (
        <svg width="22" height="22" viewBox="0 0 22 22" fill="none">
          <path d="M11 3l9 16H2L11 3z" stroke={c} strokeWidth="1.7" strokeLinejoin="round"/>
          <path d="M11 9v4M11 16v.5" stroke={c} strokeWidth="1.7" strokeLinecap="round"/>
        </svg>
      ))}
    </div>
  );
}

Object.assign(window, { FOHomeScreen, FOHomeTaskCard, FOTabBar, FOIconBtn, FO_COLORS, FO_FONT });
