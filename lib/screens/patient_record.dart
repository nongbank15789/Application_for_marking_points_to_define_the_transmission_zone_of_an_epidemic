// lib/models/patient_record.dart
class PatientRecord {
  final int? id;
  final String? name;
  final String? disease;
  final String? startDate;
  final String? endDate;
  final String? phoneNumber;
  final String? dangerLevel;
  final String? description;
  final String? dangerRange;
  final String? latitude;
  final String? longitude;

  // ที่อยู่ (ตรงกับตารางในรูป)
  final String? houseNo;      // pat_address_house_no
  final String? soi;          // pat_address_soi
  final String? road;         // pat_address_road
  final String? village;      // pat_address_village
  final String? moo;          // pat_address_moo
  final String? subdistrict;  // pat_address_subdistrict
  final String? district;     // pat_address_district
  final String? province;     // pat_address_province
  final String? postcode;     // pat_address_postcode
  final String? landmark;     // pat_address_landmark
  final String? addressFull;  // pat_address_full

  PatientRecord({
    this.id,
    this.name,
    this.disease,
    this.startDate,
    this.endDate,
    this.phoneNumber,
    this.dangerLevel,
    this.description,
    this.dangerRange,
    this.latitude,
    this.longitude,
    this.houseNo,
    this.soi,
    this.road,
    this.village,
    this.moo,
    this.subdistrict,
    this.district,
    this.province,
    this.postcode,
    this.landmark,
    this.addressFull,
  });

  factory PatientRecord.fromJson(Map<String, dynamic> j) {
    String? pick(String k) => j[k]?.toString();
    int? pickInt(String k) => int.tryParse(j[k]?.toString() ?? '');
    return PatientRecord(
      id: pickInt('pat_id'),
      name: pick('pat_name'),
      disease: pick('pat_epidemic'),
      startDate: pick('pat_infection_date'),
      endDate: pick('pat_recovery_date'),
      phoneNumber: pick('pat_phone'),
      dangerLevel: pick('pat_danger_level'),
      description: pick('pat_description'),
      dangerRange: pick('pat_danger_range'),
      latitude: pick('pat_latitude'),
      longitude: pick('pat_longitude'),
      houseNo: pick('pat_address_house_no'),
      soi: pick('pat_address_soi'),
      road: pick('pat_address_road'),
      village: pick('pat_address_village'),
      moo: pick('pat_address_moo'),
      subdistrict: pick('pat_address_subdistrict'),
      district: pick('pat_address_district'),
      province: pick('pat_address_province'),
      postcode: pick('pat_address_postcode'),
      landmark: pick('pat_address_landmark'),
      addressFull: pick('pat_address_full'),
    );
  }

  String fullAddress() {
    // ถ้ามี address_full ให้ใช้เป็นหลัก
    if ((addressFull ?? '').trim().isNotEmpty) return addressFull!.trim();

    final parts = <String>[];
    if ((houseNo ?? '').isNotEmpty) parts.add('บ้านเลขที่ $houseNo');
    if ((village ?? '').isNotEmpty) parts.add('บ้าน $village');
    if ((moo ?? '').isNotEmpty) parts.add('หมู่ $moo');
    if ((soi ?? '').isNotEmpty) parts.add('ซ.${soi!}');
    if ((road ?? '').isNotEmpty) parts.add('ถ.${road!}');
    if ((subdistrict ?? '').isNotEmpty) parts.add('ต.${subdistrict!}');
    if ((district ?? '').isNotEmpty) parts.add('อ.${district!}');
    if ((province ?? '').isNotEmpty) parts.add('จ.${province!}');
    if ((postcode ?? '').isNotEmpty) parts.add(postcode!);
    if ((landmark ?? '').isNotEmpty) parts.add('จุดสังเกต: $landmark');

    return parts.isEmpty ? '-' : parts.join(' ');
  }
}
