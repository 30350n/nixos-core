{
    fetchPypi,
    python3Packages,
    writeText,
}:
python3Packages.buildPythonApplication {
    pname = "install";
    version = "1.0";
    pyproject = true;
    build-system = with python3Packages; [setuptools];

    src = ./.;

    postInstall = ''
        wrapPythonPrograms $out/bin
    '';

    dependencies = [
        (python3Packages.buildPythonPackage rec {
            pname = "cutie";
            version = "0.3.2";
            pyproject = true;
            build-system = with python3Packages; [setuptools];

            patches = [
                (writeText "replace-imp.patch" ''
                    --- a/setup.py
                    +++ b/setup.py
                    @@ -4 +4 @@
                    -import imp
                    +import types
                    @@ -15 +15 @@ with open("cutie.py", encoding="utf-8") as file:
                    -cutie = imp.new_module("cutie")
                    +cutie = types.ModuleType("cutie")
                '')
            ];

            src = fetchPypi {
                inherit pname version;
                sha256 = "B5je6Y5x2E68AaElFVyNlMlsydBM9pKU2Lmmjt2TaW0=";
            };

            dependencies = with python3Packages; [colorama readchar];
        })
        (python3Packages.buildPythonPackage rec {
            pname = "error_helper";
            version = "1.5";
            pyproject = true;
            build-system = with python3Packages; [hatchling];

            src = fetchPypi {
                inherit pname version;
                sha256 = "7kbzGmidsZzhoE5p9Ddjn6oDc+HUzkN02ykS0e0JodY=";
            };
        })
    ];
}
