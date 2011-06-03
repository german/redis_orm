module RedisOrm
  module Associations
    module HasOne
      # user.avatars => user:1:avatars => [1, 22, 234] => Avatar.find([1, 22, 234])
      # *options* is a hash and can hold:
      #   *:as* key
      #   *:dependant* key: either *destroy* or *nullify* (default)
      def has_one(foreign_model, options = {})
        class_associations = class_variable_get(:"@@associations")
        class_associations[model_name] << {:type => :has_one, :foreign_model => foreign_model, :options => options}

        foreign_model_name = if options[:as]
          options[:as].to_sym
        else
          foreign_model.to_sym
        end

        define_method foreign_model_name do
          foreign_model.to_s.camelize.constantize.find($redis.get "#{model_name}:#{@id}:#{foreign_model_name}")
        end     

        # profile = Profile.create :title => 'test'
        # user.profile = profile => user:23:profile => 1
        define_method "#{foreign_model_name}=" do |assoc_with_record|
          # we need to store this to clear old associations later
          old_assoc = self.send(foreign_model_name)

          if assoc_with_record.model_name == foreign_model.to_s
            $redis.set("#{model_name}:#{id}:#{foreign_model_name}", assoc_with_record.id)
          else
            raise TypeMismatchError
          end

          # check whether *assoc_with_record* object has *belongs_to* declaration and TODO it states *self.model_name* and there is no record yet from the *assoc_with_record*'s side (in order not to provoke recursion)
          if class_associations[assoc_with_record.model_name].detect{|h| [:belongs_to, :has_one].include?(h[:type]) && h[:foreign_model] == model_name.to_sym} && assoc_with_record.send(model_name.to_sym).nil?
            # old association is being rewritten here automatically so we don't have to worry about it
            assoc_with_record.send("#{model_name}=", self)
          elsif class_associations[assoc_with_record.model_name].detect{|h| :has_many == h[:type] && h[:foreign_models] == model_name.to_s.pluralize.to_sym} && !$redis.zrank("#{assoc_with_record.model_name}:#{assoc_with_record.id}:#{model_name.pluralize}", self.id)
            # remove old assoc
            if old_assoc
              $redis.zrem "#{assoc_with_record.model_name}:#{old_assoc.id}:#{model_name.to_s.pluralize}", self.id
            end
            # create/add new ones
            assoc_with_record.send(model_name.pluralize.to_sym).send(:"<<", self)
          end
        end
      end
    end
  end
end
