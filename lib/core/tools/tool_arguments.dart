/// Strongly-typed argument definition for a tool parameter.
class ToolArgumentDef {
  const ToolArgumentDef({
    required this.name,
    required this.type,
    this.description,
    this.isRequired = true,
    this.defaultValue,
    this.enumValues,
  this.example,
  this.isSecret = false,
  this.label,
  this.hintText,
  this.keyboardType,
    this.minValue,
    this.maxValue,
    this.itemType,
  });

  /// Parameter name (e.g. 'query').
  final String name;

  /// Type string: 'string', 'int', 'double', 'bool', 'list', 'map'.
  final String type;

  /// Human-readable description for the LLM.
  final String? description;

  /// Whether the argument must be supplied.
  final bool isRequired;

  /// Default value when not supplied.
  final dynamic defaultValue;

  /// Allowed values if this is an enum-like argument.
  final List<String>? enumValues;

  /// Example value for documentation.
  final dynamic example;

  /// Whether this argument contains secret data (e.g. API keys).
  final bool isSecret;

  /// UI label (display name).
  final String? label;

  /// UI hint text.
  final String? hintText;

  /// Keyboard type hint for UI: 'text', 'number', 'email', 'url', etc.
  final String? keyboardType;

  /// Minimum numeric value (for int/double types).
  final num? minValue;

  /// Maximum numeric value (for int/double types).
  final num? maxValue;

  /// Element type for 'list'/'array' arguments (e.g. 'int', 'string').
  /// Gemini requires an `items` schema for ARRAY-typed parameters.
  final String? itemType;

  /// Converts to a JSON-serializable map for LLM tool schema.
  Map<String, dynamic> toSchemaMap() {
    final map = <String, dynamic>{
      'type': type,
    };
    if (description != null) map['description'] = description;
    if (enumValues != null) map['enum'] = enumValues;
    if (defaultValue != null) map['default'] = defaultValue;
    if (example != null) map['example'] = example;
    if (type == 'list' || type == 'array') {
      map['items'] = {'type': itemType ?? 'string'};
    }
    return map;
  }
}

/// Runtime argument values passed to a tool invocation.
class ToolArguments {
  const ToolArguments(this._values);

  final Map<String, dynamic> _values;

  /// The raw map of argument values.
  Map<String, dynamic> get values => Map.unmodifiable(_values);

  /// Retrieves a required argument.
  T get<T>(String name) {
    final value = _values[name];
    if (value == null) {
      throw ArgumentError('Required argument "$name" is missing');
    }
    if (value is T) return value;
    throw ArgumentError(
      'Argument "$name" expected type $T but got ${value.runtimeType}',
    );
  }

  /// Retrieves an optional argument with a default.
  T getOrElse<T>(String name, T defaultValue) {
    final value = _values[name];
    if (value == null) return defaultValue;
    if (value is T) return value;
    return defaultValue;
  }

  /// Whether an argument with [name] exists.
  bool has(String name) => _values.containsKey(name);

  /// Returns a string argument, or null.
  String? getString(String name) => _values[name] as String?;

  /// Returns an int argument, or null.
  int? getInt(String name) => _values[name] as int?;

  /// Returns a double argument, or null.
  double? getDouble(String name) => _values[name] as double?;

  /// Returns a bool argument, or null.
  bool? getBool(String name) => _values[name] as bool?;

  /// Returns a list argument, or null.
  List<dynamic>? getList(String name) => _values[name] as List<dynamic>?;

  /// Returns a map argument, or null.
  Map<String, dynamic>? getMap(String name) =>
      _values[name] as Map<String, dynamic>?;

  @override
  String toString() => 'ToolArguments($_values)';
}
