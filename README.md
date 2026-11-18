# LAFLEURMUSIC for desktop

<p align="center">
  <a href="https://github.com/Jonlekern/lafleurmusic-desktop/releases/latest/download/LAFLEURMUSIC-mac.zip"><img alt="Download for macOS" src="https://img.shields.io/github/v/release/Jonlekern/lafleurmusic-desktop?label=Download%20for%20macOS&style=for-the-badge&color=F26EF2&labelColor=1a1a1a&logo=apple&logoColor=white" height="40"></a>
</p>
<p align="center">
  <sub>macOS 12+ · Apple silicon &amp; Intel · <a href="https://github.com/Jonlekern/lafleurmusic-desktop/releases">all versions</a> · <a href="#download-macos">first launch: right-click → Open</a></sub>
</p>

An iPod-inspired music player and library manager for macOS (Windows coming), in the LAFLEURSTUDIO style.
The big sibling of [LAFLEURMUSIC](https://github.com/Jonlekern/lafleurmusic) for handheld consoles.

- Library in columns (artists, albums, tracks), search, Cover Flow, Now Playing with equalizer
- Up Next queue (Play Next / Add to Queue, drag to reorder), Top 100 most played
- Crossfade and Equal Volume (loudness levelling)
- Edit tags, replace or delete tracks (to the Trash, with automatic renumbering)
- Winamp classic skins (.wsz)
- Plays FLAC, MP3, ALAC, AAC, Opus, APE, WavPack, DSD and more

## Download (macOS)

1. Get **LAFLEURMUSIC-mac.zip** from the [latest release](https://github.com/Jonlekern/lafleurmusic-desktop/releases/latest).
2. Unzip it and move **LAFLEURMUSIC.app** to your Applications folder.
3. First launch: the app is not notarized by Apple, so macOS will refuse to open it with a double-click.
   **Right-click the app → Open → Open.** If macOS still blocks it, go to
   **System Settings → Privacy & Security** and click **Open Anyway**. You only do this once.

Requires macOS 12 or later, Apple silicon or Intel.

## Build from source

Flutter 3.47 or later, Xcode for macOS.

```bash
flutter pub get
flutter build macos --release
```

The app is in `build/macos/Build/Products/Release/`. Tests: `flutter test`.

## License

MIT — see [LICENSE](LICENSE). LAFLEURSTUDIO logos and brand assets are not covered by the MIT License.
Third-party components and their licenses: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
