require 'rspec'
require File.dirname(File.expand_path(__FILE__)) + '/../lib/redis_orm.rb'

class Article < RedisOrm::Base
  property :title, String

  has_many :comments
end

class Comment < RedisOrm::Base
  property :body, String
  
  belongs_to :article
end

describe "check associations" do
  before(:all) do
    $redis_pid = spawn 'redis-server', :out=>"/dev/null"
    sleep(1)
    puts 'started - ' + $redis_pid.to_s
    $redis = Redis.new(:host => 'localhost', :port => 6379)
  end
  
  before(:each) do
    $redis.flushall if $redis
    @article = Article.new
    @article.title = "DHH drops OpenID on 37signals"
    @article.save

    @article.should be
    @article.title.should == "DHH drops OpenID on 37signals"

    @comment1 = Comment.new
    @comment1.body = "test"
    @comment1.save
    @comment1.should be
    @comment1.body.should == "test"

    @comment2 = Comment.new
    @comment2.body = "test #2"
    @comment2.save
    @comment2.should be
    @comment2.body.should == "test #2"
  end

  after(:each) do
   $redis.flushall if $redis
  end

  after(:all) do
    puts 'finish - ' + $redis_pid.to_s
    if $redis_pid
      Process.kill 9, $redis_pid.to_i
    end
  end

  it "should return array" do
    @article.comments << [@comment1, @comment2]
    #@article.comments.should be_kind_of(Array)
    @article.comments.size.should == 2
    @comment1.article.should be
    @comment2.article.should be

    @comment1.article.id.should == @comment2.article.id
  end

  it "should return 1 comment when second was deleted" do
    Comment.count.should == 2
    @article.comments << [@comment1, @comment2]
    #@article.comments.should be_kind_of(Array)
    @article.comments.size.should == 2
    
    @comment1.destroy
    puts "article:#{@article.id}:comments" + $redis.smembers("article:#{@article.id}:comments").inspect

    @article.comments.size.should == 1

    Comment.count.should == 1
  end
end
