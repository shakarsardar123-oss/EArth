/// tool_interface_test.dart
/// AURA Assistant – Step 22: Tests for Tool interface
///
/// Structural validation only (no Flutter/Dart SDK).
/// Tests: ToolCategory enum (12 values), RiskLevel enum (4 values),
/// Tool abstract class properties, default implementations.
library;

import 'package:test/test.dart';
import 'package:aura_assistant/features/tool_execution/tool_execution.dart';

void main() {
  group('ToolCategory', () {
    test('has all 12 category values', () {
      expect(ToolCategory.values.length, equals(12));
      expect(ToolCategory.values, contains(ToolCategory.device));
      expect(ToolCategory.values, contains(ToolCategory.screen));
      expect(ToolCategory.values, contains(ToolCategory.voice));
      expect(ToolCategory.values, contains(ToolCategory.memory));
      expect(ToolCategory.values, contains(ToolCategory.vision));
      expect(ToolCategory.values, contains(ToolCategory.media));
      expect(ToolCategory.values, contains(ToolCategory.assistant));
      expect(ToolCategory.values, contains(ToolCategory.communication));
      expect(ToolCategory.values, contains(ToolCategory.navigation));
      expect(ToolCategory.values, contains(ToolCategory.system));
      expect(ToolCategory.values, contains(ToolCategory.recovery));
      expect(ToolCategory.values, contains(ToolCategory.unknown));
    });
  });

  group('RiskLevel', () {
    test('has all 4 risk level values', () {
      expect(RiskLevel.values.length, equals(4));
      expect(RiskLevel.values, contains(RiskLevel.low));
      expect(RiskLevel.values, contains(RiskLevel.medium));
      expect(RiskLevel.values, contains(RiskLevel.high));
      expect(RiskLevel.values, contains(RiskLevel.critical));
    });
  });

  group('Tool Interface', () {
    test('concrete tools implement required properties', () {
      final deviceTool = DeviceTool();
      expect(deviceTool.id, equals('device'));
      expect(deviceTool.category, equals(ToolCategory.device));
      expect(deviceTool.riskLevel, equals(RiskLevel.medium));
      expect(deviceTool.supportsOffline, isTrue);
      expect(deviceTool.isVoiceSafe, isFalse);
    });

    test('system tool has critical risk', () {
      final systemTool = SystemTool();
      expect(systemTool.riskLevel, equals(RiskLevel.critical));
      expect(systemTool.requiresConfirmation, isTrue);
      expect(systemTool.isVoiceSafe, isFalse);
    });

    test('voice tool is voice-safe', () {
      final voiceTool = VoiceTool();
      expect(voiceTool.isVoiceSafe, isTrue);
      expect(voiceTool.supportsOffline, isTrue);
    });

    test('communication tool has high risk', () {
      final commTool = CommunicationTool();
      expect(commTool.riskLevel, equals(RiskLevel.high));
      expect(commTool.supportsOffline, isFalse);
      expect(commTool.isVoiceSafe, isTrue);
    });

    test('unknown tool handler is always fail-closed', () {
      final unknownTool = UnknownToolHandler();
      expect(unknownTool.riskLevel, equals(RiskLevel.critical));
      expect(unknownTool.category, equals(ToolCategory.unknown));
    });
  });
}
