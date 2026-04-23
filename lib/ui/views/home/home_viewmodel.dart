import 'package:stacked/stacked.dart';

class HomeViewModel extends BaseViewModel {
  int _currentIndex = 1;

  int get currentIndex => _currentIndex;

  void setIndex(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    rebuildUi();
  }
}
