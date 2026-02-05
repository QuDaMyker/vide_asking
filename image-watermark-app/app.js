// DOM Elements
const uploadArea = document.getElementById("uploadArea");
const fileInput = document.getElementById("fileInput");
const previewSection = document.getElementById("previewSection");
const exifSection = document.getElementById("exifSection");
const settingsSection = document.getElementById("settingsSection");
const originalImage = document.getElementById("originalImage");
const originalImageBlur = document.getElementById("originalImageBlur");
const watermarkCanvas = document.getElementById("watermarkCanvas");
const watermarkCanvasBlur = document.getElementById("watermarkCanvasBlur");
const exifGrid = document.getElementById("exifGrid");
const loadingOverlay = document.getElementById("loadingOverlay");
const cancelUploadBtn = document.getElementById("cancelUpload");

// Settings elements
const watermarkPosition = document.getElementById("watermarkPosition");
const watermarkStyle = document.getElementById("watermarkStyle");
const fontSize = document.getElementById("fontSize");
const fontSizeValue = document.getElementById("fontSizeValue");
const opacity = document.getElementById("opacity");
const opacityValue = document.getElementById("opacityValue");
const textColor = document.getElementById("textColor");
const bgColor = document.getElementById("bgColor");
const showDate = document.getElementById("showDate");
const showAuthor = document.getElementById("showAuthor");
const showCamera = document.getElementById("showCamera");
const showLens = document.getElementById("showLens");
const showSettings = document.getElementById("showSettings");
const authorNameInput = document.getElementById("authorName");
const applyWatermarkBtn = document.getElementById("applyWatermark");
const downloadBtn = document.getElementById("downloadImage");
const resetBtn = document.getElementById("resetImage");

// State
let currentImage = null;
let exifData = {};
let uploadCancelled = false;

// Event Listeners
uploadArea.addEventListener("click", () => fileInput.click());
uploadArea.addEventListener("dragover", handleDragOver);
uploadArea.addEventListener("dragleave", handleDragLeave);
uploadArea.addEventListener("drop", handleDrop);
fileInput.addEventListener("change", handleFileSelect);

fontSize.addEventListener("input", () => {
  fontSizeValue.textContent = `${fontSize.value}px`;
});

opacity.addEventListener("input", () => {
  opacityValue.textContent = `${Math.round(opacity.value * 100)}%`;
});

// Auto-apply watermark when settings change
[
  fontSize,
  opacity,
  textColor,
  bgColor,
  showDate,
  showAuthor,
  showCamera,
  showSettings,
].forEach((element) => {
  if (element) {
    element.addEventListener("change", () => {
      if (currentImage) applyWatermark();
    });
    if (element.type === "range" || element.type === "color") {
      element.addEventListener("input", () => {
        if (currentImage) applyWatermark();
      });
    }
  }
});

// Author name input auto-apply
if (authorNameInput) {
  authorNameInput.addEventListener("input", () => {
    if (currentImage) applyWatermark();
  });
}

applyWatermarkBtn.addEventListener("click", applyWatermark);
downloadBtn.addEventListener("click", downloadImage);
resetBtn.addEventListener("click", resetApp);
cancelUploadBtn.addEventListener("click", cancelUpload);

// Drag and Drop Handlers
function handleDragOver(e) {
  e.preventDefault();
  uploadArea.classList.add("dragover");
}

function handleDragLeave(e) {
  e.preventDefault();
  uploadArea.classList.remove("dragover");
}

