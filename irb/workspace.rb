#
#   irb/workspace-binding.rb -
#       $Release Version: 0.9.5$
#       $Revision: 11708 $
#       $Date: 2007-02-13 08:01:19 +0900 (Tue, 13 Feb 2007) $
#       by Keiju ISHITSUKA(keiju@ruby-lang.org)
#
# --
#
#
#
module IRB
  class WorkSpace
    # create new workspace. If a main is specified, inherit its 'self'. Inherit
    # the local variables from the binding.
    def initialize(main = nil, binding = TOPLEVEL_BINDING)
      @binding = binding

      if !main
        @main = eval("self", @binding)
      else
        $__irb_main__ = @main = IRB::Proxy.new(main)

        # Get a binding that has the locals of the original binding, but the
        # self bound to the new main instance
        evaluate = "$__irb_main__.instance_eval('binding', '(irb_internal)')"
        @binding = eval(evaluate, @binding)
      end
      eval("_ = nil", @binding)
    end

    attr_reader :binding, :main

    def evaluate(context, statements, file = __FILE__, line = __LINE__)
      value = eval(statements, @binding, file, line)

      if $SAFE > 0
        begin
          IRB.puts "irb only works in $SAFE == 0"
        ensure
          raise SystemExit
        end
      end

      value
    end

    # error message manipulator
    def filter_backtrace(bt)
      bt =~ %r{^\(irb_internal\)} ? nil : bt
    end
  end
end
