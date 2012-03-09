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
