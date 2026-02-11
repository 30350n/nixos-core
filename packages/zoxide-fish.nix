{
    fishPlugins,
    fetchFromGitHub,
}:
fishPlugins.buildFishPlugin rec {
    pname = "zoxide-fish";
    version = "3.0";

    src = fetchFromGitHub {
        owner = "icezyclon";
        repo = "zoxide.fish";
        rev = "${version}";
        sha256 = "OjrX0d8VjDMxiI5JlJPyu/scTs/fS/f5ehVyhAA/KDM=";
    };
}
