// import 'package:flutter/material.dart';
// import 'package:quranic_competition/core/services/user_service.dart';
// import 'package:quranic_competition/core/services/round_jury_service.dart';
// import 'package:quranic_competition/models/app_user.dart';
// import 'package:quranic_competition/models/competition_version.dart';
// import 'package:quranic_competition/models/round.dart';
// import 'package:quranic_competition/core/services/evaluation_service.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import '../../../../core/widgets/modern_navigation.dart';
// import '../../../../core/widgets/ui_components.dart';
// import '../../../../core/widgets/loading_states.dart';
// import '../../../../core/theme/app_theme.dart';

// class RoundJurysPage extends StatefulWidget {
//   final CompetitionVersion version;

//   const RoundJurysPage({super.key, required this.version});

//   @override
//   State<RoundJurysPage> createState() => _RoundJurysPageState();
// }

// class _RoundJurysPageState extends State<RoundJurysPage> {
//   final UserService _userService = UserService();
//   final RoundJuryService _roundJuryService = RoundJuryService();
//   final EvaluationService _evaluationService = EvaluationService();

//   Map<String, List<AppUser>> _jurysByRound = {};
//   List<Round> _rounds = [];
//   bool _isLoading = true;
//   bool _isCheckingEvaluations = false;

//   @override
//   void initState() {
//     super.initState();
//     _loadRoundsAndJurys();
//   }

//   Future<void> _loadRoundsAndJurys() async {
//     print(
//       '🔄 Chargement des rounds et jurys pour la version: ${widget.version.id}',
//     );
//     setState(() => _isLoading = true);

//     try {
//       // 1. Charger les rounds de la version
//       final roundsResponse = await Supabase.instance.client
//           .from('rounds')
//           .select()
//           .eq('version_id', widget.version.id)
//           .order('number');

//       _rounds = roundsResponse.map<Round>((r) => Round.fromMap(r)).toList();
//       print('✅ ${_rounds.length} rounds récupérés');

//       // 2. Charger les jurys pour chaque round
//       _jurysByRound.clear();
//       for (final round in _rounds) {
//         final jurys = await _roundJuryService.getJurysByRound(round.id);
//         _jurysByRound[round.id] = jurys;
//         print('🎯 Round ${round.number}: ${jurys.length} jurys');
//       }

//       if (!mounted) return;
//       setState(() => _isLoading = false);
//     } catch (e) {
//       print('❌ Erreur lors du chargement: $e');
//       if (!mounted) return;
//       setState(() => _isLoading = false);
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('خطأ أثناء تحميل البيانات: $e')));
//     }
//   }

//   Future<void> _refreshRoundJurys(String roundId) async {
//     try {
//       final jurys = await _roundJuryService.getJurysByRound(roundId);
//       setState(() {
//         _jurysByRound[roundId] = jurys;
//       });
//     } catch (e) {
//       print('❌ Erreur lors du rechargement des jurys: $e');
//     }
//   }

//   Future<void> _showAddJurySheet() async {
//     print('📋 Affichage de la feuille d\'ajout de jury');

//     // Vérifier si l'évaluation des jurys est activée
//     if (widget.version.juryEvaluationEnabled) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('لا يمكن إضافة مصححين أثناء تفعيل التقييم'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       return;
//     }

//     if (_selectedRound == null) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('يرجى اختيار جولة أولاً'),
//           backgroundColor: Colors.red,
//         ),
//       );
//       return;
//     }

//     // Récupérer tous les utilisateurs avec le rôle "jury"
//     final allJurys = await _userService.getAllJurys();

//     // Filtrer les jurys déjà assignés à ce round
//     final assignedJuryIds = _jurys.map((j) => j.id).toSet();
//     final availableJurys =
//         allJurys.where((j) => !assignedJuryIds.contains(j.id)).toList();

//     if (availableJurys.isEmpty) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('لا يوجد مصححون متاحون للإضافة'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       return;
//     }

//     if (!mounted) return;
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => _buildAddJurySheet(availableJurys),
//     );
//   }

