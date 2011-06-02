require 'rspec'
require File.dirname(File.expand_path(__FILE__)) + '/../lib/redis_orm.rb'

class Profile < RedisOrm::Base
  property :name, String

  has_one :location
end

class Location < RedisOrm::Base
  property :coordinates, String
  
  has_many :profiles
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
  end

  after(:each) do
   $redis.flushall if $redis
  end

  after(:all) do
    Process.kill 9, $redis_pid.to_i if $redis_pid
  end

  it "should save associations properly" do
    @profile = Profile.new
    @profile.name = "my profile"
    @profile.save

    @profile.should be
    @profile.name.should == "my profile"

    @location1 = Location.new
    @location1.coordinates = "44.343456345 56.23341432"
    @location1.save
    @location1.should be
    @location1.coordinates.should == "44.343456345 56.23341432"

    @profile.location = @location1

    @profile.location.should be
    @profile.location.id.should == @location1.id

    @location1.profiles.size.should == 1
    @location1.profiles.first.id.should == @profile.id

    # check second profile
    @profile2 = Profile.new
    @profile2.name = "someone else's profile"
    @profile2.save

    @profile2.should be
    @profile2.name.should == "someone else's profile"

    @profile2.location = @location1

    @profile2.location.should be
    @profile2.location.id.should == @location1.id

    @location1.profiles.size.should == 2
    @location1.profiles.collect{|p| p.id}.sort.should == [@profile.id, @profile2.id].sort
  end
end
