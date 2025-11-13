import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quranic_competition/models/competition_version.dart';
import 'package:quranic_competition/models/participant.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/models/evaluation.dart';

class EvaluationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> submitEvaluation(Evaluation evaluation, String ageGroup) async {
    try {
      final notesJson =
          ageGroup == 'كبار'
              ? evaluation.noteModel.toMapAdult()
              : evaluation.noteModel.toMapChild();

      if (notesJson == null) {
        throw Exception('خطأ: لا يمكن إنشاء notes_json - تأكد من ملء جميع الحقول');
      }

      print('📝 Données à insérer:');
      print('  - participant_id: ${evaluation.participantId}');
      print('  - jury_id: ${evaluation.juryId}');
      print('  - version_id: ${evaluation.versionId}');
      print('  - round_id: ${evaluation.roundId}');
      print('  - total_score: ${evaluation.totalScore}');
      print('  - notes_json: $notesJson');

      final response =
          await _supabase.from('evaluations').insert({
            'participant_id': evaluation.participantId,
            'jury_id': evaluation.juryId,
            'version_id': evaluation.versionId,
            'round_id': evaluation.roundId,
            'total_score': evaluation.totalScore,
            'notes': evaluation.notes,
            'notes_json': notesJson,
            'submitted_at': evaluation.submittedAt.toIso8601String(),
          }).select();

      print("✅ Évaluation enregistrée : $response");
    } catch (e) {
      print('❌ Erreur lors de l\'enregistrement de l\'évaluation : $e');
      print('❌ Stack trace: ${StackTrace.current}');
      throw Exception('فشل في إرسال التقييم: $e');
    }
  }

  Future<Evaluation?> getEvaluationByJuryAndParticipant({
    required String juryId,
    required String participantId,
    required String versionId,
    required String roundId,
    required String ageGroup,
  }) async {
    final response =
        await _supabase
            .from('evaluations')
            .select()
            .eq('jury_id', juryId)
            .eq('participant_id', participantId)
            .eq('version_id', versionId)
            .eq('round_id', roundId)
            .maybeSingle();

    if (response == null) return null;

    return Evaluation.fromMap(response, ageGroup);
  }

  Future<void> updateEvaluation(Evaluation evaluation, String ageGroup) async {
    try {
      final updateMap = {
        'total_score': evaluation.totalScore,
        'notes': evaluation.notes,
        'submitted_at': evaluation.submittedAt.toIso8601String(),
        'notes_json':
            ageGroup == "كبار"
                ? evaluation.noteModel.toMapAdult()
                : evaluation.noteModel.toMapChild(),
      };

      await _supabase
          .from('evaluations')
          .update(updateMap)
          .eq('id', evaluation.id);

      print('✅ Évaluation mise à jour avec succès');
    } catch (e) {
      print('❌ Erreur lors de la mise à jour : $e');
      throw Exception('Erreur mise à jour : $e');
    }
  }

  /// Récupère les évaluations d'un jury pour un round spécifique
  Future<List<Evaluation>> getEvaluationsByJuryInRound({
    required String juryId,
    required String roundId,
  }) async {
    final response = await _supabase
        .from('evaluations')
        .select('*, participants(age_group)')
        .eq('jury_id', juryId)
        .eq('round_id', roundId);

    return response.map<Evaluation>((e) {
      final ageGroup = e['participants']['age_group'];
      return Evaluation.fromMap(e, ageGroup);
    }).toList();
  }

  Future<List<Evaluation>> getEvaluationsByJuryInVersion({
    required String juryId,
    required String versionId,
  }) async {
    // Récupérer les rounds de cette version
    final roundsResponse = await _supabase
        .from('rounds')
        .select('id')
        .eq('version_id', versionId);

    if (roundsResponse.isEmpty) {
      return [];
    }

    final roundIds = roundsResponse.map((r) => r['id'] as String).toList();

    // Récupérer les évaluations du jury pour tous les rounds de cette version
    final response = await _supabase
        .from('evaluations')
        .select('*, participants(age_group)')
        .eq('jury_id', juryId)
        .inFilter('round_id', roundIds);

    return response.map<Evaluation>((e) {
      final ageGroup = e['participants']['age_group'];
      return Evaluation.fromMap(e, ageGroup);
    }).toList();
  }

  /// Supprime toutes les évaluations d'un jury pour une version donnée
  Future<void> deleteEvaluationsByJuryInVersion({
    required String juryId,
    required String versionId,
  }) async {
    try {
      print(
        '🗑️ Suppression des évaluations du jury $juryId pour la version $versionId',
      );

      await _supabase
          .from('evaluations')
          .delete()
          .eq('jury_id', juryId)
          .eq('version_id', versionId);

      print('✅ Évaluations supprimées avec succès');
    } catch (e) {
      print('❌ Erreur lors de la suppression des évaluations: $e');
      throw Exception('Erreur lors de la suppression des évaluations: $e');
    }
  }

  Future<EvaluationResult> getEvaluationsByRoundId(String roundId) async {
    final response = await _supabase
        .from('evaluations')
        .select('*, participants(*)')
        .eq('round_id', roundId); // ✅ هنا التعديل المهم

    final List<Evaluation> evaluations = [];
    final List<Participant> participants = [];

    for (final row in response) {
      final participantMap = row['participants'];
      final evaluation = Evaluation.fromMap(row, participantMap['age_group']);
      evaluations.add(evaluation);
      participants.add(Participant.fromMap(participantMap));
    }

    return EvaluationResult(
      evaluations: evaluations,
      participants: participants,
    );
  }

  Future<EvaluationResult> getEvaluationsByVersionAndRoundDetailed({
    required String versionId,
    required String roundId,
  }) async {
    final response = await _supabase
        .from('evaluations')
        .select('*, participants(*)')
        .eq('version_id', versionId)
        .eq('round_id', roundId);

    final List<Evaluation> evaluations = [];
    final List<Participant> participants = [];

    for (final row in response) {
      final participantMap = row['participants'];
      final evaluation = Evaluation.fromMap(row, participantMap['age_group']);

      evaluations.add(evaluation);
      participants.add(Participant.fromMap(participantMap));
    }

    return EvaluationResult(
      evaluations: evaluations,
      participants: participants,
    );
  }

  static Future<void> exportEvaluatedParticipantsToSupabase({
    required List<Participant> participants,
    required CompetitionVersion version,
    required String roundName,
    required String juryName,
    required String ageGroup,
  }) async {
    // 1. Filtrer uniquement les évalués
    final evaluatedParticipants =
        participants.where((p) => p.isEvaluated).toList();
    if (evaluatedParticipants.isEmpty) {
      print("❌ Aucun participant évalué.");
      return;
    }

    // 2. Générer le fichier Excel
    final Excel excel = Excel.createExcel();
    final Sheet sheet = excel['Participants évalués'];

    // 3. Header
    sheet.appendRow([
      TextCellValue('Nom complet'),
      TextCellValue('Groupe d\'age'),
      TextCellValue('Téléphone'),
      TextCellValue('Numéro de registration'),
      TextCellValue('Date de naissance'),
    ]);

    // 4. Données
    for (final p in evaluatedParticipants) {
      sheet.appendRow([
        TextCellValue(p.fullName),
        TextCellValue(p.ageGroup),
        TextCellValue(p.phone),
        TextCellValue(p.registrationNumber?.toString() ?? ''),
        TextCellValue(p.birthDate.toIso8601String()),
      ]);
    }

    // 4. Encodage du fichier
    final List<int>? bytes = excel.encode();
    if (bytes == null) {
      print("❌ Erreur lors de l'encodage du fichier.");
      return;
    }
    final Uint8List fileBytes = Uint8List.fromList(bytes);

    // 5. Sauvegarder temporairement le fichier localement
    final tempDir = await getTemporaryDirectory();
    final fileName =
        'evaluation-${"juryName".replaceAll(" ", "-")}-type-${"ageGroup".replaceAll(" ", "-")}-${"roundName".replaceAll(" ", "-")}.xlsx';
    final filePath = '${tempDir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(fileBytes);

    // 6. Upload vers Supabase Storage
    final storage = Supabase.instance.client.storage;
    final bucketName =
        'juries-evaluations'; // Assure-toi que le bucket existe dans Supabase

    final storagePath = '/version.name/juries-evaluations/roundName/$fileName';

    final fileUpload = await storage
        .from(bucketName)
        .upload(
          storagePath,
          file,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

    print("✅ Fichier exporté vers Supabase Storage: $fileUpload");

    // Optionnel : récupérer l'URL publique
    final publicUrl = storage.from(bucketName).getPublicUrl(storagePath);
    print("🌐 URL publique: $publicUrl");
  }

  /*
static Future<void> exportEvaluatedParticipantsLocally({
    required List<Participant> participants,
    required CompetitionVersion version,
    required String roundName,
    required String juryName,
    required String ageGroup,
  }) async {
    // 1. Filtrer uniquement les évalués
    final evaluatedParticipants =
        participants.where((p) => p.isEvaluated).toList();
    if (evaluatedParticipants.isEmpty) {
      print("❌ Aucun participant évalué.");
      return;
    }

    // 2. Générer le fichier Excel
    final Excel excel = Excel.createExcel();
    final Sheet sheet = excel['sheet'];

    // 3. En-tête
    List<String> headers = [];

if (ageGroup == 'كبار') {
  headers = [
    "رقم المتسابق",
    "التجويد",
    "حسن الصوت",
    "عذوبة الصوت",
    "الوقف والإبتداء",
    "المجموع",
  ];
} else if (ageGroup == 'صغار') {
  headers = [
    "رقم المتسابق",
    "التجويد",
    "حسن الصوت",
    "الإلتزام بالرواية",
    "المجموع",
  ];
}

// Convertir les en-têtes en CellValue pour Excel
List<CellValue?> cellHeaders = headers.map((header) => TextCellValue(header)).toList();
sheet.appendRow(cellHeaders);


    // 4. Données
    for (final p in evaluatedParticipants) {
      sheet.appendRow([
        TextCellValue(p.fullName),
        TextCellValue(p.ageGroup),
        TextCellValue(p.phone),
        TextCellValue(p.registrationNumber?.toString() ?? ''),
        TextCellValue(p.birthDate.toIso8601String()),
      ]);
    }

    // 5. Encodage du fichier
    final List<int>? bytes = excel.encode();
    if (bytes == null) {
      print("❌ Erreur lors de l'encodage du fichier.");
      return;
    }
    final Uint8List fileBytes = Uint8List.fromList(bytes);

    // 6. Dossier temporaire
    final Directory dir = await getTemporaryDirectory();

    // 7. Générer nom du fichier
    final safeJury = juryName.replaceAll(" ", "_");
    final safeAgeGroup = ageGroup.replaceAll(" ", "_");
    final safeRound = roundName.replaceAll(" ", "_");
    final safeVersion = version.name.replaceAll(" ", "_");

    final fileName =
        'تصحيح_الشيخ_${safeJury}_فئة_${safeAgeGroup}_$safeRound.xlsx';

    final filePath = '${dir.path}/$fileName';

    // 8. Sauvegarde locale
    final file = File(filePath);
    await file.writeAsBytes(fileBytes);

    // 9. Partage avec share_plus
    await Share.shareXFiles(
      [XFile(filePath)],
      text: '📄 ملف تصحيح: $fileName',
    );
    print("✅ Fichier généré et prêt à être partagé : $filePath");
  }
*/
  static Future<void> exportEvaluatedParticipantsLocally({
    required List<Participant> participants,
    required List<Evaluation> evaluations,
    required CompetitionVersion version,
    required String roundName,
    required String juryName,
    required String ageGroup,
    required BuildContext context,
  }) async {
    final evaluatedParticipants =
        participants.where((p) => p.isEvaluated).toList();
    final unEvaluatedParticipants =
        participants.where((p) => p.isEvaluated == false).toList();
    if (unEvaluatedParticipants.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ لم يتم التصحيح لكل المتسابقين")),
      );
      return;
    } else {
      final Excel excel = Excel.createExcel();
      final Sheet sheet = excel['sheet'];

      // En-tête
      List<String> headers = [];
      if (ageGroup == 'كبار') {
        headers = [
          "رقم المتسابق",
          "التجويد",
          "حسن الصوت",
          "عذوبة الصوت",
          "الوقف والإبتداء",
          "المجموع",
        ];
      } else if (ageGroup == 'صغار') {
        headers = [
          "رقم المتسابق",
          "التجويد",
          "حسن الصوت",
          "الإلتزام بالرواية",
          "المجموع",
        ];
      }
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      // Données
      for (final participant in evaluatedParticipants) {
        final eval = evaluations.firstWhere(
          (e) => e.participantId == participant.id,
          orElse: () => Evaluation.empty(participant.id),
        );

        List<CellValue> row = [
          TextCellValue(participant.registrationNumber?.toString() ?? ''),
        ];

        if (ageGroup == 'كبار') {
          row.addAll([
            TextCellValue(eval.noteModel.noteTajwid?.toString() ?? ''),
            TextCellValue(eval.noteModel.noteHousnSawtt?.toString() ?? ''),
            TextCellValue(eval.noteModel.noteOu4oubetSawtt?.toString() ?? ''),
            TextCellValue(eval.noteModel.noteWaqfAndIbtidaa?.toString() ?? ''),
            TextCellValue(eval.noteModel.result?.toString() ?? ''),
          ]);
        } else {
          row.addAll([
            TextCellValue(eval.noteModel.noteTajwid?.toString() ?? ''),
            TextCellValue(eval.noteModel.noteHousnSawtt?.toString() ?? ''),
            TextCellValue(eval.noteModel.noteIltizamRiwaya?.toString() ?? ''),
            TextCellValue(eval.noteModel.result?.toString() ?? ''),
          ]);
        }

        sheet.appendRow(row);
      }

      final List<int>? bytes = excel.encode();
      if (bytes == null) {
        print("❌ Erreur lors de l'encodage.");
        return;
      }
      final Uint8List fileBytes = Uint8List.fromList(bytes);

      final Directory dir = await getTemporaryDirectory();

      final fileName =
          'تصحيح_الشيخ_${juryName.replaceAll(" ", "_")}_فئة_${ageGroup.replaceAll(" ", "_")}_$roundName.xlsx';
      final filePath = '${dir.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(fileBytes);

      await Share.shareXFiles([
        XFile(filePath),
      ], text: '📄 ملف تصحيح: $fileName');
      print("✅ Fichier prêt : $filePath");
    }
  }
}

class EvaluationResult {
  final List<Evaluation> evaluations;
  final List<Participant> participants;

  EvaluationResult({required this.evaluations, required this.participants});
}
