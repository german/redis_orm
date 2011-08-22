module RedisOrm
  module Utils
    def calculate_key_for_zset(string)
      return 0.0 if string.nil?
      sum = ""      
      string.codepoints.each do |codepoint|
        sum += ("%05i" % codepoint.to_s) # 5 because 65536 => 2 bytes UTF-8
      end
      "0.#{sum}".to_f
    end
  end
end
