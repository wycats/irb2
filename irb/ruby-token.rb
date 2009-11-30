#
#   irb/ruby-token.rb - ruby tokens
#       $Release Version: 0.9.5$
#       $Revision: 11708 $
#       $Date: 2007-02-13 08:01:19 +0900 (Tue, 13 Feb 2007) $
#       by Keiju ISHITSUKA(keiju@ruby-lang.org)
#
# --
#
#
#
module RubyToken
  EXPR_BEG = :EXPR_BEG
  EXPR_MID = :EXPR_MID
  EXPR_END = :EXPR_END
  EXPR_ARG = :EXPR_ARG
  EXPR_FNAME = :EXPR_FNAME
  EXPR_DOT = :EXPR_DOT
  EXPR_CLASS = :EXPR_CLASS

  class Token
    def initialize(seek, line_no, char_no, value = nil)
      @seek = seek
      @line_no = line_no
      @char_no = char_no
    end

    def to_s
      vars = instance_variables - [:@seek, :@line_no, :@char_no, "@seek", "@line_no", "@char_no"]
      details = vars.map {|v| "#{v.to_s.sub(/^@/, '')}:#{instance_variable_get(v)}" }.join(" ")
      "#{self.class.name} #{line_no}:#{char_no} #{details}"
    end
    alias inspect to_s

    attr_reader :seek, :line_no, :char_no
  end

  class TkContents < Token
    def initialize(seek, line_no, char_no, contents)
      super(seek, line_no, char_no)
      @contents = contents
    end
    attr_reader :contents
  end

  class TkNode < Token
  end

  class TkId < Token
    def initialize(seek, line_no, char_no, name)
      super(seek, line_no, char_no)
      @name = name
    end
    attr_reader :name
  end

  class TkVal < Token
    def initialize(seek, line_no, char_no, value = nil)
      super(seek, line_no, char_no)
      @value = value
    end
    attr :value
  end

  class TkOp < Token
    attr_accessor :name
  end

  class TkOPASGN < TkOp
    def initialize(seek, line_no, char_no, op)
      super(seek, line_no, char_no)
      op = TkReading2Token[op][0] unless op.kind_of?(Symbol)
      @op = op
    end
    attr_reader :op
  end

  class TkUnknownChar < Token
    def initialize(seek, line_no, char_no, id)
      super(seek, line_no, char_no)
      @name = id
    end
    attr :name
  end

  class TkError < Token
  end

  def Token(token, value = nil)
    case token
    when String
      if (tk = TkReading2Token[token]).nil?
        IRB.fail TkReading2TokenNoKey, token
      end
      tk = Token(tk[0], value)
      if tk.kind_of?(TkOp)
        tk.name = token
      end
      return tk
    when Symbol
      if (tk = TkSymbol2Token[token]).nil?
        IRB.fail TkSymbol2TokenNoKey, token
      end
      return Token(tk[0], value)
    else
      token.new(@prev_seek, @prev_line_no, @prev_char_no, value)
    end
  end

  TokenDefinitions = [
    [:TkCLASS,      TkId,  "class",  EXPR_CLASS],
    [:TkMODULE,     TkId,  "module", EXPR_BEG],
    [:TkDEF,        TkId,  "def",    EXPR_FNAME],
    [:TkUNDEF,      TkId,  "undef",  EXPR_FNAME],
    [:TkBEGIN,      TkId,  "begin",  EXPR_BEG],
    [:TkRESCUE,     TkId,  "rescue", EXPR_MID],
    [:TkENSURE,     TkId,  "ensure", EXPR_BEG],
    [:TkEND,        TkId,  "end",    EXPR_END],
    [:TkIF,         TkId,  "if",     EXPR_BEG, :TkIF_MOD],
    [:TkUNLESS,     TkId,  "unless", EXPR_BEG, :TkUNLESS_MOD],
    [:TkTHEN,       TkId,  "then",   EXPR_BEG],
    [:TkELSIF,      TkId,  "elsif",  EXPR_BEG],
    [:TkELSE,       TkId,  "else",   EXPR_BEG],
    [:TkCASE,       TkId,  "case",   EXPR_BEG],
    [:TkWHEN,       TkId,  "when",   EXPR_BEG],
    [:TkWHILE,      TkId,  "while",  EXPR_BEG, :TkWHILE_MOD],
    [:TkUNTIL,      TkId,  "until",  EXPR_BEG, :TkUNTIL_MOD],
    [:TkFOR,        TkId,  "for",    EXPR_BEG],
    [:TkBREAK,      TkId,  "break",  EXPR_END],
    [:TkNEXT,       TkId,  "next",   EXPR_END],
    [:TkREDO,       TkId,  "redo",   EXPR_END],
    [:TkRETRY,      TkId,  "retry",  EXPR_END],
    [:TkIN,         TkId,  "in",     EXPR_BEG],
    [:TkDO,         TkId,  "do",     EXPR_BEG],
    [:TkRETURN,     TkId,  "return", EXPR_MID],
    [:TkYIELD,      TkId,  "yield",  EXPR_END],
    [:TkSUPER,      TkId,  "super",  EXPR_END],
    [:TkSELF,       TkId,  "self",   EXPR_END],
    [:TkNIL,        TkId,  "nil",    EXPR_END],
    [:TkTRUE,       TkId,  "true",   EXPR_END],
    [:TkFALSE,      TkId,  "false",  EXPR_END],
    [:TkAND,        TkId,  "and",    EXPR_BEG],
    [:TkOR,         TkId,  "or",     EXPR_BEG],
    [:TkNOT,        TkId,  "not",    EXPR_BEG],
    [:TkIF_MOD,     TkId],
    [:TkUNLESS_MOD, TkId],
    [:TkWHILE_MOD,  TkId],
    [:TkUNTIL_MOD,  TkId],
    [:TkALIAS,      TkId,  "alias",    EXPR_FNAME],
    [:TkDEFINED,    TkId,  "defined?", EXPR_END],
    [:TklBEGIN,     TkId,  "BEGIN",    EXPR_END],
    [:TklEND,       TkId,  "END",      EXPR_END],
    [:Tk__LINE__,   TkId,  "__LINE__", EXPR_END],
    [:Tk__FILE__,   TkId,  "__FILE__", EXPR_END],

    [:TkIDENTIFIER, TkId],
    [:TkFID,        TkId],
    [:TkGVAR,       TkId],
    [:TkCVAR,       TkId],
    [:TkIVAR,       TkId],
    [:TkCONSTANT,   TkId],

    [:TkINTEGER,    TkVal],
    [:TkFLOAT,      TkVal],
    [:TkSTRING,     TkVal],
    [:TkXSTRING,    TkVal],
    [:TkREGEXP,     TkVal],
    [:TkSYMBOL,     TkVal],

    [:TkDSTRING,    TkNode],
    [:TkDXSTRING,   TkNode],
    [:TkDREGEXP,    TkNode],
    [:TkNTH_REF,    TkNode],
    [:TkBACK_REF,   TkNode],

    [:TkUPLUS,      TkOp,   "+@"],
    [:TkUMINUS,     TkOp,   "-@"],
    [:TkPOW,        TkOp,   "**"],
    [:TkCMP,        TkOp,   "<=>"],
    [:TkEQ,         TkOp,   "=="],
    [:TkEQQ,        TkOp,   "==="],
    [:TkNEQ,        TkOp,   "!="],
    [:TkGEQ,        TkOp,   ">="],
    [:TkLEQ,        TkOp,   "<="],
    [:TkANDOP,      TkOp,   "&&"],
    [:TkOROP,       TkOp,   "||"],
    [:TkMATCH,      TkOp,   "=~"],
    [:TkNMATCH,     TkOp,   "!~"],
    [:TkDOT2,       TkOp,   ".."],
    [:TkDOT3,       TkOp,   "..."],
    [:TkAREF,       TkOp,   "[]"],
    [:TkASET,       TkOp,   "[]="],
    [:TkLSHFT,      TkOp,   "<<"],
    [:TkRSHFT,      TkOp,   ">>"],
    [:TkCOLON2,     TkOp],
    [:TkCOLON3,     TkOp],
    [:TkASSOC,      TkOp,   "=>"],
    [:TkQUESTION,   TkOp,   "?"],        #?
    [:TkCOLON,      TkOp,   ":"],        #:

    [:TkfLPAREN],         # func( #
    [:TkfLBRACK],         # func[ #
    [:TkfLBRACE],         # func{ #
    [:TkSTAR],            # *arg
    [:TkAMPER],           # &arg #
    [:TkSYMBEG],          # :SYMBOL

    [:TkGT,         TkOp,   ">"],
    [:TkLT,         TkOp,   "<"],
    [:TkPLUS,       TkOp,   "+"],
    [:TkMINUS,      TkOp,   "-"],
    [:TkMULT,       TkOp,   "*"],
    [:TkDIV,        TkOp,   "/"],
    [:TkMOD,        TkOp,   "%"],
    [:TkBITOR,      TkOp,   "|"],
    [:TkBITXOR,     TkOp,   "^"],
    [:TkBITAND,     TkOp,   "&"],
    [:TkBITNOT,     TkOp,   "~"],
    [:TkNOTOP,      TkOp,   "!"],

    [:TkBACKQUOTE,  TkOp,   "`"],

    [:TkASSIGN,     Token,  "="],
    [:TkDOT,        Token,  "."],
    [:TkLPAREN,     Token,  "("],  #(exp)
    [:TkLBRACK,     Token,  "["],  #[arry]
    [:TkLBRACE,     Token,  "{"],  #{hash}
    [:TkRPAREN,     Token,  ")"],
    [:TkRBRACK,     Token,  "]"],
    [:TkRBRACE,     Token,  "}"],
    [:TkCOMMA,      Token,  ","],
    [:TkSEMICOLON,  Token,  ";"],

    [:TkCOMMENT,    TkContents],
    [:TkRD_COMMENT],
    [:TkSPACE],
    [:TkNL],
    [:TkEND_OF_SCRIPT],

    [:TkBACKSLASH,  TkUnknownChar,  "\\"],
    [:TkAT,         TkUnknownChar,  "@"],
    [:TkDOLLAR,     TkUnknownChar,  "$"],
  ]

  # {reading => token_class}
  # {reading => [token_class, *opt]}
  TkReading2Token = {}
  TkSymbol2Token = {}

  def self.def_token(token_n, super_token = Token, reading = nil, *opts)
    token_c = const_set(token_n, Class.new(super_token))
    TkReading2Token[reading] = [token_c].concat(opts) if reading
    TkSymbol2Token[token_n] = token_c
  end

  TokenDefinitions.each do |defs|
    def_token(*defs)
  end
end
