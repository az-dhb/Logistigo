# Logistigo 🚚

A Flutter logistics management application that connects **Managers**, **Drivers**, and **Clients** in a unified delivery workflow — from order creation to real-time tracking and mission reporting.

To download the application: https://www.mediafire.com/file/16gc9o3c82yt5z5/logistigo.apk/file

---

## Features

### 👤 Authentication
- Register with username, email, and password
- Choose account type: **Manager**, **Driver**, or **Client**
- Secure login to a role-specific dashboard

---

### 🧑‍💼 Manager Dashboard

| Page | Description |
|------|-------------|
| **Home** | Order activity chart (last 28 days) + summary cards: total orders, pending, and completed |
| **Products** | View, add, and delete company products |
| **Drivers** | Add drivers to the team via their UID |
| **Trucks** | Register fleet vehicles with model and vehicle ID |
| **Pending Orders** | Review and process incoming client orders — set price, assign driver & truck, then accept |
| **Notifications** | Receive driver leave requests, order activity updates, and end-of-mission reports; accept or decline requests |

---

### 📦 Client Dashboard

| Page | Description |
|------|-------------|
| **Active Orders** | View all currently active orders |
| **Create Order** | Submit a new delivery request: organization name, product, location, and quantity |
| **Live Tracking** | Real-time map showing both the client's location and the assigned delivery |
| **History** | View past completed or reported deliveries |

---

### 🚛 Driver Dashboard

| Page | Description |
|------|-------------|
| **Incoming Orders** | Accept or decline assigned orders (with reason if declining) |
| **Active Delivery** | Mark order as **Arrived** or report a **Breakdown** with reason |
| **Mission Report** | Auto-prompted form to fill and submit after each completed delivery |
| **Requests** | Submit requests (e.g. leave) — recorded as pending until manager responds |

---

## Order Lifecycle

```
Client creates order
       ↓
Manager sets price, assigns driver & truck → Accepts
       ↓
Driver accepts or declines (with reason)
       ↓
Order status: "En Route" — Client sees live tracking
       ↓
Driver marks Arrived (or reports Breakdown)
       ↓
Order moves to Client's history
       ↓
Driver fills & submits mission report
```

---

## Notifications & Communication

- Manager receives **driver leave requests** and **mission reports** — can accept or decline
- Driver is instantly notified of the manager's response
- Manager is notified whenever a driver **accepts or declines** an order

---

## Tech Stack

- **Framework:** Flutter (Dart)
- **Real-time tracking:** GPS / location services
- **Backend:** Firebase *(or update as applicable)*

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed
- Android Studio with Flutter plugin
- Google chrome as an emulator

### Installation

```bash
git clone https://github.com/your-username/logistigo.git
cd logistigo
flutter pub get
flutter run
```

---


## License

[MIT](LICENSE)
