require 'rails/generators'
require 'rails/generators/named_base'

module RedisOrm
  module Generators
    class ModelGenerator < ::Rails::Generators::NamedBase
      source_root File.expand_path('../templates', __FILE__)

      desc "Creates a RedisOrm model"
      argument :attributes, type: :array, default: [], banner: "field:type field:type"

      check_class_collision

      def create_model_file
        template "model.rb.erb", File.join('app/models', class_path, "#{file_name}.rb")
      end

      hook_for :test_framework
    end
  end
end
