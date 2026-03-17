# Antigravity - Premium Google TV Remote for iOS

Antigravity is a state-of-the-art, premium Google TV remote application for iOS, built with Flutter. It offers a sleek, glassmorphism-inspired interface and robust control over your Android TV or Google TV devices using ADB communication.

## ✨ Features

- 🌐 **Auto-Discovery**: Automatically finds Google TV devices on your local network.
- 📱 **Full D-Pad Control**: Navigate menus with a high-fidelity touch interface.
- 🔊 **Volume & Channel Management**: Precise sliders and buttons for volume and channel switching.
- 🔆 **Brightness Control**: Adjust your TV's brightness directly from the app.
- ⌨️ **Virtual Keyboard**: Send text to your TV effortlessly from your phone.
- 💾 **Device Management**: Save and manage multiple TV devices for quick access.
- 💎 **Premium UI**: Modern dark theme with glassmorphism effects for a high-end experience.

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev/)
- **Communication**: ADB (Android Debug Bridge) via `flutter_adb`
- **Discovery**: Multicast DNS (`multicast_dns`)
- **Persistence**: `shared_preferences`
- **Security**: `crypto` & `pointycastle`

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed on your machine.
- An iOS device or simulator for testing.
- A Google TV / Android TV device.

### TV Setup

1.  Enable **Developer Options** on your TV (Go to Settings > About > Click "Build Number" 7 times).
2.  Go to Developer Options and enable **ADB Debugging** and **Wireless Debugging**.
3.  Note your TV's IP address.

### Installation

1.  Clone the repository:
    ```bash
    git clone https://github.com/Kalpeshharsad/GoogleTVremote-iOS.git
    cd premium_app
    ```
2.  Install dependencies:
    ```bash
    flutter pub get
    ```
3.  Run the application:
    ```bash
    flutter run
    ```

## 📖 Usage

1.  Ensure your iOS device and TV are on the same Wi-Fi network.
2.  Open the Antigravity app.
3.  The app will attempt to discover your TV automatically. If not found, enter the TV's IP address manually in the connection card.
4.  Accept the ADB debugging prompt on your TV screen.
5.  Enjoy your premium remote experience!

---

Developed with ❤️ for a better TV experience.
