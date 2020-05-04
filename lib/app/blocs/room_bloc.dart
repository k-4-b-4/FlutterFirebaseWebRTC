import 'dart:html';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/webrtc.dart';
import 'package:rxdart/rxdart.dart';

//
// コネクション管理とRoom管理の両方を行う
//
class RoomBloc {
  // PeerConnections(ビデオだと10本くらいが限界らしい)
  // なので9個がMax
  final _remotelyAllocatedPeerConnections =
      BehaviorSubject<List<RTCPeerConnection>>();

  // すでにOffer/AnswerとしてやりとりしてConnectionをはっている場合
  var connectedUdids = List<String>();

  Firestore store;

  get roomRef => store.collection('rooms').reference();

  RoomBloc() {
    store = Firestore(app: FirebaseApp.instance);
  }

  // 最初のコネクション情報を生成する
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
    return await createPeerConnection(configuration, loopbackConstraints);
  }
}
