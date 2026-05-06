import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logistigo/Driver%20Home.dart';
import 'package:logistigo/Login.dart';
import 'package:logistigo/admin_home.dart';
import 'package:logistigo/drive%20missions.dart';
import 'package:logistigo/viewer%20home.dart';
import 'package:lottie/lottie.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Logistigo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthWrapper(),
    );
  }
}

// ---------------- AuthWrapper ----------------
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool showSplash = true;

  @override
  void initState() {
    super.initState();

    // Keep splash screen visible for 2 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => showSplash = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show splash while Firebase is connecting OR showSplash flag is true
        if (snapshot.connectionState == ConnectionState.waiting || showSplash) {
          return const SplashScreen();
        }

        if (!snapshot.hasData) {
          return const LoginPage();
        }

        return RoleRouter(user: snapshot.data!);
      },
    );
  }
}
// ---------------- SplashScreen ----------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 5), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminHome()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5A83AF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              "assets/Loading_car.json",
              width: 250,
              height: 250,
            ),
            const SizedBox(height: 20),
            const Text(
              "LogistiGo",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



// ---------------- RoleRouter ----------------
class RoleRouter extends StatefulWidget {
  final User user;
  const RoleRouter({super.key, required this.user});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  String? role;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadRoleWithDelay();
  }

  Future<void> _loadRoleWithDelay() async {
    final startTime = DateTime.now();

    // Load user document
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .get();

    final data = doc.data();
    final fetchedRole = data?['role'] ?? 'viewer';

    // Ensure splash shows for at least 2 seconds
    final elapsed = DateTime.now().difference(startTime);
    final delay = Duration(seconds: 1) - elapsed;
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }

    if (mounted) {
      setState(() {
        role = fetchedRole;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SplashScreen();
    }

    switch (role) {
      case 'admin':
        return const AdminHome();
      case 'manager':
        return const ManagerDashboardPage();
      case 'driver':
        return const DriverDashboard();
      case 'viewer':
        return const ClientHomePage();
      default:
        return const ClientHomePage();
    }
  }
}
// ---------------- Dummy Homepages ----------------
class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Admin Home'),
            ElevatedButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}

class DriverHome extends StatelessWidget {
  const DriverHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(child: Text('Driver Home')),
    );
  }
}

class ViewerHome extends StatelessWidget {
  const ViewerHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(child: Text('Viewer Home')),
    );
  }
}

// ---------------- Manager Dashboard ----------------
