import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/navigation_page.dart';
import 'pages/address_page.dart';
import 'package:app/pages/orders_page.dart';
import 'package:app/pages/order_success_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ShoeStoreApp());
}

class ShoeStoreApp extends StatelessWidget {
  const ShoeStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shoe Store',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.orange),
      home: const NavigationPage(), // ✅ หน้าแรก
      routes: {
        '/address_page': (context) =>
            const AddressPage(), // ✅ แก้ให้เหลืออันเดียว
        '/orders': (context) =>
            const OrdersPage(), // ✅ route สำหรับดูคำสั่งซื้อ
        '/order_success': (context) =>
            OrderSuccessPage(orderId: ''), // ✅ เพิ่มตรงนี้
      },
    );
  }
}
