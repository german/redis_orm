require 'spec_helper.rb'

describe "check atomicity" do
  let(:init_value) { 1 }
  let(:number_of_threads) { 100 }

  it "should properly increment property's value" do
    article = Article.create({title: "Simple test atomicity with multiple threads", karma: init_value})
    threads = []
    
    number_of_threads.times do |i|
      threads << Thread.new(i) do
        article.update_attributes({karma: (article.karma + 1)})
      end
    end
    
    threads.each{|thread| thread.join}
    expect(Article.first.karma).to eq(number_of_threads + init_value)
  end

  it "should properly increment/decrement property's value" do
    article = Article.create :title => "article #1", :karma => 10
    threads = []
    
    12.times do
      threads << Thread.new { article.update_attributes(karma: (article.karma + 2)) }
    end
    
    24.times do
      threads << Thread.new { article.update_attributes(karma: (article.karma - 1)) }
    end
    
    threads.each{|thread| thread.join}
    expect(article.karma).to eq(10)
  end
end
