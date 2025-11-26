# Finchron - Smart Finance Tracker

> A comprehensive Flutter finance app with AI assistance, real-time analytics, and secure cloud/local storage.

[![Flutter](https://img.shields.io/badge/Flutter-3.8.1+-blue.svg)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Integrated-orange.svg)](https://firebase.google.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Features

### **Financial Management**
- **Expense Tracking** - Add, edit, categorize transactions with 14+ categories
- **Income Management** - Track salary, freelance, investments, gifts
- **Visual Analytics** - Interactive charts, trends, category breakdowns
- **Budget Insights** - Smart spending analysis and recommendations

### **AI-Powered Assistant**
- **Google Gemini AI** - Personalized financial advice
- **Smart Insights** - Spending pattern analysis
- **Budget Recommendations** - AI-driven financial planning
- **Natural Queries** - Ask questions about your finances

### **Authentication & Security**
- **Firebase Auth** - Google Sign-In, email/password
- **Profile Management** - Editable profiles with image upload
- **Data Privacy** - Secure cloud storage with local fallbacks
- **Multi-Platform** - Android, iOS, Web, Desktop

### **Advanced Analytics**
- **Interactive Charts** - Income vs expense visualization
- **Category Analysis** - Detailed spending breakdowns
- **Trend Analysis** - Daily, monthly, yearly patterns
- **Comparative Insights** - Period-over-period analysis

### **Data Management**
- **Cloud Sync** - Real-time Firestore synchronization
- **Offline Support** - Local SQLite with smart sync
- **Import/Export** - CSV, Excel file support
- **Data Backup** - Automatic cloud backup

## Tech Stack

### **Frontend (Flutter)**
```yaml
flutter: 3.8.1+
state_management: flutter_bloc
charts: fl_chart
auth: firebase_auth, google_sign_in
ai: google_generative_ai
storage: cloud_firestore, shared_preferences
ui: material_design, custom_themes
image_handling: image_picker, firebase_storage
```

### **Backend (TypeScript)**
```json
{
  "framework": "express.js",
  "database": "sqlite3",
  "auth": "jwt + bcrypt",
  "security": "helmet, cors, rate-limiting",
  "logging": "custom logger"
}
```

### **Cloud Services**
- **Firebase**: Auth, Firestore, Analytics, Storage
- **Google AI**: Gemini for financial assistance
- **Real-time**: Live data synchronization

## Quick Start

### Prerequisites
- Flutter SDK 3.8.1+
- Node.js 16+
- Firebase project

### **Run the App**
```bash
# Clone repository
git clone <repository-url>
cd finchron_app

# Install dependencies
flutter pub get

# Run app
flutter run
```

### **Backend Setup**
```bash
cd backend
npm install
npm run dev  # Starts on http://localhost:3000
```

### **Firebase Configuration**
1. Create Firebase project
2. Enable Authentication & Firestore
3. Add config files:
   - Android: `google-services.json` → `android/app/`
   - iOS: `GoogleService-Info.plist` → `ios/Runner/`

## Project Structure

```
finchron/
├── finchron_app/          # Flutter Mobile App
│   ├── lib/
│   │   ├── bloc/          # State Management (BLoC)
│   │   ├── models/        # Data Models
│   │   ├── screens/       # UI Screens
│   │   │   ├── dashboard_screen.dart
│   │   │   ├── analytics_screen.dart
│   │   │   ├── profile_edit_screen.dart
│   │   │   └── ai_assistant_screen.dart
│   │   ├── services/      # Business Logic
│   │   │   ├── profile_service.dart
│   │   │   ├── image_service.dart
│   │   │   └── firestore_service.dart
│   │   ├── themes/        # App Theming
│   │   └── widgets/       # Reusable Components
│   └── pubspec.yaml
├── backend/               # TypeScript API
│   ├── src/
│   │   ├── controllers/      # Request Handlers
│   │   ├── database/         # Database Layer
│   │   ├── middleware/       # Security & Auth
│   │   └── routes/           # API Endpoints
│   └── package.json
└── docs/                  # Documentation
```

## Key Screens

### **Dashboard**
- Real-time balance overview
- Quick action buttons
- Recent transactions
- Spending charts
- Profile image display

### **Analytics**
- **Overview**: Income/expense comparison
- **Categories**: Spending breakdowns
- **Trends**: Time-based analysis

### **Profile Management**
- Editable user profiles
- **Image Upload**: Camera/gallery with fallback storage
- Password management
- Account deletion

### **AI Assistant**
- Chat interface with Gemini AI
- Financial advice and insights
- Budget recommendations

## Development

### **Mobile Commands**
```bash
flutter pub get              # Install dependencies
flutter run                  # Development server
flutter build apk --release  # Production build
flutter test                 # Run tests
flutter analyze             # Code analysis
```

### **Backend Commands**
```bash
npm install       # Install dependencies
npm run dev      # Development with hot reload
npm run build    # Production build
npm test         # Run tests
npm run lint     # Code linting
```

## Recent Features

### **Image Upload System**
- **Multi-source**: Camera, gallery, network images
- **Smart Fallback**: Firebase Storage → Firestore base64
- **Error Handling**: Graceful degradation
- **Shared Service**: Consistent across all screens

### **Enhanced Security**
- Firebase Storage integration
- Secure image handling
- Profile data protection
- Error recovery mechanisms

### **UI Improvements**
- Modern Material Design
- Dark/light theme support
- Responsive layouts
- Loading states & animations

## Categories

### **Income**
- Salary, Freelance, Investment, Gift

### **Expenses**
- Food & Dining, Transportation, Shopping
- Entertainment, Health, Education, Travel
- Utilities, Groceries, Others

## Status

| Feature | Status | Notes |
|---------|--------|-------|
| Core App | ✅ Complete | Fully functional |
| Authentication | ✅ Complete | Firebase + Google |
| Analytics | ✅ Complete | Interactive charts |
| AI Assistant | ✅ Complete | Gemini integration |
| Image Upload | ✅ Complete | With fallback system |
| Data Sync | ✅ Complete | Cloud + local storage |
| Multi-platform | ✅ Complete | Android, iOS, Web |

## Contributing

1. **Fork** the repository
2. **Create** feature branch (`feature/amazing-feature`)
3. **Commit** changes (`Add amazing feature`)
4. **Push** to branch
5. **Open** Pull Request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Support

- **Issues**: [GitHub Issues](../../issues)
- **Docs**: Check `FIRESTORE_INTEGRATION.md`
- **Discussions**: [GitHub Discussions](../../discussions)

## Roadmap

### **Next Version**
- [ ] Budget planning & tracking
- [ ] Bill reminders
- [ ] Investment tracking
- [ ] Multi-currency support
- [ ] Family expense sharing
- [ ] Advanced AI insights

---

**Version**: 1.0.0 | **Flutter**: 3.8.1+ | **Last Updated**: August 27, 2025

*Built using Flutter, Firebase, and Google AI*