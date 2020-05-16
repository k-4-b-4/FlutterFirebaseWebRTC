enum EmojiAction {
  Clap,
  Happy,
  Laugh,
}

extension ActionData on EmojiAction {
  String emojiData() {
    switch (this) {
      case EmojiAction.Clap:
        return ":clap:";
      case EmojiAction.Happy:
        return ":happy:";
      case EmojiAction.Laugh:
        return ":laugh:";
    }

    return '';
  }
}
