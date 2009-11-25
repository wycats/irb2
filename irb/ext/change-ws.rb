#
#   irb/ext/cb.rb -
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
  class Context

    def home_workspace
      @home_workspace ||= @workspace
    end

    def change_workspace(_main = nil)
      unless _main
        @workspace = home_workspace
        return main
      end

      @workspace = WorkSpace.new(_main)
      @workspace.main.extend ExtendCommandBundle
    end
  end
end

