import 'package:flatorg/datastructures/MyTask.dart';

class Mytasklist {
  final List<Mytask> _taskList;
  int _maxdifficulty = 0;

  Mytasklist(this._taskList, this._maxdifficulty);

  void setMaxDifficulty(int newDiff) {
    _maxdifficulty = newDiff;
  }

  int getMaxDifficulty() {
    return _maxdifficulty;
  }

  void append(Mytask newTask) {
    _taskList.add(newTask);
  }

  // TODO: REORDER FUNCTION
  bool reorder(Mytask task, int oldPos, int newPos) {
    if (oldPos < 0 ||
        oldPos >= _taskList.length ||
        newPos < 0 ||
        newPos >= _taskList.length) {
      return false;
    }

    _taskList.removeAt(oldPos);
    _taskList.insert(newPos, task);

    return true;
  }

  Mytask remove() {
    return _taskList.removeLast();
  }
}
