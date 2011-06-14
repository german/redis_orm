require File.dirname(File.expand_path(__FILE__)) + '/test_helper.rb'

class CutoutAggregator < RedisOrm::Base
  property :modified_at, Time

  property :revision, Integer, :default => 0
end

class Cutout < RedisOrm::Base
  property :filename, String

  before_create :increase_revisions
  before_destroy :decrease_revisions

  def increase_revisions
    ca = CutoutAggregator.last
    ca.update_attribute(:revision, ca.revision + 1) if ca
  end

  def decrease_revisions
    ca = CutoutAggregator.first
    if ca.revision > 0
      ca.update_attribute :revision, ca.revision - 1
    end

    ca.destroy if ca.revision == 0
  end
end

class Comment < RedisOrm::Base
  property :text, String

  belongs_to :user

  before_save :trim_whitespaces
  after_save :regenerate_karma

  def trim_whitespaces
    self.text = self.text.strip
  end

  def regenerate_karma
    if self.user
      self.user.update_attribute :karma, (self.user.karma - self.text.length)
    end
  end
end

class User < RedisOrm::Base
  property :first_name, String
  property :last_name, String

  property :karma, Integer, :default => 1000

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
  it "should fire after_create/after_destroy callbacks" do
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

  it "should fire before_create/before_destroy callbacks" do
    CutoutAggregator.create

    CutoutAggregator.count.should == 1
    Cutout.create :filename => "1.jpg"
    Cutout.create :filename => "2.jpg"
    CutoutAggregator.last.revision.should == 2
    Cutout.last.destroy
    Cutout.last.destroy
    CutoutAggregator.count.should == 0
  end

  it "should fire after_save/before_save callbacks" do
    comment = Comment.new :text => "      Trim meeee !   "
    comment.save
    Comment.first.text.should == "Trim meeee !"

    user = User.new :first_name => "Robert", :last_name => "Pirsig"
    user.save
    user.karma.should == 1000

    user.comments << comment
    user.comments.count == 1

    c = Comment.first
    c.update_attributes :text => "Another brick in the wall"

    User.first.karma.should == 975
  end
end
