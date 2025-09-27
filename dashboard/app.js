
const { useState, useEffect, useRef, useMemo } = React;
dayjs.extend(window.dayjs_plugin_relativeTime);

console.log('Dashboard app.js loaded, BACKEND_BASE:', BACKEND_BASE);

const CATEGORY_LIST = ['pothole','streetlight','signage','trash','garbage','drainage','other'];
const SEVERITIES = ['high','medium','low'];
const STATUSES = ['submitted','in_progress','fixed'];
const BACKEND_BASE = "http://127.0.0.1:8000";

const SEVERITY_COLOR = { high:'#D32F2F', medium:'#F57C00', low:'#388E3C' };
const STATUS_COLOR = { submitted:'#1976D2', in_progress:'#7B1FA2', fixed:'#455A64' };

function fetchJSON(path){ return fetch(path).then(r=>r.json()); }

// Fetch tickets from backend
async function fetchTickets(){
  console.log('Fetching tickets from:', `${BACKEND_BASE}/api/tickets`);
  try {
    const res = await fetch(`${BACKEND_BASE}/api/tickets`);
    console.log('Response status:', res.status);
    if(!res.ok) throw new Error(`Failed to fetch tickets: ${res.status}`);
    const data = await res.json();
    console.log('Fetched data:', data);
    return data;
  } catch (error) {
    console.error('Error fetching tickets:', error);
    throw error;
  }
}

// Map backend category names to frontend filter categories
function mapCategoryToFrontend(backendCategory) {
  const categoryMapping = {
    'broken_streetlight': 'streetlight',  // Backend AI model category
    'garbage': 'trash',                   // Backend AI model category
    // Direct matches (backend and frontend categories are the same)
    'pothole': 'pothole',
    'drainage': 'drainage',
    'signage': 'signage',
    'streetlight': 'streetlight',
    'other': 'other'
  };
  return categoryMapping[backendCategory] || backendCategory || 'other';
}

// Normalize API data to expected format
function normalizeReportData(report) {
  // Backend is already returning data in correct format
  // Just ensure all required fields are present and map categories
  return {
    id: report.id,
    category: mapCategoryToFrontend(report.category),
    severity: report.severity || 'low',
    status: report.status || 'submitted',
    notes: report.notes || '',
    location: {
      lat: report.latitude,
      lng: report.longitude
    },
    createdAt: report.createdAt,
    updatedAt: report.updatedAt,
    userId: report.user_id,
    userName: report.userName || null,
    address: report.address || null,
    image_url: report.image_url || null
  };
}

function useI18n(initialLang='en'){
  const [lang,setLang] = useState(localStorage.getItem('lang') || initialLang);
  const [map,setMap] = useState({en:null,ms:null});
  useEffect(()=>{
    Promise.all([fetchJSON('./i18n/en.json'), fetchJSON('./i18n/ms.json')])
      .then(([en,ms])=> setMap({en,ms}))
      .catch(err=> console.error('i18n load',err));
  },[]);
  const t = (key)=> (map[lang] && map[lang][key]) || (map['en'] && map['en'][key]) || key;
  useEffect(()=> localStorage.setItem('lang',lang),[lang]);
  return {lang,setLang,t,i18nMap:map};
}

