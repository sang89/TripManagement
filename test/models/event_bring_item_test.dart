import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/models/event_bring_item.dart';

void main() {
  const baseJson = {
    'id': 'item-1',
    'event_id': 'event-1',
    'label': 'Buy ice',
    'note': null,
    'assigned_to_name': null,
    'created_by': 'user-1',
    'created_at': '2026-06-04T22:00:00.000Z',
  };

  test('fromJson parses unassigned item', () {
    final item = EventBringItem.fromJson(baseJson);
    expect(item.id, 'item-1');
    expect(item.label, 'Buy ice');
    expect(item.note, isNull);
    expect(item.assignedToName, isNull);
    expect(item.isAssigned, false);
  });

  test('fromJson parses assigned item', () {
    final json = {...baseJson, 'assigned_to_name': 'Sarah', 'note': 'cold ones'};
    final item = EventBringItem.fromJson(json);
    expect(item.isAssigned, true);
    expect(item.assignedToName, 'Sarah');
    expect(item.note, 'cold ones');
  });

  test('copyWith clears assignedToName', () {
    final item = EventBringItem.fromJson(
        {...baseJson, 'assigned_to_name': 'Sarah'});
    final unassigned = item.copyWith(clearAssignedToName: true);
    expect(unassigned.isAssigned, false);
    expect(unassigned.assignedToName, isNull);
    expect(unassigned.label, item.label);
  });

  test('copyWith updates assignedToName', () {
    final item = EventBringItem.fromJson(baseJson);
    final assigned = item.copyWith(assignedToName: 'Alex');
    expect(assigned.assignedToName, 'Alex');
    expect(assigned.isAssigned, true);
  });
}
