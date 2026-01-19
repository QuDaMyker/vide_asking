// DOM Elements
const uploadArea = document.getElementById('uploadArea');
const fileInput = document.getElementById('fileInput');
const previewSection = document.getElementById('previewSection');
const exifSection = document.getElementById('exifSection');
const settingsSection = document.getElementById('settingsSection');
const originalImage = document.getElementById('originalImage');
const watermarkCanvas = document.getElementById('watermarkCanvas');
const exifGrid = document.getElementById('exifGrid');
const loadingOverlay = document.getElementById('loadingOverlay');

// Settings elements
const watermarkPosition = document.getElementById('watermarkPosition');
const watermarkStyle = document.getElementById('watermarkStyle');
const fontSize = document.getElementById('fontSize');
const fontSizeValue = document.getElementById('fontSizeValue');
const opacity = document.getElementById('opacity');
const opacityValue = document.getElementById('opacityValue');
const textColor = document.getElementById('textColor');
const bgColor = document.getElementById('bgColor');
const showDate = document.getElementById('showDate');
const showCamera = document.getElementById('showCamera');
const showLens = document.getElementById('showLens');
const showSettings = document.getElementById('showSettings');
const applyWatermarkBtn = document.getElementById('applyWatermark');
const downloadBtn = document.getElementById('downloadImage');
const resetBtn = document.getElementById('resetImage');

// State
let currentImage = null;
let exifData = {};

// Event Listeners
uploadArea.addEventListener('click', () => fileInput.click());
uploadArea.addEventListener('dragover', handleDragOver);
uploadArea.addEventListener('dragleave', handleDragLeave);
uploadArea.addEventListener('drop', handleDrop);
fileInput.addEventListener('change', handleFileSelect);

fontSize.addEventListener('input', () => {
    fontSizeValue.textContent = `${fontSize.value}px`;
});

opacity.addEventListener('input', () => {
    opacityValue.textContent = `${Math.round(opacity.value * 100)}%`;
});

// Auto-apply watermark when settings change
[watermarkPosition, watermarkStyle, fontSize, opacity, textColor, bgColor, 
 showDate, showCamera, showLens, showSettings].forEach(element => {
    element.addEventListener('change', () => {
        if (currentImage) applyWatermark();
    });
    if (element.type === 'range' || element.type === 'color') {
        element.addEventListener('input', () => {
            if (currentImage) applyWatermark();
        });
    }
});

applyWatermarkBtn.addEventListener('click', applyWatermark);
downloadBtn.addEventListener('click', downloadImage);
resetBtn.addEventListener('click', resetApp);

// Drag and Drop Handlers
function handleDragOver(e) {
    e.preventDefault();
    uploadArea.classList.add('dragover');
}

function handleDragLeave(e) {
    e.preventDefault();
    uploadArea.classList.remove('dragover');
}

function handleDrop(e) {
    e.preventDefault();
    uploadArea.classList.remove('dragover');
    const files = e.dataTransfer.files;
    if (files.length > 0) {
        processFile(files[0]);
    }
}

function handleFileSelect(e) {
    const files = e.target.files;
    if (files.length > 0) {
        processFile(files[0]);
    }
}

// Process uploaded file
function processFile(file) {
    if (!file.type.startsWith('image/') && !isRawFile(file.name)) {
        alert('Please upload an image file.');
        return;
    }

    showLoading(true);

    const reader = new FileReader();
    reader.onload = (e) => {
        currentImage = new Image();
        currentImage.onload = () => {
            displayImage();
            extractExifData(file);
        };
        currentImage.src = e.target.result;
    };
    reader.readAsDataURL(file);
}

function isRawFile(filename) {
    const rawExtensions = ['.raw', '.cr2', '.cr3', '.nef', '.arw', '.dng', '.orf', '.rw2', '.pef', '.srw'];
    const ext = filename.toLowerCase().substring(filename.lastIndexOf('.'));
    return rawExtensions.includes(ext);
}

