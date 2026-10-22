// MockDCOTA web console: plain JS, no build step. data-testid values mirror the iOS AID identifiers.
const $ = (id) => document.getElementById(id);
const fmt = (n) => n.toLocaleString('en-GB');
const bulkSelectEnabled = new URLSearchParams(location.search).get('bulkSelect') !== '0';

async function api(path, opts = {}) {
  let res;
  try {
    res = await fetch('/api/v1' + path, {
      method: opts.method || 'GET',
      headers: opts.body ? { 'Content-Type': 'application/json' } : undefined,
      body: opts.body ? JSON.stringify(opts.body) : undefined,
    });
  } catch (e) { throw new Error('Network error: ' + e.message); }
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.message || `HTTP ${res.status}`);
  return data;
}

function el(tag, props = {}, ...kids) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(props)) {
    if (k === 'testid') e.dataset.testid = v;
    else if (k.startsWith('on')) e.addEventListener(k.slice(2), v);
    else if (k === 'class') e.className = v;
    else e.setAttribute(k, v);
  }
  e.append(...kids.flat().filter((x) => x != null));
  return e;
}

// ---------- shell ----------
let tab = 'dashboard', retryFn = () => {}, pollTimer = null;
function showError(msg) { $('error').hidden = !msg; $('error-text').textContent = msg || ''; }
function setLoading(on) { $('loading').hidden = !on; }
function setEmpty(text) { $('empty').hidden = !text; $('empty').textContent = text || ''; }

function show(name) {
  tab = name; clearInterval(pollTimer); pollTimer = null;
  showError(null); setEmpty(null);
  for (const s of ['dashboard', 'devices', 'content', 'deployments']) $(s).hidden = s !== name;
  document.querySelectorAll('nav button').forEach((b) => {
    if (b.dataset.tab === name) b.setAttribute('aria-current', 'page'); else b.removeAttribute('aria-current');
  });
  history.replaceState(null, '', location.pathname + location.search + '#' + name);
  ({ dashboard: loadDashboard, devices: reloadDevices, content: loadContent, deployments: startDeployments })[name]();
}
document.querySelectorAll('nav button').forEach((b) => b.addEventListener('click', () => show(b.dataset.tab)));
$('retry').addEventListener('click', () => retryFn());

// ---------- dashboard ----------
async function loadDashboard() {
  retryFn = loadDashboard; setLoading(true); showError(null);
  try {
    const s = await api('/fleet/summary');
    const tiles = [['Total devices', s.totalDevices, 'total'], ['Online', s.online, 'online'], ['Offline', s.offline, 'offline'],
      ['Updating', s.updating, 'updating'], ['Failed', s.failed, 'failed'], ['Active deployments', s.activeDeployments, 'activeDeployments']];
    $('tiles').replaceChildren(...tiles.map(([label, v, id]) =>
      el('div', { class: 'tile' }, el('div', { class: 'label' }, label), el('div', { class: 'value', testid: 'dashboard.' + id }, fmt(v)))));
    $('online-pct').textContent = `${(s.totalDevices ? s.online / s.totalDevices * 100 : 0).toFixed(1)}% of the fleet is online`;
  } catch (e) { $('tiles').replaceChildren(); $('online-pct').textContent = ''; showError(e.message); }
  setLoading(false);
}

// ---------- devices ----------
const dv = { page: 1, items: [], total: 0, hasMore: false, gen: 0 };
async function fetchDevices(page) {
  const q = new URLSearchParams({ page, pageSize: 25 });
  if ($('search').value.trim()) q.set('search', $('search').value.trim());
  if ($('status').value) q.set('status', $('status').value);
  return api('/devices?' + q);
}
async function reloadDevices() {
  retryFn = reloadDevices; const gen = ++dv.gen; setLoading(true); showError(null); setEmpty(null);
  try {
    const r = await fetchDevices(1); if (gen !== dv.gen) return;
    Object.assign(dv, { page: 1, items: r.items, total: r.total, hasMore: r.page * r.pageSize < r.total });
  } catch (e) { if (gen !== dv.gen) return; Object.assign(dv, { items: [], total: 0, hasMore: false }); showError(e.message); }
  setLoading(false); renderDevices();
}
async function loadMoreDevices() {
  const gen = dv.gen;
  try {
    const r = await fetchDevices(dv.page + 1); if (gen !== dv.gen) return;
    dv.page++; dv.items.push(...r.items); dv.total = r.total; dv.hasMore = r.page * r.pageSize < r.total;
  } catch (e) { showError(e.message); }
  renderDevices();
}
function renderDevices() {
  $('result-count').textContent = `${dv.total} devices`;
  $('device-rows').replaceChildren(...dv.items.map((d) =>
    el('tr', { testid: 'devices.row.' + d.id, tabindex: 0, onclick: () => openDevice(d) },
      el('td', {}, d.serialNumber), el('td', {}, d.model), el('td', {}, d.storeName),
      el('td', {}, el('span', { class: 'badge ' + d.status }, d.status[0].toUpperCase() + d.status.slice(1))))));
  $('load-more').hidden = !dv.hasMore;
  setEmpty(!dv.items.length && $('error').hidden && $('loading').hidden ? 'No devices found' : null);
}
let searchTimer;
$('search').addEventListener('input', () => { clearTimeout(searchTimer); searchTimer = setTimeout(reloadDevices, 300); });
$('status').addEventListener('change', reloadDevices);
$('load-more').addEventListener('click', loadMoreDevices);

