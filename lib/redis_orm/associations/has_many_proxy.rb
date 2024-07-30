module RedisOrm
  module Associations
    class HasManyProxy
      include HasManyHelper
      
      def initialize(receiver_model_name, reciever_id, foreign_models, options)
        @records = [] #records.to_a
        @reciever_model_name = receiver_model_name.to_s.downcase
        @reciever_id = reciever_id
        @foreign_models = foreign_models
        @options = options
        @fetched = false
      end

      def receiver_instance
        @receiver_instance ||= @reciever_model_name.camelize.constantize.find(@reciever_id)
      end
      
      def fetch
        @records = @foreign_models.to_s.singularize.camelize.constantize.find($redis.zrevrangebyscore __key__, Time.now.to_f, 0)
        @fetched = true
      end

      def [](index)
        fetch if !@fetched
        @records[index]
      end
      
      def to_a
        fetch if !@fetched
        @records        
      end

      # user = User.find(1)
      # user.avatars << Avatar.find(23) => user:1:avatars => [23]
      def <<(new_records)
        new_records.to_a.each do |record|
          $redis.zadd(__key__, Time.now.to_f, record.id)

          receiver_instance.set_expire_on_reference_key(__key__)
          
          record.get_indices.each do |index|
            save_index_for_associated_record(index, record, [@reciever_model_name, @reciever_id, record.model_name.plural])
          end

          if !@options[:as]
            record_associations = record.get_associations

            # article.comments << [comment1, comment2] 
            # iterate through the array of comments and create backlink
            # check whether *record* object has *has_many* declaration and TODO it states *self.model_name* in plural and there is no record yet from the *record*'s side (in order not to provoke recursion)                    
            if has_many_assoc = record_associations.detect{|h| h[:type] == :has_many && h[:foreign_models] == @reciever_model_name.pluralize.to_sym}
              pluralized_reciever_model_name = if has_many_assoc[:options][:as]
                has_many_assoc[:options][:as].pluralize
              else
                @reciever_model_name.pluralize
              end

              reference_key = "#{record.model_name.singular}:#{record.id}:#{pluralized_reciever_model_name}"
              
              if !$redis.zrank(reference_key, @reciever_id)
                $redis.zadd(reference_key, Time.now.to_f, @reciever_id)
                receiver_instance.set_expire_on_reference_key(reference_key)
              end
            # check whether *record* object has *has_one* declaration and TODO it states *self.model_name* and there is no record yet from the *record*'s side (in order not to provoke recursion)
            elsif has_one_assoc = record_associations.detect{|h| [:has_one, :belongs_to].include?(h[:type]) && h[:foreign_model] == @reciever_model_name.to_sym}
              reciever_model_name = if has_one_assoc[:options][:as]
                has_one_assoc[:options][:as].to_sym
              else
                @reciever_model_name
              end
              if record.public_send(reciever_model_name).nil?
                key = "#{record.model_name.singular}:#{record.id}:#{reciever_model_name}"
                $redis.set(key, @reciever_id)
                receiver_instance.set_expire_on_reference_key(key)
              end
            end
          end
        end
        
        # return *self* here so calls could be chained
        self
      end

      def all(options = {})
        if options.is_a?(Hash) && (options[:limit] || options[:offset] || options[:order] || options[:conditions])
          limit = if options[:limit] && options[:offset]
            [options[:offset].to_i, options[:limit].to_i]            
          elsif options[:limit]
            [0, options[:limit].to_i]
          end

          prepared_index = if options[:conditions] && options[:conditions].is_a?(Hash)
            properties = options[:conditions].collect{|key, value| key}

            index = @foreign_models.to_s.singularize.camelize.constantize.find_indices(properties, :first => true)

            raise NotIndexFound if !index

            construct_prepared_index(index, options[:conditions])
          else
            __key__
          end

          @records = []

          # to DRY things up I use here check for index but *else* branch also imply that the index might have be used
          # since *prepared_index* vary whether options[:conditions] are present or not
          if index && index.options[:unique]
            id = $redis.get prepared_index
            @records << @foreign_models.to_s.singularize.camelize.constantize.find(id)
          else
            ids = if options[:order].to_s == 'desc'
              $redis.zrevrangebyscore(prepared_index, Time.now.to_f, 0, :limit => limit)
            else
              $redis.zrangebyscore(prepared_index, 0, Time.now.to_f, :limit => limit)
            end
            arr = @foreign_models.to_s.singularize.camelize.constantize.find(ids)
            @records += arr
          end
          @fetched = true
          @records
        else
          fetch if !@fetched
          @records
        end
      end

      def find(token = nil, options = {})
        if token.is_a?(String) || token.is_a?(Integer)
          record_id = $redis.zrank(__key__, token.to_i)
          if record_id
            @fetched = true
            @records = @foreign_models.to_s.singularize.camelize.constantize.find(token)
          else
            nil
          end
        elsif token == :all
          all(options)
        elsif token == :first
          all(options.merge({:limit => 1}))[0]
        elsif token == :last
          reversed = options[:order] == 'desc' ? 'asc' : 'desc'
          all(options.merge({limit: 1, order: reversed}))[0]
        end
      end

      def delete(id)
        $redis.zrem(__key__, id.to_i)
      end

      def count
        $redis.zcard __key__
      end

      def method_missing(method_name, *args, &block)
        fetch if !@fetched
        @records.send(method_name, *args, &block)        
      end

      protected

        # helper method
        def __key__
          (@options && @options[:as]) ? "#{@reciever_model_name}:#{@reciever_id}:#{@options[:as]}" : "#{@reciever_model_name}:#{@reciever_id}:#{@foreign_models}"
        end

        # "article:1:comments:moderated:true"
        def construct_prepared_index(index, conditions_hash)
          prepared_index = [@reciever_model_name, @reciever_id, @foreign_models].join(':')
          
          # in order not to depend on order of keys in *:conditions* hash we rather interate over the index itself and find corresponding values in *:conditions* hash
          if index.name.is_a?(Array)
            index.name.each do |key|
              # raise if User.find_by_firstname_and_castname => there's no *castname* in User's properties
              #raise ArgumentsMismatch if !@@properties[model_name].detect{|p| p[:name] == key.to_sym} # TODO
              prepared_index += ":#{key}:#{conditions_hash[key]}"
            end
          else
            prepared_index += ":#{index.name}:#{conditions_hash[index.name]}"
          end

          prepared_index.downcase! if index.options[:case_insensitive]

          prepared_index
        end
    end
  end
end
