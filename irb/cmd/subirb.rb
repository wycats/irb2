#!/usr/local/bin/ruby
#
#   multi.rb -
#       $Release Version: 0.9.5$
#       $Revision: 11708 $
#       $Date: 2007-02-13 08:01:19 +0900 (Tue, 13 Feb 2007) $
#       by Keiju ISHITSUKA(keiju@ruby-lang.org)
#
# --
#
#
#

require "irb/cmd/nop.rb"
require "irb/ext/multi-irb"

module IRB
  module ExtendCommand
    class IrbCommand<Nop
      def execute(*obj)
        IRB.irb(nil, *obj)
      end
    end

    class Jobs < Nop
      def execute
        IRB.p IRB.job_manager
        IRB::CommandResult
      end
    end

    class Foreground < Nop
      def execute(key = nil)
        unless key
          IRB.puts "[red]You need to specify a job to foreground[/]"
          IRB.puts
          IRB.job_manager.display_jobs
          return IRB::CommandResult
        end

        IRB.job_manager.switch(key)
        return IRB::CommandResult
      end
    end

    class Kill < Nop
      def execute(*keys)
        IRB.job_manager.kill(*keys)
      end
    end
  end
end
