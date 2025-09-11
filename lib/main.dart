import 'package:flutter/material.dart';

import 'package:sakthi_erp/auth/login_screen.dart';

import 'package:sakthi_erp/dashboard/dashboard_screen.dart';

import 'package:sakthi_erp/modules/customer/add_new_customer_screen.dart';

import 'package:sakthi_erp/modules/customer/customer_detail_screen.dart';

import 'package:sakthi_erp/modules/customer/customer_list_screen.dart';

import 'package:sakthi_erp/modules/reports/receivable_report_screen.dart';

import 'package:sakthi_erp/modules/sales/create_sales_order_screen.dart';

import 'package:sakthi_erp/modules/sales/sales_order_screen.dart';

import 'package:sakthi_erp/modules/quotation/quotation_list_screen.dart';

import 'package:sakthi_erp/modules/quotation/quotation_screen.dart';

import 'package:sakthi_erp/modules/quotation/quotation_detail_screen.dart';

import 'package:sakthi_erp/modules/visit_entry/create_visit_entry_screen.dart';
import 'package:sakthi_erp/modules/visit_entry/visit_entry_detail_screen.dart';
import 'package:sakthi_erp/modules/visit_entry/visit_entry_list_screen.dart';
import 'package:sakthi_erp/modules/reports/sales_person_receivable_report_screen.dart';

void main() {
  runApp(const SakthiErpApp());
}

class SakthiErpApp extends StatelessWidget {
  const SakthiErpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sakthi ERP',
      debugShowCheckedModeBanner: false,
      theme: _buildAppTheme(),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>? ??
              {};
          return DashboardScreen(
            serverUrl: args['serverUrl'] ?? '',
            sid: args['sid'] ?? '',
            fullName: args['fullName'] ?? '',
            email: args['email'] ?? '',
            roles: List<String>.from(args['roles'] ?? []),
          );
        },
        '/salesOrder': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>? ??
              {};
          return SalesOrderScreen(
            serverUrl: args['serverUrl'] ?? '',
            sid: args['sid'] ?? '',
            roles: List<String>.from(args['roles'] ?? []),
          );
        },
        '/createSalesOrder': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>? ??
              {};
          return CreateSalesOrderScreen(
            serverUrl: args['serverUrl'] ?? '',
            sid: args['sid'] ?? '',
          );
        },
        '/customerList': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>? ??
              {};
          return CustomerListScreen(
            serverUrl: args['serverUrl'] ?? '',
            sid: args['sid'] ?? '',
            email: args['email'] ?? '',
          );
        },
        '/addNewCustomer': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>? ??
              {};
          return AddNewCustomerScreen(
            serverUrl: args['serverUrl'] ?? '',
            sid: args['sid'] ?? '',
            email: args['email'] ?? '',
          );
        },
        '/customerDetail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>? ??
              {};
          return CustomerDetailScreen(
            customer: args['customer'] ?? {},
            serverUrl: args['serverUrl'] ?? '',
            sid: args['sid'] ?? '',
          );
        },
        '/receivableReport': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>? ??
              {};
          return ReceivableReportScreen(
            serverUrl: args['serverUrl'] ?? '',
            sid: args['sid'] ?? '',
          );
        },
        '/salesPersonReceivableReport': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>? ??
              {};
          return SalesPersonReceivableReportScreen(
            serverUrl: args['serverUrl'] ?? '',
            sid: args['sid'] ?? '',
          );
        },
        '/quotationList': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>? ??
              {};
          return QuotationListScreen(
            serverUrl: args['serverUrl'] ?? '',
            sid: args['sid'] ?? '',
          );
        },
        '/addQuotation': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>? ??
              {};
          return QuotationScreen(
            serverUrl: args['serverUrl'] ?? '',
            sid: args['sid'] ?? '',
            initialData: args['initialData'],
          );
        },
        '/quotationDetail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>? ??
              {};
          return QuotationDetailScreen(
            quotation: args['quotation'] ?? {},
            serverUrl: args['serverUrl'] ?? '',
            sid: args['sid'] ?? '',
          );
        },
        '/visitEntryList': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>? ??
              {};
          return VisitEntryListScreen(
            serverUrl: args['serverUrl'] ?? '',
            sid: args['sid'] ?? '',
          );
        },
        '/createVisitEntry': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>? ??
              {};
          return CreateVisitEntryScreen(
            serverUrl: args['serverUrl'] ?? '',
            sid: args['sid'] ?? '',
          );
        },
        '/visitEntryDetail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>? ??
              {};
          return VisitEntryDetailScreen(
            visitEntryName: args['visitEntryName'] ?? '',
            serverUrl: args['serverUrl'] ?? '',
            sid: args['sid'] ?? '',
          );
        },
      },
    );
  }

  ThemeData _buildAppTheme() {
    // Define your custom colors
    const primaryColor = Color(0xff65C18C);
    const darkGreenColor = Color(0xff195533);
    const backgroundColor = Color(0xffDDF1E5);
    const blackColor = Color(0xff000000);

    return ThemeData(
      useMaterial3: false, // ensures backward compatibility
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: 'Poppins',
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: darkGreenColor,
        background: backgroundColor,
        onPrimary: Colors.white,
        onBackground: blackColor,
        error: Colors.redAccent,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 28.0,
          fontWeight: FontWeight.bold,
          color: darkGreenColor,
        ),
        titleLarge: TextStyle(
          fontSize: 22.0,
          fontWeight: FontWeight.w600,
          color: darkGreenColor,
        ),
        bodyLarge: TextStyle(fontSize: 16.0, color: blackColor),
        bodyMedium: TextStyle(fontSize: 14.0, color: Color(0xff555555)),
        labelLarge: TextStyle(
          fontSize: 16.0,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: primaryColor, width: 2.0),
        ),
        labelStyle: const TextStyle(color: darkGreenColor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16.0)),
        ),
        margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20.0,
          fontWeight: FontWeight.bold,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}
