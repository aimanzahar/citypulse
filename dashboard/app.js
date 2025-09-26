
const { useState, useEffect, useRef, useMemo } = React;
dayjs.extend(window.dayjs_plugin_relativeTime);

const CATEGORY_LIST = ['pothole','streetlight','signage','trash','drainage','other'];
const SEVERITIES = ['high','medium','low'];
const STATUSES = ['submitted','in_progress','fixed'];

const SEVERITY_COLOR = { high:'#D32F2F', medium:'#F57C00', low:'#388E3C' };
const STATUS_COLOR = { submitted:'#1976D2', in_progress:'#7B1FA2', fixed:'#455A64' };

function fetchJSON(path){ return fetch(path).then(r=>r.json()); }

// Normalize API data to expected format
function normalizeReportData(report) {
  // If it's already in the expected format (from demo data), return as is
  if (report.location && report.location.lat !== undefined) {
    return report;
  }

  // Convert API format to expected format
  return {
    id: report.ticket_id,
    category: report.category || 'other',
    severity: report.severity || 'low',
    status: report.status || 'submitted',
    notes: report.description || '',
    location: {
      lat: report.latitude,
      lng: report.longitude
    },
    createdAt: report.created_at,
    updatedAt: report.updated_at,
    // Add missing fields with defaults
    userId: report.user_id,
    imagePath: report.image_path
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

  useEffect(()=>{
    // Try to fetch from backend API first, fallback to demo data
    fetch('http://127.0.0.1:8000/api/tickets')
      .then(r => r.ok ? r.json() : Promise.reject('API not available'))
      .then(data => {
        console.log('Loaded data from API:', data.length, 'reports');
        const normalizedData = data.map(normalizeReportData);
        setRawData(normalizedData);
        setLoading(false);
      })
      .catch(err => {
        console.log('API not available, using demo data:', err);
        return fetchJSON('./data/demo-reports.json');
      })
      .then(data => {
        if (data) {
          console.log('Loaded demo data:', data.length, 'reports');
          // Demo data is already in the correct format, but normalize just in case
          const normalizedData = data.map(normalizeReportData);
          setRawData(normalizedData);
        }
        setLoading(false);
      })
      .catch(err => {
        console.error('Error loading data:', err);
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

  const cycleStatus = async (reportId)=>{
    try {
      // Find the current report to get its status
      const currentReport = rawData.find(r => r.id === reportId);
      if (!currentReport) return;

      const idx = STATUSES.indexOf(currentReport.status);
      const nextStatus = STATUSES[(idx + 1) % STATUSES.length];

      // Try to update via API first
      const success = await fetch(`http://127.0.0.1:8000/api/tickets/${reportId}?new_status=${encodeURIComponent(nextStatus)}`, {
        method: 'PATCH'
      }).then(r => r.ok);

      if (success) {
        // If API update successful, refresh data from API
        const response = await fetch('http://127.0.0.1:8000/api/tickets');
        if (response.ok) {
          const data = await response.json();
          const normalizedData = data.map(normalizeReportData);
          setRawData(normalizedData);

          // Update selected item
          const updatedReport = normalizedData.find(r => r.id === reportId);
          setSelected(updatedReport || null);
        }
      } else {
        console.error('Failed to update status via API');
        // Fallback to local update
        setRawData(prev=>{
          const out = prev.map(r=>{
            if(r.id !== reportId) return r;
            return {...r, status: nextStatus, updatedAt: new Date().toISOString() };
          });
          if(selected && selected.id === reportId){
            const newSel = out.find(r=>r.id === reportId);
            setSelected(newSel || null);
          }
          return out;
        });
      }
    } catch (error) {
      console.error('Error updating status:', error);
      // Fallback to local update
      setRawData(prev=>{
        const out = prev.map(r=>{
          if(r.id !== reportId) return r;
          const idx = STATUSES.indexOf(r.status);
          const ni = (idx + 1) % STATUSES.length;
          return {...r, status: STATUSES[ni], updatedAt: new Date().toISOString() };
        });
        if(selected && selected.id === reportId){
          const newSel = out.find(r=>r.id === reportId);
          setSelected(newSel || null);
        }
        return out;
      });
    }
  };

  const openInMaps = (r)=>{
    const lat = r.location.lat;
    const lng = r.location.lng;
    window.open(`https://www.google.com/maps/search/?api=1&query=${lat},${lng}`, '_blank');
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
                  <div className="thumb">{t(`category.${r.category}`) || r.category}</div>
                  <div className="item-main">
                    <div className="item-title">{t(`category.${r.category}`) || r.category}</div>
                    <div className="item-meta">
                      <span className={`chip severity-${r.severity}`}>{t(`severity.${r.severity}`) || r.severity}</span>
                      <span className={`chip status-${r.status}`}>{t(`status.${r.status}`) || r.status}</span>
                      <span className="time-ago">{dayjs(r.createdAt).fromNow()}</span>
                    </div>
                  </div>
                  <div className="item-actions">
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
                <div className="drawer-thumb large">{/* placeholder */}{t(`category.${selected.category}`) || selected.category}</div>
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
                <p><strong>{t('label.location') || 'Location'}:</strong> {selected.location.lat.toFixed(5)}, {selected.location.lng.toFixed(5)}</p>
                <p><strong>{t('label.createdAt') || 'Created'}:</strong> {dayjs(selected.createdAt).format('YYYY-MM-DD HH:mm')}</p>
              </div>

              <div className="drawer-actions">
                <button className="btn" onClick={()=>{ cycleStatus(selected.id); }}>
                  {t('drawer.changeStatus') || 'Change Status'}
                </button>
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