function handleDrop(e) {
  e.preventDefault();
  uploadArea.classList.remove("dragover");
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
async function processFile(file) {
  console.log('processFile called with:', file.name);
  if (!file.type.startsWith("image/") && !isRawFile(file.name)) {
    alert("Please upload an image file.");
    return;
  }

  uploadCancelled = false;
  showLoading(true);
  console.log('Loading shown');

  // Upload to server first
  try {
    const formData = new FormData();
    formData.append('image', file);
    
    const uploadResponse = await fetch('/upload', {
      method: 'POST',
      body: formData
    });
    
    const uploadResult = await uploadResponse.json();
    if (uploadResult.success) {
      console.log('✅ Image saved to server:', uploadResult.path);
    } else {
      console.warn('⚠️ Server upload failed:', uploadResult.error);
    }
  } catch (error) {
    console.warn('⚠️ Server upload error (continuing anyway):', error.message);
    // Continue with watermarking even if server upload fails
  }

  const reader = new FileReader();
  reader.onload = async (e) => {
    console.log('FileReader loaded');
    if (uploadCancelled) {
      console.log('Upload cancelled in reader.onload');
      showLoading(false);
      return;
    }

    currentImage = new Image();
    currentImage.onload = async () => {
      console.log('Image loaded');
      if (uploadCancelled) {
        console.log('Upload cancelled in image.onload');
        showLoading(false);
        return;
      }
      displayImage();
      console.log('Extracting EXIF...');
      await extractExifData(file);
      console.log('EXIF extraction complete, hiding loading');
      showLoading(false); // Close loading after everything is done
    };
    
    currentImage.onerror = () => {
      console.error('Image failed to load');
      showLoading(false);
      alert('Failed to load image. Please try another file.');
    };
    
    currentImage.src = e.target.result;
  };
  
  reader.onerror = () => {
    console.error('FileReader error');
    showLoading(false);
    alert('Failed to read file.');
  };
  
  reader.readAsDataURL(file);
}

// Cancel upload
function cancelUpload() {
  console.log('Cancel button clicked');
  uploadCancelled = true;
  showLoading(false);
  fileInput.value = "";
  
  // Reset the image preview
  if (previewSection) {
    previewSection.style.display = "none";
  }
  if (settingsSection) {
    settingsSection.style.display = "none";
  }
}

function isRawFile(filename) {
  const rawExtensions = [
    ".raw",
    ".cr2",
    ".cr3",
    ".nef",
    ".arw",
    ".dng",
    ".orf",
    ".rw2",
    ".pef",
    ".srw",
  ];
  const ext = filename.toLowerCase().substring(filename.lastIndexOf("."));
  return rawExtensions.includes(ext);
}

// Display the image
function displayImage() {
  originalImage.src = currentImage.src;
  originalImageBlur.src = currentImage.src;
  previewSection.style.display = "block";
  settingsSection.style.display = "block";

  // Scroll to preview
  previewSection.scrollIntoView({ behavior: "smooth", block: "start" });
}

// Extract EXIF data using EXIF.js
function extractExifData(file) {
  console.log('extractExifData called');
  return new Promise((resolve) => {
    try {
      EXIF.getData(file, async function () {
        console.log('EXIF callback triggered');
        const allTags = EXIF.getAllTags(this);

        exifData = {
          make: EXIF.getTag(this, "Make") || "",
          model: EXIF.getTag(this, "Model") || "",
          lens:
            EXIF.getTag(this, "LensModel") || EXIF.getTag(this, "LensMake") || "",
          focalLength: EXIF.getTag(this, "FocalLength"),
          aperture:
            EXIF.getTag(this, "FNumber") || EXIF.getTag(this, "ApertureValue"),
          iso: EXIF.getTag(this, "ISOSpeedRatings") || EXIF.getTag(this, "ISO"),
          shutterSpeed: EXIF.getTag(this, "ExposureTime"),
          dateTime:
            EXIF.getTag(this, "DateTimeOriginal") || EXIF.getTag(this, "DateTime"),
          exposureBias:
            EXIF.getTag(this, "ExposureBias") ||
            EXIF.getTag(this, "ExposureBiasValue"),
          meteringMode: EXIF.getTag(this, "MeteringMode"),
          flash: EXIF.getTag(this, "Flash"),
          whiteBalance: EXIF.getTag(this, "WhiteBalance"),
          imageWidth:
            EXIF.getTag(this, "PixelXDimension") || EXIF.getTag(this, "ImageWidth"),
          imageHeight:
            EXIF.getTag(this, "PixelYDimension") ||
            EXIF.getTag(this, "ImageHeight"),
          software: EXIF.getTag(this, "Software"),
          artist: EXIF.getTag(this, "Artist"),
          copyright: EXIF.getTag(this, "Copyright"),
        };

        // Clean up make/model strings
        if (exifData.make) exifData.make = exifData.make.trim();
        if (exifData.model) {
          exifData.model = exifData.model.trim();
          // Remove make from model if it's duplicated
          if (
            exifData.make &&
            exifData.model.toUpperCase().startsWith(exifData.make.toUpperCase())
          ) {
            exifData.model = exifData.model.substring(exifData.make.length).trim();
          }
        }

        console.log('Displaying EXIF data');
        displayExifData();
        console.log('Applying watermark');
        applyWatermark();
        console.log('Watermark applied, resolving promise');
        resolve(); // Resolve the promise when done
      });
      
      // Fallback: If EXIF callback doesn't fire within 2 seconds, resolve anyway
      setTimeout(() => {
        console.log('EXIF timeout - resolving anyway');
        resolve();
      }, 2000);
    } catch (error) {
      console.error('Error in extractExifData:', error);
      resolve(); // Resolve even on error to prevent hanging
    }
  });
}

// Display EXIF data in the UI
function displayExifData() {
  exifGrid.innerHTML = "";
  exifSection.style.display = "block";

  const exifItems = [
    { label: "Camera Make", value: exifData.make },
    { label: "Camera Model", value: exifData.model },
    { label: "Lens", value: exifData.lens },
    { label: "Focal Length", value: formatFocalLength(exifData.focalLength) },
    { label: "Aperture", value: formatAperture(exifData.aperture) },
    { label: "ISO", value: exifData.iso },
    {
      label: "Shutter Speed",
      value: formatShutterSpeed(exifData.shutterSpeed),
    },
    { label: "Date/Time", value: formatDateTime(exifData.dateTime) },
    {
      label: "Image Size",
      value: formatImageSize(exifData.imageWidth, exifData.imageHeight),
    },
    { label: "Software", value: exifData.software },
    { label: "Artist", value: exifData.artist },
    { label: "Copyright", value: exifData.copyright },
  ];

  let hasData = false;

  exifItems.forEach((item) => {
    if (item.value && item.value !== "N/A") {
      hasData = true;
      const div = document.createElement("div");
      div.className = "exif-item";
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
  const value = typeof fl === "object" ? fl.numerator / fl.denominator : fl;
  return `${Math.round(value)}mm`;
}

function formatAperture(ap) {
  if (!ap) return null;
  const value = typeof ap === "object" ? ap.numerator / ap.denominator : ap;
  return `f/${value.toFixed(1)}`;
}

function formatShutterSpeed(ss) {
  if (!ss) return null;
  if (typeof ss === "object") {
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
  
  try {
    // EXIF date format: "YYYY:MM:DD HH:MM:SS"
    const parts = dt.split(" ");
    if (parts.length === 2) {
      const dateParts = parts[0].split(":");
      if (dateParts.length === 3) {
        // Create date string: "YYYY-MM-DD HH:MM:SS"
        const dateString = `${dateParts[0]}-${dateParts[1]}-${dateParts[2]} ${parts[1]}`;
        const date = new Date(dateString);
        
        // Check if date is valid
        if (isNaN(date.getTime())) {
          return dateString; // Return without timezone if invalid
        }
        
        // Format with local timezone
        const options = {
          year: 'numeric',
          month: '2-digit',
          day: '2-digit',
          hour: '2-digit',
          minute: '2-digit',
          hour12: false,
          timeZoneName: 'short'
        };
        
        const formatted = date.toLocaleString('en-US', options);
        // Convert: "02/03/2026, 16:50 GMT+7" → "2026-02-03 16:50 GMT+7"
        const match = formatted.match(/(\d{2})\/(\d{2})\/(\d{4}),?\s+(\d{2}:\d{2})\s*(.*)/);
        if (match) {
          return `${match[3]}-${match[1]}-${match[2]} ${match[4]} ${match[5]}`;
        }
        
        return formatted;
      }
    }
    return dt;
  } catch (error) {
    console.error('Error formatting date:', error);
    return dt;
  }
}

function formatImageSize(w, h) {
  if (!w || !h) return null;
  return `${w} × ${h}`;
}

// Apply watermark to image
function applyWatermark() {
  console.log('applyWatermark called');
  if (!currentImage) return;

  // Step 1: Draw FULL blurred background on watermarkCanvasBlur (for preview display)
  const ctxBlur = watermarkCanvasBlur.getContext("2d");
  watermarkCanvasBlur.width = currentImage.naturalWidth;
  watermarkCanvasBlur.height = currentImage.naturalHeight;

  ctxBlur.filter = "blur(30px)";
  ctxBlur.drawImage(
    currentImage,
    0,
    0,
    watermarkCanvasBlur.width,
    watermarkCanvasBlur.height,
  );
  ctxBlur.filter = "none";

  // Step 2: Draw complete image on watermarkCanvas (for download)
  const ctx = watermarkCanvas.getContext("2d");
  watermarkCanvas.width = currentImage.naturalWidth;
  watermarkCanvas.height = currentImage.naturalHeight;

  // Clear the canvas first
  ctx.clearRect(0, 0, watermarkCanvas.width, watermarkCanvas.height);

  // 2A. First draw blurred background (full size) on watermarkCanvas
  ctx.filter = "blur(30px)";
  ctx.drawImage(
    currentImage,
    0,
    0,
    watermarkCanvas.width,
    watermarkCanvas.height,
  );
  ctx.filter = "none";

  // 2B. Calculate centered position with 90% size for foreground
  const scaledWidth = watermarkCanvas.width * 0.9;
  const scaledHeight = watermarkCanvas.height * 0.9;
  const offsetX = (watermarkCanvas.width - scaledWidth) / 2;
  const offsetY = (watermarkCanvas.height - scaledHeight) / 2;

  // Define border radius (proportional to image size)
  const borderRadius = Math.min(scaledWidth, scaledHeight) * 0.02; // 2% of smallest dimension

  // 2C. Draw clear foreground image (90% centered) over the blurred background
  // Create rounded rectangle clipping path for the image
  ctx.save();
  roundRect(ctx, offsetX, offsetY, scaledWidth, scaledHeight, borderRadius);
  ctx.clip();

  // Draw clear image scaled to 90%
  ctx.drawImage(currentImage, offsetX, offsetY, scaledWidth, scaledHeight);

  ctx.restore();

  // 2D. Draw rounded border around the clear image
  ctx.save();
  const borderWidth = Math.max(3, watermarkCanvas.width * 0.0); // Responsive border width
  ctx.strokeStyle = "rgba(255, 255, 255, 0.3)";
  ctx.lineWidth = borderWidth;

  // Draw border with rounded corners
  roundRect(ctx, offsetX, offsetY, scaledWidth, scaledHeight, borderRadius);
  ctx.stroke();

  // Add subtle shadow for depth
  ctx.shadowColor = "rgba(0, 0, 0, 0.3)";
  ctx.shadowBlur = 15;
  ctx.shadowOffsetX = 0;
  ctx.shadowOffsetY = 5;
  roundRect(ctx, offsetX, offsetY, scaledWidth, scaledHeight, borderRadius);
  ctx.stroke();

  ctx.restore();

  // Step 3: Draw watermark bar IN THE GAP (below foreground, above background)
  const data = buildWatermarkBarData();
  
  // Skip if no data
  if (!data.dateTime && !data.author && !data.camera) {
    return;
  }
  
  // Draw single row watermark bar
  const settings = {
    fontSize: parseInt(fontSize.value),
    color: textColor.value,
    bgColor: bgColor.value,
    opacity: parseFloat(opacity.value)
  };
  
  // Pass canvas dimensions and foreground position for gap calculation
  console.log('Calling drawWatermarkBar...');
  drawWatermarkBar(ctx, data, offsetX, offsetY, scaledWidth, scaledHeight, watermarkCanvas.width, watermarkCanvas.height, settings);
  console.log('drawWatermarkBar returned');
}

// Draw single row watermark bar at bottom of image IN THE GAP
function drawWatermarkBar(ctx, data, foregroundX, foregroundY, foregroundWidth, foregroundHeight, canvasWidth, canvasHeight, settings) {
    console.log('drawWatermarkBar called with data:', data);
    const { fontSize, color, bgColor, opacity } = settings;
    
    // Calculate gap area
    // Foreground is 90% centered, so there's 5% gap on each side
    const foregroundBottom = foregroundY + foregroundHeight;
    const canvasBottom = canvasHeight;
    const gapHeight = canvasBottom - foregroundBottom; // This is the bottom gap
    
    // Bar dimensions
    const baseFontSize = Math.min(canvasWidth, canvasHeight) * 0.018 * (fontSize / 48);
    const barHeight = baseFontSize * 2.5;
    const padding = baseFontSize * 0.8;
    
    // Position bar in the center of the gap
    const barWidth = foregroundWidth; // Same width as foreground
    const barX = foregroundX; // Align with foreground
    const barY = foregroundBottom + (gapHeight - barHeight) / 2; // Center in gap
    const borderRadius = barHeight * 0.25;
    
    // Draw glassmorphism background
    ctx.save();
    ctx.globalAlpha = opacity;
    
    // Background
    ctx.fillStyle = hexToRgba(bgColor, 0.7);
    roundRect(ctx, barX, barY, barWidth, barHeight, borderRadius);
    ctx.fill();
    
    // Border
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.2)';
    ctx.lineWidth = 2;
    roundRect(ctx, barX, barY, barWidth, barHeight, borderRadius);
    ctx.stroke();
    
    // Draw content sections
    let currentX = barX + padding;
    const centerY = barY + barHeight / 2;
    const separatorWidth = baseFontSize * 0.6;
    
    ctx.textBaseline = 'middle';
    ctx.fillStyle = color;
    
    // 1. Date/Time (Left) - NO ICON
    if (data.dateTime) {
        ctx.font = `${baseFontSize}px 'Segoe UI', Arial, sans-serif`;
        const dateText = `${data.dateTime}`;
        ctx.textAlign = 'left';
        ctx.fillText(dateText, currentX, centerY);
        currentX += ctx.measureText(dateText).width + separatorWidth;
        
        // Separator
        ctx.fillStyle = 'rgba(255, 255, 255, 0.3)';
        ctx.fillText('|', currentX, centerY);
        currentX += ctx.measureText('|').width + separatorWidth;
        ctx.fillStyle = color;
    }
    
    // 2. Author (Center section) - NO ICON
    if (data.author) {
        ctx.font = `${baseFontSize}px 'Segoe UI', Arial, sans-serif`;
        const authorText = `${data.author}`;
        ctx.fillText(authorText, currentX, centerY);
        currentX += ctx.measureText(authorText).width + separatorWidth;
        
        // Separator
        ctx.fillStyle = 'rgba(255, 255, 255, 0.3)';
        ctx.fillText('|', currentX, centerY);
        currentX += ctx.measureText('|').width + separatorWidth;
        ctx.fillStyle = color;
    }
    
    // 3. Camera Info (Right section) - NO BRAND LOGO
    if (data.camera) {
        console.log('Drawing camera section:', data.camera);
        
        // Camera Make + Model (bold) - NO LOGO
        if (data.camera.brand || data.camera.model) {
            ctx.font = `bold ${baseFontSize}px 'Segoe UI', Arial, sans-serif`;
            const cameraText = [data.camera.brand, data.camera.model].filter(Boolean).join(' ');
            ctx.fillText(cameraText, currentX, centerY);
            currentX += ctx.measureText(cameraText).width + separatorWidth;
        }
        
        // Settings
        if (data.camera.settings && data.camera.settings.length > 0) {
            ctx.fillStyle = 'rgba(255, 255, 255, 0.3)';
            ctx.font = `${baseFontSize}px 'Segoe UI', Arial, sans-serif`;
            ctx.fillText('|', currentX, centerY);
            currentX += ctx.measureText('|').width + separatorWidth;
            
            ctx.fillStyle = color;
            ctx.font = `${baseFontSize * 0.95}px 'Segoe UI', Arial, sans-serif`;
            const settingsText = data.camera.settings.join(' ');
            ctx.fillText(settingsText, currentX, centerY);
        }
    }
    
    console.log('Watermark bar drawn successfully');
    ctx.restore();
}

// OLD FUNCTIONS BELOW - Keep for reference, can be removed later

// Draw badge watermark in the gap between foreground and background
function drawBadgeWatermarkInGap(
  ctx,
  lines,
  size,
  color,
  bgColor,
  foregroundBottom,
  gapSpace,
) {
  const padding = 20;
  const lineHeight = size * 1.3;

  ctx.font = `bold ${size}px 'Segoe UI', Arial, sans-serif`;

  // Get brand logo
  const brandLogo = getBrandLogo(exifData.make);
  const logoSize = size * 1.5;

  // Calculate dimensions for horizontal layout
  const textWidths = lines.map((line) => ctx.measureText(line).width);
  const maxTextWidth = Math.max(...textWidths);
  const totalWidth = logoSize + maxTextWidth + padding * 3;
  const totalHeight =
    Math.max(logoSize, lines.length * lineHeight) + padding * 2;

  // Define border radius for watermark badge
  const badgeRadius = Math.min(totalWidth, totalHeight) * 0.15; // 15% of smallest dimension

  // Center horizontally, position in the gap
  const x = (watermarkCanvas.width - totalWidth) / 2;
  const y = foregroundBottom + (gapSpace - totalHeight) / 2;

  // Draw glassmorphism background with rounded corners
  ctx.save();
  ctx.fillStyle = "rgba(255, 255, 255, 0.1)";
  roundRect(ctx, x, y, totalWidth, totalHeight, badgeRadius);
  ctx.fill();

  // Semi-transparent dark background
  ctx.fillStyle = hexToRgba(bgColor, 0.6);
  roundRect(ctx, x, y, totalWidth, totalHeight, badgeRadius);
  ctx.fill();

  // Glass border effect
  ctx.strokeStyle = "rgba(255, 255, 255, 0.2)";
  ctx.lineWidth = 1.5;
  roundRect(ctx, x, y, totalWidth, totalHeight, badgeRadius);
  ctx.stroke();
  ctx.restore();

  // Draw brand logo/icon
  const logoX = x + padding;
  const logoY = y + totalHeight / 2;

  if (brandLogo) {
    drawBrandLogo(ctx, brandLogo, logoX, logoY, logoSize, color);
  } else {
    // Fallback to camera emoji
    ctx.fillStyle = color;
    ctx.font = `${logoSize}px Arial`;
    ctx.textBaseline = "middle";
    ctx.fillText("📷", logoX, logoY);
  }

  // Draw text lines
  const textX = logoX + logoSize + padding / 2;
  let textY = y + padding + size * 0.7;

  ctx.textBaseline = "top";
  lines.forEach((line, i) => {
    if (i === 0) {
      ctx.font = `bold ${size}px 'Segoe UI', Arial, sans-serif`;
    } else {
      ctx.font = `${size * 0.85}px 'Segoe UI', Arial, sans-serif`;
    }
    ctx.fillStyle = color;
    ctx.fillText(line, textX, textY + i * lineHeight);
  });

  ctx.textBaseline = "alphabetic";
}

function drawMinimalWatermarkInGap(
  ctx,
  lines,
  size,
  color,
  foregroundBottom,
  gapSpace,
) {
  const padding = 10;
  const lineHeight = size * 1.4;

  ctx.font = `${size}px 'Segoe UI', sans-serif`;
  const textWidths = lines.map((line) => ctx.measureText(line).width);
  const maxTextWidth = Math.max(...textWidths);
  const totalHeight = lines.length * lineHeight;

  const x = (watermarkCanvas.width - maxTextWidth) / 2;
  const y = foregroundBottom + (gapSpace - totalHeight) / 2 + size;

  ctx.fillStyle = color;
  ctx.shadowColor = "rgba(0, 0, 0, 0.8)";
  ctx.shadowBlur = 4;
  ctx.shadowOffsetX = 2;
  ctx.shadowOffsetY = 2;

  lines.forEach((line, i) => {
    const lineWidth = ctx.measureText(line).width;
    const lineX = (watermarkCanvas.width - lineWidth) / 2;
    ctx.fillText(line, lineX, y + i * lineHeight);
  });
}

function drawDetailedWatermarkInGap(
  ctx,
  lines,
  size,
  color,
  bgColor,
  foregroundBottom,
  gapSpace,
) {
  const padding = 20;
  const lineHeight = size * 1.4;

  ctx.font = `${size}px 'Segoe UI', sans-serif`;
  const textWidths = lines.map((line) => ctx.measureText(line).width);
  const maxTextWidth = Math.max(...textWidths);
  const totalHeight = lines.length * lineHeight + padding;
  const totalWidth = maxTextWidth + padding * 2;

  const x = (watermarkCanvas.width - totalWidth) / 2;
  const y = foregroundBottom + (gapSpace - totalHeight) / 2;

  // Draw background
  ctx.fillStyle = hexToRgba(bgColor, 0.7);
  roundRect(ctx, x, y, totalWidth, totalHeight, 10);
  ctx.fill();

  // Draw text
  ctx.fillStyle = color;
  ctx.shadowColor = "transparent";

  const textX = x + padding;
  let textY = y + padding + size * 0.7;

  lines.forEach((line, i) => {
    ctx.fillText(line, textX, textY + i * lineHeight);
  });
}

// Build unified watermark bar data
function buildWatermarkBarData() {
    const data = {
        dateTime: null,
        author: null,
        camera: null
    };
    
    // 1. Date/Time
    if (showDate.checked && exifData.dateTime) {
        data.dateTime = formatDateTime(exifData.dateTime);
    }
    
    // 2. Author
    if (showAuthor.checked) {
        const authorText = authorNameInput.value.trim();
        if (authorText) {
            data.author = authorText;
        }
    }
    
    // 3. Camera Info
    if (showCamera.checked || showSettings.checked) {
        data.camera = {
            brand: null,
            model: null,
            logo: null,
            settings: []
        };
        
        if (showCamera.checked) {
            if (exifData.make) {
                data.camera.brand = exifData.make.toUpperCase();
                data.camera.logo = getBrandLogo(exifData.make);
            }
            if (exifData.model) {
                data.camera.model = exifData.model;
            }
        }
        
        if (showSettings.checked) {
            // Order: Focal Length, Aperture, Shutter Speed (NO ISO in watermark)
            if (exifData.focalLength) {
                data.camera.settings.push(formatFocalLength(exifData.focalLength));
            }
            if (exifData.aperture) {
                data.camera.settings.push(formatAperture(exifData.aperture));
            }
            if (exifData.shutterSpeed) {
                data.camera.settings.push(formatShutterSpeed(exifData.shutterSpeed));
            }
        }
        
        // If no camera data, set to null
        if (!data.camera.brand && !data.camera.model && data.camera.settings.length === 0) {
            data.camera = null;
        }
    }
    
    return data;
}

function getPosition(ctx, lines, position, size, padding) {
  const lineHeight = size * 1.4;
  const totalHeight = lines.length * lineHeight;

  // Calculate max width
  ctx.font = `${size}px 'Segoe UI', sans-serif`;
  const maxWidth = Math.max(
    ...lines.map((line) => ctx.measureText(line).width),
  );

  let x, y;
  const margin = 40;

  switch (position) {
    case "top-left":
      x = margin + padding;
      y = margin + padding + size;
      break;
    case "top-right":
      x = watermarkCanvas.width - maxWidth - margin - padding;
      y = margin + padding + size;
      break;
    case "bottom-left":
      x = margin + padding;
      y = watermarkCanvas.height - totalHeight - margin;
      break;
    case "bottom-right":
      x = watermarkCanvas.width - maxWidth - margin - padding;
      y = watermarkCanvas.height - totalHeight - margin;
      break;
    case "center":
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
  ctx.shadowColor = "rgba(0, 0, 0, 0.8)";
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
  ctx.shadowColor = "transparent";

  lines.forEach((line, i) => {
    ctx.fillText(line, pos.x, pos.y + i * pos.lineHeight);
  });
}

function drawBadgeWatermark(ctx, lines, position, size, color, bgColor) {
  const padding = 30;

  // Recalculate position for badge style (more horizontal layout)
  const lineHeight = size * 1.3;
  ctx.font = `bold ${size}px 'Segoe UI', Arial, sans-serif`;

  // Get brand logo
  const brandLogo = getBrandLogo(exifData.make);
  const logoSize = size * 1.5;

  // Calculate dimensions for horizontal layout
  const textWidths = lines.map((line) => ctx.measureText(line).width);
  const maxTextWidth = Math.max(...textWidths);
  const totalWidth = logoSize + maxTextWidth + padding * 3;
  const totalHeight =
    Math.max(logoSize, lines.length * lineHeight) + padding * 2;

  // Position based on setting
  let x, y;
  const margin = 40;

  switch (position) {
    case "top-left":
      x = margin;
      y = margin;
      break;
    case "top-right":
      x = watermarkCanvas.width - totalWidth - margin;
      y = margin;
      break;
    case "bottom-left":
      x = margin;
      y = watermarkCanvas.height - totalHeight - margin;
      break;
    case "bottom-right":
      x = watermarkCanvas.width - totalWidth - margin;
      y = watermarkCanvas.height - totalHeight - margin;
      break;
    case "bottom-center":
      x = (watermarkCanvas.width - totalWidth) / 2;
      y = watermarkCanvas.height - totalHeight - margin;
      break;
    case "center":
      x = (watermarkCanvas.width - totalWidth) / 2;
      y = (watermarkCanvas.height - totalHeight) / 2;
      break;
  }

  // Draw glassmorphism background
  // Blur effect behind badge
  ctx.save();
  ctx.fillStyle = "rgba(255, 255, 255, 0.1)";
  roundRect(ctx, x, y, totalWidth, totalHeight, 16);
  ctx.fill();

  // Semi-transparent dark background
  ctx.fillStyle = hexToRgba(bgColor, 0.6);
  roundRect(ctx, x, y, totalWidth, totalHeight, 16);
  ctx.fill();

  // Glass border effect
  ctx.strokeStyle = "rgba(255, 255, 255, 0.2)";
  ctx.lineWidth = 1.5;
  roundRect(ctx, x, y, totalWidth, totalHeight, 16);
  ctx.stroke();
  ctx.restore();

  // Draw brand logo/icon
  const logoX = x + padding;
  const logoY = y + totalHeight / 2;

  if (brandLogo) {
    drawBrandLogo(ctx, brandLogo, logoX, logoY, logoSize, color);
  } else {
    // Fallback to camera emoji
    ctx.fillStyle = color;
    ctx.font = `${logoSize}px Arial`;
    ctx.textBaseline = "middle";
    ctx.fillText("📷", logoX, logoY);
  }

  // Draw text lines
  const textX = logoX + logoSize + padding / 2;
  let textY = y + padding + size * 0.7;

  ctx.textBaseline = "top";
  lines.forEach((line, i) => {
    if (i === 0) {
      // Camera model - larger and bold
      ctx.font = `bold ${size}px 'Segoe UI', Arial, sans-serif`;
    } else {
      // Other info - slightly smaller
      ctx.font = `${size * 0.85}px 'Segoe UI', Arial, sans-serif`;
    }
    ctx.fillStyle = color;
    ctx.fillText(line, textX, textY + i * lineHeight);
  });

  ctx.textBaseline = "alphabetic"; // Reset
}

// Get brand logo based on camera make
function getBrandLogo(make) {
  if (!make) return null;

  const makeLower = make.toLowerCase();

  if (makeLower.includes("canon")) return "CANON";
  if (makeLower.includes("nikon")) return "NIKON";
  if (makeLower.includes("sony")) return "SONY";
  if (makeLower.includes("fuji")) return "FUJIFILM";
  if (makeLower.includes("olympus")) return "OLYMPUS";
  if (makeLower.includes("panasonic")) return "PANASONIC";
  if (makeLower.includes("leica")) return "LEICA";
  if (makeLower.includes("pentax")) return "PENTAX";
  if (makeLower.includes("hasselblad")) return "HASSELBLAD";
  if (makeLower.includes("samsung")) return "SAMSUNG";
  if (makeLower.includes("xiaomi")) return "XIAOMI";
  if (makeLower.includes("apple")) return "APPLE";
  if (makeLower.includes("huawei")) return "HUAWEI";
  if (makeLower.includes("google")) return "GOOGLE";

  return null;
}

// Draw brand logo
function drawBrandLogo(ctx, brand, x, y, size, color) {
  ctx.save();
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillStyle = color;

  switch (brand) {
    case "CANON":
      // Canon red badge style
      ctx.fillStyle = "#CC0000";
      ctx.beginPath();
      ctx.arc(x + size / 2, y, size * 0.4, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#FFFFFF";
      ctx.font = `bold ${size * 0.25}px Arial`;
      ctx.fillText("C", x + size / 2, y);
      break;

    case "NIKON":
      // Nikon yellow badge
      ctx.fillStyle = "#FFD700";
      roundRect(ctx, x, y - size * 0.3, size * 0.9, size * 0.6, 4);
      ctx.fill();
      ctx.fillStyle = "#000000";
      ctx.font = `bold ${size * 0.25}px Arial`;
      ctx.fillText("N", x + size * 0.45, y);
      break;

    case "SONY":
      // Sony minimalist
      ctx.fillStyle = color;
      ctx.font = `bold ${size * 0.5}px Arial`;
      ctx.fillText("α", x + size / 2, y);
      break;

    case "FUJIFILM":
      // Fujifilm red box
      ctx.fillStyle = "#E60012";
      roundRect(ctx, x, y - size * 0.35, size * 0.9, size * 0.7, 2);
      ctx.fill();
      ctx.fillStyle = "#FFFFFF";
      ctx.font = `bold ${size * 0.25}px Arial`;
      ctx.fillText("F", x + size * 0.45, y);
      break;

    case "LEICA":
      // Leica red dot
      ctx.fillStyle = "#FF0000";
      ctx.beginPath();
      ctx.arc(x + size / 2, y, size * 0.4, 0, Math.PI * 2);
      ctx.fill();
      break;

    case "SAMSUNG":
      // Samsung blue
      ctx.fillStyle = "#1428A0";
      ctx.beginPath();
      ctx.arc(x + size / 2, y, size * 0.4, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#FFFFFF";
      ctx.font = `bold ${size * 0.3}px Arial`;
      ctx.fillText("S", x + size / 2, y);
      break;

    case "XIAOMI":
      // Xiaomi orange
      ctx.fillStyle = "#FF6900";
      roundRect(ctx, x, y - size * 0.4, size * 0.9, size * 0.8, 8);
      ctx.fill();
      ctx.fillStyle = "#FFFFFF";
      ctx.font = `bold ${size * 0.35}px Arial`;
      ctx.fillText("Mi", x + size * 0.45, y);
      break;

    case "APPLE":
      // Apple icon
      ctx.fillStyle = color;
      ctx.font = `${size * 0.6}px Arial`;
      ctx.fillText("", x + size / 2, y);
      break;

    default:
      // Generic camera icon
      ctx.fillStyle = color;
      ctx.font = `${size * 0.7}px Arial`;
      ctx.fillText("📷", x + size / 2, y);
  }

  ctx.restore();
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

  const link = document.createElement("a");
  link.download = "watermarked-image.jpg";
  link.href = watermarkCanvas.toDataURL("image/jpeg", 0.95);
  link.click();
}

// Reset the app
function resetApp() {
  currentImage = null;
  exifData = {};
  fileInput.value = "";
  uploadCancelled = false;
  previewSection.style.display = "none";
  exifSection.style.display = "none";
  settingsSection.style.display = "none";
  exifGrid.innerHTML = "";

  // Reset canvases
  const ctx = watermarkCanvas.getContext("2d");
  ctx.clearRect(0, 0, watermarkCanvas.width, watermarkCanvas.height);
  const ctxBlur = watermarkCanvasBlur.getContext("2d");
  ctxBlur.clearRect(
    0,
    0,
    watermarkCanvasBlur.width,
    watermarkCanvasBlur.height,
  );

  // Scroll to top
  window.scrollTo({ top: 0, behavior: "smooth" });
}

// Show/hide loading overlay
function showLoading(show) {
  loadingOverlay.style.display = show ? "flex" : "none";
}

// Initialize
console.log("Image Watermark App initialized");

// Load saved author name from localStorage
function loadAuthorName() {
    const savedAuthor = localStorage.getItem('watermark_author');
    if (savedAuthor && authorNameInput) {
        authorNameInput.value = savedAuthor;
    }
}

// Save author name to localStorage
function saveAuthorName() {
    const author = authorNameInput.value.trim();
    if (author) {
        localStorage.setItem('watermark_author', author);
    } else {
        localStorage.removeItem('watermark_author');
    }
}

// Load author name on page load
window.addEventListener('DOMContentLoaded', loadAuthorName);

// Save author name when user changes it
if (authorNameInput) {
    authorNameInput.addEventListener('blur', saveAuthorName);
}
