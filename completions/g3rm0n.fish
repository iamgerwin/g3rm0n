# fish completions for g3rm0n

# Completes one item of a comma-separated list, keeping the items already typed.
# (fish's own __fish_complete_list relies on GNU sed, so it breaks on macOS.)
function __g3rm0n_list --description 'Complete a comma-separated g3rm0n list'
    set -l done (string replace -r -- '[^,]*$' '' (commandline -ct))
    for item in cpu memory disk power processes network ai-tokens ai-credits $argv
        printf '%s%s\n' "$done" $item
    end
end

complete -c g3rm0n -f
complete -c g3rm0n -n __fish_use_subcommand -a setup -d 'Choose sections and AI providers'
complete -c g3rm0n -n __fish_use_subcommand -a sensors -d 'List readable temperature sensors'
complete -c g3rm0n -n __fish_use_subcommand -a version -d 'Print the version'
complete -c g3rm0n -n __fish_use_subcommand -a help -d 'Show help'

complete -c g3rm0n -n '__fish_seen_subcommand_from setup' -l defaults -d 'Write a config with everything detected'
complete -c g3rm0n -n '__fish_seen_subcommand_from setup' -l show -d 'Print config and detected providers'
complete -c g3rm0n -n '__fish_seen_subcommand_from setup' -l reset -d 'Delete the config'
complete -c g3rm0n -n '__fish_seen_subcommand_from setup' -l help -d 'Show setup help'

complete -c g3rm0n -n 'not __fish_seen_subcommand_from setup' -s 1 -l once -d 'Print one snapshot and exit'
complete -c g3rm0n -n 'not __fish_seen_subcommand_from setup' -s i -l interval -x -d 'Seconds between refreshes'
# comma-separated list, e.g. cpu,memory,ai-tokens
complete -c g3rm0n -n 'not __fish_seen_subcommand_from setup' -s s -l sections -x \
    -a '(__g3rm0n_list)' -d 'Sections for this run'
complete -c g3rm0n -n 'not __fish_seen_subcommand_from setup' -s f -l fold -x \
    -a '(__g3rm0n_list all none)' -d 'Start with these folded'
complete -c g3rm0n -n 'not __fish_seen_subcommand_from setup' -l no-mouse -d 'Do not capture the mouse'
complete -c g3rm0n -n 'not __fish_seen_subcommand_from setup' -l no-ai -d 'Hide AI panels, no network calls'
complete -c g3rm0n -n 'not __fish_seen_subcommand_from setup' -l no-color -d 'Plain output'
