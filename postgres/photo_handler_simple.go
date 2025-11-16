package handler

import (
	"fmt"
	"net/http"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/yourusername/yourproject/service" // Update with your actual path
)

// GetUserPhotosSimple godoc
// @Summary Get user's photos with minimal reaction data
// @Description Get photos with only id, photo_url, and reactions (id, emoji)
// @Tags photos
// @Accept json
// @Produce json
// @Param user_id path string true "User ID"
// @Param limit query int false "Limit" default(20)
// @Param offset query int false "Offset" default(0)
// @Success 200 {array} service.SimplePhotoResponse
// @Failure 400 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /users/{user_id}/photos/simple [get]
func (h *PhotoHandler) GetUserPhotosSimple(w http.ResponseWriter, r *http.Request) {
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

	photos, err := h.photoService.GetPhotosWithReactionsSimple(r.Context(), userID, limit, offset)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to get photos")
		return
	}

	respondJSON(w, http.StatusOK, photos)
}
