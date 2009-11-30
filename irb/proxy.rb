# if !defined?(BasicObject)
  class BlankSlate < Object
    instance_methods.each do |name|
      undef_method name unless name.to_s =~ /__id__|object_id|__send__|instance_eval/
    end
  end
# end

module IRB
  class Proxy < BlankSlate
    def initialize(object)
      @object = object
      ExtendCommandBundle.extend_object(self)
    end

    def exit
      throw(:irb_exit)
    end

    def inspect
      $DEBUG ? "proxy for #{@object}" : @object.inspect
    end

    def extend(*args)
    end

    def method_missing(meth, *args, &block)
      if @object.public_methods.any? {|m| m.to_s == meth.to_s }
        @object.__send__(meth, *args, &block)
      else
        @object.__send__(:method_missing, meth, *args, &block)
      end
    end
  end
end