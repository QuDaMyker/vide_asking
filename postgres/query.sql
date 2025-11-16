-- name: GetPhotoByID :one
-- Get a single photo by ID (without reactions)
SELECT 
    id,
    sender_id,
    photo_url,
    thumbnail_url,
    file_size,
    width,
    height,
    mime_type,
    caption,
    is_deleted,
    deleted_at,
    created_at,
    expires_at,
    key
FROM photos
WHERE id = $1 AND is_deleted = false;

-- name: GetReactionsByPhotoID :many
-- Get all reactions for a specific photo
SELECT 
    id,
    photo_id,
    user_id,
    emoji,
    created_at
FROM reactions
WHERE photo_id = $1
ORDER BY created_at ASC;

-- name: GetPhotosByUserID :many
-- Get all photos by a user (without reactions)
SELECT 
    id,
    sender_id,
    photo_url,
    thumbnail_url,
    file_size,
    width,
    height,
    mime_type,
    caption,
    is_deleted,
    deleted_at,
    created_at,
    expires_at,
    key
FROM photos
WHERE sender_id = $1 AND is_deleted = false
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;

-- name: GetPhotoWithReactionsOptimized :many
-- OPTIMIZED: Get photo with reactions in a single query using LEFT JOIN
-- This returns one row per reaction (or one row with nulls if no reactions)
SELECT 
    p.id as photo_id,
    p.sender_id,
    p.photo_url,
    p.thumbnail_url,
    p.file_size,
    p.width,
    p.height,
    p.mime_type,
    p.caption,
    p.is_deleted,
    p.deleted_at,
    p.created_at as photo_created_at,
    p.expires_at,
    p.key,
    r.id as reaction_id,
    r.user_id as reaction_user_id,
    r.emoji as reaction_emoji,
    r.created_at as reaction_created_at
FROM photos p
LEFT JOIN reactions r ON p.id = r.photo_id
WHERE p.id = $1 AND p.is_deleted = false
ORDER BY r.created_at ASC;

-- name: GetPhotosWithReactionsByUserID :many
-- OPTIMIZED: Get all photos by user with their reactions in a single query
-- This uses LEFT JOIN to include photos even if they have no reactions
SELECT 
    p.id as photo_id,
    p.sender_id,
    p.photo_url,
    p.thumbnail_url,
    p.file_size,
    p.width,
    p.height,
    p.mime_type,
    p.caption,
    p.is_deleted,
    p.deleted_at,
    p.created_at as photo_created_at,
    p.expires_at,
    p.key,
    r.id as reaction_id,
    r.user_id as reaction_user_id,
    r.emoji as reaction_emoji,
    r.created_at as reaction_created_at
FROM photos p
LEFT JOIN reactions r ON p.id = r.photo_id
WHERE p.sender_id = $1 AND p.is_deleted = false
ORDER BY p.created_at DESC, r.created_at ASC
LIMIT $2 OFFSET $3;

-- name: GetPhotosWithReactionsSimple :many
-- SIMPLIFIED: Get photos with reactions returning only id, photo_url, reaction_id, and emoji
-- Returns minimal data for lightweight API responses
SELECT 
    p.id as photo_id,
    p.photo_url,
    r.id as reaction_id,
    r.emoji as reaction_emoji
FROM photos p
LEFT JOIN reactions r ON p.id = r.photo_id
WHERE p.sender_id = $1 AND p.is_deleted = false
ORDER BY p.created_at DESC, r.created_at ASC
LIMIT $2 OFFSET $3;

-- name: GetPhotosWithReactionsComplete :many
-- COMPLETE: Single query to get all photo fields with full reaction details
-- Returns all photo metadata with complete reaction information
SELECT 
    p.id as photo_id,
    p.sender_id,
    p.photo_url,
    p.thumbnail_url,
    p.file_size,
    p.width,
    p.height,
    p.mime_type,
    p.caption,
    p.is_deleted,
    p.deleted_at,
    p.created_at as photo_created_at,
    p.expires_at,
    p.key,
    r.id as reaction_id,
    r.photo_id as reaction_photo_id,
    r.user_id as reaction_user_id,
    r.emoji as reaction_emoji,
    r.created_at as reaction_created_at
FROM photos p
LEFT JOIN reactions r ON p.id = r.photo_id
WHERE p.sender_id = $1 AND p.is_deleted = false
ORDER BY p.created_at DESC, r.created_at ASC
LIMIT $2 OFFSET $3;

-- name: GetPhotoWithReactionsAggregate :one
-- ALTERNATIVE: Get photo with aggregated reaction count and emojis
-- This returns a single row with JSON aggregated reactions
SELECT 
    p.id,
    p.sender_id,
    p.photo_url,
    p.thumbnail_url,
    p.file_size,
    p.width,
    p.height,
    p.mime_type,
    p.caption,
    p.is_deleted,
    p.deleted_at,
    p.created_at,
    p.expires_at,
    p.key,
    COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', r.id,
                'user_id', r.user_id,
                'emoji', r.emoji,
                'created_at', r.created_at
            ) ORDER BY r.created_at ASC
        ) FILTER (WHERE r.id IS NOT NULL),
        '[]'::jsonb
    ) as reactions
FROM photos p
LEFT JOIN reactions r ON p.id = r.photo_id
WHERE p.id = $1 AND p.is_deleted = false
GROUP BY p.id;

-- name: CreateReaction :one
-- Create a new reaction for a photo
INSERT INTO reactions (
    photo_id,
    user_id,
    emoji
) VALUES (
    $1, $2, $3
)
ON CONFLICT (photo_id, user_id) 
DO UPDATE SET 
    emoji = EXCLUDED.emoji,
    created_at = CURRENT_TIMESTAMP
RETURNING id, photo_id, user_id, emoji, created_at;

-- name: DeleteReaction :exec
-- Delete a reaction
DELETE FROM reactions
WHERE photo_id = $1 AND user_id = $2;

-- name: GetReactionCount :one
-- Get total reaction count for a photo
SELECT COUNT(*) as count
FROM reactions
WHERE photo_id = $1;

-- name: GetReactionCountByEmoji :many
-- Get reaction counts grouped by emoji for a photo
SELECT 
    emoji,
    COUNT(*) as count
FROM reactions
WHERE photo_id = $1
GROUP BY emoji
ORDER BY count DESC;
