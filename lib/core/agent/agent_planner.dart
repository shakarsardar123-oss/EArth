import 'agent_context.dart';
import 'agent_intent.dart';
import 'agent_plan.dart';
import 'agent_step.dart';
import '../tools/tool_registry.dart';
import '../utils/uuid_util.dart';

/// Callback signature for sending messages to the AI provider.
typedef PlannerSendToAI = Future<Map<String, dynamic>> Function({
  required List<Map<String, dynamic>> messages,
  required List<Map<String, dynamic>> toolDefinitions,
  required AgentContext context,
});

/// Plans agent execution steps based on user input and available tools.
///
/// Phase 4 fully implements:
/// - LLM-guided planning: sends intent + tool descriptions to AI,
///   parses tool_calls response into AgentPlan with steps, goal,
///   dependencies, and verification conditions.
/// - Plan validation: checks tool availability, detects dependency
///   cycles via DFS, and validates execution budget.
/// - AI response parsing: extracts tool calls from AI JSON into
///   structured AgentStep list with dependency map.
class AgentPlanner {
  AgentPlanner({
    required this.toolRegistry,
    this.sendToAI,
  });

  final ToolRegistry toolRegistry;

  /// Optional AI callback for LLM-guided planning.
  /// If null, falls back to simple rule-based planning.
  final PlannerSendToAI? sendToAI;

  // ── LLM-Guided Planning ──

  /// Creates an execution plan for the given [userInput] and [context].
  ///
  /// When [sendToAI] is available, this sends the user's intent and
  /// available tool descriptions to the AI, then parses the AI's
  /// tool_calls response into a structured AgentPlan with steps,
  /// goal, dependencies, and verification conditions.
  ///
  /// Falls back to simple rule-based planning when [sendToAI] is null.
  Future<AgentPlan> plan({
    required String userInput,
    required AgentContext context,
  }) async {
    final intent = context.intent as AgentIntent?;
    final availableTools = toolRegistry.all;

    // Simple fallback: if no AI callback or no tools, return empty plan.
    if (sendToAI == null || availableTools.isEmpty) {
      return AgentPlan(
        steps: [],
        goal: intent?.goal ?? userInput,
      );
    }

    // Build the planning prompt with intent and tool descriptions.
    final planningPrompt = _buildPlanningPrompt(userInput, intent, availableTools);

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': planningPrompt},
      {'role': 'user', 'content': userInput},
    ];

    final toolDefinitions = toolRegistry.openAISchemas;

