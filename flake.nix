# Thanks to <https://ertt.ca/nix/shell-scripts/> for his simple introduction!
{
  description = "Download an album from Youtube and split it into sections.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/master";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        mainScriptName = "yt-album";
        testScriptName = "test";
        buildInputs = with pkgs; [ yt-dlp-light ffmpeg ];
        mainScript = (pkgs.writeScriptBin mainScriptName
          (builtins.readFile ./yt-album.sh)).overrideAttrs (old: {
            buildCommand = ''
              ${old.buildCommand}
               patchShebangs $out'';
          });
        testScript = (pkgs.writeScriptBin testScriptName
          (builtins.readFile ./test.sh)).overrideAttrs (old: {
            buildCommand = ''
              ${old.buildCommand}
               patchShebangs $out'';
          });

      in rec {
        defaultPackage = packages.yt-album;
        # Main script.
        packages.yt-album = pkgs.symlinkJoin {
          name = mainScriptName;
          paths = [ mainScript ] ++ buildInputs;
          buildInputs = [ pkgs.makeWrapper ];
          postBuild =
            "wrapProgram $out/bin/${mainScriptName} --prefix PATH : $out/bin";
        };
        # Tests.
        packages.test = pkgs.symlinkJoin {
          name = testScriptName;
          paths = [ testScript ] ++ buildInputs;
          buildInputs = [ pkgs.makeWrapper ];
          postBuild =
            "wrapProgram $out/bin/${testScriptName} --prefix PATH : $out/bin";
        };
        # Dev environment.
        devShell = pkgs.mkShell {
          nativeBuildInputs = [ pkgs.bashInteractive ];
          buildInputs = with pkgs; [ yt-dlp-light ffmpeg nixfmt ];
        };
      });
}
