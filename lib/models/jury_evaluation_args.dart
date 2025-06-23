import 'package:quranic_competition/models/app_user.dart';
import 'package:quranic_competition/models/competition_version.dart';
import 'package:quranic_competition/models/participant.dart';

class JuryEvaluationArgs {
  Participant participant;
  AppUser appUser;
  CompetitionVersion version;
  int round;

  JuryEvaluationArgs({
    required this.participant,
    required this.appUser,
    required this.version,
    required this.round,
  });
}
