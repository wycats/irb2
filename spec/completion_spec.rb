require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'irb/completion'

describe "IRB::InputCompletor" do
  before(:all) do
    ARGV.replace ['-f']
    IRB.setup $0
    IRB.main_context = IRB::Irb.new.context
    ARGV.replace []
  end

  def tab(input)
    Readline.completion_proc.call(input)
  end

  # describe block causes e2mmap to reload?
  # describe "completes instance methods of an anonymous" do
    it "string" do
      tab(%q{'man'.unp}).should == [%q{'man'.unpack}]
      tab(%q{"man".unp}).should == [%q{"man".unpack}]
    end
  
    it "regular expression" do
      tab('/dude/.ma').should == ['/dude/.match']
    end
  
    it "array" do
      tab('[1,2].inse').should == ['[1,2].insert']
    end
  
    it "hash" do
      tab('{:a=>1}.each_k').should == ['{:a=>1}.each_key']
    end
  
    it "symbol" do
      tab(':dude.id2').should == [':dude.id2name']
    end
  
    it "proc" do
      tab('lambda {|e| }.ca').should == ['lambda {|e| }.call']
    end
  
    it "numeric" do
      tab('3.fl').should == ['3.floor']
      tab('-3.fl').should == ['-3.floor']
      tab('3.0.fl').should == ['3.0.floor']
      tab('3e4.fl').should == ['3e4.floor']
    end
  
    it "hex numeric" do
      tab('0xfff.fl').should == ['0xfff.floor']
      tab('-0xfff.fl').should == ['-0xfff.floor']
    end
  # end

  it "completes absolute constants" do
    tab('::Arr').should == ['::Array']
  end

  it "completes module constants" do
    tab('Object::TOP').should == ['Object::TOPLEVEL_BINDING']
  end

  # it "completes symbols" do
  #   tab(':mai').should == [':main']
  # end

  it "completes global variables" do
    tab('$SA').should == ['$SAFE']
  end

  it "completes module methods using colons" do
    tab('Date::par').should == ['Date::parse']
  end

  it 'completes module methods' do
    tab('Date.par').should == ['Date.parse']
  end

  it 'completes nested module methods' do
    tab('Object::Date.par').should == ['Object::Date.parse']
  end

  it "completes local private methods" do
    tab('calle').should == ['caller']
  end

  it "completes local variables" do
    eval('dude = "test"', IRB.current_context.workspace.binding)
    tab('dud').should == ['dude']
  end

  it "completes reserved words" do
    tab('wh').should == %w{when while}
  end
end