import 'package:punch_card_record/models/punch_data.dart';
import 'package:punch_card_record/services/storage_service.dart';

class MemoryStorage extends StorageService {
  MemoryStorage([PunchData? initial]) : data = initial ?? PunchData();

  PunchData data;
  bool failLoad = false;
  bool failNextSave = false;
  int writes = 0;

  @override
  Future<PunchData> load() async {
    if (failLoad) throw StateError('Simulated read failure');
    return data;
  }

  @override
  Future<void> save(PunchData value) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('Simulated write failure');
    }
    data = value;
    writes++;
  }
}
