import 'package:flutter/material.dart';
import 'package:sistema_presupuestos/services/auth_service.dart';

import 'screens/budget_detail_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/create_budget_screen.dart';
import 'screens/materials_screen.dart';
import 'screens/budgets_list_screen.dart';
import 'screens/labor_screen.dart';
import 'screens/expenses_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const ElectricianApp());
}

class ElectricianApp extends StatelessWidget {
  const ElectricianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Presupuestos Electricista',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        primarySwatch: Colors.orange,
      ),

      //CONTROL DE SESIÓN
      home: const AuthWrapper(),

      routes: {
        "/login": (context) => const LoginScreen(),
        "/register": (context) => RegisterScreen(),
        "/home": (context) => const HomeScreen(),
        "/create": (context) => CreateBudgetScreen(),
        "/materials": (context) => MaterialsScreen(),
        "/budgets": (context) => BudgetsListScreen(),
        "/clients": (context) => ClientsScreen(),
        "/labor": (context) => LaborScreen(),
        "/expenses": (context) => ExpensesScreen(),
        "/reports": (context) => DashboardScreen(),
        "/settings": (context) => SettingsScreen(),
        "/budget-detail": (context) => BudgetDetailScreen(),
      },
    );
  }
}

// ==============================
// CONTROL DE LOGIN AUTOMÁTICO
// ==============================
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<bool> checkLogin() async {
    final auth = AuthService();
    return await auth.isLoggedIn();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: checkLogin(),

      builder: (context, snapshot) {

        // LOADING
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // YA LOGUEADO
        if (snapshot.data == true) {
          return const HomeScreen();
        }

        // NO LOGUEADO
        return const LoginScreen();
      },
    );
  }
}  