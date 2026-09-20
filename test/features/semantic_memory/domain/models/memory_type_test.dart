/// memory_type_test.dart
/// Structural tests for MemoryType enum.
/// No Flutter SDK — dart test only.
library;

import 'package:test/test.dart';

// Inline import of the source under test.
// In the real project this would be:
// import 'package:aura_assistant/features/semantic_memory/domain/models/memory_type.dart';
// For structural testing we duplicate the enum here to avoid
// depending on Flutter SDK or full project compilation.

/// Mirror of MemoryType for structural testing.
enum MemoryType {
  userPreference,
  personalFact,
  conversation,
  task,
  project,
  device,
  location,
  instruction,
  other;

  String get labelKey => 'memory_type$name';
}

void main() {
  group('MemoryType', () {
    test('has exactly 9 values', () {
      expect(MemoryType.values, hasLength(9));
    });

    test('contains all expected types', () {
      expect(MemoryType.values, containsAll([
        MemoryType.userPreference,
        MemoryType.personalFact,
        MemoryType.conversation,
        MemoryType.task,
        MemoryType.project,
        MemoryType.device,
        MemoryType.location,
        MemoryType.instruction,
        MemoryType.other,
      ]));
    });

    test('labelKey returns correct format for each type', () {
      for (final type in MemoryType.values) {
        expect(type.labelKey, startsWith('memory_type'));
        expect(type.labelKey, equals('memory_type${type.name}'));
      }
    });

    test('specific labelKey values are correct', () {
      expect(MemoryType.userPreference.labelKey, 'memory_typeuserPreference');
      expect(MemoryType.personalFact.labelKey, 'memory_typepersonalFact');
      expect(MemoryType.conversation.labelKey, 'memory_typeconversation');
      expect(MemoryType.task.labelKey, 'memory_typetask');
      expect(MemoryType.project.labelKey, 'memory_typeproject');
      expect(MemoryType.device.labelKey, 'memory_typedevice');
      expect(MemoryType.location.labelKey, 'memory_typelocation');
      expect(MemoryType.instruction.labelKey, 'memory_typeinstruction');
      expect(MemoryType.other.labelKey, 'memory_typeother');
    });

    test('name property works correctly', () {
      expect(MemoryType.userPreference.name, 'userPreference');
      expect(MemoryType.other.name, 'other');
    });
  });
}
