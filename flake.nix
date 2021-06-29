# Maintaining this file:
#
#     - Bump the inputs version using `nix flake update`
#     - Edit `sourceDirs` to update the set of local packages
#
# For more details: https://nixos.wiki/wiki/Flakes
{
  description = "haskell language server flake";

  inputs = {
    nixpkgs = {
      type = "github";
      owner = "vkleen";
      repo = "nixpkgs";
      ref = "haskell-hacks";
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      flake = false;
    };
  };
  outputs =
    { self, nixpkgs, flake-compat, flake-utils, pre-commit-hooks, gitignore }:
    {
      overlay = final: prev:
        with prev;
        let
          haskellOverrides = {
            overrides = hself: hsuper: {
              # we override mkDerivation here to apply the following
              # tweak to each haskell package:
              #   if the package is broken, then we disable its check and relax the cabal bounds;
              #   otherwise, we leave it unchanged.
              # hopefully, this could fix packages marked as broken by nix due to check failures
              # or the build failure because of tight cabal bounds
              mkDerivation = args:
                let
                  broken = args.broken or false;
                  check = args.doCheck or true;
                  jailbreak = args.jailbreak or false;
                in hsuper.mkDerivation (args // {
                  jailbreak = if broken then true else jailbreak;
                  doCheck = if broken then false else check;
                });
            };
          };
          gitignoreSource = (import gitignore { inherit lib; }).gitignoreSource;

          # List all subdirectories under `./plugins`, except `./plugins/default`
          pluginsDir = ./plugins;
          pluginSourceDirs = builtins.removeAttrs (lib.mapAttrs'
            (name: _: lib.nameValuePair name (pluginsDir + ("/" + name)))
            (builtins.readDir pluginsDir)) [ "default" ];

          # Source directories of our packages, should be consistent with cabal.project
          sourceDirs = {
            ghcide = ./ghcide;
            hls-graph = ./hls-graph;
            shake-bench = ./shake-bench;
            hie-compat = ./hie-compat;
            hls-plugin-api = ./hls-plugin-api;
            hls-test-utils = ./hls-test-utils;

            hls-class-plugin = ./plugins/hls-class-plugin;
            hls-eval-plugin = ./plugins/hls-eval-plugin;
            hls-explicit-imports-plugin = ./plugins/hls-explicit-imports-plugin;
            hls-refine-imports-plugin = ./plugins/hls-refine-imports-plugin;
            hls-hlint-plugin = ./plugins/hls-hlint-plugin;
            hls-retrie-plugin = ./plugins/hls-retrie-plugin;
            hls-haddock-comments-plugin = ./plugins/hls-haddock-comments-plugin;
            hls-floskell-plugin = ./plugins/hls-floskell-plugin;
            hls-pragmas-plugin = ./plugins/hls-pragmas-plugin;
            hls-module-name-plugin = ./plugins/hls-module-name-plugin;
          };
          # } // pluginSourceDirs;

          # Tweak our packages
          # Don't use `callHackage`, it requires us to override `all-cabal-hashes`
          tweaks = hself: hsuper:
            with haskell.lib; let
              lsp-src = builtins.fetchGit {
                url = "https://github.com/anka-213/lsp";
                ref = "refs/tags/tag-ghc-9.0.1-without-pr-326";
                rev = "c097d9cb82eb626210be161907abcd01b11c824a";
              };

              generic-lens-src = builtins.fetchGit {
                url = "https://github.com/kcsongor/generic-lens";
                rev = "8e1fc7dcf444332c474fca17110d4bc554db08c8";
              };

              these-src = builtins.fetchTarball {
                url = "https://github.com/haskellari/these/tarball/a1fe1ae3ca6e4e6280373ff62c831d81e101c245";
                sha256 = "sha256:1k1af01ysm7qfgb8f1jl5n8nlkn3bbl5jf95gysk6vphfrpg2s70";
              };
            in {

              # # https://github.com/haskell/haskell-language-server/pull/1858
              # # Remove this override when nixpkgs has this package
              # apply-refact_0_9_3_0 = hself.callCabal2nix "apply-refact"
              #   (builtins.fetchTarball {
              #     url =
              #       "https://hackage.haskell.org/package/apply-refact-0.9.3.0/apply-refact-0.9.3.0.tar.gz";
              #     sha256 =
              #       "1jfq1aw91finlpq5nn7a96za4c8j13jk6jmx2867fildxwrik2qj";
              #   }) { };

              # hls-hlint-plugin = hsuper.hls-hlint-plugin.override {
              #   # hlint = hself.hlint_3_2_7;
              #   apply-refact = hself.apply-refact_0_9_3_0;
              # };

              ghc-api-compat = hself.callCabal2nix "ghc-api-compat"
                (builtins.fetchGit {
                  url = "https://gitlab.haskell.org/haskell/ghc-api-compat.git";
                  rev = "b40dc9e77fb5274a84b5e9ddf6c3224c4d9a7afc";
                }) {};

              czipwith = hself.callCabal2nix "czipwith"
                (builtins.fetchGit {
                  url = "https://github.com/mithrandi/czipwith.git";
                  rev = "b6245884ae83e00dd2b5261762549b37390179f8";
                  ref = "ghc9";
                }) {};

              blaze-textual = hself.callCabal2nix "blaze-textual"
                (builtins.fetchGit {
                  url = "https://github.com/jwaldmann/blaze-textual.git";
                  rev = "d8ee6cf80e27f9619d621c936bb4bda4b99a183f";
                }) {};

              hie-bios = hself.callCabal2nix "hie-bios"
                (builtins.fetchGit {
                  url = "https://github.com/jneira/hie-bios/";
                  rev = "9b1445ab5efcabfad54043fc9b8e50e9d8c5bbf3";
                  ref = "ghc-9.0.1-compat";
                }) {};

              th-extras = hself.callCabal2nix "th-extras"
                (builtins.fetchGit {
                  url = "https://github.com/anka-213/th-extras";
                  rev = "57a97b4df128eb7b360e8ab9c5759392de8d1659";
                  ref = "ghc-9.0.1";
                }) {};

              dependent-sum-template = hself.callCabal2nix "dependent-sum-template"
                ("${builtins.fetchGit {
                  url = "https://github.com/anka-213/dependent-sum";
                  rev = "8cf4c7fbc3bfa2be475a17bb7c94a1e1e9a830b5";
                  ref = "ghc901";
                }}/dependent-sum-template") {};

              hiedb = hself.callCabal2nix "hiedb"
                (builtins.fetchGit {
                  url = "https://github.com/anka-213/HieDb";
                  rev = "a3f7521f6c5af1b977040cce09c8f7354f8984eb";
                  ref = "ghc-9.0.1-1";
                }) {};

              lsp-types = hself.callCabal2nix "lsp-types" "${lsp-src}/lsp-types" {};
              lsp = hself.callCabal2nix "lsp" "${lsp-src}/lsp" {};
              lsp-test = hself.callCabal2nix "lsp-test" "${lsp-src}/lsp-test" {};

              generic-lens-core = hself.callCabal2nix "generic-lens-core" "${generic-lens-src}/generic-lens-core" {};
              generic-lens = hself.callCabal2nix "generic-lens" "${generic-lens-src}/generic-lens" {};
              generic-optics = hself.callCabal2nix "generic-optics" "${generic-lens-src}/generic-optics" {};

              ghc-lib-parser = hself.ghc-lib-parser_9_0_1_20210324;

              multistate = doJailbreak hsuper.multistate;

              monad-chronicle = hself.callCabal2nix "monad-chronicle" "${these-src}/monad-chronicle" {};
              semialign-indexed = hself.callCabal2nix "semialign-indexed" "${these-src}/semialign-indexed" {};
              semialign-optics = hself.callCabal2nix "semialign-optics" "${these-src}/semialign-optics" {};
              semialign = hself.callCabal2nix "semialign" "${these-src}/semialign" {};
              these-lens = hself.callCabal2nix "these-lens" "${these-src}/these-lens" {};
              these-optics = hself.callCabal2nix "these-optics" "${these-src}/these-optics" {};
              # these = hself.callCabal2nix "these" "${these-src}/these" {};

              haskell-language-server = hself.callCabal2nixWithOptions
                "haskell-language-server"
                (gitignoreSource ./.)
                "-f-brittany -f-class -f-eval -f-fourmolu -f-ormolu -f-splice -f-stylishhaskell -f-tactic -f-refineImports -f-all-plugins"
                {};
            };

          hlsSources =
            builtins.mapAttrs (_: dir: gitignoreSource dir) sourceDirs;

          extended = hpkgs:
            (hpkgs.override haskellOverrides).extend (hself: hsuper:
              # disable all checks for our packages
              builtins.mapAttrs (_: drv: haskell.lib.dontCheck drv)
              (lib.composeExtensions
                (haskell.lib.packageSourceOverrides hlsSources) tweaks hself
                hsuper));

        in {
          inherit hlsSources;

          # Haskell packages extended with our packages
          hlsHpkgs = compiler: extended haskell.packages.${compiler};

          # Support of GenChangelogs.hs
          gen-hls-changelogs =
            let myGHC = haskellPackages.ghcWithPackages (p: with p; [ github ]);
            in runCommand "gen-hls-changelogs" {
              passAsFile = [ "text" ];
              preferLocalBuild = true;
              allowSubstitutes = false;
              buildInputs = [ git myGHC ];
            } ''
              dest=$out/bin/gen-hls-changelogs
              mkdir -p $out/bin
              echo "#!${runtimeShell}" >> $dest
              echo "${myGHC}/bin/runghc ${./GenChangelogs.hs}" >> $dest
              chmod +x $dest
            '';
        };
    } // (flake-utils.lib.eachSystem [ "x86_64-linux" "x86_64-darwin" ])
    (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlay ];
          config = { allowBroken = true; };
        };

        # Pre-commit hooks to run stylish-haskell
        pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            stylish-haskell.enable = true;
            stylish-haskell.excludes = [
              # Ignored files
              "^Setup.hs$"
              "test/testdata/.*$"
              "test/data/.*$"
              "test/manual/lhs/.*$"
              "^hie-compat/.*$"
              "^plugins/hls-tactics-plugin/.*$"

              # Temporarily ignored files
              # Stylish-haskell (and other formatters) does not work well with some CPP usages in these files
              "^ghcide/src/Development/IDE/GHC/Compat.hs$"
              "^plugins/hls-splice-plugin/src/Ide/Plugin/Splice.hs$"
              "^ghcide/test/exe/Main.hs$"
              "ghcide/src/Development/IDE/Core/Rules.hs"
              "^hls-test-utils/src/Test/Hls/Util.hs$"
            ];
          };
        };

        # GHC versions
        ghcDefault = pkgs.hlsHpkgs ("ghc"
          + pkgs.lib.replaceStrings [ "." ] [ "" ]
          pkgs.haskellPackages.ghc.version);
        ghc884 = pkgs.hlsHpkgs "ghc884";
        ghc8104 = pkgs.hlsHpkgs "ghc8104";
        ghc8105 = pkgs.hlsHpkgs "ghc8105";
        ghc901 = pkgs.hlsHpkgs "ghc901";

        # Create a development shell of hls project
        # See https://github.com/NixOS/nixpkgs/blob/5d4a430472cafada97888cc80672fab255231f57/pkgs/development/haskell-modules/make-package-set.nix#L319
        mkDevShell = hpkgs:
          with pkgs;
          hpkgs.shellFor {
            doBenchmark = true;
            packages = p:
              with builtins;
              map (name: p.${name}) (attrNames pkgs.hlsSources);
            buildInputs = [ gmp zlib ncurses capstone tracy gen-hls-changelogs ]
              ++ (with haskellPackages; [
                cabal-install
                hlint
                ormolu
                stylish-haskell
                opentelemetry-extra
              ]);

            src = null;
            shellHook = ''
              export LD_LIBRARY_PATH=${gmp}/lib:${zlib}/lib:${ncurses}/lib:${capstone}/lib
              export DYLD_LIBRARY_PATH=${gmp}/lib:${zlib}/lib:${ncurses}/lib:${capstone}/lib
              export PATH=$PATH:$HOME/.local/bin
              ${pre-commit-check.shellHook}
            '';
          };
        # Create a hls executable
        # Copied from https://github.com/NixOS/nixpkgs/blob/210784b7c8f3d926b7db73bdad085f4dc5d79418/pkgs/development/tools/haskell/haskell-language-server/withWrapper.nix#L16
        mkExe = hpkgs:
          with pkgs.haskell.lib;
          justStaticExecutables (overrideCabal hpkgs.haskell-language-server
            (_: {
              configureFlags = [ "-f-brittany"
                                 "-f-class"
                                 "-f-eval"
                                 "-f-fourmolu"
                                 "-f-ormolu"
                                 "-f-splice"
                                 "-f-stylishhaskell"
                                 "-f-tactic"
                                 "-f-refineImports"
                                 "-f-all-plugins"
                               ];
              postInstall = ''
                remove-references-to -t ${hpkgs.ghc} $out/bin/haskell-language-server
                remove-references-to -t ${hpkgs.shake.data} $out/bin/haskell-language-server
                remove-references-to -t ${hpkgs.js-jquery.data} $out/bin/haskell-language-server
                remove-references-to -t ${hpkgs.js-dgtable.data} $out/bin/haskell-language-server
                remove-references-to -t ${hpkgs.js-flot.data} $out/bin/haskell-language-server
              '';
            }));
      in with pkgs; rec {
        packages = {
          haskellPackages = ghc901;

          # dev shell
          haskell-language-server-dev = mkDevShell ghcDefault;
          haskell-language-server-884-dev = mkDevShell ghc884;
          haskell-language-server-8104-dev = mkDevShell ghc8104;
          haskell-language-server-8105-dev = mkDevShell ghc8105;
          haskell-language-server-901-dev = mkDevShell ghc901;

          # hls package
          haskell-language-server = mkExe ghcDefault;
          haskell-language-server-884 = mkExe ghc884;
          haskell-language-server-8104 = mkExe ghc8104;
          haskell-language-server-8105 = mkExe ghc8105;
          haskell-language-server-901 = mkExe ghc901;
        };

        defaultPackage = packages.haskell-language-server;

        devShell = packages.haskell-language-server-dev;
      });
}

