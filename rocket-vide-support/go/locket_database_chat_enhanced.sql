-- ============================================================
-- Locket App Database Setup Script for PostgreSQL
-- ENHANCED VERSION WITH CHAT FEATURES
-- ============================================================
-- Description: Complete database schema for a Locket-like
--              real-time photo sharing + chat application
-- Database: PostgreSQL 12+
-- Features: P2P Chat, Group Chat, Image Attachments, Reactions
-- Version: 2.0
-- Created: 2025-11-16
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- For text search

-- Set timezone to UTC
SET timezone = 'UTC';

-- ============================================================
-- EXISTING TABLES (From Original Schema)
-- ============================================================
-- Note: Keep all existing tables from original schema
-- (users, friendships, photos, photo_recipients, reactions, 
--  notifications, device_tokens, widget_configurations, 
--  photo_history, user_sessions)

-- TABLE: users (Enhanced with chat fields)
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone_number VARCHAR(20) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    display_name VARCHAR(100),
    profile_photo_url TEXT,
    bio TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_seen_at TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    is_online BOOLEAN DEFAULT FALSE,
    notification_enabled BOOLEAN DEFAULT TRUE,
    widget_enabled BOOLEAN DEFAULT TRUE,
    chat_notification_enabled BOOLEAN DEFAULT TRUE,
    show_online_status BOOLEAN DEFAULT TRUE,
    show_read_receipts BOOLEAN DEFAULT TRUE
);

-- Indexes for users table
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_phone ON users(phone_number);
CREATE INDEX idx_users_online ON users(is_online) WHERE is_online = TRUE;

-- ============================================================
-- TABLE: friendships (Keep existing)
-- ============================================================
CREATE TYPE friendship_status AS ENUM ('pending', 'accepted', 'blocked');