function App(){
  const {lang,setLang,t,i18nMap} = useI18n();

  const [rawData,setRawData] = useState([]);
  const [loading,setLoading] = useState(true);

  const defaultFrom = dayjs().subtract(30,'day').format('YYYY-MM-DD');
  const defaultTo = dayjs().format('YYYY-MM-DD');

  // form state
  const [formCategories,setFormCategories] = useState(new Set(CATEGORY_LIST));
  const [formSeverities,setFormSeverities] = useState(new Set(SEVERITIES));
  const [formStatuses,setFormStatuses] = useState(new Set(STATUSES));
  const [formFrom,setFormFrom] = useState(defaultFrom);
  const [formTo,setFormTo] = useState(defaultTo);

  // applied filters
  const [appliedFilters,setAppliedFilters] = useState({
    categories:new Set(CATEGORY_LIST),
    severities:new Set(SEVERITIES),
    statuses:new Set(STATUSES),
    from:defaultFrom,
    to:defaultTo
  });

  const [filtered,setFiltered] = useState([]);

  const [selected,setSelected] = useState(null);

  const mapRef = useRef(null);
  const markersRef = useRef(null);
  const heatRef = useRef(null);
  const mapContainerRef = useRef(null);

  const [heatEnabled,setHeatEnabled] = useState(false);

  // simple toast container for non-blocking errors / retry actions
  const toastContainerRef = useRef(null);
  useEffect(()=> {
    const c = document.createElement('div');
    c.style.position = 'fixed';
    c.style.right = '12px';
    c.style.bottom = '12px';
    c.style.zIndex = 9999;
    toastContainerRef.current = c;
    document.body.appendChild(c);
    return ()=> { if(c.parentNode) c.parentNode.removeChild(c); };
  }, []);

  const showToast = (msg, actionLabel, action) => {
    const c = toastContainerRef.current;
    if(!c) { console.warn(msg); return; }
    const el = document.createElement('div');
    el.style.background = '#111';
    el.style.color = '#fff';
    el.style.padding = '8px 12px';
    el.style.marginTop = '8px';
    el.style.borderRadius = '6px';
    el.style.boxShadow = '0 2px 6px rgba(0,0,0,0.3)';
    el.style.display = 'flex';
    el.style.alignItems = 'center';
    el.textContent = msg;
    if(actionLabel && action){
      const btn = document.createElement('button');
      btn.textContent = actionLabel;
      btn.style.marginLeft = '12px';
      btn.style.background = 'transparent';
      btn.style.color = '#4FC3F7';
      btn.style.border = 'none';
      btn.style.cursor = 'pointer';
      btn.onclick = ()=> { action(); if(el.parentNode) el.parentNode.removeChild(el); };
      el.appendChild(btn);
    }
    c.appendChild(el);
    setTimeout(()=> { if(el.parentNode) el.parentNode.removeChild(el); }, 8000);
  };

  const PLACEHOLDER_SRC = 'data:image/svg+xml;utf8,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="120" height="90"><rect width="100%" height="100%" fill="#e5e7eb"/><text x="50%" y="50%" dy=".3em" font-size="12" text-anchor="middle" fill="#6b7280">No image</text></svg>');

  useEffect(()=>{
    console.log('Dashboard useEffect triggered - about to fetch tickets');

    // First test if we can reach the backend at all
    fetch(`${BACKEND_BASE}/test`)
      .then(response => {
        console.log('Test endpoint response:', response.status);
        return response.json();
      })
      .then(testData => {
        console.log('Test data:', testData);
      })
      .catch(testErr => {
        console.error('Test request failed:', testErr);
      });

    setLoading(true);
    fetchTickets()
      .then(data => {
        console.log('Loaded data from backend:', (Array.isArray(data) ? data.length : 0), 'reports');
        console.log('Raw data received:', data);
        const normalizedData = (data || []).map(normalizeReportData);
        console.log('Normalized data:', normalizedData);
        console.log('Sample normalized item:', JSON.stringify(normalizedData[0], null, 2));
        setRawData(normalizedData);
        setLoading(false);
      })
      .catch(err => {
        console.error('Failed to load tickets from backend:', err);
        console.error('Error details:', err.message, err.stack);
        showToast('Failed to load tickets from backend.');
        setRawData([]);
        setLoading(false);
      });
  },[]);

  useEffect(()=>{
    // init map once
    const map = L.map('map', { center:[3.1390,101.6869], zoom:12, preferCanvas:true });
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom:19,
      attribution:'© OpenStreetMap'
    }).addTo(map);
    mapRef.current = map;
    markersRef.current = L.markerClusterGroup();
    map.addLayer(markersRef.current);
    return ()=> { map.remove(); mapRef.current=null; markersRef.current=null; };
  },[]);

  // compute filtered when rawData or appliedFilters change
  useEffect(()=>{
    if(!rawData) return;
    const from = dayjs(appliedFilters.from).startOf('day');
    const to = dayjs(appliedFilters.to).endOf('day');
    const out = rawData.filter(r=>{
      if(!r || !r.createdAt) return false;
      const created = dayjs(r.createdAt);
      if(created.isBefore(from) || created.isAfter(to)) return false;
      if(!appliedFilters.categories.has(r.category)) return false;
      if(!appliedFilters.severities.has(r.severity)) return false;
      if(!appliedFilters.statuses.has(r.status)) return false;
      return true;
    });
    console.log('Filtered data:', out.length, 'tickets');
    console.log('Applied filters:', {
      categories: Array.from(appliedFilters.categories),
      severities: Array.from(appliedFilters.severities),
      statuses: Array.from(appliedFilters.statuses)
    });
    setFiltered(out);
  },[rawData, appliedFilters]);

  // update markers and heatmap when filtered changes
  useEffect(()=>{
    const map = mapRef.current;
    const markersLayer = markersRef.current;
    if(!map || !markersLayer) return;
    markersLayer.clearLayers();
    if(filtered.length === 0){
      // remove heat if present
      if(heatRef.current){ heatRef.current.remove(); heatRef.current = null; }
      map.setView([3.1390,101.6869],12);
      const container = document.querySelector('.map-panel');
      if(container) container.classList.add('no-reports');
      return;
    } else {
      const container = document.querySelector('.map-panel');
      if(container) container.classList.remove('no-reports');
    }

    const bounds = [];
    filtered.forEach(r=>{
      if(!r.location) return;
      const lat = r.location.lat;
      const lng = r.location.lng;
      bounds.push([lat,lng]);
      const color = SEVERITY_COLOR[r.severity] || '#333';
      const icon = L.divIcon({
        className: 'custom-marker',
        html: `<div style="width:18px;height:18px;border-radius:50%;background:${color};border:2px solid #fff;"></div>`,
        iconSize:[22,22],
        iconAnchor:[11,11]
      });
      const marker = L.marker([lat,lng], { icon });
      marker.on('click', ()=> {
        setSelected(r);
      });
      marker.bindPopup(`<strong>${r.category}</strong><br/>${r.notes || ''}`);
      markersLayer.addLayer(marker);
    });

    try{
      const boundsObj = L.latLngBounds(bounds);
      if(bounds.length === 1){
        map.setView(bounds[0],14);
      } else {
        map.fitBounds(boundsObj.pad(0.1));
      }
    }catch(e){
      map.setView([3.1390,101.6869],12);
    }

    // heatmap
    if(heatEnabled){
      const heatPoints = filtered.map(r=> [r.location.lat, r.location.lng, 0.6]);
      if(heatRef.current){
        heatRef.current.setLatLngs(heatPoints);
      } else {
        heatRef.current = L.heatLayer(heatPoints, {radius:25,blur:15,maxZoom:17}).addTo(map);
      }
    } else {
      if(heatRef.current){ heatRef.current.remove(); heatRef.current = null; }
    }
  },[filtered, heatEnabled]);

  const applyFilters = ()=> {
    setAppliedFilters({
      categories: new Set(formCategories),
      severities: new Set(formSeverities),
      statuses: new Set(formStatuses),
      from: formFrom,
      to: formTo
    });
  };

  const resetFilters = ()=> {
    const cats = new Set(CATEGORY_LIST);
    const sevs = new Set(SEVERITIES);
    const stats = new Set(STATUSES);
    setFormCategories(cats);
    setFormSeverities(sevs);
    setFormStatuses(stats);
    setFormFrom(defaultFrom);
    setFormTo(defaultTo);
    setAppliedFilters({
      categories: cats,
      severities: sevs,
      statuses: stats,
      from:defaultFrom,
      to:defaultTo
    });
  };

  // helper toggle functions
  const toggleSet = (setState, currentSet, val) => {
    const s = new Set(currentSet);
    if(s.has(val)) s.delete(val); else s.add(val);
    setState(s);
  };

  // sorted queue
  const sortedQueue = useMemo(()=>{
    const order = { high:0, medium:1, low:2 };
    return [...filtered].sort((a,b)=>{
      const sa = order[a.severity] ?? 3;
      const sb = order[b.severity] ?? 3;
      if(sa !== sb) return sa - sb;
      return dayjs(b.createdAt).valueOf() - dayjs(a.createdAt).valueOf();
    });
  },[filtered]);

  const availableStatuses = useMemo(()=>{
    const s = new Set(STATUSES);
    rawData.forEach(r=>{ if(r && r.status) s.add(r.status); });
    return Array.from(s);
  }, [rawData]);

