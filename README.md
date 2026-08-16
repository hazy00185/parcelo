# 🚚 Parcelo

### Real-Time Delivery & Logistics App built with Flutter and Firebase

**Parcelo** is a modern real-time delivery management application built with **Flutter** and **Firebase**. It connects customers with delivery partners through a complete request-to-delivery workflow, including authentication, order management, provider acceptance, live location tracking, and real-time status updates.

The project was built with a focus on **clean UI, real-time synchronization, role-based workflows, and practical mobile application architecture**.

---

## ✨ Key Features

### 🔐 Authentication & Account Roles

* Customer and Delivery Partner authentication
* Email & password sign-up and login
* Persistent Firebase authentication
* Role-based application flow
* Secure access to authenticated Firestore data

### 📦 Customer Experience

* Create delivery requests
* Enter pickup and drop-off information
* View request status in real time
* Track delivery partner location
* Follow the provider on the live map
* View delivery progress from request to completion

### 🛵 Delivery Partner Experience

* View incoming delivery requests
* Accept delivery requests
* Update delivery progress
* Share live location
* Manage active deliveries
* Complete deliveries

### 📍 Real-Time Tracking

* Live provider location updates
* Interactive OpenStreetMap integration
* Automatic map following
* Provider location availability indicator
* Last location update information
* Real-time Firestore synchronization

### 🔄 Delivery Workflow

```text
Customer
   ↓
Create Delivery Request
   ↓
Waiting for Delivery Partner
   ↓
Provider Receives Request
   ↓
Provider Accepts
   ↓
Live Location Tracking
   ↓
Package Picked Up
   ↓
Package In Transit
   ↓
Delivered
```

---

## 🛠️ Tech Stack

| Technology              | Purpose                           |
| ----------------------- | --------------------------------- |
| Flutter                 | Cross-platform mobile application |
| Dart                    | Application development           |
| Firebase Authentication | User authentication               |
| Cloud Firestore         | Real-time data & order management |
| Flutter Map             | Interactive maps                  |
| OpenStreetMap           | Map tiles                         |
| Geolocator              | Device location services          |
| LatLong2                | Geographic coordinates            |

---

## 🏗️ Architecture Overview

```text
┌──────────────────────────────────────┐
│              PARCELO                 │
│        Flutter Mobile Client         │
└──────────────────┬───────────────────┘
                   │
          ┌────────┴────────┐
          │                 │
     CUSTOMER           PROVIDER
          │                 │
          └────────┬────────┘
                   │
          Firebase Authentication
                   │
             Cloud Firestore
                   │
        ┌──────────┴──────────┐
        │                     │
   Order Management      Live Location
        │                     │
        └──────────┬──────────┘
                   │
             Flutter Map
                   │
            OpenStreetMap
```

---

## 📱 Core Screens

* Authentication
* Sign Up
* Login
* Role Selection
* Customer Dashboard
* Delivery Request
* Provider Dashboard
* Delivery Requests
* Delivery Tracking
* Order Status
* Live Location Map

---

## 🔥 Firebase Integration

Parcelo uses Firebase for backend functionality, including:

* Authentication
* User role management
* Delivery orders
* Provider information
* Real-time order updates
* Live provider location synchronization
* Firestore security rules

---

## 🗺️ Live Delivery Tracking

The tracking system synchronizes the delivery provider's coordinates through Firestore and displays the latest available position on an interactive map.

Customers can enable or disable automatic map following while monitoring the delivery.

---

## 🧪 Testing

The application was tested on a physical Android device with both:

* Customer workflow
* Delivery Partner workflow

The complete delivery lifecycle was verified:

**Request → Accept → Track → Pick Up → In Transit → Delivered**

The project also passes Flutter static analysis with:

```text
No issues found!
```

---

## 📦 APK

A release APK is available under the project's **GitHub Releases**.

**Latest Release:** `v1.0.0`

---

## 🚀 Getting Started

### Prerequisites

Make sure you have:

* Flutter SDK
* Android Studio
* Android SDK
* A Firebase project
* An Android device or emulator

### Installation

Clone the repository:

```bash
git clone https://github.com/hazy00185/Parcelo.git
```

Navigate to the project:

```bash
cd Parcelo
```

Install dependencies:

```bash
flutter pub get
```

Run the application:

```bash
flutter run
```

For a release APK:

```bash
flutter build apk --release
```

The generated APK will be available at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔒 Security

Firebase Authentication is required for protected Firestore operations.

Firestore access is controlled through Firebase Security Rules, ensuring unauthenticated users cannot access protected application data.

> Firebase configuration and credentials should be handled according to Firebase's security recommendations when deploying or sharing the project.

---

## 🎯 Project Goals

Parcelo was developed to demonstrate practical implementation of:

* Flutter mobile development
* Firebase backend integration
* Authentication
* Role-based application workflows
* Real-time database synchronization
* Location-based services
* Interactive maps
* Delivery management
* Production-oriented mobile application development

---

## 👨‍💻 Developer

**Hassan Sardar**

BS Computer Science
Government College University Faisalabad — Sahiwal Campus

### Connect

* GitHub: https://github.com/hazy00185
* Project Repository: https://github.com/hazy00185/Parcelo

---

## 📄 License

This project is currently provided for educational, portfolio, and demonstration purposes.
