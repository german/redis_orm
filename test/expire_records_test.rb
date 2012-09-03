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

  it "should also create expirable key when record has associated records" do
    euser = ExpireUser.create :name => "Ghost rider"
    $redis.ttl(euser.__redis_record_key).should be > 9.minutes.from_now.to_i
    $redis.ttl(euser.__redis_record_key).should be < (10.minutes.from_now.to_i + 1)
    
    profile = Profile.create :title => "Profile for ghost rider", :name => "Ghost Rider"
    articles = [Article.create(:title => "article1", :karma => 1), Article.create(:title => "article2", :karma => 2)]
    
    euser.profile = profile
    euser.profile.should == profile
    $redis.get("expire_user:1:profile").to_i.should == profile.id
    $redis.ttl("expire_user:1:profile").should be > 9.minutes.from_now.to_i
    $redis.ttl("expire_user:1:profile").should be < (10.minutes.from_now.to_i + 1)
    
    euser.articles = articles
    $redis.zrange("expire_user:1:articles", 0, -1).should =~ articles.map{|a| a.id.to_s}
    $redis.ttl("expire_user:1:articles").should be > 9.minutes.from_now.to_i
    $redis.ttl("expire_user:1:articles").should be < (10.minutes.from_now.to_i + 1)
  end
  
  it "should also create expirable key when record has associated records (class with predicate expiry)" do
    euser2 = ExpireUserWithPredicate.create :name => "Ghost rider", :persist => false
    $redis.ttl(euser2.__redis_record_key).should be > 9.minutes.from_now.to_i
    $redis.ttl(euser2.__redis_record_key).should be < (10.minutes.from_now.to_i + 1)
    
    profile = Profile.create :title => "Profile for ghost rider", :name => "Ghost Rider"
    articles = [Article.create(:title => "article1", :karma => 1), Article.create(:title => "article2", :karma => 2)]
    
    euser2.profile = profile
    euser2.profile.should == profile
    $redis.get("expire_user_with_predicate:1:profile").to_i.should == profile.id
    $redis.ttl("expire_user_with_predicate:1:profile").should be > 9.minutes.from_now.to_i
    $redis.ttl("expire_user_with_predicate:1:profile").should be < (10.minutes.from_now.to_i + 1)
    
    euser2.articles << articles
    $redis.zrange("expire_user_with_predicate:1:articles", 0, -1).should =~ articles.map{|a| a.id.to_s}
    $redis.ttl("expire_user_with_predicate:1:articles").should be > 9.minutes.from_now.to_i
    $redis.ttl("expire_user_with_predicate:1:articles").should be < (10.minutes.from_now.to_i + 1)
  end
end
