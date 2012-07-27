require File.dirname(File.expand_path(__FILE__)) + '/test_helper.rb'

describe "expire record after specified time" do
=begin
  it "should create a record and then delete if *expire* method is specified in appropriate class" do
    euser = ExpireUser.create :name => "Ghost rider"
    $redis.ttl(euser.__redis_record_key).should be > 9.minutes.to_i
  end
=end
  it "should create a record and then delete if *expire* method is specified in appropriate class" do
    euser = ExpireUserWithPredicate.create :name => "Ghost rider"
    $redis.ttl(euser.__redis_record_key).should be > 9.minutes.to_i

    euser2 = ExpireUserWithPredicate.create :name => "Ghost rider", :persist => true
    $redis.ttl(euser2.__redis_record_key).should == -1
  end
=begin
  it "should create a record with inline *expire* option" do
    euser = ExpireUser.create :name => "Ghost rider", :expire => 50.minutes.from_now

    $redis.ttl(euser.__redis_record_key).should be > 49.minutes.from_now
  end
=end
end
