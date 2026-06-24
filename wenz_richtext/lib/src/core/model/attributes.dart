class TextAttributes {
  const TextAttributes({
    this.color,
    this.background,
    this.bold,
    this.italic,
    this.fontSize,
    this.fontFamily,
    this.underline,
    this.lineThrough,
    this.remark,
    this.url,
    this.commentIds = const <String>[],
    this.revisionIds = const <String>[],
  });

  final int? color;
  final int? background;
  final bool? bold;
  final bool? italic;
  final double? fontSize;
  final String? fontFamily;
  final bool? underline;
  final bool? lineThrough;
  final bool? remark;
  final String? url;
  final List<String> commentIds;
  final List<String> revisionIds;

  bool get isEmpty =>
      color == null &&
      background == null &&
      bold == null &&
      italic == null &&
      fontSize == null &&
      fontFamily == null &&
      underline == null &&
      lineThrough == null &&
      remark == null &&
      url == null &&
      commentIds.isEmpty &&
      revisionIds.isEmpty;

  TextAttributes inheritFrom(TextAttributes parent) {
    return TextAttributes(
      color: color ?? parent.color,
      background: background ?? parent.background,
      bold: bold ?? parent.bold,
      italic: italic ?? parent.italic,
      fontSize: fontSize ?? parent.fontSize,
      fontFamily: fontFamily ?? parent.fontFamily,
      underline: underline ?? parent.underline,
      lineThrough: lineThrough ?? parent.lineThrough,
      remark: remark ?? parent.remark,
      url: url ?? parent.url,
      commentIds: commentIds.isEmpty ? parent.commentIds : commentIds,
      revisionIds: revisionIds.isEmpty ? parent.revisionIds : revisionIds,
    );
  }

  TextAttributes copyWith({
    int? color,
    int? background,
    bool? bold,
    bool? italic,
    double? fontSize,
    String? fontFamily,
    bool? underline,
    bool? lineThrough,
    bool? remark,
    String? url,
    List<String>? commentIds,
    List<String>? revisionIds,
  }) {
    return TextAttributes(
      color: color ?? this.color,
      background: background ?? this.background,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      underline: underline ?? this.underline,
      lineThrough: lineThrough ?? this.lineThrough,
      remark: remark ?? this.remark,
      url: url ?? this.url,
      commentIds: commentIds ?? this.commentIds,
      revisionIds: revisionIds ?? this.revisionIds,
    );
  }

  TextAttributes mergeWith(TextAttributes overlay) {
    return TextAttributes(
      color: overlay.color ?? color,
      background: overlay.background ?? background,
      bold: overlay.bold ?? bold,
      italic: overlay.italic ?? italic,
      fontSize: overlay.fontSize ?? fontSize,
      fontFamily: overlay.fontFamily ?? fontFamily,
      underline: overlay.underline ?? underline,
      lineThrough: overlay.lineThrough ?? lineThrough,
      remark: overlay.remark ?? remark,
      url: overlay.url ?? url,
      commentIds: overlay.commentIds.isEmpty ? commentIds : overlay.commentIds,
      revisionIds:
          overlay.revisionIds.isEmpty ? revisionIds : overlay.revisionIds,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (color != null) 'color': color,
      if (background != null) 'background': background,
      if (bold != null) 'bold': bold,
      if (italic != null) 'italic': italic,
      if (fontSize != null) 'fontSize': fontSize,
      if (fontFamily != null) 'fontFamily': fontFamily,
      if (underline != null) 'underline': underline,
      if (lineThrough != null) 'lineThrough': lineThrough,
      if (remark != null) 'remark': remark,
      if (url != null) 'url': url,
      if (commentIds.isNotEmpty) 'commentIds': commentIds,
      if (revisionIds.isNotEmpty) 'revisionIds': revisionIds,
    };
  }

  factory TextAttributes.fromJson(Map<String, Object?> json) {
    return TextAttributes(
      color: _asInt(json['color']),
      background: _asInt(json['background']),
      bold: json['bold'] as bool?,
      italic: json['italic'] as bool?,
      fontSize: _asDouble(json['fontSize']),
      fontFamily: json['fontFamily'] as String?,
      underline: json['underline'] as bool?,
      lineThrough: json['lineThrough'] as bool?,
      remark: json['remark'] as bool?,
      url: json['url'] as String?,
      commentIds: _asStringList(json['commentIds']),
      revisionIds: _asStringList(json['revisionIds']),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TextAttributes &&
        other.color == color &&
        other.background == background &&
        other.bold == bold &&
        other.italic == italic &&
        other.fontSize == fontSize &&
        other.fontFamily == fontFamily &&
        other.underline == underline &&
        other.lineThrough == lineThrough &&
        other.remark == remark &&
        other.url == url &&
        _listEquals(other.commentIds, commentIds) &&
        _listEquals(other.revisionIds, revisionIds);
  }

  @override
  int get hashCode {
    return Object.hash(
      color,
      background,
      bold,
      italic,
      fontSize,
      fontFamily,
      underline,
      lineThrough,
      remark,
      url,
      Object.hashAll(commentIds),
      Object.hashAll(revisionIds),
    );
  }
}

class BlockAttributes {
  const BlockAttributes({
    this.level,
    this.indent,
    this.alignment,
    this.listType,
    this.checked,
    this.childNote,
    this.anchor,
  });

  final int? level;
  final int? indent;
  final String? alignment;
  final String? listType;
  final bool? checked;
  final String? childNote;
  final String? anchor;

  bool get isEmpty =>
      level == null &&
      indent == null &&
      alignment == null &&
      listType == null &&
      checked == null &&
      childNote == null &&
      anchor == null;

  BlockAttributes mergeWith(BlockAttributes overlay) {
    return BlockAttributes(
      level: overlay.level ?? level,
      indent: overlay.indent ?? indent,
      alignment: overlay.alignment ?? alignment,
      listType: overlay.listType ?? listType,
      checked: overlay.checked ?? checked,
      childNote: overlay.childNote ?? childNote,
      anchor: overlay.anchor ?? anchor,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (level != null) 'level': level,
      if (indent != null) 'indent': indent,
      if (alignment != null) 'alignment': alignment,
      if (listType != null) 'listType': listType,
      if (checked != null) 'checked': checked,
      if (childNote != null) 'childNote': childNote,
      if (anchor != null) 'anchor': anchor,
    };
  }

  factory BlockAttributes.fromJson(Map<String, Object?> json) {
    return BlockAttributes(
      level: _asInt(json['level']),
      indent: _asInt(json['indent']),
      alignment: json['alignment'] as String?,
      listType: json['listType'] as String?,
      checked: json['checked'] as bool?,
      childNote: json['childNote'] as String?,
      anchor: json['anchor'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BlockAttributes &&
        other.level == level &&
        other.indent == indent &&
        other.alignment == alignment &&
        other.listType == listType &&
        other.checked == checked &&
        other.childNote == childNote &&
        other.anchor == anchor;
  }

  @override
  int get hashCode {
    return Object.hash(
      level,
      indent,
      alignment,
      listType,
      checked,
      childNote,
      anchor,
    );
  }
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

double? _asDouble(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return null;
}

List<String> _asStringList(Object? value) {
  if (value is List) {
    return value.whereType<String>().toList();
  }
  return const <String>[];
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
