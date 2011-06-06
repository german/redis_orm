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
                $redis.zadd("#{record.model_name}:#{record.id}:#{pluralized_reciever_model_name}", Time.now.to_f, @reciever_id)
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
        
        # return *self* here so calls could be chained
        self
      end

      def all(options = {})
        if options.is_a?(Hash) && (options[:limit] || options[:offset] || options[:order])
          limit = if options[:limit] && options[:offset]
            [options[:offset].to_i, options[:limit].to_i]            
          elsif options[:limit]
            [0, options[:limit].to_i]
          end

          record_ids = if options[:order].to_s == 'desc'
            $redis.zrevrangebyscore(__key__, Time.now.to_f, 0, :limit => limit)
          else
            $redis.zrangebyscore(__key__, 0, Time.now.to_f, :limit => limit)
          end
          @fetched = true
          @records = @foreign_models.to_s.singularize.camelize.constantize.find(record_ids)
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
          reversed = options[:order] == 'asc' ? 'desc' : 'asc'
          all(options.merge({:limit => 1, :order => reversed}))[0]
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
          @options[:as] ? "#{@reciever_model_name}:#{@reciever_id}:#{@options[:as]}" : "#{@reciever_model_name}:#{@reciever_id}:#{@foreign_models}"
        end
    end
  end
end
