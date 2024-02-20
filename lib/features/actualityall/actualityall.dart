import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:mypug/components/design/design.dart';
import 'package:mypug/components/pug/pugitem.dart';
import 'package:mypug/features/search/search.dart';
import 'package:mypug/models/pugdetailmodel.dart';
import 'package:mypug/models/pugmodel.dart';
import 'package:mypug/response/actualityresponse.dart';
import 'package:mypug/service/themenotifier.dart';
import 'package:mypug/util/util.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../components/tab/tab.dart';
import '../../models/userfactory.dart';
import '../chat/chat.dart';
import '../comment/pugcomments.dart';
import 'api.dart';

class ActualityAll extends StatefulWidget {
  final routeName = '/actualityall';

  const ActualityAll({Key? key}) : super(key: key);

  @override
  ActualityAllState createState() => ActualityAllState();
}

class ActualityAllState extends State<ActualityAll> {
  List<PugDetailModel> details = [];
  List<PugModel> list = [];
  late ActualityResponse _response;
  late String _username;
  PageController _controller = PageController(
    initialPage: 0,
  );
  late ScrollController scrollController =
      ScrollController(initialScrollOffset: 150);

  late int startInd = 0;
  late ThemeModel notifier;
  final RefreshController _refreshController = RefreshController();
  StreamController streamController = StreamController();
  bool scrollPagePhysique = false;

  @override
  void initState() {
    fetchData();
    scrollController.addListener(scrollListener);
    super.initState();
  }

  fetchData() async {
    final event = await FirebaseMessaging.instance.getInitialMessage();
    print(event);
    _username = await getCurrentUsername();
    socketService.initialise(_username);
    if (event != null && event.data['type'] == "message") {
      navigatorKey.currentState?.push(MaterialPageRoute(
        builder: (context) => Chat.withUsername(
          receiverUser: UserFactory(
              id: "",
              username: event.data['sender_username'],
              profilePicture: event.data['sender_profilepicture']),
          seen: false,
        ),
      ));
    }
    if (event != null && event.data['type'] == "comment") {
      navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (context) => PugComments.withData(
              pugId: event.data['pug_id'],
              username: event.data['username'],
              description: event.data['description'])));
    }
    if (event != null && event.data['type'] == "like") {
      navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (context) => const TabView.withIndex(
                initialIndex: 4,
              )));
    }
    _response = await getActualityPageable(startInd, 0);
    list = _response.pugs;
    streamController.add("event");
    streamController.done;
  }

  fetchOldActuality() async {
    startInd += 5;
    _response = await getActualityPageable(startInd, 0);
    list.addAll(_response.pugs);
    streamController.add("event");
  }

  setScrollPhysique(bool value) {
    scrollPagePhysique = value;

    setState(() {});
  }

  scrollListener() {
    if (scrollController.offset >= scrollController.position.maxScrollExtent &&
        !scrollController.position.outOfRange) {
      fetchOldActuality();
    }
    if (scrollController.offset <= scrollController.position.minScrollExtent &&
        !scrollController.position.outOfRange) {}
  }

  Future<void> refreshData() async {
    startInd = 0;
    list.clear();
    _response = await getActualityPageable(startInd, 0);
    list = _response.pugs;
    streamController.add("event");
    _refreshController.refreshCompleted();
    scrollController.animateTo(151,
        duration: const Duration(milliseconds: 700), curve: Curves.ease);
    scrollPagePhysique = false;
    setState(() {});
  }

  Widget pugItem(PugModel model) {
    return PugItem(
      model: model,
      currentUsername: _username,
      refreshCb: updateData,
    );
  }

  updateData() {
    refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeModel>(
      builder: (context, ThemeModel notifier, child) {
        this.notifier = notifier;
        return Scaffold(
            appBar:  AppBar(
              title: const Text("Actualité"),
              automaticallyImplyLeading: false,
              backgroundColor:  Colors.black,              actions: [
                // IconButton(
                //   onPressed: () {
                //     navigateWithName(context, const Competition().routeName);
                //   },
                //   icon: Image.asset('asset/images/competition.png'),
                // ),
                IconButton(
                    onPressed: () {
                      navigateWithName(context, const Search().routeName);
                    },
                    icon: const Icon(Icons.search)),
              ],
            ),
            body: Container(
              child: newContent(),
              decoration: BoxCircular(notifier),
            ));
      },
    );
  }

  Widget newContent() {
    return StreamBuilder(
      stream: streamController.stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(
            color: APPCOLOR,
          ));
        }

        if (snapshot.hasData) {
          return PageView.builder(
              controller: _controller,
              scrollDirection: Axis.vertical,
              itemCount: list.length,
              itemBuilder: (context, index) {
                return pugItem(list[index]);
              });
        } else {
          return Center(
            child: Text(sentence_no_pug),
          );
        }
      },
    );
  }
}
