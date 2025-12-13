-- ============================================================
-- Locket App Database Setup Script for PostgreSQL
-- ============================================================
-- Description: Complete database schema for a Locket-like
--              real-time photo sharing application
-- Database: PostgreSQL 12+
-- Author: Database Design Document
-- Created: 2025-10-11
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Set timezone to UTC
SET timezone = 'UTC';

-- ============================================================
-- TABLE: users
-- Description: Stores user account information and preferences
-- ============================================================
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone_number VARCHAR(20) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    display_name VARCHAR(100),
    profile_photo_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_seen_at TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    notification_enabled BOOLEAN DEFAULT TRUE,
    widget_enabled BOOLEAN DEFAULT TRUE
);

-- Indexes for users table
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_phone ON users(phone_number);

-- ============================================================
-- TABLE: friendships
-- Description: Manages friend connections between users
-- ============================================================
CREATE TYPE friendship_status AS ENUM ('pending', 'accepted', 'blocked');

CREATE TABLE friendships (
    friendship_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id_1 UUID NOT NULL,
    user_id_2 UUID NOT NULL,
    status friendship_status DEFAULT 'pending',
    requested_by UUID NOT NULL,
    requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    accepted_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id_1) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id_2) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (requested_by) REFERENCES users(user_id),
    CONSTRAINT unique_friendship UNIQUE (
        LEAST(user_id_1, user_id_2),
        GREATEST(user_id_1, user_id_2)
    )
);

-- Indexes for friendships table
CREATE INDEX idx_friendships_user_1 ON friendships(user_id_1, status);
CREATE INDEX idx_friendships_user_2 ON friendships(user_id_2, status);
CREATE INDEX idx_friendships_status ON friendships(status);

