# yt-album

Download an album from Youtube and split it into sections.

## Setup

`yt-dlp` and `ffmpeg` are required to run this script.

```bash
# Both should return some information.
ffmpeg --version
yt-dlp --version
```

If you use nix you can run:

```bash
nix develop
# Or if you use direnv
direnv allow
```

## Usage

> Make sure that URLs do not contain any weird backslashes.

```bash
./yt-album.sh -- https://www.youtube.com/watch?v=lmvUFhjZdFc
# Or with nix
nix run github:marcelhas/yt-album -- https://www.youtube.com/watch?v=lmvUFhjZdFc
```

Your sections will be placed into `./sections/` by default.

## Section File

> Look at the comment section/description of your video for this!

You need to manually define how to split the album into sections
if Youtube does not provide section information.

Create a section file like `./sections.template.txt` and reference it with the `--section` option.

Follow the format: `(hh:)mm:ss <Section name>` like:

```bash
$ cat sections.template.txt
00:00 No 1 Party Anthem
04:01 Suck it and See
07:11 Fire And The Thud
10:29 The Bakery
12:44 Mardy Bum
15:29 Snap Out of It
18:58 Love Is A Laserquest
...
```

## License

[MIT](./LICENSE) License © 2022-Present [marcelhas](https://github.com/marcelhas)
