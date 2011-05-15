module ActiveModelBehavior 
  module ClassMethods
    def model_name
      @_model_name ||= ActiveModel::Name.new(self).to_s.downcase
    end
  end

  module InstanceMethods
    def model_name
      @_model_name ||= ActiveModel::Name.new(self.class).to_s.downcase
    end
  end

  def self.included(base) 
    base.send(:include, InstanceMethods)
    base.extend ClassMethods
  end 
end 
