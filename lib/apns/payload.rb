module APNS
  
  class Payload
    attr_accessor :device, :message
    
    APS_ROOT = :aps
    APS_KEYS = [:alert, :badge, :sound]
    APS_MAX_SIZE = 256
        
    def initialize(device_token, message_string_or_hash)
      self.device = APNS::Device.new(device_token)
      # Per Apple docs: Strip newlines and whitespace from payload before including in payload
      if message_string_or_hash.is_a?(String)
        self.message = {:alert => message_string_or_hash.strip}
      elsif message_string_or_hash.is_a?(Hash)
        self.message = message_string_or_hash.each_value { |val| val.strip! if val.respond_to? :strip! }
      else
        raise "Payload message needs to be either a hash or string"
      end
    end
        
    def to_ssl
      pm = self.apn_message.to_json
      [0, 0, 32, self.device.to_payload, 0, pm.size, pm].pack("ccca*cca*")
    end
    
    def size
      self.to_ssl.size
    end
    
    def valid?
      self.size <= APS_MAX_SIZE
    end
    
    def apn_message
      message_hash = message.dup
      apnm = { APS_ROOT => {} }
      APS_KEYS.each do |k|
        apnm[APS_ROOT][k] = message_hash.delete(k) if message_hash.has_key?(k)
      end
      apnm.merge!(message_hash)
      apnm
    end
    
    def truncate_alert_message!
      size_without_alert_message = self.size - self.message[:alert].size
      truncate_message_to = APS_MAX_SIZE - size_without_alert_message
      self.message[:alert] = self.message[:alert].truncate(truncate_message_to)
    end
    
  end
end
