# Usage: rbenv rehash [<command>] [<version/gem>]
# Summary: Rehash rbenv shims (run this after installing executables)
# Help: rbenv rehash                => rehash the global version
# rbenv rehash version xxx    => rehash existing commands for a version
# rbenv rehash executable xxx => rehash an executable across versions
#

param($cmd, $argument)


$REHASH_TEMPLATE = @'
# Auto generated by 'rbenv rehash'
. $env:RBENV_ROOT\rbenv\lib\version.ps1
$gem = shim_get_gem_executable_location $PSCommandPath
& $gem $args
'@
# if exists,
#   $rubyexe is C:\Ruby-on-Windows\correct_version_dir\bin\ruby.exe
#
#   $gem     is C:\Ruby-on-Windows\correct_version_dir\bin\'gem_name'.bat or
#               C:\Ruby-on-Windows\correct_version_dir\bin\'gem_name'.cmd
#


# Generate shims for specific name across all versions
#
# Note that $name shouldn't have suffix
#
# This is called after you install a gem
function rehash_single_executable_across_all_versions ($name) {
    $versions = get_all_installed_versions

    foreach ($version in $versions) {
        $where = get_bin_path_for_version $version
        Set-Content "$where\$name.ps1" $REHASH_TEMPLATE -NoNewline
    }
    success "rbenv: Rehash executable $argument for all $($versions.Count) versions"
}


# Generate a shim for specific name in specific version
#
# Note that $name shouldn't have suffix
#
# For 'rehash_version' to use
function rehash_single_executable ($where, $name) {
    Set-Content "$where\$name.ps1" $REHASH_TEMPLATE -NoNewline
}


# Generate shims for a version itself
#
#
# Every time you cd into a dir that has '.ruby-version', you
# want all shims already exists in current global version
# so that you can call it directly as if you have changed the ruby
# version.
#
# So we just need to keep the global version dir, i.e. shims dir
# always have the names that every Ruby has installed to.
#
# How can we achieve this? Via two steps:
# 1. Every time you install a new Ruby version, call 'rehash_version'
# 2. Every time you install a gem, call 'rehash_single_executable_across_all_versions'
#
function rehash_version ($version) {

    $version = auto_fix_version_for_installed $version

    $where = get_bin_path_for_version $version

    $bats = Get-ChildItem "$where\*.bat" | % { $_.Name}

    # From Ruby 3.1.0-1, all default gems except 'gem.cmd' are xxx.bat
    # So we still should handle cmds before 3.1.0-1 and for 'gem.cmd'
    $cmds = Get-ChildItem "$where\*.cmd" | % { $_.Name}

    # 'setrbvars.cmd' and 'ridk.cmd' shouldn't be rehashed
    $cmds = [Collections.ArrayList]$cmds
    $cmds.Remove('setrbvars.cmd')
    $cmds.Remove('ridk.cmd')


    # remove .bat suffix
    $bats = $bats | % { strip_ext $_}
    # remove .cmd suffix
    $cmds = $cmds | % { strip_ext $_}

    $executables = $bats + $cmds

    # echo $executables

    foreach ($exe in $executables) {
        rehash_single_executable $where $exe
    }
    success "rbenv: Rehash $($executables.Count) executables for '$version'"
}


if (!$cmd) {
    # junction is double ended, operations in either dir can affect both two dirs
    $version = get_global_version
    rehash_version $version

} elseif ($cmd -eq 'version') {
    if (!$argument) { rbenv help rehash; return}
    $version = auto_fix_version_for_installed $argument
    rehash_version $version

} elseif ($cmd -eq 'executable') {
    if (!$argument) { rbenv help rehash; return}
    rehash_single_executable_across_all_versions $argument

} else {
    rbenv help rehash
}
