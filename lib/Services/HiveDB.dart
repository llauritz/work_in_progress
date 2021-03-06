import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../hiveClasses/Zeitnahme.dart';
import 'Data.dart';
import 'Theme.dart';

class HiveDB {
  final GlobalKey<AnimatedListState> animatedListkey = GlobalKey<AnimatedListState>();
  final StreamController<int> listChangesStream = StreamController<int>.broadcast();
  int changeNumber = 0;
  int todayElapsedTime = 0;
  bool isRunning = false;
  final int ausVersehenWertSekunden = 5;

  final StreamController<int> ueberMillisekundenGesamtStream = StreamController<int>.broadcast();
  int ueberMillisekundenGesamt = 0;

  Future<void> initHiveDB() async {
    Box zeitenBox = Hive.box<Zeitnahme>("zeitenBox");
    if (zeitenBox.length > 0) {
      urlaubsTageCheck();
      checkForForgottenStop();
      calculateTodayElapsedTime();
      updateGesamtUeberstunden();
    }
  }

  void startTime(int startTime) async {
    print("HiveDB - startTime - start");
    Box zeitenBox = Hive.box<Zeitnahme>("zeitenBox");
    // Heutiger Tag in Variable
    print("HiveDB - startTime - length is" + zeitenBox.length.toString());
    if (zeitenBox.length >= 1) {
      Zeitnahme latest = zeitenBox.getAt(zeitenBox.length - 1);
      // Checks if latest entry in list is from today
      if (latest.day.isSameDate(DateTime.now())) {
        print("HiveDB - startTime - today already exists");
        changeState("default", zeitenBox.length - 1);
        updateTag("Stundenabbau", zeitenBox.length - 1);
        //Checks if the Lists are the same length before putting in new time
        if (latest.startTimes.length == latest.endTimes.length) {
          if (latest.endTimes.last > DateTime.now().millisecondsSinceEpoch) {
            print("endTime wurde in die Zukunft korrigiert -> wieder auf kurz vor jetzt");
            latest.endTimes.last = DateTime.now().millisecondsSinceEpoch - 1;
          }

          // checks if at least a few seconds have passed
          int davor = latest.endTimes.last;
          if (startTime - davor < Duration.millisecondsPerSecond * ausVersehenWertSekunden) {
            latest.endTimes.removeLast();
          } else {
            //Adds new Time to the List
            //latest.startTimes.add(startTime);
            latest.startTimes = List.from(latest.startTimes)..add(startTime);
          }

          //Saves the List
          zeitenBox.putAt(zeitenBox.length - 1, latest);
        } else {
          print("HiveDB - startTime - ERROR: EndTimes and StartTimes were not same length");
        }
        print("HiveDB - startZeit hinzugefügt");
      } else {
        // No Entry for Today -> Create new Entry with default values
        zeitenBox.add(Zeitnahme(day: DateTime.now(), state: "default", startTimes: [startTime], endTimes: []));
        print("HiveDB - neue Zeitnahme + startZeit hinzugefügt");
        animatedListkey.currentState!.insertItem(0, duration: Duration(milliseconds: 600));
      }
    } else {
      // First Entry ever -> Create new Entry with default values
      zeitenBox.add(Zeitnahme(day: DateTime.now(), state: "default", startTimes: [startTime], endTimes: []));
      print("HiveDB - neue Zeitnahme + startZeit hinzugefügt");
      animatedListkey.currentState!.insertItem(0, duration: Duration(milliseconds: 600));
    }

    listChangesStream.sink.add(changeNumber++);

    await urlaubsTageCheck();
  }

  void deleteAT(int i, int listindex) async {
    Box zeitenBox = Hive.box<Zeitnahme>("zeitenBox");
    animatedListkey.currentState!.removeItem(listindex, (context, animation) => Container());
    await zeitenBox.deleteAt(i);
    print("HiveDB - deleteAt - fertig");
  }

