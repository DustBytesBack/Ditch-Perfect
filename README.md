# Attendance Tracker

A Flutter-based attendance tracking application designed for students to manage and monitor their class attendance without requiring any user authentication. All data is stored locally on the device for privacy and offline access.

## Overview

This app helps students track their attendance across multiple subjects throughout the academic week. Users can create a personalized timetable, mark attendance daily, view attendance statistics, and review historical data through a calendar interface.

## Features

### Local Storage
- No user login required - single user per device
- All data stored locally using Hive database
- Complete privacy with no cloud sync

### Core Functionality
- **Dynamic Timetable Management**: Create and modify your weekly schedule
- **Subject Management**: Add subjects with full names and short codes
- **Attendance Tracking**: Mark classes as Present, Absent, Cancelled, or Clear
- **Percentage Calculation**: Real-time attendance percentage for each subject
- **Calendar View**: Review and modify past attendance records
- **Bulk Actions**: Mark all subjects for a day with one tap
- **Flexible Scheduling**: Add subjects on short notice outside the regular timetable

## Pages

### 1. Home Page
The main interface for daily attendance tracking.

**Features:**
- Displays current day's subjects based on the timetable
- Four action buttons per subject:
  - **Present**: Mark attendance as present
  - **Absent**: Mark attendance as absent
  - **Cancelled**: Mark class as not taken (doesn't count toward total)
  - **Clear**: Remove any marking
- Shows current attendance percentage for each subject
- Bulk action buttons to mark all subjects at once
- Option to add additional subjects for the day

### 2. Subject Page
Manage all subjects in your curriculum.

**Features:**
- Add new subjects with full name and short code
- View attendance statistics for each subject
- Delete subjects with options:
  - Remove from future timetable only
  - Delete all past entries completely
- Display attendance percentage highlighting low attendance

### 3. Timetable Page
Configure your weekly class schedule.

**Features:**
- Visual grid layout showing all days and time slots
- Assign subjects to specific slots
- Mark slots as free periods
- Edit button to access the timetable editor
- Reorder time slots via drag-and-drop

### 4. Calendar Page
Historical view and management of attendance records.

**Features:**
- Interactive calendar interface
- Click any date to view that day's subjects
- Mark or modify attendance for any past or future date
- Visual indicators for holidays and special days
- "Today" button for quick navigation

### 5. Settings Page
Customize app behavior and preferences.

**Features:**
- Set number of hours/slots per day
- Configure minimum attendance threshold
- Toggle dark/light theme
- View app information

## First-Time Setup

1. **Launch the app** - You'll be prompted to enter the number of class hours per day
2. **Configure timetable** - An empty timetable (Monday-Friday) is created with the specified slots
3. **Add subjects** - Navigate to Subject Page and add all your subjects
4. **Assign subjects** - Go to Timetable Page and assign subjects to time slots
5. **Start tracking** - Return to Home Page to begin marking attendance

## How It Works

### Attendance Marking
- **Present**: Counts as attended class
- **Absent**: Counts as missed class
- **Cancelled**: Class didn't occur - excluded from calculations
- **Clear**: Removes any marking - treated as unmarked

### Percentage Calculation
```
Attendance % = (Present Classes / Total Classes Held) × 100
Total Classes Held = Present + Absent (excludes Cancelled and Cleared)
```

### Subject Deletion Options
When removing a subject from a specific day's slot:
- **Future Only**: Removes the subject from that day slot for all upcoming weeks only
- **Delete All Entries**: Removes the subject from that slot and deletes all historical attendance records for that subject on that day

### Adding Subjects On-the-Fly
For classes scheduled outside the regular timetable (makeup classes, extra lectures), use the add button on Home Page to include additional subjects for that specific day without modifying the base timetable.

## Technical Stack

- **Framework**: Flutter
- **Database**: Hive (Local NoSQL)
- **State Management**: Provider
- **Calendar**: table_calendar package
- **Platform**: Android, iOS

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── subject.dart
│   ├── attendance.dart
│   ├── timetable.dart
│   └── settings.dart
├── providers/                # State management
│   ├── subject_provider.dart
│   ├── attendance_provider.dart
│   ├── timetable_provider.dart
│   ├── theme_provider.dart
│   └── settings_provider.dart
├── screens/                  # UI pages
│   ├── home_page.dart
│   ├── subject_page.dart
│   ├── timetable_page.dart
│   ├── timetable_editor_page.dart
│   ├── calendar_page.dart
│   ├── settings_page.dart
│   └── day_page.dart
├── services/                 # Backend services
│   └── database_service.dart
├── utils/                    # Helper functions
│   ├── attendance_utils.dart
│   └── holiday_utils.dart
└── widgets/                  # Reusable components
```

## Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK
- Android Studio / VS Code with Flutter extensions

### Installation

1. Clone the repository
```bash
git clone <repository-url>
cd flutter_test_app
```

2. Install dependencies
```bash
flutter pub get
```

3. Run the app
```bash
flutter run
```

## Future Enhancements

- Export attendance data as PDF/CSV
- Backup and restore functionality
- Multiple semester support
- Attendance alerts and notifications
- Widget for quick home screen access
- Holiday calendar integration

## License

This project is open source and available for educational purposes.
