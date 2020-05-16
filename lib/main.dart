import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/webrtc.dart';
import 'package:uuid/uuid.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: LaunchPage(),
    );
  }
}

class LaunchPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
      width: double.infinity,
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color.fromARGB(255, 186, 0, 188), Colors.black])),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          RaisedButton(
            color: Color.fromARGB(255, 66, 255, 99),
            child: Padding(
              padding: const EdgeInsets.only(right: 8, left: 8),
              child: Text(
                "ヘヤヲツクル",
                style: TextStyle(
                    color: Colors.white, fontFamily: 'カタカナボーイ', fontSize: 24),
              ),
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) {
                    return InputKeywordPage(
                      isCreate: true,
                    );
                  },
                ),
              );
            },
          ),
          RaisedButton(
            color: Color.fromARGB(255, 66, 255, 99),
            child: Padding(
              padding: const EdgeInsets.only(right: 8, left: 8),
              child: Text(
                "ヘヤニハイル",
                style: TextStyle(
                    color: Colors.white, fontFamily: 'カタカナボーイ', fontSize: 24),
              ),
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) {
                    return InputKeywordPage(
                      isCreate: false,
                    );
                  },
                ),
              );
            },
          )
        ],
      ),
    ));
  }
}

class InputKeywordPage extends StatefulWidget {
  InputKeywordPage({Key key, this.isCreate}) : super(key: key);

  final bool isCreate;

  _InputkeywordPageState createState() => _InputkeywordPageState();
}

