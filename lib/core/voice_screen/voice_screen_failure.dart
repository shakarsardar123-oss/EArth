/// Re-exports [VoiceScreenFailure] and [VoiceScreenPhase] from the
/// central failures module so that voice_screen code can import from
/// this barrel without reaching into lib/core/errors directly.
library;

export '../errors/failures.dart' show VoiceScreenFailure, VoiceScreenPhase;
