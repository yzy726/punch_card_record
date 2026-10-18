import 'package:punch_card_record/models/punch_data.dart';
import 'package:punch_card_record/models/punch_workspace.dart';
import 'package:punch_card_record/services/storage_service.dart';

class MemoryStorage extends StorageService {
  MemoryStorage([PunchData? initial])
    : workspace = PunchWorkspace.single(initial ?? PunchData());
  MemoryStorage.workspace(this.workspace);

  PunchWorkspace workspace;
  PunchData get data => workspace.active.data;
  bool failLoad = false;
  bool failNextSave = false;
  int writes = 0;

  @override
  Future<PunchWorkspace> load() async {
    if (failLoad) throw StateError('Simulated read failure');
    return workspace;
  }

  @override
  Future<void> save(PunchWorkspace value) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('Simulated write failure');
    }
    workspace = value;
    writes++;
  }
}
