# Image Watermark Application

A web-based image watermarking tool with EXIF data extraction and glassmorphism effects.

## Features

✅ **EXIF Data Extraction** - Automatically reads camera info from images
✅ **Customizable Watermark** - Date, author name, camera, and settings
✅ **Glassmorphism Effect** - Modern blur and transparency effects
✅ **Local Timezone Display** - Shows date/time in your timezone
✅ **Server-Side Storage** - Uploads saved permanently to `image_uploaded/`
✅ **Download Processed Images** - Export with watermark applied
✅ **Docker Support** - Easy deployment with Docker Compose

## Quick Start with Docker 🐳

### Prerequisites
- Docker
- Docker Compose

### Run with Docker (Recommended)

**1. Start the application:**
```bash
./docker-start.sh
```

Or manually:
```bash
docker-compose up --build -d
```

**2. Open in browser:**
```
http://localhost:3000
```

**3. Stop the application:**
```bash
docker-compose down
```

### Docker Commands

```bash
# View logs
docker-compose logs -f

# Restart
docker-compose restart

# Stop (keeps containers)
docker-compose stop

# Stop and remove containers
docker-compose down

# Rebuild after code changes
docker-compose up --build -d

# Check status
docker-compose ps
```

## Setup & Installation (Without Docker)

### Prerequisites
- Node.js (v14 or higher)
- npm or yarn

### Installation Steps

1. **Install dependencies:**
```bash
npm install
```

2. **Start the server:**
```bash
npm start
```

3. **Open in browser:**
```
http://localhost:3000
```

## Usage

1. **Upload Image** - Click or drag & drop an image
2. **Auto-Extract EXIF** - Camera info loads automatically
3. **Enter Author Name** - Optional photographer name
4. **Adjust Settings** - Font size, colors, opacity
5. **Download** - Save watermarked image

## Watermark Layout

```
┌─────────────────────────────┐
│  Blurred Background (100%)  │
│ ┌─────────────────────────┐ │
│ │ Clear Image (90%)       │ │
│ │                         │ │
│ └─────────────────────────┘ │
│ ╔═══════════════════════╗ │ ← Watermark in gap
│ ║ Date | Author | Info ║ │
│ ╚═══════════════════════╝ │
└─────────────────────────────┘
```

## File Structure

```
image-watermark-app/
├── server.js           # Express server with upload handling
├── app.js              # Client-side JavaScript
├── index.html          # Main HTML page
├── styles.css          # Styling
├── package.json        # Dependencies
├── image_uploaded/     # Uploaded images stored here (auto-created)
└── README.md           # This file
```

## Server Upload

All uploaded images are automatically saved to the `image_uploaded/` folder with timestamps:
- Format: `{timestamp}-{filename}.{ext}`
- Example: `1738612859000-photo.jpg`
- Files are never deleted (permanent storage)

## Timezone Handling

Date/time from EXIF is displayed in your browser's local timezone:
- EXIF: `2026:02:03 16:50:59`
- Display: `2026-02-03 16:50 GMT+7` (or your timezone)

## Supported Formats

**Images:** JPEG, PNG, GIF, WebP, BMP, TIFF
**RAW Files:** CR2, CR3, NEF, ARW, DNG, ORF, RW2, PEF, SRW

*Note: RAW files may not preview in browser but EXIF data can be extracted*

## Configuration

### Port
Change in `server.js`:
```javascript
const PORT = 3000; // Change to your preferred port
```

### Upload Folder
Change in `server.js`:
```javascript
const uploadDir = path.join(__dirname, 'image_uploaded'); // Change path
```

### File Size Limit
Change in `server.js`:
```javascript
limits: { fileSize: 100 * 1024 * 1024 } // 100MB default
```

## Troubleshooting

**Port already in use:**
```bash
# Change PORT in server.js or kill process:
lsof -ti:3000 | xargs kill -9
```

**Uploads not saving:**
- Check folder permissions
- Ensure `image_uploaded/` folder exists
- Check server console for errors

**Watermark not showing:**
- Open browser console (F12)
- Check for JavaScript errors
- Verify EXIF data is extracted

## Development

### Run with auto-reload:
```bash
npm run dev
```

### Debug mode:
Open browser DevTools (F12) and check Console tab for logs

## License

MIT

## Credits

- EXIF.js library for metadata extraction
- Express & Multer for server-side upload handling

## Docker Configuration

### Dockerfile
- Base image: `node:18-alpine` (lightweight)
- Installs production dependencies only
- Exposes port 3000
- Creates upload directory

### docker-compose.yml
- Service name: `watermark-app`
- Port mapping: `3000:3000`
- Volume mount: `./image_uploaded:/app/image_uploaded` (persistent storage)
- Health check: Monitors application status
- Restart policy: `unless-stopped`

### Volumes
Uploaded images are stored in `./image_uploaded/` on your host machine and mounted into the container. This ensures:
- Images persist across container restarts
- Easy access to uploaded files from host
- No data loss when container is removed

### Environment Variables
You can customize the application by setting environment variables in `docker-compose.yml`:

```yaml
environment:
  - NODE_ENV=production
  - PORT=3000
```

## Production Deployment

### Using Docker Compose (Recommended)

```bash
# 1. Clone the repository
git clone <your-repo>
cd image-watermark-app

# 2. Start with Docker Compose
docker-compose up -d

# 3. Check logs
docker-compose logs -f

# 4. Access at http://your-domain:3000
```

### Behind Nginx Reverse Proxy

Create `/etc/nginx/sites-available/watermark`:

```nginx
server {
    listen 80;
    server_name watermark.yourdomain.com;

    client_max_body_size 100M;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

Enable and restart:
```bash
sudo ln -s /etc/nginx/sites-available/watermark /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### SSL with Certbot

```bash
sudo certbot --nginx -d watermark.yourdomain.com
```

## Monitoring

### View Logs
```bash
# Docker Compose logs
docker-compose logs -f watermark-app

# Last 100 lines
docker-compose logs --tail=100 watermark-app

# Container logs
docker logs -f image-watermark-app
```

### Check Container Health
```bash
docker-compose ps
docker inspect image-watermark-app | grep -A 10 Health
```

### Monitor Resource Usage
```bash
docker stats image-watermark-app
```

