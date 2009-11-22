#
#   loader.rb -
#   	$Release Version: 0.9.5$
#   	$Revision: 11708 $
#   	$Date: 2007-02-13 08:01:19 +0900 (Tue, 13 Feb 2007) $
#   	by Keiju ISHITSUKA(keiju@ruby-lang.org)
#
# --
#
#
#


module IRB
  class LoadAbort < Exception;end

  class Irb
    def with_name(path, name, &block)
      @context.suspend_name(path, name, &block)
    end

    def with_workspace(workspace, &block)
      @context.with_workspace(workspace, &block)
    end

    def with_input_method(input_method, &block)
      @context.with_input_method(input_method, &block)
    end

    def with_context(context, &block)
      @context.with_context(context, &block)
    end
  end

  class Context
    def with_name(path, name)
      self.irb_path, old_path = path, irb_path if path
      self.irb_name, old_name = name, irb_name if name

      begin
        yield old_path, old_name
      ensure
        self.irb_path = old_path if path
        self.irb_name = old_name if name
      end
    end

    def with_workspace(workspace)
      self.workspace, old_workspace = workspace, workspace

      begin
        yield old_workspace
      ensure
        self.workspace = old_workspace
      end
    end

    def with_input_method(input_method)
      @io, old_io = input_method, @io

      begin
        yield old_io
      ensure
        @io = old_io
      end
    end

    def with_context(context)
      @context, old_context = context, @context
      begin
        yield old_context
      ensure
        @context = old_context
      end
    end
  end

  module IrbLoader
    @RCS_ID='-$Id: loader.rb 11708 2007-02-12 23:01:19Z shyouhei $-'

    alias ruby_load load
    alias ruby_require require

    def irb_load(fn, priv = nil)
      path = search_file_from_ruby_path(fn)
      raise LoadError, "No such file to load -- #{fn}" unless path

      load_file(path, priv)
    end

    def search_file_from_ruby_path(fn)
      if /^#{Regexp.quote(File::Separator)}/ =~ fn
	return fn if File.exist?(fn)
	return nil
      end

      for path in $:
	if File.exist?(f = File.join(path, fn))
	  return f
	end
      end
      return nil
    end

    def source_file(path)
      irb.with_name(path, File.basename(path)) do
        irb.with_input_method(FileInputMethod.new(path)) do |io|
          irb.with_signal_status(:IN_LOAD) do
            if io.kind_of?(FileInputMethod)
              irb.eval_input
            else
              begin
                irb.eval_input
                    rescue LoadAbort
                print "load abort!!\n"
              end
            end
          end
        end
      end
    end

    def load_file(path, priv = nil)
      irb.with_path(path, File.basename(path)) do

      if priv
        ws = WorkSpace.new(Module.new)
      else
        ws = WorkSpace.new
      end
      irb.with_workspace(ws) do
        irb.with_input_method(FileInputMethod.new(path)) do |io|
          irb.with_signal_status(:IN_LOAD) do
            if old_io.kind_of?(FileInputMethod)
              irb.eval_input
                  else
              begin
                irb.eval_input
              rescue LoadAbort
                print "load abort!!\n"
              end
            end
          end
        end
      end
      end
    end

    def old
      back_io = @io
      back_path = @irb_path
      back_name = @irb_name
      back_scanner = @irb.scanner
      begin
 	@io = FileInputMethod.new(path)
 	@irb_name = File.basename(path)
	@irb_path = path
	@irb.with_signal_status(:IN_LOAD) do
	  if back_io.kind_of?(FileInputMethod)
	    @irb.eval_input
	  else
	    begin
	      @irb.eval_input
	    rescue LoadAbort
	      print "load abort!!\n"
	    end
	  end
	end
      ensure
 	@io = back_io
 	@irb_name = back_name
 	@irb_path = back_path
	@irb.scanner = back_scanner
      end
    end
  end
end

