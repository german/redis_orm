module ActiveModelBehavior 
  module ClassMethods
    def model_name
      #@_model_name ||= ActiveModel::Name.new(self).to_s.downcase
      @_model_name ||= ActiveModel::Name.new(self).to_s.tableize.singularize
    end
  end

  module InstanceMethods
    def model_name
      #@_model_name ||= ActiveModel::Name.new(self.class).to_s.downcase
      @_model_name ||= ActiveModel::Name.new(self.class).to_s.tableize.singularize
    end
  end

  def self.included(base) 
    base.send(:include, InstanceMethods)
    base.extend ClassMethods
  end 
end 
