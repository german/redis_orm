require 'rspec'
require File.dirname(File.expand_path(__FILE__)) + '/../lib/redis_orm.rb'

class Photo < RedisOrm::Base
  property :image, String
  
  validates_presence_of :image
  validates_length_of :image, :in => 7..32
  validates_format_of :image, :with => /\w*\.(gif|jpe?g|png)/
end

describe "check associations" do
  before(:all) do
    path_to_conf = File.dirname(File.expand_path(__FILE__)) + "/redis.conf"
    $redis_pid = spawn 'redis-server ' + path_to_conf, :out=>"/dev/null"
    sleep(1)
    path_to_socket = File.dirname(File.expand_path(__FILE__)) + "/../redis.sock"
    $redis = Redis.new(:host => 'localhost', :path => path_to_socket)#:port => 6379)
  end
  
  after(:all) do
    Process.kill 9, $redis_pid.to_i if $redis_pid
  end

  after(:each) do
   $redis.flushall if $redis
  end

  before(:each) do
    $redis.flushall if $redis
  end

  it "should validate presence if image in photo" do
    p = Photo.new
    p.save.should == false
    p.errors.should be
    p.errors[:image].should include("can't be blank")

    p.image = "test"
    p.save.should == false
    p.errors.should be
    p.errors[:image].should include("is too short (minimum is 7 characters)")
    p.errors[:image].should include("is invalid")

    p.image = "facepalm.jpg"
    p.save
    p.errors.empty?.should == true
  end
end
