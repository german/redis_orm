module RedisOrm
  module Associations
    module HasMany
      # user.avatars => user:1:avatars => [1, 22, 234] => Avatar.find([1, 22, 234])
      # options
      #   *:dependant* key: either *destroy* or *nullify* (default)
      def has_many(foreign_models, options = {})
        class_associations = class_variable_get(:"@@associations")
        class_associations[model_name] << {:type => :has_many, :foreign_models => foreign_models, :options => options}

        define_method foreign_models.to_sym do
          Associations::HasManyProxy.new(model_name, id, foreign_models)
        end

        # user = User.find(1)
        # user.avatars = Avatar.find(23) => user:1:avatars => [23]
        define_method "#{foreign_models}=" do |records|
          # clear old assocs from related models side
          self.send(foreign_models).to_a.each do |record|
            $redis.zrem "#{record.model_name}:#{record.id}:#{model_name.pluralize}", id
          end

          # clear old assocs from this model side
          $redis.zremrangebyscore "#{model_name}:#{id}:#{records[0].model_name.pluralize}", 0, Time.now.to_i

          records.to_a.each do |record|
            $redis.zadd("#{model_name}:#{id}:#{record.model_name.pluralize}", Time.now.to_i, record.id)

            # article.comments = [comment1, comment2] 
            # iterate through the array of comments and create backlink
            # check whether *record* object has *has_many* declaration and TODO it states *self.model_name* in plural
            if class_associations[record.model_name].detect{|h| h[:type] == :has_many && h[:foreign_models] == model_name.pluralize.to_sym} #&& !$redis.zrank("#{record.model_name}:#{record.id}:#{model_name.pluralize}", id)#record.model_name.to_s.camelize.constantize.find(id).nil?
              $redis.zadd("#{record.model_name}:#{record.id}:#{model_name.pluralize}", Time.now.to_i, id)
            # check whether *record* object has *has_one* declaration and TODO it states *self.model_name*
            elsif record.get_associations.detect{|h| [:has_one, :belongs_to].include?(h[:type]) && h[:foreign_model] == model_name.to_sym} # overwrite assoc anyway so we don't need to check record.send(model_name.to_sym).nil? here
              $redis.set("#{record.model_name}:#{record.id}:#{model_name}", id)
            end
          end
        end
      end
    end
  end
end
