# fish completions for g3rm0n
set -l sections cpu memory disk power processes network ai-tokens ai-credits

complete -c g3rm0n -f
complete -c g3rm0n -n __fish_use_subcommand -a setup -d 'Choose sections and AI providers'
complete -c g3rm0n -n __fish_use_subcommand -a version -d 'Print the version'
complete -c g3rm0n -n __fish_use_subcommand -a help -d 'Show help'

complete -c g3rm0n -n '__fish_seen_subcommand_from setup' -l defaults -d 'Write a config with everything detected'
complete -c g3rm0n -n '__fish_seen_subcommand_from setup' -l show -d 'Print config and detected providers'
complete -c g3rm0n -n '__fish_seen_subcommand_from setup' -l reset -d 'Delete the config'

complete -c g3rm0n -n 'not __fish_seen_subcommand_from setup' -s 1 -l once -d 'Print one snapshot and exit'
complete -c g3rm0n -n 'not __fish_seen_subcommand_from setup' -s i -l interval -x -d 'Seconds between refreshes'
complete -c g3rm0n -n 'not __fish_seen_subcommand_from setup' -s s -l sections -x -a "$sections" -d 'Sections for this run'
complete -c g3rm0n -n 'not __fish_seen_subcommand_from setup' -l no-ai -d 'Hide AI panels, no network calls'
complete -c g3rm0n -n 'not __fish_seen_subcommand_from setup' -l no-color -d 'Plain output'
