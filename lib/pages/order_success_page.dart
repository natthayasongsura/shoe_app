import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'orders_page.dart';

class OrderSuccessPage extends StatelessWidget {
  final String orderId;
  const OrderSuccessPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text('สำเร็จ'), backgroundColor: Colors.black),
      body: Center(
        child: SingleChildScrollView(
          // ✅ เพิ่มตรงนี้เพื่อให้เลื่อนขึ้นลงได้
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/animations/success.json',
                  width: 200, repeat: false),
              const SizedBox(height: 30),
              const Text(
                'Order Successful',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'Order ID: $orderId',
                style: const TextStyle(color: Colors.grey, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OrdersPage(initialIndex: 0),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text('ดูคำสั่งซื้อของฉัน'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
