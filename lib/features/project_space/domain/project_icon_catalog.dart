import 'package:flutter/material.dart';

/// Maps user-facing project icon names to Material `IconData`. The name is
/// stored in `projects.icon` (TEXT) so the catalogue is the single source of
/// truth for what the picker offers and what the card/detail screens render.
class ProjectIconCatalog {
  static const String defaultName = 'star';
  static const int minCount = 16;

  static const Map<String, IconData> _map = {
    'star': Icons.star,
    'school': Icons.school,
    'work': Icons.work_outline,
    'travel_explore': Icons.travel_explore,
    'restaurant': Icons.restaurant,
    'shopping_bag': Icons.shopping_bag_outlined,
    'business': Icons.business,
    'flight': Icons.flight_takeoff,
    'health_and_safety': Icons.health_and_safety,
    'phone': Icons.phone,
    'auto_stories': Icons.auto_stories,
    'menu_book': Icons.menu_book,
    'lightbulb': Icons.lightbulb_outline,
    'rocket_launch': Icons.rocket_launch,
    'favorite': Icons.favorite_outline,
    'flag': Icons.flag_outlined,
    'public': Icons.public,
    'microphone': Icons.mic_none,
    'coffee': Icons.coffee,
    'groups': Icons.groups,
  };

  static const List<String> allNames = _map.keys.toList(growable: false);

  static IconData forName(String? name) {
    if (name == null) return Icons.star;
    return _map[name] ?? Icons.star;
  }
}
