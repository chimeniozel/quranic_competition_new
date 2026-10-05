/// Outils YouTube communs (archive, tajwid...).
class YoutubeUtils {
  YoutubeUtils._();

  static final _idPattern = RegExp(
    r'(?:youtu\.be/|[?&]v=|/embed/|/shorts/|/live/|/v/)([A-Za-z0-9_-]{11})',
  );

  /// Identifiant (11 caractères) d'une vidéo YouTube, ou chaîne vide.
  ///
  /// Gère youtu.be/ID, watch?v=ID, shorts/ID, live/ID, embed/ID, les
  /// domaines m. / www. et les espaces parasites autour du lien.
  static String videoId(String url) {
    final match = _idPattern.firstMatch(url.trim());
    return match?.group(1) ?? '';
  }

  /// Miniature standard (480×360) : elle existe pour toute vidéo, à la
  /// différence de « maxresdefault », absente des vidéos non HD.
  static String thumbnailUrl(String videoId) =>
      'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

  /// Miniature de secours plus légère (320×180)
  static String fallbackThumbnailUrl(String videoId) =>
      'https://i.ytimg.com/vi/$videoId/mqdefault.jpg';
}
