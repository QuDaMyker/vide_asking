package handler

import (
	"encoding/json"
	"net/http"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/yourusername/yourproject/service" // Update with your actual path
)

type PhotoHandler struct {
	photoService *service.PhotoService
}

func NewPhotoHandler(photoService *service.PhotoService) *PhotoHandler {
	return &PhotoHandler{
		photoService: photoService,
	}
}

// GetPhotoByID godoc
// @Summary Get a photo with its reactions
// @Description Get a single photo by ID with all its reactions
// @Tags photos
// @Accept json
// @Produce json
// @Param id path string true "Photo ID"
// @Success 200 {object} service.PhotoResponse
// @Failure 400 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /photos/{id} [get]
func (h *PhotoHandler) GetPhotoByID(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	photoID, err := uuid.Parse(vars["id"])
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid photo ID")
		return
	}

	// Use the optimized single-query approach for best performance
	photo, err := h.photoService.GetPhotoWithReactionsSingleQuery(r.Context(), photoID)
	if err != nil {
		if err.Error() == "photo not found" {
			respondError(w, http.StatusNotFound, "photo not found")
			return
		}
		respondError(w, http.StatusInternalServerError, "failed to get photo")
		return
	}

	respondJSON(w, http.StatusOK, photo)
}

// GetUserPhotos godoc
// @Summary Get user's photos with reactions
// @Description Get all photos by a user with their reactions (paginated)
// @Tags photos
// @Accept json
// @Produce json
// @Param user_id path string true "User ID"
// @Param limit query int false "Limit" default(20)
// @Param offset query int false "Offset" default(0)
// @Success 200 {array} service.PhotoResponse
// @Failure 400 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /users/{user_id}/photos [get]
func (h *PhotoHandler) GetUserPhotos(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	userID, err := uuid.Parse(vars["user_id"])
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid user ID")
		return
	}

	// Parse query parameters
	limit := int32(20)
	offset := int32(0)
	
	if l := r.URL.Query().Get("limit"); l != "" {
		var limitInt int
		if _, err := fmt.Sscanf(l, "%d", &limitInt); err == nil && limitInt > 0 {
			limit = int32(limitInt)
		}
	}
	
	if o := r.URL.Query().Get("offset"); o != "" {
		var offsetInt int
		if _, err := fmt.Sscanf(o, "%d", &offsetInt); err == nil && offsetInt >= 0 {
			offset = int32(offsetInt)
		}
	}

	photos, err := h.photoService.GetPhotosByUserWithReactions(r.Context(), userID, limit, offset)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to get photos")
		return
	}

	respondJSON(w, http.StatusOK, photos)
}

// AddReaction godoc
// @Summary Add a reaction to a photo
// @Description Add or update a user's reaction to a photo
// @Tags reactions
// @Accept json
// @Produce json
// @Param id path string true "Photo ID"
// @Param reaction body AddReactionRequest true "Reaction"
// @Success 201 {object} service.ReactionResponse
// @Failure 400 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /photos/{id}/reactions [post]
func (h *PhotoHandler) AddReaction(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	photoID, err := uuid.Parse(vars["id"])
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid photo ID")
		return
	}

	var req AddReactionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	userID, err := uuid.Parse(req.UserID)
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid user ID")
		return
	}

	if req.Emoji == "" {
		respondError(w, http.StatusBadRequest, "emoji is required")
		return
	}

	reaction, err := h.photoService.AddReaction(r.Context(), photoID, userID, req.Emoji)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to add reaction")
		return
	}

	respondJSON(w, http.StatusCreated, reaction)
}

// RemoveReaction godoc
// @Summary Remove a reaction from a photo
// @Description Remove a user's reaction from a photo
// @Tags reactions
// @Accept json
// @Produce json
// @Param id path string true "Photo ID"
// @Param user_id query string true "User ID"
// @Success 204 "No Content"
// @Failure 400 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /photos/{id}/reactions [delete]
func (h *PhotoHandler) RemoveReaction(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	photoID, err := uuid.Parse(vars["id"])
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid photo ID")
		return
	}

	userIDStr := r.URL.Query().Get("user_id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid user ID")
		return
	}

	if err := h.photoService.RemoveReaction(r.Context(), photoID, userID); err != nil {
		respondError(w, http.StatusInternalServerError, "failed to remove reaction")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// Request/Response types
type AddReactionRequest struct {
	UserID string `json:"user_id"`
	Emoji  string `json:"emoji"`
}

type ErrorResponse struct {
	Error string `json:"error"`
}

// Helper functions
func respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func respondError(w http.ResponseWriter, status int, message string) {
	respondJSON(w, status, ErrorResponse{Error: message})
}
