# Michi’s Hangul Games

An offline Flutter app of mini-games for learning Korean Hangul, vocabulary and numbers.

## Build

```sh
flutter pub get
flutter build apk --release --split-per-abi --target-platform android-arm64
```

## Vocabulary and word packs

Each built-in word pack is one file in `assets/vocab/<pack-id>.ini`.
`assets/vocab/index.txt` lists the pack ids in display order.

**Add a pack:** create `assets/vocab/<id>.ini` that starts with a header, then add `<id>` to `index.txt`.

```ini
[Pack]
Id = my-pack
Emoji = 🍀
Name = My Pack
Blurb = One short line shown under the name.
DefaultOn = false
```

**Add a word:** add a section to the pack's file. The section name must be unique across all files, because saved stats and edits are keyed by it. The word's home pack is the file it is in.

```ini
[Entry_01000]
English1 = Spider
Korean1 = 거미
Emoji = 🕷️
; optional: English2, Korean2, IsFullPhrase = true, AlsoPacks = food, animals
; optional: NotWith = Entry_00187 (section names of words too alike to share a round)
```

Never rename a pack `Id` or a word section, because players' saved data uses them.
`flutter test` checks the files for duplicate section names, unknown keys or AlsoPacks ids, missing English1/Korean1, and bad pack headers.
