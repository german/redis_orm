module RedisOrm
  module Associations
    class HasManyProxy
      def initialize(reciever_model_name, reciever_id, foreign_models, options)
        @records = [] #records.to_a
        @reciever_model_name = reciever_model_name
        @reciever_id = reciever_id
        @foreign_models = foreign_models
        @options = options
        @fetched = false
      end

      def fetch
        key = @options[:as] ? "#{@reciever_model_name}:#{@reciever_id}:#{@options[:as]}" : "#{@reciever_model_name}:#{@reciever_id}:#{@foreign_models}"
        @records = @foreign_models.to_s.singularize.camelize.constantize.find($redis.zrevrangebyscore key, Time.now.to_i, 0)
        @fetched = true
      end

      def [](index)
        fetch if !@fetched
        @records[index]
      end

      # user = User.find(1)
      # user.avatars << Avatar.find(23) => user:1:avatars => [23]
      def <<(new_records)
        new_records.to_a.each do |record|
          key = @options[:as] ? "#{@reciever_model_name}:#{@reciever_id}:#{@options[:as]}" : "#{@reciever_model_name}:#{@reciever_id}:#{@foreign_models}"
          $redis.zadd(key, Time.now.to_i, record.id)          

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

              if !$redis.zrank("#{record.model_name}:#{record.id}:#{pluralized_reciever_model_name}", @reciever_id)
                $redis.zadd("#{record.model_name}:#{record.id}:#{pluralized_reciever_model_name}", Time.now.to_i, @reciever_id)
              end
            # check whether *record* object has *has_one* declaration and TODO it states *self.model_name* and there is no record yet from the *record*'s side (in order not to provoke recursion)
            elsif has_one_assoc = record_associations.detect{|h| [:has_one, :belongs_to].include?(h[:type]) && h[:foreign_model] == @reciever_model_name.to_sym}
              reciever_model_name = if has_one_assoc[:options][:as]
                has_one_assoc[:options][:as].to_sym
              else
                @reciever_model_name
              end
              if record.send(reciever_model_name).nil?
                $redis.set("#{record.model_name}:#{record.id}:#{reciever_model_name}", @reciever_id)
              end
            end
          end
        end
      end

      def all(options = {})
        key = @options[:as] ? "#{@reciever_model_name}:#{@reciever_id}:#{@options[:as]}" : "#{@reciever_model_name}:#{@reciever_id}:#{@foreign_models}"
        if options[:limit] && options[:offset]
          # ZREVRANGEBYSCORE album:ids 1305451611 1305443260 LIMIT 0, 2
          record_ids = $redis.zrevrangebyscore(key, Time.now.to_i, 0, :limit => [options[:offset].to_i, options[:limit].to_i])
          @fetched = true
          @records = @foreign_models.to_s.singularize.camelize.constantize.find(record_ids)
        elsif options[:limit]
          record_ids = $redis.zrevrangebyscore(key, Time.now.to_i, 0, :limit => [0, options[:limit].to_i])
          @fetched = true
          @records = @foreign_models.to_s.singularize.camelize.constantize.find(record_ids)
        else
          fetch if !@fetched
          @records
        end
      end

      alias :find :all

      def count
        key = @options[:as] ? "#{@reciever_model_name}:#{@reciever_id}:#{@options[:as]}" : "#{@reciever_model_name}:#{@reciever_id}:#{@foreign_models}"
        $redis.zcard key
      end

      def method_missing(method_name, *args, &block)
        fetch if !@fetched
        @records.send(method_name, *args, &block)        
      end
    end
  end
end
