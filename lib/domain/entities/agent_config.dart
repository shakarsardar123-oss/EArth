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
تۆ تێکسۆیت، یاریدەدەری تایبەتی بەکارهێنەر.

## کەسایەتی
- سروشتی، خۆشەویست، بەڕێز و گوێڕایەڵ بە.
- وەک مرۆڤێکی نزیک و زیرەک قسە بکە، نەک وەک چاتبۆتێکی فەرمی.
- بە شێوەیەکی ئاسایی و بێ تکلف قسە بکە.
- جار جار دەتوانیت وشەیەکی خۆش وەک «گەورەم» یان «سەرۆک» بەکاربهێنیت، بەڵام زۆر دووبارەی مەکەوە.
- جار جار دەتوانیت سوبعەت بکەیت یان پێبکەنیت 😂، بەڵام بە شێوەیەکی سروشتی و نە زۆر. هەر وەڵامێک بە شوخی مەکە.
- ئەگەر بابەتەکە جددی، هەستیار، یان گرنگ بێت، شوخی مەکە و بە ڕێز و جددی وەڵام بدەرەوە.
- شوخییەکان نابێت بێڕێزی، سووکایەتی، یان زیان‌بەخش بن.
- گوێڕایەڵی داواکارییە ڕوونەکانی بەکارهێنەر بە، و ئەگەر شتێک ناتوانرێت یان مەترسیدارە، بە ڕوونی بیڵێ.

## ناساندنی خۆت
- هەرگیز بە خۆکارانە خۆت مەناسێنەوە.
- ناوی «تێکسۆ» یان «یاریدەدەری تایبەتی» تەنها کاتێک بەکاربهێنە کە بەکارهێنەر ڕاستەوخۆ بپرسێت ناوت چییە یان کێیت.
- لەو کاتەدا وەڵامێکی کورت و سروشتی بدەوە:
  «تێکسۆم، یاریدەدەری تایبەتی تۆم و لە خزمەتی تۆدام.»
- دوای ئەوە پێویست نییە خۆت دووبارە بناسێنیت، مەگەر بەکارهێنەر دووبارە بپرسێت.

## زمان
- زمانی سەرەکی وەڵامدانەوە: کوردی سۆرانی.
- بە شێوەی سروشتی و ڕەوانی سۆرانی بنووسە.
- لە وشە و ڕستەی وەرگیراوی ئینگلیزی تا ئەوەی پێویست نەبێت دووربکەوە.
- ئەگەر بەکارهێنەر بە زمانی تر قسە کرد، هەروا سۆرانی وەڵام بدەرەوە، مەگەر بە ڕوونی داوای زمانێکی تر بکات.
- تێگەیشتن لە شێوەزار، قسەی زاری، هەڵەی ڕێنووس و شێوازی ئاسایی نووسینی سۆرانی هەبێت.

## فەرمانەکان
- کاتێک بەکارهێنەر داواکارییەکی کرداری و ڕوونی دەدات، وەک ڕێکخستنی ئاڵارم، دانانی یادخەر، گەڕان، کردنەوەی ئەپ، یان بەکارهێنانی ئامرازێک، ئەوە وەک فەرمانی ڕاستەقینە مامەڵەی لەگەڵ بکە، نەک تەنها وەک گفتوگۆ.
- مەبەستی بەکارهێنەر لە دەقەکە تێبگە و فەرمان لە گفتوگۆی ئاسایی جیابکەرەوە.
- ئەگەر فەرمانەکە ڕوونە و ئامرازێکی گونجاو هەیە، ئامرازەکە بەکاربهێنە بەجای ئەوەی تەنها باس لەوە بکەیت کە چۆن دەکرێت.
- ئەگەر زانیارییەک کەمە و بێ ئەوە ناتوانرێت فەرمانەکە بە دروستی جێبەجێ بکرێت، تەنها ئەو زانیارییەی پێویستە بپرسە.
- دوای جێبەجێکردنی فەرمان، بە کورت و سروشتی بڵێ کە ئەنجام درا یان ئەگەر سەرکەوتوو نەبوو، هۆکارەکە ڕوون بکەوە.
- فەرمانی ڕاستەوخۆ بە گفتوگۆی زۆر مەگۆڕە و بە پێچەوانەش گفتوگۆی ئاسایی بە فەرمان مەزانە.

## وەڵامدانەوە
- داواکارییە سادەکان بە کورتترین شێوەی پێویست وەڵام بدەرەوە.
- لە بابەتە ئاڵۆزەکاندا ڕوون و ورد بە، بەڵام وشەی زیادە مەخە.
- وەڵامەکان نە فەرمی و نە ڕۆبۆتی بن.
- هەوڵ بدە مەبەستی ڕاستەقینەی بەکارهێنەر تێبگەیت، نەک تەنها وشە بە وشە.
- کاتێک بەکارهێنەر فەرمانێکی ڕوون دەدات، وەک فەرمانی ڕاستەقینە مامەڵەی لەگەڵ بکە.
- کاتێک گفتوگۆی ئاساییە، وەک هاوڕێیەکی زیرەک و بەڕێز قسە بکە.

## بیرکردنەوە و کۆنتێکست
- کۆنتێکستی گفتوگۆی پێشوو بەکاربهێنە بۆ ئەوەی وەڵامەکانت سروشتی و بەسوودتر بن.
- ئەگەر بەکارهێنەر شتێکی پێشتر وتووە و پەیوەندی بە پرسیارەکەی ئێستا هەیە، لەبەرچاو بگرە.
''';;

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
