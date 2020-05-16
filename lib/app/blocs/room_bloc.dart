// import 'package:firebase_core/firebase_core.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter_webrtc/webrtc.dart';
// import 'package:rxdart/rxdart.dart';

// //
// // コネクション管理とRoom管理の両方を行う
// //
// class RoomBloc {
//   // PeerConnections(ビデオだと10本くらいが限界らしい)
//   // なので9個がMax
//   final _remotelyAllocatedPeerConnections =
//       BehaviorSubject<List<RTCPeerConnection>>();

//   final _userJoined = PublishSubject<String>();
//   Stream<String> get userJoined => _userJoined.stream;

//   // すでにOffer/AnswerとしてやりとりしてConnectionをはっている場合
//   var connectedUdids = List<String>();

//   Firestore store;

//   get roomRef => store.collection('rooms').reference();

//   RoomBloc() {
//     store = Firestore(app: FirebaseApp.instance);
//   }

//   // コネクション情報を生成する
//   Future<RTCPeerConnection> createNewConnection() async {
//     Map<String, dynamic> configuration = {
//       "iceServers": [
//         {"url": "stun:stun.l.google.com:19302"},
//       ]
//     };

//     final Map<String, dynamic> loopbackConstraints = {
//       "mandatory": {},
//       "optional": [
//         {"DtlsSrtpKeyAgreement": true},
//       ],
//     };
//     return await createPeerConnection(configuration, loopbackConstraints);
//   }

//   // 新しいユーザーが入ってくるのを監視する
//   void observeUserJoining(
//       String word, DateTime joinTime, String username) async {
//     store
//         .collection("rooms")
//         .document(word)
//         .collection('users')
//         .snapshots()
//         .listen((data) async {
//       data.documentChanges
//           .where((change) => change.document.data['uid'] != username)
//           .where((change) => change.type == DocumentChangeType.added)
//           .where((change) => DateTime.fromMillisecondsSinceEpoch(
//                   change.document.data['joined'])
//               .isAfter(joinTime))
//           .forEach((dc) {});
//     });
//     // await store
//     //     .collection("rooms")
//     //     .document(words)
//     //     .collection('users')
//     //     .add({'uid': uuid, 'joined': joinedAt.millisecondsSinceEpoch});
//   }

//   void joinRoom(String words, String uuid) async {
//     final joinedAt = DateTime.now();
//     // await store
//     //     .collection("rooms")
//     //     .document(words)
//     //     .collection('users')
//     //     .add({'uid': uuid, 'joined': joinedAt.millisecondsSinceEpoch});

//     // store
//     //     .collection("rooms")
//     //     .document(words)
//     //     .collection('users')
//     //     .snapshots()
//     //     .listen((data) async {
//     //   data.documentChanges
//     //       .where((change) => change.document.data['uid'] != this.uuid)
//     //       .where((change) => change.type == DocumentChangeType.added)
//     //       .where((change) => DateTime.fromMillisecondsSinceEpoch(
//     //               change.document.data['joined'])
//     //           .isAfter(joinedAt))
//     //       .forEach((dc) {
//     //     sendOffer(dc.document.data['uid'], words);
//     //     // create Renderer
//     //   });

//     //   data.documentChanges
//     //       .where((change) => change.document.data['uid'] != this.uuid)
//     //       .where((change) => change.type == DocumentChangeType.removed)
//     //       .forEach((dc) async {
//     //     final uid = dc.document.data['uid'];
//     //     await _peerConnections[uid].dispose();
//     //     await _dataChannels[uid].close();
//     //     _peerConnections.remove(uid);
//     //     _dataChannels.remove(uid);
//     //   });
//     // });

