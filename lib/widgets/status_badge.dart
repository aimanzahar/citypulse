import 'package:flutter/material.dart';
import '../models/enums.dart';

class StatusBadge extends StatelessWidget {
  final Status status;
  final bool small;

  const StatusBadge({Key? key, required this.status, this.small = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    return Chip(
      backgroundColor: color.withOpacity(0.12),
      avatar: CircleAvatar(
        backgroundColor: color,
        radius: small ? 10 : 12,
        child: Icon(
          _iconForStatus(status),
          color: Colors.white,
          size: small ? 12 : 14,
        ),
      ),
      label: Text(
        status.displayName,
        style: TextStyle(
          color: color,
          fontSize: small ? 12 : 14,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 12, vertical: 0),
    );
  }

  IconData _iconForStatus(Status s) {
    switch (s) {
      case Status.submitted:
        return Icons.send;
      case Status.inProgress:
        return Icons.autorenew;
      case Status.fixed:
        return Icons.check;
    }
  }
}