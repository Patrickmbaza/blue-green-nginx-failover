const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

const appPool = process.env.APP_POOL || 'unknown';
const releaseId = process.env.RELEASE_ID || 'unknown-1.0.0';

let chaosMode = false;

app.use(express.json());

// Set headers on ALL responses
app.use((req, res, next) => {
  res.set({
    'X-App-Pool': appPool,
    'X-Release-Id': releaseId
  });
  next();
});

app.get('/version', (req, res) => {
  if (chaosMode) {
    return res.status(500).json({ 
      error: 'Chaos mode active',
      pool: appPool,
      release: releaseId  // ← CRITICAL: Include release ID in JSON during chaos too!
    });
  }
  
  res.json({
    version: '1.0.0',
    pool: appPool,
    release: releaseId,  // ← CRITICAL: This must match the header!
    timestamp: new Date().toISOString()
  });
});

app.get('/healthz', (req, res) => {
  res.json({ 
    status: 'healthy', 
    pool: appPool,
    release: releaseId  // ← Include release ID
  });
});

app.post('/chaos/start', (req, res) => {
  chaosMode = true;
  res.json({ 
    status: 'chaos started', 
    pool: appPool,
    release: releaseId  // ← Include release ID
  });
});

app.post('/chaos/stop', (req, res) => {
  chaosMode = false;
  res.json({ 
    status: 'chaos stopped', 
    pool: appPool,
    release: releaseId  // ← Include release ID
  });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Server running on port ${port}, Pool: ${appPool}, Release: ${releaseId}`);
});
