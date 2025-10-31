# Open WebUI Custom Branding

## Logo Specifications

### Favicon
- **Size**: 32x32 pixels
- **Format**: PNG or ICO
- **Location**: Mount to `/app/backend/static/favicon.png` in container
- **Transparency**: Recommended

### Main Logo
- **Size**: 512x512 pixels (or larger, will scale)
- **Format**: PNG with transparency or SVG
- **Location**: Mount to `/app/backend/static/logo.png` in container
- **Usage**: Displayed in header and login page

### Dark Mode Logo (Optional)
- **Size**: Same as main logo
- **Format**: PNG with transparency or SVG
- **Location**: Mount to `/app/backend/static/logo-dark.png` in container
- **Usage**: Automatically used in dark mode

## How to Add Your Logos

1. Place your logo files in `configs/open-webui/` directory:
   ```
   configs/open-webui/
   ├── favicon.png (32x32)
   ├── logo.png (512x512)
   └── logo-dark.png (optional)
   ```

2. Logos will be automatically mounted when you start the stack

3. Clear your browser cache after updating logos

## Environment Variables

You can also customize the application name in `.env`:
```bash
OPEN_WEBUI_NAME="Your Custom Name"
```

This name appears in the browser tab and header.