  void putAT(int i, Zeitnahme z, int listindex) async {
    Box zeitenBox = Hive.box<Zeitnahme>("zeitenBox");
    await zeitenBox.put(i, z);
    animatedListkey.currentState!.insertItem(listindex, duration: Duration(milliseconds: 600));
    logger.i("Zeitnahme hinzugefügt, i:" + i.toString(), "listindex: " + listindex.toString());
  }

  void endTime(int endTime) async {
    Box zeitenBox = Hive.box<Zeitnahme>("zeitenBox");

    //Adds the End time regardless of the Day -> You can end your workday at 3pm
    Zeitnahme latest = zeitenBox.getAt(zeitenBox.length - 1);

    if (latest.startTimes.length == latest.endTimes.length + 1) {
      if (latest.startTimes.length > 1) {
        int davor = latest.startTimes.last;
        if (endTime - davor < (Duration.millisecondsPerSecond * ausVersehenWertSekunden)) {
          latest.startTimes.removeLast();
        } else {
          //Adds new Time to the List
          //latest.endTimes.add(endTime);
          latest.endTimes = List.from(latest.endTimes)..add(endTime);
        }
      } else {
        latest.endTimes = List.from(latest.endTimes)..add(endTime);
      }

      zeitenBox.putAt(zeitenBox.length - 1, latest);
      logger.d('neue endTime an neuster Zeitnahme hinzugefügt' + latest.endTimes.toString());
    } else {
      logger.d('HiveDB - endTime - ERROR: StartTimes war nicht um eins größer');
    }

    listChangesStream.sink.add(changeNumber++);
  }

  Future<void> calculateTodayElapsedTime() async {
    Box zeitenBox = Hive.box<Zeitnahme>("zeitenBox");
    if (zeitenBox.length > 0) {
      Zeitnahme neusete = zeitenBox.getAt(zeitenBox.length - 1) as Zeitnahme;
      if (neusete.day.isSameDate(DateTime.now())) {
        todayElapsedTime = neusete.getElapsedTime();
        logger.v("HiveDB - today Elapsed Time is " + Duration(milliseconds: todayElapsedTime).toString());
      } else {
        todayElapsedTime = 0;
        logger.i("New Day -> Today Elapsed Time 0");
      }
    }
  }

  int getTodayElapsedTime() {
    Box zeitenBox = Hive.box<Zeitnahme>("zeitenBox");
    if (zeitenBox.length > 0) {
      Zeitnahme neusete = zeitenBox.getAt(zeitenBox.length - 1) as Zeitnahme;
      if (neusete.day.isSameDate(DateTime.now()) || getIt<Data>().isRunning) {
        return neusete.getElapsedTime();
      } else {
        return 0;
      }
    } else {
      return 0;
    }
  }

  Future<void> updateGesamtUeberstunden() async {
    Box zeitenBox = Hive.box<Zeitnahme>("zeitenBox");

    ueberMillisekundenGesamt = 0;

    for (int i = 0; i < zeitenBox.length; i++) {
      if (i == zeitenBox.length - 1 && isRunning) {
        print("HiveDB - skipped");
        continue;
      }

      Zeitnahme z = zeitenBox.getAt(i) as Zeitnahme;
      ueberMillisekundenGesamt = ueberMillisekundenGesamt + z.getUeberstunden();
      print("HiveDB - ueberMSG: " + ueberMillisekundenGesamt.toString());
    }

    ueberMillisekundenGesamt = ueberMillisekundenGesamt + await getIt<Data>().getOffset();

    print("HiveDB - final ueberMSG: " + ueberMillisekundenGesamt.toString());

    ueberMillisekundenGesamtStream.sink.add(ueberMillisekundenGesamt);
  }

  bool isSameDate(DateTime first, DateTime other) {
    return first.year == other.year && first.month == other.month && first.day == other.day;
  }