CREATE TABLE IF NOT EXISTS friendships (
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

CREATE INDEX idx_friendships_user_1 ON friendships(user_id_1, status);
CREATE INDEX idx_friendships_user_2 ON friendships(user_id_2, status);

-- ============================================================
-- NEW CHAT TABLES
-- ============================================================

-- TABLE: conversations
-- Description: Stores chat conversations (P2P and group)
-- ============================================================
CREATE TYPE conversation_type AS ENUM ('direct', 'group');

CREATE TABLE conversations (
    conversation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type conversation_type NOT NULL DEFAULT 'direct',
    name VARCHAR(100), -- For group chats
    description TEXT, -- For group chats
    photo_url TEXT, -- Group avatar
    created_by UUID NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_message_at TIMESTAMP,
    last_message_preview TEXT, -- Denormalized for quick list view
    is_archived BOOLEAN DEFAULT FALSE,
    archived_at TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(user_id) ON DELETE SET NULL
);

-- Indexes for conversations table
CREATE INDEX idx_conversations_type ON conversations(type);
CREATE INDEX idx_conversations_last_message ON conversations(last_message_at DESC NULLS LAST);
CREATE INDEX idx_conversations_created_by ON conversations(created_by);

-- ============================================================
-- TABLE: conversation_participants
-- Description: Maps users to conversations with metadata
-- ============================================================
CREATE TYPE participant_role AS ENUM ('owner', 'admin', 'member');

CREATE TABLE conversation_participants (
    participant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL,
    user_id UUID NOT NULL,
    role participant_role DEFAULT 'member',
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    left_at TIMESTAMP,
    is_muted BOOLEAN DEFAULT FALSE,
    muted_until TIMESTAMP,
    last_read_message_id UUID,
    last_read_at TIMESTAMP,
    unread_count INTEGER DEFAULT 0,
    is_pinned BOOLEAN DEFAULT FALSE,
    pinned_at TIMESTAMP,
    nickname VARCHAR(100), -- Custom name for this conversation
    FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT unique_conversation_participant UNIQUE (conversation_id, user_id)
);

-- Indexes for conversation_participants table
CREATE INDEX idx_conv_participants_user ON conversation_participants(user_id, left_at);
CREATE INDEX idx_conv_participants_conversation ON conversation_participants(conversation_id, left_at);
CREATE INDEX idx_conv_participants_unread ON conversation_participants(user_id, unread_count) WHERE unread_count > 0;
CREATE INDEX idx_conv_participants_pinned ON conversation_participants(user_id, is_pinned, last_read_at);

-- ============================================================
-- TABLE: messages
-- Description: Stores all chat messages
-- ============================================================
CREATE TYPE message_type AS ENUM ('text', 'image', 'video', 'audio', 'file', 'system', 'location');
CREATE TYPE message_status AS ENUM ('sending', 'sent', 'delivered', 'failed');

CREATE TABLE messages (
    message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL,
    sender_id UUID NOT NULL,
    message_type message_type NOT NULL DEFAULT 'text',
    content TEXT, -- Text content or caption
    metadata JSONB, -- Flexible storage for mentions, links, location data, etc.
    reply_to_message_id UUID, -- For threaded replies
    forwarded_from_message_id UUID, -- For forwarded messages
    status message_status DEFAULT 'sending',
    is_edited BOOLEAN DEFAULT FALSE,
    edited_at TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP,
    deleted_for_everyone BOOLEAN DEFAULT FALSE, -- vs deleted for self only
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    server_received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP, -- For ephemeral messages
    FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE,
    FOREIGN KEY (sender_id) REFERENCES users(user_id) ON DELETE SET NULL,
    FOREIGN KEY (reply_to_message_id) REFERENCES messages(message_id) ON DELETE SET NULL,
    FOREIGN KEY (forwarded_from_message_id) REFERENCES messages(message_id) ON DELETE SET NULL
);

-- Indexes for messages table
CREATE INDEX idx_messages_conversation_time ON messages(conversation_id, created_at DESC) 
    WHERE is_deleted = FALSE;
CREATE INDEX idx_messages_sender ON messages(sender_id, created_at DESC);
CREATE INDEX idx_messages_reply_to ON messages(reply_to_message_id) WHERE reply_to_message_id IS NOT NULL;
CREATE INDEX idx_messages_content_search ON messages USING gin(to_tsvector('english', content)) 
    WHERE message_type = 'text' AND is_deleted = FALSE;
CREATE INDEX idx_messages_created_at ON messages(created_at DESC);

-- Partial index for system messages
CREATE INDEX idx_messages_system ON messages(conversation_id, created_at) 
    WHERE message_type = 'system';

-- ============================================================
-- TABLE: message_attachments
-- Description: Stores file attachments for messages
-- ============================================================
CREATE TYPE attachment_type AS ENUM ('image', 'video', 'audio', 'document', 'other');
CREATE TYPE upload_status AS ENUM ('uploading', 'completed', 'failed', 'processing');

CREATE TABLE message_attachments (
    attachment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL,
    attachment_type attachment_type NOT NULL,
    file_url TEXT NOT NULL,
    thumbnail_url TEXT,
    preview_url TEXT, -- For documents
    file_name VARCHAR(255),
    file_size BIGINT, -- In bytes
    mime_type VARCHAR(100),
    duration INTEGER, -- For audio/video in seconds
    width INTEGER, -- For images/video
    height INTEGER, -- For images/video
    upload_status upload_status DEFAULT 'uploading',
    uploaded_at TIMESTAMP,
    metadata JSONB, -- Additional file metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (message_id) REFERENCES messages(message_id) ON DELETE CASCADE
);

-- Indexes for message_attachments table
CREATE INDEX idx_attachments_message ON message_attachments(message_id);
CREATE INDEX idx_attachments_type ON message_attachments(attachment_type, created_at DESC);
CREATE INDEX idx_attachments_status ON message_attachments(upload_status) WHERE upload_status != 'completed';

-- ============================================================
-- TABLE: message_receipts
-- Description: Tracks delivery and read status per recipient
-- ============================================================
CREATE TYPE receipt_status AS ENUM ('sent', 'delivered', 'read', 'failed');

CREATE TABLE message_receipts (
    receipt_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL,
    user_id UUID NOT NULL,
    status receipt_status NOT NULL DEFAULT 'sent',
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    delivered_at TIMESTAMP,
    read_at TIMESTAMP,
    failed_reason TEXT,
    FOREIGN KEY (message_id) REFERENCES messages(message_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT unique_message_receipt UNIQUE (message_id, user_id)
);

-- Indexes for message_receipts table
CREATE INDEX idx_receipts_message ON message_receipts(message_id, status);
CREATE INDEX idx_receipts_user_unread ON message_receipts(user_id, read_at) 
    WHERE read_at IS NULL;
CREATE INDEX idx_receipts_status ON message_receipts(status, delivered_at);

-- ============================================================
-- TABLE: message_reactions
-- Description: Emoji reactions to messages (like WhatsApp/Messenger)
-- ============================================================
CREATE TABLE message_reactions (
    reaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL,
    user_id UUID NOT NULL,
    emoji VARCHAR(10) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (message_id) REFERENCES messages(message_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT unique_message_user_reaction UNIQUE (message_id, user_id, emoji)
);

-- Indexes for message_reactions table
CREATE INDEX idx_message_reactions_message ON message_reactions(message_id);
CREATE INDEX idx_message_reactions_user ON message_reactions(user_id, created_at DESC);

-- ============================================================
-- TABLE: typing_indicators
-- Description: Tracks who is typing in real-time
-- ============================================================
CREATE TABLE typing_indicators (
    indicator_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL,
    user_id UUID NOT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL, -- Auto-expire after 10 seconds
    FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT unique_typing_indicator UNIQUE (conversation_id, user_id)
);

-- Indexes for typing_indicators table
CREATE INDEX idx_typing_conversation ON typing_indicators(conversation_id, expires_at);

-- Auto-cleanup expired typing indicators
CREATE INDEX idx_typing_expires ON typing_indicators(expires_at) 
    WHERE expires_at < CURRENT_TIMESTAMP;

-- ============================================================
-- TABLE: user_blocks
-- Description: Users can block each other from messaging
-- ============================================================
CREATE TABLE user_blocks (
    block_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id UUID NOT NULL,
    blocked_id UUID NOT NULL,
    reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (blocker_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (blocked_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT unique_user_block UNIQUE (blocker_id, blocked_id),
    CONSTRAINT no_self_block CHECK (blocker_id != blocked_id)
);

-- Indexes for user_blocks table
CREATE INDEX idx_blocks_blocker ON user_blocks(blocker_id);
CREATE INDEX idx_blocks_blocked ON user_blocks(blocked_id);

-- ============================================================
-- TABLE: message_mentions
-- Description: Track @mentions in messages for notifications
-- ============================================================
CREATE TABLE message_mentions (
    mention_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL,
    mentioned_user_id UUID NOT NULL,
    mentioned_by_user_id UUID NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (message_id) REFERENCES messages(message_id) ON DELETE CASCADE,
    FOREIGN KEY (mentioned_user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (mentioned_by_user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT unique_message_mention UNIQUE (message_id, mentioned_user_id)
);

-- Indexes for message_mentions table
CREATE INDEX idx_mentions_user_unread ON message_mentions(mentioned_user_id, is_read) 
    WHERE is_read = FALSE;
CREATE INDEX idx_mentions_message ON message_mentions(message_id);

-- ============================================================
-- TABLE: conversation_settings
-- Description: Advanced settings per conversation (group-level)
-- ============================================================
CREATE TABLE conversation_settings (
    setting_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL UNIQUE,
    only_admins_can_send BOOLEAN DEFAULT FALSE,
    only_admins_can_add_members BOOLEAN DEFAULT FALSE,
    only_admins_can_edit_info BOOLEAN DEFAULT FALSE,
    disappearing_messages_enabled BOOLEAN DEFAULT FALSE,
    disappearing_messages_duration INTEGER, -- In seconds
    max_participants INTEGER DEFAULT 256,
    allow_member_add BOOLEAN DEFAULT TRUE,
    require_admin_approval BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE
);

-- ============================================================
-- TABLE: message_reports
-- Description: Allow users to report inappropriate messages
-- ============================================================
CREATE TYPE report_status AS ENUM ('pending', 'reviewed', 'action_taken', 'dismissed');
CREATE TYPE report_reason AS ENUM ('spam', 'harassment', 'inappropriate_content', 'violence', 'other');

CREATE TABLE message_reports (
    report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL,
    reported_by UUID NOT NULL,
    reason report_reason NOT NULL,
    description TEXT,
    status report_status DEFAULT 'pending',
    reviewed_by UUID,
    reviewed_at TIMESTAMP,
    action_taken TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (message_id) REFERENCES messages(message_id) ON DELETE CASCADE,
    FOREIGN KEY (reported_by) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (reviewed_by) REFERENCES users(user_id) ON DELETE SET NULL
);

-- Indexes for message_reports table
CREATE INDEX idx_reports_status ON message_reports(status, created_at);
CREATE INDEX idx_reports_message ON message_reports(message_id);
CREATE INDEX idx_reports_reporter ON message_reports(reported_by);

-- ============================================================
-- ENHANCED NOTIFICATIONS TABLE
-- ============================================================
DROP TYPE IF EXISTS notification_type CASCADE;
CREATE TYPE notification_type AS ENUM (
    'new_photo', 
    'new_reaction', 
    'friend_request', 
    'friend_accepted',
    'new_message',
    'message_reaction',
    'mention',
    'group_invite',
    'group_added',
    'group_removed'
);

CREATE TABLE IF NOT EXISTS notifications (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    type notification_type NOT NULL,
    title VARCHAR(255),
    message TEXT,
    photo_id UUID,
    message_id UUID,
    conversation_id UUID,
    from_user_id UUID,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sent_at TIMESTAMP,
    data JSONB, -- Additional notification data
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (from_user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE
);

-- Indexes for notifications table
CREATE INDEX idx_notifications_user_unread ON notifications(user_id, is_read, created_at DESC);
CREATE INDEX idx_notifications_type ON notifications(type, created_at);
CREATE INDEX idx_notifications_conversation ON notifications(conversation_id);

-- ============================================================
-- TABLE: device_tokens (Enhanced for chat)
-- ============================================================
CREATE TYPE device_platform AS ENUM ('ios', 'android', 'web', 'desktop');

CREATE TABLE IF NOT EXISTS device_tokens (
    token_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    device_token TEXT NOT NULL,
    platform device_platform NOT NULL,
    device_name VARCHAR(100),
    os_version VARCHAR(50),
    app_version VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    voip_token TEXT, -- For iOS VoIP push
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT unique_device_token UNIQUE (device_token)
);

CREATE INDEX idx_device_tokens_user ON device_tokens(user_id, is_active);
CREATE INDEX idx_device_tokens_platform ON device_tokens(platform, is_active);

-- ============================================================
-- MATERIALIZED VIEW: Conversation List (Optimized for performance)
-- ============================================================
CREATE MATERIALIZED VIEW conversation_list_view AS
SELECT 
    c.conversation_id,
    c.type,
    c.name,
    c.photo_url,
    c.last_message_at,
    c.last_message_preview,
    cp.user_id,
    cp.is_muted,
    cp.is_pinned,
    cp.unread_count,
    cp.last_read_at,
    cp.nickname,
    -- For direct chats, get the other user's info
    CASE 
        WHEN c.type = 'direct' THEN (
            SELECT json_build_object(
                'user_id', u.user_id,
                'username', u.username,
                'display_name', u.display_name,
                'profile_photo_url', u.profile_photo_url,
                'is_online', u.is_online,
                'last_seen_at', u.last_seen_at
            )
            FROM conversation_participants cp2
            JOIN users u ON cp2.user_id = u.user_id
            WHERE cp2.conversation_id = c.conversation_id
            AND cp2.user_id != cp.user_id
            AND cp2.left_at IS NULL
            LIMIT 1
        )
        ELSE NULL
    END as other_user_info,
    -- Participant count for groups
    (
        SELECT COUNT(*)
        FROM conversation_participants cp3
        WHERE cp3.conversation_id = c.conversation_id
        AND cp3.left_at IS NULL
    ) as participant_count
FROM conversations c
JOIN conversation_participants cp ON c.conversation_id = cp.conversation_id
WHERE cp.left_at IS NULL
AND c.is_archived = FALSE;

-- Index on materialized view
CREATE INDEX idx_conv_list_view_user ON conversation_list_view(user_id, last_message_at DESC);
CREATE INDEX idx_conv_list_view_unread ON conversation_list_view(user_id, unread_count) 
    WHERE unread_count > 0;

-- ============================================================
-- TRIGGERS: Auto-update timestamps and maintain data integrity
-- ============================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_conversations_updated_at 
    BEFORE UPDATE ON conversations 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_device_tokens_updated_at 
    BEFORE UPDATE ON device_tokens 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_conversation_settings_updated_at 
    BEFORE UPDATE ON conversation_settings 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Function to update conversation last_message_at when new message arrives
CREATE OR REPLACE FUNCTION update_conversation_last_message()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE conversations
    SET 
        last_message_at = NEW.created_at,
        last_message_preview = LEFT(COALESCE(NEW.content, '[' || NEW.message_type || ']'), 100),
        updated_at = CURRENT_TIMESTAMP
    WHERE conversation_id = NEW.conversation_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_conversation_last_message
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION update_conversation_last_message();

-- Function to update unread count for participants
CREATE OR REPLACE FUNCTION update_unread_count()
RETURNS TRIGGER AS $$
BEGIN
    -- Increment unread count for all participants except sender
    UPDATE conversation_participants
    SET unread_count = unread_count + 1
    WHERE conversation_id = NEW.conversation_id
    AND user_id != NEW.sender_id
    AND left_at IS NULL;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_unread_count
    AFTER INSERT ON messages
    FOR EACH ROW
    WHEN (NEW.message_type != 'system')
    EXECUTE FUNCTION update_unread_count();

-- Function to auto-delete expired typing indicators
CREATE OR REPLACE FUNCTION cleanup_expired_typing_indicators()
RETURNS void AS $$
BEGIN
    DELETE FROM typing_indicators
    WHERE expires_at < CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Function to update user's online status
CREATE OR REPLACE FUNCTION update_user_last_seen()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_seen_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- HELPER FUNCTIONS FOR COMMON OPERATIONS
-- ============================================================

-- Function: Get or create direct conversation between two users
CREATE OR REPLACE FUNCTION get_or_create_direct_conversation(
    p_user_id_1 UUID,
    p_user_id_2 UUID
)
RETURNS UUID AS $$
DECLARE
    v_conversation_id UUID;
BEGIN
    -- Check if conversation already exists
    SELECT c.conversation_id INTO v_conversation_id
    FROM conversations c
    JOIN conversation_participants cp1 ON c.conversation_id = cp1.conversation_id
    JOIN conversation_participants cp2 ON c.conversation_id = cp2.conversation_id
    WHERE c.type = 'direct'
    AND cp1.user_id = p_user_id_1
    AND cp2.user_id = p_user_id_2
    AND cp1.left_at IS NULL
    AND cp2.left_at IS NULL
    LIMIT 1;
    
    -- If not exists, create new conversation
    IF v_conversation_id IS NULL THEN
        INSERT INTO conversations (type, created_by)
        VALUES ('direct', p_user_id_1)
        RETURNING conversation_id INTO v_conversation_id;
        
        -- Add both participants
        INSERT INTO conversation_participants (conversation_id, user_id, role)
        VALUES 
            (v_conversation_id, p_user_id_1, 'member'),
            (v_conversation_id, p_user_id_2, 'member');
    END IF;
    
    RETURN v_conversation_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Get conversation with participants
CREATE OR REPLACE FUNCTION get_conversation_details(p_conversation_id UUID, p_user_id UUID)
RETURNS TABLE (
    conversation_id UUID,
    type conversation_type,
    name VARCHAR,
    photo_url TEXT,
    created_at TIMESTAMP,
    last_message_at TIMESTAMP,
    participant_count BIGINT,
    is_muted BOOLEAN,
    is_pinned BOOLEAN,
    unread_count INTEGER,
    participants JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.conversation_id,
        c.type,
        c.name,
        c.photo_url,
        c.created_at,
        c.last_message_at,
        COUNT(DISTINCT cp.participant_id) as participant_count,
        cp_user.is_muted,
        cp_user.is_pinned,
        cp_user.unread_count,
        json_agg(
            json_build_object(
                'user_id', u.user_id,
                'username', u.username,
                'display_name', u.display_name,
                'profile_photo_url', u.profile_photo_url,
                'role', cp.role,
                'is_online', u.is_online,
                'last_seen_at', u.last_seen_at
            )
        ) as participants
    FROM conversations c
    JOIN conversation_participants cp_user ON c.conversation_id = cp_user.conversation_id 
        AND cp_user.user_id = p_user_id
    JOIN conversation_participants cp ON c.conversation_id = cp.conversation_id 
        AND cp.left_at IS NULL
    JOIN users u ON cp.user_id = u.user_id
    WHERE c.conversation_id = p_conversation_id
    GROUP BY c.conversation_id, cp_user.participant_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Get messages with pagination (cursor-based)
CREATE OR REPLACE FUNCTION get_messages(
    p_conversation_id UUID,
    p_user_id UUID,
    p_before_id UUID DEFAULT NULL,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    message_id UUID,
    sender_id UUID,
    sender_username VARCHAR,
    sender_display_name VARCHAR,
    sender_photo_url TEXT,
    message_type message_type,
    content TEXT,
    created_at TIMESTAMP,
    is_edited BOOLEAN,
    reply_to JSONB,
    attachments JSONB,
    reactions JSONB,
    receipt_status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.message_id,
        m.sender_id,
        u.username as sender_username,
        u.display_name as sender_display_name,
        u.profile_photo_url as sender_photo_url,
        m.message_type,
        m.content,
        m.created_at,
        m.is_edited,
        -- Reply info
        CASE 
            WHEN m.reply_to_message_id IS NOT NULL THEN
                json_build_object(
                    'message_id', rm.message_id,
                    'sender_username', ru.username,
                    'content', LEFT(rm.content, 100)
                )
            ELSE NULL
        END as reply_to,
        -- Attachments
        (
            SELECT json_agg(
                json_build_object(
                    'attachment_id', ma.attachment_id,
                    'type', ma.attachment_type,
                    'url', ma.file_url,
                    'thumbnail_url', ma.thumbnail_url,
                    'file_name', ma.file_name,
                    'file_size', ma.file_size,
                    'mime_type', ma.mime_type,
                    'width', ma.width,
                    'height', ma.height,
                    'duration', ma.duration
                )
            )
            FROM message_attachments ma
            WHERE ma.message_id = m.message_id
            AND ma.upload_status = 'completed'
        ) as attachments,
        -- Reactions
        (
            SELECT json_agg(
                json_build_object(
                    'emoji', mr.emoji,
                    'user_id', mr.user_id,
                    'username', u_react.username
                )
            )
            FROM message_reactions mr
            JOIN users u_react ON mr.user_id = u_react.user_id
            WHERE mr.message_id = m.message_id
        ) as reactions,
        -- Receipt status for this user
        (
            SELECT mrec.status::TEXT
            FROM message_receipts mrec
            WHERE mrec.message_id = m.message_id
            AND mrec.user_id = p_user_id
            LIMIT 1
        ) as receipt_status
    FROM messages m
    JOIN users u ON m.sender_id = u.user_id
    LEFT JOIN messages rm ON m.reply_to_message_id = rm.message_id
    LEFT JOIN users ru ON rm.sender_id = ru.user_id
    WHERE m.conversation_id = p_conversation_id
    AND m.is_deleted = FALSE
    AND (p_before_id IS NULL OR m.created_at < (
        SELECT created_at FROM messages WHERE message_id = p_before_id
    ))
    ORDER BY m.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function: Mark messages as read
CREATE OR REPLACE FUNCTION mark_messages_as_read(
    p_conversation_id UUID,
    p_user_id UUID,
    p_up_to_message_id UUID DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    v_updated_count INTEGER;
BEGIN
    -- Update message receipts
    UPDATE message_receipts mr
    SET 
        status = 'read',
        read_at = CURRENT_TIMESTAMP
    FROM messages m
    WHERE mr.message_id = m.message_id
    AND m.conversation_id = p_conversation_id
    AND mr.user_id = p_user_id
    AND mr.read_at IS NULL
    AND (p_up_to_message_id IS NULL OR m.created_at <= (
        SELECT created_at FROM messages WHERE message_id = p_up_to_message_id
    ));
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    
    -- Update conversation participant unread count
    UPDATE conversation_participants
    SET 
        unread_count = 0,
        last_read_at = CURRENT_TIMESTAMP,
        last_read_message_id = COALESCE(p_up_to_message_id, last_read_message_id)
    WHERE conversation_id = p_conversation_id
    AND user_id = p_user_id;
    
    RETURN v_updated_count;
END;
$$ LANGUAGE plpgsql;

-- Function: Get unread message count for user
CREATE OR REPLACE FUNCTION get_total_unread_count(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
    v_total_unread INTEGER;
BEGIN
    SELECT COALESCE(SUM(unread_count), 0) INTO v_total_unread
    FROM conversation_participants
    WHERE user_id = p_user_id
    AND left_at IS NULL;
    
    RETURN v_total_unread;
END;
$$ LANGUAGE plpgsql;

-- Function: Search messages across conversations
CREATE OR REPLACE FUNCTION search_messages(
    p_user_id UUID,
    p_query TEXT,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    message_id UUID,
    conversation_id UUID,
    conversation_name TEXT,
    sender_username VARCHAR,
    content TEXT,
    created_at TIMESTAMP,
    rank REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.message_id,
        m.conversation_id,
        COALESCE(c.name, 'Direct Message') as conversation_name,
        u.username as sender_username,
        m.content,
        m.created_at,
        ts_rank(to_tsvector('english', m.content), plainto_tsquery('english', p_query)) as rank
    FROM messages m
    JOIN conversations c ON m.conversation_id = c.conversation_id
    JOIN conversation_participants cp ON c.conversation_id = cp.conversation_id
    JOIN users u ON m.sender_id = u.user_id
    WHERE cp.user_id = p_user_id
    AND cp.left_at IS NULL
    AND m.is_deleted = FALSE
    AND m.message_type = 'text'
    AND to_tsvector('english', m.content) @@ plainto_tsquery('english', p_query)
    ORDER BY rank DESC, m.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function: Check if user is blocked
CREATE OR REPLACE FUNCTION is_user_blocked(
    p_user_id UUID,
    p_target_user_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_is_blocked BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM user_blocks
        WHERE (blocker_id = p_user_id AND blocked_id = p_target_user_id)
        OR (blocker_id = p_target_user_id AND blocked_id = p_user_id)
    ) INTO v_is_blocked;
    
    RETURN v_is_blocked;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- SCHEDULED JOBS (To be run by external scheduler like pg_cron)
-- ============================================================

-- Cleanup old typing indicators (run every minute)
CREATE OR REPLACE FUNCTION job_cleanup_typing_indicators()
RETURNS void AS $$
BEGIN
    DELETE FROM typing_indicators
    WHERE expires_at < CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Cleanup expired ephemeral messages (run every hour)
CREATE OR REPLACE FUNCTION job_cleanup_ephemeral_messages()
RETURNS void AS $$
BEGIN
    UPDATE messages
    SET 
        is_deleted = TRUE,
        deleted_at = CURRENT_TIMESTAMP,
        content = NULL,
        metadata = NULL
    WHERE expires_at IS NOT NULL
    AND expires_at < CURRENT_TIMESTAMP
    AND is_deleted = FALSE;
END;
$$ LANGUAGE plpgsql;

-- Update user online status based on last activity (run every 5 minutes)
CREATE OR REPLACE FUNCTION job_update_online_status()
RETURNS void AS $$
BEGIN
    UPDATE users
    SET is_online = FALSE
    WHERE is_online = TRUE
    AND last_seen_at < CURRENT_TIMESTAMP - INTERVAL '5 minutes';
END;
$$ LANGUAGE plpgsql;

-- Refresh materialized view (run every 5 minutes or on-demand)
CREATE OR REPLACE FUNCTION job_refresh_conversation_list()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY conversation_list_view;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- SAMPLE DATA FOR TESTING (Uncomment to use)
-- ============================================================

-- INSERT INTO users (username, email, password_hash, display_name) VALUES
-- ('alice', 'alice@example.com', '$2b$10$...', 'Alice Johnson'),
-- ('bob', 'bob@example.com', '$2b$10$...', 'Bob Smith'),
-- ('charlie', 'charlie@example.com', '$2b$10$...', 'Charlie Brown');

-- ============================================================
-- PERMISSIONS (Adjust for your application user)
-- ============================================================

-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO rocket_app_user;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO rocket_app_user;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO rocket_app_user;

-- ============================================================
-- COMPLETION MESSAGE
-- ============================================================

DO $$
BEGIN
    RAISE NOTICE '========================================================';
    RAISE NOTICE 'Rocket/Locket Database Setup Complete (Enhanced)!';
    RAISE NOTICE '========================================================';
    RAISE NOTICE 'New Chat Tables: 12';
    RAISE NOTICE 'Helper Functions: 10';
    RAISE NOTICE 'Scheduled Jobs: 4';
    RAISE NOTICE 'Materialized Views: 1';
    RAISE NOTICE '========================================================';
    RAISE NOTICE 'Features Enabled:';
    RAISE NOTICE '✓ P2P Direct Messaging';
    RAISE NOTICE '✓ Group Chat';
    RAISE NOTICE '✓ Image/File Attachments';
    RAISE NOTICE '✓ Message Reactions';
    RAISE NOTICE '✓ Read Receipts';
    RAISE NOTICE '✓ Typing Indicators';
    RAISE NOTICE '✓ Message Threading';
    RAISE NOTICE '✓ User Mentions';
    RAISE NOTICE '✓ Message Search';
    RAISE NOTICE '✓ User Blocking';
    RAISE NOTICE '✓ Ephemeral Messages';
    RAISE NOTICE '========================================================';
    RAISE NOTICE 'Next Steps:';
    RAISE NOTICE '1. Set up pg_cron for scheduled jobs';
    RAISE NOTICE '2. Configure S3/storage for attachments';
    RAISE NOTICE '3. Implement WebSocket server';
    RAISE NOTICE '4. Set up Redis for caching';
    RAISE NOTICE '5. Configure push notifications';
    RAISE NOTICE '6. Implement rate limiting';
    RAISE NOTICE '7. Add monitoring and logging';
    RAISE NOTICE '========================================================';
END $$;
