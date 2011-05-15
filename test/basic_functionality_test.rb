require 'rspec'
require File.dirname(File.expand_path(__FILE__)) + '/../lib/redis_orm.rb'

class User < RedisOrm::Base
  property :name, String
  property :age, Integer
  property :created_at, Time
end

describe "check basic functionality" do
  before(:all) do
    $redis_pid = spawn 'redis-server', :out=>"/dev/null"
    sleep(1)
    puts 'started - ' + $redis_pid.to_s
    $redis = Redis.new(:host => 'localhost', :port => 6379)
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
end
