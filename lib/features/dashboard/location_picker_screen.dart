import 'package:flutter/material.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  Offset? _selectedPoint;
  final String _mockAddress = "21.0285, 105.8542"; // Giả lập tọa độ Hà Nội

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chọn vị trí trên bản đồ"),
        backgroundColor: const Color(0xFF64DA56),
        actions: [
          if (_selectedPoint != null)
            TextButton(
              onPressed: () => Navigator.pop(context, _mockAddress),
              child: const Text("XÁC NHẬN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: GestureDetector(
        onTapDown: (details) {
          setState(() {
            _selectedPoint = details.localPosition;
          });
        },
        child: Stack(
          children: [
            // Giả lập bản đồ bằng một container màu xám
            Container(
              color: Colors.grey[200],
              width: double.infinity,
              height: double.infinity,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 100, color: Colors.grey),
                    SizedBox(height: 16),
                    Text("Chạm vào màn hình để chọn vị trí", style: TextStyle(color: Colors.grey)),
                    Text("(Giả lập Bản đồ)", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ),
            if (_selectedPoint != null)
              Positioned(
                left: _selectedPoint!.dx - 20,
                top: _selectedPoint!.dy - 40,
                child: const Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
          ],
        ),
      ),
    );
  }
}