  Future<void> urlaubsTageCheck() async {
    print("HiveDB - urlaubscheck start");
    Box zeitenBox = Hive.box<Zeitnahme>("zeitenBox");

    if (zeitenBox.length > 0) {
      final DateTime latestDate = zeitenBox.getAt(zeitenBox.length - 1).day as DateTime;
      print("HiveDB - last date " + latestDate.toString());
      DateTime checkedDate = latestDate.add(const Duration(days: 1));

      if (!isSameDate(checkedDate, DateTime.now()) && checkedDate.isBefore(DateTime.now())) {
        print("HiveDB - urlaubscheck Tag ergänzen");

        while (!isSameDate(checkedDate, DateTime.now())) {
          //Nur wenn es ein Arbeitstag ist
          if (getIt<Data>().wochentage[checkedDate.weekday - 1] == true) {
            zeitenBox.add(Zeitnahme(day: checkedDate, state: "empty", startTimes: [], endTimes: []));
            if (animatedListkey.currentState != null) {
              animatedListkey.currentState!.insertItem(0, duration: const Duration(milliseconds: 1000));
            }
            print("HiveDB - urlaubscheck Tag ergänzt");
          } else {
            print("HiveDB - urlaubscheck Wochentag kein Arbeitstag");
          }
          checkedDate = checkedDate.add(const Duration(days: 1));
        }
      }
    }

    print("HiveDB - urlaubscheck finished");
  }

  //checks if the user forgot to end the time counting and does that for them to avoid bugs
  void checkForForgottenStop() async {
    print("HiveDB - checkForForgottenEnds - starting");
    Box zeitenBox = Hive.box<Zeitnahme>("zeitenBox");

    if (getIt<Data>().automatischAusstempeln) {
      for (int i = 0; i < zeitenBox.length; i++) {
        Zeitnahme z = zeitenBox.getAt(i);
        if (z.startTimes.isNotEmpty) {
          if (z.startTimes.length - z.endTimes.length == 1) {
            DateTime lastStartTime = DateTime.fromMillisecondsSinceEpoch(z.startTimes.last);
            Duration autoStopTime = Duration(milliseconds: getIt<Data>().automatischAusstempelnTimeMilli);
            DateTime autoStopDateTime =
                DateTime(lastStartTime.year, lastStartTime.month, lastStartTime.day, autoStopTime.inHours, autoStopTime.inMinutes % 60);

            //if on the same day, but before -> takes the time the next day.
            if (autoStopDateTime.isBefore(lastStartTime)) autoStopDateTime = autoStopDateTime.add(Duration(days: 1));
            if (DateTime.now().isAfter(autoStopDateTime)) {
              z.endTimes.add(autoStopDateTime.millisecondsSinceEpoch);
              //if (z.autoStoppedTime != null)
              z.autoStoppedTime = true;
              zeitenBox.putAt(i, z);
              getIt<Data>().timerText.stop();
              logger.w("HiveDB - checkForForgottenEnds - added End Time");
            }
          }
        }
      }
    } else {
      // [-1] every day except the latest so that you can work until the next forgotten day.
      for (int i = 0; i < zeitenBox.length - 1; i++) {
        Zeitnahme z = zeitenBox.getAt(i);
        if (z.startTimes.isNotEmpty) {
          // Only if it isnt from the current day
          if (DateTime.fromMillisecondsSinceEpoch(z.startTimes.first).day != DateTime.now().day) {
            if (z.startTimes.length - z.endTimes.length == 1) {
              DateTime lastStartTime = DateTime.fromMillisecondsSinceEpoch(z.startTimes.last);
              DateTime lastEndTime;
              getIt<Data>().automatischAusstempeln == true
                  ? lastEndTime = DateTime(
                      lastStartTime.year,
                      lastStartTime.month,
                      lastStartTime.day,
                      24,
                      00,
                      00,
                    )
                  : lastEndTime = DateTime.now();
              z.endTimes.add(lastEndTime.millisecondsSinceEpoch);

              //TODO: TESTEN VOR DEM NÄCHSTEN RELEASE. WAS PASSIERT, WENN VON ALTER VERSION KOMMEN

              //if (z.autoStoppedTime != null)
              z.autoStoppedTime = true;
              zeitenBox.putAt(i, z);
              getIt<Data>().timerText.stop();
              print("HiveDB - checkForForgottenEnds - added End Time");
            }
          }
        }
      }
    }
  }