    try {
      final aiResponse = await sendToAI!(
        messages: messages,
        toolDefinitions: toolDefinitions,
        context: context,
      ).timeout(Duration(seconds: context.timeoutSeconds));

      // Parse the AI response into a plan.
      return parseAIPlan(aiResponse, goal: intent?.goal ?? userInput);
    } catch (e) {
      // If AI planning fails, return an empty plan — the engine will
      // fall back to the iterative tool-calling loop.
      return AgentPlan(
        steps: [],
        goal: intent?.goal ?? userInput,
        reasoning: 'LLM planning failed: $e',
      );
    }
  }

  /// Build a planning prompt that instructs the AI to generate a
  /// structured execution plan using the available tools.
  String _buildPlanningPrompt(
    String userInput,
    AgentIntent? intent,
    List<dynamic> availableTools,
  ) {
    final toolDescriptions = availableTools.map((tool) {
      final defn = (tool as dynamic).definition;
      return '- ${defn.name}: ${defn.description}';
    }).join('\n');

    final intentInfo = intent != null
        ? 'Goal: ${intent.goal}\nAction type: ${intent.actionType.name}\n'
            'Entities: ${intent.entities.map((e) => e.value).join(', ')}\n'
            'Constraints: ${intent.constraints.join(', ')}'
        : 'Goal: derive from user input';

    return '''تۆ یارمەتدەرێکی زیرەکی بە کوردی سۆرانیت. تکایە پلانێک بۆ بەکارهێنانێکی ئامرازەکان دابین بکە.

$intentInfo

ئامرازە بەردەستەکان:
$toolDescriptions

لە وەڵامدا تکایە tool_calls بەکاربهێنە بۆ ئەوەی پلانەکە دابین بکەیت. هەر tool_call پێویستە:
- name: ناوی ئامرازەکە
- arguments: ئارگومێنتەکانی ئامرازەکە

دەتوانیت چەندین tool_calls بە یەک وەڵامدا بنێریت بۆ ئەوەی پلانێکی تەواو دابین بکەیت. هەر tool_call وەک هەنگاوێک لە پلانەکە دەژمێردرێت.''';
  }

  // ── AI Response Parsing ──

  /// Parse the AI response (with potential tool_calls) into an AgentPlan.
  ///
  /// Extracts tool_calls from the AI response, creates AgentStep for each,
  /// and builds a dependency map based on the order of steps (each step
  /// depends on the previous step unless it's the first).
  AgentPlan parseAIPlan(
    Map<String, dynamic> aiResponse, {
    String? goal,
  }) {
    final toolCalls = aiResponse['tool_calls'] as List<dynamic>?;
    final content = aiResponse['content'] as String?;

    if (toolCalls == null || toolCalls.isEmpty) {
      // No tool calls — AI just wants to respond directly.
      return AgentPlan(
        steps: [],
        goal: goal ?? content ?? '',
        reasoning: content,
      );
    }

    final steps = <AgentStep>[];
    final dependencies = <String, Set<String>>{};
    String? previousStepId;

    for (int i = 0; i < toolCalls.length; i++) {
      final tc = toolCalls[i] as Map<String, dynamic>;
      final funcMap = tc['function'] as Map<String, dynamic>?;
      final functionName = funcMap?['name'] as String? ?? tc['name'] as String?;
      final functionArgs = funcMap?['arguments'] as Map<String, dynamic>? ??
          tc['arguments'] as Map<String, dynamic>? ?? {};

      if (functionName == null) continue;

      final stepId = UuidUtil().v4();
      final step = AgentStep(
        stepId: stepId,
        toolName: functionName,
        parameters: functionArgs,
        description: 'Step ${i + 1}: $functionName',
        action: functionName,
      );
      steps.add(step);

      // Build sequential dependency chain: each step depends on previous.
      if (previousStepId != null) {
        dependencies[stepId] = {previousStepId};
      }
      previousStepId = stepId;
    }

    // Extract goal from content or parameter.
    final planGoal = goal ?? content ?? 'Execute ${steps.length} steps';

    // Build verification conditions from expected outcomes.
    final verificationConditions = <String>[];
    for (final step in steps) {
      if (step.expectedResults != null) {
        verificationConditions.add(step.expectedResults!);
      }
    }

    return AgentPlan(
      steps: steps,
      goal: planGoal,
      dependencies: dependencies,
      verificationConditions: verificationConditions,
      reasoning: content,
    );
  }

  // ── Plan Validation ──

  /// Validate a plan before execution.
  ///
  /// Checks:
  /// 1. All tool names referenced in steps exist in the toolRegistry.
  /// 2. No dependency cycles exist (verified via DFS/topological sort).
  /// 3. Execution budget is not exceeded.
  ///
  /// Returns null if valid, or an error message string if invalid.
  String? validatePlan(AgentPlan plan, AgentContext context) {
    // 1. Check tool availability.
    for (final step in plan.steps) {
      if (step.toolName.isNotEmpty && !toolRegistry.has(step.toolName)) {
        return 'ئامرازی "$step.toolName" لە سیستەمدا نییە';
      }
    }

    // 2. Detect dependency cycles via DFS.
    if (_hasDependencyCycle(plan)) {
      return 'پلانەکە پێویستی بە خۆی هەیە (cycle) — ناتوانرێت جێبەجێ بکرێت';
    }

    // 3. Check execution budget.
    final totalSteps = plan.steps.length;
    if (totalSteps > context.maxSteps) {
      return 'ژمارەی هەنگاوەکان ($totalSteps) لە سنووری ڕێگەپێدراو (${context.maxSteps}) زیاترە';
    }

    if (context.isBudgetExceeded) {
      return 'بوودجەی جێبەجێکردن تەواو بووە';
    }

    return null; // Valid.
  }

  /// Check if the plan's dependency graph contains a cycle.
  ///
  /// Uses DFS with three-state coloring (WHITE=unvisited, GRAY=in current
  /// path, BLACK=fully explored). A cycle exists if we encounter a GRAY node.
  bool _hasDependencyCycle(AgentPlan plan) {
    // Build adjacency list from dependencies.
    final adj = <String, List<String>>{};
    for (final entry in plan.dependencies.entries) {
      adj[entry.key] = entry.value.toList();
    }
    // Ensure all step IDs are in the adjacency map.
    for (final step in plan.steps) {
      adj.putIfAbsent(step.stepId, () => []);
    }

    // Three-state DFS: 0=WHITE (unvisited), 1=GRAY (in path), 2=BLACK (done).
    final color = <String, int>{};
    for (final stepId in adj.keys) {
      color[stepId] = 0;
    }

    bool dfs(String node) {
      color[node] = 1; // GRAY
      for (final neighbor in adj[node] ?? <String>[]) {
        final neighborColor = color[neighbor] ?? 0;
        if (neighborColor == 1) {
          return true; // Cycle detected.
        }
        if (neighborColor == 0 && dfs(neighbor)) {
          return true;
        }
      }
      color[node] = 2; // BLACK
      return false;
    }

    for (final stepId in adj.keys) {
      if (color[stepId] == 0) {
        if (dfs(stepId)) return true;
      }
    }
    return false;
  }

  // ── Tool Validation (preserved from Phase 1–3) ──

  /// Validates that a tool call from the AI references a valid registered tool.
  bool validateToolCall(String toolName) => toolRegistry.has(toolName);
}
