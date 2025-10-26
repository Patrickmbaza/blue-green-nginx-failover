const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

const appPool = process.env.APP_POOL || 'unknown';
const releaseId = process.env.RELEASE_ID || 'unknown-1.0.0';

let chaosMode = false;

app.use(express.json());

// Middleware to set headers on ALL responses
app.use((req, res, next) => {
  res.set({
    'X-App-Pool': appPool,
    'X-Release-Id': releaseId
  });
  next();
});

/**
 * GET /version → returns JSON and headers
 */
app.get('/version', (req, res) => {
  console.log(`/version called - Chaos mode: ${chaosMode}, Pool: ${appPool}`);
  
  if (chaosMode && appPool === 'blue') {
    console.log('Returning 500 error for chaos mode');
    return res.status(500).json({ 
      error: 'Service unavailable due to chaos mode',
      pool: appPool,
      release: releaseId,
      timestamp: new Date().toISOString()
    });
  }
  
  res.json({
    version: '1.0.0',
    pool: appPool,
    release: releaseId,
    status: 'healthy',
    timestamp: new Date().toISOString()
  });
});

/**
 * POST /chaos/start → simulates downtime (500s)
 */
app.post('/chaos/start', (req, res) => {
  console.log('Chaos mode activated');
  chaosMode = true;
  
  res.json({
    status: 'chaos_started',
    message: 'Chaos mode activated - /version will return 500 errors',
    pool: appPool,
    release: releaseId,
    timestamp: new Date().toISOString()
  });
});

/**
 * POST /chaos/stop → ends simulated downtime
 */
app.post('/chaos/stop', (req, res) => {
  console.log('Chaos mode deactivated');
  chaosMode = false;
  
  res.json({
    status: 'chaos_stopped',
    message: 'Chaos mode deactivated',
    pool: appPool,
    release: releaseId,
    timestamp: new Date().toISOString()
  });
});

/**
 * GET /healthz → process liveness
 * Should always return 200 when process is alive
 */
app.get('/healthz', (req, res) => {
  res.json({
    status: 'healthy',
    pool: appPool,
    release: releaseId,
    timestamp: new Date().toISOString()
  });
});

// Handle root path
app.get('/', (req, res) => {
  res.json({
    service: 'Blue-Green Deployment',
    current_pool: appPool,
    release: releaseId,
    chaos_mode: chaosMode,
    endpoints: ['GET /version', 'POST /chaos/start', 'POST /chaos/stop', 'GET /healthz']
  });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Server running on port ${port}, Pool: ${appPool}, Release: ${releaseId}`);
});