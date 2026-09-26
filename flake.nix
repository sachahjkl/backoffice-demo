{
  description = "Independent Froment backoffice demo assembly";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2605";
    git-hooks = {
      url = "https://flakehub.com/f/cachix/git-hooks.nix/0.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    git-hooks,
    ...
  }: let
    forSystems = f: nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux"] (system: f (import nixpkgs {inherit system;}));
    preCommit = pkgs:
      git-hooks.lib.${pkgs.stdenv.hostPlatform.system}.run {
        package = pkgs.prek;
        src = ./.;
        hooks = {
          alejandra.enable = true;
          deadnix.enable = true;
          statix.enable = true;
          check-json.enable = true;
          check-merge-conflicts.enable = true;
          end-of-file-fixer.enable = true;
          trim-trailing-whitespace.enable = true;
          yamllint.enable = true;
        };
      };
  in {
    packages = forSystems (pkgs:
      pkgs.lib.optionalAttrs (builtins.pathExists ./package-lock.json) (let
        inherit (pkgs) lib;
        package = builtins.fromJSON (builtins.readFile ./package.json);
        publishedVersion = (builtins.fromJSON (builtins.readFile ./package-lock.json)).packages."node_modules/@sachahjkl/backoffice".version;
        commit = self.rev or (self.dirtyRev or "0000000000000000000000000000000000000000");
        deploymentMetadata = builtins.toJSON {
          inherit commit;
          packages = [
            {
              name = "@froment/api";
              version = publishedVersion;
            }
            {
              name = "@sachahjkl/backoffice";
              version = publishedVersion;
            }
          ];
        };
        # Do not permit a release without a registry-generated lock and its verified Nix hash.
        assembly = pkgs.buildNpmPackage {
          pname = package.name;
          inherit (package) version;
          src = lib.fileset.toSource {
            root = ./.;
            fileset = lib.fileset.unions [./package.json ./package-lock.json ./brand/acme.png];
          };
          nodejs = pkgs.nodejs_26;
          npmDepsHash = "sha256-VM9UeKR1ZPlq2QuC/zstX/bi1y2bYzi3ny9XiL6IoOY=";
          dontNpmBuild = true;
          installPhase = ''
            runHook preInstall
            mkdir -p "$out/lib/backoffice-demo" "$out/bin"
            cp -r node_modules package.json "$out/lib/backoffice-demo/"
            cp brand/acme.png "$out/lib/backoffice-demo/node_modules/@sachahjkl/backoffice/dist/web/brand/acme.png"
            ln -s "$out/lib/backoffice-demo/node_modules/.bin/froment-backoffice" "$out/bin/froment-backoffice"
            runHook postInstall
          '';
        };
        image = pkgs.dockerTools.buildLayeredImage {
          name = "backoffice-demo";
          tag = package.version;
          contents = [assembly pkgs.nodejs-slim_26 pkgs.typst pkgs.cacert pkgs.dockerTools.fakeNss];
          fakeRootCommands = ''
            cp --remove-destination ./etc/passwd ./etc/passwd.writable
            cp --remove-destination ./etc/group ./etc/group.writable
            mv ./etc/passwd.writable ./etc/passwd
            mv ./etc/group.writable ./etc/group
            chmod u+w ./etc/passwd ./etc/group
            mkdir -p ./var/lib/backoffice-demo ./tmp
            chmod 1777 ./tmp
            echo 'demo:x:1000:1000:Demo:/var/lib/backoffice-demo:/bin/sh' >> ./etc/passwd
            echo 'demo:x:1000:' >> ./etc/group
            chown 1000:1000 ./var/lib/backoffice-demo
          '';
          config = {
            Cmd = ["${assembly}/bin/froment-backoffice"];
            Env = [
              "DATABASE_PATH=/var/lib/backoffice-demo/froment.sqlite"
              "PORT=3000"
              "NODE_ENV=production"
              "DEPLOYMENT_METADATA=${deploymentMetadata}"
              "PATH=${lib.makeBinPath [assembly pkgs.nodejs-slim_26 pkgs.typst]}"
              "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              "HOME=/var/lib/backoffice-demo"
              "TMPDIR=/tmp"
            ];
            User = "demo";
            ExposedPorts."3000/tcp" = {};
            Volumes."/var/lib/backoffice-demo" = {};
          };
        };
      in {
        default = assembly;
        dockerImage = image;
      }));

    checks = forSystems (pkgs:
      {
        pre-commit = preCommit pkgs;
        # Image verification becomes available after the published package is locked.
      }
      // pkgs.lib.optionalAttrs (builtins.pathExists ./package-lock.json) {
        build = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        dockerImage = self.packages.${pkgs.stdenv.hostPlatform.system}.dockerImage;
      });

    devShells = forSystems (pkgs: let
      preCommitCheck = preCommit pkgs;
    in {
      default = pkgs.mkShell {
        packages = preCommitCheck.enabledPackages ++ [pkgs.nodejs_26 pkgs.typst];
        inherit (preCommitCheck) shellHook;
      };
    });

    formatter = forSystems (pkgs: pkgs.alejandra);
  };
}