// Display the image
function displayImage() {
    originalImage.src = currentImage.src;
    previewSection.style.display = 'block';
    settingsSection.style.display = 'block';
    
    // Scroll to preview
    previewSection.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

// Extract EXIF data using EXIF.js
function extractExifData(file) {
    EXIF.getData(file, function() {
        exifData = {
            make: EXIF.getTag(this, 'Make') || '',
            model: EXIF.getTag(this, 'Model') || '',
            lens: EXIF.getTag(this, 'LensModel') || EXIF.getTag(this, 'LensMake') || '',
            focalLength: EXIF.getTag(this, 'FocalLength'),
            aperture: EXIF.getTag(this, 'FNumber'),
            iso: EXIF.getTag(this, 'ISOSpeedRatings'),
            shutterSpeed: EXIF.getTag(this, 'ExposureTime'),
            dateTime: EXIF.getTag(this, 'DateTimeOriginal') || EXIF.getTag(this, 'DateTime'),
            exposureBias: EXIF.getTag(this, 'ExposureBias') || EXIF.getTag(this, 'ExposureBiasValue'),
            meteringMode: EXIF.getTag(this, 'MeteringMode'),
            flash: EXIF.getTag(this, 'Flash'),
            whiteBalance: EXIF.getTag(this, 'WhiteBalance'),
            imageWidth: EXIF.getTag(this, 'PixelXDimension') || EXIF.getTag(this, 'ImageWidth'),
            imageHeight: EXIF.getTag(this, 'PixelYDimension') || EXIF.getTag(this, 'ImageHeight'),
            software: EXIF.getTag(this, 'Software'),
            artist: EXIF.getTag(this, 'Artist'),
            copyright: EXIF.getTag(this, 'Copyright')
        };

        displayExifData();
        applyWatermark();
        showLoading(false);
    });
}

// Display EXIF data in the UI
function displayExifData() {
    exifGrid.innerHTML = '';
    exifSection.style.display = 'block';

    const exifItems = [
        { label: 'Camera Make', value: exifData.make },
        { label: 'Camera Model', value: exifData.model },
        { label: 'Lens', value: exifData.lens },
        { label: 'Focal Length', value: formatFocalLength(exifData.focalLength) },
        { label: 'Aperture', value: formatAperture(exifData.aperture) },
        { label: 'ISO', value: exifData.iso },
        { label: 'Shutter Speed', value: formatShutterSpeed(exifData.shutterSpeed) },
        { label: 'Date/Time', value: formatDateTime(exifData.dateTime) },
        { label: 'Image Size', value: formatImageSize(exifData.imageWidth, exifData.imageHeight) },
        { label: 'Software', value: exifData.software },
        { label: 'Artist', value: exifData.artist },
        { label: 'Copyright', value: exifData.copyright }
    ];

    let hasData = false;

    exifItems.forEach(item => {
        if (item.value && item.value !== 'N/A') {
            hasData = true;
            const div = document.createElement('div');
            div.className = 'exif-item';
            div.innerHTML = `
                <div class="label">${item.label}</div>
                <div class="value">${item.value}</div>
            `;
            exifGrid.appendChild(div);
        }
    });

    if (!hasData) {
        exifGrid.innerHTML = `
            <div class="no-exif">
                <p>⚠️ No EXIF data found in this image.</p>
                <p>EXIF data is typically preserved in JPEG images from cameras.</p>
            </div>
        `;
    }
}

// Format helpers
function formatFocalLength(fl) {
    if (!fl) return null;
    const value = typeof fl === 'object' ? fl.numerator / fl.denominator : fl;
    return `${Math.round(value)}mm`;
}

function formatAperture(ap) {
    if (!ap) return null;
    const value = typeof ap === 'object' ? ap.numerator / ap.denominator : ap;
    return `f/${value.toFixed(1)}`;
}

function formatShutterSpeed(ss) {
    if (!ss) return null;
    if (typeof ss === 'object') {
        const value = ss.numerator / ss.denominator;
        if (value < 1) {
            return `1/${Math.round(1 / value)}s`;
        }
        return `${value.toFixed(1)}s`;
    }
    if (ss < 1) {
        return `1/${Math.round(1 / ss)}s`;
    }
    return `${ss}s`;
}

function formatDateTime(dt) {
    if (!dt) return null;
    // EXIF date format: "YYYY:MM:DD HH:MM:SS"
    const parts = dt.split(' ');
    if (parts.length === 2) {
        const dateParts = parts[0].split(':');
        if (dateParts.length === 3) {
            return `${dateParts[0]}-${dateParts[1]}-${dateParts[2]} ${parts[1]}`;
        }
    }
    return dt;
}

function formatImageSize(w, h) {
    if (!w || !h) return null;
    return `${w} × ${h}`;
}

// Apply watermark to image
function applyWatermark() {
    if (!currentImage) return;

    const ctx = watermarkCanvas.getContext('2d');
    
    // Set canvas size to match image
    watermarkCanvas.width = currentImage.naturalWidth;
    watermarkCanvas.height = currentImage.naturalHeight;

    // Draw original image
    ctx.drawImage(currentImage, 0, 0);

    // Build watermark text
    const watermarkText = buildWatermarkText();
    
    if (watermarkText.length === 0) {
        return;
    }

    // Get settings
    const position = watermarkPosition.value;
    const style = watermarkStyle.value;
    const size = parseInt(fontSize.value);
    const alpha = parseFloat(opacity.value);
    const txtColor = textColor.value;
    const background = bgColor.value;

    // Apply watermark based on style
    ctx.save();
    ctx.globalAlpha = alpha;

    switch (style) {
        case 'minimal':
            drawMinimalWatermark(ctx, watermarkText, position, size, txtColor);
            break;
        case 'detailed':
            drawDetailedWatermark(ctx, watermarkText, position, size, txtColor, background);
            break;
        case 'badge':
            drawBadgeWatermark(ctx, watermarkText, position, size, txtColor, background);
            break;
    }

    ctx.restore();
}

function buildWatermarkText() {
    const lines = [];

    if (showCamera.checked && (exifData.make || exifData.model)) {
        const camera = [exifData.make, exifData.model].filter(Boolean).join(' ');
        lines.push(camera);
    }

    if (showLens.checked && exifData.lens) {
        lines.push(exifData.lens);
    }

    if (showSettings.checked) {
        const settings = [];
        if (exifData.focalLength) settings.push(formatFocalLength(exifData.focalLength));
        if (exifData.aperture) settings.push(formatAperture(exifData.aperture));
        if (exifData.shutterSpeed) settings.push(formatShutterSpeed(exifData.shutterSpeed));
        if (exifData.iso) settings.push(`ISO ${exifData.iso}`);
        
        if (settings.length > 0) {
            lines.push(settings.join(' | '));
        }
    }

    if (showDate.checked && exifData.dateTime) {
        lines.push(formatDateTime(exifData.dateTime));
    }

    return lines;
}

function getPosition(ctx, lines, position, size, padding) {
    const lineHeight = size * 1.4;
    const totalHeight = lines.length * lineHeight;
    
    // Calculate max width
    ctx.font = `${size}px 'Segoe UI', sans-serif`;
    const maxWidth = Math.max(...lines.map(line => ctx.measureText(line).width));

    let x, y;
    const margin = 40;

    switch (position) {
        case 'top-left':
            x = margin + padding;
            y = margin + padding + size;
            break;
        case 'top-right':
            x = watermarkCanvas.width - maxWidth - margin - padding;
            y = margin + padding + size;
            break;
        case 'bottom-left':
            x = margin + padding;
            y = watermarkCanvas.height - totalHeight - margin;
            break;
        case 'bottom-right':
            x = watermarkCanvas.width - maxWidth - margin - padding;
            y = watermarkCanvas.height - totalHeight - margin;
            break;
        case 'center':
            x = (watermarkCanvas.width - maxWidth) / 2;
            y = (watermarkCanvas.height - totalHeight) / 2 + size;
            break;
    }

    return { x, y, maxWidth, totalHeight, lineHeight };
}

function drawMinimalWatermark(ctx, lines, position, size, color) {
    const padding = 10;
    const pos = getPosition(ctx, lines, position, size, padding);

    ctx.font = `${size}px 'Segoe UI', sans-serif`;
    ctx.fillStyle = color;
    ctx.shadowColor = 'rgba(0, 0, 0, 0.8)';
    ctx.shadowBlur = 4;
    ctx.shadowOffsetX = 2;
    ctx.shadowOffsetY = 2;

    lines.forEach((line, i) => {
        ctx.fillText(line, pos.x, pos.y + i * pos.lineHeight);
    });
}

function drawDetailedWatermark(ctx, lines, position, size, color, bgColor) {
    const padding = 20;
    const pos = getPosition(ctx, lines, position, size, padding);

    // Draw background
    const bgX = pos.x - padding;
    const bgY = pos.y - size - padding / 2;
    const bgWidth = pos.maxWidth + padding * 2;
    const bgHeight = pos.totalHeight + padding;

    ctx.fillStyle = hexToRgba(bgColor, 0.7);
    roundRect(ctx, bgX, bgY, bgWidth, bgHeight, 10);
    ctx.fill();

    // Draw text
    ctx.font = `${size}px 'Segoe UI', sans-serif`;
    ctx.fillStyle = color;
    ctx.shadowColor = 'transparent';

    lines.forEach((line, i) => {
        ctx.fillText(line, pos.x, pos.y + i * pos.lineHeight);
    });
}

function drawBadgeWatermark(ctx, lines, position, size, color, bgColor) {
    const padding = 25;
    const pos = getPosition(ctx, lines, position, size, padding);

    // Draw badge background
    const bgX = pos.x - padding;
    const bgY = pos.y - size - padding / 2;
    const bgWidth = pos.maxWidth + padding * 2;
    const bgHeight = pos.totalHeight + padding;

    // Gradient background
    const gradient = ctx.createLinearGradient(bgX, bgY, bgX + bgWidth, bgY + bgHeight);
    gradient.addColorStop(0, hexToRgba(bgColor, 0.85));
    gradient.addColorStop(1, hexToRgba(bgColor, 0.95));

    ctx.fillStyle = gradient;
    roundRect(ctx, bgX, bgY, bgWidth, bgHeight, 15);
    ctx.fill();

    // Border
    ctx.strokeStyle = hexToRgba(color, 0.3);
    ctx.lineWidth = 2;
    roundRect(ctx, bgX, bgY, bgWidth, bgHeight, 15);
    ctx.stroke();

    // Camera icon (simple representation)
    const iconSize = size * 0.8;
    const iconX = pos.x - padding / 2;
    const iconY = pos.y - size * 0.3;
    
    ctx.fillStyle = color;
    ctx.font = `${iconSize}px Arial`;
    ctx.fillText('📷', iconX - iconSize - 10, iconY);

    // Draw text
    ctx.font = `bold ${size * 0.9}px 'Segoe UI', sans-serif`;
    ctx.fillStyle = color;

    lines.forEach((line, i) => {
        if (i === 0) {
            ctx.font = `bold ${size}px 'Segoe UI', sans-serif`;
        } else {
            ctx.font = `${size * 0.85}px 'Segoe UI', sans-serif`;
        }
        ctx.fillText(line, pos.x, pos.y + i * pos.lineHeight);
    });
}

// Utility functions
function roundRect(ctx, x, y, width, height, radius) {
    ctx.beginPath();
    ctx.moveTo(x + radius, y);
    ctx.lineTo(x + width - radius, y);
    ctx.quadraticCurveTo(x + width, y, x + width, y + radius);
    ctx.lineTo(x + width, y + height - radius);
    ctx.quadraticCurveTo(x + width, y + height, x + width - radius, y + height);
    ctx.lineTo(x + radius, y + height);
    ctx.quadraticCurveTo(x, y + height, x, y + height - radius);
    ctx.lineTo(x, y + radius);
    ctx.quadraticCurveTo(x, y, x + radius, y);
    ctx.closePath();
}

function hexToRgba(hex, alpha) {
    const r = parseInt(hex.slice(1, 3), 16);
    const g = parseInt(hex.slice(3, 5), 16);
    const b = parseInt(hex.slice(5, 7), 16);
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

// Download watermarked image
function downloadImage() {
    if (!currentImage) return;

    const link = document.createElement('a');
    link.download = 'watermarked-image.jpg';
    link.href = watermarkCanvas.toDataURL('image/jpeg', 0.95);
    link.click();
}

// Reset the app
function resetApp() {
    currentImage = null;
    exifData = {};
    fileInput.value = '';
    previewSection.style.display = 'none';
    exifSection.style.display = 'none';
    settingsSection.style.display = 'none';
    exifGrid.innerHTML = '';
    
    // Reset canvas
    const ctx = watermarkCanvas.getContext('2d');
    ctx.clearRect(0, 0, watermarkCanvas.width, watermarkCanvas.height);
    
    // Scroll to top
    window.scrollTo({ top: 0, behavior: 'smooth' });
}

// Show/hide loading overlay
function showLoading(show) {
    loadingOverlay.style.display = show ? 'flex' : 'none';
}

// Initialize
console.log('Image Watermark App initialized');