// Map dashboard status format to backend enum format
const mapStatusToBackend = (dashboardStatus) => {
  const statusMapping = {
    'submitted': 'New',
    'in_progress': 'In Progress',
    'fixed': 'Fixed'
  };
  return statusMapping[dashboardStatus] || dashboardStatus;
};

const updateTicketStatus = async (reportId, newStatus) => {
  try {
    const backendStatus = mapStatusToBackend(newStatus);
    console.log('Updating status:', newStatus, '->', backendStatus);
    const res = await fetch(`${BACKEND_BASE}/api/tickets/${reportId}/status`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: backendStatus })
    });
    if (res.ok) {
      // Prefer using returned updated ticket if provided
      let updated = null;
      try { updated = await res.json(); } catch(e){ updated = null; }
      if (updated) {
        const normalized = normalizeReportData(updated);
        setRawData(prev => prev.map(r => r.id === reportId ? normalized : r));
        if (selected && selected.id === reportId) setSelected(normalized);
      } else {
        // No body returned - update local state (keep dashboard format)
        setRawData(prev=> prev.map(r=> r.id === reportId ? {...r, status: newStatus, updatedAt: new Date().toISOString()} : r));
        if(selected && selected.id === reportId) setSelected(prev => ({...prev, status: newStatus, updatedAt: new Date().toISOString()}));
      }
      showToast('Status updated');
      return true;
    } else {
      const text = await res.text().catch(()=> '');
      console.warn('Status update failed', text);
      showToast('Failed to update status', 'Retry', ()=> updateTicketStatus(reportId, newStatus));
      return false;
    }
  } catch (err) {
    console.error('Error updating status:', err);
    showToast('Failed to update status', 'Retry', ()=> updateTicketStatus(reportId, newStatus));
    return false;
  }
};

