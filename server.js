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

// Chaos mode middleware for ALL endpoints except chaos control
app.use((req, res, next) => {
  // Skip chaos for chaos control endpoints and health check
  if (req.path === '/chaos/start' || req.path === '/chaos/stop' || req.path === '/healthz') {
    return next();
  }
  
  if (chaosMode) {
    if (chaosModeType === 'error') {
      return res.status(500).json({
        error: 'Service unavailable - chaos mode active',
        timestamp: new Date().toISOString(),
        instance: appPool,
        release: releaseId
      });
    } else if (chaosModeType === 'timeout') {
      // Simulate timeout by not responding
      return setTimeout(() => {
        res.status(504).json({
          error: 'Service timeout - chaos mode active',
          timestamp: new Date().toISOString(),
          instance: appPool,
          release: releaseId
        });
      }, 10000); // 10 second timeout
    }
  }
  
  next();
});

/**
 * GET /version → returns JSON and headers
 * Headers: X-App-Pool, X-Release-Id
 */
app.get('/version', (req, res) => {
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
    description: 'This service demonstrates blue-green deployment with automatic failover',
    endpoints: {
      'GET /version': 'Returns version info with X-App-Pool and X-Release-Id headers',
      'POST /chaos/start': 'Simulates downtime (500s or timeout)',
      'POST /chaos/stop': 'Ends simulated downtime', 
      'GET /healthz': 'Process liveness check'
    },
    this_instance: {
      environment: appPool,
      release: releaseId,
      status: 'healthy',
      port: port,
      timestamp: new Date().toISOString()
    },
    headers_provided: {
      'X-App-Pool': 'Identifies which pool (blue/green) served this request',
      'X-Release-Id': 'Identifies the release version of this instance'
    }
  });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Server running on port ${port}, Pool: ${appPool}, Release: ${releaseId}`);
});
