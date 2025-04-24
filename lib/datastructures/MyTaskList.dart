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

  Mytask remove() {
    return _taskList.removeLast();
  }
}
