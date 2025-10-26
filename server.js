const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

const appPool = process.env.APP_POOL || 'unknown';
const releaseId = process.env.RELEASE_ID || 'unknown-1.0.0';

let chaosMode = false;
let chaosModeType = null; // 'error' or 'timeout'

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
 * Headers: X-App-Pool, X-Release-Id
 */
app.get('/version', (req, res) => {
  if (chaosMode) {
    if (chaosModeType === 'error') {
      return res.status(500).json({
        error: 'Service unavailable - chaos mode active',
        timestamp: new Date().toISOString()
      });
    } else if (chaosModeType === 'timeout') {
      // Simulate timeout by not responding
      return setTimeout(() => {
        res.status(504).json({
          error: 'Service timeout - chaos mode active',
          timestamp: new Date().toISOString()
        });
      }, 10000); // 10 second timeout
    }
  }
  
  res.json({
    version: '1.0.0',
    status: 'healthy',
    environment: appPool,
    release: releaseId,
    timestamp: new Date().toISOString()
  });
});

/**
 * POST /chaos/start → simulates downtime (500s or timeout)
 * Query params: ?mode=error or ?mode=timeout
 */
app.post('/chaos/start', (req, res) => {
  const mode = req.query.mode || 'error';
  
  if (mode !== 'error' && mode !== 'timeout') {
    return res.status(400).json({
      error: 'Invalid mode. Use "error" or "timeout"',
      timestamp: new Date().toISOString()
    });
  }
  
  chaosMode = true;
  chaosModeType = mode;
  
  res.json({
    status: 'chaos_started',
    mode: mode,
    message: `Chaos mode activated with ${mode} simulation`,
    timestamp: new Date().toISOString()
  });
});

/**
 * POST /chaos/stop → ends simulated downtime
 */
app.post('/chaos/stop', (req, res) => {
  chaosMode = false;
  chaosModeType = null;
  
  res.json({
    status: 'chaos_stopped',
    message: 'Chaos mode deactivated',
    timestamp: new Date().toISOString()
  });
});

/**
 * GET /healthz → process liveness
 * Always returns 200 when process is alive
 */
app.get('/healthz', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString()
  });
});

// Root endpoint - informational
app.get('/', (req, res) => {
  res.json({
    service: 'Blue-Green Deployment API',
    endpoints: {
      'GET /version': 'Returns version info with X-App-Pool and X-Release-Id headers',
      'POST /chaos/start': 'Simulates downtime (500s or timeout)',
      'POST /chaos/stop': 'Ends simulated downtime', 
      'GET /healthz': 'Process liveness check'
    },
    current_environment: appPool,
    release: releaseId,
    chaos_mode: chaosMode ? `${chaosModeType} mode` : 'inactive'
  });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Server running on port ${port}, Pool: ${appPool}, Release: ${releaseId}`);
});