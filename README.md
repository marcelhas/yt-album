# yt-album

Download an album from Youtube and split it into sections.

## Usage

> Make sure that URLs do not contain any weird backslashes.

```bash
# With nix.
nix run github:marcelhas/yt-album -- "https://www.youtube.com/watch?v=lmvUFhjZdFc"
# With custom sections.
nix run github:marcelhas/yt-album -- --sections ./sections.txt "https://www.youtube.com/watch?v=lmvUFhjZdFc"
# With custom output directory. Directory must already exist!
nix run github:marcelhas/yt-album -- --output ./out/ "https://www.youtube.com/watch?v=lmvUFhjZdFc"
# With Bash (see #Setup).
./yt-album.sh -- "https://www.youtube.com/watch?v=lmvUFhjZdFc"
```

Your sections will be placed into `./sections/` by default.

## Setup

> Not required for nix!

`yt-dlp` and `ffmpeg` are required to run this script.

```bash
# Both should return some information.
ffmpeg --version
yt-dlp --version
```

## Sections

> Look at the comment section and description of your video for this!

You can manually define how to split an album into sections.
Each section is only defined by its start time, 
its end time is implicitly the start of the next section.

Create a section file like `./sections.template.txt` and reference it
 with the `--sections` option.
Follow the format `[hh:]mm:ss <Section name>`, as in:

```bash
$ cat sections.template.txt
00:00 No 1 Party Anthem
04:01 Suck it and See
07:11 Fire And The Thud
10:29 The Bakery
12:44 Mardy Bum
15:29 Snap Out of It
18:58 Love Is A Laserquest
02:59:59 This is the End
...
```

## License

[MIT](./LICENSE) License © 2022-Present [marcelhas](https://github.com/marcelhas)
