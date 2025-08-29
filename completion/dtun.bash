# bash completion for dtun (basic)
_dtun_complete() {
  local cur prev
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  local cmds="init alias key start stop enable disable status logs ssh test"
  if [[ $COMP_CWORD -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "$cmds" -- "$cur") )
    return 0
  fi

  case "${COMP_WORDS[1]}" in
    alias)
      local sub="add list show rm"
      if [[ $COMP_CWORD -eq 2 ]]; then
        COMPREPLY=( $(compgen -W "$sub" -- "$cur") )
      fi
      ;;
    key)
      local sub="gen add copy"
      if [[ $COMP_CWORD -eq 2 ]]; then
        COMPREPLY=( $(compgen -W "$sub" -- "$cur") )
      fi
      ;;
    start|stop|enable|disable|status|logs|ssh|test)
      local list
      list=$(ls -1 ~/.ssh/config.d/*.conf 2>/dev/null | sed -E 's|.*/||; s|\.conf$||')
      COMPREPLY=( $(compgen -W "$list" -- "$cur") )
      ;;
  esac
}
complete -F _dtun_complete dtun
