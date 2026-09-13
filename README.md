# 🎵 DOLCE Music Player

**DOLCE** is a modern, high-performance music streaming application built with **React 18**, **Vite**, **Tailwind CSS**, **Zustand**, **Dexie (IndexedDB)**, and **Capacitor 6** for Native Android. Designed with a dark glassmorphism aesthetic, Plus Jakarta Sans typography, and instant 0ms playback transitions, DOLCE brings a sweet, seamless listening experience across Web, Desktop, and Android devices.

---

## ✨ Features

- **🚀 Ultra-Fast Catalog & Search Engine**: Multi-pass resolution for Tracks, Albums, Playlists, and Artists with priority ranking for Indian & Telugu music hits.
- **📱 Native Android Background Audio**: Continuous audio playback when the phone screen is locked or when switching apps, running until the app is swiped away from recent apps.
- **🔒 Android MediaSession Lock Screen Controls**: System media notification integration displaying Song Title, Artist, Cover Artwork, Play, Pause, Next, Previous, and Seek controls.
- **💾 Offline Library & Playlists**:
  - Save full playlists and albums directly into **Your Library**.
  - Like favorite tracks and download songs offline using **Dexie IndexedDB** storage.
- **♾️ Infinite Auto-Queue**: Automatically fetches related tracks and radio recommendations when nearing the end of your queue.
- **🔄 Persistent Player State**: Last played song, playback timestamp, queue, and volume persist seamlessly across app restarts.
- **🎤 Synchronized Lyrics**: Real-time line-by-line synced lyrics display with custom typography presets.
- **🎨 Dynamic Glassmorphism UI**: Real-time color palette extraction from cover artwork with smooth Framer Motion animations.

---

## 🛠️ Technology Stack

- **Frontend Core**: React 18, Vite 5, JavaScript (ESNext)
- **Styling**: Tailwind CSS v3, Custom Glassmorphic Design System, Plus Jakarta Sans
- **State Management**: Zustand 5 (with `persist` middleware)
- **Storage**: Dexie.js (IndexedDB wrapper) for offline tracks, history, and playlists
- **Animations & Icons**: Framer Motion 11, Lucide React Icons
- **Native Android Wrapper**: Capacitor 6 (`@capacitor/android`, `@capacitor/core`, `@capacitor/cli`)

---

## 📁 Project Structure

```
musicplayer/
├── android/               # Native Android Studio Project (Capacitor 6)
├── api/                   # Serverless Vercel API Handlers
├── public/                # Static Public Assets & Favicon
├── src/
│   ├── components/        # UI Components (PlayerBar, TrackCard, CollectionModal, GlassDrawer, etc.)
│   ├── pages/             # Page Views (Home, Search, Library, TasteProfile)
│   ├── services/          # Audio Engine, Catalog API, Dexie DB, MediaSession
│   ├── store/             # Zustand State Stores (usePlayerStore, useSearchStore)
│   ├── styles/            # Global Tailwind & Custom Glassmorphism CSS
│   ├── App.jsx            # App Layout & Navigation Router
│   └── main.jsx           # App Entry Point
├── capacitor.config.json  # Capacitor App Configuration
├── package.json           # Dependencies & Scripts
├── tailwind.config.js     # Tailwind CSS Config
├── vite.config.js         # Vite Configuration
└── README.md              # Project Documentation
```

---

## ⚡ Getting Started

### Prerequisites
- **Node.js**: v18.x or higher
- **npm**: v9.x or higher
- **Android Studio**: (Optional, for building native Android APK)

### 1. Clone & Install Dependencies
```bash
git clone https://github.com/GaneshPulikanti/DOLCE.git
cd DOLCE
npm install
```

### 2. Run Development Server
```bash
npm run dev
```
Open `http://localhost:5173` in your browser.

### 3. Build Web Bundle
```bash
npm run build
```

---

## 📱 Native Android Build & Capacitor Sync

To build and sync the native Android project:

```bash
# Sync web build assets with Capacitor Android
npm run cap:sync

# Open project in Android Studio
npm run cap:open
```

Or build the release APK directly via Gradle CLI:
```bash
cd android
./gradlew assembleRelease
```
The output APK will be located at:
`android/app/build/outputs/apk/release/app-release.apk`

---

## 📄 License

This project is licensed under the MIT License.

> **Disclaimer:** DOLCE is an independent educational and portfolio project. It is inspired by modern music streaming user experiences and is not affiliated with, endorsed by, or associated with Google, YouTube, or YouTube Music.
