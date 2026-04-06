# Ditch Perfect

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Material 3](https://img.shields.io/badge/Material--3-%236750A4.svg?style=for-the-badge&logo=material-design&logoColor=white)](https://m3.material.io)
[![Firebase](https://img.shields.io/badge/Firebase-%23039BE5.svg?style=for-the-badge&logo=firebase)](https://firebase.google.com)

**Ditch Perfect** is a premium, high-fidelity attendance tracking application for students. Designed with a modern, "expressive" Material 3 aesthetic, it helps you manage your weekly timetable, monitor attendance percentages, and intelligently predict how many classes you can miss (or must attend) to meet your targets.

---

## 📸 Screenshots

| Home | Calendar | Subjects | Settings |
| :---: | :---: | :---: | :---: |
| <img src="https://github.com/user-attachments/assets/ff110a8c-b7cf-42d8-9746-3f72f6d60367" width="220" /> | <img src="https://github.com/user-attachments/assets/7f2c1ec1-e885-4636-a4b0-2206b07feb90" width="220" /> | <img src="https://github.com/user-attachments/assets/066f82d4-cec7-4331-aa32-dd2d34d0948a" width="220" /> | <img src="https://github.com/user-attachments/assets/44214749-a8bc-41aa-ad14-625850efd2a4" width="220" /> |

---

## ✨ Key Features

- **Material 3 Expressive UI**: A stunning, fluid design system featuring Dynamic Color support.
- **Weekly Timetable Management**: A flexible schedule editor to manage your classes with ease.
- **Smart Bunk Prediction**: Intelligent algorithms that calculate exactly how many classes you can "bunk" or how many you must attend to recover your percentage.
- **Detailed Analytics**: Stay on top of your attendance with subject-wise statistics and monthly calendar visualizations.
- **Firebase Synchronization**: Secure authentication and real-time data sync across devices.
- **Personalized Themes**: Support for Dark Mode, Dynamic Color (Android 12+), and specialized modes like "Pookie Mode."
- **Local & Cloud Storage**: High-performance local storage with Hive and reliable cloud backup via Firestore.

---

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev) (Dart)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Local Database**: [Hive](https://pub.dev/packages/hive)
- **Backend**: [Firebase](https://firebase.google.com/) (Auth, Firestore)
- **UI Components**: [Material 3](https://m3.material.io/), [Google Fonts](https://fonts.google.com/), [Lucide Icons](https://lucide.dev)
- **Utilities**: `connectivity_plus`, `shared_preferences`, `package_info_plus`

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (Channel Stable)
- Android Studio / VS Code
- A Firebase project (for cloud sync features)

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/DustBytesBack/Ditch-Perfect.git
   cd Ditch-Perfect
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**:
   - Create a Firebase project.
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).
   - Enable Email/Password Authentication and Cloud Firestore.

4. **Run the app**:
   ```bash
   flutter run
   ```

---

## 📐 Design Philosophy

Ditch Perfect is built with a focus on **visual excellence** and **responsive interactions**. 
- **Consistency**: Unified Material 3 components across all flows (Auth, Settings, Core).
- **Accessibility**: High contrast support and adaptive layouts.
- **Premium Feel**: Micro-animations and spring-based transitions for a fluid UX.

---

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.

---

<p align="center">
  Made by DustBytesBack
</p>
