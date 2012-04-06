class Comment < RedisOrm::Base
  property :body, String
  property :text, String
  property :moderated, RedisOrm::Boolean, :default => false

  index :moderated

  belongs_to :user
  belongs_to :article

  has_many :comments, :as => :replies
  belongs_to :comment, :as => :reply_to

  before_save :trim_whitespaces
  after_save :regenerate_karma

  def trim_whitespaces
    self.text = self.text.to_s.strip
  end

  def regenerate_karma
    if self.user
      self.user.update_attribute :karma, (self.user.karma - self.text.length)
    end
  end
end
