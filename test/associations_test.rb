require 'rspec'
require File.dirname(File.expand_path(__FILE__)) + '/../lib/redis_orm.rb'

class Article < RedisOrm::Base
  property :title, String
  has_many :comments
  has_many :categories
end

class Comment < RedisOrm::Base
  property :body, String
  belongs_to :article
end

class Profile < RedisOrm::Base
  property :title, String
  has_one :city
end

class City < RedisOrm::Base
  property :name, String
  has_many :profiles
end

class Category < RedisOrm::Base
  property :name, String
  has_many :articles
end

class User < RedisOrm::Base
  property :name, String
  index :name
  has_many :users, :as => :friends
end

describe "check associations" do
  before(:all) do
    path_to_conf = File.dirname(File.expand_path(__FILE__)) + "/redis.conf"
    $redis_pid = spawn 'redis-server ' + path_to_conf, :out => "/dev/null"
    sleep(0.3) # must be some delay otherwise "Connection refused - Unable to connect to Redis"
    path_to_socket = File.dirname(File.expand_path(__FILE__)) + "/../redis.sock"
    $redis = Redis.new(:host => 'localhost', :path => path_to_socket)
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
    Process.kill 9, $redis_pid.to_i if $redis_pid
  end

  it "should assign properly from belongs_to side" do
    @comment1.article.should == nil
    @comment1.article = @article
    @comment1.article.id.should == @article.id
    @article.comments.count.should == 1
    @article.comments[0].id.should == @comment1.id
    
    @comment2.article.should == nil
    @comment2.article = @article
    @comment2.article.id.should == @article.id
    @article.comments.count.should == 2
    @article.comments[0].id.should == @comment2.id
    
    #@comment1.article = nil
    #@article.comments.count.should == 1
    #@comment1.article.should == nil
  end
  
  it "should return array" do
    @article.comments << []    
    @article.comments.count.should == 0
    
    @article.comments = []    
    @article.comments.count.should == 0
    
    @article.comments << [@comment1, @comment2]
    #@article.comments.should be_kind_of(Array)

    @article.comments.count.should == 2
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

    @article.comments.size.should == 1
    @article.comments.count.should == 1
    Comment.count.should == 1
  end

  it "should leave associations when parent has been deleted (nullify assocs)" do
    Comment.count.should == 2
    @article.comments << [@comment1, @comment2]
    @comment1.article.id.should == @article.id
    @comment2.article.id.should == @article.id
    #@article.comments.should be_kind_of(Array)
    @article.comments.size.should == 2
    @article.comments.count.should == 2
    
    @article.destroy

    Article.count.should == 0

    Comment.count.should == 2
  end

  it "should replace associations when '=' is used instead of '<<' " do
    Comment.count.should == 2
    @article.comments << [@comment1, @comment2]
    @comment1.article.id.should == @article.id
    @comment2.article.id.should == @article.id
    @article.comments.size.should == 2
    @article.comments.count.should == 2
    
    @article.comments = [@comment1]
    @article.comments.count.should == 1
    @article.comments.first.id.should == @comment1.id

    @comment1.article.id.should == @article.id
  end

  it "should correctly use many-to-many associations both with '=' and '<<' " do
    @cat1 = Category.create :name => "Nature"
    @cat2 = Category.create :name => "Art"
    @cat3 = Category.create :name => "Web"

    @cat1.name.should == "Nature"
    @cat2.name.should == "Art"
    @cat3.name.should == "Web"

    @article.categories << [@cat1, @cat2]

    @cat1.articles.count.should == 1
    @cat1.articles[0].id.should == @article.id
    @cat2.articles.count.should == 1
    @cat2.articles[0].id.should == @article.id

    @article.categories.size.should == 2
    @article.categories.count.should == 2
    
    @article.categories = [@cat1, @cat3]
    @article.categories.count.should == 2
    @article.categories.map{|c| c.id}.include?(@cat1.id).should be
    @article.categories.map{|c| c.id}.include?(@cat3.id).should be

    @cat1.articles.count.should == 1
    @cat1.articles[0].id.should == @article.id

    @cat3.articles.count.should == 1
    @cat3.articles[0].id.should == @article.id

    @cat2.articles.count.should == 0

    @cat1.destroy
    Category.count.should == 2
    @article.categories.count.should == 1
  end

  it "should remove old associations and create new ones" do
    profile = Profile.new
    profile.title = "test"
    profile.save

    chicago = City.new
    chicago.name = "Chicago"
    chicago.save
    
    washington = City.new
    washington.name = "Washington"
    washington.save

    profile.city = chicago
    profile.city.name.should == "Chicago"
    chicago.profiles.count.should == 1
    washington.profiles.count.should == 0
    chicago.profiles[0].id.should == profile.id

    profile.city = washington
    profile.city.name.should == "Washington"
    chicago.profiles.count.should == 0
    washington.profiles.count.should == 1
    washington.profiles[0].id.should == profile.id
  end

  it "should maintain correct self referencing link" do
    me = User.create :name => "german"
    friend1 = User.create :name => "friend1"
    friend2 = User.create :name => "friend2"

    me.friends << [friend1, friend2]

    me.friends.count.should == 2
    friend1.friends.count.should == 0
    friend2.friends.count.should == 0
  end

  it "should delete one specific record from an array with associated records" do
    me = User.create :name => "german"
    friend1 = User.create :name => "friend1"
    friend2 = User.create :name => "friend2"

    me.friends << [friend1, friend2]

    me = User.find_by_name 'german'
    me.friends.count.should == 2
    friend1 = User.find_by_name 'friend1'
    friend1.friends.count.should == 0
    friend2 = User.find_by_name 'friend2'
    friend2.friends.count.should == 0

    me.friends.delete(friend1.id)
    me.friends.count.should == 1
    me.friends[0].id == friend2.id
    User.count.should == 3
  end
end
