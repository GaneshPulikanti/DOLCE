# 🎵 DOLCE Music Player

**DOLCE** is a modern, high-performance music streaming application built with **React 18**, **Vite**, **Tailwind CSS**, **Zustand**, and **Dexie (IndexedDB)** for Native Android and Web. Designed with a dark glassmorphism aesthetic, Plus Jakarta Sans typography, and instant playback transitions, DOLCE brings a sweet, seamless listening experience across Web, Desktop, and Mobile.

---

## 📖 About DOLCE

**DOLCE** (Italian for *"Sweet"*) is designed for music enthusiasts who desire a clean, ad-free, and hyper-responsive audio player. 

Key architectural & design highlights:
- **Instant Search & High-Fidelity Streaming**: Fetches high-definition audio and 540x540 album covers from global music catalogs with zero latency.
- **Synchronized Real-Time Lyrics**: Powered by LRCLIB, featuring butter-smooth 60+ FPS GPU-accelerated scrolling and full-screen immersive view.
- **Offline & Local Storage**: Full offline playback capabilities, track downloads, custom playlists, and listening history backed by IndexedDB.
- **Adaptive Ambient Design**: Dynamic real-time color extraction adapts the background ambient glow to match the dominant colors of the currently playing album cover.
- **Native Android Background Playback**: Continuous background playback when the device screen is locked or when switching apps, integrated with native Android `MediaSession` lock screen controls.

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

## 👨‍💻 Developer & Author

Designed, Engineered & Maintained by **Ganesh Pulikanti**.
- **GitHub**: [@GaneshPulikanti](https://github.com/GaneshPulikanti)
- **Repository**: [GaneshPulikanti/DOLCE](https://github.com/GaneshPulikanti/DOLCE)

---

## 📄 License

This project is licensed under the MIT License.

> **Disclaimer:** DOLCE is created & developed by Ganesh Pulikanti. It is an independent educational and portfolio project inspired by modern music streaming user experiences and is not affiliated with, endorsed by, or associated with Google, YouTube, or YouTube Music.
