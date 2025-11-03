const express = require('express');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());

// Health check endpoint (important for ECS)
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    hostname: os.hostname(),
    platform: os.platform(),
    nodeVersion: process.version
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Welcome to ECS Demo Application!',
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    container: {
      hostname: os.hostname(),
      platform: os.platform(),
      arch: os.arch(),
      cpus: os.cpus().length,
      totalMemory: `${(os.totalmem() / 1024 / 1024 / 1024).toFixed(2)} GB`,
      freeMemory: `${(os.freemem() / 1024 / 1024 / 1024).toFixed(2)} GB`
    },
    timestamp: new Date().toISOString()
  });
});

// API endpoints
app.get('/api/info', (req, res) => {
  res.json({
    app: 'ECS Demo App',
    version: '1.0.0',
    description: 'A simple Node.js application running on AWS ECS',
    endpoints: [
      { path: '/', method: 'GET', description: 'Root endpoint with system info' },
      { path: '/health', method: 'GET', description: 'Health check endpoint' },
      { path: '/api/info', method: 'GET', description: 'API information' },
      { path: '/api/echo', method: 'POST', description: 'Echo service' }
    ]
  });
});

// Echo endpoint for testing POST requests
app.post('/api/echo', (req, res) => {
  res.json({
    message: 'Echo response',
    receivedData: req.body,
    timestamp: new Date().toISOString(),
    hostname: os.hostname()
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    path: req.path,
    method: req.method,
    timestamp: new Date().toISOString()
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: err.message,
    timestamp: new Date().toISOString()
  });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`
╔════════════════════════════════════════════╗
║     ECS Demo Application Started          ║
╚════════════════════════════════════════════╝

Server is running on:
  - Local:   http://localhost:${PORT}
  - Network: http://0.0.0.0:${PORT}

Hostname: ${os.hostname()}
Platform: ${os.platform()}
Node Version: ${process.version}
Environment: ${process.env.NODE_ENV || 'development'}

Available Endpoints:
  GET  /              - System information
  GET  /health        - Health check
  GET  /api/info      - API information
  POST /api/echo      - Echo service

Press Ctrl+C to stop the server
  `);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    console.log('HTTP server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('\nSIGINT signal received: closing HTTP server');
  process.exit(0);
});
