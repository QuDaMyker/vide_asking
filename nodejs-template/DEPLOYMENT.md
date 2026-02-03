# Deployment Guide

This guide covers deploying the Node.js API to different environments: development, staging, and production.

---

## Table of Contents

1. [Environment Overview](#environment-overview)
2. [Prerequisites](#prerequisites)
3. [Environment Configuration](#environment-configuration)
4. [Local Development](#local-development)
5. [Staging Deployment](#staging-deployment)
6. [Production Deployment](#production-deployment)
7. [Database Migrations](#database-migrations)
8. [Docker Deployment](#docker-deployment)
9. [Health Checks & Monitoring](#health-checks--monitoring)
10. [Troubleshooting](#troubleshooting)

---

## Environment Overview

### Development
- **Purpose**: Local development with hot reload
- **Database**: Local PostgreSQL
- **Logging**: Verbose (debug level)
- **Security**: Relaxed for easier debugging
- **Port**: 3000 (default)

### Staging
- **Purpose**: Pre-production testing environment
- **Database**: Staging database server
- **Logging**: Moderate (info level)
- **Security**: Production-like settings
- **Port**: 3000 (default)

### Production
- **Purpose**: Live production environment
- **Database**: Production database server
- **Logging**: Minimal (error level)
- **Security**: Maximum security settings
- **Port**: 3000 (default)

---

## Prerequisites

### All Environments
- Node.js v18 or higher
- PostgreSQL v13 or higher
- npm or yarn

### Staging/Production Only
- Secure environment variable management (AWS Secrets Manager, HashiCorp Vault, etc.)
- SSL certificates for HTTPS
- Reverse proxy (Nginx, Apache, or cloud load balancer)
- Monitoring tools (optional but recommended)

---

## Environment Configuration

### Environment Files

Each environment has its own configuration file:

- `.env.development` - Development settings
- `.env.staging` - Staging settings
- `.env.production` - Production settings

**⚠️ IMPORTANT**: Never commit actual `.env.staging` or `.env.production` files with real credentials!

### Required Environment Variables

#### Development (.env.development)
```env
NODE_ENV=development
PORT=3000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=nodejs_template_dev
DB_USER=postgres
DB_PASSWORD=your_dev_password
JWT_SECRET=dev_jwt_secret
JWT_REFRESH_SECRET=dev_refresh_secret
CORS_ORIGIN=*
```

#### Staging (.env.staging)
```env
NODE_ENV=staging
PORT=3000
DB_HOST=staging-db.example.com
DB_PORT=5432
DB_NAME=nodejs_template_staging
DB_USER=staging_user
DB_PASSWORD=<secure_password>
JWT_SECRET=<random_secure_string>
JWT_REFRESH_SECRET=<random_secure_string>
CORS_ORIGIN=https://staging.example.com
LOG_LEVEL=info
```

#### Production (.env.production)
```env
NODE_ENV=production
PORT=3000
DB_HOST=prod-db.example.com
DB_PORT=5432
DB_NAME=nodejs_template_prod
DB_USER=prod_user
DB_PASSWORD=<very_secure_password>
JWT_SECRET=<very_random_secure_string>
JWT_REFRESH_SECRET=<very_random_secure_string>
CORS_ORIGIN=https://api.example.com,https://example.com
LOG_LEVEL=error
HELMET_ENABLED=true
TRUST_PROXY=true
```

---

## Local Development

### Setup

1. **Create database**:
```bash
createdb nodejs_template_dev
```

2. **Configure environment**:
```bash
cp .env.development.example .env.development
# Edit .env.development with your local settings
```

3. **Install dependencies**:
```bash
npm install
```

4. **Run migrations**:
```bash
npm run db:migrate:dev
```

5. **Start development server**:
```bash
npm run dev
```

The server will start with hot reload enabled on http://localhost:3000

### Development Scripts

```bash
npm run dev              # Start with hot reload
npm run dev:debug        # Start with debug logging
npm run build            # Build TypeScript
npm run start:dev        # Start built version (dev config)
npm run test:dev         # Run tests in development mode
```

---

## Staging Deployment

### Option 1: Direct Deployment (Node.js)

1. **Set up staging server** (SSH into server):
```bash
ssh user@staging-server.example.com
```

2. **Clone repository**:
```bash
git clone <repository-url>
cd nodejs-template
```

3. **Configure environment**:
```bash
cp .env.staging.example .env.staging
# Edit with staging credentials (use secure method!)
```

4. **Install dependencies**:
```bash
npm ci --only=production
```

5. **Build application**:
```bash
npm run build:staging
```

6. **Run migrations**:
```bash
npm run db:migrate:staging
```

7. **Start application** (use process manager):
```bash
# Using PM2
pm2 start npm --name "api-staging" -- run start:staging

# Or using systemd
sudo systemctl start nodejs-api-staging
```

### Option 2: Docker Deployment

1. **Build and start with Docker Compose**:
```bash
docker-compose -f docker-compose.staging.yml up -d
```

2. **Run migrations inside container**:
```bash
docker-compose -f docker-compose.staging.yml exec app npm run db:migrate:staging
```

3. **Check logs**:
```bash
docker-compose -f docker-compose.staging.yml logs -f
```

### Staging Scripts

```bash
npm run staging          # Build and start staging
npm run build:staging    # Build with staging config
npm run start:staging    # Start staging server
npm run db:migrate:staging  # Run database migrations
```

---

## Production Deployment

### Pre-Deployment Checklist

- [ ] All tests passing
- [ ] Code reviewed and approved
- [ ] Staging environment tested
- [ ] Database backup created
- [ ] Environment variables secured
- [ ] SSL certificates configured
- [ ] Monitoring tools set up
- [ ] Rollback plan prepared

### Option 1: Direct Deployment (Node.js)

1. **Set up production server**:
```bash
ssh user@prod-server.example.com
```

2. **Clone or pull latest code**:
```bash
git pull origin main
```

3. **Configure environment** (use secrets manager):
```bash
# Use AWS Secrets Manager, HashiCorp Vault, etc.
# Never copy .env.production directly!
```

4. **Install dependencies**:
```bash
npm ci --only=production
```

5. **Build application**:
```bash
npm run build:prod
```

6. **Run migrations** (during maintenance window):
```bash
npm run db:migrate:prod
```

7. **Start/restart application**:
```bash
# Using PM2
pm2 restart api-prod

# Or using systemd
sudo systemctl restart nodejs-api
```

### Option 2: Docker Deployment

1. **Pull latest changes**:
```bash
git pull origin main
```

2. **Build and deploy**:
```bash
docker-compose -f docker-compose.prod.yml up -d --build
```

3. **Run migrations**:
```bash
docker-compose -f docker-compose.prod.yml exec app npm run db:migrate:prod
```

4. **Verify deployment**:
```bash
curl https://api.example.com/health
```

### Production Scripts

```bash
npm run prod             # Build and start production
npm run build:prod       # Build with production config
npm run start:prod       # Start production server
npm run db:migrate:prod  # Run production migrations
```

### Using PM2 (Process Manager)

**Install PM2**:
```bash
npm install -g pm2
```

**Start application**:
```bash
pm2 start npm --name "api-prod" -- run start:prod
```

**Useful PM2 commands**:
```bash
pm2 list                 # List all processes
pm2 logs api-prod        # View logs
pm2 restart api-prod     # Restart application
pm2 stop api-prod        # Stop application
pm2 save                 # Save process list
pm2 startup              # Generate startup script
```

---

## Database Migrations

### Development
```bash
# Create migration
npx sequelize-cli migration:generate --name add-user-field

# Run migrations
npm run db:migrate:dev

# Undo last migration
npm run db:migrate:undo
```

### Staging
```bash
npm run db:migrate:staging
```

### Production
```bash
# ALWAYS test migrations in staging first!
npm run db:migrate:prod
```

### Migration Best Practices

1. **Always test in development** before staging
2. **Test in staging** before production
3. **Create database backup** before production migrations
4. **Have rollback plan** ready
5. **Run during maintenance window** if possible
6. **Monitor database** after migration

---

## Docker Deployment

### Development
```bash
# Start services
docker-compose -f docker-compose.dev.yml up

# With rebuild
docker-compose -f docker-compose.dev.yml up --build

# Stop services
docker-compose -f docker-compose.dev.yml down
```

### Staging
```bash
# Start
docker-compose -f docker-compose.staging.yml up -d

# View logs
docker-compose -f docker-compose.staging.yml logs -f app

# Stop
docker-compose -f docker-compose.staging.yml down
```

### Production
```bash
# Start
docker-compose -f docker-compose.prod.yml up -d

# View logs
docker-compose -f docker-compose.prod.yml logs -f app

# Stop (with maintenance notice!)
docker-compose -f docker-compose.prod.yml down
```

### Useful Docker Commands

```bash
# View running containers
docker ps

# Execute command in container
docker-compose -f docker-compose.prod.yml exec app sh

# View logs
docker logs <container_id>

# Remove unused images
docker image prune -a

# View resource usage
docker stats
```

---

## Health Checks & Monitoring

### Health Check Endpoint

The API provides a health check endpoint:

```bash
curl http://localhost:3000/health
```

Response:
```json
{
  "status": "ok",
  "timestamp": "2026-02-03T10:00:00.000Z",
  "uptime": 3600
}
```

### Monitoring Recommendations

1. **Application Performance Monitoring**:
   - New Relic
   - Datadog
   - AppDynamics

2. **Log Management**:
   - ELK Stack (Elasticsearch, Logstash, Kibana)
   - Splunk
   - CloudWatch Logs (AWS)

3. **Uptime Monitoring**:
   - Pingdom
   - UptimeRobot
   - StatusCake

4. **Database Monitoring**:
   - pgAdmin (PostgreSQL)
   - CloudWatch (AWS RDS)
   - Datadog

### Metrics to Monitor

- Response times
- Error rates
- CPU usage
- Memory usage
- Database connections
- Request rate
- Active users

---

## Troubleshooting

### Application Won't Start

**Check environment variables**:
```bash
# Verify .env file exists
ls -la .env*

# Check if variables are loaded
node -e "require('dotenv').config(); console.log(process.env.DB_HOST)"
```

**Check database connection**:
```bash
# Test PostgreSQL connection
psql -h $DB_HOST -U $DB_USER -d $DB_NAME
```

**Check logs**:
```bash
# PM2
pm2 logs api-prod

# Docker
docker-compose -f docker-compose.prod.yml logs app

# System logs
journalctl -u nodejs-api -f
```

### Database Migration Failed

**Rollback migration**:
```bash
npm run db:migrate:undo
```

**Check migration status**:
```bash
npx sequelize-cli db:migrate:status
```

**Restore from backup**:
```bash
# PostgreSQL
pg_restore -h $DB_HOST -U $DB_USER -d $DB_NAME backup.sql
```

### High Memory Usage

**Check Node.js memory**:
```bash
# Add to package.json script
node --max-old-space-size=2048 dist/server.js
```

**Monitor with PM2**:
```bash
pm2 monit
```

### Connection Pool Exhausted

Check `src/config/database.ts` pool settings:
```typescript
pool: {
  max: 5,      // Increase if needed
  min: 0,
  acquire: 30000,
  idle: 10000
}
```

---

## Security Checklist

### Pre-Production

- [ ] All environment variables secured
- [ ] JWT secrets are strong and unique
- [ ] Database passwords are strong
- [ ] CORS properly configured
- [ ] Rate limiting enabled
- [ ] Helmet.js security headers enabled
- [ ] HTTPS/TLS enabled
- [ ] Database backups automated
- [ ] Monitoring and alerting configured
- [ ] Error messages don't leak sensitive info

### Post-Deployment

- [ ] Health check responding
- [ ] All endpoints accessible
- [ ] Database migrations applied
- [ ] Logs are being generated
- [ ] Monitoring dashboard shows green
- [ ] SSL certificate valid
- [ ] Performance metrics acceptable

---

## Rollback Procedure

### Quick Rollback

1. **Using Git**:
```bash
git checkout <previous_commit>
pm2 restart api-prod
```

2. **Using Docker**:
```bash
docker-compose -f docker-compose.prod.yml down
# Revert to previous image
docker-compose -f docker-compose.prod.yml up -d
```

3. **Database Rollback**:
```bash
# Restore from backup
pg_restore -h $DB_HOST -U $DB_USER -d $DB_NAME backup_before_deployment.sql
```

---

## Support & Resources

- **Documentation**: Check `README.md` and `API_DOCUMENTATION.md`
- **Logs**: Check application and system logs
- **Monitoring**: Check monitoring dashboard
- **Team**: Contact DevOps or backend team

---

**Remember**: Always test in staging before deploying to production!
