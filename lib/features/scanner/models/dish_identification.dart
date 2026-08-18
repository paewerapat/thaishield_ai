/// What Gemini Vision made of a food photo.
///
/// Two outcomes matter to the scanner, and they are deliberately separate
/// fields rather than one nullable name:
///
/// * [knownDishName] — the photo matched a dish already in `price_standards`.
///   That path is unchanged: the staff-curated range is shown.
/// * [genericNameEn] plus [estimatedMin]/[estimatedMax] — the dish is not in
///   the collection at all, and the model offered its own rough range. This is
///   the fallback that replaced a dead end, and every number in it is a guess.
///
/// The distinction is load-bearing for `CLAUDE.md` §10: a curated range and a
/// model's guess must never render the same way, because only one of them has
/// a human standing behind it.
class DishIdentification {
  const DishIdentification({
    this.knownDishName,
    this.genericNameEn,
    this.genericNameTh,
    this.estimatedMin,
    this.estimatedMax,
    this.confidence = DishConfidence.low,
  });

  /// Exact name copied from the `price_standards` list we sent.
  final String? knownDishName;

  /// The dish the model believes it saw, when it is not one we carry.
  final String? genericNameEn;
  final String? genericNameTh;

  /// The model's own guess at a typical street-price range, in THB.
  final double? estimatedMin;
  final double? estimatedMax;

  final DishConfidence confidence;

  bool get isKnownDish =>
      knownDishName != null && knownDishName!.trim().isNotEmpty;

  /// Whether there is enough here to show an estimate card.
  ///
  /// `low` confidence is withheld rather than shown with a caveat: a number a
  /// tourist might repeat to a vendor is worse than no number, and the empty
  /// state already tells them the dish is not in the database.
  bool get hasUsableEstimate {
    final min = estimatedMin;
    final max = estimatedMax;
    return (genericNameEn?.trim().isNotEmpty ?? false) &&
        min != null &&
        max != null &&
        min > 0 &&
        max >= min &&
        confidence != DishConfidence.low;
  }
}

enum DishConfidence { high, medium, low }

DishConfidence parseDishConfidence(String? raw) {
  return switch (raw?.trim().toLowerCase()) {
    'high' => DishConfidence.high,
    'medium' => DishConfidence.medium,
    _ => DishConfidence.low,
  };
}