  Future<void> changeState(String state, int index) async {
    Box zeitenBox = Hive.box<Zeitnahme>("zeitenBox");
    print("HiveDB - changeState - 1 $index");

    final Zeitnahme _updated = zeitenBox.getAt(index) as Zeitnahme;
    print("HiveDB - changeState - 2 ${_updated.state}");
    _updated.state = state;
    zeitenBox.putAt(index, _updated);

    listChangesStream.sink.add(changeNumber++);
    updateGesamtUeberstunden();
    print("HiveDB - changeState - 3 ${_updated.state}");
  }

  void dispose() {
    Box zeitenBox = Hive.box<Zeitnahme>("zeitenBox");
    zeitenBox.close();
    listChangesStream.close();
    ueberMillisekundenGesamtStream.close();
  }

  Future<void> updateStartEndZeit(int zeitnahmeIndex, int startEndIndex, bool start, int value) async {
    Box zeitenBox = Hive.box<Zeitnahme>("zeitenBox");

    final Zeitnahme edit = zeitenBox.getAt(zeitnahmeIndex) as Zeitnahme;

    start ? edit.startTimes[startEndIndex] = value : edit.endTimes[startEndIndex] = value;

    zeitenBox.putAt(zeitnahmeIndex, edit);

    print("HiveDB - updateStartEndZeit - gespeichert");
  }

  Future<void> updateTag(String tag, int index) async {
    Box zeitenBox = Hive.box<Zeitnahme>("zeitenBox");
    print("HiveDB - changeTag - 1 $index");

    Zeitnahme _updated = zeitenBox.getAt(index) as Zeitnahme;
    print("HiveDB - changeTag - 2 ${_updated.tag}");
    _updated.tag = tag;
    zeitenBox.putAt(index, _updated);

    listChangesStream.sink.add(changeNumber++);
    print("HiveDB - changeTag - 3 ${_updated.tag}");
  }

  Future<void> updateEditMilli(int editMilli, int index) async {
    Box zeitenBox = Hive.box<Zeitnahme>("zeitenBox");
    print("HiveDB - changeEditMilli - 1 $index");

    Zeitnahme _updated = zeitenBox.getAt(index) as Zeitnahme;
    print("HiveDB - changeEditMilli - 2 ${Duration(milliseconds: _updated.editMilli)}");
    _updated.editMilli = editMilli;
    zeitenBox.putAt(index, _updated);

    listChangesStream.sink.add(changeNumber++);
    print("HiveDB - changeEditMilli - 3 ${Duration(milliseconds: _updated.editMilli)}");
  }

  Future<List<List<Zeitnahme>>> getMonthLists() async {
    Box zeitenBox = Hive.box<Zeitnahme>("zeitenBox");

    logger.i("getMonthLists");

    Zeitnahme first = zeitenBox.getAt(0);
    int month = first.day.month;
    List<List<Zeitnahme>> zlist = [[]];

    for (Zeitnahme zeit in zeitenBox.values) {
      if (zeit.day.month == month)
        zlist.last.add(zeit);
      else {
        zlist.add([zeit]);
        month = zeit.day.month;
      }
    }

    logger.i(zlist.length);
    logger.i(zlist.first.length);
    return zlist;
  }
}

extension DateOnlyCompare on DateTime {
  bool isSameDate(DateTime other) {
    return this.year == other.year && this.month == other.month && this.day == other.day;
  }
}
