-- Migration: 000001_init_schema.down.sql
-- Rollback Cloud Manager Initial Schema

-- Drop triggers
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
DROP TRIGGER IF EXISTS update_cloud_providers_updated_at ON cloud_providers;
DROP TRIGGER IF EXISTS update_cloud_resources_updated_at ON cloud_resources;
DROP TRIGGER IF EXISTS update_alerts_updated_at ON alerts;
DROP TRIGGER IF EXISTS update_scheduled_jobs_updated_at ON scheduled_jobs;
DROP TRIGGER IF EXISTS update_notification_preferences_updated_at ON notification_preferences;

-- Drop trigger function
DROP FUNCTION IF EXISTS update_updated_at_column();

-- Drop tables in reverse order (respecting foreign keys)
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS notification_preferences;
DROP TABLE IF EXISTS job_executions;
DROP TABLE IF EXISTS scheduled_jobs;
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS cost_reports;
DROP TABLE IF EXISTS alert_history;
DROP TABLE IF EXISTS alerts;
DROP TABLE IF EXISTS resource_metrics;
DROP TABLE IF EXISTS cloud_resources;
DROP TABLE IF EXISTS cloud_providers;
DROP TABLE IF EXISTS users;

-- Drop extension
DROP EXTENSION IF EXISTS "uuid-ossp";
