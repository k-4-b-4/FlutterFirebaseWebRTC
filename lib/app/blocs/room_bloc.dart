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

  Firestore cloudStoreConnection;

  get roomRef => cloudStoreConnection.collection('rooms').reference();

  Map<String, dynamic> configuration = {
    "iceServers": [
      {"url": "stun:stun.l.google.com:19302"},
    ]
  };

  final Map<String, dynamic> offerSdpConstraints = {
    "mandatory": {
      "OfferToReceiveAudio": true,
      "OfferToReceiveVideo": false,
    },
    "optional": [],
  };

  final Map<String, dynamic> loopbackConstraints = {
    "mandatory": {},
    "optional": [
      {"DtlsSrtpKeyAgreement": true},
    ],
  };

  RoomBloc() {
    cloudStoreConnection = Firestore(app: FirebaseApp.instance);
    createFirstPeerConnection();
    startSignaling();
  }

  // 最初のコネクション情報を生成する
  void createFirstPeerConnection() async {
    final peerConnection =
        await createPeerConnection(configuration, loopbackConstraints);

    var peerConnections = List<RTCPeerConnection>(10);
    peerConnections[0] = peerConnection;
  }

  @pragma('Signaling: Start SignalingObserving')
  void startSignaling() {
//    cloudStoreConnection.collection('rooms')
  }
}