-- ============================================================
-- TABLE: photos
-- Description: Stores photo metadata and content
-- ============================================================
CREATE TABLE photos (
    photo_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL,
    photo_url TEXT NOT NULL,
    thumbnail_url TEXT,
    file_size INTEGER,
    width INTEGER,
    height INTEGER,
    mime_type VARCHAR(50) DEFAULT 'image/jpeg',
    caption TEXT,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    FOREIGN KEY (sender_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Indexes for photos table
CREATE INDEX idx_photos_sender ON photos(sender_id, created_at);
CREATE INDEX idx_photos_created ON photos(created_at);
CREATE INDEX idx_photos_deleted ON photos(is_deleted);

-- ============================================================
-- TABLE: photo_recipients
-- Description: Tracks which users received which photos
-- ============================================================
CREATE TABLE photo_recipients (
    recipient_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    photo_id UUID NOT NULL,
    user_id UUID NOT NULL,
    delivered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    viewed_at TIMESTAMP,
    is_viewed BOOLEAN DEFAULT FALSE,
    view_count INTEGER DEFAULT 0,
    last_viewed_at TIMESTAMP,
    is_hidden BOOLEAN DEFAULT FALSE,
    hidden_at TIMESTAMP,
    FOREIGN KEY (photo_id) REFERENCES photos(photo_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT unique_photo_recipient UNIQUE (photo_id, user_id)
);

-- Indexes for photo_recipients table
CREATE INDEX idx_photo_recipients_user ON photo_recipients(user_id, delivered_at);
CREATE INDEX idx_photo_recipients_photo ON photo_recipients(photo_id);
CREATE INDEX idx_photo_recipients_viewed ON photo_recipients(is_viewed, user_id);

-- ============================================================
-- TABLE: reactions
-- Description: Stores emoji reactions to photos
-- ============================================================
CREATE TABLE reactions (
    reaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    photo_id UUID NOT NULL,
    user_id UUID NOT NULL,
    emoji VARCHAR(10) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (photo_id) REFERENCES photos(photo_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT unique_user_photo_reaction UNIQUE (photo_id, user_id)
);

-- Indexes for reactions table
CREATE INDEX idx_reactions_photo ON reactions(photo_id);
CREATE INDEX idx_reactions_user ON reactions(user_id);

-- ============================================================
-- TABLE: notifications
-- Description: Manages push notifications and in-app notifications
-- ============================================================
CREATE TYPE notification_type AS ENUM ('new_photo', 'new_reaction', 'friend_request', 'friend_accepted');

CREATE TABLE notifications (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    type notification_type NOT NULL,
    title VARCHAR(255),
    message TEXT,
    photo_id UUID,
    from_user_id UUID,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sent_at TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (photo_id) REFERENCES photos(photo_id) ON DELETE SET NULL,
    FOREIGN KEY (from_user_id) REFERENCES users(user_id) ON DELETE SET NULL
);

-- Indexes for notifications table
CREATE INDEX idx_notifications_user_unread ON notifications(user_id, is_read, created_at);
CREATE INDEX idx_notifications_created ON notifications(created_at);

-- ============================================================
-- TABLE: device_tokens
-- Description: Stores device tokens for push notifications
-- ============================================================
CREATE TYPE device_platform AS ENUM ('ios', 'android', 'web');

CREATE TABLE device_tokens (
    token_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    device_token TEXT NOT NULL,
    platform device_platform NOT NULL,
    device_name VARCHAR(100),
    os_version VARCHAR(50),
    app_version VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT unique_device_token UNIQUE (device_token)
);

-- Indexes for device_tokens table
CREATE INDEX idx_device_tokens_user ON device_tokens(user_id, is_active);

-- ============================================================
-- TABLE: widget_configurations
-- Description: Stores user widget preferences and settings
-- ============================================================
CREATE TYPE widget_size AS ENUM ('small', 'medium', 'large');

CREATE TABLE widget_configurations (
    config_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    widget_size widget_size DEFAULT 'medium',
    show_sender_name BOOLEAN DEFAULT TRUE,
    show_caption BOOLEAN DEFAULT TRUE,
    animation_enabled BOOLEAN DEFAULT TRUE,
    update_frequency INTEGER DEFAULT 0, -- 0 means instant
    last_updated_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Indexes for widget_configurations table
CREATE INDEX idx_widget_configurations_user ON widget_configurations(user_id);

-- ============================================================
-- TABLE: photo_history
-- Description: Maintains a history log for analytics and debugging
-- ============================================================
CREATE TYPE photo_action AS ENUM ('uploaded', 'delivered', 'viewed', 'reacted', 'deleted', 'hidden');

CREATE TABLE photo_history (
    history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    photo_id UUID NOT NULL,
    user_id UUID NOT NULL,
    action photo_action NOT NULL,
    metadata JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (photo_id) REFERENCES photos(photo_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Indexes for photo_history table
CREATE INDEX idx_photo_history_photo ON photo_history(photo_id, created_at);
CREATE INDEX idx_photo_history_user ON photo_history(user_id, created_at);
CREATE INDEX idx_photo_history_action ON photo_history(action, created_at);

-- ============================================================
-- TABLE: user_sessions
-- Description: Tracks active user sessions for security
-- ============================================================
CREATE TABLE user_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    refresh_token TEXT NOT NULL,
    access_token_hash VARCHAR(255),
    device_info JSONB,
    ip_address INET,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_activity_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_revoked BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Indexes for user_sessions table
CREATE INDEX idx_user_sessions_user ON user_sessions(user_id, is_revoked);
CREATE INDEX idx_user_sessions_expires ON user_sessions(expires_at);
CREATE INDEX idx_user_sessions_refresh_token ON user_sessions(refresh_token);

-- ============================================================
-- TRIGGERS: Auto-update updated_at timestamps
-- ============================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply trigger to users table
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Apply trigger to friendships table
CREATE TRIGGER update_friendships_updated_at 
    BEFORE UPDATE ON friendships 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Apply trigger to device_tokens table
CREATE TRIGGER update_device_tokens_updated_at 
    BEFORE UPDATE ON device_tokens 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Apply trigger to widget_configurations table
CREATE TRIGGER update_widget_configurations_updated_at 
    BEFORE UPDATE ON widget_configurations 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- FUNCTIONS: Helper functions for common operations
-- ============================================================

-- Function to get friends for a user
CREATE OR REPLACE FUNCTION get_user_friends(p_user_id UUID)
RETURNS TABLE (
    friend_id UUID,
    friend_username VARCHAR(50),
    friend_display_name VARCHAR(100),
    friend_profile_photo_url TEXT,
    friendship_status friendship_status,
    friendship_created_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        CASE 
            WHEN f.user_id_1 = p_user_id THEN f.user_id_2
            ELSE f.user_id_1
        END as friend_id,
        u.username,
        u.display_name,
        u.profile_photo_url,
        f.status::public.friendship_status,
        f.created_at
    FROM friendships f
    JOIN users u ON (
        CASE 
            WHEN f.user_id_1 = p_user_id THEN u.user_id = f.user_id_2
            ELSE u.user_id = f.user_id_1
        END
    )
    WHERE (f.user_id_1 = p_user_id OR f.user_id_2 = p_user_id)
    AND f.status = 'accepted'
    ORDER BY f.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get recent photos for a user
CREATE OR REPLACE FUNCTION get_user_recent_photos(p_user_id UUID, p_limit INTEGER DEFAULT 50)
RETURNS TABLE (
    photo_id UUID,
    sender_id UUID,
    sender_username VARCHAR(50),
    sender_display_name VARCHAR(100),
    photo_url TEXT,
    thumbnail_url TEXT,
    caption TEXT,
    created_at TIMESTAMP,
    is_viewed BOOLEAN,
    viewed_at TIMESTAMP,
    reaction_emoji VARCHAR(10)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.photo_id,
        p.sender_id,
        u.username,
        u.display_name,
        p.photo_url,
        p.thumbnail_url,
        p.caption,
        p.created_at,
        pr.is_viewed,
        pr.viewed_at,
        r.emoji as reaction_emoji
    FROM photos p
    JOIN photo_recipients pr ON p.photo_id = pr.photo_id
    JOIN users u ON p.sender_id = u.user_id
    LEFT JOIN reactions r ON p.photo_id = r.photo_id AND r.user_id = p_user_id
    WHERE pr.user_id = p_user_id
    AND p.is_deleted = FALSE
    AND pr.is_hidden = FALSE
    ORDER BY pr.delivered_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function to get unread notification count
CREATE OR REPLACE FUNCTION get_unread_notification_count(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
    unread_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO unread_count
    FROM notifications
    WHERE user_id = p_user_id
    AND is_read = FALSE;
    
    RETURN unread_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- VIEWS: Common queries as views for easier access
-- ============================================================

-- View for active friendships with user details
CREATE OR REPLACE VIEW active_friendships_view AS
SELECT 
    f.friendship_id,
    f.user_id_1,
    u1.username as user_1_username,
    u1.display_name as user_1_display_name,
    f.user_id_2,
    u2.username as user_2_username,
    u2.display_name as user_2_display_name,
    f.status,
    f.created_at,
    f.accepted_at
FROM friendships f
JOIN users u1 ON f.user_id_1 = u1.user_id
JOIN users u2 ON f.user_id_2 = u2.user_id
WHERE f.status = 'accepted';

-- View for recent photos with sender details
CREATE OR REPLACE VIEW recent_photos_view AS
SELECT 
    p.photo_id,
    p.sender_id,
    u.username as sender_username,
    u.display_name as sender_display_name,
    u.profile_photo_url as sender_profile_photo,
    p.photo_url,
    p.thumbnail_url,
    p.caption,
    p.created_at,
    p.file_size,
    p.width,
    p.height,
    COUNT(DISTINCT pr.user_id) as recipient_count,
    COUNT(DISTINCT r.reaction_id) as reaction_count
FROM photos p
JOIN users u ON p.sender_id = u.user_id
LEFT JOIN photo_recipients pr ON p.photo_id = pr.photo_id
LEFT JOIN reactions r ON p.photo_id = r.photo_id
WHERE p.is_deleted = FALSE
GROUP BY p.photo_id, u.user_id
ORDER BY p.created_at DESC;

-- ============================================================
-- INITIAL DATA: Optional seed data for testing
-- ============================================================

-- Note: Uncomment the following lines to insert sample data

-- INSERT INTO users (username, email, password_hash, display_name) VALUES
-- ('john_doe', 'john@example.com', '$2b$10$...', 'John Doe'),
-- ('jane_smith', 'jane@example.com', '$2b$10$...', 'Jane Smith'),
-- ('bob_wilson', 'bob@example.com', '$2b$10$...', 'Bob Wilson');

-- ============================================================
-- GRANTS: Set appropriate permissions (adjust as needed)
-- ============================================================

-- Example: Grant permissions to application user
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO locket_app_user;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO locket_app_user;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO locket_app_user;

-- ============================================================
-- COMPLETION MESSAGE
-- ============================================================

DO $$
BEGIN
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Locket Database Setup Complete!';
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Tables created: 10';
    RAISE NOTICE 'Types created: 5';
    RAISE NOTICE 'Functions created: 3';
    RAISE NOTICE 'Views created: 2';
    RAISE NOTICE 'Triggers created: 4';
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '1. Review and adjust table permissions';
    RAISE NOTICE '2. Configure connection pooling';
    RAISE NOTICE '3. Set up backup schedules';
    RAISE NOTICE '4. Monitor query performance';
    RAISE NOTICE '================================================';
END $$;