class _InputkeywordPageState extends State<InputKeywordPage> {
  final roomWordsEditingController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color.fromARGB(255, 186, 0, 188), Colors.black])),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text("アイコトバヲニュウリョクシヨウ",
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'カタカナボーイ',
                  fontSize: 24,
                )),
            Padding(
              padding: const EdgeInsets.only(right: 40, left: 40),
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(width: 10, color: Colors.white)),
                child: Padding(
                  padding:
                      const EdgeInsets.only(right: 10, left: 10, bottom: 4),
                  child: TextField(
                    maxLength: 5,
                    controller: roomWordsEditingController,
                    style: TextStyle(color: Colors.white),
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: Color.fromARGB(255, 66, 255, 99), width: 2),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: Color.fromARGB(255, 66, 255, 99), width: 2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            RaisedButton(
              color: Color.fromARGB(255, 66, 255, 99),
              child: Padding(
                padding: const EdgeInsets.only(right: 8, left: 8),
                child: Text(
                  widget.isCreate ? "ヘヤヲツクル" : "ヘヤニハイル",
                  style: TextStyle(
                      color: Colors.white, fontFamily: 'カタカナボーイ', fontSize: 24),
                ),
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) {
                      return MyHomePage(
                        roomword: roomWordsEditingController.text,
                        isCreated: widget.isCreate,
                      );
                    },
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.roomword, this.isCreated}) : super(key: key);

  final String roomword;
  final bool isCreated;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Map<String, RTCPeerConnection> _peerConnections = {};
  Map<String, RTCDataChannel> _dataChannels = {};
  Map<String, List<RTCIceCandidate>> preparedCandidates = {};
  Map<String, RTCVideoRenderer> renderer = {};
  List<RTCVideoViewV2> videoViews = [];

  String displayString = '';
  String roomWords = '';
  String uuid = Uuid().v4();
  DateTime joinedAt = null;

  MediaStream _localStream;

  final _localRenderer = new RTCVideoRenderer();
  final _remoteRenderer = new RTCVideoRenderer();
  bool _remoteUsed = false;
  final _remoteRenderer2 = new RTCVideoRenderer();
  bool _remote2Used = false;

  static final app = FirebaseApp.instance;
  final _store = Firestore(app: app);
  get store => _store;

  get isInRoom => roomWords.isEmpty;

  @override
  initState() {
    super.initState();
    initRenderers();
    setupMediaStream();
    this.roomWords = widget.roomword;

    if (widget.isCreated) {
      this.makeCall();
    } else {
      joinRoom(this.roomWords);
    }
  }

  initRenderers() async {
    await _localRenderer.initialize(); // 自分のインカメラ
    await _remoteRenderer.initialize(); // 1人目のカメラ
    await _remoteRenderer2.initialize(); // 2人目のカメラ
  }

  setupMediaStream() async {
    final Map<String, dynamic> mediaConstraints = {
      "audio": false,
      "video": {
        "mandatory": {
          "minWidth":
              '640', // Provide your own width, height and frame rate here
          "minHeight": '360',
          "minFrameRate": '30',
        },
        "facingMode": "user",
        "optional": [],
      }
    };
    _localStream = await navigator.getUserMedia(mediaConstraints);
    _localRenderer.srcObject = _localStream;
    _localRenderer.mirror = true;
  }

  joinRoom(String words) async {
    setState(() {
      roomWords = words;
    });
    joinedAt = DateTime.now();
    await store
        .collection("rooms")
        .document(words)
        .collection('users')
        .add({'uid': uuid, 'joined': joinedAt.millisecondsSinceEpoch});

    store
        .collection("rooms")
        .document(words)
        .collection('users')
        .snapshots()
        .listen((data) async {
      data.documentChanges
          .where((change) => change.document.data['uid'] != this.uuid)
          .where((change) => change.type == DocumentChangeType.added)
          .where((change) => DateTime.fromMillisecondsSinceEpoch(
                  change.document.data['joined'])
              .isAfter(joinedAt))
          .forEach((dc) {
        sendOffer(dc.document.data['uid'], words);
        // create Renderer
      });

      data.documentChanges
          .where((change) => change.document.data['uid'] != this.uuid)
          .where((change) => change.type == DocumentChangeType.removed)
          .forEach((dc) async {
        final uid = dc.document.data['uid'];
        await _peerConnections[uid].dispose();
        await _dataChannels[uid].close();
        _peerConnections.remove(uid);
        _dataChannels.remove(uid);
      });
    });

    store
        .collection("rooms")
        .document(words)
        .collection("candidates")
        .where("to", isEqualTo: this.uuid)
        .snapshots()
        .listen((data) async {
      data.documentChanges
          .where((change) => change.type == DocumentChangeType.added)
          .forEach((dc) async {
        print('ICECandidate情報が送られてきました');
        final uid = dc.document.data['from'];
        final candidate = dc.document.data['candidate'];
        final sdpMid = dc.document.data['sdpMid'];
        final sdpMlineIndex = dc.document.data['sdpMLineIndex'];
        final iceCandidate = RTCIceCandidate(candidate, sdpMid, sdpMlineIndex);

        if (_peerConnections[uid] != null) {
          await _peerConnections[uid].addCandidate(iceCandidate);
        } else {
          if (preparedCandidates[uid] == null) {
            preparedCandidates[uid] = [];
          }
          preparedCandidates[uid].add(iceCandidate);
        }
      });

      store
          .collection("rooms")
          .document(words)
          .collection('offers_and_answers')
          .where("type", isEqualTo: "answer")
          .where("to", isEqualTo: this.uuid)
          .snapshots()
          .listen((data) async {
        if (data.documentChanges.length == 0) {
          return;
        }

        data.documentChanges.forEach((change) {
          final uid = change.document.data['from'];
          final sdp = change.document['sdp'];
          final type = change.document['type'];

          _peerConnections[uid]
              .setRemoteDescription(new RTCSessionDescription(sdp, type));

          if (preparedCandidates[uid] != null) {
            preparedCandidates[uid].forEach((c) async {
              await _peerConnections[uid].addCandidate(c);
            });
          }
        });
      });
    });

    store
        .collection("rooms")
        .document(words)
        .collection("offers_and_answers")
        .where("type", isEqualTo: "offer")
        .where("to", isEqualTo: uuid)
        .snapshots()
        .listen((data) async {
      data.documentChanges
          .where((change) => change.document.data['from'] != this.uuid)
          .where((change) => change.type == DocumentChangeType.added)
          .forEach((dc) async {
        print(dc);
        final uid = dc.document.data['from'];
        final offer = new RTCSessionDescription(
            dc.document.data['sdp'], dc.document.data['type']);
        final connection = await createNewConnection();
        connection.onDataChannel = (dataChannel) {
          _dataChannels[uid] = dataChannel;
          _dataChannels[uid].onMessage = (message) {
            final text = message.text;
            updateDispalyString('$text from $uid');
          };
        };
        connection.onAddStream = applyRemoteStream;

        connection.onIceCandidate = (candidate) {
          connection.addCandidate(candidate);
          store
              .collection("rooms")
              .document(words)
              .collection('candidates')
              .add(Map<String, dynamic>.from({
                ...{
                  'from': this.uuid,
                  'to': uid,
                },
                ...candidate.toMap()
              }));
        };
        connection.addStream(_localStream);
        connection.setRemoteDescription(offer);

        final answer = await connection.createAnswer({});
        connection.setLocalDescription(answer);

        store
            .collection("rooms")
            .document(words)
            .collection("offers_and_answers")
            .add({
          'type': answer.type,
          'from': this.uuid,
          'to': uid,
          'sdp': answer.sdp
        });

        _peerConnections[uid] = connection;

        if (preparedCandidates[uid] != null) {
          preparedCandidates[uid].forEach((can) {
            connection.addCandidate(can);
          });
          preparedCandidates[uid].clear();
        }
      });
    });
  }

  applyRemoteStream(MediaStream stream) {
    if (!_remoteUsed) {
      _remoteRenderer.srcObject = stream;
      setState(() {
        _remoteUsed = true;
      });
    } else if (!_remote2Used) {
      _remoteRenderer2.srcObject = stream;
      setState(() {
        _remote2Used = true;
      });
    }
  }

  sendOffer(String uid, String roomWord) async {
    final connection = await createNewConnection();
    connection.addStream(_localStream);
    final dataChannel =
        await connection.createDataChannel('chat', RTCDataChannelInit());
    _dataChannels[uid] = dataChannel;
    _dataChannels[uid].onMessage = (message) {
      final text = message.text;
      updateDispalyString('$text from $uid');
    };

    connection.onIceCandidate = (candidate) async {
      connection.addCandidate(candidate);
      await store
          .collection("rooms")
          .document(roomWord)
          .collection('candidates')
          .add(Map<String, dynamic>.from({
            ...{
              'from': this.uuid,
              'to': uid,
            },
            ...candidate.toMap()
          }));
    };

    connection.onAddStream = applyRemoteStream;

    final offer = await connection.createOffer({});
    connection.setLocalDescription(offer);
    _peerConnections[uid] = connection;

    store
        .collection("rooms")
        .document(roomWord)
        .collection("offers_and_answers")
        .add({
      'type': offer.type,
      'from': this.uuid,
      'to': uid,
      'sdp': offer.sdp
    });
  }

  updateDispalyString(String ds) {
    print(ds);
    setState(() {
      displayString = ds;
    });
  }

  @override
  deactivate() async {
    super.deactivate();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    await store
        .collection("rooms")
        .document(roomWords)
        .collection("users")
        .delete(this.uuid);
    _localStream.dispose();
  }

  leaveRoom() async {
    _remoteRenderer.dispose();
    await store
        .collection("rooms")
        .document(roomWords)
        .collection("users")
        .delete(this.uuid);
  }

  makeCall() async {
    // final words = RandomWordGenerator.generate5Words();
    await joinRoom(this.roomWords);
  }

  Future<RTCPeerConnection> createNewConnection() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {"url": "stun:stun.l.google.com:19302"},
      ]
    };

    final Map<String, dynamic> loopbackConstraints = {
      "mandatory": {},
      "optional": [
        {"DtlsSrtpKeyAgreement": true},
      ],
    };
    final connection =
        await createPeerConnection(configuration, loopbackConstraints);
    connection.onIceConnectionState = (state) {
      print(state.toString());
    };

    return connection;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color.fromARGB(255, 186, 0, 188), Colors.black])),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Container(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.only(
                        right: 20, left: 20, top: 60, bottom: 100),
                    child: Container(
                      child: RTCVideoViewV2(_remoteRenderer),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: Colors.white, width: 10)),
                    ),
                  ),
                ),
                Container(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Container(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 80),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "通話を終了",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.red),
                            ),
                            Container(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  widget.roomword,
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      height: 170,
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              MaterialButton(
                                onPressed: () {
                                  _dataChannels.values.forEach((c) {
                                    //  NOTE: 特定の人にのみ送る挙動はuidで絞り込みすればできる
                                    c.send(RTCDataChannelMessage(
                                        "emoji_action_like"));
                                  });
                                },
                                color: Colors.blue,
                                textColor: Colors.white,
                                child: Text(
                                  "👍",
                                  style: TextStyle(fontSize: 32),
                                ),
                                padding: EdgeInsets.all(10),
                                shape: CircleBorder(),
                              ),
                              MaterialButton(
                                onPressed: () {
                                  _dataChannels.values.forEach((c) {
                                    //  NOTE: 特定の人にのみ送る挙動はuidで絞り込みすればできる
                                    c.send(RTCDataChannelMessage(
                                        "emoji_action_tada"));
                                  });
                                },
                                color: Colors.blue,
                                textColor: Colors.white,
                                child: Text(
                                  "🎉",
                                  style: TextStyle(fontSize: 32),
                                ),
                                padding: EdgeInsets.all(10),
                                shape: CircleBorder(),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(25),
                                    border: Border.all(
                                        color: Colors.white, width: 10)),
                                child: RTCVideoViewV2(_localRenderer),
                              ),
                            ]),
                      ),
                    )
                  ],
                ))
              ],
            )));
  }

  // TODO Wordのバリデーション
  // bool validateRoomWord(String word) {
  //   store.collection("rooms").document(word)
  // }
}