const cycleStatus = async (reportId) => {
  const currentReport = rawData.find(r => r.id === reportId);
  if (!currentReport) return;
  const idx = availableStatuses.indexOf(currentReport.status);
  const nextStatus = availableStatuses[(idx + 1) % availableStatuses.length] || STATUSES[(STATUSES.indexOf(currentReport.status) + 1) % STATUSES.length];
  await updateTicketStatus(reportId, nextStatus);
};

  const openInMaps = (r)=>{
    const lat = r.location.lat;
    const lng = r.location.lng;
    window.open(`https://www.google.com/maps/search/?api=1&query=${lat},${lng}`, '_blank');
  };

  const navigateToLocation = (r) => {
    const map = mapRef.current;
    if (!map || !r.location) return;

    const { lat, lng } = r.location;
    const currentZoom = map.getZoom();
    const targetZoom = 20; // Maximum zoom level for focusing on a specific location

    // First zoom out a bit for animation effect, then zoom to target
    map.flyTo([lat, lng], targetZoom, {
      animate: true,
      duration: 1.5,
      easeLinearity: 0.25
    });

    // Also set the selected item to show details
    setSelected(r);
  };

  return (
    <div className="app-root">
      <header className="header">
        <div className="brand">{t('dashboard.brand') || 'FixMate'}</div>
        <div className="lang-toggle">
          <label style={{fontSize:12, color:'#374151'}}>{t('label.language') || 'Language'}</label>
          <select value={lang} onChange={e=>setLang(e.target.value)}>
            <option value="en">EN</option>
            <option value="ms">BM</option>
          </select>
        </div>
      </header>

      <div className="container">
        <div className="main">
          <aside className="panel filters">
            <h3>{t('dashboard.filters') || 'Filters'}</h3>

            <div className="filter-group">
              <div className="row space-between"><strong>{t('filter.category') || 'Category'}</strong></div>
              <div className="checkbox-row" aria-label="categories">
                {CATEGORY_LIST.map(cat=>(
                  <label key={cat} style={{display:'flex',alignItems:'center',gap:8}}>
                    <input type="checkbox"
                      checked={formCategories.has(cat)}
                      onChange={()=> toggleSet(setFormCategories, formCategories, cat)}
                    />
                    <span style={{textTransform:'capitalize'}}>{t(`category.${cat}`) || cat}</span>
                  </label>
                ))}
              </div>
            </div>

            <div className="filter-group">
              <div className="row space-between"><strong>{t('filter.severity') || 'Severity'}</strong></div>
              <div className="multi-select">
                {SEVERITIES.map(s=>(
                  <button key={s} className={`chip severity-${s}`} onClick={()=> toggleSet(setFormSeverities, formSeverities, s)} aria-pressed={formSeverities.has(s)}>
                    {t(`severity.${s}`) || s}
                  </button>
                ))}
              </div>
            </div>

            <div className="filter-group">
              <div className="row space-between"><strong>{t('filter.status') || 'Status'}</strong></div>
              <div className="multi-select">
                {STATUSES.map(s=>(
                  <button key={s} className={`chip status-${s}`} onClick={()=> toggleSet(setFormStatuses, formStatuses, s)} aria-pressed={formStatuses.has(s)}>
                    {t(`status.${s}`) || s}
                  </button>
                ))}
              </div>
            </div>

            <div className="filter-group">
              <div className="row space-between"><strong>{t('filter.dateRange') || 'Date Range'}</strong></div>
              <div style={{display:'flex',gap:8,marginTop:8}}>
                <div style={{display:'flex',flexDirection:'column'}}>
                  <label style={{fontSize:12}}>{t('filter.dateFrom') || 'From'}</label>
                  <input type="date" value={formFrom} onChange={e=>setFormFrom(e.target.value)} />
                </div>
                <div style={{display:'flex',flexDirection:'column'}}>
                  <label style={{fontSize:12}}>{t('filter.dateTo') || 'To'}</label>
                  <input type="date" value={formTo} onChange={e=>setFormTo(e.target.value)} />
                </div>
              </div>
            </div>

            <div style={{display:'flex',gap:8,marginTop:12}}>
              <button className="btn" onClick={applyFilters}>{t('btn.apply') || 'Apply'}</button>
              <button className="btn secondary" onClick={resetFilters}>{t('btn.reset') || 'Reset'}</button>
            </div>

          </aside>

          <section className="panel map-panel" ref={mapContainerRef}>
            <div id="map"></div>
            <div className="map-empty">{t('map.noReports') || 'No reports match filters'}</div>
          </section>

          <aside className="panel">
            <div style={{display:'flex',justifyContent:'space-between',alignItems:'center'}}>
              <h3>{t('queue.title') || 'Tickets'}</h3>
            </div>

            <div className="queue-list" role="list">
              {sortedQueue.map(r=>(
                <div key={r.id} className="queue-item" role="listitem">
                  <div className="thumb">
                    {(r.image_url || r.imagePath) ? (
                      <img src={r.image_url || r.imagePath} alt={r.category} style={{width:64,height:48,objectFit:'cover',borderRadius:6}} onError={(e)=>{ e.currentTarget.style.display='none'; }} />
                    ) : (t(`category.${r.category}`) || r.category)}
                  </div>
                  <div className="item-main">
                    <div
                      className="item-title clickable"
                      onClick={() => navigateToLocation(r)}
                      title="Click to view on map"
                    >
                      {t(`category.${r.category}`) || r.category}
                    </div>
                    <div className="item-meta">
                      <span className={`chip severity-${r.severity}`}>{t(`severity.${r.severity}`) || r.severity}</span>
                      <span className={`chip status-${r.status}`}>{t(`status.${r.status}`) || r.status}</span>
                      <span className="time-ago">{dayjs(r.createdAt).fromNow()}</span>
                    </div>
                  </div>
                  <div className="item-actions" style={{display:'flex',flexDirection:'column',gap:8,alignItems:'flex-end'}}>
                    <select value={r.status} onChange={(e)=> updateTicketStatus(r.id, e.target.value)}>
                      {availableStatuses.map(s => <option key={s} value={s}>{t(`status.${s}`) || s}</option>)}
                    </select>
                    <button className="btn ghost" onClick={()=> { setSelected(r); }}>{t('btn.view') || 'View'}</button>
                  </div>
                </div>
              ))}
            </div>
          </aside>
        </div>

        <footer className="footer">
          <div className="stats">
            <div><strong>{t('stats.total') || 'Total'}: </strong> {filtered.length}</div>
            <div className="chip severity-high">{filtered.filter(x=>x.severity==='high').length} {t('severity.high') || 'High'}</div>
            <div className="chip severity-medium">{filtered.filter(x=>x.severity==='medium').length} {t('severity.medium') || 'Medium'}</div>
            <div className="chip severity-low">{filtered.filter(x=>x.severity==='low').length} {t('severity.low') || 'Low'}</div>
          </div>
          <div style={{display:'flex',gap:12,alignItems:'center'}}>
            <label style={{display:'flex',alignItems:'center',gap:8}}>
              <input type="checkbox" checked={heatEnabled} onChange={e=>setHeatEnabled(e.target.checked)} /> {t('stats.heatmap') || 'Heatmap'}
            </label>
          </div>
        </footer>

        {/* Detail Drawer */}
        <div className={`drawer ${selected ? 'open' : ''}`} role="dialog" aria-hidden={!selected}>
          {selected ? (
            <div className="drawer-content" aria-live="polite">
              <button className="drawer-close" onClick={()=>setSelected(null)} aria-label="Close">×</button>
              <div className="drawer-header">
                <div className="drawer-thumb large">
                  {(selected.image_url || selected.imagePath) ? (
                    <img src={selected.image_url || selected.imagePath} alt={selected.category} style={{width:88,height:64,objectFit:'cover',borderRadius:6}} onError={(e)=>{ e.currentTarget.style.display='none'; }} />
                  ) : (t(`category.${selected.category}`) || selected.category)}
                </div>
                <div style={{marginLeft:12}}>
                  <h3 style={{margin:0}}>{t(`category.${selected.category}`) || selected.category}</h3>
                  <div style={{display:'flex',gap:8,alignItems:'center',marginTop:6}}>
                    <span className={`chip severity-${selected.severity}`}>{t(`severity.${selected.severity}`) || selected.severity}</span>
                    <span className={`chip status-${selected.status}`}>{t(`status.${selected.status}`) || selected.status}</span>
                    <span style={{color:'#6b7280',fontSize:12}}>{dayjs(selected.createdAt).fromNow()}</span>
                  </div>
                </div>
              </div>

              <div className="drawer-body">
                <p style={{marginTop:8}}><strong>{t('drawer.details') || 'Details'}</strong></p>
                {selected.notes ? <p>{selected.notes}</p> : <p style={{opacity:0.7}}>{t('drawer.noNotes') || 'No additional notes'}</p>}
                <p><strong>{t('label.submittedBy') || 'Submitted by'}:</strong> {selected.userName || (t('label.guest') || 'Guest')}</p>
                <p><strong>{t('label.place') || 'Place'}:</strong> {selected.address ? selected.address : `${selected.location.lat.toFixed(5)}, ${selected.location.lng.toFixed(5)}`}</p>
                <p><strong>{t('label.location') || 'Location'}:</strong> {selected.location.lat.toFixed(5)}, {selected.location.lng.toFixed(5)}</p>
                <p><strong>{t('label.createdAt') || 'Created'}:</strong> {dayjs(selected.createdAt).format('YYYY-MM-DD HH:mm')}</p>
              </div>

              <div className="drawer-actions">
                <select value={selected.status} onChange={(e)=> updateTicketStatus(selected.id, e.target.value)}>
                  {availableStatuses.map(s => <option key={s} value={s}>{t(`status.${s}`) || s}</option>)}
                </select>
                <button className="btn secondary" onClick={()=>openInMaps(selected)}>
                  {t('drawer.openMap') || 'Open Map'}
                </button>
              </div>
            </div>
          ) : null}
        </div>

      </div>

    </div>
  );
}

// mount
const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App />);