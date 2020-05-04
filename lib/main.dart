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
  Map<String, List<RTCIceCandidate>> preparedCandidates = {};
  String displayString = '';
  String uuid = Uuid().v4();
  bool isWait = false;

  MediaStream _localStream;
  final _localRenderer = new RTCVideoRenderer();
  final _remoteRenderer = new RTCVideoRenderer();

  final app = FirebaseApp.instance;

  final Map<String, dynamic> offerSdpConstraints = {
    "mandatory": {
      "OfferToReceiveAudio": true,
      "OfferToReceiveVideo": true,
    },
    "optional": [],
  };

  @override
  initState() {
    super.initState();
    initRenderers();
    setupStream();
    connect();
  }

  initRenderers() async {
    await _localRenderer.initialize(); // 自分のインカメラ
    await _remoteRenderer.initialize(); // 相手のカメラ
  }

  setupStream() async {
    final Map<String, dynamic> mediaConstraints = {
      "audio": true,
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

  connect() {
    final store = Firestore(app: app);
    store
        .collection("rooms")
        .where("type", isEqualTo: "offer")
        .where("to", isEqualTo: "") // 誰もマッチしていないOffer
        .snapshots()
        .listen((data) async {
      if (data.documentChanges
              .where((change) => change.document.data['from'] != this.uuid)
              .where((change) => change.type == DocumentChangeType.added)
              .length >
          0) {
        updateDispalyString("createAnswer");

        print('新しいオファーがありました');
        data.documentChanges.forEach((dc) async {
          final uid = dc.document.data['from'];
          final offer = new RTCSessionDescription(
              dc.document.data['sdp'], dc.document.data['type']);
          final connection = await createNewConnection();

          connection.onAddStream = (stream) {
            _remoteRenderer.srcObject = stream;
          };

          connection.onIceCandidate = (candidate) {
            connection.addCandidate(candidate);
            store.collection('candidates').add({
              ...{'from': this.uuid},
              ...candidate.toMap()
            });
          };
          connection.addStream(_localStream);
          connection.setRemoteDescription(offer);
          final answer = await connection.createAnswer({});
          connection.setLocalDescription(answer);

          store.collection("rooms").add({
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
      }
    });

    store.collection("candidates").snapshots().listen((data) async {
      final newCandidates = data.documentChanges
          // .where((change) =>
          //     change.document.data['from'] !=
          //     this.uuid) // 自分自身のcandidate登録しないように
          .where((change) => change.type == DocumentChangeType.added);
      if (newCandidates.length > 0) {
        updateDispalyString("applying candidate");
        print('ICECandidate情報が送られてきました');
        newCandidates.forEach((dc) async {
          final uid = dc.document.data['from']; // candidate対象のuuid
          updateDispalyString("applying candidate $uid");
          final candidate = dc.document.data['candidate'];
          final sdpMid = dc.document.data['sdpMid'];
          final sdpMlineIndex = dc.document.data['sdpMLineIndex'];
          dc.document.data.keys.forEach((k) {
            print(k);
            print(dc.document.data[k]);
          });
          final iceCandidate =
              RTCIceCandidate(candidate, sdpMid, sdpMlineIndex);

          if (_peerConnections[uid] != null) {
            print("peerConnection Founded");
            await _peerConnections[uid].addCandidate(iceCandidate);
          } else {
            print("peerConnection did not founded");
            if (preparedCandidates[uid] == null) {
              preparedCandidates[uid] = [];
            }
            preparedCandidates[uid].add(iceCandidate);
          }
        });
      }
    });
  }

  updateDispalyString(String ds) {
    setState(() {
      displayString = ds;
    });
  }

  @override
  deactivate() {
    super.deactivate();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  makeCall() async {
    final store = new Firestore(app: app);
    createOffer(store);

    store
        .collection("rooms")
        .where("type", isEqualTo: "answer")
        .where("to", isEqualTo: this.uuid)
        .snapshots()
        .listen((data) async {
      if (data.documentChanges.length == 0) {
        return;
      }

      updateDispalyString("apply answer");

      final uid = data.documentChanges[0].document.data['from'];
      if (_peerConnections[uid] != null) {
        return;
      }
      _peerConnections[uid] = _offeredConnection;

      final sdp = data.documentChanges[0].document.data['sdp'];
      final type = data.documentChanges[0].document.data['type'];

      _offeredConnection
          .setRemoteDescription(new RTCSessionDescription(sdp, type));

      if (preparedCandidates[uid].length > 0) {
        preparedCandidates[uid].forEach((c) async {
          await _offeredConnection.addCandidate(c);
        });
      }
    });
  }

  createOffer(Firestore store) async {
    setState(() {
      displayString = "createOffer";
    });

    final connection = await createNewConnection();
    connection.onIceCandidate = (candidate) {
      connection.addCandidate(candidate);
      store.collection('candidates').add({
        ...{'from': this.uuid},
        ...candidate.toMap()
      });
    };
    connection.onAddStream = (stream) {
      print('This is added Stream createOffer: ' + stream.id);
      _remoteRenderer.srcObject = stream;
    };
    connection.addStream(_localStream);
    final offer = await connection.createOffer({});
    connection.setLocalDescription(offer);
    _offeredConnection = connection;
    store.collection("rooms").add(
        {'type': offer.type, 'from': this.uuid, 'to': '', 'sdp': offer.sdp});
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
    var widgets = <Widget>[
      Text(
        '$displayString',
        style: Theme.of(context).textTheme.display1,
      ),
      new Expanded(
        child: new RTCVideoView(_localRenderer),
      ),
      new Expanded(
        child: new RTCVideoView(_remoteRenderer),
      )
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: new OrientationBuilder(
        builder: (context, orientation) {
          return new Center(
            child: new Container(
              decoration: new BoxDecoration(color: Colors.black54),
              child: orientation == Orientation.portrait
                  ? new Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: widgets)
                  : new Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: widgets),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: makeCall,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
