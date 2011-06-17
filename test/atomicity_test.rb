require File.dirname(File.expand_path(__FILE__)) + '/test_helper.rb'

class Article < RedisOrm::Base
  property :title, String
  property :karma, Integer
end

describe "check atomicity" do
  it "should properly increment property's value" do
    @article = Article.new :title => "Simple test atomicity with multiple threads", :karma => 1
    @article.save
    
    @threads = []
    
    50.times do |i|
      @threads << Thread.new(i) do
        @article.update_attribute :karma, (@article.karma + 1)
      end
    end
    
    @threads.each{|thread| thread.join}
    
    Article.first.karma.should == 51
  end
end
