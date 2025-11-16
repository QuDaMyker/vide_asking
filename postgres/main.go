package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/yourusername/yourproject/db"
	"github.com/yourusername/yourproject/handler"
	"github.com/yourusername/yourproject/service"
)

func main() {
	// Get database connection string from environment
	connString := os.Getenv("DATABASE_URL")
	if connString == "" {
		connString = "postgres://user:password@localhost:5432/dbname?sslmode=disable"
	}

	// Create connection pool
	ctx := context.Background()
	poolConfig, err := pgxpool.ParseConfig(connString)
	if err != nil {
		log.Fatalf("Unable to parse database config: %v", err)
	}

	// Configure pool
	poolConfig.MaxConns = 25
	poolConfig.MinConns = 5

	// Connect to database
	pool, err := pgxpool.NewWithConfig(ctx, poolConfig)
	if err != nil {
		log.Fatalf("Unable to connect to database: %v", err)
	}
	defer pool.Close()

	// Verify connection
	if err := pool.Ping(ctx); err != nil {
		log.Fatalf("Unable to ping database: %v", err)
	}

	log.Println("Successfully connected to database")

	// Initialize layers
	queries := db.New(pool)
	photoService := service.NewPhotoService(queries)
	photoHandler := handler.NewPhotoHandler(photoService)

	// Setup router
	r := mux.NewRouter()

	// API routes
	api := r.PathPrefix("/api/v1").Subrouter()
	
	// Photo endpoints
	api.HandleFunc("/photos/{id}", photoHandler.GetPhotoByID).Methods("GET")
	api.HandleFunc("/users/{user_id}/photos", photoHandler.GetUserPhotos).Methods("GET")
	
	// Reaction endpoints
	api.HandleFunc("/photos/{id}/reactions", photoHandler.AddReaction).Methods("POST")
	api.HandleFunc("/photos/{id}/reactions", photoHandler.RemoveReaction).Methods("DELETE")

	// Health check
	r.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, "OK")
	}).Methods("GET")

	// Start server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server starting on port %s", port)
	if err := http.ListenAndServe(":"+port, r); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