//   Widget _buildAddJurySheet(List<AppUser> availableJurys) {
//     return Container(
//       height: MediaQuery.of(context).size.height * 0.7,
//       decoration: BoxDecoration(
//         color: AppTheme.surfaceColor,
//         borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       child: Column(
//         children: [
//           // Handle
//           Container(
//             margin: const EdgeInsets.only(top: 12),
//             width: 40,
//             height: 4,
//             decoration: BoxDecoration(
//               color: AppTheme.textSecondaryColor,
//               borderRadius: BorderRadius.circular(2),
//             ),
//           ),

//           // Header
//           Padding(
//             padding: const EdgeInsets.all(20),
//             child: Row(
//               children: [
//                 Icon(Icons.person_add, color: AppTheme.primaryColor, size: 24),
//                 const SizedBox(width: 12),
//                 Text(
//                   'إضافة مصحح للجولة ${_selectedRound?.number}',
//                   style: AppTheme.headingMedium.copyWith(
//                     fontSize: 18,
//                     color: AppTheme.textPrimaryColor,
//                   ),
//                 ),
//                 const Spacer(),
//                 IconButton(
//                   onPressed: () => Navigator.pop(context),
//                   icon: Icon(Icons.close, color: AppTheme.textSecondaryColor),
//                 ),
//               ],
//             ),
//           ),

//           // List of available jurys
//           Expanded(
//             child: ListView.builder(
//               padding: const EdgeInsets.symmetric(horizontal: 20),
//               itemCount: availableJurys.length,
//               itemBuilder: (context, index) {
//                 final jury = availableJurys[index];
//                 return ModernCard(
//                   margin: const EdgeInsets.only(bottom: 12),
//                   child: ListTile(
//                     leading: CircleAvatar(
//                       backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
//                       child: Icon(Icons.person, color: AppTheme.primaryColor),
//                     ),
//                     title: Text(
//                       jury.fullName,
//                       style: AppTheme.bodyMedium.copyWith(
//                         fontWeight: FontWeight.w600,
//                         color: AppTheme.textPrimaryColor,
//                       ),
//                     ),
//                     subtitle: Text(
//                       jury.phone,
//                       style: AppTheme.bodySmall.copyWith(
//                         color: AppTheme.textSecondaryColor,
//                       ),
//                     ),
//                     trailing: ElevatedButton(
//                       onPressed: () => _addJuryToRound(jury),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: AppTheme.primaryColor,
//                         foregroundColor: Colors.white,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                       ),
//                       child: const Text('إضافة'),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _addJuryToRound(AppUser jury) async {
//     if (_selectedRound == null) return;

//     try {
//       print(
//         '➕ Ajout du jury ${jury.fullName} au round ${_selectedRound!.number}',
//       );

//       final success = await _roundJuryService.assignJuryToRound(
//         jury.id,
//         _selectedRound!.id,
//       );

//       if (success) {
//         if (!mounted) return;
//         Navigator.pop(context);

//         // Recharger la liste des jurys
//         await _loadJurysForSelectedRound();

