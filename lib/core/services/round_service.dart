import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/models/round.dart';

class RoundService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Round?> getActiveRound(String versionId) async {
    final response = await _supabase
        .from('rounds')
        .select()
        .eq('version_id', versionId)
        .eq('is_active', true)
        .order('number')
        .maybeSingle();

    if (response == null) return null;
    return Round.fromMap(response);
  }

  Future<List<Round>> getRoundsByVersion(String versionId) async {
  final response = await _supabase
      .from('rounds')
      .select()
      .eq('version_id', versionId)
      .order('number', ascending: true);

  if (response.isEmpty) {
    throw Exception('Aucun tour trouvé pour cette version');
  }

  return response.map<Round>((e) => Round.fromMap(e)).toList();
}
}
