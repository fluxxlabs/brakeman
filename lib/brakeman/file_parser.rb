module Brakeman
  ASTFile = Struct.new(:path, :ast)

  # This class handles reading and parsing files.
  class FileParser
    attr_reader :file_list

    def initialize tracker
      @tracker = tracker
      @timeout = @tracker.options[:parser_timeout]
      @app_tree = @tracker.app_tree
      @file_list = {}
    end

    def parse_files list, type
      read_files list, type do |path, contents|
        relative_path = @app_tree.relative_path(path) # For consistency in __FILE__ handling
        if ast = parse_ruby(contents, relative_path)
          ASTFile.new(path, ast)
        end
      end
    end

    def read_files list, type
      @file_list[type] ||= []

      list.each do |path|
        result = yield path, read_path(path)
        if result
          @file_list[type] << result
        end
      end
    end

    def parse_ruby input, path, parser = RubyParser.new
      begin
        Brakeman.debug "Parsing #{path}"
        parser.parse input, path, @timeout
      rescue Racc::ParseError => e
        if parser.class == RubyParser
          return parse_ruby(input, path, RubyParser.latest)
        else
          @tracker.error e, "Could not parse #{path}"
          nil
        end
      rescue Timeout::Error => e
        @tracker.error Exception.new("Parsing #{path} took too long (> #{@timeout} seconds). Try increasing the limit with --parser-timeout"), caller
        nil
      rescue => e
        @tracker.error e.exception(e.message + "\nWhile processing #{path}"), e.backtrace
        nil
      end
    end

    def read_path path
      @app_tree.read_path path
    end
  end
end
