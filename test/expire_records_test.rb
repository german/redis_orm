require File.dirname(File.expand_path(__FILE__)) + '/test_helper.rb'

describe "expire record after specified time" do
  it "should create a record and then delete if *expire* method is specified in appropriate class" do
    euser = ExpireUser.create :name => "Ghost rider"
    $redis.ttl(euser.__redis_record_key).should be > 9.minutes.from_now.to_i
    $redis.ttl(euser.__redis_record_key).should be < (10.minutes.from_now.to_i + 1)
  end

  it "should create a record and then delete if *expire* method is specified in appropriate class" do
    euser = ExpireUserWithPredicate.create :name => "Ghost rider"
    $redis.ttl(euser.__redis_record_key).should be > 9.minutes.from_now.to_i
    $redis.ttl(euser.__redis_record_key).should be < (10.minutes.from_now.to_i + 1)

    euser2 = ExpireUserWithPredicate.create :name => "Ghost rider", :persist => true
    $redis.ttl(euser2.__redis_record_key).should == -1
  end

  it "should create a record with an inline *expire* option (which overrides default *expire* value)" do
    euser = ExpireUser.create :name => "Ghost rider", :expire_in => 50.minutes.from_now
    $redis.ttl(euser.__redis_record_key).should be < (50.minutes.from_now.to_i + 1)
    $redis.ttl(euser.__redis_record_key).should be > 49.minutes.from_now.to_i
  end
end
