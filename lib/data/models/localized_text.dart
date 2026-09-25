/// Prefers a Turkmen translation over its English source when one is
/// present and non-empty; falls back to the English extraction text
/// otherwise (e.g. an entry that doesn't have a translation yet). Used by
/// every model's `displayX` getter so a missing translation degrades
/// gracefully instead of showing a blank string or crashing.
String preferTurkmen(String english, String? turkmen) =>
    (turkmen != null && turkmen.trim().isNotEmpty) ? turkmen : english;