//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('تم إضافة ${jury.fullName} بنجاح'),
//             backgroundColor: Colors.green,
//           ),
//         );
//       } else {
//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('فشل في إضافة المصحح'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } catch (e) {
//       print('❌ Erreur lors de l\'ajout du jury: $e');
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('خطأ أثناء إضافة المصحح: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   Future<void> _checkJuryHasEvaluatedAll(AppUser jury) async {
//     if (_selectedRound == null) return;

//     setState(() => _isCheckingEvaluations = true);

//     try {
//       print(
//         '🔍 Vérification des évaluations du jury ${jury.fullName} pour le round ${_selectedRound!.number}',
//       );

//       // Récupérer les évaluations du jury pour ce round
//       final evaluations = await _evaluationService.getEvaluationsByJuryInRound(
//         juryId: jury.id,
//         roundId: _selectedRound!.id,
//       );

//       print(
//         '📊 ${evaluations.length} évaluations trouvées pour ce jury dans ce round',
//       );

//       // Récupérer tous les participants acceptés pour ce round
//       final participantsResponse = await Supabase.instance.client
//           .from('participant_versions')
//           .select('participants(*)')
//           .eq('version_id', widget.version.id)
//           .eq('participants.is_accepted', true);

//       final totalParticipants = participantsResponse.length;
//       final evaluatedParticipants = evaluations.length;

//       print('👥 Participants acceptés: $totalParticipants');
//       print('📝 Participants évalués: $evaluatedParticipants');

//       final hasEvaluatedAll = evaluatedParticipants >= totalParticipants;

//       if (!mounted) return;
//       setState(() => _isCheckingEvaluations = false);

//       if (hasEvaluatedAll) {
//         _showRemoveJuryDialog(jury, keepEvaluations: true);
//       } else {
//         _showRemoveJuryDialog(jury, keepEvaluations: false);
//       }
//     } catch (e) {
//       print('❌ Erreur lors de la vérification des évaluations: $e');
//       if (!mounted) return;
//       setState(() => _isCheckingEvaluations = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('خطأ أثناء التحقق من التقييمات: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   void _showRemoveJuryDialog(AppUser jury, {required bool keepEvaluations}) {
//     showDialog(
//       context: context,
//       builder:
//           (context) => AlertDialog(
//             title: Text(
//               'إزالة المصحح',
//               style: AppTheme.headingMedium.copyWith(
//                 color: AppTheme.textPrimaryColor,
//               ),
//             ),
//             content: Text(
//               keepEvaluations
//                   ? 'هل تريد إزالة ${jury.fullName} من الجولة ${_selectedRound?.number}؟\n\nسيتم الاحتفاظ بتقييماته.'
//                   : 'هل تريد إزالة ${jury.fullName} من الجولة ${_selectedRound?.number}؟\n\nسيتم حذف جميع تقييماته.',
//               style: AppTheme.bodyMedium.copyWith(
//                 color: AppTheme.textSecondaryColor,
//               ),
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: Text(
//                   'إلغاء',
//                   style: TextStyle(color: AppTheme.textSecondaryColor),
//                 ),
//               ),
//               ElevatedButton(
//                 onPressed: () {
//                   Navigator.pop(context);
//                   _removeJury(jury, keepEvaluations: keepEvaluations);
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.red,
//                   foregroundColor: Colors.white,
//                 ),
//                 child: const Text('إزالة'),
//               ),
//             ],
//           ),
//     );
//   }

//   Future<void> _removeJury(
//     AppUser jury, {
//     required bool keepEvaluations,
//   }) async {
//     if (_selectedRound == null) return;

//     try {
//       print(
//         '➖ Suppression du jury ${jury.fullName} du round ${_selectedRound!.number}',
//       );

//       // Supprimer l'assignation du round
//       final success = await _roundJuryService.removeJuryFromRound(
//         jury.id,
//         _selectedRound!.id,
//       );

//       if (success) {
//         // Si on ne garde pas les évaluations, les supprimer
//         if (!keepEvaluations) {
//           await _evaluationService.deleteEvaluationsByJuryInVersion(
//             juryId: jury.id,
//             versionId: widget.version.id,
//           );
//           print('🗑️ Évaluations du jury supprimées');
//         }

//         // Recharger la liste des jurys
//         await _loadJurysForSelectedRound();

//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('تم إزالة ${jury.fullName} بنجاح'),
//             backgroundColor: Colors.green,
//           ),
//         );
//       } else {
//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('فشل في إزالة المصحح'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } catch (e) {
//       print('❌ Erreur lors de la suppression du jury: $e');
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('خطأ أثناء إزالة المصحح: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppTheme.backgroundColor,
//       appBar: ModernAppBar(
//         title: 'إدارة المصححين - ${widget.version.name}',
//         actions: [
//           if (_selectedRound != null)
//             IconButton(
//               onPressed: _showAddJurySheet,
//               icon: const Icon(Icons.person_add, color: Colors.white),
//             ),
//         ],
//       ),
//       body: _isLoading ? _buildLoadingState() : _buildContent(),
//     );
//   }

//   Widget _buildLoadingState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           CircularProgressIndicator(
//             valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
//           ),
//           const SizedBox(height: 16),
//           Text(
//             'جاري التحميل...',
//             style: AppTheme.bodyMedium.copyWith(
//               color: AppTheme.textSecondaryColor,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildContent() {
//     if (_rounds.isEmpty) {
//       return Center(
//         child: EmptyState(
//           icon: Icons.event_busy,
//           title: 'لا توجد جولات',
//           subtitle: 'لم يتم إنشاء أي جولات لهذه المسابقة بعد',
//         ),
//       );
//     }

//     return Column(
//       children: [
//         // Round selector
//         _buildRoundSelector(),

//         // Jurys list
//         Expanded(child: _buildJurysList()),
//       ],
//     );
//   }

//   Widget _buildRoundSelector() {
//     return Container(
//       margin: const EdgeInsets.all(16),
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       decoration: BoxDecoration(
//         color: AppTheme.surfaceColor,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: AppTheme.dividerColor, width: 1),
//       ),
//       child: Row(
//         children: [
//           Icon(Icons.event, color: AppTheme.primaryColor, size: 20),
//           const SizedBox(width: 12),
//           Text(
//             'الجولة:',
//             style: AppTheme.bodyMedium.copyWith(
//               fontWeight: FontWeight.w600,
//               color: AppTheme.textPrimaryColor,
//             ),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: DropdownButton<Round>(
//               value: _selectedRound,
//               isExpanded: true,
//               underline: const SizedBox(),
//               items:
//                   _rounds.map((round) {
//                     return DropdownMenuItem<Round>(
//                       value: round,
//                       child: Text(
//                         'الجولة ${round.number}${round.name != null ? ' - ${round.name}' : ''}',
//                         style: AppTheme.bodyMedium.copyWith(
//                           color: AppTheme.textPrimaryColor,
//                         ),
//                       ),
//                     );
//                   }).toList(),
//               onChanged: _onRoundChanged,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildJurysList() {
//     if (_selectedRound == null) {
//       return Center(
//         child: EmptyState(
//           icon: Icons.event_busy,
//           title: 'اختر جولة',
//           subtitle: 'يرجى اختيار جولة لعرض المصححين',
//         ),
//       );
//     }

//     if (_jurys.isEmpty) {
//       return Center(
//         child: EmptyState(
//           icon: Icons.people_outline,
//           title: 'لا يوجد مصححون',
//           subtitle: 'لم يتم تعيين أي مصححين لهذه الجولة بعد',
//           action: ElevatedButton(
//             onPressed: _showAddJurySheet,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: AppTheme.primaryColor,
//               foregroundColor: Colors.white,
//             ),
//             child: const Text('إضافة مصحح'),
//           ),
//         ),
//       );
//     }

//     return ListView.builder(
//       padding: const EdgeInsets.all(16),
//       itemCount: _jurys.length,
//       itemBuilder: (context, index) {
//         final jury = _jurys[index];
//         return ModernCard(
//           margin: const EdgeInsets.only(bottom: 12),
//           child: ListTile(
//             leading: CircleAvatar(
//               backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
//               child: Icon(Icons.person, color: AppTheme.primaryColor),
//             ),
//             title: Text(
//               jury.fullName,
//               style: AppTheme.bodyMedium.copyWith(
//                 fontWeight: FontWeight.w600,
//                 color: AppTheme.textPrimaryColor,
//               ),
//             ),
//             subtitle: Text(
//               jury.phone,
//               style: AppTheme.bodySmall.copyWith(
//                 color: AppTheme.textSecondaryColor,
//               ),
//             ),
//             trailing:
//                 _isCheckingEvaluations
//                     ? SizedBox(
//                       width: 20,
//                       height: 20,
//                       child: CircularProgressIndicator(
//                         strokeWidth: 2,
//                         valueColor: AlwaysStoppedAnimation<Color>(
//                           AppTheme.primaryColor,
//                         ),
//                       ),
//                     )
//                     : IconButton(
//                       onPressed: () => _checkJuryHasEvaluatedAll(jury),
//                       icon: Icon(Icons.delete_outline, color: Colors.red),
//                     ),
//           ),
//         );
//       },
//     );
//   }
// }
