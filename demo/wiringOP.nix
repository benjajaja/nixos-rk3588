{
  lib,
  stdenv,
  symlinkJoin,
  fetchFromGitHub,
  libxcrypt,
}:

let
  version = "unstable-2023-11-16";
  srcAll = fetchFromGitHub {
    owner = "orangepi-xunlong";
    repo = "wiringOP";
    rev = "8cb35ff967291aca24f22af151aaa975246cf861";
    sha256 = "sha256-W6lZh4nEhhpkdcu/PWbVmjcvfhu6eqRGlkj8jiphG+k=";
  };
  mkSubProject =
    {
      subprj, # The only mandatory argument
      buildInputs ? [ ],
      src ? srcAll,
    }:
    stdenv.mkDerivation (finalAttrs: {
      pname = "wiringop-${subprj}";
      inherit version src;
      sourceRoot = "${src.name}/${subprj}";
      inherit buildInputs;
      # Remove (meant for other OSs) lines from Makefiles
      preInstall = ''
        mkdir -p $out/bin
        sed -i "/chown root/d" Makefile
        sed -i "/chmod/d" Makefile
        sed -i "/ldconfig/d" Makefile
      '';
      makeFlags = [
        "DESTDIR=${placeholder "out"}"
        "PREFIX=/."
        # On NixOS we don't need to run ldconfig during build:
        "LDCONFIG=echo"
      ];
    });
  passthru = {
    # Helps nix-update and probably nixpkgs-update find the src of this package
    # automatically.
    src = srcAll;
    inherit mkSubProject;
    wiringPi = mkSubProject {
      subprj = "wiringPi";
      buildInputs = [ libxcrypt ];
    };
    devLib = mkSubProject {
      subprj = "devLib";
      buildInputs = [ passthru.wiringPi ];
    };
    gpio = mkSubProject {
      subprj = "gpio";
      buildInputs = [
        libxcrypt
        passthru.wiringPi
        passthru.devLib
      ];
    };
  };
in

symlinkJoin {
  name = "wiringop-${version}";
  inherit passthru;
  paths = [
    passthru.wiringPi
    passthru.devLib
    passthru.gpio
  ];
  meta = with lib; {
    description = "GPIO access library for Orange Pi (wiringPi port)";
    homepage = "https://github.com/orangepi-xunlong/wiringOP";
    license = licenses.lgpl3Plus;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
