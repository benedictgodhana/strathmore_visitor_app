
import 'package:flutter/material.dart';
import '../models/visitor.dart';
import '../utils/constants.dart';

class VisitorCard extends StatelessWidget {
  final Visitor visitor;
  final VoidCallback onTap;

  const VisitorCard({
    Key? key,
    required this.visitor,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryBlue,
          backgroundImage: (visitor.photoPath != null && visitor.photoPath!.isNotEmpty)
              ? NetworkImage(visitor.photoPath!)
              : null,
          child: (visitor.photoPath == null || visitor.photoPath!.isEmpty)
              ? const Icon(Icons.person, color: Colors.white)
              : null,
        ),
        title: Text(
          visitor.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              visitor.phoneNumber ?? 'No phone number',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            Text(
              '${visitor.idType.replaceAll('_', ' ').toUpperCase()}: ${visitor.idNumber}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            if (visitor.action != null)
              Text(
                'Status: ${visitor.action!.toUpperCase()}',
                style: TextStyle(
                  fontSize: 14,
                  color: visitor.action == 'checked in' ? Colors.green : Colors.red,
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}