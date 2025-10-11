import 'package:quranic_competition/models/app_user.dart';
import 'package:quranic_competition/models/competition_version.dart';
import 'package:quranic_competition/models/participant.dart';
import 'package:quranic_competition/models/round.dart';

class JuryEvaluationArgs {
  Participant participant;
  AppUser appUser;
  CompetitionVersion version;
  bool isReadOnly;
  Round round;

  JuryEvaluationArgs({
    required this.participant,
    required this.appUser,
    required this.version,
    this.isReadOnly = false,
    required this.round,
  });
}
