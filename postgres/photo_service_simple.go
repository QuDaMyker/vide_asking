package service

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yourusername/yourproject/db" // Update with your actual path
)

// SimpleReactionResponse represents a minimal reaction in the API response
type SimpleReactionResponse struct {
	ID    uuid.UUID `json:"id"`
	Emoji string    `json:"emoji"`
}

// SimplePhotoResponse represents a photo with minimal reaction data
type SimplePhotoResponse struct {
	ID        uuid.UUID                `json:"id"`
	PhotoURL  string                   `json:"photo_url"`
	Reactions []SimpleReactionResponse `json:"reactions"` // Always include, empty if no reactions
}

// GetPhotosWithReactionsSimple fetches photos with only essential data (id, photo_url, reaction id, emoji)
// This is optimized for lightweight API responses
func (s *PhotoService) GetPhotosWithReactionsSimple(ctx context.Context, userID uuid.UUID, limit, offset int32) ([]SimplePhotoResponse, error) {
	rows, err := s.queries.GetPhotosWithReactionsSimple(ctx, db.GetPhotosWithReactionsSimpleParams{
		SenderID: userID,
		Limit:    limit,
		Offset:   offset,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to get photos with reactions: %w", err)
	}

	// Group by photo ID
	photoMap := make(map[uuid.UUID]*SimplePhotoResponse)
	var photoOrder []uuid.UUID // Track order

	for _, row := range rows {
		photoID := row.PhotoID

		// Create photo response if not exists
		if _, exists := photoMap[photoID]; !exists {
			photoMap[photoID] = &SimplePhotoResponse{
				ID:        row.PhotoID,
				PhotoURL:  row.PhotoURL,
				Reactions: make([]SimpleReactionResponse, 0),
			}
			photoOrder = append(photoOrder, photoID)
		}

		// Add reaction if exists (LEFT JOIN might return NULL)
		if row.ReactionID != nil {
			photoMap[photoID].Reactions = append(photoMap[photoID].Reactions, SimpleReactionResponse{
				ID:    *row.ReactionID,
				Emoji: *row.ReactionEmoji,
			})
		}
	}

	// Convert map to ordered slice
	result := make([]SimplePhotoResponse, 0, len(photoOrder))
	for _, photoID := range photoOrder {
		result = append(result, *photoMap[photoID])
	}

	return result, nil
}
