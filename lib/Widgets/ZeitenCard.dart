import 'package:animations/animations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:work_in_progress/Widgets/ZeitenCardWidgets/EmptyCardClosed.dart';
import 'package:work_in_progress/Widgets/ZeitenCardWidgets/firstWidget.dart';
import 'package:work_in_progress/hiveClasses/Zeitnahme.dart';

import '../Services/Data.dart';
import '../Services/HiveDB.dart';
import 'ZeitenCardWidgets/DefaultCardClosed.dart';
import 'ZeitenCardWidgets/DefaultCardOpen/DefaultCardOpen.dart';
import 'ZeitenCardWidgets/FirstCardClosed.dart';
import 'ZeitenCardWidgets/FreeCardClosed.dart';

final getIt = GetIt.instance;

class ZeitenPanel extends StatefulWidget {
  const ZeitenPanel({
    Key key,
    @required this.panelController,
  }) : super(key: key);

  final PanelController panelController;

  @override
  _ZeitenPanelState createState() => _ZeitenPanelState();
}

class _ZeitenPanelState extends State<ZeitenPanel> {
  //Tween<Size> _size = Tween(begin: Offset(0,-1), end: Offset(0,0));

  @override
  Widget build(BuildContext context) {
    return Card(
        clipBehavior: Clip.antiAlias,
        elevation: 10.0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        child: LimitedBox(
          maxHeight: 500,
          child: StreamBuilder<Color>(
              stream: getIt<Data>().primaryColorStream.stream,
              initialData: getIt<Data>().primaryColor,
              builder: (context, snapshot) {
                return Column(
                  children: [
                    FirstWidget(panelController: widget.panelController),
                    Flexible(
                      child: Theme(
                        data: Theme.of(context)
                            .copyWith(accentColor: Colors.tealAccent[100]),
                        child: ValueListenableBuilder(
                          valueListenable:
                              getIt<HiveDB>().zeitenBox.listenable(),
                          builder: (context, Box box, _) {
                            return StreamBuilder(
                                stream:
                                    getIt<HiveDB>().listChangesStream.stream,
                                builder: (context, snapshot) {
                                  print("Zeiten Card - snapshot Data is " +
                                      snapshot.data.toString());
                                  print("Zeiten Card - box length is " +
                                      box.length.toString());

                                  return Container(
                                    child: ShaderMask(
                                      shaderCallback: (Rect bounds) {
                                        return LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment(0, -0.8),
                                          colors: <Color>[
                                            Colors.white.withAlpha(0),
                                            Colors.white,
                                          ],
                                        ).createShader(bounds);
                                      },
                                      blendMode: BlendMode.dstATop,
                                      child: AnimatedList(
                                          initialItemCount:
                                              getIt<HiveDB>().zeitenBox.length,
                                          key: getIt<HiveDB>().animatedListkey,
                                          padding: EdgeInsets.only(top: 30.0),
                                          itemBuilder:
                                              (context, index, animation) {
                                            //Liste wird umgekehrt
                                            int i = box.length - index - 1;
                                            Zeitnahme _zeitnahme = box.getAt(i);
                                            String _state = _zeitnahme.state;

                                            return SizeTransition(
                                                sizeFactor: CurvedAnimation(
                                                    parent: animation,
                                                    curve: Curves.ease),
                                                child: OpenContainer(
                                                  closedElevation: 0.0,
                                                  openElevation: 20.0,
                                                  closedShape:
                                                      RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      20.0)),
                                                  openShape:
                                                      RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      20.0)),
                                                  transitionDuration: Duration(
                                                      milliseconds: 600),
                                                  transitionType:
                                                      ContainerTransitionType
                                                          .fade,
                                                  openColor: Colors.white,
                                                  closedBuilder: (BuildContext
                                                          context,
                                                      void Function() action) {
                                                    Widget _widget;

                                                    if (index == 0 &&
                                                        _state == "default") {
                                                      _widget = KeyedSubtree(
                                                        key: ValueKey<int>(1),
                                                        child: StreamBuilder<
                                                                bool>(
                                                            stream: getIt<
                                                                    Data>()
                                                                .isRunningStream
                                                                .stream,
                                                            initialData:
                                                                getIt<Data>()
                                                                    .isRunning,
                                                            builder: (context,
                                                                snapshot) {
                                                              return FirstCardClosed(
                                                                  i: i,
                                                                  index: index,
                                                                  zeitnahme:
                                                                      _zeitnahme,
                                                                  isRunning:
                                                                      snapshot
                                                                          .data);
                                                            }),
                                                      );
                                                    } else {
                                                      switch (_state) {
                                                        case "default":
                                                          {
                                                            _widget = KeyedSubtree(
                                                                key: ValueKey<
                                                                    int>(1),
                                                                child: DefaultCardClosed(
                                                                    i: i,
                                                                    index:
                                                                        index,
                                                                    zeitnahme:
                                                                        _zeitnahme));
                                                            break;
                                                          }

                                                        case "free":
                                                          {
                                                            _widget =
                                                                FreeCardClosed(
                                                                    i: i,
                                                                    index:
                                                                        index,
                                                                    zeitnahme:
                                                                        _zeitnahme);
                                                            break;
                                                          }

                                                        case "empty":
                                                          {
                                                            _widget =
                                                                EmptyCardClosed(
                                                                    i: i,
                                                                    index:
                                                                        index,
                                                                    zeitnahme:
                                                                        _zeitnahme);
                                                            break;
                                                          }

                                                        case "edited":
                                                          {
                                                            _widget =
                                                                Text("edited");
                                                            break;
                                                          }

                                                        default:
                                                          {
                                                            _widget =
                                                                Text("error");
                                                          }
                                                      }
                                                    }

                                                    return PageTransitionSwitcher(
                                                      reverse: _state == "free",
                                                      transitionBuilder: (
                                                        Widget child,
                                                        Animation<double>
                                                            primaryAnimation,
                                                        Animation<double>
                                                            secondaryAnimation,
                                                      ) {
                                                        return SharedAxisTransition(
                                                          child: child,
                                                          animation:
                                                              primaryAnimation,
                                                          secondaryAnimation:
                                                              secondaryAnimation,
                                                          transitionType:
                                                              SharedAxisTransitionType
                                                                  .horizontal,
                                                          fillColor: Colors
                                                              .transparent,
                                                        );
                                                      },
                                                      child: _widget,
                                                      duration: const Duration(
                                                          milliseconds: 600),
                                                    );
                                                  },
                                                  openBuilder: (BuildContext
                                                          context,
                                                      void Function(
                                                              {Object
                                                                  returnValue})
                                                          action) {
                                                    switch (_state) {
                                                      case "default":
                                                        {
                                                          return DefaultCardOpen(
                                                              i: i,
                                                              index: index,
                                                              zeitnahme:
                                                                  _zeitnahme);
                                                        }

                                                      case "free":
                                                        {
                                                          return Text("free");
                                                        }

                                                      case "edited":
                                                        {
                                                          return Text("edited");
                                                        }

                                                      case "empty":
                                                        {
                                                          return Text("empty");
                                                        }

                                                      default:
                                                        {
                                                          return Text("error");
                                                        }
                                                    }
                                                  },
                                                  onClosed: (o) {
                                                    getIt<HiveDB>()
                                                        .updateGesamtUeberstunden();
                                                  },
                                                ));
                                          }),
                                    ),
                                  );
                                });
                          },
                        ),
                      ),
                    ),
                  ],
                );
              }),
        ));
  }
}