import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onToggle;

  const Sidebar({super.key, required this.isCollapsed, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isCollapsed ? 70 : 250, // Toggle width
      color: Colors.blueGrey[900],
      child: Column(
        children: [
          IconButton(
            icon: Icon(isCollapsed ? Icons.arrow_forward : Icons.arrow_back, color: Colors.white),
            onPressed: onToggle,
          ),
          // Add your navigation items here
          if (!isCollapsed) 
            const ListTile(title: Text("Dashboard", style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }
}