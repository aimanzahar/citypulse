# FixMate Dashboard

A modern, responsive dashboard for managing civic issue reports with an interactive map interface.

## Features

- **Interactive Map**: View reported issues on an interactive Leaflet map with clustering
- **Advanced Filtering**: Filter by category, severity, status, and date range
- **Real-time Updates**: Live status updates and filtering
- **Responsive Design**: Works seamlessly on desktop, tablet, and mobile devices
- **Modern UI**: Clean, professional interface with smooth animations
- **Accessibility**: Keyboard navigation and screen reader friendly
- **Multi-language**: Support for English and Bahasa Malaysia

## UI Improvements Made

### 🎨 Modern Design System
- **Color Palette**: Updated with modern semantic colors and CSS custom properties
- **Typography**: Inter font family for better readability
- **Spacing**: Consistent spacing system using CSS custom properties
- **Shadows**: Subtle shadows and depth for better visual hierarchy

### 🔧 Enhanced Components
- **Header**: Modern sticky header with improved branding and language selector
- **Filter Panel**: Organized filter groups with hover states and better visual feedback
- **Ticket Cards**: Modern card design with hover effects and improved typography
- **Map Container**: Better map styling with loading states and empty state handling
- **Detail Drawer**: Slide-out drawer with improved layout and actions

### 📱 Responsive Design
- **Mobile-first**: Optimized layouts for mobile, tablet, and desktop
- **Flexible Grid**: CSS Grid layout that adapts to screen size
- **Touch-friendly**: Larger touch targets for mobile interactions

### ⚡ Performance & UX
- **Loading States**: Skeleton screens and loading indicators
- **Smooth Animations**: CSS transitions for better user experience
- **Error Handling**: Better error states and retry mechanisms
- **Offline Support**: Graceful handling when backend is unavailable

## Technology Stack

- **Frontend**: React 18, JavaScript ES6+
- **Styling**: Modern CSS with custom properties (CSS variables)
- **Maps**: Leaflet with marker clustering
- **Build**: No build process - runs directly in browser
- **Fonts**: Google Fonts (Inter)

## Getting Started

1. **Start the Backend**:
   ```bash
   cd backend
   python main.py
   ```

2. **Open the Dashboard**:
   Open `index.html` in your web browser, or serve it with a local server:
   ```bash
   # Using Python
   python -m http.server 8000

   # Using Node.js
   npx serve .
   ```

3. **Access**: Navigate to `http://localhost:8000/dashboard/`

## Project Structure

```
dashboard/
├── index.html          # Main HTML file
├── styles.css          # Modern CSS styles
├── app.js              # React application
├── i18n/               # Internationalization files
│   ├── en.json
│   └── ms.json
└── data/
    └── demo-reports.json # Sample data for testing
```

## Key Features

### Map View
- Interactive Leaflet map with OpenStreetMap tiles
- Clustered markers for better performance
- Click markers to view details
- Heatmap overlay option

### Filtering System
- Category filtering (pothole, streetlight, signage, etc.)
- Severity levels (high, medium, low)
- Status tracking (submitted, in progress, fixed)
- Date range filtering

### Ticket Management
- View all reported issues in a scrollable list
- Click to navigate to location on map
- Update status directly from the list
- Detailed view in slide-out drawer

### Responsive Breakpoints
- Desktop: 1200px+
- Tablet: 900px - 1200px
- Mobile: 600px - 900px
- Small Mobile: < 600px

## Customization

The design system is built with CSS custom properties, making it easy to customize:

```css
:root {
  --primary-500: #0ea5a4;    /* Main brand color */
  --severity-high: #dc2626;  /* High priority color */
  --spacing-4: 1rem;         /* Base spacing unit */
  --radius: 0.5rem;          /* Border radius */
}
```

## Browser Support

- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

## License

This project is part of the FixMate civic engagement platform.
