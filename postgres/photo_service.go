package service

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yourusername/yourproject/db" // Update with your actual path
)

// ReactionResponse represents a reaction in the API response
type ReactionResponse struct {
	ID        uuid.UUID `json:"id"`
	PhotoID   uuid.UUID `json:"photo_id"`
	UserID    uuid.UUID `json:"user_id"`
	Emoji     string    `json:"emoji"`
	CreatedAt time.Time `json:"created_at"`
}

// PhotoResponse represents a photo with its reactions in the API response
type PhotoResponse struct {
	ID           uuid.UUID          `json:"id"`
	SenderID     uuid.UUID          `json:"sender_id"`
	PhotoURL     string             `json:"photo_url"`
	ThumbnailURL *string            `json:"thumbnail_url,omitempty"`
	FileSize     *int32             `json:"file_size,omitempty"`
	Width        *int32             `json:"width,omitempty"`
	Height       *int32             `json:"height,omitempty"`
	MimeType     *string            `json:"mime_type,omitempty"`
	Caption      *string            `json:"caption,omitempty"`
	IsDeleted    *bool              `json:"is_deleted,omitempty"`
	DeletedAt    *time.Time         `json:"deleted_at,omitempty"`
	CreatedAt    *time.Time         `json:"created_at"`
	ExpiresAt    *time.Time         `json:"expires_at,omitempty"`
	Key          *string            `json:"key,omitempty"`
	Reactions    []ReactionResponse `json:"reactions"` // Always include, empty if no reactions
}

// PhotoService handles business logic for photos
type PhotoService struct {
	queries *db.Queries
}

// NewPhotoService creates a new photo service
func NewPhotoService(queries *db.Queries) *PhotoService {
	return &PhotoService{queries: queries}
}

// APPROACH 1: Two-Query Approach (More Flexible, Easier to Understand)
// Best for: Simple use cases, when you need fine-grained control

// GetPhotoWithReactionsTwoQueries fetches a photo and its reactions using two queries
func (s *PhotoService) GetPhotoWithReactionsTwoQueries(ctx context.Context, photoID uuid.UUID) (*PhotoResponse, error) {
	// Query 1: Get the photo
	photo, err := s.queries.GetPhotoByID(ctx, photoID)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("photo not found")
		}
		return nil, fmt.Errorf("failed to get photo: %w", err)
	}

	// Query 2: Get reactions for the photo
	reactions, err := s.queries.GetReactionsByPhotoID(ctx, photoID)
	if err != nil {
		return nil, fmt.Errorf("failed to get reactions: %w", err)
	}

	// Build the response
	response := &PhotoResponse{
		ID:           photo.ID,
		SenderID:     photo.SenderID,
		PhotoURL:     photo.PhotoURL,
		ThumbnailURL: photo.ThumbnailURL,
		FileSize:     photo.FileSize,
		Width:        photo.Width,
		Height:       photo.Height,
		MimeType:     photo.MimeType,
		Caption:      photo.Caption,
		IsDeleted:    photo.IsDeleted,
		DeletedAt:    photo.DeletedAt,
		CreatedAt:    photo.CreatedAt,
		ExpiresAt:    photo.ExpiresAt,
		Key:          photo.Key,
		Reactions:    make([]ReactionResponse, 0), // Initialize empty slice
	}

	// Convert reactions to response format
	for _, r := range reactions {
		response.Reactions = append(response.Reactions, ReactionResponse{
			ID:        r.ID,
			PhotoID:   r.PhotoID,
			UserID:    r.UserID,
			Emoji:     r.Emoji,
			CreatedAt: r.CreatedAt,
		})
	}

	return response, nil
}

// APPROACH 2: Single-Query with LEFT JOIN (More Efficient for Database)
// Best for: High-performance needs, reducing database round trips