//     // store
//     //     .collection("rooms")
//     //     .document(words)
//     //     .collection("candidates")
//     //     .where("to", isEqualTo: this.uuid)
//     //     .snapshots()
//     //     .listen((data) async {
//     //   data.documentChanges
//     //       .where((change) => change.type == DocumentChangeType.added)
//     //       .forEach((dc) async {
//     //     print('ICECandidate情報が送られてきました');
//     //     final uid = dc.document.data['from'];
//     //     final candidate = dc.document.data['candidate'];
//     //     final sdpMid = dc.document.data['sdpMid'];
//     //     final sdpMlineIndex = dc.document.data['sdpMLineIndex'];
//     //     final iceCandidate = RTCIceCandidate(candidate, sdpMid, sdpMlineIndex);

//     //     if (_peerConnections[uid] != null) {
//     //       await _peerConnections[uid].addCandidate(iceCandidate);
//     //     } else {
//     //       if (preparedCandidates[uid] == null) {
//     //         preparedCandidates[uid] = [];
//     //       }
//     //       preparedCandidates[uid].add(iceCandidate);
//     //     }
//     //   });

//     //   store
//     //       .collection("rooms")
//     //       .document(words)
//     //       .collection('offers_and_answers')
//     //       .where("type", isEqualTo: "answer")
//     //       .where("to", isEqualTo: this.uuid)
//     //       .snapshots()
//     //       .listen((data) async {
//     //     if (data.documentChanges.length == 0) {
//     //       return;
//     //     }

//     //     data.documentChanges.forEach((change) {
//     //       final uid = change.document.data['from'];
//     //       final sdp = change.document['sdp'];
//     //       final type = change.document['type'];

//     //       _peerConnections[uid]
//     //           .setRemoteDescription(new RTCSessionDescription(sdp, type));

//     //       if (preparedCandidates[uid] != null) {
//     //         preparedCandidates[uid].forEach((c) async {
//     //           await _peerConnections[uid].addCandidate(c);
//     //         });
//     //       }
//     //     });
//     //   });
//     // });

//     // store
//     //     .collection("rooms")
//     //     .document(words)
//     //     .collection("offers_and_answers")
//     //     .where("type", isEqualTo: "offer")
//     //     .where("to", isEqualTo: uuid)
//     //     .snapshots()
//     //     .listen((data) async {
//     //   data.documentChanges
//     //       .where((change) => change.document.data['from'] != this.uuid)
//     //       .where((change) => change.type == DocumentChangeType.added)
//     //       .forEach((dc) async {
//     //     print(dc);
//     //     final uid = dc.document.data['from'];
//     //     final offer = new RTCSessionDescription(
//     //         dc.document.data['sdp'], dc.document.data['type']);
//     //     final connection = await createNewConnection();
//     //     connection.onDataChannel = (dataChannel) {
//     //       _dataChannels[uid] = dataChannel;
//     //       _dataChannels[uid].onMessage = (message) {
//     //         final text = message.text;
//     //         updateDispalyString('$text from $uid');
//     //       };
//     //     };
//     //     connection.onAddStream = applyRemoteStream;

//     //     connection.onIceCandidate = (candidate) {
//     //       connection.addCandidate(candidate);
//     //       store
//     //           .collection("rooms")
//     //           .document(words)
//     //           .collection('candidates')
//     //           .add(Map<String, dynamic>.from({
//     //             ...{
//     //               'from': this.uuid,
//     //               'to': uid,
//     //             },
//     //             ...candidate.toMap()
//     //           }));
//     //     };
//     //     connection.addStream(_localStream);
//     //     connection.setRemoteDescription(offer);

//     //     final answer = await connection.createAnswer({});
//     //     connection.setLocalDescription(answer);

//     //     store
//     //         .collection("rooms")
//     //         .document(words)
//     //         .collection("offers_and_answers")
//     //         .add({
//     //       'type': answer.type,
//     //       'from': this.uuid,
//     //       'to': uid,
//     //       'sdp': answer.sdp
//     //     });

//     //     _peerConnections[uid] = connection;

//     //     if (preparedCandidates[uid] != null) {
//     //       preparedCandidates[uid].forEach((can) {
//     //         connection.addCandidate(can);
//     //       });
//     //       preparedCandidates[uid].clear();
//     //     }
//     //   });
//     // });
//   }
// }
