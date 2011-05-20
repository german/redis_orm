require 'rspec'
require File.dirname(File.expand_path(__FILE__)) + '/../lib/redis_orm.rb'

class User < RedisOrm::Base
  property :name, String
  property :age, Integer
  property :wage, Float

  property :created_at, Time
  property :modified_at, Time
end

describe "check basic functionality" do
  before(:all) do
    #$redis_pid = spawn 'redis-server', :out=>"/dev/null"
    #sleep(1)
    #puts 'started - ' + $redis_pid.to_s
    #$redis = Redis.new(:host => 'localhost', :port => 6379)
    path_to_conf = File.dirname(File.expand_path(__FILE__)) + "/redis.conf"
    $redis_pid = spawn 'redis-server ' + path_to_conf, :out=>"/dev/null"
    sleep(1)
    puts 'started - ' + $redis_pid.to_s
    path_to_socket = File.dirname(File.expand_path(__FILE__)) + "/../redis.sock"
    puts 'path_to_socket - ' + path_to_socket.inspect
    $redis = Redis.new(:host => 'localhost', :path => path_to_socket)#:port => 6379)
  end
  
  before(:each) do
    $redis.flushall if $redis
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

  it "test_simple_creation" do
    User.count.should == 0

    user = User.new
    user.should be

    user.name = "german"
    user.save

    user.name.should == "german"

    User.count.should == 1
  end

  it "test_simple_update" do
    User.count.should == 0

    user = User.new
    user.should be

    user.name = "german"
    user.save

    user.name.should == "german"

    user.name = "nobody"
    user.save

    user.name.should == "nobody"

    User.count.should == 1
  end

  it "test_deletion" do
    User.count.should == 0

    user = User.new
    user.should be

    user.name = "german"
    user.save

    user.name.should == "german"

    User.count.should == 1

    user.destroy
    User.count.should == 0
  end

  it "should return first and last objects" do
    User.count.should == 0
    User.first.should == nil
    User.last.should == nil

    user1 = User.new
    user1.name = "german"
    user1.save
    user1.should be
    user1.name.should == "german"

    user2 = User.new
    user2.name = "nobody"
    user2.save
    user2.should be
    user2.name.should == "nobody"

    User.count.should == 2

    User.first.should be
    User.last.should be

    User.first.id.should == user1.id
    User.last.id.should  == user2.id
  end

  it "should return values with correct classes" do
    user = User.new
    user.name = "german"
    user.age = 26
    user.wage = 124.34
    user.save

    user.should be

    u = User.first

    u.created_at.class.should == Time
    u.modified_at.class.should == Time
    u.wage.class.should == Float
    u.age.class.to_s.should match(/Integer|Fixnum/)

    u.name.should == "german"
    u.wage.should == 124.34
    u.age.should  == 26
  end
end
