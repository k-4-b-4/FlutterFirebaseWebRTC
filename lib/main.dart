import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_firebase_webrtc/app/utils/RandomWordGenerator.dart';
import 'package:flutter_webrtc/webrtc.dart';
import 'package:uuid/uuid.dart';
import 'package:random_string/random_string.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Map<String, RTCPeerConnection> _peerConnections = {};
  RTCPeerConnection _offeredConnection = null;
  RTCDataChannel _dataChannel = null; // TODO: 複数持つ
  Map<String, List<RTCIceCandidate>> preparedCandidates = {};
  String displayString = '';
  String roomWords = '';
  String uuid = Uuid().v4();
  DateTime joinedAt = null;

  MediaStream _localStream;
  final _localRenderer = new RTCVideoRenderer();
  final _remoteRenderer = new RTCVideoRenderer();
  final roomWordsEditingController = TextEditingController();

  static final app = FirebaseApp.instance;
  final _store = Firestore(app: app);
  get store => _store;

  get isInRoom => roomWords.isEmpty;

  @override
  initState() {
    super.initState();
    initRenderers();
    setupMediaStream();
  }

  initRenderers() async {
    await _localRenderer.initialize(); // 自分のインカメラ
    await _remoteRenderer.initialize(); // 相手のカメラ
  }

  setupMediaStream() async {
    final Map<String, dynamic> mediaConstraints = {
      "audio": false,
      "video": {
        "mandatory": {
          "minWidth":
              '1280', // Provide your own width, height and frame rate here
          "minHeight": '720',
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
      });
    });

    store
        .collection("rooms")
        .document(words)
        .collection("candidates")
        .snapshots()
        .listen((data) async {
          data.documentChanges
              .where((change) => change.type == DocumentChangeType.added)
              .forEach((dc) async {
                print('ICECandidate情報が送られてきました');
          final uid = dc.document.data['from']; // candidate対象のuuid
          // updateDispalyString("applying candidate $uid");
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

        connection.onAddStream = (stream) {
          _remoteRenderer.srcObject = stream;
        };

        connection.onIceCandidate = (candidate) {
          connection.addCandidate(candidate);
          store
              .collection("rooms")
              .document(words)
              .collection('candidates')
              .add(
                Map<String, dynamic>.from({
                  ...{'from': this.uuid},
                  ...candidate.toMap()
              }));
        };
        connection.addStream(_localStream);
        connection.setRemoteDescription(offer);
        connection.onDataChannel = (channnel) {
          _dataChannel = channnel;
          _dataChannel.onMessage = (message) {
            updateDispalyString(message.text);
          };
        };

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

  sendOffer(String uid, String roomWord) async {
    final connection = await createNewConnection();
    connection.onIceCandidate = (candidate) async {
      connection.addCandidate(candidate);
      await store
          .collection("rooms")
          .document(roomWord)
          .collection('candidates')
          .add(Map<String, dynamic>.from({
            ...{'from': this.uuid},
            ...candidate.toMap()
          }));
    };
    connection.onAddStream = (stream) {
      _remoteRenderer.srcObject = stream;
    };
    connection.addStream(_localStream);
    _dataChannel =
        await connection.createDataChannel('chat', RTCDataChannelInit());
    _dataChannel.onMessage = (message) {
      updateDispalyString(message.text);
    };

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
  deactivate() {
    super.deactivate();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    roomWordsEditingController.dispose();
    _localStream.dispose();
  }

  makeCall() async {
    final store = new Firestore(app: app);
    final words = RandomWordGenerator.generate5Words();

    setState(() {
      roomWords = words;
    });

    await joinRoom(words);

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
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: new Container(
          decoration: BoxDecoration(color: Colors.black54),
          child: Column(
            children: <Widget>[
              Text('$displayString'),
              Expanded(child: RTCVideoView(_localRenderer)),
              Expanded(child: RTCVideoView(_remoteRenderer)),
              TextField(
                onChanged: (String newText) {
                  if (_dataChannel != null) {
                    _dataChannel.send(RTCDataChannelMessage(newText));
                  }
                },
              ),
              Row(
                children: <Widget>[
                  FlatButton(
                    child: Text("入室する"),
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text("あいことばを入力しよう"),
                              content: TextField(
                                controller: roomWordsEditingController,
                              ),
                              actions: <Widget>[
                                FlatButton(
                                  child: Text("この部屋に入る"),
                                  onPressed: () async {
                                    await joinRoom(roomWordsEditingController.text);
                                    Navigator.pop(context);
                                  },
                                ),
                                FlatButton(
                                  child: Text("やっぱりやめる"),
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                )
                              ],
                            );
                          });
                    },
                  ),
                  FlatButton(
                    child: Text("部屋をつくる"),
                    onPressed: makeCall,
                  ),
                  Text("$roomWords")
                ],
              ),
            ],
          )),
    );
  }
}
