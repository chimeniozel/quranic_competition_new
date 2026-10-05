import 'package:flutter_test/flutter_test.dart';
import 'package:quranic_competition/core/utils/youtube_utils.dart';

void main() {
  test("extraction de l'identifiant YouTube", () {
    const id = 'UkOLnnqDOi4';
    for (final url in [
      'https://youtu.be/$id?si=d4u7REUx8j4Am8pj',
      'https://www.youtube.com/watch?v=$id&t=10s',
      'https://m.youtube.com/watch?feature=share&v=$id',
      'https://youtube.com/shorts/$id?feature=share',
      'https://www.youtube.com/live/$id',
      'https://www.youtube.com/embed/$id',
      '  https://youtu.be/$id  ',
    ]) {
      expect(YoutubeUtils.videoId(url), id, reason: url);
    }
    expect(YoutubeUtils.videoId('https://example.com/video.mp4'), '');
  });
}
