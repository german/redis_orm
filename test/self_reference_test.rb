require 'rspec'
require File.dirname(File.expand_path(__FILE__)) + '/../lib/redis_orm.rb'

class User < RedisOrm::Base
  property :name, String
  has_many :users, :as => :friends
end

describe "test self reference" do
  before(:all) do
    path_to_conf = File.dirname(File.expand_path(__FILE__)) + "/redis.conf"
    $redis_pid = spawn 'redis-server ' + path_to_conf, :out=>"/dev/null"
    sleep(1)
    path_to_socket = File.dirname(File.expand_path(__FILE__)) + "/../redis.sock"
    $redis = Redis.new(:host => 'localhost', :path => path_to_socket)#:port => 6379)
  end
  
  after(:all) do    
    Process.kill(9, $redis_pid.to_i) if $redis_pid
  end

  after(:each) do
   $redis.flushall if $redis
  end

  before(:each) do
    $redis.flushall if $redis
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
end
