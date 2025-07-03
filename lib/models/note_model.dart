class NoteModel {
  double? _noteTajwid;
  double? _noteHousnSawtt;
  double? _noteOu4oubetSawtt;
  double? _noteWaqfAndIbtidaa;
  double? _noteIltizamRiwaya;
  double? _result;

  NoteModel({
    double? noteTajwid,
    double? noteHousnSawtt,
    double? noteOu4oubetSawtt,
    double? noteWaqfAndIbtidaa,
    double? noteIltizamRiwaya,
    double? result,
  }) : _noteTajwid = noteTajwid,
       _noteHousnSawtt = noteHousnSawtt,
       _noteOu4oubetSawtt = noteOu4oubetSawtt,
       _noteWaqfAndIbtidaa = noteWaqfAndIbtidaa,
       _noteIltizamRiwaya = noteIltizamRiwaya,
       _result = result;

  // setters
  set noteTajwid(double? value) {
    _noteTajwid = value;
  }

  set noteHousnSawtt(double? value) {
    _noteHousnSawtt = value;
  }

  set noteOu4oubetSawtt(double? value) {
    _noteOu4oubetSawtt = value;
  }

  set noteWaqfAndIbtidaa(double? value) {
    _noteWaqfAndIbtidaa = value;
  }

  set noteIltizamRiwaya(double? value) {
    _noteIltizamRiwaya = value;
  }

  set result(double? value) {
    _result = value;
  }

  // getters
  double? get noteTajwid => _noteTajwid;
  double? get noteHousnSawtt => _noteHousnSawtt;
  double? get noteOu4oubetSawtt => _noteOu4oubetSawtt;
  double? get noteWaqfAndIbtidaa => _noteWaqfAndIbtidaa;
  double? get noteIltizamRiwaya => _noteIltizamRiwaya;
  double? get result => _result;

  // for adult participants
  NoteModel.fromMapAdult(Map<String, dynamic> map) {
    noteTajwid = (map["التجويد"] as num?)?.toDouble();
    noteHousnSawtt = (map["حسن الصوت"] as num?)?.toDouble();
    noteOu4oubetSawtt = (map["عذوبة الصوت"] as num?)?.toDouble();
    noteWaqfAndIbtidaa = (map["الوقف والإبتداء"] as num?)?.toDouble();
    result = (map["النتيجة"] as num?)?.toDouble();
  }

  // for children participants
  NoteModel.fromMapChild(Map<String, dynamic> map) {
    noteTajwid = (map["التجويد"] as num?)?.toDouble();
    noteHousnSawtt = (map["حسن الصوت"] as num?)?.toDouble();
    noteIltizamRiwaya = (map["الإلتزام بالرواية"] as num?)?.toDouble();
    result = (map["النتيجة"] as num?)?.toDouble();
  }

  // to MapAdult
  Map<String, dynamic>? toMapChild() {
    return {
      "التجويد": _noteTajwid,
      "حسن الصوت": _noteHousnSawtt,
      "الإلتزام بالرواية": _noteIltizamRiwaya,
      "النتيجة": _result,
    };
  }

  // to MapChild
  Map<String, dynamic>? toMapAdult() {
    return {
      "التجويد": _noteTajwid,
      "حسن الصوت": _noteHousnSawtt,
      "عذوبة الصوت": _noteOu4oubetSawtt,
      "الوقف والإبتداء": _noteWaqfAndIbtidaa,
      "النتيجة": _result,
    };
  }
}
