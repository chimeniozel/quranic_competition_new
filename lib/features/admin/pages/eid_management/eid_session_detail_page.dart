import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/eid_session_service.dart';
import 'package:quranic_competition/models/eid_session.dart';
import 'package:quranic_competition/models/eid_participant.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';
import '../../../../core/widgets/loading_states.dart';

class EidSessionDetailPage extends StatefulWidget {
  final EidSession session;

  const EidSessionDetailPage({super.key, required this.session});

  @override
  State<EidSessionDetailPage> createState() => _EidSessionDetailPageState();
}

class _EidSessionDetailPageState extends State<EidSessionDetailPage> {
  final EidSessionService _service = EidSessionService();
  List<EidParticipant> _participants = [];
  List<EidParticipant> _winners = [];
  bool _isLoading = false;
  int _participantCount = 0;
  late EidSession _currentSession;
  final TextEditingController _numberOfWinnersController =
      TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _currentSession = widget.session;
    _loadData();
  }

  @override
  void dispose() {
    _numberOfWinnersController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Recharger la session pour avoir les dernières données
      final sessions = await _service.getAllSessions();
      final updatedSession = sessions.firstWhere(
        (s) => s.id == _currentSession.id,
        orElse: () => _currentSession,
      );

      final participants = await _service.getParticipantsBySession(
        _currentSession.id,
      );
      final winners = await _service.getWinners(_currentSession.id);
      final count = await _service.getParticipantCount(_currentSession.id);

      setState(() {
        _currentSession = updatedSession;
        _participants = participants;
        _winners = winners;
        _participantCount = count;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل البيانات: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _showLotteryDialog() async {
    if (_participants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد مشاركون في هذه الفسحة أو الدورة'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    _numberOfWinnersController.clear();
    _numberOfWinnersController.text = '1';

    // Fermer le clavier avant d'ouvrir le dialogue
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 100));

    final numberOfWinners = await showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return PopScope(
          canPop: true,
          onPopInvoked: (didPop) {
            // Fermer le clavier quand le dialogue se ferme
            if (didPop) {
              FocusScope.of(context).unfocus();
              SystemChannels.textInput.invokeMethod('TextInput.hide');
            }
          },
          child: AlertDialog(
            title: const Text('اختيار عدد الفائزين في القرعة'),
            content: TextField(
              controller: _numberOfWinnersController,
              keyboardType: TextInputType.number,
              autofocus: false,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'عدد الفائزين (1-10)',
                hintText: '1',
                helperText: 'الحد الأقصى: 10 فائزين',
              ),
              onSubmitted: (value) async {
                // Fermer le clavier
                FocusScope.of(context).unfocus();
                SystemChannels.textInput.invokeMethod('TextInput.hide');

                final count = int.tryParse(value);
                if (count != null && count >= 1 && count <= 10) {
                  if (count > _participants.length) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'عدد المشاركين (${_participants.length}) أقل من عدد الفائزين المطلوبة ($count). الرجاء إدخال رقم بين 1 و ${_participants.length < 10 ? _participants.length : 10}',
                        ),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  } else {
                    Navigator.of(context).pop(count);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('يرجى إدخال رقم صحيح بين 1 و 10'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // Fermer le clavier
                  FocusScope.of(context).unfocus();
                  SystemChannels.textInput.invokeMethod('TextInput.hide');
                  _numberOfWinnersController.clear();
                  Navigator.of(context).pop();
                },
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Fermer le clavier
                  FocusScope.of(context).unfocus();
                  SystemChannels.textInput.invokeMethod('TextInput.hide');

                  await Future.delayed(const Duration(milliseconds: 100));

                  final count = int.tryParse(_numberOfWinnersController.text);
                  if (count != null && count >= 1 && count <= 10) {
                    if (count > _participants.length) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'عدد المشاركين (${_participants.length}) أقل من عدد الفائزين المطلوبة ($count). الرجاء إدخال رقم بين 1 و ${_participants.length < 10 ? _participants.length : 10}',
                          ),
                          backgroundColor: AppTheme.errorColor,
                        ),
                      );
                    } else {
                      if (context.mounted) {
                        Navigator.of(context).pop(count);
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('يرجى إدخال رقم صحيح بين 1 و 10'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                },
                child: const Text('موافق'),
              ),
            ],
          ),
        );
      },
    );

    if (numberOfWinners != null && numberOfWinners > 0) {
      await _selectWinners(numberOfWinners);
    }
  }

  Future<void> _selectWinners(int numberOfWinners) async {
    // Afficher un dialog de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: AppTheme.spacingS),
                const Text('جاري إجراء القرعة...'),
              ],
            ),
          ),
    );

    try {
      final winners = await _service.selectWinners(
        sessionId: _currentSession.id,
        numberOfWinners: numberOfWinners,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Fermer le dialog de chargement
        await _loadData();

        // Afficher un dialog avec les gagnants
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('🎉 الفائزون 🎉'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        winners.map((winner) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppTheme.spacingS,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.stars,
                                  color: AppTheme.warningColor,
                                  size: 20,
                                ),
                                const SizedBox(width: AppTheme.spacingS),
                                Expanded(
                                  child: Text(
                                    '${winner.fullName} - ${winner.phone}',
                                    style: AppTheme.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('موافق'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Fermer le dialog de chargement
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _resetWinners() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تأكيد إعادة التعيين'),
            content: const Text(
              'هل أنت متأكد من إعادة تعيين الفائزين؟ يمكنك بعد ذلك إجراء قرعة جديدة.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('إعادة التعيين'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await _service.resetWinners(_currentSession.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إعادة تعيين الفائزين'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteParticipant(EidParticipant participant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text('هل أنت متأكد من حذف ${participant.fullName}؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                ),
                child: const Text('حذف'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await _service.deleteParticipant(participant.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم الحذف بنجاح'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في الحذف: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: _currentSession.name,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'تعديل الفسحة أو الدورة',
            onPressed: () async {
              final result = await context.push(
                '/admin/eid-sessions/${_currentSession.id}/edit',
                extra: _currentSession,
              );
              if (result == true) {
                Navigator.of(context).pop(true);
              }
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const ModernLoadingIndicator()
              : DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    TabBar(
                      labelColor: AppTheme.primaryColor,
                      tabs: const [
                        Tab(text: 'المشاركون'),
                        Tab(text: 'الفائزون'),
                        Tab(text: 'الإعدادات'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildParticipantsTab(),
                          _buildWinnersTab(),
                          _buildSettingsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildParticipantsTab() {
    return ModernPullToRefresh(
      onRefresh: _loadData,
      child:
          _participants.isEmpty
              ? EmptyState(
                icon: Icons.people_outline,
                title: 'لا يوجد مشاركون',
                subtitle: 'لم يسجل أي شخص بعد في هذه الفسحة أو الدورة',
              )
              : ListView.builder(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                itemCount: _participants.length,
                itemBuilder: (context, index) {
                  final participant = _participants[index];
                  return _buildParticipantCard(participant);
                },
              ),
    );
  }

  Widget _buildWinnersTab() {
    return ModernPullToRefresh(
      onRefresh: _loadData,
      child:
          _winners.isEmpty
              ? EmptyState(
                icon: Icons.emoji_events_outlined,
                title: 'لا يوجد فائزون بعد',
                subtitle: 'قم بإجراء القرعة لاختيار الفائزين',
              )
              : ListView.builder(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                itemCount: _winners.length,
                itemBuilder: (context, index) {
                  final winner = _winners[index];
                  return _buildWinnerCard(winner);
                },
              ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Paramètres de la session
          ModernCard(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إعدادات الفسحة أو الدورة',
                    style: AppTheme.headingSmall,
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          onPressed:
                              () => _toggleSessionActive(_currentSession),
                          text:
                              _currentSession.isActive
                                  ? 'إخفاء الفسحة أو الدورة'
                                  : 'تفعيل الفسحة أو الدورة',
                          icon:
                              _currentSession.isActive
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        child: SecondaryButton(
                          onPressed: () => _toggleSessionOpen(_currentSession),
                          text:
                              _currentSession.isOpen
                                  ? 'إغلاق التسجيل'
                                  : 'فتح التسجيل',
                          icon:
                              _currentSession.isOpen
                                  ? Icons.lock
                                  : Icons.lock_open,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  SizedBox(
                    width: double.infinity,
                    child: SecondaryButton(
                      onPressed: () => _deleteSession(_currentSession),
                      text: 'حذف الفسحة',
                      icon: Icons.delete,
                      borderColor: AppTheme.errorColor,
                      textColor: AppTheme.errorColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          // Loterie
          ModernCard(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('إجراء القرعة', style: AppTheme.headingSmall),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    'عدد المشاركين: $_participantCount',
                    style: AppTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      onPressed:
                          (_currentSession.isActive && !_currentSession.isOpen)
                              ? _showLotteryDialog
                              : null,
                      text: '🎲 القرعة',
                      icon: Icons.casino,
                    ),
                  ),
                  if (!_currentSession.isActive || _currentSession.isOpen) ...[
                    const SizedBox(height: AppTheme.spacingS),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingS),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        border: Border.all(
                          color: AppTheme.warningColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppTheme.warningColor,
                            size: 20,
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Expanded(
                            child: Text(
                              !_currentSession.isActive
                                  ? 'يجب تفعيل الفسحة أو الدورة لإجراء القرعة'
                                  : 'يجب إغلاق التسجيل لإجراء القرعة',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.warningColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_winners.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingS),
                    SizedBox(
                      width: double.infinity,
                      child: SecondaryButton(
                        onPressed: _resetWinners,
                        text: 'إعادة تعيين الفائزين',
                        icon: Icons.refresh,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSessionActive(EidSession session) async {
    try {
      await _service.updateSession(id: session.id, isActive: !session.isActive);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              session.isActive
                  ? 'تم إخفاء الفسحة أو الدورة'
                  : 'تم تفعيل الفسحة أو الدورة',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
        // Mettre à jour le widget avec les nouvelles données
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _toggleSessionOpen(EidSession session) async {
    try {
      final updatedSession = await _service.updateSession(
        id: session.id,
        isOpen: !session.isOpen,
      );

      // Mettre à jour l'état local
      setState(() {
        _currentSession = updatedSession;
      });

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updatedSession.isOpen ? 'تم فتح التسجيل' : 'تم إغلاق التسجيل',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _deleteSession(EidSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text(
              'هل أنت متأكد من حذف الفسحة أو الدورة "${session.name}"؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                ),
                child: const Text('حذف'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await _service.deleteSession(session.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم الحذف بنجاح'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          context.pop(true); // Retourner à la liste avec un résultat positif
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في الحذف: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  Widget _buildParticipantCard(EidParticipant participant) {
    return ModernCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              participant.gender == 'ذكر'
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.pink.withOpacity(0.1),
          child: Icon(
            participant.gender == 'ذكر' ? Icons.male : Icons.female,
            color: participant.gender == 'ذكر' ? Colors.blue : Colors.pink,
          ),
        ),
        title: Text(
          participant.fullName,
          style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(participant.phone),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: AppTheme.errorColor),
          onPressed: () => _deleteParticipant(participant),
        ),
      ),
    );
  }

  Widget _buildWinnerCard(EidParticipant winner) {
    return ModernCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.warningColor.withOpacity(0.1),
              AppTheme.warningColor.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(AppTheme.spacingS),
            decoration: BoxDecoration(
              color: AppTheme.warningColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.stars, color: Colors.white, size: 20),
          ),
          title: Text(
            winner.fullName,
            style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(winner.phone),
        ),
      ),
    );
  }
}
