# Attendance Tracker

A simple Flutter app for tracking subject attendance using a weekly timetable.  
It helps students monitor attendance percentage and determine how many classes they can miss or must attend to stay within the required attendance criteria.

---

## Screenshots

| Home | Calendar | Time Table | Subjects | Settings | Calculator |
|------|----------|------------|----------|----------|------------|
| <p align="center"><img src="https://github.com/user-attachments/assets/ff110a8c-b7cf-42d8-9746-3f72f6d60367" width="270"></p> | <p align="center"><img src="https://github.com/user-attachments/assets/7f2c1ec1-e885-4636-a4b0-2206b07feb90" width="270"></p> | <p align="center"><img src="https://github.com/user-attachments/assets/8b434ad7-25fe-4ccb-9bd9-48593bb54d5a" width="270"></p> | <p align="center"><img src="https://github.com/user-attachments/assets/066f82d4-cec7-4331-aa32-dd2d34d0948a" width="270"></p> | <p align="center"><img src="https://github.com/user-attachments/assets/44214749-a8bc-41aa-ad14-625850efd2a4" width="270"></p> | <p align="center"><img src="https://github.com/user-attachments/assets/44214749-a8bc-41aa-ad14-625850efd2a4" width="270"></p> |

---

## Features

- Weekly timetable based attendance tracking
- Mark classes as **Present / Absent / Cancelled**
- Add **extra subjects** for a day
- Add **Shedule** of a particular day on special class days
- Automatic **attendance percentage calculation**
- **Bunk prediction** (classes you can miss or must attend)
- **Bunk calculator** (classes you can miss based on the upcoming classes count)
- Monthly **calendar visualization**
- Flexible **timetable editor**
- Custom **themes and color schemes**
- **GitHub APK update system**


---

## Application Pages

| Page | Description |
|-----|-------------|
| **Home** | Shows today's timetable and allows marking attendance |
| **Calendar** | Monthly attendance visualization along with Mutliselect of days|
| **Day Timetable** | View and mark attendance for a selected day |
| **Subjects** | Manage, rename and, view attendance statistics of subjects|
| **Timetable** | Weekly subject schedule |
| **Timetable Editor** | Add, reorder, or remove subjects |
| **Settings** | Attendance criteria, tutorial, themes, color schemes, and data reset |


---

## Attendance Rules

- **Total Classes = Present + Absent**
- **Cancelled classes are ignored**
- Minimum attendance requirement defaults to **75%** (configurable)

The app calculates:

- Attendance percentage
- Classes you can **bunk**
- Classes you must **attend to recover** 

---

## Calendar Color Indicators

| Color | Meaning |
|------|--------|
| 🟢 Green | All classes marked **Present** |
| 🔴 Red | All classes marked **Absent** |
| 🟠 Orange | All classes **Cancelled** or **No subjects scheduled** |
| 🟣 Purple | **Mixed** attendance statuses|
| ⚪ None | All classes **Unmarked** |

---


## Installation

Download the latest APK from the **Releases** section and install it on your Android device.

---

## Build From Source

Install dependencies:

```bash
flutter pub get
