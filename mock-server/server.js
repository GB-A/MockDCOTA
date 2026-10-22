#!/usr/bin/env node
// Zero-dependency mock DCOTA REST API (Node >= 18). Implements openapi.yaml.
//   node server.js            -> API + web console at http://localhost:8080
//   PORT=9000 node server.js
//
// Test-support endpoints (not part of the product API):
//   GET  /health
//   POST /__admin/reset                       restore seed data
//   POST /__admin/scenario  {"mode":"standard|empty|error|slow"}
//   POST /__admin/fail-next {"count":1,"status":503}   fail the next N /api calls

const http = require('http');
const { URL } = require('url');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 8080;
const FLEET_SCALE = 1_400_000;
const MAX_STORES = 10;
const REF = Date.UTC(2025, 9, 9, 8, 53, 20); // fixed "now" for stable data

// ---------- deterministic data ----------
function mulberry32(seed) {
  return () => {
    seed |= 0; seed = (seed + 0x6D2B79F5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const iso = (ms) => new Date(ms).toISOString().replace(/\.\d{3}Z$/, 'Z');

function seed() {
  const rnd = mulberry32(42);
  const pick = (a) => a[Math.floor(rnd() * a.length)];
  const cities = ['London', 'Manchester', 'Leeds', 'Glasgow', 'Bristol', 'Cardiff',
    'Edinburgh', 'Belfast', 'Sheffield', 'Liverpool', 'Dublin', 'Cork'];
  const partners = ['Northwind Retail', 'Contoso Mobile', 'Fabrikam Stores', 'Tailspin Tech'];
  const stores = cities.map((city, i) => ({
    id: `store-${String(i + 1).padStart(3, '0')}`, name: `${city} Central`, city,
    partner: partners[i % partners.length], deviceCount: 0,
  }));
  const models = ['Demo Phone 15', 'Demo Phone 16', 'Demo Tablet Air', 'Demo Tablet Pro', 'Demo Watch'];
  const oses = ['17.6', '17.7', '18.0', '18.1'];
  const statuses = ['online', 'online', 'online', 'online', 'online', 'online', 'offline', 'updating', 'failed'];
  const devices = Array.from({ length: 480 }, (_, k) => {
    const n = k + 1, store = pick(stores), status = pick(statuses);
    store.deviceCount++;
    const ageMin = status === 'offline' ? 600 + Math.floor(rnd() * 19400) : Math.floor(rnd() * 31);
    return {
      id: `dev-${String(n).padStart(5, '0')}`,
      serialNumber: `C02${String(1_000_000 + n * 37).padStart(7, '0')}`,
      model: pick(models), osVersion: pick(oses),
      storeID: store.id, storeName: store.name, status,
      contentVersion: status === 'failed' ? null : `2.0.${Math.floor(rnd() * 4)}`,
      lastCheckIn: iso(REF - ageMin * 60_000),
    };
  });
  const packages = [
    { id: 'pkg-001', name: 'Holiday Demo Loop', version: '2.1.0', sizeMB: 480, category: 'Marketing' },
    { id: 'pkg-002', name: 'Trade-In Promo', version: '1.4.2', sizeMB: 120, category: 'Promotion' },
    { id: 'pkg-003', name: 'Accessories Showcase', version: '3.0.0', sizeMB: 260, category: 'Product' },
    { id: 'pkg-004', name: 'Store Safety Notice', version: '1.0.1', sizeMB: 12, category: 'Compliance' },
    { id: 'pkg-005', name: 'Wearables Launch', version: '0.9.0', sizeMB: 910, category: 'Marketing' },
  ];
  const deployments = [
    { id: 'dep-001', packageID: 'pkg-001', packageName: 'Holiday Demo Loop', packageVersion: '2.1.0',
      storeIDs: ['store-001'], deviceCount: 40, status: 'inProgress', progress: 0.5, createdAt: iso(REF - 3_600_000) },
    { id: 'dep-002', packageID: 'pkg-002', packageName: 'Trade-In Promo', packageVersion: '1.4.2',
      storeIDs: ['store-002', 'store-003'], deviceCount: 80, status: 'completed', progress: 1, createdAt: iso(REF - 86_400_000) },
    { id: 'dep-003', packageID: 'pkg-003', packageName: 'Accessories Showcase', packageVersion: '3.0.0',
      storeIDs: ['store-004'], deviceCount: 38, status: 'failed', progress: 0.3, createdAt: iso(REF - 172_800_000) },
  ];
  return { stores, devices, packages, deployments };
}

// ---------- state ----------
let db, mode = 'standard', failNext = { count: 0, status: 503 }, nextDep = 100;
const ticks = {};
function reset() {
  db = seed(); mode = 'standard'; failNext = { count: 0, status: 503 }; nextDep = 100;
  for (const k of Object.keys(ticks)) delete ticks[k];
}
reset();

const isActive = (d) => d.status === 'scheduled' || d.status === 'inProgress';
class ApiError extends Error {
  constructor(status, code, message) { super(message); this.status = status; this.code = code; }
}

// ---------- handlers ----------
function summary() {
  if (mode === 'empty') return { totalDevices: 0, online: 0, offline: 0, updating: 0, failed: 0, activeDeployments: 0 };
  const n = db.devices.length;
  const scaled = (s) => Math.round(db.devices.filter((d) => d.status === s).length / n * FLEET_SCALE);
  const online = scaled('online'), offline = scaled('offline'), updating = scaled('updating');
  return { totalDevices: FLEET_SCALE, online, offline, updating,
    failed: FLEET_SCALE - online - offline - updating,
    activeDeployments: db.deployments.filter(isActive).length };
}

function listDevices(q) {
  const page = Number(q.get('page') ?? 1), pageSize = Number(q.get('pageSize') ?? 25);
  if (!Number.isInteger(page) || page < 1) throw new ApiError(400, 'VALIDATION_ERROR', 'page must be >= 1');
  if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100)
    throw new ApiError(400, 'VALIDATION_ERROR', 'pageSize must be between 1 and 100');
  const status = q.get('status');
  if (status && !['online', 'offline', 'updating', 'failed'].includes(status))
    throw new ApiError(400, 'VALIDATION_ERROR', `Unknown status '${status}'`);
  const term = (q.get('search') ?? '').trim().toLowerCase();
  const all = (mode === 'empty' ? [] : db.devices).filter((d) =>
    (!status || d.status === status) &&
    (!term || [d.serialNumber, d.storeName, d.model].some((f) => f.toLowerCase().includes(term))));
  const start = (page - 1) * pageSize;
  return { items: all.slice(start, start + pageSize), page, pageSize, total: all.length };
}

function listDeployments() {
  for (const d of db.deployments.filter(isActive)) {
    if (d.id === 'dep-001') continue; // fixture stays in progress
    const t = (ticks[d.id] = (ticks[d.id] ?? 0) + 1);
    if (t === 1) { d.status = 'inProgress'; d.progress = 0.4; }
    else if (t === 2) d.progress = 0.8;
    else { d.status = 'completed'; d.progress = 1; }
  }
  return [...(mode === 'empty' ? [] : db.deployments)].sort((a, b) => b.createdAt.localeCompare(a.createdAt));
}

function createDeployment(body) {
  if (!body || typeof body.packageID !== 'string' || !Array.isArray(body.storeIDs))
    throw new ApiError(400, 'VALIDATION_ERROR', 'packageID and storeIDs are required');
  const pkg = db.packages.find((p) => p.id === body.packageID);
  if (!pkg) throw new ApiError(404, 'NOT_FOUND', `Package ${body.packageID} not found`);
  const ids = [...new Set(body.storeIDs)].sort();
  if (ids.length === 0) throw new ApiError(400, 'VALIDATION_ERROR', 'Select at least one store.');
  if (ids.length > MAX_STORES)
    throw new ApiError(400, 'VALIDATION_ERROR', `A deployment can target at most ${MAX_STORES} stores.`);
  const targets = db.stores.filter((s) => ids.includes(s.id));
  if (targets.length !== ids.length) throw new ApiError(400, 'VALIDATION_ERROR', 'One or more stores do not exist.');
  const busy = db.deployments.some((d) => isActive(d) && d.packageID === pkg.id && d.storeIDs.some((s) => ids.includes(s)));
  if (busy) throw new ApiError(409, 'CONFLICT', `${pkg.name} is already being deployed to one or more selected stores.`);
  const dep = {
    id: `dep-${++nextDep}`, packageID: pkg.id, packageName: pkg.name, packageVersion: pkg.version,
    storeIDs: ids, deviceCount: targets.reduce((n, s) => n + s.deviceCount, 0),
    status: 'scheduled', progress: 0, createdAt: iso(Date.now()),
  };
  db.deployments.push(dep);
  return dep;
}

function cancelDeployment(id) {
  const d = db.deployments.find((x) => x.id === id);
  if (!d) throw new ApiError(404, 'NOT_FOUND', `Deployment ${id} not found`);
  if (!isActive(d)) throw new ApiError(409, 'CONFLICT', 'Only scheduled or in-progress deployments can be cancelled.');
  d.status = 'cancelled';
  return d;
}

// Web console (mock-server/web), served from the same origin as the API.
const STATIC = {
  '/': ['index.html', 'text/html; charset=utf-8'],
  '/styles.css': ['styles.css', 'text/css; charset=utf-8'],
  '/app.js': ['app.js', 'text/javascript; charset=utf-8'],
};

// ---------- plumbing ----------
function readBody(req) {
  return new Promise((resolve, reject) => {
    let raw = '';
    req.on('data', (c) => (raw += c));
    req.on('end', () => {
      if (!raw) return resolve(undefined);
      try { resolve(JSON.parse(raw)); }
      catch { reject(new ApiError(400, 'VALIDATION_ERROR', 'Request body is not valid JSON')); }
    });
  });
}

function send(res, status, body) {
  const payload = JSON.stringify(body);
  res.writeHead(status, { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload) });
  res.end(payload);
}

async function route(req, res) {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const p = url.pathname.replace(/\/+$/, '') || '/';
  const m = req.method;
  const body = ['POST', 'PUT', 'PATCH'].includes(m) ? await readBody(req) : undefined;

  if (p === '/health') return send(res, 200, { status: 'ok', mode });
  if (p === '/__admin/reset' && m === 'POST') { reset(); return send(res, 200, { status: 'reset' }); }
  if (p === '/__admin/scenario' && m === 'POST') {
    if (!['standard', 'empty', 'error', 'slow'].includes(body?.mode)) throw new ApiError(400, 'VALIDATION_ERROR', 'bad mode');
    mode = body.mode; return send(res, 200, { mode });
  }
  if (p === '/__admin/fail-next' && m === 'POST') {
    failNext = { count: body?.count ?? 1, status: body?.status ?? 503 }; return send(res, 200, failNext);
  }

  if (m === 'GET' && p === '/favicon.ico') { res.writeHead(204); return res.end(); }
  if (m === 'GET' && STATIC[p]) {
    const [file, type] = STATIC[p];
    res.writeHead(200, { 'Content-Type': type, 'Cache-Control': 'no-store' });
    return res.end(fs.readFileSync(path.join(__dirname, 'web', file)));
  }

  if (!p.startsWith('/api/v1/')) throw new ApiError(404, 'NOT_FOUND', `No route for ${m} ${p}`);
  if (failNext.count > 0) { failNext.count--; throw new ApiError(failNext.status, 'SERVER_ERROR', 'Injected failure'); }
  if (mode === 'error') throw new ApiError(503, 'SERVER_ERROR', 'DCOTA service is unavailable. Please try again.');
  if (mode === 'slow') await new Promise((r) => setTimeout(r, 2000));

  const r = p.slice('/api/v1'.length);
  let match;
  if (m === 'GET' && r === '/fleet/summary') return send(res, 200, summary());
  if (m === 'GET' && r === '/devices') return send(res, 200, listDevices(url.searchParams));
  if (m === 'GET' && (match = r.match(/^\/devices\/([\w-]+)$/))) {
    const d = (mode === 'empty' ? [] : db.devices).find((x) => x.id === match[1]);
    if (!d) throw new ApiError(404, 'NOT_FOUND', `Device ${match[1]} not found`);
    return send(res, 200, d);
  }
  if (m === 'GET' && r === '/stores') return send(res, 200, db.stores);
  if (m === 'GET' && r === '/packages') return send(res, 200, mode === 'empty' ? [] : db.packages);
  if (m === 'GET' && r === '/deployments') return send(res, 200, listDeployments());
  if (m === 'POST' && r === '/deployments') return send(res, 201, createDeployment(body));
  if (m === 'POST' && (match = r.match(/^\/deployments\/([\w-]+)\/cancel$/))) return send(res, 200, cancelDeployment(match[1]));
  throw new ApiError(404, 'NOT_FOUND', `No route for ${m} ${p}`);
}

const server = http.createServer((req, res) => {
  route(req, res).catch((e) => {
    if (e instanceof ApiError) return send(res, e.status, { code: e.code, message: e.message });
    console.error(e); send(res, 500, { code: 'SERVER_ERROR', message: 'Unexpected error' });
  });
});

if (require.main === module) {
  server.listen(PORT, () => console.log(`Mock DCOTA API listening on http://localhost:${PORT}`));
}
module.exports = server;
