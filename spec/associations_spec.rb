require 'spec_helper'

describe "check associations" do
  before(:each) do
    @article = Article.new :title => "DHH drops OpenID on 37signals"
    @article.save

    @article.should be
    @article.title.should == "DHH drops OpenID on 37signals"

    @comment1 = Comment.new :body => "test"
    @comment1.save
    @comment1.should be
    @comment1.body.should == "test"

    @comment2 = Comment.new :body => "test #2"
    @comment2.save
    @comment2.should be
    @comment2.body.should == "test #2"
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
  end
 
  it "should correctly resets associations when nil/[] provided" do
    # from has_many proxy side
    @article.comments << [@comment1, @comment2]
    @article.comments.count.should == 2
    expect(@comment1.article.id).to eq(@article.id)
    expect(@comment2.article.id).to eq(@article.id)
    
    # clear    
    @article.comments = []
    @article.comments.count.should == 0
    expect(@comment1.article).to be_nil
    expect(@comment2.article).to be_nil

    # from belongs_to side
    @article.comments << [@comment1, @comment2]
    @article.comments.count.should == 2
    @comment1.article.id.should == @article.id
    
    # clear
    @comment1.article = nil
    @article.comments.count.should == 1
    @comment1.article.should == nil
    
    # from has_one side
    profile = Profile.create :title => "test"
    chicago = City.create :name => "Chicago"

    profile.city = chicago
    profile.city.name.should == "Chicago"
    chicago.profiles.count.should == 1
    chicago.profiles[0].id.should == profile.id
    
    # clear
    profile.city = nil
    profile.city.should == nil
    chicago.profiles.count.should == 0
  end
  
  it "should return array of records for has_many association" do
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

  it "should behave as active_record (proxy couldn't return records w/o #all call) += and << behave differently" do
    @article.comments << @comment1 << @comment2
    @article.comments.count.should == 2

    comments = @article.comments
    comments.count.should == 2
    
    comments = []
    comments += @article.comments
    comments.count.should == 2
    comments.collect{|c| c.id}.should include(@comment1.id)
    comments.collect{|c| c.id}.should include(@comment2.id)
    
    comments = []
    comments << @article.comments.all
    comments.flatten.count.should == 2
    
    comments = []
    comments << @article.comments
    comments.count.should == 1
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
    @cat1.articles[0].should == @article
    @cat2.articles.count.should == 1
    @cat2.articles[0].should == @article

    @article.categories.size.should == 2
    @article.categories.count.should == 2
    
    @article.categories = [@cat1, @cat3]
    @article.categories.count.should == 2
    @article.categories.map{|c| c.id}.include?(@cat1.id).should be
    @article.categories.map{|c| c.id}.include?(@cat3.id).should be

    @cat1.articles.count.should == 1
    @cat1.articles[0].should == @article

    @cat3.articles.count.should == 1
    @cat3.articles[0].should == @article

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
  
  it "should create self-referencing link for has_one association" do
    m = Message.create :text => "it should create self-referencing link for has_one association"

    r = Message.create :text => "replay"
    
    r.replay_to = m

    Message.count.should == 2
    r.replay_to.should be
    r.replay_to.id.should == m.id
    
    rf = Message.last
    rf.replay_to.should be
    rf.replay_to.id.should == Message.first.id
  end

  it "should find associations within modules" do    
    BelongsToModelWithinModule::Reply.count.should == 0
    essay = Article.create :title => "Red is cluster"
    BelongsToModelWithinModule::Reply.create :essay => essay
    BelongsToModelWithinModule::Reply.count.should == 1
    reply = BelongsToModelWithinModule::Reply.last
    reply.essay.should == essay
    
    HasManyModelWithinModule::SpecialComment.count.should == 0
    book = HasManyModelWithinModule::Brochure.create :title => "Red is unstable"
    HasManyModelWithinModule::SpecialComment.create :book => book
    HasManyModelWithinModule::Brochure.count.should == 1
    HasManyModelWithinModule::SpecialComment.count.should == 1
  end

  it "should properly handle self-referencing model both belongs_to and has_many/has_one associations" do
    comment1 = Comment.create :body => "comment1"
    comment11 = Comment.create :body => "comment1.1"
    comment12 = Comment.create :body => "comment1.2"
    
    comment1.replies = [comment11, comment12]
    comment1.replies.count.should == 2
    comment11.reply_to.should == comment1
    comment12.reply_to.should == comment1
  end
end
