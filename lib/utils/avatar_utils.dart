import 'package:flutter/material.dart';

const _avatarPalette = [
  [Color(0xFF1A5276), Color(0xFF2E86C1)],
  [Color(0xFF145A32), Color(0xFF27AE60)],
  [Color(0xFF6C3483), Color(0xFF9B59B6)],
  [Color(0xFF78281F), Color(0xFFE74C3C)],
  [Color(0xFF784212), Color(0xFFE67E22)],
  [Color(0xFF117A65), Color(0xFF1ABC9C)],
  [Color(0xFF212F3C), Color(0xFF5D6D7E)],
  [Color(0xFF1A5276), Color(0xFF76D7C4)],
];

List<Color> avatarColors(String name) {
  if (name.isEmpty) return _avatarPalette[0];
  int hash = 0;
  for (final ch in name.codeUnits) {
    hash = (hash * 31 + ch) & 0xFFFFFFFF;
  }
  return _avatarPalette[hash % _avatarPalette.length];
}

String avatarInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
