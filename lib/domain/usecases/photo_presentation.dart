import '../../core/localization/app_strings.dart';
import '../../data/models/handbook_photo.dart';

/// Message shown in place of a handbook figure image that failed to load
/// (missing or corrupt asset) — the caption/figure metadata is still shown
/// alongside this, never silently dropped.
String imageUnavailableCaption(HandbookPhoto photo) =>
    AppStrings.imageUnavailableMessage(photo.figureNumber, photo.displayCaption);
