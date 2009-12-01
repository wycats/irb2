#
#   irb/ruby-lex.rb - ruby lexcal analyzer
#       $Release Version: 0.9.5$
#       $Revision: 16857 $
#       $Date: 2008-06-06 17:05:24 +0900 (Fri, 06 Jun 2008) $
#       by Keiju ISHITSUKA(keiju@ruby-lang.org)
#
# --
#
#
#

require "e2mmap"
require "irb/slex"
require "irb/ruby-token"

# EXPR_BEG,     /* ignore newline, +/- is a sign. */
# EXPR_END,     /* newline significant, +/- is an operator. */
# EXPR_ENDARG,    /* ditto, and unbound braces. */
# EXPR_ARG,     /* newline significant, +/- is an operator. */
# EXPR_CMDARG,    /* newline significant, +/- is an operator. */
# EXPR_MID,     /* newline significant, +/- is an operator. */
# EXPR_FNAME,     /* ignore newline, no reserved words. */
# EXPR_DOT,     /* right after `.' or `::', no reserved words. */
# EXPR_CLASS,     /* immediate after `class', no here document. */
# EXPR_VALUE      /* alike EXPR_BEG but label is disallowed. */

class RubyLex
  @RCS_ID='-$Id: ruby-lex.rb 16857 2008-06-06 08:05:24Z knu $-'

  extend Exception2MessageMapper
  def_exception(:AlreadyDefinedToken, "Already defined token(%s)")
  def_exception(:TkReading2TokenNoKey, "key nothing(key='%s')")
  def_exception(:TkSymbol2TokenNoKey, "key nothing(key='%s')")
  def_exception(:TkReading2TokenDuplicateError,
                "key duplicate(token_n='%s', key='%s')")
  def_exception(:SyntaxError, "%s")

  def_exception(:TerminateLineInput, "Terminate Line Input")

  include RubyToken

  class << self
    attr_accessor :debug_level
    def debug?
      @debug_level > 0
    end
  end
  @debug_level = 0

  def initialize
    lex_init
    set_input { STDIN.gets }

    @seek = 0
    @exp_line_no = @line_no = 1
    @base_char_no = 0
    @char_no = 0
    @rests = []
    @readed = []
    @here_readed = []

    @indent = 0
    @indent_stack = []
    begin_expression
    @space_seen = false
    @here_header = false

    @continue = false
    @line = ""

    @skip_space = false
    @readed_auto_clean_up = false
    @exception_on_syntax_error = true

    @prompt = nil
  end

  LEFTS = [TkLPAREN, TkLBRACK, TkLBRACE, TkfLPAREN, TkfLBRACK, TkfLBRACE]

  def expr_begin?
    @state == EXPR_BEG
  end

  def expr_mid?
    @state == EXPR_MID
  end

  def expr_end?
    @state == EXPR_END
  end

  def with_ltype(type, after = nil)
    @lt, old = type, @lt
    yield
    @lt = after || old
  end

  attr_accessor :skip_space
  attr_accessor :readed_auto_clean_up
  attr_accessor :exception_on_syntax_error

  attr_reader :seek
  attr_reader :char_no
  attr_reader :line_no
  attr_reader :indent

  # io functions
  def set_input(&block)
    @input = block
  end

  def get_readed
    if idx = @readed.reverse.index("\n")
      @base_char_no = idx
    else
      @base_char_no += @readed.size
    end

    readed = @readed.join("")
    @readed = []
    readed
  end

  def getc
    while @rests.empty?
      @rests.push nil unless buf_input
    end
    c = @rests.shift
    if @here_header
      @here_readed.push c
    else
      @readed.push c
    end
    @seek += 1
    if c == "\n"
      @line_no += 1
      @char_no = 0
    else
      @char_no += 1
    end
    c
  end

  def getc_until(regex)
    val = ""
    until (char = getc) =~ regex
      val << char
    end
    val << char
  end

  def gets
    l = ""
    while c = getc
      l.concat(c)
      break if c == "\n"
    end
    return nil if l == "" and c.nil?
    l
  end

  def getc_of_rests
    if @rests.empty?
      nil
    else
      getc
    end
  end

  def ungetc(c = nil)
    if @here_readed.empty?
      c2 = @readed.pop
    else
      c2 = @here_readed.pop
    end
    c = c2 unless c
    @rests.unshift c #c =
      @seek -= 1
    if c == "\n"
      @line_no -= 1
      if idx = @readed.reverse.index("\n")
        @char_no = @readed.size - idx
      else
        @char_no = @base_char_no + @readed.size
      end
    else
      @char_no -= 1
    end
  end

  def peek_equal?(str)
    chrs = str.split(//)
    until @rests.size >= chrs.size
      return false unless buf_input
    end
    @rests[0, chrs.size] == chrs
  end

  def peek_match?(regexp)
    while @rests.empty?
      return false unless buf_input
    end
    regexp =~ @rests.join("")
  end

  def peek(i = 0)
    while @rests.size <= i
      return nil unless buf_input
    end
    @rests[i]
  end

  def peek_forward(n)
    val = ""
    n.times {|i| val << peek(i) }
    val
  end

  def begin_expression(token = nil, *args)
    @lex_state = EXPR_BEG
    Token(token, *args) if token
  end

  def begin_expression!(token = nil, *args)
    token = begin_expression(token, *args)
    until @indent_stack.empty? || LEFTS.include?(@indent_stack.last)
      @indent_stack.pop
    end
    token
  end

  def end_expression(token = nil, *args)
    @lex_state = EXPR_END
    Token(token, *args) if token
  end

  def expect_argument(token = nil, *args)
    @lex_state = EXPR_ARG
    Token(token, *args) if token
  end

  def open_indent(token)
    @indent += 1
    @indent_stack.push token
    Token(token)
  end

  def open_indent!(token)
    begin_expression
    open_indent(token)
  end

  def buf_input
    prompt
    line = @input.call
    return nil unless line
    @rests.concat line.split(//)
    true
  end
  private :buf_input

  def set_prompt(p = nil, &block)
    p = block if block_given?
    if p.respond_to?(:call)
      @prompt = p
    else
      @prompt = Proc.new{print p}
    end
  end

  def state
    if @ltype
      :ltype
    elsif @continue
      :continue
    elsif @indent > 0
      :indent
    else
      :normal
    end
  end

  def prompt
    if @prompt
      @prompt.call(state, @ltype, @indent, @line_no)
    end
  end

  def initialize_input
    @ltype = nil
    @quoted = nil
    @indent = 0
    @indent_stack = []
    @lex_state = EXPR_BEG
    @space_seen = false
    @here_header = false

    @continue = false
    prompt

    @line = ""
    @exp_line_no = @line_no
  end

  def each_top_level_statement
    initialize_input
    catch(:TERM_INPUT) do
      loop do
        begin
          @continue = false
          prompt
          unless l = lex
            throw :TERM_INPUT if @line == ''
          else
            @line.concat l
            if @ltype or @continue or @indent > 0
              next
            end
          end
          if @line != "\n"
            yield @line, @exp_line_no
          end
          break unless l
          @line = ''
          @exp_line_no = @line_no

          @indent = 0
          @indent_stack = []
          prompt
        rescue TerminateLineInput
          initialize_input
          prompt
          get_readed
        end
      end
    end
  end

  def get_lex(string)
    set_input { "#{string}\0" }
    tokens = []
    until (tk = token).kind_of?(TkEND_OF_SCRIPT)
      tokens << tk
    end
    tokens
  end

  def lex
    until (((tk = token).kind_of?(TkNL) || tk.kind_of?(TkEND_OF_SCRIPT)) &&
             !@continue or
             tk.nil?)
    end
    line = get_readed
    if line == "" and tk.kind_of?(TkEND_OF_SCRIPT) || tk.nil?
      nil
    else
      line
    end
  end

  def token
    @prev_seek = @seek
    @prev_line_no = @line_no
    @prev_char_no = @char_no
    begin
      begin
        tk = @OP.match(self)
        @space_seen = tk.kind_of?(TkSPACE)
      rescue SyntaxError
        raise if @exception_on_syntax_error
        tk = TkError.new(@seek, @line_no, @char_no)
      end
    end while @skip_space and tk.kind_of?(TkSPACE)
    if @readed_auto_clean_up
      get_readed
    end
    tk
  end

  ENINDENT_CLAUSE = [
    "case", "class", "def", "do", "for", "if",
    "module", "unless", "until", "while", "begin" #, "when"
  ]
  DEINDENT_CLAUSE = ["end" #, "when"
  ]

  PERCENT_LTYPE = {
    "q" => "\'",
    "Q" => "\"",
    "x" => "\`",
    "r" => "/",
    "w" => "]",
    "W" => "]",
    "s" => ":"
  }

  PERCENT_PAREN = {
    "{" => "}",
    "[" => "]",
    "<" => ">",
    "(" => ")"
  }

  Ltype2Token = {
    "\'" => TkSTRING,
    "\"" => TkSTRING,
    "\`" => TkXSTRING,
    "/" => TkREGEXP,
    "]" => TkDSTRING,
    ":" => TkSYMBOL
  }
  DLtype2Token = {
    "\"" => TkDSTRING,
    "\`" => TkDXSTRING,
    "/" => TkDREGEXP,
  }

  def lex_init()
    @OP = IRB::SLex.new
    @OP.def_rules("\0", "\004", "\032") do
      Token(TkEND_OF_SCRIPT)
    end

    @OP.def_rules(" ", "\t", "\f", "\r", "\13") do
      @space_seen = true
      true while getc =~ /[ \t\f\r\13]/
      ungetc
      Token(TkSPACE)
    end

    @OP.def_rule("#") do
      identify_comment
    end

    begin_condition = proc { @prev_char_no == 0 && peek(0) =~ /\s/ }
    @OP.def_rule("=begin", begin_condition) do
      val = ""

      with_ltype("=") do
        getc_until(/\n/)
        until peek_forward(5) =~ /=end\s/
          val << getc_until(/\n/)
        end
        gets
      end

      Token(TkRD_COMMENT, val)
    end

    @OP.def_rule("\n") do
      print "\\n\n" if RubyLex.debug?

      case @lex_state
      when EXPR_BEG, EXPR_FNAME, EXPR_DOT
        @complete = false
      else
        @complete = true
        begin_expression!
      end
      @here_header = false
      @here_readed = []
      Token(TkNL)
    end

    @OP.def_rules(*%w|* ** = == === =~ <=> < <= > >=|) do |op, io|
      case @lex_state
      when EXPR_FNAME, EXPR_DOT
        expect_argument(op)
      else
        begin_expression(op)
      end
    end

    @OP.def_rules("!", "!=", "!~") do |op|
      begin_expression(op)
    end

    @OP.def_rules("<<") do |op, io|
      tk = nil
      if @lex_state != EXPR_END && @lex_state != EXPR_CLASS &&
          (@lex_state != EXPR_ARG || @space_seen)
        c = peek(0)
        if /\S/ =~ c && (/["'`]/ =~ c || /[\w_]/ =~ c || c == "-")
          tk = identify_here_document
        end
      end
      unless tk
        tk = Token(op)
        case @lex_state
        when EXPR_FNAME, EXPR_DOT
          expect_argument
        else
          begin_expression
        end
      end
      tk
    end

    @OP.def_rules("'", '"') do |op|
      identify_string(op)
    end

    @OP.def_rules("`") do |op|
      if @lex_state == EXPR_FNAME
        end_expression(op)
      else
        identify_string(op)
      end
    end

    @OP.def_rules('?') do
      if @lex_state == EXPR_END
        begin_expression(TkQUESTION)
      else
        ch = getc
        if @lex_state == EXPR_ARG && ch =~ /\s/
          ungetc
          begin_expression(TkQUESTION)
        else
          read_escape if (ch == '\\')
          end_expression(TkINTEGER)
        end
      end
    end

    @OP.def_rules("&", "&&", "|", "||") do |op|
      begin_expression(op)
    end

    @OP.def_rules(*%w{+= -= *= **= &= |= ^= <<= >>= ||= &&=}) do
      op =~ /^(.*)=$/
      begin_expression(TkOPASGN, $1)
    end

    @OP.def_rule("+@", proc { @lex_state == EXPR_FNAME }) do |op|
      expect_argument(op)
    end

    @OP.def_rule("-@", proc { @lex_state == EXPR_FNAME }) do |op|
      expect_argument(op)
    end

    @OP.def_rules("+", "-") do |op|
      catch(:RET) do
        if @lex_state == EXPR_ARG
          if @space_seen and peek(0) =~ /[0-9]/
            throw :RET, identify_number(op)
          else
            begin_expression(op)
          end
        elsif @lex_state != EXPR_END and peek(0) =~ /[0-9]/
          throw :RET, identify_number(op)
        else
          begin_expression(op)
        end
      end
    end

    @OP.def_rule(".") do
      begin_expression
      if peek(0) =~ /[0-9]/
        ungetc
        identify_number
      else
        # for "obj.if" etc.
        @lex_state = EXPR_DOT
        Token(TkDOT)
      end
    end

    @OP.def_rules("..", "...") do |op|
      begin_expression(op)
    end

    lex_int2
  end

  def lex_int2
    @OP.def_rules("]", "}", ")") do |op|
      @indent -= 1
      @indent_stack.pop
      end_expression(op)
    end

    @OP.def_rule(":") do
      if @lex_state == EXPR_END || peek(0) =~ /\s/
        begin_expression(TkCOLON)
      else
        @lex_state = EXPR_FNAME
        Token(TkSYMBEG)
      end
    end

    @OP.def_rule("::") do
      if @lex_state == EXPR_BEG or @lex_state == EXPR_ARG && @space_seen
        begin_expression(TkCOLON3)
      else
        @lex_state = EXPR_DOT
        Token(TkCOLON2)
      end
    end

    @OP.def_rule("/") do |op|
      if @lex_state == EXPR_BEG || @lex_state == EXPR_MID
        identify_string(op)
      elsif peek(0) == '='
        getc
        begin_expression(TkOPASGN, "/")
      elsif @lex_state == EXPR_ARG and @space_seen and peek(0) !~ /\s/
        identify_string(op)
      else
        begin_expression("/")
      end
    end

    @OP.def_rules("^") do
      begin_expression("^")
    end

    @OP.def_rules(",") do |op|
      begin_expression(op)
    end

    @OP.def_rules(";") do |op|
      begin_expression!(op)
    end

    @OP.def_rule("~") do
      begin_expression("~")
    end

    @OP.def_rule("~@", proc{|op, io| @lex_state == EXPR_FNAME}) do |op, io|
      begin_expression("~")
    end

    @OP.def_rule("(") do
      if @lex_state == EXPR_BEG || @lex_state == EXPR_MID
        open_indent!(TkfLPAREN)
      else
        open_indent!(TkLPAREN)
      end
    end

    @OP.def_rule("[]", proc{|op, io| @lex_state == EXPR_FNAME}) do
      expect_argument("[]")
    end

    @OP.def_rule("[]=", proc{|op, io| @lex_state == EXPR_FNAME}) do
      expect_argument("[]=")
    end

    @OP.def_rule("[") do
      if @lex_state == EXPR_FNAME
        open_indent(TkfLBRACK)
      else
        if @lex_state == EXPR_BEG || @lex_state == EXPR_MID
          open_indent!(TkLBRACK)
        elsif @lex_state == EXPR_ARG && @space_seen
          open_indent!(TkLBRACK)
        else
          open_indent!(TkfLBRACK)
        end
      end
    end

    @OP.def_rule("{") do
      if @lex_state == EXPR_END || @lex_state == EXPR_ARG
        open_indent(TkfLBRACE)
      else
        open_indent!(TkLBRACE)
      end
    end

    @OP.def_rule('\\') do
      if getc == "\n"
        @space_seen = true
        @continue = true
        Token(TkSPACE)
      else
        ungetc
        Token("\\")
      end
    end

    @OP.def_rule('%') do
      if @lex_state == EXPR_BEG || @lex_state == EXPR_MID
        identify_quotation
      elsif peek(0) == '='
        getc
        Token(TkOPASGN, :%)
      elsif @lex_state == EXPR_ARG and @space_seen and peek(0) !~ /\s/
        identify_quotation
      else
        begin_expression("%")
      end
    end

    @OP.def_rule('$') do
      identify_gvar
    end

    @OP.def_rule('@') do
      if peek(0) =~ /[\w_@]/
        ungetc
        identify_identifier
      else
        Token("@")
      end
    end

    @OP.def_rule("") do
      if peek(0) =~ /[0-9]/
        identify_number
      elsif peek(0) =~ /[\w_]/
        identify_identifier
      end
    end
  end

  def identify_gvar
    end_expression

    case ch = getc
    when /[~_*$?!@\/\\;,=:<>".]/   #"
      Token(TkGVAR, "$" + ch)
    when "-"
      Token(TkGVAR, "$-" + getc)
    when "&", "`", "'", "+"
      Token(TkBACK_REF, "$"+ch)
    when /[1-9]/
      while getc =~ /[0-9]/; end
      ungetc
      Token(TkNTH_REF)
    when /\w/
      ungetc
      ungetc
      identify_identifier
    else
      ungetc
      Token("$")
    end
  end

  def identify_identifier
    token = ""
    if peek(0) =~ /[$@]/
      token.concat(c = getc)
      if c == "@" and peek(0) == "@"
        token.concat getc
      end
    end

    while (ch = getc) =~ /\w|_/
      print ":", ch, ":" if RubyLex.debug?
      token.concat ch
    end
    ungetc

    if (ch == "!" || ch == "?") && token[0,1] =~ /\w/ && peek(0) != "="
      token.concat getc
    end

    # almost fix token

    case token
    when /^\$/
      return Token(TkGVAR, token)
    when /^\@\@/
      return end_expression(TkCVAR, token)
    when /^\@/
      return end_expression(TkIVAR, token)
    end

    if @lex_state != EXPR_DOT
      print token, "\n" if RubyLex.debug?

      token_c, *trans = TkReading2Token[token]
      if token_c
        # reserved word?

        if (@lex_state != EXPR_BEG &&
            @lex_state != EXPR_FNAME &&
            trans[1])
          # modifiers
          token_c = TkSymbol2Token[trans[1]]
          @lex_state = trans[0]
        else
          if @lex_state != EXPR_FNAME
            if ENINDENT_CLAUSE.include?(token)
              # check for ``class = val'' etc.
              valid = true
              case token
              when "class"
                valid = false unless peek_match?(/^\s*(<<|\w|::)/)
              when "def"
                valid = false if peek_match?(/^\s*(([+-\/*&\|^]|<<|>>|\|\||\&\&)=|\&\&|\|\|)/)
              when "do"
                valid = false if peek_match?(/^\s*([+-\/*]?=|\*|<|>|\&)/)
              when *ENINDENT_CLAUSE
                valid = false if peek_match?(/^\s*([+-\/*]?=|\*|<|>|\&|\|)/)
              else
                # no nothing
              end
              if valid
                if token == "do"
                  if ![TkFOR, TkWHILE, TkUNTIL].include?(@indent_stack.last)
                    @indent += 1
                    @indent_stack.push token_c
                  end
                else
                  @indent += 1
                  @indent_stack.push token_c
                end
              end

            elsif DEINDENT_CLAUSE.include?(token)
              @indent -= 1
              @indent_stack.pop
            end
            @lex_state = trans[0]
          else
            @lex_state = EXPR_END
          end
        end
        return Token(token_c, token)
      end
    end

    if @lex_state == EXPR_FNAME
      @lex_state = EXPR_END
      if peek(0) == '='
        token.concat getc
      end
    elsif @lex_state == EXPR_BEG || @lex_state == EXPR_DOT
      expect_argument
    else
      @lex_state = EXPR_END
    end

    if token[0, 1] =~ /[A-Z]/
      return Token(TkCONSTANT, token)
    elsif token[token.size - 1, 1] =~ /[!?]/
      return Token(TkFID, token)
    else
      return Token(TkIDENTIFIER, token)
    end
  end

  def identify_here_document
    ch = getc
    if ch == "-"
      ch = getc
      indent = true
    end
    if /['"`]/ =~ ch
      lt = ch
      quoted = ""
      while (c = getc) && c != lt
        quoted.concat c
      end
    else
      lt = '"'
      quoted = ch.dup
      while (c = getc) && c =~ /\w/
        quoted.concat c
      end
      ungetc
    end

    ltback, @ltype = @ltype, lt
    reserve = []
    while ch = getc
      reserve.push ch
      if ch == "\\"
        reserve.push ch = getc
      elsif ch == "\n"
        break
      end
    end

    @here_header = false
    while l = gets
      l = l.sub(/(:?\r)?\n\z/, '')
      if (indent ? l.strip : l) == quoted
        break
      end
    end

    @here_header = true
    @here_readed.concat reserve
    while ch = reserve.pop
      ungetc ch
    end

    @ltype = ltback
    end_expression(Ltype2Token[lt])
  end

  def identify_quotation
    ch = getc
    if lt = PERCENT_LTYPE[ch]
      ch = getc
    elsif ch =~ /\W/
      lt = "\""
    else
      RubyLex.fail SyntaxError, "unknown type of %string"
    end
    @quoted = ch unless @quoted = PERCENT_PAREN[ch]
    identify_string(lt, @quoted)
  end

  def identify_number(op = "")
    end_expression

    value = op

    if peek(0) == "0" && peek(1) !~ /[.eE]/
      value << getc
      case next_peek = peek(0)
      when /[xX]/
        ch = getc
        value << ch
        match = /[0-9a-fA-F_]/
      when /[bB]/
        ch = getc
        value << ch
        match = /[01_]/
      when /[oO]/
        ch = getc
        value << ch
        match = /[0-7_]/
      when /[dD]/
        ch = getc
        value << ch
        match = /[0-9_]/
      when /[0-7]/
        match = /[0-7_]/
      when /[89]/
        RubyLex.fail SyntaxError, "Illegal octal digit"
      else
        return Token(TkINTEGER, value)
      end

      len0 = true
      non_digit = false
      while ch = getc
        value << ch
        if match =~ ch
          if ch == "_"
            if non_digit
              RubyLex.fail SyntaxError, "trailing `#{ch}' in number"
            else
              non_digit = ch
            end
          else
            non_digit = false
            len0 = false
          end
        else
          ungetc
          if len0
            RubyLex.fail SyntaxError, "numeric literal without digits"
          end
          if non_digit
            RubyLex.fail SyntaxError, "trailing `#{non_digit}' in number"
          end
          break
        end
      end
      return Token(TkINTEGER, value)
    end

    type = TkINTEGER
    allow_point = true
    allow_e = true
    non_digit = false
    while ch = getc
      value << ch
      case ch
      when /[0-9]/
        non_digit = false
      when "_"
        non_digit = ch
      when allow_point && "."
        if non_digit
          RubyLex.fail SyntaxError, "trailing `#{non_digit}' in number"
        end
        type = TkFLOAT
        if peek(0) !~ /[0-9]/
          type = TkINTEGER
          ungetc
          break
        end
        allow_point = false
      when allow_e && "e", allow_e && "E"
        if non_digit
          RubyLex.fail SyntaxError, "trailing `#{non_digit}' in number"
        end
        type = TkFLOAT
        if peek(0) =~ /[+-]/
          value << getc
        end
        allow_e = false
        allow_point = false
        non_digit = ch
      else
        if non_digit
          RubyLex.fail SyntaxError, "trailing `#{non_digit}' in number"
        end
        ungetc
        value.chop!
        break
      end
    end
    Token(type, value)
  end

  def identify_string(ltype, quoted = ltype)
    @ltype = ltype
    @quoted = quoted
    subtype = nil
    begin
      nest = 0
      while ch = getc
        if @quoted == ch and nest == 0
          break
        elsif @ltype != "'" && @ltype != "]" && @ltype != ":" and ch == "#"
          subtype = true
        elsif ch == '\\' #'
          read_escape
        end
        if PERCENT_PAREN.values.include?(@quoted)
          if PERCENT_PAREN[ch] == @quoted
            nest += 1
          elsif ch == @quoted
            nest -= 1
          end
        end
      end
      if @ltype == "/"
        if peek(0) =~ /i|m|x|o|e|s|u|n/
          getc
        end
      end
      if subtype
        Token(DLtype2Token[ltype])
      else
        Token(Ltype2Token[ltype])
      end
    ensure
      @ltype = nil
      @quoted = nil
      end_expression
    end
  end

  def identify_comment
    @ltype = "#"

    val = ""

    while ch = getc
      if ch == "\n"
        @ltype = nil
        ungetc
        break
      end
      val << ch
    end
    return Token(TkCOMMENT, val)
  end

  def read_escape
    case ch = getc
    when "\n", "\r", "\f"
    when "\\", "n", "t", "r", "f", "v", "a", "e", "b", "s" #"
    when /[0-7]/
      ungetc ch
      3.times do
        case ch = getc
        when /[0-7]/
        when nil
          break
        else
          ungetc
          break
        end
      end

    when "x"
      2.times do
        case ch = getc
        when /[0-9a-fA-F]/
        when nil
          break
        else
          ungetc
          break
        end
      end

    when "M"
      if (ch = getc) != '-'
        ungetc
      else
        if (ch = getc) == "\\" #"
          read_escape
        end
      end

    when "C", "c" #, "^"
      if ch == "C" and (ch = getc) != "-"
        ungetc
      elsif (ch = getc) == "\\" #"
        read_escape
      end
    else
      # other characters
    end
  end
end
