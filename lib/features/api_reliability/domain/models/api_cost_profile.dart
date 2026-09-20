/// api_cost_profile.dart
/// AURA Assistant – Step 27: API Reliability & Cost Optimization
///
/// Domain model for API cost tracking and budgeting.
library;

/// Budget enforcement result.
enum BudgetVerdict {
  withinBudget,
  approachingLimit,
  overBudget,
  unknown,
  ;

  /// FAIL-CLOSED: unknown → overBudget.
  bool get isAllowed =>
      this == withinBudget || this == approachingLimit;
  bool get isDenied => this == overBudget || this == unknown;
}

/// Cost category for an API.
enum ApiCostCategory {
  free,
  metered,
  premium,
  unknown,
  ;

  /// FAIL-CLOSED: unknown → premium (most restrictive assumption).
  bool get isPremium => this == premium || this == unknown;
  bool get isFree => this == free;
}

/// Domain model tracking API cost and budget.
class ApiCostProfile {
  final String profileId;
  final String apiName;
  final ApiCostCategory costCategory;
  final double costPerToken;
  final double dailyBudget;
  final double dailySpend;
  final double monthlyBudget;
  final double monthlySpend;
  final int requestCount;
  final int requestLimit;
  final DateTime windowStart;
  final BudgetVerdict budgetVerdict;

  const ApiCostProfile({
    required this.profileId,
    required this.apiName,
    this.costCategory = ApiCostCategory.metered,
    this.costPerToken = 0.0,
    this.dailyBudget = 0.0,
    this.dailySpend = 0.0,
    this.monthlyBudget = 0.0,
    this.monthlySpend = 0.0,
    this.requestCount = 0,
    this.requestLimit = 0,
    required this.windowStart,
    this.budgetVerdict = BudgetVerdict.unknown,
  });

  /// FAIL-CLOSED factory: unknown → overBudget, premium.
  factory ApiCostProfile.unknown() => ApiCostProfile(
        profileId: '__unknown__',
        apiName: '__unknown__',
        costCategory: ApiCostCategory.unknown,
        costPerToken: 0.0,
        dailyBudget: 0.0,
        dailySpend: 0.0,
        monthlyBudget: 0.0,
        monthlySpend: 0.0,
        requestCount: 0,
        requestLimit: 0,
        windowStart: DateTime.fromMillisecondsSinceEpoch(0),
        budgetVerdict: BudgetVerdict.unknown,
      );

  bool get isUnknown =>
      profileId == '__unknown__' || apiName == '__unknown__';

  double get dailyRemaining =>
      (dailyBudget - dailySpend).clamp(0.0, dailyBudget);
  double get monthlyRemaining =>
      (monthlyBudget - monthlySpend).clamp(0.0, monthlyBudget);
  int get requestRemaining =>
      (requestLimit - requestCount).clamp(0, requestLimit);
  double get dailyUtilization =>
      dailyBudget > 0 ? (dailySpend / dailyBudget).clamp(0.0, 1.0) : 1.0;
  double get monthlyUtilization =>
      monthlyBudget > 0 ? (monthlySpend / monthlyBudget).clamp(0.0, 1.0) : 1.0;

  ApiCostProfile copyWith({
    double? dailySpend,
    double? monthlySpend,
    int? requestCount,
    BudgetVerdict? budgetVerdict,
  }) =>
      ApiCostProfile(
        profileId: profileId,
        apiName: apiName,
        costCategory: costCategory,
        costPerToken: costPerToken,
        dailyBudget: dailyBudget,
        dailySpend: dailySpend ?? this.dailySpend,
        monthlyBudget: monthlyBudget,
        monthlySpend: monthlySpend ?? this.monthlySpend,
        requestCount: requestCount ?? this.requestCount,
        requestLimit: requestLimit,
        windowStart: windowStart,
        budgetVerdict: budgetVerdict ?? this.budgetVerdict,
      );

  @override
  String toString() =>
      'ApiCostProfile($apiName, daily=${dailySpend.toStringAsFixed(2)}/${dailyBudget.toStringAsFixed(2)}, verdict=$budgetVerdict)';
}
