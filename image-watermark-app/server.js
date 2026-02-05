const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = 3000;

// Ensure upload folder exists
const uploadDir = path.join(__dirname, 'image_uploaded');
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
    console.log('Created image_uploaded folder');
}

// Configure multer storage
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, uploadDir);
    },
    filename: function (req, file, cb) {
        // Generate unique filename with timestamp
        const timestamp = Date.now();
        const ext = path.extname(file.originalname);
        const basename = path.basename(file.originalname, ext);
        const uniqueName = `${timestamp}-${basename}${ext}`;
        cb(null, uniqueName);
    }
});

// File filter to accept only images
const fileFilter = (req, file, cb) => {
    const allowedTypes = /jpeg|jpg|png|gif|webp|bmp|tiff|cr2|nef|arw|dng|orf|rw2|pef|srw/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype) || file.mimetype.startsWith('image/');
    
    if (extname || mimetype) {
        cb(null, true);
    } else {
        cb(new Error('Only image files are allowed!'));
    }
};

const upload = multer({ 
    storage: storage,
    limits: { 
        fileSize: 100 * 1024 * 1024 // 100MB limit for RAW files
    },
    fileFilter: fileFilter
});

// Serve static files from current directory
app.use(express.static(__dirname));

// Serve uploaded images
app.use('/image_uploaded', express.static(uploadDir));

// Upload endpoint
app.post('/upload', upload.single('image'), (req, res) => {
    if (!req.file) {
        return res.status(400).json({ 
            success: false,
            error: 'No file uploaded' 
        });
    }
    
    console.log(`Image uploaded: ${req.file.filename} (${(req.file.size / 1024 / 1024).toFixed(2)} MB)`);
    
    res.json({ 
        success: true, 
        filename: req.file.filename,
        path: `/image_uploaded/${req.file.filename}`,
        size: req.file.size,
        originalName: req.file.originalname
    });
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error('Error:', err.message);
    res.status(500).json({ 
        success: false,
        error: err.message 
    });
});

// Start server
app.listen(PORT, () => {
    console.log(`
╔════════════════════════════════════════════════════════╗
║  Image Watermark Server                               ║
║  Running on: http://localhost:${PORT}                    ║
║  Upload folder: ${uploadDir}                           ║
╚════════════════════════════════════════════════════════╝
    `);
});
