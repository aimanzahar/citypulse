import 'package:flutter/material.dart';
import '../models/enums.dart';

class SeverityBadge extends StatelessWidget {
  final Severity severity;
  final bool small;

  const SeverityBadge({super.key, required this.severity, this.small = false});

  @override
  Widget build(BuildContext context) {
    final color = severity.color;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 12, vertical: small ? 4 : 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        severity.displayName,
        style: TextStyle(color: color, fontSize: small ? 12 : 14),
      ),
    );
  }
}