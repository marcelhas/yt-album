# yt-album

A simple bash script that downloads an album from Youtube and splits it
by tracks using either native Youtube sections or a custom text file.

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

In most cases, you can simply run the following command as Youtube
provides section information for many albums.
Your tracks will be placed into `./tracks/`.

```bash
./yt-album.sh https://www.youtube.com/watch?v=lmvUFhjZdFc
```

If Youtube does not provide section information then you need to manually
define how to split the album into tracks.
Have a look at the comment section/description of your album, often there
will be a comment in the correct format.

Copy `chapters.template.txt` to `chapters.txt` and make your edits,
while following the format. Empty lines are ignored.

> (hh:)mm:ss \<Track name\>

```plain
00:00 No 1 Party Anthem
04:01 Suck it and See
07:11 Fire And The Thud
10:29 The Bakery
12:44 Mardy Bum
15:29 Snap Out of It
18:58 Love Is A Laserquest
21:29 ...
```

## License

[MIT](./LICENSE) License © 2022-Present [marcelhas](https://github.com/marcelhas)
