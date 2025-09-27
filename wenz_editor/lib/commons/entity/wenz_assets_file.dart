class WenzAssetsFile {
  int? id;
  String? uuid;
  String? type;
  String? name;
  String? path;
  String? url;
  int? size;
  int? createTime;
  int? updateTime;

  WenzAssetsFile({
    this.id,
    this.uuid,
    this.type,
    this.name,
    this.path,
    this.url,
    this.size,
    this.createTime,
    this.updateTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'uuid': this.uuid,
      'type': this.type,
      'name': this.name,
      'path': this.path,
      'url': this.url,
      'size': this.size,
      'createTime': this.createTime,
      'updateTime': this.updateTime,
    };
  }

  factory WenzAssetsFile.fromMap(Map<String, dynamic> map) {
    return WenzAssetsFile(
      uuid: map['uuid'] as String?,
      type: map['type'] as String?,
      name: map['name'] as String?,
      path: map['path'] as String?,
      url: map['url'] as String?,
      size: map['size'] as int?,
      createTime: map['createTime'] as int?,
      updateTime: map['updateTime'] as int?,
    );
  }
}
