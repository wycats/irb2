#
#   output-method.rb - optput methods used by irb 
#       $Release Version: 0.9.5$
#       $Revision: 11708 $
#       $Date: 2007-02-13 08:01:19 +0900 (Tue, 13 Feb 2007) $
#       by Keiju ISHITSUKA(keiju@ruby-lang.org)
#
# --
#
#   
#

require "e2mmap"

module IRB
  # OutputMethod
  #   StdioOutputMethod

  class OutputMethod
    @RCS_ID='-$Id: output-method.rb 11708 2007-02-12 23:01:19Z shyouhei $-'

    def self.colorizer
      @@colorizer
    end

    def self.colorizer=(colorizer)
      @@colorizer = colorizer
    end

    def print(*opts)
      IRB.fail NotImplementError, "print"
    end

    def printn(*opts)
      print opts.join(" "), "\n"
    end

    # extend printf
    def printf(format, *opts)
      if /(%*)%I/ =~ format
        format, opts = parse_printf_format(format, opts)
      end
      print sprintf(format, *opts)
    end

    def parse_printf_format(format, opts)
      return format, opts if $1.size % 2 == 1
    end

    def puts(*objs)
      for obj in objs
        print(*obj)
        print "\n"
      end
    end

    def pp(*objs)
      puts(*objs.collect{|obj| obj.inspect})
    end

    def ppx(prefix, *objs)
      puts(*objs.collect{|obj| prefix+obj.inspect})
    end

  end

  class StdioOutputMethod<OutputMethod
    def print(*opts)
      opts = opts.map {|o| @@colorizer.new(o).to_s }
      STDOUT.print(*opts)
    end
  end
end
