{
  description = "Unframe Cloudflare infrastructure toolchain";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        mkTerraformApp =
          {
            name,
            script,
          }:
          let
            app = pkgs.writeShellApplication {
              name = "unframe-infra-${name}";
              runtimeInputs = [ pkgs.terraform ];
              text = script;
            };
          in
          {
            type = "app";
            program = "${app}/bin/unframe-infra-${name}";
            meta.description = "Run the Unframe infrastructure ${name} check.";
          };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            terraform
            terraform-ls
            tflint
            curl
            jq
            git
          ];
        };

        apps = {
          fmt = mkTerraformApp {
            name = "fmt";
            script = "terraform fmt -check -recursive";
          };
          validate = mkTerraformApp {
            name = "validate";
            script = ''
              terraform init -backend=false -input=false
              terraform validate
            '';
          };
        };

        formatter = pkgs.nixfmt;
      }
    );
}