// GetPhotoWithReactionsSingleQuery fetches a photo and its reactions using a single optimized query
func (s *PhotoService) GetPhotoWithReactionsSingleQuery(ctx context.Context, photoID uuid.UUID) (*PhotoResponse, error) {
	// Single query with LEFT JOIN
	rows, err := s.queries.GetPhotoWithReactionsOptimized(ctx, photoID)
	if err != nil {
		return nil, fmt.Errorf("failed to get photo with reactions: %w", err)
	}

	if len(rows) == 0 {
		return nil, fmt.Errorf("photo not found")
	}

	// Build response from the first row (photo data)
	firstRow := rows[0]
	response := &PhotoResponse{
		ID:           firstRow.PhotoID,
		SenderID:     firstRow.SenderID,
		PhotoURL:     firstRow.PhotoURL,
		ThumbnailURL: firstRow.ThumbnailURL,
		FileSize:     firstRow.FileSize,
		Width:        firstRow.Width,
		Height:       firstRow.Height,
		MimeType:     firstRow.MimeType,
		Caption:      firstRow.Caption,
		IsDeleted:    firstRow.IsDeleted,
		DeletedAt:    firstRow.DeletedAt,
		CreatedAt:    &firstRow.PhotoCreatedAt,
		ExpiresAt:    firstRow.ExpiresAt,
		Key:          firstRow.Key,
		Reactions:    make([]ReactionResponse, 0), // Initialize empty slice
	}

	// Collect reactions from all rows
	for _, row := range rows {
		// Check if reaction exists (LEFT JOIN might return NULL)
		// Use pgtype.UUID.Valid field to check for NULL
		if row.ReactionID.Valid {
			reactionID, _ := uuid.FromBytes(row.ReactionID.Bytes[:])
			reactionUserID, _ := uuid.FromBytes(row.ReactionUserID.Bytes[:])
			
			response.Reactions = append(response.Reactions, ReactionResponse{
				ID:        reactionID,
				PhotoID:   response.ID,
				UserID:    reactionUserID,
				Emoji:     row.ReactionEmoji,
				CreatedAt: row.ReactionCreatedAt.Time,
			})
		}
	}

	return response, nil
}

