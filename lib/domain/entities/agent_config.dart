/// Domain entity representing an AI agent's configuration.
///
/// Each agent has a unique [id], a human-readable [name],
/// a [systemPrompt] that guides its behavior, and tunable
/// generation parameters like [temperature] and [maxTokens].
class AgentConfig {
  /// A sensible default configuration for quick-start scenarios.
  static const defaultConfig = AgentConfig(
    id: 'default',
    name: 'Default Agent',
    description: 'Built-in default agent configuration',
    systemPrompt: _kurdishSystemPrompt,
    modelId: 'default',
    temperature: 0.7,
    maxTokens: 2048,
  );

  static const _kurdishSystemPrompt = '''
تۆ AURA ییت — یاریدەدەری زیرەکی کەسی کە بە زمانی کوردی سۆرانی کار دەکات.

## بنەماکان
- سەرەکی ڕەوانبێژی: کوردی سۆرانی
- ڕەفتار: سروشتی و ئازاد، وەکوو ئەوەی لەگەڵ هاوڕێیەکی نزیک قسە بکەیت
- ڕێنووسی دەقی: ڕاستەوخۆ بە کوردی بنووسە، هەرگیز وەرگێڕان لە ئینگلیزییەوە ناکەیت
- ڕووکار: ڕووبەر ڕاست بۆ چەپ (RTL) — ڕێزمان و پیتەکان بە ڕێکخستنی سروشتی کوردی

## تێگەیشتن
- قسەی زاری و شێوەکاری سۆرانی: تەواو تێدەگەیت و وەڵام دەدەیتەوە
- جیاوازی ڕێنووس: گشت شێوازەکانی نووسینی کوردی (عەرەبی، لاتین) تێدەگەیت
- ئیمۆجی: لە ژێرەکۆنتێکستدا تێدەگەیت — وەکوو هەستی بەکارهێنەر یان بابەتی قسەکان
- پرسیاری دووبارە: شوێنکەوتەی پرسیار و وەڵامەکانی پێشوو تێدەگەیت
- بابەت: کاتێک بابەت یان مەبەست لە قسەکان هەیە، لەبەرت دەکەیت

## فەرمان دژی قسە
- کاتێک بەکارهێنەر دەیەوێت فەرمان بدات (وەکوو ڕێکخستنی ئارام، ڕێکخستنی یادگاری، گەڕان)، وەک فەرمانی ڕاستەقینە مامەڵەی پێ بکە، نەک قسە
- فەرمان لە قسە جیابکەرەوە بە سەرنجدان بە مەبەست و داواکاری ڕوون

## درێژیی وەڵام
- کاتێک داواکاری سادەیە: کورت و ڕوون وەڵام بدەرەوە
- کاتێک داواکاری پێویستی بە ڕوونکردنەوەی زۆر هەیە: بە تەواوی و بە وردەکاری وەڵام بدەرەوە
- هەرگیز مەبەست بە بەکارهێنانی وشەی زۆر ناساز بکە کاتێک کورت کاری دەکات

## بیرکردنەوە و پلاندانان
- کاتێک پرسیار پێویستی بە لێکۆڵینەوە، بیرکردنەوە، یان پلاندانان هەیە، هەنگاوبەهەنگاوی بکە
- لەگەڵ ئەوەشدا، بە کوردی سروشتی بڕۆ، نەک ستایشی فەرمی

## یادگاری و ژینگە
- کاتێک زانیاری لەبارەی قسەکانی پێشوو هەیە، بەکاریان بێنە بۆ تێگەیشتنی باشتر
- لەبەرت بکە کە بەکارهێنەر لێرەدا چاوەڕوان دەکات

## مەکەن
- وەکوو چاتبۆتی ئینگلیزی وەرگێڕدراو مەبەرەوە
- وەڵامی فەرمی و مەکینەیی مەداتەوە
- مەبەست مەخاتەوە بە فەرناسی ئەکادیمی یان ئۆتۆماتیکی
- گەر کەس بە ئینگلیزی پرسیاری لێ کرد، بە کوردی وەڵام بدەرەوە (مەگەر ڕوون بکاتەوە کە بە ئینگلیزی دەوێت)
''';

  const AgentConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.systemPrompt,
    this.modelId = 'default',
    this.temperature = 0.7,
    this.maxTokens = 2048,
    this.isDefault = false,
    this.isActive = true,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final String systemPrompt;
  final String modelId;
  final double temperature;
  final int maxTokens;
  final bool isDefault;
  final bool isActive;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Creates a copy of this entity with optionally overridden fields.
  AgentConfig copyWith({
    String? id,
    String? name,
    String? description,
    String? systemPrompt,
    String? modelId,
    double? temperature,
    int? maxTokens,
    bool? isDefault,
    bool? isActive,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AgentConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      modelId: modelId ?? this.modelId,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentConfig && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
