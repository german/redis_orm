require 'rspec'
require File.dirname(File.expand_path(__FILE__)) + '/../lib/redis_orm.rb'

class Comment < RedisOrm::Base
  property :text, String

  belongs_to :user
end

class User < RedisOrm::Base
  property :first_name, String
  property :last_name, String

  index :first_name
  index :last_name
  index [:first_name, :last_name]

  has_many :comments

  after_create :store_in_rating
  after_destroy :after_destroy_callback

  def store_in_rating
    $redis.zadd "users:sorted_by_rating", 0.0, self.id
  end

  def after_destroy_callback
    self.comments.map{|c| c.destroy}
  end
end

describe "check callbacks" do
  before(:all) do
    path_to_conf = File.dirname(File.expand_path(__FILE__)) + "/redis.conf"
    $redis_pid = spawn 'redis-server ' + path_to_conf, :out=>"/dev/null"
    sleep(1)
    path_to_socket = File.dirname(File.expand_path(__FILE__)) + "/../redis.sock"
    $redis = Redis.new(:host => 'localhost', :path => path_to_socket)#:port => 6379)
  end
  
  before(:each) do
    $redis.flushall if $redis
  end

  after(:each) do
   $redis.flushall if $redis
  end

  after(:all) do
    if $redis_pid
      Process.kill 9, $redis_pid.to_i
    end
  end

  it "should fire after_create/after_destroy callback" do
    user = User.new :first_name => "Robert", :last_name => "Pirsig"
    user.save

    $redis.zrank("users:sorted_by_rating", user.id).should == 0

    comment = Comment.create :text => "First!"
    user.comments << comment

    u = User.first
    u.id.should == user.id
    u.comments.count.should == 1
    u.destroy
    u.comments.count.should == 0
  end
end