// GetPhotosByUserWithReactions fetches all photos by a user with their reactions
func (s *PhotoService) GetPhotosByUserWithReactions(ctx context.Context, userID uuid.UUID, limit, offset int32) ([]PhotoResponse, error) {
	rows, err := s.queries.GetPhotosWithReactionsByUserID(ctx, db.GetPhotosWithReactionsByUserIDParams{
		SenderID: userID,
		Limit:    limit,
		Offset:   offset,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to get photos with reactions: %w", err)
	}

	// Group by photo ID
	photoMap := make(map[uuid.UUID]*PhotoResponse)
	var photoOrder []uuid.UUID // Track order

	for _, row := range rows {
		photoID := row.PhotoID

		// Create photo response if not exists
		if _, exists := photoMap[photoID]; !exists {
			photoMap[photoID] = &PhotoResponse{
				ID:           row.PhotoID,
				SenderID:     row.SenderID,
				PhotoURL:     row.PhotoURL,
				ThumbnailURL: row.ThumbnailURL,
				FileSize:     row.FileSize,
				Width:        row.Width,
				Height:       row.Height,
				MimeType:     row.MimeType,
				Caption:      row.Caption,
				IsDeleted:    row.IsDeleted,
				DeletedAt:    row.DeletedAt,
				CreatedAt:    &row.PhotoCreatedAt,
				ExpiresAt:    row.ExpiresAt,
				Key:          row.Key,
				Reactions:    make([]ReactionResponse, 0),
			}
			photoOrder = append(photoOrder, photoID)
		}

		// Add reaction if exists
		// Check if reaction_id is valid (not NULL) using pgtype.UUID.Valid field
		if row.ReactionID.Valid {
			reactionID, _ := uuid.FromBytes(row.ReactionID.Bytes[:])
			reactionUserID, _ := uuid.FromBytes(row.ReactionUserID.Bytes[:])
			
			photoMap[photoID].Reactions = append(photoMap[photoID].Reactions, ReactionResponse{
				ID:        reactionID,
				PhotoID:   photoID,
				UserID:    reactionUserID,
				Emoji:     row.ReactionEmoji,
				CreatedAt: row.ReactionCreatedAt.Time,
			})
		}
	}

	// Convert map to ordered slice
	result := make([]PhotoResponse, 0, len(photoOrder))
	for _, photoID := range photoOrder {
		result = append(result, *photoMap[photoID])
	}

	return result, nil
}

// AddReaction adds or updates a reaction to a photo
func (s *PhotoService) AddReaction(ctx context.Context, photoID, userID uuid.UUID, emoji string) (*ReactionResponse, error) {
	reaction, err := s.queries.CreateReaction(ctx, db.CreateReactionParams{
		PhotoID: photoID,
		UserID:  userID,
		Emoji:   emoji,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create reaction: %w", err)
	}

	return &ReactionResponse{
		ID:        reaction.ID,
		PhotoID:   reaction.PhotoID,
		UserID:    reaction.UserID,
		Emoji:     reaction.Emoji,
		CreatedAt: reaction.CreatedAt,
	}, nil
}

// RemoveReaction removes a user's reaction from a photo
func (s *PhotoService) RemoveReaction(ctx context.Context, photoID, userID uuid.UUID) error {
	err := s.queries.DeleteReaction(ctx, db.DeleteReactionParams{
		PhotoID: photoID,
		UserID:  userID,
	})
	if err != nil {
		return fmt.Errorf("failed to delete reaction: %w", err)
	}
	return nil
}

// GetPhotosWithReactionsComplete fetches all photos by a user with complete photo and reaction data
// This uses a single optimized query with LEFT JOIN to include all fields
func (s *PhotoService) GetPhotosWithReactionsComplete(ctx context.Context, userID uuid.UUID, limit, offset int32) ([]PhotoResponse, error) {
	rows, err := s.queries.GetPhotosWithReactionsComplete(ctx, db.GetPhotosWithReactionsCompleteParams{
		SenderID: userID,
		Limit:    limit,
		Offset:   offset,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to get photos with reactions: %w", err)
	}

	// Group by photo ID
	photoMap := make(map[uuid.UUID]*PhotoResponse)
	var photoOrder []uuid.UUID // Track order

	for _, row := range rows {
		photoID := row.PhotoID

		// Create photo response if not exists
		if _, exists := photoMap[photoID]; !exists {
			photoMap[photoID] = &PhotoResponse{
				ID:           row.PhotoID,
				SenderID:     row.SenderID,
				PhotoURL:     row.PhotoURL,
				ThumbnailURL: row.ThumbnailURL,
				FileSize:     row.FileSize,
				Width:        row.Width,
				Height:       row.Height,
				MimeType:     row.MimeType,
				Caption:      row.Caption,
				IsDeleted:    row.IsDeleted,
				DeletedAt:    row.DeletedAt,
				CreatedAt:    &row.PhotoCreatedAt,
				ExpiresAt:    row.ExpiresAt,
				Key:          row.Key,
				Reactions:    make([]ReactionResponse, 0), // Initialize empty slice
			}
			photoOrder = append(photoOrder, photoID)
		}

		// Add reaction if exists (LEFT JOIN might return NULL)
		// Check if reaction_id is valid (not NULL) using pgtype.UUID.Valid field
		if row.ReactionID.Valid {
			reactionID, _ := uuid.FromBytes(row.ReactionID.Bytes[:])
			reactionPhotoID, _ := uuid.FromBytes(row.ReactionPhotoID.Bytes[:])
			reactionUserID, _ := uuid.FromBytes(row.ReactionUserID.Bytes[:])
			
			photoMap[photoID].Reactions = append(photoMap[photoID].Reactions, ReactionResponse{
				ID:        reactionID,
				PhotoID:   reactionPhotoID,
				UserID:    reactionUserID,
				Emoji:     row.ReactionEmoji,
				CreatedAt: row.ReactionCreatedAt.Time,
			})
		}
	}

	// Convert map to ordered slice
	result := make([]PhotoResponse, 0, len(photoOrder))
	for _, photoID := range photoOrder {
		result = append(result, *photoMap[photoID])
	}

	return result, nil
}
