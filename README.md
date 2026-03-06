# ☁️ StoreThis

A lightweight, native macOS menu bar app for managing Google Cloud Storage buckets — built entirely through vibes.

> **🤖 Fully Vibe Coded** — This entire application was built through conversational AI prompting. No manual coding, no IDE marathons, just vibes and good intentions. Every line of Swift was generated through the power of describing what you want and watching it materialize.

---

## What is StoreThis?

StoreThis lives in your macOS menu bar and gives you instant access to your Google Cloud Storage buckets. Upload files with drag & drop, browse your bucket contents, preview files inline, and manage multiple GCS accounts — all without opening a browser or touching `gsutil`.

## Features

### 🗂️ Bucket Browser
- Navigate your bucket's folder hierarchy with breadcrumb navigation
- View files with smart icons based on file type
- See file sizes at a glance
- Delete files directly from the context menu

### 📤 Drag & Drop Upload
- Drop files directly onto the menu bar panel to upload
- Real-time upload progress feedback
- Uploads respect your current folder location
- Multi-file upload support

### 👁️ File Preview
- **Images** — Inline preview with zoom (PNG, JPEG, GIF, WebP)
- **Text & Code** — Syntax-highlighted preview (JSON, XML, YAML, JS)
- **PDFs** — Metadata display with option to open in your PDF viewer
- Download any file to open in its default application

### 🔐 Service Account Authentication
- Import Google Cloud service account JSON keys
- JWT-based OAuth2 with RS256 signing
- Automatic token caching and refresh
- Supports both PKCS#1 and PKCS#8 private key formats

### 👤 Multiple Profiles
- Create and manage multiple GCS configurations
- Each profile gets its own service account key and bucket
- Quick-switch between profiles from the menu bar
- Connection testing to verify credentials

## Screenshots

*Coming soon*

## Getting Started

### Prerequisites
- macOS 15.0+
- A Google Cloud Storage bucket
- A service account key (JSON) with Storage permissions

### Setup
1. Download and run StoreThis
2. Open Settings (`⌘ ,`)
3. Create a profile and give it a name
4. Import your service account JSON key file
5. Enter your GCS bucket name
6. Hit "Test Connection" to verify — you're good to go

## Tech Stack

- **Swift** + **SwiftUI** — Native macOS app, no Electron in sight
- **AppKit** — Menu bar integration with `NSStatusItem` and floating `NSPanel`
- **Security.framework** — RSA key parsing and JWT signing
- **URLSession** — Direct GCS REST API calls, no SDKs needed
- **@Observable** — Reactive state management throughout

## Architecture

```
storethisApp (Entry Point)
├── AppDelegate          — Menu bar status item + floating panel
├── MenuBarContentView   — Main UI shell with profile picker
│   ├── DropZoneView     — Drag & drop upload target
│   ├── BucketBrowserView — Folder/file navigation
│   │   └── FileRowView  — Individual file/folder rows
│   └── FilePreviewView  — Inline file previews
├── SettingsView         — Profile & connection management
├── AuthenticationService — JWT auth + token lifecycle
├── GCSService           — GCS REST API wrapper
└── ProfileManager       — Multi-profile CRUD + persistence
```

## Data Storage

- **Profiles** — `~/Library/Application Support/storethis/profiles.json`
- **Service Account Keys** — `~/Library/Application Support/storethis/keys/`
- **Active Profile** — `UserDefaults`

## License

MIT

---

*Built with vibes, shipped with confidence.* ✌️
