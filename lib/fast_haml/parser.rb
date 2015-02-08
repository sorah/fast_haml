require 'fast_haml/ast'
require 'fast_haml/element_parser'
require 'fast_haml/filter_parser'
require 'fast_haml/indent_tracker'
require 'fast_haml/line_parser'
require 'fast_haml/ruby_multiline'
require 'fast_haml/syntax_error'

module FastHaml
  class Parser
    def initialize(options = {})
    end

    def call(template_str)
      @ast = Ast::Root.new
      @stack = []
      @line_parser = LineParser.new(template_str)
      @indent_tracker = IndentTracker.new(on_enter: method(:indent_enter), on_leave: method(:indent_leave))
      @filter_parser = FilterParser.new(@indent_tracker)

      while @line_parser.has_next?
        line = @line_parser.next_line
        if !@ast.is_a?(Ast::HamlComment) && @filter_parser.enabled?
          ast = @filter_parser.append(line)
          if ast
            @ast << ast
          end
        end
        unless @filter_parser.enabled?
          parse_line(line, @line_parser.lineno)
        end
      end

      ast = @filter_parser.finish
      if ast
        @ast << ast
      end
      @indent_tracker.finish
      @ast
    end

    private


    DOCTYPE_PREFIX = '!'
    ELEMENT_PREFIX = '%'
    SCRIPT_PREFIX = '='
    COMMENT_PREFIX = '/'
    SILENT_SCRIPT_PREFIX = '-'
    DIV_ID_PREFIX = '#'
    DIV_CLASS_PREFIX = '.'
    FILTER_PREFIX = ':'

    def parse_line(line, lineno)
      text, indent = @indent_tracker.process(line, lineno)

      if text.empty?
        return
      end

      if @ast.is_a?(Ast::HamlComment)
        @ast << Ast::Text.new(text)
        return
      end

      case text[0]
      when ELEMENT_PREFIX
        parse_element(text, lineno)
      when DOCTYPE_PREFIX
        if text.start_with?('!!!')
          parse_doctype(text, lineno)
        else
          syntax_error!("Illegal doctype declaration")
        end
      when COMMENT_PREFIX
        parse_comment(text, lineno)
      when SCRIPT_PREFIX
        parse_script(text, lineno)
      when SILENT_SCRIPT_PREFIX
        parse_silent_script(text, lineno)
      when DIV_ID_PREFIX, DIV_CLASS_PREFIX
        parse_line("#{indent}%div#{text}", lineno)
      when FILTER_PREFIX
        parse_filter(text, lineno)
      else
        parse_plain(text, lineno)
      end
    end

    def parse_doctype(text, lineno)
      @ast << Ast::Doctype.new(text)
    end

    def parse_comment(text, lineno)
      @ast << Ast::HtmlComment.new(text[1, text.size-1].strip)
    end

    def parse_plain(text, lineno)
      @ast << Ast::Text.new(text)
    end

    def parse_element(text, lineno)
      @ast << ElementParser.new(text, lineno, @line_parser).parse
    end

    def parse_script(text, lineno)
      script = text[/\A= *(.*)\z/, 1]
      if script.empty?
        syntax_error!("No Ruby code to evaluate")
      end
      script += RubyMultiline.read(@line_parser, script)
      @ast << Ast::Script.new([], script)
    end

    def parse_silent_script(text, lineno)
      if text.start_with?('-#')
        @ast << Ast::HamlComment.new
        return
      end
      script = text[/\A- *(.*)\z/, 1]
      if script.empty?
        syntax_error!("No Ruby code to evaluate")
      end
      script += RubyMultiline.read(@line_parser, script)
      @ast << Ast::SilentScript.new([], script)
    end

    def parse_filter(text, lineno)
      filter_name = text[/\A#{FILTER_PREFIX}(\w+)\z/, 1]
      unless filter_name
        syntax_error!("Invalid filter name: #{text}")
      end
      @filter_parser.start(filter_name)
    end

    def indent_enter(text)
      @stack.push(@ast)
      @ast = @ast.children.last
      if @ast.is_a?(Ast::Element) && @ast.self_closing
        syntax_error!('Illegal nesting: nesting within a self-closing tag is illegal')
      end
      if @ast.is_a?(Ast::HamlComment)
        @indent_tracker.enter_comment!
      end
      nil
    end

    def indent_leave(text)
      parent_ast = @stack.pop
      case @ast
      when Ast::Script, Ast::SilentScript
        @ast.mid_block_keyword = mid_block_keyword?(text)
      end
      @ast = parent_ast
      nil
    end

    MID_BLOCK_KEYWORDS = %w[else elsif rescue ensure end when]
    START_BLOCK_KEYWORDS = %w[if begin case unless]
    # Try to parse assignments to block starters as best as possible
    START_BLOCK_KEYWORD_REGEX = /(?:\w+(?:,\s*\w+)*\s*=\s*)?(#{Regexp.union(START_BLOCK_KEYWORDS)})/
    BLOCK_KEYWORD_REGEX = /^-?\s*(?:(#{Regexp.union(MID_BLOCK_KEYWORDS)})|#{START_BLOCK_KEYWORD_REGEX.source})\b/

    def block_keyword(text)
      m = text.match(BLOCK_KEYWORD_REGEX)
      if m
        m[1] || m[2]
      else
        nil
      end
    end

    def mid_block_keyword?(text)
      MID_BLOCK_KEYWORDS.include?(block_keyword(text))
    end

    def syntax_error!(message)
      raise SyntaxError.new(message, @line_parser.lineno)
    end
  end
end
