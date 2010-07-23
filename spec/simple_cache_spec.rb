require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

# General behavior for SimpleCache can be described here

describe SimpleCache do

  before(:each) do
    class TestClass
      @@cache_refresh_interval = 1.minute
      include SimpleCache
      attr_accessor :test_val
      def initialize(cache_refresh_interval)
        @cache_refresh_interval = cache_refresh_interval
        test_val = 'test val'
      end

      def self.test_class_method_cached
        simple_cache(:test_class_method, @@cache_refresh_interval)
      end
      def self.test_class_method
        "test result"
      end
      def self.test_class_method_with_param_cached(p)
        simple_cache(:test_class_method_with_param, @@cache_refresh_interval, p)
      end
      def self.test_class_method_with_param(p)
        "test result with param #{p}"
      end

      def test_method_cached
        simple_cache(:test_method, @cache_refresh_interval)
      end
      def test_method
        "test result: #{test_val}"
      end
      def test_method_with_param_cached(p)
        simple_cache(:test_method_with_param, @cache_refresh_interval, p)
      end
      def test_method_with_param(p)
        "test result with param #{p}: #{test_val}"
      end

      def test_chained_method
        "test result: #{test_val}"
      end
      alias_simple_cache_method_chain(:test_chained_method,@@cache_refresh_interval)
    end

  end

  context "class methods" do
    before(:each) do
      @test_class_method_result = TestClass.test_class_method
      @param = 'test param'
      @test_class_method_with_param_result = TestClass.test_class_method_with_param(@param)
    end
    after(:each) do
      TestClass.simple_cache_purge(:test_class_method)
      TestClass.simple_cache_purge(:test_class_method_with_param, @param)
    end

    it "should return the same results as the non-cached method" do
      TestClass.test_class_method_cached.should == @test_class_method_result
    end

    context "without parameters" do
      it "should only call method once if within cache refresh interval" do
        TestClass.should_receive(:test_class_method).once
        3.times do 
          TestClass.test_class_method_cached
        end
      end 

      it "should call the cached method again if the cache is stale" do
        TestClass.should_receive(:simple_cache_stale?).and_return(true,true)
        TestClass.should_receive(:test_class_method).twice

        2.times { TestClass.test_class_method_cached }
      end
    end

    context "with parameters" do
      it "should only call method once if within cache refresh interval" do
        TestClass.should_receive(:test_class_method_with_param).with(@param).once
        3.times do 
          TestClass.test_class_method_with_param_cached(@param)
        end
      end 

      it "should call the cached method again if the cache is stale" do
        TestClass.should_receive(:simple_cache_stale?).and_return(true,true)
        TestClass.should_receive(:test_class_method_with_param).twice

        2.times { TestClass.test_class_method_with_param_cached(@param) }
      end
    end
  end

  context "instance methods" do
    before(:each) do
      @test_object = TestClass.new(1.minute)
      @test_method_result = @test_object.test_method
      @param = 'test param'
      @test_method_with_param_result = @test_object.test_method_with_param(@param)
    end

    after(:each) do
      @test_object.simple_cache_purge(:test_method)
      @test_object.simple_cache_purge(:test_method_with_param,@param)
    end

    context "chained methods" do
      it "should use the cached value after initial call" do
        @test_object.test_chained_method.should == @test_method_result
        @test_object.test_val = 'new val'
        new_test_method_result = @test_object.test_method
        @test_object.test_chained_method.should == @test_method_result
      end

      it "unchained method should always return current value" do
        @test_object.test_chained_method_without_simple_cache_.should == @test_method_result
        @test_object.test_val = 'new val'
        new_test_method_result = @test_object.test_method
        @test_object.test_chained_method.should == new_test_method_result
      end
    end

    it "should return correct results on subsequent chained method calls" do
      3.times { @test_object.test_chained_method.should == @test_method_result }
    end

    it "should return the same results as the non-cached method" do
      @test_object.test_method_cached.should == @test_method_result
    end

    it "should return the same results as the non-cached method after repeated calls (assuming underlying method does not change)" do
      5.times { @test_object.test_method_cached.should == @test_method_result }
    end

    context "without parameters" do
      it "should only call method once if within cache refresh interval" do
        @test_object.should_receive(:test_method).once
        3.times do 
          @test_object.test_method_cached
        end
      end 

      it "should call the cached method again if cache is stale" do
        TestClass.should_receive(:simple_cache_stale?).and_return(true,true)
        @test_object.should_receive(:test_method).twice

        2.times { @test_object.test_method_cached }
      end
    end
    context "with parameters" do
      it "should only call method once if within cache refresh interval" do
        @test_object.should_receive(:test_method_with_param).with(@param).once
        3.times do 
          @test_object.test_method_with_param_cached(@param)
        end
      end 

      it "should call the cached method again if the cache is stale" do
        TestClass.should_receive(:simple_cache_stale?).and_return(true,true)
        @test_object.should_receive(:test_method_with_param).twice

        2.times { @test_object.test_method_with_param_cached(@param) }
      end
    end
  end

end

