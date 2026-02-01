import 'reflect-metadata';
import 'dotenv/config';

// Import config first to ensure it's initialized
import './config/config.mongodb';

// Then import app which uses config
import app from './app';

// Get port from environment with fallback
const PORT = parseInt(process.env.DEV_APP_PORT || '3052', 10);

const server = app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});

process.on('SIGINT', () => {
  server.close(() => console.log('Server closed'));
  process.exit(0);
});