class RTCVideoViewV2 extends StatefulWidget {
  final RTCVideoRenderer _renderer;
  RTCVideoViewV2(this._renderer, {Key key}) : super(key: key);
  @override
  _RTCVideoViewV2State createState() => new _RTCVideoViewV2State();
}

class _RTCVideoViewV2State extends State<RTCVideoViewV2> {
  double _aspectRatio;
//  RTCVideoViewObjectFit _objectFit;
  int _textureId;

  @override
  void initState() {
    super.initState();
    _setCallbacks();
    _aspectRatio = widget._renderer.aspectRatio;
//    _objectFit = widget._renderer.objectFit;
  }

  @override
  void dispose() {
    super.dispose();
    widget._renderer.onStateChanged = null;
  }

  void _setCallbacks() {
    widget._renderer.onStateChanged = () {
      setState(() {
        _aspectRatio = widget._renderer.aspectRatio;
        //       _objectFit = widget._renderer.objectFit;
        _textureId = widget._renderer.textureId;
      });
    };
  }

  Widget _buildVideoView(BoxConstraints constraints) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
      width: constraints.maxHeight * _aspectRatio,
      height: constraints.maxHeight,
      child: ClipRRect(
        child: _textureId != null
            ? Texture(textureId: _textureId)
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: FractionalOffset.topLeft,
                    end: FractionalOffset.bottomRight,
                    colors: [
                      const Color(0xffe4a972).withOpacity(0.6),
                      const Color(0xff9941d8).withOpacity(0.6),
                    ],
                    stops: const [
                      0.0,
                      1.0,
                    ],
                  ),
                ),
              ),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return new LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      return Stack(
        children: <Widget>[
          _buildVideoView(constraints),
          Positioned(
            left: 20,
            bottom: 10,
            child: Text(
              _textureId != null ? "接続済み" : "未接続",
              style: TextStyle(color: Colors.white),
            ),
          )
        ],
      );
    });
  }
}
