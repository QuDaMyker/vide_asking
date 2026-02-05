#!/bin/bash

# Docker Quick Start Script for Image Watermark App

echo "🐳 Image Watermark App - Docker Setup"
echo "======================================"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first:"
    echo "   https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose:"
    echo "   https://docs.docker.com/compose/install/"
    exit 1
fi

echo "✅ Docker and Docker Compose are installed"
echo ""

# Build and start containers
echo "🔨 Building and starting containers..."
docker-compose up --build -d

# Wait for container to be healthy
echo ""
echo "⏳ Waiting for application to be ready..."
sleep 5

# Check if container is running
if docker-compose ps | grep -q "Up"; then
    echo ""
    echo "✅ Application is running!"
    echo ""
    echo "📍 Access the app at: http://localhost:3000"
    echo ""
    echo "📂 Uploaded images will be saved to: ./image_uploaded/"
    echo ""
    echo "🔧 Useful commands:"
    echo "   • View logs:     docker-compose logs -f"
    echo "   • Stop:          docker-compose stop"
    echo "   • Restart:       docker-compose restart"
    echo "   • Stop & remove: docker-compose down"
    echo "   • Rebuild:       docker-compose up --build -d"
    echo ""
else
    echo ""
    echo "❌ Container failed to start. Check logs with:"
    echo "   docker-compose logs"
fi