function openDevice(d) {
  const rows = [['Serial', d.serialNumber, 'serial'], ['Model', d.model, 'model'], ['OS', d.osVersion],
    ['Store', d.storeName, 'store'], ['Status', d.status[0].toUpperCase() + d.status.slice(1), 'status'],
    ['Content version', d.contentVersion ?? 'None', 'content'], ['Last check-in', new Date(d.lastCheckIn).toLocaleString('en-GB')]];
  $('device-detail').replaceChildren(...rows.flatMap(([k, v, id]) =>
    [el('dt', {}, k), el('dd', id ? { testid: 'deviceDetail.' + id } : {}, v)]));
  $('device-dialog').showModal();
}
$('device-close').addEventListener('click', () => $('device-dialog').close());

// ---------- content + deploy ----------
async function loadContent() {
  retryFn = loadContent; setLoading(true); showError(null); setEmpty(null);
  try {
    const pkgs = await api('/packages');
    $('package-list').replaceChildren(...pkgs.map((p) =>
      el('li', { testid: 'content.row.' + p.id },
        el('div', { class: 'head' },
          el('div', {}, el('strong', {}, p.name), el('div', { class: 'muted' }, `v${p.version} · ${p.sizeMB} MB · ${p.category}`)),
          el('button', { class: 'primary', testid: 'content.deploy.' + p.id, onclick: () => openDeploy(p) }, 'Deploy')))));
    if (!pkgs.length) setEmpty('No content packages');
  } catch (e) { $('package-list').replaceChildren(); showError(e.message); }
  setLoading(false);
}

const dp = { pkg: null, stores: [], selected: new Set() };
async function openDeploy(pkg) {
  Object.assign(dp, { pkg, stores: [], selected: new Set() });
  $('deploy-title').textContent = `Deploy ${pkg.name} v${pkg.version}`;
  $('deploy-error').hidden = true; $('select-all').hidden = !bulkSelectEnabled;
  $('deploy-dialog').showModal(); renderDeploy();
  try { dp.stores = await api('/stores'); } catch (e) { return showDeployError(e.message); }
  renderDeploy();
}
function showDeployError(msg) { $('deploy-error').hidden = !msg; $('deploy-error').textContent = msg || ''; }
function renderDeploy() {
  const all = dp.stores.length > 0 && dp.selected.size === dp.stores.length;
  $('select-all').textContent = all ? 'Deselect all' : 'Select all';
  $('store-list').replaceChildren(...dp.stores.map((s) =>
    el('li', {}, el('button', { type: 'button', testid: 'deploySheet.store.' + s.id, 'aria-pressed': dp.selected.has(s.id),
      onclick: () => { dp.selected.has(s.id) ? dp.selected.delete(s.id) : dp.selected.add(s.id); renderDeploy(); } },
      el('span', {}, `${s.name} `, el('span', { class: 'muted' }, `${s.partner} · ${s.deviceCount} devices`)),
      dp.selected.has(s.id) ? '✓' : ''))));
  const devices = dp.stores.filter((s) => dp.selected.has(s.id)).reduce((n, s) => n + s.deviceCount, 0);
  $('selection-count').textContent = `${dp.selected.size} stores · ${devices} devices`;
}
$('select-all').addEventListener('click', () => {
  dp.selected = dp.selected.size === dp.stores.length ? new Set() : new Set(dp.stores.map((s) => s.id)); renderDeploy();
});
$('deploy-cancel').addEventListener('click', () => $('deploy-dialog').close());
$('deploy-submit').addEventListener('click', async () => {
  $('deploy-submit').disabled = true; showDeployError(null);
  try {
    await api('/deployments', { method: 'POST', body: { packageID: dp.pkg.id, storeIDs: [...dp.selected] } });
    $('deploy-dialog').close(); show('deployments');
  } catch (e) { showDeployError(e.message); }
  $('deploy-submit').disabled = false;
});

// ---------- deployments ----------
const LABEL = { scheduled: 'Scheduled', inProgress: 'In Progress', completed: 'Completed', failed: 'Failed', cancelled: 'Cancelled' };
async function loadDeployments(first) {
  retryFn = loadDeployments; if (first) setLoading(true); showError(null);
  try {
    const list = await api('/deployments');
    $('deployment-list').replaceChildren(...list.map((d) =>
      el('li', { testid: 'deployments.row.' + d.id },
        el('div', { class: 'head' }, el('strong', {}, `${d.packageName} v${d.packageVersion}`),
          el('span', { class: 'badge ' + d.status, testid: 'deployments.status.' + d.id }, LABEL[d.status])),
        el('div', { class: 'muted' }, `${d.storeIDs.length} stores · ${d.deviceCount} devices`),
        el('progress', { max: 1, value: d.progress, testid: 'deployments.progress.' + d.id, 'aria-label': `${Math.round(d.progress * 100)} percent` }),
        d.status === 'scheduled' || d.status === 'inProgress'
          ? el('button', { testid: 'deployments.cancel.' + d.id, onclick: () => cancelDeployment(d.id) }, 'Cancel deployment') : null)));
    setEmpty(list.length ? null : 'No deployments yet');
  } catch (e) { showError(e.message); }
  setLoading(false);
}
async function cancelDeployment(id) {
  try { await api(`/deployments/${id}/cancel`, { method: 'POST' }); } catch (e) { showError(e.message); return; }
  loadDeployments();
}
function startDeployments() { loadDeployments(true); pollTimer = setInterval(() => tab === 'deployments' && loadDeployments(), 3000); }

show(location.hash.slice(1).split('?')[0] in { dashboard: 1, devices: 1, content: 1, deployments: 1 } ? location.hash.slice(1).split('?')[0] : 'dashboard');
