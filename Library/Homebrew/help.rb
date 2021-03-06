# frozen_string_literal: true

HOMEBREW_HELP = <<~EOS
  Example usage:
    brew search [TEXT|/REGEX/]
    brew info [FORMULA...]
    brew install FORMULA...
    brew update
    brew upgrade [FORMULA...]
    brew uninstall FORMULA...
    brew list [FORMULA...]

  Troubleshooting:
    brew config
    brew doctor
    brew install --verbose --debug FORMULA

  Contributing:
    brew create [URL [--no-fetch]]
    brew edit [FORMULA...]

  Further help:
    brew commands
    brew help [COMMAND]
    man brew
    https://docs.brew.sh
EOS

# NOTE Keep the length of vanilla --help less than 25 lines!
# This is because the default Terminal height is 25 lines. Scrolling sucks
# and concision is important. If more help is needed we should start
# specialising help like the gem command does.
# NOTE Keep lines less than 80 characters! Wrapping is just not cricket.
# NOTE The reason the string is at the top is so 25 lines is easy to measure!

require "cli/parser"
require "commands"

module Homebrew
  module Help
    module_function

    def help(cmd = nil, empty_argv: false, usage_error: nil)
      if cmd.nil?
        # Handle `brew` (no arguments).
        if empty_argv
          $stderr.puts HOMEBREW_HELP
          exit 1
        end

        # Handle `brew (-h|--help|--usage|-?|help)` (no other arguments).
        puts HOMEBREW_HELP
        exit 0
      end

      # Resolve command aliases and find file containing the implementation.
      path = Commands.path(cmd)

      # Display command-specific (or generic) help in response to `UsageError`.
      if usage_error
        $stderr.puts path ? command_help(cmd, path) : HOMEBREW_HELP
        $stderr.puts
        onoe usage_error
        exit 1
      end

      # Resume execution in `brew.rb` for unknown commands.
      return if path.nil?

      # Display help for internal command (or generic help if undocumented).
      puts command_help(cmd, path)
      exit 0
    end

    def command_help(cmd, path)
      # Only some types of commands can have a parser.
      output = if Commands.valid_internal_cmd?(cmd) ||
                  Commands.valid_internal_dev_cmd?(cmd) ||
                  Commands.external_ruby_v2_cmd_path(cmd)
        parser_help(path)
      end

      output ||= comment_help(path)

      output ||= if output.blank?
        opoo "No help text in: #{path}" if Homebrew::EnvConfig.developer?
        HOMEBREW_HELP
      end

      output
    end

    def parser_help(path)
      # Let OptionParser generate help text for commands which have a parser.
      cmd_parser = CLI::Parser.from_cmd_path(path)
      return unless cmd_parser

      # Try parsing arguments here in order to show formula options in help output.
      cmd_parser.parse(Homebrew.args.remaining, ignore_invalid_options: true)
      cmd_parser.generate_help_text
    end

    def comment_help(path)
      # Otherwise read #: lines from the file.
      help_lines = command_help_lines(path)
      return if help_lines.blank?

      Formatter.wrap(help_lines.join, COMMAND_DESC_WIDTH)
               .sub("@hide_from_man_page ", "")
               .sub(/^\* /, "#{Tty.bold}Usage: brew#{Tty.reset} ")
               .gsub(/`(.*?)`/m, "#{Tty.bold}\\1#{Tty.reset}")
               .gsub(%r{<([^\s]+?://[^\s]+?)>}) { |url| Formatter.url(url) }
               .gsub(/<(.*?)>/m, "#{Tty.underline}\\1#{Tty.reset}")
               .gsub(/\*(.*?)\*/m, "#{Tty.underline}\\1#{Tty.reset}")
    end
  end
end
